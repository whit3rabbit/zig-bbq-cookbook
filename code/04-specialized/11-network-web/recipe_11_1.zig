// Recipe 11.1: Making HTTP Requests
// Target Zig Version: 0.15.2
//
// Educational demonstration of HTTP client patterns in Zig.
// This code shows the structure and API design for HTTP clients
// but does not make actual network requests in tests (to avoid external dependencies).
//
// For production HTTP requests, use std.http.Client:
// https://ziglang.org/documentation/master/std/#std.http.Client
//
// Key concepts:
// - HTTP request/response structures
// - Request builder pattern with fluent API
// - Header management
// - URL parsing
// - Error handling for network operations
// - Retry policies with exponential backoff

const std = @import("std");
const testing = std.testing;

// ANCHOR: http_client_basic
// Basic HTTP client wrapper
pub const HttpClient = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) HttpClient {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *HttpClient) void {
        // Currently no resources to clean up.
        // This method exists for API consistency and future extensibility.
        _ = self;
    }
};

test "http client initialization" {
    var client = HttpClient.init(testing.allocator);
    defer client.deinit();
}
// ANCHOR_END: http_client_basic

// ANCHOR: request_options
pub const RequestOptions = struct {
    method: Method = .GET,
    headers: ?std.StringHashMap([]const u8) = null,
    body: ?[]const u8 = null,
    timeout_ms: ?u32 = null,
    follow_redirects: bool = true,
    max_redirects: u32 = 10,

    pub const Method = enum {
        GET,
        POST,
        PUT,
        DELETE,
        PATCH,
        HEAD,
        OPTIONS,

        pub fn toString(self: Method) []const u8 {
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
};

test "request options" {
    const opts = RequestOptions{
        .method = .POST,
        .body = "test data",
        .timeout_ms = 5000,
    };

    try testing.expectEqual(RequestOptions.Method.POST, opts.method);
    try testing.expectEqualStrings("POST", opts.method.toString());
}
// ANCHOR_END: request_options

// ANCHOR: response_struct
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

test "response status checks" {
    var resp = try Response.init(testing.allocator, 200, "OK");
    defer resp.deinit();

    try testing.expect(resp.isSuccess());
    try testing.expect(!resp.isRedirect());
    try testing.expect(!resp.isClientError());
    try testing.expect(!resp.isServerError());

    var resp_404 = try Response.init(testing.allocator, 404, "Not Found");
    defer resp_404.deinit();

    try testing.expect(!resp_404.isSuccess());
    try testing.expect(resp_404.isClientError());
}
// ANCHOR_END: response_struct

// ANCHOR: url_parser
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
    /// The allocator parameter is currently unused but reserved for future use.
    ///
    /// Simplified URL parsing for demonstration purposes.
    /// Production code should use a robust URL parsing library.
    /// Missing features: query parsing, fragment parsing, IPv6 support, URL encoding
    pub fn parse(allocator: std.mem.Allocator, url: []const u8) !Url {
        _ = allocator;

        // Find scheme (e.g., "https")
        var scheme_end: usize = 0;
        if (std.mem.indexOf(u8, url, "://")) |idx| {
            scheme_end = idx;
        } else {
            return error.InvalidUrl;
        }

        const scheme = url[0..scheme_end];
        var rest = url[scheme_end + 3 ..];

        // Find path start
        const path_start = std.mem.indexOfAny(u8, rest, "/?#") orelse rest.len;
        const host_port = rest[0..path_start];

        var host = host_port;
        var port: ?u16 = null;

        if (std.mem.indexOf(u8, host_port, ":")) |colon_idx| {
            host = host_port[0..colon_idx];
            const port_str = host_port[colon_idx + 1 ..];
            port = try std.fmt.parseInt(u16, port_str, 10);
        }

        const path = if (path_start < rest.len) rest[path_start..] else "/";

        return .{
            .scheme = scheme,
            .host = host,
            .port = port,
            .path = path,
            .query = null,
            .fragment = null,
        };
    }
};

test "url parsing" {
    const url1 = try Url.parse(testing.allocator, "https://example.com/path");
    try testing.expectEqualStrings("https", url1.scheme);
    try testing.expectEqualStrings("example.com", url1.host);
    try testing.expectEqualStrings("/path", url1.path);

    const url2 = try Url.parse(testing.allocator, "http://localhost:8080/api");
    try testing.expectEqualStrings("http", url2.scheme);
    try testing.expectEqualStrings("localhost", url2.host);
    try testing.expectEqual(@as(u16, 8080), url2.port.?);
}
// ANCHOR_END: url_parser

// ANCHOR: header_builder
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

    pub fn setAuthorization(self: *HeaderBuilder, auth: []const u8) !void {
        try self.set("Authorization", auth);
    }

    pub fn build(self: HeaderBuilder) std.StringHashMap([]const u8) {
        return self.headers;
    }
};

