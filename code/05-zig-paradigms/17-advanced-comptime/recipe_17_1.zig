// Recipe 17.1: Type-Level Pattern Matching
// This recipe demonstrates how to use compile-time reflection to match and
// transform types based on patterns, implementing generic functions that
// behave differently for specific type families.

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_type_matching
/// Check if a type is a numeric type (integer or float)
fn isNumeric(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .int, .comptime_int, .float, .comptime_float => true,
        else => false,
    };
}

test "basic type matching" {
    try testing.expect(isNumeric(i32));
    try testing.expect(isNumeric(u64));
    try testing.expect(isNumeric(f32));
    try testing.expect(isNumeric(f64));
    try testing.expect(!isNumeric(bool));
    try testing.expect(!isNumeric([]const u8));
}
// ANCHOR_END: basic_type_matching

// ANCHOR: type_categories
/// Categorize types into broad families
const TypeCategory = enum {
    integer,
    float,
    pointer,
    array,
    slice,
    @"struct",
    @"enum",
    @"union",
    optional,
    error_union,
    other,
};

fn categorizeType(comptime T: type) TypeCategory {
    return switch (@typeInfo(T)) {
        .int, .comptime_int => .integer,
        .float, .comptime_float => .float,
        .pointer => .pointer,
        .array => .array,
        .@"struct" => .@"struct",
        .@"enum" => .@"enum",
        .@"union" => .@"union",
        .optional => .optional,
        .error_union => .error_union,
        else => .other,
    };
}

test "type categorization" {
    try testing.expectEqual(TypeCategory.integer, categorizeType(i32));
    try testing.expectEqual(TypeCategory.float, categorizeType(f64));
    try testing.expectEqual(TypeCategory.pointer, categorizeType(*u8));
    try testing.expectEqual(TypeCategory.array, categorizeType([10]u8));
    try testing.expectEqual(TypeCategory.optional, categorizeType(?i32));
}
// ANCHOR_END: type_categories

// ANCHOR: generic_zero
/// Return the "zero" value for any numeric type
fn zero(comptime T: type) T {
    const info = @typeInfo(T);

    return switch (info) {
        .int, .comptime_int => 0,
        .float, .comptime_float => 0.0,
        else => @compileError("zero() only works with numeric types"),
    };
}

test "generic zero value" {
    try testing.expectEqual(@as(i32, 0), zero(i32));
    try testing.expectEqual(@as(u64, 0), zero(u64));
    try testing.expectEqual(@as(f32, 0.0), zero(f32));
    try testing.expectEqual(@as(f64, 0.0), zero(f64));
}
// ANCHOR_END: generic_zero

// ANCHOR: container_depth
/// Calculate the nesting depth of container types (arrays, slices, pointers)
fn containerDepth(comptime T: type) comptime_int {
    const info = @typeInfo(T);

    return switch (info) {
        .pointer => |ptr| 1 + containerDepth(ptr.child),
        .array => |arr| 1 + containerDepth(arr.child),
        .optional => |opt| 1 + containerDepth(opt.child),
        else => 0,
    };
}

test "container depth calculation" {
    try testing.expectEqual(0, containerDepth(i32));
    try testing.expectEqual(1, containerDepth(*i32));
    try testing.expectEqual(2, containerDepth(**i32));
    try testing.expectEqual(1, containerDepth([10]u8));
    try testing.expectEqual(2, containerDepth([5][10]u8));
    try testing.expectEqual(1, containerDepth(?i32));
    try testing.expectEqual(2, containerDepth(?*i32));
}
// ANCHOR_END: container_depth

// ANCHOR: unwrap_type
/// Unwrap nested container types to get the innermost child type
fn unwrapType(comptime T: type) type {
    const info = @typeInfo(T);

    return switch (info) {
        .pointer => |ptr| unwrapType(ptr.child),
        .array => |arr| unwrapType(arr.child),
        .optional => |opt| unwrapType(opt.child),
        else => T,
    };
}

test "unwrap nested types" {
    try testing.expectEqual(i32, unwrapType(i32));
    try testing.expectEqual(i32, unwrapType(*i32));
    try testing.expectEqual(i32, unwrapType(**i32));
    try testing.expectEqual(u8, unwrapType([10]u8));
    try testing.expectEqual(u8, unwrapType([5][10]u8));
    try testing.expectEqual(i32, unwrapType(?i32));
    try testing.expectEqual(i32, unwrapType(?*i32));
}
// ANCHOR_END: unwrap_type

// ANCHOR: size_based_dispatch
/// Choose an implementation based on type size
fn processValue(comptime T: type, value: T) void {
    const size = @sizeOf(T);

    if (size <= 8) {
        // Fast path for small types that fit in a register
        processSmall(T, value);
    } else {
        // Different strategy for larger types
        processLarge(T, value);
    }
}

fn processSmall(comptime T: type, value: T) void {
    _ = value;
    std.debug.print("Processing small type {} (size: {} bytes)\n", .{ T, @sizeOf(T) });
}

fn processLarge(comptime T: type, value: T) void {
    _ = value;
    std.debug.print("Processing large type {} (size: {} bytes)\n", .{ T, @sizeOf(T) });
}

test "size-based dispatch" {
    processValue(u8, 42);
    processValue(u64, 1000);
    processValue([100]u8, [_]u8{0} ** 100);
}
// ANCHOR_END: size_based_dispatch

