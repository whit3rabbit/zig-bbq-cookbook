## Problem

You need to pass extra state or context to callback functions that will be invoked later.

## Solution

Use `*anyopaque` with type-safe wrappers to carry state:

```zig
{{#include ../../../code/03-advanced/07-functions/recipe_7_10.zig:basic_callback_state}}
```

## Discussion

### Multiple Callbacks with Shared State

Share state across multiple callbacks:

```zig
const EventSystem = struct {
    callbacks: std.ArrayList(Callback),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) EventSystem {
        return .{
            .callbacks = std.ArrayList(Callback){},
            .allocator = allocator,
        };
    }

    pub fn register(self: *EventSystem, callback: Callback) !void {
        try self.callbacks.append(self.allocator, callback);
    }

    pub fn trigger(self: EventSystem, value: i32) void {
        for (self.callbacks.items) |callback| {
            callback.invoke(value);
        }
    }

    pub fn deinit(self: *EventSystem) void {
        self.callbacks.deinit(self.allocator);
    }
};

test "shared state callbacks" {
    const allocator = std.testing.allocator;

    const Counter = struct {
        count: *usize,

        fn increment(self: *@This(), value: i32) void {
            self.count.* += @intCast(value);
        }
    };

    var total: usize = 0;
    var counter = Counter{ .count = &total };

    var events = EventSystem.init(allocator);
    defer events.deinit();

    try events.register(Callback.init(&counter, Counter.increment));
    try events.register(Callback.init(&counter, Counter.increment));

    events.trigger(5);

    try std.testing.expectEqual(@as(usize, 10), total);
}
```

### Callback with Allocator State

Carry allocator in callback context:

```zig
const AllocCallback = struct {
    context: *anyopaque,
    call_fn: *const fn (*anyopaque, std.mem.Allocator, []const u8) !void,

    pub fn init(
        context: anytype,
        comptime call_fn: fn (@TypeOf(context), std.mem.Allocator, []const u8) !void,
    ) AllocCallback {
        const Wrapper = struct {
            fn call(ctx: *anyopaque, allocator: std.mem.Allocator, data: []const u8) !void {
                const ptr: @TypeOf(context) = @ptrCast(@alignCast(ctx));
                try call_fn(ptr, allocator, data);
            }
        };

        return .{
            .context = @ptrCast(context),
            .call_fn = Wrapper.call,
        };
    }

    pub fn invoke(self: AllocCallback, allocator: std.mem.Allocator, data: []const u8) !void {
        try self.call_fn(self.context, allocator, data);
    }
};

test "callback with allocator" {
    const allocator = std.testing.allocator;

    const Logger = struct {
        messages: std.ArrayList([]u8),

        fn log(self: *@This(), alloc: std.mem.Allocator, msg: []const u8) !void {
            const copy = try alloc.dupe(u8, msg);
            try self.messages.append(alloc, copy);
        }

        fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
            for (self.messages.items) |msg| {
                alloc.free(msg);
            }
            self.messages.deinit(alloc);
        }
    };

    var logger = Logger{ .messages = std.ArrayList([]u8){} };
    defer logger.deinit(allocator);

    const callback = AllocCallback.init(&logger, Logger.log);

    try callback.invoke(allocator, "message1");
    try callback.invoke(allocator, "message2");

    try std.testing.expectEqual(@as(usize, 2), logger.messages.items.len);
}
```

### Callback with Error Handling

Carry error handling state:

```zig
const ErrorCallback = struct {
    context: *anyopaque,
    call_fn: *const fn (*anyopaque, anyerror) void,

    pub fn init(
        context: anytype,
        comptime call_fn: fn (@TypeOf(context), anyerror) void,
    ) ErrorCallback {
        const Wrapper = struct {
            fn call(ctx: *anyopaque, err: anyerror) void {
                const ptr: @TypeOf(context) = @ptrCast(@alignCast(ctx));
                call_fn(ptr, err);
            }
        };

        return .{
            .context = @ptrCast(context),
            .call_fn = Wrapper.call,
        };
    }

    pub fn invoke(self: ErrorCallback, err: anyerror) void {
        self.call_fn(self.context, err);
    }
};

test "error callback" {
    const ErrorTracker = struct {
        errors: *std.ArrayList(anyerror),

        fn track(self: *@This(), err: anyerror) void {
            self.errors.append(err) catch {};
        }
    };

    const allocator = std.testing.allocator;
    var errors = std.ArrayList(anyerror).init(allocator);
    defer errors.deinit();

    var tracker = ErrorTracker{ .errors = &errors };
    const callback = ErrorCallback.init(&tracker, ErrorTracker.track);

    callback.invoke(error.OutOfMemory);
    callback.invoke(error.InvalidInput);

    try std.testing.expectEqual(@as(usize, 2), errors.items.len);
}
```

