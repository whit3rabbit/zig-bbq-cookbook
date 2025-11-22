const std = @import("std");
const testing = std.testing;

// ANCHOR: graphql_operation
pub const OperationType = enum {
    query,
    mutation,
    subscription,

    pub fn toString(self: OperationType) []const u8 {
        return switch (self) {
            .query => "query",
            .mutation => "mutation",
            .subscription => "subscription",
        };
    }
};
// ANCHOR_END: graphql_operation

// ANCHOR: graphql_variable
pub const Variable = struct {
    name: []const u8,
    value: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, value: []const u8) !Variable {
        const owned_name = try allocator.dupe(u8, name);
        errdefer allocator.free(owned_name);

        const owned_value = try allocator.dupe(u8, value);

        return .{
            .name = owned_name,
            .value = owned_value,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Variable) void {
        self.allocator.free(self.name);
        self.allocator.free(self.value);
    }
};
// ANCHOR_END: graphql_variable

// ANCHOR: graphql_query
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

    pub fn deinit(self: *GraphQLQuery) void {
        self.allocator.free(self.query);

        if (self.operation_name) |name| {
            self.allocator.free(name);
        }

        var it = self.variables.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.variables.deinit();
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
};
// ANCHOR_END: graphql_query

// ANCHOR: graphql_response
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

    pub fn deinit(self: *GraphQLError) void {
        self.allocator.free(self.message);

        if (self.locations) |*locs| {
            locs.deinit(self.allocator);
        }

        if (self.path) |*p| {
            for (p.items) |item| {
                self.allocator.free(item);
            }
            p.deinit(self.allocator);
        }
    }
};

pub const GraphQLResponse = struct {
    data: ?[]const u8,
    errors: ?std.ArrayList(GraphQLError),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) GraphQLResponse {
        return .{
            .data = null,
            .errors = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *GraphQLResponse) void {
        if (self.data) |data| {
            self.allocator.free(data);
        }

        if (self.errors) |*errs| {
            for (errs.items) |*err| {
                err.deinit();
            }
            errs.deinit(self.allocator);
        }
    }

    pub fn setData(self: *GraphQLResponse, data: []const u8) !void {
        if (self.data) |old_data| {
            self.allocator.free(old_data);
        }
        self.data = try self.allocator.dupe(u8, data);
    }

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
// ANCHOR_END: graphql_response

// ANCHOR: graphql_client
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

    pub fn deinit(self: *GraphQLClient) void {
        self.allocator.free(self.endpoint);

        var it = self.headers.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();
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
        _ = query;
        // Simulate GraphQL execution
        var response = GraphQLResponse.init(self.allocator);
        try response.setData("{\"user\":{\"id\":\"123\",\"name\":\"Alice\"}}");
        return response;
    }

    pub fn executeWithErrors(self: *GraphQLClient, query: *const GraphQLQuery) !GraphQLResponse {
        _ = query;
        var response = GraphQLResponse.init(self.allocator);
        try response.addError("Field 'unknownField' doesn't exist on type 'User'");
        return response;
    }
};
// ANCHOR_END: graphql_client

