// Recipe 9.4: Defining a Decorator That Takes Arguments
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_parameterized
// Decorator that takes compile-time arguments
fn WithMultiplier(comptime func: anytype, comptime multiplier: i32) type {
    return struct {
        pub fn call(x: i32) i32 {
            return func(x) * multiplier;
        }
    };
}

fn identity(x: i32) i32 {
    return x;
}

test "basic parameterized" {
    const Times2 = WithMultiplier(identity, 2);
    const Times10 = WithMultiplier(identity, 10);

    try testing.expectEqual(@as(i32, 10), Times2.call(5));
    try testing.expectEqual(@as(i32, 50), Times10.call(5));
}
// ANCHOR_END: basic_parameterized

// ANCHOR: validation_decorator
// Decorator with validation bounds
fn WithBounds(comptime func: anytype, comptime min: i32, comptime max: i32) type {
    return struct {
        pub fn call(x: i32) !i32 {
            if (x < min or x > max) {
                return error.OutOfBounds;
            }
            return func(x);
        }

        pub fn getMin() i32 {
            return min;
        }

        pub fn getMax() i32 {
            return max;
        }
    };
}

fn square(x: i32) i32 {
    return x * x;
}

test "validation decorator" {
    const BoundedSquare = WithBounds(square, 0, 10);

    const r1 = try BoundedSquare.call(5);
    try testing.expectEqual(@as(i32, 25), r1);

    const r2 = BoundedSquare.call(15);
    try testing.expectError(error.OutOfBounds, r2);

    try testing.expectEqual(@as(i32, 0), BoundedSquare.getMin());
    try testing.expectEqual(@as(i32, 10), BoundedSquare.getMax());
}
// ANCHOR_END: validation_decorator

// ANCHOR: retry_decorator
// Decorator with retry configuration
fn WithRetry(comptime func: anytype, comptime max_attempts: u32, comptime delay_ms: u64) type {
    return struct {
        pub fn call(x: i32) !i32 {
            var attempts: u32 = 0;
            var last_error: ?anyerror = null;

            while (attempts < max_attempts) : (attempts += 1) {
                const result = func(x) catch |err| {
                    last_error = err;
                    // In real code, would sleep for delay_ms milliseconds
                    continue;
                };
                return result;
            }

            if (last_error) |err| {
                return err;
            }
            return error.MaxRetriesExceeded;
        }

        pub fn getMaxAttempts() u32 {
            return max_attempts;
        }

        pub fn getDelay() u64 {
            return delay_ms;
        }
    };
}

var attempt_count: u32 = 0;

fn unreliable(x: i32) !i32 {
    attempt_count += 1;
    if (attempt_count < 3) {
        return error.Temporary;
    }
    return x * 2;
}

test "retry decorator" {
    attempt_count = 0;
    const Retried = WithRetry(unreliable, 5, 100);

    const result = try Retried.call(10);
    try testing.expectEqual(@as(i32, 20), result);
    try testing.expectEqual(@as(u32, 3), attempt_count);

    try testing.expectEqual(@as(u32, 5), Retried.getMaxAttempts());
    try testing.expectEqual(@as(u64, 100), Retried.getDelay());
}
// ANCHOR_END: retry_decorator

// ANCHOR: prefix_suffix_decorator
// Decorator with string configuration
fn WithPrefixSuffix(comptime func: anytype, comptime prefix: []const u8, comptime suffix: []const u8) type {
    return struct {
        pub fn call(allocator: std.mem.Allocator, x: i32) ![]u8 {
            const result = try func(allocator, x);
            defer allocator.free(result);

            const full = try std.fmt.allocPrint(
                allocator,
                "{s}{s}{s}",
                .{ prefix, result, suffix },
            );
            return full;
        }
    };
}

fn formatNumber(allocator: std.mem.Allocator, x: i32) ![]u8 {
    return try std.fmt.allocPrint(allocator, "{d}", .{x});
}

test "prefix suffix decorator" {
    const Bracketed = WithPrefixSuffix(formatNumber, "[", "]");

    const result = try Bracketed.call(testing.allocator, 42);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("[42]", result);
}
// ANCHOR_END: prefix_suffix_decorator

// ANCHOR: typed_decorator
// Decorator that takes a type parameter
fn WithDefault(comptime func: anytype, comptime T: type, comptime default: T) type {
    const func_info = @typeInfo(@TypeOf(func));
    const ReturnType = func_info.@"fn".return_type.?;

    return struct {
        pub fn call(x: ?T) ReturnType {
            const val = x orelse default;
            return func(val);
        }

        pub fn getDefault() T {
            return default;
        }
    };
}

fn double(x: i32) i32 {
    return x * 2;
}

test "typed decorator" {
    const DoubleWithDefault = WithDefault(double, i32, 10);

    const r1 = DoubleWithDefault.call(5);
    const r2 = DoubleWithDefault.call(null);

    try testing.expectEqual(@as(i32, 10), r1);
    try testing.expectEqual(@as(i32, 20), r2);
    try testing.expectEqual(@as(i32, 10), DoubleWithDefault.getDefault());
}
// ANCHOR_END: typed_decorator

// ANCHOR: callback_decorator
// Decorator with callback functions
fn WithCallbacks(
    comptime func: anytype,
    comptime before: anytype,
    comptime after: anytype,
) type {
    return struct {
        pub fn call(x: i32) i32 {
            before(x);
            const result = func(x);
            after(result);
            return result;
        }
    };
}

var before_value: i32 = 0;
var after_value: i32 = 0;

fn logBefore(x: i32) void {
    before_value = x;
}

fn logAfter(x: i32) void {
    after_value = x;
}

