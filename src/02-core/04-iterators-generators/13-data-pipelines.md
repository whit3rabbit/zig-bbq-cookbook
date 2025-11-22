## Problem

You need to perform multiple transformations and filters on data efficiently without creating intermediate collections or repeated iterations.

## Solution

### Pipeline Builder

```zig
{{#include ../../../code/02-core/04-iterators-generators/recipe_4_13.zig:pipeline_builder}}
```

### Pipeline Stages

```zig
{{#include ../../../code/02-core/04-iterators-generators/recipe_4_13.zig:pipeline_stages}}
```

### Pipeline Composition

```zig
{{#include ../../../code/02-core/04-iterators-generators/recipe_4_13.zig:pipeline_composition}}
```

## Original Solution

Build composable iterator pipelines that chain operations together, processing data in a single pass.

var pipeline = Pipeline(i32).init(&items).map(i32, double);

while (pipeline.next()) |value| {
    std.debug.print("{} ", .{value});
}
// Output: 2 4 6 8 10
```

### Filter Pipeline

```zig
// Filter even numbers
const isEven = struct {
    fn f(x: i32) bool {
        return @rem(x, 2) == 0;
    }
}.f;

var pipeline = Pipeline(i32).init(&items).filter(isEven);

while (pipeline.next()) |value| {
    std.debug.print("{} ", .{value});
}
```

### Chained Map Operations

```zig
const double = struct {
    fn f(x: i32) i32 {
        return x * 2;
    }
}.f;

const addTen = struct {
    fn f(x: i32) i32 {
        return x + 10;
    }
}.f;

var pipeline = Pipeline(i32).init(&items)
    .map(i32, double)
    .map(i32, addTen);

while (pipeline.next()) |value| {
    std.debug.print("{} ", .{value});
}
// Output: 12 14 16 18 20 (each item doubled then +10)
```

### Filter Then Map

```zig
const isEven = struct {
    fn f(x: i32) bool {
        return @rem(x, 2) == 0;
    }
}.f;

const square = struct {
    fn f(x: i32) i32 {
        return x * x;
    }
}.f;

// Filter even numbers, then square them
var pipeline = Pipeline(i32).init(&items)
    .filter(isEven)
    .map(i32, square);

// Yields: 4, 16, 36, 64 (2², 4², 6², 8²)
```

### Map Then Filter

```zig
const double = struct {
    fn f(x: i32) i32 {
        return x * 2;
    }
}.f;

const greaterThan5 = struct {
    fn f(x: i32) bool {
        return x > 5;
    }
}.f;

// Double all numbers, then filter those > 5
var pipeline = Pipeline(i32).init(&items)
    .map(i32, double)
    .filter(greaterThan5);

// Yields: 6, 8, 10, 12, 14, 16 (doubled values > 5)
```

### Take and Skip in Pipelines

```zig
// Skip first 5, take next 3
var pipeline = Pipeline(i32).init(&items)
    .skip(5)
    .take(3);

// Or: filter then take first 5 matches
var pipeline2 = Pipeline(i32).init(&items)
    .filter(isEven)
    .take(5);
```

### Complex Composition

```zig
const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

const isEven = struct {
    fn f(x: i32) bool {
        return @rem(x, 2) == 0;
    }
}.f;

const doubleAndAddFive = struct {
    fn f(x: i32) i32 {
        return (x * 2) + 5;
    }
}.f;

// Filter even numbers, then transform them
var pipeline = Pipeline(i32).init(&items)
    .filter(isEven)
    .map(i32, doubleAndAddFive);

// Yields: 9, 13, 17, 21, 25
// (2*2)+5, (4*2)+5, (6*2)+5, (8*2)+5, (10*2)+5
```

### Collecting Results

```zig
pub fn MapPipeline(comptime T: type, comptime R: type) type {
    return struct {
        pub fn collectSlice(
            self: *Self,
            allocator: std.mem.Allocator
        ) ![]R {
            var list = try allocator.alloc(R, self.items.len);
            var idx: usize = 0;
            while (self.next()) |item| : (idx += 1) {
                list[idx] = item;
            }
            return list[0..idx];
        }
    };
}

// Usage
var pipeline = Pipeline(i32).init(&items).map(i32, double);

const result = try pipeline.collectSlice(allocator);
defer allocator.free(result);

