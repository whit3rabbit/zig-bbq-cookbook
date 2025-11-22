// Recipe 4.8: Skipping the first part of an iterable
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to skip items at the beginning of an iterator,
// including skip N items, skip while predicate, and skip until patterns.

const std = @import("std");
const testing = std.testing;

// ANCHOR: skip_iterator
/// Skip the first N items
pub fn SkipIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        index: usize,
        skip_count: usize,
        skipped: bool,

        pub fn init(items: []const T, skip_count: usize) Self {
            return Self{
                .items = items,
                .index = 0,
                .skip_count = @min(skip_count, items.len),
                .skipped = false,
            };
        }

        pub fn next(self: *Self) ?T {
            if (!self.skipped) {
                self.index += self.skip_count;
                self.skipped = true;
            }

            if (self.index >= self.items.len) return null;

            const item = self.items[self.index];
            self.index += 1;
            return item;
        }
    };
}
// ANCHOR_END: skip_iterator

// ANCHOR: skip_while_until
/// Skip while predicate is true
pub fn SkipWhile(comptime T: type) type {
    return struct {
        const Self = @This();
        const PredicateFn = *const fn (T) bool;

        items: []const T,
        index: usize,
        predicate: PredicateFn,
        skipping_done: bool,

        pub fn init(items: []const T, predicate: PredicateFn) Self {
            return Self{
                .items = items,
                .index = 0,
                .predicate = predicate,
                .skipping_done = false,
            };
        }

        pub fn next(self: *Self) ?T {
            // If we haven't finished skipping, skip items
            if (!self.skipping_done) {
                while (self.index < self.items.len) {
                    const item = self.items[self.index];
                    if (!self.predicate(item)) {
                        self.skipping_done = true;
                        break;
                    }
                    self.index += 1;
                }
            }

            if (self.index >= self.items.len) return null;

            const item = self.items[self.index];
            self.index += 1;
            return item;
        }

        pub fn itemsSkipped(self: *const Self) usize {
            if (!self.skipping_done) return 0;
            // Before skipping_done is set, index points to first non-skipped item
            return self.index - 1;
        }
    };
}

/// Skip until predicate becomes true
pub fn SkipUntil(comptime T: type) type {
    return struct {
        const Self = @This();
        const PredicateFn = *const fn (T) bool;

        items: []const T,
        index: usize,
        predicate: PredicateFn,
        found: bool,

        pub fn init(items: []const T, predicate: PredicateFn) Self {
            return Self{
                .items = items,
                .index = 0,
                .predicate = predicate,
                .found = false,
            };
        }

        pub fn next(self: *Self) ?T {
            if (!self.found) {
                while (self.index < self.items.len) {
                    const item = self.items[self.index];
                    if (self.predicate(item)) {
                        self.found = true;
                        break;
                    }
                    self.index += 1;
                }
            }

            if (self.index >= self.items.len) return null;

            const item = self.items[self.index];
            self.index += 1;
            return item;
        }
    };
}
// ANCHOR_END: skip_while_until

// ANCHOR: advanced_skip_patterns
/// Drop first N items, similar to Skip but with different semantics
pub fn DropIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        start_index: usize,
        current_index: usize,

        pub fn init(items: []const T, drop_count: usize) Self {
            const actual_start = @min(drop_count, items.len);
            return Self{
                .items = items,
                .start_index = actual_start,
                .current_index = actual_start,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.current_index >= self.items.len) return null;

            const item = self.items[self.current_index];
            self.current_index += 1;
            return item;
        }

        pub fn reset(self: *Self) void {
            self.current_index = self.start_index;
        }

        pub fn remaining(self: *const Self) usize {
            if (self.current_index >= self.items.len) return 0;
            return self.items.len - self.current_index;
        }
    };
}

/// Skip every nth item (inverse of take every nth)
pub fn SkipEveryN(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        index: usize,
        step: usize,
        counter: usize,

        pub fn init(items: []const T, step: usize) Self {
            return Self{
                .items = items,
                .index = 0,
                .step = if (step == 0) 1 else step,
                .counter = 0,
            };
        }

        pub fn next(self: *Self) ?T {
            while (self.index < self.items.len) {
                const item = self.items[self.index];
                self.index += 1;
                self.counter += 1;

                // Skip every nth item (when counter is multiple of step)
                if (self.counter % self.step != 0) {
                    return item;
                }
            }
            return null;
        }
    };
}

/// Batched skip - skip in batches
pub fn BatchSkipIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        index: usize,
        take_count: usize,
        skip_count: usize,
        in_take_phase: bool,
        phase_counter: usize,

        pub fn init(
            items: []const T,
            take_count: usize,
            skip_count: usize,
        ) Self {
            return Self{
                .items = items,
                .index = 0,
                .take_count = take_count,
                .skip_count = skip_count,
                .in_take_phase = true,
                .phase_counter = 0,
            };
        }

        pub fn next(self: *Self) ?T {
            while (self.index < self.items.len) {
                if (self.in_take_phase) {
                    const item = self.items[self.index];
                    self.index += 1;
                    self.phase_counter += 1;

                    if (self.phase_counter >= self.take_count) {
                        self.in_take_phase = false;
                        self.phase_counter = 0;
                    }

                    return item;
                } else {
                    // Skip phase
                    self.index += 1;
                    self.phase_counter += 1;

                    if (self.phase_counter >= self.skip_count) {
                        self.in_take_phase = true;
                        self.phase_counter = 0;
                    }
                }
            }
            return null;
        }
    };
}
// ANCHOR_END: advanced_skip_patterns

