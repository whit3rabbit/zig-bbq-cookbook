// Recipe 8.22: Making Classes Support Comparison Operations
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_equality
// Basic equality implementation
const Point = struct {
    x: i32,
    y: i32,

    pub fn eql(self: Point, other: Point) bool {
        return self.x == other.x and self.y == other.y;
    }
};

test "basic equality" {
    const p1 = Point{ .x = 10, .y = 20 };
    const p2 = Point{ .x = 10, .y = 20 };
    const p3 = Point{ .x = 15, .y = 20 };

    try testing.expect(p1.eql(p2));
    try testing.expect(!p1.eql(p3));
}
// ANCHOR_END: basic_equality

// ANCHOR: ordering_comparison
// Ordering comparisons for sorting
const Person = struct {
    name: []const u8,
    age: u32,

    pub fn lessThan(self: Person, other: Person) bool {
        // Compare by age first, then name
        if (self.age != other.age) {
            return self.age < other.age;
        }
        return std.mem.lessThan(u8, self.name, other.name);
    }

    pub fn compare(self: Person, other: Person) std.math.Order {
        if (self.age < other.age) return .lt;
        if (self.age > other.age) return .gt;
        return std.mem.order(u8, self.name, other.name);
    }
};

test "ordering comparison" {
    const alice = Person{ .name = "Alice", .age = 30 };
    const bob = Person{ .name = "Bob", .age = 25 };
    const charlie = Person{ .name = "Charlie", .age = 25 };

    try testing.expect(bob.lessThan(alice));
    try testing.expect(!alice.lessThan(bob));
    try testing.expect(bob.lessThan(charlie));

    try testing.expectEqual(std.math.Order.gt, alice.compare(bob));
    try testing.expectEqual(std.math.Order.lt, bob.compare(charlie));
}
// ANCHOR_END: ordering_comparison

// ANCHOR: comparison_context
// Comparison context for std.sort
const Item = struct {
    id: u32,
    priority: i32,
    name: []const u8,

    const ByPriority = struct {
        pub fn lessThan(_: @This(), a: Item, b: Item) bool {
            return a.priority > b.priority; // Higher priority first
        }
    };

    const ByName = struct {
        pub fn lessThan(_: @This(), a: Item, b: Item) bool {
            return std.mem.lessThan(u8, a.name, b.name);
        }
    };
};

test "comparison context" {
    const allocator = testing.allocator;

    var items = try allocator.alloc(Item, 3);
    defer allocator.free(items);

    items[0] = Item{ .id = 1, .priority = 10, .name = "zebra" };
    items[1] = Item{ .id = 2, .priority = 20, .name = "apple" };
    items[2] = Item{ .id = 3, .priority = 15, .name = "banana" };

    // Sort by priority
    std.mem.sort(Item, items, Item.ByPriority{}, Item.ByPriority.lessThan);
    try testing.expectEqual(@as(u32, 2), items[0].id); // Priority 20
    try testing.expectEqual(@as(u32, 3), items[1].id); // Priority 15

    // Sort by name
    std.mem.sort(Item, items, Item.ByName{}, Item.ByName.lessThan);
    try testing.expectEqualStrings("apple", items[0].name);
    try testing.expectEqualStrings("banana", items[1].name);
}
// ANCHOR_END: comparison_context

// ANCHOR: hash_function
// Hash function for use in hash maps
const Coordinate = struct {
    x: i32,
    y: i32,

    pub fn hash(self: Coordinate) u64 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(std.mem.asBytes(&self.x));
        hasher.update(std.mem.asBytes(&self.y));
        return hasher.final();
    }

    pub fn eql(self: Coordinate, other: Coordinate) bool {
        return self.x == other.x and self.y == other.y;
    }
};

test "hash function" {
    const c1 = Coordinate{ .x = 10, .y = 20 };
    const c2 = Coordinate{ .x = 10, .y = 20 };
    const c3 = Coordinate{ .x = 15, .y = 20 };

    try testing.expectEqual(c1.hash(), c2.hash());
    try testing.expect(c1.hash() != c3.hash());
    try testing.expect(c1.eql(c2));
}
// ANCHOR_END: hash_function

