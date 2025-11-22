const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_export
// Export a simple function callable from C
export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic exported function" {
    const result = add(5, 7);
    try testing.expectEqual(@as(i32, 12), result);
}
// ANCHOR_END: basic_export

// ANCHOR: export_with_c_types
// Use C types for better compatibility
export fn multiply(a: c_int, b: c_int) c_int {
    return a * b;
}

test "exported function with C types" {
    const result = multiply(6, 7);
    try testing.expectEqual(@as(c_int, 42), result);
}
// ANCHOR_END: export_with_c_types

// ANCHOR: export_struct
// Struct with C ABI for use in exported functions
pub const Point = extern struct {
    x: c_int,
    y: c_int,
};

export fn create_point(x: c_int, y: c_int) Point {
    return Point{ .x = x, .y = y };
}

export fn point_distance_squared(p: Point) c_int {
    return p.x * p.x + p.y * p.y;
}

test "exported struct operations" {
    const p = create_point(3, 4);
    try testing.expectEqual(@as(c_int, 3), p.x);
    try testing.expectEqual(@as(c_int, 4), p.y);

    const dist_sq = point_distance_squared(p);
    try testing.expectEqual(@as(c_int, 25), dist_sq);
}
// ANCHOR_END: export_struct

// ANCHOR: export_array_operations
// Export function that works with array pointers
export fn sum_array(arr: [*]const c_int, len: usize) c_int {
    var total: c_int = 0;
    for (0..len) |i| {
        total += arr[i];
    }
    return total;
}

test "exported array operation" {
    const numbers = [_]c_int{ 1, 2, 3, 4, 5 };
    const result = sum_array(&numbers, numbers.len);
    try testing.expectEqual(@as(c_int, 15), result);
}
// ANCHOR_END: export_array_operations

// ANCHOR: export_string_operations
// Export function that works with C strings
export fn string_length(str: [*:0]const u8) usize {
    var len: usize = 0;
    while (str[len] != 0) {
        len += 1;
    }
    return len;
}

test "exported string operation" {
    const text = "Hello, World!";
    const len = string_length(text.ptr);
    try testing.expectEqual(@as(usize, 13), len);
}
// ANCHOR_END: export_string_operations

// ANCHOR: export_error_handling
// Export function that returns error codes
export fn safe_divide(a: c_int, b: c_int, result: *c_int) c_int {
    if (b == 0) {
        return -1; // Error code
    }
    result.* = @divTrunc(a, b);
    return 0; // Success
}

test "exported function with error handling" {
    var result: c_int = 0;

    // Successful division
    var status = safe_divide(10, 2, &result);
    try testing.expectEqual(@as(c_int, 0), status);
    try testing.expectEqual(@as(c_int, 5), result);

    // Division by zero
    status = safe_divide(10, 0, &result);
    try testing.expectEqual(@as(c_int, -1), status);
}
// ANCHOR_END: export_error_handling

// ANCHOR: export_opaque_type
// Export opaque type for encapsulation
const Counter = struct {
    value: c_int,
};

export fn counter_create() ?*Counter {
    const allocator = std.heap.c_allocator;
    const counter = allocator.create(Counter) catch return null;
    counter.* = Counter{ .value = 0 };
    return counter;
}

export fn counter_increment(counter: ?*Counter) void {
    if (counter) |c| {
        c.value += 1;
    }
}

export fn counter_get_value(counter: ?*const Counter) c_int {
    if (counter) |c| {
        return c.value;
    }
    return -1;
}

export fn counter_destroy(counter: ?*Counter) void {
    if (counter) |c| {
        const allocator = std.heap.c_allocator;
        allocator.destroy(c);
    }
}

test "exported opaque type" {
    const counter = counter_create();
    try testing.expect(counter != null);

    try testing.expectEqual(@as(c_int, 0), counter_get_value(counter));

    counter_increment(counter);
    counter_increment(counter);
    try testing.expectEqual(@as(c_int, 2), counter_get_value(counter));

    counter_destroy(counter);
}
// ANCHOR_END: export_opaque_type

// ANCHOR: export_callback
// Export function that takes a callback
const CallbackFn = *const fn (c_int) callconv(.c) void;

var callback_result: c_int = 0;

export fn process_with_callback(value: c_int, callback: CallbackFn) void {
    callback(value * 2);
}

fn test_callback(value: c_int) callconv(.c) void {
    callback_result = value;
}

test "exported function with callback" {
    callback_result = 0;
    process_with_callback(21, test_callback);
    try testing.expectEqual(@as(c_int, 42), callback_result);
}
// ANCHOR_END: export_callback

// ANCHOR: export_buffer_operations
// Export function that modifies a buffer
export fn to_uppercase(buffer: [*]u8, len: usize) void {
    for (0..len) |i| {
        if (buffer[i] >= 'a' and buffer[i] <= 'z') {
            buffer[i] -= 32;
        }
    }
}

test "exported buffer modification" {
    var text = "hello world".*;
    to_uppercase(&text, text.len);
    try testing.expect(std.mem.eql(u8, &text, "HELLO WORLD"));
}
// ANCHOR_END: export_buffer_operations

// ANCHOR: export_variable
// Export global variables
export var global_counter: c_int = 0;

export fn increment_global() c_int {
    global_counter += 1;
    return global_counter;
}

test "exported global variable" {
    global_counter = 0;

    const v1 = increment_global();
    try testing.expectEqual(@as(c_int, 1), v1);

    const v2 = increment_global();
    try testing.expectEqual(@as(c_int, 2), v2);

    try testing.expectEqual(@as(c_int, 2), global_counter);
}
// ANCHOR_END: export_variable
