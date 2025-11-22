// Recipe 0.6: Arrays, ArrayLists, and Slices (CRITICAL)
// Target Zig Version: 0.15.2
//
// This is the #1 confusion point for Zig beginners!
// This recipe clarifies the three fundamental sequence types in Zig.

const std = @import("std");
const testing = std.testing;

// ANCHOR: fixed_arrays
// Part 1: Fixed Arrays [N]T
//
// Arrays have compile-time known size. The size is part of the type!
// [3]i32 and [5]i32 are completely different types.

test "fixed arrays have compile-time size" {
    // The size is in the type
    const arr1: [3]i32 = [_]i32{ 1, 2, 3 };
    const arr2: [5]i32 = [_]i32{ 1, 2, 3, 4, 5 };

    // These are different types!
    // const same: [3]i32 = arr2;  // error: type mismatch

    try testing.expectEqual(@as(usize, 3), arr1.len);
    try testing.expectEqual(@as(usize, 5), arr2.len);
}

test "arrays live on the stack" {
    // No allocator needed - arrays are value types
    const numbers = [_]i32{ 10, 20, 30, 40 };

    // You can pass arrays by value (they get copied)
    const sum = sumArray(numbers);

    try testing.expectEqual(@as(i32, 100), sum);
}

fn sumArray(arr: [4]i32) i32 {
    var total: i32 = 0;
    for (arr) |n| {
        total += n;
    }
    return total;
}

test "arrays cannot grow or shrink" {
    var arr = [_]i32{ 1, 2, 3 };

    // Can modify elements
    arr[0] = 10;
    try testing.expectEqual(@as(i32, 10), arr[0]);

    // But cannot change size
    // arr.append(4);  // No such method!
    // The size is fixed at compile time
}
// ANCHOR_END: fixed_arrays

// ANCHOR: slices_views
// Part 2: Slices []T
//
// Slices are "views" into arrays - pointer + length
// They're how you work with arrays when size isn't known at compile time

test "slices are views into arrays" {
    const array = [_]i32{ 1, 2, 3, 4, 5 };

    // Create a slice (view) of the array
    const slice: []const i32 = &array;

    // Slice knows its length at runtime
    try testing.expectEqual(@as(usize, 5), slice.len);
    try testing.expectEqual(@as(i32, 1), slice[0]);
}

test "slicing an array" {
    const array = [_]i32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };

    // Get a sub-slice [start..end]
    const middle: []const i32 = array[3..7]; // [3, 4, 5, 6]

    try testing.expectEqual(@as(usize, 4), middle.len);
    try testing.expectEqual(@as(i32, 3), middle[0]);
    try testing.expectEqual(@as(i32, 6), middle[3]);
}

test "slices can be passed to functions" {
    const array = [_]i32{ 10, 20, 30 };

    // Functions that take slices work with any array size
    const sum1 = sumSlice(&array);
    try testing.expectEqual(@as(i32, 60), sum1);

    const other = [_]i32{ 5, 15 };
    const sum2 = sumSlice(&other);
    try testing.expectEqual(@as(i32, 20), sum2);
}

fn sumSlice(slice: []const i32) i32 {
    var total: i32 = 0;
    for (slice) |n| {
        total += n;
    }
    return total;
}

test "mutable slices" {
    var array = [_]i32{ 1, 2, 3, 4, 5 };

    // Mutable slice - can modify through it
    const slice: []i32 = &array;
    slice[0] = 99;

    try testing.expectEqual(@as(i32, 99), array[0]);
}

test "slices don't own memory" {
    const array = [_]i32{ 1, 2, 3 };
    const slice: []const i32 = &array;

    // The slice is just a view - array owns the memory
    // When array goes out of scope, slice becomes invalid
    try testing.expectEqual(array.len, slice.len);
}
// ANCHOR_END: slices_views

// ANCHOR: arraylist_growable
// Part 3: ArrayList - Growable Arrays
//
// When you need to add/remove elements, use ArrayList
// This is like Python's list or Java's ArrayList

test "ArrayList needs an allocator" {
    // ArrayList requires an allocator to manage memory
    var list = std.ArrayList(i32){};
    defer list.deinit(testing.allocator);

    // Can grow dynamically
    try list.append(testing.allocator, 1);
    try list.append(testing.allocator, 2);
    try list.append(testing.allocator, 3);

    try testing.expectEqual(@as(usize, 3), list.items.len);
    try testing.expectEqual(@as(i32, 1), list.items[0]);
}

