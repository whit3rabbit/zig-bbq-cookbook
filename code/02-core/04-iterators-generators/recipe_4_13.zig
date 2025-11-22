// Recipe 4.13: Creating data processing pipelines
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to compose multiple iterator operations together
// to create data processing pipelines without intermediate allocations.

const std = @import("std");
const testing = std.testing;

// ANCHOR: pipeline_builder
/// Pipeline builder for composing iterator operations
pub fn Pipeline(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,

        pub fn init(items: []const T) Self {
            return Self{ .items = items };
        }

        /// Map transformation
        pub fn map(self: Self, comptime R: type, map_fn: *const fn (T) R) MapPipeline(T, R) {
            return MapPipeline(T, R).init(self.items, map_fn);
        }

        /// Filter items
        pub fn filter(self: Self, pred: *const fn (T) bool) FilterPipeline(T) {
            return FilterPipeline(T).init(self.items, pred);
        }

        /// Take first N items
        pub fn take(self: Self, n: usize) TakePipeline(T) {
            return TakePipeline(T).init(self.items, n);
        }

        /// Skip first N items
        pub fn skip(self: Self, n: usize) SkipPipeline(T) {
            return SkipPipeline(T).init(self.items, n);
        }

        /// Count items
        pub fn len(self: Self) usize {
            return self.items.len;
        }
    };
}
// ANCHOR_END: pipeline_builder

