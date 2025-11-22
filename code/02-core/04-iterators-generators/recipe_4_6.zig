// Recipe 4.6: Defining generators with extra state
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to create iterators that maintain additional
// state beyond just the current position, enabling more complex iteration patterns
// like filtering, counting, transforming, and stateful generation.

const std = @import("std");
const testing = std.testing;

// ANCHOR: stateful_generators
/// Fibonacci generator with state
pub fn FibonacciIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        current: T,
        next_val: T,
        max_value: ?T,
        count: usize,

        pub fn init(max_value: ?T) Self {
            return Self{
                .current = 0,
                .next_val = 1,
                .max_value = max_value,
                .count = 0,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.max_value) |max| {
                if (self.current > max) return null;
            }

            const value = self.current;
            const temp = self.current + self.next_val;
            self.current = self.next_val;
            self.next_val = temp;
            self.count += 1;

            return value;
        }

        pub fn getCount(self: *const Self) usize {
            return self.count;
        }

        pub fn reset(self: *Self) void {
            self.current = 0;
            self.next_val = 1;
            self.count = 0;
        }
    };
}

/// Iterator that filters items based on a predicate
pub fn FilterIterator(comptime T: type) type {
    return struct {
        const Self = @This();
        const PredicateFn = *const fn (T) bool;

        items: []const T,
        index: usize,
        predicate: PredicateFn,
        filtered_count: usize,
        total_checked: usize,

        pub fn init(items: []const T, predicate: PredicateFn) Self {
            return Self{
                .items = items,
                .index = 0,
                .predicate = predicate,
                .filtered_count = 0,
                .total_checked = 0,
            };
        }

        pub fn next(self: *Self) ?T {
            while (self.index < self.items.len) {
                const item = self.items[self.index];
                self.index += 1;
                self.total_checked += 1;

                if (self.predicate(item)) {
                    self.filtered_count += 1;
                    return item;
                }
            }
            return null;
        }

        pub fn getStats(self: *const Self) struct { passed: usize, total: usize } {
            return .{ .passed = self.filtered_count, .total = self.total_checked };
        }
    };
}
// ANCHOR_END: stateful_generators

// ANCHOR: tracking_iterators
/// Iterator that counts occurrences while iterating
pub fn CountingIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        index: usize,
        occurrence_count: std.AutoHashMap(T, usize),
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, items: []const T) !Self {
            return Self{
                .items = items,
                .index = 0,
                .occurrence_count = std.AutoHashMap(T, usize).init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.occurrence_count.deinit();
        }

        pub fn next(self: *Self) !?T {
            if (self.index >= self.items.len) return null;

            const item = self.items[self.index];
            self.index += 1;

            const entry = try self.occurrence_count.getOrPut(item);
            if (entry.found_existing) {
                entry.value_ptr.* += 1;
            } else {
                entry.value_ptr.* = 1;
            }

            return item;
        }

        pub fn getCount(self: *const Self, item: T) ?usize {
            return self.occurrence_count.get(item);
        }

        pub fn getTotalUnique(self: *const Self) usize {
            return self.occurrence_count.count();
        }
    };
}

/// Iterator with running statistics
pub fn StatsIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        index: usize,
        sum: T,
        min: T,
        max: T,
        count: usize,

        pub fn init(items: []const T) ?Self {
            if (items.len == 0) return null;

            return Self{
                .items = items,
                .index = 0,
                .sum = 0,
                .min = items[0],
                .max = items[0],
                .count = 0,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.index >= self.items.len) return null;

            const item = self.items[self.index];
            self.index += 1;
            self.count += 1;

            self.sum += item;
            if (item < self.min) self.min = item;
            if (item > self.max) self.max = item;

            return item;
        }

        pub fn getStats(self: *const Self) struct { sum: T, min: T, max: T, count: usize } {
            return .{
                .sum = self.sum,
                .min = self.min,
                .max = self.max,
                .count = self.count,
            };
        }

        pub fn getAverage(self: *const Self) f64 {
            if (self.count == 0) return 0.0;
            return @as(f64, @floatFromInt(self.sum)) / @as(f64, @floatFromInt(self.count));
        }
    };
}

