// Recipe 4.10: Iterating over index-value pairs
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to iterate over sequences while tracking indices,
// including Zig's built-in index syntax and custom enumerate patterns.

const std = @import("std");
const testing = std.testing;

// ANCHOR: enumerate_iterator
/// Enumerate iterator that yields index-value pairs
pub fn EnumerateIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const Pair = struct {
            index: usize,
            value: T,
        };

        items: []const T,
        index: usize,

        pub fn init(items: []const T) Self {
            return Self{
                .items = items,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?Pair {
            if (self.index >= self.items.len) return null;

            const pair = Pair{
                .index = self.index,
                .value = self.items[self.index],
            };
            self.index += 1;
            return pair;
        }

        pub fn reset(self: *Self) void {
            self.index = 0;
        }
    };
}
// ANCHOR_END: enumerate_iterator

// ANCHOR: enumerate_variants
/// Enumerate with custom start index
pub fn EnumerateFrom(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const Pair = struct {
            index: usize,
            value: T,
        };

        items: []const T,
        current_index: usize,
        start_index: usize,

        pub fn init(items: []const T, start: usize) Self {
            return Self{
                .items = items,
                .current_index = 0,
                .start_index = start,
            };
        }

        pub fn next(self: *Self) ?Pair {
            if (self.current_index >= self.items.len) return null;

            const pair = Pair{
                .index = self.start_index + self.current_index,
                .value = self.items[self.current_index],
            };
            self.current_index += 1;
            return pair;
        }
    };
}

/// Enumerate with step
pub fn EnumerateStep(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const Pair = struct {
            index: usize,
            value: T,
        };

        items: []const T,
        array_index: usize,
        logical_index: usize,
        step: usize,

        pub fn init(items: []const T, step: usize) Self {
            return Self{
                .items = items,
                .array_index = 0,
                .logical_index = 0,
                .step = if (step == 0) 1 else step,
            };
        }

        pub fn next(self: *Self) ?Pair {
            if (self.array_index >= self.items.len) return null;

            const pair = Pair{
                .index = self.logical_index,
                .value = self.items[self.array_index],
            };

            self.array_index += self.step;
            self.logical_index += 1;
            return pair;
        }
    };
}

/// Reversed enumerate
pub fn EnumerateReverse(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const Pair = struct {
            index: usize,
            value: T,
        };

        items: []const T,
        current_position: usize,

        pub fn init(items: []const T) Self {
            return Self{
                .items = items,
                .current_position = items.len,
            };
        }

        pub fn next(self: *Self) ?Pair {
            if (self.current_position == 0) return null;

            self.current_position -= 1;
            const pair = Pair{
                .index = self.current_position,
                .value = self.items[self.current_position],
            };
            return pair;
        }
    };
}
// ANCHOR_END: enumerate_variants

// ANCHOR: advanced_enumerate
/// Enumerate with filtering
pub fn EnumerateFilter(comptime T: type) type {
    return struct {
        const Self = @This();
        const PredicateFn = *const fn (T) bool;

        pub const Pair = struct {
            original_index: usize,
            filtered_index: usize,
            value: T,
        };

        items: []const T,
        original_index: usize,
        filtered_index: usize,
        predicate: PredicateFn,

        pub fn init(items: []const T, predicate: PredicateFn) Self {
            return Self{
                .items = items,
                .original_index = 0,
                .filtered_index = 0,
                .predicate = predicate,
            };
        }

        pub fn next(self: *Self) ?Pair {
            while (self.original_index < self.items.len) {
                const item = self.items[self.original_index];
                const orig_idx = self.original_index;
                self.original_index += 1;

                if (self.predicate(item)) {
                    const pair = Pair{
                        .original_index = orig_idx,
                        .filtered_index = self.filtered_index,
                        .value = item,
                    };
                    self.filtered_index += 1;
                    return pair;
                }
            }
            return null;
        }
    };
}

