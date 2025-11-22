// Recipe 20.4: Implementing a basic HTTP/1.1 parser from scratch
// Target Zig Version: 0.15.2
const std = @import("std");
const testing = std.testing;
const mem = std.mem;

// ANCHOR: http_method
const HttpMethod = enum {
    GET,
    POST,
    PUT,
    DELETE,
    HEAD,
    OPTIONS,
    PATCH,

    pub fn fromString(s: []const u8) !HttpMethod {
        if (mem.eql(u8, s, "GET")) return .GET;
        if (mem.eql(u8, s, "POST")) return .POST;
        if (mem.eql(u8, s, "PUT")) return .PUT;
        if (mem.eql(u8, s, "DELETE")) return .DELETE;
        if (mem.eql(u8, s, "HEAD")) return .HEAD;
        if (mem.eql(u8, s, "OPTIONS")) return .OPTIONS;
        if (mem.eql(u8, s, "PATCH")) return .PATCH;
        return error.InvalidMethod;
    }
};
// ANCHOR_END: http_method

// ANCHOR: http_request
const HttpRequest = struct {
    method: HttpMethod,
    path: []const u8,
    version: []const u8,
    headers: std.StringHashMap([]const u8),
    body: []const u8,

    pub fn deinit(self: *HttpRequest) void {
        self.headers.deinit();
    }
};
// ANCHOR_END: http_request

// ANCHOR: request_parser
const RequestParser = struct {
    allocator: mem.Allocator,
    state: ParserState,
    request: HttpRequest,

    const ParserState = enum {
        request_line,
        headers,
        body,
        complete,
    };

    pub fn init(allocator: mem.Allocator) RequestParser {
        return .{
            .allocator = allocator,
            .state = .request_line,
            .request = .{
                .method = .GET,
                .path = &[_]u8{},
                .version = &[_]u8{},
                .headers = std.StringHashMap([]const u8).init(allocator),
                .body = &[_]u8{},
            },
        };
    }

    pub fn deinit(self: *RequestParser) void {
        self.request.deinit();
    }

    pub fn parse(self: *RequestParser, data: []const u8) !HttpRequest {
        var lines = mem.splitScalar(u8, data, '\n');

        // Parse request line
        if (lines.next()) |line| {
            const trimmed = mem.trim(u8, line, "\r\n ");
            try self.parseRequestLine(trimmed);
        }

        // Parse headers
        while (lines.next()) |line| {
            const trimmed = mem.trim(u8, line, "\r\n ");
            if (trimmed.len == 0) {
                self.state = .body;
                break;
            }
            try self.parseHeader(trimmed);
        }

        // Get body (everything after blank line)
        const remaining = lines.rest();
        self.request.body = mem.trim(u8, remaining, "\r\n ");
        self.state = .complete;

        return self.request;
    }

    fn parseRequestLine(self: *RequestParser, line: []const u8) !void {
        var parts = mem.splitScalar(u8, line, ' ');

        const method_str = parts.next() orelse return error.InvalidRequestLine;
        self.request.method = try HttpMethod.fromString(method_str);

        self.request.path = parts.next() orelse return error.InvalidRequestLine;
        self.request.version = parts.next() orelse return error.InvalidRequestLine;
    }

    fn parseHeader(self: *RequestParser, line: []const u8) !void {
        const colon_pos = mem.indexOf(u8, line, ":") orelse return error.InvalidHeader;

        const name = line[0..colon_pos];
        const value = mem.trim(u8, line[colon_pos + 1 ..], " ");

        try self.request.headers.put(name, value);
    }
};
// ANCHOR_END: request_parser

// ANCHOR: response_builder
const ResponseBuilder = struct {
    allocator: mem.Allocator,
    status_code: u16,
    status_text: []const u8,
    headers: std.StringHashMap([]const u8),
    body: []const u8,

    pub fn init(allocator: mem.Allocator) ResponseBuilder {
        return .{
            .allocator = allocator,
            .status_code = 200,
            .status_text = "OK",
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = &[_]u8{},
        };
    }

    pub fn deinit(self: *ResponseBuilder) void {
        self.headers.deinit();
    }

    pub fn setStatus(self: *ResponseBuilder, code: u16, text: []const u8) void {
        self.status_code = code;
        self.status_text = text;
    }

    pub fn addHeader(self: *ResponseBuilder, name: []const u8, value: []const u8) !void {
        try self.headers.put(name, value);
    }

    pub fn setBody(self: *ResponseBuilder, body: []const u8) void {
        self.body = body;
    }

    pub fn build(self: *ResponseBuilder) ![]const u8 {
        // Calculate total size for single allocation
        var total_size: usize = 0;

        // Status line: "HTTP/1.1 NNN TEXT\r\n"
        total_size += 9 + 3 + 1 + self.status_text.len + 2; // "HTTP/1.1 " + code + " " + text + "\r\n"

        // Headers
        var iter = self.headers.iterator();
        while (iter.next()) |entry| {
            total_size += entry.key_ptr.len + 2 + entry.value_ptr.len + 2; // "key: value\r\n"
        }

        // Content-Length header if body exists
        if (self.body.len > 0) {
            total_size += 20; // "Content-Length: " + number + "\r\n"
        }

        // Blank line + body
        total_size += 2 + self.body.len;

        var result = std.ArrayList(u8){};
        errdefer result.deinit(self.allocator);

        // Reserve capacity
        try result.ensureTotalCapacity(self.allocator, total_size);

        // Status line
        try result.appendSlice(self.allocator, "HTTP/1.1 ");
        var buf: [16]u8 = undefined;
        const code_str = try std.fmt.bufPrint(&buf, "{d}", .{self.status_code});
        try result.appendSlice(self.allocator, code_str);
        try result.appendSlice(self.allocator, " ");
        try result.appendSlice(self.allocator, self.status_text);
        try result.appendSlice(self.allocator, "\r\n");

        // Headers
        iter = self.headers.iterator();
        while (iter.next()) |entry| {
            try result.appendSlice(self.allocator, entry.key_ptr.*);
            try result.appendSlice(self.allocator, ": ");
            try result.appendSlice(self.allocator, entry.value_ptr.*);
            try result.appendSlice(self.allocator, "\r\n");
        }

        // Content-Length if needed
        if (self.body.len > 0) {
            const len_str = try std.fmt.bufPrint(&buf, "{d}", .{self.body.len});
            try result.appendSlice(self.allocator, "Content-Length: ");
            try result.appendSlice(self.allocator, len_str);
            try result.appendSlice(self.allocator, "\r\n");
        }

        // Blank line
        try result.appendSlice(self.allocator, "\r\n");

        // Body
        if (self.body.len > 0) {
            try result.appendSlice(self.allocator, self.body);
        }

        return result.toOwnedSlice(self.allocator);
    }
};
// ANCHOR_END: response_builder