// ANCHOR: pipeline_stages
/// Map pipeline stage
pub fn MapPipeline(comptime T: type, comptime R: type) type {
    return struct {
        const Self = @This();
        const MapFn = *const fn (T) R;

        items: []const T,
        map_fn: MapFn,
        index: usize,

        pub fn init(items: []const T, map_fn: MapFn) Self {
            return Self{
                .items = items,
                .map_fn = map_fn,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?R {
            if (self.index >= self.items.len) return null;

            const item = self.items[self.index];
            self.index += 1;
            return self.map_fn(item);
        }

        /// Chain another map
        pub fn map(self: Self, comptime S: type, next_fn: *const fn (R) S) ChainedMap(T, R, S) {
            return ChainedMap(T, R, S).init(self.items, self.map_fn, next_fn);
        }

        /// Add filter stage
        pub fn filter(self: Self, pred: *const fn (R) bool) MapFilter(T, R) {
            return MapFilter(T, R).init(self.items, self.map_fn, pred);
        }

        /// Collect results into slice
        pub fn collectSlice(self: *Self, allocator: std.mem.Allocator) ![]R {
            var list = try allocator.alloc(R, self.items.len);
            var idx: usize = 0;
            while (self.next()) |item| : (idx += 1) {
                list[idx] = item;
            }
            return list[0..idx];
        }
    };
}

/// Filter pipeline stage
pub fn FilterPipeline(comptime T: type) type {
    return struct {
        const Self = @This();
        const PredicateFn = *const fn (T) bool;

        items: []const T,
        predicate: PredicateFn,
        index: usize,

        pub fn init(items: []const T, predicate: PredicateFn) Self {
            return Self{
                .items = items,
                .predicate = predicate,
                .index = 0,
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

        /// Chain map after filter
        pub fn map(self: Self, comptime R: type, map_fn: *const fn (T) R) FilterMap(T, R) {
            return FilterMap(T, R).init(self.items, self.predicate, map_fn);
        }

        /// Chain another filter
        pub fn filter(self: Self, pred: *const fn (T) bool) ChainedFilter(T) {
            return ChainedFilter(T).init(self.items, self.predicate, pred);
        }

        /// Count filtered results
        pub fn countFiltered(self: *Self) usize {
            var c: usize = 0;
            while (self.next()) |_| {
                c += 1;
            }
            return c;
        }
    };
}

/// Take pipeline stage
pub fn TakePipeline(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        count: usize,
        index: usize,

        pub fn init(items: []const T, count: usize) Self {
            return Self{
                .items = items,
                .count = count,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.index >= self.count or self.index >= self.items.len) {
                return null;
            }

            const item = self.items[self.index];
            self.index += 1;
            return item;
        }
    };
}

/// Skip pipeline stage
pub fn SkipPipeline(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        skip_count: usize,
        index: usize,
        skipped: bool,

        pub fn init(items: []const T, skip_count: usize) Self {
            return Self{
                .items = items,
                .skip_count = @min(skip_count, items.len),
                .index = 0,
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
// ANCHOR_END: pipeline_stages

// ANCHOR: pipeline_composition
/// Chained map operations
pub fn ChainedMap(comptime T: type, comptime R: type, comptime S: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        first_fn: *const fn (T) R,
        second_fn: *const fn (R) S,
        index: usize,

        pub fn init(
            items: []const T,
            first_fn: *const fn (T) R,
            second_fn: *const fn (R) S,
        ) Self {
            return Self{
                .items = items,
                .first_fn = first_fn,
                .second_fn = second_fn,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?S {
            if (self.index >= self.items.len) return null;

            const item = self.items[self.index];
            self.index += 1;
            return self.second_fn(self.first_fn(item));
        }

        pub fn count(self: *Self) usize {
            var c: usize = 0;
            while (self.next()) |_| {
                c += 1;
            }
            return c;
        }
    };
}

/// Map after filter
pub fn FilterMap(comptime T: type, comptime R: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        predicate: *const fn (T) bool,
        map_fn: *const fn (T) R,
        index: usize,

        pub fn init(
            items: []const T,
            predicate: *const fn (T) bool,
            map_fn: *const fn (T) R,
        ) Self {
            return Self{
                .items = items,
                .predicate = predicate,
                .map_fn = map_fn,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?R {
            while (self.index < self.items.len) {
                const item = self.items[self.index];
                self.index += 1;

                if (self.predicate(item)) {
                    return self.map_fn(item);
                }
            }
            return null;
        }

        pub fn count(self: *Self) usize {
            var c: usize = 0;
            while (self.next()) |_| {
                c += 1;
            }
            return c;
        }
    };
}

/// Filter after map
pub fn MapFilter(comptime T: type, comptime R: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        map_fn: *const fn (T) R,
        predicate: *const fn (R) bool,
        index: usize,

        pub fn init(
            items: []const T,
            map_fn: *const fn (T) R,
            predicate: *const fn (R) bool,
        ) Self {
            return Self{
                .items = items,
                .map_fn = map_fn,
                .predicate = predicate,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?R {
            while (self.index < self.items.len) {
                const item = self.items[self.index];
                self.index += 1;

                const mapped = self.map_fn(item);
                if (self.predicate(mapped)) {
                    return mapped;
                }
            }
            return null;
        }

        pub fn count(self: *Self) usize {
            var c: usize = 0;
            while (self.next()) |_| {
                c += 1;
            }
            return c;
        }
    };
}

/// Chained filters
pub fn ChainedFilter(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        first_pred: *const fn (T) bool,
        second_pred: *const fn (T) bool,
        index: usize,

        pub fn init(
            items: []const T,
            first_pred: *const fn (T) bool,
            second_pred: *const fn (T) bool,
        ) Self {
            return Self{
                .items = items,
                .first_pred = first_pred,
                .second_pred = second_pred,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?T {
            while (self.index < self.items.len) {
                const item = self.items[self.index];
                self.index += 1;

                if (self.first_pred(item) and self.second_pred(item)) {
                    return item;
                }
            }
            return null;
        }
    };
}
// ANCHOR_END: pipeline_composition

test "pipeline map basic" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    var pipeline = Pipeline(i32).init(&items).map(i32, double);

    try testing.expectEqual(@as(?i32, 2), pipeline.next());
    try testing.expectEqual(@as(?i32, 4), pipeline.next());
    try testing.expectEqual(@as(?i32, 6), pipeline.next());
    try testing.expectEqual(@as(?i32, 8), pipeline.next());
    try testing.expectEqual(@as(?i32, 10), pipeline.next());
}

test "pipeline filter basic" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    const isEven = struct {
        fn f(x: i32) bool {
            return @rem(x, 2) == 0;
        }
    }.f;

    var pipeline = Pipeline(i32).init(&items).filter(isEven);

    try testing.expectEqual(@as(?i32, 2), pipeline.next());
    try testing.expectEqual(@as(?i32, 4), pipeline.next());
    try testing.expectEqual(@as(?i32, 6), pipeline.next());
}

test "pipeline chained map" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const addTen = struct {
        fn f(x: i32) i32 {
            return x + 10;
        }
    }.f;

    var pipeline = Pipeline(i32).init(&items).map(i32, double).map(i32, addTen);

    try testing.expectEqual(@as(?i32, 12), pipeline.next()); // (1*2)+10
    try testing.expectEqual(@as(?i32, 14), pipeline.next()); // (2*2)+10
    try testing.expectEqual(@as(?i32, 16), pipeline.next()); // (3*2)+10
}

test "pipeline filter then map" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8 };

    const isEven = struct {
        fn f(x: i32) bool {
            return @rem(x, 2) == 0;
        }
    }.f;

    const square = struct {
        fn f(x: i32) i32 {
            return x * x;
        }
    }.f;

    var pipeline = Pipeline(i32).init(&items).filter(isEven).map(i32, square);

    try testing.expectEqual(@as(?i32, 4), pipeline.next()); // 2*2
    try testing.expectEqual(@as(?i32, 16), pipeline.next()); // 4*4
    try testing.expectEqual(@as(?i32, 36), pipeline.next()); // 6*6
    try testing.expectEqual(@as(?i32, 64), pipeline.next()); // 8*8
}

test "pipeline map then filter" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8 };

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const greaterThan5 = struct {
        fn f(x: i32) bool {
            return x > 5;
        }
    }.f;

    var pipeline = Pipeline(i32).init(&items).map(i32, double).filter(greaterThan5);

    try testing.expectEqual(@as(?i32, 6), pipeline.next()); // 3*2
    try testing.expectEqual(@as(?i32, 8), pipeline.next()); // 4*2
    try testing.expectEqual(@as(?i32, 10), pipeline.next()); // 5*2
}

test "pipeline take" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    var pipeline = Pipeline(i32).init(&items).take(5);

    var count: usize = 0;
    while (pipeline.next()) |_| {
        count += 1;
    }

    try testing.expectEqual(@as(usize, 5), count);
}

test "pipeline skip" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    var pipeline = Pipeline(i32).init(&items).skip(5);

    try testing.expectEqual(@as(?i32, 6), pipeline.next());
    try testing.expectEqual(@as(?i32, 7), pipeline.next());
}

test "pipeline collect to slice" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    var pipeline = Pipeline(i32).init(&items).map(i32, double);

    const result = try pipeline.collectSlice(testing.allocator);
    defer testing.allocator.free(result);

    try testing.expectEqual(@as(usize, 5), result.len);
    try testing.expectEqual(@as(i32, 2), result[0]);
    try testing.expectEqual(@as(i32, 10), result[4]);
}

