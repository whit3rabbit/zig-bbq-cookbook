// Recipe 1.5: Build Modes and Safety Features
// Target Zig Version: 0.15.2
//
// This recipe demonstrates Zig's build modes and safety features,
// showing how different optimization levels affect runtime safety checks.

const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");

// ANCHOR: build_mode_detection
// Detect current build mode at compile time
fn getCurrentBuildMode() []const u8 {
    return switch (builtin.mode) {
        .Debug => "Debug",
        .ReleaseSafe => "ReleaseSafe",
        .ReleaseFast => "ReleaseFast",
        .ReleaseSmall => "ReleaseSmall",
    };
}

test "detect build mode" {
    const mode = getCurrentBuildMode();
    std.debug.print("\nCurrent build mode: {s}\n", .{mode});

    // In tests, usually run in Debug mode
    // But can be overridden with -Doptimize=ReleaseSafe etc.
    try testing.expect(mode.len > 0);
}
// ANCHOR_END: build_mode_detection

// ANCHOR: integer_overflow_safety
// Integer overflow is caught in Debug and ReleaseSafe
fn wouldOverflowInSafeMode() bool {
    // In Debug/ReleaseSafe: would panic with "integer overflow"
    // In ReleaseFast/ReleaseSmall: would wrap to 0
    // We don't actually trigger overflow in tests (it would panic)
    return builtin.mode == .Debug or builtin.mode == .ReleaseSafe;
}

test "integer overflow detection" {
    const has_checks = wouldOverflowInSafeMode();

    if (has_checks) {
        // In these modes, x + 1 where x = 255 would panic
        std.debug.print("\nOverflow checking is enabled\n", .{});
    } else {
        // In release modes without safety, overflow wraps
        std.debug.print("\nOverflow checking is disabled (wraps)\n", .{});
    }

    try testing.expect(true);
}
// ANCHOR_END: integer_overflow_safety

// ANCHOR: wrapping_arithmetic
// Use wrapping operators when overflow is intentional
fn intentionalWrapping() u8 {
    var x: u8 = 255;
    x +%= 1; // Wrapping add: always wraps, never panics
    return x;
}

fn wrappingMultiply(a: u16, b: u16) u16 {
    return a *% b; // Wrapping multiply
}

test "intentional wrapping" {
    const wrapped = intentionalWrapping();
    try testing.expectEqual(@as(u8, 0), wrapped);

    const product = wrappingMultiply(300, 300);
    // 300 * 300 = 90000, wraps to 24464 for u16 (max 65535)
    try testing.expectEqual(@as(u16, 24464), product);
}
// ANCHOR_END: wrapping_arithmetic

// ANCHOR: saturating_arithmetic
// Saturating arithmetic clamps to min/max instead of wrapping
fn saturatingAdd(a: u8, b: u8) u8 {
    return a +| b; // Saturating add
}

fn saturatingSubtract(a: u8, b: u8) u8 {
    return a -| b; // Saturating subtract
}

test "saturating arithmetic" {
    try testing.expectEqual(@as(u8, 255), saturatingAdd(200, 100));
    try testing.expectEqual(@as(u8, 255), saturatingAdd(255, 1));

    try testing.expectEqual(@as(u8, 0), saturatingSubtract(10, 20));
    try testing.expectEqual(@as(u8, 0), saturatingSubtract(0, 1));
}
// ANCHOR_END: saturating_arithmetic

// ANCHOR: bounds_checking
// Array bounds checking is active in Debug and ReleaseSafe
fn accessArray(index: usize) !i32 {
    const array = [_]i32{ 1, 2, 3, 4, 5 };

    // Bounds check happens at runtime in Debug/ReleaseSafe
    // Skipped in ReleaseFast/ReleaseSmall for performance
    if (index >= array.len) {
        return error.OutOfBounds;
    }

    return array[index];
}

