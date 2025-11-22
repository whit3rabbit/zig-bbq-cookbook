// Recipe 1.10: Removing Duplicates While Maintaining Order
// Target Zig Version: 0.15.2
//
// Demonstrates deduplication techniques while preserving insertion order.
// Run: zig test code/02-core/01-data-structures/recipe_1_10.zig

const std = @import("std");
const testing = std.testing;

// ==============================================================================
// Basic Deduplication (Generic)
// ==============================================================================

// ANCHOR: remove_duplicates
fn removeDuplicates(
    comptime T: type,
    allocator: std.mem.Allocator,
    items: []const T,
) ![]T {
    var seen = std.AutoHashMap(T, void).init(allocator);
    defer seen.deinit();

    var result = std.ArrayList(T){};
    errdefer result.deinit(allocator);

    for (items) |item| {
        if (!seen.contains(item)) {
            try seen.put(item, {});
            try result.append(allocator, item);
        }
    }

    return result.toOwnedSlice(allocator);
}
// ANCHOR_END: remove_duplicates

test "remove duplicates from integer slice" {
    const allocator = testing.allocator;

    const numbers = [_]i32{ 1, 2, 3, 2, 4, 1, 5, 3, 6 };
    const unique = try removeDuplicates(i32, allocator, &numbers);
    defer allocator.free(unique);

    try testing.expectEqual(@as(usize, 6), unique.len);
    try testing.expectEqual(@as(i32, 1), unique[0]);
    try testing.expectEqual(@as(i32, 2), unique[1]);
    try testing.expectEqual(@as(i32, 3), unique[2]);
    try testing.expectEqual(@as(i32, 4), unique[3]);
    try testing.expectEqual(@as(i32, 5), unique[4]);
    try testing.expectEqual(@as(i32, 6), unique[5]);
}

test "remove duplicates preserves order" {
    const allocator = testing.allocator;

    const numbers = [_]i32{ 5, 1, 3, 1, 2, 3, 4 };
    const unique = try removeDuplicates(i32, allocator, &numbers);
    defer allocator.free(unique);

    try testing.expectEqual(@as(usize, 5), unique.len);
    try testing.expectEqual(@as(i32, 5), unique[0]); // First occurrence
    try testing.expectEqual(@as(i32, 1), unique[1]);
    try testing.expectEqual(@as(i32, 3), unique[2]);
    try testing.expectEqual(@as(i32, 2), unique[3]);
    try testing.expectEqual(@as(i32, 4), unique[4]);
}

test "remove duplicates with no duplicates" {
    const allocator = testing.allocator;

    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    const unique = try removeDuplicates(i32, allocator, &numbers);
    defer allocator.free(unique);

    try testing.expectEqual(@as(usize, 5), unique.len);
    try testing.expectEqualSlices(i32, &numbers, unique);
}

test "remove duplicates from empty slice" {
    const allocator = testing.allocator;

    const numbers: []const i32 = &[_]i32{};
    const unique = try removeDuplicates(i32, allocator, numbers);
    defer allocator.free(unique);

    try testing.expectEqual(@as(usize, 0), unique.len);
}

test "remove duplicates with all duplicates" {
    const allocator = testing.allocator;

    const numbers = [_]i32{ 7, 7, 7, 7, 7 };
    const unique = try removeDuplicates(i32, allocator, &numbers);
    defer allocator.free(unique);

    try testing.expectEqual(@as(usize, 1), unique.len);
    try testing.expectEqual(@as(i32, 7), unique[0]);
}

// ==============================================================================
// String Deduplication
// ==============================================================================

// ANCHOR: string_dedup
fn removeDuplicateStrings(
    allocator: std.mem.Allocator,
    strings: []const []const u8,
) ![][]const u8 {
    var seen = std.StringHashMap(void).init(allocator);
    defer seen.deinit();

    var result = std.ArrayList([]const u8){};
    errdefer result.deinit(allocator);

    for (strings) |str| {
        if (!seen.contains(str)) {
            try seen.put(str, {});
            try result.append(allocator, str);
        }
    }

    return result.toOwnedSlice(allocator);
}
// ANCHOR_END: string_dedup