test "pipeline complex composition" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    const isEven = struct {
        fn f(x: i32) bool {
            return @rem(x, 2) == 0;
        }
    }.f;

    const doubleAndAddFive = struct {
        fn f(x: i32) i32 {
            return (x * 2) + 5;
        }
    }.f;

    // Filter even, then double and add five
    var pipeline = Pipeline(i32).init(&items)
        .filter(isEven)
        .map(i32, doubleAndAddFive);

    try testing.expectEqual(@as(?i32, 9), pipeline.next()); // (2*2)+5
    try testing.expectEqual(@as(?i32, 13), pipeline.next()); // (4*2)+5
    try testing.expectEqual(@as(?i32, 17), pipeline.next()); // (6*2)+5
}

test "pipeline chained filters" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };

    const isEven = struct {
        fn f(x: i32) bool {
            return @rem(x, 2) == 0;
        }
    }.f;

    const greaterThan5 = struct {
        fn f(x: i32) bool {
            return x > 5;
        }
    }.f;

    var pipeline = Pipeline(i32).init(&items).filter(isEven).filter(greaterThan5);

    try testing.expectEqual(@as(?i32, 6), pipeline.next());
    try testing.expectEqual(@as(?i32, 8), pipeline.next());
    try testing.expectEqual(@as(?i32, 10), pipeline.next());
    try testing.expectEqual(@as(?i32, 12), pipeline.next());
}

test "memory safety - pipeline empty" {
    const empty: []const i32 = &[_]i32{};

    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    var pipeline = Pipeline(i32).init(empty).map(i32, double);

    try testing.expect(pipeline.next() == null);
}

test "security - pipeline count filtered" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };

    const isOdd = struct {
        fn f(x: i32) bool {
            return @rem(x, 2) != 0;
        }
    }.f;

    var pipeline = Pipeline(i32).init(&items).filter(isOdd);

    const result = pipeline.countFiltered();

    try testing.expectEqual(@as(usize, 3), result);
}
