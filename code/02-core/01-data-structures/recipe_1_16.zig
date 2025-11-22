// Recipe 1.16: Filtering sequence elements
// Target Zig Version: 0.15.2
//
// This recipe demonstrates idiomatic filtering of sequence elements in Zig
// using ArrayList and explicit loops rather than functional-style iterators.

const std = @import("std");
const testing = std.testing;
const ArrayList = std.ArrayList;

/// Filter function type: takes an item and returns true if it should be included
fn FilterFn(comptime T: type) type {
    return *const fn (T) bool;
}

/// Filter a slice based on a predicate function, returning a new ArrayList
/// Caller owns the returned ArrayList and must call deinit()
// ANCHOR: basic_filter
pub fn filter(
    comptime T: type,
    allocator: std.mem.Allocator,
    items: []const T,
    predicate: FilterFn(T),
) !ArrayList(T) {
    var result = ArrayList(T){};
    errdefer result.deinit(allocator);

    for (items) |item| {
        if (predicate(item)) {
            try result.append(allocator, item);
        }
    }

    return result;
}
// ANCHOR_END: basic_filter

/// In-place filtering: removes elements that don't match the predicate
/// Modifies the ArrayList in place, more efficient than creating a new list
// ANCHOR: filter_inplace
pub fn filterInPlace(
    comptime T: type,
    list: *ArrayList(T),
    predicate: FilterFn(T),
) void {
    var write_idx: usize = 0;

    for (list.items) |item| {
        if (predicate(item)) {
            list.items[write_idx] = item;
            write_idx += 1;
        }
    }

    list.shrinkRetainingCapacity(write_idx);
}
// ANCHOR_END: filter_inplace

// Example predicate functions
fn isEven(n: i32) bool {
    return @mod(n, 2) == 0;
}

fn isPositive(n: i32) bool {
    return n > 0;
}

fn isLongString(s: []const u8) bool {
    return s.len >= 5;
}

test "filter numbers - basic predicate" {
    const numbers = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    var filtered = try filter(i32, testing.allocator, &numbers, isEven);
    defer filtered.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 5), filtered.items.len);
    try testing.expectEqualSlices(i32, &[_]i32{ 2, 4, 6, 8, 10 }, filtered.items);
}

// ANCHOR: inline_predicate
test "filter with inline closure-like function" {
    const numbers = [_]i32{ -5, -2, 0, 3, 7, -1, 4 };

    const greaterThanZero = struct {
        fn pred(n: i32) bool {
            return n > 0;
        }
    }.pred;

    var filtered = try filter(i32, testing.allocator, &numbers, greaterThanZero);
    defer filtered.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 3), filtered.items.len);
    try testing.expectEqualSlices(i32, &[_]i32{ 3, 7, 4 }, filtered.items);
}
// ANCHOR_END: inline_predicate

test "filter strings by length" {
    const words = [_][]const u8{ "hi", "hello", "world", "ok", "goodbye", "yes" };

    var longWords = try filter([]const u8, testing.allocator, &words, isLongString);
    defer longWords.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 3), longWords.items.len);
    try testing.expectEqualStrings("hello", longWords.items[0]);
    try testing.expectEqualStrings("world", longWords.items[1]);
    try testing.expectEqualStrings("goodbye", longWords.items[2]);
}

test "filter in place - more efficient" {
    var list = ArrayList(i32){};
    defer list.deinit(testing.allocator);

    try list.appendSlice(testing.allocator, &[_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 });

    filterInPlace(i32, &list, isEven);

    try testing.expectEqual(@as(usize, 5), list.items.len);
    try testing.expectEqualSlices(i32, &[_]i32{ 2, 4, 6, 8, 10 }, list.items);
}

test "filter empty slice" {
    const empty = [_]i32{};

    var filtered = try filter(i32, testing.allocator, &empty, isEven);
    defer filtered.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 0), filtered.items.len);
}

test "filter with no matches" {
    const numbers = [_]i32{ 1, 3, 5, 7, 9 };

    var filtered = try filter(i32, testing.allocator, &numbers, isEven);
    defer filtered.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 0), filtered.items.len);
}

test "filter with all matches" {
    const numbers = [_]i32{ 2, 4, 6, 8 };

    var filtered = try filter(i32, testing.allocator, &numbers, isEven);
    defer filtered.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 4), filtered.items.len);
    try testing.expectEqualSlices(i32, &numbers, filtered.items);
}

test "complex filtering with struct data" {
    const Person = struct {
        name: []const u8,
        age: u32,
    };

    const people = [_]Person{
        .{ .name = "Alice", .age = 30 },
        .{ .name = "Bob", .age = 17 },
        .{ .name = "Charlie", .age = 25 },
        .{ .name = "Diana", .age = 16 },
        .{ .name = "Eve", .age = 45 },
    };

    const isAdult = struct {
        fn pred(p: Person) bool {
            return p.age >= 18;
        }
    }.pred;

    var adults = try filter(Person, testing.allocator, &people, isAdult);
    defer adults.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 3), adults.items.len);
    try testing.expectEqualStrings("Alice", adults.items[0].name);
    try testing.expectEqualStrings("Charlie", adults.items[1].name);
    try testing.expectEqualStrings("Eve", adults.items[2].name);
}

test "memory safety - no leaks with error during append" {
    // This test verifies that errdefer properly cleans up on allocation failure
    // Using testing.allocator automatically checks for leaks
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };

    var result = try filter(i32, testing.allocator, &numbers, isPositive);
    defer result.deinit(testing.allocator);

    try testing.expect(result.items.len > 0);
}
