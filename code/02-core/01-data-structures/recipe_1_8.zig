// Recipe 1.8: Calculating with Dictionaries
// Target Zig Version: 0.15.2
//
// Demonstrates calculations and transformations on HashMap values.
// Run: zig test code/02-core/01-data-structures/recipe_1_8.zig

const std = @import("std");
const testing = std.testing;

// ==============================================================================
// Finding Min/Max Values
// ==============================================================================

// ANCHOR: min_max_values
fn findMin(map: std.AutoArrayHashMap(u32, i32)) ?i32 {
    if (map.count() == 0) return null;

    var min_value = map.values()[0];
    for (map.values()[1..]) |value| {
        if (value < min_value) {
            min_value = value;
        }
    }
    return min_value;
}

fn findMax(map: std.AutoArrayHashMap(u32, i32)) ?i32 {
    if (map.count() == 0) return null;

    var max_value = map.values()[0];
    for (map.values()[1..]) |value| {
        if (value > max_value) {
            max_value = value;
        }
    }
    return max_value;
}
// ANCHOR_END: min_max_values

test "finding min and max values" {
    const allocator = testing.allocator;

    var prices = std.AutoArrayHashMap(u32, i32).init(allocator);
    defer prices.deinit();

    try prices.put(1, 45);
    try prices.put(2, 12);
    try prices.put(3, 99);
    try prices.put(4, 5);

    try testing.expectEqual(@as(?i32, 5), findMin(prices));
    try testing.expectEqual(@as(?i32, 99), findMax(prices));
}

test "min/max on empty map" {
    const allocator = testing.allocator;

    var map = std.AutoArrayHashMap(u32, i32).init(allocator);
    defer map.deinit();

    try testing.expectEqual(@as(?i32, null), findMin(map));
    try testing.expectEqual(@as(?i32, null), findMax(map));
}

// ==============================================================================
// Finding Key with Min/Max Value
// ==============================================================================

fn findKeyWithMaxValue(map: std.AutoArrayHashMap(u32, i32)) ?u32 {
    if (map.count() == 0) return null;

    var max_key = map.keys()[0];
    var max_value = map.values()[0];

    for (map.keys()[1..], map.values()[1..]) |key, value| {
        if (value > max_value) {
            max_key = key;
            max_value = value;
        }
    }
    return max_key;
}

fn findKeyWithMinValue(map: std.AutoArrayHashMap(u32, i32)) ?u32 {
    if (map.count() == 0) return null;

    var min_key = map.keys()[0];
    var min_value = map.values()[0];

    for (map.keys()[1..], map.values()[1..]) |key, value| {
        if (value < min_value) {
            min_key = key;
            min_value = value;
        }
    }
    return min_key;
}

test "finding keys with min/max values" {
    const allocator = testing.allocator;

    var scores = std.AutoArrayHashMap(u32, i32).init(allocator);
    defer scores.deinit();

    try scores.put(1, 85);
    try scores.put(2, 92);
    try scores.put(3, 78);

    try testing.expectEqual(@as(?u32, 2), findKeyWithMaxValue(scores));
    try testing.expectEqual(@as(?u32, 3), findKeyWithMinValue(scores));
}

// ==============================================================================
// Summing and Averaging
// ==============================================================================

// ANCHOR: sum_average
fn sumValues(map: std.AutoArrayHashMap(u32, i32)) i32 {
    var total: i32 = 0;
    for (map.values()) |value| {
        total += value;
    }
    return total;
}

fn averageValues(map: std.AutoArrayHashMap(u32, f64)) f64 {
    if (map.count() == 0) return 0.0;

    var total: f64 = 0.0;
    for (map.values()) |value| {
        total += value;
    }
    return total / @as(f64, @floatFromInt(map.count()));
}
// ANCHOR_END: sum_average

test "sum values" {
    const allocator = testing.allocator;

    var numbers = std.AutoArrayHashMap(u32, i32).init(allocator);
    defer numbers.deinit();

    try numbers.put(1, 10);
    try numbers.put(2, 20);
    try numbers.put(3, 30);

    try testing.expectEqual(@as(i32, 60), sumValues(numbers));
}

test "average values" {
    const allocator = testing.allocator;

    var scores = std.AutoArrayHashMap(u32, f64).init(allocator);
    defer scores.deinit();

    try scores.put(1, 85.0);
    try scores.put(2, 90.0);
    try scores.put(3, 95.0);

    try testing.expectEqual(@as(f64, 90.0), averageValues(scores));
}

