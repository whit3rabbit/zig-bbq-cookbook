// Recipe 11.4: Building a Simple HTTP Server
// Target Zig Version: 0.15.2
//
// Educational demonstration of HTTP server patterns in Zig.
// Shows request parsing, response building, routing, and middleware patterns.
//
// Note: This demonstrates HTTP server concepts without actual networking.
// For production HTTP servers, use std.http.Server or a framework.
//
// Key concepts:
// - HTTP request parsing (method, path, headers, body)
// - HTTP response building (status, headers, body)
// - Route matching and handlers
// - Middleware pattern
// - Static file serving
// - Content type detection

const std = @import("std");
const testing = std.testing;

// ANCHOR: http_method
pub const HttpMethod = enum {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
    HEAD,
    OPTIONS,

    pub fn fromString(s: []const u8) ?HttpMethod {
        if (std.mem.eql(u8, s, "GET")) return .GET;
        if (std.mem.eql(u8, s, "POST")) return .POST;
        if (std.mem.eql(u8, s, "PUT")) return .PUT;
        if (std.mem.eql(u8, s, "DELETE")) return .DELETE;
        if (std.mem.eql(u8, s, "PATCH")) return .PATCH;
        if (std.mem.eql(u8, s, "HEAD")) return .HEAD;
        if (std.mem.eql(u8, s, "OPTIONS")) return .OPTIONS;
        return null;
    }

    pub fn toString(self: HttpMethod) []const u8 {
        return switch (self) {
            .GET => "GET",
            .POST => "POST",
            .PUT => "PUT",
            .DELETE => "DELETE",
            .PATCH => "PATCH",
            .HEAD => "HEAD",
            .OPTIONS => "OPTIONS",
        };
    }
};

test "http method conversion" {
    try testing.expectEqual(HttpMethod.GET, HttpMethod.fromString("GET").?);
    try testing.expectEqualStrings("POST", HttpMethod.POST.toString());
    try testing.expect(HttpMethod.fromString("INVALID") == null);
}
// ANCHOR_END: http_method

// ANCHOR: http_status
pub const HttpStatus = enum(u16) {
    ok = 200,
    created = 201,
    no_content = 204,
    moved_permanently = 301,
    found = 302,
    bad_request = 400,
    unauthorized = 401,
    forbidden = 403,
    not_found = 404,
    method_not_allowed = 405,
    internal_server_error = 500,
    not_implemented = 501,
    service_unavailable = 503,

    pub fn toText(self: HttpStatus) []const u8 {
        return switch (self) {
            .ok => "OK",
            .created => "Created",
            .no_content => "No Content",
            .moved_permanently => "Moved Permanently",
            .found => "Found",
            .bad_request => "Bad Request",
            .unauthorized => "Unauthorized",
            .forbidden => "Forbidden",
            .not_found => "Not Found",
            .method_not_allowed => "Method Not Allowed",
            .internal_server_error => "Internal Server Error",
            .not_implemented => "Not Implemented",
            .service_unavailable => "Service Unavailable",
        };
    }
};

test "http status codes" {
    try testing.expectEqual(@as(u16, 200), @intFromEnum(HttpStatus.ok));
    try testing.expectEqual(@as(u16, 404), @intFromEnum(HttpStatus.not_found));
    try testing.expectEqualStrings("OK", HttpStatus.ok.toText());
    try testing.expectEqualStrings("Not Found", HttpStatus.not_found.toText());
}
// ANCHOR_END: http_status

