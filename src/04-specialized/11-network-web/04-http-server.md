# Recipe 11.4: Building a Simple HTTP Server

## Problem

You want to build an HTTP server in Zig - parsing requests, routing to handlers, generating responses, and implementing middleware patterns. You need to understand HTTP server fundamentals without the complexity of actual network programming.

## Solution

This recipe demonstrates HTTP server patterns using pure Zig structures and logic. While production servers use `std.http.Server` or frameworks, understanding these patterns helps you work with any HTTP library.

### HTTP Methods

Define supported HTTP methods:

```zig
{{#include ../../../code/04-specialized/11-network-web/recipe_11_4.zig:http_method}}
```

Usage:

```zig
try testing.expectEqual(HttpMethod.GET, HttpMethod.fromString("GET").?);
try testing.expectEqualStrings("POST", HttpMethod.POST.toString());
```

### HTTP Status Codes

Standard HTTP status codes with descriptions:

```zig
{{#include ../../../code/04-specialized/11-network-web/recipe_11_4.zig:http_status}}
```

Status code examples:

```zig
try testing.expectEqual(@as(u16, 200), @intFromEnum(HttpStatus.ok));
try testing.expectEqual(@as(u16, 404), @intFromEnum(HttpStatus.not_found));
try testing.expectEqualStrings("OK", HttpStatus.ok.toText());
```

## Discussion

### Python vs Zig HTTP Servers

The implementation philosophies differ:

**Python (Flask/FastAPI):**
```python
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/api/users', methods=['GET'])
def get_users():
    return jsonify({"users": ["Alice", "Bob"]})

@app.route('/api/users', methods=['POST'])
def create_user():
    data = request.json
    return jsonify({"id": 123, "name": data["name"]}), 201

if __name__ == '__main__':
    app.run(port=8080)
```

**Zig (Pattern-based):**
```zig
var router = Router.init(allocator);
defer router.deinit();

try router.add(.GET, "/api/users", getUsersHandler);
try router.add(.POST, "/api/users", createUserHandler);

// In handler:
fn getUsersHandler(request: *const HttpRequest, allocator: Allocator) !HttpResponse {
    return try jsonResponse(allocator, .ok, "{\"users\":[\"Alice\",\"Bob\"]}");
}
```

Key differences:
- **Magic vs Explicit**: Python uses decorators; Zig uses explicit registration
- **Serialization**: Python auto-converts; Zig requires manual JSON handling
- **Memory**: Python GC handles cleanup; Zig requires explicit `defer`
- **Type Safety**: Zig catches routing errors at compile time
- **Performance**: Zig has zero overhead; Python has interpreter costs
- **Control**: Zig exposes full request/response lifecycle

### HTTP Request Parsing

Parse raw HTTP requests into structured data:

```zig
pub const HttpRequest = struct {
    method: HttpMethod,
    path: []const u8,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    allocator: std.mem.Allocator,

    pub fn parse(allocator: std.mem.Allocator, raw: []const u8) !HttpRequest {
        var request = HttpRequest.init(allocator);
        errdefer request.deinit();

        var lines = std.mem.splitScalar(u8, raw, '\n');

        // Parse request line
        if (lines.next()) |request_line| {
            var parts = std.mem.splitScalar(u8, request_line, ' ');

            if (parts.next()) |method_str| {
                const method_trimmed = std.mem.trim(u8, method_str, &std.ascii.whitespace);
                request.method = HttpMethod.fromString(method_trimmed) orelse .GET;
            }

            if (parts.next()) |path_str| {
                request.path = std.mem.trim(u8, path_str, &std.ascii.whitespace);
            }
        }

        // Parse headers
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
            if (trimmed.len == 0) break; // Empty line separates headers from body

            if (std.mem.indexOf(u8, trimmed, ":")) |colon_idx| {
                const name = std.mem.trim(u8, trimmed[0..colon_idx], &std.ascii.whitespace);
                const value = std.mem.trim(u8, trimmed[colon_idx + 1 ..], &std.ascii.whitespace);

                const owned_name = try allocator.dupe(u8, name);
                errdefer allocator.free(owned_name);
                const owned_value = try allocator.dupe(u8, value);
                errdefer allocator.free(owned_value);

                try request.headers.put(owned_name, owned_value);
            }
        }

        // Remaining is body
        // (Real implementation would use Content-Length header)

        return request;
    }

    pub fn getHeader(self: HttpRequest, name: []const u8) ?[]const u8 {
        return self.headers.get(name);
    }
};
```

Parsing example:

```zig
const raw_request =
    \\GET /api/users HTTP/1.1
    \\Host: example.com
    \\Content-Type: application/json
    \\
    \\{"name": "Alice"}
;

var request = try HttpRequest.parse(testing.allocator, raw_request);
defer request.deinit();

try testing.expectEqual(HttpMethod.GET, request.method);
try testing.expectEqualStrings("/api/users", request.path);

const host = request.getHeader("Host");
try testing.expectEqualStrings("example.com", host.?);
```

