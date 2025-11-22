// Recipe 9.9: Writing Decorators That Add Arguments to Wrapped Functions
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: inject_allocator
// Decorator that injects allocator as first argument
// NOTE: The wrapped function MUST accept the allocator as its first parameter.
// This follows Zig stdlib conventions where allocator is typically the first argument
// to init/create functions (e.g., ArrayList.init(allocator), alloc(allocator, size)).
// If your function has a different signature, use a different decorator pattern.
fn WithAllocator(comptime func: anytype, comptime allocator: std.mem.Allocator) type {
    return struct {
        const Self = @This();

        pub fn call(args: anytype) @TypeOf(@call(.auto, func, .{allocator} ++ args)) {
            return @call(.auto, func, .{allocator} ++ args);
        }
    };
}

fn createSlice(allocator: std.mem.Allocator, size: usize) ![]i32 {
    return try allocator.alloc(i32, size);
}

test "inject allocator" {
    const WithTestAllocator = WithAllocator(createSlice, testing.allocator);

    const slice = try WithTestAllocator.call(.{5});
    defer testing.allocator.free(slice);

    try testing.expectEqual(@as(usize, 5), slice.len);
}
// ANCHOR_END: inject_allocator

// ANCHOR: inject_context
// Decorator that injects context object
fn WithContext(comptime func: anytype, comptime Context: type, comptime context: Context) type {
    return struct {
        const Self = @This();

        pub fn call(args: anytype) @TypeOf(@call(.auto, func, .{context} ++ args)) {
            return @call(.auto, func, .{context} ++ args);
        }
    };
}

const Config = struct {
    multiplier: i32,
    offset: i32,
};

fn transform(config: Config, x: i32) i32 {
    return (x * config.multiplier) + config.offset;
}

test "inject context" {
    const config = Config{ .multiplier = 2, .offset = 5 };
    const Configured = WithContext(transform, Config, config);

    const result = Configured.call(.{10});
    try testing.expectEqual(@as(i32, 25), result); // (10 * 2) + 5
}
// ANCHOR_END: inject_context

// ANCHOR: prepend_arguments
// Decorator that prepends arguments
fn PrependArgs(comptime func: anytype, comptime prepend: anytype) type {
    return struct {
        const Self = @This();

        pub fn call(args: anytype) @TypeOf(@call(.auto, func, prepend ++ args)) {
            return @call(.auto, func, prepend ++ args);
        }
    };
}

fn multiply(a: i32, b: i32) i32 {
    return a * b;
}

test "prepend arguments" {
    const TimesTwo = PrependArgs(multiply, .{2});

    const result = TimesTwo.call(.{5});
    try testing.expectEqual(@as(i32, 10), result); // 2 * 5
}
// ANCHOR_END: prepend_arguments

// ANCHOR: append_arguments
// Decorator that appends arguments
fn AppendArgs(comptime func: anytype, comptime append: anytype) type {
    return struct {
        const Self = @This();

        pub fn call(args: anytype) @TypeOf(@call(.auto, func, args ++ append)) {
            return @call(.auto, func, args ++ append);
        }
    };
}

fn divide(a: i32, b: i32) i32 {
    return @divTrunc(a, b);
}

test "append arguments" {
    const DivideByTwo = AppendArgs(divide, .{2});

    const result = DivideByTwo.call(.{10});
    try testing.expectEqual(@as(i32, 5), result); // 10 / 2
}
// ANCHOR_END: append_arguments

// ANCHOR: inject_default_args
// Decorator that injects default arguments
fn WithDefaults(comptime func: anytype, comptime defaults: anytype) type {
    return struct {
        const Self = @This();

        pub fn call(provided: anytype) @TypeOf(@call(.auto, func, provided ++ defaults)) {
            return @call(.auto, func, provided ++ defaults);
        }
    };
}

fn configuredAdd(x: i32, multiplier: i32, offset: i32) i32 {
    return (x * multiplier) + offset;
}

test "inject default args" {
    const DefaultConfig = WithDefaults(configuredAdd, .{ 3, 10 });

    const result = DefaultConfig.call(.{5});
    try testing.expectEqual(@as(i32, 25), result); // (5 * 3) + 10
}
// ANCHOR_END: inject_default_args

