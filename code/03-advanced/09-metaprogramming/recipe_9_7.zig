// Recipe 9.7: Defining Decorators as Structs
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_decorator_struct
// Define decorator as a struct type
fn TimingDecorator(comptime Func: type) type {
    return struct {
        const Self = @This();
        func: Func,
        elapsed_ns: u64 = 0,

        pub fn init(func: Func) Self {
            return .{ .func = func };
        }

        pub fn call(self: *Self, x: i32) i32 {
            // In real code, measure actual time
            self.elapsed_ns += 100;
            return self.func.call(x);
        }

        pub fn getElapsed(self: Self) u64 {
            return self.elapsed_ns;
        }
    };
}

const SimpleFunc = struct {
    pub fn call(_: @This(), x: i32) i32 {
        return x * 2;
    }
};

test "basic decorator struct" {
    const simple = SimpleFunc{};
    var timed = TimingDecorator(SimpleFunc).init(simple);

    const result = timed.call(5);
    try testing.expectEqual(@as(i32, 10), result);
    try testing.expectEqual(@as(u64, 100), timed.getElapsed());
}
// ANCHOR_END: basic_decorator_struct

// ANCHOR: stateful_decorator
// Decorator with persistent state
fn CountingDecorator(comptime Func: type) type {
    return struct {
        const Self = @This();
        func: Func,
        call_count: u32 = 0,
        total_sum: i64 = 0,

        pub fn init(func: Func) Self {
            return .{ .func = func };
        }

        pub fn call(self: *Self, x: i32) i32 {
            self.call_count += 1;
            const result = self.func.call(x);
            self.total_sum += result;
            return result;
        }

        pub fn getCallCount(self: Self) u32 {
            return self.call_count;
        }

        pub fn getTotalSum(self: Self) i64 {
            return self.total_sum;
        }

        pub fn reset(self: *Self) void {
            self.call_count = 0;
            self.total_sum = 0;
        }
    };
}

test "stateful decorator" {
    const simple = SimpleFunc{};
    var counter = CountingDecorator(SimpleFunc).init(simple);

    _ = counter.call(5);
    _ = counter.call(10);

    try testing.expectEqual(@as(u32, 2), counter.getCallCount());
    try testing.expectEqual(@as(i64, 30), counter.getTotalSum()); // 10 + 20

    counter.reset();
    try testing.expectEqual(@as(u32, 0), counter.getCallCount());
}
// ANCHOR_END: stateful_decorator

// ANCHOR: configured_decorator
// Decorator with configuration
fn ValidatingDecorator(comptime Func: type, comptime Config: type) type {
    return struct {
        const Self = @This();
        func: Func,
        config: Config,

        pub fn init(func: Func, config: Config) Self {
            return .{ .func = func, .config = config };
        }

        pub fn call(self: *Self, x: i32) !i32 {
            if (x < self.config.min or x > self.config.max) {
                return error.OutOfBounds;
            }
            return self.func.call(x);
        }
    };
}

const BoundsConfig = struct {
    min: i32,
    max: i32,
};

test "configured decorator" {
    const simple = SimpleFunc{};
    const config = BoundsConfig{ .min = 0, .max = 10 };
    var validator = ValidatingDecorator(SimpleFunc, BoundsConfig).init(simple, config);

    const r1 = try validator.call(5);
    try testing.expectEqual(@as(i32, 10), r1);

    const r2 = validator.call(15);
    try testing.expectError(error.OutOfBounds, r2);
}
// ANCHOR_END: configured_decorator

// ANCHOR: caching_decorator
// Decorator with cache storage
fn CachingDecorator(comptime Func: type) type {
    return struct {
        const Self = @This();
        const CacheEntry = struct {
            input: i32,
            output: i32,
        };

        func: Func,
        cache: ?CacheEntry = null,

        pub fn init(func: Func) Self {
            return .{ .func = func };
        }

        pub fn call(self: *Self, x: i32) i32 {
            if (self.cache) |entry| {
                if (entry.input == x) {
                    return entry.output;
                }
            }

            const result = self.func.call(x);
            self.cache = CacheEntry{ .input = x, .output = result };
            return result;
        }

        pub fn clearCache(self: *Self) void {
            self.cache = null;
        }

        pub fn isCached(self: Self, x: i32) bool {
            if (self.cache) |entry| {
                return entry.input == x;
            }
            return false;
        }
    };
}

test "caching decorator" {
    const simple = SimpleFunc{};
    var cached = CachingDecorator(SimpleFunc).init(simple);

    const r1 = cached.call(5);
    try testing.expectEqual(@as(i32, 10), r1);
    try testing.expect(cached.isCached(5));

    const r2 = cached.call(5);
    try testing.expectEqual(@as(i32, 10), r2);

    cached.clearCache();
    try testing.expect(!cached.isCached(5));
}
// ANCHOR_END: caching_decorator

