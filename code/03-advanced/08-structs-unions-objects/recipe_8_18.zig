// Recipe 8.18: Extending Classes with Mixins
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_mixin
// Basic mixin pattern - wrapping a type with additional functionality
fn WithLogging(comptime T: type) type {
    return struct {
        inner: T,
        log_count: u32,

        const Self = @This();

        pub fn init(inner: T) Self {
            return Self{
                .inner = inner,
                .log_count = 0,
            };
        }

        pub fn execute(self: *Self) void {
            self.log_count += 1;
            if (@hasDecl(T, "execute")) {
                self.inner.execute();
            }
        }

        pub fn getLogCount(self: *const Self) u32 {
            return self.log_count;
        }

        pub fn getInner(self: *Self) *T {
            return &self.inner;
        }
    };
}

const SimpleTask = struct {
    count: u32,

    pub fn init() SimpleTask {
        return SimpleTask{ .count = 0 };
    }

    pub fn execute(self: *SimpleTask) void {
        self.count += 1;
    }
};

test "basic mixin" {
    const task = SimpleTask.init();
    var logged = WithLogging(SimpleTask).init(task);

    logged.execute();
    logged.execute();
    logged.execute();

    try testing.expectEqual(@as(u32, 3), logged.getLogCount());
    try testing.expectEqual(@as(u32, 3), logged.getInner().count);
}
// ANCHOR_END: basic_mixin

// ANCHOR: multiple_mixins
// Composing multiple mixins
fn WithTiming(comptime T: type) type {
    return struct {
        inner: T,
        last_duration_ns: u64,

        const Self = @This();

        pub fn init(inner: T) Self {
            return Self{
                .inner = inner,
                .last_duration_ns = 0,
            };
        }

        pub fn execute(self: *Self) void {
            const start = std.time.nanoTimestamp();
            if (@hasDecl(T, "execute")) {
                self.inner.execute();
            }
            const end = std.time.nanoTimestamp();
            self.last_duration_ns = @intCast(end - start);
        }

        pub fn getDuration(self: *const Self) u64 {
            return self.last_duration_ns;
        }

        pub fn getInner(self: *Self) *T {
            return &self.inner;
        }
    };
}

test "multiple mixins" {
    const task = SimpleTask.init();
    const logged = WithLogging(SimpleTask).init(task);
    var timed = WithTiming(WithLogging(SimpleTask)).init(logged);

    timed.execute();

    try testing.expect(timed.getDuration() >= 0);
    try testing.expectEqual(@as(u32, 1), timed.getInner().getLogCount());
}
// ANCHOR_END: multiple_mixins

// ANCHOR: validation_mixin
// Validation mixin
fn WithValidation(comptime T: type) type {
    return struct {
        inner: T,
        validation_errors: u32,

        const Self = @This();

        pub fn init(inner: T) Self {
            return Self{
                .inner = inner,
                .validation_errors = 0,
            };
        }

        pub fn setValue(self: *Self, value: i32) !void {
            if (value < 0) {
                self.validation_errors += 1;
                return error.InvalidValue;
            }
            if (@hasDecl(T, "setValue")) {
                try self.inner.setValue(value);
            }
        }

        pub fn getValidationErrors(self: *const Self) u32 {
            return self.validation_errors;
        }

        pub fn getInner(self: *Self) *T {
            return &self.inner;
        }
    };
}

const Counter = struct {
    value: i32,

    pub fn init() Counter {
        return Counter{ .value = 0 };
    }

    pub fn setValue(self: *Counter, value: i32) !void {
        self.value = value;
    }
};

test "validation mixin" {
    const counter = Counter.init();
    var validated = WithValidation(Counter).init(counter);

    try validated.setValue(10);
    try testing.expectEqual(@as(i32, 10), validated.getInner().value);

    const result = validated.setValue(-5);
    try testing.expectError(error.InvalidValue, result);
    try testing.expectEqual(@as(u32, 1), validated.getValidationErrors());
}
// ANCHOR_END: validation_mixin

// ANCHOR: caching_mixin
// Caching mixin
fn WithCache(comptime T: type, comptime CacheType: type) type {
    return struct {
        inner: T,
        cache: ?CacheType,
        cache_hits: u32,

        const Self = @This();

        pub fn init(inner: T) Self {
            return Self{
                .inner = inner,
                .cache = null,
                .cache_hits = 0,
            };
        }

        pub fn compute(self: *Self) CacheType {
            if (self.cache) |cached| {
                self.cache_hits += 1;
                return cached;
            }

            const result = if (@hasDecl(T, "compute"))
                self.inner.compute()
            else
                @as(CacheType, 0);

            self.cache = result;
            return result;
        }

        pub fn invalidate(self: *Self) void {
            self.cache = null;
        }

        pub fn getCacheHits(self: *const Self) u32 {
            return self.cache_hits;
        }
    };
}

