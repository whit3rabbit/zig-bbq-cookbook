// Recipe 11.2: Working with JSON APIs
// Target Zig Version: 0.15.2
//
// Educational demonstration of JSON API patterns in Zig.
// Shows JSON parsing, serialization, and API interaction patterns.
//
// Key concepts:
// - JSON parsing with std.json
// - Serializing Zig structs to JSON
// - Handling nested JSON structures
// - Error handling for malformed JSON
// - Working with dynamic JSON data
// - Type-safe API responses

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_json_parsing
// Parse JSON string to Zig value
test "basic json parsing" {
    const json_string =
        \\{"name": "Alice", "age": 30, "active": true}
    ;

    const parsed = try std.json.parseFromSlice(
        std.json.Value,
        testing.allocator,
        json_string,
        .{},
    );
    defer parsed.deinit();

    const root = parsed.value.object;
    try testing.expectEqualStrings("Alice", root.get("name").?.string);
    try testing.expectEqual(@as(i64, 30), root.get("age").?.integer);
    try testing.expect(root.get("active").?.bool);
}
// ANCHOR_END: basic_json_parsing

// ANCHOR: user_struct
// Define a user struct for JSON serialization
pub const User = struct {
    name: []const u8,
    age: u32,
    email: []const u8,
    active: bool = true,
};
// ANCHOR_END: user_struct

// ANCHOR: parse_to_struct
test "parse json to struct" {
    const json_string =
        \\{
        \\  "name": "Bob",
        \\  "age": 25,
        \\  "email": "bob@example.com",
        \\  "active": false
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        User,
        testing.allocator,
        json_string,
        .{},
    );
    defer parsed.deinit();

    const user = parsed.value;
    try testing.expectEqualStrings("Bob", user.name);
    try testing.expectEqual(@as(u32, 25), user.age);
    try testing.expectEqualStrings("bob@example.com", user.email);
    try testing.expect(!user.active);
}
// ANCHOR_END: parse_to_struct

// ANCHOR: stringify_struct
test "serialize struct to json" {
    const user = User{
        .name = "Charlie",
        .age = 35,
        .email = "charlie@example.com",
        .active = true,
    };

    const string = try std.json.Stringify.valueAlloc(testing.allocator, user, .{});
    defer testing.allocator.free(string);

    // Parse it back to verify
    const parsed = try std.json.parseFromSlice(
        User,
        testing.allocator,
        string,
        .{},
    );
    defer parsed.deinit();

    try testing.expectEqualStrings("Charlie", parsed.value.name);
    try testing.expectEqual(@as(u32, 35), parsed.value.age);
}
// ANCHOR_END: stringify_struct

// ANCHOR: nested_structures
pub const Address = struct {
    street: []const u8,
    city: []const u8,
    zip: []const u8,
};

pub const UserWithAddress = struct {
    name: []const u8,
    age: u32,
    address: Address,
};

test "nested json structures" {
    const json_string =
        \\{
        \\  "name": "Diana",
        \\  "age": 28,
        \\  "address": {
        \\    "street": "123 Main St",
        \\    "city": "Springfield",
        \\    "zip": "12345"
        \\  }
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        UserWithAddress,
        testing.allocator,
        json_string,
        .{},
    );
    defer parsed.deinit();

    const user = parsed.value;
    try testing.expectEqualStrings("Diana", user.name);
    try testing.expectEqualStrings("123 Main St", user.address.street);
    try testing.expectEqualStrings("Springfield", user.address.city);
}
// ANCHOR_END: nested_structures

// ANCHOR: array_handling
pub const UserList = struct {
    users: []User,
};

test "json array handling" {
    const json_string =
        \\{
        \\  "users": [
        \\    {"name": "Alice", "age": 30, "email": "alice@example.com"},
        \\    {"name": "Bob", "age": 25, "email": "bob@example.com"}
        \\  ]
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        UserList,
        testing.allocator,
        json_string,
        .{},
    );
    defer parsed.deinit();

    const user_list = parsed.value;
    try testing.expectEqual(@as(usize, 2), user_list.users.len);
    try testing.expectEqualStrings("Alice", user_list.users[0].name);
    try testing.expectEqualStrings("Bob", user_list.users[1].name);
}
// ANCHOR_END: array_handling