// ANCHOR: composable_decorators
// Compose multiple decorator structs
fn LoggingDecorator(comptime Func: type) type {
    return struct {
        const Self = @This();
        func: Func,
        log_count: u32 = 0,

        pub fn init(func: Func) Self {
            return .{ .func = func };
        }

        pub fn call(self: *Self, x: i32) @TypeOf(self.func.call(0)) {
            self.log_count += 1;
            return self.func.call(x);
        }

        pub fn getLogCount(self: Self) u32 {
            return self.log_count;
        }
    };
}

fn ScalingDecorator(comptime Func: type, comptime factor: i32) type {
    return struct {
        const Self = @This();
        func: Func,

        pub fn init(func: Func) Self {
            return .{ .func = func };
        }

        pub fn call(self: *Self, x: i32) @TypeOf(self.func.call(0)) {
            return self.func.call(x) * factor;
        }
    };
}

test "composable decorators" {
    const simple = SimpleFunc{};
    const logged = LoggingDecorator(SimpleFunc).init(simple);
    var scaled = ScalingDecorator(LoggingDecorator(SimpleFunc), 3).init(logged);

    const result = scaled.call(5);
    try testing.expectEqual(@as(i32, 30), result); // (5 * 2) * 3
}
// ANCHOR_END: composable_decorators

// ANCHOR: allocator_decorator
// Decorator with allocator for dynamic data
fn HistoryDecorator(comptime Func: type) type {
    return struct {
        const Self = @This();
        func: Func,
        allocator: std.mem.Allocator,
        history: std.ArrayList(i32),

        pub fn init(allocator: std.mem.Allocator, func: Func) Self {
            return .{
                .func = func,
                .allocator = allocator,
                .history = .{ .items = &.{}, .capacity = 0 },
            };
        }

        pub fn deinit(self: *Self) void {
            self.history.deinit(self.allocator);
        }

        pub fn call(self: *Self, x: i32) !i32 {
            const result = self.func.call(x);
            try self.history.append(self.allocator, result);
            return result;
        }

        pub fn getHistory(self: Self) []const i32 {
            return self.history.items;
        }

        pub fn clearHistory(self: *Self) void {
            self.history.clearRetainingCapacity();
        }
    };
}

test "allocator decorator" {
    const simple = SimpleFunc{};
    var history = HistoryDecorator(SimpleFunc).init(testing.allocator, simple);
    defer history.deinit();

    _ = try history.call(5);
    _ = try history.call(10);

    const hist = history.getHistory();
    try testing.expectEqual(@as(usize, 2), hist.len);
    try testing.expectEqual(@as(i32, 10), hist[0]);
    try testing.expectEqual(@as(i32, 20), hist[1]);

    history.clearHistory();
    try testing.expectEqual(@as(usize, 0), history.getHistory().len);
}
// ANCHOR_END: allocator_decorator

