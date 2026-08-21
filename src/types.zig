//! Type definitions for the Ollama API.
//!
//! Contains request and response structs mirroring the Ollama HTTP API, plus
//! helper union types that serialize to bare JSON values.

const std = @import("std");
const Http = std.http;

/// Configuration for the Ollama client.
pub const Config = struct {
    /// The base URL of the Ollama server (e.g. `http://localhost:11434`).
    host: []const u8,

    /// Whether to use a proxy.
    proxy: ?bool = null,

    /// Additional headers to send with every request.
    headers: ?[]const Http.Header = null,
};

/// Model options that control generation behavior.
pub const Options = struct {
    /// Enable NUMA support.
    numa: ?bool = null,

    /// Size of the context window.
    num_ctx: ?u32 = null,

    /// Batch size for prompt processing.
    num_batch: ?u32 = null,

    /// Number of GPUs to use.
    num_gpu: ?u32 = null,

    /// The GPU to use for the main model.
    main_gpu: ?u32 = null,

    /// Use low VRAM mode.
    low_vram: ?bool = null,

    /// Use 16-bit floating point for the KV cache.
    f16_kv: ?bool = null,

    /// Return logits for all tokens, not just the last one.
    logits_all: ?bool = null,

    /// Load only the vocabulary, not the weights.
    vocab_only: ?bool = null,

    /// Use memory-mapped I/O.
    use_mmap: ?bool = null,

    /// Lock the model in memory.
    use_mlock: ?bool = null,

    /// Use embedding-only mode.
    embedding_only: ?bool = null,

    /// Number of threads to use.
    num_thread: ?u32 = null,

    // Runtime options

    /// Number of tokens to keep from the prompt.
    num_keep: ?u32 = null,

    /// Random seed for generation.
    seed: ?u32 = null,

    /// Maximum number of tokens to predict.
    num_predict: ?u32 = null,

    /// Top-k sampling.
    top_k: ?u32 = null,

    /// Top-p (nucleus) sampling.
    top_p: ?f32 = null,

    /// Minimum probability for a token to be considered.
    min_p: ?f32 = null,

    /// Tail-free sampling parameter.
    tfs_z: ?f32 = null,

    /// Locally typical sampling parameter.
    typical_p: ?f32 = null,

    /// Number of tokens to consider for repeat penalty.
    repeat_last_n: ?u32 = null,

    /// Sampling temperature.
    temperature: ?f32 = null,

    /// Penalty for repeating tokens.
    repeat_penalty: ?f32 = null,

    /// Penalty for token presence.
    presence_penalty: ?f32 = null,

    /// Penalty for token frequency.
    frequency_penalty: ?f32 = null,

    /// Mirostat sampling mode.
    mirostat: ?u32 = null,

    /// Mirostat target entropy.
    mirostat_tau: ?f32 = null,

    /// Mirostat learning rate.
    mirostat_eta: ?f32 = null,

    /// Penalize newlines.
    penalize_newline: ?bool = null,

    /// Stop sequences.
    stop: ?[]const []const u8 = null,
};

/// Controls whether the model should think before responding (for thinking models).
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

/// The format to return a response in. Can be `json` or a JSON schema.
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

/// Controls how long the model stays loaded into memory following a request.
pub const KeepAliveOption = union(enum) {
    /// A duration string with a unit suffix (e.g. `"5m"`, `"1.5h"`).
    string: []const u8,

    /// A number of seconds.
    number: u32,

    pub fn jsonStringify(self: *const KeepAliveOption, writer: *std.json.Stringify) !void {
        switch (self.*) {
            inline else => |value| try writer.write(value),
        }
    }
};

/// Request to generate a response from a text prompt.
pub const GenerateRequest = struct {
    /// The model name.
    model: []const u8,

    /// The prompt to generate a response for.
    prompt: []const u8,

    /// The text after the model response.
    suffix: ?[]const u8 = null,

    /// System message (overrides what is defined in the `Modelfile`).
    system: ?[]const u8 = null,

    /// The prompt template to use (overrides what is defined in the `Modelfile`).
    template: ?[]const u8 = null,

    /// Deprecated: the context parameter returned from a previous request to
    /// `/generate`, used to keep a short conversational memory.
    context: ?[]u32 = null,

    /// If `false` the response is returned as a single object rather than a stream.
    stream: ?bool = null,

    /// If `true` no formatting is applied to the prompt.
    raw: ?bool = null,

    /// The format to return a response in.
    format: ?Format = null,

    /// A list of base64-encoded images (for multimodal models such as `llava`).
    images: ?[]const []const u8 = null,

    /// Controls how long the model stays loaded into memory following the request.
    keep_alive: ?KeepAliveOption = null,

    /// Should the model think before responding (for thinking models).
    think: ?ThinkOption = null,

    /// Return log probabilities for the generated tokens.
    logprobs: ?bool = null,

    /// Number of most likely tokens to return per token.
    top_logprobs: ?u32 = null,

    /// Width of the generated image in pixels (image generation models only).
    width: ?u32 = null,

    /// Height of the generated image in pixels (image generation models only).
    height: ?u32 = null,

    /// Number of diffusion steps (image generation models only).
    steps: ?u32 = null,

    /// Options to control the generation.
    options: ?Options = null,
};