// result contains all transformed values
```

## Discussion

### Why Pipelines?

**Benefits:**
1. **No intermediate collections** - Transforms happen in single pass
2. **Memory efficient** - Only one item in memory at a time
3. **Composable** - Build complex operations from simple parts
4. **Lazy evaluation** - Only compute what's needed
5. **Type-safe** - Compiler checks pipeline compatibility

**Traditional approach:**
```zig
// Multiple passes, intermediate allocations
var temp1 = try filter(allocator, items, isEven);
defer allocator.free(temp1);

var temp2 = try map(allocator, temp1, double);
defer allocator.free(temp2);

var result = try map(allocator, temp2, addTen);
defer allocator.free(result);
```

**Pipeline approach:**
```zig
// Single pass, no intermediate allocations
var pipeline = Pipeline(i32).init(&items)
    .filter(isEven)
    .map(i32, double)
    .map(i32, addTen);

while (pipeline.next()) |value| {
    process(value);
}
```

### Order Matters

Pipeline order affects results:

```zig
// Filter then map: only squares even numbers
items → filter(isEven) → map(square)
[1,2,3,4] → [2,4] → [4,16]

// Map then filter: squares all, filters even results
items → map(square) → filter(isEven)
[1,2,3,4] → [1,4,9,16] → [4,16]
```

Choose order based on:
- **Filter first** when filtering reduces data significantly
- **Map first** when transformation enables better filtering

### Type Transformations

Pipelines can change types:

```zig
const items = [_]i32{ 1, 2, 3, 4, 5 };

const toFloat = struct {
    fn f(x: i32) f64 {
        return @floatFromInt(x);
    }
}.f;

const multiplyByPi = struct {
    fn f(x: f64) f64 {
        return x * std.math.pi;
    }
}.f;

var pipeline = Pipeline(i32).init(&items)
    .map(f64, toFloat)
    .map(f64, multiplyByPi);

// i32 → f64 → f64
```

### Performance Considerations

**Pipeline overhead:**
- Zero-cost abstraction when inlined
- No heap allocations for pipeline structure
- Single traversal of data

**Benchmarks:**
```zig
// Pipeline: O(n) time, O(1) space
var pipeline = Pipeline(i32).init(&items)
    .filter(pred1)
    .filter(pred2)
    .map(i32, transform);

// Traditional: O(n) time, O(n) space per stage
var temp1 = try filter(allocator, items, pred1);
var temp2 = try filter(allocator, temp1, pred2);
var result = try map(allocator, temp2, transform);
```

### Short-Circuiting

Pipeline automatically short-circuits when combined with take:

```zig
const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

// Only processes until 5 matches found
var pipeline = Pipeline(i32).init(&items)
    .filter(isEven)
    .take(5);

// Processes only: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
// But stops after finding 5 even numbers
```

### Common Patterns

**Data transformation:**
```zig
// Parse, validate, transform
var pipeline = Pipeline([]const u8).init(lines)
    .map(ParsedData, parseLine)
    .filter(isValid)
    .map(Output, transform);
```

**Analytics:**
```zig
// Filter outliers, normalize, aggregate
var pipeline = Pipeline(f64).init(measurements)
    .filter(isNotOutlier)
    .map(f64, normalize)
    .map(f64, smoothing);
```

**Data cleaning:**
```zig
// Remove nulls, trim, deduplicate
var pipeline = Pipeline(?Data).init(raw_data)
    .filter(isNotNull)
    .map(Data, unwrap)
    .map(Data, trim);
```

### Comparison with Other Languages

**Python:**
```python
result = (
    items
    .filter(is_even)
    .map(double)
    .map(add_ten)
)
```

**Rust:**
```rust
let result: Vec<i32> = items
    .iter()
    .filter(|x| is_even(**x))
    .map(|x| double(*x))
    .map(|x| add_ten(x))
    .collect();
```

**JavaScript:**
```javascript
const result = items
    .filter(isEven)
    .map(double)
    .map(addTen);
```

**Zig's approach** provides similar ergonomics with explicit type transformations and no hidden allocations.

### Limitations

Pipelines work best when:
- Single pass is sufficient
- Operations are independent
- No need for random access
- Data fits streaming model

For multiple passes or complex dependencies, use traditional loops or intermediate collections.

## See Also

- `code/02-core/04-iterators-generators/recipe_4_13.zig` - Full implementations and tests
- Recipe 4.6: Defining generators with extra state
- Recipe 4.7: Taking a slice of an iterator
- Recipe 4.8: Skipping the first part of an iterable
- Recipe 4.11: Zip iterators
- Recipe 4.12: Chain iterators
