// Recipe 1.12: Determining Most Frequently Occurring Items
// Target Zig Version: 0.15.2
//
// Demonstrates frequency counting and finding most common elements using HashMaps.
// Run: zig test code/02-core/01-data-structures/recipe_1_12.zig

const std = @import("std");
const testing = std.testing;

// ==============================================================================
// Basic Frequency Counting
// ==============================================================================

// ANCHOR: count_frequencies
fn countFrequencies(
    comptime T: type,
    allocator: std.mem.Allocator,
    items: []const T,
) !std.AutoHashMap(T, usize) {
    var freq_map = std.AutoHashMap(T, usize).init(allocator);
    errdefer freq_map.deinit();

    for (items) |item| {
        const entry = try freq_map.getOrPut(item);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
        } else {
            entry.value_ptr.* = 1;
        }
    }

    return freq_map;
}
// ANCHOR_END: count_frequencies

test "basic frequency counting with integers" {
    const allocator = testing.allocator;

    const numbers = [_]i32{ 1, 2, 3, 2, 1, 3, 1, 4, 2, 1 };
    var freq_map = try countFrequencies(i32, allocator, &numbers);
    defer freq_map.deinit();

    try testing.expectEqual(@as(usize, 4), freq_map.get(1).?);
    try testing.expectEqual(@as(usize, 3), freq_map.get(2).?);
    try testing.expectEqual(@as(usize, 2), freq_map.get(3).?);
    try testing.expectEqual(@as(usize, 1), freq_map.get(4).?);
}

test "frequency counting with strings" {
    const allocator = testing.allocator;

    const words = [_][]const u8{ "apple", "banana", "apple", "cherry", "banana", "apple" };

    var freq_map = std.StringHashMap(usize).init(allocator);
    defer freq_map.deinit();

    for (words) |word| {
        const entry = try freq_map.getOrPut(word);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
        } else {
            entry.value_ptr.* = 1;
        }
    }

    try testing.expectEqual(@as(usize, 3), freq_map.get("apple").?);
    try testing.expectEqual(@as(usize, 2), freq_map.get("banana").?);
    try testing.expectEqual(@as(usize, 1), freq_map.get("cherry").?);
}

test "empty collection frequency" {
    const allocator = testing.allocator;

    const numbers: []const i32 = &[_]i32{};
    var freq_map = try countFrequencies(i32, allocator, numbers);
    defer freq_map.deinit();

    try testing.expectEqual(@as(usize, 0), freq_map.count());
}

// ==============================================================================
// Finding the Most Common Item
// ==============================================================================

// ANCHOR: most_common
fn mostCommon(
    comptime T: type,
    freq_map: std.AutoHashMap(T, usize),
) ?struct { item: T, count: usize } {
    if (freq_map.count() == 0) return null;

    var max_item: ?T = null;
    var max_count: usize = 0;

    var it = freq_map.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.* > max_count) {
            max_count = entry.value_ptr.*;
            max_item = entry.key_ptr.*;
        }
    }

    return .{ .item = max_item.?, .count = max_count };
}
// ANCHOR_END: most_common

test "find most common item" {
    const allocator = testing.allocator;

    const numbers = [_]i32{ 5, 2, 5, 3, 5, 2, 1 };
    var freq_map = try countFrequencies(i32, allocator, &numbers);
    defer freq_map.deinit();

    const result = mostCommon(i32, freq_map).?;
    try testing.expectEqual(@as(i32, 5), result.item);
    try testing.expectEqual(@as(usize, 3), result.count);
}

test "most common with empty map" {
    const allocator = testing.allocator;

    var freq_map = std.AutoHashMap(i32, usize).init(allocator);
    defer freq_map.deinit();

    try testing.expect(mostCommon(i32, freq_map) == null);
}

test "most common with tie" {
    const allocator = testing.allocator;

    const numbers = [_]i32{ 1, 2, 1, 2 };
    var freq_map = try countFrequencies(i32, allocator, &numbers);
    defer freq_map.deinit();

    const result = mostCommon(i32, freq_map).?;
    try testing.expectEqual(@as(usize, 2), result.count);
    // Either 1 or 2 is acceptable due to HashMap ordering
    try testing.expect(result.item == 1 or result.item == 2);
}

