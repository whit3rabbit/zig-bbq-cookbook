# Implementing a Priority Queue

## Problem

You need a data structure that always gives you the highest (or lowest) priority item, and you want efficient insertion and removal operations.

## Solution

Use Zig's `std.PriorityQueue` from the standard library, which implements a binary heap:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_5.zig:basic_priority_queue}}
```

## Discussion

### How Priority Queues Work

A priority queue maintains elements in heap order, allowing:
- **Add**: O(log n) - Insert a new element
- **Remove**: O(log n) - Remove highest/lowest priority element
- **Peek**: O(1) - View highest/lowest priority without removing

This is much more efficient than sorting after each insertion.

### Comparison Functions

The comparison function determines priority order. It returns `std.math.Order`:

```zig
// Min heap (smallest first)
fn compareMin(_: void, a: i32, b: i32) std.math.Order {
    return std.math.order(a, b);
}

// Max heap (largest first)
fn compareMax(_: void, a: i32, b: i32) std.math.Order {
    return std.math.order(b, a);  // Note: reversed!
}
```

### Priority Queue with Custom Types

You can use priority queues with any type by providing a custom comparator:

<!-- Anchor: custom_type_priority from code/02-core/01-data-structures/recipe_1_5.zig -->
```zig
const Task = struct {
    name: []const u8,
    priority: u32,
};

fn compareTasks(_: void, a: Task, b: Task) std.math.Order {
    // Higher priority numbers come first
    return std.math.order(b.priority, a.priority);
}

var pq = std.PriorityQueue(Task, void, compareTasks).init(allocator, {});
```

### Context Parameter

The priority queue supports a context parameter for state-dependent comparisons:

```zig
const CompareContext = struct {
    reverse: bool,
};

fn compareWithContext(ctx: CompareContext, a: i32, b: i32) std.math.Order {
    if (ctx.reverse) {
        return std.math.order(b, a);
    }
    return std.math.order(a, b);
}

const context = CompareContext{ .reverse = true };
var pq = std.PriorityQueue(i32, CompareContext, compareWithContext)
    .init(allocator, context);
```

### Common Operations

```zig
// Add elements
try pq.add(value);

// Remove highest priority
const item = pq.remove();  // Returns ?T (null if empty)

// Peek at highest priority without removing
const top = pq.peek();  // Returns ?T

// Check size
const count = pq.count();

// Check if empty
const is_empty = pq.count() == 0;
```

### Use Cases

Priority queues are perfect for:
- **Task scheduling**: Process highest priority tasks first
- **Dijkstra's algorithm**: Graph pathfinding
- **Event simulation**: Process events in time order
- **Huffman coding**: Build optimal encoding trees
- **Merge K sorted lists**: Efficiently combine sorted streams

### Example: Task Scheduler

```zig
const Task = struct {
    name: []const u8,
    priority: u32,
    deadline: i64,
};

fn compareDeadline(_: void, a: Task, b: Task) std.math.Order {
    // Earlier deadlines first
    return std.math.order(a.deadline, b.deadline);
}

// Use it
var scheduler = std.PriorityQueue(Task, void, compareDeadline)
    .init(allocator, {});
defer scheduler.deinit();

try scheduler.add(.{
    .name = "Write report",
    .priority = 2,
    .deadline = 1704067200,  // Unix timestamp
});

// Process tasks in deadline order
while (scheduler.remove()) |task| {
    // Execute task
}
```

### Min Heap vs Max Heap

```zig
// Min heap (smallest value has highest priority)
fn minCompare(_: void, a: i32, b: i32) std.math.Order {
    return std.math.order(a, b);
}

// Max heap (largest value has highest priority)
fn maxCompare(_: void, a: i32, b: i32) std.math.Order {
    return std.math.order(b, a);
}
```

### Performance Characteristics

| Operation | Time Complexity | Description |
|-----------|-----------------|-------------|
| `add()` | O(log n) | Insert new element |
| `remove()` | O(log n) | Extract highest priority |
| `peek()` | O(1) | View highest priority |
| `count()` | O(1) | Get queue size |

Memory: O(n) where n is the number of elements.

## See Also

- Recipe 1.4: Finding largest/smallest N items
- Recipe 12.10: Defining an actor task (task queues)
- std.PriorityQueue documentation

Full compilable example: `code/02-core/01-data-structures/recipe_1_5.zig`
