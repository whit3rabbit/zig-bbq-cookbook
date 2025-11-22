## Problem

You need to interact with RESTful web services or build a REST API. REST (Representational State Transfer) is the standard architecture for web APIs, using HTTP methods (GET, POST, PUT, DELETE) and status codes to perform CRUD operations on resources. You need clean abstractions for requests, responses, and client operations.

## Solution

Build REST API components using Zig's type system and standard library. The solution includes HTTP method and status code enums, request/response structures, a REST client for consuming APIs, and resource handlers for building APIs.

### HTTP Methods and Status Codes

```zig
{{#include ../../../code/04-specialized/11-network-web/recipe_11_6.zig:http_method}}
```

```zig
{{#include ../../../code/04-specialized/11-network-web/recipe_11_6.zig:http_status}}
```

### Creating REST Requests

```zig
var request = RestRequest.init(testing.allocator, .GET, "/users");
defer request.deinit();

// Add query parameters
try request.addQuery("page", "2");
try request.addQuery("limit", "10");

// Add headers
try request.addHeader("Authorization", "Bearer token123");
try request.addHeader("Content-Type", "application/json");

// Set request body
const json_body = "{\"name\":\"Alice\",\"age\":30}";
try request.setBody(json_body);

// Build complete URL with query string
const url = try request.buildUrl();
defer testing.allocator.free(url);
// Result: "/users?page=2&limit=10"
```

### Handling REST Responses

```zig
var response = RestResponse.init(testing.allocator, .created);
defer response.deinit();

try response.setBody("{\"id\":123}");
try response.addHeader("Content-Type", "application/json");
try response.addHeader("Location", "/users/123");

// Check response status
if (response.isSuccess()) {
    // Process response body
    const body = response.body.?;
}
```

### Using the REST Client

The `RestClient` provides convenient methods for common REST operations:

```zig
var client = try RestClient.init(testing.allocator, "https://api.example.com");
defer client.deinit();

// Set default headers for all requests
try client.setDefaultHeader("User-Agent", "Zig REST Client/1.0");
try client.setDefaultHeader("Accept", "application/json");

// GET request
var response = try client.get("/users/1");
defer response.deinit();

if (response.isSuccess()) {
    // Response body contains user data
}
```

### REST CRUD Operations

**Create (POST):**
```zig
const body = "{\"name\":\"Bob\",\"email\":\"bob@example.com\"}";
var response = try client.post("/users", body);
defer response.deinit();

// 201 Created with Location header
if (response.status == .created) {
    const location = response.headers.get("Location");
    // location = "/users/123"
}
```

**Read (GET):**
```zig
var response = try client.get("/users/1");
defer response.deinit();

// 200 OK with user data in body
if (response.isSuccess()) {
    // Parse JSON from response.body
}
```

**Update (PUT/PATCH):**
```zig
// Full update with PUT
const updated = "{\"name\":\"Alice Updated\",\"email\":\"alice@example.com\"}";
var response = try client.put("/users/1", updated);
defer response.deinit();

// Partial update with PATCH
const patch = "{\"name\":\"Alice Smith\"}";
var patch_response = try client.patch("/users/1", patch);
defer patch_response.deinit();
```

**Delete (DELETE):**
```zig
var response = try client.delete("/users/1");
defer response.deinit();

// 204 No Content on successful deletion
if (response.status == .no_content) {
    // Resource deleted
}
```

### Building Resource Handlers

For server-side REST APIs, use resource handlers to process operations:

```zig
var handler = ResourceHandler.init(testing.allocator);

// Handle GET /resources/123
var response = try handler.handleGet("123");
defer response.deinit();
// Returns 200 OK with resource data

// Handle POST /resources
const data = "{\"name\":\"New Resource\"}";
var create_response = try handler.handleCreate(data);
defer create_response.deinit();
// Returns 201 Created with Location header

// Handle PUT /resources/123
const updated_data = "{\"name\":\"Updated Resource\"}";
var update_response = try handler.handleUpdate("123", updated_data);
defer update_response.deinit();
// Returns 200 OK with updated data

// Handle DELETE /resources/123
var delete_response = try handler.handleDelete("123");
defer delete_response.deinit();
// Returns 204 No Content
```

## Discussion

### REST Principles

REST APIs follow these core principles:

1. **Resource-Based**: URLs identify resources (`/users/1`, not `/getUser?id=1`)
2. **HTTP Methods**: Use standard verbs for operations
   - GET: Read resource
   - POST: Create resource
   - PUT: Replace resource
   - PATCH: Update resource partially
   - DELETE: Remove resource
