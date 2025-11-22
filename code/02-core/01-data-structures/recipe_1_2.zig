// Recipe 1.2: Working with Slices
// Target Zig Version: 0.15.2
//
// Demonstrates how to work with Zig's slice type for safe array manipulation.
// Run: zig test code/02-core/01-data-structures/recipe_1_2.zig

const std = @import("std");
const testing = std.testing;

// ==============================================================================
// Basic Slice Usage
// ==============================================================================

// ANCHOR: basic_slice
test "basic slice usage" {
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    const slice: []const i32 = &numbers;

    try testing.expectEqual(@as(usize, 5), slice.len);
    try testing.expectEqual(@as(i32, 3), slice[2]);
}
// ANCHOR_END: basic_slice

test "slice from array" {
    const array: [5]i32 = [_]i32{ 10, 20, 30, 40, 50 };
    const slice: []const i32 = &array;

    try testing.expectEqual(@as(usize, 5), slice.len);
    try testing.expectEqual(@as(i32, 10), slice[0]);
    try testing.expectEqual(@as(i32, 50), slice[4]);
}

// ==============================================================================
// Creating Slices with Range Syntax
// ==============================================================================

// ANCHOR: range_syntax
test "partial slice with range" {
    const array = [_]i32{ 10, 20, 30, 40, 50 };
    const partial: []const i32 = array[1..4];

    try testing.expectEqual(@as(usize, 3), partial.len);
    try testing.expectEqual(@as(i32, 20), partial[0]);
    try testing.expectEqual(@as(i32, 30), partial[1]);
    try testing.expectEqual(@as(i32, 40), partial[2]);
}
// ANCHOR_END: range_syntax

test "slice from start" {
    const array = [_]i32{ 10, 20, 30, 40, 50 };
    const from_start: []const i32 = array[0..3];

    try testing.expectEqual(@as(usize, 3), from_start.len);
    try testing.expectEqual(@as(i32, 10), from_start[0]);
    try testing.expectEqual(@as(i32, 30), from_start[2]);
}

test "slice to end" {
    const array = [_]i32{ 10, 20, 30, 40, 50 };
    const to_end: []const i32 = array[2..];

    try testing.expectEqual(@as(usize, 3), to_end.len);
    try testing.expectEqual(@as(i32, 30), to_end[0]);
    try testing.expectEqual(@as(i32, 50), to_end[2]);
}

test "sub-slicing" {
    const data = [_]u8{ 1, 2, 3, 4, 5, 6 };
    const middle = data[2..5];

    try testing.expectEqual(@as(usize, 3), middle.len);
    try testing.expectEqual(@as(u8, 3), middle[0]);
    try testing.expectEqual(@as(u8, 4), middle[1]);
    try testing.expectEqual(@as(u8, 5), middle[2]);
}

// ==============================================================================
// Const vs Mutable Slices
// ==============================================================================

test "const slice is read-only" {
    var array = [_]i32{ 1, 2, 3 };
    const const_slice: []const i32 = &array;

    // We can read
    try testing.expectEqual(@as(i32, 1), const_slice[0]);

    // But cannot modify through const slice
    // const_slice[0] = 99;  // This would be a compile error
}

test "mutable slice allows modifications" {
    var array = [_]i32{ 1, 2, 3 };
    const mut_slice: []i32 = &array;

    // Modify through slice
    mut_slice[0] = 99;
    mut_slice[1] = 88;

    try testing.expectEqual(@as(i32, 99), array[0]);
    try testing.expectEqual(@as(i32, 88), array[1]);
    try testing.expectEqual(@as(i32, 3), array[2]);
}

// ==============================================================================
// Iterating Over Slices
// ==============================================================================

test "iterate over slice values" {
    const items = [_]i32{ 10, 20, 30 };
    const slice: []const i32 = &items;

    var total: i32 = 0;
    for (slice) |value| {
        total += value;
    }

    try testing.expectEqual(@as(i32, 60), total);
}

test "iterate with index" {
    const items = [_]i32{ 10, 20, 30 };
    const slice: []const i32 = &items;

    var total: i32 = 0;
    for (slice, 0..) |value, i| {
        total += value * @as(i32, @intCast(i));
    }

    // 10*0 + 20*1 + 30*2 = 0 + 20 + 60 = 80
    try testing.expectEqual(@as(i32, 80), total);
}

// ==============================================================================
// Slices as Function Parameters
// ==============================================================================

fn sum(numbers: []const i32) i32 {
    var total: i32 = 0;
    for (numbers) |n| {
        total += n;
    }
    return total;
}

test "slice as function parameter" {
    const data = [_]i32{ 1, 2, 3, 4, 5 };
    const total = sum(&data);

    try testing.expectEqual(@as(i32, 15), total);
}

test "partial slice as function parameter" {
    const data = [_]i32{ 1, 2, 3, 4, 5 };
    const total = sum(data[1..4]);  // Sum of 2, 3, 4

    try testing.expectEqual(@as(i32, 9), total);
}

