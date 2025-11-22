// Recipe 0.13: Testing and Debugging Fundamentals
// Target Zig Version: 0.15.2
//
// This recipe covers creating tests, using std.testing, and debugging techniques.

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_testing
// Part 1: Basic Testing with std.testing
//
// Tests are first-class citizens in Zig

test "basic test example" {
    // Test blocks start with 'test' keyword
    // They run when you execute `zig test filename.zig`

    const x: i32 = 42;
    const y: i32 = 42;

    // expect: assert a boolean condition
    try testing.expect(x == y);
}

test "testing equality" {
    // expectEqual: check two values are equal
    const result = 2 + 2;
    try testing.expectEqual(@as(i32, 4), result);

    // Type must match exactly
    const a: u8 = 10;
    const b: u8 = 10;
    try testing.expectEqual(a, b);
}

test "testing strings" {
    const str1 = "hello";
    const str2 = "hello";

    // For strings, use std.mem.eql
    try testing.expect(std.mem.eql(u8, str1, str2));

    // This would NOT work:
    // try testing.expectEqual(str1, str2);  // Compares pointers, not content
}

test "testing errors" {
    const divide = struct {
        fn call(a: i32, b: i32) !i32 {
            if (b == 0) return error.DivisionByZero;
            return @divTrunc(a, b);
        }
    }.call;

    // expectError: check a specific error is returned
    const result = divide(10, 0);
    try testing.expectError(error.DivisionByZero, result);

    // Successful case
    const success = try divide(10, 2);
    try testing.expectEqual(@as(i32, 5), success);
}

test "testing floating point" {
    const pi: f32 = 3.14159;

    // For floats, use epsilon comparison
    try testing.expect(@abs(pi - 3.14159) < 0.00001);

    // Or use expectApproxEqAbs
    try testing.expectApproxEqAbs(@as(f32, 3.14159), pi, 0.00001);
}
// ANCHOR_END: basic_testing

// ANCHOR: advanced_testing
// Part 2: Advanced Testing Patterns
//
// More sophisticated testing techniques

test "testing with allocators" {
    // Always use testing.allocator in tests
    // It detects memory leaks automatically

    var list = std.ArrayList(i32){};
    defer list.deinit(testing.allocator);

    try list.append(testing.allocator, 1);
    try list.append(testing.allocator, 2);
    try list.append(testing.allocator, 3);

    try testing.expectEqual(@as(usize, 3), list.items.len);
    try testing.expectEqual(@as(i32, 2), list.items[1]);

    // If you forget defer, test fails with memory leak error
}

test "testing slices" {
    const expected = [_]i32{ 1, 2, 3, 4, 5 };
    const actual = [_]i32{ 1, 2, 3, 4, 5 };

    // expectEqualSlices: compare entire slices
    try testing.expectEqualSlices(i32, &expected, &actual);

    // Works with strings too
    const str = "hello";
    try testing.expectEqualSlices(u8, "hello", str);
}

test "testing optional values" {
    const maybe_value: ?i32 = 42;
    const no_value: ?i32 = null;

    // Check if optional has value
    try testing.expect(maybe_value != null);
    try testing.expect(no_value == null);

    // Unwrap and check value
    if (maybe_value) |value| {
        try testing.expectEqual(@as(i32, 42), value);
    } else {
        try testing.expect(false); // Should not reach here
    }
}

test "testing panics" {
    const willPanic = struct {
        fn call() void {
            @panic("This is a panic!");
        }
    }.call;

    // Can't directly test for panics in tests
    // But you can test conditions that would cause them

    const safe_optional: ?i32 = 42;
    if (safe_optional) |val| {
        try testing.expectEqual(@as(i32, 42), val);
    }

    // Using .? would panic if null - avoid in tests unless intended
    _ = willPanic; // Acknowledged but not called
}