// ==============================================================================
// Finding Top N Most Common Items
// ==============================================================================

// ANCHOR: top_n_frequencies
const FreqEntry = struct {
    item: []const u8,
    count: usize,
};

fn freqEntryOrder(_: void, a: FreqEntry, b: FreqEntry) std.math.Order {
    return std.math.order(a.count, b.count);
}

fn topN(
    allocator: std.mem.Allocator,
    freq_map: std.StringHashMap(usize),
    n: usize,
) ![]FreqEntry {
    if (n == 0 or freq_map.count() == 0) return allocator.alloc(FreqEntry, 0);

    var queue = std.PriorityQueue(FreqEntry, void, freqEntryOrder).init(allocator, {});
    defer queue.deinit();

    var it = freq_map.iterator();
    while (it.next()) |entry| {
        try queue.add(.{
            .item = entry.key_ptr.*,
            .count = entry.value_ptr.*,
        });
        if (queue.count() > n) {
            _ = queue.remove();
        }
    }

    const result_size = queue.count();
    var result = try allocator.alloc(FreqEntry, result_size);
    while (queue.count() > 0) {
        const idx = queue.count() - 1;
        result[idx] = queue.remove();
    }
    return result;
}
// ANCHOR_END: top_n_frequencies

test "top N most common items" {
    const allocator = testing.allocator;

    const words = [_][]const u8{
        "apple",  "banana", "apple",  "cherry",
        "banana", "apple",  "date",   "banana",
    };

    var freq_map = std.StringHashMap(usize).init(allocator);
    defer freq_map.deinit();

    for (words) |word| {
        const entry = try freq_map.getOrPut(word);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
        } else {
            entry.value_ptr.* = 1;
        }
    }

    const top2 = try topN(allocator, freq_map, 2);
    defer allocator.free(top2);

    try testing.expectEqual(@as(usize, 2), top2.len);

    // Both apple and banana have count 3, either order is valid
    try testing.expectEqual(@as(usize, 3), top2[0].count);
    try testing.expectEqual(@as(usize, 3), top2[1].count);

    // Check that we got the right items (either order)
    const has_apple = std.mem.eql(u8, top2[0].item, "apple") or std.mem.eql(u8, top2[1].item, "apple");
    const has_banana = std.mem.eql(u8, top2[0].item, "banana") or std.mem.eql(u8, top2[1].item, "banana");
    try testing.expect(has_apple);
    try testing.expect(has_banana);
}

test "top N when N exceeds item count" {
    const allocator = testing.allocator;

    var freq_map = std.StringHashMap(usize).init(allocator);
    defer freq_map.deinit();

    try freq_map.put("a", 5);
    try freq_map.put("b", 3);

    const top10 = try topN(allocator, freq_map, 10);
    defer allocator.free(top10);

    try testing.expectEqual(@as(usize, 2), top10.len);
}

// ==============================================================================
// Generic Top N Function
// ==============================================================================

fn FreqResult(comptime T: type) type {
    return struct {
        item: T,
        count: usize,
    };
}

fn topNGeneric(
    comptime T: type,
    allocator: std.mem.Allocator,
    freq_map: std.AutoHashMap(T, usize),
    n: usize,
) ![]FreqResult(T) {
    if (n == 0 or freq_map.count() == 0) return allocator.alloc(FreqResult(T), 0);

    const Compare = struct {
        pub fn order(_: void, a: FreqResult(T), b: FreqResult(T)) std.math.Order {
            return std.math.order(a.count, b.count);
        }
    };

    var queue = std.PriorityQueue(FreqResult(T), void, Compare.order).init(allocator, {});
    defer queue.deinit();

    var it = freq_map.iterator();
    while (it.next()) |entry| {
        try queue.add(.{
            .item = entry.key_ptr.*,
            .count = entry.value_ptr.*,
        });
        if (queue.count() > n) {
            _ = queue.remove();
        }
    }

    const result_size = queue.count();
    var result = try allocator.alloc(FreqResult(T), result_size);
    while (queue.count() > 0) {
        const idx = queue.count() - 1;
        result[idx] = queue.remove();
    }
    return result;
}

