// Recipe 1.5: Implementing a Priority Queue
// Target Zig Version: 0.15.2
//
// Demonstrates using std.PriorityQueue for efficient priority-based ordering.
// Run: zig test code/02-core/01-data-structures/recipe_1_5.zig

const std = @import("std");
const testing = std.testing;

// ==============================================================================
// Basic Priority Queue Usage
// ==============================================================================

// ANCHOR: basic_priority_queue
fn compareMin(_: void, a: i32, b: i32) std.math.Order {
    return std.math.order(a, b);
}

test "basic priority queue - min heap" {
    const allocator = testing.allocator;

    var pq = std.PriorityQueue(i32, void, compareMin).init(allocator, {});
    defer pq.deinit();

    try pq.add(5);
    try pq.add(2);
    try pq.add(9);
    try pq.add(1);

    // Remove in priority order (smallest first)
    try testing.expectEqual(@as(i32, 1), pq.remove());
    try testing.expectEqual(@as(i32, 2), pq.remove());
    try testing.expectEqual(@as(i32, 5), pq.remove());
    try testing.expectEqual(@as(i32, 9), pq.remove());
    try testing.expectEqual(@as(usize, 0), pq.count());
}

fn compareMax(_: void, a: i32, b: i32) std.math.Order {
    return std.math.order(b, a); // Reversed for max heap
}

test "basic priority queue - max heap" {
    const allocator = testing.allocator;

    var pq = std.PriorityQueue(i32, void, compareMax).init(allocator, {});
    defer pq.deinit();

    try pq.add(5);
    try pq.add(2);
    try pq.add(9);
    try pq.add(1);

    // Remove in priority order (largest first)
    try testing.expectEqual(@as(i32, 9), pq.remove());
    try testing.expectEqual(@as(i32, 5), pq.remove());
    try testing.expectEqual(@as(i32, 2), pq.remove());
    try testing.expectEqual(@as(i32, 1), pq.remove());
    try testing.expectEqual(@as(usize, 0), pq.count());
}
// ANCHOR_END: basic_priority_queue

// ==============================================================================
// Peek Operation
// ==============================================================================

test "peek without removing" {
    const allocator = testing.allocator;

    var pq = std.PriorityQueue(i32, void, compareMin).init(allocator, {});
    defer pq.deinit();

    try pq.add(5);
    try pq.add(2);
    try pq.add(9);

    // Peek returns the min element without removing
    try testing.expectEqual(@as(i32, 2), pq.peek().?);
    try testing.expectEqual(@as(i32, 2), pq.peek().?);  // Still there

    // Now remove it
    try testing.expectEqual(@as(i32, 2), pq.remove());
    try testing.expectEqual(@as(i32, 5), pq.peek().?);  // Next smallest
}

// ==============================================================================
// Count and Empty Check
// ==============================================================================

test "count and empty operations" {
    const allocator = testing.allocator;

    var pq = std.PriorityQueue(i32, void, compareMin).init(allocator, {});
    defer pq.deinit();

    try testing.expectEqual(@as(usize, 0), pq.count());

    try pq.add(1);
    try testing.expectEqual(@as(usize, 1), pq.count());

    try pq.add(2);
    try pq.add(3);
    try testing.expectEqual(@as(usize, 3), pq.count());

    _ = pq.remove();
    try testing.expectEqual(@as(usize, 2), pq.count());
}

// ==============================================================================
// Priority Queue with Custom Types
// ==============================================================================

// ANCHOR: custom_type_priority
const Task = struct {
    name: []const u8,
    priority: u32,
};

fn compareTasks(_: void, a: Task, b: Task) std.math.Order {
    // Higher priority numbers come first
    return std.math.order(b.priority, a.priority);
}

