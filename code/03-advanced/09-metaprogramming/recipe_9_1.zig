// Recipe 9.1: Putting a Wrapper Around a Function
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_wrapper
// Basic function wrapper using comptime
fn withLogging(comptime func: anytype) fn (i32) i32 {
    return struct {
        fn wrapper(x: i32) i32 {
            std.debug.print("Calling function with: {d}\n", .{x});
            const result = func(x);
            std.debug.print("Result: {d}\n", .{result});
            return result;
        }
    }.wrapper;
}

fn double(x: i32) i32 {
    return x * 2;
}

test "basic wrapper" {
    const wrapped = withLogging(double);
    const result = wrapped(5);
    try testing.expectEqual(@as(i32, 10), result);
}
// ANCHOR_END: basic_wrapper

// ANCHOR: timing_wrapper
// Wrapper that measures execution time
fn withTiming(comptime func: anytype) fn (i32) i32 {
    return struct {
        fn wrapper(x: i32) i32 {
            const start = std.time.nanoTimestamp();
            const result = func(x);
            const end = std.time.nanoTimestamp();
            const duration = end - start;
            std.debug.print("Execution time: {d}ns\n", .{duration});
            return result;
        }
    }.wrapper;
}

fn slowFunction(x: i32) i32 {
    var sum: i32 = 0;
    var i: i32 = 0;
    while (i < x) : (i += 1) {
        sum += i;
    }
    return sum;
}

test "timing wrapper" {
    const wrapped = withTiming(slowFunction);
    const result = wrapped(100);
    try testing.expect(result >= 0);
}
// ANCHOR_END: timing_wrapper

// ANCHOR: error_wrapper
// Wrapper that adds error handling
fn withErrorHandling(comptime func: anytype) fn (i32) anyerror!i32 {
    return struct {
        fn wrapper(x: i32) anyerror!i32 {
            if (x < 0) {
                std.debug.print("Warning: negative input {d}\n", .{x});
            }
            return func(x);
        }
    }.wrapper;
}

fn safeDivide(x: i32) anyerror!i32 {
    if (x == 0) return error.DivisionByZero;
    return @divTrunc(100, x);
}

test "error wrapper" {
    const wrapped = withErrorHandling(safeDivide);
    const result = try wrapped(10);
    try testing.expectEqual(@as(i32, 10), result);

    const err_result = wrapped(0);
    try testing.expectError(error.DivisionByZero, err_result);
}
// ANCHOR_END: error_wrapper

// ANCHOR: generic_wrapper
// Generic wrapper for any function signature
fn GenericWrapper(comptime func: anytype) type {
    const FuncInfo = @typeInfo(@TypeOf(func));
    const ReturnType = switch (FuncInfo) {
        .@"fn" => |f| f.return_type.?,
        else => @compileError("Expected function"),
    };

    return struct {
        call_count: usize = 0,

        pub fn call(self: *@This(), args: anytype) ReturnType {
            self.call_count += 1;
            return @call(.auto, func, args);
        }

        pub fn getCallCount(self: *const @This()) usize {
            return self.call_count;
        }
    };
}

fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "generic wrapper" {
    const Wrapper = GenericWrapper(add);
    var wrapper = Wrapper{};

    const r1 = wrapper.call(.{ 5, 3 });
    const r2 = wrapper.call(.{ 10, 20 });

    try testing.expectEqual(@as(i32, 8), r1);
    try testing.expectEqual(@as(i32, 30), r2);
    try testing.expectEqual(@as(usize, 2), wrapper.getCallCount());
}
// ANCHOR_END: generic_wrapper

// ANCHOR: caching_wrapper
// Wrapper that caches results
fn WithCache(comptime func: anytype) type {
    return struct {
        cache: ?i32 = null,
        cache_key: ?i32 = null,

        pub fn call(self: *@This(), x: i32) i32 {
            if (self.cache_key) |key| {
                if (key == x) {
                    return self.cache.?;
                }
            }

            const result = func(x);
            self.cache = result;
            self.cache_key = x;
            return result;
        }
    };
}

fn expensive(x: i32) i32 {
    var result: i32 = 0;
    var i: i32 = 0;
    while (i < x) : (i += 1) {
        result += i * i;
    }
    return result;
}

test "caching wrapper" {
    const CachedFunc = WithCache(expensive);
    var cached = CachedFunc{};

    const r1 = cached.call(10);
    const r2 = cached.call(10); // Should use cache
    const r3 = cached.call(20); // New computation

    try testing.expectEqual(r1, r2);
    try testing.expect(r3 > r1);
}
// ANCHOR_END: caching_wrapper

// ANCHOR: validation_wrapper
// Wrapper that validates inputs
fn WithValidation(comptime func: anytype, comptime min: i32, comptime max: i32) type {
    return struct {
        pub fn call(x: i32) !i32 {
            if (x < min or x > max) {
                return error.OutOfRange;
            }
            return func(x);
        }
    };
}

fn processValue(x: i32) i32 {
    return x * x;
}

