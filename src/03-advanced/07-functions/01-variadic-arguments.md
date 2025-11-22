## Problem

You need to write a function that can accept a variable number of arguments, similar to variadic functions in other languages.

## Solution

### Runtime Variadic

```zig
{{#include ../../../code/03-advanced/07-functions/recipe_7_1.zig:runtime_variadic}}
```

### Comptime Variadic

```zig
{{#include ../../../code/03-advanced/07-functions/recipe_7_1.zig:comptime_variadic}}
```

### Generic Print

```zig
{{#include ../../../code/03-advanced/07-functions/recipe_7_1.zig:generic_print}}
```

## Discussion

### Compile-Time Variadic Functions

Use tuples for compile-time known arguments (see code examples above).
    }
    return total;
}

test "sum comptime" {
    const result = sumComptime(.{ 1, 2, 3, 4, 5 });
    try std.testing.expectEqual(@as(i32, 15), result);

    const result2 = sumComptime(.{ 1.5, 2.5, 3.0 });
    try std.testing.expectEqual(@as(f32, 7.0), result2);
}
```

### Generic Print Function

Accept any types at compile time:

```zig
pub fn print(writer: anytype, args: anytype) !void {
    const ArgsType = @TypeOf(args);
    const args_type_info = @typeInfo(ArgsType);

    if (args_type_info != .@"struct") {
        @compileError("Expected tuple argument");
    }

    inline for (args_type_info.@"struct".fields) |field| {
        const value = @field(args, field.name);
        const ValueType = @TypeOf(value);
        const value_type_info = @typeInfo(ValueType);

        // Check if it's a string-like type (pointer to u8 array or slice)
        const is_string = switch (value_type_info) {
            .pointer => |ptr_info| blk: {
                const child_info = @typeInfo(ptr_info.child);
                break :blk switch (child_info) {
                    .array => |arr_info| arr_info.child == u8,
                    else => ptr_info.child == u8,
                };
            },
            else => false,
        };

        if (is_string) {
            try writer.print("{s} ", .{value});
        } else {
            try writer.print("{any} ", .{value});
        }
    }
}

test "generic print" {
    var buffer: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);

    try print(fbs.writer(), .{ 42, "hello", 3.14 });

    try std.testing.expectEqualStrings("42 hello 3.14 ", fbs.getWritten());
}
```

### Formatted String Builder

Build strings with variable arguments:

```zig
pub fn buildString(
    allocator: std.mem.Allocator,
    args: anytype,
) ![]u8 {
    var list = std.ArrayList(u8){};
    errdefer list.deinit(allocator);

    const ArgsType = @TypeOf(args);
    const args_type_info = @typeInfo(ArgsType);

    inline for (args_type_info.@"struct".fields) |field| {
        const value = @field(args, field.name);
        const str = try std.fmt.allocPrint(allocator, "{any}", .{value});
        defer allocator.free(str);
        try list.appendSlice(allocator, str);
    }

    return list.toOwnedSlice(allocator);
}

test "build string" {
    const allocator = std.testing.allocator;

    const result = try buildString(allocator, .{ "Hello", " ", "World", "!" });
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello World!", result);
}
```

### Minimum/Maximum Functions

Find min/max of any number of values:

```zig
pub fn min(args: anytype) @TypeOf(args[0]) {
    const ArgsType = @TypeOf(args);
    const args_type_info = @typeInfo(ArgsType);

    if (args_type_info != .@"struct") {
        @compileError("Expected tuple argument");
    }

    const fields = args_type_info.@"struct".fields;
    if (fields.len == 0) {
        @compileError("Need at least one argument");
    }

    var minimum = args[0];
    inline for (fields[1..]) |field| {
        const value = @field(args, field.name);
        if (value < minimum) {
            minimum = value;
        }
    }
    return minimum;
}

