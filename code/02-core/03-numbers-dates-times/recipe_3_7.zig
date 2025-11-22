// Recipe 3.7: Working with infinity and NaNs
// Target Zig Version: 0.15.2
//
// This recipe demonstrates detecting and handling infinity and NaN (Not a Number)
// values in floating-point calculations using std.math functions.

const std = @import("std");
const testing = std.testing;
const math = std.math;

// ANCHOR: detection
/// Check if a value is NaN
pub fn isNaN(comptime T: type, value: T) bool {
    return math.isNan(value);
}

/// Check if a value is infinity (positive or negative)
pub fn isInf(comptime T: type, value: T) bool {
    return math.isInf(value);
}

/// Check if a value is positive infinity
pub fn isPosInf(comptime T: type, value: T) bool {
    return math.isPositiveInf(value);
}

/// Check if a value is negative infinity
pub fn isNegInf(comptime T: type, value: T) bool {
    return math.isNegativeInf(value);
}

/// Check if a value is finite (not NaN or infinity)
pub fn isFinite(comptime T: type, value: T) bool {
    return !math.isNan(value) and !math.isInf(value);
}

/// Check if a value is normal (finite, non-zero, non-subnormal)
pub fn isNormal(comptime T: type, value: T) bool {
    return math.isNormal(value);
}
// ANCHOR_END: detection

// ANCHOR: creation
/// Get positive infinity
pub fn positiveInf(comptime T: type) T {
    return math.inf(T);
}

/// Get negative infinity
pub fn negativeInf(comptime T: type) T {
    return -math.inf(T);
}

/// Get NaN (Not a Number)
pub fn nan(comptime T: type) T {
    return math.nan(T);
}
// ANCHOR_END: creation

// ANCHOR: safe_operations
/// Safe division that returns 0 if divisor is 0
pub fn safeDivide(comptime T: type, a: T, b: T) T {
    if (b == 0.0) return 0.0;
    return a / b;
}

/// Safe operation that replaces NaN with default value
pub fn replaceNaN(comptime T: type, value: T, default: T) T {
    return if (math.isNan(value)) default else value;
}

/// Safe operation that replaces infinity with default value
pub fn replaceInf(comptime T: type, value: T, default: T) T {
    return if (math.isInf(value)) default else value;
}

/// Clamp to finite range, replacing NaN/Inf with bounds
pub fn clampToFinite(comptime T: type, value: T, min_val: T, max_val: T) T {
    if (math.isNan(value)) return min_val;
    if (math.isPositiveInf(value)) return max_val;
    if (math.isNegativeInf(value)) return min_val;
    return math.clamp(value, min_val, max_val);
}

/// Compare floats with NaN handling (NaN is considered equal to NaN)
pub fn equalWithNaN(comptime T: type, a: T, b: T) bool {
    if (math.isNan(a) and math.isNan(b)) return true;
    if (math.isNan(a) or math.isNan(b)) return false;
    return a == b;
}

/// Get sign of number including infinity (-1, 0, or 1)
pub fn signOf(comptime T: type, value: T) i2 {
    if (math.isNan(value)) return 0;
    if (value > 0.0 or math.isPositiveInf(value)) return 1;
    if (value < 0.0 or math.isNegativeInf(value)) return -1;
    return 0;
}
// ANCHOR_END: safe_operations

test "detect NaN" {
    const nan_value = nan(f64);
    try testing.expect(isNaN(f64, nan_value));
    try testing.expect(!isNaN(f64, 1.0));
    try testing.expect(!isNaN(f64, 0.0));
}

test "create NaN from invalid operation" {
    // Use runtime values to avoid compile-time division by zero error
    var zero: f64 = 0.0;
    _ = &zero; // Prevent optimization
    const result = zero / zero;
    try testing.expect(isNaN(f64, result));
}

test "detect positive infinity" {
    const pos_inf = positiveInf(f64);
    try testing.expect(isInf(f64, pos_inf));
    try testing.expect(isPosInf(f64, pos_inf));
    try testing.expect(!isNegInf(f64, pos_inf));
}

test "detect negative infinity" {
    const neg_inf = negativeInf(f64);
    try testing.expect(isInf(f64, neg_inf));
    try testing.expect(isNegInf(f64, neg_inf));
    try testing.expect(!isPosInf(f64, neg_inf));
}