// ==============================================================================
// Filtering Maps
// ==============================================================================

// ANCHOR: filter_map
fn filterByValue(
    allocator: std.mem.Allocator,
    map: std.AutoArrayHashMap(u32, i32),
    min_value: i32,
) !std.AutoArrayHashMap(u32, i32) {
    var result = std.AutoArrayHashMap(u32, i32).init(allocator);
    errdefer result.deinit();

    var it = map.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.* >= min_value) {
            try result.put(entry.key_ptr.*, entry.value_ptr.*);
        }
    }
    return result;
}
// ANCHOR_END: filter_map

test "filter map by value" {
    const allocator = testing.allocator;

    var scores = std.AutoArrayHashMap(u32, i32).init(allocator);
    defer scores.deinit();

    try scores.put(1, 85);
    try scores.put(2, 92);
    try scores.put(3, 78);
    try scores.put(4, 95);

    var passing = try filterByValue(allocator, scores, 80);
    defer passing.deinit();

    try testing.expectEqual(@as(usize, 3), passing.count());
    try testing.expect(passing.contains(1));
    try testing.expect(passing.contains(2));
    try testing.expect(passing.contains(4));
    try testing.expect(!passing.contains(3));
}

// ==============================================================================
// Transforming Values
// ==============================================================================

fn multiplyValues(map: *std.AutoArrayHashMap(u32, i32), multiplier: i32) void {
    for (map.values()) |*value| {
        value.* *= multiplier;
    }
}

fn doubleValue(value: i32) i32 {
    return value * 2;
}

fn mapValues(
    allocator: std.mem.Allocator,
    map: std.AutoArrayHashMap(u32, i32),
    comptime transform: fn (i32) i32,
) !std.AutoArrayHashMap(u32, i32) {
    var result = std.AutoArrayHashMap(u32, i32).init(allocator);
    errdefer result.deinit();

    var it = map.iterator();
    while (it.next()) |entry| {
        try result.put(entry.key_ptr.*, transform(entry.value_ptr.*));
    }
    return result;
}

test "multiply all values in place" {
    const allocator = testing.allocator;

    var prices = std.AutoArrayHashMap(u32, i32).init(allocator);
    defer prices.deinit();

    try prices.put(1, 10);
    try prices.put(2, 20);
    try prices.put(3, 30);

    multiplyValues(&prices, 2);

    try testing.expectEqual(@as(i32, 20), prices.get(1).?);
    try testing.expectEqual(@as(i32, 40), prices.get(2).?);
    try testing.expectEqual(@as(i32, 60), prices.get(3).?);
}

test "transform values creating new map" {
    const allocator = testing.allocator;

    var original = std.AutoArrayHashMap(u32, i32).init(allocator);
    defer original.deinit();

    try original.put(1, 5);
    try original.put(2, 10);

    var doubled = try mapValues(allocator, original, doubleValue);
    defer doubled.deinit();

    try testing.expectEqual(@as(i32, 10), doubled.get(1).?);
    try testing.expectEqual(@as(i32, 20), doubled.get(2).?);

    // Original unchanged
    try testing.expectEqual(@as(i32, 5), original.get(1).?);
}

// ==============================================================================
// Counting Occurrences
// ==============================================================================

fn countOccurrences(
    allocator: std.mem.Allocator,
    items: []const u32,
) !std.AutoArrayHashMap(u32, usize) {
    var counts = std.AutoArrayHashMap(u32, usize).init(allocator);
    errdefer counts.deinit();

    for (items) |item| {
        const entry = try counts.getOrPut(item);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
        } else {
            entry.value_ptr.* = 1;
        }
    }
    return counts;
}

test "count occurrences" {
    const allocator = testing.allocator;

    const numbers = [_]u32{ 1, 2, 1, 3, 2, 1, 4, 2, 1 };
    var counts = try countOccurrences(allocator, &numbers);
    defer counts.deinit();

    try testing.expectEqual(@as(usize, 4), counts.get(1).?);
    try testing.expectEqual(@as(usize, 3), counts.get(2).?);
    try testing.expectEqual(@as(usize, 1), counts.get(3).?);
    try testing.expectEqual(@as(usize, 1), counts.get(4).?);
}

// ==============================================================================
// Merging Maps
// ==============================================================================

