// Recipe 1.6: Mapping Keys to Multiple Values
// Target Zig Version: 0.15.2
//
// Demonstrates how to create multimap structures where keys have multiple values.
// Run: zig test code/02-core/01-data-structures/recipe_1_6.zig

const std = @import("std");
const testing = std.testing;

// ==============================================================================
// Generic MultiMap Implementation
// ==============================================================================

// ANCHOR: multimap_impl
fn MultiMap(comptime K: type, comptime V: type) type {
    return struct {
        map: std.AutoHashMap(K, std.ArrayList(V)),
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .map = std.AutoHashMap(K, std.ArrayList(V)).init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            var it = self.map.valueIterator();
            while (it.next()) |list| {
                list.deinit(self.allocator);
            }
            self.map.deinit();
        }

        pub fn add(self: *Self, key: K, value: V) !void {
            const entry = try self.map.getOrPut(key);
            if (!entry.found_existing) {
                entry.value_ptr.* = std.ArrayList(V){};
            }
            try entry.value_ptr.append(self.allocator, value);
        }

        pub fn get(self: *Self, key: K) ?[]const V {
            if (self.map.get(key)) |list| {
                return list.items;
            }
            return null;
        }

        pub fn count(self: *Self, key: K) usize {
            if (self.map.get(key)) |list| {
                return list.items.len;
            }
            return 0;
        }

        /// Remove a specific value from a key's list (fast, breaks order).
        /// Uses swapRemove: O(1) removal after O(n) search.
        /// The removed item is replaced with the last item in the list.
        /// Use this when insertion order doesn't matter.
        pub fn remove(self: *Self, key: K, value: V) bool {
            if (self.map.getPtr(key)) |list| {
                for (list.items, 0..) |item, i| {
                    if (item == value) {
                        _ = list.swapRemove(i);
                        return true;
                    }
                }
            }
            return false;
        }

        /// Remove a specific value from a key's list (preserves order).
        /// Uses orderedRemove: O(n) search + O(n) shift.
        /// All items after the removed item are shifted left.
        /// Use this when insertion order matters (FIFO queues, chronological lists, etc).
        pub fn removeOrdered(self: *Self, key: K, value: V) bool {
            if (self.map.getPtr(key)) |list| {
                for (list.items, 0..) |item, i| {
                    if (item == value) {
                        _ = list.orderedRemove(i);
                        return true;
                    }
                }
            }
            return false;
        }

        pub fn removeKey(self: *Self, key: K) void {
            if (self.map.fetchRemove(key)) |entry| {
                var list = entry.value;
                list.deinit(self.allocator);
            }
        }
    };
}
// ANCHOR_END: multimap_impl

// ANCHOR: basic_usage
test "MultiMap - basic operations" {
    const allocator = testing.allocator;
    var multimap = MultiMap(i32, []const u8).init(allocator);
    defer multimap.deinit();

    // Add values to same key
    try multimap.add(1, "apple");
    try multimap.add(1, "apricot");
    try multimap.add(2, "banana");

    // Get values
    const fruits1 = multimap.get(1).?;
    try testing.expectEqual(@as(usize, 2), fruits1.len);
    try testing.expectEqualStrings("apple", fruits1[0]);
    try testing.expectEqualStrings("apricot", fruits1[1]);

    const fruits2 = multimap.get(2).?;
    try testing.expectEqual(@as(usize, 1), fruits2.len);
    try testing.expectEqualStrings("banana", fruits2[0]);

    // Non-existent key
    try testing.expectEqual(@as(?[]const []const u8, null), multimap.get(3));
}
// ANCHOR_END: basic_usage

test "MultiMap - count values" {
    const allocator = testing.allocator;
    var multimap = MultiMap(u32, i32).init(allocator);
    defer multimap.deinit();

    try multimap.add(1, 95);
    try multimap.add(1, 87);
    try multimap.add(1, 92);

    try testing.expectEqual(@as(usize, 3), multimap.count(1));
    try testing.expectEqual(@as(usize, 0), multimap.count(999));
}