test "ArrayList vs fixed array" {
    // Fixed array - size known at compile time
    const fixed = [_]i32{ 1, 2, 3 };
    _ = fixed;

    // ArrayList - size known at runtime, can grow
    var list = std.ArrayList(i32){};
    defer list.deinit(testing.allocator);

    try list.append(testing.allocator, 1);
    try list.append(testing.allocator, 2);
    try list.append(testing.allocator, 3);

    // Can add more!
    try list.append(testing.allocator, 4);
    try testing.expectEqual(@as(usize, 4), list.items.len);
}

test "ArrayList operations" {
    var list = std.ArrayList(i32){};
    defer list.deinit(testing.allocator);

    // Append items
    try list.append(testing.allocator, 10);
    try list.append(testing.allocator, 20);
    try list.append(testing.allocator, 30);

    try testing.expectEqual(@as(usize, 3), list.items.len);

    // Access items through .items slice
    try testing.expectEqual(@as(i32, 10), list.items[0]);
    try testing.expectEqual(@as(i32, 20), list.items[1]);

    // Pop removes last element
    const last = list.pop();
    try testing.expectEqual(@as(i32, 30), last);
    try testing.expectEqual(@as(usize, 2), list.items.len);
}

test "ArrayList .items is a slice" {
    var list = std.ArrayList(i32){};
    defer list.deinit(testing.allocator);

    try list.append(testing.allocator, 5);
    try list.append(testing.allocator, 10);
    try list.append(testing.allocator, 15);

    // .items gives you a slice of the contents
    const slice: []i32 = list.items;

    // Can use slice operations
    try testing.expectEqual(@as(usize, 3), slice.len);

    // Can pass to functions expecting slices
    const sum = sumSlice(slice);
    try testing.expectEqual(@as(i32, 30), sum);
}
// ANCHOR_END: arraylist_growable

// String examples - strings are just byte arrays!

test "string literals are special arrays" {
    // String literal type: *const [N:0]u8
    // *const = pointer to const
    // [N:0]u8 = array of N bytes with null terminator
    const hello: *const [5:0]u8 = "hello";

    try testing.expectEqual(@as(usize, 5), hello.len);
    try testing.expectEqual(@as(u8, 'h'), hello[0]);
}

test "strings as slices" {
    const hello = "hello";

    // Can convert to slice
    const slice: []const u8 = hello;

    try testing.expectEqual(@as(usize, 5), slice.len);

    // Can slice strings
    const ello: []const u8 = hello[1..];
    try testing.expect(std.mem.eql(u8, ello, "ello"));
}

test "building strings with ArrayList" {
    // For dynamic strings, use ArrayList(u8)
    var string = std.ArrayList(u8){};
    defer string.deinit(testing.allocator);

    try string.appendSlice(testing.allocator, "Hello");
    try string.appendSlice(testing.allocator, ", ");
    try string.appendSlice(testing.allocator, "World!");

    try testing.expect(std.mem.eql(u8, string.items, "Hello, World!"));
}

// Comparison table

test "comparing the three types" {
    // 1. Fixed Array [N]T
    const fixed: [3]i32 = [_]i32{ 1, 2, 3 };
    // - Size known at compile time
    // - Lives on stack
    // - Cannot grow
    // - No allocator needed
    try testing.expectEqual(@as(usize, 3), fixed.len);

    // 2. Slice []T
    const slice_view: []const i32 = &fixed;
    // - View into array
    // - Size known at runtime
    // - Just pointer + length
    // - Doesn't own memory
    try testing.expectEqual(@as(usize, 3), slice_view.len);

    // 3. ArrayList
    var dynamic = std.ArrayList(i32){};
    defer dynamic.deinit(testing.allocator);
    try dynamic.append(testing.allocator, 1);
    try dynamic.append(testing.allocator, 2);
    try dynamic.append(testing.allocator, 3);
    // - Can grow and shrink
    // - Owns memory (needs allocator)
    // - .items gives you a slice
    // - Like Python list or Java ArrayList
    try testing.expectEqual(@as(usize, 3), dynamic.items.len);
}

// Summary:
// [N]T      - Fixed size, compile-time, stack, no allocator
// []T       - View/pointer, runtime size, doesn't own memory
// ArrayList - Growable, heap, needs allocator, owns memory
//
// When to use what:
// - Know size at compile time? Use [N]T
// - Passing arrays to functions? Use []T slice parameter
// - Need to grow/shrink? Use ArrayList
// - Working with strings? Usually []const u8 (slice)
