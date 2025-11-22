## Problem

You need to transform data and then combine it into a single result, like calculating the sum of squares or building complex aggregations from collections.

## Solution

Zig doesn't have built-in `map().reduce()` chains, but you can implement efficient transform-reduce operations using explicit loops or fold functions.

### Single-Pass Transform and Reduce

The most efficient approach combines transformation and reduction in one loop:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_19.zig:transform_reduce}}
```

### Fold Left (Sequential Reduction)

For more complex reductions with state, use a fold operation:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_19.zig:fold_left}}
```

### Idiomatic Zig: Explicit Loops

For simple cases, Zig prefers explicit for-loops over functional abstractions:

```zig
const numbers = [_]i32{ 1, 2, 3, 4, 5 };

// Calculate: sum of (n * 2) for even numbers only
var sum: i32 = 0;
for (numbers) |n| {
    if (@mod(n, 2) == 0) {
        sum += n * 2;
    }
}
// Result: 12 ((2*2) + (4*2))
```

This is clearer than chained operations and makes performance characteristics obvious.

### Filtering and Reducing Combined

Combine filtering with reduction using a stateful fold:

```zig
// Sum of squares of even numbers
const FilterReduceState = struct {
    sum: i32,
};

const processEven = struct {
    fn f(state: FilterReduceState, n: i32) FilterReduceState {
        if (@mod(n, 2) == 0) {
            return .{ .sum = state.sum + (n * n) };
        }
        return state;
    }
}.f;

const numbers = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
const result = foldl(i32, FilterReduceState, &numbers, .{ .sum = 0 }, processEven);
// result.sum is 220 (4+16+36+64+100)
```

### String Building with Fold

Fold works well for building strings:

```zig
const words = [_][]const u8{ "Hello", "Zig", "World" };

const Acc = struct {
    buf: [100]u8 = undefined,
    len: usize = 0,

    fn addWord(self: @This(), word: []const u8) @This() {
        var result = self;

        // Add space if not first word
        if (result.len > 0) {
            result.buf[result.len] = ' ';
            result.len += 1;
        }

        // Copy word
        @memcpy(result.buf[result.len..][0..word.len], word);
        result.len += word.len;

        return result;
    }
};

const concat = struct {
    fn f(acc: Acc, word: []const u8) Acc {
        return acc.addWord(word);
    }
}.f;

const result = foldl([]const u8, Acc, &words, Acc{}, concat);
// result.buf[0..result.len] is "Hello Zig World"
```

## Discussion

### Why Not Method Chaining?

Languages like JavaScript or Python use method chaining:

```javascript
// JavaScript
const sum = numbers
  .map(x => x * x)
  .reduce((a, b) => a + b, 0);
```

Zig prefers explicit operations for several reasons:

1. **No hidden allocations** - Each step's memory cost is visible
2. **Clear error handling** - Errors at each step are explicit
3. **Performance transparency** - You can see if operations combine or require multiple passes
4. **Easier to debug** - Step through clear code, not chains

### Performance: Single-Pass vs Two-Pass

**Single-pass `transformReduce`:**
- O(n) time, O(1) space
- No intermediate allocations
- Fastest approach when you don't need intermediate values

**Two-pass (map then reduce):**
- O(n) time, O(n) space
- Creates intermediate array
- Use when you need the transformed values separately

### Fold Left vs Fold Right

**Fold Left** (`foldl`) processes left-to-right:
```zig
foldl([1, 2, 3], 0, add) // ((0 + 1) + 2) + 3
```

**Fold Right** (`foldr`) processes right-to-left:
```zig
foldr([1, 2, 3], 0, add) // 1 + (2 + (3 + 0))
```

For associative operations (like addition), order doesn't matter. For non-associative operations (like division or string building), it does.

### Accumulator Patterns

The accumulator can be any type:

- **Simple value** - `i32`, `f32` for sums, products
- **Struct** - Multiple aggregations (min, max, sum, count)
- **Buffer** - String building, data collection
- **HashMap** - Grouping, counting, indexing

### Memory Safety

`transformReduce` and `foldl` don't allocate memory, so there's no manual cleanup needed. If your accumulator contains allocations, manage them explicitly:

```zig
var acc = Accumulator.init(allocator);
defer acc.deinit();

const result = foldl(T, Accumulator, &items, acc, func);
```

### Comparison with Functional Languages

Unlike Haskell or Clojure where lazy evaluation and function composition are idiomatic, Zig emphasizes:

- **Explicit control flow** - No hidden operations
- **Zero overhead** - Compiles to tight loops
- **Predictable performance** - No unexpected allocations or thunks

This makes Zig ideal for systems programming where understanding exactly what the code does is critical.

### When to Use Each Approach

**Use `transformReduce`** for simple transform-then-combine operations where you don't need intermediate values.

**Use `foldl`** when you need complex state or want a general-purpose reduction.

**Use explicit loops** for clarity in simple cases or when logic doesn't fit a functional pattern.

**Use two-pass** only when you genuinely need both the intermediate and final results.
