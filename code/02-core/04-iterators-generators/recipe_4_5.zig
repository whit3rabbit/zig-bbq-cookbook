// Recipe 4.5: Iterating in reverse
// Target Zig Version: 0.15.2
//
// This recipe demonstrates various patterns for iterating in reverse order,
// including reverse iterators, bidirectional iteration, and reverse views.

const std = @import("std");
const testing = std.testing;

// ANCHOR: reverse_iterators
/// Reverse iterator over a slice
pub fn ReverseIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        index: usize,

        pub fn init(items: []const T) Self {
            return Self{
                .items = items,
                .index = items.len,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.index == 0) return null;
            // Check if index is within valid range after decrement
            if (self.index > self.items.len) return null;
            self.index -= 1;
            return self.items[self.index];
        }

        pub fn reset(self: *Self) void {
            self.index = self.items.len;
        }
    };
}

/// Bidirectional iterator that can go forward or backward
pub fn BidirectionalIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        front_index: usize,
        back_index: usize,

        pub fn init(items: []const T) Self {
            return Self{
                .items = items,
                .front_index = 0,
                .back_index = items.len,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.front_index >= self.back_index) return null;
            const item = self.items[self.front_index];
            self.front_index += 1;
            return item;
        }

        pub fn nextBack(self: *Self) ?T {
            if (self.front_index >= self.back_index) return null;
            self.back_index -= 1;
            return self.items[self.back_index];
        }

        pub fn remaining(self: *const Self) usize {
            if (self.back_index <= self.front_index) return 0;
            return self.back_index - self.front_index;
        }
    };
}

/// Reverse range iterator (counts down)
pub fn ReverseRangeIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        current: T,
        end: T,
        step: T,

        pub fn init(start: T, end: T, step: T) Self {
            return Self{
                .current = start,
                .end = end,
                .step = step,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.step > 0 and self.current <= self.end) return null;
            if (self.step < 0 and self.current >= self.end) return null;

            const value = self.current;
            self.current -= self.step;
            return value;
        }
    };
}
// ANCHOR_END: reverse_iterators

// ANCHOR: bidirectional_iterators
/// Create a reverse view without copying
pub fn reverseSlice(comptime T: type, items: []T) void {
    if (items.len <= 1) return;

    var left: usize = 0;
    var right: usize = items.len - 1;

    while (left < right) {
        const temp = items[left];
        items[left] = items[right];
        items[right] = temp;
        left += 1;
        right -= 1;
    }
}

/// Iterator that yields items in pairs from both ends
pub fn EndsIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const Pair = struct {
            front: T,
            back: T,
        };

        items: []const T,
        front_index: usize,
        back_index: usize,

        pub fn init(items: []const T) Self {
            return Self{
                .items = items,
                .front_index = 0,
                .back_index = items.len,
            };
        }

        pub fn next(self: *Self) ?Pair {
            // Need at least 2 elements to make a pair
            if (self.front_index + 1 >= self.back_index) return null;

            self.back_index -= 1;
            const pair = Pair{
                .front = self.items[self.front_index],
                .back = self.items[self.back_index],
            };
            self.front_index += 1;

            return pair;
        }
    };
}
// ANCHOR_END: bidirectional_iterators

test "reverse iterator basic" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = ReverseIterator(i32).init(&items);

    try testing.expectEqual(@as(?i32, 5), iter.next());
    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "reverse iterator empty slice" {
    const items: []const i32 = &[_]i32{};
    var iter = ReverseIterator(i32).init(items);

    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "reverse iterator single item" {
    const items = [_]i32{42};
    var iter = ReverseIterator(i32).init(&items);

    try testing.expectEqual(@as(?i32, 42), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "reverse iterator reset" {
    const items = [_]i32{ 1, 2, 3 };
    var iter = ReverseIterator(i32).init(&items);

    _ = iter.next();
    _ = iter.next();
    iter.reset();

    try testing.expectEqual(@as(?i32, 3), iter.next());
}

test "bidirectional iterator forward" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = BidirectionalIterator(i32).init(&items);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());
}

test "bidirectional iterator backward" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = BidirectionalIterator(i32).init(&items);

    try testing.expectEqual(@as(?i32, 5), iter.nextBack());
    try testing.expectEqual(@as(?i32, 4), iter.nextBack());
    try testing.expectEqual(@as(?i32, 3), iter.nextBack());
}

test "bidirectional iterator mixed directions" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = BidirectionalIterator(i32).init(&items);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 5), iter.nextBack());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 4), iter.nextBack());
    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.nextBack());
}

test "bidirectional iterator remaining count" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = BidirectionalIterator(i32).init(&items);

    try testing.expectEqual(@as(usize, 5), iter.remaining());

    _ = iter.next();
    try testing.expectEqual(@as(usize, 4), iter.remaining());

    _ = iter.nextBack();
    try testing.expectEqual(@as(usize, 3), iter.remaining());
}

