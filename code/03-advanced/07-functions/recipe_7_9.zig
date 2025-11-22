const std = @import("std");

// ANCHOR: basic_pattern
/// Generic validator pattern
const Validator = struct {
    context: *anyopaque,
    validate_fn: *const fn (*anyopaque, []const u8) bool,

    pub fn init(
        context: anytype,
        comptime validate_fn: fn (@TypeOf(context), []const u8) bool,
    ) Validator {
        const Wrapper = struct {
            fn call(ctx: *anyopaque, input: []const u8) bool {
                const ptr: @TypeOf(context) = @ptrCast(@alignCast(ctx));
                return validate_fn(ptr, input);
            }
        };

        return .{
            .context = @ptrCast(context),
            .validate_fn = Wrapper.call,
        };
    }

    pub fn validate(self: Validator, input: []const u8) bool {
        return self.validate_fn(self.context, input);
    }
};
// ANCHOR_END: basic_pattern

// ANCHOR: function_pointers
/// Function pointer type
const TransformFn = *const fn ([]const u8) []const u8;

pub fn applyTransform(input: []const u8, transform: TransformFn) []const u8 {
    return transform(input);
}

fn toUpper(s: []const u8) []const u8 {
    _ = s;
    return "UPPER";
}

fn toLower(s: []const u8) []const u8 {
    _ = s;
    return "lower";
}

/// Comparator pattern
const CompareFn = *const fn (*anyopaque, *anyopaque) bool;

pub fn sortWithComparator(
    items: []i32,
    context: *anyopaque,
    compare: CompareFn,
) void {
    for (items, 0..) |_, i| {
        for (items[0 .. items.len - i - 1], 0..) |_, j| {
            const a = @as(*i32, @ptrCast(@alignCast(&items[j])));
            const b = @as(*i32, @ptrCast(@alignCast(&items[j + 1])));
            if (!compare(@ptrCast(a), @ptrCast(b))) {
                const temp = items[j];
                items[j] = items[j + 1];
                items[j + 1] = temp;
            }
        }
    }
    _ = context;
}
// ANCHOR_END: function_pointers

// ANCHOR: strategy_pattern
/// Strategy pattern
const Strategy = struct {
    context: *anyopaque,
    execute_fn: *const fn (*anyopaque, i32, i32) i32,

    pub fn init(
        context: anytype,
        comptime execute_fn: fn (@TypeOf(context), i32, i32) i32,
    ) Strategy {
        const Wrapper = struct {
            fn call(ctx: *anyopaque, a: i32, b: i32) i32 {
                const ptr: @TypeOf(context) = @ptrCast(@alignCast(ctx));
                return execute_fn(ptr, a, b);
            }
        };

        return .{
            .context = @ptrCast(context),
            .execute_fn = Wrapper.call,
        };
    }

    pub fn execute(self: Strategy, a: i32, b: i32) i32 {
        return self.execute_fn(self.context, a, b);
    }
};
// ANCHOR_END: strategy_pattern

/// Command pattern
const Command = struct {
    context: *anyopaque,
    execute_fn: *const fn (*anyopaque) void,

    pub fn init(
        context: anytype,
        comptime execute_fn: fn (@TypeOf(context)) void,
    ) Command {
        const Wrapper = struct {
            fn call(ctx: *anyopaque) void {
                const ptr: @TypeOf(context) = @ptrCast(@alignCast(ctx));
                execute_fn(ptr);
            }
        };

        return .{
            .context = @ptrCast(context),
            .execute_fn = Wrapper.call,
        };
    }

    pub fn execute(self: Command) void {
        self.execute_fn(self.context);
    }
};

/// Generic callable
pub fn Callable(comptime Ret: type) type {
    return struct {
        context: *anyopaque,
        call_fn: *const fn (*anyopaque) Ret,

        pub fn init(
            context: anytype,
            comptime call_fn: fn (@TypeOf(context)) Ret,
        ) @This() {
            const Wrapper = struct {
                fn call(ctx: *anyopaque) Ret {
                    const ptr: @TypeOf(context) = @ptrCast(@alignCast(ctx));
                    return call_fn(ptr);
                }
            };

            return .{
                .context = @ptrCast(context),
                .call_fn = Wrapper.call,
            };
        }

        pub fn call(self: @This()) Ret {
            return self.call_fn(self.context);
        }
    };
}

/// Predicate pattern
const Predicate = struct {
    context: *anyopaque,
    test_fn: *const fn (*anyopaque, i32) bool,

    pub fn init(
        context: anytype,
        comptime test_fn: fn (@TypeOf(context), i32) bool,
    ) Predicate {
        const Wrapper = struct {
            fn call(ctx: *anyopaque, value: i32) bool {
                const ptr: @TypeOf(context) = @ptrCast(@alignCast(ctx));
                return test_fn(ptr, value);
            }
        };

        return .{
            .context = @ptrCast(context),
            .test_fn = Wrapper.call,
        };
    }

    pub fn test_(self: Predicate, value: i32) bool {
        return self.test_fn(self.context, value);
    }
};

