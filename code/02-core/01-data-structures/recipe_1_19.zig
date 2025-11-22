// Recipe 1.19: Transforming and reducing data simultaneously
// Target Zig Version: 0.15.2
//
// This recipe demonstrates idiomatic approaches to transforming and reducing
// data in Zig using explicit loops rather than functional-style chains.

const std = @import("std");
const testing = std.testing;

/// Transform and reduce in a single pass - most efficient approach
// ANCHOR: transform_reduce
pub fn transformReduce(
    comptime T: type,
    comptime R: type,
    items: []const T,
    initial: R,
    transformFn: *const fn (T) R,
    reduceFn: *const fn (R, R) R,
) R {
    var result = initial;
    for (items) |item| {
        const transformed = transformFn(item);
        result = reduceFn(result, transformed);
    }
    return result;
}
// ANCHOR_END: transform_reduce

/// Map then reduce with intermediate storage (when you need the transformed values)
pub fn mapThenReduce(
    comptime T: type,
    comptime R: type,
    allocator: std.mem.Allocator,
    items: []const T,
    initial: R,
    mapFn: *const fn (T) R,
    reduceFn: *const fn (R, R) R,
) !R {
    var mapped = std.ArrayList(R){};
    defer mapped.deinit(allocator);

    // Transform phase
    for (items) |item| {
        try mapped.append(allocator, mapFn(item));
    }

    // Reduce phase
    var result = initial;
    for (mapped.items) |value| {
        result = reduceFn(result, value);
    }

    return result;
}

/// Fold left (reduce from left to right) with state
// ANCHOR: fold_left
pub fn foldl(
    comptime T: type,
    comptime Acc: type,
    items: []const T,
    initial: Acc,
    func: *const fn (Acc, T) Acc,
) Acc {
    var acc = initial;
    for (items) |item| {
        acc = func(acc, item);
    }
    return acc;
}
// ANCHOR_END: fold_left

/// Fold right (reduce from right to left)
// ANCHOR: fold_right
pub fn foldr(
    comptime T: type,
    comptime Acc: type,
    items: []const T,
    initial: Acc,
    func: *const fn (T, Acc) Acc,
) Acc {
    var acc = initial;
    var i = items.len;
    while (i > 0) {
        i -= 1;
        acc = func(items[i], acc);
    }
    return acc;
}
// ANCHOR_END: fold_right

test "transform and reduce - sum of squares" {
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };

    const square = struct {
        fn f(n: i32) i32 {
            return n * n;
        }
    }.f;

    const add = struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f;

    const sum_of_squares = transformReduce(i32, i32, &numbers, 0, square, add);

    try testing.expectEqual(@as(i32, 55), sum_of_squares); // 1+4+9+16+25
}

test "transform and reduce - product of doubled values" {
    const numbers = [_]i32{ 1, 2, 3, 4 };

    const double = struct {
        fn f(n: i32) i32 {
            return n * 2;
        }
    }.f;

    const multiply = struct {
        fn f(a: i32, b: i32) i32 {
            return a * b;
        }
    }.f;

    const product = transformReduce(i32, i32, &numbers, 1, double, multiply);

    try testing.expectEqual(@as(i32, 384), product); // 2*4*6*8
}

test "fold left - sum with accumulator" {
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };

    const add = struct {
        fn f(acc: i32, n: i32) i32 {
            return acc + n;
        }
    }.f;

    const sum = foldl(i32, i32, &numbers, 0, add);

    try testing.expectEqual(@as(i32, 15), sum);
}

test "fold right - reverse string building" {
    const chars = [_]u8{ 'a', 'b', 'c', 'd' };

    const Acc = struct {
        buf: [10]u8 = undefined,
        len: usize = 0,

        fn append(self: *@This(), c: u8) void {
            self.buf[self.len] = c;
            self.len += 1;
        }
    };

    // Fold right reverses the order
    const appendChar = struct {
        fn f(c: u8, acc: Acc) Acc {
            var result = acc;
            result.buf[result.len] = c;
            result.len += 1;
            return result;
        }
    }.f;

    const result = foldr(u8, Acc, &chars, Acc{}, appendChar);

    try testing.expectEqualStrings("dcba", result.buf[0..result.len]);
}

test "idiomatic Zig - explicit loop for clarity" {
    // Instead of chaining functional methods, Zig prefers explicit loops
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };

    // Calculate: sum of (n * 2) for even numbers only
    var sum: i32 = 0;
    for (numbers) |n| {
        if (@mod(n, 2) == 0) {
            sum += n * 2;
        }
    }

    try testing.expectEqual(@as(i32, 12), sum); // (2*2) + (4*2)
}