### Timer Callback with Context

Callback for delayed execution:

```zig
const TimerCallback = struct {
    context: *anyopaque,
    call_fn: *const fn (*anyopaque) void,
    deadline_ms: i64,

    pub fn init(
        context: anytype,
        comptime call_fn: fn (@TypeOf(context)) void,
        deadline_ms: i64,
    ) TimerCallback {
        const Wrapper = struct {
            fn call(ctx: *anyopaque) void {
                const ptr: @TypeOf(context) = @ptrCast(@alignCast(ctx));
                call_fn(ptr);
            }
        };

        return .{
            .context = @ptrCast(context),
            .call_fn = Wrapper.call,
            .deadline_ms = deadline_ms,
        };
    }

    pub fn invoke(self: TimerCallback) void {
        self.call_fn(self.context);
    }

    pub fn isReady(self: TimerCallback, current_time: i64) bool {
        return current_time >= self.deadline_ms;
    }
};

test "timer callback" {
    const Task = struct {
        executed: *bool,

        fn run(self: *@This()) void {
            self.executed.* = true;
        }
    };

    var executed = false;
    var task = Task{ .executed = &executed };

    const timer = TimerCallback.init(&task, Task.run, 100);

    try std.testing.expect(!timer.isReady(50));
    try std.testing.expect(timer.isReady(100));

    timer.invoke();
    try std.testing.expect(executed);
}
```

### Async Callback with Result

Callback carrying result state:

```zig
pub fn ResultCallback(comptime T: type) type {
    return struct {
        context: *anyopaque,
        call_fn: *const fn (*anyopaque, T) void,

        pub fn init(
            context: anytype,
            comptime call_fn: fn (@TypeOf(context), T) void,
        ) @This() {
            const Wrapper = struct {
                fn call(ctx: *anyopaque, result: T) void {
                    const ptr: @TypeOf(context) = @ptrCast(@alignCast(ctx));
                    call_fn(ptr, result);
                }
            };

            return .{
                .context = @ptrCast(context),
                .call_fn = Wrapper.call,
            };
        }

        pub fn invoke(self: @This(), result: T) void {
            self.call_fn(self.context, result);
        }
    };
}

test "result callback" {
    const Receiver = struct {
        result: *?i32,

        fn onResult(self: *@This(), value: i32) void {
            self.result.* = value;
        }
    };

    var result: ?i32 = null;
    var receiver = Receiver{ .result = &result };

    const callback = ResultCallback(i32).init(&receiver, Receiver.onResult);

    callback.invoke(42);
    try std.testing.expectEqual(@as(i32, 42), result.?);
}
```

### Callback Chain

Chain callbacks with accumulated state:

```zig
const ChainCallback = struct {
    context: *anyopaque,
    call_fn: *const fn (*anyopaque, i32) i32,
    next: ?*const ChainCallback,

    pub fn init(
        context: anytype,
        comptime call_fn: fn (@TypeOf(context), i32) i32,
    ) ChainCallback {
        const Wrapper = struct {
            fn call(ctx: *anyopaque, value: i32) i32 {
                const ptr: @TypeOf(context) = @ptrCast(@alignCast(ctx));
                return call_fn(ptr, value);
            }
        };

        return .{
            .context = @ptrCast(context),
            .call_fn = Wrapper.call,
            .next = null,
        };
    }

    pub fn invoke(self: ChainCallback, value: i32) i32 {
        var result = self.call_fn(self.context, value);
        if (self.next) |next| {
            result = next.invoke(result);
        }
        return result;
    }
};

test "callback chain" {
    const Doubler = struct {
        fn apply(_: *@This(), val: i32) i32 {
            return val * 2;
        }
    };

    const Adder = struct {
        amount: i32,

        fn apply(self: *@This(), val: i32) i32 {
            return val + self.amount;
        }
    };

    var doubler = Doubler{};
    var adder = Adder{ .amount = 10 };

    var cb1 = ChainCallback.init(&doubler, Doubler.apply);
    const cb2 = ChainCallback.init(&adder, Adder.apply);
    cb1.next = &cb2;

    const result = cb1.invoke(5); // (5 * 2) + 10 = 20
    try std.testing.expectEqual(@as(i32, 20), result);
}
```

