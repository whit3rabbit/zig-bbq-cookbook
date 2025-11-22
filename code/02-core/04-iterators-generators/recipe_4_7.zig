// Recipe 4.7: Taking a slice of an iterator
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to take a limited number of items from an
// iterator, similar to slicing operations but for lazy iterators.

const std = @import("std");
const testing = std.testing;

// ANCHOR: take_iterators
/// Take iterator that limits the number of items
pub fn TakeIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        index: usize,
        remaining: usize,

        pub fn init(items: []const T, count: usize) Self {
            return Self{
                .items = items,
                .index = 0,
                .remaining = @min(count, items.len),
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.remaining == 0 or self.index >= self.items.len) {
                return null;
            }

            const item = self.items[self.index];
            self.index += 1;
            self.remaining -= 1;
            return item;
        }

        pub fn getRemaining(self: *const Self) usize {
            return self.remaining;
        }
    };
}

/// Generic take wrapper for any iterator
pub fn Take(comptime IteratorType: type) type {
    return struct {
        const Self = @This();

        iterator: IteratorType,
        remaining: usize,

        pub fn init(iterator: IteratorType, count: usize) Self {
            return Self{
                .iterator = iterator,
                .remaining = count,
            };
        }

        pub fn next(self: *Self) ?@TypeOf(self.iterator.next()) {
            if (self.remaining == 0) return null;

            const item = self.iterator.next();
            if (item != null) {
                self.remaining -= 1;
            }
            return item;
        }
    };
}

/// Take while predicate is true
pub fn TakeWhile(comptime T: type) type {
    return struct {
        const Self = @This();
        const PredicateFn = *const fn (T) bool;

        items: []const T,
        index: usize,
        predicate: PredicateFn,
        stopped: bool,

        pub fn init(items: []const T, predicate: PredicateFn) Self {
            return Self{
                .items = items,
                .index = 0,
                .predicate = predicate,
                .stopped = false,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.stopped or self.index >= self.items.len) {
                return null;
            }

            const item = self.items[self.index];
            self.index += 1;

            if (!self.predicate(item)) {
                self.stopped = true;
                return null;
            }

            return item;
        }
    };
}

/// Slice iterator - skip and take
pub fn SliceIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        index: usize,
        start: usize,
        end: usize,

        pub fn init(items: []const T, start: usize, end: ?usize) Self {
            const actual_end = if (end) |e| @min(e, items.len) else items.len;
            const actual_start = @min(start, items.len);

            return Self{
                .items = items,
                .index = actual_start,
                .start = actual_start,
                .end = actual_end,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.index >= self.end) return null;

            const item = self.items[self.index];
            self.index += 1;
            return item;
        }

        pub fn remaining(self: *const Self) usize {
            if (self.index >= self.end) return 0;
            return self.end - self.index;
        }

        pub fn reset(self: *Self) void {
            self.index = self.start;
        }
    };
}
// ANCHOR_END: take_iterators

// ANCHOR: chunking_iterators
/// Chunking iterator - take items in fixed-size chunks
pub fn ChunkIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        index: usize,
        chunk_size: usize,

        pub fn init(items: []const T, chunk_size: usize) Self {
            return Self{
                .items = items,
                .index = 0,
                .chunk_size = chunk_size,
            };
        }

        pub fn next(self: *Self) ?[]const T {
            if (self.index >= self.items.len) return null;

            const remaining = self.items.len - self.index;
            const actual_size = @min(self.chunk_size, remaining);

            const chunk = self.items[self.index .. self.index + actual_size];
            self.index += actual_size;
            return chunk;
        }

        pub fn chunksRemaining(self: *const Self) usize {
            if (self.index >= self.items.len) return 0;
            const remaining = self.items.len - self.index;
            return (remaining + self.chunk_size - 1) / self.chunk_size;
        }
    };
}

/// Take with step (every nth item)
pub fn TakeEveryN(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        index: usize,
        step: usize,
        count: usize,
        max_count: ?usize,

        pub fn init(items: []const T, step: usize, max_count: ?usize) Self {
            return Self{
                .items = items,
                .index = 0,
                .step = step,
                .count = 0,
                .max_count = max_count,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.max_count) |max| {
                if (self.count >= max) return null;
            }

            if (self.index >= self.items.len) return null;

            const item = self.items[self.index];
            self.index += self.step;
            self.count += 1;
            return item;
        }

        pub fn getCount(self: *const Self) usize {
            return self.count;
        }
    };
}

/// Limit iterator that stops after N items regardless of source
pub fn Limit(comptime IteratorType: type) type {
    return struct {
        const Self = @This();

        iterator: IteratorType,
        max_items: usize,
        count: usize,

        pub fn init(iterator: IteratorType, max_items: usize) Self {
            return Self{
                .iterator = iterator,
                .max_items = max_items,
                .count = 0,
            };
        }

        pub fn next(self: *Self) ?@TypeOf(self.iterator.next()) {
            if (self.count >= self.max_items) return null;

            if (self.iterator.next()) |item| {
                self.count += 1;
                return item;
            }

            return null;
        }

        pub fn getCount(self: *const Self) usize {
            return self.count;
        }
    };
}
// ANCHOR_END: chunking_iterators

