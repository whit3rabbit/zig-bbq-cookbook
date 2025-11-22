## Problem

You need to iterate over two or more sequences simultaneously, pairing or combining values at corresponding positions.

## Solution

### Basic Zip

```zig
{{#include ../../../code/02-core/04-iterators-generators/recipe_4_11.zig:basic_zip}}
```

### Strategic Zip

```zig
{{#include ../../../code/02-core/04-iterators-generators/recipe_4_11.zig:strategic_zip}}
```

### Advanced Zip

```zig
{{#include ../../../code/02-core/04-iterators-generators/recipe_4_11.zig:advanced_zip}}
```

## Original Solution

Use Zig's built-in multi-array `for` loop syntax, or build custom zip iterators for more control over length handling and transformation.

### Zig's Built-in Multi-Array Iteration

Zig 0.11+ provides elegant syntax for iterating multiple arrays:

```zig
const names = [_][]const u8{ "Alice", "Bob", "Carol" };
const ages = [_]u32{ 30, 25, 35 };

for (names, ages) |name, age| {
    std.debug.print("{} is {} years old\n", .{ name, age });
}
// Output:
// Alice is 30 years old
// Bob is 25 years old
// Carol is 35 years old
```

This is the recommended approach for most cases with arrays of equal length.

### Custom Zip2 Iterator

For reusable patterns or different-length handling:

```zig
pub fn Zip2(comptime T1: type, comptime T2: type) type {
    return struct {
        const Self = @This();

        pub const Pair = struct {
            first: T1,
            second: T2,
        };

        items1: []const T1,
        items2: []const T2,
        index: usize,

        pub fn init(items1: []const T1, items2: []const T2) Self {
            return Self{
                .items1 = items1,
                .items2 = items2,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?Pair {
            const min_len = @min(self.items1.len, self.items2.len);
            if (self.index >= min_len) return null;

            const pair = Pair{
                .first = self.items1[self.index],
                .second = self.items2[self.index],
            };
            self.index += 1;
            return pair;
        }
    };
}

// Usage
const numbers = [_]i32{ 1, 2, 3, 4, 5 };
const letters = [_]u8{ 'a', 'b', 'c', 'd', 'e' };

var iter = Zip2(i32, u8).init(&numbers, &letters);
while (iter.next()) |pair| {
    std.debug.print("{} -> {c}\n", .{
        pair.first,
        pair.second
    });
}
```

### Zip3 for Three Sequences

```zig
pub fn Zip3(
    comptime T1: type,
    comptime T2: type,
    comptime T3: type
) type {
    return struct {
        const Self = @This();

        pub const Triple = struct {
            first: T1,
            second: T2,
            third: T3,
        };

        items1: []const T1,
        items2: []const T2,
        items3: []const T3,
        index: usize,

        pub fn init(
            items1: []const T1,
            items2: []const T2,
            items3: []const T3,
        ) Self {
            return Self{
                .items1 = items1,
                .items2 = items2,
                .items3 = items3,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?Triple {
            const min_len = @min(
                @min(self.items1.len, self.items2.len),
                self.items3.len,
            );
            if (self.index >= min_len) return null;

            const triple = Triple{
                .first = self.items1[self.index],
                .second = self.items2[self.index],
                .third = self.items3[self.index],
            };
            self.index += 1;
            return triple;
        }
    };
}
```

### Strategic Zipping - Handle Different Lengths

```zig
pub const ZipStrategy = enum {
    shortest, // Stop at shortest sequence
    longest,  // Continue until longest (with optionals)
    exact,    // Require exact length match
};

pub fn ZipStrategic(
    comptime T1: type,
    comptime T2: type,
    comptime strategy: ZipStrategy
) type {
    return struct {
        // ...

        pub fn init(
            items1: []const T1,
            items2: []const T2
        ) !Self {
            if (strategy == .exact and items1.len != items2.len) {
                return error.LengthMismatch;
            }
            // ...
        }

        pub fn next(self: *Self) ?Pair {
            switch (strategy) {
                .shortest, .exact => {
                    const min_len = @min(
                        self.items1.len,
                        self.items2.len
                    );
                    // Stop at shortest
                },
                .longest => {
                    const max_len = @max(
                        self.items1.len,
                        self.items2.len
                    );
                    // Continue with nulls for shorter
                    const pair = Pair{
                        .first = if (self.index < self.items1.len)
                            self.items1[self.index]
                        else
                            null,
                        .second = if (self.index < self.items2.len)
                            self.items2[self.index]
                        else
                            null,
                    };
                    // ...
                },
            }
        }
    };
}

// Usage
const short = [_]i32{ 1, 2, 3 };
const long = [_]i32{ 10, 20, 30, 40, 50 };

// Shortest: 3 pairs
var iter1 = try ZipStrategic(i32, i32, .shortest)
    .init(&short, &long);

// Longest: 5 pairs (with nulls)
var iter2 = try ZipStrategic(i32, i32, .longest)
    .init(&short, &long);

// Exact: error on mismatch
var iter3 = ZipStrategic(i32, i32, .exact)
    .init(&short, &long); // Returns error.LengthMismatch
```

### Zip with Index

```zig
pub fn ZipWithIndex(comptime T1: type, comptime T2: type) type {
    return struct {
        pub const IndexedPair = struct {
            index: usize,
            first: T1,
            second: T2,
        };

        // ... implementation
    };
}

// Usage
var iter = ZipWithIndex(i32, u8).init(&numbers, &letters);
while (iter.next()) |item| {
    std.debug.print("[{}] {} -> {}\n", .{
        item.index,
        item.first,
        item.second
    });
}
```