/// Response from a generate request.
pub const GenerateResponse = struct {
    /// The model that generated the response.
    model: []const u8 = "",

    /// The time the response was generated, in ISO 8601 format.
    created_at: []const u8 = "",

    /// The generated text. When streaming, this is a partial response.
    response: []const u8 = "",

    /// The model's thinking output, if it is a thinking model.
    thinking: ?[]const u8 = null,

    /// Whether the model has finished generating the response.
    done: bool = false,

    /// The reason the model finished generating (e.g. `stop`, `length`).
    done_reason: ?[]const u8 = null,

    /// Time spent generating the response in nanoseconds.
    total_duration: ?u64 = null,

    /// Time spent loading the model in nanoseconds.
    load_duration: ?u64 = null,

    /// Number of tokens in the prompt.
    prompt_eval_count: ?u32 = null,

    /// Time spent evaluating the prompt in nanoseconds.
    prompt_eval_duration: ?u64 = null,

    /// Number of tokens in the response.
    eval_count: ?u32 = null,

    /// Time spent generating the response in nanoseconds.
    eval_duration: ?u64 = null,

    /// An encoding of the conversation used in this response.
    context: ?[]u32 = null,

    /// Log probability information for the generated tokens.
    logprobs: ?[]Logprob = null,

    /// Base64-encoded generated image data (image generation models only).
    image: ?[]const u8 = null,

    /// Number of completed steps (for streaming progress).
    completed: ?u32 = null,

    /// Total number of steps (for streaming progress).
    total: ?u32 = null,
};

/// The role of a message in a conversation.
pub const Role = enum {
    system,
    user,
    assistant,
    tool,
};

/// A tool call made by the model.
pub const ToolCall = struct {
    function: struct {
        /// The name of the function to call.
        name: []const u8 = "",

        /// The arguments to pass to the function.
        arguments: std.json.Value = .null,
    },
};

/// A message in a conversation.
pub const Message = struct {
    /// The role of the message.
    role: Role,

    /// The content of the message.
    content: []const u8 = "",

    /// The thinking output associated with the message.
    thinking: ?[]const u8 = null,

    /// A list of base64-encoded images (for multimodal models).
    images: ?[]const []const u8 = null,

    /// Tool calls made by the model.
    tool_calls: ?[]ToolCall = null,

    /// The name of the tool that produced this message.
    tool_name: ?[]const u8 = null,
};

/// A tool definition. Represented as an arbitrary JSON value.
pub const Tool = std.json.Value;

/// Request to chat with the model.
pub const ChatRequest = struct {
    /// The model name.
    model: []const u8,

    /// The messages in the conversation.
    messages: ?[]const Message = null,

    /// If `false` the response is returned as a single object rather than a stream.
    stream: ?bool = null,

    /// The format to return a response in.
    format: ?Format = null,

    /// Controls how long the model stays loaded into memory following the request.
    keep_alive: ?KeepAliveOption = null,

    /// Tools available to the model.
    tools: ?[]const Tool = null,

    /// Should the model think before responding (for thinking models).
    think: ?ThinkOption = null,

    /// Return log probabilities for the generated tokens.
    logprobs: ?bool = null,

    /// Number of most likely tokens to return per token.
    top_logprobs: ?u32 = null,

    /// Options to control the generation.
    options: ?Options = null,
};

