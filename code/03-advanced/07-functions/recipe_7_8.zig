const std = @import("std");

// ANCHOR: basic_partial
/// Power function
pub fn power(base: i32, exponent: i32) i32 {
    return std.math.powi(i32, base, exponent) catch unreachable;
}

/// Partial power application
pub fn partial_power(exponent: i32) type {
    return struct {
        pub fn call(base: i32) i32 {
            return power(base, exponent);
        }
    };
}

/// Basic math functions
fn add(a: i32, b: i32) i32 {
    return a + b;
}

fn multiply(a: i32, b: i32) i32 {
    return a * b;
}

/// Runtime partial add
pub fn PartialAdd(comptime T: type) type {
    return struct {
        value: T,

        pub fn init(value: T) @This() {
            return .{ .value = value };
        }

        pub fn call(self: @This(), other: T) T {
            return self.value + other;
        }
    };
}
// ANCHOR_END: basic_partial

// ANCHOR: runtime_partial
/// Three-argument function for currying
fn add3(a: i32, b: i32, c: i32) i32 {
    return a + b + c;
}

/// Partial format
pub fn PartialFormat(comptime fmt: []const u8) type {
    return struct {
        pub fn call(
            allocator: std.mem.Allocator,
            args: anytype,
        ) ![]u8 {
            return try std.fmt.allocPrint(allocator, fmt, args);
        }
    };
}

/// Greater than predicate
pub fn GreaterThan(comptime T: type) type {
    return struct {
        threshold: T,

        pub fn init(threshold: T) @This() {
            return .{ .threshold = threshold };
        }

        pub fn check(self: @This(), value: T) bool {
            return value > self.threshold;
        }
    };
}

pub fn filter(
    allocator: std.mem.Allocator,
    items: []const i32,
    predicate: anytype,
) ![]i32 {
    var result = std.ArrayList(i32){};
    errdefer result.deinit(allocator);

    for (items) |item| {
        if (predicate.check(item)) {
            try result.append(allocator, item);
        }
    }

    return try result.toOwnedSlice(allocator);
}
// ANCHOR_END: runtime_partial

// ANCHOR: advanced_partial
/// Partial error handling
pub fn PartialTry(comptime ErrorSet: type, comptime T: type) type {
    return struct {
        fallback: T,

        pub fn init(fallback: T) @This() {
            return .{ .fallback = fallback };
        }

        pub fn call(self: @This(), result: ErrorSet!T) T {
            return result catch self.fallback;
        }
    };
}

fn mayFail(value: i32) !i32 {
    if (value < 0) return error.Negative;
    return value * 2;
}

/// Bind first two arguments
pub fn BindFirst2(comptime T1: type, comptime T2: type) type {
    return struct {
        arg1: T1,
        arg2: T2,

        pub fn init(arg1: T1, arg2: T2) @This() {
            return .{ .arg1 = arg1, .arg2 = arg2 };
        }

        pub fn call(
            self: @This(),
            func: anytype,
            arg3: anytype,
        ) @TypeOf(func(self.arg1, self.arg2, arg3)) {
            return func(self.arg1, self.arg2, arg3);
        }
    };
}

fn add3args(a: i32, b: i32, c: i32) i32 {
    return a + b + c;
}

/// Function builder
pub fn FunctionBuilder(comptime Ret: type) type {
    return struct {
        const Self = @This();

        pub fn arg(comptime T: type, value: T) type {
            return struct {
                captured: T,

                pub fn init() @This() {
                    return .{ .captured = value };
                }

                pub fn apply(self: @This(), func: fn (T) Ret) Ret {
                    return func(self.captured);
                }
            };
        }
    };
}

/// Calculator with partial methods
pub fn Calculator() type {
    return struct {
        base: i32,

        const Self = @This();

        pub fn init(base: i32) Self {
            return .{ .base = base };
        }

        pub fn add_impl(self: Self, value: i32) i32 {
            return self.base + value;
        }

        pub fn multiply_impl(self: Self, value: i32) i32 {
            return self.base * value;
        }

        pub const PartialAdder = struct {
            calc: Self,

            pub fn init(calc: Self) @This() {
                return .{ .calc = calc };
            }

            pub fn call(this: @This(), value: i32) i32 {
                return this.calc.add_impl(value);
            }
        };

        pub fn partialAdd(self: Self) PartialAdder {
            return PartialAdder.init(self);
        }
    };
}

/// Reverse partial application
pub fn PartialLast(comptime T: type) type {
    return struct {
        last_arg: T,

        pub fn init(last_arg: T) @This() {
            return .{ .last_arg = last_arg };
        }

        pub fn call(
            self: @This(),
            func: anytype,
            first_arg: anytype,
        ) @TypeOf(func(first_arg, self.last_arg)) {
            return func(first_arg, self.last_arg);
        }
    };
}

fn subtract(a: i32, b: i32) i32 {
    return a - b;
}
// ANCHOR_END: advanced_partial