**Important**: Always `defer request.deinit()` to free allocated headers.

### HTTP Response Building

Construct HTTP responses programmatically:

```zig
pub const HttpResponse = struct {
    status: HttpStatus,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, status: HttpStatus) HttpResponse {
        return .{
            .status = status,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = "",
            .allocator = allocator,
        };
    }

    pub fn setHeader(self: *HttpResponse, name: []const u8, value: []const u8) !void {
        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);

        // Use getOrPut to avoid leaking keys when updating
        const gop = try self.headers.getOrPut(name);
        if (gop.found_existing) {
            self.allocator.free(gop.value_ptr.*);
            gop.value_ptr.* = owned_value;
        } else {
            const owned_name = try self.allocator.dupe(u8, name);
            gop.key_ptr.* = owned_name;
            gop.value_ptr.* = owned_value;
        }
    }

    pub fn setBody(self: *HttpResponse, body: []const u8) void {
        self.body = body;
    }

    pub fn build(self: HttpResponse, allocator: std.mem.Allocator) ![]u8 {
        var result = std.ArrayList(u8){};
        errdefer result.deinit(allocator);

        const writer = result.writer(allocator);

        // Status line
        try writer.print("HTTP/1.1 {d} {s}\r\n", .{
            @intFromEnum(self.status),
            self.status.toText(),
        });

        // Headers
        var it = self.headers.iterator();
        while (it.next()) |entry| {
            try writer.print("{s}: {s}\r\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }

        // Empty line separates headers from body
        try writer.writeAll("\r\n");

        // Body
        try writer.writeAll(self.body);

        return result.toOwnedSlice(allocator);
    }
};
```

Building a response:

```zig
var response = HttpResponse.init(testing.allocator, .ok);
defer response.deinit();

try response.setHeader("Content-Type", "text/plain");
response.setBody("Hello, World!");

const raw = try response.build(testing.allocator);
defer testing.allocator.free(raw);

// Verify response format
try testing.expect(std.mem.indexOf(u8, raw, "HTTP/1.1 200 OK") != null);
try testing.expect(std.mem.indexOf(u8, raw, "Content-Type: text/plain") != null);
try testing.expect(std.mem.indexOf(u8, raw, "Hello, World!") != null);
```

### Routing

Map URLs to handler functions:

```zig
pub const Handler = *const fn (request: *const HttpRequest, allocator: std.mem.Allocator) anyerror!HttpResponse;

pub const Route = struct {
    method: HttpMethod,
    path: []const u8,
    handler: Handler,

    pub fn matches(self: Route, method: HttpMethod, path: []const u8) bool {
        return self.method == method and std.mem.eql(u8, self.path, path);
    }
};

pub const Router = struct {
    routes: std.ArrayList(Route),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Router {
        return .{
            .routes = std.ArrayList(Route){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Router) void {
        self.routes.deinit(self.allocator);
    }

    pub fn add(self: *Router, method: HttpMethod, path: []const u8, handler: Handler) !void {
        try self.routes.append(self.allocator, .{
            .method = method,
            .path = path,
            .handler = handler,
        });
    }

    pub fn handle(self: Router, request: *const HttpRequest) !HttpResponse {
        for (self.routes.items) |route| {
            if (route.matches(request.method, request.path)) {
                return try route.handler(request, self.allocator);
            }
        }

        // No route matched - return 404
        var response = HttpResponse.init(self.allocator, .not_found);
        response.setBody("Not Found");
        return response;
    }
};
```

Using the router:

```zig
fn getUsersHandler(request: *const HttpRequest, allocator: Allocator) !HttpResponse {
    _ = request;
    var response = HttpResponse.init(allocator, .ok);
    response.setBody("Users list");
    return response;
}

var router = Router.init(testing.allocator);
defer router.deinit();

try router.add(.GET, "/api/users", getUsersHandler);

var request = HttpRequest.init(testing.allocator);
defer request.deinit();
request.method = .GET;
request.path = "/api/users";

var response = try router.handle(&request);
defer response.deinit();

try testing.expectEqual(HttpStatus.ok, response.status);
```

The router automatically returns `404 Not Found` for unmatched routes.

### Middleware Pattern

Chain request processing with middleware:

```zig
pub const Middleware = *const fn (request: *HttpRequest, next: Handler) anyerror!HttpResponse;

pub const MiddlewareChain = struct {
    middlewares: std.ArrayList(Middleware),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) MiddlewareChain {
        return .{
            .middlewares = std.ArrayList(Middleware){},
            .allocator = allocator,
        };
    }

    pub fn use(self: *MiddlewareChain, middleware: Middleware) !void {
        try self.middlewares.append(self.allocator, middleware);
    }
};

// Example: Logging middleware
fn loggingMiddleware(request: *HttpRequest, next: Handler) !HttpResponse {
    // Log request
    std.debug.print("Request: {s} {s}\n", .{
        request.method.toString(),
        request.path,
    });

    // Call next handler
    var response = try next(request, request.allocator);

    // Log response
    std.debug.print("Response: {d}\n", .{@intFromEnum(response.status)});

    return response;
}
```

Middleware allows cross-cutting concerns like logging, authentication, and CORS without modifying handlers.

### Content Type Detection

Determine MIME types from file extensions:

```zig
pub const ContentType = enum {
    text_html,
    text_plain,
    application_json,
    application_xml,
    image_png,
    image_jpeg,
    application_octet_stream,

    pub fn fromExtension(ext: []const u8) ContentType {
        if (std.mem.eql(u8, ext, ".html")) return .text_html;
        if (std.mem.eql(u8, ext, ".txt")) return .text_plain;
        if (std.mem.eql(u8, ext, ".json")) return .application_json;
        if (std.mem.eql(u8, ext, ".xml")) return .application_xml;
        if (std.mem.eql(u8, ext, ".png")) return .image_png;
        if (std.mem.eql(u8, ext, ".jpg") or std.mem.eql(u8, ext, ".jpeg")) return .image_jpeg;
        return .application_octet_stream;
    }

    pub fn toString(self: ContentType) []const u8 {
        return switch (self) {
            .text_html => "text/html",
            .text_plain => "text/plain",
            .application_json => "application/json",
            // ...
        };
    }
};
```

Usage:

```zig
const html_type = ContentType.fromExtension(".html");
try testing.expectEqual(ContentType.text_html, html_type);
try testing.expectEqualStrings("text/html", html_type.toString());
```

### Static File Serving

Serve static files with proper content types:

```zig
pub const StaticFileHandler = struct {
    root_dir: []const u8,

    pub fn init(root_dir: []const u8) StaticFileHandler {
        return .{ .root_dir = root_dir };
    }

    pub fn serve(self: StaticFileHandler, path: []const u8, allocator: std.mem.Allocator) !HttpResponse {
        _ = self;

        // In real implementation: read file from root_dir + path
        var response = HttpResponse.init(allocator, .ok);

        // Detect content type from extension
        const ext = std.fs.path.extension(path);
        const content_type = ContentType.fromExtension(ext);
        try response.setHeader("Content-Type", content_type.toString());

        response.setBody("File content here");

        return response;
    }
};
```

Example:

```zig
const handler = StaticFileHandler.init("/var/www");

var response = try handler.serve("/index.html", testing.allocator);
defer response.deinit();

const content_type = response.headers.get("Content-Type");
try testing.expectEqualStrings("text/html", content_type.?);
```

### Query Parameters

Parse URL query strings:

```zig
pub const QueryParams = struct {
    params: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn parse(allocator: std.mem.Allocator, query_string: []const u8) !QueryParams {
        var result = QueryParams.init(allocator);
        errdefer result.deinit();

        var pairs = std.mem.splitScalar(u8, query_string, '&');
        while (pairs.next()) |pair| {
            if (std.mem.indexOf(u8, pair, "=")) |eq_idx| {
                const key = pair[0..eq_idx];
                const value = pair[eq_idx + 1 ..];

                const owned_key = try allocator.dupe(u8, key);
                errdefer allocator.free(owned_key);
                const owned_value = try allocator.dupe(u8, value);
                errdefer allocator.free(owned_value);

                try result.params.put(owned_key, owned_value);
            }
        }

        return result;
    }

    pub fn get(self: QueryParams, key: []const u8) ?[]const u8 {
        return self.params.get(key);
    }
};
```

Parsing example:

```zig
var params = try QueryParams.parse(testing.allocator, "name=Alice&age=30");
defer params.deinit();

try testing.expectEqualStrings("Alice", params.get("name").?);
try testing.expectEqualStrings("30", params.get("age").?);
```

### JSON Response Helper

Convenience function for JSON responses:

```zig
pub fn jsonResponse(allocator: std.mem.Allocator, status: HttpStatus, json_data: []const u8) !HttpResponse {
    var response = HttpResponse.init(allocator, status);
    errdefer response.deinit();

    try response.setHeader("Content-Type", "application/json");
    response.setBody(json_data);

    return response;
}
```

Usage:

```zig
var response = try jsonResponse(testing.allocator, .ok, "{\"message\":\"Success\"}");
defer response.deinit();

const content_type = response.headers.get("Content-Type");
try testing.expectEqualStrings("application/json", content_type.?);
```

## Best Practices

