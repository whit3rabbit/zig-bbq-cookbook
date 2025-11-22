// Recipe 0.7: Functions and the Standard Library (EXPANDED)
// Target Zig Version: 0.15.2
//
// This recipe covers defining functions, working with the standard library,
// and introduces basic comptime parameters for generic functions.

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_function
// Part 1: Basic Function Definition
//
// Functions are defined with `fn`, must declare parameter types and return type

fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic function definition" {
    const result = add(5, 3);
    try testing.expectEqual(@as(i32, 8), result);
}

fn greet(name: []const u8) void {
    // void means no return value
    std.debug.print("Hello, {s}!\n", .{name});
}

test "function with no return value" {
    // Functions returning void still get called normally
    greet("Zig");
    // Can't test print output easily, but this shows the pattern
}

// Functions can take multiple parameters of different types
fn formatMessage(count: usize, item: []const u8) void {
    std.debug.print("You have {d} {s}\n", .{ count, item });
}

test "function with multiple parameters" {
    formatMessage(5, "apples");
}
// ANCHOR_END: basic_function

// ANCHOR: error_return
// Part 2: Functions Returning Errors
//
// Use `!T` to return either an error or a value
// This is Zig's error handling mechanism

fn divide(a: i32, b: i32) !i32 {
    if (b == 0) {
        return error.DivisionByZero;
    }
    return @divTrunc(a, b);
}

test "function returning error union" {
    // Success case
    const result = try divide(10, 2);
    try testing.expectEqual(@as(i32, 5), result);

    // Error case
    const err_result = divide(10, 0);
    try testing.expectError(error.DivisionByZero, err_result);
}

// Can use `try` to propagate errors up the call stack
fn safeDivide(a: i32, b: i32) !i32 {
    // `try` returns on error, otherwise unwraps the value
    const result = try divide(a, b);
    return result * 2;
}

test "propagating errors with try" {
    const result = try safeDivide(10, 2);
    try testing.expectEqual(@as(i32, 10), result);

    // Error propagates up
    const err = safeDivide(10, 0);
    try testing.expectError(error.DivisionByZero, err);
}

// Can use `catch` to handle errors inline
fn divideOrDefault(a: i32, b: i32) i32 {
    return divide(a, b) catch 0;
}

test "handling errors with catch" {
    const result1 = divideOrDefault(10, 2);
    try testing.expectEqual(@as(i32, 5), result1);

    const result2 = divideOrDefault(10, 0);
    try testing.expectEqual(@as(i32, 0), result2);
}
// ANCHOR_END: error_return

// ANCHOR: stdlib_usage
// Part 3: Using the Standard Library
//
// Import std and use its modules

test "using standard library for strings" {
    const str = "Hello, World!";

    // std.mem - memory operations
    try testing.expect(std.mem.startsWith(u8, str, "Hello"));
    try testing.expect(std.mem.endsWith(u8, str, "World!"));

    // Finding substrings
    const index = std.mem.indexOf(u8, str, "World");
    try testing.expect(index != null);
    try testing.expectEqual(@as(usize, 7), index.?);
}

test "using standard library for math" {
    // Builtin math operations
    const abs_val = @abs(@as(i32, -42));
    try testing.expectEqual(@as(i32, 42), abs_val);

    const min_val = @min(10, 20);
    try testing.expectEqual(@as(i32, 10), min_val);

    const max_val = @max(10, 20);
    try testing.expectEqual(@as(i32, 20), max_val);

    // std.math - Check for NaN, infinity
    const nan = std.math.nan(f32);
    try testing.expect(std.math.isNan(nan));

    const inf = std.math.inf(f32);
    try testing.expect(std.math.isInf(inf));
}

test "using standard library for collections" {
    // ArrayList - growable array
    var list = std.ArrayList(i32){};
    defer list.deinit(testing.allocator);

    try list.append(testing.allocator, 1);
    try list.append(testing.allocator, 2);
    try list.append(testing.allocator, 3);

    try testing.expectEqual(@as(usize, 3), list.items.len);
    try testing.expectEqual(@as(i32, 2), list.items[1]);

    // HashMap - key-value mapping
    var map = std.StringHashMap(i32).init(testing.allocator);
    defer map.deinit();

    // Note: StringHashMap stores key references, not copies.
    // String literals like "answer" are safe because they have static lifetime.
    // For dynamic keys, see idiomatic_examples.zig Cache.put() for ownership patterns.
    try map.put("answer", 42);
    try map.put("year", 2025);

    const value = map.get("answer");
    try testing.expect(value != null);
    try testing.expectEqual(@as(i32, 42), value.?);
}

