// Recipe 1.9: Finding Commonalities in Sets
// Target Zig Version: 0.15.2
//
// Demonstrates set operations using HashMap with void values.
// Run: zig test code/02-core/01-data-structures/recipe_1_9.zig

const std = @import("std");
const testing = std.testing;

// ==============================================================================
// Creating Sets
// ==============================================================================

// ANCHOR: basic_set
test "create and use integer set" {
    const allocator = testing.allocator;

    var numbers = std.AutoHashMap(i32, void).init(allocator);
    defer numbers.deinit();

    try numbers.put(1, {});
    try numbers.put(2, {});
    try numbers.put(3, {});

    try testing.expect(numbers.contains(1));
    try testing.expect(numbers.contains(2));
    try testing.expect(numbers.contains(3));
    try testing.expect(!numbers.contains(4));

    try testing.expectEqual(@as(usize, 3), numbers.count());
}
// ANCHOR_END: basic_set

test "create and use string set" {
    const allocator = testing.allocator;

    var words = std.StringHashMap(void).init(allocator);
    defer words.deinit();

    try words.put("hello", {});
    try words.put("world", {});

    try testing.expect(words.contains("hello"));
    try testing.expect(words.contains("world"));
    try testing.expect(!words.contains("missing"));
}

test "sets automatically deduplicate" {
    const allocator = testing.allocator;

    var set = std.AutoHashMap(i32, void).init(allocator);
    defer set.deinit();

    try set.put(1, {});
    try set.put(1, {}); // Duplicate
    try set.put(1, {}); // Duplicate

    try testing.expectEqual(@as(usize, 1), set.count());
}

// ==============================================================================
// Union Operation (A ∪ B)
// ==============================================================================

// ANCHOR: set_operations
fn unionSets(
    allocator: std.mem.Allocator,
    set1: std.AutoHashMap(i32, void),
    set2: std.AutoHashMap(i32, void),
) !std.AutoHashMap(i32, void) {
    var result = std.AutoHashMap(i32, void).init(allocator);
    errdefer result.deinit();

    // Add all elements from set1
    var it1 = set1.keyIterator();
    while (it1.next()) |key| {
        try result.put(key.*, {});
    }

    // Add all elements from set2
    var it2 = set2.keyIterator();
    while (it2.next()) |key| {
        try result.put(key.*, {});
    }

    return result;
}
// ANCHOR_END: set_operations

test "union of two sets" {
    const allocator = testing.allocator;

    var set1 = std.AutoHashMap(i32, void).init(allocator);
    defer set1.deinit();
    var set2 = std.AutoHashMap(i32, void).init(allocator);
    defer set2.deinit();

    try set1.put(1, {});
    try set1.put(2, {});
    try set1.put(3, {});

    try set2.put(3, {});
    try set2.put(4, {});
    try set2.put(5, {});

    var result = try unionSets(allocator, set1, set2);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 5), result.count());
    try testing.expect(result.contains(1));
    try testing.expect(result.contains(2));
    try testing.expect(result.contains(3));
    try testing.expect(result.contains(4));
    try testing.expect(result.contains(5));
}

// ==============================================================================
// Intersection Operation (A ∩ B)
// ==============================================================================

fn intersectionSets(
    allocator: std.mem.Allocator,
    set1: std.AutoHashMap(i32, void),
    set2: std.AutoHashMap(i32, void),
) !std.AutoHashMap(i32, void) {
    var result = std.AutoHashMap(i32, void).init(allocator);
    errdefer result.deinit();

    // Add elements that exist in both sets
    var it = set1.keyIterator();
    while (it.next()) |key| {
        if (set2.contains(key.*)) {
            try result.put(key.*, {});
        }
    }

    return result;
}

test "intersection of two sets" {
    const allocator = testing.allocator;

    var set1 = std.AutoHashMap(i32, void).init(allocator);
    defer set1.deinit();
    var set2 = std.AutoHashMap(i32, void).init(allocator);
    defer set2.deinit();

    try set1.put(1, {});
    try set1.put(2, {});
    try set1.put(3, {});

    try set2.put(2, {});
    try set2.put(3, {});
    try set2.put(4, {});

    var result = try intersectionSets(allocator, set1, set2);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.count());
    try testing.expect(result.contains(2));
    try testing.expect(result.contains(3));
    try testing.expect(!result.contains(1));
    try testing.expect(!result.contains(4));
}