// ANCHOR: chunked_parser
const ChunkedParser = struct {
    state: enum { chunk_size, chunk_data, chunk_end, trailer, complete },
    chunk_size: usize,
    bytes_read: usize,

    pub fn init() ChunkedParser {
        return .{
            .state = .chunk_size,
            .chunk_size = 0,
            .bytes_read = 0,
        };
    }

    pub fn parseChunkSize(line: []const u8) !usize {
        const trimmed = mem.trim(u8, line, "\r\n ");
        const semicolon = mem.indexOf(u8, trimmed, ";") orelse trimmed.len;
        const size_str = trimmed[0..semicolon];

        return try std.fmt.parseInt(usize, size_str, 16);
    }
};
// ANCHOR_END: chunked_parser

// Tests
test "HTTP method parsing" {
    try testing.expectEqual(HttpMethod.GET, try HttpMethod.fromString("GET"));
    try testing.expectEqual(HttpMethod.POST, try HttpMethod.fromString("POST"));
    try testing.expectError(error.InvalidMethod, HttpMethod.fromString("INVALID"));
}

test "parse simple GET request" {
    var parser = RequestParser.init(testing.allocator);
    defer parser.deinit();

    const request_data =
        \\GET /index.html HTTP/1.1
        \\Host: example.com
        \\User-Agent: TestClient/1.0
        \\
        \\
    ;

    const request = try parser.parse(request_data);
    try testing.expectEqual(HttpMethod.GET, request.method);
    try testing.expectEqualStrings("/index.html", request.path);
    try testing.expectEqualStrings("HTTP/1.1", request.version);
    try testing.expectEqualStrings("example.com", request.headers.get("Host").?);
}

test "parse POST request with body" {
    var parser = RequestParser.init(testing.allocator);
    defer parser.deinit();

    const request_data =
        \\POST /api/data HTTP/1.1
        \\Host: api.example.com
        \\Content-Type: application/json
        \\Content-Length: 27
        \\
        \\{"key": "value", "id": 42}
    ;

    const request = try parser.parse(request_data);
    try testing.expectEqual(HttpMethod.POST, request.method);
    try testing.expectEqualStrings("/api/data", request.path);
    try testing.expectEqualStrings("{\"key\": \"value\", \"id\": 42}", request.body);
}

test "response builder - basic response" {
    var builder = ResponseBuilder.init(testing.allocator);
    defer builder.deinit();

    builder.setStatus(200, "OK");
    try builder.addHeader("Content-Type", "text/plain");
    builder.setBody("Hello, World!");

    const response = try builder.build();
    defer testing.allocator.free(response);

    try testing.expect(mem.indexOf(u8, response, "HTTP/1.1 200 OK") != null);
    try testing.expect(mem.indexOf(u8, response, "Hello, World!") != null);
}

test "response builder - 404 response" {
    var builder = ResponseBuilder.init(testing.allocator);
    defer builder.deinit();

    builder.setStatus(404, "Not Found");
    try builder.addHeader("Content-Type", "text/html");
    builder.setBody("<h1>404 Not Found</h1>");

    const response = try builder.build();
    defer testing.allocator.free(response);

    try testing.expect(mem.indexOf(u8, response, "404 Not Found") != null);
}

test "chunked encoding - parse chunk size" {
    try testing.expectEqual(@as(usize, 0x1a), try ChunkedParser.parseChunkSize("1a\r\n"));
    try testing.expectEqual(@as(usize, 0x100), try ChunkedParser.parseChunkSize("100\r\n"));
    try testing.expectEqual(@as(usize, 0), try ChunkedParser.parseChunkSize("0\r\n"));
}

test "chunked encoding - parse with extension" {
    try testing.expectEqual(@as(usize, 0x1a), try ChunkedParser.parseChunkSize("1a;name=value\r\n"));
}

test "request parser - multiple headers" {
    var parser = RequestParser.init(testing.allocator);
    defer parser.deinit();

    const request_data =
        \\GET / HTTP/1.1
        \\Host: example.com
        \\Accept: text/html
        \\Accept-Encoding: gzip
        \\Connection: keep-alive
        \\
        \\
    ;

    const request = try parser.parse(request_data);
    try testing.expectEqual(@as(usize, 4), request.headers.count());
}

test "response builder - empty body" {
    var builder = ResponseBuilder.init(testing.allocator);
    defer builder.deinit();

    builder.setStatus(204, "No Content");

    const response = try builder.build();
    defer testing.allocator.free(response);

    try testing.expect(mem.indexOf(u8, response, "204 No Content") != null);
}