test "skip iterator basic" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    var iter = SkipIterator(i32).init(&items, 5);

    try testing.expectEqual(@as(?i32, 6), iter.next());
    try testing.expectEqual(@as(?i32, 7), iter.next());
    try testing.expectEqual(@as(?i32, 8), iter.next());
    try testing.expectEqual(@as(?i32, 9), iter.next());
    try testing.expectEqual(@as(?i32, 10), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "skip all items" {
    const items = [_]i32{ 1, 2, 3 };

    var iter = SkipIterator(i32).init(&items, 10);

    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "skip zero items" {
    const items = [_]i32{ 1, 2, 3 };

    var iter = SkipIterator(i32).init(&items, 0);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());
}

test "skip while predicate" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    const lessThan5 = struct {
        fn f(x: i32) bool {
            return x < 5;
        }
    }.f;

    var iter = SkipWhile(i32).init(&items, lessThan5);

    try testing.expectEqual(@as(?i32, 5), iter.next());
    try testing.expectEqual(@as(?i32, 6), iter.next());
    try testing.expectEqual(@as(?i32, 7), iter.next());
}

test "skip while all items match" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };

    const alwaysTrue = struct {
        fn f(_: i32) bool {
            return true;
        }
    }.f;

    var iter = SkipWhile(i32).init(&items, alwaysTrue);

    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "skip while no items match" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };

    const alwaysFalse = struct {
        fn f(_: i32) bool {
            return false;
        }
    }.f;

    var iter = SkipWhile(i32).init(&items, alwaysFalse);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
}

test "skip until predicate" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    const greaterThan5 = struct {
        fn f(x: i32) bool {
            return x > 5;
        }
    }.f;

    var iter = SkipUntil(i32).init(&items, greaterThan5);

    try testing.expectEqual(@as(?i32, 6), iter.next());
    try testing.expectEqual(@as(?i32, 7), iter.next());
    try testing.expectEqual(@as(?i32, 8), iter.next());
}

test "skip until never matches" {
    const items = [_]i32{ 1, 2, 3 };

    const alwaysFalse = struct {
        fn f(_: i32) bool {
            return false;
        }
    }.f;

    var iter = SkipUntil(i32).init(&items, alwaysFalse);

    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "drop iterator" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    var iter = DropIterator(i32).init(&items, 3);

    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, 5), iter.next());

    try testing.expectEqual(@as(usize, 5), iter.remaining());
}

test "drop iterator reset" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };

    var iter = DropIterator(i32).init(&items, 2);

    _ = iter.next();
    _ = iter.next();

    iter.reset();

    try testing.expectEqual(@as(?i32, 3), iter.next());
}

test "skip every nth" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    var iter = SkipEveryN(i32).init(&items, 3);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    // 3 is skipped (3rd item)
    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, 5), iter.next());
    // 6 is skipped (6th item)
    try testing.expectEqual(@as(?i32, 7), iter.next());
    try testing.expectEqual(@as(?i32, 8), iter.next());
    // 9 is skipped (9th item)
    try testing.expectEqual(@as(?i32, 10), iter.next());
}

test "batch skip iterator" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };

    // Take 2, skip 2, take 2, skip 2, ...
    var iter = BatchSkipIterator(i32).init(&items, 2, 2);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    // 3, 4 are skipped
    try testing.expectEqual(@as(?i32, 5), iter.next());
    try testing.expectEqual(@as(?i32, 6), iter.next());
    // 7, 8 are skipped
    try testing.expectEqual(@as(?i32, 9), iter.next());
    try testing.expectEqual(@as(?i32, 10), iter.next());
    // 11, 12 are skipped
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "combining skip and take" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    // Skip first 3, then take 4
    var skip_iter = SkipIterator(i32).init(&items, 3);

    var collected: [4]i32 = undefined;
    var i: usize = 0;
    while (i < 4) : (i += 1) {
        if (skip_iter.next()) |item| {
            collected[i] = item;
        }
    }

    try testing.expectEqual(@as(i32, 4), collected[0]);
    try testing.expectEqual(@as(i32, 5), collected[1]);
    try testing.expectEqual(@as(i32, 6), collected[2]);
    try testing.expectEqual(@as(i32, 7), collected[3]);
}

test "skip while with mixed values" {
    const items = [_]i32{ 2, 4, 6, 3, 8, 10 };

    const isEven = struct {
        fn f(x: i32) bool {
            return @rem(x, 2) == 0;
        }
    }.f;

    var iter = SkipWhile(i32).init(&items, isEven);

    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, 8), iter.next());
    try testing.expectEqual(@as(?i32, 10), iter.next());
}

test "memory safety - skip beyond length" {
    const items = [_]i32{ 1, 2, 3 };

    var iter = SkipIterator(i32).init(&items, 100);

    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "security - drop iterator bounds" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };

    var iter = DropIterator(i32).init(&items, 1000);

    try testing.expectEqual(@as(?i32, null), iter.next());
    try testing.expectEqual(@as(usize, 0), iter.remaining());
}

test "security - skip every nth edge cases" {
    // Empty array
    const empty: []const i32 = &[_]i32{};
    var iter1 = SkipEveryN(i32).init(empty, 2);
    try testing.expectEqual(@as(?i32, null), iter1.next());

    // Step of 0 (should be treated as 1)
    const items = [_]i32{ 1, 2, 3 };
    var iter2 = SkipEveryN(i32).init(&items, 0);
    try testing.expectEqual(@as(?i32, null), iter2.next());
}

test "security - batch skip edge cases" {
    const items = [_]i32{ 1, 2, 3 };

    // Take more than available
    var iter = BatchSkipIterator(i32).init(&items, 10, 1);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}
