## Problem

You need to read and write JSON data, parse it into Zig structs, or work with dynamic JSON structures.

## Solution

### JSON Parsing

```zig
{{#include ../../../code/03-advanced/06-data-encoding/recipe_6_2.zig:json_parsing}}
```

### JSON Stringifying

```zig
{{#include ../../../code/03-advanced/06-data-encoding/recipe_6_2.zig:json_stringifying}}
```

### JSON Error Handling

```zig
{{#include ../../../code/03-advanced/06-data-encoding/recipe_6_2.zig:json_error_handling}}
```

## Discussion

### Parsing JSON into Structs

The most common use case is parsing JSON into known structs:

```zig
const User = struct {
    id: u32,
    name: []const u8,
    active: bool,
    score: ?f32 = null,
};

pub fn parseUser(allocator: std.mem.Allocator, json_text: []const u8) !std.json.Parsed(User) {
    return try std.json.parseFromSlice(
        User,
        allocator,
        json_text,
        .{},
    );
}

test "parse user" {
    const json =
        \\{"id":123,"name":"Alice","active":true,"score":98.5}
    ;

    const parsed = try parseUser(std.testing.allocator, json);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(u32, 123), parsed.value.id);
    try std.testing.expectEqualStrings("Alice", parsed.value.name);
    try std.testing.expect(parsed.value.active);
    try std.testing.expectEqual(@as(f32, 98.5), parsed.value.score.?);
}
```

### Writing JSON from Structs

Serialize structs to JSON:

```zig
pub fn stringifyToBuffer(value: anytype, buffer: []u8) ![]const u8 {
    var stream = std.io.fixedBufferStream(buffer);
    try std.json.stringify(value, .{}, stream.writer());
    return stream.getWritten();
}

pub fn stringifyAlloc(allocator: std.mem.Allocator, value: anytype) ![]u8 {
    var list: std.ArrayList(u8) = .{};
    errdefer list.deinit(allocator);

    try std.json.stringify(value, .{}, list.writer(allocator));
    return try list.toOwnedSlice(allocator);
}

test "stringify to buffer" {
    const data = .{ .x = 10, .y = 20 };

    var buffer: [128]u8 = undefined;
    const result = try stringifyToBuffer(data, &buffer);

    try std.testing.expect(std.mem.indexOf(u8, result, "10") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "20") != null);
}
```

### Pretty Printing JSON

Format JSON with indentation:

```zig
pub fn prettyPrint(
    value: anytype,
    writer: std.io.AnyWriter,
) !void {
    try std.json.stringify(value, .{
        .whitespace = .indent_2,
    }, writer);
}

test "pretty print" {
    const data = .{
        .name = "Test",
        .items = .{ 1, 2, 3 },
    };

    var buffer: [256]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    try prettyPrint(data, stream.writer().any());

    const result = stream.getWritten();
    // Should contain newlines and indentation
    try std.testing.expect(std.mem.indexOf(u8, result, "\n") != null);
}
```

### Parsing Arrays

Parse JSON arrays:

```zig
test "parse array" {
    const json = "[1, 2, 3, 4, 5]";

    const parsed = try std.json.parseFromSlice(
        []i32,
        std.testing.allocator,
        json,
        .{},
    );
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 5), parsed.value.len);
    try std.testing.expectEqual(@as(i32, 1), parsed.value[0]);
    try std.testing.expectEqual(@as(i32, 5), parsed.value[4]);
}
```

### Nested Structures

Handle nested JSON objects:

```zig
const Address = struct {
    street: []const u8,
    city: []const u8,
    zip: []const u8,
};

const Person = struct {
    name: []const u8,
    age: u32,
    address: Address,
};

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

    const parsed = try std.json.parseFromSlice(
        Person,
        std.testing.allocator,
        json,
        .{},
    );
    defer parsed.deinit();

    try std.testing.expectEqualStrings("Alice", parsed.value.name);
    try std.testing.expectEqualStrings("Springfield", parsed.value.address.city);
}
```

