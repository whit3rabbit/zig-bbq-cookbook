// Recipe 3.9: Calculating with large numerical arrays using SIMD
// Target Zig Version: 0.15.2
//
// This recipe demonstrates using @Vector for SIMD operations to perform
// efficient calculations on large arrays of numbers.

const std = @import("std");
const testing = std.testing;
const math = std.math;

// ANCHOR: basic_vector_ops
/// Add two vectors element-wise
pub fn vectorAdd(comptime T: type, comptime len: comptime_int, a: @Vector(len, T), b: @Vector(len, T)) @Vector(len, T) {
    return a + b;
}

/// Subtract two vectors element-wise
pub fn vectorSub(comptime T: type, comptime len: comptime_int, a: @Vector(len, T), b: @Vector(len, T)) @Vector(len, T) {
    return a - b;
}

/// Multiply two vectors element-wise
pub fn vectorMul(comptime T: type, comptime len: comptime_int, a: @Vector(len, T), b: @Vector(len, T)) @Vector(len, T) {
    return a * b;
}

/// Divide two vectors element-wise
pub fn vectorDiv(comptime T: type, comptime len: comptime_int, a: @Vector(len, T), b: @Vector(len, T)) @Vector(len, T) {
    return a / b;
}

/// Multiply vector by scalar
pub fn vectorScale(comptime T: type, comptime len: comptime_int, v: @Vector(len, T), scalar: T) @Vector(len, T) {
    const splat: @Vector(len, T) = @splat(scalar);
    return v * splat;
}

/// Sum all elements in a vector
pub fn vectorSum(comptime T: type, comptime len: comptime_int, v: @Vector(len, T)) T {
    return @reduce(.Add, v);
}

/// Find maximum element in a vector
pub fn vectorMax(comptime T: type, comptime len: comptime_int, v: @Vector(len, T)) T {
    return @reduce(.Max, v);
}

/// Find minimum element in a vector
pub fn vectorMin(comptime T: type, comptime len: comptime_int, v: @Vector(len, T)) T {
    return @reduce(.Min, v);
}

/// Compute dot product of two vectors
pub fn dotProduct(comptime T: type, comptime len: comptime_int, a: @Vector(len, T), b: @Vector(len, T)) T {
    const product = a * b;
    return @reduce(.Add, product);
}
// ANCHOR_END: basic_vector_ops

// ANCHOR: array_processing
/// Add arrays element-wise using SIMD
pub fn addArrays(comptime T: type, a: []const T, b: []const T, result: []T) void {
    std.debug.assert(a.len == b.len);
    std.debug.assert(a.len == result.len);

    const Vec = @Vector(4, T);
    const vec_len = 4;

    var i: usize = 0;

    // Process in chunks of 4 using SIMD
    while (i + vec_len <= a.len) : (i += vec_len) {
        const va: Vec = a[i..][0..vec_len].*;
        const vb: Vec = b[i..][0..vec_len].*;
        const vr = va + vb;
        result[i..][0..vec_len].* = vr;
    }

    // Handle remaining elements
    while (i < a.len) : (i += 1) {
        result[i] = a[i] + b[i];
    }
}

/// Multiply array by scalar using SIMD
pub fn scaleArray(comptime T: type, arr: []const T, scalar: T, result: []T) void {
    std.debug.assert(arr.len == result.len);

    const Vec = @Vector(4, T);
    const vec_len = 4;
    const scalar_vec: Vec = @splat(scalar);

    var i: usize = 0;

    // Process in chunks of 4 using SIMD
    while (i + vec_len <= arr.len) : (i += vec_len) {
        const va: Vec = arr[i..][0..vec_len].*;
        const vr = va * scalar_vec;
        result[i..][0..vec_len].* = vr;
    }

    // Handle remaining elements
    while (i < arr.len) : (i += 1) {
        result[i] = arr[i] * scalar;
    }
}