test "remove duplicate strings" {
    const allocator = testing.allocator;

    const words = [_][]const u8{ "apple", "banana", "apple", "cherry", "banana", "date" };
    const unique = try removeDuplicateStrings(allocator, &words);
    defer allocator.free(unique);

    try testing.expectEqual(@as(usize, 4), unique.len);
    try testing.expectEqualStrings("apple", unique[0]);
    try testing.expectEqualStrings("banana", unique[1]);
    try testing.expectEqualStrings("cherry", unique[2]);
    try testing.expectEqualStrings("date", unique[3]);
}

test "remove duplicate empty strings" {
    const allocator = testing.allocator;

    const words = [_][]const u8{ "", "hello", "", "world", "" };
    const unique = try removeDuplicateStrings(allocator, &words);
    defer allocator.free(unique);

    try testing.expectEqual(@as(usize, 3), unique.len);
    try testing.expectEqualStrings("", unique[0]);
    try testing.expectEqualStrings("hello", unique[1]);
    try testing.expectEqualStrings("world", unique[2]);
}

// ==============================================================================
// In-Place Deduplication
// ==============================================================================

// ANCHOR: inplace_dedup
fn deduplicateInPlace(
    comptime T: type,
    allocator: std.mem.Allocator,
    items: []T,
) !usize {
    var seen = std.AutoHashMap(T, void).init(allocator);
    defer seen.deinit();

    var write_pos: usize = 0;
    for (items) |item| {
        if (!seen.contains(item)) {
            try seen.put(item, {});
            items[write_pos] = item;
            write_pos += 1;
        }
    }

    return write_pos;
}
// ANCHOR_END: inplace_dedup

test "in-place deduplication" {
    const allocator = testing.allocator;

    var numbers = [_]i32{ 1, 2, 3, 2, 4, 1, 5 };
    const new_len = try deduplicateInPlace(i32, allocator, &numbers);

    try testing.expectEqual(@as(usize, 5), new_len);
    try testing.expectEqual(@as(i32, 1), numbers[0]);
    try testing.expectEqual(@as(i32, 2), numbers[1]);
    try testing.expectEqual(@as(i32, 3), numbers[2]);
    try testing.expectEqual(@as(i32, 4), numbers[3]);
    try testing.expectEqual(@as(i32, 5), numbers[4]);
}

test "in-place deduplication with no changes needed" {
    const allocator = testing.allocator;

    var numbers = [_]i32{ 1, 2, 3, 4, 5 };
    const new_len = try deduplicateInPlace(i32, allocator, &numbers);

    try testing.expectEqual(@as(usize, 5), new_len);
    try testing.expectEqual(@as(i32, 1), numbers[0]);
    try testing.expectEqual(@as(i32, 2), numbers[1]);
    try testing.expectEqual(@as(i32, 3), numbers[2]);
    try testing.expectEqual(@as(i32, 4), numbers[3]);
    try testing.expectEqual(@as(i32, 5), numbers[4]);
}

// ==============================================================================
// Deduplication by Struct Field
// ==============================================================================

const Person = struct {
    id: u32,
    name: []const u8,
    age: u8,
};

fn removeDuplicateIds(
    allocator: std.mem.Allocator,
    people: []const Person,
) ![]Person {
    var seen = std.AutoHashMap(u32, void).init(allocator);
    defer seen.deinit();

    var result = std.ArrayList(Person){};
    errdefer result.deinit(allocator);

    for (people) |person| {
        if (!seen.contains(person.id)) {
            try seen.put(person.id, {});
            try result.append(allocator, person);
        }
    }

    return result.toOwnedSlice(allocator);
}

test "remove duplicates by struct field" {
    const allocator = testing.allocator;

    const people = [_]Person{
        .{ .id = 1, .name = "Alice", .age = 30 },
        .{ .id = 2, .name = "Bob", .age = 25 },
        .{ .id = 1, .name = "Alice Duplicate", .age = 31 },
        .{ .id = 3, .name = "Charlie", .age = 35 },
        .{ .id = 2, .name = "Bob Duplicate", .age = 26 },
    };

    const unique = try removeDuplicateIds(allocator, &people);
    defer allocator.free(unique);

    try testing.expectEqual(@as(usize, 3), unique.len);
    try testing.expectEqual(@as(u32, 1), unique[0].id);
    try testing.expectEqualStrings("Alice", unique[0].name);
    try testing.expectEqual(@as(u32, 2), unique[1].id);
    try testing.expectEqualStrings("Bob", unique[1].name);
    try testing.expectEqual(@as(u32, 3), unique[2].id);
    try testing.expectEqualStrings("Charlie", unique[2].name);
}