/// Windowed enumerate - pairs of consecutive items with indices
pub fn EnumerateWindowed(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const WindowPair = struct {
            start_index: usize,
            first: T,
            second: T,
        };

        items: []const T,
        index: usize,

        pub fn init(items: []const T) Self {
            return Self{
                .items = items,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?WindowPair {
            if (self.index + 1 >= self.items.len) return null;

            const pair = WindowPair{
                .start_index = self.index,
                .first = self.items[self.index],
                .second = self.items[self.index + 1],
            };
            self.index += 1;
            return pair;
        }
    };
}
// ANCHOR_END: advanced_enumerate

test "enumerate basic" {
    const items = [_]i32{ 10, 20, 30, 40, 50 };
    var iter = EnumerateIterator(i32).init(&items);

    const pair1 = iter.next().?;
    try testing.expectEqual(@as(usize, 0), pair1.index);
    try testing.expectEqual(@as(i32, 10), pair1.value);

    const pair2 = iter.next().?;
    try testing.expectEqual(@as(usize, 1), pair2.index);
    try testing.expectEqual(@as(i32, 20), pair2.value);

    const pair3 = iter.next().?;
    try testing.expectEqual(@as(usize, 2), pair3.index);
    try testing.expectEqual(@as(i32, 30), pair3.value);
}

test "enumerate complete iteration" {
    const items = [_]i32{ 1, 2, 3 };
    var iter = EnumerateIterator(i32).init(&items);

    var count: usize = 0;
    while (iter.next()) |pair| {
        try testing.expectEqual(count, pair.index);
        try testing.expectEqual(items[count], pair.value);
        count += 1;
    }
    try testing.expectEqual(@as(usize, 3), count);
}

test "enumerate empty" {
    const items: []const i32 = &[_]i32{};
    var iter = EnumerateIterator(i32).init(items);

    try testing.expect(iter.next() == null);
}

test "enumerate reset" {
    const items = [_]i32{ 1, 2, 3 };
    var iter = EnumerateIterator(i32).init(&items);

    _ = iter.next();
    _ = iter.next();

    iter.reset();

    const pair = iter.next().?;
    try testing.expectEqual(@as(usize, 0), pair.index);
    try testing.expectEqual(@as(i32, 1), pair.value);
}

test "enumerate from custom start" {
    const items = [_]i32{ 10, 20, 30 };
    var iter = EnumerateFrom(i32).init(&items, 100);

    const pair1 = iter.next().?;
    try testing.expectEqual(@as(usize, 100), pair1.index);
    try testing.expectEqual(@as(i32, 10), pair1.value);

    const pair2 = iter.next().?;
    try testing.expectEqual(@as(usize, 101), pair2.index);
    try testing.expectEqual(@as(i32, 20), pair2.value);

    const pair3 = iter.next().?;
    try testing.expectEqual(@as(usize, 102), pair3.index);
    try testing.expectEqual(@as(i32, 30), pair3.value);
}

test "enumerate with step" {
    const items = [_]i32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    var iter = EnumerateStep(i32).init(&items, 2);

    const pair1 = iter.next().?;
    try testing.expectEqual(@as(usize, 0), pair1.index);
    try testing.expectEqual(@as(i32, 0), pair1.value);

    const pair2 = iter.next().?;
    try testing.expectEqual(@as(usize, 1), pair2.index);
    try testing.expectEqual(@as(i32, 2), pair2.value);

    const pair3 = iter.next().?;
    try testing.expectEqual(@as(usize, 2), pair3.index);
    try testing.expectEqual(@as(i32, 4), pair3.value);
}

test "enumerate reverse" {
    const items = [_]i32{ 10, 20, 30, 40, 50 };
    var iter = EnumerateReverse(i32).init(&items);

    const pair1 = iter.next().?;
    try testing.expectEqual(@as(usize, 4), pair1.index);
    try testing.expectEqual(@as(i32, 50), pair1.value);

    const pair2 = iter.next().?;
    try testing.expectEqual(@as(usize, 3), pair2.index);
    try testing.expectEqual(@as(i32, 40), pair2.value);
}

test "enumerate with filter" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    const isEven = struct {
        fn f(x: i32) bool {
            return @rem(x, 2) == 0;
        }
    }.f;

    var iter = EnumerateFilter(i32).init(&items, isEven);

    const pair1 = iter.next().?;
    try testing.expectEqual(@as(usize, 1), pair1.original_index);
    try testing.expectEqual(@as(usize, 0), pair1.filtered_index);
    try testing.expectEqual(@as(i32, 2), pair1.value);

    const pair2 = iter.next().?;
    try testing.expectEqual(@as(usize, 3), pair2.original_index);
    try testing.expectEqual(@as(usize, 1), pair2.filtered_index);
    try testing.expectEqual(@as(i32, 4), pair2.value);
}

