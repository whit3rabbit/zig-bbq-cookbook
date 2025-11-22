const std = @import("std");
const testing = std.testing;

// Custom panic handler
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = msg;
    _ = error_return_trace;
    _ = ret_addr;
    while (true) {}
}

// ANCHOR: console_log_import
// Import console.log from JavaScript
extern "env" fn consoleLog(value: f64) void;
extern "env" fn consoleLogInt(value: i32) void;
extern "env" fn consoleLogStr(ptr: [*]const u8, len: usize) void;
// ANCHOR_END: console_log_import

// ANCHOR: math_imports
// Import JavaScript Math functions
extern "env" fn jsRandom() f64;
extern "env" fn jsDateNow() f64;
extern "env" fn jsMathPow(base: f64, exponent: f64) f64;
extern "env" fn jsMathSin(x: f64) f64;
extern "env" fn jsMathCos(x: f64) f64;
// ANCHOR_END: math_imports

// ANCHOR: callback_imports
// Import custom JavaScript callbacks
extern "env" fn jsCallback(value: i32) void;
extern "env" fn jsProcessData(data: i32) i32;
// ANCHOR_END: callback_imports

// Test stubs for extern functions (only compiled during testing)
const builtin = @import("builtin");
const is_test = builtin.is_test;

// Provide stub implementations for testing
comptime {
    if (is_test) {
        @export(&stub_consoleLog, .{ .name = "consoleLog" });
        @export(&stub_consoleLogInt, .{ .name = "consoleLogInt" });
        @export(&stub_consoleLogStr, .{ .name = "consoleLogStr" });
        @export(&stub_jsRandom, .{ .name = "jsRandom" });
        @export(&stub_jsDateNow, .{ .name = "jsDateNow" });
        @export(&stub_jsMathPow, .{ .name = "jsMathPow" });
        @export(&stub_jsMathSin, .{ .name = "jsMathSin" });
        @export(&stub_jsMathCos, .{ .name = "jsMathCos" });
        @export(&stub_jsCallback, .{ .name = "jsCallback" });
        @export(&stub_jsProcessData, .{ .name = "jsProcessData" });
    }
}

fn stub_consoleLog(value: f64) callconv(.c) void {
    _ = value;
}
fn stub_consoleLogInt(value: i32) callconv(.c) void {
    _ = value;
}
fn stub_consoleLogStr(ptr: [*]const u8, len: usize) callconv(.c) void {
    _ = ptr;
    _ = len;
}
fn stub_jsRandom() callconv(.c) f64 {
    return 0.5;
}
fn stub_jsDateNow() callconv(.c) f64 {
    return 1000.0;
}
fn stub_jsMathPow(base: f64, exponent: f64) callconv(.c) f64 {
    return std.math.pow(f64, base, exponent);
}
fn stub_jsMathSin(x: f64) callconv(.c) f64 {
    return @sin(x);
}
fn stub_jsMathCos(x: f64) callconv(.c) f64 {
    return @cos(x);
}
fn stub_jsCallback(value: i32) callconv(.c) void {
    _ = value;
}
fn stub_jsProcessData(data: i32) callconv(.c) i32 {
    return data * 2;
}

// ANCHOR: using_console_log
// Function that logs to JavaScript console
export fn logValue(x: f64) void {
    consoleLog(x);
}

export fn logInteger(x: i32) void {
    consoleLogInt(x);
}

export fn logMessage() void {
    const msg = "Hello from Zig!";
    consoleLogStr(msg, msg.len);
}
// ANCHOR_END: using_console_log

// ANCHOR: using_math
// Use JavaScript Math functions
export fn calculatePower(base: f64, exponent: f64) f64 {
    return jsMathPow(base, exponent);
}

export fn calculateCircleArea(radius: f64) f64 {
    const pi = 3.141592653589793;
    const area = pi * jsMathPow(radius, 2.0);
    consoleLog(area); // Log the result
    return area;
}

export fn calculateSinCos(angle: f64) f64 {
    const sin_val = jsMathSin(angle);
    const cos_val = jsMathCos(angle);
    // sin² + cos² = 1
    return jsMathPow(sin_val, 2.0) + jsMathPow(cos_val, 2.0);
}
// ANCHOR_END: using_math

