## Problem

You need to interact with GraphQL APIs, constructing queries with variables, handling mutations, parsing responses, and managing errors.

## Solution

Zig's string manipulation and JSON handling capabilities make it well-suited for building GraphQL clients. This recipe demonstrates query construction, variable management, and response parsing.

### Operation Types

GraphQL supports three operation types:

```zig
{{#include ../../../code/04-specialized/11-network-web/recipe_11_11.zig:graphql_operation}}
```

### GraphQL Query Building

The `GraphQLQuery` struct represents a GraphQL operation with variables:

```zig
pub const GraphQLQuery = struct {
    operation_type: OperationType,
    operation_name: ?[]const u8,
    query: []const u8,
    variables: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, operation_type: OperationType, query: []const u8) !GraphQLQuery {
        const owned_query = try allocator.dupe(u8, query);
        errdefer allocator.free(owned_query);

        return .{
            .operation_type = operation_type,
            .operation_name = null,
            .query = owned_query,
            .variables = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn setOperationName(self: *GraphQLQuery, name: []const u8) !void {
        if (self.operation_name) |old_name| {
            self.allocator.free(old_name);
        }
        self.operation_name = try self.allocator.dupe(u8, name);
    }

    pub fn addVariable(self: *GraphQLQuery, name: []const u8, value: []const u8) !void {
        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);

        const result = try self.variables.getOrPut(name);
        if (result.found_existing) {
            self.allocator.free(result.value_ptr.*);
            result.value_ptr.* = owned_value;
        } else {
            const owned_name = try self.allocator.dupe(u8, name);
            result.key_ptr.* = owned_name;
            result.value_ptr.* = owned_value;
        }
    }
};
```

### Building JSON Requests

GraphQL queries are sent as JSON with the query and optional variables:

```zig
pub fn buildRequest(self: *const GraphQLQuery) ![]const u8 {
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(self.allocator);

    try buffer.appendSlice(self.allocator, "{\"query\":\"");
    try self.escapeAndAppend(&buffer, self.query);
    try buffer.appendSlice(self.allocator, "\"");

    if (self.variables.count() > 0) {
        try buffer.appendSlice(self.allocator, ",\"variables\":{");
        var it = self.variables.iterator();
        var first = true;
        while (it.next()) |entry| {
            if (!first) try buffer.appendSlice(self.allocator, ",");
            try buffer.appendSlice(self.allocator, "\"");
            try buffer.appendSlice(self.allocator, entry.key_ptr.*);
            try buffer.appendSlice(self.allocator, "\":");
            try buffer.appendSlice(self.allocator, entry.value_ptr.*);
            first = false;
        }
        try buffer.appendSlice(self.allocator, "}");
    }

    try buffer.appendSlice(self.allocator, "}");

    return buffer.toOwnedSlice(self.allocator);
}

fn escapeAndAppend(self: *const GraphQLQuery, buffer: *std.ArrayList(u8), str: []const u8) !void {
    for (str) |c| {
        switch (c) {
            '\n' => try buffer.appendSlice(self.allocator, "\\n"),
            '\r' => try buffer.appendSlice(self.allocator, "\\r"),
            '\t' => try buffer.appendSlice(self.allocator, "\\t"),
            '"' => try buffer.appendSlice(self.allocator, "\\\""),
            '\\' => try buffer.appendSlice(self.allocator, "\\\\"),
            else => try buffer.append(self.allocator, c),
        }
    }
}
```

### Response Handling

GraphQL responses contain data and/or errors:

```zig
pub const GraphQLError = struct {
    message: []const u8,
    locations: ?std.ArrayList(ErrorLocation),
    path: ?std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub const ErrorLocation = struct {
        line: usize,
        column: usize,
    };

    pub fn init(allocator: std.mem.Allocator, message: []const u8) !GraphQLError {
        const owned_message = try allocator.dupe(u8, message);
        errdefer allocator.free(owned_message);

        return .{
            .message = owned_message,
            .locations = null,
            .path = null,
            .allocator = allocator,
        };
    }
};

pub const GraphQLResponse = struct {
    data: ?[]const u8,
    errors: ?std.ArrayList(GraphQLError),
    allocator: std.mem.Allocator,

    pub fn addError(self: *GraphQLResponse, error_msg: []const u8) !void {
        if (self.errors == null) {
            self.errors = std.ArrayList(GraphQLError){};
        }

        var err = try GraphQLError.init(self.allocator, error_msg);
        errdefer err.deinit();
        try self.errors.?.append(self.allocator, err);
    }

    pub fn hasErrors(self: *const GraphQLResponse) bool {
        if (self.errors) |errs| {
            return errs.items.len > 0;
        }
        return false;
    }
};
```