// ==============================================================================
// Keep Last Occurrence Instead of First
// ==============================================================================

fn keepLastOccurrence(
    comptime T: type,
    allocator: std.mem.Allocator,
    items: []const T,
) ![]T {
    var last_index = std.AutoHashMap(T, usize).init(allocator);
    defer last_index.deinit();

    // Record the last index of each element
    for (items, 0..) |item, i| {
        try last_index.put(item, i);
    }

    // Build result keeping only last occurrences in order
    var result = std.ArrayList(T){};
    errdefer result.deinit(allocator);

    for (items, 0..) |item, i| {
        if (last_index.get(item).? == i) {
            try result.append(allocator, item);
        }
    }

    return result.toOwnedSlice(allocator);
}

test "keep last occurrence of duplicates" {
    const allocator = testing.allocator;

    const numbers = [_]i32{ 1, 2, 3, 2, 4, 1, 5 };
    const unique = try keepLastOccurrence(i32, allocator, &numbers);
    defer allocator.free(unique);

    try testing.expectEqual(@as(usize, 5), unique.len);
    try testing.expectEqual(@as(i32, 3), unique[0]); // Index 2
    try testing.expectEqual(@as(i32, 2), unique[1]); // Index 3 (last 2)
    try testing.expectEqual(@as(i32, 4), unique[2]); // Index 4
    try testing.expectEqual(@as(i32, 1), unique[3]); // Index 5 (last 1)
    try testing.expectEqual(@as(i32, 5), unique[4]); // Index 6
}

test "keep last occurrence with all unique" {
    const allocator = testing.allocator;

    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    const unique = try keepLastOccurrence(i32, allocator, &numbers);
    defer allocator.free(unique);

    try testing.expectEqual(@as(usize, 5), unique.len);
    try testing.expectEqualSlices(i32, &numbers, unique);
}

// ==============================================================================
// Custom Equality with HashMap
// ==============================================================================

const Point = struct {
    x: f32,
    y: f32,

    pub fn eql(self: Point, other: Point) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn hashFn(self: Point) u64 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(std.mem.asBytes(&self.x));
        hasher.update(std.mem.asBytes(&self.y));
        return hasher.final();
    }
};

fn removeDuplicatePoints(
    allocator: std.mem.Allocator,
    points: []const Point,
) ![]Point {
    const Context = struct {
        pub fn hash(_: @This(), p: Point) u64 {
            return p.hashFn();
        }
        pub fn eql(_: @This(), a: Point, b: Point) bool {
            return a.eql(b);
        }
    };

    var seen = std.HashMap(Point, void, Context, std.hash_map.default_max_load_percentage).init(allocator);
    defer seen.deinit();

    var result = std.ArrayList(Point){};
    errdefer result.deinit(allocator);

    for (points) |point| {
        if (!seen.contains(point)) {
            try seen.put(point, {});
            try result.append(allocator, point);
        }
    }

    return result.toOwnedSlice(allocator);
}

test "remove duplicate points with custom equality" {
    const allocator = testing.allocator;

    const points = [_]Point{
        .{ .x = 1.0, .y = 2.0 },
        .{ .x = 3.0, .y = 4.0 },
        .{ .x = 1.0, .y = 2.0 }, // Duplicate
        .{ .x = 5.0, .y = 6.0 },
        .{ .x = 3.0, .y = 4.0 }, // Duplicate
    };

    const unique = try removeDuplicatePoints(allocator, &points);
    defer allocator.free(unique);

    try testing.expectEqual(@as(usize, 3), unique.len);
    try testing.expectEqual(@as(f32, 1.0), unique[0].x);
    try testing.expectEqual(@as(f32, 2.0), unique[0].y);
    try testing.expectEqual(@as(f32, 3.0), unique[1].x);
    try testing.expectEqual(@as(f32, 4.0), unique[1].y);
    try testing.expectEqual(@as(f32, 5.0), unique[2].x);
    try testing.expectEqual(@as(f32, 6.0), unique[2].y);
}

// ==============================================================================
// Unordered Deduplication (When Order Doesn't Matter)
// ==============================================================================

