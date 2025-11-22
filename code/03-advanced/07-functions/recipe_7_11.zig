const std = @import("std");

// ANCHOR: inline_callback
/// Inline callback for immediate execution
pub fn processInline(
    items: []const i32,
    comptime callback: fn (i32) i32,
) i32 {
    var sum: i32 = 0;
    for (items) |item| {
        sum += callback(item);
    }
    return sum;
}

fn double(x: i32) i32 {
    return x * 2;
}

/// Comptime callback specialization
pub fn forEach(
    items: []const i32,
    context: anytype,
    comptime callback: fn (@TypeOf(context), i32) void,
) void {
    for (items) |item| {
        callback(context, item);
    }
}
// ANCHOR_END: inline_callback

// ANCHOR: inline_transforms
/// Inline map function
pub fn map(
    allocator: std.mem.Allocator,
    items: []const i32,
    comptime transform: fn (i32) i32,
) ![]i32 {
    var result = std.ArrayList(i32){};
    errdefer result.deinit(allocator);

    for (items) |item| {
        try result.append(allocator, transform(item));
    }

    return try result.toOwnedSlice(allocator);
}

/// Inline filter function
pub fn filter(
    allocator: std.mem.Allocator,
    items: []const i32,
    comptime predicate: fn (i32) bool,
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

/// Inline reduce function
pub fn reduce(
    items: []const i32,
    initial: i32,
    comptime accumulate: fn (i32, i32) i32,
) i32 {
    var result = initial;
    for (items) |item| {
        result = accumulate(result, item);
    }
    return result;
}
// ANCHOR_END: inline_transforms

// ANCHOR: inline_pipeline
/// Pipeline function
pub fn pipeline(
    allocator: std.mem.Allocator,
    items: []const i32,
    comptime transform: fn (i32) i32,
    comptime pred: fn (i32) bool,
) ![]i32 {
    var result = std.ArrayList(i32){};
    errdefer result.deinit(allocator);

    for (items) |item| {
        const transformed = transform(item);
        if (pred(transformed)) {
            try result.append(allocator, transformed);
        }
    }

    return try result.toOwnedSlice(allocator);
}
// ANCHOR_END: inline_pipeline

/// Generic map
pub fn GenericMap(comptime T: type, comptime R: type) type {
    return struct {
        pub fn map(
            allocator: std.mem.Allocator,
            items: []const T,
            comptime transform: fn (T) R,
        ) ![]R {
            var result = std.ArrayList(R){};
            errdefer result.deinit(allocator);

            for (items) |item| {
                try result.append(allocator, transform(item));
            }

            return try result.toOwnedSlice(allocator);
        }
    };
}

/// Iterator type
pub fn Iterator(comptime T: type) type {
    return struct {
        items: []const T,
        index: usize = 0,

        pub fn next(self: *@This()) ?T {
            if (self.index >= self.items.len) return null;
            const item = self.items[self.index];
            self.index += 1;
            return item;
        }

        pub fn collect(
            self: *@This(),
            allocator: std.mem.Allocator,
            comptime transform: fn (T) T,
        ) ![]T {
            var result = std.ArrayList(T){};
            errdefer result.deinit(allocator);

            while (self.next()) |item| {
                try result.append(allocator, transform(item));
            }

            return try result.toOwnedSlice(allocator);
        }
    };
}

/// Conditional inlining
pub fn processWithStrategy(
    items: []const i32,
    comptime inline_it: bool,
) i32 {
    if (inline_it) {
        return processInline(items, struct {
            fn double_fn(x: i32) i32 {
                return x * 2;
            }
        }.double_fn);
    } else {
        var sum: i32 = 0;
        for (items) |item| {
            sum += item * 2;
        }
        return sum;
    }
}

/// Sort with inline comparator
pub fn sortWith(
    items: []i32,
    comptime lessThan: fn (i32, i32) bool,
) void {
    if (items.len <= 1) return;

    for (items, 0..) |_, i| {
        for (items[0 .. items.len - i - 1], 0..) |_, j| {
            if (!lessThan(items[j], items[j + 1])) {
                const temp = items[j];
                items[j] = items[j + 1];
                items[j + 1] = temp;
            }
        }
    }
}

// Tests

test "inline callback" {
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    const result = processInline(&numbers, double);
    try std.testing.expectEqual(@as(i32, 30), result);
}

test "comptime callback specialization" {
    var sum: i32 = 0;

    const Adder = struct {
        fn add(ctx: *i32, value: i32) void {
            ctx.* += value;
        }
    };

    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    forEach(&numbers, &sum, Adder.add);

    try std.testing.expectEqual(@as(i32, 15), sum);
}

test "inline map" {
    const allocator = std.testing.allocator;

    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    const doubled = try map(allocator, &numbers, struct {
        fn transform(x: i32) i32 {
            return x * 2;
        }
    }.transform);
    defer allocator.free(doubled);

    try std.testing.expectEqual(@as(usize, 5), doubled.len);
    try std.testing.expectEqual(@as(i32, 2), doubled[0]);
    try std.testing.expectEqual(@as(i32, 10), doubled[4]);
}

test "inline filter" {
    const allocator = std.testing.allocator;

    const numbers = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    const evens = try filter(allocator, &numbers, struct {
        fn isEven(x: i32) bool {
            return @mod(x, 2) == 0;
        }
    }.isEven);
    defer allocator.free(evens);

    try std.testing.expectEqual(@as(usize, 5), evens.len);
    try std.testing.expectEqual(@as(i32, 2), evens[0]);
}

test "inline reduce" {
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };

    const sum = reduce(&numbers, 0, struct {
        fn add(acc: i32, x: i32) i32 {
            return acc + x;
        }
    }.add);

    try std.testing.expectEqual(@as(i32, 15), sum);

    const product = reduce(&numbers, 1, struct {
        fn multiply(acc: i32, x: i32) i32 {
            return acc * x;
        }
    }.multiply);

    try std.testing.expectEqual(@as(i32, 120), product);
}