3. **Stateless**: Each request contains all needed information
4. **Status Codes**: Use HTTP status codes to indicate result
5. **Representations**: Resources have representations (usually JSON)

### HTTP Method Semantics

**GET:**
- Retrieves a resource
- Safe (doesn't modify server state)
- Idempotent (same result on repeated calls)
- Cacheable
- No request body

**POST:**
- Creates a new resource
- Not idempotent (creates new resource each time)
- Returns 201 Created with Location header
- Request body contains new resource data

**PUT:**
- Replaces entire resource
- Idempotent (same result on repeated calls)
- Returns 200 OK or 204 No Content
- Request body contains complete resource

**PATCH:**
- Updates part of a resource
- May or may not be idempotent
- Returns 200 OK
- Request body contains partial updates

**DELETE:**
- Removes a resource
- Idempotent
- Returns 204 No Content
- Usually no response body

### Status Code Usage

The `HttpStatus` enum provides common codes with helper methods:

```zig
pub fn isSuccess(self: HttpStatus) bool {
    const code = @intFromEnum(self);
    return code >= 200 and code < 300;
}

pub fn isClientError(self: HttpStatus) bool {
    const code = @intFromEnum(self);
    return code >= 400 and code < 500;
}

pub fun isServerError(self: HttpStatus) bool {
    const code = @intFromEnum(self);
    return code >= 500 and code < 600;
}
```

**Success Codes (2xx):**
- `200 OK` - Request succeeded
- `201 Created` - Resource created
- `204 No Content` - Success with no body

**Client Error Codes (4xx):**
- `400 Bad Request` - Malformed request
- `401 Unauthorized` - Authentication required
- `403 Forbidden` - Authenticated but not authorized
- `404 Not Found` - Resource doesn't exist
- `409 Conflict` - Resource conflict (e.g., duplicate)
- `422 Unprocessable Entity` - Validation failed

**Server Error Codes (5xx):**
- `500 Internal Server Error` - Server error
- `502 Bad Gateway` - Upstream error
- `503 Service Unavailable` - Temporary failure

### Memory Management

All structures use explicit allocator passing and proper cleanup:

```zig
pub const RestRequest = struct {
    method: HttpMethod,
    path: []const u8,
    query: std.StringHashMap([]const u8),
    headers: std.StringHashMap([]const u8),
    body: ?[]const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *RestRequest) void {
        // Free all query parameters
        var query_it = self.query.iterator();
        while (query_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.query.deinit();

        // Free all headers
        var header_it = self.headers.iterator();
        while (header_it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();

        // Free body if present
        if (self.body) |body| {
            self.allocator.free(body);
        }
    }
};
```

The `deinit` methods ensure:
- All HashMap keys and values are freed
- Optional fields are checked before freeing
- No memory leaks even on error paths

### Error Handling with errdefer

The implementation uses `errdefer` to prevent leaks on allocation failures:

```zig
pub fn addHeader(self: *RestRequest, key: []const u8, value: []const u8) !void {
    const owned_key = try self.allocator.dupe(u8, key);
    errdefer self.allocator.free(owned_key);
    const owned_value = try self.allocator.dupe(u8, value);
    errdefer self.allocator.free(owned_value);
    try self.headers.put(owned_key, owned_value);
}
```

If `put()` fails after allocating both key and value, both `errdefer` statements trigger, freeing the allocations. This ensures no leaks on error paths.

### URL Building

The `buildUrl` method constructs URLs with query parameters:

```zig
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
```

This uses ArrayList for efficient string building and returns owned memory that the caller must free.

### Content Negotiation

REST APIs typically use headers for content negotiation:

```zig
// Request JSON
try request.addHeader("Accept", "application/json");

// Send JSON
try request.addHeader("Content-Type", "application/json");

// The server responds with appropriate Content-Type
const content_type = response.headers.get("Content-Type");
if (std.mem.eql(u8, content_type.?, "application/json")) {
    // Parse JSON from response.body
}
```

### Default Headers

The `RestClient` supports default headers applied to all requests:

```zig
var client = try RestClient.init(allocator, base_url);
defer client.deinit();

try client.setDefaultHeader("User-Agent", "MyApp/1.0");
try client.setDefaultHeader("Accept", "application/json");
try client.setDefaultHeader("Accept-Language", "en-US");

// All subsequent requests include these headers
var response = try client.get("/api/users");
```

This is useful for:
- API authentication tokens
- User-Agent identification
- Content type preferences
- Custom application headers

### Resource Handler Pattern

The `ResourceHandler` demonstrates server-side REST handling:

```zig
pub const ResourceHandler = struct {
    allocator: std.mem.Allocator,

    pub fn handleGet(self: *ResourceHandler, id: []const u8) !RestResponse {
        // Fetch resource by ID
        var response = RestResponse.init(self.allocator, .ok);
        try response.setBody(/* resource data */);
        try response.addHeader("Content-Type", "application/json");
        return response;
    }

    pub fn handleCreate(self: *ResourceHandler, data: []const u8) !RestResponse {
        // Create new resource
        var response = RestResponse.init(self.allocator, .created);
        try response.setBody(data);
        try response.addHeader("Location", "/resources/123");
        return response;
    }
};
```

Key patterns:
- Use appropriate status codes (200 OK, 201 Created, 204 No Content)
- Include Location header for created resources
- Return resource representation in response body
- Set Content-Type header for response format

### Integration with HTTP Client

In production, integrate with `std.http.Client`:

```zig
pub fn execute(self: *RestClient, request: *RestRequest) !RestResponse {
    var client = std.http.Client{ .allocator = self.allocator };
    defer client.deinit();

    const url = try request.buildUrl();
    defer self.allocator.free(url);

    // Build full URL with base_url
    var full_url = std.ArrayList(u8){};
    defer full_url.deinit(self.allocator);
    try full_url.appendSlice(self.allocator, self.base_url);
    try full_url.appendSlice(self.allocator, url);

    // Make HTTP request
    var req = try client.open(request.method, try std.Uri.parse(full_url.items), .{
        .server_header_buffer = /* buffer */,
    });
    defer req.deinit();

    // Add headers
    var it = request.headers.iterator();
    while (it.next()) |entry| {
        try req.headers.append(entry.key_ptr.*, entry.value_ptr.*);
    }

    // Send body if present
    if (request.body) |body| {
        req.transfer_encoding = .{ .content_length = body.len };
        try req.send(.{});
        try req.writeAll(body);
        try req.finish();
    } else {
        try req.send(.{});
        try req.finish();
    }

    try req.wait();

    // Build response
    var response = RestResponse.init(self.allocator, @enumFromInt(req.response.status));
    // ... read response body and headers
    return response;
}
```

### Limitations of This Implementation

This recipe provides educational patterns but lacks production features:

**Missing Features:**
- URL encoding for query parameters (special characters break URLs)
- Header validation (newlines could cause injection attacks)
- Request/response size limits (unbounded memory usage)
- Timeout configuration
- Redirect handling
- TLS certificate validation
- Connection pooling
- Retry logic
- Rate limiting

**Security Considerations:**
```zig
// NEEDED: URL encode query parameters
pub fn addQuery(self: *RestRequest, key: []const u8, value: []const u8) !void {
    // Validate no dangerous characters
    if (std.mem.indexOfAny(u8, key, "&=\r\n") != null) return error.InvalidQueryKey;
    if (std.mem.indexOfAny(u8, value, "\r\n") != null) return error.InvalidQueryValue;

    // URL encode the value
    const encoded_value = try urlEncode(self.allocator, value);
    // ... rest of implementation
}
```

For production use:
- Add proper URL encoding/decoding
- Validate all user-supplied input
- Implement request size limits
- Add timeout handling
- Use connection pooling for performance
- Handle redirects safely (limit redirect count)
- Validate TLS certificates

### Best Practices

**API Design:**
- Use plural nouns for collections (`/users`, not `/user`)
- Use nested resources for relationships (`/users/1/posts`)
- Version your API (`/v1/users`)
- Provide pagination for collections
- Use query parameters for filtering/sorting
- Return appropriate status codes
- Include helpful error messages

**Client Usage:**
- Always use `defer response.deinit()` after requests
- Check status codes before processing response
- Handle errors gracefully
- Set reasonable timeouts
- Retry failed requests with exponential backoff
- Cache responses when appropriate

**Error Handling:**
```zig
var response = try client.get("/users/1");
defer response.deinit();

if (response.status == .not_found) {
    // Handle 404 specifically
    return error.UserNotFound;
} else if (response.status.isClientError()) {
    // Handle other 4xx errors
    return error.BadRequest;
} else if (response.status.isServerError()) {
    // Handle 5xx errors
    return error.ServerError;
} else if (!response.isSuccess()) {
    // Unexpected status
    return error.UnexpectedStatus;
}

// Process successful response
```

## See Also

- Recipe 11.1: Making HTTP requests - Foundation for HTTP clients
- Recipe 11.2: Working with JSON APIs - Serialize/deserialize REST data
- Recipe 11.4: Building a simple HTTP server - Server-side REST handling
- Recipe 11.7: Handling cookies and sessions - State management for REST APIs

Full compilable example: `code/04-specialized/11-network-web/recipe_11_6.zig`