test "create infinity from division by zero" {
    // Use runtime values to avoid compile-time division by zero error
    var zero: f64 = 0.0;
    _ = &zero; // Prevent optimization
    const result = 1.0 / zero;
    try testing.expect(isPosInf(f64, result));

    const result_neg = -1.0 / zero;
    try testing.expect(isNegInf(f64, result_neg));
}

test "detect finite values" {
    try testing.expect(isFinite(f64, 0.0));
    try testing.expect(isFinite(f64, 1.0));
    try testing.expect(isFinite(f64, -100.5));
    try testing.expect(!isFinite(f64, positiveInf(f64)));
    try testing.expect(!isFinite(f64, negativeInf(f64)));
    try testing.expect(!isFinite(f64, nan(f64)));
}

test "detect normal values" {
    try testing.expect(isNormal(f64, 1.0));
    try testing.expect(isNormal(f64, -100.0));
    try testing.expect(!isNormal(f64, 0.0));
    try testing.expect(!isNormal(f64, nan(f64)));
    try testing.expect(!isNormal(f64, positiveInf(f64)));
}

test "NaN properties" {
    const nan_val = nan(f64);

    // NaN is not equal to anything, including itself
    try testing.expect(nan_val != nan_val);

    // NaN comparisons always return false
    try testing.expect(!(nan_val < 1.0));
    try testing.expect(!(nan_val > 1.0));
    try testing.expect(!(nan_val == 1.0));
}

test "infinity arithmetic" {
    const pos_inf = positiveInf(f64);
    const neg_inf = negativeInf(f64);

    // Infinity + finite = infinity
    try testing.expect(isPosInf(f64, pos_inf + 1.0));
    try testing.expect(isNegInf(f64, neg_inf - 1.0));

    // Infinity * finite = infinity (same sign)
    try testing.expect(isPosInf(f64, pos_inf * 2.0));
    try testing.expect(isNegInf(f64, pos_inf * -2.0));

    // Infinity / finite = infinity
    try testing.expect(isPosInf(f64, pos_inf / 2.0));
}

test "infinity edge cases" {
    const pos_inf = positiveInf(f64);
    const neg_inf = negativeInf(f64);

    // Infinity - Infinity = NaN
    try testing.expect(isNaN(f64, pos_inf + neg_inf));

    // Infinity / Infinity = NaN
    try testing.expect(isNaN(f64, pos_inf / pos_inf));

    // 0 * Infinity = NaN
    try testing.expect(isNaN(f64, 0.0 * pos_inf));
}

test "safe divide" {
    try testing.expectEqual(@as(f64, 2.0), safeDivide(f64, 10.0, 5.0));
    try testing.expectEqual(@as(f64, 0.0), safeDivide(f64, 10.0, 0.0));
    try testing.expect(!isNaN(f64, safeDivide(f64, 10.0, 0.0)));
}

test "replace NaN with default" {
    const nan_val = nan(f64);
    const result = replaceNaN(f64, nan_val, 0.0);
    try testing.expectEqual(@as(f64, 0.0), result);

    const normal = replaceNaN(f64, 42.0, 0.0);
    try testing.expectEqual(@as(f64, 42.0), normal);
}

test "replace infinity with default" {
    const pos_inf = positiveInf(f64);
    const result = replaceInf(f64, pos_inf, 999.0);
    try testing.expectEqual(@as(f64, 999.0), result);

    const normal = replaceInf(f64, 42.0, 999.0);
    try testing.expectEqual(@as(f64, 42.0), normal);
}

test "clamp to finite range" {
    const pos_inf = positiveInf(f64);
    const neg_inf = negativeInf(f64);
    const nan_val = nan(f64);

    try testing.expectEqual(@as(f64, 100.0), clampToFinite(f64, pos_inf, 0.0, 100.0));
    try testing.expectEqual(@as(f64, 0.0), clampToFinite(f64, neg_inf, 0.0, 100.0));
    try testing.expectEqual(@as(f64, 0.0), clampToFinite(f64, nan_val, 0.0, 100.0));
    try testing.expectEqual(@as(f64, 50.0), clampToFinite(f64, 50.0, 0.0, 100.0));
}

