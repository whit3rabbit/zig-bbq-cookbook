// Recipe 1.4: Finding Largest or Smallest N Items
// Target Zig Version: 0.15.2
//
// Demonstrates different approaches to finding top/bottom N elements efficiently.
//
// APPROACH COMPARISON:
// 1. Simple Sort: O(n log n) - Best for small datasets or when N ≈ collection size
// 2. std.PriorityQueue: O(n log k) - RECOMMENDED for production, idiomatic Zig
// 3. Manual Heap: O(n log k) - Educational, shows how heaps work internally
//
// Run: zig test code/02-core/01-data-structures/recipe_1_4.zig

const std = @import("std");
const testing = std.testing;

// ==============================================================================
// Approach 1: Simple Sort and Take
// ==============================================================================
// WHEN TO USE:
// - Small datasets (< 1000 items)
// - N is large relative to collection size (N > len/2)
// - You need the results in sorted order
// - Simplicity is more important than performance
//
// COMPLEXITY: O(n log n) time, O(n) space
// ==============================================================================

// ANCHOR: sort_and_take
fn findLargestN(allocator: std.mem.Allocator, items: []const i32, n: usize) ![]i32 {
    // Make a mutable copy
    var sorted = try allocator.dupe(i32, items);
    errdefer allocator.free(sorted);

    // Sort descending
    std.mem.sort(i32, sorted, {}, comptime std.sort.desc(i32));

    // Take first N
    const result = try allocator.dupe(i32, sorted[0..@min(n, sorted.len)]);
    allocator.free(sorted);
    return result;
}

fn findSmallestN(allocator: std.mem.Allocator, items: []const i32, n: usize) ![]i32 {
    // Make a mutable copy
    var sorted = try allocator.dupe(i32, items);
    errdefer allocator.free(sorted);

    // Sort ascending
    std.mem.sort(i32, sorted, {}, comptime std.sort.asc(i32));

    // Take first N
    const result = try allocator.dupe(i32, sorted[0..@min(n, sorted.len)]);
    allocator.free(sorted);
    return result;
}
// ANCHOR_END: sort_and_take

test "find largest N items" {
    const allocator = testing.allocator;
    const data = [_]i32{ 5, 2, 9, 1, 7, 3, 8, 4, 6 };

    const largest3 = try findLargestN(allocator, &data, 3);
    defer allocator.free(largest3);

    try testing.expectEqual(@as(usize, 3), largest3.len);
    try testing.expectEqual(@as(i32, 9), largest3[0]);
    try testing.expectEqual(@as(i32, 8), largest3[1]);
    try testing.expectEqual(@as(i32, 7), largest3[2]);
}

test "find smallest N items" {
    const allocator = testing.allocator;
    const data = [_]i32{ 5, 2, 9, 1, 7, 3, 8, 4, 6 };

    const smallest3 = try findSmallestN(allocator, &data, 3);
    defer allocator.free(smallest3);

    try testing.expectEqual(@as(usize, 3), smallest3.len);
    try testing.expectEqual(@as(i32, 1), smallest3[0]);
    try testing.expectEqual(@as(i32, 2), smallest3[1]);
    try testing.expectEqual(@as(i32, 3), smallest3[2]);
}

test "handles N larger than collection" {
    const allocator = testing.allocator;
    const data = [_]i32{ 3, 1, 2 };

    const largest10 = try findLargestN(allocator, &data, 10);
    defer allocator.free(largest10);

    try testing.expectEqual(@as(usize, 3), largest10.len);
}

// ==============================================================================
// Approach 2: std.PriorityQueue (RECOMMENDED FOR PRODUCTION)
// ==============================================================================
// WHEN TO USE:
// - Large datasets (1000+ items) where N is small (N << collection size)
// - Streaming data (process items one at a time)
// - Production code (battle-tested, maintained by Zig team)
// - You don't need results in sorted order
//
// WHY PREFERRED:
// - Idiomatic Zig - uses standard library
// - Memory efficient - only stores N items at a time
// - Well-tested and optimized
// - Generic - works with any type
//
// COMPLEXITY: O(n log k) time where k=N, O(k) space
// HOW IT WORKS:
// - Maintains a min-heap of size N to track largest items
// - For each new item, if larger than smallest in heap, replace it
// - Final heap contains the N largest items
// ==============================================================================

// ANCHOR: priority_queue
fn compareLargest(_: void, a: i32, b: i32) std.math.Order {
    // For tracking largest N items, use a MIN heap
    // Smallest item is at top, gets replaced when we find larger items
    return std.math.order(a, b);
}

