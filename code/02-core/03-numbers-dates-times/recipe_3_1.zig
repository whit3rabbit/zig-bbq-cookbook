// Recipe 3.1: Rounding numerical values
// Target Zig Version: 0.15.2
//
// This recipe demonstrates various rounding operations on floating-point numbers
// using Zig's built-in functions and math library.

const std = @import("std");
const testing = std.testing;
const math = std.math;

// ANCHOR: basic_rounding
/// Round to nearest integer
pub fn roundToNearest(value: anytype) @TypeOf(value) {
    return @round(value);
}

/// Round down (floor)
pub fn roundDown(value: anytype) @TypeOf(value) {
    return @floor(value);
}

/// Round up (ceiling)
pub fn roundUp(value: anytype) @TypeOf(value) {
    return @ceil(value);
}

/// Truncate towards zero
pub fn truncate(value: anytype) @TypeOf(value) {
    return @trunc(value);
}
// ANCHOR_END: basic_rounding

// ANCHOR: precision_rounding
/// Round to N decimal places
pub fn roundToDecimalPlaces(comptime T: type, value: T, places: u32) T {
    const multiplier = math.pow(T, 10.0, @as(T, @floatFromInt(places)));
    return @round(value * multiplier) / multiplier;
}

/// Round to nearest multiple of step
pub fn roundToMultiple(comptime T: type, value: T, step: T) T {
    return @round(value / step) * step;
}
// ANCHOR_END: precision_rounding

// ANCHOR: special_rounding
/// Round half to even (banker's rounding)
pub fn roundHalfToEven(comptime T: type, value: T) T {
    const floored = @floor(value);
    const diff = value - floored;

    if (diff < 0.5) {
        return floored;
    } else if (diff > 0.5) {
        return @ceil(value);
    } else {
        // Exactly 0.5 - round to even
        const floored_int = @as(i64, @intFromFloat(floored));
        if (@mod(floored_int, 2) == 0) {
            return floored;
        } else {
            return floored + 1.0;
        }
    }
}

/// Round away from zero
pub fn roundAwayFromZero(comptime T: type, value: T) T {
    if (value >= 0) {
        return @ceil(value);
    } else {
        return @floor(value);
    }
}

/// Round towards zero (same as truncate)
pub fn roundTowardsZero(comptime T: type, value: T) T {
    return @trunc(value);
}

/// Convert to integer with rounding
pub fn toInt(comptime T: type, value: anytype) T {
    return @intFromFloat(@round(value));
}
// ANCHOR_END: special_rounding

test "round to nearest" {
    try testing.expectEqual(@as(f32, 3.0), roundToNearest(@as(f32, 2.5)));
    try testing.expectEqual(@as(f32, 3.0), roundToNearest(@as(f32, 2.7)));
    try testing.expectEqual(@as(f32, 2.0), roundToNearest(@as(f32, 2.3)));
    try testing.expectEqual(@as(f32, -3.0), roundToNearest(@as(f32, -2.5)));
}

test "round down (floor)" {
    try testing.expectEqual(@as(f32, 2.0), roundDown(@as(f32, 2.7)));
    try testing.expectEqual(@as(f32, 2.0), roundDown(@as(f32, 2.3)));
    try testing.expectEqual(@as(f32, -3.0), roundDown(@as(f32, -2.3)));
    try testing.expectEqual(@as(f32, -3.0), roundDown(@as(f32, -2.7)));
}

test "round up (ceiling)" {
    try testing.expectEqual(@as(f32, 3.0), roundUp(@as(f32, 2.1)));
    try testing.expectEqual(@as(f32, 3.0), roundUp(@as(f32, 2.9)));
    try testing.expectEqual(@as(f32, -2.0), roundUp(@as(f32, -2.1)));
    try testing.expectEqual(@as(f32, -2.0), roundUp(@as(f32, -2.9)));
}

test "truncate towards zero" {
    try testing.expectEqual(@as(f32, 2.0), truncate(@as(f32, 2.7)));
    try testing.expectEqual(@as(f32, 2.0), truncate(@as(f32, 2.3)));
    try testing.expectEqual(@as(f32, -2.0), truncate(@as(f32, -2.3)));
    try testing.expectEqual(@as(f32, -2.0), truncate(@as(f32, -2.7)));
}

test "round to decimal places" {
    const value: f64 = 3.14159;

    try testing.expectEqual(@as(f64, 3.1), roundToDecimalPlaces(f64, value, 1));
    try testing.expectEqual(@as(f64, 3.14), roundToDecimalPlaces(f64, value, 2));
    try testing.expectEqual(@as(f64, 3.142), roundToDecimalPlaces(f64, value, 3));
}

test "round to decimal places - negative" {
    const value: f64 = -2.7182;

    try testing.expectEqual(@as(f64, -2.7), roundToDecimalPlaces(f64, value, 1));
    try testing.expectEqual(@as(f64, -2.72), roundToDecimalPlaces(f64, value, 2));
}

test "round to multiple" {
    try testing.expectEqual(@as(f32, 10.0), roundToMultiple(f32, 12.0, 5.0));
    try testing.expectEqual(@as(f32, 15.0), roundToMultiple(f32, 13.0, 5.0));
    try testing.expectEqual(@as(f32, 0.5), roundToMultiple(f32, 0.6, 0.25));
}

test "round half to even - positive" {
    try testing.expectEqual(@as(f64, 2.0), roundHalfToEven(f64, 2.5)); // 2 is even
    try testing.expectEqual(@as(f64, 4.0), roundHalfToEven(f64, 3.5)); // 4 is even
    try testing.expectEqual(@as(f64, 3.0), roundHalfToEven(f64, 2.6));
    try testing.expectEqual(@as(f64, 2.0), roundHalfToEven(f64, 2.4));
}