// ANCHOR: inject_logger
// Decorator that injects logger
fn WithLogger(comptime func: anytype) type {
    return struct {
        const Self = @This();
        const Logger = struct {
            log_count: *u32,

            pub fn log(self: Logger, comptime fmt: []const u8, args: anytype) void {
                _ = fmt;
                _ = args;
                self.log_count.* += 1;
            }
        };

        log_count: u32 = 0,

        pub fn call(self: *Self, args: anytype) @TypeOf(@call(.auto, func, .{Logger{ .log_count = &self.log_count }} ++ args)) {
            const logger = Logger{ .log_count = &self.log_count };
            return @call(.auto, func, .{logger} ++ args);
        }

        pub fn getLogCount(self: Self) u32 {
            return self.log_count;
        }
    };
}

fn processWithLog(logger: anytype, x: i32) i32 {
    logger.log("Processing {d}", .{x});
    return x * 2;
}

test "inject logger" {
    var decorated = WithLogger(processWithLog){};

    const result = decorated.call(.{5});
    try testing.expectEqual(@as(i32, 10), result);
    try testing.expectEqual(@as(u32, 1), decorated.getLogCount());
}
// ANCHOR_END: inject_logger

// ANCHOR: inject_timestamp
// Decorator that injects timestamp
fn WithTimestamp(comptime func: anytype) type {
    return struct {
        const Self = @This();
        current_time: u64 = 0,

        pub fn call(self: *Self, args: anytype) @TypeOf(@call(.auto, func, .{self.current_time} ++ args)) {
            self.current_time += 1;
            return @call(.auto, func, .{self.current_time} ++ args);
        }

        pub fn getCurrentTime(self: Self) u64 {
            return self.current_time;
        }
    };
}

fn processWithTime(timestamp: u64, x: i32) i32 {
    _ = timestamp;
    return x * 2;
}

test "inject timestamp" {
    var decorated = WithTimestamp(processWithTime){};

    _ = decorated.call(.{5});
    _ = decorated.call(.{10});

    try testing.expectEqual(@as(u64, 2), decorated.getCurrentTime());
}
// ANCHOR_END: inject_timestamp

// ANCHOR: inject_error_handler
// Decorator that injects error handler
fn WithErrorHandler(comptime func: anytype) type {
    return struct {
        const Self = @This();
        const ErrorHandler = struct {
            error_count: *u32,

            pub fn handleError(self: ErrorHandler, _: anyerror) void {
                self.error_count.* += 1;
            }
        };

        error_count: u32 = 0,

        pub fn call(self: *Self, args: anytype) @TypeOf(@call(.auto, func, .{ErrorHandler{ .error_count = &self.error_count }} ++ args)) {
            const handler = ErrorHandler{ .error_count = &self.error_count };
            return @call(.auto, func, .{handler} ++ args);
        }

        pub fn getErrorCount(self: Self) u32 {
            return self.error_count;
        }
    };
}

fn processWithErrorHandler(handler: anytype, x: i32) !i32 {
    if (x < 0) {
        handler.handleError(error.NegativeValue);
        return error.NegativeValue;
    }
    return x * 2;
}

test "inject error handler" {
    var decorated = WithErrorHandler(processWithErrorHandler){};

    const r1 = try decorated.call(.{5});
    try testing.expectEqual(@as(i32, 10), r1);

    const r2 = decorated.call(.{-5});
    try testing.expectError(error.NegativeValue, r2);
    try testing.expectEqual(@as(u32, 1), decorated.getErrorCount());
}
// ANCHOR_END: inject_error_handler

// ANCHOR: inject_metrics
// Decorator that injects metrics collector
fn WithMetrics(comptime func: anytype) type {
    return struct {
        const Self = @This();
        const Metrics = struct {
            calls: *u32,
            total: *i64,

            pub fn record(self: Metrics, value: i32) void {
                self.calls.* += 1;
                self.total.* += value;
            }
        };

        calls: u32 = 0,
        total: i64 = 0,

        pub fn call(self: *Self, args: anytype) @TypeOf(@call(.auto, func, .{Metrics{ .calls = &self.calls, .total = &self.total }} ++ args)) {
            const metrics = Metrics{ .calls = &self.calls, .total = &self.total };
            return @call(.auto, func, .{metrics} ++ args);
        }

        pub fn getAverage(self: Self) i64 {
            if (self.calls == 0) return 0;
            return @divTrunc(self.total, self.calls);
        }
    };
}

fn processWithMetrics(metrics: anytype, x: i32) i32 {
    const result = x * 2;
    metrics.record(result);
    return result;
}

