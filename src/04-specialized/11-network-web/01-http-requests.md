# Recipe 11.1: Making HTTP Requests

## Problem

You want to make HTTP requests in Zig, similar to Python's `requests` library. You need to construct requests with headers, parse responses, handle errors, and implement retry logic.

## Solution

Zig provides `std.http.Client` for production use, but understanding the underlying patterns helps you build robust HTTP clients. This recipe demonstrates the structure and API design for HTTP clients without external dependencies.

### Basic HTTP Client

Create a simple HTTP client wrapper:

```zig
{{#include ../../../code/04-specialized/11-network-web/recipe_11_1.zig:http_client_basic}}
```

Usage:

```zig
var client = HttpClient.init(testing.allocator);
defer client.deinit();
```

### Request Options

Define request configuration with HTTP methods:

```zig
{{#include ../../../code/04-specialized/11-network-web/recipe_11_1.zig:request_options}}
```

Example:

```zig
const opts = RequestOptions{
    .method = .POST,
    .body = "test data",
    .timeout_ms = 5000,
};

try testing.expectEqualStrings("POST", opts.method.toString());
```

### Response Structure

Handle HTTP responses with status helpers:

```zig
pub const Response = struct {
    status: u16,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        status: u16,
        body: []const u8,
    ) !Response {
        return .{
            .status = status,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = try allocator.dupe(u8, body),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Response) void {
        var it = self.headers.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();
        self.allocator.free(self.body);
    }

    pub fn isSuccess(self: Response) bool {
        return self.status >= 200 and self.status < 300;
    }

    pub fn isRedirect(self: Response) bool {
        return self.status >= 300 and self.status < 400;
    }

    pub fn isClientError(self: Response) bool {
        return self.status >= 400 and self.status < 500;
    }

    pub fn isServerError(self: Response) bool {
        return self.status >= 500 and self.status < 600;
    }
};
```

Status checking examples:

```zig
var resp = try Response.init(testing.allocator, 200, "OK");
defer resp.deinit();

try testing.expect(resp.isSuccess());
try testing.expect(!resp.isClientError());

var resp_404 = try Response.init(testing.allocator, 404, "Not Found");
defer resp_404.deinit();

try testing.expect(resp_404.isClientError());
```

## Discussion

### Python vs Zig HTTP Clients

The approaches differ in philosophy and control:

**Python (requests library):**
```python
import requests

# Simple GET request
response = requests.get('https://api.example.com/users')
print(response.status_code)
print(response.json())

# POST with headers
response = requests.post(
    'https://api.example.com/users',
    json={'name': 'Alice'},
    headers={'Authorization': 'Bearer token'},
    timeout=5
)
```

**Zig (explicit control):**
```zig
var client = HttpClient.init(allocator);
defer client.deinit();

var builder = RequestBuilder.init(allocator, "https://api.example.com/users");
defer builder.deinit();

_ = builder.method(.POST);
_ = builder.body("{\"name\":\"Alice\"}");
_ = try builder.header("Authorization", "Bearer token");
_ = builder.timeout(5000);
```

Key differences:
- **Explicitness**: Zig makes all operations visible; Python hides complexity
- **Memory**: Zig requires explicit allocator management; Python uses GC
- **Errors**: Zig uses error unions; Python uses exceptions
- **Dependencies**: Zig can use stdlib; Python typically requires external packages
- **Performance**: Zig compiles to native code; Python interprets

### URL Parsing

Parse URLs into components:

```zig
pub const Url = struct {
    scheme: []const u8,
    host: []const u8,
    port: ?u16,
    path: []const u8,
    query: ?[]const u8,
    fragment: ?[]const u8,

    /// Parses a URL string into components.
    /// Note: Returned Url contains slices into the input string.
    /// The input `url` must remain valid for the lifetime of the returned Url.
    pub fn parse(allocator: std.mem.Allocator, url: []const u8) !Url {
        // Implementation details...
    }
};
```

Usage:

```zig
const url1 = try Url.parse(testing.allocator, "https://example.com/path");
try testing.expectEqualStrings("https", url1.scheme);
try testing.expectEqualStrings("example.com", url1.host);
try testing.expectEqualStrings("/path", url1.path);

const url2 = try Url.parse(testing.allocator, "http://localhost:8080/api");
try testing.expectEqualStrings("http", url2.scheme);
try testing.expectEqual(@as(u16, 8080), url2.port.?);
```

**Important:** The returned `Url` contains slices into the input string, so the input must remain valid for the lifetime of the `Url`. This avoids allocation but creates a lifetime dependency.

### Header Builder Pattern

Build headers with a fluent API:

```zig
pub const HeaderBuilder = struct {
    headers: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) HeaderBuilder {
        return .{
            .headers = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *HeaderBuilder) void {
        var it = self.headers.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();
    }

    pub fn set(self: *HeaderBuilder, name: []const u8, value: []const u8) !void {
        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);

        // Use getOrPut to avoid leaking keys when updating existing headers
        const gop = try self.headers.getOrPut(name);

        if (gop.found_existing) {
            // Free old value and update with new value
            self.allocator.free(gop.value_ptr.*);
            gop.value_ptr.* = owned_value;
        } else {
            // New entry - need to own the key
            const owned_name = try self.allocator.dupe(u8, name);
            errdefer self.allocator.free(owned_name);

            gop.key_ptr.* = owned_name;
            gop.value_ptr.* = owned_value;
        }
    }

    pub fn setUserAgent(self: *HeaderBuilder, agent: []const u8) !void {
        try self.set("User-Agent", agent);
    }

    pub fn setContentType(self: *HeaderBuilder, content_type: []const u8) !void {
        try self.set("Content-Type", content_type);
    }
};
```

The `set` method uses `getOrPut` to avoid memory leaks when updating existing headers. This is a critical pattern for managing HashMap entries where both keys and values are owned strings.

Usage:

```zig
var builder = HeaderBuilder.init(testing.allocator);
defer builder.deinit();

try builder.setUserAgent("Zig HTTP Client/1.0");
try builder.setContentType("application/json");
try builder.set("X-Custom-Header", "custom-value");

const headers = builder.build();
const user_agent = headers.get("User-Agent");
try testing.expectEqualStrings("Zig HTTP Client/1.0", user_agent.?);
```

### Request Builder Pattern

Chain request configuration methods:

```zig
pub const RequestBuilder = struct {
    url: []const u8,
    options: RequestOptions,
    headers: HeaderBuilder,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, url: []const u8) RequestBuilder {
        return .{
            .url = url,
            .options = .{},
            .headers = HeaderBuilder.init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RequestBuilder) void {
        self.headers.deinit();
    }

    pub fn method(self: *RequestBuilder, m: RequestOptions.Method) *RequestBuilder {
        self.options.method = m;
        return self;
    }

    pub fn body(self: *RequestBuilder, data: []const u8) *RequestBuilder {
        self.options.body = data;
        return self;
    }

    pub fn header(self: *RequestBuilder, name: []const u8, value: []const u8) !*RequestBuilder {
        try self.headers.set(name, value);
        return self;
    }

    pub fn timeout(self: *RequestBuilder, ms: u32) *RequestBuilder {
        self.options.timeout_ms = ms;
        return self;
    }
};
```

Fluent API usage:

```zig
var builder = RequestBuilder.init(testing.allocator, "https://example.com/api");
defer builder.deinit();

_ = builder.method(.POST);
_ = builder.body("{\"key\":\"value\"}");
_ = try builder.header("Content-Type", "application/json");
_ = builder.timeout(5000);
```

### JSON Request Helpers

Convenience functions for JSON APIs:

```zig
pub const JsonRequest = struct {
    pub fn post(
        allocator: std.mem.Allocator,
        url: []const u8,
        json_data: []const u8,
    ) !RequestBuilder {
        var builder = RequestBuilder.init(allocator, url);
        _ = builder.method(.POST);
        _ = builder.body(json_data);
        _ = try builder.header("Content-Type", "application/json");
        return builder;
    }

    pub fn get(
        allocator: std.mem.Allocator,
        url: []const u8,
    ) !RequestBuilder {
        var builder = RequestBuilder.init(allocator, url);
        _ = builder.method(.GET);
        _ = try builder.header("Accept", "application/json");
        return builder;
    }
};
```

