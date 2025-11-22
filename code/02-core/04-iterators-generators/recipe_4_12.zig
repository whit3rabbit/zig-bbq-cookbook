// Recipe 4.12: Iterating on items in separate containers (Chain iterators)
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to chain multiple sequences together to iterate
// over them as a single continuous sequence.

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_chain
/// Chain two sequences together
pub fn Chain2(comptime T: type) type {
    return struct {
        const Self = @This();

        first: []const T,
        second: []const T,
        index: usize,

        pub fn init(first: []const T, second: []const T) Self {
            return Self{
                .first = first,
                .second = second,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.index < self.first.len) {
                const item = self.first[self.index];
                self.index += 1;
                return item;
            }

            const second_index = self.index - self.first.len;
            if (second_index < self.second.len) {
                const item = self.second[second_index];
                self.index += 1;
                return item;
            }

            return null;
        }

        pub fn remaining(self: *const Self) usize {
            const total = self.first.len + self.second.len;
            if (self.index >= total) return 0;
            return total - self.index;
        }

        pub fn reset(self: *Self) void {
            self.index = 0;
        }
    };
}

/// Chain three sequences together
pub fn Chain3(comptime T: type) type {
    return struct {
        const Self = @This();

        first: []const T,
        second: []const T,
        third: []const T,
        index: usize,

        pub fn init(first: []const T, second: []const T, third: []const T) Self {
            return Self{
                .first = first,
                .second = second,
                .third = third,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.index < self.first.len) {
                const item = self.first[self.index];
                self.index += 1;
                return item;
            }

            const second_start = self.first.len;
            if (self.index < second_start + self.second.len) {
                const item = self.second[self.index - second_start];
                self.index += 1;
                return item;
            }

            const third_start = second_start + self.second.len;
            if (self.index < third_start + self.third.len) {
                const item = self.third[self.index - third_start];
                self.index += 1;
                return item;
            }

            return null;
        }
    };
}

/// Chain multiple sequences using ArrayList
pub fn ChainMany(comptime T: type) type {
    return struct {
        const Self = @This();

        sequences: []const []const T,
        sequence_index: usize,
        item_index: usize,

        pub fn init(sequences: []const []const T) Self {
            return Self{
                .sequences = sequences,
                .sequence_index = 0,
                .item_index = 0,
            };
        }

        pub fn next(self: *Self) ?T {
            while (self.sequence_index < self.sequences.len) {
                const current_seq = self.sequences[self.sequence_index];

                if (self.item_index < current_seq.len) {
                    const item = current_seq[self.item_index];
                    self.item_index += 1;
                    return item;
                }

                // Move to next sequence
                self.sequence_index += 1;
                self.item_index = 0;
            }

            return null;
        }

        pub fn reset(self: *Self) void {
            self.sequence_index = 0;
            self.item_index = 0;
        }
    };
}

/// Flatten nested sequences
pub fn Flatten(comptime T: type) type {
    return struct {
        const Self = @This();

        sequences: []const []const T,
        outer_index: usize,
        inner_index: usize,

        pub fn init(sequences: []const []const T) Self {
            return Self{
                .sequences = sequences,
                .outer_index = 0,
                .inner_index = 0,
            };
        }

        pub fn next(self: *Self) ?T {
            while (self.outer_index < self.sequences.len) {
                const current = self.sequences[self.outer_index];

                if (self.inner_index < current.len) {
                    const item = current[self.inner_index];
                    self.inner_index += 1;
                    return item;
                }

                self.outer_index += 1;
                self.inner_index = 0;
            }

            return null;
        }
    };
}
// ANCHOR_END: basic_chain

// ANCHOR: interleave_chain
/// Chain with interleaving (alternate between sequences)
pub fn Interleave(comptime T: type) type {
    return struct {
        const Self = @This();

        first: []const T,
        second: []const T,
        index: usize,
        take_from_first: bool,

        pub fn init(first: []const T, second: []const T) Self {
            return Self{
                .first = first,
                .second = second,
                .index = 0,
                .take_from_first = true,
            };
        }

        pub fn next(self: *Self) ?T {
            while (self.index < self.first.len or self.index < self.second.len) {
                if (self.take_from_first) {
                    self.take_from_first = false;
                    if (self.index < self.first.len) {
                        return self.first[self.index];
                    }
                } else {
                    self.take_from_first = true;
                    const item = if (self.index < self.second.len)
                        self.second[self.index]
                    else
                        null;
                    self.index += 1;
                    if (item != null) return item;
                    // If second is exhausted, continue to first
                    if (self.index < self.first.len) {
                        return self.first[self.index];
                    }
                }
            }

            return null;
        }
    };
}

