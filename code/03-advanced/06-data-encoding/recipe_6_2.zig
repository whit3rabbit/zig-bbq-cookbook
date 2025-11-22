const std = @import("std");

// Test structures

const Person = struct {
    name: []const u8,
    age: u32,
    email: ?[]const u8 = null,
};

const User = struct {
    id: u32,
    name: []const u8,
    active: bool,
    score: ?f32 = null,
};

const Address = struct {
    street: []const u8,
    city: []const u8,
    zip: []const u8,
};

const PersonWithAddress = struct {
    name: []const u8,
    age: u32,
    address: Address,
};

const Config = struct {
    host: []const u8,
    port: u16,
    ssl: ?bool = null,
    timeout: ?u32 = null,
};

const Numbers = struct {
    int_val: i64,
    float_val: f64,
    optional_num: ?f32 = null,
};

// Helper functions

// ANCHOR: json_parsing
/// Parse JSON into a struct
pub fn parseJson(
    comptime T: type,
    allocator: std.mem.Allocator,
    json_text: []const u8,
) !std.json.Parsed(T) {
    return try std.json.parseFromSlice(T, allocator, json_text, .{});
}
// ANCHOR_END: json_parsing

/// Stringify value to buffer using FixedBufferAllocator to avoid heap allocations
/// This is more efficient than allocating on the heap and copying
pub fn stringifyToBuffer(value: anytype, buffer: []u8) ![]const u8 {
    var fba = std.heap.FixedBufferAllocator.init(buffer);
    const allocator = fba.allocator();

    const json_str = try std.json.Stringify.valueAlloc(allocator, value, .{});
    // json_str is already in buffer, no copy needed
    return json_str;
}

// ANCHOR: json_stringifying
/// Stringify value with allocator
pub fn stringifyAlloc(allocator: std.mem.Allocator, value: anytype) ![]u8 {
    return try std.json.Stringify.valueAlloc(allocator, value, .{});
}

/// Pretty print JSON
pub fn prettyPrint(value: anytype, writer: std.io.AnyWriter) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const json_str = try std.json.Stringify.valueAlloc(allocator, value, .{
        .whitespace = .indent_2,
    });
    try writer.writeAll(json_str);
}
// ANCHOR_END: json_stringifying

// ANCHOR: json_error_handling
/// Safe JSON parsing with error handling
pub fn parseJsonSafe(
    comptime T: type,
    allocator: std.mem.Allocator,
    json_text: []const u8,
) !std.json.Parsed(T) {
    return std.json.parseFromSlice(T, allocator, json_text, .{}) catch |err| switch (err) {
        error.UnexpectedEndOfInput => {
            std.debug.print("Incomplete JSON\n", .{});
            return error.InvalidJson;
        },
        error.InvalidCharacter => {
            std.debug.print("Invalid JSON character\n", .{});
            return error.InvalidJson;
        },
        error.UnexpectedToken => {
            std.debug.print("Unexpected JSON token\n", .{});
            return error.InvalidJson;
        },
        error.SyntaxError => {
            std.debug.print("Invalid JSON syntax\n", .{});
            return error.InvalidJson;
        },
        else => return err,
    };
}
// ANCHOR_END: json_error_handling

// Tests

test "parse json into struct" {
    const json_text =
        \\{"name":"Alice","age":30,"email":"alice@example.com"}
    ;

    const parsed = try parseJson(Person, std.testing.allocator, json_text);
    defer parsed.deinit();

    try std.testing.expectEqualStrings("Alice", parsed.value.name);
    try std.testing.expectEqual(@as(u32, 30), parsed.value.age);
    try std.testing.expectEqualStrings("alice@example.com", parsed.value.email.?);
}

test "stringify struct to json" {
    const person = Person{
        .name = "Bob",
        .age = 25,
        .email = "bob@example.com",
    };

    var buffer: [256]u8 = undefined;
    const result = try stringifyToBuffer(person, &buffer);

    try std.testing.expect(std.mem.indexOf(u8, result, "Bob") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "25") != null);
}

test "parse user with optional field" {
    const json =
        \\{"id":123,"name":"Alice","active":true,"score":98.5}
    ;

    const parsed = try parseJson(User, std.testing.allocator, json);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(u32, 123), parsed.value.id);
    try std.testing.expectEqualStrings("Alice", parsed.value.name);
    try std.testing.expect(parsed.value.active);
    try std.testing.expectEqual(@as(f32, 98.5), parsed.value.score.?);
}