pub fn filterWithPredicate(
    allocator: std.mem.Allocator,
    items: []const i32,
    predicate: Predicate,
) ![]i32 {
    var result = std.ArrayList(i32){};
    errdefer result.deinit(allocator);

    for (items) |item| {
        if (predicate.test_(item)) {
            try result.append(allocator, item);
        }
    }

    return try result.toOwnedSlice(allocator);
}

/// Factory pattern
pub fn Factory(comptime T: type) type {
    return struct {
        context: *anyopaque,
        create_fn: *const fn (*anyopaque) T,

        pub fn init(
            context: anytype,
            comptime create_fn: fn (@TypeOf(context)) T,
        ) @This() {
            const Wrapper = struct {
                fn call(ctx: *anyopaque) T {
                    const ptr: @TypeOf(context) = @ptrCast(@alignCast(ctx));
                    return create_fn(ptr);
                }
            };

            return .{
                .context = @ptrCast(context),
                .create_fn = Wrapper.call,
            };
        }

        pub fn create(self: @This()) T {
            return self.create_fn(self.context);
        }
    };
}

/// Handler pattern
pub fn Handler(comptime Event: type) type {
    return struct {
        context: *anyopaque,
        handle_fn: *const fn (*anyopaque, Event) void,

        pub fn init(
            context: anytype,
            comptime handle_fn: fn (@TypeOf(context), Event) void,
        ) @This() {
            const Wrapper = struct {
                fn call(ctx: *anyopaque, event: Event) void {
                    const ptr: @TypeOf(context) = @ptrCast(@alignCast(ctx));
                    handle_fn(ptr, event);
                }
            };

            return .{
                .context = @ptrCast(context),
                .handle_fn = Wrapper.call,
            };
        }

        pub fn handle(self: @This(), event: Event) void {
            self.handle_fn(self.context, event);
        }
    };
}

const KeyEvent = struct {
    key: u8,
    pressed: bool,
};

/// Visitor pattern
pub fn Visitor(comptime T: type) type {
    return struct {
        context: *anyopaque,
        visit_fn: *const fn (*anyopaque, T) void,

        pub fn init(
            context: anytype,
            comptime visit_fn: fn (@TypeOf(context), T) void,
        ) @This() {
            const Wrapper = struct {
                fn call(ctx: *anyopaque, item: T) void {
                    const ptr: @TypeOf(context) = @ptrCast(@alignCast(ctx));
                    visit_fn(ptr, item);
                }
            };

            return .{
                .context = @ptrCast(context),
                .visit_fn = Wrapper.call,
            };
        }

        pub fn visit(self: @This(), item: T) void {
            self.visit_fn(self.context, item);
        }
    };
}

/// Transformer pattern
pub fn Transformer(comptime In: type, comptime Out: type) type {
    return struct {
        context: *anyopaque,
        transform_fn: *const fn (*anyopaque, In) Out,

        pub fn init(
            context: anytype,
            comptime transform_fn: fn (@TypeOf(context), In) Out,
        ) @This() {
            const Wrapper = struct {
                fn call(ctx: *anyopaque, input: In) Out {
                    const ptr: @TypeOf(context) = @ptrCast(@alignCast(ctx));
                    return transform_fn(ptr, input);
                }
            };

            return .{
                .context = @ptrCast(context),
                .transform_fn = Wrapper.call,
            };
        }

        pub fn transform(self: @This(), input: In) Out {
            return self.transform_fn(self.context, input);
        }
    };
}

// Tests

test "single method replacement" {
    const EmailValidator = struct {
        domain: []const u8,

        fn check(self: *@This(), email: []const u8) bool {
            return std.mem.endsWith(u8, email, self.domain);
        }
    };

    var ctx = EmailValidator{ .domain = "@example.com" };
    const validator = Validator.init(&ctx, EmailValidator.check);

    try std.testing.expect(validator.validate("user@example.com"));
    try std.testing.expect(!validator.validate("user@other.com"));
}

test "function pointers" {
    try std.testing.expectEqualStrings("UPPER", applyTransform("test", toUpper));
    try std.testing.expectEqualStrings("lower", applyTransform("TEST", toLower));
}

test "comparator pattern" {
    var numbers = [_]i32{ 5, 2, 8, 1, 9 };

    const ascending = struct {
        fn cmp(a: *anyopaque, b: *anyopaque) bool {
            const x: *i32 = @ptrCast(@alignCast(a));
            const y: *i32 = @ptrCast(@alignCast(b));
            return x.* < y.*;
        }
    }.cmp;

    var ctx: u8 = 0;
    sortWithComparator(&numbers, @ptrCast(&ctx), ascending);

    try std.testing.expectEqual(@as(i32, 1), numbers[0]);
    try std.testing.expectEqual(@as(i32, 9), numbers[4]);
}

test "strategy pattern" {
    const AddStrategy = struct {
        bonus: i32,

        fn run(self: *@This(), a: i32, b: i32) i32 {
            return a + b + self.bonus;
        }
    };

    var add_ctx = AddStrategy{ .bonus = 10 };
    const strategy = Strategy.init(&add_ctx, AddStrategy.run);

    try std.testing.expectEqual(@as(i32, 25), strategy.execute(5, 10));
}

