//! A Zig client for the Ollama API.
//!
//! This module is the library root: `@import("ollama")` yields the `Ollama`
//! type, with all request/response types re-exported as `pub const` fields.

const std = @import("std");

const HttpClient = @import("http.zig");
const types = @import("types.zig");

/// A client for the Ollama API.
///
/// Create an instance with `init`, then call methods such as `generate`,
/// `chat`, `list`, and `version`. Call `deinit` when done.
const Ollama = @This();

pub const Config = types.Config;
pub const Options = types.Options;
pub const ThinkOption = types.ThinkOption;
pub const Format = types.Format;
pub const KeepAliveOption = types.KeepAliveOption;
pub const GenerateRequest = types.GenerateRequest;
pub const GenerateResponse = types.GenerateResponse;
pub const Role = types.Role;
pub const ToolCall = types.ToolCall;
pub const Message = types.Message;
pub const Tool = types.Tool;
pub const ChatRequest = types.ChatRequest;
pub const ChatResponse = types.ChatResponse;
pub const PullRequest = types.PullRequest;
pub const PushRequest = types.PushRequest;
pub const CreateRequest = types.CreateRequest;
pub const License = types.License;
pub const DeleteRequest = types.DeleteRequest;
pub const CopyRequest = types.CopyRequest;
pub const ShowRequest = types.ShowRequest;
pub const ShowResponse = types.ShowResponse;
pub const EmbedRequest = types.EmbedRequest;
pub const Input = types.Input;
pub const EmbeddingsRequest = types.EmbeddingsRequest;
pub const EmbeddingsResponse = types.EmbeddingsResponse;
pub const ListResponse = types.ListResponse;
pub const VersionResponse = types.VersionResponse;
pub const ProgressResponse = types.ProgressResponse;
pub const StatusResponse = types.StatusResponse;
pub const ErrorResponse = types.ErrorResponse;
pub const ModelDetails = types.ModelDetails;
pub const ModelResponse = types.ModelResponse;
pub const EmbedResponse = types.EmbedResponse;
pub const TokenLogprob = types.TokenLogprob;
pub const Logprob = types.Logprob;
pub const WebSearchRequest = types.WebSearchRequest;
pub const WebSearchResult = types.WebSearchResult;
pub const WebSearchResponse = types.WebSearchResponse;
pub const WebFetchRequest = types.WebFetchRequest;
pub const WebFetchResponse = types.WebFetchResponse;

pub const Response = HttpClient.Response;
pub const ResponseStream = HttpClient.ResponseStream;

allocator: std.mem.Allocator,
http_client: HttpClient,
config: Config,

/// Creates a new Ollama client.
///
/// `config` may be `null` to use the default host `http://localhost:11434`.
pub fn init(io: std.Io, allocator: std.mem.Allocator, config: ?Config) Ollama {
    const cfg: Config = config orelse .{ .host = "http://localhost:11434" };
    return .{
        .allocator = allocator,
        .http_client = HttpClient.init(io, allocator, cfg.headers orelse &.{}),
        .config = cfg,
    };
}

/// Releases resources held by the client.
pub fn deinit(self: *Ollama) void {
    self.http_client.deinit();
}

/// Builds a full URL by appending `path` to the configured host.
/// The caller owns the returned slice.
fn url(self: *Ollama, path: []const u8) ![]u8 {
    return std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.config.host, path });
}

/// Serializes `value` to a JSON string. The caller owns the returned slice.
fn stringify(self: *Ollama, value: anytype) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(self.allocator);
    defer aw.deinit();

    var s: std.json.Stringify = .{
        .writer = &aw.writer,
        .options = .{ .emit_null_optional_fields = false },
    };
    try s.write(value);

    return try aw.toOwnedSlice();
}

/// Generates a response from a text prompt.
///
/// Returns a `ResponseStream` that yields `GenerateResponse` chunks. Set
/// `request.stream` to `false` to receive a single response object instead.
pub fn generate(self: *Ollama, request: GenerateRequest) !ResponseStream(GenerateResponse) {
    const u = try self.url("/api/generate");
    defer self.allocator.free(u);

    const body = try self.stringify(request);
    defer self.allocator.free(body);

    return try self.http_client.postStream(GenerateResponse, u, body);
}

/// Chats with the model.
///
/// Returns a `ResponseStream` that yields `ChatResponse` chunks. Set
/// `request.stream` to `false` to receive a single response object instead.
pub fn chat(self: *Ollama, request: ChatRequest) !ResponseStream(ChatResponse) {
    const u = try self.url("/api/chat");
    defer self.allocator.free(u);

    const body = try self.stringify(request);
    defer self.allocator.free(body);

    return try self.http_client.postStream(ChatResponse, u, body);
}