fn fibonacci(n: u32) u32 {
    if (n <= 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

test "testing a function with multiple cases" {
    try testing.expectEqual(@as(u32, 0), fibonacci(0));
    try testing.expectEqual(@as(u32, 1), fibonacci(1));
    try testing.expectEqual(@as(u32, 1), fibonacci(2));
    try testing.expectEqual(@as(u32, 2), fibonacci(3));
    try testing.expectEqual(@as(u32, 3), fibonacci(4));
    try testing.expectEqual(@as(u32, 5), fibonacci(5));
    try testing.expectEqual(@as(u32, 8), fibonacci(6));
}
// ANCHOR_END: advanced_testing

// ANCHOR: debugging
// Part 3: Debugging Techniques
//
// Tools and patterns for debugging Zig code

test "debug printing" {
    // std.debug.print outputs to stderr
    std.debug.print("\n[TEST] Starting debug print test\n", .{});

    const x: i32 = 42;
    const name = "Zig";

    // Format specifiers:
    // {d} - decimal
    // {s} - string
    // {x} - hexadecimal
    // {b} - binary
    // {} - default format for type
    std.debug.print("x={d}, name={s}\n", .{ x, name });
    std.debug.print("x in hex={x}, binary={b}\n", .{ x, x });

    // Print with default formatter
    std.debug.print("Value: {}\n", .{x});
}

test "printing arrays and slices" {
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };

    std.debug.print("\nArray: ", .{});
    for (numbers) |n| {
        std.debug.print("{d} ", .{n});
    }
    std.debug.print("\n", .{});

    // Print with array formatter
    std.debug.print("Numbers: {any}\n", .{numbers});
}

test "printing structs" {
    const Point = struct {
        x: i32,
        y: i32,
    };

    const p = Point{ .x = 10, .y = 20 };

    // {any} prints the struct with field names
    std.debug.print("\nPoint: {any}\n", .{p});

    // Manual printing
    std.debug.print("Point {{ x={d}, y={d} }}\n", .{ p.x, p.y });
}

test "conditional debug output" {
    const debug_mode = true;

    if (debug_mode) {
        std.debug.print("\n[DEBUG] This only prints in debug mode\n", .{});
    }

    // Use comptime to completely remove debug code in release builds
    const comptime_debug = struct {
        fn log(comptime fmt: []const u8, args: anytype) void {
            if (@import("builtin").mode == .Debug) {
                std.debug.print(fmt, args);
            }
        }
    }.log;

    comptime_debug("\n[COMPTIME DEBUG] This is removed in release\n", .{});
}

test "assertions" {
    const x: i32 = 42;

    // std.debug.assert panics if condition is false
    // Only in Debug/ReleaseSafe builds - removed in ReleaseFast/ReleaseSmall
    std.debug.assert(x == 42);

    // Always runs, even in release:
    if (x != 42) {
        @panic("x must be 42!");
    }
}

test "logging levels" {
    // std.log provides structured logging
    std.log.debug("This is a debug message", .{});
    std.log.info("This is an info message", .{});
    std.log.warn("This is a warning", .{});
    std.log.err("This is an error", .{});

    // Log with context
    const value: i32 = 100;
    std.log.info("Value is {d}", .{value});
}

fn debugHelper(x: i32) void {
    std.debug.print("debugHelper called with {d}\n", .{x});
    std.debug.print("Stack trace:\n", .{});
    std.debug.dumpCurrentStackTrace(@returnAddress());
}

test "stack traces" {
    // Stack traces help find where errors occur
    std.debug.print("\n[TEST] Stack trace example:\n", .{});
    debugHelper(42);
}
// ANCHOR_END: debugging

// Organizing tests

test "test organization" {
    // Tests are typically organized near the code they test
    // Or in the same file

    const MyStruct = struct {
        value: i32,

        fn init(val: i32) @This() {
            return .{ .value = val };
        }

        fn double(self: @This()) i32 {
            return self.value * 2;
        }

        // Tests can be inside structs too
        test "MyStruct.double" {
            const s = init(21);
            try testing.expectEqual(@as(i32, 42), s.double());
        }
    };

    const s = MyStruct.init(10);
    try testing.expectEqual(@as(i32, 20), s.double());
}

test "test names can be descriptive" {
    // Test names are strings, so they can be very descriptive
    // This helps when tests fail

    const add = struct {
        fn call(a: i32, b: i32) i32 {
            return a + b;
        }
    }.call;

    try testing.expectEqual(@as(i32, 5), add(2, 3));
}

// Summary:
// - Use `test` blocks for testing
// - std.testing provides assertion functions
// - testing.allocator detects memory leaks
// - Use std.debug.print for debugging output
// - Use {any} formatter to print complex types
// - std.log provides structured logging
// - Tests run with `zig test filename.zig`
// - Tests are first-class - write them alongside code