test "enumerate windowed" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = EnumerateWindowed(i32).init(&items);

    const window1 = iter.next().?;
    try testing.expectEqual(@as(usize, 0), window1.start_index);
    try testing.expectEqual(@as(i32, 1), window1.first);
    try testing.expectEqual(@as(i32, 2), window1.second);

    const window2 = iter.next().?;
    try testing.expectEqual(@as(usize, 1), window2.start_index);
    try testing.expectEqual(@as(i32, 2), window2.first);
    try testing.expectEqual(@as(i32, 3), window2.second);
}

test "zig builtin indexed for loop" {
    // Demonstrate Zig's built-in indexed iteration
    const items = [_]i32{ 10, 20, 30 };

    var collected_indices: [3]usize = undefined;
    var collected_values: [3]i32 = undefined;

    for (items, 0..) |value, index| {
        collected_indices[index] = index;
        collected_values[index] = value;
    }

    try testing.expectEqual(@as(usize, 0), collected_indices[0]);
    try testing.expectEqual(@as(i32, 10), collected_values[0]);
    try testing.expectEqual(@as(usize, 2), collected_indices[2]);
    try testing.expectEqual(@as(i32, 30), collected_values[2]);
}

test "comparing builtin vs iterator" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };

    // Built-in way
    var sum1: i32 = 0;
    for (items, 0..) |value, index| {
        sum1 += value * @as(i32, @intCast(index));
    }

    // Iterator way
    var sum2: i32 = 0;
    var iter = EnumerateIterator(i32).init(&items);
    while (iter.next()) |pair| {
        sum2 += pair.value * @as(i32, @intCast(pair.index));
    }

    try testing.expectEqual(sum1, sum2);
}

test "memory safety - enumerate bounds" {
    const items = [_]i32{ 1, 2, 3 };
    var iter = EnumerateIterator(i32).init(&items);

    // Exhaust iterator
    while (iter.next()) |_| {}

    // Should safely return null
    try testing.expect(iter.next() == null);
}

test "security - enumerate step edge cases" {
    // Step of 0 should be treated as 1
    const items = [_]i32{ 1, 2, 3 };
    var iter = EnumerateStep(i32).init(&items, 0);

    const pair1 = iter.next().?;
    try testing.expectEqual(@as(i32, 1), pair1.value);

    const pair2 = iter.next().?;
    try testing.expectEqual(@as(i32, 2), pair2.value);
}

test "security - reverse enumerate empty" {
    const items: []const i32 = &[_]i32{};
    var iter = EnumerateReverse(i32).init(items);

    try testing.expect(iter.next() == null);
}

test "security - windowed enumerate single item" {
    const items = [_]i32{42};
    var iter = EnumerateWindowed(i32).init(&items);

    try testing.expect(iter.next() == null);
}

test "enumerate filter preserves both indices" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6 };

    const isOdd = struct {
        fn f(x: i32) bool {
            return @rem(x, 2) != 0;
        }
    }.f;

    var iter = EnumerateFilter(i32).init(&items, isOdd);

    const expected_original: [3]usize = .{ 0, 2, 4 };
    const expected_filtered: [3]usize = .{ 0, 1, 2 };
    const expected_values: [3]i32 = .{ 1, 3, 5 };

    var i: usize = 0;
    while (iter.next()) |pair| : (i += 1) {
        try testing.expectEqual(expected_original[i], pair.original_index);
        try testing.expectEqual(expected_filtered[i], pair.filtered_index);
        try testing.expectEqual(expected_values[i], pair.value);
    }

    try testing.expectEqual(@as(usize, 3), i);
}