test "priority queue with custom type" {
    const allocator = testing.allocator;

    var pq = std.PriorityQueue(Task, void, compareTasks).init(allocator, {});
    defer pq.deinit();

    try pq.add(.{ .name = "Low priority", .priority = 1 });
    try pq.add(.{ .name = "High priority", .priority = 10 });
    try pq.add(.{ .name = "Medium priority", .priority = 5 });

    const first = pq.remove();
    try testing.expectEqualStrings("High priority", first.name);
    try testing.expectEqual(@as(u32, 10), first.priority);

    const second = pq.remove();
    try testing.expectEqualStrings("Medium priority", second.name);
    try testing.expectEqual(@as(u32, 5), second.priority);

    const third = pq.remove();
    try testing.expectEqualStrings("Low priority", third.name);
    try testing.expectEqual(@as(u32, 1), third.priority);
}
// ANCHOR_END: custom_type_priority

// ==============================================================================
// Priority Queue with Context
// ==============================================================================

const CompareContext = struct {
    reverse: bool,
};

fn compareWithContext(ctx: CompareContext, a: i32, b: i32) std.math.Order {
    if (ctx.reverse) {
        return std.math.order(b, a);
    }
    return std.math.order(a, b);
}

test "priority queue with context" {
    const allocator = testing.allocator;

    const context = CompareContext{ .reverse = true };
    var pq = std.PriorityQueue(i32, CompareContext, compareWithContext)
        .init(allocator, context);
    defer pq.deinit();

    try pq.add(5);
    try pq.add(2);
    try pq.add(9);

    // Reversed order (max heap)
    try testing.expectEqual(@as(i32, 9), pq.remove());
    try testing.expectEqual(@as(i32, 5), pq.remove());
    try testing.expectEqual(@as(i32, 2), pq.remove());
}

// ==============================================================================
// Task Scheduler Example
// ==============================================================================

const ScheduledTask = struct {
    name: []const u8,
    priority: u32,
    deadline: i64,
};

fn compareDeadline(_: void, a: ScheduledTask, b: ScheduledTask) std.math.Order {
    // Earlier deadlines first
    return std.math.order(a.deadline, b.deadline);
}

test "task scheduler by deadline" {
    const allocator = testing.allocator;

    var scheduler = std.PriorityQueue(ScheduledTask, void, compareDeadline)
        .init(allocator, {});
    defer scheduler.deinit();

    try scheduler.add(.{
        .name = "Task C",
        .priority = 1,
        .deadline = 300,
    });
    try scheduler.add(.{
        .name = "Task A",
        .priority = 10,
        .deadline = 100,
    });
    try scheduler.add(.{
        .name = "Task B",
        .priority = 5,
        .deadline = 200,
    });

    // Process in deadline order
    const first = scheduler.remove();
    try testing.expectEqualStrings("Task A", first.name);
    try testing.expectEqual(@as(i64, 100), first.deadline);

    const second = scheduler.remove();
    try testing.expectEqualStrings("Task B", second.name);

    const third = scheduler.remove();
    try testing.expectEqualStrings("Task C", third.name);
}

// ==============================================================================
// Event Queue Example
// ==============================================================================

const Event = struct {
    event_type: []const u8,
    timestamp: i64,
};

fn compareTimestamp(_: void, a: Event, b: Event) std.math.Order {
    return std.math.order(a.timestamp, b.timestamp);
}

test "event queue by timestamp" {
    const allocator = testing.allocator;

    var events = std.PriorityQueue(Event, void, compareTimestamp)
        .init(allocator, {});
    defer events.deinit();

    try events.add(.{ .event_type = "click", .timestamp = 1000 });
    try events.add(.{ .event_type = "hover", .timestamp = 500 });
    try events.add(.{ .event_type = "scroll", .timestamp = 1500 });

    // Process events in chronological order
    const first = events.remove();
    try testing.expectEqualStrings("hover", first.event_type);

    const second = events.remove();
    try testing.expectEqualStrings("click", second.event_type);

    const third = events.remove();
    try testing.expectEqualStrings("scroll", third.event_type);
}

// ==============================================================================
// Handling Duplicates
// ==============================================================================

