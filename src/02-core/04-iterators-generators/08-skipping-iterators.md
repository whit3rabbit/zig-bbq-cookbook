## Problem

You need to skip over initial items in an iterator based on a count, predicate, or pattern before processing the remaining items.

## Solution

Build iterators that advance past unwanted items before yielding results.

### Skip Iterator

```zig
{{#include ../../../code/02-core/04-iterators-generators/recipe_4_8.zig:skip_iterator}}
```

### Skip While and Until

```zig
{{#include ../../../code/02-core/04-iterators-generators/recipe_4_8.zig:skip_while_until}}
```

### Advanced Skip Patterns

```zig
{{#include ../../../code/02-core/04-iterators-generators/recipe_4_8.zig:advanced_skip_patterns}}
```

### Skip While Predicate is True

```zig
pub fn SkipWhile(comptime T: type) type {
    return struct {
        const Self = @This();
        const PredicateFn = *const fn (T) bool;

        items: []const T,
        index: usize,
        predicate: PredicateFn,
        skipping_done: bool,

        pub fn init(items: []const T, predicate: PredicateFn) Self {
            return Self{
                .items = items,
                .index = 0,
                .predicate = predicate,
                .skipping_done = false,
            };
        }

        pub fn next(self: *Self) ?T {
            if (!self.skipping_done) {
                while (self.index < self.items.len) {
                    const item = self.items[self.index];
                    if (!self.predicate(item)) {
                        self.skipping_done = true;
                        break;
                    }
                    self.index += 1;
                }
            }

            if (self.index >= self.items.len) return null;

            const item = self.items[self.index];
            self.index += 1;
            return item;
        }
    };
}

// Usage
const lessThan5 = struct {
    fn f(x: i32) bool {
        return x < 5;
    }
}.f;

var iter = SkipWhile(i32).init(&items, lessThan5);
while (iter.next()) |num| {
    std.debug.print("{} ", .{num});
}
// Output: 5 6 7 8 9 10
```

### Skip Until Predicate Becomes True

```zig
pub fn SkipUntil(comptime T: type) type {
    return struct {
        const Self = @This();
        const PredicateFn = *const fn (T) bool;

        items: []const T,
        index: usize,
        predicate: PredicateFn,
        found: bool,

        pub fn init(items: []const T, predicate: PredicateFn) Self {
            return Self{
                .items = items,
                .index = 0,
                .predicate = predicate,
                .found = false,
            };
        }

        pub fn next(self: *Self) ?T {
            if (!self.found) {
                while (self.index < self.items.len) {
                    const item = self.items[self.index];
                    if (self.predicate(item)) {
                        self.found = true;
                        break;
                    }
                    self.index += 1;
                }
            }

            if (self.index >= self.items.len) return null;

            const item = self.items[self.index];
            self.index += 1;
            return item;
        }
    };
}

// Usage - skip until we find a number > 5
const greaterThan5 = struct {
    fn f(x: i32) bool {
        return x > 5;
    }
}.f;

var iter = SkipUntil(i32).init(&items, greaterThan5);
// Output: 6 7 8 9 10
```

### Drop Iterator (Functional Style)

```zig
pub fn DropIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        start_index: usize,
        current_index: usize,

        pub fn init(items: []const T, drop_count: usize) Self {
            const actual_start = @min(drop_count, items.len);
            return Self{
                .items = items,
                .start_index = actual_start,
                .current_index = actual_start,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.current_index >= self.items.len) return null;

            const item = self.items[self.current_index];
            self.current_index += 1;
            return item;
        }

        pub fn reset(self: *Self) void {
            self.current_index = self.start_index;
        }

        pub fn remaining(self: *const Self) usize {
            if (self.current_index >= self.items.len) return 0;
            return self.items.len - self.current_index;
        }
    };
}
```

### Batch Skip - Take N, Skip M Pattern

