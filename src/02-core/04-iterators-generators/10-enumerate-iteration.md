## Problem

You need to iterate over a sequence while keeping track of item indices, similar to Python's `enumerate()` or tracking loop counters.

## Solution

### Enumerate Iterator

```zig
{{#include ../../../code/02-core/04-iterators-generators/recipe_4_10.zig:enumerate_iterator}}
```

### Enumerate Variants

```zig
{{#include ../../../code/02-core/04-iterators-generators/recipe_4_10.zig:enumerate_variants}}
```

### Advanced Enumerate

```zig
{{#include ../../../code/02-core/04-iterators-generators/recipe_4_10.zig:advanced_enumerate}}
```

## Original Solution

Use Zig's built-in indexed `for` loop syntax, or build custom enumerate iterators for more complex patterns.

### Zig's Built-in Indexed For Loop

Zig 0.13+ provides elegant syntax for indexed iteration:

```zig
const items = [_]i32{ 10, 20, 30, 40, 50 };

for (items, 0..) |value, index| {
    std.debug.print("Index {}: {}\n", .{ index, value });
}
// Output:
// Index 0: 10
// Index 1: 20
// Index 2: 30
// Index 3: 40
// Index 4: 50
```

The `0..` syntax creates an infinite range that pairs with the array.

### Custom Enumerate Iterator

For reusable patterns or when working with other iterators:

```zig
pub fn EnumerateIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const Pair = struct {
            index: usize,
            value: T,
        };

        items: []const T,
        index: usize,

        pub fn init(items: []const T) Self {
            return Self{
                .items = items,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?Pair {
            if (self.index >= self.items.len) return null;

            const pair = Pair{
                .index = self.index,
                .value = self.items[self.index],
            };
            self.index += 1;
            return pair;
        }
    };
}

// Usage
var iter = EnumerateIterator(i32).init(&items);
while (iter.next()) |pair| {
    std.debug.print("Index {}: {}\n", .{
        pair.index,
        pair.value
    });
}
```

### Enumerate from Custom Start

```zig
pub fn EnumerateFrom(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const Pair = struct {
            index: usize,
            value: T,
        };

        items: []const T,
        current_index: usize,
        start_index: usize,

        pub fn init(items: []const T, start: usize) Self {
            return Self{
                .items = items,
                .current_index = 0,
                .start_index = start,
            };
        }

        pub fn next(self: *Self) ?Pair {
            if (self.current_index >= self.items.len) return null;

            const pair = Pair{
                .index = self.start_index + self.current_index,
                .value = self.items[self.current_index],
            };
            self.current_index += 1;
            return pair;
        }
    };
}

// Usage - start counting from 100
var iter = EnumerateFrom(i32).init(&items, 100);
// Yields (100, first_item), (101, second_item), ...
```

### Enumerate in Reverse

```zig
pub fn EnumerateReverse(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const Pair = struct {
            index: usize,
            value: T,
        };

        items: []const T,
        current_position: usize,

        pub fn init(items: []const T) Self {
            return Self{
                .items = items,
                .current_position = items.len,
            };
        }

        pub fn next(self: *Self) ?Pair {
            if (self.current_position == 0) return null;

            self.current_position -= 1;
            const pair = Pair{
                .index = self.current_position,
                .value = self.items[self.current_position],
            };
            return pair;
        }
    };
}

// Usage
var iter = EnumerateReverse(i32).init(&items);
// Yields items in reverse with their original indices
```

### Enumerate with Filtering

Track both original and filtered indices:

```zig
pub fn EnumerateFilter(comptime T: type) type {
    return struct {
        const Self = @This();
        const PredicateFn = *const fn (T) bool;

        pub const Pair = struct {
            original_index: usize,
            filtered_index: usize,
            value: T,
        };

        items: []const T,
        original_index: usize,
        filtered_index: usize,
        predicate: PredicateFn,

        pub fn init(items: []const T, predicate: PredicateFn) Self {
            return Self{
                .items = items,
                .original_index = 0,
                .filtered_index = 0,
                .predicate = predicate,
            };
        }

        pub fn next(self: *Self) ?Pair {
            while (self.original_index < self.items.len) {
                const item = self.items[self.original_index];
                const orig_idx = self.original_index;
                self.original_index += 1;

                if (self.predicate(item)) {
                    const pair = Pair{
                        .original_index = orig_idx,
                        .filtered_index = self.filtered_index,
                        .value = item,
                    };
                    self.filtered_index += 1;
                    return pair;
                }
            }
            return null;
        }
    };
}

// Usage
const isEven = struct {
    fn f(x: i32) bool {
        return @rem(x, 2) == 0;
    }
}.f;

var iter = EnumerateFilter(i32).init(&items, isEven);
while (iter.next()) |pair| {
    std.debug.print(
        "Original[{}] Filtered[{}]: {}\n",
        .{ pair.original_index, pair.filtered_index, pair.value }
    );
}
```