### Optional Fields

Handle optional JSON fields:

```zig
const Config = struct {
    host: []const u8,
    port: u16,
    ssl: ?bool = null,
    timeout: ?u32 = null,
};

test "optional fields" {
    const json =
        \\{"host":"localhost","port":8080,"ssl":true}
    ;

    const parsed = try std.json.parseFromSlice(
        Config,
        std.testing.allocator,
        json,
        .{},
    );
    defer parsed.deinit();

    try std.testing.expectEqual(@as(u16, 8080), parsed.value.port);
    try std.testing.expectEqual(@as(bool, true), parsed.value.ssl.?);
    try std.testing.expect(parsed.value.timeout == null);
}
```

### Dynamic JSON Values

Work with unknown JSON structures using `std.json.Value`:

```zig
test "dynamic json" {
    const json =
        \\{"name":"Alice","scores":[95,87,92]}
    ;

    const parsed = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        json,
        .{},
    );
    defer parsed.deinit();

    const obj = parsed.value.object;
    const name = obj.get("name").?.string;
    try std.testing.expectEqualStrings("Alice", name);

    const scores = obj.get("scores").?.array;
    try std.testing.expectEqual(@as(usize, 3), scores.items.len);
}
```

### Custom Serialization

Implement custom JSON serialization:

```zig
const Point = struct {
    x: f32,
    y: f32,

    pub fn jsonStringify(self: Point, jws: anytype) !void {
        try jws.beginObject();
        try jws.objectField("x");
        try jws.write(self.x);
        try jws.objectField("y");
        try jws.write(self.y);
        try jws.endObject();
    }
};

test "custom serialization" {
    const point = Point{ .x = 10.5, .y = 20.3 };

    var buffer: [128]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    try std.json.stringify(point, .{}, stream.writer());

    const result = stream.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, result, "10.5") != null);
}
```

### Custom Parsing

Implement custom JSON parsing:

```zig
const Color = struct {
    r: u8,
    g: u8,
    b: u8,

    pub fn jsonParse(
        allocator: std.mem.Allocator,
        source: anytype,
        options: std.json.ParseOptions,
    ) !Color {
        _ = allocator;
        _ = options;

        const value = try std.json.innerParse(std.json.Value, allocator, source, options);
        defer value.deinit();

        if (value.value == .string) {
            // Parse hex color like "#FF0000"
            const hex = value.value.string;
            if (hex[0] != '#' or hex.len != 7) return error.InvalidColor;

            return Color{
                .r = try std.fmt.parseInt(u8, hex[1..3], 16),
                .g = try std.fmt.parseInt(u8, hex[3..5], 16),
                .b = try std.fmt.parseInt(u8, hex[5..7], 16),
            };
        }

        return error.InvalidColor;
    }
};
```

### Streaming JSON Parsing

Parse large JSON files incrementally:

```zig
pub fn parseJsonStream(
    allocator: std.mem.Allocator,
    reader: std.io.AnyReader,
) !std.json.Parsed(std.json.Value) {
    const json_text = try reader.readAllAlloc(allocator, 1024 * 1024);
    defer allocator.free(json_text);

    return try std.json.parseFromSlice(
        std.json.Value,
        allocator,
        json_text,
        .{},
    );
}
```

### Handling Errors

Graceful error handling:

```zig
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
        else => return err,
    };
}
```

### Validating JSON Schema

Basic schema validation:

```zig
pub fn validateUser(user: anytype) !void {
    if (user.age < 0 or user.age > 150) {
        return error.InvalidAge;
    }

    if (user.name.len == 0) {
        return error.EmptyName;
    }
}

test "validate json" {
    const json =
        \\{"name":"","age":30}
    ;

    const parsed = try std.json.parseFromSlice(
        struct { name: []const u8, age: i32 },
        std.testing.allocator,
        json,
        .{},
    );
    defer parsed.deinit();

    const result = validateUser(parsed.value);
    try std.testing.expectError(error.EmptyName, result);
}
```

