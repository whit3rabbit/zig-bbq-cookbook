const std = @import("std");
const testing = std.testing;

// ANCHOR: http_method
pub const HttpMethod = enum {
    GET,
    POST,
    PUT,
    PATCH,
    DELETE,
    HEAD,
    OPTIONS,

    pub fn toString(self: HttpMethod) []const u8 {
        return switch (self) {
            .GET => "GET",
            .POST => "POST",
            .PUT => "PUT",
            .PATCH => "PATCH",
            .DELETE => "DELETE",
            .HEAD => "HEAD",
            .OPTIONS => "OPTIONS",
        };
    }
};
// ANCHOR_END: http_method

// ANCHOR: http_status
pub const HttpStatus = enum(u16) {
    // Success
    ok = 200,
    created = 201,
    accepted = 202,
    no_content = 204,

    // Client Errors
    bad_request = 400,
    unauthorized = 401,
    forbidden = 403,
    not_found = 404,
    method_not_allowed = 405,
    conflict = 409,
    unprocessable_entity = 422,

    // Server Errors
    internal_server_error = 500,
    not_implemented = 501,
    bad_gateway = 502,
    service_unavailable = 503,

    pub fn isSuccess(self: HttpStatus) bool {
        const code = @intFromEnum(self);
        return code >= 200 and code < 300;
    }

    pub fn isClientError(self: HttpStatus) bool {
        const code = @intFromEnum(self);
        return code >= 400 and code < 500;
    }

    pub fn isServerError(self: HttpStatus) bool {
        const code = @intFromEnum(self);
        return code >= 500 and code < 600;
    }
};
// ANCHOR_END: http_status

// ANCHOR: rest_request
pub const RestRequest = struct {
    method: HttpMethod,
    path: []const u8,
    query: std.StringHashMap([]const u8),
    headers: std.StringHashMap([]const u8),
    body: ?[]const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, method: HttpMethod, path: []const u8) RestRequest {
        return .{
            .method = method,
            .path = path,
            .query = std.StringHashMap([]const u8).init(allocator),
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RestRequest) void {
        var query_it = self.query.iterator();
        while (query_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.query.deinit();

        var header_it = self.headers.iterator();
        while (header_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();

        if (self.body) |body| {
            self.allocator.free(body);
        }
    }

    pub fn addQuery(self: *RestRequest, key: []const u8, value: []const u8) !void {
        // HashMap Memory Leak Prevention
        //
        // Using getOrPut() instead of put() prevents memory leaks when the same
        // query parameter is added multiple times (e.g., ?page=1 overridden to ?page=2).
        //
        // The pattern:
        // 1. Allocate new value (always needed)
        // 2. Check if key exists with getOrPut()
        // 3. If duplicate: free old value, reuse key
        // 4. If new: allocate key, store both

        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);

        const gop = try self.query.getOrPut(key);
        if (gop.found_existing) {
            // Duplicate parameter: free old value, reuse existing key
            self.allocator.free(gop.value_ptr.*);
            gop.value_ptr.* = owned_value;
        } else {
            // New parameter: allocate key and store both
            const owned_key = try self.allocator.dupe(u8, key);
            gop.key_ptr.* = owned_key;
            gop.value_ptr.* = owned_value;
        }
    }

    pub fn addHeader(self: *RestRequest, key: []const u8, value: []const u8) !void {
        // HashMap Memory Leak Prevention
        //
        // Using getOrPut() instead of put() prevents memory leaks when the same
        // header is set multiple times (e.g., updating Content-Type or Authorization).
        //
        // This is the correct pattern for all HashMap operations with owned strings.
        // See HttpResponse.setHeader (recipe_11_4.zig:248-264) for reference implementation.

        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);

        const gop = try self.headers.getOrPut(key);
        if (gop.found_existing) {
            // Duplicate header: free old value, reuse existing key
            self.allocator.free(gop.value_ptr.*);
            gop.value_ptr.* = owned_value;
        } else {
            // New header: allocate key and store both
            const owned_key = try self.allocator.dupe(u8, key);
            gop.key_ptr.* = owned_key;
            gop.value_ptr.* = owned_value;
        }
    }

    pub fn setBody(self: *RestRequest, body: []const u8) !void {
        if (self.body) |old_body| {
            self.allocator.free(old_body);
        }
        self.body = try self.allocator.dupe(u8, body);
    }

    pub fn buildUrl(self: *const RestRequest) ![]const u8 {
        var url = std.ArrayList(u8){};
        defer url.deinit(self.allocator);

        try url.appendSlice(self.allocator, self.path);

        if (self.query.count() > 0) {
            try url.append(self.allocator, '?');
            var first = true;
            var it = self.query.iterator();
            while (it.next()) |entry| {
                if (!first) try url.append(self.allocator, '&');
                first = false;
                try url.appendSlice(self.allocator, entry.key_ptr.*);
                try url.append(self.allocator, '=');
                try url.appendSlice(self.allocator, entry.value_ptr.*);
            }
        }

        return url.toOwnedSlice(self.allocator);
    }
};
// ANCHOR_END: rest_request

