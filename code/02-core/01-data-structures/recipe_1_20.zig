// Recipe 1.20: Combining multiple mappings into a single mapping
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to merge multiple hashmaps into one,
// handling key conflicts and preserving data from multiple sources.

const std = @import("std");
const testing = std.testing;

/// Merge two hashmaps, with values from the second map overwriting the first on conflict
// ANCHOR: merge_overwrite
pub fn mergeOverwrite(
    comptime K: type,
    comptime V: type,
    allocator: std.mem.Allocator,
    map1: std.AutoHashMap(K, V),
    map2: std.AutoHashMap(K, V),
) !std.AutoHashMap(K, V) {
    var result = std.AutoHashMap(K, V).init(allocator);
    errdefer result.deinit();

    // Copy all entries from map1
    var iter1 = map1.iterator();
    while (iter1.next()) |entry| {
        try result.put(entry.key_ptr.*, entry.value_ptr.*);
    }

    // Copy all entries from map2, overwriting conflicts
    var iter2 = map2.iterator();
    while (iter2.next()) |entry| {
        try result.put(entry.key_ptr.*, entry.value_ptr.*);
    }

    return result;
}
// ANCHOR_END: merge_overwrite

/// Merge StringHashMaps, second map wins on conflicts
pub fn mergeStringOverwrite(
    comptime V: type,
    allocator: std.mem.Allocator,
    map1: std.StringHashMap(V),
    map2: std.StringHashMap(V),
) !std.StringHashMap(V) {
    var result = std.StringHashMap(V).init(allocator);
    errdefer result.deinit();

    // Copy all entries from map1
    var iter1 = map1.iterator();
    while (iter1.next()) |entry| {
        try result.put(entry.key_ptr.*, entry.value_ptr.*);
    }

    // Copy all entries from map2, overwriting conflicts
    var iter2 = map2.iterator();
    while (iter2.next()) |entry| {
        try result.put(entry.key_ptr.*, entry.value_ptr.*);
    }

    return result;
}

/// Merge maps, keeping only entries present in both (intersection)
pub fn mergeIntersection(
    comptime K: type,
    comptime V: type,
    allocator: std.mem.Allocator,
    map1: std.AutoHashMap(K, V),
    map2: std.AutoHashMap(K, V),
) !std.AutoHashMap(K, V) {
    var result = std.AutoHashMap(K, V).init(allocator);
    errdefer result.deinit();

    var iter1 = map1.iterator();
    while (iter1.next()) |entry| {
        // Only add if key exists in both maps
        if (map2.contains(entry.key_ptr.*)) {
            try result.put(entry.key_ptr.*, entry.value_ptr.*);
        }
    }

    return result;
}

/// Merge maps with custom conflict resolution function
// ANCHOR: merge_with_resolver
pub fn mergeWith(
    comptime K: type,
    comptime V: type,
    allocator: std.mem.Allocator,
    map1: std.AutoHashMap(K, V),
    map2: std.AutoHashMap(K, V),
    resolveFn: *const fn (V, V) V,
) !std.AutoHashMap(K, V) {
    var result = std.AutoHashMap(K, V).init(allocator);
    errdefer result.deinit();

    // Copy all entries from map1
    var iter1 = map1.iterator();
    while (iter1.next()) |entry| {
        try result.put(entry.key_ptr.*, entry.value_ptr.*);
    }

    // Merge entries from map2 with conflict resolution
    var iter2 = map2.iterator();
    while (iter2.next()) |entry| {
        if (result.get(entry.key_ptr.*)) |existing| {
            const resolved = resolveFn(existing, entry.value_ptr.*);
            try result.put(entry.key_ptr.*, resolved);
        } else {
            try result.put(entry.key_ptr.*, entry.value_ptr.*);
        }
    }

    return result;
}
// ANCHOR_END: merge_with_resolver

/// Merge multiple maps (variadic-like using slice)
// ANCHOR: merge_many
pub fn mergeMany(
    comptime K: type,
    comptime V: type,
    allocator: std.mem.Allocator,
    maps: []const std.AutoHashMap(K, V),
) !std.AutoHashMap(K, V) {
    var result = std.AutoHashMap(K, V).init(allocator);
    errdefer result.deinit();

    for (maps) |map| {
        var iter = map.iterator();
        while (iter.next()) |entry| {
            try result.put(entry.key_ptr.*, entry.value_ptr.*);
        }
    }

    return result;
}
// ANCHOR_END: merge_many

