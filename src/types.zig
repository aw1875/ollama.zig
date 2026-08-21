const std = @import("std");
const Http = std.http;

pub const Config = struct {
    host: []const u8,
    proxy: ?bool = null,
    headers: ?[]const Http.Header = null,
};

pub const Options = struct {
    numa: ?bool = null,
    num_ctx: ?u32 = null,
    num_batch: ?u32 = null,
    num_gpu: ?u32 = null,
    main_gpu: ?u32 = null,
    low_vram: ?bool = null,
    f16_kv: ?bool = null,
    logits_all: ?bool = null,
    vocab_only: ?bool = null,
    use_mmap: ?bool = null,
    use_mlock: ?bool = null,
    embedding_only: ?bool = null,
    num_thread: ?u32 = null,

    // Runtime options
    num_keep: ?u32 = null,
    seed: ?u32 = null,
    num_predict: ?u32 = null,
    top_k: ?u32 = null,
    top_p: ?f32 = null,
    min_p: ?f32 = null,
    tfs_z: ?f32 = null,
    typical_p: ?f32 = null,
    repeat_last_n: ?u32 = null,
    temperature: ?f32 = null,
    repeat_penalty: ?f32 = null,
    presence_penalty: ?f32 = null,
    frequency_penalty: ?f32 = null,
    mirostat: ?u32 = null,
    mirostat_tau: ?f32 = null,
    mirostat_eta: ?f32 = null,
    penalize_newline: ?bool = null,
    stop: ?[]const []const u8 = null,
};

pub const ThinkOption = union(enum) {
    bool: bool,
    string: enum {
        high,
        medium,
        low,
    },

    pub fn jsonStringify(self: *const ThinkOption, writer: *std.json.Stringify) !void {
        switch (self.*) {
            .bool => |value| try writer.write(value),
            .string => |value| try writer.write(value),
        }
    }
};

pub const Format = union(enum) {
    json: []const u8,
    structured: std.json.Value,

    pub fn jsonStringify(self: *const Format, writer: *std.json.Stringify) !void {
        switch (self.*) {
            .json => |value| try writer.write(value),
            .structured => |value| try writer.write(value),
        }
    }
};

pub const KeepAliveOption = union(enum) {
    string: []const u8,
    number: u32,

    pub fn jsonStringify(self: *const KeepAliveOption, writer: *std.json.Stringify) !void {
        switch (self.*) {
            inline else => |value| try writer.write(value),
        }
    }
};

pub const GenerateRequest = struct {
    model: []const u8,
    prompt: []const u8,
    suffix: ?[]const u8 = null,
    system: ?[]const u8 = null,
    template: ?[]const u8 = null,
    context: ?[]u32 = null,
    stream: ?bool = null,
    raw: ?bool = null,
    format: ?Format = null,
    images: ?[]const []const u8 = null,
    keep_alive: ?KeepAliveOption = null,
    think: ?ThinkOption = null,
    logprobs: ?bool = null,
    top_logprobs: ?u32 = null,
    width: ?u32 = null,
    height: ?u32 = null,
    steps: ?u32 = null,
    options: ?Options = null,
};

pub const GenerateResponse = struct {
    model: []const u8 = "",
    created_at: []const u8 = "",
    response: []const u8 = "",
    thinking: ?[]const u8 = null,
    done: bool = false,
    done_reason: ?[]const u8 = null,
    total_duration: ?u64 = null,
    load_duration: ?u64 = null,
    prompt_eval_count: ?u32 = null,
    prompt_eval_duration: ?u64 = null,
    eval_count: ?u32 = null,
    eval_duration: ?u64 = null,
    context: ?[]u32 = null,
    logprobs: ?[]Logprob = null,
    image: ?[]const u8 = null,
    completed: ?u32 = null,
    total: ?u32 = null,
};

pub const Role = enum {
    system,
    user,
    assistant,
    tool,
};

pub const ToolCall = struct {
    function: struct {
        name: []const u8 = "",
        arguments: std.json.Value = .null,
    },
};

pub const Message = struct {
    role: Role,
    content: []const u8 = "",
    thinking: ?[]const u8 = null,
    images: ?[]const []const u8 = null,
    tool_calls: ?[]ToolCall = null,
    tool_name: ?[]const u8 = null,
};

pub const Tool = std.json.Value;

pub const ChatRequest = struct {
    model: []const u8,
    messages: ?[]const Message = null,
    stream: ?bool = null,
    format: ?Format = null,
    keep_alive: ?KeepAliveOption = null,
    tools: ?[]const Tool = null,
    think: ?ThinkOption = null,
    logprobs: ?bool = null,
    top_logprobs: ?u32 = null,
    options: ?Options = null,
};