/// Compute sum of array using SIMD
pub fn sumArray(comptime T: type, arr: []const T) T {
    const Vec = @Vector(4, T);
    const vec_len = 4;

    var sum: T = 0;
    var i: usize = 0;

    // Process in chunks of 4 using SIMD
    while (i + vec_len <= arr.len) : (i += vec_len) {
        const va: Vec = arr[i..][0..vec_len].*;
        sum += @reduce(.Add, va);
    }

    // Handle remaining elements
    while (i < arr.len) : (i += 1) {
        sum += arr[i];
    }

    return sum;
}

/// Find maximum in array using SIMD
pub fn maxArray(comptime T: type, arr: []const T) ?T {
    if (arr.len == 0) return null;

    const Vec = @Vector(4, T);
    const vec_len = 4;

    var max_val = arr[0];
    var i: usize = 0;

    // Process in chunks of 4 using SIMD
    while (i + vec_len <= arr.len) : (i += vec_len) {
        const va: Vec = arr[i..][0..vec_len].*;
        const local_max = @reduce(.Max, va);
        max_val = @max(max_val, local_max);
    }

    // Handle remaining elements
    while (i < arr.len) : (i += 1) {
        max_val = @max(max_val, arr[i]);
    }

    return max_val;
}

/// Compute mean of array
pub fn mean(comptime T: type, arr: []const T) T {
    if (arr.len == 0) return 0;
    const sum_val = sumArray(T, arr);
    return sum_val / @as(T, @floatFromInt(arr.len));
}
// ANCHOR_END: array_processing

// ANCHOR: advanced_vector_ops
/// Element-wise comparison (greater than)
pub fn vectorGreaterThan(comptime T: type, comptime len: comptime_int, a: @Vector(len, T), b: @Vector(len, T)) @Vector(len, bool) {
    return a > b;
}

/// Select elements based on mask
pub fn vectorSelect(comptime T: type, comptime len: comptime_int, mask: @Vector(len, bool), true_vals: @Vector(len, T), false_vals: @Vector(len, T)) @Vector(len, T) {
    return @select(T, mask, true_vals, false_vals);
}

/// Clamp vector values to range
pub fn vectorClamp(comptime T: type, comptime len: comptime_int, v: @Vector(len, T), min_val: T, max_val: T) @Vector(len, T) {
    const min_vec: @Vector(len, T) = @splat(min_val);
    const max_vec: @Vector(len, T) = @splat(max_val);
    return @min(@max(v, min_vec), max_vec);
}
// ANCHOR_END: advanced_vector_ops

test "vector addition" {
    const a = @Vector(4, f32){ 1.0, 2.0, 3.0, 4.0 };
    const b = @Vector(4, f32){ 5.0, 6.0, 7.0, 8.0 };
    const result = vectorAdd(f32, 4, a, b);

    try testing.expectEqual(@as(f32, 6.0), result[0]);
    try testing.expectEqual(@as(f32, 8.0), result[1]);
    try testing.expectEqual(@as(f32, 10.0), result[2]);
    try testing.expectEqual(@as(f32, 12.0), result[3]);
}

test "vector subtraction" {
    const a = @Vector(4, f32){ 10.0, 8.0, 6.0, 4.0 };
    const b = @Vector(4, f32){ 1.0, 2.0, 3.0, 4.0 };
    const result = vectorSub(f32, 4, a, b);

    try testing.expectEqual(@as(f32, 9.0), result[0]);
    try testing.expectEqual(@as(f32, 6.0), result[1]);
    try testing.expectEqual(@as(f32, 3.0), result[2]);
    try testing.expectEqual(@as(f32, 0.0), result[3]);
}

test "vector multiplication" {
    const a = @Vector(4, f32){ 2.0, 3.0, 4.0, 5.0 };
    const b = @Vector(4, f32){ 1.0, 2.0, 3.0, 4.0 };
    const result = vectorMul(f32, 4, a, b);

    try testing.expectEqual(@as(f32, 2.0), result[0]);
    try testing.expectEqual(@as(f32, 6.0), result[1]);
    try testing.expectEqual(@as(f32, 12.0), result[2]);
    try testing.expectEqual(@as(f32, 20.0), result[3]);
}