const ExpensiveComputation = struct {
    base: i32,

    pub fn init(base: i32) ExpensiveComputation {
        return ExpensiveComputation{ .base = base };
    }

    pub fn compute(self: *const ExpensiveComputation) i32 {
        return self.base * self.base;
    }
};

test "caching mixin" {
    const comp = ExpensiveComputation.init(5);
    var cached = WithCache(ExpensiveComputation, i32).init(comp);

    const result1 = cached.compute();
    try testing.expectEqual(@as(i32, 25), result1);
    try testing.expectEqual(@as(u32, 0), cached.getCacheHits());

    const result2 = cached.compute();
    try testing.expectEqual(@as(i32, 25), result2);
    try testing.expectEqual(@as(u32, 1), cached.getCacheHits());

    cached.invalidate();
    const result3 = cached.compute();
    try testing.expectEqual(@as(i32, 25), result3);
    try testing.expectEqual(@as(u32, 1), cached.getCacheHits());
}
// ANCHOR_END: caching_mixin

// ANCHOR: serializable_mixin
// Serialization mixin
fn Serializable(comptime T: type) type {
    return struct {
        inner: T,

        const Self = @This();

        pub fn init(inner: T) Self {
            return Self{ .inner = inner };
        }

        pub fn toBytes(self: *const Self, buffer: []u8) !usize {
            if (buffer.len < @sizeOf(T)) return error.BufferTooSmall;
            const bytes = std.mem.asBytes(&self.inner);
            @memcpy(buffer[0..bytes.len], bytes);
            return bytes.len;
        }

        pub fn fromBytes(bytes: []const u8) !Self {
            if (bytes.len < @sizeOf(T)) return error.BufferTooSmall;
            var inner: T = undefined;
            const dest = std.mem.asBytes(&inner);
            @memcpy(dest, bytes[0..dest.len]);
            return Self{ .inner = inner };
        }

        pub fn getInner(self: *const Self) *const T {
            return &self.inner;
        }
    };
}

const Coordinate = struct {
    x: i32,
    y: i32,
};

test "serializable mixin" {
    const coord = Coordinate{ .x = 10, .y = 20 };
    const serializable = Serializable(Coordinate).init(coord);

    var buffer: [16]u8 = undefined;
    const written = try serializable.toBytes(&buffer);
    try testing.expect(written == @sizeOf(Coordinate));

    const deserialized = try Serializable(Coordinate).fromBytes(buffer[0..written]);
    try testing.expectEqual(@as(i32, 10), deserialized.getInner().x);
    try testing.expectEqual(@as(i32, 20), deserialized.getInner().y);
}
// ANCHOR_END: serializable_mixin

// ANCHOR: observable_mixin
// Observable mixin with callbacks
fn Observable(comptime T: type) type {
    return struct {
        inner: T,
        observers: u32,

        const Self = @This();

        pub fn init(inner: T) Self {
            return Self{
                .inner = inner,
                .observers = 0,
            };
        }

        pub fn notify(self: *Self) void {
            self.observers += 1;
        }

        pub fn modify(self: *Self, value: anytype) void {
            if (@hasDecl(T, "setValue")) {
                self.inner.setValue(value) catch {};
            }
            self.notify();
        }

        pub fn getNotificationCount(self: *const Self) u32 {
            return self.observers;
        }

        pub fn getInner(self: *Self) *T {
            return &self.inner;
        }
    };
}

test "observable mixin" {
    const counter = Counter.init();
    var observable = Observable(Counter).init(counter);

    observable.modify(5);
    observable.modify(10);

    try testing.expectEqual(@as(u32, 2), observable.getNotificationCount());
    try testing.expectEqual(@as(i32, 10), observable.getInner().value);
}
// ANCHOR_END: observable_mixin

// ANCHOR: retry_mixin
// Retry mixin for error handling
fn WithRetry(comptime T: type, comptime max_retries: u32) type {
    return struct {
        inner: T,
        retry_count: u32,

        const Self = @This();

        pub fn init(inner: T) Self {
            return Self{
                .inner = inner,
                .retry_count = 0,
            };
        }

        pub fn execute(self: *Self) !void {
            var attempts: u32 = 0;
            while (attempts < max_retries) : (attempts += 1) {
                if (@hasDecl(T, "execute")) {
                    self.inner.execute() catch |err| {
                        self.retry_count += 1;
                        if (attempts == max_retries - 1) {
                            return err;
                        }
                        continue;
                    };
                    return;
                }
            }
        }

        pub fn getRetryCount(self: *const Self) u32 {
            return self.retry_count;
        }
    };
}

const FailingTask = struct {
    failures_left: u32,

    pub fn init(failures: u32) FailingTask {
        return FailingTask{ .failures_left = failures };
    }

    pub fn execute(self: *FailingTask) !void {
        if (self.failures_left > 0) {
            self.failures_left -= 1;
            return error.TemporaryFailure;
        }
    }
};