test "priority queue with duplicates" {
    const allocator = testing.allocator;

    var pq = std.PriorityQueue(i32, void, compareMin).init(allocator, {});
    defer pq.deinit();

    try pq.add(5);
    try pq.add(5);
    try pq.add(5);
    try pq.add(2);
    try pq.add(2);

    try testing.expectEqual(@as(?i32, 2), pq.remove());
    try testing.expectEqual(@as(?i32, 2), pq.remove());
    try testing.expectEqual(@as(?i32, 5), pq.remove());
    try testing.expectEqual(@as(?i32, 5), pq.remove());
    try testing.expectEqual(@as(?i32, 5), pq.remove());
}

// ==============================================================================
// Multi-Level Priority
// ==============================================================================

const MultiPriorityTask = struct {
    name: []const u8,
    high_priority: u32,
    low_priority: u32,
};

fn compareMultiPriority(_: void, a: MultiPriorityTask, b: MultiPriorityTask) std.math.Order {
    // First compare high priority (higher is better)
    const high_cmp = std.math.order(b.high_priority, a.high_priority);
    if (high_cmp != .eq) {
        return high_cmp;
    }
    // If high priority is equal, compare low priority (higher is better)
    return std.math.order(b.low_priority, a.low_priority);
}

test "multi-level priority" {
    const allocator = testing.allocator;

    var pq = std.PriorityQueue(MultiPriorityTask, void, compareMultiPriority)
        .init(allocator, {});
    defer pq.deinit();

    try pq.add(.{ .name = "Task A", .high_priority = 1, .low_priority = 5 });
    try pq.add(.{ .name = "Task B", .high_priority = 2, .low_priority = 3 });
    try pq.add(.{ .name = "Task C", .high_priority = 1, .low_priority = 8 });

    // Task B has highest high_priority
    const first = pq.remove();
    try testing.expectEqualStrings("Task B", first.name);

    // Task C and A have same high_priority, but C has higher low_priority
    const second = pq.remove();
    try testing.expectEqualStrings("Task C", second.name);

    const third = pq.remove();
    try testing.expectEqualStrings("Task A", third.name);
}

// ==============================================================================
// Practical Example: Merge K Sorted Lists
// ==============================================================================

// ANCHOR: merge_k_sorted
const ListItem = struct {
    value: i32,
    list_index: usize,
};

fn compareListItem(_: void, a: ListItem, b: ListItem) std.math.Order {
    return std.math.order(a.value, b.value);
}

fn mergeKSorted(allocator: std.mem.Allocator, lists: []const []const i32) ![]i32 {
    var pq = std.PriorityQueue(ListItem, void, compareListItem).init(allocator, {});
    defer pq.deinit();

    var indices = try allocator.alloc(usize, lists.len);
    defer allocator.free(indices);
    @memset(indices, 0);

    // Add first element from each list
    for (lists, 0..) |list, i| {
        if (list.len > 0) {
            try pq.add(.{ .value = list[0], .list_index = i });
            indices[i] = 1;
        }
    }

    var result = std.ArrayList(i32){};
    defer result.deinit(allocator);

    // Extract minimum and add next from same list
    while (pq.count() > 0) {
        const item = pq.remove();
        try result.append(allocator, item.value);

        const list_idx = item.list_index;
        if (indices[list_idx] < lists[list_idx].len) {
            try pq.add(.{
                .value = lists[list_idx][indices[list_idx]],
                .list_index = list_idx,
            });
            indices[list_idx] += 1;
        }
    }

    return result.toOwnedSlice(allocator);
}
// ANCHOR_END: merge_k_sorted

test "merge k sorted lists" {
    const allocator = testing.allocator;

    const list1 = [_]i32{ 1, 4, 7 };
    const list2 = [_]i32{ 2, 5, 8 };
    const list3 = [_]i32{ 3, 6, 9 };

    const lists = [_][]const i32{ &list1, &list2, &list3 };

    const merged = try mergeKSorted(allocator, &lists);
    defer allocator.free(merged);

    const expected = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    try testing.expectEqualSlices(i32, &expected, merged);
}