test "parse user without optional field" {
    const json =
        \\{"id":456,"name":"Bob","active":false}
    ;

    const parsed = try parseJson(User, std.testing.allocator, json);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(u32, 456), parsed.value.id);
    try std.testing.expect(!parsed.value.active);
    try std.testing.expect(parsed.value.score == null);
}

test "stringify to buffer" {
    const data = .{ .x = 10, .y = 20 };

    var buffer: [128]u8 = undefined;
    const result = try stringifyToBuffer(data, &buffer);

    try std.testing.expect(std.mem.indexOf(u8, result, "10") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "20") != null);
}

test "stringify with allocator" {
    const data = .{ .name = "Test", .value = 42 };

    const result = try stringifyAlloc(std.testing.allocator, data);
    defer std.testing.allocator.free(result);

    try std.testing.expect(std.mem.indexOf(u8, result, "Test") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "42") != null);
}

test "pretty print json" {
    const data = .{
        .name = "Test",
        .items = .{ 1, 2, 3 },
    };

    var buffer: [256]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    try prettyPrint(data, stream.writer().any());

    const result = stream.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, result, "\n") != null);
}

test "parse array" {
    const json = "[1, 2, 3, 4, 5]";

    const parsed = try parseJson([]i32, std.testing.allocator, json);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 5), parsed.value.len);
    try std.testing.expectEqual(@as(i32, 1), parsed.value[0]);
    try std.testing.expectEqual(@as(i32, 5), parsed.value[4]);
}

test "nested structures" {
    const json =
        \\{
        \\  "name": "Alice",
        \\  "age": 30,
        \\  "address": {
        \\    "street": "123 Main St",
        \\    "city": "Springfield",
        \\    "zip": "12345"
        \\  }
        \\}
    ;

    const parsed = try parseJson(PersonWithAddress, std.testing.allocator, json);
    defer parsed.deinit();

    try std.testing.expectEqualStrings("Alice", parsed.value.name);
    try std.testing.expectEqual(@as(u32, 30), parsed.value.age);
    try std.testing.expectEqualStrings("123 Main St", parsed.value.address.street);
    try std.testing.expectEqualStrings("Springfield", parsed.value.address.city);
    try std.testing.expectEqualStrings("12345", parsed.value.address.zip);
}

test "optional fields" {
    const json =
        \\{"host":"localhost","port":8080,"ssl":true}
    ;

    const parsed = try parseJson(Config, std.testing.allocator, json);
    defer parsed.deinit();

    try std.testing.expectEqualStrings("localhost", parsed.value.host);
    try std.testing.expectEqual(@as(u16, 8080), parsed.value.port);
    try std.testing.expectEqual(@as(bool, true), parsed.value.ssl.?);
    try std.testing.expect(parsed.value.timeout == null);
}

test "dynamic json" {
    const json =
        \\{"name":"Alice","scores":[95,87,92]}
    ;

    const parsed = try parseJson(std.json.Value, std.testing.allocator, json);
    defer parsed.deinit();

    const obj = parsed.value.object;
    const name = obj.get("name").?.string;
    try std.testing.expectEqualStrings("Alice", name);

    const scores = obj.get("scores").?.array;
    try std.testing.expectEqual(@as(usize, 3), scores.items.len);
    try std.testing.expectEqual(@as(i64, 95), scores.items[0].integer);
}

test "parse numbers" {
    const json =
        \\{"int_val":42,"float_val":3.14159}
    ;

    const parsed = try parseJson(Numbers, std.testing.allocator, json);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(i64, 42), parsed.value.int_val);
    try std.testing.expectApproxEqRel(@as(f64, 3.14159), parsed.value.float_val, 0.0001);
}

test "special characters" {
    const data = .{
        .message = "Line 1\nLine 2\tTabbed",
        .quote = "He said \"Hello\"",
    };

    var buffer: [256]u8 = undefined;
    const result = try stringifyToBuffer(data, &buffer);
    try std.testing.expect(std.mem.indexOf(u8, result, "\\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "\\\"") != null);
}

test "empty object" {
    const json = "{}";

    const EmptyStruct = struct {};
    const parsed = try parseJson(EmptyStruct, std.testing.allocator, json);
    defer parsed.deinit();

    // Just verify it parses successfully
    _ = parsed.value;
}

test "empty array" {
    const json = "[]";

    const parsed = try parseJson([]i32, std.testing.allocator, json);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 0), parsed.value.len);
}

