## Problem

You need to limit an iterator to produce only the first N items, skip to a specific position, or extract a range, similar to array slicing but for lazy iterators.

## Solution

Build iterators that track position and limits, stopping when the desired range is exhausted.

### Take Iterators

```zig
{{#include ../../../code/02-core/04-iterators-generators/recipe_4_7.zig:take_iterators}}
```

### Chunking Iterators

```zig
{{#include ../../../code/02-core/04-iterators-generators/recipe_4_7.zig:chunking_iterators}}
```

        items: []const T,
        index: usize,
        start: usize,
        end: usize,

        pub fn init(
            items: []const T,
            start: usize,
            end: ?usize
        ) Self {
            const actual_end = if (end) |e|
                @min(e, items.len)
            else
                items.len;
            const actual_start = @min(start, items.len);

            return Self{
                .items = items,
                .index = actual_start,
                .start = actual_start,
                .end = actual_end,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.index >= self.end) return null;

            const item = self.items[self.index];
            self.index += 1;
            return item;
        }

        pub fn reset(self: *Self) void {
            self.index = self.start;
        }
    };
}

// Usage
const items = [_]i32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };

// Items from index 3 to 7
var iter = SliceIterator(i32).init(&items, 3, 7);
while (iter.next()) |num| {
    std.debug.print("{} ", .{num});
}
// Output: 3 4 5 6
```

### Chunking Iterator

```zig
pub fn ChunkIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        index: usize,
        chunk_size: usize,

        pub fn init(items: []const T, chunk_size: usize) Self {
            return Self{
                .items = items,
                .index = 0,
                .chunk_size = chunk_size,
            };
        }

        pub fn next(self: *Self) ?[]const T {
            if (self.index >= self.items.len) return null;

            const remaining = self.items.len - self.index;
            const actual_size = @min(self.chunk_size, remaining);

            const chunk = self.items[
                self.index .. self.index + actual_size
            ];
            self.index += actual_size;
            return chunk;
        }
    };
}

// Usage
const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
var iter = ChunkIterator(i32).init(&items, 3);

while (iter.next()) |chunk| {
    std.debug.print("Chunk: [", .{});
    for (chunk) |val| {
        std.debug.print("{} ", .{val});
    }
    std.debug.print("]\n", .{});
}
// Output:
// Chunk: [1 2 3 ]
// Chunk: [4 5 6 ]
// Chunk: [7 8 9 ]
```

### Take Every Nth Item

```zig
pub fn TakeEveryN(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        index: usize,
        step: usize,
        count: usize,
        max_count: ?usize,

        pub fn init(
            items: []const T,
            step: usize,
            max_count: ?usize
        ) Self {
            return Self{
                .items = items,
                .index = 0,
                .step = step,
                .count = 0,
                .max_count = max_count,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.max_count) |max| {
                if (self.count >= max) return null;
            }

            if (self.index >= self.items.len) return null;

            const item = self.items[self.index];
            self.index += self.step;
            self.count += 1;
            return item;
        }
    };
}

// Usage - take every 2nd item
const items = [_]i32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };
var iter = TakeEveryN(i32).init(&items, 2, null);

while (iter.next()) |num| {
    std.debug.print("{} ", .{num});
}
// Output: 0 2 4 6 8
```

## Discussion

### Comparison with Array Slicing

Array slicing in Zig is eager and creates a slice view:

```zig
const items = [_]i32{ 1, 2, 3, 4, 5 };
const slice = items[1..4]; // [2, 3, 4]
```

Iterator slicing is lazy and works with any iterator:

```zig
var iter = SliceIterator(i32).init(&items, 1, 4);
// Items computed only when next() is called
```

### Benefits of Iterator Slicing

1. **Memory efficiency** - No intermediate arrays
2. **Lazy evaluation** - Items computed on demand
3. **Infinite sequences** - Can slice infinite iterators
4. **Composability** - Chain with other iterator operations

### Common Patterns

**Skip and take:**
```zig
// Skip first 10, take next 5
var iter = SliceIterator(i32).init(&items, 10, 15);
```

**Take first N:**
```zig
var iter = TakeIterator(i32).init(&items, 10);
```

**Skip to end:**
```zig
// Everything from index 5 onward
var iter = SliceIterator(i32).init(&items, 5, null);
```

**Batching:**
```zig
var iter = ChunkIterator(i32).init(&items, 100);
while (iter.next()) |batch| {
    processBatch(batch);
}
```

### Edge Cases to Handle

Always handle:

- **Empty sequences** - Return null immediately
- **Counts exceeding length** - Clamp to available items
- **Zero-sized ranges** - Return null without error
- **Out of bounds starts** - Clamp to length

```zig
pub fn init(items: []const T, start: usize, end: ?usize) Self {
    // Clamp values to valid range
    const actual_end = if (end) |e|
        @min(e, items.len)
    else
        items.len;
    const actual_start = @min(start, items.len);

    // ...
}
```

### Combining Operations

Chain slicing with other iterator operations:

```zig
// Filter, then take first 10
const isEven = struct {
    fn f(x: i32) bool {
        return @rem(x, 2) == 0;
    }
}.f;

var filter = FilterIterator(i32).init(&items, isEven);

var result: [10]i32 = undefined;
var i: usize = 0;
while (i < 10) : (i += 1) {
    if (filter.next()) |item| {
        result[i] = item;
    } else break;
}
```

### Resettable Slicing

For repeated iteration over the same range:

```zig
pub fn reset(self: *Self) void {
    self.index = self.start;
}

// Use
var iter = SliceIterator(i32).init(&items, 5, 10);
while (iter.next()) |_| {}

iter.reset();
// Iterate again over same range
while (iter.next()) |_| {}
```

### Comparison with Other Languages

**Python:**
```python
# Slicing
items[3:7]

# itertools
from itertools import islice
list(islice(items, 3, 7))
```

**Rust:**
```rust
items.iter().skip(3).take(4)
```

**Zig's approach** provides explicit control with no magic, making bounds checking and memory layout clear.

## See Also

- `code/02-core/04-iterators-generators/recipe_4_7.zig` - Full implementations and tests
- Recipe 4.6: Defining generators with extra state
- Recipe 4.8: Skipping the first part of an iterable
- Recipe 4.10: Iterating over index-value pairs