test "using std.debug.print for logging" {
    // std.debug.print outputs to stderr
    std.debug.print("\n[DEBUG] This is a debug message\n", .{});

    // Format specifiers:
    // {d} - decimal integer
    // {s} - string
    // {x} - hexadecimal
    // {b} - binary
    const num: i32 = 42;
    const name = "Zig";
    std.debug.print("[DEBUG] num={d}, name={s}\n", .{ num, name });
}
// ANCHOR_END: stdlib_usage

// ANCHOR: comptime_basics
// Part 4: Comptime Basics - Generic Functions
//
// Use `comptime` to create generic functions that work with any type

fn maximum(comptime T: type, a: T, b: T) T {
    // T is determined at compile time
    // This function works with any type that supports comparison
    return if (a > b) a else b;
}

test "generic function with comptime type parameter" {
    // Works with integers
    const max_int = maximum(i32, 10, 20);
    try testing.expectEqual(@as(i32, 20), max_int);

    // Works with floats
    const max_float = maximum(f32, 3.14, 2.71);
    try testing.expect(@abs(max_float - 3.14) < 0.01);

    // Works with unsigned integers
    const max_uint = maximum(u8, 100, 200);
    try testing.expectEqual(@as(u8, 200), max_uint);
}

// Generic function that works with any array type
fn sum(comptime T: type, items: []const T) T {
    var total: T = 0;
    for (items) |item| {
        total += item;
    }
    return total;
}

test "generic sum function" {
    const ints = [_]i32{ 1, 2, 3, 4, 5 };
    const total = sum(i32, &ints);
    try testing.expectEqual(@as(i32, 15), total);

    const floats = [_]f32{ 1.0, 2.0, 3.0 };
    const float_sum = sum(f32, &floats);
    try testing.expect(@abs(float_sum - 6.0) < 0.01);
}

// Comptime parameters must be known at compile time
fn createArray(comptime size: usize, comptime T: type, value: T) [size]T {
    var arr: [size]T = undefined;
    for (0..size) |i| {
        arr[i] = value;
    }
    return arr;
}

test "comptime size parameter" {
    // Size must be compile-time known
    const arr = createArray(5, i32, 42);

    try testing.expectEqual(@as(usize, 5), arr.len);
    try testing.expectEqual(@as(i32, 42), arr[0]);
    try testing.expectEqual(@as(i32, 42), arr[4]);
}

// Why comptime is needed: Type information doesn't exist at runtime
fn typeInfo(comptime T: type) void {
    // @typeName returns the name of a type
    const name = @typeName(T);
    std.debug.print("Type: {s}\n", .{name});

    // @sizeOf returns size in bytes
    const size = @sizeOf(T);
    std.debug.print("Size: {d} bytes\n", .{size});
}

test "type introspection with comptime" {
    typeInfo(i32);
    typeInfo(f64);
    typeInfo([10]u8);
}

// Common comptime error: trying to use runtime value as comptime parameter
test "understanding comptime errors" {
    // This works - comptime known
    const size: usize = 5;
    var arr1: [size]i32 = undefined;
    _ = &arr1;

    // This would NOT work - runtime value:
    // var runtime_size: usize = 5;
    // var arr2: [runtime_size]i32 = undefined;  // error: unable to resolve comptime value

    // For runtime-sized collections, use ArrayList
    var list = std.ArrayList(i32){};
    defer list.deinit(testing.allocator);

    const runtime_size: usize = 5;
    for (0..runtime_size) |_| {
        try list.append(testing.allocator, 0);
    }

    try testing.expectEqual(runtime_size, list.items.len);
}
// ANCHOR_END: comptime_basics

// Summary examples

test "putting it all together" {
    // Define a generic function that handles errors
    const findMax = struct {
        fn call(comptime T: type, items: []const T) !T {
            if (items.len == 0) {
                return error.EmptySlice;
            }
            var max_val = items[0];
            for (items[1..]) |item| {
                if (item > max_val) {
                    max_val = item;
                }
            }
            return max_val;
        }
    }.call;

    const numbers = [_]i32{ 3, 7, 2, 9, 1 };
    const max_num = try findMax(i32, &numbers);
    try testing.expectEqual(@as(i32, 9), max_num);

    // Error case
    const empty: [0]i32 = .{};
    const err = findMax(i32, &empty);
    try testing.expectError(error.EmptySlice, err);
}

// Summary:
// - Functions defined with `fn`, explicit types required
// - `!T` for error returns, use `try` or `catch` to handle
// - std library has modules: std.mem, std.math, std.debug, etc.
// - `comptime` creates generic functions that work with any type
// - comptime parameters must be compile-time known
// - Use ArrayList for runtime-sized collections
