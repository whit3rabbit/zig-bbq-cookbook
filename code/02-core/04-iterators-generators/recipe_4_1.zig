// Recipe 4.1: Manually consuming an iterator
// Target Zig Version: 0.15.2
//
// This recipe demonstrates the standard Zig iterator pattern using next()
// returning ?T, and how to manually consume iterators.

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_iterators
/// Basic iterator over a slice
pub fn SliceIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        index: usize,

        pub fn init(items: []const T) Self {
            return Self{
                .items = items,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.index >= self.items.len) return null;
            const item = self.items[self.index];
            self.index += 1;
            return item;
        }

        pub fn reset(self: *Self) void {
            self.index = 0;
        }

        pub fn peek(self: *Self) ?T {
            if (self.index >= self.items.len) return null;
            return self.items[self.index];
        }
    };
}

/// Iterator that yields numbers in a range
pub const RangeIterator = struct {
    const Self = @This();

    start: i32,
    end: i32,
    current: i32,
    step: i32,

    pub fn init(start: i32, end: i32, step: i32) Self {
        return Self{
            .start = start,
            .end = end,
            .current = start,
            .step = step,
        };
    }

    pub fn next(self: *Self) ?i32 {
        if (self.step > 0 and self.current >= self.end) return null;
        if (self.step < 0 and self.current <= self.end) return null;
        if (self.step == 0) return null;

        const value = self.current;
        self.current += self.step;
        return value;
    }

    pub fn reset(self: *Self) void {
        self.current = self.start;
    }
};
// ANCHOR_END: basic_iterators

// ANCHOR: transformation_iterators
/// Iterator that filters items based on a predicate
pub fn FilterIterator(comptime T: type) type {
    return struct {
        const Self = @This();
        const PredicateFn = *const fn (T) bool;

        items: []const T,
        index: usize,
        predicate: PredicateFn,

        pub fn init(items: []const T, predicate: PredicateFn) Self {
            return Self{
                .items = items,
                .index = 0,
                .predicate = predicate,
            };
        }

        pub fn next(self: *Self) ?T {
            while (self.index < self.items.len) {
                const item = self.items[self.index];
                self.index += 1;
                if (self.predicate(item)) {
                    return item;
                }
            }
            return null;
        }
    };
}

/// Iterator that transforms items using a mapping function
pub fn MapIterator(comptime T: type, comptime R: type) type {
    return struct {
        const Self = @This();
        const MapFn = *const fn (T) R;

        items: []const T,
        index: usize,
        map_fn: MapFn,

        pub fn init(items: []const T, map_fn: MapFn) Self {
            return Self{
                .items = items,
                .index = 0,
                .map_fn = map_fn,
            };
        }

        pub fn next(self: *Self) ?R {
            if (self.index >= self.items.len) return null;
            const item = self.items[self.index];
            self.index += 1;
            return self.map_fn(item);
        }
    };
}
// ANCHOR_END: transformation_iterators

// ANCHOR: consumer_functions
/// Consume iterator and collect into ArrayList
pub fn collect(comptime T: type, allocator: std.mem.Allocator, iter: anytype) !std.ArrayList(T) {
    var list: std.ArrayList(T) = .{};
    errdefer list.deinit(allocator);

    while (iter.next()) |item| {
        try list.append(allocator, item);
    }

    return list;
}

/// Count remaining items in iterator (consumes it)
pub fn count(iter: anytype) usize {
    var total: usize = 0;
    while (iter.next()) |_| {
        total += 1;
    }
    return total;
}

/// Consume iterator for side effects only
pub fn forEach(iter: anytype, comptime action: anytype) void {
    while (iter.next()) |item| {
        action(item);
    }
}
// ANCHOR_END: consumer_functions

test "slice iterator basic usage" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = SliceIterator(i32).init(&items);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, 5), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "slice iterator with while loop" {
    const items = [_]i32{ 10, 20, 30 };
    var iter = SliceIterator(i32).init(&items);

    var sum: i32 = 0;
    while (iter.next()) |item| {
        sum += item;
    }

    try testing.expectEqual(@as(i32, 60), sum);
}

test "slice iterator reset" {
    const items = [_]i32{ 1, 2, 3 };
    var iter = SliceIterator(i32).init(&items);

    _ = iter.next();
    _ = iter.next();
    iter.reset();

    try testing.expectEqual(@as(?i32, 1), iter.next());
}

test "slice iterator peek" {
    const items = [_]i32{ 1, 2, 3 };
    var iter = SliceIterator(i32).init(&items);

    try testing.expectEqual(@as(?i32, 1), iter.peek());
    try testing.expectEqual(@as(?i32, 1), iter.peek());
    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.peek());
}