fn findMax(numbers: []const i32) ?i32 {
    if (numbers.len == 0) return null;

    var max_val = numbers[0];
    for (numbers[1..]) |n| {
        if (n > max_val) {
            max_val = n;
        }
    }
    return max_val;
}

test "function returning optional with slices" {
    const data = [_]i32{ 3, 7, 2, 9, 1 };

    const max_val = findMax(&data);
    try testing.expectEqual(@as(?i32, 9), max_val);

    const empty: []const i32 = &[_]i32{};
    const no_max = findMax(empty);
    try testing.expectEqual(@as(?i32, null), no_max);
}

// ==============================================================================
// Slice Operations with std.mem
// ==============================================================================

test "copying slices with @memcpy" {
    var dest: [5]i32 = undefined;
    const src = [_]i32{ 1, 2, 3, 4, 5 };

    @memcpy(&dest, &src);

    try testing.expectEqual(@as(i32, 1), dest[0]);
    try testing.expectEqual(@as(i32, 5), dest[4]);
}

test "comparing slices with std.mem.eql" {
    const a = [_]i32{ 1, 2, 3 };
    const b = [_]i32{ 1, 2, 3 };
    const c = [_]i32{ 1, 2, 4 };

    try testing.expect(std.mem.eql(i32, &a, &b));
    try testing.expect(!std.mem.eql(i32, &a, &c));
}

test "finding subsequence with std.mem.indexOf" {
    const haystack = [_]i32{ 1, 2, 3, 4, 5 };
    const needle = [_]i32{ 3, 4 };

    const index = std.mem.indexOf(i32, &haystack, &needle);
    try testing.expectEqual(@as(?usize, 2), index);

    const not_found = [_]i32{ 6, 7 };
    const no_index = std.mem.indexOf(i32, &haystack, &not_found);
    try testing.expectEqual(@as(?usize, null), no_index);
}

test "checking if slice starts with prefix" {
    const data = "Hello, World!";

    try testing.expect(std.mem.startsWith(u8, data, "Hello"));
    try testing.expect(!std.mem.startsWith(u8, data, "World"));
}

test "checking if slice ends with suffix" {
    const data = "Hello, World!";

    try testing.expect(std.mem.endsWith(u8, data, "World!"));
    try testing.expect(!std.mem.endsWith(u8, data, "Hello"));
}

// ==============================================================================
// Dynamic Slices with ArrayList
// ==============================================================================

test "ArrayList provides dynamic slices" {
    const allocator = testing.allocator;

    var list = std.ArrayList(i32){};
    defer list.deinit(allocator);

    try list.append(allocator, 1);
    try list.append(allocator, 2);
    try list.append(allocator, 3);

    // Get a slice view
    const slice: []const i32 = list.items;

    try testing.expectEqual(@as(usize, 3), slice.len);
    try testing.expectEqual(@as(i32, 1), slice[0]);
    try testing.expectEqual(@as(i32, 3), slice[2]);
}

// ==============================================================================
// Zero-Length and Empty Slices
// ==============================================================================

test "zero-length slice is valid" {
    const empty: []const i32 = &[_]i32{};

    try testing.expectEqual(@as(usize, 0), empty.len);
}

test "empty slice from range" {
    const array = [_]i32{ 1, 2, 3 };
    const empty = array[2..2];  // Empty slice starting at index 2

    try testing.expectEqual(@as(usize, 0), empty.len);
}

// ==============================================================================
// Sentinel-Terminated Slices
// ==============================================================================

test "sentinel-terminated string slice" {
    const str: [:0]const u8 = "hello";

    try testing.expectEqual(@as(usize, 5), str.len);
    try testing.expectEqualStrings("hello", str);

    // The sentinel is not counted in len, but exists in memory
    try testing.expectEqual(@as(u8, 0), str[str.len]);
}

// ==============================================================================
// Practical Examples
// ==============================================================================

// ANCHOR: practical_reverse
fn reverseSlice(slice: []i32) void {
    if (slice.len < 2) return;

    var left: usize = 0;
    var right: usize = slice.len - 1;

    while (left < right) {
        const temp = slice[left];
        slice[left] = slice[right];
        slice[right] = temp;
        left += 1;
        right -= 1;
    }
}

test "practical example - reversing a slice" {
    var data = [_]i32{ 1, 2, 3, 4, 5 };
    reverseSlice(&data);

    try testing.expectEqual(@as(i32, 5), data[0]);
    try testing.expectEqual(@as(i32, 4), data[1]);
    try testing.expectEqual(@as(i32, 3), data[2]);
    try testing.expectEqual(@as(i32, 2), data[3]);
    try testing.expectEqual(@as(i32, 1), data[4]);
}
// ANCHOR_END: practical_reverse

fn contains(haystack: []const i32, needle: i32) bool {
    for (haystack) |item| {
        if (item == needle) return true;
    }
    return false;
}

test "practical example - checking if slice contains value" {
    const data = [_]i32{ 10, 20, 30, 40, 50 };

    try testing.expect(contains(&data, 30));
    try testing.expect(!contains(&data, 100));
}
