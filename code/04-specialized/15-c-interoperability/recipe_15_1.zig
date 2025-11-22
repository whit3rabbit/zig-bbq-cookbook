const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_cimport
// Import C standard library headers
const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("math.h");
    @cInclude("string.h");
});
// ANCHOR_END: basic_cimport

// ANCHOR: calling_printf
test "calling C printf" {
    const result = c.printf("Hello from Zig via C printf!\n");
    try testing.expect(result > 0);
}
// ANCHOR_END: calling_printf

// ANCHOR: calling_math
test "calling C math functions" {
    const result = c.sqrt(16.0);
    try testing.expectApproxEqAbs(4.0, result, 0.001);

    const power = c.pow(2.0, 8.0);
    try testing.expectApproxEqAbs(256.0, power, 0.001);

    const sine = c.sin(0.0);
    try testing.expectApproxEqAbs(0.0, sine, 0.001);
}
// ANCHOR_END: calling_math

// ANCHOR: c_types
test "using C type primitives" {
    const x: c_int = 42;
    const y: c_long = 1234567890;
    const z: c_char = 'A';

    try testing.expectEqual(@as(c_int, 42), x);
    try testing.expectEqual(@as(c_long, 1234567890), y);
    try testing.expectEqual(@as(c_char, 'A'), z);
}
// ANCHOR_END: c_types

// ANCHOR: strlen_example
test "calling C strlen" {
    const str = "Hello, World!";
    const len = c.strlen(str.ptr);
    try testing.expectEqual(@as(usize, 13), len);
}
// ANCHOR_END: strlen_example

// ANCHOR: cdefine_example
// Using @cDefine to set preprocessor macros
const c_with_defines = @cImport({
    @cDefine("_GNU_SOURCE", "1");
    @cInclude("stdio.h");
});

test "using @cDefine" {
    // The define affects how headers are processed
    _ = c_with_defines.printf("Testing with defines\n");
}
// ANCHOR_END: cdefine_example

// ANCHOR: conditional_import
// Conditional imports based on compile-time conditions
const builtin = @import("builtin");

const c_platform = @cImport({
    if (builtin.os.tag == .windows) {
        @cInclude("windows.h");
    } else {
        @cInclude("unistd.h");
    }
    @cInclude("stdlib.h");
});

test "conditional C imports" {
    // Test that platform-specific imports work
    _ = c_platform;
}
// ANCHOR_END: conditional_import

// ANCHOR: c_constants
test "using C constants" {
    // Access C preprocessor constants
    const eof = c.EOF;
    try testing.expect(eof < 0);

    // Many C constants are available
    const null_char = c.NULL;
    try testing.expectEqual(@as(?*anyopaque, null), null_char);
}
// ANCHOR_END: c_constants

// ANCHOR: allocator_with_c
test "using Zig allocator with C functions" {
    var buffer: [100]u8 = undefined;

    // sprintf is a C function that writes to a buffer
    const result = c.sprintf(&buffer, "Number: %d, String: %s", @as(c_int, 42), "test");
    try testing.expect(result > 0);

    // Verify the output
    const output = buffer[0..@as(usize, @intCast(result))];
    try testing.expect(std.mem.eql(u8, output, "Number: 42, String: test"));
}
// ANCHOR_END: allocator_with_c

// ANCHOR: multiple_headers
// Import multiple related headers
const c_time = @cImport({
    @cInclude("time.h");
    @cInclude("stdlib.h");
});

test "working with C time functions" {
    const timestamp = c_time.time(null);
    try testing.expect(timestamp > 0);

    // C functions can be called naturally from Zig
    const tm_ptr = c_time.localtime(&timestamp);
    try testing.expect(tm_ptr != null);
}
// ANCHOR_END: multiple_headers

// ANCHOR: error_handling
test "error handling with C functions" {
    // C functions that can fail often return error codes or NULL
    // We need to handle these cases explicitly in Zig

    const invalid_ptr: ?*c.FILE = null;
    try testing.expectEqual(@as(?*c.FILE, null), invalid_ptr);

    // Many C functions return -1 or NULL on error
    // Zig's type system helps us handle these cases safely
}
// ANCHOR_END: error_handling

// ANCHOR: c_void_pointer
test "working with C void pointers" {
    // C void* is represented as ?*anyopaque in Zig
    var value: c_int = 42;
    const void_ptr: ?*anyopaque = @ptrCast(&value);

    // Cast back to the original type
    const int_ptr: *c_int = @ptrCast(@alignCast(void_ptr.?));
    try testing.expectEqual(@as(c_int, 42), int_ptr.*);
}
// ANCHOR_END: c_void_pointer