test "empty slice iterator" {
    const items: []const i32 = &[_]i32{};
    var iter = SliceIterator(i32).init(items);

    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "range iterator forward" {
    var iter = RangeIterator.init(0, 5, 1);

    try testing.expectEqual(@as(?i32, 0), iter.next());
    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "range iterator backward" {
    var iter = RangeIterator.init(5, 0, -1);

    try testing.expectEqual(@as(?i32, 5), iter.next());
    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "range iterator with step" {
    var iter = RangeIterator.init(0, 10, 2);

    try testing.expectEqual(@as(?i32, 0), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, 6), iter.next());
    try testing.expectEqual(@as(?i32, 8), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "range iterator reset" {
    var iter = RangeIterator.init(0, 3, 1);

    _ = iter.next();
    _ = iter.next();
    iter.reset();

    try testing.expectEqual(@as(?i32, 0), iter.next());
}

fn isEven(n: i32) bool {
    return @mod(n, 2) == 0;
}

test "filter iterator" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6 };
    var iter = FilterIterator(i32).init(&items, isEven);

    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, 6), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

fn square(n: i32) i32 {
    return n * n;
}

test "map iterator" {
    const items = [_]i32{ 1, 2, 3, 4 };
    var iter = MapIterator(i32, i32).init(&items, square);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, 9), iter.next());
    try testing.expectEqual(@as(?i32, 16), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

fn double(n: i32) i64 {
    return @as(i64, n) * 2;
}

test "map iterator with type conversion" {
    const items = [_]i32{ 1, 2, 3 };
    var iter = MapIterator(i32, i64).init(&items, double);

    try testing.expectEqual(@as(?i64, 2), iter.next());
    try testing.expectEqual(@as(?i64, 4), iter.next());
    try testing.expectEqual(@as(?i64, 6), iter.next());
    try testing.expectEqual(@as(?i64, null), iter.next());
}

test "collect iterator to list" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = SliceIterator(i32).init(&items);

    var list = try collect(i32, testing.allocator, &iter);
    defer list.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 5), list.items.len);
    try testing.expectEqual(@as(i32, 1), list.items[0]);
    try testing.expectEqual(@as(i32, 5), list.items[4]);
}

test "count iterator items" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = SliceIterator(i32).init(&items);

    const total = count(&iter);
    try testing.expectEqual(@as(usize, 5), total);
}

test "forEach with side effects" {
    const items = [_]i32{ 1, 2, 3 };
    var iter = SliceIterator(i32).init(&items);

    var sum: i32 = 0;
    const addToSum = struct {
        fn f(s: *i32, item: i32) void {
            s.* += item;
        }
    }.f;

    while (iter.next()) |item| {
        addToSum(&sum, item);
    }

    try testing.expectEqual(@as(i32, 6), sum);
}

test "chaining filter and map" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6 };

    // First filter evens
    var filter_iter = FilterIterator(i32).init(&items, isEven);

    // Collect filtered items
    var evens: std.ArrayList(i32) = .{};
    defer evens.deinit(testing.allocator);

    while (filter_iter.next()) |item| {
        try evens.append(testing.allocator, item);
    }

    // Then square them
    var map_iter = MapIterator(i32, i32).init(evens.items, square);

    try testing.expectEqual(@as(?i32, 4), map_iter.next());   // 2²
    try testing.expectEqual(@as(?i32, 16), map_iter.next());  // 4²
    try testing.expectEqual(@as(?i32, 36), map_iter.next());  // 6²
    try testing.expectEqual(@as(?i32, null), map_iter.next());
}

test "iterator exhaustion" {
    const items = [_]i32{ 1, 2 };
    var iter = SliceIterator(i32).init(&items);

    // Exhaust iterator
    while (iter.next()) |_| {}

    // Should return null
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "multiple passes with reset" {
    const items = [_]i32{ 1, 2, 3 };
    var iter = SliceIterator(i32).init(&items);

    // First pass
    var sum1: i32 = 0;
    while (iter.next()) |item| sum1 += item;
    try testing.expectEqual(@as(i32, 6), sum1);

    // Reset and second pass
    iter.reset();
    var sum2: i32 = 0;
    while (iter.next()) |item| sum2 += item;
    try testing.expectEqual(@as(i32, 6), sum2);
}

test "memory safety - no allocation for simple iterators" {
    const items = [_]i32{ 1, 2, 3 };
    var iter = SliceIterator(i32).init(&items);

    // Iterating doesn't allocate
    while (iter.next()) |_| {}
}

test "security - iterator bounds checking" {
    const items = [_]i32{ 1, 2, 3 };
    var iter = SliceIterator(i32).init(&items);

    // Manually advance beyond bounds
    iter.index = 100;

    // Should safely return null, not access out of bounds
    try testing.expectEqual(@as(?i32, null), iter.next());
}