fn triple(x: i32) i32 {
    return x * 3;
}

test "callback decorator" {
    before_value = 0;
    after_value = 0;

    const Instrumented = WithCallbacks(triple, logBefore, logAfter);

    const result = Instrumented.call(5);

    try testing.expectEqual(@as(i32, 15), result);
    try testing.expectEqual(@as(i32, 5), before_value);
    try testing.expectEqual(@as(i32, 15), after_value);
}
// ANCHOR_END: callback_decorator

// ANCHOR: conditional_decorator
// Decorator with boolean flag
fn Conditional(comptime func: anytype, comptime enabled: bool) type {
    if (enabled) {
        return struct {
            pub fn call(x: i32) i32 {
                const result = func(x);
                return result * 2; // Apply transformation
            }

            pub fn isEnabled() bool {
                return true;
            }
        };
    } else {
        return struct {
            pub fn call(x: i32) i32 {
                return func(x); // Pass through
            }

            pub fn isEnabled() bool {
                return false;
            }
        };
    }
}

fn add10(x: i32) i32 {
    return x + 10;
}

test "conditional decorator" {
    const Enabled = Conditional(add10, true);
    const Disabled = Conditional(add10, false);

    try testing.expectEqual(@as(i32, 30), Enabled.call(5)); // (5 + 10) * 2
    try testing.expectEqual(@as(i32, 15), Disabled.call(5)); // 5 + 10

    try testing.expect(Enabled.isEnabled());
    try testing.expect(!Disabled.isEnabled());
}
// ANCHOR_END: conditional_decorator

// ANCHOR: threshold_decorator
// Decorator with threshold check
fn WithThreshold(comptime func: anytype, comptime threshold: i32, comptime action: enum { clamp, error_on_exceed }) type {
    return struct {
        pub fn call(x: i32) !i32 {
            if (x > threshold) {
                switch (action) {
                    .clamp => {
                        const result = func(threshold);
                        return result;
                    },
                    .error_on_exceed => {
                        return error.ThresholdExceeded;
                    },
                }
            }
            return func(x);
        }

        pub fn getThreshold() i32 {
            return threshold;
        }
    };
}

test "threshold decorator" {
    const Clamped = WithThreshold(double, 10, .clamp);
    const ErrorBased = WithThreshold(double, 10, .error_on_exceed);

    try testing.expectEqual(@as(i32, 10), try Clamped.call(5));
    try testing.expectEqual(@as(i32, 20), try Clamped.call(15)); // Clamped to 10

    try testing.expectEqual(@as(i32, 10), try ErrorBased.call(5));
    try testing.expectError(error.ThresholdExceeded, ErrorBased.call(15));
}
// ANCHOR_END: threshold_decorator

// ANCHOR: multi_param_decorator
// Decorator with multiple parameters
fn WithConfig(
    comptime func: anytype,
    comptime config: struct {
        multiplier: i32,
        offset: i32,
        invert: bool,
    },
) type {
    return struct {
        pub fn call(x: i32) i32 {
            var result = func(x);
            result = result * config.multiplier;
            result = result + config.offset;
            if (config.invert) {
                result = -result;
            }
            return result;
        }

        pub fn getConfig() @TypeOf(config) {
            return config;
        }
    };
}

test "multi param decorator" {
    const Configured = WithConfig(identity, .{
        .multiplier = 2,
        .offset = 5,
        .invert = false,
    });

    const Inverted = WithConfig(identity, .{
        .multiplier = 1,
        .offset = 0,
        .invert = true,
    });

    try testing.expectEqual(@as(i32, 15), Configured.call(5)); // (5 * 2) + 5
    try testing.expectEqual(@as(i32, -5), Inverted.call(5)); // -(5)

    const cfg = Configured.getConfig();
    try testing.expectEqual(@as(i32, 2), cfg.multiplier);
}
// ANCHOR_END: multi_param_decorator

// ANCHOR: array_param_decorator
// Decorator with array parameter
fn WithAllowList(comptime func: anytype, comptime allowed: []const i32) type {
    return struct {
        pub fn call(x: i32) !i32 {
            for (allowed) |val| {
                if (x == val) {
                    return func(x);
                }
            }
            return error.NotAllowed;
        }

        pub fn getAllowed() []const i32 {
            return allowed;
        }
    };
}

test "array param decorator" {
    const allowed_values = [_]i32{ 1, 5, 10, 15 };
    const Restricted = WithAllowList(double, &allowed_values);

    const r1 = try Restricted.call(5);
    try testing.expectEqual(@as(i32, 10), r1);

    const r2 = Restricted.call(7);
    try testing.expectError(error.NotAllowed, r2);

    try testing.expectEqual(@as(usize, 4), Restricted.getAllowed().len);
}
// ANCHOR_END: array_param_decorator

// Comprehensive test
test "comprehensive parameterized decorators" {
    // Test multiplier
    const Times3 = WithMultiplier(identity, 3);
    try testing.expectEqual(@as(i32, 15), Times3.call(5));

    // Test bounds
    const Bounded = WithBounds(square, 1, 5);
    try testing.expectEqual(@as(i32, 16), try Bounded.call(4));

    // Test conditional
    const Enabled = Conditional(add10, true);
    try testing.expectEqual(@as(i32, 30), Enabled.call(5));

    // Test threshold
    const Clamped = WithThreshold(double, 8, .clamp);
    try testing.expectEqual(@as(i32, 16), try Clamped.call(10));

    // Test multi-param
    const Configured = WithConfig(identity, .{ .multiplier = 2, .offset = 3, .invert = false });
    try testing.expectEqual(@as(i32, 13), Configured.call(5));
}
