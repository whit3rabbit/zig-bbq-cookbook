// Recipe 4.2: Delegating iteration
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to delegate iteration to inner iterators,
// creating composite iterators and wrapping existing iterators.

const std = @import("std");
const testing = std.testing;

// ANCHOR: wrapper_iterators
/// Iterator wrapper that adds counting functionality
pub fn CountingIterator(comptime Iterator: type, comptime Item: type) type {
    return struct {
        const Self = @This();

        inner: Iterator,
        count: usize,

        pub fn init(inner: Iterator) Self {
            return Self{
                .inner = inner,
                .count = 0,
            };
        }

        pub fn next(self: *Self) Item {
            const item = self.inner.next();
            if (item != null) {
                self.count += 1;
            }
            return item;
        }

        pub fn getCount(self: *const Self) usize {
            return self.count;
        }
    };
}

/// Iterator that takes items while a predicate is true
pub fn TakeWhileIterator(comptime T: type) type {
    return struct {
        const Self = @This();
        const PredicateFn = *const fn (T) bool;

        items: []const T,
        index: usize,
        predicate: PredicateFn,
        done: bool,

        pub fn init(items: []const T, predicate: PredicateFn) Self {
            return Self{
                .items = items,
                .index = 0,
                .predicate = predicate,
                .done = false,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.done) return null;
            if (self.index >= self.items.len) return null;

            const item = self.items[self.index];
            if (!self.predicate(item)) {
                self.done = true;
                return null;
            }

            self.index += 1;
            return item;
        }
    };
}

/// Iterator that chains two iterators together
pub fn ChainIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        first: []const T,
        second: []const T,
        first_index: usize,
        second_index: usize,

        pub fn init(first: []const T, second: []const T) Self {
            return Self{
                .first = first,
                .second = second,
                .first_index = 0,
                .second_index = 0,
            };
        }

        pub fn next(self: *Self) ?T {
            // Delegate to first iterator
            if (self.first_index < self.first.len) {
                const item = self.first[self.first_index];
                self.first_index += 1;
                return item;
            }

            // Then delegate to second iterator
            if (self.second_index < self.second.len) {
                const item = self.second[self.second_index];
                self.second_index += 1;
                return item;
            }

            return null;
        }
    };
}
// ANCHOR_END: wrapper_iterators

// ANCHOR: advanced_delegation
/// Iterator that flattens nested slices
pub fn FlattenIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        outer: []const []const T,
        outer_index: usize,
        inner_index: usize,

        pub fn init(items: []const []const T) Self {
            return Self{
                .outer = items,
                .outer_index = 0,
                .inner_index = 0,
            };
        }

        pub fn next(self: *Self) ?T {
            while (self.outer_index < self.outer.len) {
                const inner = self.outer[self.outer_index];

                if (self.inner_index < inner.len) {
                    const item = inner[self.inner_index];
                    self.inner_index += 1;
                    return item;
                }

                // Move to next outer item
                self.outer_index += 1;
                self.inner_index = 0;
            }

            return null;
        }
    };
}

/// Iterator that enumerates items with their index
pub fn EnumerateIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const Item = struct {
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

        pub fn next(self: *Self) ?Item {
            if (self.index >= self.items.len) return null;

            const item = Item{
                .index = self.index,
                .value = self.items[self.index],
            };
            self.index += 1;
            return item;
        }
    };
}

/// Iterator that yields items in chunks
pub fn ChunkIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        chunk_size: usize,
        index: usize,

        pub fn init(items: []const T, chunk_size: usize) Self {
            return Self{
                .items = items,
                .chunk_size = chunk_size,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?[]const T {
            if (self.index >= self.items.len) return null;

            const start = self.index;
            const end = @min(start + self.chunk_size, self.items.len);
            self.index = end;

            return self.items[start..end];
        }
    };
}
// ANCHOR_END: advanced_delegation

// ANCHOR: skip_take_iterators
/// Iterator that skips N items
pub fn SkipIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        index: usize,

        pub fn init(items: []const T, skip_count: usize) Self {
            return Self{
                .items = items,
                .index = @min(skip_count, items.len),
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.index >= self.items.len) return null;
            const item = self.items[self.index];
            self.index += 1;
            return item;
        }
    };
}

/// Iterator that takes at most N items
pub fn TakeIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        index: usize,
        remaining: usize,

        pub fn init(items: []const T, take_count: usize) Self {
            return Self{
                .items = items,
                .index = 0,
                .remaining = take_count,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.remaining == 0) return null;
            if (self.index >= self.items.len) return null;

            const item = self.items[self.index];
            self.index += 1;
            self.remaining -= 1;
            return item;
        }
    };
}
// ANCHOR_END: skip_take_iterators

test "counting iterator wrapper" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };

    const BaseIter = struct {
        items: []const i32,
        index: usize,

        pub fn next(self: *@This()) ?i32 {
            if (self.index >= self.items.len) return null;
            const item = self.items[self.index];
            self.index += 1;
            return item;
        }
    };

    const base_iter = BaseIter{ .items = &items, .index = 0 };
    var counting_iter = CountingIterator(BaseIter, ?i32).init(base_iter);

    try testing.expectEqual(@as(usize, 0), counting_iter.getCount());

    _ = counting_iter.next();
    try testing.expectEqual(@as(usize, 1), counting_iter.getCount());

    _ = counting_iter.next();
    _ = counting_iter.next();
    try testing.expectEqual(@as(usize, 3), counting_iter.getCount());

    // Exhaust iterator
    while (counting_iter.next()) |_| {}
    try testing.expectEqual(@as(usize, 5), counting_iter.getCount());
}

fn lessThan5(n: i32) bool {
    return n < 5;
}