/// Windowing iterator that yields sliding windows
pub fn WindowIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        window_size: usize,
        index: usize,
        windows_produced: usize,

        pub fn init(items: []const T, window_size: usize) Self {
            return Self{
                .items = items,
                .window_size = window_size,
                .index = 0,
                .windows_produced = 0,
            };
        }

        pub fn next(self: *Self) ?[]const T {
            if (self.index + self.window_size > self.items.len) return null;

            const window = self.items[self.index .. self.index + self.window_size];
            self.index += 1;
            self.windows_produced += 1;
            return window;
        }

        pub fn getWindowCount(self: *const Self) usize {
            return self.windows_produced;
        }

        pub fn getRemainingWindows(self: *const Self) usize {
            if (self.index + self.window_size > self.items.len) return 0;
            return self.items.len - self.window_size - self.index + 1;
        }
    };
}

/// Stateful transform iterator
pub fn TransformIterator(comptime T: type, comptime R: type) type {
    return struct {
        const Self = @This();
        const TransformFn = *const fn (T, *usize) R;

        items: []const T,
        index: usize,
        transform_fn: TransformFn,
        transform_count: usize,

        pub fn init(items: []const T, transform_fn: TransformFn) Self {
            return Self{
                .items = items,
                .index = 0,
                .transform_fn = transform_fn,
                .transform_count = 0,
            };
        }

        pub fn next(self: *Self) ?R {
            if (self.index >= self.items.len) return null;

            const item = self.items[self.index];
            self.index += 1;

            const result = self.transform_fn(item, &self.transform_count);
            return result;
        }

        pub fn getTransformCount(self: *const Self) usize {
            return self.transform_count;
        }
    };
}
// ANCHOR_END: tracking_iterators

test "fibonacci iterator with state" {
    var fib = FibonacciIterator(u64).init(100);

    try testing.expectEqual(@as(?u64, 0), fib.next());
    try testing.expectEqual(@as(?u64, 1), fib.next());
    try testing.expectEqual(@as(?u64, 1), fib.next());
    try testing.expectEqual(@as(?u64, 2), fib.next());
    try testing.expectEqual(@as(?u64, 3), fib.next());
    try testing.expectEqual(@as(?u64, 5), fib.next());
    try testing.expectEqual(@as(?u64, 8), fib.next());
    try testing.expectEqual(@as(?u64, 13), fib.next());

    try testing.expectEqual(@as(usize, 8), fib.getCount());
}

test "fibonacci iterator unlimited" {
    var fib = FibonacciIterator(u64).init(null);

    var count: usize = 0;
    while (count < 10) : (count += 1) {
        _ = fib.next();
    }

    try testing.expectEqual(@as(usize, 10), fib.getCount());
}

test "fibonacci iterator reset" {
    var fib = FibonacciIterator(u64).init(10);

    _ = fib.next();
    _ = fib.next();
    _ = fib.next();

    fib.reset();
    try testing.expectEqual(@as(?u64, 0), fib.next());
    try testing.expectEqual(@as(usize, 1), fib.getCount());
}

test "filter iterator with state" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    const isEven = struct {
        fn f(x: i32) bool {
            return @rem(x, 2) == 0;
        }
    }.f;

    var iter = FilterIterator(i32).init(&items, isEven);

    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, 6), iter.next());
    try testing.expectEqual(@as(?i32, 8), iter.next());
    try testing.expectEqual(@as(?i32, 10), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());

    const stats = iter.getStats();
    try testing.expectEqual(@as(usize, 5), stats.passed);
    try testing.expectEqual(@as(usize, 10), stats.total);
}

test "counting iterator with state" {
    const items = [_]u8{ 1, 2, 3, 2, 1, 3, 1, 2, 3, 1 };

    var iter = try CountingIterator(u8).init(testing.allocator, &items);
    defer iter.deinit();

    while (try iter.next()) |_| {}

    try testing.expectEqual(@as(?usize, 4), iter.getCount(1));
    try testing.expectEqual(@as(?usize, 3), iter.getCount(2));
    try testing.expectEqual(@as(?usize, 3), iter.getCount(3));
    try testing.expectEqual(@as(usize, 3), iter.getTotalUnique());
}

test "stats iterator with state" {
    const items = [_]i32{ 5, 2, 8, 1, 9, 3 };

    var iter = StatsIterator(i32).init(&items).?;

    while (iter.next()) |_| {}

    const stats = iter.getStats();
    try testing.expectEqual(@as(i32, 28), stats.sum);
    try testing.expectEqual(@as(i32, 1), stats.min);
    try testing.expectEqual(@as(i32, 9), stats.max);
    try testing.expectEqual(@as(usize, 6), stats.count);

    const avg = iter.getAverage();
    try testing.expect(@abs(avg - 4.666666) < 0.0001);
}