### Callback with Multiple Parameters

Carry complex state with multiple parameters:

```zig
const MultiParamCallback = struct {
    context: *anyopaque,
    call_fn: *const fn (*anyopaque, []const u8, i32, bool) void,

    pub fn init(
        context: anytype,
        comptime call_fn: fn (@TypeOf(context), []const u8, i32, bool) void,
    ) MultiParamCallback {
        const Wrapper = struct {
            fn call(ctx: *anyopaque, s: []const u8, n: i32, b: bool) void {
                const ptr: @TypeOf(context) = @ptrCast(@alignCast(ctx));
                call_fn(ptr, s, n, b);
            }
        };

        return .{
            .context = @ptrCast(context),
            .call_fn = Wrapper.call,
        };
    }

    pub fn invoke(self: MultiParamCallback, s: []const u8, n: i32, b: bool) void {
        self.call_fn(self.context, s, n, b);
    }
};

test "multi param callback" {
    const Collector = struct {
        count: *usize,

        fn collect(self: *@This(), _: []const u8, _: i32, flag: bool) void {
            if (flag) {
                self.count.* += 1;
            }
        }
    };

    var count: usize = 0;
    var collector = Collector{ .count = &count };
    const callback = MultiParamCallback.init(&collector, Collector.collect);

    callback.invoke("test", 42, true);
    callback.invoke("test", 42, false);
    callback.invoke("test", 42, true);

    try std.testing.expectEqual(@as(usize, 2), count);
}
```

### Callback Registry

Register and manage multiple callbacks:

```zig
const CallbackRegistry = struct {
    callbacks: std.ArrayList(Callback),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) CallbackRegistry {
        return .{
            .callbacks = std.ArrayList(Callback){},
            .allocator = allocator,
        };
    }

    pub fn add(self: *CallbackRegistry, callback: Callback) !void {
        try self.callbacks.append(self.allocator, callback);
    }

    pub fn invokeAll(self: CallbackRegistry, value: i32) void {
        for (self.callbacks.items) |callback| {
            callback.invoke(value);
        }
    }

    pub fn deinit(self: *CallbackRegistry) void {
        self.callbacks.deinit(self.allocator);
    }
};

test "callback registry" {
    const allocator = std.testing.allocator;

    const Tracker = struct {
        total: *i32,

        fn track(self: *@This(), value: i32) void {
            self.total.* += value;
        }
    };

    var total: i32 = 0;
    var tracker1 = Tracker{ .total = &total };
    var tracker2 = Tracker{ .total = &total };

    var registry = CallbackRegistry.init(allocator);
    defer registry.deinit();

    try registry.add(Callback.init(&tracker1, Tracker.track));
    try registry.add(Callback.init(&tracker2, Tracker.track));

    registry.invokeAll(10);

    try std.testing.expectEqual(@as(i32, 20), total);
}
```

### Best Practices

**Type Safety:**
```zig
// Good: Type-safe wrapper
const Callback = struct {
    context: *anyopaque,
    call_fn: *const fn (*anyopaque, T) void,

    pub fn init(
        context: anytype,
        comptime call_fn: fn (@TypeOf(context), T) void,
    ) Callback { ... }
};

// Avoid: Raw function pointers without context
const BadCallback = *const fn (i32) void;
```

**Memory Management:**
- Document ownership of context
- Ensure context outlives callback
- Use arena allocators when appropriate
- Be explicit about cleanup requirements

**Error Handling:**
```zig
// Good: Explicit error handling
const ErrorAwareCallback = struct {
    call_fn: *const fn (*anyopaque, T) !void,

    pub fn invoke(self: @This(), value: T) !void {
        return self.call_fn(self.context, value);
    }
};
```

**Thread Safety:**
- Document if callbacks are thread-safe
- Use appropriate synchronization primitives
- Consider atomic operations for counters
- Be explicit about execution context

### Related Functions

- `*anyopaque` for type-erased context
- `@ptrCast()` and `@alignCast()` for type recovery
- `@TypeOf()` for context type inference
- Function pointer types `*const fn(T) R`
- Comptime wrappers for type-safe erasure
