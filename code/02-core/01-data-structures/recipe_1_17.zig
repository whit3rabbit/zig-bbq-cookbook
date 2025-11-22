// Recipe 1.17: Extracting a subset of a dictionary
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to extract a subset of key-value pairs from
// a hashmap based on keys or value criteria.

const std = @import("std");
const testing = std.testing;

/// Extract entries from a map where the key is in the provided keys set
// ANCHOR: extract_by_keys
pub fn extractByKeys(
    comptime K: type,
    comptime V: type,
    allocator: std.mem.Allocator,
    source: anytype,
    keys: []const K,
) !std.AutoHashMap(K, V) {
    var result = std.AutoHashMap(K, V).init(allocator);
    errdefer result.deinit();

    for (keys) |key| {
        if (source.get(key)) |value| {
            try result.put(key, value);
        }
    }

    return result;
}
// ANCHOR_END: extract_by_keys

/// Extract entries from a map where the value matches a predicate
// ANCHOR: extract_by_value
pub fn extractByValue(
    comptime K: type,
    comptime V: type,
    allocator: std.mem.Allocator,
    source: anytype,
    predicate: *const fn (V) bool,
) !std.AutoHashMap(K, V) {
    var result = std.AutoHashMap(K, V).init(allocator);
    errdefer result.deinit();

    var iter = source.iterator();
    while (iter.next()) |entry| {
        if (predicate(entry.value_ptr.*)) {
            try result.put(entry.key_ptr.*, entry.value_ptr.*);
        }
    }

    return result;
}
// ANCHOR_END: extract_by_value

/// Extract entries from a StringHashMap where the value matches a predicate
pub fn extractStringByValue(
    comptime V: type,
    allocator: std.mem.Allocator,
    source: std.StringHashMap(V),
    predicate: *const fn (V) bool,
) !std.StringHashMap(V) {
    var result = std.StringHashMap(V).init(allocator);
    errdefer result.deinit();

    var iter = source.iterator();
    while (iter.next()) |entry| {
        if (predicate(entry.value_ptr.*)) {
            try result.put(entry.key_ptr.*, entry.value_ptr.*);
        }
    }

    return result;
}

/// Extract entries from a map where key-value pair matches a predicate
// ANCHOR: extract_by_pair
pub fn extractByPair(
    comptime K: type,
    comptime V: type,
    allocator: std.mem.Allocator,
    source: anytype,
    predicate: *const fn (K, V) bool,
) !std.AutoHashMap(K, V) {
    var result = std.AutoHashMap(K, V).init(allocator);
    errdefer result.deinit();

    var iter = source.iterator();
    while (iter.next()) |entry| {
        if (predicate(entry.key_ptr.*, entry.value_ptr.*)) {
            try result.put(entry.key_ptr.*, entry.value_ptr.*);
        }
    }

    return result;
}
// ANCHOR_END: extract_by_pair

/// Extract entries from a StringHashMap where key-value pair matches a predicate
pub fn extractStringByPair(
    comptime V: type,
    allocator: std.mem.Allocator,
    source: std.StringHashMap(V),
    predicate: *const fn ([]const u8, V) bool,
) !std.StringHashMap(V) {
    var result = std.StringHashMap(V).init(allocator);
    errdefer result.deinit();

    var iter = source.iterator();
    while (iter.next()) |entry| {
        if (predicate(entry.key_ptr.*, entry.value_ptr.*)) {
            try result.put(entry.key_ptr.*, entry.value_ptr.*);
        }
    }

    return result;
}

/// Extract entries for string keys (specialized for StringHashMap)
pub fn extractStringKeys(
    comptime V: type,
    allocator: std.mem.Allocator,
    source: std.StringHashMap(V),
    keys: []const []const u8,
) !std.StringHashMap(V) {
    var result = std.StringHashMap(V).init(allocator);
    errdefer result.deinit();

    for (keys) |key| {
        if (source.get(key)) |value| {
            try result.put(key, value);
        }
    }

    return result;
}

test "extract by specific keys" {
    var prices = std.StringHashMap(f32).init(testing.allocator);
    defer prices.deinit();

    try prices.put("apple", 1.50);
    try prices.put("banana", 0.75);
    try prices.put("orange", 1.25);
    try prices.put("grape", 2.00);
    try prices.put("melon", 3.50);

    const wanted = [_][]const u8{ "apple", "orange", "melon" };
    var subset = try extractStringKeys(f32, testing.allocator, prices, &wanted);
    defer subset.deinit();

    try testing.expectEqual(@as(usize, 3), subset.count());
    try testing.expectEqual(@as(f32, 1.50), subset.get("apple").?);
    try testing.expectEqual(@as(f32, 1.25), subset.get("orange").?);
    try testing.expectEqual(@as(f32, 3.50), subset.get("melon").?);
    try testing.expect(subset.get("banana") == null);
}

