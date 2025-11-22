const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdarg.h");
});

// ANCHOR: calling_printf
// Calling C variadic functions (printf)
pub extern "c" fn printf(format: [*:0]const u8, ...) c_int;

test "calling printf" {
    // Must cast literals for variadic functions
    const result = printf("Number: %d, String: %s\n", @as(c_int, 42), "test");
    try testing.expect(result > 0);
}
// ANCHOR_END: calling_printf

// ANCHOR: calling_sprintf
// Using sprintf with variadic arguments
pub extern "c" fn sprintf(buf: [*]u8, format: [*:0]const u8, ...) c_int;

test "calling sprintf" {
    var buffer: [100]u8 = undefined;

    const written = sprintf(&buffer, "x=%d, y=%d", @as(c_int, 10), @as(c_int, 20));
    try testing.expect(written > 0);

    const result = buffer[0..@as(usize, @intCast(written))];
    try testing.expect(std.mem.eql(u8, result, "x=10, y=20"));
}
// ANCHOR_END: calling_sprintf

// ANCHOR: defining_variadic
// Define a variadic function in Zig
fn sum_integers(count: c_int, ...) callconv(.c) c_int {
    var ap = @cVaStart();
    defer @cVaEnd(&ap);

    var total: c_int = 0;
    var i: c_int = 0;
    while (i < count) : (i += 1) {
        total += @cVaArg(&ap, c_int);
    }

    return total;
}

test "defining variadic function" {
    // Skip on platforms with known issues
    if (builtin.cpu.arch == .aarch64 and builtin.os.tag != .macos) {
        return error.SkipZigTest;
    }
    if (builtin.cpu.arch == .x86_64 and builtin.os.tag == .windows) {
        return error.SkipZigTest;
    }

    try testing.expectEqual(@as(c_int, 0), sum_integers(0));
    try testing.expectEqual(@as(c_int, 5), sum_integers(1, @as(c_int, 5)));
    try testing.expectEqual(@as(c_int, 15), sum_integers(3, @as(c_int, 3), @as(c_int, 5), @as(c_int, 7)));
}
// ANCHOR_END: defining_variadic

// ANCHOR: variadic_wrapper
// Wrapper for C variadic function
pub const Printf = struct {
    pub fn print(comptime fmt: []const u8, args: anytype) !void {
        // Build format string with proper specifiers
        var buffer: [1024]u8 = undefined;
        const result = try std.fmt.bufPrint(&buffer, fmt, args);

        _ = printf("%s", result.ptr);
    }

    pub fn printInt(value: i32) void {
        _ = printf("%d\n", @as(c_int, value));
    }

    pub fn printFloat(value: f64) void {
        _ = printf("%f\n", value);
    }

    pub fn printString(str: []const u8) void {
        _ = printf("%.*s\n", @as(c_int, @intCast(str.len)), str.ptr);
    }
};

test "variadic wrapper functions" {
    Printf.printInt(42);
    Printf.printFloat(3.14159);
    Printf.printString("Hello from wrapper");
}
// ANCHOR_END: variadic_wrapper

// ANCHOR: type_checking
// Type-safe variadic wrapper
export fn print_values(format: [*:0]const u8, int_count: c_int, ints: [*]const c_int, str_count: c_int, strs: [*]const [*:0]const u8) c_int {
    // This is safer than true variadic functions
    // We know exactly what types and how many args we have
    _ = format;
    _ = int_count;
    _ = ints;
    _ = str_count;
    _ = strs;

    return 0;
}

test "type-safe variadic alternative" {
    const ints = [_]c_int{ 1, 2, 3 };
    const strs = [_][*:0]const u8{ "hello".ptr, "world".ptr };

    _ = print_values("fmt", 3, &ints, 2, &strs);
}
// ANCHOR_END: type_checking

// ANCHOR: forwarding_varargs
// Forwarding variadic arguments
export fn log_message(level: c_int, format: [*:0]const u8, ...) c_int {
    // Prepend log level
    const level_str = switch (level) {
        0 => "DEBUG",
        1 => "INFO",
        2 => "WARN",
        3 => "ERROR",
        else => "UNKNOWN",
    };

    _ = printf("[%s] ", level_str.ptr);

    // Note: We can't easily forward va_list in Zig
    // Better to reconstruct the call
    _ = format;

    return 0;
}

test "forwarding variadic arguments" {
    _ = log_message(1, "Test message: %d\n", @as(c_int, 42));
}
// ANCHOR_END: forwarding_varargs

// ANCHOR: mixed_types
// Variadic function with mixed types
fn print_mixed(count: c_int, ...) callconv(.c) void {
    var ap = @cVaStart();
    defer @cVaEnd(&ap);

    var i: c_int = 0;
    while (i < count) : (i += 1) {
        // First arg is type indicator
        const type_id = @cVaArg(&ap, c_int);

        switch (type_id) {
            0 => { // int
                const value = @cVaArg(&ap, c_int);
                _ = printf("int: %d\n", value);
            },
            1 => { // double
                const value = @cVaArg(&ap, f64);
                _ = printf("double: %f\n", value);
            },
            2 => { // string
                const value = @cVaArg(&ap, [*:0]const u8);
                _ = printf("string: %s\n", value);
            },
            else => {},
        }
    }
}

test "mixed type variadic" {
    if (builtin.cpu.arch == .aarch64 and builtin.os.tag != .macos) {
        return error.SkipZigTest;
    }
    if (builtin.cpu.arch == .x86_64 and builtin.os.tag == .windows) {
        return error.SkipZigTest;
    }

    print_mixed(
        3,
        @as(c_int, 0),
        @as(c_int, 42), // int
        @as(c_int, 1),
        @as(f64, 3.14), // double
        @as(c_int, 2),
        "hello".ptr, // string
    );
}
// ANCHOR_END: mixed_types

// ANCHOR: safer_alternative
// Safer alternative to variadic functions using tuples
pub fn printFormatted(comptime fmt: []const u8, args: anytype) void {
    const result = std.fmt.allocPrint(std.heap.c_allocator, fmt, args) catch return;
    defer std.heap.c_allocator.free(result);

    _ = printf("%s", result.ptr);
}

test "safer tuple-based alternative" {
    printFormatted("Values: {d}, {s}, {d:.2}\n", .{ 42, "test", 3.14159 });
}
// ANCHOR_END: safer_alternative

// ANCHOR: examining_varargs
// Examining variadic arguments
export fn count_non_zero(count: c_int, ...) c_int {
    var ap = @cVaStart();
    defer @cVaEnd(&ap);

    var non_zero: c_int = 0;
    var i: c_int = 0;

    while (i < count) : (i += 1) {
        const value = @cVaArg(&ap, c_int);
        if (value != 0) {
            non_zero += 1;
        }
    }

    return non_zero;
}

test "examining variadic arguments" {
    if (builtin.cpu.arch == .aarch64 and builtin.os.tag != .macos) {
        return error.SkipZigTest;
    }
    if (builtin.cpu.arch == .x86_64 and builtin.os.tag == .windows) {
        return error.SkipZigTest;
    }

    const result = count_non_zero(5, @as(c_int, 1), @as(c_int, 0), @as(c_int, 3), @as(c_int, 0), @as(c_int, 5));
    try testing.expectEqual(@as(c_int, 3), result);
}
// ANCHOR_END: examining_varargs