test "complex reduction - statistics calculation" {
    const numbers = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0 };

    const Stats = struct {
        sum: f32 = 0.0,
        count: usize = 0,
        min: f32 = std.math.floatMax(f32),
        max: f32 = std.math.floatMin(f32),

        fn avg(self: @This()) f32 {
            return self.sum / @as(f32, @floatFromInt(self.count));
        }
    };

    const updateStats = struct {
        fn f(stats: Stats, value: f32) Stats {
            return Stats{
                .sum = stats.sum + value,
                .count = stats.count + 1,
                .min = @min(stats.min, value),
                .max = @max(stats.max, value),
            };
        }
    }.f;

    const stats = foldl(f32, Stats, &numbers, Stats{}, updateStats);

    try testing.expectEqual(@as(f32, 15.0), stats.sum);
    try testing.expectEqual(@as(usize, 5), stats.count);
    try testing.expectEqual(@as(f32, 1.0), stats.min);
    try testing.expectEqual(@as(f32, 5.0), stats.max);
    try testing.expectEqual(@as(f32, 3.0), stats.avg());
}

test "string concatenation with fold" {
    const words = [_][]const u8{ "Hello", "Zig", "World" };

    const Acc = struct {
        buf: [100]u8 = undefined,
        len: usize = 0,

        fn addWord(self: @This(), word: []const u8) @This() {
            var result = self;

            // Add space if not first word
            if (result.len > 0) {
                result.buf[result.len] = ' ';
                result.len += 1;
            }

            // Copy word
            @memcpy(result.buf[result.len..][0..word.len], word);
            result.len += word.len;

            return result;
        }
    };

    const concat = struct {
        fn f(acc: Acc, word: []const u8) Acc {
            return acc.addWord(word);
        }
    }.f;

    const result = foldl([]const u8, Acc, &words, Acc{}, concat);

    try testing.expectEqualStrings("Hello Zig World", result.buf[0..result.len]);
}

test "map then reduce - when intermediate values needed" {
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };

    const square = struct {
        fn f(n: i32) i32 {
            return n * n;
        }
    }.f;

    const add = struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f;

    const sum = try mapThenReduce(i32, i32, testing.allocator, &numbers, 0, square, add);

    try testing.expectEqual(@as(i32, 55), sum); // 1+4+9+16+25
}

test "filtering and reducing combined" {
    const numbers = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    // Sum of squares of even numbers
    const FilterReduceState = struct {
        sum: i32,
    };

    const processEven = struct {
        fn f(state: FilterReduceState, n: i32) FilterReduceState {
            if (@mod(n, 2) == 0) {
                return .{ .sum = state.sum + (n * n) };
            }
            return state;
        }
    }.f;

    const result = foldl(i32, FilterReduceState, &numbers, .{ .sum = 0 }, processEven);

    try testing.expectEqual(@as(i32, 220), result.sum); // 4+16+36+64+100
}

test "grouping and counting simultaneously" {
    const words = [_][]const u8{ "apple", "banana", "apricot", "blueberry", "avocado" };

    // Count words by first letter
    const LetterCount = struct {
        a_count: usize = 0,
        b_count: usize = 0,
    };

    const countByLetter = struct {
        fn f(counts: LetterCount, word: []const u8) LetterCount {
            if (word.len == 0) return counts;

            var result = counts;
            switch (word[0]) {
                'a' => result.a_count += 1,
                'b' => result.b_count += 1,
                else => {},
            }
            return result;
        }
    }.f;

    const counts = foldl([]const u8, LetterCount, &words, LetterCount{}, countByLetter);

    try testing.expectEqual(@as(usize, 3), counts.a_count); // apple, apricot, avocado
    try testing.expectEqual(@as(usize, 2), counts.b_count); // banana, blueberry
}

test "memory safety - no allocations in transformReduce" {
    // transformReduce doesn't allocate, so no memory management needed
    const numbers = [_]i32{ 1, 2, 3 };

    const double = struct {
        fn f(n: i32) i32 {
            return n * 2;
        }
    }.f;

    const add = struct {
        fn f(a: i32, b: i32) i32 {
            return a + b;
        }
    }.f;

    const sum = transformReduce(i32, i32, &numbers, 0, double, add);

    try testing.expectEqual(@as(i32, 12), sum);
}
