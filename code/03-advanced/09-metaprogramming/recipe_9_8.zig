// Recipe 9.8: Applying Decorators to Struct and Static Methods
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: instance_method_decorator
// Decorate instance methods
fn WithLogging(comptime method: anytype) type {
    return struct {
        const Self = @This();
        call_count: u32 = 0,

        pub fn call(self: *Self, instance: anytype, x: i32) i32 {
            self.call_count += 1;
            return method(instance, x);
        }

        pub fn getCallCount(self: Self) u32 {
            return self.call_count;
        }
    };
}

const Counter = struct {
    value: i32 = 0,

    pub fn add(self: *Counter, x: i32) i32 {
        self.value += x;
        return self.value;
    }
};

test "instance method decorator" {
    var counter = Counter{};
    var logged = WithLogging(Counter.add){};

    const r1 = logged.call(&counter, 5);
    try testing.expectEqual(@as(i32, 5), r1);
    try testing.expectEqual(@as(u32, 1), logged.getCallCount());

    const r2 = logged.call(&counter, 3);
    try testing.expectEqual(@as(i32, 8), r2);
    try testing.expectEqual(@as(u32, 2), logged.getCallCount());
}
// ANCHOR_END: instance_method_decorator

// ANCHOR: static_method_decorator
// Decorate static methods (no self parameter)
fn WithCache(comptime func: anytype) type {
    return struct {
        const Self = @This();
        const CacheEntry = struct {
            input: i32,
            output: i32,
        };

        cache: ?CacheEntry = null,

        pub fn call(self: *Self, x: i32) i32 {
            if (self.cache) |entry| {
                if (entry.input == x) {
                    return entry.output;
                }
            }

            const result = func(x);
            self.cache = CacheEntry{ .input = x, .output = result };
            return result;
        }

        pub fn isCached(self: Self, x: i32) bool {
            if (self.cache) |entry| {
                return entry.input == x;
            }
            return false;
        }
    };
}

const Math = struct {
    pub fn square(x: i32) i32 {
        return x * x;
    }

    pub fn cube(x: i32) i32 {
        return x * x * x;
    }
};

test "static method decorator" {
    var cached = WithCache(Math.square){};

    const r1 = cached.call(5);
    try testing.expectEqual(@as(i32, 25), r1);
    try testing.expect(cached.isCached(5));

    const r2 = cached.call(5);
    try testing.expectEqual(@as(i32, 25), r2);
}
// ANCHOR_END: static_method_decorator

// ANCHOR: generic_method_decorator
// Generic decorator for any method signature
fn MethodDecorator(comptime func: anytype) type {
    const func_info = @typeInfo(@TypeOf(func));
    const ReturnType = func_info.@"fn".return_type.?;

    return struct {
        const Self = @This();
        invocations: u32 = 0,

        pub fn call(self: *Self, args: anytype) ReturnType {
            self.invocations += 1;
            return @call(.auto, func, args);
        }

        pub fn getInvocations(self: Self) u32 {
            return self.invocations;
        }
    };
}

const Calculator = struct {
    multiplier: i32,

    pub fn multiply(self: Calculator, x: i32) i32 {
        return x * self.multiplier;
    }

    pub fn add(a: i32, b: i32) i32 {
        return a + b;
    }
};

test "generic method decorator" {
    const calc = Calculator{ .multiplier = 3 };
    var decorated = MethodDecorator(Calculator.multiply){};

    const result = decorated.call(.{ calc, 5 });
    try testing.expectEqual(@as(i32, 15), result);
    try testing.expectEqual(@as(u32, 1), decorated.getInvocations());

    var static_decorated = MethodDecorator(Calculator.add){};
    const r2 = static_decorated.call(.{ 10, 20 });
    try testing.expectEqual(@as(i32, 30), r2);
}
// ANCHOR_END: generic_method_decorator

// ANCHOR: bound_method_decorator
// Decorator that binds instance to method
fn BoundMethod(comptime Instance: type, comptime method: anytype) type {
    return struct {
        const Self = @This();
        instance: *Instance,
        call_count: u32 = 0,

        pub fn init(instance: *Instance) Self {
            return .{ .instance = instance };
        }

        pub fn call(self: *Self, x: i32) i32 {
            self.call_count += 1;
            return method(self.instance, x);
        }

        pub fn getCallCount(self: Self) u32 {
            return self.call_count;
        }
    };
}

test "bound method decorator" {
    var counter = Counter{};
    var bound = BoundMethod(Counter, Counter.add).init(&counter);

    _ = bound.call(5);
    _ = bound.call(3);

    try testing.expectEqual(@as(i32, 8), counter.value);
    try testing.expectEqual(@as(u32, 2), bound.getCallCount());
}
// ANCHOR_END: bound_method_decorator