// ANCHOR: rest_response
pub const RestResponse = struct {
    status: HttpStatus,
    headers: std.StringHashMap([]const u8),
    body: ?[]const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, status: HttpStatus) RestResponse {
        return .{
            .status = status,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RestResponse) void {
        var it = self.headers.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();

        if (self.body) |body| {
            self.allocator.free(body);
        }
    }

    pub fn addHeader(self: *RestResponse, key: []const u8, value: []const u8) !void {
        const owned_key = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned_key);
        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);
        try self.headers.put(owned_key, owned_value);
    }

    pub fn setBody(self: *RestResponse, body: []const u8) !void {
        if (self.body) |old_body| {
            self.allocator.free(old_body);
        }
        self.body = try self.allocator.dupe(u8, body);
    }

    pub fn isSuccess(self: *const RestResponse) bool {
        return self.status.isSuccess();
    }
};
// ANCHOR_END: rest_response

// ANCHOR: rest_client
pub const RestClient = struct {
    base_url: []const u8,
    default_headers: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, base_url: []const u8) !RestClient {
        return .{
            .base_url = try allocator.dupe(u8, base_url),
            .default_headers = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RestClient) void {
        self.allocator.free(self.base_url);

        var it = self.default_headers.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.default_headers.deinit();
    }

    pub fn setDefaultHeader(self: *RestClient, key: []const u8, value: []const u8) !void {
        const owned_key = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned_key);
        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);
        try self.default_headers.put(owned_key, owned_value);
    }

    pub fn get(self: *RestClient, path: []const u8) !RestResponse {
        var request = RestRequest.init(self.allocator, .GET, path);
        defer request.deinit();
        return try self.execute(&request);
    }

    pub fn post(self: *RestClient, path: []const u8, body: []const u8) !RestResponse {
        var request = RestRequest.init(self.allocator, .POST, path);
        defer request.deinit();
        try request.setBody(body);
        try request.addHeader("Content-Type", "application/json");
        return try self.execute(&request);
    }

    pub fn put(self: *RestClient, path: []const u8, body: []const u8) !RestResponse {
        var request = RestRequest.init(self.allocator, .PUT, path);
        defer request.deinit();
        try request.setBody(body);
        try request.addHeader("Content-Type", "application/json");
        return try self.execute(&request);
    }

    pub fn patch(self: *RestClient, path: []const u8, body: []const u8) !RestResponse {
        var request = RestRequest.init(self.allocator, .PATCH, path);
        defer request.deinit();
        try request.setBody(body);
        try request.addHeader("Content-Type", "application/json");
        return try self.execute(&request);
    }

    pub fn delete(self: *RestClient, path: []const u8) !RestResponse {
        var request = RestRequest.init(self.allocator, .DELETE, path);
        defer request.deinit();
        return try self.execute(&request);
    }

    pub fn execute(self: *RestClient, request: *RestRequest) !RestResponse {
        // Simulate HTTP request (in real implementation, use std.http.Client)
        // For testing, return mock responses based on method and path

        if (request.method == .GET and std.mem.eql(u8, request.path, "/users/1")) {
            var response = RestResponse.init(self.allocator, .ok);
            try response.setBody("{\"id\":1,\"name\":\"Alice\"}");
            try response.addHeader("Content-Type", "application/json");
            return response;
        } else if (request.method == .POST and std.mem.eql(u8, request.path, "/users")) {
            var response = RestResponse.init(self.allocator, .created);
            try response.setBody("{\"id\":2,\"name\":\"Bob\"}");
            try response.addHeader("Content-Type", "application/json");
            return response;
        } else if (request.method == .PUT and std.mem.eql(u8, request.path, "/users/1")) {
            var response = RestResponse.init(self.allocator, .ok);
            try response.setBody("{\"id\":1,\"name\":\"Alice Updated\"}");
            try response.addHeader("Content-Type", "application/json");
            return response;
        } else if (request.method == .DELETE and std.mem.eql(u8, request.path, "/users/1")) {
            return RestResponse.init(self.allocator, .no_content);
        }

        return RestResponse.init(self.allocator, .not_found);
    }
};
// ANCHOR_END: rest_client