/// Creates a new model from a stream of data.
///
/// Returns a `ResponseStream` that yields `ProgressResponse` chunks.
pub fn create(self: *Ollama, request: CreateRequest) !ResponseStream(ProgressResponse) {
    const u = try self.url("/api/create");
    defer self.allocator.free(u);

    const body = try self.stringify(request);
    defer self.allocator.free(body);

    return try self.http_client.postStream(ProgressResponse, u, body);
}

/// Pulls a model from the Ollama registry.
///
/// Returns a `ResponseStream` that yields `ProgressResponse` chunks.
pub fn pull(self: *Ollama, request: PullRequest) !ResponseStream(ProgressResponse) {
    const u = try self.url("/api/pull");
    defer self.allocator.free(u);

    const body = try self.stringify(request);
    defer self.allocator.free(body);

    return try self.http_client.postStream(ProgressResponse, u, body);
}

/// Pushes a model to the Ollama registry.
///
/// Returns a `ResponseStream` that yields `ProgressResponse` chunks.
pub fn push(self: *Ollama, request: PushRequest) !ResponseStream(ProgressResponse) {
    const u = try self.url("/api/push");
    defer self.allocator.free(u);

    const body = try self.stringify(request);
    defer self.allocator.free(body);

    return try self.http_client.postStream(ProgressResponse, u, body);
}

/// Deletes a model from the server.
pub fn delete(self: *Ollama, request: DeleteRequest) !Response(StatusResponse) {
    const u = try self.url("/api/delete");
    defer self.allocator.free(u);

    const body = try self.stringify(request);
    defer self.allocator.free(body);

    return try self.http_client.del(StatusResponse, u, body);
}

/// Copies a model from one name to another.
pub fn copy(self: *Ollama, request: CopyRequest) !Response(StatusResponse) {
    const u = try self.url("/api/copy");
    defer self.allocator.free(u);

    const body = try self.stringify(request);
    defer self.allocator.free(body);

    return try self.http_client.post(StatusResponse, u, body);
}

/// Lists the models available on the server.
pub fn list(self: *Ollama) !Response(ListResponse) {
    const u = try self.url("/api/tags");
    defer self.allocator.free(u);

    return try self.http_client.get(ListResponse, u);
}

/// Shows the metadata of a model.
pub fn show(self: *Ollama, request: ShowRequest) !Response(ShowResponse) {
    const u = try self.url("/api/show");
    defer self.allocator.free(u);

    const body = try self.stringify(request);
    defer self.allocator.free(body);

    return try self.http_client.post(ShowResponse, u, body);
}

/// Embeds text input into vectors.
pub fn embed(self: *Ollama, request: EmbedRequest) !Response(EmbedResponse) {
    const u = try self.url("/api/embed");
    defer self.allocator.free(u);

    const body = try self.stringify(request);
    defer self.allocator.free(body);

    return try self.http_client.post(EmbedResponse, u, body);
}

/// Embeds a text prompt into a vector.
pub fn embeddings(self: *Ollama, request: EmbeddingsRequest) !Response(EmbeddingsResponse) {
    const u = try self.url("/api/embeddings");
    defer self.allocator.free(u);

    const body = try self.stringify(request);
    defer self.allocator.free(body);

    return try self.http_client.post(EmbeddingsResponse, u, body);
}

/// Lists the models currently running on the server.
pub fn ps(self: *Ollama) !Response(ListResponse) {
    const u = try self.url("/api/ps");
    defer self.allocator.free(u);

    return try self.http_client.get(ListResponse, u);
}

/// Returns the Ollama server version.
pub fn version(self: *Ollama) !Response(VersionResponse) {
    const u = try self.url("/api/version");
    defer self.allocator.free(u);

    return try self.http_client.get(VersionResponse, u);
}

/// Performs a web search using the Ollama web search API.
pub fn webSearch(self: *Ollama, request: WebSearchRequest) !Response(WebSearchResponse) {
    const body = try self.stringify(request);
    defer self.allocator.free(body);

    return try self.http_client.post(WebSearchResponse, "https://ollama.com/api/web_search", body);
}

/// Fetches a single page using the Ollama web fetch API.
pub fn webFetch(self: *Ollama, request: WebFetchRequest) !Response(WebFetchResponse) {
    const body = try self.stringify(request);
    defer self.allocator.free(body);

    return try self.http_client.post(WebFetchResponse, "https://ollama.com/api/web_fetch", body);
}

test {
    std.testing.refAllDecls(@This());
}