// ANCHOR: signedness_matching
/// Determine if an integer type is signed or unsigned
fn isSigned(comptime T: type) bool {
    const info = @typeInfo(T);

    return switch (info) {
        .int => |int_info| int_info.signedness == .signed,
        else => @compileError("isSigned() only works with integer types"),
    };
}

/// Get the corresponding signed or unsigned version of an integer type
fn toggleSignedness(comptime T: type) type {
    const info = @typeInfo(T);

    return switch (info) {
        .int => |int_info| {
            const new_signedness: std.builtin.Signedness =
                if (int_info.signedness == .signed) .unsigned else .signed;

            return @Type(.{
                .int = .{
                    .signedness = new_signedness,
                    .bits = int_info.bits
                }
            });
        },
        else => @compileError("toggleSignedness() only works with integer types"),
    };
}

test "signedness matching" {
    try testing.expect(isSigned(i32));
    try testing.expect(!isSigned(u32));

    try testing.expectEqual(u32, toggleSignedness(i32));
    try testing.expectEqual(i32, toggleSignedness(u32));
    try testing.expectEqual(u64, toggleSignedness(i64));
    try testing.expectEqual(i8, toggleSignedness(u8));
}
// ANCHOR_END: signedness_matching

// ANCHOR: struct_field_matching
/// Check if a struct has a specific field
fn hasField(comptime T: type, comptime field_name: []const u8) bool {
    const info = @typeInfo(T);

    return switch (info) {
        .@"struct" => |struct_info| {
            inline for (struct_info.fields) |field| {
                if (std.mem.eql(u8, field.name, field_name)) {
                    return true;
                }
            }
            return false;
        },
        else => false,
    };
}

/// Get the type of a specific field if it exists
fn fieldType(comptime T: type, comptime field_name: []const u8) ?type {
    const info = @typeInfo(T);

    return switch (info) {
        .@"struct" => |struct_info| {
            inline for (struct_info.fields) |field| {
                if (std.mem.eql(u8, field.name, field_name)) {
                    return field.type;
                }
            }
            return null;
        },
        else => null,
    };
}

const TestStruct = struct {
    id: u32,
    name: []const u8,
    value: f64,
};

test "struct field matching" {
    try testing.expect(hasField(TestStruct, "id"));
    try testing.expect(hasField(TestStruct, "name"));
    try testing.expect(hasField(TestStruct, "value"));
    try testing.expect(!hasField(TestStruct, "missing"));

    try testing.expectEqual(u32, fieldType(TestStruct, "id").?);
    try testing.expectEqual([]const u8, fieldType(TestStruct, "name").?);
    try testing.expectEqual(f64, fieldType(TestStruct, "value").?);
    try testing.expectEqual(@as(?type, null), fieldType(TestStruct, "missing"));
}
// ANCHOR_END: struct_field_matching

// ANCHOR: polymorphic_serializer
/// Generic serializer that adapts to different type patterns
fn serialize(comptime T: type, value: T, writer: anytype) !void {
    const info = @typeInfo(T);

    switch (info) {
        .int, .comptime_int => try writer.print("{d}", .{value}),
        .float, .comptime_float => try writer.print("{d:.2}", .{value}),
        .bool => try writer.writeAll(if (value) "true" else "false"),
        .pointer => |ptr| {
            if (ptr.size == .slice) {
                if (ptr.child == u8) {
                    // Special case for string slices
                    try writer.print("\"{s}\"", .{value});
                } else {
                    try writer.writeAll("[");
                    for (value, 0..) |item, i| {
                        if (i > 0) try writer.writeAll(", ");
                        try serialize(ptr.child, item, writer);
                    }
                    try writer.writeAll("]");
                }
            } else {
                try writer.writeAll("(pointer)");
            }
        },
        .array => |arr| {
            try writer.writeAll("[");
            for (value, 0..) |item, i| {
                if (i > 0) try writer.writeAll(", ");
                try serialize(arr.child, item, writer);
            }
            try writer.writeAll("]");
        },
        .optional => {
            if (value) |val| {
                try serialize(@TypeOf(val), val, writer);
            } else {
                try writer.writeAll("null");
            }
        },
        else => try writer.writeAll("(unsupported)"),
    }
}

test "polymorphic serializer" {
    var buffer: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    try serialize(i32, 42, writer);
    try writer.writeAll(" ");

    try serialize(f64, 3.14159, writer);
    try writer.writeAll(" ");

    try serialize(bool, true, writer);
    try writer.writeAll(" ");

    try serialize([]const u8, "hello", writer);
    try writer.writeAll(" ");

    const arr = [_]i32{ 1, 2, 3 };
    try serialize([3]i32, arr, writer);
    try writer.writeAll(" ");

    try serialize(?i32, null, writer);
    try writer.writeAll(" ");

    try serialize(?i32, 99, writer);

    const output = fbs.getWritten();
    try testing.expect(std.mem.indexOf(u8, output, "42") != null);
    try testing.expect(std.mem.indexOf(u8, output, "3.14") != null);
    try testing.expect(std.mem.indexOf(u8, output, "true") != null);
    try testing.expect(std.mem.indexOf(u8, output, "\"hello\"") != null);
    try testing.expect(std.mem.indexOf(u8, output, "[1, 2, 3]") != null);
    try testing.expect(std.mem.indexOf(u8, output, "null") != null);
    try testing.expect(std.mem.indexOf(u8, output, "99") != null);
}
// ANCHOR_END: polymorphic_serializer