/// Response from a chat request.
pub const ChatResponse = struct {
    /// The model that generated the response.
    model: []const u8 = "",

    /// The time the response was generated, in ISO 8601 format.
    created_at: []const u8 = "",

    /// The message generated by the model.
    message: Message = .{ .role = .assistant },

    /// Whether the model has finished generating the response.
    done: bool = false,

    /// The reason the model finished generating.
    done_reason: ?[]const u8 = null,

    /// Time spent generating the response in nanoseconds.
    total_duration: ?u64 = null,

    /// Time spent loading the model in nanoseconds.
    load_duration: ?u64 = null,

    /// Number of tokens in the prompt.
    prompt_eval_count: ?u32 = null,

    /// Time spent evaluating the prompt in nanoseconds.
    prompt_eval_duration: ?u64 = null,

    /// Number of tokens in the response.
    eval_count: ?u32 = null,

    /// Time spent generating the response in nanoseconds.
    eval_duration: ?u64 = null,

    /// Log probability information for the generated tokens.
    logprobs: ?[]Logprob = null,
};

/// Request to pull a model from the Ollama registry.
pub const PullRequest = struct {
    /// The model name.
    model: []const u8,

    /// Allow insecure connections to the registry.
    insecure: ?bool = null,

    /// If `false` the response is returned as a single object rather than a stream.
    stream: ?bool = null,
};

/// Request to push a model to the Ollama registry.
pub const PushRequest = struct {
    /// The model name.
    model: []const u8,

    /// Allow insecure connections to the registry.
    insecure: ?bool = null,

    /// If `false` the response is returned as a single object rather than a stream.
    stream: ?bool = null,
};

/// Request to create a new model.
pub const CreateRequest = struct {
    /// Name of the model to create.
    model: []const u8,

    /// Name of an existing model to create the new model from.
    from: ?[]const u8 = null,

    /// If `false` the response is returned as a single object rather than a stream.
    stream: ?bool = null,

    /// Quantization level to use.
    quantize: ?[]const u8 = null,

    /// The prompt template to use.
    template: ?[]const u8 = null,

    /// The license for the model.
    license: ?License = null,

    /// System message.
    system: ?[]const u8 = null,

    /// Model parameters.
    parameters: ?std.json.Value = null,

    /// Messages used to create the model.
    messages: ?[]const Message = null,

    /// Adapter configurations.
    adapters: ?std.json.Value = null,
};

/// A license, either a single string or a list of strings.
pub const License = union(enum) {
    string: []const u8,
    array: []const []const u8,

    pub fn jsonStringify(self: *const License, writer: *std.json.Stringify) !void {
        switch (self.*) {
            inline else => |value| try writer.write(value),
        }
    }
};

/// Request to delete a model.
pub const DeleteRequest = struct {
    /// The model name.
    model: []const u8,
};

/// Request to copy a model from one name to another.
pub const CopyRequest = struct {
    /// The source model name.
    source: []const u8,

    /// The destination model name.
    destination: []const u8,
};

/// Request to show the metadata of a model.
pub const ShowRequest = struct {
    /// The model name.
    model: []const u8,

    /// System message.
    system: ?[]const u8 = null,

    /// The prompt template to use.
    template: ?[]const u8 = null,

    /// Options to control the generation.
    options: ?Options = null,
};

/// Request to embed text input into vectors.
pub const EmbedRequest = struct {
    /// The model name.
    model: []const u8,

    /// The input text, or a list of input texts.
    input: Input,

    /// Truncate the input to fit the context window.
    truncate: ?bool = null,

    /// Controls how long the model stays loaded into memory following the request.
    keep_alive: ?KeepAliveOption = null,

    /// The number of dimensions for the output embeddings.
    dimensions: ?u32 = null,

    /// Options to control the generation.
    options: ?Options = null,
};

/// Input to an embed request: either a single string or a list of strings.
pub const Input = union(enum) {
    string: []const u8,
    array: []const []const u8,

    pub fn jsonStringify(self: *const Input, writer: *std.json.Stringify) !void {
        switch (self.*) {
            inline else => |value| try writer.write(value),
        }
    }
};

/// Request to embed a text prompt into a vector.
pub const EmbeddingsRequest = struct {
    /// The model name.
    model: []const u8,

    /// The prompt to embed.
    prompt: []const u8,

    /// Controls how long the model stays loaded into memory following the request.
    keep_alive: ?KeepAliveOption = null,

    /// Options to control the generation.
    options: ?Options = null,
};

/// A token and its log probability.
pub const TokenLogprob = struct {
    /// The text representation of the token.
    token: []const u8 = "",

    /// The log probability of this token.
    logprob: f64 = 0,
};

/// Log probability information for a generated token.
pub const Logprob = struct {
    /// The text representation of the token.
    token: []const u8 = "",

    /// The log probability of this token.
    logprob: f64 = 0,

    /// Most likely tokens and their log probabilities at this position.
    top_logprobs: ?[]TokenLogprob = null,
};