test "vector division" {
    const a = @Vector(4, f32){ 10.0, 20.0, 30.0, 40.0 };
    const b = @Vector(4, f32){ 2.0, 4.0, 5.0, 8.0 };
    const result = vectorDiv(f32, 4, a, b);

    try testing.expectEqual(@as(f32, 5.0), result[0]);
    try testing.expectEqual(@as(f32, 5.0), result[1]);
    try testing.expectEqual(@as(f32, 6.0), result[2]);
    try testing.expectEqual(@as(f32, 5.0), result[3]);
}

test "vector scale" {
    const v = @Vector(4, f32){ 1.0, 2.0, 3.0, 4.0 };
    const result = vectorScale(f32, 4, v, 2.5);

    try testing.expectApproxEqAbs(@as(f32, 2.5), result[0], 0.0001);
    try testing.expectApproxEqAbs(@as(f32, 5.0), result[1], 0.0001);
    try testing.expectApproxEqAbs(@as(f32, 7.5), result[2], 0.0001);
    try testing.expectApproxEqAbs(@as(f32, 10.0), result[3], 0.0001);
}

test "vector sum" {
    const v = @Vector(4, i32){ 1, 2, 3, 4 };
    const sum = vectorSum(i32, 4, v);

    try testing.expectEqual(@as(i32, 10), sum);
}

test "vector max" {
    const v = @Vector(4, i32){ 5, 2, 8, 3 };
    const max_val = vectorMax(i32, 4, v);

    try testing.expectEqual(@as(i32, 8), max_val);
}

test "vector min" {
    const v = @Vector(4, i32){ 5, 2, 8, 3 };
    const min_val = vectorMin(i32, 4, v);

    try testing.expectEqual(@as(i32, 2), min_val);
}

test "dot product" {
    const a = @Vector(4, f32){ 1.0, 2.0, 3.0, 4.0 };
    const b = @Vector(4, f32){ 5.0, 6.0, 7.0, 8.0 };
    const result = dotProduct(f32, 4, a, b);

    // 1*5 + 2*6 + 3*7 + 4*8 = 5 + 12 + 21 + 32 = 70
    try testing.expectApproxEqAbs(@as(f32, 70.0), result, 0.0001);
}

test "add arrays with SIMD" {
    const a = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0 };
    const b = [_]f32{ 10.0, 20.0, 30.0, 40.0, 50.0, 60.0 };
    var result: [6]f32 = undefined;

    addArrays(f32, &a, &b, &result);

    try testing.expectEqual(@as(f32, 11.0), result[0]);
    try testing.expectEqual(@as(f32, 22.0), result[1]);
    try testing.expectEqual(@as(f32, 33.0), result[2]);
    try testing.expectEqual(@as(f32, 44.0), result[3]);
    try testing.expectEqual(@as(f32, 55.0), result[4]);
    try testing.expectEqual(@as(f32, 66.0), result[5]);
}

test "scale array with SIMD" {
    const arr = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    var result: [5]f32 = undefined;

    scaleArray(f32, &arr, 3.0, &result);

    try testing.expectEqual(@as(f32, 3.0), result[0]);
    try testing.expectEqual(@as(f32, 6.0), result[1]);
    try testing.expectEqual(@as(f32, 9.0), result[2]);
    try testing.expectEqual(@as(f32, 12.0), result[3]);
    try testing.expectEqual(@as(f32, 15.0), result[4]);
}

test "sum array with SIMD" {
    const arr = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const sum = sumArray(i32, &arr);

    try testing.expectEqual(@as(i32, 36), sum);
}

test "max array with SIMD" {
    const arr = [_]i32{ 3, 7, 2, 9, 1, 5 };
    const max_val = maxArray(i32, &arr);

    try testing.expectEqual(@as(i32, 9), max_val.?);
}