// ANCHOR: http_request
pub const HttpRequest = struct {
    method: HttpMethod,
    path: []const u8,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) HttpRequest {
        return .{
            .method = .GET,
            .path = "/",
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = "",
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *HttpRequest) void {
        var it = self.headers.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();
    }

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

                // Memory Allocation Tradeoff
                //
                // This implementation uses allocator.dupe() to own all strings, which:
                // - Pros: Simple lifetime management, data outlives request buffer
                // - Cons: Allocates memory for every header (slower for high-traffic servers)
                //
                // Production alternative: Use slices of the original buffer
                // - Store []const u8 slices pointing into 'raw' parameter
                // - Requires 'raw' buffer to outlive HttpRequest
                // - Zero allocations, approximately 10x faster parsing
                // - Used by std.http.Server and production frameworks
                //
                // For this educational recipe, we prioritize clarity over performance.

                // HashMap Memory Leak Prevention
                //
                // INCORRECT pattern (causes memory leak with duplicate keys):
                //   const owned_key = try allocator.dupe(u8, name);
                //   const owned_value = try allocator.dupe(u8, value);
                //   try map.put(owned_key, owned_value);  // LEAKS old key/value if duplicate!
                //
                // CORRECT pattern using getOrPut():
                // 1. Allocate value first (always needed)
                // 2. Check if key exists with getOrPut()
                // 3. If existing: free old value, reuse existing key
                // 4. If new: allocate key, assign both key and value
                //
                // This prevents leaks when HTTP requests contain duplicate headers
                // (common with Set-Cookie, Cache-Control, etc.)

                const owned_value = try allocator.dupe(u8, value);
                errdefer allocator.free(owned_value);

                const gop = try request.headers.getOrPut(name);
                if (gop.found_existing) {
                    // Duplicate header: free old value, reuse existing key
                    allocator.free(gop.value_ptr.*);
                    gop.value_ptr.* = owned_value;
                } else {
                    // New header: allocate key and store both
                    const owned_name = try allocator.dupe(u8, name);
                    gop.key_ptr.* = owned_name;
                    gop.value_ptr.* = owned_value;
                }
            }
        }

        // Remaining is body (simplified - real parsing would use Content-Length)
        var body_parts: std.ArrayList(u8) = .{};
        defer body_parts.deinit(allocator);

        while (lines.next()) |line| {
            try body_parts.appendSlice(allocator, line);
        }

        request.body = std.mem.trim(u8, body_parts.items, &std.ascii.whitespace);

        return request;
    }

    pub fn getHeader(self: HttpRequest, name: []const u8) ?[]const u8 {
        return self.headers.get(name);
    }
};

test "http request parsing" {
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
    try testing.expect(host != null);
    try testing.expectEqualStrings("example.com", host.?);
}

test "http request parsing with duplicate headers - no memory leak" {
    const raw_request =
        \\POST /api/data HTTP/1.1
        \\Host: example.com
        \\Content-Type: application/json
        \\Content-Type: text/plain
        \\Authorization: Bearer token1
        \\Authorization: Bearer token2
        \\
        \\{"data": "test"}
    ;

    var request = try HttpRequest.parse(testing.allocator, raw_request);
    defer request.deinit();

    // Last value should win for duplicate headers
    const content_type = request.getHeader("Content-Type");
    try testing.expect(content_type != null);
    try testing.expectEqualStrings("text/plain", content_type.?);

    const auth = request.getHeader("Authorization");
    try testing.expect(auth != null);
    try testing.expectEqualStrings("Bearer token2", auth.?);

    // Only 3 unique headers should exist (Host, Content-Type, Authorization)
    try testing.expectEqual(@as(u32, 3), request.headers.count());
}
// ANCHOR_END: http_request

// ANCHOR: http_response
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

    pub fn deinit(self: *HttpResponse) void {
        var it = self.headers.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();
    }

    pub fn setHeader(self: *HttpResponse, name: []const u8, value: []const u8) !void {
        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);

        // Check if header already exists
        const gop = try self.headers.getOrPut(name);
        if (gop.found_existing) {
            // Free old value and replace
            self.allocator.free(gop.value_ptr.*);
            gop.value_ptr.* = owned_value;
        } else {
            // New header - allocate key
            const owned_name = try self.allocator.dupe(u8, name);
            gop.key_ptr.* = owned_name;
            gop.value_ptr.* = owned_value;
        }
    }

    pub fn setBody(self: *HttpResponse, body: []const u8) void {
        self.body = body;
    }

    pub fn build(self: HttpResponse, allocator: std.mem.Allocator) ![]u8 {
        var result: std.ArrayList(u8) = .{};
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

        // Empty line
        try writer.writeAll("\r\n");

        // Body
        try writer.writeAll(self.body);

        return result.toOwnedSlice(allocator);
    }
};