// ANCHOR: validation_method_decorator
// Decorator with validation for methods
fn WithValidation(comptime method: anytype, comptime min: i32, comptime max: i32) type {
    return struct {
        const Self = @This();
        validation_errors: u32 = 0,

        pub fn call(self: *Self, instance: anytype, x: i32) !i32 {
            if (x < min or x > max) {
                self.validation_errors += 1;
                return error.OutOfBounds;
            }
            return method(instance, x);
        }

        pub fn getValidationErrors(self: Self) u32 {
            return self.validation_errors;
        }
    };
}

test "validation method decorator" {
    var counter = Counter{};
    var validated = WithValidation(Counter.add, 0, 10){};

    const r1 = try validated.call(&counter, 5);
    try testing.expectEqual(@as(i32, 5), r1);
    try testing.expectEqual(@as(u32, 0), validated.getValidationErrors());

    const r2 = validated.call(&counter, 15);
    try testing.expectError(error.OutOfBounds, r2);
    try testing.expectEqual(@as(u32, 1), validated.getValidationErrors());
}
// ANCHOR_END: validation_method_decorator

// ANCHOR: timing_method_decorator
// Decorator to track method timing
fn WithTiming(comptime method: anytype) type {
    return struct {
        const Self = @This();
        total_time: u64 = 0,
        calls: u32 = 0,

        pub fn call(self: *Self, instance: anytype, x: i32) i32 {
            // In real code, measure actual time
            const elapsed: u64 = 100;
            self.total_time += elapsed;
            self.calls += 1;
            return method(instance, x);
        }

        pub fn getAverageTime(self: Self) u64 {
            if (self.calls == 0) return 0;
            return self.total_time / self.calls;
        }
    };
}

test "timing method decorator" {
    var counter = Counter{};
    var timed = WithTiming(Counter.add){};

    _ = timed.call(&counter, 5);
    _ = timed.call(&counter, 3);

    try testing.expectEqual(@as(u64, 100), timed.getAverageTime());
}
// ANCHOR_END: timing_method_decorator

// ANCHOR: composed_method_decorators
// Compose multiple decorators on methods
fn ComposeDecorators(comptime method: anytype) type {
    return struct {
        const Self = @This();
        log_count: u32 = 0,
        time_count: u32 = 0,

        pub fn call(self: *Self, instance: anytype, x: i32) i32 {
            // Log the call
            self.log_count += 1;
            // Time the call
            self.time_count += 1;
            // Call the method
            const result = method(instance, x);
            // Apply additional transformation
            return result * 2;
        }

        pub fn getLogCount(self: Self) u32 {
            return self.log_count;
        }
    };
}

test "composed method decorators" {
    var counter = Counter{};
    var composed_dec = ComposeDecorators(Counter.add){};

    const result = composed_dec.call(&counter, 5);
    try testing.expectEqual(@as(i32, 10), result); // 5 * 2
    try testing.expectEqual(@as(u32, 1), composed_dec.getLogCount());
}
// ANCHOR_END: composed_method_decorators

// ANCHOR: method_wrapper_struct
// Struct that wraps all methods with decorators
fn DecoratedStruct(comptime T: type) type {
    return struct {
        const Self = @This();
        inner: T,
        add_calls: u32 = 0,

        pub fn init(inner: T) Self {
            return .{ .inner = inner };
        }

        pub fn add(self: *Self, x: i32) i32 {
            self.add_calls += 1;
            return self.inner.add(x);
        }

        pub fn getAddCalls(self: Self) u32 {
            return self.add_calls;
        }
    };
}

test "method wrapper struct" {
    const counter = Counter{};
    var decorated = DecoratedStruct(Counter).init(counter);

    _ = decorated.add(5);
    _ = decorated.add(3);

    try testing.expectEqual(@as(u32, 2), decorated.getAddCalls());
}
// ANCHOR_END: method_wrapper_struct

// ANCHOR: conditional_method_decorator
// Decorator that conditionally applies behavior
fn ConditionalMethod(comptime method: anytype, comptime enabled: bool) type {
    return struct {
        const Self = @This();
        calls_when_enabled: u32 = 0,

        pub fn call(self: *Self, instance: anytype, x: i32) i32 {
            if (enabled) {
                self.calls_when_enabled += 1;
                const result = method(instance, x);
                return result * 2;
            }
            return method(instance, x);
        }

        pub fn getCalls(self: Self) u32 {
            return self.calls_when_enabled;
        }
    };
}