test "bounds checking" {
    const valid = try accessArray(2);
    try testing.expectEqual(@as(i32, 3), valid);

    const invalid = accessArray(10);
    try testing.expectError(error.OutOfBounds, invalid);
}
// ANCHOR_END: bounds_checking

// ANCHOR: null_pointer_safety
// Null pointer dereference is caught in Debug/ReleaseSafe
fn dereferenceOptional(ptr: ?*i32) !i32 {
    // Using orelse handles null safely
    const value = ptr orelse return error.NullPointer;
    return value.*;
}

test "null pointer safety" {
    var value: i32 = 42;
    const valid = try dereferenceOptional(&value);
    try testing.expectEqual(@as(i32, 42), valid);

    const invalid = dereferenceOptional(null);
    try testing.expectError(error.NullPointer, invalid);
}
// ANCHOR_END: null_pointer_safety

// ANCHOR: unreachable_marker
// Mark code paths that should never execute
fn dividePositive(a: u32, b: u32) u32 {
    if (b == 0) {
        unreachable; // Tells compiler this never happens
    }
    return a / b;
}

fn getSign(x: i32) []const u8 {
    if (x > 0) return "positive";
    if (x < 0) return "negative";
    if (x == 0) return "zero";
    unreachable; // All cases covered
}

test "unreachable marker" {
    try testing.expectEqual(@as(u32, 5), dividePositive(10, 2));

    try testing.expectEqualStrings("positive", getSign(10));
    try testing.expectEqualStrings("negative", getSign(-5));
    try testing.expectEqualStrings("zero", getSign(0));
}
// ANCHOR_END: unreachable_marker

// ANCHOR: runtime_safety_control
// Control safety checks with @setRuntimeSafety
fn unsafeButFast(arr: []i32) i32 {
    // Disable safety checks for this scope
    @setRuntimeSafety(false);

    var sum: i32 = 0;
    for (arr) |val| {
        sum += val; // No overflow check
    }
    return sum;
}

fn safeVersion(arr: []i32) i32 {
    @setRuntimeSafety(true);

    var sum: i32 = 0;
    for (arr) |val| {
        sum += val; // Overflow checked even in release modes
    }
    return sum;
}

test "runtime safety control" {
    var numbers = [_]i32{ 1, 2, 3, 4, 5 };

    const unsafe_sum = unsafeButFast(&numbers);
    const safe_sum = safeVersion(&numbers);

    try testing.expectEqual(unsafe_sum, safe_sum);
    try testing.expectEqual(@as(i32, 15), safe_sum);
}
// ANCHOR_END: runtime_safety_control

// ANCHOR: assertion_checks
// Use std.debug.assert for development-time checks
fn processValidInput(value: i32) i32 {
    // Active in Debug, stripped in all release modes
    std.debug.assert(value >= 0);
    std.debug.assert(value < 1000);

    return value * 2;
}

test "assertion checks" {
    const result = processValidInput(10);
    try testing.expectEqual(@as(i32, 20), result);

    // In Debug mode, this would panic:
    // processValidInput(-5);  // assertion failure
    // In release modes, assertions are compiled out
}
// ANCHOR_END: assertion_checks

// ANCHOR: checked_arithmetic
// Use @addWithOverflow and friends for explicit overflow handling
fn addWithOverflowCheck(a: u32, b: u32) !u32 {
    const result = @addWithOverflow(a, b);

    if (result[1] != 0) {
        return error.Overflow;
    }

    return result[0];
}

fn multiplyChecked(a: u16, b: u16) !u16 {
    const result = @mulWithOverflow(a, b);

    if (result[1] != 0) {
        return error.Overflow;
    }

    return result[0];
}

test "checked arithmetic" {
    const sum = try addWithOverflowCheck(100, 200);
    try testing.expectEqual(@as(u32, 300), sum);

    const overflow = addWithOverflowCheck(4_000_000_000, 1_000_000_000);
    try testing.expectError(error.Overflow, overflow);

    const product = try multiplyChecked(100, 200);
    try testing.expectEqual(@as(u16, 20000), product);

    const mul_overflow = multiplyChecked(300, 300);
    try testing.expectError(error.Overflow, mul_overflow);
}
// ANCHOR_END: checked_arithmetic

