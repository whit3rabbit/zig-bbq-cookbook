# Ring Buffers and Keeping Last N Items

## Problem

You need to keep track of the last N items in a stream of data, automatically discarding older items when the buffer is full.

## Solution

Zig's standard library doesn't have a dedicated ring buffer, but you can easily implement one using a fixed-size array with wrap-around indexing:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_3.zig:ring_buffer_impl}}
```

## Discussion

### How Ring Buffers Work

A ring buffer is a fixed-size buffer that wraps around when it reaches the end. When the buffer is full, new items overwrite the oldest items:

```
Initial state (size=5):
[ _, _, _, _, _ ]  write_index=0, count=0

After pushing 1, 2, 3:
[ 1, 2, 3, _, _ ]  write_index=3, count=3

After pushing 4, 5, 6:
[ 6, 2, 3, 4, 5 ]  write_index=1, count=5
Item 1 was overwritten by item 6
```

### When to Use Ring Buffers

Ring buffers are perfect for:
- Keeping the last N log entries
- Rolling window calculations (averages, sums)
- Event history tracking
- Audio/video buffering
- Network packet buffering

### Advantages

- **Fixed memory**: No allocations after initialization
- **Constant time operations**: Both push and get are O(1)
- **Cache friendly**: Contiguous memory layout
- **Automatic overflow handling**: Old data automatically discarded

### Simple Implementation

For basic use cases, a simple array with modulo arithmetic works well:

```zig
const RecentItems = struct {
    items: [10]i32,
    next_index: usize,
    filled: bool,

    pub fn init() RecentItems {
        return .{
            .items = undefined,
            .next_index = 0,
            .filled = false,
        };
    }

    pub fn add(self: *RecentItems, item: i32) void {
        self.items[self.next_index] = item;
        self.next_index += 1;
        if (self.next_index >= self.items.len) {
            self.next_index = 0;
            self.filled = true;
        }
    }

    pub fn getRecent(self: RecentItems) []const i32 {
        if (!self.filled) {
            return self.items[0..self.next_index];
        }
        return &self.items;
    }
};
```

### With Dynamic Allocation

For variable-size ring buffers, use an ArrayList-backed implementation:

```zig
fn DynamicRingBuffer(comptime T: type) type {
    return struct {
        data: std.ArrayList(T),
        write_index: usize,
        capacity: usize,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, capacity: usize) !Self {
            var data = try std.ArrayList(T).initCapacity(allocator, capacity);
            return .{
                .data = data,
                .write_index = 0,
                .capacity = capacity,
            };
        }

        pub fn deinit(self: *Self) void {
            self.data.deinit();
        }

        pub fn push(self: *Self, item: T) !void {
            if (self.data.items.len < self.capacity) {
                try self.data.append(item);
            } else {
                self.data.items[self.write_index] = item;
            }
            self.write_index = (self.write_index + 1) % self.capacity;
        }
    };
}
```

### Rolling Window Calculations

Ring buffers are great for calculating rolling averages:

```zig
const RollingAverage = struct {
    buffer: [10]f64,
    index: usize,
    count: usize,

    pub fn init() RollingAverage {
        return .{
            .buffer = [_]f64{0.0} ** 10,
            .index = 0,
            .count = 0,
        };
    }

    pub fn add(self: *RollingAverage, value: f64) void {
        self.buffer[self.index] = value;
        self.index = (self.index + 1) % self.buffer.len;
        if (self.count < self.buffer.len) {
            self.count += 1;
        }
    }

    pub fn average(self: RollingAverage) f64 {
        if (self.count == 0) return 0.0;

        var sum: f64 = 0.0;
        for (self.buffer[0..self.count]) |val| {
            sum += val;
        }
        return sum / @as(f64, @floatFromInt(self.count));
    }
};
```

## See Also

- Recipe 1.4: Finding largest/smallest N items (different use case)
- Recipe 4.7: Taking a slice of an iterator
- Recipe 13.13: Making a stopwatch timer

Full compilable example: `code/02-core/01-data-structures/recipe_1_3.zig`