test "intersection with no common elements" {
    const allocator = testing.allocator;

    var set1 = std.AutoHashMap(i32, void).init(allocator);
    defer set1.deinit();
    var set2 = std.AutoHashMap(i32, void).init(allocator);
    defer set2.deinit();

    try set1.put(1, {});
    try set1.put(2, {});

    try set2.put(3, {});
    try set2.put(4, {});

    var result = try intersectionSets(allocator, set1, set2);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 0), result.count());
}

// ==============================================================================
// Difference Operation (A - B)
// ==============================================================================

fn differenceSets(
    allocator: std.mem.Allocator,
    set1: std.AutoHashMap(i32, void),
    set2: std.AutoHashMap(i32, void),
) !std.AutoHashMap(i32, void) {
    var result = std.AutoHashMap(i32, void).init(allocator);
    errdefer result.deinit();

    // Add elements from set1 that aren't in set2
    var it = set1.keyIterator();
    while (it.next()) |key| {
        if (!set2.contains(key.*)) {
            try result.put(key.*, {});
        }
    }

    return result;
}

test "difference of two sets" {
    const allocator = testing.allocator;

    var set1 = std.AutoHashMap(i32, void).init(allocator);
    defer set1.deinit();
    var set2 = std.AutoHashMap(i32, void).init(allocator);
    defer set2.deinit();

    try set1.put(1, {});
    try set1.put(2, {});
    try set1.put(3, {});

    try set2.put(2, {});
    try set2.put(4, {});

    var result = try differenceSets(allocator, set1, set2);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.count());
    try testing.expect(result.contains(1));
    try testing.expect(result.contains(3));
    try testing.expect(!result.contains(2));
}

// ==============================================================================
// Symmetric Difference (A △ B)
// ==============================================================================

fn symmetricDifference(
    allocator: std.mem.Allocator,
    set1: std.AutoHashMap(i32, void),
    set2: std.AutoHashMap(i32, void),
) !std.AutoHashMap(i32, void) {
    var result = std.AutoHashMap(i32, void).init(allocator);
    errdefer result.deinit();

    // Add elements from set1 not in set2
    var it1 = set1.keyIterator();
    while (it1.next()) |key| {
        if (!set2.contains(key.*)) {
            try result.put(key.*, {});
        }
    }

    // Add elements from set2 not in set1
    var it2 = set2.keyIterator();
    while (it2.next()) |key| {
        if (!set1.contains(key.*)) {
            try result.put(key.*, {});
        }
    }

    return result;
}

test "symmetric difference of two sets" {
    const allocator = testing.allocator;

    var set1 = std.AutoHashMap(i32, void).init(allocator);
    defer set1.deinit();
    var set2 = std.AutoHashMap(i32, void).init(allocator);
    defer set2.deinit();

    try set1.put(1, {});
    try set1.put(2, {});
    try set1.put(3, {});

    try set2.put(2, {});
    try set2.put(3, {});
    try set2.put(4, {});

    var result = try symmetricDifference(allocator, set1, set2);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.count());
    try testing.expect(result.contains(1)); // Only in set1
    try testing.expect(result.contains(4)); // Only in set2
    try testing.expect(!result.contains(2)); // In both
    try testing.expect(!result.contains(3)); // In both
}

// ==============================================================================
// Subset and Superset Checks
// ==============================================================================

fn isSubset(
    set1: std.AutoHashMap(i32, void),
    set2: std.AutoHashMap(i32, void),
) bool {
    var it = set1.keyIterator();
    while (it.next()) |key| {
        if (!set2.contains(key.*)) {
            return false;
        }
    }
    return true;
}

fn isSuperset(
    set1: std.AutoHashMap(i32, void),
    set2: std.AutoHashMap(i32, void),
) bool {
    return isSubset(set2, set1);
}