// ANCHOR: optimization_levels
// Different build modes optimize differently
fn computeHeavy() u64 {
    var result: u64 = 1;
    var i: u64 = 1;
    while (i <= 10) : (i += 1) {
        result *= i;
    }
    return result;
}

test "optimization behavior" {
    const factorial = computeHeavy();
    try testing.expectEqual(@as(u64, 3628800), factorial);

    // Debug: No optimizations, full safety
    // ReleaseSafe: Optimized, full safety
    // ReleaseFast: Optimized, safety disabled (fastest)
    // ReleaseSmall: Size-optimized, safety disabled (smallest)
}
// ANCHOR_END: optimization_levels

// ANCHOR: safety_comparison
// Compare safety vs performance tradeoffs
const SafetyLevel = enum {
    debug,
    release_safe,
    release_fast,
};

fn getSafetyInfo(level: SafetyLevel) struct { checks: bool, optimized: bool } {
    return switch (level) {
        .debug => .{ .checks = true, .optimized = false },
        .release_safe => .{ .checks = true, .optimized = true },
        .release_fast => .{ .checks = false, .optimized = true },
    };
}

test "safety level comparison" {
    const debug = getSafetyInfo(.debug);
    try testing.expect(debug.checks);
    try testing.expect(!debug.optimized);

    const safe = getSafetyInfo(.release_safe);
    try testing.expect(safe.checks);
    try testing.expect(safe.optimized);

    const fast = getSafetyInfo(.release_fast);
    try testing.expect(!fast.checks);
    try testing.expect(fast.optimized);
}
// ANCHOR_END: safety_comparison

// ANCHOR: division_by_zero
// Division by zero is caught in Debug/ReleaseSafe
fn safeDivide(a: i32, b: i32) !i32 {
    if (b == 0) {
        return error.DivisionByZero;
    }
    return @divTrunc(a, b);
}

test "division by zero protection" {
    const result = try safeDivide(10, 2);
    try testing.expectEqual(@as(i32, 5), result);

    const div_error = safeDivide(10, 0);
    try testing.expectError(error.DivisionByZero, div_error);
}
// ANCHOR_END: division_by_zero

// ANCHOR: panic_behavior
// Panics can be caught and handled differently per build mode
fn panicOnInvalidInput(value: i32) i32 {
    if (value < 0) {
        // Panic stops execution in Debug/ReleaseSafe
        // In tests, we avoid actual panics
        return -1; // Simulate panic return
    }
    return value * 2;
}

test "panic behavior" {
    const valid = panicOnInvalidInput(10);
    try testing.expectEqual(@as(i32, 20), valid);

    // In production, panicOnInvalidInput(-5) would panic
    // We can't test actual panics, so we just document behavior
}
// ANCHOR_END: panic_behavior

// Comprehensive test
test "comprehensive safety features" {
    // Build mode detection
    const mode = getCurrentBuildMode();
    try testing.expect(mode.len > 0);

    // Wrapping arithmetic
    try testing.expectEqual(@as(u8, 0), intentionalWrapping());

    // Saturating arithmetic
    try testing.expectEqual(@as(u8, 255), saturatingAdd(200, 100));

    // Bounds checking
    _ = try accessArray(0);
    try testing.expectError(error.OutOfBounds, accessArray(100));

    // Null safety
    var val: i32 = 42;
    _ = try dereferenceOptional(&val);
    try testing.expectError(error.NullPointer, dereferenceOptional(null));

    // Checked arithmetic
    _ = try addWithOverflowCheck(10, 20);
    try testing.expectError(error.Overflow, addWithOverflowCheck(4_000_000_000, 1_000_000_000));

    // Division by zero
    _ = try safeDivide(10, 2);
    try testing.expectError(error.DivisionByZero, safeDivide(10, 0));

    try testing.expect(true);
}
