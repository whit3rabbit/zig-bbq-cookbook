## Problem

You want to create functions that capture and remember variables from their surrounding scope, similar to closures in Python.

## Solution

Use structs to manually capture state:

```zig
{{#include ../../../code/03-advanced/07-functions/recipe_7_7.zig:basic_closure}}
```

## Discussion

### Simple Closure Pattern

Capture a single value:

```zig
pub fn makeAdder(n: i32) type {
    return struct {
        pub fn call(x: i32) i32 {
            return x + n;
        }
    };
}

test "simple closure" {
    const Add5 = makeAdder(5);
    const Add10 = makeAdder(10);

    try std.testing.expectEqual(@as(i32, 15), Add5.call(10));
    try std.testing.expectEqual(@as(i32, 20), Add10.call(10));
}
```

### Closure with Mutable State

Create stateful closures:

```zig
pub fn Accumulator(comptime T: type) type {
    return struct {
        sum: T,

        pub fn init(initial: T) @This() {
            return .{ .sum = initial };
        }

        pub fn add(self: *@This(), value: T) T {
            self.sum += value;
            return self.sum;
        }

        pub fn reset(self: *@This()) void {
            self.sum = 0;
        }
    };
}

test "mutable closure state" {
    var acc = Accumulator(i32).init(0);

    try std.testing.expectEqual(@as(i32, 5), acc.add(5));
    try std.testing.expectEqual(@as(i32, 8), acc.add(3));
    try std.testing.expectEqual(@as(i32, 15), acc.add(7));

    acc.reset();
    try std.testing.expectEqual(@as(i32, 10), acc.add(10));
}
```

### Closure with Multiple Captures

Capture multiple values:

```zig
pub fn makeMultiplier(factor: i32, offset: i32) type {
    return struct {
        pub fn call(x: i32) i32 {
            return x * factor + offset;
        }
    };
}

test "multiple captures" {
    const Transform = makeMultiplier(3, 10);

    try std.testing.expectEqual(@as(i32, 25), Transform.call(5)); // 5 * 3 + 10
    try std.testing.expectEqual(@as(i32, 40), Transform.call(10)); // 10 * 3 + 10
}
```

### Closure Factory

Generate closures dynamically:

```zig
const FilterFn = struct {
    threshold: i32,

    pub fn init(threshold: i32) FilterFn {
        return .{ .threshold = threshold };
    }

    pub fn check(self: FilterFn, value: i32) bool {
        return value > self.threshold;
    }
};

pub fn filterSlice(
    allocator: std.mem.Allocator,
    items: []const i32,
    filter_fn: FilterFn,
) ![]i32 {
    var result = std.ArrayList(i32){};
    errdefer result.deinit(allocator);

    for (items) |item| {
        if (filter_fn.check(item)) {
            try result.append(allocator, item);
        }
    }

    return try result.toOwnedSlice(allocator);
}

test "closure factory" {
    const allocator = std.testing.allocator;
    const numbers = [_]i32{ 1, 5, 10, 15, 20 };

    const filter = FilterFn.init(10);
    const filtered = try filterSlice(allocator, &numbers, filter);
    defer allocator.free(filtered);

    try std.testing.expectEqual(@as(usize, 2), filtered.len);
    try std.testing.expectEqual(@as(i32, 15), filtered[0]);
}
```

### Closure with Allocator

Capture allocator for dynamic operations:

```zig
pub fn StringBuilder(allocator: std.mem.Allocator) type {
    return struct {
        buffer: std.ArrayList(u8),

        const Self = @This();

        pub fn init() Self {
            return .{
                .buffer = std.ArrayList(u8){},
            };
        }

        pub fn append(self: *Self, text: []const u8) !void {
            try self.buffer.appendSlice(allocator, text);
        }

        pub fn build(self: *Self) ![]u8 {
            return try self.buffer.toOwnedSlice(allocator);
        }

        pub fn deinit(self: *Self) void {
            self.buffer.deinit(allocator);
        }
    };
}

test "closure with allocator" {
    const allocator = std.testing.allocator;
    const Builder = StringBuilder(allocator);

    var builder = Builder.init();
    defer builder.deinit();

    try builder.append("Hello");
    try builder.append(" ");
    try builder.append("World");

    const result = try builder.build();
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello World", result);
}
```