test "equal with NaN handling" {
    const nan1 = nan(f64);
    const nan2 = nan(f64);

    // Our custom comparison considers NaN equal to NaN
    try testing.expect(equalWithNaN(f64, nan1, nan2));

    // Regular values work normally
    try testing.expect(equalWithNaN(f64, 42.0, 42.0));
    try testing.expect(!equalWithNaN(f64, 42.0, 43.0));

    // NaN not equal to regular value
    try testing.expect(!equalWithNaN(f64, nan1, 42.0));
}

test "sign of number" {
    try testing.expectEqual(@as(i2, 1), signOf(f64, 42.0));
    try testing.expectEqual(@as(i2, -1), signOf(f64, -42.0));
    try testing.expectEqual(@as(i2, 0), signOf(f64, 0.0));
    try testing.expectEqual(@as(i2, 1), signOf(f64, positiveInf(f64)));
    try testing.expectEqual(@as(i2, -1), signOf(f64, negativeInf(f64)));
    try testing.expectEqual(@as(i2, 0), signOf(f64, nan(f64)));
}

test "propagation of NaN" {
    const nan_val = nan(f64);

    // NaN propagates through operations
    try testing.expect(isNaN(f64, nan_val + 1.0));
    try testing.expect(isNaN(f64, nan_val * 2.0));
    try testing.expect(isNaN(f64, nan_val / 5.0));
    try testing.expect(isNaN(f64, @sqrt(nan_val)));
}

test "comparing infinities" {
    const pos_inf = positiveInf(f64);
    const neg_inf = negativeInf(f64);

    // Infinity comparisons work as expected
    try testing.expect(pos_inf > 1e308);
    try testing.expect(neg_inf < -1e308);
    try testing.expect(pos_inf > neg_inf);
    try testing.expect(pos_inf == pos_inf);
}

test "f32 infinity and NaN" {
    const pos_inf_f32 = positiveInf(f32);
    const nan_f32 = nan(f32);

    try testing.expect(isPosInf(f32, pos_inf_f32));
    try testing.expect(isNaN(f32, nan_f32));
    try testing.expect(isFinite(f32, 1.0));
}

test "largest finite values" {
    const max_f64 = math.floatMax(f64);
    const min_f64 = -math.floatMax(f64);

    try testing.expect(isFinite(f64, max_f64));
    try testing.expect(isFinite(f64, min_f64));
    try testing.expect(!isInf(f64, max_f64));

    // Exceeding max should give infinity
    const beyond_max = max_f64 * 2.0;
    try testing.expect(isPosInf(f64, beyond_max));
}

test "smallest positive values" {
    const tiny = math.floatMin(f64);
    try testing.expect(isFinite(f64, tiny));
    try testing.expect(tiny > 0.0);
}

test "special value arithmetic combinations" {
    const pos_inf = positiveInf(f64);
    const neg_inf = negativeInf(f64);
    const nan_val = nan(f64);

    // NaN with anything = NaN
    try testing.expect(isNaN(f64, nan_val + 1.0));
    try testing.expect(isNaN(f64, nan_val + pos_inf));

    // Infinity operations
    try testing.expect(isPosInf(f64, pos_inf * 2.0));
    try testing.expect(isNegInf(f64, pos_inf * -1.0));
    try testing.expect(isNaN(f64, pos_inf * 0.0));

    // Negative infinity operations
    try testing.expect(isNegInf(f64, neg_inf * 2.0));
}

test "memory safety - no allocation" {
    // All operations are pure math, no allocation
    const nan_val = nan(f64);
    const pos_inf = positiveInf(f64);

    try testing.expect(isNaN(f64, nan_val));
    try testing.expect(isPosInf(f64, pos_inf));
}

test "security - safe handling" {
    // Ensure we can safely check and replace special values
    const values = [_]f64{ 1.0, nan(f64), positiveInf(f64), -5.0, negativeInf(f64) };

    for (values) |val| {
        const safe_val = replaceNaN(f64, replaceInf(f64, val, 0.0), 0.0);
        try testing.expect(isFinite(f64, safe_val));
    }
}
