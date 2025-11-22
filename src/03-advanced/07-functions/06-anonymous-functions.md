## Problem

You want to define small, anonymous functions (like lambdas in Python) for callbacks, comparisons, or local operations.

## Solution

Use anonymous structs with functions for simple callbacks:

```zig
{{#include ../../../code/03-advanced/07-functions/recipe_7_6.zig:basic_anonymous}}
```

## Discussion

### Inline Functions

Use the `inline` keyword to force inlining of small functions:

```zig
inline fn add(a: i32, b: i32) i32 {
    return a + b;
}

inline fn square(x: i32) i32 {
    return x * x;
}

pub fn processValues(values: []i32) i32 {
    var sum: i32 = 0;
    for (values) |v| {
        sum = add(sum, square(v));
    }
    return sum;
}

test "inline functions" {
    var values = [_]i32{ 1, 2, 3, 4 };
    const result = processValues(&values);
    try std.testing.expectEqual(@as(i32, 30), result); // 1 + 4 + 9 + 16
}
```

### Anonymous Comparison Functions

Common pattern for sorting with custom comparison:

```zig
pub fn sortBy(items: []i32, comptime descending: bool) void {
    const compare = if (descending)
        struct {
            fn cmp(_: void, a: i32, b: i32) bool {
                return a > b;
            }
        }.cmp
    else
        struct {
            fn cmp(_: void, a: i32, b: i32) bool {
                return a < b;
            }
        }.cmp;

    std.mem.sort(i32, items, {}, compare);
}

test "anonymous comparison" {
    var numbers = [_]i32{ 5, 2, 8, 1, 9 };

    sortBy(&numbers, false);
    try std.testing.expectEqual(@as(i32, 1), numbers[0]);

    sortBy(&numbers, true);
    try std.testing.expectEqual(@as(i32, 9), numbers[0]);
}
```

### Function Tables

Map operations to anonymous implementations:

```zig
const Operation = enum { add, subtract, multiply, divide };

pub fn calculate(op: Operation, a: i32, b: i32) !i32 {
    const functions = .{
        struct {
            fn call(x: i32, y: i32) !i32 {
                return x + y;
            }
        }.call,
        struct {
            fn call(x: i32, y: i32) !i32 {
                return x - y;
            }
        }.call,
        struct {
            fn call(x: i32, y: i32) !i32 {
                return x * y;
            }
        }.call,
        struct {
            fn call(x: i32, y: i32) !i32 {
                if (y == 0) return error.DivideByZero;
                return @divTrunc(x, y);
            }
        }.call,
    };

    return switch (op) {
        .add => functions[0](a, b),
        .subtract => functions[1](a, b),
        .multiply => functions[2](a, b),
        .divide => functions[3](a, b),
    };
}

test "function tables" {
    try std.testing.expectEqual(@as(i32, 8), try calculate(.add, 5, 3));
    try std.testing.expectEqual(@as(i32, 2), try calculate(.subtract, 5, 3));
    try std.testing.expectEqual(@as(i32, 15), try calculate(.multiply, 5, 3));
    try std.testing.expectEqual(@as(i32, 1), try calculate(.divide, 5, 3));
    try std.testing.expectError(error.DivideByZero, calculate(.divide, 5, 0));
}
```

### Filtering with Predicates

Use anonymous predicates for filtering:

```zig
pub fn filter(
    allocator: std.mem.Allocator,
    items: []const i32,
    predicate: fn (i32) bool,
) ![]i32 {
    var result = std.ArrayList(i32).init(allocator);
    errdefer result.deinit();

    for (items) |item| {
        if (predicate(item)) {
            try result.append(item);
        }
    }

    return result.toOwnedSlice();
}

test "anonymous predicates" {
    const allocator = std.testing.allocator;
    const numbers = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    // Filter even numbers
    const is_even = struct {
        fn call(n: i32) bool {
            return @mod(n, 2) == 0;
        }
    }.call;

    const evens = try filter(allocator, &numbers, is_even);
    defer allocator.free(evens);

    try std.testing.expectEqual(@as(usize, 5), evens.len);
    try std.testing.expectEqual(@as(i32, 2), evens[0]);

    // Filter numbers greater than 5
    const greater_than_five = struct {
        fn call(n: i32) bool {
            return n > 5;
        }
    }.call;

    const filtered = try filter(allocator, &numbers, greater_than_five);
    defer allocator.free(filtered);

    try std.testing.expectEqual(@as(usize, 5), filtered.len);
    try std.testing.expectEqual(@as(i32, 6), filtered[0]);
}
```

### Map/Transform Functions

Transform data with anonymous functions:

```zig
pub fn map(
    allocator: std.mem.Allocator,
    items: []const i32,
    transform: fn (i32) i32,
) ![]i32 {
    var result = try allocator.alloc(i32, items.len);
    errdefer allocator.free(result);

    for (items, 0..) |item, i| {
        result[i] = transform(item);
    }

    return result;
}

test "anonymous transformations" {
    const allocator = std.testing.allocator;
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };

    // Double all values
    const double = struct {
        fn call(n: i32) i32 {
            return n * 2;
        }
    }.call;

    const doubled = try map(allocator, &numbers, double);
    defer allocator.free(doubled);

    try std.testing.expectEqual(@as(i32, 2), doubled[0]);
    try std.testing.expectEqual(@as(i32, 10), doubled[4]);

    // Square all values
    const square = struct {
        fn call(n: i32) i32 {
            return n * n;
        }
    }.call;

    const squared = try map(allocator, &numbers, square);
    defer allocator.free(squared);

    try std.testing.expectEqual(@as(i32, 1), squared[0]);
    try std.testing.expectEqual(@as(i32, 25), squared[4]);
}
```