/// Chain iterator - iterate over multiple maps sequentially
pub fn ChainedIterator(comptime K: type, comptime V: type) type {
    return struct {
        maps: []const std.AutoHashMap(K, V),
        current_map: usize = 0,
        current_iter: ?std.AutoHashMap(K, V).Iterator = null,

        const Self = @This();

        pub fn init(maps: []const std.AutoHashMap(K, V)) Self {
            var self = Self{ .maps = maps };
            if (maps.len > 0) {
                self.current_iter = maps[0].iterator();
            }
            return self;
        }

        pub fn next(self: *Self) ?struct { key: K, value: V } {
            while (self.current_map < self.maps.len) {
                if (self.current_iter) |*iter| {
                    if (iter.next()) |entry| {
                        return .{
                            .key = entry.key_ptr.*,
                            .value = entry.value_ptr.*,
                        };
                    }
                }

                // Move to next map
                self.current_map += 1;
                if (self.current_map < self.maps.len) {
                    self.current_iter = self.maps[self.current_map].iterator();
                }
            }

            return null;
        }
    };
}

test "merge with overwrite - last wins" {
    var map1 = std.AutoHashMap(u32, i32).init(testing.allocator);
    defer map1.deinit();
    var map2 = std.AutoHashMap(u32, i32).init(testing.allocator);
    defer map2.deinit();

    try map1.put(1, 10);
    try map1.put(2, 20);
    try map1.put(3, 30);

    try map2.put(2, 200); // Conflicts with map1
    try map2.put(3, 300); // Conflicts with map1
    try map2.put(4, 40);

    var result = try mergeOverwrite(u32, i32, testing.allocator, map1, map2);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 4), result.count());
    try testing.expectEqual(@as(i32, 10), result.get(1).?);
    try testing.expectEqual(@as(i32, 200), result.get(2).?); // map2 wins
    try testing.expectEqual(@as(i32, 300), result.get(3).?); // map2 wins
    try testing.expectEqual(@as(i32, 40), result.get(4).?);
}

test "merge string maps" {
    var map1 = std.StringHashMap(f32).init(testing.allocator);
    defer map1.deinit();
    var map2 = std.StringHashMap(f32).init(testing.allocator);
    defer map2.deinit();

    try map1.put("apple", 1.50);
    try map1.put("banana", 0.75);

    try map2.put("banana", 0.80); // Price update
    try map2.put("orange", 1.25);

    var result = try mergeStringOverwrite(f32, testing.allocator, map1, map2);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 3), result.count());
    try testing.expectEqual(@as(f32, 1.50), result.get("apple").?);
    try testing.expectEqual(@as(f32, 0.80), result.get("banana").?); // Updated price
    try testing.expectEqual(@as(f32, 1.25), result.get("orange").?);
}

test "merge intersection - only common keys" {
    var map1 = std.AutoHashMap(u32, i32).init(testing.allocator);
    defer map1.deinit();
    var map2 = std.AutoHashMap(u32, i32).init(testing.allocator);
    defer map2.deinit();

    try map1.put(1, 10);
    try map1.put(2, 20);
    try map1.put(3, 30);

    try map2.put(2, 200);
    try map2.put(3, 300);
    try map2.put(4, 40);

    var result = try mergeIntersection(u32, i32, testing.allocator, map1, map2);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 2), result.count());
    try testing.expectEqual(@as(i32, 20), result.get(2).?); // From map1
    try testing.expectEqual(@as(i32, 30), result.get(3).?); // From map1
    try testing.expect(result.get(1) == null);
    try testing.expect(result.get(4) == null);
}

test "merge with custom conflict resolution" {
    var map1 = std.AutoHashMap(u32, i32).init(testing.allocator);
    defer map1.deinit();
    var map2 = std.AutoHashMap(u32, i32).init(testing.allocator);
    defer map2.deinit();

    try map1.put(1, 10);
    try map1.put(2, 20);
    try map1.put(3, 30);

    try map2.put(2, 5);
    try map2.put(3, 7);
    try map2.put(4, 40);

    // Conflict resolution: sum the values
    const sumValues = struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f;

    var result = try mergeWith(u32, i32, testing.allocator, map1, map2, sumValues);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 4), result.count());
    try testing.expectEqual(@as(i32, 10), result.get(1).?);
    try testing.expectEqual(@as(i32, 25), result.get(2).?); // 20 + 5
    try testing.expectEqual(@as(i32, 37), result.get(3).?); // 30 + 7
    try testing.expectEqual(@as(i32, 40), result.get(4).?);
}

test "merge with max value conflict resolution" {
    var inventory1 = std.StringHashMap(i32).init(testing.allocator);
    defer inventory1.deinit();
    var inventory2 = std.StringHashMap(i32).init(testing.allocator);
    defer inventory2.deinit();

    try inventory1.put("apples", 50);
    try inventory1.put("bananas", 30);

    try inventory2.put("bananas", 40);
    try inventory2.put("oranges", 25);

    const maxValue = struct {
        fn f(a: i32, b: i32) i32 {
            return @max(a, b);
        }
    }.f;

    var map1_auto = std.AutoHashMap(u64, i32).init(testing.allocator);
    defer map1_auto.deinit();
    var map2_auto = std.AutoHashMap(u64, i32).init(testing.allocator);
    defer map2_auto.deinit();

    // Convert string keys to hashes for testing
    const hash1 = std.hash.Wyhash.hash(0, "apples");
    const hash2 = std.hash.Wyhash.hash(0, "bananas");
    const hash3 = std.hash.Wyhash.hash(0, "oranges");

    try map1_auto.put(hash1, 50);
    try map1_auto.put(hash2, 30);
    try map2_auto.put(hash2, 40);
    try map2_auto.put(hash3, 25);

    var result = try mergeWith(u64, i32, testing.allocator, map1_auto, map2_auto, maxValue);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 3), result.count());
    try testing.expectEqual(@as(i32, 50), result.get(hash1).?);
    try testing.expectEqual(@as(i32, 40), result.get(hash2).?); // max(30, 40)
    try testing.expectEqual(@as(i32, 25), result.get(hash3).?);
}