### GraphQL Client

The client manages endpoint configuration and request execution:

```zig
pub const GraphQLClient = struct {
    endpoint: []const u8,
    headers: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, endpoint: []const u8) !GraphQLClient {
        const owned_endpoint = try allocator.dupe(u8, endpoint);
        errdefer allocator.free(owned_endpoint);

        return .{
            .endpoint = owned_endpoint,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn setHeader(self: *GraphQLClient, name: []const u8, value: []const u8) !void {
        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);

        const result = try self.headers.getOrPut(name);
        if (result.found_existing) {
            self.allocator.free(result.value_ptr.*);
            result.value_ptr.* = owned_value;
        } else {
            const owned_name = try self.allocator.dupe(u8, name);
            result.key_ptr.* = owned_name;
            result.value_ptr.* = owned_value;
        }
    }

    pub fn execute(self: *GraphQLClient, query: *const GraphQLQuery) !GraphQLResponse {
        // In real implementation, use std.http.Client to POST to self.endpoint
        var response = GraphQLResponse.init(self.allocator);
        try response.setData("{\"user\":{\"id\":\"123\",\"name\":\"Alice\"}}");
        return response;
    }
};
```

### Fragments

GraphQL fragments allow reusing field selections:

```zig
pub const Fragment = struct {
    name: []const u8,
    on_type: []const u8,
    fields: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, on_type: []const u8, fields: []const u8) !Fragment {
        const owned_name = try allocator.dupe(u8, name);
        errdefer allocator.free(owned_name);

        const owned_on_type = try allocator.dupe(u8, on_type);
        errdefer allocator.free(owned_on_type);

        const owned_fields = try allocator.dupe(u8, fields);
        errdefer allocator.free(owned_fields);

        return .{
            .name = owned_name,
            .on_type = owned_on_type,
            .fields = owned_fields,
            .allocator = allocator,
        };
    }

    pub fn toGraphQL(self: *const Fragment) ![]const u8 {
        var buffer = std.ArrayList(u8){};
        defer buffer.deinit(self.allocator);

        try buffer.appendSlice(self.allocator, "fragment ");
        try buffer.appendSlice(self.allocator, self.name);
        try buffer.appendSlice(self.allocator, " on ");
        try buffer.appendSlice(self.allocator, self.on_type);
        try buffer.appendSlice(self.allocator, " { ");
        try buffer.appendSlice(self.allocator, self.fields);
        try buffer.appendSlice(self.allocator, " }");

        return buffer.toOwnedSlice(self.allocator);
    }
};
```

## Discussion

This recipe demonstrates the core concepts of GraphQL client implementation in Zig.

### GraphQL Basics

GraphQL is a query language that allows clients to request exactly the data they need:

**Query Example:**
```graphql
query GetUser($id: ID!) {
  user(id: $id) {
    id
    name
    email
  }
}
```

**Variables:**
```json
{
  "id": "123"
}
```

**Response:**
```json
{
  "data": {
    "user": {
      "id": "123",
      "name": "Alice",
      "email": "alice@example.com"
    }
  }
}
```

### JSON Escaping