test "command pattern" {
    const PrintCommand = struct {
        message: []const u8,
        count: *usize,

        fn run(self: *@This()) void {
            _ = self.message;
            self.count.* += 1;
        }
    };

    var execution_count: usize = 0;
    var cmd_ctx = PrintCommand{
        .message = "Hello",
        .count = &execution_count,
    };
    const command = Command.init(&cmd_ctx, PrintCommand.run);

    command.execute();
    command.execute();

    try std.testing.expectEqual(@as(usize, 2), execution_count);
}

test "callable pattern" {
    const Counter = struct {
        value: i32,

        fn get(self: *@This()) i32 {
            self.value += 1;
            return self.value;
        }
    };

    var counter = Counter{ .value = 0 };
    const callable = Callable(i32).init(&counter, Counter.get);

    try std.testing.expectEqual(@as(i32, 1), callable.call());
    try std.testing.expectEqual(@as(i32, 2), callable.call());
}

test "predicate pattern" {
    const allocator = std.testing.allocator;

    const RangePredicate = struct {
        min: i32,
        max: i32,

        fn inRange(self: *@This(), value: i32) bool {
            return value >= self.min and value <= self.max;
        }
    };

    var range = RangePredicate{ .min = 5, .max = 15 };
    const predicate = Predicate.init(&range, RangePredicate.inRange);

    const numbers = [_]i32{ 1, 7, 12, 20, 10 };
    const filtered = try filterWithPredicate(allocator, &numbers, predicate);
    defer allocator.free(filtered);

    try std.testing.expectEqual(@as(usize, 3), filtered.len);
}

test "factory pattern" {
    const Config = struct {
        default_value: i32,

        fn createInstance(self: *@This()) i32 {
            return self.default_value * 2;
        }
    };

    var config = Config{ .default_value = 21 };
    const factory = Factory(i32).init(&config, Config.createInstance);

    try std.testing.expectEqual(@as(i32, 42), factory.create());
}

test "handler pattern" {
    const KeyLogger = struct {
        count: *usize,

        fn onKey(self: *@This(), event: KeyEvent) void {
            if (event.pressed) {
                self.count.* += 1;
            }
        }
    };

    var press_count: usize = 0;
    var logger = KeyLogger{ .count = &press_count };
    const handler = Handler(KeyEvent).init(&logger, KeyLogger.onKey);

    handler.handle(.{ .key = 'A', .pressed = true });
    handler.handle(.{ .key = 'B', .pressed = false });
    handler.handle(.{ .key = 'C', .pressed = true });

    try std.testing.expectEqual(@as(usize, 2), press_count);
}

test "visitor pattern" {
    const Accumulator = struct {
        sum: *i32,

        fn visitNumber(self: *@This(), n: i32) void {
            self.sum.* += n;
        }
    };

    var total: i32 = 0;
    var acc = Accumulator{ .sum = &total };
    const visitor = Visitor(i32).init(&acc, Accumulator.visitNumber);

    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    for (numbers) |n| {
        visitor.visit(n);
    }

    try std.testing.expectEqual(@as(i32, 15), total);
}

test "transformer pattern" {
    const Multiplier = struct {
        factor: i32,

        fn apply(self: *@This(), value: i32) i32 {
            return value * self.factor;
        }
    };

    var multiplier = Multiplier{ .factor = 3 };
    const transformer = Transformer(i32, i32).init(&multiplier, Multiplier.apply);

    try std.testing.expectEqual(@as(i32, 15), transformer.transform(5));
    try std.testing.expectEqual(@as(i32, 30), transformer.transform(10));
}

test "validator with multiple domains" {
    const MultiDomainValidator = struct {
        domains: []const []const u8,

        fn check(self: *@This(), email: []const u8) bool {
            for (self.domains) |domain| {
                if (std.mem.endsWith(u8, email, domain)) {
                    return true;
                }
            }
            return false;
        }
    };

    const domains = [_][]const u8{ "@example.com", "@test.org" };
    var ctx = MultiDomainValidator{ .domains = &domains };
    const validator = Validator.init(&ctx, MultiDomainValidator.check);

    try std.testing.expect(validator.validate("user@example.com"));
    try std.testing.expect(validator.validate("admin@test.org"));
    try std.testing.expect(!validator.validate("user@other.net"));
}

test "strategy with subtraction" {
    const SubtractStrategy = struct {
        penalty: i32,

        fn run(self: *@This(), a: i32, b: i32) i32 {
            return a - b - self.penalty;
        }
    };

    var sub_ctx = SubtractStrategy{ .penalty = 5 };
    const strategy = Strategy.init(&sub_ctx, SubtractStrategy.run);

    try std.testing.expectEqual(@as(i32, 0), strategy.execute(10, 5));
}

test "callable with string return" {
    const StringProvider = struct {
        prefix: []const u8,

        fn get(self: *@This()) []const u8 {
            return self.prefix;
        }
    };

    var provider = StringProvider{ .prefix = "Hello" };
    const callable = Callable([]const u8).init(&provider, StringProvider.get);

    try std.testing.expectEqualStrings("Hello", callable.call());
}
