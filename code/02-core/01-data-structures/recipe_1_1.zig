// Recipe 1.1: Unpacking and Destructuring
// Target Zig Version: 0.15.2
//
// Demonstrates how to unpack tuples and arrays into separate variables.
// Run: zig test code/02-core/01-data-structures/recipe_1_1.zig

const std = @import("std");
const testing = std.testing;

// ==============================================================================
// Basic Tuple Destructuring
// ==============================================================================

// ANCHOR: basic_destructuring
test "basic tuple destructuring" {
    const point = .{ 3, 4 };
    const x, const y = point;

    try testing.expectEqual(3, x);
    try testing.expectEqual(4, y);
}
// ANCHOR_END: basic_destructuring

test "tuple with mixed types" {
    const person = .{ "Alice", 30, true };
    const name, const age, const is_active = person;

    try testing.expectEqualStrings("Alice", name);
    try testing.expectEqual(30, age);
    try testing.expectEqual(true, is_active);
}

test "tuple with floating point" {
    const measurement = .{ 3.14, 2.71, 1.41 };
    const pi, const e, const sqrt2 = measurement;

    try testing.expectEqual(3.14, pi);
    try testing.expectEqual(2.71, e);
    try testing.expectEqual(1.41, sqrt2);
}

// ==============================================================================
// Array Destructuring
// ==============================================================================

test "array destructuring" {
    const coords = [3]i32{ 1, 2, 3 };
    const a, const b, const c = coords;

    try testing.expectEqual(@as(i32, 1), a);
    try testing.expectEqual(@as(i32, 2), b);
    try testing.expectEqual(@as(i32, 3), c);
}

test "array of strings" {
    const colors = [3][]const u8{ "red", "green", "blue" };
    const r, const g, const b = colors;

    try testing.expectEqualStrings("red", r);
    try testing.expectEqualStrings("green", g);
    try testing.expectEqualStrings("blue", b);
}

// ==============================================================================
// Ignoring Values
// ==============================================================================

// ANCHOR: ignoring_values
test "ignoring values with underscore" {
    const point3d = .{ 5, 10, 15 };
    const x, const y, _ = point3d;

    try testing.expectEqual(5, x);
    try testing.expectEqual(10, y);
    // Third value is ignored
}
// ANCHOR_END: ignoring_values

test "ignoring middle values" {
    const data = .{ 1, 2, 3, 4, 5 };
    const first, _, const third, _, const fifth = data;

    try testing.expectEqual(1, first);
    try testing.expectEqual(3, third);
    try testing.expectEqual(5, fifth);
}

// ==============================================================================
// Function Return Values
// ==============================================================================

fn divmod(a: i32, b: i32) struct { quotient: i32, remainder: i32 } {
    return .{
        .quotient = @divTrunc(a, b),
        .remainder = @rem(a, b),
    };
}

test "destructuring function return value" {
    const result = divmod(17, 5);
    const q, const r = .{ result.quotient, result.remainder };

    try testing.expectEqual(@as(i32, 3), q);
    try testing.expectEqual(@as(i32, 2), r);
}

fn getPoint() struct { x: i32, y: i32 } {
    return .{ .x = 100, .y = 200 };
}

test "destructuring named struct fields" {
    const point = getPoint();
    const x, const y = .{ point.x, point.y };

    try testing.expectEqual(@as(i32, 100), x);
    try testing.expectEqual(@as(i32, 200), y);
}

// ==============================================================================
// Mutable Variables
// ==============================================================================

test "destructuring into mutable variables" {
    const point = .{ @as(i32, 5), @as(i32, 10) };
    var x, var y = point;

    x += 1;
    y += 2;

    try testing.expectEqual(@as(i32, 6), x);
    try testing.expectEqual(@as(i32, 12), y);
}

test "modifying individual destructured values" {
    const original = .{ @as(i32, 1), @as(i32, 2), @as(i32, 3) };
    var a, var b, var c = original;

    a *= 10;
    b *= 10;
    c *= 10;

    try testing.expectEqual(@as(i32, 10), a);
    try testing.expectEqual(@as(i32, 20), b);
    try testing.expectEqual(@as(i32, 30), c);
}

// ==============================================================================
// Practical Examples
// ==============================================================================

// ANCHOR: practical_examples
fn parseCoordinate(text: []const u8) !struct { x: i32, y: i32 } {
    // Simplified parsing - just returns example values
    _ = text;
    return .{ .x = 42, .y = 24 };
}

test "practical example - parsing coordinates" {
    const result = try parseCoordinate("42,24");
    const x, const y = .{ result.x, result.y };

    try testing.expectEqual(@as(i32, 42), x);
    try testing.expectEqual(@as(i32, 24), y);
}

fn swapInts(a: i32, b: i32) struct { i32, i32 } {
    return .{ b, a };
}

test "practical example - swapping values" {
    const a: i32 = 10;
    const b: i32 = 20;

    const new_a, const new_b = swapInts(a, b);

    try testing.expectEqual(@as(i32, 20), new_a);
    try testing.expectEqual(@as(i32, 10), new_b);
}
// ANCHOR_END: practical_examples

// ==============================================================================
// Edge Cases
// ==============================================================================

test "single element tuple - cannot destructure" {
    const single = .{42};

    // Single-element tuples cannot be destructured in Zig.
    // This would be a syntax error: const value, = single;
    //
    // Instead, assign the whole tuple and access via index:
    const tuple = single;
    try testing.expectEqual(42, tuple[0]);

    // Or access directly via index or field name:
    const value = single[0];
    try testing.expectEqual(42, value);

    const field_value = single.@"0";
    try testing.expectEqual(42, field_value);
}

test "destructuring two element tuple" {
    const pair = .{ 1, 2 };
    const first, const second = pair;

    try testing.expectEqual(1, first);
    try testing.expectEqual(2, second);
}

test "nested tuple destructuring requires manual unpacking" {
    const nested = .{ .{ 1, 2 }, .{ 3, 4 } };
    const first_pair, const second_pair = nested;

    const a, const b = first_pair;
    const c, const d = second_pair;

    try testing.expectEqual(1, a);
    try testing.expectEqual(2, b);
    try testing.expectEqual(3, c);
    try testing.expectEqual(4, d);
}