// ANCHOR: error_handling_decorator
// Decorator with error handling
fn RetryDecorator(comptime Func: type, comptime max_attempts: u32) type {
    return struct {
        const Self = @This();
        func: Func,
        attempts: u32 = 0,

        pub fn init(func: Func) Self {
            return .{ .func = func };
        }

        pub fn call(self: *Self, x: i32) !i32 {
            var last_error: ?anyerror = null;
            var attempt: u32 = 0;

            while (attempt < max_attempts) : (attempt += 1) {
                self.attempts += 1;
                const result = self.func.call(x) catch |err| {
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

        pub fn getAttempts(self: Self) u32 {
            return self.attempts;
        }
    };
}

const FallibleFunc = struct {
    attempts: *u32,

    pub fn call(self: @This(), x: i32) !i32 {
        self.attempts.* += 1;
        if (self.attempts.* < 3) {
            return error.Temporary;
        }
        return x * 2;
    }
};

test "error handling decorator" {
    var attempt_count: u32 = 0;
    const fallible = FallibleFunc{ .attempts = &attempt_count };
    var retry = RetryDecorator(FallibleFunc, 5).init(fallible);

    const result = try retry.call(10);
    try testing.expectEqual(@as(i32, 20), result);
    try testing.expectEqual(@as(u32, 3), retry.getAttempts());
}
// ANCHOR_END: error_handling_decorator

// ANCHOR: builder_pattern
// Builder pattern for decorator construction
fn DecoratorBuilder(comptime Func: type) type {
    return struct {
        const Self = @This();

        func: Func,
        enable_logging: bool = false,
        enable_caching: bool = false,
        scale_factor: i32 = 1,

        pub fn init(func: Func) Self {
            return .{ .func = func };
        }

        pub fn withLogging(self: Self) Self {
            var new = self;
            new.enable_logging = true;
            return new;
        }

        pub fn withCaching(self: Self) Self {
            var new = self;
            new.enable_caching = true;
            return new;
        }

        pub fn withScale(self: Self, factor: i32) Self {
            var new = self;
            new.scale_factor = factor;
            return new;
        }

        pub fn build(self: Self) Built(Func) {
            return Built(Func){
                .func = self.func,
                .enable_logging = self.enable_logging,
                .enable_caching = self.enable_caching,
                .scale_factor = self.scale_factor,
            };
        }
    };
}

fn Built(comptime Func: type) type {
    return struct {
        const Self = @This();

        func: Func,
        enable_logging: bool,
        enable_caching: bool,
        scale_factor: i32,
        cache: ?i32 = null,
        log_count: u32 = 0,

        pub fn call(self: *Self, x: i32) i32 {
            if (self.enable_logging) {
                self.log_count += 1;
            }

            if (self.enable_caching) {
                if (self.cache) |c| {
                    return c;
                }
            }

            var result = self.func.call(x);
            result = result * self.scale_factor;

            if (self.enable_caching) {
                self.cache = result;
            }

            return result;
        }

        pub fn getLogCount(self: Self) u32 {
            return self.log_count;
        }
    };
}

test "builder pattern" {
    const simple = SimpleFunc{};
    var decorated = DecoratorBuilder(SimpleFunc).init(simple)
        .withLogging()
        .withScale(3)
        .build();

    const result = decorated.call(5);
    try testing.expectEqual(@as(i32, 30), result); // (5 * 2) * 3
    try testing.expectEqual(@as(u32, 1), decorated.getLogCount());
}
// ANCHOR_END: builder_pattern

// ANCHOR: conditional_decorator
// Conditional behavior based on struct fields
fn ConditionalDecorator(comptime Func: type) type {
    return struct {
        const Self = @This();

        func: Func,
        enabled: bool,
        multiplier: i32,

        pub fn init(func: Func, enabled: bool, multiplier: i32) Self {
            return .{
                .func = func,
                .enabled = enabled,
                .multiplier = multiplier,
            };
        }

        pub fn call(self: *Self, x: i32) i32 {
            const base = self.func.call(x);
            if (self.enabled) {
                return base * self.multiplier;
            }
            return base;
        }

        pub fn enable(self: *Self) void {
            self.enabled = true;
        }

        pub fn disable(self: *Self) void {
            self.enabled = false;
        }
    };
}

test "conditional decorator" {
    const simple = SimpleFunc{};
    var conditional = ConditionalDecorator(SimpleFunc).init(simple, true, 3);

    const r1 = conditional.call(5);
    try testing.expectEqual(@as(i32, 30), r1); // Enabled: (5*2)*3

    conditional.disable();
    const r2 = conditional.call(5);
    try testing.expectEqual(@as(i32, 10), r2); // Disabled: 5*2
}
// ANCHOR_END: conditional_decorator

// ANCHOR: chaining_methods
// Decorator with method chaining
fn ChainableDecorator(comptime Func: type) type {
    return struct {
        const Self = @This();

        func: Func,
        offset: i32 = 0,
        multiplier: i32 = 1,
        invert: bool = false,

        pub fn init(func: Func) Self {
            return .{ .func = func };
        }

        pub fn addOffset(self: *Self, offset: i32) *Self {
            self.offset = offset;
            return self;
        }

        pub fn setMultiplier(self: *Self, multiplier: i32) *Self {
            self.multiplier = multiplier;
            return self;
        }

        pub fn setInvert(self: *Self, invert: bool) *Self {
            self.invert = invert;
            return self;
        }

        pub fn call(self: *Self, x: i32) i32 {
            var result = self.func.call(x);
            result = result + self.offset;
            result = result * self.multiplier;
            if (self.invert) {
                result = -result;
            }
            return result;
        }
    };
}

test "chaining methods" {
    const simple = SimpleFunc{};
    var chainable = ChainableDecorator(SimpleFunc).init(simple);

    _ = chainable.addOffset(5).setMultiplier(2).setInvert(false);

    const result = chainable.call(5);
    try testing.expectEqual(@as(i32, 30), result); // ((5*2) + 5) * 2
}
// ANCHOR_END: chaining_methods

// Comprehensive test
test "comprehensive decorator structs" {
    // Basic decorator
    const simple = SimpleFunc{};
    var timed = TimingDecorator(SimpleFunc).init(simple);
    try testing.expectEqual(@as(i32, 10), timed.call(5));

    // Stateful decorator
    var counter = CountingDecorator(SimpleFunc).init(simple);
    _ = counter.call(5);
    try testing.expectEqual(@as(u32, 1), counter.getCallCount());

    // Caching decorator
    var cached = CachingDecorator(SimpleFunc).init(simple);
    _ = cached.call(5);
    try testing.expect(cached.isCached(5));

    // Builder pattern
    var built = DecoratorBuilder(SimpleFunc).init(simple)
        .withLogging()
        .build();
    _ = built.call(5);
    try testing.expectEqual(@as(u32, 1), built.getLogCount());
}
