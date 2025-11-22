// Recipe 0.9: Understanding Pointers and References (CRITICAL)
// Target Zig Version: 0.15.2
//
// This is essential for beginners from garbage-collected languages.
// Understand when and how to use pointers in Zig.

const std = @import("std");
const testing = std.testing;

// ANCHOR: single_item_pointer
// Part 1: Single-Item Pointers *T
//
// A single-item pointer points to exactly one value

test "basic single-item pointer" {
    var x: i32 = 42;

    // Take address with &
    const ptr: *i32 = &x;

    // Dereference with .*
    try testing.expectEqual(@as(i32, 42), ptr.*);

    // Can modify through pointer
    ptr.* = 100;
    try testing.expectEqual(@as(i32, 100), x);
}

test "const pointers" {
    var x: i32 = 42;

    // *const T - pointer to const value (can't modify)
    const const_ptr: *const i32 = &x;
    try testing.expectEqual(@as(i32, 42), const_ptr.*);

    // This would not compile:
    // const_ptr.* = 100;  // error: cannot assign to constant

    // *T - pointer to mutable value (can modify)
    const mut_ptr: *i32 = &x;
    mut_ptr.* = 100;
    try testing.expectEqual(@as(i32, 100), x);
}

test "pointers to structs" {
    const Point = struct {
        x: i32,
        y: i32,
    };

    var p = Point{ .x = 10, .y = 20 };
    const ptr: *Point = &p;

    // Access fields through pointer (automatic dereferencing)
    try testing.expectEqual(@as(i32, 10), ptr.x);

    // Modify through pointer
    ptr.x = 30;
    try testing.expectEqual(@as(i32, 30), p.x);
}

fn increment(value: *i32) void {
    value.* += 1;
}

test "passing pointers to functions" {
    var x: i32 = 10;

    // Pass pointer to modify the value
    increment(&x);
    try testing.expectEqual(@as(i32, 11), x);

    increment(&x);
    try testing.expectEqual(@as(i32, 12), x);
}
// ANCHOR_END: single_item_pointer

// ANCHOR: many_item_pointer
// Part 2: Many-Item Pointers [*]T and Slices []T
//
// Many-item pointers point to multiple values (unknown length)
// Slices are many-item pointers WITH a length

test "many-item pointers" {
    var array = [_]i32{ 1, 2, 3, 4, 5 };

    // Many-item pointer - no length information
    const many_ptr: [*]i32 = &array;

    // Access via indexing (like C pointers)
    try testing.expectEqual(@as(i32, 1), many_ptr[0]);
    try testing.expectEqual(@as(i32, 2), many_ptr[1]);

    // No bounds checking - YOU must track length!
    // many_ptr[100] would be undefined behavior
}

test "slices are better than many-item pointers" {
    var array = [_]i32{ 1, 2, 3, 4, 5 };

    // Slice - pointer + length
    const slice: []i32 = &array;

    // Has length
    try testing.expectEqual(@as(usize, 5), slice.len);

    // Bounds checking in debug builds
    try testing.expectEqual(@as(i32, 1), slice[0]);
    try testing.expectEqual(@as(i32, 5), slice[4]);
}

test "const slices" {
    const array = [_]i32{ 1, 2, 3, 4, 5 };

    // []const T - slice of const values
    const slice: []const i32 = &array;

    try testing.expectEqual(@as(i32, 1), slice[0]);

    // Cannot modify
    // slice[0] = 10;  // error: cannot assign to constant
}

test "slicing arrays" {
    const array = [_]i32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };

    // Create sub-slices with [start..end] syntax
    const middle: []const i32 = array[3..7];

    try testing.expectEqual(@as(usize, 4), middle.len);
    try testing.expectEqual(@as(i32, 3), middle[0]);
    try testing.expectEqual(@as(i32, 6), middle[3]);

    // [start..] - from start to end
    const tail: []const i32 = array[7..];
    try testing.expectEqual(@as(usize, 3), tail.len);

    // [0..end] - from beginning to end
    const head: []const i32 = array[0..5];
    try testing.expectEqual(@as(usize, 5), head.len);
}

fn sumSlice(values: []const i32) i32 {
    var total: i32 = 0;
    for (values) |v| {
        total += v;
    }
    return total;
}

test "passing slices to functions" {
    const array = [_]i32{ 1, 2, 3, 4, 5 };

    // Pass entire array as slice
    const total1 = sumSlice(&array);
    try testing.expectEqual(@as(i32, 15), total1);

    // Pass sub-slice
    const total2 = sumSlice(array[0..3]);
    try testing.expectEqual(@as(i32, 6), total2);
}
// ANCHOR_END: many_item_pointer

// ANCHOR: when_to_use_pointers
// Part 3: When to Use Pointers vs Values
//
// Zig passes small values efficiently, so you don't always need pointers