// ANCHOR: resource_handler
pub const ResourceHandler = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ResourceHandler {
        return .{ .allocator = allocator };
    }

    pub fn handleGet(self: *ResourceHandler, id: []const u8) !RestResponse {
        var response = RestResponse.init(self.allocator, .ok);
        var body = std.ArrayList(u8){};
        defer body.deinit(self.allocator);

        try body.appendSlice(self.allocator, "{\"id\":");
        try body.appendSlice(self.allocator, id);
        try body.appendSlice(self.allocator, ",\"name\":\"Resource\"}");

        try response.setBody(body.items);
        try response.addHeader("Content-Type", "application/json");
        return response;
    }

    pub fn handleCreate(self: *ResourceHandler, data: []const u8) !RestResponse {
        var response = RestResponse.init(self.allocator, .created);
        try response.setBody(data);
        try response.addHeader("Content-Type", "application/json");
        try response.addHeader("Location", "/resources/123");
        return response;
    }

    pub fn handleUpdate(self: *ResourceHandler, id: []const u8, data: []const u8) !RestResponse {
        _ = id;
        var response = RestResponse.init(self.allocator, .ok);
        try response.setBody(data);
        try response.addHeader("Content-Type", "application/json");
        return response;
    }

    pub fn handleDelete(self: *ResourceHandler, id: []const u8) !RestResponse {
        _ = id;
        return RestResponse.init(self.allocator, .no_content);
    }
};
// ANCHOR_END: resource_handler

// ANCHOR: test_http_method
test "HTTP method to string conversion" {
    try testing.expectEqualStrings("GET", HttpMethod.GET.toString());
    try testing.expectEqualStrings("POST", HttpMethod.POST.toString());
    try testing.expectEqualStrings("PUT", HttpMethod.PUT.toString());
    try testing.expectEqualStrings("DELETE", HttpMethod.DELETE.toString());
}
// ANCHOR_END: test_http_method

// ANCHOR: test_http_status
test "HTTP status code classification" {
    try testing.expect(HttpStatus.ok.isSuccess());
    try testing.expect(HttpStatus.created.isSuccess());
    try testing.expect(!HttpStatus.bad_request.isSuccess());

    try testing.expect(HttpStatus.not_found.isClientError());
    try testing.expect(HttpStatus.unauthorized.isClientError());
    try testing.expect(!HttpStatus.ok.isClientError());

    try testing.expect(HttpStatus.internal_server_error.isServerError());
    try testing.expect(!HttpStatus.ok.isServerError());
}
// ANCHOR_END: test_http_status

// ANCHOR: test_rest_request
test "create REST request" {
    var request = RestRequest.init(testing.allocator, .GET, "/users");
    defer request.deinit();

    try testing.expectEqual(HttpMethod.GET, request.method);
    try testing.expectEqualStrings("/users", request.path);
    try testing.expectEqual(@as(?[]const u8, null), request.body);
}
// ANCHOR_END: test_rest_request

