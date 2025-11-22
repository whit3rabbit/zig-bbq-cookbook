// Recipe 1.7: Keeping Dictionaries in Order
// Target Zig Version: 0.15.2
//
// Demonstrates ArrayHashMap for maintaining insertion order in hash maps.
// Run: zig test code/02-core/01-data-structures/recipe_1_7.zig

const std = @import("std");
const testing = std.testing;

// ==============================================================================
// Basic ArrayHashMap Usage
// ==============================================================================

// ANCHOR: basic_ordered_map
test "ArrayHashMap - maintains insertion order" {
    const allocator = testing.allocator;

    var map = std.AutoArrayHashMap(u32, []const u8).init(allocator);
    defer map.deinit();

    try map.put(3, "third");
    try map.put(1, "first");
    try map.put(2, "second");

    // Keys are in insertion order, not sorted
    const keys = map.keys();
    try testing.expectEqual(@as(u32, 3), keys[0]);
    try testing.expectEqual(@as(u32, 1), keys[1]);
    try testing.expectEqual(@as(u32, 2), keys[2]);

    const values = map.values();
    try testing.expectEqualStrings("third", values[0]);
    try testing.expectEqualStrings("first", values[1]);
    try testing.expectEqualStrings("second", values[2]);
}
// ANCHOR_END: basic_ordered_map

test "AutoHashMap - no order guarantees" {
    const allocator = testing.allocator;

    var map = std.AutoHashMap(u32, []const u8).init(allocator);
    defer map.deinit();

    try map.put(3, "third");
    try map.put(1, "first");
    try map.put(2, "second");

    // Can iterate but order is not predictable
    try testing.expectEqual(@as(usize, 3), map.count());

    // Values exist regardless of order
    try testing.expectEqualStrings("first", map.get(1).?);
    try testing.expectEqualStrings("second", map.get(2).?);
    try testing.expectEqualStrings("third", map.get(3).?);
}

// ==============================================================================
// StringArrayHashMap for String Keys
// ==============================================================================

// ANCHOR: string_ordered_map
test "StringArrayHashMap - ordered string keys" {
    const allocator = testing.allocator;

    var config = std.StringArrayHashMap(i32).init(allocator);
    defer config.deinit();

    // Note: String keys are stored as references. String literals are safe
    // because they have static lifetime. For dynamic keys, duplicate them or
    // use an arena allocator. See idiomatic_examples.zig Cache.put() for details.
    try config.put("port", 8080);
    try config.put("timeout", 30);
    try config.put("retries", 3);

    // Check insertion order
    const keys = config.keys();
    try testing.expectEqualStrings("port", keys[0]);
    try testing.expectEqualStrings("timeout", keys[1]);
    try testing.expectEqualStrings("retries", keys[2]);

    // Verify values
    try testing.expectEqual(@as(i32, 8080), config.get("port").?);
    try testing.expectEqual(@as(i32, 30), config.get("timeout").?);
    try testing.expectEqual(@as(i32, 3), config.get("retries").?);
}
// ANCHOR_END: string_ordered_map

// ==============================================================================
// Index-Based Access
// ==============================================================================

test "ArrayHashMap - access by index" {
    const allocator = testing.allocator;

    var map = std.StringArrayHashMap(i32).init(allocator);
    defer map.deinit();

    try map.put("a", 10);
    try map.put("b", 20);
    try map.put("c", 30);

    // Direct index access
    const first_key = map.keys()[0];
    const first_value = map.values()[0];
    try testing.expectEqualStrings("a", first_key);
    try testing.expectEqual(@as(i32, 10), first_value);

    // Last element
    const last_index = map.count() - 1;
    try testing.expectEqualStrings("c", map.keys()[last_index]);
    try testing.expectEqual(@as(i32, 30), map.values()[last_index]);
}

// ==============================================================================
// Common Operations
// ==============================================================================

test "ArrayHashMap - put overwrites existing keys" {
    const allocator = testing.allocator;

    var map = std.AutoArrayHashMap(i32, []const u8).init(allocator);
    defer map.deinit();

    try map.put(1, "first");
    try testing.expectEqual(@as(usize, 1), map.count());

    try map.put(1, "updated");
    try testing.expectEqual(@as(usize, 1), map.count());
    try testing.expectEqualStrings("updated", map.get(1).?);
}

test "ArrayHashMap - contains and get" {
    const allocator = testing.allocator;

    var map = std.AutoArrayHashMap(i32, []const u8).init(allocator);
    defer map.deinit();

    try map.put(42, "answer");

    try testing.expect(map.contains(42));
    try testing.expect(!map.contains(99));

    const value = map.get(42);
    try testing.expect(value != null);
    try testing.expectEqualStrings("answer", value.?);

    const missing = map.get(99);
    try testing.expectEqual(@as(?[]const u8, null), missing);
}

