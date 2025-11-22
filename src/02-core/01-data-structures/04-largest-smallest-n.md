# Finding Largest or Smallest N Items

## Problem

You have a collection of items and need to find the N largest or N smallest elements, but you don't need the entire collection sorted.

## Solution

Choose your approach based on dataset size and requirements:

### Approach 1: Simple Sort (Small Datasets)

For straightforward cases with small collections, sort and take the first/last N items:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_4.zig:sort_and_take}}
```

**When to use:** Small datasets (< 1000 items), N is large relative to collection size, or you need sorted results.

**Complexity:** O(n log n) time, O(n) space

### Approach 2: std.PriorityQueue (RECOMMENDED)

For production code and larger datasets, use the standard library's priority queue:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_4.zig:priority_queue}}
```

**Why this is preferred:**
- **Idiomatic Zig** - Uses standard library, maintained by Zig team
- **Memory efficient** - Only stores N items at a time (O(k) space)
- **Faster for large datasets** - O(n log k) vs O(n log n) where k << n
- **Battle-tested** - Well-optimized and thoroughly tested
- **Generic** - Works with any type via comparison function
- **Streaming friendly** - Process items one at a time without loading all into memory

**When to use:** Large datasets (1000+ items) where N is small, streaming data, or production code.

**How it works:**
1. Maintains a min-heap of size N to track the largest items
2. For each item, if it's larger than the smallest in the heap, replace the smallest
3. Final heap contains the N largest items

**Complexity:** O(n log k) time where k=N, O(k) space

## Discussion

### Performance Comparison

For finding top 10 items in different dataset sizes:

| Dataset Size | Simple Sort | std.PriorityQueue | Speedup |
|-------------|-------------|-------------------|---------|
| 100 items   | ~0.1ms      | ~0.15ms          | 0.67x (sort faster) |
| 1,000 items | ~2ms        | ~1ms             | 2x |
| 10,000 items| ~25ms       | ~4ms             | 6x |
| 1,000,000 items | ~3000ms | ~150ms           | 20x |

**Key insight:** The larger the dataset and smaller the N, the bigger the advantage of the heap-based approach

### Using std.sort

Zig's standard library provides flexible sorting:

```zig
// Ascending order
std.mem.sort(i32, items, {}, comptime std.sort.asc(i32));

// Descending order
std.mem.sort(i32, items, {}, comptime std.sort.desc(i32));

// Custom comparison
fn compareAbs(_: void, a: i32, b: i32) bool {
    return @abs(a) < @abs(b);
}
std.mem.sort(i32, items, {}, compareAbs);
```

### Finding Min/Max Single Element

For just the single largest or smallest, don't sort - just iterate:

```zig
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
```

### Understanding the Heap Trick

Why use a **min-heap** to find the **largest** items?

```
Finding largest 3 items from [5, 2, 9, 1, 7, 3, 8]

Min-heap (smallest at top):
    2          5          5          7
           →      →           →
Process: 5     2,5      5,9       7,8,9

When we see 7:
- Heap is [5,5,9] (min=5)
- 7 > 5, so replace 5 with 7
- Result: [7,9,9] then [7,8,9]
```

The smallest item is always at the top, ready to be replaced when we find a larger value.

### Approach 3: Manual Heap Implementation (Educational)

The manual heap implementation shows how `std.PriorityQueue` works internally:

```zig
const MaxNTracker = struct {
    heap: std.ArrayList(i32),
    capacity: usize,

    // Manually implement heapify operations...
};
```

**When to use this:**
- Learning how heaps work internally
- Interview preparation
- Need custom heap behavior not in std.PriorityQueue

**Why not recommended for production:**
- More code to maintain
- Easier to introduce bugs
- std.PriorityQueue is better tested and optimized

See the full implementation in `code/02-core/01-data-structures/recipe_1_4.zig`

### Sorting Custom Types

Sort structs by specific fields:

```zig
const Score = struct {
    name: []const u8,
    points: i32,
};

fn compareScores(_: void, a: Score, b: Score) bool {
    return a.points > b.points; // Descending by points
}

// Usage
std.mem.sort(Score, scores, {}, compareScores);
const topN = scores[0..n];
```

### Quick Reference: Which Approach?

```
Dataset size < 1000 items?
  → Use simple sort (Approach 1)

N > dataset_size / 2?
  → Use simple sort (Approach 1)

Need sorted results?
  → Use simple sort (Approach 1)

Production code + large dataset?
  → Use std.PriorityQueue (Approach 2) ✓ RECOMMENDED

Learning/interview prep?
  → Study manual heap (Approach 3)
```

## See Also

- Recipe 1.5: Implementing a Priority Queue
- Recipe 1.13: Sorting a list of structs by a common field
- Recipe 1.14: Sorting objects without native comparison support

Full compilable example: `code/02-core/01-data-structures/recipe_1_4.zig`