test "conditional method decorator" {
    var counter1 = Counter{};
    var enabled = ConditionalMethod(Counter.add, true){};

    const r1 = enabled.call(&counter1, 5);
    try testing.expectEqual(@as(i32, 10), r1); // 5 * 2
    try testing.expectEqual(@as(u32, 1), enabled.getCalls());

    var counter2 = Counter{};
    var disabled = ConditionalMethod(Counter.add, false){};

    const r2 = disabled.call(&counter2, 5);
    try testing.expectEqual(@as(i32, 5), r2); // No multiplication
    try testing.expectEqual(@as(u32, 0), disabled.getCalls());
}
// ANCHOR_END: conditional_method_decorator

// ANCHOR: memoizing_method
// Decorator that memoizes method results
fn Memoized(comptime method: anytype) type {
    return struct {
        const Self = @This();
        const Entry = struct {
            input: i32,
            output: i32,
        };

        cache: [10]?Entry = [_]?Entry{null} ** 10,
        cache_size: usize = 0,

        pub fn call(self: *Self, instance: anytype, x: i32) i32 {
            // Check cache
            for (self.cache[0..self.cache_size]) |maybe_entry| {
                if (maybe_entry) |entry| {
                    if (entry.input == x) {
                        return entry.output;
                    }
                }
            }

            // Not in cache, compute
            const result = method(instance, x);

            // Add to cache if space
            if (self.cache_size < self.cache.len) {
                self.cache[self.cache_size] = Entry{ .input = x, .output = result };
                self.cache_size += 1;
            }

            return result;
        }

        pub fn getCacheSize(self: Self) usize {
            return self.cache_size;
        }
    };
}

test "memoizing method" {
    var counter = Counter{};
    var memoized = Memoized(Counter.add){};

    _ = memoized.call(&counter, 5);
    _ = memoized.call(&counter, 5); // Should use cache

    try testing.expectEqual(@as(usize, 1), memoized.getCacheSize());
}
// ANCHOR_END: memoizing_method

// ANCHOR: retry_method_decorator
// Decorator with retry logic for methods
fn WithRetry(comptime method: anytype, comptime max_attempts: u32) type {
    return struct {
        const Self = @This();
        retry_count: u32 = 0,

        pub fn call(self: *Self, instance: anytype, x: i32) !i32 {
            var attempt: u32 = 0;
            var last_error: ?anyerror = null;

            while (attempt < max_attempts) : (attempt += 1) {
                self.retry_count += 1;
                const result = method(instance, x) catch |err| {
                    last_error = err;
                    continue;
                };
                return result;
            }

            if (last_error) |err| {
                return err;
            }
            return error.MaxRetriesExceeded;
        }

        pub fn getRetryCount(self: Self) u32 {
            return self.retry_count;
        }
    };
}

const Fallible = struct {
    attempts: u32 = 0,

    pub fn unreliable(self: *Fallible, x: i32) !i32 {
        self.attempts += 1;
        if (self.attempts < 3) {
            return error.Temporary;
        }
        return x * 2;
    }
};

test "retry method decorator" {
    var fallible = Fallible{};
    var retry = WithRetry(Fallible.unreliable, 5){};

    const result = try retry.call(&fallible, 10);
    try testing.expectEqual(@as(i32, 20), result);
    try testing.expectEqual(@as(u32, 3), retry.getRetryCount());
}
// ANCHOR_END: retry_method_decorator

// Comprehensive test
test "comprehensive method decorators" {
    // Instance method decorator
    var counter1 = Counter{};
    var logged = WithLogging(Counter.add){};
    _ = logged.call(&counter1, 5);
    try testing.expectEqual(@as(u32, 1), logged.getCallCount());

    // Static method decorator
    var cached = WithCache(Math.square){};
    try testing.expectEqual(@as(i32, 25), cached.call(5));

    // Generic method decorator
    const calc = Calculator{ .multiplier = 2 };
    var generic = MethodDecorator(Calculator.multiply){};
    try testing.expectEqual(@as(i32, 10), generic.call(.{ calc, 5 }));

    // Bound method decorator
    var counter2 = Counter{};
    var bound = BoundMethod(Counter, Counter.add).init(&counter2);
    _ = bound.call(5);
    try testing.expectEqual(@as(i32, 5), counter2.value);

    // Validation decorator
    var counter3 = Counter{};
    var validated = WithValidation(Counter.add, 0, 10){};
    try testing.expectEqual(@as(i32, 5), try validated.call(&counter3, 5));
}