/// Partial with allocator
pub fn WithAllocator(allocator: std.mem.Allocator) type {
    return struct {
        pub fn duplicate(text: []const u8) ![]u8 {
            return try allocator.dupe(u8, text);
        }

        pub fn format(comptime fmt: []const u8, args: anytype) ![]u8 {
            return try std.fmt.allocPrint(allocator, fmt, args);
        }
    };
}

/// Function composition
pub fn Compose(
    comptime f: fn (i32) i32,
    comptime g: fn (i32) i32,
) type {
    return struct {
        pub fn call(x: i32) i32 {
            return f(g(x));
        }
    };
}

fn double(x: i32) i32 {
    return x * 2;
}

fn addTen(x: i32) i32 {
    return x + 10;
}

/// Multiply partial
pub fn PartialMultiply(comptime T: type) type {
    return struct {
        factor: T,

        pub fn init(factor: T) @This() {
            return .{ .factor = factor };
        }

        pub fn call(self: @This(), value: T) T {
            return self.factor * value;
        }
    };
}

// Tests

test "partial application" {
    const square = partial_power(2);
    const cube = partial_power(3);

    try std.testing.expectEqual(@as(i32, 25), square.call(5));
    try std.testing.expectEqual(@as(i32, 125), cube.call(5));
}

test "runtime partial" {
    const add5 = PartialAdd(i32).init(5);
    const add10 = PartialAdd(i32).init(10);

    try std.testing.expectEqual(@as(i32, 15), add5.call(10));
    try std.testing.expectEqual(@as(i32, 25), add10.call(15));
}

test "partial format" {
    const allocator = std.testing.allocator;

    const format_name = PartialFormat("Hello, {s}!");
    const result = try format_name.call(allocator, .{"World"});
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello, World!", result);
}

test "partial comparison" {
    const allocator = std.testing.allocator;
    const numbers = [_]i32{ 1, 5, 10, 15, 20 };

    const gt10 = GreaterThan(i32).init(10);
    const filtered = try filter(allocator, &numbers, gt10);
    defer allocator.free(filtered);

    try std.testing.expectEqual(@as(usize, 2), filtered.len);
    try std.testing.expectEqual(@as(i32, 15), filtered[0]);
}

test "partial error handling" {
    const safe_double = PartialTry(error{Negative}, i32).init(0);

    try std.testing.expectEqual(@as(i32, 10), safe_double.call(mayFail(5)));
    try std.testing.expectEqual(@as(i32, 0), safe_double.call(mayFail(-5)));
}

test "bind first arguments" {
    const bound = BindFirst2(i32, i32).init(10, 20);

    const result = bound.call(add3args, 30);
    try std.testing.expectEqual(@as(i32, 60), result);
}

test "function builder" {
    const double_fn = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const Builder = FunctionBuilder(i32);
    const partial = Builder.arg(i32, 5).init();

    try std.testing.expectEqual(@as(i32, 10), partial.apply(double_fn));
}

test "method partial" {
    const calc = Calculator().init(10);

    const add_to_10 = calc.partialAdd();
    try std.testing.expectEqual(@as(i32, 15), add_to_10.call(5));
}

test "reverse partial" {
    const subtract5 = PartialLast(i32).init(5);

    try std.testing.expectEqual(@as(i32, 5), subtract5.call(subtract, 10));
    try std.testing.expectEqual(@as(i32, 15), subtract5.call(subtract, 20));
}

test "partial allocator" {
    const allocator = std.testing.allocator;
    const Mem = WithAllocator(allocator);

    const dup = try Mem.duplicate("hello");
    defer allocator.free(dup);
    try std.testing.expectEqualStrings("hello", dup);

    const formatted = try Mem.format("Value: {}", .{42});
    defer allocator.free(formatted);
    try std.testing.expectEqualStrings("Value: 42", formatted);
}

test "composition" {
    const doubleAndAdd = Compose(addTen, double);

    // (5 * 2) + 10 = 20
    try std.testing.expectEqual(@as(i32, 20), doubleAndAdd.call(5));
}

test "partial multiply" {
    const times3 = PartialMultiply(i32).init(3);
    const times5 = PartialMultiply(i32).init(5);

    try std.testing.expectEqual(@as(i32, 15), times3.call(5));
    try std.testing.expectEqual(@as(i32, 25), times5.call(5));
}

test "multiple partial instances" {
    const add2 = PartialAdd(i32).init(2);
    const add7 = PartialAdd(i32).init(7);

    try std.testing.expectEqual(@as(i32, 12), add2.call(10));
    try std.testing.expectEqual(@as(i32, 17), add7.call(10));
}

test "partial with floats" {
    const add_half = PartialAdd(f32).init(0.5);

    try std.testing.expectEqual(@as(f32, 5.5), add_half.call(5.0));
}

test "filter with different thresholds" {
    const allocator = std.testing.allocator;
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };

    const gt2 = GreaterThan(i32).init(2);
    const filtered = try filter(allocator, &numbers, gt2);
    defer allocator.free(filtered);

    try std.testing.expectEqual(@as(usize, 3), filtered.len);
}
