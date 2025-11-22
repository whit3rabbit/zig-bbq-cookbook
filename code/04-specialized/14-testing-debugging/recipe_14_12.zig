const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");

// ANCHOR: stack_trace_basics
fn faultyFunction() void {
    // In debug mode, this provides a stack trace
    std.debug.print("Function called\n", .{});
}

fn intermediateFunction() void {
    faultyFunction();
}

fn topLevelFunction() void {
    intermediateFunction();
}

test "stack trace basics" {
    topLevelFunction();
}
// ANCHOR_END: stack_trace_basics

// ANCHOR: panic_with_message
fn validateInput(value: i32) void {
    if (value < 0) {
        std.debug.panic("Invalid input: value {d} must be non-negative", .{value});
    }
    std.debug.print("Valid input: {d}\n", .{value});
}

test "panic with message" {
    // This test demonstrates panic (commented out to allow test suite to pass)
    // validateInput(-1);  // Would panic with stack trace
    validateInput(42); // Safe call
}
// ANCHOR_END: panic_with_message

// ANCHOR: debug_assertions
fn processValue(value: i32) i32 {
    std.debug.assert(value >= 0); // Only active in Debug mode
    std.debug.assert(value <= 100);
    return value * 2;
}

test "debug assertions" {
    // Assertions are active in test builds
    try testing.expectEqual(@as(i32, 20), processValue(10));
    // processValue(-1);  // Would trigger assertion in debug mode
}
// ANCHOR_END: debug_assertions

// ANCHOR: safe_unwrapping
fn safeUnwrap(optional: ?i32) !i32 {
    if (optional) |value| {
        return value;
    } else {
        std.debug.print("Attempted to unwrap null value\n", .{});
        return error.NullValue;
    }
}

test "safe optional unwrapping" {
    try testing.expectEqual(@as(i32, 42), try safeUnwrap(42));
    try testing.expectError(error.NullValue, safeUnwrap(null));
}
// ANCHOR_END: safe_unwrapping

// ANCHOR: bounds_checking
fn safeArrayAccess(array: []const i32, index: usize) !i32 {
    if (index >= array.len) {
        std.debug.print("Index {d} out of bounds (len: {d})\n", .{ index, array.len });
        return error.OutOfBounds;
    }
    return array[index];
}

test "bounds checking" {
    const array = [_]i32{ 1, 2, 3, 4, 5 };
    try testing.expectEqual(@as(i32, 3), try safeArrayAccess(&array, 2));
    try testing.expectError(error.OutOfBounds, safeArrayAccess(&array, 10));
}
// ANCHOR_END: bounds_checking

// ANCHOR: null_checks
fn processPointer(ptr: ?*i32) !i32 {
    const value = ptr orelse {
        std.debug.print("Null pointer detected\n", .{});
        return error.NullPointer;
    };
    return value.*;
}

test "null pointer checks" {
    var value: i32 = 42;
    try testing.expectEqual(@as(i32, 42), try processPointer(&value));
    try testing.expectError(error.NullPointer, processPointer(null));
}
// ANCHOR_END: null_checks

// ANCHOR: overflow_detection
fn safeAdd(a: i32, b: i32) !i32 {
    const result = @addWithOverflow(a, b);
    if (result[1] != 0) {
        std.debug.print("Overflow detected: {d} + {d}\n", .{ a, b });
        return error.Overflow;
    }
    return result[0];
}

test "overflow detection" {
    try testing.expectEqual(@as(i32, 100), try safeAdd(50, 50));
    try testing.expectError(error.Overflow, safeAdd(std.math.maxInt(i32), 1));
}
// ANCHOR_END: overflow_detection

// ANCHOR: debug_print_inspection
const Point = struct {
    x: i32,
    y: i32,

    fn debug(self: Point) void {
        std.debug.print("Point{{ x: {d}, y: {d} }}\n", .{ self.x, self.y });
    }

    fn debugWithContext(self: Point, context: []const u8) void {
        std.debug.print("[{s}] Point{{ x: {d}, y: {d} }}\n", .{ context, self.x, self.y });
    }
};

fn processPoint(point: Point) Point {
    point.debug();
    const result = Point{ .x = point.x * 2, .y = point.y * 2 };
    result.debugWithContext("After doubling");
    return result;
}