test "null value" {
    const json =
        \\{"name":"Alice","age":30,"email":null}
    ;

    const parsed = try parseJson(Person, std.testing.allocator, json);
    defer parsed.deinit();

    try std.testing.expectEqualStrings("Alice", parsed.value.name);
    try std.testing.expect(parsed.value.email == null);
}

test "boolean values" {
    const BoolData = struct {
        flag1: bool,
        flag2: bool,
    };

    const json =
        \\{"flag1":true,"flag2":false}
    ;

    const parsed = try parseJson(BoolData, std.testing.allocator, json);
    defer parsed.deinit();

    try std.testing.expect(parsed.value.flag1);
    try std.testing.expect(!parsed.value.flag2);
}

test "stringify boolean" {
    const data = .{ .enabled = true, .disabled = false };

    var buffer: [128]u8 = undefined;
    const result = try stringifyToBuffer(data, &buffer);

    try std.testing.expect(std.mem.indexOf(u8, result, "true") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "false") != null);
}

test "parse error handling" {
    const bad_json = "{invalid json";

    const result = parseJsonSafe(Person, std.testing.allocator, bad_json);
    try std.testing.expectError(error.InvalidJson, result);
}

test "incomplete json" {
    const incomplete = "{\"name\":\"Alice\"";

    const result = parseJsonSafe(Person, std.testing.allocator, incomplete);
    try std.testing.expectError(error.InvalidJson, result);
}

test "json to hashmap" {
    const json =
        \\{"key1":"value1","key2":"value2"}
    ;

    const parsed = try parseJson(std.json.Value, std.testing.allocator, json);
    defer parsed.deinit();

    const map = parsed.value.object;
    try std.testing.expectEqualStrings("value1", map.get("key1").?.string);
    try std.testing.expectEqualStrings("value2", map.get("key2").?.string);
}

test "array of objects" {
    const json =
        \\[{"name":"Alice","age":30},{"name":"Bob","age":25}]
    ;

    const PersonSimple = struct {
        name: []const u8,
        age: u32,
    };

    const parsed = try parseJson([]PersonSimple, std.testing.allocator, json);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 2), parsed.value.len);
    try std.testing.expectEqualStrings("Alice", parsed.value[0].name);
    try std.testing.expectEqual(@as(u32, 30), parsed.value[0].age);
    try std.testing.expectEqualStrings("Bob", parsed.value[1].name);
    try std.testing.expectEqual(@as(u32, 25), parsed.value[1].age);
}

test "nested arrays" {
    const json =
        \\[[1,2],[3,4],[5,6]]
    ;

    const parsed = try parseJson([][]i32, std.testing.allocator, json);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 3), parsed.value.len);
    try std.testing.expectEqual(@as(i32, 1), parsed.value[0][0]);
    try std.testing.expectEqual(@as(i32, 6), parsed.value[2][1]);
}

test "whitespace handling" {
    const json =
        \\  {  "name"  :  "Alice"  ,  "age"  :  30  }
    ;

    const PersonSimple = struct {
        name: []const u8,
        age: u32,
    };

    const parsed = try parseJson(PersonSimple, std.testing.allocator, json);
    defer parsed.deinit();

    try std.testing.expectEqualStrings("Alice", parsed.value.name);
    try std.testing.expectEqual(@as(u32, 30), parsed.value.age);
}

test "large numbers" {
    const LargeNums = struct {
        big_int: i64,
        big_float: f64,
    };

    const json =
        \\{"big_int":9007199254740991,"big_float":1.7976931348623157e308}
    ;

    const parsed = try parseJson(LargeNums, std.testing.allocator, json);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(i64, 9007199254740991), parsed.value.big_int);
    try std.testing.expect(parsed.value.big_float > 1e308);
}

test "unicode in strings" {
    const data = .{
        .english = "Hello",
        .japanese = "こんにちは",
        .emoji = "🎉",
    };

    var buffer: [256]u8 = undefined;
    const result = try stringifyToBuffer(data, &buffer);

    try std.testing.expect(std.mem.indexOf(u8, result, "Hello") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "こんにちは") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "🎉") != null);
}

test "roundtrip conversion" {
    const original = Person{
        .name = "Charlie",
        .age = 35,
        .email = "charlie@example.com",
    };

    // Stringify
    const json_str = try stringifyAlloc(std.testing.allocator, original);
    defer std.testing.allocator.free(json_str);

    // Parse back
    const parsed = try parseJson(Person, std.testing.allocator, json_str);
    defer parsed.deinit();

    try std.testing.expectEqualStrings(original.name, parsed.value.name);
    try std.testing.expectEqual(original.age, parsed.value.age);
}