// ANCHOR: test_query_parameters
test "REST request with query parameters" {
    var request = RestRequest.init(testing.allocator, .GET, "/users");
    defer request.deinit();

    try request.addQuery("page", "2");
    try request.addQuery("limit", "10");

    const url = try request.buildUrl();
    defer testing.allocator.free(url);

    // URL should contain path and query params (order may vary)
    try testing.expect(std.mem.startsWith(u8, url, "/users?"));
    try testing.expect(std.mem.indexOf(u8, url, "page=2") != null);
    try testing.expect(std.mem.indexOf(u8, url, "limit=10") != null);
}
// ANCHOR_END: test_query_parameters

test "REST request with duplicate query parameters - no memory leak" {
    var request = RestRequest.init(testing.allocator, .GET, "/search");
    defer request.deinit();

    // Add query parameter twice - last value should win
    try request.addQuery("page", "1");
    try request.addQuery("page", "2");
    try request.addQuery("sort", "asc");
    try request.addQuery("sort", "desc");

    // Should only have 2 parameters, not 4
    try testing.expectEqual(@as(u32, 2), request.query.count());

    // Last values should win
    const page = request.query.get("page");
    try testing.expect(page != null);
    try testing.expectEqualStrings("2", page.?);

    const sort = request.query.get("sort");
    try testing.expect(sort != null);
    try testing.expectEqualStrings("desc", sort.?);
}

// ANCHOR: test_request_headers
test "REST request with headers" {
    var request = RestRequest.init(testing.allocator, .POST, "/users");
    defer request.deinit();

    try request.addHeader("Content-Type", "application/json");
    try request.addHeader("Authorization", "Bearer token123");

    const content_type = request.headers.get("Content-Type");
    try testing.expect(content_type != null);
    try testing.expectEqualStrings("application/json", content_type.?);

    const auth = request.headers.get("Authorization");
    try testing.expect(auth != null);
    try testing.expectEqualStrings("Bearer token123", auth.?);
}
// ANCHOR_END: test_request_headers

test "REST request with duplicate headers - no memory leak" {
    var request = RestRequest.init(testing.allocator, .POST, "/api/data");
    defer request.deinit();

    // Add same header multiple times - last value should win
    try request.addHeader("Authorization", "Bearer oldtoken");
    try request.addHeader("Authorization", "Bearer newtoken");
    try request.addHeader("Content-Type", "text/plain");
    try request.addHeader("Content-Type", "application/json");

    // Should only have 2 headers, not 4
    try testing.expectEqual(@as(u32, 2), request.headers.count());

    // Last values should win
    const auth = request.headers.get("Authorization");
    try testing.expect(auth != null);
    try testing.expectEqualStrings("Bearer newtoken", auth.?);

    const content_type = request.headers.get("Content-Type");
    try testing.expect(content_type != null);
    try testing.expectEqualStrings("application/json", content_type.?);
}

// ANCHOR: test_request_body
test "REST request with body" {
    var request = RestRequest.init(testing.allocator, .POST, "/users");
    defer request.deinit();

    const json_body = "{\"name\":\"Alice\",\"age\":30}";
    try request.setBody(json_body);

    try testing.expect(request.body != null);
    try testing.expectEqualStrings(json_body, request.body.?);
}
// ANCHOR_END: test_request_body

// ANCHOR: test_rest_response
test "create REST response" {
    var response = RestResponse.init(testing.allocator, .ok);
    defer response.deinit();

    try testing.expectEqual(HttpStatus.ok, response.status);
    try testing.expect(response.isSuccess());
}
// ANCHOR_END: test_rest_response

// ANCHOR: test_response_with_body
test "REST response with body and headers" {
    var response = RestResponse.init(testing.allocator, .created);
    defer response.deinit();

    try response.setBody("{\"id\":123}");
    try response.addHeader("Content-Type", "application/json");
    try response.addHeader("Location", "/users/123");

    try testing.expect(response.body != null);
    try testing.expectEqualStrings("{\"id\":123}", response.body.?);

    const location = response.headers.get("Location");
    try testing.expect(location != null);
    try testing.expectEqualStrings("/users/123", location.?);
}
// ANCHOR_END: test_response_with_body