test "generic top N with integers" {
    const allocator = testing.allocator;

    const numbers = [_]i32{ 7, 3, 7, 9, 3, 7, 1 };
    var freq_map = try countFrequencies(i32, allocator, &numbers);
    defer freq_map.deinit();

    const top2 = try topNGeneric(i32, allocator, freq_map, 2);
    defer allocator.free(top2);

    try testing.expectEqual(@as(usize, 2), top2.len);
    try testing.expectEqual(@as(i32, 7), top2[0].item);
    try testing.expectEqual(@as(usize, 3), top2[0].count);
    try testing.expectEqual(@as(i32, 3), top2[1].item);
    try testing.expectEqual(@as(usize, 2), top2[1].count);
}

// ==============================================================================
// Finding Items by Frequency Threshold
// ==============================================================================

fn itemsWithMinFrequency(
    comptime T: type,
    allocator: std.mem.Allocator,
    freq_map: std.AutoHashMap(T, usize),
    min_count: usize,
) ![]T {
    var result = std.ArrayList(T){};
    errdefer result.deinit(allocator);

    var it = freq_map.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.* >= min_count) {
            try result.append(allocator, entry.key_ptr.*);
        }
    }

    return result.toOwnedSlice(allocator);
}

test "items with minimum frequency" {
    const allocator = testing.allocator;

    const numbers = [_]i32{ 1, 2, 2, 3, 3, 3, 4, 4, 4, 4 };
    var freq_map = try countFrequencies(i32, allocator, &numbers);
    defer freq_map.deinit();

    const items = try itemsWithMinFrequency(i32, allocator, freq_map, 3);
    defer allocator.free(items);

    try testing.expectEqual(@as(usize, 2), items.len);

    // Items can be in any order
    var found_3 = false;
    var found_4 = false;
    for (items) |item| {
        if (item == 3) found_3 = true;
        if (item == 4) found_4 = true;
    }
    try testing.expect(found_3);
    try testing.expect(found_4);
}

test "no items meet minimum frequency" {
    const allocator = testing.allocator;

    const numbers = [_]i32{ 1, 2, 3 };
    var freq_map = try countFrequencies(i32, allocator, &numbers);
    defer freq_map.deinit();

    const items = try itemsWithMinFrequency(i32, allocator, freq_map, 5);
    defer allocator.free(items);

    try testing.expectEqual(@as(usize, 0), items.len);
}

// ==============================================================================
// Character Frequency Counting
// ==============================================================================

fn countCharFrequencies(
    allocator: std.mem.Allocator,
    text: []const u8,
) !std.AutoHashMap(u8, usize) {
    var freq_map = std.AutoHashMap(u8, usize).init(allocator);
    errdefer freq_map.deinit();

    for (text) |char| {
        const entry = try freq_map.getOrPut(char);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
        } else {
            entry.value_ptr.* = 1;
        }
    }

    return freq_map;
}

test "character frequency counting" {
    const allocator = testing.allocator;

    const text = "hello world";
    var freq_map = try countCharFrequencies(allocator, text);
    defer freq_map.deinit();

    try testing.expectEqual(@as(usize, 3), freq_map.get('l').?);
    try testing.expectEqual(@as(usize, 2), freq_map.get('o').?);
    try testing.expectEqual(@as(usize, 1), freq_map.get('h').?);
    try testing.expectEqual(@as(usize, 1), freq_map.get(' ').?);
}

test "character frequency with special characters" {
    const allocator = testing.allocator;

    const text = "a!!b!!c";
    var freq_map = try countCharFrequencies(allocator, text);
    defer freq_map.deinit();

    try testing.expectEqual(@as(usize, 4), freq_map.get('!').?);
    try testing.expectEqual(@as(usize, 1), freq_map.get('a').?);
    try testing.expectEqual(@as(usize, 1), freq_map.get('b').?);
    try testing.expectEqual(@as(usize, 1), freq_map.get('c').?);
}