test "ArrayHashMap - remove operations" {
    const allocator = testing.allocator;

    var map = std.AutoArrayHashMap(i32, []const u8).init(allocator);
    defer map.deinit();

    try map.put(1, "one");
    try map.put(2, "two");
    try map.put(3, "three");

    // Remove returns true if key existed
    try testing.expect(map.swapRemove(2));
    try testing.expect(!map.swapRemove(999));

    try testing.expectEqual(@as(usize, 2), map.count());
    try testing.expect(!map.contains(2));
}

test "ArrayHashMap - clear operations" {
    const allocator = testing.allocator;

    var map = std.AutoArrayHashMap(i32, i32).init(allocator);
    defer map.deinit();

    try map.put(1, 100);
    try map.put(2, 200);

    // Clear but keep capacity
    const old_capacity = map.capacity();
    map.clearRetainingCapacity();
    try testing.expectEqual(@as(usize, 0), map.count());
    try testing.expectEqual(old_capacity, map.capacity());

    // Can add again
    try map.put(3, 300);
    try testing.expectEqual(@as(usize, 1), map.count());

    // Clear and free memory
    map.clearAndFree();
    try testing.expectEqual(@as(usize, 0), map.count());
}

// ==============================================================================
// Iteration Patterns
// ==============================================================================

test "ArrayHashMap - iterate keys and values" {
    const allocator = testing.allocator;

    var map = std.AutoArrayHashMap(i32, i32).init(allocator);
    defer map.deinit();

    try map.put(1, 10);
    try map.put(2, 20);
    try map.put(3, 30);

    var key_sum: i32 = 0;
    var value_sum: i32 = 0;

    for (map.keys(), map.values()) |key, value| {
        key_sum += key;
        value_sum += value;
    }

    try testing.expectEqual(@as(i32, 6), key_sum);   // 1 + 2 + 3
    try testing.expectEqual(@as(i32, 60), value_sum); // 10 + 20 + 30
}

test "ArrayHashMap - iterate with index" {
    const allocator = testing.allocator;

    var map = std.StringArrayHashMap(i32).init(allocator);
    defer map.deinit();

    try map.put("a", 1);
    try map.put("b", 2);
    try map.put("c", 3);

    for (map.keys(), 0..) |key, i| {
        const value = map.values()[i];

        if (i == 0) {
            try testing.expectEqualStrings("a", key);
            try testing.expectEqual(@as(i32, 1), value);
        }
    }
}

test "ArrayHashMap - iterator method" {
    const allocator = testing.allocator;

    var map = std.AutoArrayHashMap(i32, i32).init(allocator);
    defer map.deinit();

    try map.put(1, 100);
    try map.put(2, 200);

    var count: usize = 0;
    var it = map.iterator();
    while (it.next()) |entry| {
        count += 1;
        try testing.expect(entry.key_ptr.* * 100 == entry.value_ptr.*);
    }

    try testing.expectEqual(@as(usize, 2), count);
}

// ==============================================================================
// Mutable Iteration
// ==============================================================================

test "ArrayHashMap - modify values during iteration" {
    const allocator = testing.allocator;

    var map = std.AutoArrayHashMap(i32, i32).init(allocator);
    defer map.deinit();

    try map.put(1, 10);
    try map.put(2, 20);
    try map.put(3, 30);

    // Double all values
    for (map.values()) |*value| {
        value.* *= 2;
    }

    try testing.expectEqual(@as(i32, 20), map.get(1).?);
    try testing.expectEqual(@as(i32, 40), map.get(2).?);
    try testing.expectEqual(@as(i32, 60), map.get(3).?);
}

test "ArrayHashMap - modify with iterator" {
    const allocator = testing.allocator;

    var map = std.AutoArrayHashMap(i32, i32).init(allocator);
    defer map.deinit();

    try map.put(1, 5);
    try map.put(2, 10);

    var it = map.iterator();
    while (it.next()) |entry| {
        entry.value_ptr.* += 100;
    }

    try testing.expectEqual(@as(i32, 105), map.get(1).?);
    try testing.expectEqual(@as(i32, 110), map.get(2).?);
}

// ==============================================================================
// Capacity Management
// ==============================================================================

test "ArrayHashMap - capacity management" {
    const allocator = testing.allocator;

    var map = std.AutoArrayHashMap(i32, i32).init(allocator);
    defer map.deinit();

    // Pre-allocate capacity
    try map.ensureTotalCapacity(100);
    try testing.expect(map.capacity() >= 100);

    // Add items without reallocation
    for (0..50) |i| {
        try map.put(@as(i32, @intCast(i)), @as(i32, @intCast(i * 10)));
    }

    try testing.expectEqual(@as(usize, 50), map.count());
}