test "merge many maps at once" {
    var map1 = std.AutoHashMap(u32, i32).init(testing.allocator);
    defer map1.deinit();
    var map2 = std.AutoHashMap(u32, i32).init(testing.allocator);
    defer map2.deinit();
    var map3 = std.AutoHashMap(u32, i32).init(testing.allocator);
    defer map3.deinit();

    try map1.put(1, 10);
    try map2.put(2, 20);
    try map3.put(3, 30);

    const maps = [_]std.AutoHashMap(u32, i32){ map1, map2, map3 };
    var result = try mergeMany(u32, i32, testing.allocator, &maps);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 3), result.count());
    try testing.expectEqual(@as(i32, 10), result.get(1).?);
    try testing.expectEqual(@as(i32, 20), result.get(2).?);
    try testing.expectEqual(@as(i32, 30), result.get(3).?);
}

test "merge empty maps" {
    var map1 = std.AutoHashMap(u32, i32).init(testing.allocator);
    defer map1.deinit();
    var map2 = std.AutoHashMap(u32, i32).init(testing.allocator);
    defer map2.deinit();

    var result = try mergeOverwrite(u32, i32, testing.allocator, map1, map2);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 0), result.count());
}

test "chained iterator over multiple maps" {
    var map1 = std.AutoHashMap(u32, i32).init(testing.allocator);
    defer map1.deinit();
    var map2 = std.AutoHashMap(u32, i32).init(testing.allocator);
    defer map2.deinit();
    var map3 = std.AutoHashMap(u32, i32).init(testing.allocator);
    defer map3.deinit();

    try map1.put(1, 10);
    try map1.put(2, 20);
    try map2.put(3, 30);
    try map3.put(4, 40);
    try map3.put(5, 50);

    const maps = [_]std.AutoHashMap(u32, i32){ map1, map2, map3 };
    var iter = ChainedIterator(u32, i32).init(&maps);

    var count: usize = 0;
    var sum: i32 = 0;

    while (iter.next()) |entry| {
        count += 1;
        sum += entry.value;
    }

    try testing.expectEqual(@as(usize, 5), count);
    try testing.expectEqual(@as(i32, 150), sum); // 10+20+30+40+50
}

test "merge with struct values" {
    const Item = struct {
        quantity: i32,
        price: f32,
    };

    var warehouse1 = std.AutoHashMap(u32, Item).init(testing.allocator);
    defer warehouse1.deinit();
    var warehouse2 = std.AutoHashMap(u32, Item).init(testing.allocator);
    defer warehouse2.deinit();

    try warehouse1.put(1, .{ .quantity = 10, .price = 5.0 });
    try warehouse1.put(2, .{ .quantity = 20, .price = 3.0 });

    try warehouse2.put(2, .{ .quantity = 5, .price = 3.0 });
    try warehouse2.put(3, .{ .quantity = 15, .price = 7.0 });

    // Merge by summing quantities
    const sumQuantities = struct {
        fn f(a: Item, b: Item) Item {
            return .{
                .quantity = a.quantity + b.quantity,
                .price = a.price, // Keep first price
            };
        }
    }.f;

    var result = try mergeWith(u32, Item, testing.allocator, warehouse1, warehouse2, sumQuantities);
    defer result.deinit();

    try testing.expectEqual(@as(usize, 3), result.count());
    try testing.expectEqual(@as(i32, 10), result.get(1).?.quantity);
    try testing.expectEqual(@as(i32, 25), result.get(2).?.quantity); // 20 + 5
    try testing.expectEqual(@as(i32, 15), result.get(3).?.quantity);
}

test "memory safety - no leaks on error" {
    // Using testing.allocator automatically checks for leaks
    var map1 = std.AutoHashMap(u32, i32).init(testing.allocator);
    defer map1.deinit();
    var map2 = std.AutoHashMap(u32, i32).init(testing.allocator);
    defer map2.deinit();

    try map1.put(1, 10);
    try map2.put(2, 20);

    var result = try mergeOverwrite(u32, i32, testing.allocator, map1, map2);
    defer result.deinit();

    try testing.expect(result.count() > 0);
}