test "stats iterator empty" {
    const items: []const i32 = &[_]i32{};
    const iter = StatsIterator(i32).init(items);
    try testing.expectEqual(@as(?StatsIterator(i32), null), iter);
}

test "window iterator with state" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };

    var iter = WindowIterator(i32).init(&items, 3);

    const window1 = iter.next().?;
    try testing.expectEqual(@as(i32, 1), window1[0]);
    try testing.expectEqual(@as(i32, 2), window1[1]);
    try testing.expectEqual(@as(i32, 3), window1[2]);

    const window2 = iter.next().?;
    try testing.expectEqual(@as(i32, 2), window2[0]);
    try testing.expectEqual(@as(i32, 3), window2[1]);
    try testing.expectEqual(@as(i32, 4), window2[2]);

    const window3 = iter.next().?;
    try testing.expectEqual(@as(i32, 3), window3[0]);
    try testing.expectEqual(@as(i32, 4), window3[1]);
    try testing.expectEqual(@as(i32, 5), window3[2]);

    try testing.expectEqual(@as(?[]const i32, null), iter.next());
    try testing.expectEqual(@as(usize, 3), iter.getWindowCount());
}

test "window iterator remaining count" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    var iter = WindowIterator(i32).init(&items, 3);

    try testing.expectEqual(@as(usize, 8), iter.getRemainingWindows());
    _ = iter.next();
    try testing.expectEqual(@as(usize, 7), iter.getRemainingWindows());
    _ = iter.next();
    try testing.expectEqual(@as(usize, 6), iter.getRemainingWindows());
}

test "transform iterator with state" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };

    const multiplyByIndex = struct {
        fn f(x: i32, count: *usize) i32 {
            const result = x * @as(i32, @intCast(count.*));
            count.* += 1;
            return result;
        }
    }.f;

    var iter = TransformIterator(i32, i32).init(&items, multiplyByIndex);

    try testing.expectEqual(@as(?i32, 0), iter.next()); // 1 * 0
    try testing.expectEqual(@as(?i32, 2), iter.next()); // 2 * 1
    try testing.expectEqual(@as(?i32, 6), iter.next()); // 3 * 2
    try testing.expectEqual(@as(?i32, 12), iter.next()); // 4 * 3
    try testing.expectEqual(@as(?i32, 20), iter.next()); // 5 * 4

    try testing.expectEqual(@as(usize, 5), iter.getTransformCount());
}

test "combining filter and stats" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    const isOdd = struct {
        fn f(x: i32) bool {
            return @rem(x, 2) != 0;
        }
    }.f;

    var filter = FilterIterator(i32).init(&items, isOdd);

    var odd_values: [5]i32 = undefined;
    var i: usize = 0;
    while (filter.next()) |val| : (i += 1) {
        odd_values[i] = val;
    }

    var stats = StatsIterator(i32).init(&odd_values).?;
    while (stats.next()) |_| {}

    const s = stats.getStats();
    try testing.expectEqual(@as(i32, 25), s.sum);
    try testing.expectEqual(@as(i32, 1), s.min);
    try testing.expectEqual(@as(i32, 9), s.max);
}

test "memory safety - iterator state tracking" {
    var fib = FibonacciIterator(u32).init(1000);

    var count: usize = 0;
    while (fib.next()) |_| {
        count += 1;
        if (count > 20) break;
    }

    try testing.expect(fib.getCount() <= 20);
}

test "security - filter iterator bounds" {
    const items = [_]i32{ 1, 2, 3 };

    const alwaysTrue = struct {
        fn f(_: i32) bool {
            return true;
        }
    }.f;

    var iter = FilterIterator(i32).init(&items, alwaysTrue);

    // Exhaust iterator
    while (iter.next()) |_| {}

    // Should safely return null
    try testing.expectEqual(@as(?i32, null), iter.next());

    const stats = iter.getStats();
    try testing.expectEqual(@as(usize, 3), stats.passed);
    try testing.expectEqual(@as(usize, 3), stats.total);
}

test "security - counting iterator with allocator" {
    const items = [_]u8{ 1, 2, 3, 2, 1 };

    var iter = try CountingIterator(u8).init(testing.allocator, &items);
    defer iter.deinit();

    while (try iter.next()) |_| {}

    // Verify no memory leaks through proper cleanup
    try testing.expect(iter.getTotalUnique() > 0);
}