### Zip and Transform

```zig
pub fn ZipMap(
    comptime T1: type,
    comptime T2: type,
    comptime R: type
) type {
    return struct {
        const MapFn = *const fn (T1, T2) R;

        items1: []const T1,
        items2: []const T2,
        map_fn: MapFn,

        // ... implementation
    };
}

// Usage - combine and sum
const add = struct {
    fn f(x: i32, y: i32) i32 {
        return x + y;
    }
}.f;

var iter = ZipMap(i32, i32, i32).init(&a, &b, add);
while (iter.next()) |sum| {
    std.debug.print("{} ", .{sum});
}
```

### Unzip - Split Pairs

```zig
pub fn unzip(
    comptime T1: type,
    comptime T2: type,
    allocator: std.mem.Allocator,
    pairs: []const struct { T1, T2 }
) !struct { []T1, []T2 } {
    var first = try allocator.alloc(T1, pairs.len);
    errdefer allocator.free(first);

    var second = try allocator.alloc(T2, pairs.len);
    errdefer allocator.free(second);

    for (pairs, 0..) |pair, i| {
        first[i] = pair[0];
        second[i] = pair[1];
    }

    return .{ first, second };
}

// Usage
const pairs = [_]struct { i32, u8 }{
    .{ 1, 'a' },
    .{ 2, 'b' },
    .{ 3, 'c' },
};

const result = try unzip(i32, u8, allocator, &pairs);
defer allocator.free(result[0]);
defer allocator.free(result[1]);

// result[0] = [1, 2, 3]
// result[1] = ['a', 'b', 'c']
```

## Discussion

### When to Use Built-in vs Custom

**Use built-in `for` loop when:**
- Arrays have same length (or you don't care about extra items)
- Iterating once without interruption
- Simple direct access patterns

**Use custom iterator when:**
- Need to pause/resume iteration
- Different length handling strategies required
- Composing with other iterators
- Need to track remaining items

### Common Patterns

**Parallel processing:**
```zig
const inputs = [_]f64{ 1.0, 2.0, 3.0 };
const weights = [_]f64{ 0.5, 0.3, 0.2 };

var sum: f64 = 0.0;
for (inputs, weights) |input, weight| {
    sum += input * weight;
}
```

**Building lookup tables:**
```zig
var map = std.StringHashMap(i32).init(allocator);
for (keys, values) |key, value| {
    try map.put(key, value);
}
```

**Coordinate iteration:**
```zig
const xs = [_]f64{ 1.0, 2.0, 3.0 };
const ys = [_]f64{ 4.0, 5.0, 6.0 };

for (xs, ys) |x, y| {
    const distance = @sqrt(x * x + y * y);
    std.debug.print("({}, {}) -> {}\n", .{ x, y, distance });
}
```

### Length Mismatch Strategies

**1. Shortest (default):** Stop when any sequence ends
```zig
[1, 2, 3] + [a, b, c, d, e] = [(1,a), (2,b), (3,c)]
```

**2. Longest:** Pad with nulls
```zig
[1, 2, 3] + [a, b, c, d, e] =
    [(1,a), (2,b), (3,c), (null,d), (null,e)]
```

**3. Exact:** Error on mismatch (for safety)
```zig
[1, 2, 3] + [a, b, c, d] = error.LengthMismatch
```

### Performance Considerations

Built-in multi-array iteration is zero-cost:

```zig
// These produce identical machine code
for (a, b) |x, y| {
    process(x, y);
}

var i: usize = 0;
while (i < a.len and i < b.len) : (i += 1) {
    process(a[i], b[i]);
}
```

Custom iterators inline well with small overhead.

### Type Safety

Zig's zip maintains type safety:

```zig
const ints = [_]i32{ 1, 2, 3 };
const floats = [_]f64{ 1.5, 2.5, 3.5 };

var iter = Zip2(i32, f64).init(&ints, &floats);
while (iter.next()) |pair| {
    // pair.first is i32
    // pair.second is f64
    // No implicit conversions
}
```

### Comparison with Other Languages

**Python:**
```python
for x, y in zip(list1, list2):
    print(x, y)

# With strict length checking
from itertools import zip_longest
for x, y in zip_longest(list1, list2, fillvalue=None):
    print(x, y)
```

**Rust:**
```rust
for (x, y) in list1.iter().zip(list2.iter()) {
    println!("{} {}", x, y);
}
```

**C:**
```c
for (size_t i = 0; i < len1 && i < len2; i++) {
    process(list1[i], list2[i]);
}
```

**Zig's approach** provides both the ergonomics of Python/Rust and the explicitness of C, with no hidden allocations or complexity.

### Edge Cases

**Empty sequences:**
```zig
const empty: []const i32 = &[_]i32{};
const items = [_]i32{ 1, 2, 3 };

for (empty, items) |_, _| {
    // Never executes
}
```

**Single item:**
```zig
const single = [_]i32{42};
const multi = [_]i32{ 1, 2, 3 };

for (single, multi) |x, y| {
    // Executes once: (42, 1)
}
```

## See Also

- `code/02-core/04-iterators-generators/recipe_4_11.zig` - Full implementations and tests
- Recipe 4.10: Iterating over index-value pairs
- Recipe 4.12: Chain iterators (separate containers)
- Recipe 4.13: Creating data processing pipelines