test "round away from zero" {
    try testing.expectEqual(@as(f64, 3.0), roundAwayFromZero(f64, 2.1));
    try testing.expectEqual(@as(f64, -3.0), roundAwayFromZero(f64, -2.1));
    try testing.expectEqual(@as(f64, 3.0), roundAwayFromZero(f64, 2.9));
    try testing.expectEqual(@as(f64, -3.0), roundAwayFromZero(f64, -2.9));
}

test "round towards zero" {
    try testing.expectEqual(@as(f64, 2.0), roundTowardsZero(f64, 2.9));
    try testing.expectEqual(@as(f64, -2.0), roundTowardsZero(f64, -2.9));
    try testing.expectEqual(@as(f64, 2.0), roundTowardsZero(f64, 2.1));
    try testing.expectEqual(@as(f64, -2.0), roundTowardsZero(f64, -2.1));
}

test "convert to integer" {
    try testing.expectEqual(@as(i32, 3), toInt(i32, @as(f32, 2.7)));
    try testing.expectEqual(@as(i32, 2), toInt(i32, @as(f32, 2.3)));
    try testing.expectEqual(@as(i32, -3), toInt(i32, @as(f32, -2.7)));
}

test "round zero" {
    try testing.expectEqual(@as(f32, 0.0), roundToNearest(@as(f32, 0.0)));
    try testing.expectEqual(@as(f32, 0.0), roundDown(@as(f32, 0.0)));
    try testing.expectEqual(@as(f32, 0.0), roundUp(@as(f32, 0.0)));
}

test "round exactly half" {
    // Standard @round rounds 0.5 away from zero
    try testing.expectEqual(@as(f32, 3.0), roundToNearest(@as(f32, 2.5)));
    try testing.expectEqual(@as(f32, -3.0), roundToNearest(@as(f32, -2.5)));
}

test "round very small numbers" {
    try testing.expectEqual(@as(f64, 0.0), roundToNearest(@as(f64, 0.0001)));
    try testing.expectEqual(@as(f64, 1.0), roundToNearest(@as(f64, 0.9999)));
}

test "round very large numbers" {
    const large: f64 = 1000000.7;
    try testing.expectEqual(@as(f64, 1000001.0), roundToNearest(large));
}

test "round with f64 precision" {
    const value: f64 = 123.456789;
    try testing.expectEqual(@as(f64, 123.46), roundToDecimalPlaces(f64, value, 2));
    try testing.expectEqual(@as(f64, 123.457), roundToDecimalPlaces(f64, value, 3));
}

test "round prices (2 decimal places)" {
    const price1: f64 = 19.995;
    const price2: f64 = 19.994;

    try testing.expectEqual(@as(f64, 20.0), roundToDecimalPlaces(f64, price1, 2));
    try testing.expectEqual(@as(f64, 19.99), roundToDecimalPlaces(f64, price2, 2));
}

test "round to nearest nickel (0.05)" {
    try testing.expectApproxEqAbs(@as(f32, 1.00), roundToMultiple(f32, 0.99, 0.05), 0.001);
    try testing.expectApproxEqAbs(@as(f32, 1.05), roundToMultiple(f32, 1.03, 0.05), 0.001);
    try testing.expectApproxEqAbs(@as(f32, 1.05), roundToMultiple(f32, 1.07, 0.05), 0.001);
}

test "round to nearest quarter (0.25)" {
    try testing.expectEqual(@as(f32, 1.00), roundToMultiple(f32, 0.99, 0.25));
    try testing.expectEqual(@as(f32, 1.25), roundToMultiple(f32, 1.20, 0.25));
    try testing.expectEqual(@as(f32, 1.50), roundToMultiple(f32, 1.40, 0.25));
}

test "round to nearest 10" {
    try testing.expectEqual(@as(f32, 20.0), roundToMultiple(f32, 23.0, 10.0));
    try testing.expectEqual(@as(f32, 20.0), roundToMultiple(f32, 17.0, 10.0));
    try testing.expectEqual(@as(f32, 30.0), roundToMultiple(f32, 25.0, 10.0));
}

test "floor vs truncate difference" {
    // For positive numbers, same result
    try testing.expectEqual(roundDown(@as(f32, 2.7)), truncate(@as(f32, 2.7)));

    // For negative numbers, different
    try testing.expectEqual(@as(f32, -3.0), roundDown(@as(f32, -2.3)));
    try testing.expectEqual(@as(f32, -2.0), truncate(@as(f32, -2.3)));
}

test "rounding mode comparison" {
    const value: f64 = 2.5;

    // Standard round (away from zero for .5)
    try testing.expectEqual(@as(f64, 3.0), roundToNearest(value));

    // Banker's rounding (to even for .5)
    try testing.expectEqual(@as(f64, 2.0), roundHalfToEven(f64, value));

    // Always up
    try testing.expectEqual(@as(f64, 3.0), roundUp(value));

    // Always down
    try testing.expectEqual(@as(f64, 2.0), roundDown(value));
}

test "convert float to int safely" {
    try testing.expectEqual(@as(u32, 43), toInt(u32, @as(f32, 42.7)));
    try testing.expectEqual(@as(i32, -42), toInt(i32, @as(f32, -42.3)));
}

test "memory safety - no allocation" {
    // All rounding operations are pure math, no allocation
    const rounded = roundToNearest(@as(f32, 3.7));
    try testing.expectEqual(@as(f32, 4.0), rounded);
}

test "security - bounds checking" {
    // Rounding stays within float range
    const max_f32 = math.floatMax(f32);
    const rounded = roundToNearest(max_f32);
    try testing.expect(rounded <= max_f32);
}