test "extract by integer keys" {
    var ages = std.AutoHashMap(u32, []const u8).init(testing.allocator);
    defer ages.deinit();

    try ages.put(1, "Alice");
    try ages.put(2, "Bob");
    try ages.put(3, "Charlie");
    try ages.put(4, "Diana");
    try ages.put(5, "Eve");

    const wanted_ids = [_]u32{ 2, 4, 5 };
    var subset = try extractByKeys(u32, []const u8, testing.allocator, ages, &wanted_ids);
    defer subset.deinit();

    try testing.expectEqual(@as(usize, 3), subset.count());
    try testing.expectEqualStrings("Bob", subset.get(2).?);
    try testing.expectEqualStrings("Diana", subset.get(4).?);
    try testing.expectEqualStrings("Eve", subset.get(5).?);
}

test "extract by value predicate" {
    var scores = std.StringHashMap(i32).init(testing.allocator);
    defer scores.deinit();

    try scores.put("Alice", 95);
    try scores.put("Bob", 67);
    try scores.put("Charlie", 88);
    try scores.put("Diana", 72);
    try scores.put("Eve", 91);

    const isPassing = struct {
        fn pred(score: i32) bool {
            return score >= 80;
        }
    }.pred;

    var passing = try extractStringByValue(i32, testing.allocator, scores, isPassing);
    defer passing.deinit();

    try testing.expectEqual(@as(usize, 3), passing.count());
    try testing.expectEqual(@as(i32, 95), passing.get("Alice").?);
    try testing.expectEqual(@as(i32, 88), passing.get("Charlie").?);
    try testing.expectEqual(@as(i32, 91), passing.get("Eve").?);
    try testing.expect(passing.get("Bob") == null);
}

test "extract by key-value pair predicate" {
    var inventory = std.StringHashMap(i32).init(testing.allocator);
    defer inventory.deinit();

    try inventory.put("apples", 50);
    try inventory.put("bananas", 5);
    try inventory.put("oranges", 30);
    try inventory.put("grapes", 8);
    try inventory.put("melons", 2);

    // Extract items with low stock (< 10) but not if it's "melons"
    const needsRestock = struct {
        fn pred(name: []const u8, count: i32) bool {
            return count < 10 and !std.mem.eql(u8, name, "melons");
        }
    }.pred;

    var lowStock = try extractStringByPair(i32, testing.allocator, inventory, needsRestock);
    defer lowStock.deinit();

    try testing.expectEqual(@as(usize, 2), lowStock.count());
    try testing.expectEqual(@as(i32, 5), lowStock.get("bananas").?);
    try testing.expectEqual(@as(i32, 8), lowStock.get("grapes").?);
    try testing.expect(lowStock.get("melons") == null);
}

test "extract non-existent keys returns empty map" {
    var data = std.StringHashMap(i32).init(testing.allocator);
    defer data.deinit();

    try data.put("a", 1);
    try data.put("b", 2);

    const wanted = [_][]const u8{ "x", "y", "z" };
    var subset = try extractStringKeys(i32, testing.allocator, data, &wanted);
    defer subset.deinit();

    try testing.expectEqual(@as(usize, 0), subset.count());
}

test "extract with some non-existent keys" {
    var data = std.StringHashMap(i32).init(testing.allocator);
    defer data.deinit();

    try data.put("a", 1);
    try data.put("b", 2);
    try data.put("c", 3);

    const wanted = [_][]const u8{ "a", "x", "c", "y" };
    var subset = try extractStringKeys(i32, testing.allocator, data, &wanted);
    defer subset.deinit();

    try testing.expectEqual(@as(usize, 2), subset.count());
    try testing.expectEqual(@as(i32, 1), subset.get("a").?);
    try testing.expectEqual(@as(i32, 3), subset.get("c").?);
}

test "extract complex struct values" {
    const Person = struct {
        name: []const u8,
        age: u32,
        score: f32,
    };

    var people = std.AutoHashMap(u32, Person).init(testing.allocator);
    defer people.deinit();

    try people.put(1, .{ .name = "Alice", .age = 30, .score = 95.5 });
    try people.put(2, .{ .name = "Bob", .age = 25, .score = 67.0 });
    try people.put(3, .{ .name = "Charlie", .age = 35, .score = 88.5 });
    try people.put(4, .{ .name = "Diana", .age = 28, .score = 72.0 });

    const highScorers = struct {
        fn pred(p: Person) bool {
            return p.score >= 85.0;
        }
    }.pred;

    var result = try extractByValue(u32, Person, testing.allocator, people, highScorers);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.count());
    try testing.expectEqualStrings("Alice", result.get(1).?.name);
    try testing.expectEqualStrings("Charlie", result.get(3).?.name);
}

test "memory safety - no leaks" {
    // Using testing.allocator automatically checks for leaks
    var data = std.StringHashMap(i32).init(testing.allocator);
    defer data.deinit();

    try data.put("test", 42);

    const keys = [_][]const u8{"test"};
    var subset = try extractStringKeys(i32, testing.allocator, data, &keys);
    defer subset.deinit();

    try testing.expect(subset.count() > 0);
}