fn compareSmallest(_: void, a: i32, b: i32) std.math.Order {
    // For tracking smallest N items, use a MAX heap
    // Largest item is at top, gets replaced when we find smaller items
    return std.math.order(b, a);
}

fn findLargestNWithPriorityQueue(
    allocator: std.mem.Allocator,
    items: []const i32,
    n: usize,
) ![]i32 {
    if (n == 0) return &[_]i32{};

    // Create a min-heap to track the N largest items
    var pq = std.PriorityQueue(i32, void, compareLargest).init(allocator, {});
    defer pq.deinit();

    for (items) |item| {
        if (pq.count() < n) {
            // Still filling up to N items
            try pq.add(item);
        } else {
            // Check if this item should replace the smallest of our top N
            const min_of_top_n = pq.peek() orelse unreachable;
            if (item > min_of_top_n) {
                _ = pq.remove(); // Remove smallest
                try pq.add(item); // Add new larger item
            }
        }
    }

    // Extract results (will be in heap order, not sorted)
    const result = try allocator.alloc(i32, pq.count());
    var i: usize = 0;
    while (pq.removeOrNull()) |val| {
        result[i] = val;
        i += 1;
    }

    return result;
}
// ANCHOR_END: priority_queue

fn findSmallestNWithPriorityQueue(
    allocator: std.mem.Allocator,
    items: []const i32,
    n: usize,
) ![]i32 {
    if (n == 0) return &[_]i32{};

    // Create a max-heap to track the N smallest items
    var pq = std.PriorityQueue(i32, void, compareSmallest).init(allocator, {});
    defer pq.deinit();

    for (items) |item| {
        if (pq.count() < n) {
            try pq.add(item);
        } else {
            const max_of_bottom_n = pq.peek() orelse unreachable;
            if (item < max_of_bottom_n) {
                _ = pq.remove();
                try pq.add(item);
            }
        }
    }

    const result = try allocator.alloc(i32, pq.count());
    var i: usize = 0;
    while (pq.removeOrNull()) |val| {
        result[i] = val;
        i += 1;
    }

    return result;
}

test "priority queue - find largest N items" {
    const allocator = testing.allocator;
    const data = [_]i32{ 5, 2, 9, 1, 7, 3, 8, 4, 6 };

    const largest3 = try findLargestNWithPriorityQueue(allocator, &data, 3);
    defer allocator.free(largest3);

    // Sort results for easy verification
    std.mem.sort(i32, largest3, {}, comptime std.sort.desc(i32));

    try testing.expectEqual(@as(usize, 3), largest3.len);
    try testing.expectEqual(@as(i32, 9), largest3[0]);
    try testing.expectEqual(@as(i32, 8), largest3[1]);
    try testing.expectEqual(@as(i32, 7), largest3[2]);
}

test "priority queue - find smallest N items" {
    const allocator = testing.allocator;
    const data = [_]i32{ 5, 2, 9, 1, 7, 3, 8, 4, 6 };

    const smallest3 = try findSmallestNWithPriorityQueue(allocator, &data, 3);
    defer allocator.free(smallest3);

    // Sort results for easy verification
    std.mem.sort(i32, smallest3, {}, comptime std.sort.asc(i32));

    try testing.expectEqual(@as(usize, 3), smallest3.len);
    try testing.expectEqual(@as(i32, 1), smallest3[0]);
    try testing.expectEqual(@as(i32, 2), smallest3[1]);
    try testing.expectEqual(@as(i32, 3), smallest3[2]);
}

test "priority queue - handles large dataset efficiently" {
    const allocator = testing.allocator;

    // Create large dataset
    const large_data = try allocator.alloc(i32, 10000);
    defer allocator.free(large_data);

    for (large_data, 0..) |*item, i| {
        item.* = @as(i32, @intCast(i));
    }

    // Find top 10 - this should be much faster than sorting all 10k items
    const top10 = try findLargestNWithPriorityQueue(allocator, large_data, 10);
    defer allocator.free(top10);

    try testing.expectEqual(@as(usize, 10), top10.len);

    // Sort to verify we got the right values
    std.mem.sort(i32, top10, {}, comptime std.sort.desc(i32));
    try testing.expectEqual(@as(i32, 9999), top10[0]);
    try testing.expectEqual(@as(i32, 9998), top10[1]);
}

test "priority queue - handles empty input" {
    const allocator = testing.allocator;
    const empty: []const i32 = &[_]i32{};

    const result = try findLargestNWithPriorityQueue(allocator, empty, 5);
    defer allocator.free(result);

    try testing.expectEqual(@as(usize, 0), result.len);
}