fn removeDuplicatesUnordered(
    comptime T: type,
    allocator: std.mem.Allocator,
    items: []const T,
) ![]T {
    var set = std.AutoHashMap(T, void).init(allocator);
    defer set.deinit();

    for (items) |item| {
        try set.put(item, {});
    }

    var result = try allocator.alloc(T, set.count());
    errdefer allocator.free(result);

    var i: usize = 0;
    var it = set.keyIterator();
    while (it.next()) |key| : (i += 1) {
        result[i] = key.*;
    }

    return result;
}

test "unordered deduplication" {
    const allocator = testing.allocator;

    const numbers = [_]i32{ 1, 2, 3, 2, 1 };
    const unique = try removeDuplicatesUnordered(i32, allocator, &numbers);
    defer allocator.free(unique);

    try testing.expectEqual(@as(usize, 3), unique.len);

    // Order is unpredictable, so just check all elements are present
    var found = [_]bool{ false, false, false };
    for (unique) |num| {
        switch (num) {
            1 => found[0] = true,
            2 => found[1] = true,
            3 => found[2] = true,
            else => unreachable,
        }
    }

    try testing.expect(found[0]);
    try testing.expect(found[1]);
    try testing.expect(found[2]);
}

// ==============================================================================
// Practical Example: Cleaning Tag List
// ==============================================================================

fn cleanTagList(
    allocator: std.mem.Allocator,
    tags: []const []const u8,
) ![][]const u8 {
    var seen = std.StringHashMap(void).init(allocator);
    defer seen.deinit();

    var result = std.ArrayList([]const u8){};
    errdefer {
        for (result.items) |tag| {
            allocator.free(tag);
        }
        result.deinit(allocator);
    }

    for (tags) |tag| {
        // Skip empty tags
        if (tag.len == 0) continue;

        // Normalize to lowercase for comparison
        const lower = try std.ascii.allocLowerString(allocator, tag);
        defer allocator.free(lower);

        if (!seen.contains(lower)) {
            const owned = try allocator.dupe(u8, lower);
            errdefer allocator.free(owned);
            try seen.put(owned, {});
            try result.append(allocator, owned);
        }
    }

    return result.toOwnedSlice(allocator);
}

test "clean tag list with normalization" {
    const allocator = testing.allocator;

    const tags = [_][]const u8{ "Zig", "rust", "ZIG", "", "Rust", "go", "Zig" };
    const cleaned = try cleanTagList(allocator, &tags);
    defer {
        for (cleaned) |tag| {
            allocator.free(tag);
        }
        allocator.free(cleaned);
    }

    try testing.expectEqual(@as(usize, 3), cleaned.len);
    try testing.expectEqualStrings("zig", cleaned[0]);
    try testing.expectEqualStrings("rust", cleaned[1]);
    try testing.expectEqualStrings("go", cleaned[2]);
}

// ==============================================================================
// Edge Cases
// ==============================================================================

test "single element slice" {
    const allocator = testing.allocator;

    const numbers = [_]i32{42};
    const unique = try removeDuplicates(i32, allocator, &numbers);
    defer allocator.free(unique);

    try testing.expectEqual(@as(usize, 1), unique.len);
    try testing.expectEqual(@as(i32, 42), unique[0]);
}

test "large sequence with many duplicates" {
    const allocator = testing.allocator;

    // Create a large sequence with pattern: 0,1,2,0,1,2,...
    const numbers = try allocator.alloc(i32, 1000);
    defer allocator.free(numbers);

    for (numbers, 0..) |*num, i| {
        num.* = @as(i32, @intCast(i % 3));
    }

    const unique = try removeDuplicates(i32, allocator, numbers);
    defer allocator.free(unique);

    try testing.expectEqual(@as(usize, 3), unique.len);
    try testing.expectEqual(@as(i32, 0), unique[0]);
    try testing.expectEqual(@as(i32, 1), unique[1]);
    try testing.expectEqual(@as(i32, 2), unique[2]);
}

test "negative numbers deduplication" {
    const allocator = testing.allocator;

    const numbers = [_]i32{ -1, -2, -3, -2, -1, 0, -3 };
    const unique = try removeDuplicates(i32, allocator, &numbers);
    defer allocator.free(unique);

    try testing.expectEqual(@as(usize, 4), unique.len);
    try testing.expectEqual(@as(i32, -1), unique[0]);
    try testing.expectEqual(@as(i32, -2), unique[1]);
    try testing.expectEqual(@as(i32, -3), unique[2]);
    try testing.expectEqual(@as(i32, 0), unique[3]);
}
