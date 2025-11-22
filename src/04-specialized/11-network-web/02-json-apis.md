# Recipe 11.2: Working with JSON APIs

## Problem

You want to work with JSON data in Zig - parsing JSON from APIs, serializing Zig structs to JSON, handling nested structures, and dealing with dynamic data. You need type-safe parsing with good performance.

## Solution

Zig provides `std.json` with two main approaches: typed parsing for known schemas and dynamic parsing for flexible data. This recipe demonstrates both approaches and common JSON patterns.

### Basic JSON Parsing

Parse JSON strings into dynamic values:

```zig
{{#include ../../../code/04-specialized/11-network-web/recipe_11_2.zig:basic_json_parsing}}
```

The `.?` unwraps the optional returned by `get()`, which is safe here because we know the keys exist.

### Parsing to Structs

For known schemas, parse directly to Zig structs:

```zig
{{#include ../../../code/04-specialized/11-network-web/recipe_11_2.zig:parse_to_struct}}
```

This provides compile-time type safety and better performance than dynamic parsing.

### Serializing Structs to JSON

Convert Zig structs back to JSON:

```zig
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
```

## Discussion

### Python vs Zig JSON Handling

The approaches differ in philosophy:

**Python (dynamic, runtime):**
```python
import json

# Parse JSON
data = json.loads('{"name": "Alice", "age": 30}')
print(data['name'])  # Runtime key access
print(data.get('missing', 'default'))  # Runtime default

# Serialize
user = {'name': 'Bob', 'age': 25}
json_str = json.dumps(user)

# Type checking is optional (via typing hints)
from typing import TypedDict
class User(TypedDict):
    name: str
    age: int
# But still runtime-checked
```

**Zig (typed, compile-time):**
```zig
// Type-safe parsing
const User = struct {
    name: []const u8,
    age: u32,
};

const parsed = try std.json.parseFromSlice(User, allocator, json_string, .{});
defer parsed.deinit();

// Compile-time field access
const name = parsed.value.name;  // Compile error if field doesn't exist

// Serialize with type safety
const json_str = try std.json.Stringify.valueAlloc(allocator, user, .{});
defer allocator.free(json_str);
```

Key differences:
- **Type Safety**: Zig catches missing fields at compile time; Python at runtime
- **Performance**: Zig parsing is faster (no interpreter overhead)
- **Memory**: Zig requires explicit allocation; Python uses GC
- **Flexibility**: Python handles unknown schemas easily; Zig uses `std.json.Value` for dynamic data
- **Error Handling**: Zig uses error unions; Python uses exceptions

### Nested Structures

Handle complex nested JSON:

```zig
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
```

Zig automatically handles nested struct parsing recursively.

### Array Handling

Parse JSON arrays:

```zig
pub const UserList = struct {
    users: []User,
};

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
```

### Optional Fields

Handle missing JSON fields with optionals:

```zig
pub const UserWithOptionals = struct {
    name: []const u8,
    age: u32,
    email: ?[]const u8 = null,
    phone: ?[]const u8 = null,
};

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
```

Fields marked as optional (`?T`) can be missing from the JSON.

### Error Handling

Handle malformed JSON gracefully:

```zig
const invalid_json = "{ invalid json }";

const result = std.json.parseFromSlice(
    User,
    testing.allocator,
    invalid_json,
    .{},
);

try testing.expectError(error.SyntaxError, result);
```

Zig's error handling makes parse failures explicit and recoverable.

### API Response Pattern

Structure API responses consistently:

```zig
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

try testing.expect(parsed.value.isSuccess());
```

### Custom Serialization

Control how types are serialized:

```zig
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

const event = Event{
    .name = "test_event",
    .timestamp = .{ .unix_timestamp = 1234567890 },
};

const string = try std.json.Stringify.valueAlloc(testing.allocator, event, .{});
defer testing.allocator.free(string);

// Verify timestamp is serialized as number
try testing.expect(std.mem.indexOf(u8, string, "1234567890") != null);
```

The `jsonStringify` method is automatically called during serialization, allowing custom formatting.

### JSON Builder Pattern

Build JSON programmatically:

```zig
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
```

Usage:

```zig
var builder = JsonBuilder.init(testing.allocator);
defer builder.deinit();

_ = try builder.object();
_ = try builder.field("name", "Alice");
_ = try builder.field("age", 30);
_ = try builder.field("active", true);
_ = try builder.endObject();

const json = builder.build();
```

### Pretty Printing