// ANCHOR: test_rest_client
test "REST client GET request" {
    var client = try RestClient.init(testing.allocator, "https://api.example.com");
    defer client.deinit();

    var response = try client.get("/users/1");
    defer response.deinit();

    try testing.expect(response.isSuccess());
    try testing.expect(response.body != null);
    try testing.expect(std.mem.indexOf(u8, response.body.?, "Alice") != null);
}
// ANCHOR_END: test_rest_client

// ANCHOR: test_client_post
test "REST client POST request" {
    var client = try RestClient.init(testing.allocator, "https://api.example.com");
    defer client.deinit();

    const body = "{\"name\":\"Bob\"}";
    var response = try client.post("/users", body);
    defer response.deinit();

    try testing.expectEqual(HttpStatus.created, response.status);
    try testing.expect(response.body != null);
}
// ANCHOR_END: test_client_post

// ANCHOR: test_client_put
test "REST client PUT request" {
    var client = try RestClient.init(testing.allocator, "https://api.example.com");
    defer client.deinit();

    const body = "{\"name\":\"Alice Updated\"}";
    var response = try client.put("/users/1", body);
    defer response.deinit();

    try testing.expectEqual(HttpStatus.ok, response.status);
}
// ANCHOR_END: test_client_put

// ANCHOR: test_client_delete
test "REST client DELETE request" {
    var client = try RestClient.init(testing.allocator, "https://api.example.com");
    defer client.deinit();

    var response = try client.delete("/users/1");
    defer response.deinit();

    try testing.expectEqual(HttpStatus.no_content, response.status);
}
// ANCHOR_END: test_client_delete

// ANCHOR: test_client_default_headers
test "REST client with default headers" {
    var client = try RestClient.init(testing.allocator, "https://api.example.com");
    defer client.deinit();

    try client.setDefaultHeader("User-Agent", "Zig REST Client/1.0");
    try client.setDefaultHeader("Accept", "application/json");

    const user_agent = client.default_headers.get("User-Agent");
    try testing.expect(user_agent != null);
    try testing.expectEqualStrings("Zig REST Client/1.0", user_agent.?);
}
// ANCHOR_END: test_client_default_headers

// ANCHOR: test_resource_get
test "resource handler GET operation" {
    var handler = ResourceHandler.init(testing.allocator);

    var response = try handler.handleGet("123");
    defer response.deinit();

    try testing.expectEqual(HttpStatus.ok, response.status);
    try testing.expect(response.body != null);
    try testing.expect(std.mem.indexOf(u8, response.body.?, "123") != null);
}
// ANCHOR_END: test_resource_get

// ANCHOR: test_resource_create
test "resource handler CREATE operation" {
    var handler = ResourceHandler.init(testing.allocator);

    const data = "{\"name\":\"New Resource\"}";
    var response = try handler.handleCreate(data);
    defer response.deinit();

    try testing.expectEqual(HttpStatus.created, response.status);

    const location = response.headers.get("Location");
    try testing.expect(location != null);
    try testing.expectEqualStrings("/resources/123", location.?);
}
// ANCHOR_END: test_resource_create

// ANCHOR: test_resource_update
test "resource handler UPDATE operation" {
    var handler = ResourceHandler.init(testing.allocator);

    const data = "{\"name\":\"Updated Resource\"}";
    var response = try handler.handleUpdate("123", data);
    defer response.deinit();

    try testing.expectEqual(HttpStatus.ok, response.status);
    try testing.expect(response.body != null);
}
// ANCHOR_END: test_resource_update

// ANCHOR: test_resource_delete
test "resource handler DELETE operation" {
    var handler = ResourceHandler.init(testing.allocator);

    var response = try handler.handleDelete("123");
    defer response.deinit();

    try testing.expectEqual(HttpStatus.no_content, response.status);
    try testing.expectEqual(@as(?[]const u8, null), response.body);
}
// ANCHOR_END: test_resource_delete