### Windowed Enumerate

Enumerate consecutive pairs:

```zig
pub fn EnumerateWindowed(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const WindowPair = struct {
            start_index: usize,
            first: T,
            second: T,
        };

        items: []const T,
        index: usize,

        pub fn init(items: []const T) Self {
            return Self{
                .items = items,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?WindowPair {
            if (self.index + 1 >= self.items.len) return null;

            const pair = WindowPair{
                .start_index = self.index,
                .first = self.items[self.index],
                .second = self.items[self.index + 1],
            };
            self.index += 1;
            return pair;
        }
    };
}

// Usage
var iter = EnumerateWindowed(i32).init(&items);
while (iter.next()) |window| {
    std.debug.print(
        "[{}]: {} -> {}\n",
        .{ window.start_index, window.first, window.second }
    );
}
```

## Discussion

### When to Use Built-in vs Iterator

**Use built-in `for` loop when:**
- Iterating over arrays/slices directly
- Index is only needed inside loop
- No complex iteration logic needed

**Use custom iterator when:**
- Composing with other iterators
- Need to pause/resume iteration
- Implementing complex enumerate patterns
- Need resettable iteration

### Common Patterns

**Find index of first match:**
```zig
for (items, 0..) |item, i| {
    if (item == target) {
        std.debug.print("Found at index {}\n", .{i});
        break;
    }
}
```

**Process items with their positions:**
```zig
for (matrix, 0..) |row, y| {
    for (row, 0..) |cell, x| {
        processCell(x, y, cell);
    }
}
```

**Build index mapping:**
```zig
var map = std.AutoHashMap(i32, usize).init(allocator);
for (items, 0..) |value, index| {
    try map.put(value, index);
}
```

### Multiple Arrays with Same Length

Zig's `for` loop can iterate multiple arrays simultaneously:

```zig
const names = [_][]const u8{ "Alice", "Bob", "Carol" };
const ages = [_]u32{ 30, 25, 35 };

for (names, ages, 0..) |name, age, i| {
    std.debug.print("{}. {} is {} years old\n", .{
        i + 1,
        name,
        age
    });
}
```

### Performance Considerations

Built-in indexing is zero-cost:

```zig
// These compile to identical machine code
for (items, 0..) |item, i| {
    process(i, item);
}

var i: usize = 0;
while (i < items.len) : (i += 1) {
    process(i, items[i]);
}
```

Custom iterators have minimal overhead when inlined.

### Comparison with Other Languages

**Python:**
```python
for index, value in enumerate(items):
    print(f"{index}: {value}")

for index, value in enumerate(items, start=1):
    print(f"{index}: {value}")
```

**Rust:**
```rust
for (index, value) in items.iter().enumerate() {
    println!("{}: {}", index, value);
}
```

**C:**
```c
for (size_t i = 0; i < len; i++) {
    process(i, items[i]);
}
```

**Zig's approach** combines C's explicitness with modern language ergonomics, making the iteration cost clear while being concise.

### Edge Cases

Handle empty sequences gracefully:

```zig
const empty: []const i32 = &[_]i32{};

// Built-in for loop handles this automatically
for (empty, 0..) |value, index| {
    // Never executes
}

// Custom iterator returns null immediately
var iter = EnumerateIterator(i32).init(empty);
try testing.expect(iter.next() == null);
```

### Memory Safety

Zig's bounds checking ensures index safety:

```zig
for (items, 0..) |item, i| {
    // i is guaranteed to be valid for items
    // items[i] == item (always true)
}
```

No risk of off-by-one errors compared to manual indexing.

## See Also

- `code/02-core/04-iterators-generators/recipe_4_10.zig` - Full implementations and tests
- Recipe 4.6: Defining generators with extra state
- Recipe 4.11: Iterating over multiple sequences simultaneously
- Recipe 1.18: Mapping names to sequence elements