Usage:

```zig
var post_req = try JsonRequest.post(
    testing.allocator,
    "https://api.example.com/users",
    "{\"name\":\"Alice\"}",
);
defer post_req.deinit();

var get_req = try JsonRequest.get(testing.allocator, "https://api.example.com/users/1");
defer get_req.deinit();
```

### Error Handling

Define specific HTTP errors:

```zig
pub const HttpError = error{
    ConnectionFailed,
    Timeout,
    InvalidUrl,
    TooManyRedirects,
    InvalidResponse,
    RequestCancelled,
    DnsResolutionFailed,
    SslError,
};

pub const ErrorInfo = struct {
    error_code: HttpError,
    message: []const u8,
    url: ?[]const u8 = null,

    pub fn init(err: HttpError, message: []const u8) ErrorInfo {
        return .{
            .error_code = err,
            .message = message,
        };
    }
};
```

Example:

```zig
const err_info = ErrorInfo.init(HttpError.Timeout, "Request timed out after 5000ms");
try testing.expectEqual(HttpError.Timeout, err_info.error_code);
```

### Retry Policy with Exponential Backoff

Implement automatic retries for transient failures:

```zig
pub const RetryPolicy = struct {
    max_retries: u32 = 3,
    retry_delay_ms: u32 = 1000,
    backoff_multiplier: f32 = 2.0,
    retry_on_timeout: bool = true,
    retry_on_connection_error: bool = true,

    pub fn shouldRetry(self: RetryPolicy, attempt: u32, err: HttpError) bool {
        if (attempt >= self.max_retries) return false;

        return switch (err) {
            HttpError.Timeout => self.retry_on_timeout,
            HttpError.ConnectionFailed, HttpError.DnsResolutionFailed => self.retry_on_connection_error,
            else => false,
        };
    }

    pub fn getDelay(self: RetryPolicy, attempt: u32) u32 {
        const base_delay: f32 = @floatFromInt(self.retry_delay_ms);
        const multiplier = std.math.pow(f32, self.backoff_multiplier,
                                       @as(f32, @floatFromInt(attempt)));
        const delay = base_delay * multiplier;

        // Cap at max u32 value to prevent overflow
        const max_delay: f32 = @floatFromInt(std.math.maxInt(u32));
        return @intFromFloat(@min(delay, max_delay));
    }
};
```

The retry delay follows exponential backoff:
- Attempt 0: 1000ms
- Attempt 1: 2000ms (1000 * 2^1)
- Attempt 2: 4000ms (1000 * 2^2)
- Attempt 3: 8000ms (1000 * 2^3)

Usage:

```zig
const policy = RetryPolicy{};

try testing.expect(policy.shouldRetry(0, HttpError.Timeout));
try testing.expect(policy.shouldRetry(1, HttpError.ConnectionFailed));
try testing.expect(!policy.shouldRetry(3, HttpError.Timeout)); // Exceeds max retries

try testing.expectEqual(@as(u32, 1000), policy.getDelay(0));
try testing.expectEqual(@as(u32, 2000), policy.getDelay(1));
try testing.expectEqual(@as(u32, 4000), policy.getDelay(2));
```

### Content Type Negotiation

Handle MIME types:

```zig
pub const ContentType = enum {
    json,
    xml,
    html,
    text,
    form_urlencoded,
    multipart_form,
    octet_stream,

    pub fn toString(self: ContentType) []const u8 {
        return switch (self) {
            .json => "application/json",
            .xml => "application/xml",
            .html => "text/html",
            .text => "text/plain",
            .form_urlencoded => "application/x-www-form-urlencoded",
            .multipart_form => "multipart/form-data",
            .octet_stream => "application/octet-stream",
        };
    }

    pub fn fromString(s: []const u8) ?ContentType {
        if (std.mem.eql(u8, s, "application/json")) return .json;
        if (std.mem.eql(u8, s, "application/xml")) return .xml;
        if (std.mem.eql(u8, s, "text/html")) return .html;
        if (std.mem.eql(u8, s, "text/plain")) return .text;
        if (std.mem.eql(u8, s, "application/x-www-form-urlencoded")) return .form_urlencoded;
        if (std.mem.eql(u8, s, "multipart/form-data")) return .multipart_form;
        if (std.mem.eql(u8, s, "application/octet-stream")) return .octet_stream;
        return null;
    }
};
```