test "validation wrapper" {
    const ValidatedFunc = WithValidation(processValue, 0, 100);

    const r1 = try ValidatedFunc.call(50);
    try testing.expectEqual(@as(i32, 2500), r1);

    const r2 = ValidatedFunc.call(150);
    try testing.expectError(error.OutOfRange, r2);

    const r3 = ValidatedFunc.call(-5);
    try testing.expectError(error.OutOfRange, r3);
}
// ANCHOR_END: validation_wrapper

// ANCHOR: retry_wrapper
// Wrapper that retries on failure
fn WithRetry(comptime func: anytype, comptime max_retries: u32) type {
    return struct {
        pub fn call(x: i32) !i32 {
            var attempts: u32 = 0;
            var last_error: ?anyerror = null;

            while (attempts < max_retries) : (attempts += 1) {
                const result = func(x) catch |err| {
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
    };
}

var fail_count: u32 = 0;

fn unreliable(x: i32) !i32 {
    fail_count += 1;
    if (fail_count < 3) {
        return error.Temporary;
    }
    return x * 2;
}

test "retry wrapper" {
    fail_count = 0;
    const RetriedFunc = WithRetry(unreliable, 5);

    const result = try RetriedFunc.call(10);
    try testing.expectEqual(@as(i32, 20), result);
    try testing.expectEqual(@as(u32, 3), fail_count);
}
// ANCHOR_END: retry_wrapper

// ANCHOR: chaining_wrappers
// Chaining multiple wrappers together
fn compose(comptime f: anytype, comptime g: anytype) fn (i32) i32 {
    return struct {
        fn wrapper(x: i32) i32 {
            return f(g(x));
        }
    }.wrapper;
}

fn increment(x: i32) i32 {
    return x + 1;
}

fn triple(x: i32) i32 {
    return x * 3;
}

test "chaining wrappers" {
    // (x + 1) * 3
    const composed = compose(triple, increment);
    const result = composed(5);
    try testing.expectEqual(@as(i32, 18), result); // (5 + 1) * 3 = 18
}
// ANCHOR_END: chaining_wrappers

// ANCHOR: state_wrapper
// Wrapper that maintains state across calls
fn WithState(comptime func: anytype) type {
    return struct {
        total_calls: usize = 0,
        total_sum: i32 = 0,

        pub fn call(self: *@This(), x: i32) i32 {
            self.total_calls += 1;
            const result = func(x);
            self.total_sum += result;
            return result;
        }

        pub fn getAverage(self: *const @This()) i32 {
            if (self.total_calls == 0) return 0;
            return @divTrunc(self.total_sum, @as(i32, @intCast(self.total_calls)));
        }
    };
}

fn identity(x: i32) i32 {
    return x;
}

test "state wrapper" {
    const StatefulFunc = WithState(identity);
    var stateful = StatefulFunc{};

    _ = stateful.call(10);
    _ = stateful.call(20);
    _ = stateful.call(30);

    try testing.expectEqual(@as(usize, 3), stateful.total_calls);
    try testing.expectEqual(@as(i32, 20), stateful.getAverage());
}
// ANCHOR_END: state_wrapper

// ANCHOR: conditional_wrapper
// Wrapper that conditionally executes
fn ConditionalWrapper(comptime func: anytype, comptime enable: bool) type {
    if (enable) {
        return struct {
            pub fn call(x: i32) i32 {
                std.debug.print("Enabled wrapper\n", .{});
                return func(x);
            }
        };
    } else {
        return struct {
            pub fn call(x: i32) i32 {
                return func(x);
            }
        };
    }
}

fn simpleFunc(x: i32) i32 {
    return x + 5;
}

test "conditional wrapper" {
    const EnabledWrapper = ConditionalWrapper(simpleFunc, true);
    const DisabledWrapper = ConditionalWrapper(simpleFunc, false);

    const r1 = EnabledWrapper.call(10);
    const r2 = DisabledWrapper.call(10);

    try testing.expectEqual(r1, r2);
    try testing.expectEqual(@as(i32, 15), r1);
}
// ANCHOR_END: conditional_wrapper

// Comprehensive test
test "comprehensive function wrappers" {
    // Test basic wrapper
    const wrapped_double = withLogging(double);
    try testing.expectEqual(@as(i32, 20), wrapped_double(10));

    // Test timing wrapper
    const timed = withTiming(slowFunction);
    _ = timed(50);

    // Test generic wrapper with state
    const Wrapper = GenericWrapper(add);
    var wrapper = Wrapper{};
    _ = wrapper.call(.{ 1, 2 });
    _ = wrapper.call(.{ 3, 4 });
    try testing.expectEqual(@as(usize, 2), wrapper.getCallCount());

    // Test caching
    const CachedFunc = WithCache(expensive);
    var cached = CachedFunc{};
    const c1 = cached.call(5);
    const c2 = cached.call(5);
    try testing.expectEqual(c1, c2);

    // Test composition
    const composed = compose(triple, increment);
    try testing.expectEqual(@as(i32, 18), composed(5));
}