test "debug print inspection" {
    const p = Point{ .x = 10, .y = 20 };
    const result = processPoint(p);
    try testing.expectEqual(@as(i32, 20), result.x);
    try testing.expectEqual(@as(i32, 40), result.y);
}
// ANCHOR_END: debug_print_inspection

// ANCHOR: error_trace
fn level1() !void {
    return error.Level1Failed;
}

fn level2() !void {
    try level1();
}

fn level3() !void {
    level2() catch |err| {
        std.debug.print("Error caught at level3: {s}\n", .{@errorName(err)});
        std.debug.print("Stack trace available in debug mode\n", .{});
        return err;
    };
}

test "error trace" {
    try testing.expectError(error.Level1Failed, level3());
}
// ANCHOR_END: error_trace

// ANCHOR: memory_debugging
fn allocateAndFree(allocator: std.mem.Allocator) !void {
    std.debug.print("Allocating memory...\n", .{});
    const buffer = try allocator.alloc(u8, 100);
    defer {
        std.debug.print("Freeing memory...\n", .{});
        allocator.free(buffer);
    }

    std.debug.print("Using buffer of size {d}\n", .{buffer.len});
}

test "memory debugging with allocator tracking" {
    try allocateAndFree(testing.allocator);
    // testing.allocator detects leaks automatically
}
// ANCHOR_END: memory_debugging

// ANCHOR: conditional_debugging
const debug_enabled = builtin.mode == .Debug;

fn debugLog(comptime fmt: []const u8, args: anytype) void {
    if (debug_enabled) {
        std.debug.print("[DEBUG] " ++ fmt ++ "\n", args);
    }
}

fn computeValue(a: i32, b: i32) i32 {
    debugLog("Computing {d} + {d}", .{ a, b });
    const result = a + b;
    debugLog("Result: {d}", .{result});
    return result;
}

test "conditional debugging" {
    const result = computeValue(10, 20);
    try testing.expectEqual(@as(i32, 30), result);
}
// ANCHOR_END: conditional_debugging

// ANCHOR: crash_handler
const CrashInfo = struct {
    message: []const u8,
    location: []const u8,
    value: ?i32,

    fn report(self: CrashInfo) void {
        std.debug.print("=== CRASH REPORT ===\n", .{});
        std.debug.print("Message: {s}\n", .{self.message});
        std.debug.print("Location: {s}\n", .{self.location});
        if (self.value) |v| {
            std.debug.print("Value: {d}\n", .{v});
        }
        std.debug.print("==================\n", .{});
    }
};

fn riskyOperation(value: i32) !i32 {
    if (value < 0) {
        const info = CrashInfo{
            .message = "Negative value not allowed",
            .location = "riskyOperation",
            .value = value,
        };
        info.report();
        return error.InvalidValue;
    }
    return value * 2;
}

test "crash handler pattern" {
    try testing.expectError(error.InvalidValue, riskyOperation(-5));
    try testing.expectEqual(@as(i32, 20), try riskyOperation(10));
}
// ANCHOR_END: crash_handler

// ANCHOR: debug_symbols
fn complexFunction(a: i32, b: i32, c: i32) !i32 {
    std.debug.print("Input: a={d}, b={d}, c={d}\n", .{ a, b, c });

    if (a == 0) {
        std.debug.print("Error: a cannot be zero\n", .{});
        return error.DivisionByZero;
    }

    const step1 = @divTrunc(b, a);
    std.debug.print("Step 1: {d} / {d} = {d}\n", .{ b, a, step1 });

    const step2 = step1 + c;
    std.debug.print("Step 2: {d} + {d} = {d}\n", .{ step1, c, step2 });

    return step2;
}

test "debug with intermediate values" {
    try testing.expectEqual(@as(i32, 7), try complexFunction(2, 10, 2));
    try testing.expectError(error.DivisionByZero, complexFunction(0, 10, 2));
}
// ANCHOR_END: debug_symbols

// ANCHOR: unreachable_code
fn switchWithUnreachable(value: u8) u8 {
    switch (value) {
        0...10 => return value * 2,
        11...20 => return value * 3,
        21...255 => return value * 4,
    }
}

test "unreachable code paths" {
    try testing.expectEqual(@as(u8, 10), switchWithUnreachable(5));
    try testing.expectEqual(@as(u8, 45), switchWithUnreachable(15));
    try testing.expectEqual(@as(u8, 100), switchWithUnreachable(25));
}
// ANCHOR_END: unreachable_code