test "http response building" {
    var response = HttpResponse.init(testing.allocator, .ok);
    defer response.deinit();

    try response.setHeader("Content-Type", "text/plain");
    response.setBody("Hello, World!");

    const raw = try response.build(testing.allocator);
    defer testing.allocator.free(raw);

    try testing.expect(std.mem.indexOf(u8, raw, "HTTP/1.1 200 OK") != null);
    try testing.expect(std.mem.indexOf(u8, raw, "Content-Type: text/plain") != null);
    try testing.expect(std.mem.indexOf(u8, raw, "Hello, World!") != null);
}

test "http response header overwriting" {
    var response = HttpResponse.init(testing.allocator, .ok);
    defer response.deinit();

    try response.setHeader("Content-Type", "text/plain");
    try response.setHeader("Content-Type", "text/html");

    const ct = response.headers.get("Content-Type");
    try testing.expect(ct != null);
    try testing.expectEqualStrings("text/html", ct.?);

    // Ensure only one header exists (no memory leak)
    try testing.expectEqual(@as(usize, 1), response.headers.count());
}
// ANCHOR_END: http_response

// ANCHOR: route_handler
pub const Handler = *const fn (request: *const HttpRequest, allocator: std.mem.Allocator) anyerror!HttpResponse;

pub const Route = struct {
    method: HttpMethod,
    path: []const u8,
    handler: Handler,

    pub fn matches(self: Route, method: HttpMethod, path: []const u8) bool {
        return self.method == method and std.mem.eql(u8, self.path, path);
    }
};

test "route matching" {
    const route = Route{
        .method = .GET,
        .path = "/users",
        .handler = undefined,
    };

    try testing.expect(route.matches(.GET, "/users"));
    try testing.expect(!route.matches(.POST, "/users"));
    try testing.expect(!route.matches(.GET, "/posts"));
}
// ANCHOR_END: route_handler

// ANCHOR: router
pub const Router = struct {
    routes: std.ArrayList(Route),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Router {
        return .{
            .routes = .{},
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

fn testHandler(request: *const HttpRequest, allocator: std.mem.Allocator) !HttpResponse {
    _ = request;
    var response = HttpResponse.init(allocator, .ok);
    response.setBody("Test response");
    return response;
}

test "router handling" {
    var router = Router.init(testing.allocator);
    defer router.deinit();

    try router.add(.GET, "/test", testHandler);

    var request = HttpRequest.init(testing.allocator);
    defer request.deinit();
    request.method = .GET;
    request.path = "/test";

    var response = try router.handle(&request);
    defer response.deinit();

    try testing.expectEqual(HttpStatus.ok, response.status);
    try testing.expectEqualStrings("Test response", response.body);
}

test "router 404 for unmatched routes" {
    var router = Router.init(testing.allocator);
    defer router.deinit();

    try router.add(.GET, "/exists", testHandler);

    var request = HttpRequest.init(testing.allocator);
    defer request.deinit();
    request.method = .GET;
    request.path = "/nonexistent";

    var response = try router.handle(&request);
    defer response.deinit();

    try testing.expectEqual(HttpStatus.not_found, response.status);
    try testing.expectEqualStrings("Not Found", response.body);
}
// ANCHOR_END: router

// ANCHOR: middleware
pub const Middleware = *const fn (request: *HttpRequest, next: Handler) anyerror!HttpResponse;

pub const MiddlewareChain = struct {
    middlewares: std.ArrayList(Middleware),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) MiddlewareChain {
        return .{
            .middlewares = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MiddlewareChain) void {
        self.middlewares.deinit(self.allocator);
    }

    pub fn use(self: *MiddlewareChain, middleware: Middleware) !void {
        try self.middlewares.append(self.allocator, middleware);
    }
};

// Example logging middleware
fn loggingMiddleware(request: *HttpRequest, next: Handler) !HttpResponse {
    // Log request (in real code, use std.log)
    _ = next;

    // Call next handler
    // return try next(request);

    // For testing, return a mock response
    var response = HttpResponse.init(request.allocator, .ok);
    response.setBody("Logged");
    return response;
}

test "middleware pattern" {
    var chain = MiddlewareChain.init(testing.allocator);
    defer chain.deinit();

    try chain.use(loggingMiddleware);

    try testing.expectEqual(@as(usize, 1), chain.middlewares.items.len);
}
// ANCHOR_END: middleware

// ANCHOR: content_type
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
            .application_xml => "application/xml",
            .image_png => "image/png",
            .image_jpeg => "image/jpeg",
            .application_octet_stream => "application/octet-stream",
        };
    }
};