test "MultiMap - remove vs removeOrdered behavior" {
    const allocator = testing.allocator;
    var map1 = MultiMap(i32, i32).init(allocator);
    defer map1.deinit();
    var map2 = MultiMap(i32, i32).init(allocator);
    defer map2.deinit();

    // Setup identical lists
    try map1.add(1, 10);
    try map1.add(1, 20);
    try map1.add(1, 30);
    try map1.add(1, 40);

    try map2.add(1, 10);
    try map2.add(1, 20);
    try map2.add(1, 30);
    try map2.add(1, 40);

    // Remove middle value with swapRemove (breaks order)
    try testing.expect(map1.remove(1, 20));
    const values1 = map1.get(1).?;
    try testing.expectEqual(@as(usize, 3), values1.len);
    try testing.expectEqual(@as(i32, 10), values1[0]);
    try testing.expectEqual(@as(i32, 40), values1[1]); // Last item swapped here
    try testing.expectEqual(@as(i32, 30), values1[2]);

    // Remove middle value with orderedRemove (preserves order)
    try testing.expect(map2.removeOrdered(1, 20));
    const values2 = map2.get(1).?;
    try testing.expectEqual(@as(usize, 3), values2.len);
    try testing.expectEqual(@as(i32, 10), values2[0]);
    try testing.expectEqual(@as(i32, 30), values2[1]); // Order preserved
    try testing.expectEqual(@as(i32, 40), values2[2]);
}

test "MultiMap - remove specific value" {
    const allocator = testing.allocator;
    var multimap = MultiMap(i32, i32).init(allocator);
    defer multimap.deinit();

    try multimap.add(1, 10);
    try multimap.add(1, 20);
    try multimap.add(1, 30);

    // Remove middle value
    try testing.expect(multimap.remove(1, 20));
    const values = multimap.get(1).?;
    try testing.expectEqual(@as(usize, 2), values.len);

    // Try to remove non-existent value
    try testing.expect(!multimap.remove(1, 999));
}

test "MultiMap - removeOrdered non-existent value" {
    const allocator = testing.allocator;
    var multimap = MultiMap(i32, i32).init(allocator);
    defer multimap.deinit();

    try multimap.add(1, 10);
    try multimap.add(1, 20);

    // Try to remove non-existent value
    try testing.expect(!multimap.removeOrdered(1, 999));
    try testing.expect(!multimap.removeOrdered(2, 10));
}

test "MultiMap - remove entire key" {
    const allocator = testing.allocator;
    var multimap = MultiMap(i32, i32).init(allocator);
    defer multimap.deinit();

    try multimap.add(1, 10);
    try multimap.add(1, 20);
    try testing.expectEqual(@as(usize, 2), multimap.count(1));

    multimap.removeKey(1);
    try testing.expectEqual(@as(usize, 0), multimap.count(1));
    try testing.expectEqual(@as(?[]const i32, null), multimap.get(1));
}

// ==============================================================================
// String-Based MultiMap (Tags Example)
// ==============================================================================