test "header builder" {
    var builder = HeaderBuilder.init(testing.allocator);
    defer builder.deinit();

    try builder.setUserAgent("Zig HTTP Client/1.0");
    try builder.setContentType("application/json");
    try builder.set("X-Custom-Header", "custom-value");

    const headers = builder.build();
    const user_agent = headers.get("User-Agent");
    try testing.expect(user_agent != null);
    try testing.expectEqualStrings("Zig HTTP Client/1.0", user_agent.?);
}
// ANCHOR_END: header_builder

// ANCHOR: request_builder
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

test "request builder" {
    var builder = RequestBuilder.init(testing.allocator, "https://example.com/api");
    defer builder.deinit();

    _ = builder.method(.POST);
    _ = builder.body("{\"key\":\"value\"}");
    _ = try builder.header("Content-Type", "application/json");
    _ = builder.timeout(5000);

    try testing.expectEqual(RequestOptions.Method.POST, builder.options.method);
}
// ANCHOR_END: request_builder

// ANCHOR: json_request
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

test "json request helpers" {
    var post_req = try JsonRequest.post(
        testing.allocator,
        "https://api.example.com/users",
        "{\"name\":\"Alice\"}",
    );
    defer post_req.deinit();

    try testing.expectEqual(RequestOptions.Method.POST, post_req.options.method);

    var get_req = try JsonRequest.get(testing.allocator, "https://api.example.com/users/1");
    defer get_req.deinit();

    try testing.expectEqual(RequestOptions.Method.GET, get_req.options.method);
}
// ANCHOR_END: json_request

// ANCHOR: error_types
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

test "error types" {
    const err_info = ErrorInfo.init(HttpError.Timeout, "Request timed out after 5000ms");
    try testing.expectEqual(HttpError.Timeout, err_info.error_code);
    try testing.expectEqualStrings("Request timed out after 5000ms", err_info.message);
}
// ANCHOR_END: error_types

// ANCHOR: retry_policy
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
        const multiplier = std.math.pow(f32, self.backoff_multiplier, @as(f32, @floatFromInt(attempt)));
        const delay = base_delay * multiplier;

        // Cap at max u32 value to prevent overflow
        const max_delay: f32 = @floatFromInt(std.math.maxInt(u32));
        return @intFromFloat(@min(delay, max_delay));
    }
};

test "retry policy" {
    const policy = RetryPolicy{};

    try testing.expect(policy.shouldRetry(0, HttpError.Timeout));
    try testing.expect(policy.shouldRetry(1, HttpError.ConnectionFailed));
    try testing.expect(!policy.shouldRetry(3, HttpError.Timeout));
    try testing.expect(!policy.shouldRetry(0, HttpError.InvalidUrl));

    try testing.expectEqual(@as(u32, 1000), policy.getDelay(0));
    try testing.expectEqual(@as(u32, 2000), policy.getDelay(1));
    try testing.expectEqual(@as(u32, 4000), policy.getDelay(2));
}
// ANCHOR_END: retry_policy

// ANCHOR: content_negotiation
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

test "content type negotiation" {
    const json_type = ContentType.json;
    try testing.expectEqualStrings("application/json", json_type.toString());

    const parsed = ContentType.fromString("application/json");
    try testing.expectEqual(ContentType.json, parsed.?);
}
// ANCHOR_END: content_negotiation

// Comprehensive test
test "comprehensive http client patterns" {
    // Request options
    const opts = RequestOptions{ .method = .GET };
    try testing.expectEqualStrings("GET", opts.method.toString());

    // Response handling
    var resp = try Response.init(testing.allocator, 200, "Success");
    defer resp.deinit();
    try testing.expect(resp.isSuccess());

    // URL parsing
    const url = try Url.parse(testing.allocator, "https://example.com:443/api");
    try testing.expectEqualStrings("https", url.scheme);
    try testing.expectEqual(@as(u16, 443), url.port.?);

    // Header building
    var headers = HeaderBuilder.init(testing.allocator);
    defer headers.deinit();
    try headers.setUserAgent("Test/1.0");

    // Retry logic
    const policy = RetryPolicy{};
    try testing.expect(policy.shouldRetry(0, HttpError.Timeout));
}