### Comptime Function Generation

Generate functions at compile time:

```zig
pub fn makeAdder(comptime n: i32) fn (i32) i32 {
    return struct {
        fn add(x: i32) i32 {
            return x + n;
        }
    }.add;
}

test "comptime function generation" {
    const add5 = makeAdder(5);
    const add10 = makeAdder(10);

    try std.testing.expectEqual(@as(i32, 15), add5(10));
    try std.testing.expectEqual(@as(i32, 20), add10(10));
}
```

### Generic Anonymous Functions

Create generic operations:

```zig
pub fn GenericOperation(comptime T: type) type {
    return struct {
        pub fn min(a: T, b: T) T {
            return if (a < b) a else b;
        }

        pub fn max(a: T, b: T) T {
            return if (a > b) a else b;
        }

        pub fn clamp(value: T, low: T, high: T) T {
            return max(low, min(value, high));
        }
    };
}

test "generic anonymous functions" {
    const IntOps = GenericOperation(i32);

    try std.testing.expectEqual(@as(i32, 3), IntOps.min(5, 3));
    try std.testing.expectEqual(@as(i32, 5), IntOps.max(5, 3));
    try std.testing.expectEqual(@as(i32, 5), IntOps.clamp(10, 0, 5));

    const FloatOps = GenericOperation(f32);

    try std.testing.expectEqual(@as(f32, 1.5), FloatOps.min(2.5, 1.5));
    try std.testing.expectEqual(@as(f32, 2.5), FloatOps.max(2.5, 1.5));
}
```

### Callback Registration

Register anonymous callbacks:

```zig
const EventHandler = struct {
    context: *anyopaque,
    callback: *const fn (*anyopaque, []const u8) void,

    pub fn init(
        context: anytype,
        comptime callback: fn (@TypeOf(context), []const u8) void,
    ) EventHandler {
        const Wrapper = struct {
            fn call(ctx: *anyopaque, data: []const u8) void {
                const ptr: @TypeOf(context) = @ptrCast(@alignCast(ctx));
                callback(ptr, data);
            }
        };

        return .{
            .context = @ptrCast(context),
            .callback = Wrapper.call,
        };
    }

    pub fn trigger(self: EventHandler, data: []const u8) void {
        self.callback(self.context, data);
    }
};

test "callback registration" {
    const Handler = struct {
        count: usize = 0,

        fn onEvent(self: *@This(), data: []const u8) void {
            self.count += data.len;
        }
    };

    var handler = Handler{};
    const event = EventHandler.init(&handler, Handler.onEvent);

    event.trigger("hello");
    event.trigger("world");

    try std.testing.expectEqual(@as(usize, 10), handler.count);
}
```

### Reduce/Fold Operations

Implement reduce with anonymous functions:

```zig
pub fn reduce(
    items: []const i32,
    initial: i32,
    reducer: fn (i32, i32) i32,
) i32 {
    var accumulator = initial;
    for (items) |item| {
        accumulator = reducer(accumulator, item);
    }
    return accumulator;
}

test "anonymous reduce" {
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };

    // Sum
    const sum = struct {
        fn call(acc: i32, val: i32) i32 {
            return acc + val;
        }
    }.call;

    const total = reduce(&numbers, 0, sum);
    try std.testing.expectEqual(@as(i32, 15), total);

    // Product
    const multiply = struct {
        fn call(acc: i32, val: i32) i32 {
            return acc * val;
        }
    }.call;

    const product = reduce(&numbers, 1, multiply);
    try std.testing.expectEqual(@as(i32, 120), product);
}
```

### Inline Loop Unrolling

Use inline functions for loop unrolling:

```zig
pub fn processVector(data: @Vector(4, i32)) @Vector(4, i32) {
    inline for (0..4) |i| {
        data[i] = data[i] * 2;
    }
    return data;
}

test "inline loop unrolling" {
    const input: @Vector(4, i32) = .{ 1, 2, 3, 4 };
    const result = processVector(input);

    try std.testing.expectEqual(@as(i32, 2), result[0]);
    try std.testing.expectEqual(@as(i32, 8), result[3]);
}
```

### Best Practices

**Anonymous Struct Pattern:**
```zig
// Good: Clear intent, self-documenting
const is_positive = struct {
    fn call(n: i32) bool {
        return n > 0;
    }
}.call;

// Acceptable: Very short, obvious operation
const double = struct {
    fn f(n: i32) i32 {
        return n * 2;
    }
}.f;
```

**When to Use Inline:**
- Small, frequently called functions
- Performance-critical inner loops
- When function call overhead is significant
- Comptime-evaluated code

**When NOT to Use Inline:**
- Large functions (increases binary size)
- Rarely called code
- When debugging (inlined code harder to debug)
- Recursive functions

**Type Safety:**
```zig
// Good: Type-safe callback with context
pub fn forEach(
    items: []i32,
    context: anytype,
    callback: fn (@TypeOf(context), i32) void,
) void {
    for (items) |item| {
        callback(context, item);
    }
}

// Less safe: Type-erased context
pub fn forEachErased(
    items: []i32,
    context: *anyopaque,
    callback: fn (*anyopaque, i32) void,
) void {
    for (items) |item| {
        callback(context, item);
    }
}
```

**Performance Considerations:**
- Anonymous structs have zero runtime cost
- `inline` functions are expanded at call site
- Function pointers have call overhead
- Comptime functions are evaluated at compile time

### Related Functions

- `inline` keyword for forced inlining
- Anonymous struct syntax `struct { ... }`
- Function pointers `fn(T) R`
- `@ptrCast` and `@alignCast` for type-erased callbacks
- `std.mem.sort` for custom comparisons
- `comptime` for compile-time function generation
