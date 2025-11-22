const std = @import("std");

// ANCHOR: basic_anonymous
/// Apply an operation to two integers
pub fn applyOperation(a: i32, b: i32, operation: fn (i32, i32) i32) i32 {
    return operation(a, b);
}

/// Inline addition function
inline fn add(a: i32, b: i32) i32 {
    return a + b;
}

/// Inline square function
inline fn square(x: i32) i32 {
    return x * x;
}

pub fn processValues(values: []i32) i32 {
    var sum: i32 = 0;
    for (values) |v| {
        sum = add(sum, square(v));
    }
    return sum;
}
// ANCHOR_END: basic_anonymous

// ANCHOR: inline_functions
/// Sort with compile-time direction
pub fn sortBy(items: []i32, comptime descending: bool) void {
    const compare = if (descending)
        struct {
            fn cmp(_: void, a: i32, b: i32) bool {
                return a > b;
            }
        }.cmp
    else
        struct {
            fn cmp(_: void, a: i32, b: i32) bool {
                return a < b;
            }
        }.cmp;

    std.mem.sort(i32, items, {}, compare);
}
// ANCHOR_END: inline_functions

// ANCHOR: function_tables
/// Operation enum
const Operation = enum { add, subtract, multiply, divide };

/// Calculate with operation selector
pub fn calculate(op: Operation, a: i32, b: i32) !i32 {
    const functions = .{
        struct {
            fn call(x: i32, y: i32) !i32 {
                return x + y;
            }
        }.call,
        struct {
            fn call(x: i32, y: i32) !i32 {
                return x - y;
            }
        }.call,
        struct {
            fn call(x: i32, y: i32) !i32 {
                return x * y;
            }
        }.call,
        struct {
            fn call(x: i32, y: i32) !i32 {
                if (y == 0) return error.DivideByZero;
                return @divTrunc(x, y);
            }
        }.call,
    };

    return switch (op) {
        .add => functions[0](a, b),
        .subtract => functions[1](a, b),
        .multiply => functions[2](a, b),
        .divide => functions[3](a, b),
    };
}
// ANCHOR_END: function_tables

/// Filter items by predicate
pub fn filter(
    allocator: std.mem.Allocator,
    items: []const i32,
    predicate: fn (i32) bool,
) ![]i32 {
    var result = std.ArrayList(i32){};
    errdefer result.deinit(allocator);

    for (items) |item| {
        if (predicate(item)) {
            try result.append(allocator, item);
        }
    }

    return try result.toOwnedSlice(allocator);
}

/// Map transformation over items
pub fn map(
    allocator: std.mem.Allocator,
    items: []const i32,
    transform: fn (i32) i32,
) ![]i32 {
    var result = try allocator.alloc(i32, items.len);
    errdefer allocator.free(result);

    for (items, 0..) |item, i| {
        result[i] = transform(item);
    }

    return result;
}

/// Generate adder function at compile time
pub fn makeAdder(comptime n: i32) fn (i32) i32 {
    return struct {
        fn add_impl(x: i32) i32 {
            return x + n;
        }
    }.add_impl;
}

/// Generic operations
pub fn GenericOperation(comptime T: type) type {
    return struct {
        pub fn min(a: T, b: T) T {
            return if (a < b) a else b;
        }

        pub fn max(a: T, b: T) T {
            return if (a > b) a else b;
        }

        pub fn clamp(value: T, low: T, high: T) T {
            return max(low, min(value, high));
        }
    };
}

/// Event handler with type-erased context
const EventHandler = struct {
    context: *anyopaque,
    callback: *const fn (*anyopaque, []const u8) void,

    pub fn init(
        context: anytype,
        comptime callback: fn (@TypeOf(context), []const u8) void,
    ) EventHandler {
        const Wrapper = struct {
            fn call(ctx: *anyopaque, data: []const u8) void {
                const ptr: @TypeOf(context) = @ptrCast(@alignCast(ctx));
                callback(ptr, data);
            }
        };

        return .{
            .context = @ptrCast(context),
            .callback = Wrapper.call,
        };
    }

    pub fn trigger(self: EventHandler, data: []const u8) void {
        self.callback(self.context, data);
    }
};

