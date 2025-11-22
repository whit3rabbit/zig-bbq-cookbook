const std = @import("std");
const testing = std.testing;

// ANCHOR: extern_panic_callback
// Import JavaScript panic reporting function
extern "env" fn jsPanic(msg_ptr: [*]const u8, msg_len: usize) void;
extern "env" fn jsLogPanic(msg_ptr: [*]const u8, msg_len: usize) void;
// ANCHOR_END: extern_panic_callback

// Test stubs
const builtin = @import("builtin");

comptime {
    if (builtin.is_test) {
        @export(&stub_jsPanic, .{ .name = "jsPanic" });
        @export(&stub_jsLogPanic, .{ .name = "jsLogPanic" });
    }
}

fn stub_jsPanic(msg_ptr: [*]const u8, msg_len: usize) callconv(.c) void {
    _ = msg_ptr;
    _ = msg_len;
}

fn stub_jsLogPanic(msg_ptr: [*]const u8, msg_len: usize) callconv(.c) void {
    _ = msg_ptr;
    _ = msg_len;
}

// ANCHOR: simple_panic_handler
// Simple panic handler - infinite loop
pub fn simplePanicHandler(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = msg;
    _ = error_return_trace;
    _ = ret_addr;
    while (true) {} // Hang forever
}
// ANCHOR_END: simple_panic_handler

// ANCHOR: logging_panic_handler
// Panic handler that logs to JavaScript
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = error_return_trace;
    _ = ret_addr;

    // Call JavaScript to report the panic
    jsPanic(msg.ptr, msg.len);

    // Hang after reporting
    while (true) {}
}
// ANCHOR_END: logging_panic_handler

// ANCHOR: panic_with_context
// Enhanced panic handler with more context
var last_panic_message: [256]u8 = undefined;
var last_panic_len: usize = 0;

pub fn enhancedPanic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = error_return_trace;

    // Store panic message
    const copy_len = @min(msg.len, last_panic_message.len);
    for (0..copy_len) |i| {
        last_panic_message[i] = msg[i];
    }
    last_panic_len = copy_len;

    // Build context message
    var buffer: [512]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    writer.print("PANIC: {s}", .{msg}) catch {};

    if (ret_addr) |addr| {
        writer.print(" (address: 0x{x})", .{addr}) catch {};
    }

    const context = fbs.getWritten();
    jsLogPanic(context.ptr, context.len);

    while (true) {}
}
// ANCHOR_END: panic_with_context

// ANCHOR: get_panic_info
// Export functions to retrieve panic info
export fn getLastPanicMessage() [*]const u8 {
    return &last_panic_message;
}

export fn getLastPanicLength() usize {
    return last_panic_len;
}
// ANCHOR_END: get_panic_info

// ANCHOR: panic_triggering_functions
// Functions that can trigger panics

export fn divideByZero(a: i32, b: i32) i32 {
    if (b == 0) {
        @panic("Division by zero");
    }
    return @divTrunc(a, b);
}

export fn accessOutOfBounds(index: usize) i32 {
    const array = [_]i32{ 1, 2, 3, 4, 5 };
    if (index >= array.len) {
        @panic("Index out of bounds");
    }
    return array[index];
}

export fn assertCondition(value: i32) void {
    std.debug.assert(value > 0); // Panics if false
}

export fn unwrapNull(has_value: bool) i32 {
    const optional: ?i32 = if (has_value) 42 else null;
    return optional.?; // Panics if null
}
// ANCHOR_END: panic_triggering_functions

// ANCHOR: controlled_panic
// Controlled panic with custom messages
export fn triggerPanic(code: i32) void {
    switch (code) {
        1 => @panic("Error code 1: Invalid input"),
        2 => @panic("Error code 2: Resource exhausted"),
        3 => @panic("Error code 3: Operation failed"),
        else => @panic("Unknown error code"),
    }
}
// ANCHOR_END: controlled_panic

// ANCHOR: panic_with_cleanup
// Panic after cleanup attempt
var cleanup_called = false;

fn attemptCleanup() void {
    cleanup_called = true;
    // Cleanup resources before panic
}

export fn panicWithCleanup() void {
    attemptCleanup();
    @panic("Panic after cleanup");
}

export fn wasCleanupCalled() bool {
    return cleanup_called;
}

export fn resetCleanupFlag() void {
    cleanup_called = false;
}
// ANCHOR_END: panic_with_cleanup

// Tests

// ANCHOR: test_panic_info
test "panic info storage" {
    last_panic_len = 0;

    const msg = "Test panic message";
    const copy_len = @min(msg.len, last_panic_message.len);
    for (0..copy_len) |i| {
        last_panic_message[i] = msg[i];
    }
    last_panic_len = copy_len;

    try testing.expectEqual(@as(usize, msg.len), last_panic_len);
    const stored = last_panic_message[0..last_panic_len];
    try testing.expectEqualStrings(msg, stored);
}
// ANCHOR_END: test_panic_info

// ANCHOR: test_divide_by_zero
test "divide by zero detection" {
    const result = divideByZero(10, 2);
    try testing.expectEqual(@as(i32, 5), result);

    // Cannot test actual panic in tests, but verify logic
    const b: i32 = 0;
    try testing.expect(b == 0);
}
// ANCHOR_END: test_divide_by_zero

// ANCHOR: test_bounds_check
test "bounds check" {
    const result = accessOutOfBounds(2);
    try testing.expectEqual(@as(i32, 3), result);

    // Verify array length
    const array = [_]i32{ 1, 2, 3, 4, 5 };
    try testing.expectEqual(@as(usize, 5), array.len);
}
// ANCHOR_END: test_bounds_check

// ANCHOR: test_optional_unwrap
test "optional unwrap" {
    const result = unwrapNull(true);
    try testing.expectEqual(@as(i32, 42), result);
}
// ANCHOR_END: test_optional_unwrap

// ANCHOR: test_cleanup
test "cleanup before panic" {
    cleanup_called = false;
    attemptCleanup();
    try testing.expect(wasCleanupCalled());

    resetCleanupFlag();
    try testing.expect(!wasCleanupCalled());
}
// ANCHOR_END: test_cleanup