/// Progress response for pull, push, and create operations.
pub const ProgressResponse = struct {
    /// The current status (e.g. `pulling manifest`, `success`).
    status: []const u8 = "",

    /// The digest of the current layer.
    digest: ?[]const u8 = null,

    /// Total size of the operation.
    total: ?u64 = null,

    /// Completed size of the operation.
    completed: ?u64 = null,
};

/// Additional information about a model's format and family.
pub const ModelDetails = struct {
    /// The parent model name.
    parent_model: []const u8 = "",

    /// Model file format (e.g. `gguf`).
    format: []const u8 = "",

    /// Primary model family (e.g. `llama`).
    family: []const u8 = "",

    /// All families the model belongs to.
    families: ?[]const []const u8 = null,

    /// Approximate parameter count label (e.g. `7B`, `13B`).
    parameter_size: []const u8 = "",

    /// Quantization level used (e.g. `Q4_0`).
    quantization_level: []const u8 = "",
};

/// A model listed by the server.
pub const ModelResponse = struct {
    /// Model name.
    name: []const u8 = "",

    /// Model name.
    model: []const u8 = "",

    /// Last modified timestamp in ISO 8601 format.
    modified_at: []const u8 = "",

    /// Total size of the model on disk in bytes.
    size: u64 = 0,

    /// SHA256 digest identifier of the model contents.
    digest: []const u8 = "",

    /// Additional information about the model's format and family.
    details: ModelDetails = .{},

    /// Time when the model will be unloaded.
    expires_at: ?[]const u8 = null,

    /// VRAM usage in bytes.
    size_vram: u64 = 0,

    /// Model capabilities.
    capabilities: ?[]const []const u8 = null,
};

/// Response from a show request.
pub const ShowResponse = struct {
    /// The model license.
    license: []const u8 = "",

    /// The Modelfile contents.
    modelfile: []const u8 = "",

    /// The model parameters.
    parameters: []const u8 = "",

    /// The prompt template.
    template: []const u8 = "",

    /// The system message.
    system: []const u8 = "",

    /// Additional information about the model's format and family.
    details: ModelDetails = .{},

    /// Messages used to create the model.
    messages: ?[]Message = null,

    /// Last modified timestamp in ISO 8601 format.
    modified_at: []const u8 = "",

    /// Model information.
    model_info: ?std.json.Value = null,

    /// Model capabilities.
    capabilities: ?[]const []const u8 = null,

    /// Projector information.
    projector_info: ?std.json.Value = null,
};

/// Response from an embed request.
pub const EmbedResponse = struct {
    /// The model that generated the embeddings.
    model: []const u8 = "",

    /// The embeddings, one vector per input.
    embeddings: [][]f32 = &.{},

    /// Time spent generating the response in nanoseconds.
    total_duration: ?u64 = null,

    /// Time spent loading the model in nanoseconds.
    load_duration: ?u64 = null,

    /// Number of tokens in the prompt.
    prompt_eval_count: ?u32 = null,
};

/// Response from an embeddings request.
pub const EmbeddingsResponse = struct {
    /// The embedding vector.
    embedding: []f32 = &.{},
};

/// Response listing available models.
pub const ListResponse = struct {
    /// List of available models.
    models: []ModelResponse = &.{},
};

/// Response containing the Ollama server version.
pub const VersionResponse = struct {
    /// Version of Ollama.
    version: []const u8 = "",
};

/// Error response from the server.
pub const ErrorResponse = struct {
    /// The error message.
    @"error": []const u8 = "",
};

/// A simple status response.
pub const StatusResponse = struct {
    /// The status (e.g. `success`).
    status: []const u8 = "",
};

/// Request to perform a web search.
pub const WebSearchRequest = struct {
    /// The search query.
    query: []const u8,

    /// Maximum number of results to return.
    maxResults: ?u32 = null,
};

/// A single web search result.
pub const WebSearchResult = struct {
    /// The content of the result.
    content: []const u8 = "",
};

/// Response from a web search request.
pub const WebSearchResponse = struct {
    /// The search results.
    results: []WebSearchResult = &.{},
};

/// Request to fetch a single web page.
pub const WebFetchRequest = struct {
    /// The URL to fetch.
    url: []const u8,
};

/// Response from a web fetch request.
pub const WebFetchResponse = struct {
    /// The page title.
    title: []const u8 = "",

    /// The page URL.
    url: []const u8 = "",

    /// The page content.
    content: []const u8 = "",

    /// Links found on the page.
    links: []const []const u8 = &.{},
};
