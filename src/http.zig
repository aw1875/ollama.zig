//! Low-level HTTP transport for the Ollama client.
//!
//! Wraps `std.http.Client` to perform JSON requests and return either a
//! fully-buffered `Response` or a streaming `ResponseStream`.

const std = @import("std");

/// A thin wrapper around `std.http.Client` that performs JSON requests and
/// returns either a fully-buffered `Response` or a streaming `ResponseStream`.
const HttpClient = @This();

io: std.Io,
allocator: std.mem.Allocator,
client: std.http.Client,
headers: []const std.http.Header,

/// Creates a new HTTP client. `headers` are sent with every request.
pub fn init(io: std.Io, allocator: std.mem.Allocator, headers: []const std.http.Header) HttpClient {
    return .{
        .io = io,
        .allocator = allocator,
        .client = std.http.Client{ .io = io, .allocator = allocator },
        .headers = headers,
    };
}

/// Releases resources held by the client.
pub fn deinit(self: *HttpClient) void {
    self.client.deinit();
}

/// A parsed, non-streaming HTTP response. The body is parsed lazily via `body()`.
pub fn Response(comptime T: type) type {
    return struct {
        arena: *std.heap.ArenaAllocator,
        status: std.http.Status,
        raw: []const u8,

        /// Frees the response and all memory backing its parsed body.
        pub fn deinit(self: *Response(T)) void {
            const child = self.arena.child_allocator;
            self.arena.deinit();
            child.destroy(self.arena);
        }

        /// Parses the raw response body into `T`.
        pub fn body(self: *Response(T)) !T {
            return try std.json.parseFromSliceLeaky(T, self.arena.allocator(), self.raw, .{
                .ignore_unknown_fields = true,
            });
        }
    };
}

/// A streaming HTTP response. Each call to `next()` yields the next parsed
/// newline-delimited JSON object, or `null` when the stream is exhausted.
///
/// All yielded values are backed by the stream's arena and remain valid until
/// the next call to `next()` or `deinit()`.
pub fn ResponseStream(comptime T: type) type {
    return struct {
        arena: *std.heap.ArenaAllocator,
        req: *std.http.Client.Request,
        body_reader: *std.Io.Reader,

        /// Frees the request, arena, and all memory backing yielded values.
        pub fn deinit(self: *ResponseStream(T)) void {
            self.req.deinit();
            const child = self.arena.child_allocator;
            self.arena.deinit();
            child.destroy(self.arena);
        }

        /// Returns the next parsed chunk, or `null` when the stream is exhausted.
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

/// Allocates and initializes an arena allocator. The caller owns the result.
fn newArena(allocator: std.mem.Allocator) !*std.heap.ArenaAllocator {
    const arena = try allocator.create(std.heap.ArenaAllocator);
    errdefer allocator.destroy(arena);
    arena.* = .init(allocator);
    return arena;
}

/// Frees an arena and the struct backing it. `arena.deinit()` alone frees the
/// arena's contents but leaks the struct `newArena` allocated.
fn destroyArena(arena: *std.heap.ArenaAllocator) void {
    const child = arena.child_allocator;
    arena.deinit();
    child.destroy(arena);
}

/// Performs a GET request and buffers the response body.
pub fn get(self: *HttpClient, comptime T: type, url: []const u8) !Response(T) {
    const arena = try newArena(self.allocator);
    errdefer destroyArena(arena);

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

/// Performs a POST request with a JSON body and buffers the response body.
pub fn post(self: *HttpClient, comptime T: type, url: []const u8, body: []const u8) !Response(T) {
    const arena = try newArena(self.allocator);
    errdefer destroyArena(arena);

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

/// Performs a DELETE request with a JSON body and buffers the response body.
pub fn del(self: *HttpClient, comptime T: type, url: []const u8, body: []const u8) !Response(T) {
    const arena = try newArena(self.allocator);
    errdefer destroyArena(arena);

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

/// Performs a streaming POST request. The response body is read incrementally
/// and parsed as newline-delimited JSON.
pub fn postStream(self: *HttpClient, comptime T: type, url: []const u8, body: []u8) !ResponseStream(T) {
    const arena = try newArena(self.allocator);
    errdefer destroyArena(arena);

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

test "Response.body parses JSON into the target type" {
    const allocator = std.testing.allocator;

    const arena = try allocator.create(std.heap.ArenaAllocator);
    arena.* = .init(allocator);

    const raw = try arena.allocator().dupe(u8, "{\"model\":\"llama3.2\",\"response\":\"hello\",\"done\":true}");

    var response: Response(struct {
        model: []const u8,
        response: []const u8,
        done: bool,
    }) = .{
        .arena = arena,
        .status = .ok,
        .raw = raw,
    };
    defer response.deinit();

    const body = try response.body();
    try std.testing.expectEqualStrings("llama3.2", body.model);
    try std.testing.expectEqualStrings("hello", body.response);
    try std.testing.expect(body.done);
}

test "Response.body ignores unknown fields" {
    const allocator = std.testing.allocator;

    const arena = try allocator.create(std.heap.ArenaAllocator);
    arena.* = .init(allocator);

    const raw = try arena.allocator().dupe(u8, "{\"model\":\"llama3.2\",\"unknown_field\":123}");

    var response: Response(struct {
        model: []const u8,
    }) = .{
        .arena = arena,
        .status = .ok,
        .raw = raw,
    };
    defer response.deinit();

    const body = try response.body();
    try std.testing.expectEqualStrings("llama3.2", body.model);
}