test "subset checks" {
    const allocator = testing.allocator;

    var set1 = std.AutoHashMap(i32, void).init(allocator);
    defer set1.deinit();
    var set2 = std.AutoHashMap(i32, void).init(allocator);
    defer set2.deinit();

    try set1.put(1, {});
    try set1.put(2, {});

    try set2.put(1, {});
    try set2.put(2, {});
    try set2.put(3, {});

    // set1 is a subset of set2
    try testing.expect(isSubset(set1, set2));
    try testing.expect(!isSubset(set2, set1));
}

test "superset checks" {
    const allocator = testing.allocator;

    var set1 = std.AutoHashMap(i32, void).init(allocator);
    defer set1.deinit();
    var set2 = std.AutoHashMap(i32, void).init(allocator);
    defer set2.deinit();

    try set1.put(1, {});
    try set1.put(2, {});
    try set1.put(3, {});

    try set2.put(1, {});
    try set2.put(2, {});

    // set1 is a superset of set2
    try testing.expect(isSuperset(set1, set2));
    try testing.expect(!isSuperset(set2, set1));
}

// ==============================================================================
// Disjoint Check
// ==============================================================================

fn isDisjoint(
    set1: std.AutoHashMap(i32, void),
    set2: std.AutoHashMap(i32, void),
) bool {
    var it = set1.keyIterator();
    while (it.next()) |key| {
        if (set2.contains(key.*)) {
            return false;
        }
    }
    return true;
}

test "disjoint sets" {
    const allocator = testing.allocator;

    var set1 = std.AutoHashMap(i32, void).init(allocator);
    defer set1.deinit();
    var set2 = std.AutoHashMap(i32, void).init(allocator);
    defer set2.deinit();

    try set1.put(1, {});
    try set1.put(2, {});

    try set2.put(3, {});
    try set2.put(4, {});

    try testing.expect(isDisjoint(set1, set2));
}

test "non-disjoint sets" {
    const allocator = testing.allocator;

    var set1 = std.AutoHashMap(i32, void).init(allocator);
    defer set1.deinit();
    var set2 = std.AutoHashMap(i32, void).init(allocator);
    defer set2.deinit();

    try set1.put(1, {});
    try set1.put(2, {});

    try set2.put(2, {});
    try set2.put(3, {});

    try testing.expect(!isDisjoint(set1, set2));
}

// ==============================================================================
// Building Sets from Slices
// ==============================================================================

fn fromSlice(
    allocator: std.mem.Allocator,
    items: []const i32,
) !std.AutoHashMap(i32, void) {
    var set = std.AutoHashMap(i32, void).init(allocator);
    errdefer set.deinit();

    for (items) |item| {
        try set.put(item, {});
    }

    return set;
}

test "create set from slice" {
    const allocator = testing.allocator;

    const numbers = [_]i32{ 1, 2, 3, 2, 1 }; // Has duplicates
    var set = try fromSlice(allocator, &numbers);
    defer set.deinit();

    try testing.expectEqual(@as(usize, 3), set.count());
    try testing.expect(set.contains(1));
    try testing.expect(set.contains(2));
    try testing.expect(set.contains(3));
}

// ==============================================================================
// Converting Sets to Slices
// ==============================================================================

fn toSlice(
    allocator: std.mem.Allocator,
    set: std.AutoHashMap(i32, void),
) ![]i32 {
    var result = try allocator.alloc(i32, set.count());
    errdefer allocator.free(result);

    var i: usize = 0;
    var it = set.keyIterator();
    while (it.next()) |key| : (i += 1) {
        result[i] = key.*;
    }

    return result;
}

test "convert set to slice" {
    const allocator = testing.allocator;

    var set = std.AutoHashMap(i32, void).init(allocator);
    defer set.deinit();

    try set.put(10, {});
    try set.put(20, {});
    try set.put(30, {});

    const slice = try toSlice(allocator, set);
    defer allocator.free(slice);

    try testing.expectEqual(@as(usize, 3), slice.len);

    // Sort for consistent testing (hash map order is unpredictable)
    std.mem.sort(i32, slice, {}, comptime std.sort.asc(i32));
    try testing.expectEqual(@as(i32, 10), slice[0]);
    try testing.expectEqual(@as(i32, 20), slice[1]);
    try testing.expectEqual(@as(i32, 30), slice[2]);
}