Format JSON with indentation:

```zig
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
```

The `.whitespace` option controls formatting:
- `.minified` - No whitespace (default)
- `.indent_2` - 2-space indentation
- `.indent_4` - 4-space indentation
- `.indent_tab` - Tab indentation

### Processing JSON Arrays

Work with arrays of primitives:

```zig
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
```

### Working with Dynamic JSON

Use `std.json.Value` when the structure is unknown:

```zig
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
```

**When to use each approach:**

**Typed Parsing (`parseFromSlice(MyStruct, ...)`):**
- Known, fixed schema
- Performance critical code
- Want compile-time type safety
- API contracts are well-defined

**Dynamic Parsing (`parseFromSlice(std.json.Value, ...)`):**
- Unknown or varying schema
- Working with user-provided JSON
- Need runtime introspection
- Implementing generic JSON tools

## Best Practices

1. **Use Typed Parsing**: Prefer struct types over `std.json.Value` for better safety and performance
2. **Always Defer Cleanup**: Use `defer parsed.deinit()` immediately after parsing
3. **Handle Optionals**: Use `?T` for fields that might be missing
4. **Validate Input**: Check for `error.SyntaxError` when parsing untrusted JSON
5. **Custom Serialization**: Implement `jsonStringify` for types needing special formatting
6. **Memory Management**: Remember that `parseFromSlice` allocates - always deinit
7. **Pretty Print for Debugging**: Use `.whitespace` option when logging JSON
8. **Error Context**: Wrap JSON errors with context about what failed
9. **Default Values**: Use struct defaults for optional fields that should have fallbacks
10. **Testing**: Test both happy path and malformed JSON

## Common Patterns

**Round-Trip Validation:**
```zig
const original = User{ .name = "test", .age = 30, .email = "test@test.com" };

// Serialize
const json_str = try std.json.Stringify.valueAlloc(allocator, original, .{});
defer allocator.free(json_str);

// Parse back
const parsed = try std.json.parseFromSlice(User, allocator, json_str, .{});
defer parsed.deinit();

// Verify
try testing.expectEqualStrings(original.name, parsed.value.name);
```

**Handling API Errors:**
```zig
const response_json = try fetchFromApi(url);
const response = try std.json.parseFromSlice(ApiResponse, allocator, response_json, .{});
defer response.deinit();

if (!response.value.isSuccess()) {
    std.debug.print("API Error: {s}\n", .{response.value.getErrorMessage()});
    return error.ApiRequestFailed;
}

// Process successful response...
```

**Partial Parsing:**
```zig
// Only parse the fields you need
const Metadata = struct {
    id: []const u8,
    timestamp: i64,
    // Ignore other fields
};

const parsed = try std.json.parseFromSlice(
    Metadata,
    allocator,
    large_json,
    .{ .ignore_unknown_fields = true },
);
defer parsed.deinit();
```

**Array Mapping:**
```zig
const json_users = try parseUserArray(json_string);
defer json_users.deinit();

var active_users = std.ArrayList(User).init(allocator);
defer active_users.deinit();

for (json_users.value.users) |user| {
    if (user.active) {
        try active_users.append(user);
    }
}
```

## Troubleshooting

**Parse Error: SyntaxError:**
- Check JSON is valid (use a JSON validator)
- Verify quotes are correct (must be double quotes, not single)
- Ensure trailing commas are removed
- Check for unescaped characters in strings

**Missing Field Error:**
- Make the field optional in your struct (`?T`)
- Add a default value to the struct field
- Use `.ignore_unknown_fields = true` in parse options

**Type Mismatch:**
- JSON numbers parse to `i64` by default
- Explicit cast if you need `u32`, `f64`, etc.
- Check that JSON booleans are `true`/`false`, not `1`/`0`

**Memory Leak:**
- Always `defer parsed.deinit()` after parsing
- For serialization, always `defer allocator.free(json_string)`
- Use testing allocator to detect leaks

**Performance Issues:**
- Use typed parsing instead of `std.json.Value` when possible
- For large files, consider streaming approaches
- Reuse allocators instead of creating new ones

## See Also

- Recipe 11.1: Making HTTP Requests - Fetching JSON from APIs
- Recipe 11.3: WebSocket Communication - Real-time JSON messages
- Recipe 11.6: Working with REST APIs - Complete REST client patterns
- Recipe 14.2: Unit Testing Strategies - Testing JSON parsing code

Full compilable example: `code/04-specialized/11-network-web/recipe_11_2.zig`