pub fn max(args: anytype) @TypeOf(args[0]) {
    const ArgsType = @TypeOf(args);
    const args_type_info = @typeInfo(ArgsType);

    if (args_type_info != .@"struct") {
        @compileError("Expected tuple argument");
    }

    const fields = args_type_info.@"struct".fields;
    if (fields.len == 0) {
        @compileError("Need at least one argument");
    }

    var maximum = args[0];
    inline for (fields[1..]) |field| {
        const value = @field(args, field.name);
        if (value > maximum) {
            maximum = value;
        }
    }
    return maximum;
}

test "min and max" {
    try std.testing.expectEqual(@as(i32, 1), min(.{ 5, 3, 1, 4, 2 }));
    try std.testing.expectEqual(@as(i32, 5), max(.{ 5, 3, 1, 4, 2 }));

    try std.testing.expectEqual(@as(f32, -2.5), min(.{ 1.5, -2.5, 3.0 }));
    try std.testing.expectEqual(@as(f32, 3.0), max(.{ 1.5, -2.5, 3.0 }));
}
```

### Type-Safe Logging

Log with type-checked arguments:

```zig
pub const LogLevel = enum {
    debug,
    info,
    warn,
    err,
};

pub fn log(
    writer: anytype,
    level: LogLevel,
    args: anytype,
) !void {
    try writer.print("[{s}] ", .{@tagName(level)});

    const ArgsType = @TypeOf(args);
    const args_type_info = @typeInfo(ArgsType);

    inline for (args_type_info.@"struct".fields, 0..) |field, i| {
        const value = @field(args, field.name);
        if (i > 0) {
            try writer.writeAll(" ");
        }
        try writer.print("{any}", .{value});
    }

    try writer.writeAll("\n");
}

test "logging" {
    var buffer: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);

    try log(fbs.writer(), .info, .{ "User", 42, "logged in" });

    try std.testing.expect(std.mem.startsWith(u8, fbs.getWritten(), "[info]"));
    try std.testing.expect(std.mem.indexOf(u8, fbs.getWritten(), "User") != null);
}
```

### Slice-Based Variadic for Runtime

Use slices when argument count is only known at runtime:

```zig
pub fn average(numbers: []const f64) f64 {
    if (numbers.len == 0) return 0.0;

    var sum: f64 = 0.0;
    for (numbers) |n| {
        sum += n;
    }
    return sum / @as(f64, @floatFromInt(numbers.len));
}

test "average" {
    const result1 = average(&[_]f64{ 1.0, 2.0, 3.0, 4.0, 5.0 });
    try std.testing.expectEqual(@as(f64, 3.0), result1);

    const result2 = average(&[_]f64{});
    try std.testing.expectEqual(@as(f64, 0.0), result2);
}
```

### Best Practices

**Compile-Time vs Runtime:**
```zig
// Use tuples for compile-time known arguments
const result = sum(.{ 1, 2, 3 }); // Comptime

// Use slices for runtime variable arguments
const numbers = try getUserInput();
const result = sum(numbers); // Runtime
```

**Type Safety:**
- Tuples provide compile-time type checking
- All tuple elements are accessible at comptime
- Use `anytype` parameter to accept tuples
- Use `@TypeOf` and `@typeInfo` to introspect

**Error Handling:**
```zig
pub fn processAll(allocator: std.mem.Allocator, items: anytype) !void {
    inline for (@typeInfo(@TypeOf(items)).@"struct".fields) |field| {
        const item = @field(items, field.name);
        try processItem(allocator, item);
    }
}
```

**Performance:**
- Tuple-based functions are inlined at compile time
- Slice-based functions have runtime overhead
- Use tuples when possible for zero-cost abstraction

### Related Functions

- `@TypeOf()` - Get type of expression
- `@typeInfo()` - Get reflection information
- `@field()` - Access struct/tuple field
- `@tagName()` - Get enum tag name as string
- `inline for` - Unroll loops at compile time
- `anytype` - Accept any type parameter