// ANCHOR: deep_equality
// Deep equality for nested structures
const Team = struct {
    name: []const u8,
    members: []const []const u8,
    score: i32,

    pub fn eql(self: Team, other: Team) bool {
        if (self.score != other.score) return false;
        if (!std.mem.eql(u8, self.name, other.name)) return false;
        if (self.members.len != other.members.len) return false;

        for (self.members, other.members) |m1, m2| {
            if (!std.mem.eql(u8, m1, m2)) return false;
        }

        return true;
    }
};

test "deep equality" {
    const members1 = [_][]const u8{ "Alice", "Bob" };
    const members2 = [_][]const u8{ "Alice", "Bob" };
    const members3 = [_][]const u8{ "Alice", "Charlie" };

    const team1 = Team{ .name = "Red", .members = &members1, .score = 100 };
    const team2 = Team{ .name = "Red", .members = &members2, .score = 100 };
    const team3 = Team{ .name = "Red", .members = &members3, .score = 100 };

    try testing.expect(team1.eql(team2));
    try testing.expect(!team1.eql(team3));
}
// ANCHOR_END: deep_equality

// ANCHOR: custom_comparison
// Custom comparison with context
const Product = struct {
    name: []const u8,
    price: f64,
    rating: f32,

    const CompareMode = enum {
        by_price,
        by_rating,
        by_name,
    };

    pub fn compare(self: Product, other: Product, mode: CompareMode) std.math.Order {
        return switch (mode) {
            .by_price => std.math.order(self.price, other.price),
            .by_rating => std.math.order(self.rating, other.rating),
            .by_name => std.mem.order(u8, self.name, other.name),
        };
    }
};

test "custom comparison" {
    const laptop = Product{ .name = "Laptop", .price = 999.99, .rating = 4.5 };
    const phone = Product{ .name = "Phone", .price = 599.99, .rating = 4.8 };

    try testing.expectEqual(std.math.Order.gt, laptop.compare(phone, .by_price));
    try testing.expectEqual(std.math.Order.lt, laptop.compare(phone, .by_rating));
    try testing.expectEqual(std.math.Order.lt, laptop.compare(phone, .by_name)); // L < P
}
// ANCHOR_END: custom_comparison

// ANCHOR: approximate_equality
// Approximate equality for floating point
const Vector2D = struct {
    x: f64,
    y: f64,

    pub fn eql(self: Vector2D, other: Vector2D) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn approxEql(self: Vector2D, other: Vector2D, epsilon: f64) bool {
        const dx = @abs(self.x - other.x);
        const dy = @abs(self.y - other.y);
        return dx < epsilon and dy < epsilon;
    }
};

test "approximate equality" {
    const v1 = Vector2D{ .x = 1.0, .y = 2.0 };
    const v2 = Vector2D{ .x = 1.0001, .y = 2.0001 };

    try testing.expect(!v1.eql(v2)); // Exact equality fails
    try testing.expect(v1.approxEql(v2, 0.001)); // Approximate succeeds
    try testing.expect(!v1.approxEql(v2, 0.00001)); // Too strict
}
// ANCHOR_END: approximate_equality

// ANCHOR: comparable_interface
// Generic comparable interface using comptime
fn Comparable(comptime T: type) type {
    return struct {
        pub fn requiresCompare() void {
            if (!@hasDecl(T, "compare")) {
                @compileError("Type must have compare method");
            }
        }

        pub fn min(a: T, b: T) T {
            return if (a.compare(b) == .lt) a else b;
        }

        pub fn max(a: T, b: T) T {
            return if (a.compare(b) == .gt) a else b;
        }

        pub fn clamp(value: T, low: T, high: T) T {
            return max(low, min(value, high));
        }
    };
}

const Score = struct {
    value: i32,

    pub fn compare(self: Score, other: Score) std.math.Order {
        return std.math.order(self.value, other.value);
    }
};

