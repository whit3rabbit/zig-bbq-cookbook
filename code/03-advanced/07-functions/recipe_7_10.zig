const std = @import("std");

// ANCHOR: basic_callback
/// Basic callback with state
const Callback = struct {
    context: *anyopaque,
    call_fn: *const fn (*anyopaque, i32) void,

    pub fn init(
        context: anytype,
        comptime call_fn: fn (@TypeOf(context), i32) void,
    ) Callback {
        const Wrapper = struct {
            fn call(ctx: *anyopaque, value: i32) void {
                const ptr: @TypeOf(context) = @ptrCast(@alignCast(ctx));
                call_fn(ptr, value);
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
// ANCHOR_END: basic_callback

// ANCHOR: event_system
/// Event system with shared state
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
// ANCHOR_END: event_system

// ANCHOR: advanced_callbacks
/// Callback with allocator
const AllocCallback = struct {
    context: *anyopaque,
    call_fn: *const fn (*anyopaque, std.mem.Allocator, []const u8) anyerror!void,

    pub fn init(
        context: anytype,
        comptime call_fn: fn (@TypeOf(context), std.mem.Allocator, []const u8) anyerror!void,
    ) AllocCallback {
        const Wrapper = struct {
            fn call(ctx: *anyopaque, allocator: std.mem.Allocator, data: []const u8) anyerror!void {
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

/// Error callback
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

/// Timer callback
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
// ANCHOR_END: advanced_callbacks

/// Result callback
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

/// Chain callback
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

/// Multi-param callback
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

/// Callback registry
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

// Tests

test "callback with state" {
    const State = struct {
        sum: i32 = 0,

        fn onValue(self: *@This(), value: i32) void {
            self.sum += value;
        }
    };

    var state = State{};
    const callback = Callback.init(&state, State.onValue);

    callback.invoke(10);
    callback.invoke(20);
    callback.invoke(5);

    try std.testing.expectEqual(@as(i32, 35), state.sum);
}

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

test "error callback" {
    const ErrorTracker = struct {
        last_error: *?anyerror,

        fn track(self: *@This(), err: anyerror) void {
            self.last_error.* = err;
        }
    };

    var last_error: ?anyerror = null;
    var tracker = ErrorTracker{ .last_error = &last_error };
    const callback = ErrorCallback.init(&tracker, ErrorTracker.track);

    callback.invoke(error.OutOfMemory);
    try std.testing.expectEqual(error.OutOfMemory, last_error.?);

    callback.invoke(error.InvalidInput);
    try std.testing.expectEqual(error.InvalidInput, last_error.?);
}

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

    const result = cb1.invoke(5);
    try std.testing.expectEqual(@as(i32, 20), result);
}

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

test "callback multiply" {
    const Multiplier = struct {
        factor: *i32,

        fn multiply(self: *@This(), value: i32) void {
            self.factor.* = value * 2;
        }
    };

    var result: i32 = 0;
    var multiplier = Multiplier{ .factor = &result };
    const callback = Callback.init(&multiplier, Multiplier.multiply);

    callback.invoke(7);
    try std.testing.expectEqual(@as(i32, 14), result);
}

test "multiple timer callbacks" {
    const Counter = struct {
        count: *usize,

        fn increment(self: *@This()) void {
            self.count.* += 1;
        }
    };

    var count: usize = 0;
    var counter = Counter{ .count = &count };

    const timer1 = TimerCallback.init(&counter, Counter.increment, 50);
    const timer2 = TimerCallback.init(&counter, Counter.increment, 100);

    try std.testing.expect(timer1.isReady(50));
    try std.testing.expect(!timer2.isReady(50));

    timer1.invoke();
    try std.testing.expectEqual(@as(usize, 1), count);

    timer2.invoke();
    try std.testing.expectEqual(@as(usize, 2), count);
}

test "result callback with string" {
    const StringReceiver = struct {
        result: *?[]const u8,

        fn onResult(self: *@This(), value: []const u8) void {
            self.result.* = value;
        }
    };

    var result: ?[]const u8 = null;
    var receiver = StringReceiver{ .result = &result };

    const callback = ResultCallback([]const u8).init(&receiver, StringReceiver.onResult);

    callback.invoke("hello");
    try std.testing.expectEqualStrings("hello", result.?);
}

test "event system with three callbacks" {
    const allocator = std.testing.allocator;

    const Accumulator = struct {
        value: *i32,

        fn add(self: *@This(), n: i32) void {
            self.value.* += n;
        }
    };

    var total: i32 = 0;
    var acc1 = Accumulator{ .value = &total };
    var acc2 = Accumulator{ .value = &total };
    var acc3 = Accumulator{ .value = &total };

    var events = EventSystem.init(allocator);
    defer events.deinit();

    try events.register(Callback.init(&acc1, Accumulator.add));
    try events.register(Callback.init(&acc2, Accumulator.add));
    try events.register(Callback.init(&acc3, Accumulator.add));

    events.trigger(3);

    try std.testing.expectEqual(@as(i32, 9), total);
}