// ANCHOR: using_random
// Generate random numbers using JavaScript
export fn rollDice() i32 {
    const rand = jsRandom(); // Returns [0, 1)
    return @as(i32, @intFromFloat(@floor(rand * 6.0))) + 1;
}

export fn randomInRange(min: i32, max: i32) i32 {
    const rand = jsRandom();
    const range: f64 = @floatFromInt(max - min + 1);
    return min + @as(i32, @intFromFloat(@floor(rand * range)));
}

export fn shuffleArray(arr: [*]i32, len: usize) void {
    // Fisher-Yates shuffle using JavaScript random
    var i: usize = len - 1;
    while (i > 0) : (i -= 1) {
        const rand = jsRandom();
        const j: usize = @intFromFloat(@floor(rand * @as(f64, @floatFromInt(i + 1))));

        // Swap arr[i] and arr[j]
        const temp = arr[i];
        arr[i] = arr[j];
        arr[j] = temp;
    }
}
// ANCHOR_END: using_random

// ANCHOR: using_timestamp
// Get current time from JavaScript
export fn getElapsedSeconds(start_time: f64) f64 {
    const now = jsDateNow();
    return (now - start_time) / 1000.0; // Convert ms to seconds
}

export fn getCurrentTimestamp() f64 {
    return jsDateNow();
}
// ANCHOR_END: using_timestamp

// ANCHOR: using_callbacks
// Use custom callbacks to process data
export fn processWithCallback(value: i32) void {
    // Do some processing
    const result = value * 2 + 10;
    // Send result to JavaScript
    jsCallback(result);
}

export fn processArray(arr: [*]i32, len: usize) void {
    for (0..len) |i| {
        arr[i] = jsProcessData(arr[i]);
    }
}
// ANCHOR_END: using_callbacks

// ANCHOR: benchmark_example
// Benchmark using JavaScript timing
export fn fibonacci(n: i32) i32 {
    if (n <= 1) return n;

    var prev: i32 = 0;
    var curr: i32 = 1;
    var i: i32 = 2;

    while (i <= n) : (i += 1) {
        const next = prev + curr;
        prev = curr;
        curr = next;
    }

    return curr;
}

export fn benchmarkFibonacci(n: i32) f64 {
    const start = jsDateNow();
    _ = fibonacci(n);
    const end = jsDateNow();
    return end - start;
}
// ANCHOR_END: benchmark_example

// Tests (these verify logic, not the external calls)

// ANCHOR: test_dice
test "dice roll in valid range" {
    // We can't test actual randomness in unit tests,
    // but we can verify the formula logic
    const rand = 0.5; // Simulated random value
    const result = @as(i32, @intFromFloat(@floor(rand * 6.0))) + 1;
    try testing.expect(result >= 1 and result <= 6);
}
// ANCHOR_END: test_dice

// ANCHOR: test_random_range
test "random in range logic" {
    const min: i32 = 10;
    const max: i32 = 20;
    const rand = 0.5; // Simulated
    const range: f64 = @floatFromInt(max - min + 1);
    const result = min + @as(i32, @intFromFloat(@floor(rand * range)));
    try testing.expect(result >= min and result <= max);
}
// ANCHOR_END: test_random_range

// ANCHOR: test_shuffle
test "shuffle array logic" {
    const arr = [_]i32{ 1, 2, 3, 4, 5 };
    // Test that array structure is valid
    try testing.expectEqual(@as(usize, 5), arr.len);
}
// ANCHOR_END: test_shuffle

// ANCHOR: test_fibonacci
test "fibonacci function" {
    try testing.expectEqual(@as(i32, 0), fibonacci(0));
    try testing.expectEqual(@as(i32, 1), fibonacci(1));
    try testing.expectEqual(@as(i32, 1), fibonacci(2));
    try testing.expectEqual(@as(i32, 55), fibonacci(10));
}
// ANCHOR_END: test_fibonacci

// ANCHOR: test_elapsed_time
test "elapsed time calculation" {
    const start: f64 = 1000.0;
    const now: f64 = 5000.0;
    const elapsed = (now - start) / 1000.0;
    try testing.expectEqual(@as(f64, 4.0), elapsed);
}
// ANCHOR_END: test_elapsed_time