test "small values - just pass by value" {
    const Point = struct {
        x: i32,
        y: i32,

        fn distance(self: @This()) f32 {
            const dx = @as(f32, @floatFromInt(self.x));
            const dy = @as(f32, @floatFromInt(self.y));
            return @sqrt(dx * dx + dy * dy);
        }
    };

    const p = Point{ .x = 3, .y = 4 };

    // Pass by value - efficient for small structs
    const dist = p.distance();
    try testing.expect(@abs(dist - 5.0) < 0.01);
}

test "when to use pointers" {
    const BigStruct = struct {
        data: [1000]i32,

        fn sum(self: *const @This()) i32 {
            var total: i32 = 0;
            for (self.data) |val| {
                total += val;
            }
            return total;
        }
    };

    var big = BigStruct{ .data = [_]i32{1} ** 1000 };

    // Use pointer to avoid copying large struct
    const total = big.sum();
    try testing.expectEqual(@as(i32, 1000), total);
}

test "when you need to modify a value" {
    const Counter = struct {
        count: i32,

        fn increment(self: *@This()) void {
            self.count += 1;
        }

        fn reset(self: *@This()) void {
            self.count = 0;
        }
    };

    var counter = Counter{ .count = 0 };

    // Pass pointer to modify
    counter.increment();
    try testing.expectEqual(@as(i32, 1), counter.count);

    counter.increment();
    try testing.expectEqual(@as(i32, 2), counter.count);

    counter.reset();
    try testing.expectEqual(@as(i32, 0), counter.count);
}

test "optional pointers" {
    // ?*T - optional pointer (can be null)
    var x: i32 = 42;
    var maybe_ptr: ?*i32 = &x;

    // Check if not null
    if (maybe_ptr) |ptr| {
        try testing.expectEqual(@as(i32, 42), ptr.*);
    }

    // Set to null
    maybe_ptr = null;
    try testing.expectEqual(@as(?*i32, null), maybe_ptr);
}

test "pointer to array vs slice" {
    var array = [_]i32{ 1, 2, 3, 4, 5 };

    // Pointer to array - knows the size in the type
    const array_ptr: *[5]i32 = &array;
    try testing.expectEqual(@as(usize, 5), array_ptr.len);

    // Slice - size known at runtime
    const slice: []i32 = &array;
    try testing.expectEqual(@as(usize, 5), slice.len);

    // Both access the same data
    array_ptr[0] = 99;
    try testing.expectEqual(@as(i32, 99), slice[0]);
}
// ANCHOR_END: when_to_use_pointers

// Additional examples

test "pointer arithmetic with many-item pointers" {
    var array = [_]i32{ 10, 20, 30, 40, 50 };

    const ptr: [*]i32 = &array;

    // Can do pointer arithmetic (like C)
    const offset_ptr = ptr + 2;
    try testing.expectEqual(@as(i32, 30), offset_ptr[0]);

    // But slices are safer and easier
    const slice: []i32 = array[2..];
    try testing.expectEqual(@as(i32, 30), slice[0]);
}

test "sentinel-terminated pointers" {
    // [*:0]u8 - many-item pointer terminated by 0 (for C strings)
    const c_string: [*:0]const u8 = "hello";

    // Can iterate until sentinel
    var len: usize = 0;
    while (c_string[len] != 0) : (len += 1) {}

    try testing.expectEqual(@as(usize, 5), len);

    // Better: use std.mem.span to convert to slice
    const slice = std.mem.span(c_string);
    try testing.expectEqual(@as(usize, 5), slice.len);
    try testing.expect(std.mem.eql(u8, slice, "hello"));
}

test "comparing pointers vs comparing values" {
    var x: i32 = 42;
    var y: i32 = 42;

    const ptr_x: *i32 = &x;
    const ptr_y: *i32 = &y;

    // Different pointers (different addresses)
    try testing.expect(ptr_x != ptr_y);

    // Same values
    try testing.expectEqual(ptr_x.*, ptr_y.*);

    // Pointer to same location
    const also_ptr_x: *i32 = &x;
    try testing.expect(ptr_x == also_ptr_x);
}

test "avoiding dangling pointers" {
    // Example of what NOT to do (would cause undefined behavior)
    _ = struct {
        fn call() *i32 {
            var x: i32 = 42;
            return &x; // BAD: x goes out of scope!
        }
    };

    // This would be undefined behavior:
    // const bad_ptr = getBadPointer();
    // const value = bad_ptr.*;  // Reading freed memory!

    // Instead, return the value or use an allocator
    const getGoodValue = struct {
        fn call() i32 {
            const x: i32 = 42;
            return x; // Good: return by value
        }
    }.call;

    const value = getGoodValue();
    try testing.expectEqual(@as(i32, 42), value);
}

// Summary:
// - *T: single-item pointer (points to one value)
// - [*]T: many-item pointer (no length, like C pointers)
// - []T: slice (pointer + length, safer and more common)
// - Use & to get address, .* to dereference
// - *const T vs *T: const vs mutable pointer
// - Pass by value for small structs, pointer for large ones
// - Use pointers when you need to modify or avoid copying
// - Slices are almost always better than many-item pointers