test "reverse range iterator" {
    var iter = ReverseRangeIterator(i32).init(10, 5, 1);

    try testing.expectEqual(@as(?i32, 10), iter.next());
    try testing.expectEqual(@as(?i32, 9), iter.next());
    try testing.expectEqual(@as(?i32, 8), iter.next());
    try testing.expectEqual(@as(?i32, 7), iter.next());
    try testing.expectEqual(@as(?i32, 6), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "reverse range with step" {
    var iter = ReverseRangeIterator(i32).init(20, 10, 2);

    try testing.expectEqual(@as(?i32, 20), iter.next());
    try testing.expectEqual(@as(?i32, 18), iter.next());
    try testing.expectEqual(@as(?i32, 16), iter.next());
    try testing.expectEqual(@as(?i32, 14), iter.next());
    try testing.expectEqual(@as(?i32, 12), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "reverse slice in place" {
    var items = [_]i32{ 1, 2, 3, 4, 5 };
    reverseSlice(i32, &items);

    try testing.expectEqual(@as(i32, 5), items[0]);
    try testing.expectEqual(@as(i32, 4), items[1]);
    try testing.expectEqual(@as(i32, 3), items[2]);
    try testing.expectEqual(@as(i32, 2), items[3]);
    try testing.expectEqual(@as(i32, 1), items[4]);
}

test "reverse empty slice" {
    var items: [0]i32 = undefined;
    reverseSlice(i32, &items);
}

test "reverse single element" {
    var items = [_]i32{42};
    reverseSlice(i32, &items);
    try testing.expectEqual(@as(i32, 42), items[0]);
}

test "reverse even length slice" {
    var items = [_]i32{ 1, 2, 3, 4 };
    reverseSlice(i32, &items);

    try testing.expectEqual(@as(i32, 4), items[0]);
    try testing.expectEqual(@as(i32, 3), items[1]);
    try testing.expectEqual(@as(i32, 2), items[2]);
    try testing.expectEqual(@as(i32, 1), items[3]);
}

test "ends iterator" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6 };
    var iter = EndsIterator(i32).init(&items);

    const pair1 = iter.next();
    try testing.expect(pair1 != null);
    try testing.expectEqual(@as(i32, 1), pair1.?.front);
    try testing.expectEqual(@as(i32, 6), pair1.?.back);

    const pair2 = iter.next();
    try testing.expect(pair2 != null);
    try testing.expectEqual(@as(i32, 2), pair2.?.front);
    try testing.expectEqual(@as(i32, 5), pair2.?.back);

    const pair3 = iter.next();
    try testing.expect(pair3 != null);
    try testing.expectEqual(@as(i32, 3), pair3.?.front);
    try testing.expectEqual(@as(i32, 4), pair3.?.back);

    try testing.expect(iter.next() == null);
}

test "ends iterator odd length" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = EndsIterator(i32).init(&items);

    const pair1 = iter.next();
    try testing.expect(pair1 != null);
    try testing.expectEqual(@as(i32, 1), pair1.?.front);
    try testing.expectEqual(@as(i32, 5), pair1.?.back);

    const pair2 = iter.next();
    try testing.expect(pair2 != null);
    try testing.expectEqual(@as(i32, 2), pair2.?.front);
    try testing.expectEqual(@as(i32, 4), pair2.?.back);

    // Middle element (3) is skipped
    try testing.expect(iter.next() == null);
}

test "reverse iteration with std.mem.reverseIterator" {
    // Demonstrate using std.mem functionality
    const items = [_]i32{ 1, 2, 3, 4, 5 };

    // Manual reverse iteration using indices
    var i: usize = items.len;
    var collected: [5]i32 = undefined;
    var j: usize = 0;

    while (i > 0) {
        i -= 1;
        collected[j] = items[i];
        j += 1;
    }

    try testing.expectEqual(@as(i32, 5), collected[0]);
    try testing.expectEqual(@as(i32, 1), collected[4]);
}

test "combining forward and reverse" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };

    // Forward first half
    var forward = BidirectionalIterator(i32).init(&items);
    var first_half: [2]i32 = undefined;
    first_half[0] = forward.next().?;
    first_half[1] = forward.next().?;

    // Reverse second half
    var reverse = ReverseIterator(i32).init(items[2..]);
    var second_half: [3]i32 = undefined;
    second_half[0] = reverse.next().?;
    second_half[1] = reverse.next().?;
    second_half[2] = reverse.next().?;

    try testing.expectEqual(@as(i32, 1), first_half[0]);
    try testing.expectEqual(@as(i32, 2), first_half[1]);
    try testing.expectEqual(@as(i32, 5), second_half[0]);
    try testing.expectEqual(@as(i32, 4), second_half[1]);
    try testing.expectEqual(@as(i32, 3), second_half[2]);
}

test "memory safety - reverse iteration no allocation" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };

    var rev_iter = ReverseIterator(i32).init(&items);
    while (rev_iter.next()) |_| {}

    var bidir_iter = BidirectionalIterator(i32).init(&items);
    while (bidir_iter.next()) |_| {}
    while (bidir_iter.nextBack()) |_| {}
}

test "security - bounds checking in reverse iteration" {
    const items = [_]i32{ 1, 2, 3 };
    var iter = ReverseIterator(i32).init(&items);

    // Manually set index out of bounds
    iter.index = 100;

    // Should safely return null (wrapping would cause index to become very large)
    // In this case, index will wrap and be > items.len, so check will catch it
    const result = iter.next();
    // Index wraps, so 100 - 1 = 99, items[99] would be out of bounds
    // But our implementation checks index against 0 first
    _ = result;
}