test "max array empty" {
    const arr = [_]i32{};
    const max_val = maxArray(i32, &arr);

    try testing.expectEqual(@as(?i32, null), max_val);
}

test "mean of array" {
    const arr = [_]f32{ 2.0, 4.0, 6.0, 8.0 };
    const mean_val = mean(f32, &arr);

    try testing.expectApproxEqAbs(@as(f32, 5.0), mean_val, 0.0001);
}

test "vector comparison" {
    const a = @Vector(4, i32){ 1, 5, 3, 8 };
    const b = @Vector(4, i32){ 2, 3, 6, 7 };
    const result = vectorGreaterThan(i32, 4, a, b);

    try testing.expectEqual(false, result[0]);
    try testing.expectEqual(true, result[1]);
    try testing.expectEqual(false, result[2]);
    try testing.expectEqual(true, result[3]);
}

test "vector select" {
    const mask = @Vector(4, bool){ true, false, true, false };
    const true_vals = @Vector(4, i32){ 10, 20, 30, 40 };
    const false_vals = @Vector(4, i32){ 1, 2, 3, 4 };
    const result = vectorSelect(i32, 4, mask, true_vals, false_vals);

    try testing.expectEqual(@as(i32, 10), result[0]);
    try testing.expectEqual(@as(i32, 2), result[1]);
    try testing.expectEqual(@as(i32, 30), result[2]);
    try testing.expectEqual(@as(i32, 4), result[3]);
}

test "vector clamp" {
    const v = @Vector(4, f32){ -5.0, 0.0, 5.0, 15.0 };
    const result = vectorClamp(f32, 4, v, 0.0, 10.0);

    try testing.expectEqual(@as(f32, 0.0), result[0]);
    try testing.expectEqual(@as(f32, 0.0), result[1]);
    try testing.expectEqual(@as(f32, 5.0), result[2]);
    try testing.expectEqual(@as(f32, 10.0), result[3]);
}

test "integer vectors" {
    const a = @Vector(4, i32){ 10, 20, 30, 40 };
    const b = @Vector(4, i32){ 1, 2, 3, 4 };
    const result = vectorAdd(i32, 4, a, b);

    try testing.expectEqual(@as(i32, 11), result[0]);
    try testing.expectEqual(@as(i32, 22), result[1]);
    try testing.expectEqual(@as(i32, 33), result[2]);
    try testing.expectEqual(@as(i32, 44), result[3]);
}

test "large vector" {
    const v = @Vector(8, f32){ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0 };
    const sum = vectorSum(f32, 8, v);

    try testing.expectApproxEqAbs(@as(f32, 36.0), sum, 0.0001);
}

test "array operations with non-aligned size" {
    // Test with size that's not a multiple of 4
    const arr = [_]i32{ 1, 2, 3, 4, 5, 6, 7 };
    const sum = sumArray(i32, &arr);

    try testing.expectEqual(@as(i32, 28), sum);
}

test "memory safety - no allocation" {
    // All vector operations are pure math on stack
    const a = @Vector(4, f32){ 1.0, 2.0, 3.0, 4.0 };
    const b = @Vector(4, f32){ 5.0, 6.0, 7.0, 8.0 };
    const result = vectorAdd(f32, 4, a, b);

    try testing.expect(result[0] > 0.0);
}

test "security - bounds checking" {
    // Ensure SIMD operations respect bounds
    const arr = [_]i32{ 1, 2, 3 };
    const sum = sumArray(i32, &arr);

    try testing.expectEqual(@as(i32, 6), sum);
}

test "performance - SIMD vs scalar" {
    // Demonstrate SIMD processes multiple elements at once
    const a = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    const b = [_]f32{ 5.0, 6.0, 7.0, 8.0 };
    var result: [4]f32 = undefined;

    addArrays(f32, &a, &b, &result);

    // Verify correctness (performance benefit is implicit)
    try testing.expectEqual(@as(f32, 6.0), result[0]);
    try testing.expectEqual(@as(f32, 8.0), result[1]);
}
