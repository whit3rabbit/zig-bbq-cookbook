const std = @import("std");
const testing = std.testing;

// ANCHOR: many_item_pointer
// Zig function accepting a C array as many-item pointer
export fn sum_integers(arr: [*]const c_int, len: usize) c_int {
    var total: c_int = 0;
    for (0..len) |i| {
        total += arr[i];
    }
    return total;
}

test "passing array to Zig from C" {
    const numbers = [_]c_int{ 10, 20, 30, 40, 50 };
    const result = sum_integers(&numbers, numbers.len);
    try testing.expectEqual(@as(c_int, 150), result);
}
// ANCHOR_END: many_item_pointer

// ANCHOR: modifying_array
// Zig function that modifies a C array in place
export fn double_values(arr: [*]c_int, len: usize) void {
    for (0..len) |i| {
        arr[i] *= 2;
    }
}

test "modifying C array from Zig" {
    var numbers = [_]c_int{ 1, 2, 3, 4, 5 };
    double_values(&numbers, numbers.len);

    try testing.expectEqual(@as(c_int, 2), numbers[0]);
    try testing.expectEqual(@as(c_int, 4), numbers[1]);
    try testing.expectEqual(@as(c_int, 6), numbers[2]);
    try testing.expectEqual(@as(c_int, 8), numbers[3]);
    try testing.expectEqual(@as(c_int, 10), numbers[4]);
}
// ANCHOR_END: modifying_array

// ANCHOR: returning_array
// Allocate and return an array to C
export fn create_range(start: c_int, count: usize, out_arr: [*]c_int) void {
    for (0..count) |i| {
        out_arr[i] = start + @as(c_int, @intCast(i));
    }
}

test "returning array to C" {
    var result: [5]c_int = undefined;
    create_range(10, 5, &result);

    try testing.expectEqual(@as(c_int, 10), result[0]);
    try testing.expectEqual(@as(c_int, 11), result[1]);
    try testing.expectEqual(@as(c_int, 12), result[2]);
    try testing.expectEqual(@as(c_int, 13), result[3]);
    try testing.expectEqual(@as(c_int, 14), result[4]);
}
// ANCHOR_END: returning_array

// ANCHOR: c_pointer_conversion
// Using C pointers ([*c]T) for maximum compatibility
const c = @cImport({
    @cInclude("stdlib.h");
});

export fn process_c_array(arr: [*c]c_int, len: usize) c_int {
    if (arr == null) return -1;

    var max: c_int = arr[0];
    for (1..len) |i| {
        if (arr[i] > max) {
            max = arr[i];
        }
    }
    return max;
}

test "working with C pointers" {
    var numbers = [_]c_int{ 15, 42, 8, 23, 16 };
    const result = process_c_array(&numbers, numbers.len);
    try testing.expectEqual(@as(c_int, 42), result);

    // Test NULL handling
    const null_result = process_c_array(null, 0);
    try testing.expectEqual(@as(c_int, -1), null_result);
}
// ANCHOR_END: c_pointer_conversion

// ANCHOR: multidimensional_arrays
// Working with 2D arrays (arrays of pointers)
export fn sum_2d_array(rows: [*]const [*]const c_int, num_rows: usize, cols_per_row: usize) c_int {
    var total: c_int = 0;
    for (0..num_rows) |i| {
        for (0..cols_per_row) |j| {
            total += rows[i][j];
        }
    }
    return total;
}

test "2D array operations" {
    const row1 = [_]c_int{ 1, 2, 3 };
    const row2 = [_]c_int{ 4, 5, 6 };
    const row3 = [_]c_int{ 7, 8, 9 };

    const rows = [_][*]const c_int{ &row1, &row2, &row3 };
    const result = sum_2d_array(&rows, 3, 3);
    try testing.expectEqual(@as(c_int, 45), result);
}
// ANCHOR_END: multidimensional_arrays

// ANCHOR: struct_array
// Passing arrays of structs
pub const Point2D = extern struct {
    x: c_int,
    y: c_int,
};

export fn compute_bounding_box(points: [*]const Point2D, count: usize, min_x: *c_int, min_y: *c_int, max_x: *c_int, max_y: *c_int) void {
    if (count == 0) return;

    min_x.* = points[0].x;
    min_y.* = points[0].y;
    max_x.* = points[0].x;
    max_y.* = points[0].y;

    for (1..count) |i| {
        if (points[i].x < min_x.*) min_x.* = points[i].x;
        if (points[i].y < min_y.*) min_y.* = points[i].y;
        if (points[i].x > max_x.*) max_x.* = points[i].x;
        if (points[i].y > max_y.*) max_y.* = points[i].y;
    }
}