test "inline pipeline" {
    const allocator = std.testing.allocator;

    const numbers = [_]i32{ 1, 2, 3, 4, 5 };

    const result = try pipeline(
        allocator,
        &numbers,
        struct {
            fn double_fn(x: i32) i32 {
                return x * 2;
            }
        }.double_fn,
        struct {
            fn greaterThanFive(x: i32) bool {
                return x > 5;
            }
        }.greaterThanFive,
    );
    defer allocator.free(result);

    try std.testing.expectEqual(@as(usize, 3), result.len);
    try std.testing.expectEqual(@as(i32, 6), result[0]);
    try std.testing.expectEqual(@as(i32, 8), result[1]);
    try std.testing.expectEqual(@as(i32, 10), result[2]);
}

test "generic inline map" {
    const allocator = std.testing.allocator;

    const numbers = [_]i32{ 1, 2, 3 };
    const doubled = try GenericMap(i32, i32).map(allocator, &numbers, struct {
        fn double_fn(x: i32) i32 {
            return x * 2;
        }
    }.double_fn);
    defer allocator.free(doubled);

    try std.testing.expectEqual(@as(usize, 3), doubled.len);
    try std.testing.expectEqual(@as(i32, 2), doubled[0]);
}

test "inline iterator processing" {
    const allocator = std.testing.allocator;

    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = Iterator(i32){ .items = &numbers };

    const doubled = try iter.collect(allocator, struct {
        fn double_fn(x: i32) i32 {
            return x * 2;
        }
    }.double_fn);
    defer allocator.free(doubled);

    try std.testing.expectEqual(@as(usize, 5), doubled.len);
    try std.testing.expectEqual(@as(i32, 10), doubled[4]);
}

test "conditional inlining" {
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };

    const result1 = processWithStrategy(&numbers, true);
    try std.testing.expectEqual(@as(i32, 30), result1);

    const result2 = processWithStrategy(&numbers, false);
    try std.testing.expectEqual(@as(i32, 30), result2);
}

test "inline comparison ascending" {
    var ascending = [_]i32{ 5, 2, 8, 1, 9 };
    sortWith(&ascending, struct {
        fn lessThan(a: i32, b: i32) bool {
            return a < b;
        }
    }.lessThan);

    try std.testing.expectEqual(@as(i32, 1), ascending[0]);
    try std.testing.expectEqual(@as(i32, 9), ascending[4]);
}

test "inline comparison descending" {
    var descending = [_]i32{ 5, 2, 8, 1, 9 };
    sortWith(&descending, struct {
        fn greaterThan(a: i32, b: i32) bool {
            return a > b;
        }
    }.greaterThan);

    try std.testing.expectEqual(@as(i32, 9), descending[0]);
    try std.testing.expectEqual(@as(i32, 1), descending[4]);
}

test "map with triple" {
    const allocator = std.testing.allocator;

    const numbers = [_]i32{ 1, 2, 3 };
    const tripled = try map(allocator, &numbers, struct {
        fn triple(x: i32) i32 {
            return x * 3;
        }
    }.triple);
    defer allocator.free(tripled);

    try std.testing.expectEqual(@as(usize, 3), tripled.len);
    try std.testing.expectEqual(@as(i32, 3), tripled[0]);
    try std.testing.expectEqual(@as(i32, 9), tripled[2]);
}

test "filter odds" {
    const allocator = std.testing.allocator;

    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    const odds = try filter(allocator, &numbers, struct {
        fn isOdd(x: i32) bool {
            return @mod(x, 2) == 1;
        }
    }.isOdd);
    defer allocator.free(odds);

    try std.testing.expectEqual(@as(usize, 3), odds.len);
    try std.testing.expectEqual(@as(i32, 1), odds[0]);
    try std.testing.expectEqual(@as(i32, 5), odds[2]);
}

test "reduce with max" {
    const numbers = [_]i32{ 5, 2, 8, 1, 9 };

    const max_val = reduce(&numbers, numbers[0], struct {
        fn max(acc: i32, x: i32) i32 {
            return if (x > acc) x else acc;
        }
    }.max);

    try std.testing.expectEqual(@as(i32, 9), max_val);
}
