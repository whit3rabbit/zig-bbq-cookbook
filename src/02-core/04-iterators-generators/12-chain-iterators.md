## Problem

You need to iterate over multiple separate sequences as if they were a single continuous sequence, without copying data into a new container.

## Solution

### Basic Chain

```zig
{{#include ../../../code/02-core/04-iterators-generators/recipe_4_12.zig:basic_chain}}
```

### Interleave Chain

```zig
{{#include ../../../code/02-core/04-iterators-generators/recipe_4_12.zig:interleave_chain}}
```

### Cycle Iterator

```zig
{{#include ../../../code/02-core/04-iterators-generators/recipe_4_12.zig:cycle_iterator}}
```

## Original Solution

Build chain iterators that track position across multiple sequences, switching between them as each is exhausted.

### Chain Two Sequences

```zig
pub fn Chain2(comptime T: type) type {
    return struct {
        const Self = @This();

        first: []const T,
        second: []const T,
        index: usize,

        pub fn init(first: []const T, second: []const T) Self {
            return Self{
                .first = first,
                .second = second,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.index < self.first.len) {
                const item = self.first[self.index];
                self.index += 1;
                return item;
            }

            const second_index = self.index - self.first.len;
            if (second_index < self.second.len) {
                const item = self.second[second_index];
                self.index += 1;
                return item;
            }

            return null;
        }

        pub fn remaining(self: *const Self) usize {
            const total = self.first.len + self.second.len;
            if (self.index >= total) return 0;
            return total - self.index;
        }
    };
}

// Usage
const first = [_]i32{ 1, 2, 3 };
const second = [_]i32{ 4, 5, 6 };

var iter = Chain2(i32).init(&first, &second);
while (iter.next()) |item| {
    std.debug.print("{} ", .{item});
}
// Output: 1 2 3 4 5 6
```

### Chain Many Sequences

```zig
pub fn ChainMany(comptime T: type) type {
    return struct {
        const Self = @This();

        sequences: []const []const T,
        sequence_index: usize,
        item_index: usize,

        pub fn init(sequences: []const []const T) Self {
            return Self{
                .sequences = sequences,
                .sequence_index = 0,
                .item_index = 0,
            };
        }

        pub fn next(self: *Self) ?T {
            while (self.sequence_index < self.sequences.len) {
                const current_seq = self.sequences[self.sequence_index];

                if (self.item_index < current_seq.len) {
                    const item = current_seq[self.item_index];
                    self.item_index += 1;
                    return item;
                }

                // Move to next sequence
                self.sequence_index += 1;
                self.item_index = 0;
            }

            return null;
        }
    };
}

// Usage - chain 4 sequences
const seq1 = [_]i32{ 1, 2 };
const seq2 = [_]i32{ 3, 4 };
const seq3 = [_]i32{ 5, 6 };
const seq4 = [_]i32{ 7, 8 };

const sequences = [_][]const i32{ &seq1, &seq2, &seq3, &seq4 };
var iter = ChainMany(i32).init(&sequences);
// Yields: 1, 2, 3, 4, 5, 6, 7, 8
```

### Flatten Nested Sequences

```zig
pub fn Flatten(comptime T: type) type {
    return struct {
        const Self = @This();

        sequences: []const []const T,
        outer_index: usize,
        inner_index: usize,

        pub fn init(sequences: []const []const T) Self {
            return Self{
                .sequences = sequences,
                .outer_index = 0,
                .inner_index = 0,
            };
        }

        pub fn next(self: *Self) ?T {
            while (self.outer_index < self.sequences.len) {
                const current = self.sequences[self.outer_index];

                if (self.inner_index < current.len) {
                    const item = current[self.inner_index];
                    self.inner_index += 1;
                    return item;
                }

                self.outer_index += 1;
                self.inner_index = 0;
            }

            return null;
        }
    };
}

// Usage
const matrix = [_][]const i32{
    &[_]i32{ 1, 2, 3 },
    &[_]i32{ 4, 5 },
    &[_]i32{ 6, 7, 8, 9 },
};

var iter = Flatten(i32).init(&matrix);
// Yields: 1, 2, 3, 4, 5, 6, 7, 8, 9
```

### Interleave - Alternate Between Sequences

```zig
pub fn Interleave(comptime T: type) type {
    return struct {
        const Self = @This();

        first: []const T,
        second: []const T,
        index: usize,
        take_from_first: bool,

        pub fn init(first: []const T, second: []const T) Self {
            return Self{
                .first = first,
                .second = second,
                .index = 0,
                .take_from_first = true,
            };
        }

        pub fn next(self: *Self) ?T {
            while (self.index < self.first.len or
                   self.index < self.second.len) {
                if (self.take_from_first) {
                    self.take_from_first = false;
                    if (self.index < self.first.len) {
                        return self.first[self.index];
                    }
                } else {
                    self.take_from_first = true;
                    const item = if (self.index < self.second.len)
                        self.second[self.index]
                    else
                        null;
                    self.index += 1;
                    if (item != null) return item;
                }
            }

            return null;
        }
    };
}

// Usage
const a = [_]i32{ 1, 2, 3, 4 };
const b = [_]i32{ 10, 20, 30, 40 };

var iter = Interleave(i32).init(&a, &b);
// Yields: 1, 10, 2, 20, 3, 30, 4, 40
```

### Round-Robin - Fair Distribution