### Working with Maps

Parse JSON objects as hashmaps:

```zig
test "json to hashmap" {
    const json =
        \\{"key1":"value1","key2":"value2"}
    ;

    const parsed = try std.json.parseFromSlice(
        std.json.Value,
        std.testing.allocator,
        json,
        .{},
    );
    defer parsed.deinit();

    const map = parsed.value.object;
    try std.testing.expectEqualStrings("value1", map.get("key1").?.string);
    try std.testing.expectEqualStrings("value2", map.get("key2").?.string);
}
```

### Handling Numbers

Different number types in JSON:

```zig
const Numbers = struct {
    int_val: i64,
    float_val: f64,
    optional_num: ?f32 = null,
};

test "parse numbers" {
    const json =
        \\{"int_val":42,"float_val":3.14159}
    ;

    const parsed = try std.json.parseFromSlice(
        Numbers,
        std.testing.allocator,
        json,
        .{},
    );
    defer parsed.deinit();

    try std.testing.expectEqual(@as(i64, 42), parsed.value.int_val);
    try std.testing.expectApproxEqRel(@as(f64, 3.14159), parsed.value.float_val, 0.0001);
}
```

### Escaping Special Characters

JSON automatically handles escaping:

```zig
test "special characters" {
    const data = .{
        .message = "Line 1\nLine 2\tTabbed",
        .quote = "He said \"Hello\"",
    };

    var buffer: [256]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    try std.json.stringify(data, .{}, stream.writer());

    const result = stream.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, result, "\\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "\\\"") != null);
}
```

### Performance Considerations

**Parsing:**
- `parseFromSlice` allocates memory for parsed data
- Always call `.deinit()` on parsed results
- For large files, consider streaming approaches

**Writing:**
- Use `ArrayList` writer for dynamic size
- Use `fixedBufferStream` when size is known
- Pretty printing adds overhead

**Memory:**
```zig
// Good: Parse once, use, then free
const parsed = try std.json.parseFromSlice(T, allocator, json, .{});
defer parsed.deinit();
use(parsed.value);

// Bad: Multiple parses without cleanup
const p1 = try std.json.parseFromSlice(T, allocator, json, .{});
const p2 = try std.json.parseFromSlice(T, allocator, json, .{}); // Leak!
```

### Common Patterns

**Configuration files:**
```zig
pub fn loadConfig(allocator: std.mem.Allocator, path: []const u8) !Config {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const json_text = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(json_text);

    const parsed = try std.json.parseFromSlice(Config, allocator, json_text, .{});
    errdefer parsed.deinit();

    return parsed.value;
}
```

**API responses:**
```zig
pub fn parseApiResponse(
    allocator: std.mem.Allocator,
    response_body: []const u8,
) !ApiResult {
    const parsed = try std.json.parseFromSlice(
        ApiResult,
        allocator,
        response_body,
        .{ .ignore_unknown_fields = true },
    );
    defer parsed.deinit();

    return try allocator.dupe(ApiResult, &.{parsed.value});
}
```

### JSON Lines (JSONL)

Parse newline-delimited JSON:

```zig
pub fn parseJsonLines(
    comptime T: type,
    allocator: std.mem.Allocator,
    text: []const u8,
) ![]T {
    var results: std.ArrayList(T) = .{};
    errdefer results.deinit(allocator);

    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        const parsed = try std.json.parseFromSlice(T, allocator, line, .{});
        defer parsed.deinit();

        try results.append(allocator, parsed.value);
    }

    return try results.toOwnedSlice(allocator);
}
```

### Related Functions

- `std.json.parseFromSlice()` - Parse JSON into struct
- `std.json.stringify()` - Serialize to JSON
- `std.json.Value` - Dynamic JSON value
- `std.json.ParseOptions` - Parsing configuration
- `std.json.StringifyOptions` - Serialization options
- `std.json.innerParse()` - Custom parsing helper