/// Round-robin iterator across multiple sequences
pub fn RoundRobin(comptime T: type) type {
    return struct {
        const Self = @This();

        sequences: []const []const T,
        sequence_index: usize,
        position: usize,
        active_count: usize,

        pub fn init(sequences: []const []const T) Self {
            var active: usize = 0;
            for (sequences) |seq| {
                if (seq.len > 0) active += 1;
            }

            return Self{
                .sequences = sequences,
                .sequence_index = 0,
                .position = 0,
                .active_count = active,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.active_count == 0) return null;

            var attempts: usize = 0;
            while (attempts < self.sequences.len) : (attempts += 1) {
                const seq = self.sequences[self.sequence_index];

                if (self.position < seq.len) {
                    const item = seq[self.position];
                    self.sequence_index = (self.sequence_index + 1) % self.sequences.len;

                    // Check if we completed a round
                    if (self.sequence_index == 0) {
                        self.position += 1;
                    }

                    return item;
                }

                // This sequence is exhausted
                self.sequence_index = (self.sequence_index + 1) % self.sequences.len;
            }

            return null;
        }
    };
}
// ANCHOR_END: interleave_chain

// ANCHOR: cycle_iterator
/// Cycle iterator - repeat sequence indefinitely
pub fn Cycle(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        index: usize,
        cycles_completed: usize,
        max_cycles: ?usize,

        pub fn init(items: []const T, max_cycles: ?usize) Self {
            return Self{
                .items = items,
                .index = 0,
                .cycles_completed = 0,
                .max_cycles = max_cycles,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.items.len == 0) return null;

            if (self.max_cycles) |max| {
                if (self.cycles_completed >= max) return null;
            }

            const item = self.items[self.index];
            self.index += 1;

            if (self.index >= self.items.len) {
                self.index = 0;
                self.cycles_completed += 1;
            }

            return item;
        }

        pub fn getCyclesCompleted(self: *const Self) usize {
            return self.cycles_completed;
        }
    };
}
// ANCHOR_END: cycle_iterator

test "chain2 basic" {
    const first = [_]i32{ 1, 2, 3 };
    const second = [_]i32{ 4, 5, 6 };

    var iter = Chain2(i32).init(&first, &second);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, 5), iter.next());
    try testing.expectEqual(@as(?i32, 6), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "chain2 with empty sequences" {
    const empty: []const i32 = &[_]i32{};
    const items = [_]i32{ 1, 2, 3 };

    var iter1 = Chain2(i32).init(empty, &items);
    try testing.expectEqual(@as(?i32, 1), iter1.next());

    var iter2 = Chain2(i32).init(&items, empty);
    try testing.expectEqual(@as(?i32, 1), iter2.next());
    try testing.expectEqual(@as(?i32, 2), iter2.next());
    try testing.expectEqual(@as(?i32, 3), iter2.next());
    try testing.expectEqual(@as(?i32, null), iter2.next());
}

test "chain2 remaining" {
    const first = [_]i32{ 1, 2 };
    const second = [_]i32{ 3, 4, 5 };

    var iter = Chain2(i32).init(&first, &second);

    try testing.expectEqual(@as(usize, 5), iter.remaining());
    _ = iter.next();
    try testing.expectEqual(@as(usize, 4), iter.remaining());
    _ = iter.next();
    _ = iter.next();
    try testing.expectEqual(@as(usize, 2), iter.remaining());
}

test "chain3 basic" {
    const first = [_]i32{ 1, 2 };
    const second = [_]i32{ 3, 4 };
    const third = [_]i32{ 5, 6 };

    var iter = Chain3(i32).init(&first, &second, &third);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, 5), iter.next());
    try testing.expectEqual(@as(?i32, 6), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "chain many sequences" {
    const seq1 = [_]i32{ 1, 2 };
    const seq2 = [_]i32{ 3, 4 };
    const seq3 = [_]i32{ 5, 6 };
    const seq4 = [_]i32{ 7, 8 };

    const sequences = [_][]const i32{ &seq1, &seq2, &seq3, &seq4 };

    var iter = ChainMany(i32).init(&sequences);

    var expected: i32 = 1;
    while (iter.next()) |item| : (expected += 1) {
        try testing.expectEqual(expected, item);
    }
    try testing.expectEqual(@as(i32, 9), expected);
}

test "chain many with empty sequences" {
    const seq1 = [_]i32{ 1, 2 };
    const empty: []const i32 = &[_]i32{};
    const seq2 = [_]i32{ 3, 4 };

    const sequences = [_][]const i32{ &seq1, empty, &seq2 };

    var iter = ChainMany(i32).init(&sequences);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "flatten nested sequences" {
    const seq1 = [_]i32{ 1, 2, 3 };
    const seq2 = [_]i32{ 4, 5 };
    const seq3 = [_]i32{ 6, 7, 8, 9 };

    const nested = [_][]const i32{ &seq1, &seq2, &seq3 };

    var iter = Flatten(i32).init(&nested);

    var count: usize = 0;
    var expected: i32 = 1;
    while (iter.next()) |item| {
        try testing.expectEqual(expected, item);
        expected += 1;
        count += 1;
    }
    try testing.expectEqual(@as(usize, 9), count);
}

test "interleave sequences" {
    const first = [_]i32{ 1, 2, 3, 4 };
    const second = [_]i32{ 10, 20, 30, 40 };

    var iter = Interleave(i32).init(&first, &second);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 10), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 20), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, 30), iter.next());
}