fn mergeMaps(
    allocator: std.mem.Allocator,
    map1: std.AutoArrayHashMap(u32, i32),
    map2: std.AutoArrayHashMap(u32, i32),
) !std.AutoArrayHashMap(u32, i32) {
    _ = allocator;
    var result = try map1.clone();
    errdefer result.deinit();

    var it = map2.iterator();
    while (it.next()) |entry| {
        try result.put(entry.key_ptr.*, entry.value_ptr.*);
    }
    return result;
}

fn addValues(a: i32, b: i32) i32 {
    return a + b;
}

fn mergeWith(
    allocator: std.mem.Allocator,
    map1: std.AutoArrayHashMap(u32, i32),
    map2: std.AutoArrayHashMap(u32, i32),
    comptime combine: fn (i32, i32) i32,
) !std.AutoArrayHashMap(u32, i32) {
    _ = allocator;
    var result = try map1.clone();
    errdefer result.deinit();

    var it = map2.iterator();
    while (it.next()) |entry| {
        if (result.getPtr(entry.key_ptr.*)) |existing| {
            existing.* = combine(existing.*, entry.value_ptr.*);
        } else {
            try result.put(entry.key_ptr.*, entry.value_ptr.*);
        }
    }
    return result;
}

test "merge maps - second overwrites first" {
    const allocator = testing.allocator;

    var map1 = std.AutoArrayHashMap(u32, i32).init(allocator);
    defer map1.deinit();
    var map2 = std.AutoArrayHashMap(u32, i32).init(allocator);
    defer map2.deinit();

    try map1.put(1, 10);
    try map1.put(2, 20);

    try map2.put(2, 25);
    try map2.put(3, 30);

    var merged = try mergeMaps(allocator, map1, map2);
    defer merged.deinit();

    try testing.expectEqual(@as(i32, 10), merged.get(1).?);
    try testing.expectEqual(@as(i32, 25), merged.get(2).?); // Overwritten
    try testing.expectEqual(@as(i32, 30), merged.get(3).?);
}

test "merge maps with combining function" {
    const allocator = testing.allocator;

    var map1 = std.AutoArrayHashMap(u32, i32).init(allocator);
    defer map1.deinit();
    var map2 = std.AutoArrayHashMap(u32, i32).init(allocator);
    defer map2.deinit();

    try map1.put(1, 10);
    try map1.put(2, 20);

    try map2.put(2, 5);
    try map2.put(3, 30);

    var merged = try mergeWith(allocator, map1, map2, addValues);
    defer merged.deinit();

    try testing.expectEqual(@as(i32, 10), merged.get(1).?);
    try testing.expectEqual(@as(i32, 25), merged.get(2).?); // 20 + 5
    try testing.expectEqual(@as(i32, 30), merged.get(3).?);
}

// ==============================================================================
// Inverting Maps
// ==============================================================================

fn invertMap(
    allocator: std.mem.Allocator,
    map: std.AutoArrayHashMap(u32, u32),
) !std.AutoArrayHashMap(u32, u32) {
    var result = std.AutoArrayHashMap(u32, u32).init(allocator);
    errdefer result.deinit();

    var it = map.iterator();
    while (it.next()) |entry| {
        try result.put(entry.value_ptr.*, entry.key_ptr.*);
    }
    return result;
}

test "invert map - swap keys and values" {
    const allocator = testing.allocator;

    var original = std.AutoArrayHashMap(u32, u32).init(allocator);
    defer original.deinit();

    try original.put(1, 100);
    try original.put(2, 200);
    try original.put(3, 300);

    var inverted = try invertMap(allocator, original);
    defer inverted.deinit();

    try testing.expectEqual(@as(u32, 1), inverted.get(100).?);
    try testing.expectEqual(@as(u32, 2), inverted.get(200).?);
    try testing.expectEqual(@as(u32, 3), inverted.get(300).?);
}

// ==============================================================================
// Top N Items
// ==============================================================================

const Entry = struct {
    key: u32,
    value: i32,
};

fn topN(
    allocator: std.mem.Allocator,
    map: std.AutoArrayHashMap(u32, i32),
    n: usize,
) ![]Entry {
    // Collect all entries
    var entries = try allocator.alloc(Entry, map.count());
    defer allocator.free(entries);

    var i: usize = 0;
    var it = map.iterator();
    while (it.next()) |entry| : (i += 1) {
        entries[i] = .{
            .key = entry.key_ptr.*,
            .value = entry.value_ptr.*,
        };
    }

    // Sort by value descending
    std.mem.sort(Entry, entries, {}, struct {
        fn lessThan(_: void, a: Entry, b: Entry) bool {
            return a.value > b.value;
        }
    }.lessThan);

    // Return top N in a new allocation
    const count = @min(n, entries.len);
    const result = try allocator.alloc(Entry, count);
    @memcpy(result, entries[0..count]);
    return result;
}