/// Reduce operation
pub fn reduce(
    items: []const i32,
    initial: i32,
    reducer: fn (i32, i32) i32,
) i32 {
    var accumulator = initial;
    for (items) |item| {
        accumulator = reducer(accumulator, item);
    }
    return accumulator;
}

/// Process vector with inline operations
pub fn processVector(data: @Vector(4, i32)) @Vector(4, i32) {
    var result = data;
    inline for (0..4) |i| {
        result[i] = result[i] * 2;
    }
    return result;
}

// Tests

test "anonymous functions" {
    // Define anonymous function using struct
    const add_fn = struct {
        fn call(a: i32, b: i32) i32 {
            return a + b;
        }
    }.call;

    const result = applyOperation(5, 3, add_fn);
    try std.testing.expectEqual(@as(i32, 8), result);

    // Define multiply inline
    const multiply = struct {
        fn call(a: i32, b: i32) i32 {
            return a * b;
        }
    }.call;

    const result2 = applyOperation(5, 3, multiply);
    try std.testing.expectEqual(@as(i32, 15), result2);
}

test "inline functions" {
    var values = [_]i32{ 1, 2, 3, 4 };
    const result = processValues(&values);
    try std.testing.expectEqual(@as(i32, 30), result); // 1 + 4 + 9 + 16
}

test "anonymous comparison" {
    var numbers = [_]i32{ 5, 2, 8, 1, 9 };

    sortBy(&numbers, false);
    try std.testing.expectEqual(@as(i32, 1), numbers[0]);

    sortBy(&numbers, true);
    try std.testing.expectEqual(@as(i32, 9), numbers[0]);
}

test "function tables" {
    try std.testing.expectEqual(@as(i32, 8), try calculate(.add, 5, 3));
    try std.testing.expectEqual(@as(i32, 2), try calculate(.subtract, 5, 3));
    try std.testing.expectEqual(@as(i32, 15), try calculate(.multiply, 5, 3));
    try std.testing.expectEqual(@as(i32, 1), try calculate(.divide, 5, 3));
    try std.testing.expectError(error.DivideByZero, calculate(.divide, 5, 0));
}

test "anonymous predicates" {
    const allocator = std.testing.allocator;
    const numbers = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    // Filter even numbers
    const is_even = struct {
        fn call(n: i32) bool {
            return @mod(n, 2) == 0;
        }
    }.call;

    const evens = try filter(allocator, &numbers, is_even);
    defer allocator.free(evens);

    try std.testing.expectEqual(@as(usize, 5), evens.len);
    try std.testing.expectEqual(@as(i32, 2), evens[0]);

    // Filter numbers greater than 5
    const greater_than_five = struct {
        fn call(n: i32) bool {
            return n > 5;
        }
    }.call;

    const filtered = try filter(allocator, &numbers, greater_than_five);
    defer allocator.free(filtered);

    try std.testing.expectEqual(@as(usize, 5), filtered.len);
    try std.testing.expectEqual(@as(i32, 6), filtered[0]);
}

test "anonymous transformations" {
    const allocator = std.testing.allocator;
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };

    // Double all values
    const double = struct {
        fn call(n: i32) i32 {
            return n * 2;
        }
    }.call;

    const doubled = try map(allocator, &numbers, double);
    defer allocator.free(doubled);

    try std.testing.expectEqual(@as(i32, 2), doubled[0]);
    try std.testing.expectEqual(@as(i32, 10), doubled[4]);

    // Square all values
    const square_fn = struct {
        fn call(n: i32) i32 {
            return n * n;
        }
    }.call;

    const squared = try map(allocator, &numbers, square_fn);
    defer allocator.free(squared);

    try std.testing.expectEqual(@as(i32, 1), squared[0]);
    try std.testing.expectEqual(@as(i32, 25), squared[4]);
}