test "priority queue - handles N = 0" {
    const allocator = testing.allocator;
    const data = [_]i32{ 1, 2, 3 };

    const result = try findLargestNWithPriorityQueue(allocator, &data, 0);
    defer allocator.free(result);

    try testing.expectEqual(@as(usize, 0), result.len);
}

// ==============================================================================
// Finding Single Min/Max (No Sorting)
// ==============================================================================

fn findMax(items: []const i32) ?i32 {
    if (items.len == 0) return null;

    var max_val = items[0];
    for (items[1..]) |item| {
        if (item > max_val) {
            max_val = item;
        }
    }
    return max_val;
}

fn findMin(items: []const i32) ?i32 {
    if (items.len == 0) return null;

    var min_val = items[0];
    for (items[1..]) |item| {
        if (item < min_val) {
            min_val = item;
        }
    }
    return min_val;
}

test "find single maximum" {
    const data = [_]i32{ 5, 2, 9, 1, 7, 3 };

    const max_val = findMax(&data);
    try testing.expectEqual(@as(?i32, 9), max_val);
}

test "find single minimum" {
    const data = [_]i32{ 5, 2, 9, 1, 7, 3 };

    const min_val = findMin(&data);
    try testing.expectEqual(@as(?i32, 1), min_val);
}

test "min/max with empty slice" {
    const empty: []const i32 = &[_]i32{};

    try testing.expectEqual(@as(?i32, null), findMax(empty));
    try testing.expectEqual(@as(?i32, null), findMin(empty));
}

test "min/max with single element" {
    const single = [_]i32{42};

    try testing.expectEqual(@as(?i32, 42), findMax(&single));
    try testing.expectEqual(@as(?i32, 42), findMin(&single));
}

// ==============================================================================
// Using std.sort with Custom Comparisons
// ==============================================================================

fn compareAbs(_: void, a: i32, b: i32) bool {
    return @abs(a) < @abs(b);
}

test "sort by absolute value" {
    const allocator = testing.allocator;
    const data = [_]i32{ -5, 2, -9, 1, 7, -3 };

    const sorted = try allocator.dupe(i32, &data);
    defer allocator.free(sorted);

    std.mem.sort(i32, sorted, {}, compareAbs);

    // Sorted by abs: 1, 2, -3, -5, 7, -9
    try testing.expectEqual(@as(i32, 1), sorted[0]);
    try testing.expectEqual(@as(i32, 2), sorted[1]);
    try testing.expectEqual(@as(i32, -3), sorted[2]);
}

// ==============================================================================
// Approach 3: Manual Heap Implementation (EDUCATIONAL)
// ==============================================================================
// WHEN TO USE:
// - Learning how heaps work internally
// - Understanding priority queue implementation
// - Educational purposes or interview prep
// - You need custom heap behavior not provided by std.PriorityQueue
//
// WHY NOT RECOMMENDED FOR PRODUCTION:
// - More code to maintain
// - Easier to introduce bugs
// - std.PriorityQueue already does this (better tested)
//
// COMPLEXITY: Same as std.PriorityQueue - O(n log k) time, O(k) space
// HOW IT WORKS: Same algorithm, but we implement the heap operations ourselves
// ==============================================================================

const MaxNTracker = struct {
    heap: std.ArrayList(i32),
    capacity: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, n: usize) MaxNTracker {
        return .{
            .heap = std.ArrayList(i32){},
            .capacity = n,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MaxNTracker) void {
        self.heap.deinit(self.allocator);
    }

    pub fn add(self: *MaxNTracker, value: i32) !void {
        if (self.heap.items.len < self.capacity) {
            try self.heap.append(self.allocator, value);
            self.heapifyUp(self.heap.items.len - 1);
        } else if (value > self.heap.items[0]) {
            // Value larger than smallest in our top N
            self.heap.items[0] = value;
            self.heapifyDown(0);
        }
    }

    pub fn getResults(self: MaxNTracker) []const i32 {
        return self.heap.items;
    }

    fn heapifyUp(self: *MaxNTracker, index: usize) void {
        if (index == 0) return;

        const parent = (index - 1) / 2;
        if (self.heap.items[index] < self.heap.items[parent]) {
            std.mem.swap(i32, &self.heap.items[index], &self.heap.items[parent]);
            self.heapifyUp(parent);
        }
    }

    fn heapifyDown(self: *MaxNTracker, index: usize) void {
        const left = 2 * index + 1;
        const right = 2 * index + 2;
        var smallest = index;

        if (left < self.heap.items.len and
            self.heap.items[left] < self.heap.items[smallest])
        {
            smallest = left;
        }
        if (right < self.heap.items.len and
            self.heap.items[right] < self.heap.items[smallest])
        {
            smallest = right;
        }

        if (smallest != index) {
            std.mem.swap(i32, &self.heap.items[index], &self.heap.items[smallest]);
            self.heapifyDown(smallest);
        }
    }
};

