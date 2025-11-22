## Problem

You need to create an iterator that maintains additional state beyond just the current position, such as counters, statistics, or transformation context.

## Solution

Build struct-based iterators that hold extra state fields and update them during iteration. Zig's explicit state management makes this pattern straightforward and efficient.

### Stateful Generators

```zig
{{#include ../../../code/02-core/04-iterators-generators/recipe_4_6.zig:stateful_generators}}
```

### Tracking Iterators

```zig
{{#include ../../../code/02-core/04-iterators-generators/recipe_4_6.zig:tracking_iterators}}

        pub fn init(items: []const T) ?Self {
            if (items.len == 0) return null;

            return Self{
                .items = items,
                .index = 0,
                .sum = 0,
                .min = items[0],
                .max = items[0],
                .count = 0,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.index >= self.items.len) return null;

            const item = self.items[self.index];
            self.index += 1;
            self.count += 1;

            self.sum += item;
            if (item < self.min) self.min = item;
            if (item > self.max) self.max = item;

            return item;
        }

        pub fn getAverage(self: *const Self) f64 {
            if (self.count == 0) return 0.0;
            return @as(f64, @floatFromInt(self.sum)) /
                   @as(f64, @floatFromInt(self.count));
        }
    };
}
```

### Sliding Window Iterator

```zig
pub fn WindowIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        window_size: usize,
        index: usize,
        windows_produced: usize,

        pub fn init(items: []const T, window_size: usize) Self {
            return Self{
                .items = items,
                .window_size = window_size,
                .index = 0,
                .windows_produced = 0,
            };
        }

        pub fn next(self: *Self) ?[]const T {
            if (self.index + self.window_size > self.items.len)
                return null;

            const window = self.items[
                self.index .. self.index + self.window_size
            ];
            self.index += 1;
            self.windows_produced += 1;
            return window;
        }
    };
}

// Usage
var iter = WindowIterator(i32).init(&items, 3);
while (iter.next()) |window| {
    std.debug.print("Window: [", .{});
    for (window) |val| {
        std.debug.print("{} ", .{val});
    }
    std.debug.print("]\n", .{});
}
```

## Discussion

### State Management Patterns

Struct-based iterators naturally hold state:

1. **Position state** - Current index or position
2. **Computation state** - Running sums, counters, previous values
3. **Configuration state** - Predicates, limits, window sizes
4. **Statistics state** - Counts, min/max, averages

### When to Use Stateful Iterators

Use stateful iterators when you need to:

- Generate infinite sequences (Fibonacci, primes, random numbers)
- Filter while collecting statistics
- Transform items based on previous items
- Create sliding windows or batches
- Count occurrences during iteration
- Calculate running statistics

### Memory Considerations

Stateful iterators can require allocation for:

- Hash maps (counting occurrences)
- Buffers (windowing)
- History (lookback patterns)

Always provide `deinit()` methods when your iterator allocates:

```zig
pub fn CountingIterator(comptime T: type) type {
    return struct {
        occurrence_count: std.AutoHashMap(T, usize),
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) !Self {
            return Self{
                .occurrence_count =
                    std.AutoHashMap(T, usize).init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.occurrence_count.deinit();
        }

        // ... next() implementation
    };
}
```

### Composing Stateful Iterators

Stateful iterators can be chained for complex processing:

```zig
// Filter odd numbers, then compute statistics
const isOdd = struct {
    fn f(x: i32) bool {
        return @rem(x, 2) != 0;
    }
}.f;

var filter = FilterIterator(i32).init(&items, isOdd);

var odd_values: [100]i32 = undefined;
var i: usize = 0;
while (filter.next()) |val| : (i += 1) {
    odd_values[i] = val;
}

var stats = StatsIterator(i32).init(odd_values[0..i]).?;
while (stats.next()) |_| {}

const avg = stats.getAverage();
```

### Reset and Reuse

For iterators over immutable data, provide a `reset()` method:

```zig
pub fn reset(self: *Self) void {
    self.index = 0;
    self.count = 0;
    // Reset other state fields
}
```

This allows reusing the iterator without reallocating.

### Comparison with Other Languages

**Python generators** use `yield` to maintain state implicitly:
```python
def fibonacci(max_val):
    a, b = 0, 1
    count = 0
    while a <= max_val:
        yield a
        count += 1
        a, b = b, a + b
```

**Zig's approach** makes state explicit in the struct, giving you more control over state access and no hidden allocations.

## See Also

- `code/02-core/04-iterators-generators/recipe_4_6.zig` - Full implementations and tests
- Recipe 4.1: Manually consuming an iterator
- Recipe 4.3: Creating new iteration patterns
- Recipe 4.7: Taking a slice of an iterator