// ==============================================================================
// Practical Example: Finding Common Words
// ==============================================================================

// ANCHOR: common_words
fn findCommonWords(
    allocator: std.mem.Allocator,
    text1: []const []const u8,
    text2: []const []const u8,
) !std.StringHashMap(void) {
    // Build set from first text
    var words1 = std.StringHashMap(void).init(allocator);
    defer words1.deinit();

    for (text1) |word| {
        try words1.put(word, {});
    }

    // Find intersection
    var common = std.StringHashMap(void).init(allocator);
    errdefer common.deinit();

    for (text2) |word| {
        if (words1.contains(word)) {
            try common.put(word, {});
        }
    }

    return common;
}
// ANCHOR_END: common_words

test "find common words between texts" {
    const allocator = testing.allocator;

    const text1 = [_][]const u8{ "the", "quick", "brown", "fox" };
    const text2 = [_][]const u8{ "the", "lazy", "brown", "dog" };

    var common = try findCommonWords(allocator, &text1, &text2);
    defer common.deinit();

    try testing.expectEqual(@as(usize, 2), common.count());
    try testing.expect(common.contains("the"));
    try testing.expect(common.contains("brown"));
    try testing.expect(!common.contains("fox"));
    try testing.expect(!common.contains("dog"));
}

// ==============================================================================
// Common Patterns
// ==============================================================================

fn areEqual(set1: std.AutoHashMap(i32, void), set2: std.AutoHashMap(i32, void)) bool {
    if (set1.count() != set2.count()) return false;
    return isSubset(set1, set2);
}

fn countCommon(set1: std.AutoHashMap(i32, void), set2: std.AutoHashMap(i32, void)) usize {
    var count: usize = 0;
    var it = set1.keyIterator();
    while (it.next()) |key| {
        if (set2.contains(key.*)) count += 1;
    }
    return count;
}

fn removeAll(set: *std.AutoHashMap(i32, void), to_remove: std.AutoHashMap(i32, void)) void {
    var it = to_remove.keyIterator();
    while (it.next()) |key| {
        _ = set.remove(key.*);
    }
}

test "check if sets are equal" {
    const allocator = testing.allocator;

    var set1 = std.AutoHashMap(i32, void).init(allocator);
    defer set1.deinit();
    var set2 = std.AutoHashMap(i32, void).init(allocator);
    defer set2.deinit();

    try set1.put(1, {});
    try set1.put(2, {});

    try set2.put(2, {});
    try set2.put(1, {});

    try testing.expect(areEqual(set1, set2));

    try set2.put(3, {});
    try testing.expect(!areEqual(set1, set2));
}

test "count common elements" {
    const allocator = testing.allocator;

    var set1 = std.AutoHashMap(i32, void).init(allocator);
    defer set1.deinit();
    var set2 = std.AutoHashMap(i32, void).init(allocator);
    defer set2.deinit();

    try set1.put(1, {});
    try set1.put(2, {});
    try set1.put(3, {});

    try set2.put(2, {});
    try set2.put(3, {});
    try set2.put(4, {});

    try testing.expectEqual(@as(usize, 2), countCommon(set1, set2));
}

test "remove elements in-place" {
    const allocator = testing.allocator;

    var set = std.AutoHashMap(i32, void).init(allocator);
    defer set.deinit();
    var to_remove = std.AutoHashMap(i32, void).init(allocator);
    defer to_remove.deinit();

    try set.put(1, {});
    try set.put(2, {});
    try set.put(3, {});

    try to_remove.put(2, {});
    try to_remove.put(3, {});

    removeAll(&set, to_remove);

    try testing.expectEqual(@as(usize, 1), set.count());
    try testing.expect(set.contains(1));
    try testing.expect(!set.contains(2));
    try testing.expect(!set.contains(3));
}