test "heap tracker - maintains top N" {
    const allocator = testing.allocator;
    var tracker = MaxNTracker.init(allocator, 3);
    defer tracker.deinit();

    // Add values
    try tracker.add(5);
    try tracker.add(2);
    try tracker.add(9);
    try tracker.add(1);
    try tracker.add(7);
    try tracker.add(3);

    const results = tracker.getResults();
    try testing.expectEqual(@as(usize, 3), results.len);

    // Should contain 9, 7, 5 (in heap order, not sorted)
    const sorted = try allocator.dupe(i32, results);
    defer allocator.free(sorted);
    std.mem.sort(i32, sorted, {}, comptime std.sort.desc(i32));

    try testing.expectEqual(@as(i32, 9), sorted[0]);
    try testing.expectEqual(@as(i32, 7), sorted[1]);
    try testing.expectEqual(@as(i32, 5), sorted[2]);
}

test "heap tracker - handles duplicates" {
    const allocator = testing.allocator;
    var tracker = MaxNTracker.init(allocator, 3);
    defer tracker.deinit();

    try tracker.add(5);
    try tracker.add(5);
    try tracker.add(5);
    try tracker.add(3);

    const results = tracker.getResults();
    try testing.expectEqual(@as(usize, 3), results.len);
}

// ==============================================================================
// Sorting Custom Types
// ==============================================================================

const Score = struct {
    name: []const u8,
    points: i32,
};

fn compareScoresDesc(_: void, a: Score, b: Score) bool {
    return a.points > b.points;
}

test "sort custom structs by field" {
    var scores = [_]Score{
        .{ .name = "Alice", .points = 95 },
        .{ .name = "Bob", .points = 87 },
        .{ .name = "Charlie", .points = 92 },
        .{ .name = "Diana", .points = 88 },
    };

    std.mem.sort(Score, &scores, {}, compareScoresDesc);

    // Top 3 scorers
    try testing.expectEqualStrings("Alice", scores[0].name);
    try testing.expectEqual(@as(i32, 95), scores[0].points);

    try testing.expectEqualStrings("Charlie", scores[1].name);
    try testing.expectEqual(@as(i32, 92), scores[1].points);

    try testing.expectEqualStrings("Diana", scores[2].name);
    try testing.expectEqual(@as(i32, 88), scores[2].points);
}

// ==============================================================================
// Practical Example: Top K Frequent Elements
// ==============================================================================

// ANCHOR: top_k_frequent
const FrequencyItem = struct {
    value: i32,
    count: usize,
};

fn compareFrequency(_: void, a: FrequencyItem, b: FrequencyItem) bool {
    return a.count > b.count;
}

fn topKFrequent(allocator: std.mem.Allocator, items: []const i32, k: usize) ![]i32 {
    // Count frequencies
    var freq_map = std.AutoHashMap(i32, usize).init(allocator);
    defer freq_map.deinit();

    for (items) |item| {
        const entry = try freq_map.getOrPut(item);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
        } else {
            entry.value_ptr.* = 1;
        }
    }

    // Convert to array
    var freq_list = std.ArrayList(FrequencyItem){};
    defer freq_list.deinit(allocator);

    var iter = freq_map.iterator();
    while (iter.next()) |entry| {
        try freq_list.append(allocator, .{
            .value = entry.key_ptr.*,
            .count = entry.value_ptr.*,
        });
    }

    // Sort by frequency
    std.mem.sort(FrequencyItem, freq_list.items, {}, compareFrequency);

    // Extract top k values
    const result = try allocator.alloc(i32, @min(k, freq_list.items.len));
    for (result, 0..) |*r, i| {
        r.* = freq_list.items[i].value;
    }

    return result;
}
// ANCHOR_END: top_k_frequent

test "find top K frequent elements" {
    const allocator = testing.allocator;
    const data = [_]i32{ 1, 1, 1, 2, 2, 3, 4, 4, 4, 4 };

    const top2 = try topKFrequent(allocator, &data, 2);
    defer allocator.free(top2);

    try testing.expectEqual(@as(usize, 2), top2.len);
    // 4 appears 4 times, 1 appears 3 times
    try testing.expectEqual(@as(i32, 4), top2[0]);
    try testing.expectEqual(@as(i32, 1), top2[1]);
}
