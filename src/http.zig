const std = @import("std");

const HttpClient = @This();

io: std.Io,
allocator: std.mem.Allocator,
client: std.http.Client,
headers: []const std.http.Header,

pub fn init(io: std.Io, allocator: std.mem.Allocator, headers: []const std.http.Header) HttpClient {
    return .{
        .io = io,
        .allocator = allocator,
        .client = std.http.Client{ .io = io, .allocator = allocator },
        .headers = headers,
    };
}

pub fn deinit(self: *HttpClient) void {
    self.client.deinit();
}

pub fn Response(comptime T: type) type {
    return struct {
        arena: *std.heap.ArenaAllocator,
        status: std.http.Status,
        raw: []const u8,

        pub fn deinit(self: *Response(T)) void {
            const child = self.arena.child_allocator;
            self.arena.deinit();
            child.destroy(self.arena);
        }

        pub fn body(self: *Response(T)) !T {
            return try std.json.parseFromSliceLeaky(T, self.arena.allocator(), self.raw, .{
                .ignore_unknown_fields = true,
            });
        }
    };
}

pub fn ResponseStream(comptime T: type) type {
    return struct {
        arena: *std.heap.ArenaAllocator,
        req: *std.http.Client.Request,
        body_reader: *std.Io.Reader,

        pub fn deinit(self: *ResponseStream(T)) void {
            self.req.deinit();
            const child = self.arena.child_allocator;
            self.arena.deinit();
            child.destroy(self.arena);
        }

        pub fn next(self: *ResponseStream(T)) !?T {
            while (true) {
                const line = try self.body_reader.takeDelimiter('\n') orelse return null;
                const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
                if (trimmed.len == 0) continue;
                return try std.json.parseFromSliceLeaky(T, self.arena.allocator(), trimmed, .{
                    .ignore_unknown_fields = true,
                });
            }
        }
    };
}

fn newArena(allocator: std.mem.Allocator) !*std.heap.ArenaAllocator {
    const arena = try allocator.create(std.heap.ArenaAllocator);
    errdefer allocator.destroy(arena);
    arena.* = .init(allocator);
    return arena;
}

pub fn get(self: *HttpClient, comptime T: type, url: []const u8) !Response(T) {
    const arena = try newArena(self.allocator);
    errdefer arena.deinit();

    var bw: std.Io.Writer.Allocating = .init(arena.allocator());

    const response = self.client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .extra_headers = self.headers,
        .response_writer = &bw.writer,
    }) catch |err| {
        std.log.scoped(.ollama).err("GET failed: {s}", .{@errorName(err)});
        return err;
    };

    return .{
        .arena = arena,
        .status = response.status,
        .raw = try bw.toOwnedSlice(),
    };
}

pub fn post(self: *HttpClient, comptime T: type, url: []const u8, body: []const u8) !Response(T) {
    const arena = try newArena(self.allocator);
    errdefer arena.deinit();

    var bw: std.Io.Writer.Allocating = .init(arena.allocator());

    const response = self.client.fetch(.{
        .location = .{ .url = url },
        .method = .POST,
        .headers = .{ .content_type = .{ .override = "application/json" } },
        .extra_headers = self.headers,
        .payload = body,
        .response_writer = &bw.writer,
    }) catch |err| {
        std.log.scoped(.ollama).err("POST failed: {s}", .{@errorName(err)});
        return err;
    };

    return .{
        .arena = arena,
        .status = response.status,
        .raw = try bw.toOwnedSlice(),
    };
}

pub fn del(self: *HttpClient, comptime T: type, url: []const u8, body: []const u8) !Response(T) {
    const arena = try newArena(self.allocator);
    errdefer arena.deinit();

    var bw: std.Io.Writer.Allocating = .init(arena.allocator());

    const response = self.client.fetch(.{
        .location = .{ .url = url },
        .method = .DELETE,
        .headers = .{ .content_type = .{ .override = "application/json" } },
        .extra_headers = self.headers,
        .payload = body,
        .response_writer = &bw.writer,
    }) catch |err| {
        std.log.scoped(.ollama).err("DELETE failed: {s}", .{@errorName(err)});
        return err;
    };

    return .{
        .arena = arena,
        .status = response.status,
        .raw = try bw.toOwnedSlice(),
    };
}

pub fn postStream(self: *HttpClient, comptime T: type, url: []const u8, body: []u8) !ResponseStream(T) {
    const arena = try newArena(self.allocator);
    errdefer arena.deinit();

    const a = arena.allocator();

    const uri = try std.Uri.parse(url);

    const req = try a.create(std.http.Client.Request);
    errdefer a.destroy(req);

    req.* = try self.client.request(.POST, uri, .{
        .headers = .{ .content_type = .{ .override = "application/json" } },
        .extra_headers = self.headers,
        .keep_alive = false,
    });
    errdefer req.deinit();

    try req.sendBodyComplete(body);

    var redirect_buf: [0]u8 = undefined;
    var response = try req.receiveHead(&redirect_buf);

    if (response.head.status != .ok) return error.HttpError;

    const transfer_buffer = try a.alloc(u8, 1024 * 1024);
    const body_reader = response.reader(transfer_buffer);

    return .{
        .arena = arena,
        .req = req,
        .body_reader = body_reader,
    };
}