test "content type detection" {
    try testing.expectEqual(ContentType.text_html, ContentType.fromExtension(".html"));
    try testing.expectEqual(ContentType.application_json, ContentType.fromExtension(".json"));
    try testing.expectEqualStrings("text/html", ContentType.text_html.toString());
}
// ANCHOR_END: content_type

// ANCHOR: static_file_handler
pub const StaticFileHandler = struct {
    root_dir: []const u8,

    pub fn init(root_dir: []const u8) StaticFileHandler {
        return .{ .root_dir = root_dir };
    }

    pub fn serve(self: StaticFileHandler, path: []const u8, allocator: std.mem.Allocator) !HttpResponse {
        _ = self;

        // In real implementation: read file from root_dir + path
        // For demo, return mock response

        var response = HttpResponse.init(allocator, .ok);

        // Detect content type from extension
        const ext = std.fs.path.extension(path);
        const content_type = ContentType.fromExtension(ext);
        try response.setHeader("Content-Type", content_type.toString());

        response.setBody("Mock file content");

        return response;
    }
};

test "static file handler" {
    const handler = StaticFileHandler.init("/var/www");

    var response = try handler.serve("/index.html", testing.allocator);
    defer response.deinit();

    try testing.expectEqual(HttpStatus.ok, response.status);

    const content_type = response.headers.get("Content-Type");
    try testing.expect(content_type != null);
    try testing.expectEqualStrings("text/html", content_type.?);
}
// ANCHOR_END: static_file_handler

// ANCHOR: query_params
pub const QueryParams = struct {
    params: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) QueryParams {
        return .{
            .params = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *QueryParams) void {
        var it = self.params.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.params.deinit();
    }

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

test "query params parsing" {
    var params = try QueryParams.parse(testing.allocator, "name=Alice&age=30");
    defer params.deinit();

    try testing.expectEqualStrings("Alice", params.get("name").?);
    try testing.expectEqualStrings("30", params.get("age").?);
    try testing.expect(params.get("missing") == null);
}
// ANCHOR_END: query_params

// ANCHOR: json_response_helper
pub fn jsonResponse(allocator: std.mem.Allocator, status: HttpStatus, json_data: []const u8) !HttpResponse {
    var response = HttpResponse.init(allocator, status);
    errdefer response.deinit();

    try response.setHeader("Content-Type", "application/json");
    response.setBody(json_data);

    return response;
}

test "json response helper" {
    var response = try jsonResponse(testing.allocator, .ok, "{\"message\":\"Success\"}");
    defer response.deinit();

    try testing.expectEqual(HttpStatus.ok, response.status);

    const content_type = response.headers.get("Content-Type");
    try testing.expect(content_type != null);
    try testing.expectEqualStrings("application/json", content_type.?);
}
// ANCHOR_END: json_response_helper

// Comprehensive test
test "comprehensive http server patterns" {
    // Parse request
    const raw_request =
        \\POST /api/users?admin=true HTTP/1.1
        \\Host: localhost:8080
        \\Content-Type: application/json
        \\
        \\{"name":"Bob"}
    ;

    var request = try HttpRequest.parse(testing.allocator, raw_request);
    defer request.deinit();

    try testing.expectEqual(HttpMethod.POST, request.method);
    try testing.expectEqualStrings("/api/users?admin=true", request.path);

    // Build response
    var response = HttpResponse.init(testing.allocator, .created);
    defer response.deinit();

    try response.setHeader("Location", "/api/users/123");
    response.setBody("{\"id\":123,\"name\":\"Bob\"}");

    const raw_response = try response.build(testing.allocator);
    defer testing.allocator.free(raw_response);

    try testing.expect(std.mem.indexOf(u8, raw_response, "201 Created") != null);
}