test "retry mixin" {
    const task = FailingTask.init(2);
    var with_retry = WithRetry(FailingTask, 5).init(task);

    try with_retry.execute();
    try testing.expectEqual(@as(u32, 2), with_retry.getRetryCount());
}
// ANCHOR_END: retry_mixin

// ANCHOR: conditional_mixin
// Conditional mixin based on comptime
fn WithDebug(comptime T: type, comptime enable_debug: bool) type {
    if (enable_debug) {
        return struct {
            inner: T,
            debug_info: []const u8,

            const Self = @This();

            pub fn init(inner: T) Self {
                return Self{
                    .inner = inner,
                    .debug_info = "Debug enabled",
                };
            }

            pub fn execute(self: *Self) void {
                // Debug wrapper
                if (@hasDecl(T, "execute")) {
                    self.inner.execute();
                }
            }

            pub fn getDebugInfo(self: *const Self) []const u8 {
                return self.debug_info;
            }

            pub fn getInner(self: *Self) *T {
                return &self.inner;
            }
        };
    } else {
        return struct {
            inner: T,

            const Self = @This();

            pub fn init(inner: T) Self {
                return Self{ .inner = inner };
            }

            pub fn execute(self: *Self) void {
                if (@hasDecl(T, "execute")) {
                    self.inner.execute();
                }
            }

            pub fn getInner(self: *Self) *T {
                return &self.inner;
            }
        };
    }
}

test "conditional mixin" {
    const task1 = SimpleTask.init();
    var debug_enabled = WithDebug(SimpleTask, true).init(task1);
    debug_enabled.execute();
    try testing.expectEqualStrings("Debug enabled", debug_enabled.getDebugInfo());

    const task2 = SimpleTask.init();
    var debug_disabled = WithDebug(SimpleTask, false).init(task2);
    debug_disabled.execute();
    try testing.expectEqual(@as(u32, 1), debug_disabled.getInner().count);
}
// ANCHOR_END: conditional_mixin

// ANCHOR: builder_mixin
// Builder mixin for fluent interfaces
fn Buildable(comptime T: type) type {
    return struct {
        inner: T,

        const Self = @This();

        pub fn init() Self {
            return Self{
                .inner = if (@hasDecl(T, "init")) T.init() else undefined,
            };
        }

        pub fn with(_: Self, inner: T) Self {
            return Self{ .inner = inner };
        }

        pub fn build(self: Self) T {
            return self.inner;
        }

        pub fn getInner(self: *Self) *T {
            return &self.inner;
        }
    };
}

test "builder mixin" {
    const builder = Buildable(Counter).init();
    var counter = Counter.init();
    counter.value = 42;

    const result = builder.with(counter).build();
    try testing.expectEqual(@as(i32, 42), result.value);
}
// ANCHOR_END: builder_mixin

// ANCHOR: thread_safe_mixin
// Thread-safety mixin (conceptual - would use real mutex in production)
fn ThreadSafe(comptime T: type) type {
    return struct {
        inner: T,
        lock_count: u32,

        const Self = @This();

        pub fn init(inner: T) Self {
            return Self{
                .inner = inner,
                .lock_count = 0,
            };
        }

        pub fn withLock(self: *Self, comptime func: anytype) void {
            self.lock_count += 1;
            defer self.lock_count -= 1;
            func(&self.inner);
        }

        pub fn getLockCount(self: *const Self) u32 {
            return self.lock_count;
        }

        pub fn getInner(self: *Self) *T {
            return &self.inner;
        }
    };
}

test "thread safe mixin" {
    const counter = Counter.init();
    var safe = ThreadSafe(Counter).init(counter);

    safe.withLock(struct {
        fn call(c: *Counter) void {
            c.value = 100;
        }
    }.call);

    try testing.expectEqual(@as(i32, 100), safe.getInner().value);
    try testing.expectEqual(@as(u32, 0), safe.getLockCount());
}
// ANCHOR_END: thread_safe_mixin

// Comprehensive test
test "comprehensive mixin patterns" {
    // Stack mixins
    const task = SimpleTask.init();
    const logged = WithLogging(SimpleTask).init(task);
    var timed = WithTiming(WithLogging(SimpleTask)).init(logged);

    timed.execute();
    try testing.expect(timed.getInner().getLogCount() > 0);

    // Validation
    const counter = Counter.init();
    var validated = WithValidation(Counter).init(counter);
    try validated.setValue(5);
    try testing.expectEqual(@as(i32, 5), validated.getInner().value);

    // Caching
    const comp = ExpensiveComputation.init(10);
    var cached = WithCache(ExpensiveComputation, i32).init(comp);
    _ = cached.compute();
    _ = cached.compute();
    try testing.expectEqual(@as(u32, 1), cached.getCacheHits());
}