test "comparable interface" {
    const ScoreOps = Comparable(Score);

    const s1 = Score{ .value = 100 };
    const s2 = Score{ .value = 200 };
    const s3 = Score{ .value = 150 };

    const min_score = ScoreOps.min(s1, s2);
    const max_score = ScoreOps.max(s1, s2);
    const clamped = ScoreOps.clamp(s3, s1, s2);

    try testing.expectEqual(@as(i32, 100), min_score.value);
    try testing.expectEqual(@as(i32, 200), max_score.value);
    try testing.expectEqual(@as(i32, 150), clamped.value);
}
// ANCHOR_END: comparable_interface

// ANCHOR: partial_ordering
// Partial ordering with optional comparison
const Entry = struct {
    key: ?[]const u8,
    value: i32,

    pub fn compare(self: Entry, other: Entry) ?std.math.Order {
        // Can't compare if either key is null
        const k1 = self.key orelse return null;
        const k2 = other.key orelse return null;

        const key_order = std.mem.order(u8, k1, k2);
        if (key_order != .eq) return key_order;

        return std.math.order(self.value, other.value);
    }
};

test "partial ordering" {
    const e1 = Entry{ .key = "apple", .value = 10 };
    const e2 = Entry{ .key = "banana", .value = 20 };
    const e3 = Entry{ .key = null, .value = 30 };

    try testing.expectEqual(std.math.Order.lt, e1.compare(e2).?);
    try testing.expect(e1.compare(e3) == null);
    try testing.expect(e3.compare(e2) == null);
}
// ANCHOR_END: partial_ordering

// ANCHOR: multi_field_comparison
// Efficient multi-field comparison
const Record = struct {
    category: u8,
    priority: i32,
    timestamp: i64,
    id: u32,

    pub fn compare(self: Record, other: Record) std.math.Order {
        // Compare fields in order of importance
        if (self.category != other.category) {
            return std.math.order(self.category, other.category);
        }
        if (self.priority != other.priority) {
            return std.math.order(self.priority, other.priority);
        }
        if (self.timestamp != other.timestamp) {
            return std.math.order(self.timestamp, other.timestamp);
        }
        return std.math.order(self.id, other.id);
    }

    pub fn eql(self: Record, other: Record) bool {
        return self.category == other.category and
            self.priority == other.priority and
            self.timestamp == other.timestamp and
            self.id == other.id;
    }
};

test "multi field comparison" {
    const r1 = Record{ .category = 1, .priority = 10, .timestamp = 1000, .id = 1 };
    const r2 = Record{ .category = 1, .priority = 10, .timestamp = 1000, .id = 2 };
    const r3 = Record{ .category = 2, .priority = 5, .timestamp = 900, .id = 1 };

    try testing.expectEqual(std.math.Order.lt, r1.compare(r2));
    try testing.expectEqual(std.math.Order.lt, r1.compare(r3));
    try testing.expect(r1.eql(r1));
    try testing.expect(!r1.eql(r2));
}
// ANCHOR_END: multi_field_comparison

// Comprehensive test
test "comprehensive comparison operations" {
    // Test all patterns work together
    const allocator = testing.allocator;

    // Basic equality
    const p1 = Point{ .x = 5, .y = 10 };
    const p2 = Point{ .x = 5, .y = 10 };
    try testing.expect(p1.eql(p2));

    // Ordering
    const alice = Person{ .name = "Alice", .age = 30 };
    const bob = Person{ .name = "Bob", .age = 25 };
    try testing.expect(bob.lessThan(alice));

    // Sorting with context
    var items = try allocator.alloc(Item, 2);
    defer allocator.free(items);
    items[0] = Item{ .id = 1, .priority = 10, .name = "zebra" };
    items[1] = Item{ .id = 2, .priority = 20, .name = "apple" };
    std.mem.sort(Item, items, Item.ByPriority{}, Item.ByPriority.lessThan);
    try testing.expectEqual(@as(u32, 2), items[0].id);

    // Hash equality
    const c1 = Coordinate{ .x = 1, .y = 2 };
    const c2 = Coordinate{ .x = 1, .y = 2 };
    try testing.expectEqual(c1.hash(), c2.hash());

    // Approximate equality
    const v1 = Vector2D{ .x = 1.0, .y = 2.0 };
    const v2 = Vector2D{ .x = 1.0001, .y = 2.0001 };
    try testing.expect(v1.approxEql(v2, 0.001));
}
