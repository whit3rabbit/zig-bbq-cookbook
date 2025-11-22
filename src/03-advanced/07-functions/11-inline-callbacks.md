## Problem

You want to use callbacks for flexibility but need to eliminate the function call overhead in performance-critical code.

## Solution

Use `inline` keyword and `comptime` to eliminate callback overhead:

```zig
{{#include ../../../code/03-advanced/07-functions/recipe_7_11.zig:basic_inline_callback}}
```

## Discussion

### Comptime Callback Specialization

Generate specialized versions at compile time:

```zig
pub fn forEach(
    items: []const i32,
    comptime callback: fn (i32) void,
) void {
    for (items) |item| {
        callback(item);
    }
}

test "comptime callback specialization" {
    var sum: i32 = 0;

    const Adder = struct {
        total: *i32,

        fn add(self: *@This(), value: i32) void {
            self.total.* += value;
        }
    };

    var adder = Adder{ .total = &sum };

    const numbers = [_]i32{ 1, 2, 3, 4, 5 };

    // Comptime specialization
    forEach(&numbers, struct {
        fn call(x: i32) void {
            adder.add(x);
        }
    }.call);

    try std.testing.expectEqual(@as(i32, 15), sum);
}
```

### Inline Higher-Order Functions

Use `inline` keyword for zero-cost abstractions:

```zig
pub fn map(
    allocator: std.mem.Allocator,
    items: []const i32,
    comptime transform: fn (i32) i32,
) ![]i32 {
    var result = std.ArrayList(i32){};
    errdefer result.deinit(allocator);

    for (items) |item| {
        try result.append(allocator, transform(item));
    }

    return try result.toOwnedSlice(allocator);
}

test "inline map" {
    const allocator = std.testing.allocator;

    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    const doubled = try map(allocator, &numbers, struct {
        fn transform(x: i32) i32 {
            return x * 2;
        }
    }.transform);
    defer allocator.free(doubled);

    try std.testing.expectEqual(@as(usize, 5), doubled.len);
    try std.testing.expectEqual(@as(i32, 2), doubled[0]);
    try std.testing.expectEqual(@as(i32, 10), doubled[4]);
}
```

### Filter with Inline Predicate

Zero-overhead filtering:

```zig
pub fn filter(
    allocator: std.mem.Allocator,
    items: []const i32,
    comptime predicate: fn (i32) bool,
) ![]i32 {
    var result = std.ArrayList(i32){};
    errdefer result.deinit(allocator);

    for (items) |item| {
        if (predicate(item)) {
            try result.append(allocator, item);
        }
    }

    return try result.toOwnedSlice(allocator);
}

test "inline filter" {
    const allocator = std.testing.allocator;

    const numbers = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    const evens = try filter(allocator, &numbers, struct {
        fn isEven(x: i32) bool {
            return @mod(x, 2) == 0;
        }
    }.isEven);
    defer allocator.free(evens);

    try std.testing.expectEqual(@as(usize, 5), evens.len);
    try std.testing.expectEqual(@as(i32, 2), evens[0]);
}
```

### Reduce with Inline Accumulator

Compile-time optimized reduction:

```zig
pub fn reduce(
    items: []const i32,
    initial: i32,
    comptime accumulate: fn (i32, i32) i32,
) i32 {
    var result = initial;
    for (items) |item| {
        result = accumulate(result, item);
    }
    return result;
}

test "inline reduce" {
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };

    const sum = reduce(&numbers, 0, struct {
        fn add(acc: i32, x: i32) i32 {
            return acc + x;
        }
    }.add);

    try std.testing.expectEqual(@as(i32, 15), sum);

    const product = reduce(&numbers, 1, struct {
        fn multiply(acc: i32, x: i32) i32 {
            return acc * x;
        }
    }.multiply);

    try std.testing.expectEqual(@as(i32, 120), product);
}
```

### Chained Operations

Compose inline operations:

```zig
pub fn pipeline(
    allocator: std.mem.Allocator,
    items: []const i32,
    comptime transform: fn (i32) i32,
    comptime pred: fn (i32) bool,
) ![]i32 {
    var result = std.ArrayList(i32){};
    errdefer result.deinit(allocator);

    for (items) |item| {
        const transformed = transform(item);
        if (pred(transformed)) {
            try result.append(allocator, transformed);
        }
    }

    return try result.toOwnedSlice(allocator);
}

test "inline pipeline" {
    const allocator = std.testing.allocator;

    const numbers = [_]i32{ 1, 2, 3, 4, 5 };

    const result = try pipeline(
        allocator,
        &numbers,
        struct {
            fn double(x: i32) i32 {
                return x * 2;
            }
        }.double,
        struct {
            fn greaterThanFive(x: i32) bool {
                return x > 5;
            }
        }.greaterThanFive,
    );
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(@as(i32, 6), result[0]);
    try std.testing.expectEqual(@as(i32, 8), result[1]);
    try std.testing.expectEqual(@as(i32, 10), result[2]);
}
```

### Generic Inline Callbacks

Work with any type using comptime:

```zig
pub fn GenericMap(comptime T: type, comptime R: type) type {
    return struct {
        pub fn map(
            allocator: std.mem.Allocator,
            items: []const T,
            comptime transform: fn (T) R,
        ) ![]R {
            var result = std.ArrayList(R){};
            errdefer result.deinit(allocator);

            for (items) |item| {
                try result.append(allocator, transform(item));
            }

            return try result.toOwnedSlice(allocator);
        }
    };
}

test "generic inline map" {
    const allocator = std.testing.allocator;

    const numbers = [_]i32{ 1, 2, 3 };
    const doubled = try GenericMap(i32, i32).map(allocator, &numbers, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);
    defer allocator.free(doubled);

    try std.testing.expectEqual(@as(usize, 3), doubled.len);
    try std.testing.expectEqual(@as(i32, 2), doubled[0]);
}
```

### Inline Iterator Processing

Process iterators without function call overhead:

```zig
pub fn Iterator(comptime T: type) type {
    return struct {
        items: []const T,
        index: usize = 0,

        pub fn next(self: *@This()) ?T {
            if (self.index >= self.items.len) return null;
            const item = self.items[self.index];
            self.index += 1;
            return item;
        }

        pub fn collect(
            self: *@This(),
            allocator: std.mem.Allocator,
            comptime transform: fn (T) T,
        ) ![]T {
            var result = std.ArrayList(T){};
            errdefer result.deinit(allocator);

            while (self.next()) |item| {
                try result.append(allocator, transform(item));
            }

            return try result.toOwnedSlice(allocator);
        }
    };
}

test "inline iterator processing" {
    const allocator = std.testing.allocator;

    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = Iterator(i32){ .items = &numbers };

    const doubled = try iter.collect(allocator, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);
    defer allocator.free(doubled);

    try std.testing.expectEqual(@as(usize, 5), doubled.len);
    try std.testing.expectEqual(@as(i32, 10), doubled[4]);
}
```

### Conditional Inlining

Use comptime to choose implementation:

```zig
pub fn processWithStrategy(
    items: []const i32,
    comptime inline_it: bool,
) i32 {
    if (inline_it) {
        return processInline(items, struct {
            fn double(x: i32) i32 {
                return x * 2;
            }
        }.double);
    } else {
        var sum: i32 = 0;
        for (items) |item| {
            sum += item * 2;
        }
        return sum;
    }
}

test "conditional inlining" {
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };

    const result1 = processWithStrategy(&numbers, true);
    try std.testing.expectEqual(@as(i32, 30), result1);

    const result2 = processWithStrategy(&numbers, false);
    try std.testing.expectEqual(@as(i32, 30), result2);
}
```

### Inline Comparison Functions

Sorting with inline comparators:

```zig
pub fn sortWith(
    items: []i32,
    comptime lessThan: fn (i32, i32) bool,
) void {
    if (items.len <= 1) return;

    // Simple bubble sort for demonstration
    for (items, 0..) |_, i| {
        for (items[0 .. items.len - i - 1], 0..) |_, j| {
            if (!lessThan(items[j], items[j + 1])) {
                const temp = items[j];
                items[j] = items[j + 1];
                items[j + 1] = temp;
            }
        }
    }
}

test "inline comparison" {
    var ascending = [_]i32{ 5, 2, 8, 1, 9 };
    sortWith(&ascending, struct {
        fn lessThan(a: i32, b: i32) bool {
            return a < b;
        }
    }.lessThan);

    try std.testing.expectEqual(@as(i32, 1), ascending[0]);
    try std.testing.expectEqual(@as(i32, 9), ascending[4]);

    var descending = [_]i32{ 5, 2, 8, 1, 9 };
    sortWith(&descending, struct {
        fn greaterThan(a: i32, b: i32) bool {
            return a > b;
        }
    }.greaterThan);

    try std.testing.expectEqual(@as(i32, 9), descending[0]);
    try std.testing.expectEqual(@as(i32, 1), descending[4]);
}
```

### Best Practices

**When to Inline:**
```zig
// Good: Small, frequently called callbacks
pub fn fastMap(items: []const i32, comptime f: fn(i32) i32) []i32 {
    // Compiler can inline f() completely
}

// Avoid: Large callbacks that bloat code size
pub fn slowMap(items: []const i32, comptime f: fn(i32) ComplexResult) []ComplexResult {
    // May increase binary size significantly
}
```

**Performance:**
- Inline callbacks eliminate function call overhead
- Comptime callbacks enable better compiler optimizations
- Use for hot loops and performance-critical paths
- Profile before and after inlining

**Code Size:**
- Inlining increases code size (one copy per call site)
- Balance performance vs. binary size
- Use `inline` judiciously for critical paths only

**Debugging:**
```zig
// Good: Named inline functions for better stack traces
const Transform = struct {
    fn double(x: i32) i32 {
        return x * 2;
    }
};

processInline(&items, Transform.double);

// Harder to debug: Anonymous inline functions
processInline(&items, struct {
    fn call(x: i32) i32 {
        return x * 2;
    }
}.call);
```

**Comptime vs Runtime:**
```zig
// Comptime: Callback known at compile time
pub fn compiletimeProcess(comptime callback: fn(i32) i32) type {
    // Can use callback in type construction
}

// Runtime: Callback determined at runtime
pub fn runtimeProcess(callback: *const fn(i32) i32) void {
    // Cannot inline, regular function pointer
}
```

### Related Functions

- `inline` keyword for forced inlining
- `comptime` for compile-time function parameters
- Anonymous structs for inline function definitions
- `@inlineCall()` for explicit inline calls (advanced)
- Generic functions with `comptime` parameters