test "take iterator basic" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    var iter = TakeIterator(i32).init(&items, 5);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, 5), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "take more than available" {
    const items = [_]i32{ 1, 2, 3 };

    var iter = TakeIterator(i32).init(&items, 10);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "take zero items" {
    const items = [_]i32{ 1, 2, 3 };

    var iter = TakeIterator(i32).init(&items, 0);

    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "take while predicate" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    const lessThan5 = struct {
        fn f(x: i32) bool {
            return x < 5;
        }
    }.f;

    var iter = TakeWhile(i32).init(&items, lessThan5);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "take while stops on first false" {
    const items = [_]i32{ 2, 4, 6, 5, 8, 10 };

    const isEven = struct {
        fn f(x: i32) bool {
            return @rem(x, 2) == 0;
        }
    }.f;

    var iter = TakeWhile(i32).init(&items, isEven);

    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, 6), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "slice iterator range" {
    const items = [_]i32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };

    var iter = SliceIterator(i32).init(&items, 3, 7);

    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, 5), iter.next());
    try testing.expectEqual(@as(?i32, 6), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "slice iterator from start" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };

    var iter = SliceIterator(i32).init(&items, 0, 3);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "slice iterator to end" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };

    var iter = SliceIterator(i32).init(&items, 3, null);

    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, 5), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "slice iterator reset" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };

    var iter = SliceIterator(i32).init(&items, 1, 4);

    _ = iter.next();
    _ = iter.next();

    iter.reset();

    try testing.expectEqual(@as(?i32, 2), iter.next());
}

test "chunk iterator" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };

    var iter = ChunkIterator(i32).init(&items, 3);

    const chunk1 = iter.next().?;
    try testing.expectEqual(@as(usize, 3), chunk1.len);
    try testing.expectEqual(@as(i32, 1), chunk1[0]);
    try testing.expectEqual(@as(i32, 3), chunk1[2]);

    const chunk2 = iter.next().?;
    try testing.expectEqual(@as(usize, 3), chunk2.len);
    try testing.expectEqual(@as(i32, 4), chunk2[0]);

    const chunk3 = iter.next().?;
    try testing.expectEqual(@as(usize, 3), chunk3.len);

    try testing.expectEqual(@as(?[]const i32, null), iter.next());
}

test "chunk iterator uneven" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7 };

    var iter = ChunkIterator(i32).init(&items, 3);

    _ = iter.next();
    _ = iter.next();

    const last_chunk = iter.next().?;
    try testing.expectEqual(@as(usize, 1), last_chunk.len);
    try testing.expectEqual(@as(i32, 7), last_chunk[0]);
}

test "take every nth" {
    const items = [_]i32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };

    var iter = TakeEveryN(i32).init(&items, 2, null);

    try testing.expectEqual(@as(?i32, 0), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, 6), iter.next());
    try testing.expectEqual(@as(?i32, 8), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "take every nth limited" {
    const items = [_]i32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };

    var iter = TakeEveryN(i32).init(&items, 3, 3);

    try testing.expectEqual(@as(?i32, 0), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, 6), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());

    try testing.expectEqual(@as(usize, 3), iter.getCount());
}

test "combining slice and take" {
    const items = [_]i32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };

    // Take items from index 2 to 8
    var slice_iter = SliceIterator(i32).init(&items, 2, 8);

    // Then only take 3 of those
    var collected: [3]i32 = undefined;
    var i: usize = 0;
    while (i < 3) : (i += 1) {
        if (slice_iter.next()) |item| {
            collected[i] = item;
        }
    }

    try testing.expectEqual(@as(i32, 2), collected[0]);
    try testing.expectEqual(@as(i32, 3), collected[1]);
    try testing.expectEqual(@as(i32, 4), collected[2]);
}

test "memory safety - bounds checking" {
    const items = [_]i32{ 1, 2, 3 };

    var iter = TakeIterator(i32).init(&items, 100);

    var count: usize = 0;
    while (iter.next()) |_| {
        count += 1;
    }

    try testing.expectEqual(@as(usize, 3), count);
}

test "security - slice iterator out of bounds" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };

    // Start beyond array length
    var iter1 = SliceIterator(i32).init(&items, 100, 200);
    try testing.expectEqual(@as(?i32, null), iter1.next());

    // End beyond array length (should be clamped)
    var iter2 = SliceIterator(i32).init(&items, 2, 100);
    var count: usize = 0;
    while (iter2.next()) |_| {
        count += 1;
    }
    try testing.expectEqual(@as(usize, 3), count);
}

test "security - chunk iterator edge cases" {
    // Empty array
    const empty: []const i32 = &[_]i32{};
    var iter1 = ChunkIterator(i32).init(empty, 3);
    try testing.expectEqual(@as(?[]const i32, null), iter1.next());

    // Single item
    const single = [_]i32{42};
    var iter2 = ChunkIterator(i32).init(&single, 5);
    const chunk = iter2.next().?;
    try testing.expectEqual(@as(usize, 1), chunk.len);
    try testing.expectEqual(@as(i32, 42), chunk[0]);
}
