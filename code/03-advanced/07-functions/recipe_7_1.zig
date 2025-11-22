const std = @import("std");

// ANCHOR: runtime_variadic
/// Sum using slice (runtime variadic)
pub fn sum(numbers: []const i32) i32 {
    var total: i32 = 0;
    for (numbers) |n| {
        total += n;
    }
    return total;
}
// ANCHOR_END: runtime_variadic

// ANCHOR: comptime_variadic
/// Sum using comptime tuple
pub fn sumComptime(args: anytype) @TypeOf(args[0]) {
    const ArgsType = @TypeOf(args);
    const args_type_info = @typeInfo(ArgsType);

    if (args_type_info != .@"struct") {
        @compileError("Expected tuple argument");
    }

    const fields = args_type_info.@"struct".fields;
    if (fields.len == 0) {
        @compileError("Need at least one argument");
    }

    var total: @TypeOf(args[0]) = 0;
    inline for (fields) |field| {
        total += @field(args, field.name);
    }
    return total;
}
// ANCHOR_END: comptime_variadic

// ANCHOR: generic_print
/// Generic print function
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
// ANCHOR_END: generic_print

/// Build string from multiple arguments
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

        const str = if (is_string)
            try std.fmt.allocPrint(allocator, "{s}", .{value})
        else
            try std.fmt.allocPrint(allocator, "{any}", .{value});
        defer allocator.free(str);
        try list.appendSlice(allocator, str);
    }

    return list.toOwnedSlice(allocator);
}

/// Find minimum value
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

/// Find maximum value
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

/// Log levels
pub const LogLevel = enum {
    debug,
    info,
    warn,
    err,
};

/// Logging with variable arguments
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

        if (i > 0) {
            try writer.writeAll(" ");
        }

        if (is_string) {
            try writer.print("{s}", .{value});
        } else {
            try writer.print("{any}", .{value});
        }
    }

    try writer.writeAll("\n");
}

/// Calculate average
pub fn average(numbers: []const f64) f64 {
    if (numbers.len == 0) return 0.0;

    var sum_total: f64 = 0.0;
    for (numbers) |n| {
        sum_total += n;
    }
    return sum_total / @as(f64, @floatFromInt(numbers.len));
}

// Tests

test "sum with slice" {
    const result1 = sum(&[_]i32{ 1, 2, 3 });
    try std.testing.expectEqual(@as(i32, 6), result1);

    const result2 = sum(&[_]i32{ 10, 20, 30, 40 });
    try std.testing.expectEqual(@as(i32, 100), result2);

    const result3 = sum(&[_]i32{});
    try std.testing.expectEqual(@as(i32, 0), result3);
}

test "sum comptime" {
    const result = sumComptime(.{ 1, 2, 3, 4, 5 });
    try std.testing.expectEqual(@as(i32, 15), result);

    const result2 = sumComptime(.{ 1.5, 2.5, 3.0 });
    try std.testing.expectEqual(@as(f32, 7.0), result2);
}

test "generic print" {
    var buffer: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);

    try print(fbs.writer(), .{ 42, "hello", 3.14 });

    try std.testing.expectEqualStrings("42 hello 3.14 ", fbs.getWritten());
}

test "build string" {
    const allocator = std.testing.allocator;

    const result = try buildString(allocator, .{ "Hello", " ", "World", "!" });
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello World!", result);
}

test "min and max" {
    try std.testing.expectEqual(@as(i32, 1), min(.{ 5, 3, 1, 4, 2 }));
    try std.testing.expectEqual(@as(i32, 5), max(.{ 5, 3, 1, 4, 2 }));

    try std.testing.expectEqual(@as(f32, -2.5), min(.{ 1.5, -2.5, 3.0 }));
    try std.testing.expectEqual(@as(f32, 3.0), max(.{ 1.5, -2.5, 3.0 }));
}

test "logging" {
    var buffer: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);

    try log(fbs.writer(), .info, .{ "User", 42, "logged in" });

    try std.testing.expect(std.mem.startsWith(u8, fbs.getWritten(), "[info]"));
    try std.testing.expect(std.mem.indexOf(u8, fbs.getWritten(), "User") != null);
}

test "average" {
    const result1 = average(&[_]f64{ 1.0, 2.0, 3.0, 4.0, 5.0 });
    try std.testing.expectEqual(@as(f64, 3.0), result1);

    const result2 = average(&[_]f64{});
    try std.testing.expectEqual(@as(f64, 0.0), result2);
}

test "single value" {
    try std.testing.expectEqual(@as(i32, 42), min(.{42}));
    try std.testing.expectEqual(@as(i32, 42), max(.{42}));
}

test "negative numbers" {
    try std.testing.expectEqual(@as(i32, -10), min(.{ -5, -3, -10, -1 }));
    try std.testing.expectEqual(@as(i32, -1), max(.{ -5, -3, -10, -1 }));
}

test "mixed types in print" {
    var buffer: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);

    try print(fbs.writer(), .{ 1, 2.5, "test", true });

    const written = fbs.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, written, "1 ") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "2.5") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "test") != null);
    try std.testing.expect(std.mem.indexOf(u8, written, "true") != null);
}

test "empty buildString" {
    const allocator = std.testing.allocator;

    const result = try buildString(allocator, .{});
    defer allocator.free(result);

    try std.testing.expectEqualStrings("", result);
}

test "log levels" {
    var buffer: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);

    try log(fbs.writer(), .debug, .{"Debug message"});
    try std.testing.expect(std.mem.startsWith(u8, fbs.getWritten(), "[debug]"));

    fbs.pos = 0;
    try log(fbs.writer(), .err, .{"Error occurred"});
    try std.testing.expect(std.mem.startsWith(u8, fbs.getWritten(), "[err]"));
}

test "large slice sum" {
    var numbers: [100]i32 = undefined;
    for (&numbers, 0..) |*n, i| {
        n.* = @intCast(i + 1);
    }

    const result = sum(&numbers);
    try std.testing.expectEqual(@as(i32, 5050), result);
}

test "float comptime sum" {
    const result = sumComptime(.{ 1.1, 2.2, 3.3 });
    try std.testing.expectApproxEqAbs(@as(f64, 6.6), result, 0.001);
}

test "single element average" {
    const result = average(&[_]f64{42.0});
    try std.testing.expectEqual(@as(f64, 42.0), result);
}