// ANCHOR: graphql_fragment
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

    pub fn deinit(self: *Fragment) void {
        self.allocator.free(self.name);
        self.allocator.free(self.on_type);
        self.allocator.free(self.fields);
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
// ANCHOR_END: graphql_fragment

// ANCHOR: test_operation_type
test "operation type to string" {
    try testing.expectEqualStrings("query", OperationType.query.toString());
    try testing.expectEqualStrings("mutation", OperationType.mutation.toString());
    try testing.expectEqualStrings("subscription", OperationType.subscription.toString());
}
// ANCHOR_END: test_operation_type

// ANCHOR: test_variable
test "create and cleanup variable" {
    var variable = try Variable.init(testing.allocator, "userId", "\"123\"");
    defer variable.deinit();

    try testing.expectEqualStrings("userId", variable.name);
    try testing.expectEqualStrings("\"123\"", variable.value);
}
// ANCHOR_END: test_variable

// ANCHOR: test_query_basic
test "create basic query" {
    var query = try GraphQLQuery.init(testing.allocator, .query, "{ user { id name } }");
    defer query.deinit();

    try testing.expectEqual(OperationType.query, query.operation_type);
    try testing.expectEqualStrings("{ user { id name } }", query.query);
    try testing.expect(query.operation_name == null);
}
// ANCHOR_END: test_query_basic

// ANCHOR: test_query_with_name
test "query with operation name" {
    var query = try GraphQLQuery.init(testing.allocator, .query, "{ user { id } }");
    defer query.deinit();

    try query.setOperationName("GetUser");

    try testing.expect(query.operation_name != null);
    try testing.expectEqualStrings("GetUser", query.operation_name.?);
}
// ANCHOR_END: test_query_with_name

// ANCHOR: test_query_with_variables
test "query with variables" {
    var query = try GraphQLQuery.init(testing.allocator, .query, "query($id: ID!) { user(id: $id) { name } }");
    defer query.deinit();

    try query.addVariable("id", "\"123\"");

    try testing.expectEqual(@as(u32, 1), query.variables.count());

    const id_value = query.variables.get("id");
    try testing.expect(id_value != null);
    try testing.expectEqualStrings("\"123\"", id_value.?);
}
// ANCHOR_END: test_query_with_variables

// ANCHOR: test_build_request
test "build request JSON" {
    var query = try GraphQLQuery.init(testing.allocator, .query, "{ user { id } }");
    defer query.deinit();

    const request = try query.buildRequest();
    defer testing.allocator.free(request);

    try testing.expect(std.mem.indexOf(u8, request, "\"query\"") != null);
    try testing.expect(std.mem.indexOf(u8, request, "{ user { id } }") != null);
}
// ANCHOR_END: test_build_request

// ANCHOR: test_build_request_with_variables
test "build request with variables" {
    var query = try GraphQLQuery.init(testing.allocator, .query, "query($id: ID!) { user(id: $id) { name } }");
    defer query.deinit();

    try query.addVariable("id", "\"123\"");

    const request = try query.buildRequest();
    defer testing.allocator.free(request);

    try testing.expect(std.mem.indexOf(u8, request, "\"query\"") != null);
    try testing.expect(std.mem.indexOf(u8, request, "\"variables\"") != null);
    try testing.expect(std.mem.indexOf(u8, request, "\"id\"") != null);
}
// ANCHOR_END: test_build_request_with_variables

// ANCHOR: test_escape_query
test "escape special characters in query" {
    var query = try GraphQLQuery.init(testing.allocator, .query, "{ user { description } }");
    defer query.deinit();

    // Query with newline
    testing.allocator.free(query.query);
    query.query = try testing.allocator.dupe(u8, "{\n  user\n}");

    const request = try query.buildRequest();
    defer testing.allocator.free(request);

    try testing.expect(std.mem.indexOf(u8, request, "\\n") != null);
}
// ANCHOR_END: test_escape_query

// ANCHOR: test_graphql_error
test "create GraphQL error" {
    var err = try GraphQLError.init(testing.allocator, "Field not found");
    defer err.deinit();

    try testing.expectEqualStrings("Field not found", err.message);
    try testing.expect(err.locations == null);
    try testing.expect(err.path == null);
}
// ANCHOR_END: test_graphql_error

// ANCHOR: test_graphql_response
test "create GraphQL response with data" {
    var response = GraphQLResponse.init(testing.allocator);
    defer response.deinit();

    try response.setData("{\"user\":{\"id\":\"123\"}}");

    try testing.expect(response.data != null);
    try testing.expectEqualStrings("{\"user\":{\"id\":\"123\"}}", response.data.?);
    try testing.expect(!response.hasErrors());
}
// ANCHOR_END: test_graphql_response

// ANCHOR: test_graphql_response_with_errors
test "GraphQL response with errors" {
    var response = GraphQLResponse.init(testing.allocator);
    defer response.deinit();

    try response.addError("Syntax error");
    try response.addError("Unknown field");

    try testing.expect(response.hasErrors());
    try testing.expectEqual(@as(usize, 2), response.errors.?.items.len);
}
// ANCHOR_END: test_graphql_response_with_errors

// ANCHOR: test_client_init
test "create GraphQL client" {
    var client = try GraphQLClient.init(testing.allocator, "https://api.example.com/graphql");
    defer client.deinit();

    try testing.expectEqualStrings("https://api.example.com/graphql", client.endpoint);
}
// ANCHOR_END: test_client_init

// ANCHOR: test_client_headers
test "client with custom headers" {
    var client = try GraphQLClient.init(testing.allocator, "https://api.example.com/graphql");
    defer client.deinit();

    try client.setHeader("Authorization", "Bearer token123");
    try client.setHeader("X-Custom-Header", "custom-value");

    try testing.expectEqual(@as(u32, 2), client.headers.count());

    const auth = client.headers.get("Authorization");
    try testing.expect(auth != null);
    try testing.expectEqualStrings("Bearer token123", auth.?);
}
// ANCHOR_END: test_client_headers

// ANCHOR: test_client_execute
test "execute query" {
    var client = try GraphQLClient.init(testing.allocator, "https://api.example.com/graphql");
    defer client.deinit();

    var query = try GraphQLQuery.init(testing.allocator, .query, "{ user { id name } }");
    defer query.deinit();

    var response = try client.execute(&query);
    defer response.deinit();

    try testing.expect(response.data != null);
    try testing.expect(!response.hasErrors());
}
// ANCHOR_END: test_client_execute

// ANCHOR: test_client_execute_errors
test "execute query with errors" {
    var client = try GraphQLClient.init(testing.allocator, "https://api.example.com/graphql");
    defer client.deinit();

    var query = try GraphQLQuery.init(testing.allocator, .query, "{ unknownField }");
    defer query.deinit();

    var response = try client.executeWithErrors(&query);
    defer response.deinit();

    try testing.expect(response.hasErrors());
}
// ANCHOR_END: test_client_execute_errors

// ANCHOR: test_fragment
test "create fragment" {
    var fragment = try Fragment.init(
        testing.allocator,
        "UserFields",
        "User",
        "id name email",
    );
    defer fragment.deinit();

    try testing.expectEqualStrings("UserFields", fragment.name);
    try testing.expectEqualStrings("User", fragment.on_type);
    try testing.expectEqualStrings("id name email", fragment.fields);
}
// ANCHOR_END: test_fragment

// ANCHOR: test_fragment_to_graphql
test "fragment to GraphQL string" {
    var fragment = try Fragment.init(
        testing.allocator,
        "UserFields",
        "User",
        "id name",
    );
    defer fragment.deinit();

    const graphql = try fragment.toGraphQL();
    defer testing.allocator.free(graphql);

    try testing.expect(std.mem.indexOf(u8, graphql, "fragment UserFields") != null);
    try testing.expect(std.mem.indexOf(u8, graphql, "on User") != null);
    try testing.expect(std.mem.indexOf(u8, graphql, "id name") != null);
}
// ANCHOR_END: test_fragment_to_graphql

// ANCHOR: test_mutation
test "create mutation" {
    var mutation = try GraphQLQuery.init(
        testing.allocator,
        .mutation,
        "mutation($input: CreateUserInput!) { createUser(input: $input) { id } }",
    );
    defer mutation.deinit();

    try testing.expectEqual(OperationType.mutation, mutation.operation_type);

    try mutation.addVariable("input", "{\"name\":\"Alice\",\"email\":\"alice@example.com\"}");

    const request = try mutation.buildRequest();
    defer testing.allocator.free(request);

    try testing.expect(std.mem.indexOf(u8, request, "mutation") != null);
    try testing.expect(std.mem.indexOf(u8, request, "\"variables\"") != null);
}
// ANCHOR_END: test_mutation