test "inject metrics" {
    var decorated = WithMetrics(processWithMetrics){};

    _ = decorated.call(.{5});
    _ = decorated.call(.{10});
    _ = decorated.call(.{15});

    try testing.expectEqual(@as(i64, 20), decorated.getAverage()); // (10 + 20 + 30) / 3
}
// ANCHOR_END: inject_metrics

// ANCHOR: inject_runtime_context
// Decorator with runtime-configurable context
fn WithRuntimeContext(comptime func: anytype, comptime Context: type) type {
    return struct {
        const Self = @This();
        context: Context,

        pub fn init(context: Context) Self {
            return .{ .context = context };
        }

        pub fn call(self: Self, args: anytype) @TypeOf(@call(.auto, func, .{self.context} ++ args)) {
            return @call(.auto, func, .{self.context} ++ args);
        }
    };
}

const RuntimeConfig = struct {
    scale: i32,
    enabled: bool,
};

fn processWithRuntimeContext(config: RuntimeConfig, x: i32) i32 {
    if (!config.enabled) return x;
    return x * config.scale;
}

test "inject runtime context" {
    const config1 = RuntimeConfig{ .scale = 3, .enabled = true };
    const decorated1 = WithRuntimeContext(processWithRuntimeContext, RuntimeConfig).init(config1);

    const r1 = decorated1.call(.{5});
    try testing.expectEqual(@as(i32, 15), r1);

    const config2 = RuntimeConfig{ .scale = 3, .enabled = false };
    const decorated2 = WithRuntimeContext(processWithRuntimeContext, RuntimeConfig).init(config2);

    const r2 = decorated2.call(.{5});
    try testing.expectEqual(@as(i32, 5), r2);
}
// ANCHOR_END: inject_runtime_context

// ANCHOR: inject_multiple_args
// Decorator that injects multiple arguments
fn InjectMultiple(comptime func: anytype, comptime inject: anytype) type {
    return struct {
        const Self = @This();

        pub fn call(args: anytype) @TypeOf(@call(.auto, func, inject ++ args)) {
            return @call(.auto, func, inject ++ args);
        }
    };
}

fn complexFunc(a: i32, b: i32, c: i32, d: i32) i32 {
    return a + b + c + d;
}

test "inject multiple args" {
    const Injected = InjectMultiple(complexFunc, .{ 1, 2 });

    const result = Injected.call(.{ 3, 4 });
    try testing.expectEqual(@as(i32, 10), result); // 1 + 2 + 3 + 4
}
// ANCHOR_END: inject_multiple_args

// ANCHOR: conditional_injection
// Decorator with conditional argument injection
fn ConditionalInject(comptime func: anytype, comptime condition: bool, comptime inject: anytype) type {
    if (condition) {
        return struct {
            pub fn call(args: anytype) @TypeOf(@call(.auto, func, inject ++ args)) {
                return @call(.auto, func, inject ++ args);
            }
        };
    } else {
        return struct {
            pub fn call(args: anytype) @TypeOf(@call(.auto, func, args)) {
                return @call(.auto, func, args);
            }
        };
    }
}

fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "conditional injection" {
    const WithInjection = ConditionalInject(add, true, .{10});
    const r1 = WithInjection.call(.{5});
    try testing.expectEqual(@as(i32, 15), r1); // 10 + 5

    const WithoutInjection = ConditionalInject(add, false, .{10});
    const r2 = WithoutInjection.call(.{ 5, 3 });
    try testing.expectEqual(@as(i32, 8), r2); // 5 + 3
}
// ANCHOR_END: conditional_injection

// Comprehensive test
test "comprehensive argument injection" {
    // Allocator injection
    const WithTestAlloc = WithAllocator(createSlice, testing.allocator);
    const slice = try WithTestAlloc.call(.{3});
    defer testing.allocator.free(slice);
    try testing.expectEqual(@as(usize, 3), slice.len);

    // Prepend arguments
    const Times3 = PrependArgs(multiply, .{3});
    try testing.expectEqual(@as(i32, 15), Times3.call(.{5}));

    // Append arguments
    const DivBy5 = AppendArgs(divide, .{5});
    try testing.expectEqual(@as(i32, 4), DivBy5.call(.{20}));

    // Logger injection
    var logger_dec = WithLogger(processWithLog){};
    _ = logger_dec.call(.{10});
    try testing.expectEqual(@as(u32, 1), logger_dec.getLogCount());

    // Multiple argument injection
    const Multi = InjectMultiple(complexFunc, .{ 2, 3 });
    try testing.expectEqual(@as(i32, 11), Multi.call(.{ 4, 2 }));
}