test "array of structs" {
    const points = [_]Point2D{
        .{ .x = 5, .y = 3 },
        .{ .x = 1, .y = 7 },
        .{ .x = 9, .y = 2 },
        .{ .x = 3, .y = 8 },
    };

    var min_x: c_int = undefined;
    var min_y: c_int = undefined;
    var max_x: c_int = undefined;
    var max_y: c_int = undefined;

    compute_bounding_box(&points, points.len, &min_x, &min_y, &max_x, &max_y);

    try testing.expectEqual(@as(c_int, 1), min_x);
    try testing.expectEqual(@as(c_int, 2), min_y);
    try testing.expectEqual(@as(c_int, 9), max_x);
    try testing.expectEqual(@as(c_int, 8), max_y);
}
// ANCHOR_END: struct_array

// ANCHOR: slice_to_c_array
// Converting Zig slices to C arrays
export fn average_slice(slice_ptr: [*]const c_int, slice_len: usize) f64 {
    if (slice_len == 0) return 0.0;

    var sum: c_int = 0;
    for (0..slice_len) |i| {
        sum += slice_ptr[i];
    }

    return @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(slice_len));
}

test "converting slice to C array" {
    const numbers = [_]c_int{ 10, 20, 30, 40, 50 };
    const slice: []const c_int = &numbers;

    const result = average_slice(slice.ptr, slice.len);
    try testing.expectApproxEqAbs(30.0, result, 0.001);
}
// ANCHOR_END: slice_to_c_array

// ANCHOR: dynamic_array_allocation
// Allocating arrays for C callers
export fn create_fibonacci(n: usize) ?[*]c_int {
    if (n == 0) return null;

    const allocator = std.heap.c_allocator;
    const arr = allocator.alloc(c_int, n) catch return null;

    if (n >= 1) arr[0] = 0;
    if (n >= 2) arr[1] = 1;

    for (2..n) |i| {
        arr[i] = arr[i - 1] + arr[i - 2];
    }

    return arr.ptr;
}

export fn free_array(arr: ?[*]c_int, len: usize) void {
    if (arr) |a| {
        const allocator = std.heap.c_allocator;
        const slice = a[0..len];
        allocator.free(slice);
    }
}

test "dynamic array allocation" {
    const arr = create_fibonacci(10);
    try testing.expect(arr != null);

    if (arr) |a| {
        try testing.expectEqual(@as(c_int, 0), a[0]);
        try testing.expectEqual(@as(c_int, 1), a[1]);
        try testing.expectEqual(@as(c_int, 1), a[2]);
        try testing.expectEqual(@as(c_int, 2), a[3]);
        try testing.expectEqual(@as(c_int, 3), a[4]);
        try testing.expectEqual(@as(c_int, 5), a[5]);
        try testing.expectEqual(@as(c_int, 8), a[6]);
        try testing.expectEqual(@as(c_int, 13), a[7]);
        try testing.expectEqual(@as(c_int, 21), a[8]);
        try testing.expectEqual(@as(c_int, 34), a[9]);

        free_array(arr, 10);
    }
}
// ANCHOR_END: dynamic_array_allocation

// ANCHOR: byte_array_operations
// Working with byte arrays (useful for buffers)
export fn reverse_bytes(data: [*]u8, len: usize) void {
    var left: usize = 0;
    var right: usize = len - 1;

    while (left < right) {
        const temp = data[left];
        data[left] = data[right];
        data[right] = temp;
        left += 1;
        right -= 1;
    }
}

test "byte array manipulation" {
    var data = "Hello".*;
    reverse_bytes(&data, data.len);
    try testing.expect(std.mem.eql(u8, &data, "olleH"));
}
// ANCHOR_END: byte_array_operations

// ANCHOR: array_bounds_safety
// Safe array access with bounds checking
export fn safe_get_element(arr: [*]const c_int, len: usize, index: usize, out_value: *c_int) bool {
    if (index >= len) {
        return false;
    }
    out_value.* = arr[index];
    return true;
}

test "safe array access" {
    const numbers = [_]c_int{ 100, 200, 300, 400 };
    var value: c_int = undefined;

    // Valid access
    const success = safe_get_element(&numbers, numbers.len, 2, &value);
    try testing.expect(success);
    try testing.expectEqual(@as(c_int, 300), value);

    // Out of bounds access
    const failure = safe_get_element(&numbers, numbers.len, 10, &value);
    try testing.expect(!failure);
}
// ANCHOR_END: array_bounds_safety