// ANCHOR: optional_fields
pub const UserWithOptionals = struct {
    name: []const u8,
    age: u32,
    email: ?[]const u8 = null,
    phone: ?[]const u8 = null,
};

test "optional json fields" {
    const json_with_email =
        \\{"name": "Eve", "age": 32, "email": "eve@example.com"}
    ;

    const parsed1 = try std.json.parseFromSlice(
        UserWithOptionals,
        testing.allocator,
        json_with_email,
        .{},
    );
    defer parsed1.deinit();

    try testing.expect(parsed1.value.email != null);
    try testing.expectEqualStrings("eve@example.com", parsed1.value.email.?);
    try testing.expect(parsed1.value.phone == null);

    const json_without_email =
        \\{"name": "Frank", "age": 40}
    ;

    const parsed2 = try std.json.parseFromSlice(
        UserWithOptionals,
        testing.allocator,
        json_without_email,
        .{},
    );
    defer parsed2.deinit();

    try testing.expect(parsed2.value.email == null);
}
// ANCHOR_END: optional_fields

// ANCHOR: error_handling
test "json parse error handling" {
    const invalid_json = "{ invalid json }";

    const result = std.json.parseFromSlice(
        User,
        testing.allocator,
        invalid_json,
        .{},
    );

    try testing.expectError(error.SyntaxError, result);
}
// ANCHOR_END: error_handling

// ANCHOR: api_response
pub const ApiResponse = struct {
    success: bool,
    message: []const u8,
    data: ?std.json.Value = null,
    error_code: ?[]const u8 = null,

    pub fn isSuccess(self: ApiResponse) bool {
        return self.success;
    }

    pub fn getErrorMessage(self: ApiResponse) []const u8 {
        if (self.error_code) |code| {
            return code;
        }
        return "Unknown error";
    }
};

test "api response structure" {
    const success_response =
        \\{
        \\  "success": true,
        \\  "message": "User created successfully"
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        ApiResponse,
        testing.allocator,
        success_response,
        .{},
        );
    defer parsed.deinit();

    const response = parsed.value;
    try testing.expect(response.isSuccess());
    try testing.expectEqualStrings("User created successfully", response.message);
}
// ANCHOR_END: api_response

// ANCHOR: custom_serialization
pub const Timestamp = struct {
    unix_timestamp: i64,

    pub fn jsonStringify(
        self: Timestamp,
        jw: anytype,
    ) !void {
        try jw.print("{d}", .{self.unix_timestamp});
    }
};

pub const Event = struct {
    name: []const u8,
    timestamp: Timestamp,
};

test "custom json serialization" {
    const event = Event{
        .name = "test_event",
        .timestamp = .{ .unix_timestamp = 1234567890 },
    };

    const string = try std.json.Stringify.valueAlloc(testing.allocator, event, .{});
    defer testing.allocator.free(string);

    // Verify timestamp is serialized as number
    try testing.expect(std.mem.indexOf(u8, string, "1234567890") != null);
}
// ANCHOR_END: custom_serialization

// ANCHOR: json_builder
pub const JsonBuilder = struct {
    allocator: std.mem.Allocator,
    buffer: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) JsonBuilder {
        return .{
            .allocator = allocator,
            .buffer = std.ArrayList(u8){},
        };
    }

    pub fn deinit(self: *JsonBuilder) void {
        self.buffer.deinit(self.allocator);
    }

    pub fn object(self: *JsonBuilder) !*JsonBuilder {
        try self.buffer.append(self.allocator, '{');
        return self;
    }

    pub fn endObject(self: *JsonBuilder) !*JsonBuilder {
        // Remove trailing comma if present
        if (self.buffer.items.len > 0 and self.buffer.items[self.buffer.items.len - 1] == ',') {
            _ = self.buffer.pop();
        }
        try self.buffer.append(self.allocator, '}');
        return self;
    }

    pub fn field(self: *JsonBuilder, name: []const u8, value: anytype) !*JsonBuilder {
        const writer = self.buffer.writer(self.allocator);
        try writer.print("\"{s}\":", .{name});

        // Serialize the value to a temporary string
        const value_json = try std.json.Stringify.valueAlloc(self.allocator, value, .{});
        defer self.allocator.free(value_json);

        try writer.writeAll(value_json);
        try self.buffer.append(self.allocator, ',');
        return self;
    }

    pub fn build(self: JsonBuilder) []const u8 {
        return self.buffer.items;
    }
};