// ==============================================================================
// Mode (Statistical)
// ==============================================================================

fn mode(
    comptime T: type,
    allocator: std.mem.Allocator,
    data: []const T,
) !?T {
    var freq_map = try countFrequencies(T, allocator, data);
    defer freq_map.deinit();

    if (freq_map.count() == 0) return null;

    var mode_value: ?T = null;
    var max_count: usize = 0;

    var it = freq_map.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.* > max_count) {
            max_count = entry.value_ptr.*;
            mode_value = entry.key_ptr.*;
        }
    }

    return mode_value;
}

test "statistical mode" {
    const allocator = testing.allocator;

    const data = [_]i32{ 1, 2, 2, 3, 3, 3, 4 };
    const mode_value = try mode(i32, allocator, &data);

    try testing.expectEqual(@as(i32, 3), mode_value.?);
}

test "mode with empty dataset" {
    const allocator = testing.allocator;

    const data: []const i32 = &[_]i32{};
    const mode_value = try mode(i32, allocator, data);

    try testing.expect(mode_value == null);
}

test "mode with uniform distribution" {
    const allocator = testing.allocator;

    const data = [_]i32{ 1, 2, 3, 4 };
    const mode_value = try mode(i32, allocator, &data);

    // Any value is valid as mode when all have same frequency
    try testing.expect(mode_value != null);
}

// ==============================================================================
// Frequency Distribution
// ==============================================================================

fn frequencyDistribution(
    allocator: std.mem.Allocator,
    freq_map: std.AutoHashMap(i32, usize),
) !std.AutoHashMap(usize, usize) {
    var distribution = std.AutoHashMap(usize, usize).init(allocator);
    errdefer distribution.deinit();

    var it = freq_map.iterator();
    while (it.next()) |entry| {
        const count = entry.value_ptr.*;
        const dist_entry = try distribution.getOrPut(count);
        if (dist_entry.found_existing) {
            dist_entry.value_ptr.* += 1;
        } else {
            dist_entry.value_ptr.* = 1;
        }
    }

    return distribution;
}

test "frequency distribution" {
    const allocator = testing.allocator;

    const numbers = [_]i32{ 1, 2, 2, 3, 3, 3, 4, 4, 4, 4 };
    var freq_map = try countFrequencies(i32, allocator, &numbers);
    defer freq_map.deinit();

    var distribution = try frequencyDistribution(allocator, freq_map);
    defer distribution.deinit();

    // 1 appears once (count=1)
    // 2 appears twice (count=2)
    // 3 appears three times (count=3)
    // 4 appears four times (count=4)
    try testing.expectEqual(@as(usize, 1), distribution.get(1).?); // One item with count 1
    try testing.expectEqual(@as(usize, 1), distribution.get(2).?); // One item with count 2
    try testing.expectEqual(@as(usize, 1), distribution.get(3).?); // One item with count 3
    try testing.expectEqual(@as(usize, 1), distribution.get(4).?); // One item with count 4
}

// ==============================================================================
// Multiset Operations
// ==============================================================================