Usage:

```zig
const json_type = ContentType.json;
try testing.expectEqualStrings("application/json", json_type.toString());

const parsed = ContentType.fromString("application/json");
try testing.expectEqual(ContentType.json, parsed.?);
```

## Best Practices

1. **Use std.http.Client for Production**: The patterns shown here are educational; use `std.http.Client` for actual HTTP requests
2. **Explicit Allocator Management**: Always pass allocators explicitly and track ownership
3. **Error Handling**: Use explicit error sets for different failure modes
4. **Resource Cleanup**: Use `defer` and `errdefer` to ensure cleanup
5. **Retry Logic**: Implement exponential backoff to avoid overwhelming servers
6. **Header Management**: Use `getOrPut` pattern to avoid memory leaks when updating HashMap entries
7. **Lifetime Dependencies**: Document when returned data contains slices into input parameters
8. **Builder Pattern**: Chain configuration methods for better API ergonomics
9. **Status Helpers**: Provide convenience methods for common status code checks
10. **Overflow Protection**: Cap calculations that could overflow (like retry delays)

## Common Patterns

**Complete Request Example:**
```zig
var client = HttpClient.init(allocator);
defer client.deinit();

var builder = RequestBuilder.init(allocator, "https://api.example.com/users");
defer builder.deinit();

_ = builder.method(.POST);
_ = builder.body("{\"name\":\"Alice\"}");
_ = try builder.header("Content-Type", "application/json");
_ = try builder.header("Authorization", "Bearer token123");
_ = builder.timeout(5000);

const url = try Url.parse(allocator, builder.url);
// Make request (requires actual network code)...
```

**Retry Loop:**
```zig
const policy = RetryPolicy{};
var attempt: u32 = 0;

while (attempt < policy.max_retries) : (attempt += 1) {
    const result = makeRequest() catch |err| {
        if (policy.shouldRetry(attempt, err)) {
            const delay = policy.getDelay(attempt);
            std.time.sleep(delay * std.time.ns_per_ms);
            continue;
        }
        return err;
    };
    break; // Success
}
```

**Response Status Handling:**
```zig
var response = try Response.init(allocator, status_code, body);
defer response.deinit();

if (response.isSuccess()) {
    // Handle 2xx
} else if (response.isClientError()) {
    // Handle 4xx
} else if (response.isServerError()) {
    // Handle 5xx
} else if (response.isRedirect()) {
    // Handle 3xx
}
```

## Troubleshooting

**Memory Leaks in HeaderBuilder:**
- Always use `getOrPut` when updating HashMap entries
- Free both keys and values when the entry already exists
- Use `errdefer` to clean up on allocation failures

**Lifetime Issues with Url:**
- Remember that `Url.parse()` returns slices into the input string
- Keep the original URL string alive as long as the `Url` is used
- Consider duplicating strings if ownership transfer is needed

**Retry Logic Not Working:**
- Check that attempt counter is incremented correctly
- Verify error types match those in `shouldRetry()`
- Ensure delay calculation doesn't overflow (use `@min` to cap)

**Builder Pattern Awkwardness:**
- Use `_` to ignore return values when chaining isn't needed
- Or assign to a variable and use method chaining
- Error-returning methods break the chain (use `try`)

## See Also

- Recipe 11.2: Working with JSON APIs - JSON parsing and serialization
- Recipe 11.3: WebSocket Communication - Real-time bidirectional communication
- Recipe 14.1: Writing Unit Tests - Testing HTTP client code
- Recipe 15.1: Calling C Libraries - Integrating with C HTTP libraries like libcurl

Full compilable example: `code/04-specialized/11-network-web/recipe_11_1.zig`