// ==============================================================================
// Practical Example: Configuration Manager
// ==============================================================================

const Config = struct {
    settings: std.StringArrayHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Config {
        return .{
            .settings = std.StringArrayHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn set(self: *Config, key: []const u8, value: []const u8) !void {
        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);

        // Use getOrPut to safely handle existing keys
        const entry = try self.settings.getOrPut(key);
        if (entry.found_existing) {
            // Free old value before replacing
            self.allocator.free(entry.value_ptr.*);
        }
        entry.value_ptr.* = owned_value;
    }

    pub fn get(self: *Config, key: []const u8) ?[]const u8 {
        return self.settings.get(key);
    }

    pub fn count(self: Config) usize {
        return self.settings.count();
    }

    pub fn deinit(self: *Config) void {
        // Free all owned values
        for (self.settings.values()) |value| {
            self.allocator.free(value);
        }
        self.settings.deinit();
    }
};

test "Config - maintains insertion order" {
    const allocator = testing.allocator;

    var config = Config.init(allocator);
    defer config.deinit();

    try config.set("host", "localhost");
    try config.set("port", "8080");
    try config.set("timeout", "30");

    // Check order
    const keys = config.settings.keys();
    try testing.expectEqualStrings("host", keys[0]);
    try testing.expectEqualStrings("port", keys[1]);
    try testing.expectEqualStrings("timeout", keys[2]);

    // Check values
    try testing.expectEqualStrings("localhost", config.get("host").?);
    try testing.expectEqualStrings("8080", config.get("port").?);
    try testing.expectEqualStrings("30", config.get("timeout").?);
}

test "Config - handles value updates" {
    const allocator = testing.allocator;

    var config = Config.init(allocator);
    defer config.deinit();

    try config.set("setting", "initial");
    try testing.expectEqualStrings("initial", config.get("setting").?);

    try config.set("setting", "updated");
    try testing.expectEqualStrings("updated", config.get("setting").?);

    // Still only one setting
    try testing.expectEqual(@as(usize, 1), config.count());
}

// ==============================================================================
// Practical Example: Ordered Counter
// ==============================================================================

// ANCHOR: ordered_counter
const OrderedCounter = struct {
    counts: std.StringArrayHashMap(usize),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) OrderedCounter {
        return .{
            .counts = std.StringArrayHashMap(usize).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn increment(self: *OrderedCounter, item: []const u8) !void {
        const entry = try self.counts.getOrPut(item);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
        } else {
            entry.value_ptr.* = 1;
        }
    }

    pub fn get(self: *OrderedCounter, item: []const u8) usize {
        return self.counts.get(item) orelse 0;
    }

    pub fn topN(self: *OrderedCounter, n: usize, result: *std.ArrayList([]const u8)) !void {
        var count: usize = 0;
        for (self.counts.keys()) |key| {
            if (count >= n) break;
            try result.append(self.allocator, key);
            count += 1;
        }
    }

    pub fn deinit(self: *OrderedCounter) void {
        self.counts.deinit();
    }
};
// ANCHOR_END: ordered_counter

test "OrderedCounter - first-seen order" {
    const allocator = testing.allocator;

    var counter = OrderedCounter.init(allocator);
    defer counter.deinit();

    try counter.increment("apple");
    try counter.increment("banana");
    try counter.increment("apple");
    try counter.increment("cherry");

    try testing.expectEqual(@as(usize, 2), counter.get("apple"));
    try testing.expectEqual(@as(usize, 1), counter.get("banana"));
    try testing.expectEqual(@as(usize, 1), counter.get("cherry"));

    // First seen order preserved
    const keys = counter.counts.keys();
    try testing.expectEqualStrings("apple", keys[0]);
    try testing.expectEqualStrings("banana", keys[1]);
    try testing.expectEqualStrings("cherry", keys[2]);
}

test "OrderedCounter - topN items" {
    const allocator = testing.allocator;

    var counter = OrderedCounter.init(allocator);
    defer counter.deinit();

    try counter.increment("first");
    try counter.increment("second");
    try counter.increment("third");
    try counter.increment("fourth");

    var results = std.ArrayList([]const u8){};
    defer results.deinit(allocator);

    try counter.topN(2, &results);

    try testing.expectEqual(@as(usize, 2), results.items.len);
    try testing.expectEqualStrings("first", results.items[0]);
    try testing.expectEqualStrings("second", results.items[1]);
}