const Multiset = struct {
    map: std.AutoHashMap(i32, usize),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Multiset {
        return .{
            .map = std.AutoHashMap(i32, usize).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Multiset) void {
        self.map.deinit();
    }

    pub fn add(self: *Multiset, item: i32, occurrences: usize) !void {
        const entry = try self.map.getOrPut(item);
        if (entry.found_existing) {
            entry.value_ptr.* += occurrences;
        } else {
            entry.value_ptr.* = occurrences;
        }
    }

    pub fn count(self: Multiset, item: i32) usize {
        return self.map.get(item) orelse 0;
    }

    pub fn totalCount(self: Multiset) usize {
        var total: usize = 0;
        var it = self.map.valueIterator();
        while (it.next()) |cnt| {
            total += cnt.*;
        }
        return total;
    }
};

test "multiset operations" {
    const allocator = testing.allocator;

    var mset = Multiset.init(allocator);
    defer mset.deinit();

    try mset.add(5, 3);
    try mset.add(10, 2);
    try mset.add(5, 1);

    try testing.expectEqual(@as(usize, 4), mset.count(5));
    try testing.expectEqual(@as(usize, 2), mset.count(10));
    try testing.expectEqual(@as(usize, 0), mset.count(99));
    try testing.expectEqual(@as(usize, 6), mset.totalCount());
}

// ==============================================================================
// Practical Patterns and Edge Cases
// ==============================================================================

test "counting with single unique item" {
    const allocator = testing.allocator;

    const numbers = [_]i32{ 7, 7, 7, 7, 7 };
    var freq_map = try countFrequencies(i32, allocator, &numbers);
    defer freq_map.deinit();

    try testing.expectEqual(@as(usize, 1), freq_map.count());
    try testing.expectEqual(@as(usize, 5), freq_map.get(7).?);
}

test "counting all unique items" {
    const allocator = testing.allocator;

    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    var freq_map = try countFrequencies(i32, allocator, &numbers);
    defer freq_map.deinit();

    try testing.expectEqual(@as(usize, 5), freq_map.count());
    for (numbers) |num| {
        try testing.expectEqual(@as(usize, 1), freq_map.get(num).?);
    }
}

test "large dataset frequency counting" {
    const allocator = testing.allocator;

    // Create a large dataset with pattern
    const numbers = try allocator.alloc(i32, 1000);
    defer allocator.free(numbers);

    for (numbers, 0..) |*num, i| {
        num.* = @as(i32, @intCast(i % 10));
    }

    var freq_map = try countFrequencies(i32, allocator, numbers);
    defer freq_map.deinit();

    // Each number 0-9 should appear 100 times
    for (0..10) |i| {
        try testing.expectEqual(@as(usize, 100), freq_map.get(@as(i32, @intCast(i))).?);
    }
}

test "frequency counting with negative numbers" {
    const allocator = testing.allocator;

    const numbers = [_]i32{ -5, -3, -5, 0, -3, -5 };
    var freq_map = try countFrequencies(i32, allocator, &numbers);
    defer freq_map.deinit();

    try testing.expectEqual(@as(usize, 3), freq_map.get(-5).?);
    try testing.expectEqual(@as(usize, 2), freq_map.get(-3).?);
    try testing.expectEqual(@as(usize, 1), freq_map.get(0).?);
}

test "case-insensitive word counting" {
    const allocator = testing.allocator;

    const words_raw = [_][]const u8{ "Apple", "BANANA", "apple", "Banana", "APPLE" };

    var freq_map = std.StringHashMap(usize).init(allocator);
    defer {
        // Clean up allocated keys
        var it = freq_map.keyIterator();
        while (it.next()) |key| {
            allocator.free(key.*);
        }
        freq_map.deinit();
    }

    // Convert to lowercase and count
    for (words_raw) |word| {
        const lower = try std.ascii.allocLowerString(allocator, word);
        defer allocator.free(lower);

        const entry = try freq_map.getOrPut(lower);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
        } else {
            // Need to duplicate for storage
            const stored_key = try allocator.dupe(u8, lower);
            entry.key_ptr.* = stored_key;
            entry.value_ptr.* = 1;
        }
    }

    try testing.expectEqual(@as(usize, 3), freq_map.get("apple").?);
    try testing.expectEqual(@as(usize, 2), freq_map.get("banana").?);
}

test "finding maximum frequency value" {
    const allocator = testing.allocator;

    const numbers = [_]i32{ 1, 2, 2, 3, 3, 3 };
    var freq_map = try countFrequencies(i32, allocator, &numbers);
    defer freq_map.deinit();

    var max_freq: usize = 0;
    var it = freq_map.valueIterator();
    while (it.next()) |count| {
        max_freq = @max(max_freq, count.*);
    }

    try testing.expectEqual(@as(usize, 3), max_freq);
}