```zig
pub fn BatchSkipIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        index: usize,
        take_count: usize,
        skip_count: usize,
        in_take_phase: bool,
        phase_counter: usize,

        pub fn init(
            items: []const T,
            take_count: usize,
            skip_count: usize,
        ) Self {
            return Self{
                .items = items,
                .index = 0,
                .take_count = take_count,
                .skip_count = skip_count,
                .in_take_phase = true,
                .phase_counter = 0,
            };
        }

        pub fn next(self: *Self) ?T {
            while (self.index < self.items.len) {
                if (self.in_take_phase) {
                    const item = self.items[self.index];
                    self.index += 1;
                    self.phase_counter += 1;

                    if (self.phase_counter >= self.take_count) {
                        self.in_take_phase = false;
                        self.phase_counter = 0;
                    }

                    return item;
                } else {
                    // Skip phase
                    self.index += 1;
                    self.phase_counter += 1;

                    if (self.phase_counter >= self.skip_count) {
                        self.in_take_phase = true;
                        self.phase_counter = 0;
                    }
                }
            }
            return null;
        }
    };
}

// Usage - take 2, skip 2, take 2, skip 2, ...
const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };
var iter = BatchSkipIterator(i32).init(&items, 2, 2);
// Output: 1 2 5 6 9 10
```

## Discussion

### Skip vs Drop Terminology

While similar, these terms have subtle differences:

- **Skip** - Advance past items, typically once at the start
- **Drop** - Functional programming term, often resettable

Both achieve the same goal but may have different API surfaces.

### Skip While vs Skip Until

The distinction is important:

- **SkipWhile** - Skip AS LONG AS predicate is true
- **SkipUntil** - Skip UNTIL predicate becomes true

```zig
const items = [_]i32{ 1, 2, 3, 4, 5 };

// Skip while < 3: yields [3, 4, 5]
const lessThan3 = struct {
    fn f(x: i32) bool { return x < 3; }
}.f;
var skip_while = SkipWhile(i32).init(&items, lessThan3);

// Skip until > 2: yields [3, 4, 5]
const greaterThan2 = struct {
    fn f(x: i32) bool { return x > 2; }
}.f;
var skip_until = SkipUntil(i32).init(&items, greaterThan2);
```

### Combining Skip and Take

Create powerful slicing by combining operations:

```zig
// Skip 5, then take 3
var skip_iter = SkipIterator(i32).init(&items, 5);

var collected: [3]i32 = undefined;
var i: usize = 0;
while (i < 3) : (i += 1) {
    if (skip_iter.next()) |item| {
        collected[i] = item;
    }
}
```

This is equivalent to array slicing `items[5..8]` but works with any iterator.

### Use Cases

**Data processing:**
```zig
// Skip CSV header
var iter = SkipIterator([]const u8).init(lines, 1);
```

**Windowing:**
```zig
// Skip warmup period in performance data
var iter = SkipIterator(f64).init(measurements, warmup_count);
```

**Pagination:**
```zig
// Skip to page
const page_size = 20;
const page_num = 3;
var iter = SkipIterator(Item).init(items, page_size * page_num);
```

**Pattern matching:**
```zig
// Skip leading whitespace
const isWhitespace = struct {
    fn f(c: u8) bool {
        return c == ' ' or c == '\t' or c == '\n';
    }
}.f;
var iter = SkipWhile(u8).init(text, isWhitespace);
```

### Performance Considerations

Skipping is O(1) for count-based operations:

```zig
// Constant time skip
pub fn init(items: []const T, skip_count: usize) Self {
    const actual_start = @min(skip_count, items.len);
    return Self{
        .items = items,
        .start_index = actual_start,
        .current_index = actual_start,
    };
}
```

Predicate-based skipping is O(n) where n is items skipped:

```zig
// Linear in skipped items
while (self.index < self.items.len) {
    if (!self.predicate(self.items[self.index])) break;
    self.index += 1;
}
```

### Edge Cases

Always handle:

- **Skip count > length** - Return empty iterator
- **Skip zero items** - Return all items
- **Predicate always true** - Skip all items
- **Predicate always false** - Skip no items

```zig
pub fn init(items: []const T, skip_count: usize) Self {
    // Clamp to valid range
    return Self{
        .skip_count = @min(skip_count, items.len),
        // ...
    };
}
```

### Comparison with Other Languages

**Python:**
```python
from itertools import islice, dropwhile

# Skip first 5
list(islice(items, 5, None))

# Skip while
list(dropwhile(lambda x: x < 5, items))
```

**Rust:**
```rust
items.iter().skip(5)
items.iter().skip_while(|x| x < 5)
```

**Zig's approach** provides explicit control without method chaining magic, making the iteration cost visible.

## See Also

- `code/02-core/04-iterators-generators/recipe_4_8.zig` - Full implementations and tests
- Recipe 4.7: Taking a slice of an iterator
- Recipe 4.6: Defining generators with extra state
- Recipe 4.13: Creating data processing pipelines