The `escapeAndAppend()` method handles special characters in GraphQL queries:
- Newlines (`\n`) → `\\n`
- Quotes (`"`) → `\"`
- Backslashes (`\`) → `\\`

This ensures queries with multi-line strings or special characters are properly encoded in JSON.

### Variable Management

Variables are passed separately from the query for security and reusability:

```zig
var query = try GraphQLQuery.init(
    allocator,
    .query,
    "query($id: ID!) { user(id: $id) { name } }"
);
defer query.deinit();

try query.addVariable("id", "\"123\"");

const request = try query.buildRequest();
defer allocator.free(request);
// Results in: {"query":"...","variables":{"id":"123"}}
```

**Important:** Variable values must be valid JSON (note the quoted string `"\"123\""`).

### Memory Safety with HashMap Updates

The `getOrPut` pattern prevents memory leaks when updating HashMap entries:

```zig
const result = try self.variables.getOrPut(name);
if (result.found_existing) {
    self.allocator.free(result.value_ptr.*);  // Free old value
    result.value_ptr.* = owned_value;         // Store new value
} else {
    const owned_name = try self.allocator.dupe(u8, name);
    result.key_ptr.* = owned_name;
    result.value_ptr.* = owned_value;
}
```

This pattern:
1. Checks if the key exists
2. Frees the old value if found
3. Only allocates a new key for new entries
4. Prevents leaking the old value

### Error Handling

GraphQL can return partial data with errors:

```json
{
  "data": {
    "user": null
  },
  "errors": [
    {
      "message": "User not found",
      "locations": [{"line": 2, "column": 3}],
      "path": ["user"]
    }
  ]
}
```

The `GraphQLResponse` struct can hold both data and errors, allowing clients to handle partial failures gracefully.

### Mutations

Mutations use the same structure as queries but with different operation type:

```zig
var mutation = try GraphQLQuery.init(
    allocator,
    .mutation,
    "mutation($input: CreateUserInput!) { createUser(input: $input) { id } }"
);
defer mutation.deinit();

try mutation.addVariable("input", "{\"name\":\"Alice\",\"email\":\"alice@example.com\"}");
```

### Fragments

Fragments reduce duplication in complex queries:

```graphql
fragment UserFields on User {
  id
  name
  email
}

query GetUsers {
  users {
    ...UserFields
  }
  admins {
    ...UserFields
    role
  }
}
```

```zig
var fragment = try Fragment.init(
    allocator,
    "UserFields",
    "User",
    "id name email"
);
defer fragment.deinit();

const graphql = try fragment.toGraphQL();
defer allocator.free(graphql);
// "fragment UserFields on User { id name email }"
```

### Real Implementation Considerations

This recipe provides the foundation. A production implementation would:

**Use std.http.Client:**
```zig
pub fn execute(self: *GraphQLClient, query: *const GraphQLQuery) !GraphQLResponse {
    var client = std.http.Client{ .allocator = self.allocator };
    defer client.deinit();

    const request_body = try query.buildRequest();
    defer self.allocator.free(request_body);

    var req = try client.request(.POST, try std.Uri.parse(self.endpoint), .{
        .extra_headers = &.{
            .{ .name = "Content-Type", .value = "application/json" },
        },
    });
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = request_body.len };
    try req.send();
    try req.writeAll(request_body);
    try req.finish();

    // Parse response...
}
```

**Parse JSON responses:**
Use `std.json.parseFromSlice()` to parse the response data into structured types.

**Handle connection errors:**
- Network timeouts
- DNS resolution failures
- HTTP error status codes
- Invalid JSON responses

**Support introspection:**
GraphQL supports querying the schema itself for documentation and validation.

**Batch operations:**
Some GraphQL servers support batching multiple queries in a single request.

### Security Considerations

**Variable injection:**
Always use GraphQL variables instead of string interpolation:
```zig
// WRONG - injection risk
const query = try std.fmt.allocPrint(allocator, "{{ user(id: \"{s}\") {{ name }} }}", .{user_id});

// CORRECT - use variables
const query = "query($id: ID!) { user(id: $id) { name } }";
try graphql_query.addVariable("id", user_id_json);
```

**Query complexity:**
Implement query depth and complexity limits to prevent DoS attacks.

**Authentication:**
Use HTTP headers for authentication tokens:
```zig
try client.setHeader("Authorization", "Bearer YOUR_TOKEN");
```

**SSL/TLS:**
Always use HTTPS endpoints in production for encrypted communication.

### Performance Optimization

**Connection pooling:**
Reuse HTTP connections for multiple queries.

**Query batching:**
Combine multiple queries into a single request when possible.

**Caching:**
Cache query results based on variables and implement cache invalidation strategies.

**Compression:**
Enable gzip compression for large queries and responses.

## See Also

- Recipe 11.1: Making HTTP requests
- Recipe 11.2: Working with JSON APIs
- Recipe 11.6: Working with REST APIs

Full compilable example: `code/04-specialized/11-network-web/recipe_11_11.zig`