pub const ChatResponse = struct {
    model: []const u8 = "",
    created_at: []const u8 = "",
    message: Message = .{ .role = .assistant },
    done: bool = false,
    done_reason: ?[]const u8 = null,
    total_duration: ?u64 = null,
    load_duration: ?u64 = null,
    prompt_eval_count: ?u32 = null,
    prompt_eval_duration: ?u64 = null,
    eval_count: ?u32 = null,
    eval_duration: ?u64 = null,
    logprobs: ?[]Logprob = null,
};

pub const PullRequest = struct {
    model: []const u8,
    insecure: ?bool = null,
    stream: ?bool = null,
};

pub const PushRequest = struct {
    model: []const u8,
    insecure: ?bool = null,
    stream: ?bool = null,
};

pub const CreateRequest = struct {
    model: []const u8,
    from: ?[]const u8 = null,
    stream: ?bool = null,
    quantize: ?[]const u8 = null,
    template: ?[]const u8 = null,
    license: ?License = null,
    system: ?[]const u8 = null,
    parameters: ?std.json.Value = null,
    messages: ?[]const Message = null,
    adapters: ?std.json.Value = null,
};

pub const License = union(enum) {
    string: []const u8,
    array: []const []const u8,

    pub fn jsonStringify(self: *const License, writer: *std.json.Stringify) !void {
        switch (self.*) {
            inline else => |value| try writer.write(value),
        }
    }
};

pub const DeleteRequest = struct {
    model: []const u8,
};

pub const CopyRequest = struct {
    source: []const u8,
    destination: []const u8,
};

pub const ShowRequest = struct {
    model: []const u8,
    system: ?[]const u8 = null,
    template: ?[]const u8 = null,
    options: ?Options = null,
};

pub const EmbedRequest = struct {
    model: []const u8,
    input: Input,
    truncate: ?bool = null,
    keep_alive: ?KeepAliveOption = null,
    dimensions: ?u32 = null,
    options: ?Options = null,
};

pub const Input = union(enum) {
    string: []const u8,
    array: []const []const u8,

    pub fn jsonStringify(self: *const Input, writer: *std.json.Stringify) !void {
        switch (self.*) {
            inline else => |value| try writer.write(value),
        }
    }
};

pub const EmbeddingsRequest = struct {
    model: []const u8,
    prompt: []const u8,
    keep_alive: ?KeepAliveOption = null,
    options: ?Options = null,
};

pub const TokenLogprob = struct {
    token: []const u8 = "",
    logprob: f64 = 0,
};

pub const Logprob = struct {
    token: []const u8 = "",
    logprob: f64 = 0,
    top_logprobs: ?[]TokenLogprob = null,
};

pub const ProgressResponse = struct {
    status: []const u8 = "",
    digest: ?[]const u8 = null,
    total: ?u64 = null,
    completed: ?u64 = null,
};

pub const ModelDetails = struct {
    parent_model: []const u8 = "",
    format: []const u8 = "",
    family: []const u8 = "",
    families: ?[]const []const u8 = null,
    parameter_size: []const u8 = "",
    quantization_level: []const u8 = "",
};

pub const ModelResponse = struct {
    name: []const u8 = "",
    model: []const u8 = "",
    modified_at: []const u8 = "",
    size: u64 = 0,
    digest: []const u8 = "",
    details: ModelDetails = .{},
    expires_at: ?[]const u8 = null,
    size_vram: u64 = 0,
    capabilities: ?[]const []const u8 = null,
};

pub const ShowResponse = struct {
    license: []const u8 = "",
    modelfile: []const u8 = "",
    parameters: []const u8 = "",
    template: []const u8 = "",
    system: []const u8 = "",
    details: ModelDetails = .{},
    messages: ?[]Message = null,
    modified_at: []const u8 = "",
    model_info: ?std.json.Value = null,
    capabilities: ?[]const []const u8 = null,
    projector_info: ?std.json.Value = null,
};

pub const EmbedResponse = struct {
    model: []const u8 = "",
    embeddings: [][]f32 = &.{},
    total_duration: ?u64 = null,
    load_duration: ?u64 = null,
    prompt_eval_count: ?u32 = null,
};

pub const EmbeddingsResponse = struct {
    embedding: []f32 = &.{},
};

pub const ListResponse = struct {
    models: []ModelResponse = &.{},
};

pub const VersionResponse = struct {
    version: []const u8 = "",
};

pub const ErrorResponse = struct {
    @"error": []const u8 = "",
};

pub const StatusResponse = struct {
    status: []const u8 = "",
};

pub const WebSearchRequest = struct {
    query: []const u8,
    maxResults: ?u32 = null,
};

pub const WebSearchResult = struct {
    content: []const u8 = "",
};

pub const WebSearchResponse = struct {
    results: []WebSearchResult = &.{},
};

pub const WebFetchRequest = struct {
    url: []const u8,
};

pub const WebFetchResponse = struct {
    title: []const u8 = "",
    url: []const u8 = "",
    content: []const u8 = "",
    links: []const []const u8 = &.{},
};