test "comptime function generation" {
    const add5 = makeAdder(5);
    const add10 = makeAdder(10);

    try std.testing.expectEqual(@as(i32, 15), add5(10));
    try std.testing.expectEqual(@as(i32, 20), add10(10));
}

test "generic anonymous functions" {
    const IntOps = GenericOperation(i32);

    try std.testing.expectEqual(@as(i32, 3), IntOps.min(5, 3));
    try std.testing.expectEqual(@as(i32, 5), IntOps.max(5, 3));
    try std.testing.expectEqual(@as(i32, 5), IntOps.clamp(10, 0, 5));

    const FloatOps = GenericOperation(f32);

    try std.testing.expectEqual(@as(f32, 1.5), FloatOps.min(2.5, 1.5));
    try std.testing.expectEqual(@as(f32, 2.5), FloatOps.max(2.5, 1.5));
}

test "callback registration" {
    const Handler = struct {
        count: usize = 0,

        fn onEvent(self: *@This(), data: []const u8) void {
            self.count += data.len;
        }
    };

    var handler = Handler{};
    const event = EventHandler.init(&handler, Handler.onEvent);

    event.trigger("hello");
    event.trigger("world");

    try std.testing.expectEqual(@as(usize, 10), handler.count);
}

test "anonymous reduce" {
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };

    // Sum
    const sum = struct {
        fn call(acc: i32, val: i32) i32 {
            return acc + val;
        }
    }.call;

    const total = reduce(&numbers, 0, sum);
    try std.testing.expectEqual(@as(i32, 15), total);

    // Product
    const multiply = struct {
        fn call(acc: i32, val: i32) i32 {
            return acc * val;
        }
    }.call;

    const product = reduce(&numbers, 1, multiply);
    try std.testing.expectEqual(@as(i32, 120), product);
}

test "inline loop unrolling" {
    const input: @Vector(4, i32) = .{ 1, 2, 3, 4 };
    const result = processVector(input);

    try std.testing.expectEqual(@as(i32, 2), result[0]);
    try std.testing.expectEqual(@as(i32, 8), result[3]);
}

test "subtract operation" {
    const subtract = struct {
        fn call(a: i32, b: i32) i32 {
            return a - b;
        }
    }.call;

    const result = applyOperation(10, 3, subtract);
    try std.testing.expectEqual(@as(i32, 7), result);
}

test "filter odd numbers" {
    const allocator = std.testing.allocator;
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };

    const is_odd = struct {
        fn call(n: i32) bool {
            return @mod(n, 2) != 0;
        }
    }.call;

    const odds = try filter(allocator, &numbers, is_odd);
    defer allocator.free(odds);

    try std.testing.expectEqual(@as(usize, 3), odds.len);
    try std.testing.expectEqual(@as(i32, 1), odds[0]);
}

test "map negate values" {
    const allocator = std.testing.allocator;
    const numbers = [_]i32{ 1, -2, 3, -4 };

    const negate = struct {
        fn call(n: i32) i32 {
            return -n;
        }
    }.call;

    const negated = try map(allocator, &numbers, negate);
    defer allocator.free(negated);

    try std.testing.expectEqual(@as(i32, -1), negated[0]);
    try std.testing.expectEqual(@as(i32, 2), negated[1]);
}

test "reduce maximum" {
    const numbers = [_]i32{ 3, 7, 2, 9, 1 };

    const max_fn = struct {
        fn call(acc: i32, val: i32) i32 {
            return if (val > acc) val else acc;
        }
    }.call;

    const maximum = reduce(&numbers, numbers[0], max_fn);
    try std.testing.expectEqual(@as(i32, 9), maximum);
}