```zig
pub fn RoundRobin(comptime T: type) type {
    return struct {
        const Self = @This();

        sequences: []const []const T,
        sequence_index: usize,
        position: usize,

        pub fn init(sequences: []const []const T) Self {
            return Self{
                .sequences = sequences,
                .sequence_index = 0,
                .position = 0,
            };
        }

        pub fn next(self: *Self) ?T {
            // Take one from each sequence in turn
            // ...implementation...
        }
    };
}

// Usage
const seq1 = [_]i32{ 1, 2, 3 };
const seq2 = [_]i32{ 10, 20, 30 };
const seq3 = [_]i32{ 100, 200, 300 };

const sequences = [_][]const i32{ &seq1, &seq2, &seq3 };
var iter = RoundRobin(i32).init(&sequences);
// Yields: 1, 10, 100, 2, 20, 200, 3, 30, 300
```

### Cycle - Repeat Sequence

```zig
pub fn Cycle(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        index: usize,
        cycles_completed: usize,
        max_cycles: ?usize,

        pub fn init(items: []const T, max_cycles: ?usize) Self {
            return Self{
                .items = items,
                .index = 0,
                .cycles_completed = 0,
                .max_cycles = max_cycles,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.items.len == 0) return null;

            if (self.max_cycles) |max| {
                if (self.cycles_completed >= max) return null;
            }

            const item = self.items[self.index];
            self.index += 1;

            if (self.index >= self.items.len) {
                self.index = 0;
                self.cycles_completed += 1;
            }

            return item;
        }
    };
}

// Usage
const pattern = [_]i32{ 1, 2, 3 };

var iter = Cycle(i32).init(&pattern, 2);
// Yields: 1, 2, 3, 1, 2, 3 (then stops)
```

## Discussion

### Chain vs Concat

**Chain (lazy):**
- No allocation
- Iterates over original sequences
- Zero-copy operation
- Efficient for large sequences

**Concat (eager):**
```zig
// Requires allocation
var result = try std.ArrayList(i32).init(allocator);
try result.appendSlice(first);
try result.appendSlice(second);
```

Use chain when you only need to iterate once. Use concat when you need random access to the combined sequence.

### Common Patterns

**Processing multiple files:**
```zig
const file1_data = try readFile("file1.txt");
const file2_data = try readFile("file2.txt");
const file3_data = try readFile("file3.txt");

const all_data = [_][]const u8{ file1_data, file2_data, file3_data };
var iter = ChainMany(u8).init(&all_data);

while (iter.next()) |byte| {
    processData(byte);
}
```

**Combining results:**
```zig
const results1 = try queryDatabase(connection1);
const results2 = try queryDatabase(connection2);

var iter = Chain2(Result).init(results1, results2);
while (iter.next()) |result| {
    displayResult(result);
}
```

**Building sequences:**
```zig
const header = [_]u8{ 0xFF, 0xFE };
const body = try generateBody();
const footer = [_]u8{ 0x00, 0x00 };

var iter = Chain3(u8).init(&header, body, &footer);
// Yields complete packet
```

### Performance Considerations

Chaining is O(1) memory and O(1) per item:

```zig
// No allocation, just bookkeeping
pub fn init(first: []const T, second: []const T) Self {
    return Self{
        .first = first,
        .second = second,
        .index = 0,
    };
}
```

Compared to concatenation which is O(n) memory and O(n) copy cost.

### Empty Sequence Handling

Chain iterators gracefully handle empty sequences:

```zig
const empty: []const i32 = &[_]i32{};
const items = [_]i32{ 1, 2, 3 };

var iter = Chain2(i32).init(empty, &items);
// Yields: 1, 2, 3 (empty sequence skipped)
```

### Interleave vs Round-Robin

**Interleave:** Alternates between two sequences, continuing with remaining items when one exhausts

```zig
[1, 2] + [a, b, c, d] → [1, a, 2, b, c, d]
```

**Round-Robin:** Takes one from each in turn, stops when all exhausted at same position

```zig
[1, 2, 3] + [a, b, c] → [1, a, 2, b, 3, c]
```

### Cycle Use Cases

**Repeating patterns:**
```zig
const colors = [_][]const u8{ "red", "green", "blue" };
var iter = Cycle([]const u8).init(&colors, null);

for (items, 0..) |item, i| {
    const color = iter.next().?;
    displayWithColor(item, color);
}
```

**Round-robin scheduling:**
```zig
const servers = [_]Server{ server1, server2, server3 };
var iter = Cycle(Server).init(&servers, null);

for (requests) |request| {
    const server = iter.next().?;
    try server.handle(request);
}
```

### Comparison with Other Languages

**Python:**
```python
from itertools import chain, cycle

# Chain
list(chain([1, 2], [3, 4], [5, 6]))

# Cycle
list(islice(cycle([1, 2, 3]), 9))
```

**Rust:**
```rust
let chained = vec1.iter().chain(vec2.iter());
let cycled = vec.iter().cycle().take(10);
```

**Zig's approach** provides explicit iterator types with no hidden allocations, making the cost model clear.

### Type Safety

All chain operations maintain type safety:

```zig
// This won't compile - type mismatch
const ints = [_]i32{ 1, 2, 3 };
const floats = [_]f64{ 1.5, 2.5 };

// Error: expected '[]const i32', found '[]const f64'
var iter = Chain2(i32).init(&ints, &floats);
```

### Edge Cases

**All empty sequences:**
```zig
const empty1: []const i32 = &[_]i32{};
const empty2: []const i32 = &[_]i32{};

var iter = Chain2(i32).init(empty1, empty2);
// Immediately returns null
```

**Single-item cycle:**
```zig
const single = [_]i32{42};
var iter = Cycle(i32).init(&single, 3);
// Yields: 42, 42, 42
```

## See Also

- `code/02-core/04-iterators-generators/recipe_4_12.zig` - Full implementations and tests
- Recipe 4.11: Iterating over multiple sequences simultaneously (Zip)
- Recipe 4.7: Taking a slice of an iterator
- Recipe 4.13: Creating data processing pipelines