test "take while iterator" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7 };
    var iter = TakeWhileIterator(i32).init(&items, lessThan5);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "chain iterator" {
    const first = [_]i32{ 1, 2, 3 };
    const second = [_]i32{ 4, 5, 6 };
    var iter = ChainIterator(i32).init(&first, &second);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, 5), iter.next());
    try testing.expectEqual(@as(?i32, 6), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "chain empty iterators" {
    const empty: []const i32 = &[_]i32{};
    const items = [_]i32{ 1, 2 };

    var iter1 = ChainIterator(i32).init(empty, &items);
    try testing.expectEqual(@as(?i32, 1), iter1.next());
    try testing.expectEqual(@as(?i32, 2), iter1.next());
    try testing.expectEqual(@as(?i32, null), iter1.next());

    var iter2 = ChainIterator(i32).init(&items, empty);
    try testing.expectEqual(@as(?i32, 1), iter2.next());
    try testing.expectEqual(@as(?i32, 2), iter2.next());
    try testing.expectEqual(@as(?i32, null), iter2.next());
}

test "flatten iterator" {
    const slice1 = [_]i32{ 1, 2 };
    const slice2 = [_]i32{ 3, 4, 5 };
    const slice3 = [_]i32{ 6 };

    const slices = [_][]const i32{ &slice1, &slice2, &slice3 };

    var iter = FlattenIterator(i32).init(&slices);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, 5), iter.next());
    try testing.expectEqual(@as(?i32, 6), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "flatten with empty slices" {
    const slice1 = [_]i32{ 1 };
    const slice2 = [_]i32{};
    const slice3 = [_]i32{ 2, 3 };

    const slices = [_][]const i32{ &slice1, &slice2, &slice3 };

    var iter = FlattenIterator(i32).init(&slices);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "enumerate iterator" {
    const items = [_][]const u8{ "foo", "bar", "baz" };
    var iter = EnumerateIterator([]const u8).init(&items);

    const item1 = iter.next();
    try testing.expect(item1 != null);
    try testing.expectEqual(@as(usize, 0), item1.?.index);
    try testing.expect(std.mem.eql(u8, "foo", item1.?.value));

    const item2 = iter.next();
    try testing.expect(item2 != null);
    try testing.expectEqual(@as(usize, 1), item2.?.index);
    try testing.expect(std.mem.eql(u8, "bar", item2.?.value));

    const item3 = iter.next();
    try testing.expect(item3 != null);
    try testing.expectEqual(@as(usize, 2), item3.?.index);
    try testing.expect(std.mem.eql(u8, "baz", item3.?.value));

    try testing.expect(iter.next() == null);
}

test "chunk iterator" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7 };
    var iter = ChunkIterator(i32).init(&items, 3);

    const chunk1 = iter.next();
    try testing.expect(chunk1 != null);
    try testing.expectEqual(@as(usize, 3), chunk1.?.len);
    try testing.expectEqual(@as(i32, 1), chunk1.?[0]);
    try testing.expectEqual(@as(i32, 3), chunk1.?[2]);

    const chunk2 = iter.next();
    try testing.expect(chunk2 != null);
    try testing.expectEqual(@as(usize, 3), chunk2.?.len);
    try testing.expectEqual(@as(i32, 4), chunk2.?[0]);

    const chunk3 = iter.next();
    try testing.expect(chunk3 != null);
    try testing.expectEqual(@as(usize, 1), chunk3.?.len);
    try testing.expectEqual(@as(i32, 7), chunk3.?[0]);

    try testing.expect(iter.next() == null);
}

test "skip iterator" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = SkipIterator(i32).init(&items, 2);

    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, 5), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "skip more than length" {
    const items = [_]i32{ 1, 2 };
    var iter = SkipIterator(i32).init(&items, 10);

    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "take iterator" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = TakeIterator(i32).init(&items, 3);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "take more than length" {
    const items = [_]i32{ 1, 2 };
    var iter = TakeIterator(i32).init(&items, 10);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "combining skip and take" {
    const items = [_]i32{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };

    // Skip first 3, then take 4
    var skip_iter = SkipIterator(i32).init(&items, 3);

    // Collect skipped items
    var skipped: [7]i32 = undefined;
    var i: usize = 0;
    while (skip_iter.next()) |item| {
        skipped[i] = item;
        i += 1;
    }

    // Now take first 4 from skipped
    var take_iter = TakeIterator(i32).init(skipped[0..i], 4);

    try testing.expectEqual(@as(?i32, 3), take_iter.next());
    try testing.expectEqual(@as(?i32, 4), take_iter.next());
    try testing.expectEqual(@as(?i32, 5), take_iter.next());
    try testing.expectEqual(@as(?i32, 6), take_iter.next());
    try testing.expectEqual(@as(?i32, null), take_iter.next());
}

test "memory safety - no allocation for delegation" {
    const items = [_]i32{ 1, 2, 3 };

    var chain = ChainIterator(i32).init(&items, &items);
    while (chain.next()) |_| {}

    var flatten = FlattenIterator(i32).init(&[_][]const i32{&items});
    while (flatten.next()) |_| {}

    var enumerate = EnumerateIterator(i32).init(&items);
    while (enumerate.next()) |_| {}
}

test "security - bounds checking in delegated iterators" {
    const items = [_]i32{ 1, 2, 3 };

    // Chain with bounds check
    var chain = ChainIterator(i32).init(&items, &items);
    chain.first_index = 100;
    try testing.expect(chain.next() != null); // Should safely access second

    // Skip with large value
    var skip = SkipIterator(i32).init(&items, 1000);
    try testing.expect(skip.next() == null); // Should safely return null
}