test "top N items by value" {
    const allocator = testing.allocator;

    var scores = std.AutoArrayHashMap(u32, i32).init(allocator);
    defer scores.deinit();

    try scores.put(1, 85);
    try scores.put(2, 92);
    try scores.put(3, 78);
    try scores.put(4, 95);
    try scores.put(5, 88);

    const top3 = try topN(allocator, scores, 3);
    defer allocator.free(top3);

    try testing.expectEqual(@as(usize, 3), top3.len);
    try testing.expectEqual(@as(u32, 4), top3[0].key);
    try testing.expectEqual(@as(i32, 95), top3[0].value);
    try testing.expectEqual(@as(u32, 2), top3[1].key);
    try testing.expectEqual(@as(i32, 92), top3[1].value);
    try testing.expectEqual(@as(u32, 5), top3[2].key);
    try testing.expectEqual(@as(i32, 88), top3[2].value);
}

// ==============================================================================
// Common Condition Checks
// ==============================================================================

fn allValuesAbove(map: std.AutoArrayHashMap(u32, i32), min: i32) bool {
    for (map.values()) |value| {
        if (value < min) return false;
    }
    return true;
}

fn anyValueEquals(map: std.AutoArrayHashMap(u32, i32), target: i32) bool {
    for (map.values()) |value| {
        if (value == target) return true;
    }
    return false;
}

fn countWhere(map: std.AutoArrayHashMap(u32, i32), min: i32) usize {
    var count: usize = 0;
    for (map.values()) |value| {
        if (value >= min) count += 1;
    }
    return count;
}

test "check all values meet condition" {
    const allocator = testing.allocator;

    var scores = std.AutoArrayHashMap(u32, i32).init(allocator);
    defer scores.deinit();

    try scores.put(1, 85);
    try scores.put(2, 90);
    try scores.put(3, 95);

    try testing.expect(allValuesAbove(scores, 80));
    try testing.expect(!allValuesAbove(scores, 90));
}

test "check any value matches" {
    const allocator = testing.allocator;

    var numbers = std.AutoArrayHashMap(u32, i32).init(allocator);
    defer numbers.deinit();

    try numbers.put(1, 10);
    try numbers.put(2, 20);
    try numbers.put(3, 30);

    try testing.expect(anyValueEquals(numbers, 20));
    try testing.expect(!anyValueEquals(numbers, 25));
}

test "count values matching condition" {
    const allocator = testing.allocator;

    var scores = std.AutoArrayHashMap(u32, i32).init(allocator);
    defer scores.deinit();

    try scores.put(1, 85);
    try scores.put(2, 92);
    try scores.put(3, 78);
    try scores.put(4, 95);

    try testing.expectEqual(@as(usize, 3), countWhere(scores, 85));
    try testing.expectEqual(@as(usize, 2), countWhere(scores, 92));
}

// ==============================================================================
// Practical Example: Statistics Calculator
// ==============================================================================

const Statistics = struct {
    min: i32,
    max: i32,
    sum: i32,
    average: f64,
    count: usize,

    pub fn calculate(map: std.AutoArrayHashMap(u32, i32)) ?Statistics {
        if (map.count() == 0) return null;

        var min_val = map.values()[0];
        var max_val = map.values()[0];
        var sum_val: i32 = 0;

        for (map.values()) |value| {
            if (value < min_val) min_val = value;
            if (value > max_val) max_val = value;
            sum_val += value;
        }

        return Statistics{
            .min = min_val,
            .max = max_val,
            .sum = sum_val,
            .average = @as(f64, @floatFromInt(sum_val)) / @as(f64, @floatFromInt(map.count())),
            .count = map.count(),
        };
    }
};

test "statistics calculator" {
    const allocator = testing.allocator;

    var data = std.AutoArrayHashMap(u32, i32).init(allocator);
    defer data.deinit();

    try data.put(1, 10);
    try data.put(2, 20);
    try data.put(3, 30);
    try data.put(4, 40);

    const stats = Statistics.calculate(data).?;

    try testing.expectEqual(@as(i32, 10), stats.min);
    try testing.expectEqual(@as(i32, 40), stats.max);
    try testing.expectEqual(@as(i32, 100), stats.sum);
    try testing.expectEqual(@as(f64, 25.0), stats.average);
    try testing.expectEqual(@as(usize, 4), stats.count);
}