### Callback with Captured Context

Pass captured state to callbacks:

```zig
const Callback = struct {
    context: *anyopaque,
    call_fn: *const fn (*anyopaque, i32) void,

    pub fn init(
        context: anytype,
        comptime callback: fn (@TypeOf(context), i32) void,
    ) Callback {
        const Wrapper = struct {
            fn call(ctx: *anyopaque, value: i32) void {
                const ptr: @TypeOf(context) = @ptrCast(@alignCast(ctx));
                callback(ptr, value);
            }
        };

        return .{
            .context = @ptrCast(context),
            .call_fn = Wrapper.call,
        };
    }

    pub fn invoke(self: Callback, value: i32) void {
        self.call_fn(self.context, value);
    }
};

test "callback with context" {
    const State = struct {
        sum: i32 = 0,

        fn onValue(self: *@This(), value: i32) void {
            self.sum += value;
        }
    };

    var state = State{};
    const callback = Callback.init(&state, State.onValue);

    callback.invoke(5);
    callback.invoke(10);
    callback.invoke(3);

    try std.testing.expectEqual(@as(i32, 18), state.sum);
}
```

### Closure Chain

Chain multiple closures together:

```zig
pub fn Pipeline(comptime T: type) type {
    return struct {
        transforms: []const *const fn (T) T,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .transforms = &[_]*const fn (T) T{},
                .allocator = allocator,
            };
        }

        pub fn add(self: *Self, transform: *const fn (T) T) !void {
            const new_transforms = try self.allocator.alloc(*const fn (T) T, self.transforms.len + 1);
            @memcpy(new_transforms[0..self.transforms.len], self.transforms);
            new_transforms[self.transforms.len] = transform;

            if (self.transforms.len > 0) {
                self.allocator.free(self.transforms);
            }
            self.transforms = new_transforms;
        }

        pub fn execute(self: Self, value: T) T {
            var result = value;
            for (self.transforms) |transform| {
                result = transform(result);
            }
            return result;
        }

        pub fn deinit(self: *Self) void {
            if (self.transforms.len > 0) {
                self.allocator.free(self.transforms);
            }
        }
    };
}

test "closure chain" {
    const allocator = std.testing.allocator;

    var pipeline = Pipeline(i32).init(allocator);
    defer pipeline.deinit();

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const add10 = struct {
        fn f(x: i32) i32 {
            return x + 10;
        }
    }.f;

    try pipeline.add(&double);
    try pipeline.add(&add10);

    const result = pipeline.execute(5); // (5 * 2) + 10 = 20
    try std.testing.expectEqual(@as(i32, 20), result);
}
```

### Lazy Evaluation Closure

Defer computation until needed:

```zig
pub fn Lazy(comptime T: type) type {
    return struct {
        compute_fn: *const fn () T,
        cached_value: ?T,
        is_computed: bool,

        const Self = @This();

        pub fn init(compute_fn: *const fn () T) Self {
            return .{
                .compute_fn = compute_fn,
                .cached_value = null,
                .is_computed = false,
            };
        }

        pub fn get(self: *Self) T {
            if (!self.is_computed) {
                self.cached_value = self.compute_fn();
                self.is_computed = true;
            }
            return self.cached_value.?;
        }

        pub fn reset(self: *Self) void {
            self.is_computed = false;
            self.cached_value = null;
        }
    };
}

test "lazy evaluation" {
    const expensive = struct {
        var call_count: usize = 0;

        fn compute() i32 {
            call_count += 1;
            return 42;
        }
    };

    var lazy = Lazy(i32).init(&expensive.compute);

    try std.testing.expectEqual(@as(usize, 0), expensive.call_count);

    const value1 = lazy.get();
    try std.testing.expectEqual(@as(i32, 42), value1);
    try std.testing.expectEqual(@as(usize, 1), expensive.call_count);

    const value2 = lazy.get();
    try std.testing.expectEqual(@as(i32, 42), value2);
    try std.testing.expectEqual(@as(usize, 1), expensive.call_count); // Not called again
}
```

### Memoization Pattern

Cache function results:

```zig
pub fn Memoized(comptime Input: type, comptime Output: type) type {
    return struct {
        cache: std.AutoHashMap(Input, Output),
        compute_fn: *const fn (Input) Output,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(
            allocator: std.mem.Allocator,
            compute_fn: *const fn (Input) Output,
        ) Self {
            return .{
                .cache = std.AutoHashMap(Input, Output).init(allocator),
                .compute_fn = compute_fn,
                .allocator = allocator,
            };
        }

        pub fn call(self: *Self, input: Input) !Output {
            if (self.cache.get(input)) |cached| {
                return cached;
            }

            const result = self.compute_fn(input);
            try self.cache.put(input, result);
            return result;
        }

        pub fn deinit(self: *Self) void {
            self.cache.deinit();
        }
    };
}

test "memoization" {
    const fibonacci = struct {
        var call_count: usize = 0;

        fn compute(n: u32) u32 {
            call_count += 1;
            if (n <= 1) return n;
            return n; // Simplified for testing
        }
    };

    const allocator = std.testing.allocator;
    var memo = Memoized(u32, u32).init(allocator, &fibonacci.compute);
    defer memo.deinit();

    _ = try memo.call(5);
    try std.testing.expectEqual(@as(usize, 1), fibonacci.call_count);

    _ = try memo.call(5);
    try std.testing.expectEqual(@as(usize, 1), fibonacci.call_count); // Cached
}
```

### Event Listener Pattern

Capture state for event handlers:

```zig
const EventListener = struct {
    id: usize,
    context: *anyopaque,
    handler: *const fn (*anyopaque, []const u8) void,

    pub fn init(
        id: usize,
        context: anytype,
        comptime handler: fn (@TypeOf(context), []const u8) void,
    ) EventListener {
        const Wrapper = struct {
            fn call(ctx: *anyopaque, data: []const u8) void {
                const ptr: @TypeOf(context) = @ptrCast(@alignCast(ctx));
                handler(ptr, data);
            }
        };

        return .{
            .id = id,
            .context = @ptrCast(context),
            .handler = Wrapper.call,
        };
    }

    pub fn trigger(self: EventListener, data: []const u8) void {
        self.handler(self.context, data);
    }
};

test "event listener" {
    const Logger = struct {
        messages: std.ArrayList([]const u8),
        allocator: std.mem.Allocator,

        fn onEvent(self: *@This(), message: []const u8) void {
            self.messages.append(self.allocator, message) catch unreachable;
        }

        fn deinit(self: *@This()) void {
            self.messages.deinit();
        }
    };

    const allocator = std.testing.allocator;
    var logger = Logger{
        .messages = std.ArrayList([]const u8){},
        .allocator = allocator,
    };
    defer logger.deinit();

    const listener = EventListener.init(1, &logger, Logger.onEvent);

    listener.trigger("event1");
    listener.trigger("event2");

    try std.testing.expectEqual(@as(usize, 2), logger.messages.items.len);
}
```

### Best Practices

**Closure Pattern Selection:**
```zig
// Good: Comptime closure for zero runtime cost
pub fn makeAdder(comptime n: i32) type {
    return struct {
        pub fn call(x: i32) i32 {
            return x + n;
        }
    };
}

// Good: Runtime closure with mutable state
pub fn Counter() type {
    return struct {
        count: i32 = 0,

        pub fn increment(self: *@This()) i32 {
            self.count += 1;
            return self.count;
        }
    };
}
```

**Memory Management:**
- Always provide `deinit()` for closures that allocate
- Use `errdefer` for cleanup on error
- Capture allocators when dynamic allocation is needed
- Document ownership semantics clearly

**Type Safety:**
```zig
// Good: Type-safe context with comptime
pub fn Callback(comptime Context: type) type {
    return struct {
        context: *Context,
        fn_ptr: *const fn (*Context, i32) void,
    };
}

// Less safe: Type-erased with anyopaque
// Use only when generic context is truly needed
```

**Performance Considerations:**
- Comptime closures have zero runtime overhead
- Runtime closures are just struct instances
- Avoid unnecessary heap allocations in closures
- Cache expensive computations with memoization

### Related Functions

- `@TypeOf()` for capturing type information
- `@ptrCast()` and `@alignCast()` for type-erased contexts
- `comptime` for compile-time closure generation
- `std.ArrayList` for dynamic collections in closures
- `std.AutoHashMap` for memoization
- Function pointers `*const fn(T) R`