test "json builder" {
    var builder = JsonBuilder.init(testing.allocator);
    defer builder.deinit();

    _ = try builder.object();
    _ = try builder.field("name", "Alice");
    _ = try builder.field("age", 30);
    _ = try builder.field("active", true);
    _ = try builder.endObject();

    const json = builder.build();

    // Parse to verify
    const parsed = try std.json.parseFromSlice(
        std.json.Value,
        testing.allocator,
        json,
        .{},
    );
    defer parsed.deinit();

    const obj = parsed.value.object;
    try testing.expectEqualStrings("Alice", obj.get("name").?.string);
    try testing.expectEqual(@as(i64, 30), obj.get("age").?.integer);
}
// ANCHOR_END: json_builder

// ANCHOR: pretty_print
test "pretty print json" {
    const user = User{
        .name = "Grace",
        .age = 27,
        .email = "grace@example.com",
        .active = true,
    };

    const string = try std.json.Stringify.valueAlloc(
        testing.allocator,
        user,
        .{ .whitespace = .indent_2 },
    );
    defer testing.allocator.free(string);

    // Verify it contains newlines and indentation
    try testing.expect(std.mem.indexOf(u8, string, "\n") != null);
    try testing.expect(std.mem.indexOf(u8, string, "  ") != null);
}
// ANCHOR_END: pretty_print

// ANCHOR: array_processing
test "processing json arrays" {
    const json_string =
        \\[1, 2, 3, 4, 5]
    ;

    const parsed = try std.json.parseFromSlice(
        []i64,
        testing.allocator,
        json_string,
        .{},
    );
    defer parsed.deinit();

    var sum: i64 = 0;
    for (parsed.value) |num| {
        sum += num;
    }

    try testing.expectEqual(@as(i64, 15), sum);
    try testing.expectEqual(@as(usize, 5), parsed.value.len);
}
// ANCHOR_END: array_processing

// ANCHOR: dynamic_fields
test "working with dynamic json" {
    const json_string =
        \\{
        \\  "field1": "value1",
        \\  "field2": 42,
        \\  "field3": true,
        \\  "nested": {"key": "value"}
        \\}
    ;

    const parsed = try std.json.parseFromSlice(
        std.json.Value,
        testing.allocator,
        json_string,
        .{},
    );
    defer parsed.deinit();

    const root = parsed.value.object;

    // Access different types
    try testing.expectEqualStrings("value1", root.get("field1").?.string);
    try testing.expectEqual(@as(i64, 42), root.get("field2").?.integer);
    try testing.expect(root.get("field3").?.bool);

    const nested = root.get("nested").?.object;
    try testing.expectEqualStrings("value", nested.get("key").?.string);
}
// ANCHOR_END: dynamic_fields

// Comprehensive test
test "comprehensive json api patterns" {
    // Parse user from JSON
    const json_user =
        \\{"name": "Helen", "age": 29, "email": "helen@example.com"}
    ;

    const parsed_user = try std.json.parseFromSlice(
        User,
        testing.allocator,
        json_user,
        .{},
    );
    defer parsed_user.deinit();

    // Serialize user back to JSON
    const json_output = try std.json.Stringify.valueAlloc(
        testing.allocator,
        parsed_user.value,
        .{},
    );
    defer testing.allocator.free(json_output);

    // Parse it again to verify round-trip
    const reparsed = try std.json.parseFromSlice(
        User,
        testing.allocator,
        json_output,
        .{},
    );
    defer reparsed.deinit();

    try testing.expectEqualStrings("Helen", reparsed.value.name);
    try testing.expectEqual(@as(u32, 29), reparsed.value.age);
}
