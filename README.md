# ollama.zig

A Zig client for the [Ollama](https://ollama.com) API, modeled after
[ollama-js](https://github.com/ollama/ollama-js). Supports both buffered and
streaming responses.

Requires Zig `0.16.0`.

## Installation

```bash
zig fetch --save git+https://github.com/aw1875/ollama.zig
```

Then wire it up in `build.zig`:

```zig
const ollama = b.dependency("ollama", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("ollama", ollama.module("ollama"));
```

## Usage

`@import("ollama")` is the `Ollama` type. All request/response types are
re-exported as `pub const` fields on it.

```zig
const std = @import("std");
const Ollama = @import("ollama");

pub fn main(init: std.process.Init) !void {
    var o = Ollama.init(init.io, init.gpa, .{ .host = "http://localhost:11434" });
    defer o.deinit();

    // Non-streaming
    var res = try o.generate(.{
        .model = "llama3.2",
        .prompt = "why is the sky blue?",
        .stream = false,
    });
    defer res.deinit();
    const body = try res.body();
    std.debug.print("{s}\n", .{body.response});
}
```

### Streaming

Set `stream = true` and iterate the returned `ResponseStream`:

```zig
var res = try o.generate(.{
    .model = "llama3.2",
    .prompt = "why is the sky blue?",
    .stream = true,
});
defer res.deinit();

while (try res.next()) |chunk| {
    std.debug.print("{s}", .{chunk.response});
    if (chunk.done) break;
}
```

### Thinking models

Thinking output arrives in the `thinking` field, separate from `response`:

```zig
var res = try o.generate(.{
    .model = "qwen3",
    .prompt = "explain recursion",
    .stream = true,
    .think = .{ .bool = true },
});
defer res.deinit();

while (try res.next()) |chunk| {
    if (chunk.thinking) |t| std.debug.print("[think] {s}", .{t});
    if (chunk.response.len > 0) std.debug.print("{s}", .{chunk.response});
    if (chunk.done) break;
}
```

### Cloud (ollama.com)

Pass an API token via the `headers` config field:

```zig
const headers = [_]std.http.Header{
    .{ .name = "Authorization", .value = "Bearer <token>" },
};

var o = Ollama.init(init.io, init.gpa, .{ .host = "https://ollama.com", .headers = headers[0..] });
defer o.deinit();
```

## API

| Method | Endpoint | Returns |
| --- | --- | --- |
| `generate` | `/api/generate` | `ResponseStream(GenerateResponse)` |
| `chat` | `/api/chat` | `ResponseStream(ChatResponse)` |
| `create` | `/api/create` | `ResponseStream(ProgressResponse)` |
| `pull` | `/api/pull` | `ResponseStream(ProgressResponse)` |
| `push` | `/api/push` | `ResponseStream(ProgressResponse)` |
| `delete` | `/api/delete` | `Response(StatusResponse)` |
| `copy` | `/api/copy` | `Response(StatusResponse)` |
| `list` | `/api/tags` | `Response(ListResponse)` |
| `show` | `/api/show` | `Response(ShowResponse)` |
| `embed` | `/api/embed` | `Response(EmbedResponse)` |
| `embeddings` | `/api/embeddings` | `Response(EmbeddingsResponse)` |
| `ps` | `/api/ps` | `Response(ListResponse)` |
| `version` | `/api/version` | `Response(VersionResponse)` |
| `webSearch` | `ollama.com/api/web_search` | `Response(WebSearchResponse)` |
| `webFetch` | `ollama.com/api/web_fetch` | `Response(WebFetchResponse)` |