test "interleave different lengths" {
    const short = [_]i32{ 1, 2 };
    const long = [_]i32{ 10, 20, 30, 40 };

    var iter = Interleave(i32).init(&short, &long);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 10), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 20), iter.next());
    try testing.expectEqual(@as(?i32, 30), iter.next());
    try testing.expectEqual(@as(?i32, 40), iter.next());
}

test "round robin" {
    const seq1 = [_]i32{ 1, 2, 3 };
    const seq2 = [_]i32{ 10, 20, 30 };
    const seq3 = [_]i32{ 100, 200, 300 };

    const sequences = [_][]const i32{ &seq1, &seq2, &seq3 };

    var iter = RoundRobin(i32).init(&sequences);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 10), iter.next());
    try testing.expectEqual(@as(?i32, 100), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 20), iter.next());
    try testing.expectEqual(@as(?i32, 200), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, 30), iter.next());
    try testing.expectEqual(@as(?i32, 300), iter.next());
}

test "cycle with limit" {
    const items = [_]i32{ 1, 2, 3 };

    var iter = Cycle(i32).init(&items, 2);

    // First cycle
    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());

    // Second cycle
    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());

    // Should stop after 2 cycles
    try testing.expectEqual(@as(?i32, null), iter.next());
    try testing.expectEqual(@as(usize, 2), iter.getCyclesCompleted());
}

test "cycle unlimited" {
    const items = [_]i32{ 1, 2, 3 };

    var iter = Cycle(i32).init(&items, null);

    var count: usize = 0;
    while (count < 10) : (count += 1) {
        _ = iter.next();
    }

    try testing.expectEqual(@as(usize, 3), iter.getCyclesCompleted());
}

test "chain reset" {
    const first = [_]i32{ 1, 2 };
    const second = [_]i32{ 3, 4 };

    var iter = Chain2(i32).init(&first, &second);

    _ = iter.next();
    _ = iter.next();

    iter.reset();

    try testing.expectEqual(@as(?i32, 1), iter.next());
}

test "memory safety - chain bounds" {
    const a = [_]i32{ 1, 2, 3 };
    const b = [_]i32{ 4, 5, 6 };

    var iter = Chain2(i32).init(&a, &b);

    var count: usize = 0;
    while (iter.next()) |_| {
        count += 1;
    }

    try testing.expectEqual(@as(usize, 6), count);
    try testing.expect(iter.next() == null);
}

test "security - flatten empty nested" {
    const empty: []const []const i32 = &[_][]const i32{};

    var iter = Flatten(i32).init(empty);

    try testing.expect(iter.next() == null);
}

test "security - cycle empty sequence" {
    const empty: []const i32 = &[_]i32{};

    var iter = Cycle(i32).init(empty, 5);

    try testing.expect(iter.next() == null);
}