const Tags = struct {
    tags: std.StringArrayHashMap(std.ArrayList([]const u8)),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Tags {
        return .{
            .tags = std.StringArrayHashMap(std.ArrayList([]const u8)).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn addTag(self: *Tags, tag: []const u8, item: []const u8) !void {
        const entry = try self.tags.getOrPut(tag);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList([]const u8){};
        }
        try entry.value_ptr.append(self.allocator, item);
    }

    pub fn getItems(self: *Tags, tag: []const u8) ?[]const []const u8 {
        if (self.tags.get(tag)) |list| {
            return list.items;
        }
        return null;
    }

    pub fn countTags(self: *Tags) usize {
        return self.tags.count();
    }

    pub fn deinit(self: *Tags) void {
        var it = self.tags.iterator();
        while (it.next()) |entry| {
            var list = entry.value_ptr.*;
            list.deinit(self.allocator);
        }
        self.tags.deinit();
    }
};

test "Tags - string-based multimap" {
    const allocator = testing.allocator;
    var tags = Tags.init(allocator);
    defer tags.deinit();

    try tags.addTag("color", "red");
    try tags.addTag("color", "blue");
    try tags.addTag("size", "large");

    const color_items = tags.getItems("color").?;
    try testing.expectEqual(@as(usize, 2), color_items.len);
    try testing.expectEqualStrings("red", color_items[0]);
    try testing.expectEqualStrings("blue", color_items[1]);

    const size_items = tags.getItems("size").?;
    try testing.expectEqual(@as(usize, 1), size_items.len);
    try testing.expectEqualStrings("large", size_items[0]);

    try testing.expectEqual(@as(usize, 2), tags.countTags());
}

// ==============================================================================
// Practical Example: Category System
// ==============================================================================

// ANCHOR: category_system
const CategorySystem = struct {
    categories: std.StringArrayHashMap(std.ArrayList(Product)),
    allocator: std.mem.Allocator,

    const Product = struct {
        name: []const u8,
        price: f32,
    };

    pub fn init(allocator: std.mem.Allocator) CategorySystem {
        return .{
            .categories = std.StringArrayHashMap(std.ArrayList(Product)).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn addProduct(self: *CategorySystem, category: []const u8, product: Product) !void {
        const entry = try self.categories.getOrPut(category);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(Product){};
        }
        try entry.value_ptr.append(self.allocator, product);
    }

    pub fn getProducts(self: *CategorySystem, category: []const u8) ?[]const Product {
        if (self.categories.get(category)) |list| {
            return list.items;
        }
        return null;
    }

    pub fn deinit(self: *CategorySystem) void {
        var it = self.categories.iterator();
        while (it.next()) |entry| {
            var list = entry.value_ptr.*;
            list.deinit(self.allocator);
        }
        self.categories.deinit();
    }
};
// ANCHOR_END: category_system

test "CategorySystem - organize products by category" {
    const allocator = testing.allocator;
    var system = CategorySystem.init(allocator);
    defer system.deinit();

    try system.addProduct("electronics", .{ .name = "Phone", .price = 699.99 });
    try system.addProduct("electronics", .{ .name = "Laptop", .price = 1299.99 });
    try system.addProduct("books", .{ .name = "Zig Guide", .price = 39.99 });

    const electronics = system.getProducts("electronics").?;
    try testing.expectEqual(@as(usize, 2), electronics.len);
    try testing.expectEqualStrings("Phone", electronics[0].name);
    try testing.expectEqual(@as(f32, 699.99), electronics[0].price);

    const books = system.getProducts("books").?;
    try testing.expectEqual(@as(usize, 1), books.len);
    try testing.expectEqualStrings("Zig Guide", books[0].name);
}

// ==============================================================================
// Alternative: Array of Tuples (Simpler for Small Data)
// ==============================================================================

const SimpleTupleMap = struct {
    entries: std.ArrayList(Entry),
    allocator: std.mem.Allocator,

    const Entry = struct {
        key: []const u8,
        value: i32,
    };

    pub fn init(allocator: std.mem.Allocator) SimpleTupleMap {
        return .{
            .entries = std.ArrayList(Entry){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SimpleTupleMap) void {
        self.entries.deinit(self.allocator);
    }

    pub fn add(self: *SimpleTupleMap, key: []const u8, value: i32) !void {
        try self.entries.append(self.allocator, .{ .key = key, .value = value });
    }

    pub fn getAll(self: *SimpleTupleMap, key: []const u8, results: *std.ArrayList(i32)) !void {
        for (self.entries.items) |entry| {
            if (std.mem.eql(u8, entry.key, key)) {
                try results.append(self.allocator, entry.value);
            }
        }
    }
};

test "SimpleTupleMap - array-based multimap" {
    const allocator = testing.allocator;
    var map = SimpleTupleMap.init(allocator);
    defer map.deinit();

    try map.add("score", 100);
    try map.add("score", 95);
    try map.add("score", 88);
    try map.add("count", 5);

    var scores = std.ArrayList(i32){};
    defer scores.deinit(allocator);
    try map.getAll("score", &scores);

    try testing.expectEqual(@as(usize, 3), scores.items.len);
    try testing.expectEqual(@as(i32, 100), scores.items[0]);
    try testing.expectEqual(@as(i32, 95), scores.items[1]);
    try testing.expectEqual(@as(i32, 88), scores.items[2]);
}

// ==============================================================================
// Iteration Patterns
// ==============================================================================

test "MultiMap - iterate all keys and values" {
    const allocator = testing.allocator;
    var multimap = MultiMap(u32, i32).init(allocator);
    defer multimap.deinit();

    try multimap.add(1, 1);
    try multimap.add(1, 2);
    try multimap.add(2, 3);

    var total: i32 = 0;
    var key_count: usize = 0;

    var it = multimap.map.iterator();
    while (it.next()) |entry| {
        key_count += 1;
        for (entry.value_ptr.items) |value| {
            total += value;
        }
    }

    try testing.expectEqual(@as(i32, 6), total); // 1 + 2 + 3
    try testing.expectEqual(@as(usize, 2), key_count);
}

// ==============================================================================
// Edge Cases
// ==============================================================================

test "MultiMap - empty map operations" {
    const allocator = testing.allocator;
    var multimap = MultiMap(i32, i32).init(allocator);
    defer multimap.deinit();

    try testing.expectEqual(@as(?[]const i32, null), multimap.get(1));
    try testing.expectEqual(@as(usize, 0), multimap.count(1));
    try testing.expect(!multimap.remove(1, 10));
}

test "MultiMap - duplicate values allowed" {
    const allocator = testing.allocator;
    var multimap = MultiMap(i32, i32).init(allocator);
    defer multimap.deinit();

    // Add same value multiple times
    try multimap.add(1, 10);
    try multimap.add(1, 10);
    try multimap.add(1, 10);

    const values = multimap.get(1).?;
    try testing.expectEqual(@as(usize, 3), values.len);
    try testing.expectEqual(@as(i32, 10), values[0]);
    try testing.expectEqual(@as(i32, 10), values[1]);
    try testing.expectEqual(@as(i32, 10), values[2]);
}