1. **Always Defer Cleanup**: Use `defer request.deinit()` and `defer response.deinit()`
2. **Use getOrPut for Maps**: Prevents memory leaks when updating existing keys
3. **Validate Input**: Check method strings, header formats, and body sizes
4. **Set Content-Type**: Always specify content type in responses
5. **Handle 404**: Routers should return `404 Not Found` for unmatched routes
6. **Use errdefer**: Clean up allocations on error paths
7. **Explicit Ownership**: Document whether body/header values are borrowed or owned
8. **Route Registration Order**: More specific routes before generic ones
9. **Middleware Ordering**: Authentication before authorization, logging first/last
10. **Status Code Accuracy**: Use correct HTTP status codes for each situation

## Common Patterns

**REST API Handler:**
```zig
fn getUserHandler(request: *const HttpRequest, allocator: Allocator) !HttpResponse {
    // Extract user ID from path (e.g., /users/123)
    const path_parts = std.mem.split(u8, request.path, "/");
    // ... parse ID ...

    // Query database (mocked here)
    const user_json = "{\"id\":123,\"name\":\"Alice\"}";

    return try jsonResponse(allocator, .ok, user_json);
}

fn createUserHandler(request: *const HttpRequest, allocator: Allocator) !HttpResponse {
    // Parse JSON from request body
    // ... validation ...

    // Create user in database (mocked)
    const new_user = "{\"id\":124,\"name\":\"Bob\"}";

    var response = try jsonResponse(allocator, .created, new_user);
    try response.setHeader("Location", "/users/124");

    return response;
}
```

**Complete Server Setup:**
```zig
var router = Router.init(allocator);
defer router.deinit();

// Register routes
try router.add(.GET, "/api/users", getUsersHandler);
try router.add(.POST, "/api/users", createUserHandler);
try router.add(.GET, "/api/users/:id", getUserHandler);
try router.add(.DELETE, "/api/users/:id", deleteUserHandler);

// Handle request
var request = try HttpRequest.parse(allocator, raw_request);
defer request.deinit();

var response = try router.handle(&request);
defer response.deinit();

const raw_response = try response.build(allocator);
defer allocator.free(raw_response);

// Send raw_response over network...
```

**Error Handling:**
```zig
fn apiHandler(request: *const HttpRequest, allocator: Allocator) !HttpResponse {
    const result = processRequest(request) catch |err| {
        const error_json = switch (err) {
            error.InvalidInput => "{\"error\":\"Invalid input\"}",
            error.NotFound => "{\"error\":\"Resource not found\"}",
            else => "{\"error\":\"Internal server error\"}",
        };

        const status: HttpStatus = switch (err) {
            error.InvalidInput => .bad_request,
            error.NotFound => .not_found,
            else => .internal_server_error,
        };

        return try jsonResponse(allocator, status, error_json);
    };

    return try jsonResponse(allocator, .ok, result);
}
```

## Troubleshooting

**Memory Leaks:**
- Always `defer deinit()` for requests, responses, routers, query params
- Use `testing.allocator` in tests to catch leaks
- Check that `setHeader()` frees old values when updating

**Header Not Found:**
- Headers are case-sensitive in this implementation
- Check header name spelling exactly matches
- Verify header was set before calling `build()`

**404 for Valid Route:**
- Check route path matches exactly (including trailing slashes)
- Verify HTTP method matches route registration
- Routes are checked in order - ensure no earlier route shadows

**Request Body Empty:**
- Production code should parse Content-Length header
- Check that blank line separates headers from body
- Body parsing is simplified in this educational example

**Response Not Formatted Correctly:**
- Ensure `\r\n` line endings (CRLF, not just `\n`)
- Blank line must separate headers from body
- Status line must be first line

## Production Considerations

For real HTTP servers, you need:

1. **Actual Networking**: Use `std.net` or `std.http.Server`
2. **Request Size Limits**: Prevent memory exhaustion
3. **Path Traversal Protection**: Validate file paths for static serving
4. **Header Injection Prevention**: Validate header values don't contain `\r\n`
5. **Timeouts**: Connection, read, and write timeouts
6. **Connection Pooling**: Reuse connections efficiently
7. **TLS/HTTPS**: Use secure connections in production
8. **Logging**: Structured logging with `std.log`
9. **Metrics**: Track requests, errors, latency
10. **Graceful Shutdown**: Close connections cleanly

## See Also

- Recipe 11.1: Making HTTP Requests - Client-side HTTP patterns
- Recipe 11.2: Working with JSON APIs - JSON serialization for APIs
- Recipe 11.3: WebSocket Communication - Upgrading HTTP to WebSocket
- Recipe 12.1: Async I/O Patterns - Handling concurrent connections

Full compilable example: `code/04-specialized/11-network-web/recipe_11_4.zig`
