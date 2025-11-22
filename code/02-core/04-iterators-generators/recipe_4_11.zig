// Recipe 4.11: Iterating over multiple sequences simultaneously (Zip iterators)
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to iterate over multiple sequences simultaneously,
// combining values from different sources into tuples or structs.

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_zip
/// Zip two sequences together
pub fn Zip2(comptime T1: type, comptime T2: type) type {
    return struct {
        const Self = @This();

        pub const Pair = struct {
            first: T1,
            second: T2,
        };

        items1: []const T1,
        items2: []const T2,
        index: usize,

        pub fn init(items1: []const T1, items2: []const T2) Self {
            return Self{
                .items1 = items1,
                .items2 = items2,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?Pair {
            const min_len = @min(self.items1.len, self.items2.len);
            if (self.index >= min_len) return null;

            const pair = Pair{
                .first = self.items1[self.index],
                .second = self.items2[self.index],
            };
            self.index += 1;
            return pair;
        }

        pub fn remaining(self: *const Self) usize {
            const min_len = @min(self.items1.len, self.items2.len);
            if (self.index >= min_len) return 0;
            return min_len - self.index;
        }
    };
}

/// Zip three sequences together
pub fn Zip3(comptime T1: type, comptime T2: type, comptime T3: type) type {
    return struct {
        const Self = @This();

        pub const Triple = struct {
            first: T1,
            second: T2,
            third: T3,
        };

        items1: []const T1,
        items2: []const T2,
        items3: []const T3,
        index: usize,

        pub fn init(
            items1: []const T1,
            items2: []const T2,
            items3: []const T3,
        ) Self {
            return Self{
                .items1 = items1,
                .items2 = items2,
                .items3 = items3,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?Triple {
            const min_len = @min(
                @min(self.items1.len, self.items2.len),
                self.items3.len,
            );
            if (self.index >= min_len) return null;

            const triple = Triple{
                .first = self.items1[self.index],
                .second = self.items2[self.index],
                .third = self.items3[self.index],
            };
            self.index += 1;
            return triple;
        }
    };
}
// ANCHOR_END: basic_zip

// ANCHOR: strategic_zip
/// Zip with explicit length checking strategy
pub const ZipStrategy = enum {
    shortest, // Stop at shortest sequence
    longest, // Continue until longest (requires optional values)
    exact, // Require all sequences to have same length
};

/// Zip with strategy for handling different lengths
pub fn ZipStrategic(comptime T1: type, comptime T2: type, comptime strategy: ZipStrategy) type {
    return struct {
        const Self = @This();

        pub const Pair = if (strategy == .longest)
            struct {
                first: ?T1,
                second: ?T2,
            }
        else
            struct {
                first: T1,
                second: T2,
            };

        items1: []const T1,
        items2: []const T2,
        index: usize,
        checked: bool,

        pub fn init(items1: []const T1, items2: []const T2) !Self {
            if (strategy == .exact and items1.len != items2.len) {
                return error.LengthMismatch;
            }

            return Self{
                .items1 = items1,
                .items2 = items2,
                .index = 0,
                .checked = false,
            };
        }

        pub fn next(self: *Self) ?Pair {
            switch (strategy) {
                .shortest, .exact => {
                    const min_len = @min(self.items1.len, self.items2.len);
                    if (self.index >= min_len) return null;

                    const pair = Pair{
                        .first = self.items1[self.index],
                        .second = self.items2[self.index],
                    };
                    self.index += 1;
                    return pair;
                },
                .longest => {
                    const max_len = @max(self.items1.len, self.items2.len);
                    if (self.index >= max_len) return null;

                    const pair = Pair{
                        .first = if (self.index < self.items1.len)
                            self.items1[self.index]
                        else
                            null,
                        .second = if (self.index < self.items2.len)
                            self.items2[self.index]
                        else
                            null,
                    };
                    self.index += 1;
                    return pair;
                },
            }
        }
    };
}

// ANCHOR: advanced_zip
/// Zip with index
pub fn ZipWithIndex(comptime T1: type, comptime T2: type) type {
    return struct {
        const Self = @This();

        pub const IndexedPair = struct {
            index: usize,
            first: T1,
            second: T2,
        };

        items1: []const T1,
        items2: []const T2,
        index: usize,

        pub fn init(items1: []const T1, items2: []const T2) Self {
            return Self{
                .items1 = items1,
                .items2 = items2,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?IndexedPair {
            const min_len = @min(self.items1.len, self.items2.len);
            if (self.index >= min_len) return null;

            const pair = IndexedPair{
                .index = self.index,
                .first = self.items1[self.index],
                .second = self.items2[self.index],
            };
            self.index += 1;
            return pair;
        }
    };
}

/// Zip and transform
pub fn ZipMap(comptime T1: type, comptime T2: type, comptime R: type) type {
    return struct {
        const Self = @This();
        const MapFn = *const fn (T1, T2) R;

        items1: []const T1,
        items2: []const T2,
        index: usize,
        map_fn: MapFn,

        pub fn init(items1: []const T1, items2: []const T2, map_fn: MapFn) Self {
            return Self{
                .items1 = items1,
                .items2 = items2,
                .index = 0,
                .map_fn = map_fn,
            };
        }

        pub fn next(self: *Self) ?R {
            const min_len = @min(self.items1.len, self.items2.len);
            if (self.index >= min_len) return null;

            const result = self.map_fn(
                self.items1[self.index],
                self.items2[self.index],
            );
            self.index += 1;
            return result;
        }
    };
}
// ANCHOR_END: advanced_zip

/// Unzip - split pairs back into separate sequences
pub fn unzip(comptime T1: type, comptime T2: type, allocator: std.mem.Allocator, pairs: []const struct { T1, T2 }) !struct { []T1, []T2 } {
    var first = try allocator.alloc(T1, pairs.len);
    errdefer allocator.free(first);

    var second = try allocator.alloc(T2, pairs.len);
    errdefer allocator.free(second);

    for (pairs, 0..) |pair, i| {
        first[i] = pair[0];
        second[i] = pair[1];
    }

    return .{ first, second };
}
// ANCHOR_END: strategic_zip

test "zip2 basic" {
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    const letters = [_]u8{ 'a', 'b', 'c', 'd', 'e' };

    var iter = Zip2(i32, u8).init(&numbers, &letters);

    const pair1 = iter.next().?;
    try testing.expectEqual(@as(i32, 1), pair1.first);
    try testing.expectEqual(@as(u8, 'a'), pair1.second);

    const pair2 = iter.next().?;
    try testing.expectEqual(@as(i32, 2), pair2.first);
    try testing.expectEqual(@as(u8, 'b'), pair2.second);
}

test "zip2 different lengths" {
    const short = [_]i32{ 1, 2, 3 };
    const long = [_]i32{ 10, 20, 30, 40, 50 };

    var iter = Zip2(i32, i32).init(&short, &long);

    var count: usize = 0;
    while (iter.next()) |_| {
        count += 1;
    }

    try testing.expectEqual(@as(usize, 3), count);
}

test "zip2 empty" {
    const empty: []const i32 = &[_]i32{};
    const items = [_]i32{ 1, 2, 3 };

    var iter = Zip2(i32, i32).init(empty, &items);

    try testing.expect(iter.next() == null);
}

test "zip3 basic" {
    const a = [_]i32{ 1, 2, 3 };
    const b = [_]i32{ 10, 20, 30 };
    const c = [_]i32{ 100, 200, 300 };

    var iter = Zip3(i32, i32, i32).init(&a, &b, &c);

    const triple1 = iter.next().?;
    try testing.expectEqual(@as(i32, 1), triple1.first);
    try testing.expectEqual(@as(i32, 10), triple1.second);
    try testing.expectEqual(@as(i32, 100), triple1.third);

    const triple2 = iter.next().?;
    try testing.expectEqual(@as(i32, 2), triple2.first);
    try testing.expectEqual(@as(i32, 20), triple2.second);
    try testing.expectEqual(@as(i32, 200), triple2.third);
}

test "zip strategic shortest" {
    const short = [_]i32{ 1, 2, 3 };
    const long = [_]i32{ 10, 20, 30, 40, 50 };

    var iter = try ZipStrategic(i32, i32, .shortest).init(&short, &long);

    var count: usize = 0;
    while (iter.next()) |_| {
        count += 1;
    }

    try testing.expectEqual(@as(usize, 3), count);
}

test "zip strategic longest" {
    const short = [_]i32{ 1, 2, 3 };
    const long = [_]i32{ 10, 20, 30, 40, 50 };

    var iter = try ZipStrategic(i32, i32, .longest).init(&short, &long);

    var pairs: [5]@TypeOf(iter).Pair = undefined;
    var i: usize = 0;

    while (iter.next()) |pair| : (i += 1) {
        pairs[i] = pair;
    }

    try testing.expectEqual(@as(usize, 5), i);

    try testing.expectEqual(@as(?i32, 1), pairs[0].first);
    try testing.expectEqual(@as(?i32, 10), pairs[0].second);

    try testing.expectEqual(@as(?i32, null), pairs[4].first);
    try testing.expectEqual(@as(?i32, 50), pairs[4].second);
}

test "zip strategic exact match" {
    const a = [_]i32{ 1, 2, 3 };
    const b = [_]i32{ 10, 20, 30 };

    var iter = try ZipStrategic(i32, i32, .exact).init(&a, &b);

    var count: usize = 0;
    while (iter.next()) |_| {
        count += 1;
    }

    try testing.expectEqual(@as(usize, 3), count);
}

test "zip strategic exact mismatch" {
    const short = [_]i32{ 1, 2, 3 };
    const long = [_]i32{ 10, 20, 30, 40, 50 };

    const result = ZipStrategic(i32, i32, .exact).init(&short, &long);
    try testing.expectError(error.LengthMismatch, result);
}

test "zip with index" {
    const a = [_]i32{ 10, 20, 30 };
    const b = [_]u8{ 'a', 'b', 'c' };

    var iter = ZipWithIndex(i32, u8).init(&a, &b);

    const item1 = iter.next().?;
    try testing.expectEqual(@as(usize, 0), item1.index);
    try testing.expectEqual(@as(i32, 10), item1.first);
    try testing.expectEqual(@as(u8, 'a'), item1.second);

    const item2 = iter.next().?;
    try testing.expectEqual(@as(usize, 1), item2.index);
}

test "zip map" {
    const a = [_]i32{ 1, 2, 3, 4, 5 };
    const b = [_]i32{ 10, 20, 30, 40, 50 };

    const add = struct {
        fn f(x: i32, y: i32) i32 {
            return x + y;
        }
    }.f;

    var iter = ZipMap(i32, i32, i32).init(&a, &b, add);

    try testing.expectEqual(@as(?i32, 11), iter.next());
    try testing.expectEqual(@as(?i32, 22), iter.next());
    try testing.expectEqual(@as(?i32, 33), iter.next());
    try testing.expectEqual(@as(?i32, 44), iter.next());
    try testing.expectEqual(@as(?i32, 55), iter.next());
}

test "zip map with different types" {
    const numbers = [_]f64{ 1.5, 2.5, 3.5 };
    const multipliers = [_]i32{ 2, 3, 4 };

    const multiply = struct {
        fn f(n: f64, m: i32) f64 {
            return n * @as(f64, @floatFromInt(m));
        }
    }.f;

    var iter = ZipMap(f64, i32, f64).init(&numbers, &multipliers, multiply);

    try testing.expect(@abs(iter.next().? - 3.0) < 0.001);
    try testing.expect(@abs(iter.next().? - 7.5) < 0.001);
    try testing.expect(@abs(iter.next().? - 14.0) < 0.001);
}

test "unzip" {
    const pairs = [_]struct { i32, u8 }{
        .{ 1, 'a' },
        .{ 2, 'b' },
        .{ 3, 'c' },
    };

    const result = try unzip(i32, u8, testing.allocator, &pairs);
    defer testing.allocator.free(result[0]);
    defer testing.allocator.free(result[1]);

    try testing.expectEqual(@as(usize, 3), result[0].len);
    try testing.expectEqual(@as(usize, 3), result[1].len);

    try testing.expectEqual(@as(i32, 1), result[0][0]);
    try testing.expectEqual(@as(u8, 'a'), result[1][0]);

    try testing.expectEqual(@as(i32, 3), result[0][2]);
    try testing.expectEqual(@as(u8, 'c'), result[1][2]);
}

test "zig builtin multi-array iteration" {
    const names = [_][]const u8{ "Alice", "Bob", "Carol" };
    const ages = [_]u32{ 30, 25, 35 };

    var collected: [3]struct { []const u8, u32 } = undefined;
    var i: usize = 0;

    for (names, ages) |name, age| {
        collected[i] = .{ name, age };
        i += 1;
    }

    try testing.expectEqual(@as(usize, 3), i);
    try testing.expect(std.mem.eql(u8, "Alice", collected[0][0]));
    try testing.expectEqual(@as(u32, 30), collected[0][1]);
}

test "memory safety - zip remaining" {
    const a = [_]i32{ 1, 2, 3, 4, 5 };
    const b = [_]i32{ 10, 20, 30 };

    var iter = Zip2(i32, i32).init(&a, &b);

    try testing.expectEqual(@as(usize, 3), iter.remaining());

    _ = iter.next();
    try testing.expectEqual(@as(usize, 2), iter.remaining());

    _ = iter.next();
    _ = iter.next();
    try testing.expectEqual(@as(usize, 0), iter.remaining());
}

test "security - zip bounds checking" {
    const a = [_]i32{ 1, 2, 3 };
    const b = [_]i32{ 10, 20 };

    var iter = Zip2(i32, i32).init(&a, &b);

    _ = iter.next();
    _ = iter.next();

    // Should safely return null, not access out of bounds
    try testing.expect(iter.next() == null);
}

test "security - unzip with allocator" {
    const pairs = [_]struct { i32, u8 }{
        .{ 1, 'a' },
        .{ 2, 'b' },
    };

    const result = try unzip(i32, u8, testing.allocator, &pairs);
    defer testing.allocator.free(result[0]);
    defer testing.allocator.free(result[1]);

    // Verify no memory leaks through proper cleanup
    try testing.expectEqual(@as(usize, 2), result[0].len);
    try testing.expectEqual(@as(usize, 2), result[1].len);
}
