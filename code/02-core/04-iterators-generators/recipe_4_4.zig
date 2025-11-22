// Recipe 4.4: Implementing the iterator protocol
// Target Zig Version: 0.15.2
//
// This recipe demonstrates creating a standardized iterator protocol and
// generic utilities that work with any conforming iterator.

const std = @import("std");
const testing = std.testing;

// ANCHOR: protocol_checking
/// Check if a type conforms to the iterator protocol
pub fn isIterator(comptime T: type) bool {
    return @hasDecl(T, "next");
}

/// Get the item type from an iterator type
pub fn IteratorItem(comptime Iterator: type) type {
    if (!@hasDecl(Iterator, "next")) {
        @compileError("Type does not have a 'next' method");
    }

    const NextFn = @TypeOf(@field(Iterator, "next"));
    const next_info = @typeInfo(NextFn);

    if (next_info != .Pointer) {
        @compileError("next is not a function pointer");
    }

    const fn_info = @typeInfo(next_info.Pointer.child);
    if (fn_info != .Fn) {
        @compileError("next is not a function");
    }

    const return_type = fn_info.Fn.return_type orelse {
        @compileError("next function has no return type");
    };

    return return_type;
}
// ANCHOR_END: protocol_checking

// ANCHOR: generic_operations
/// Generic collect function for any iterator
pub fn collect(comptime T: type, allocator: std.mem.Allocator, iter: anytype) !std.ArrayList(T) {
    var list: std.ArrayList(T) = .{};
    errdefer list.deinit(allocator);

    while (iter.next()) |item| {
        try list.append(allocator, item);
    }

    return list;
}

/// Generic count function for any iterator
pub fn count(iter: anytype) usize {
    var total: usize = 0;
    while (iter.next()) |_| {
        total += 1;
    }
    return total;
}

/// Generic all function - check if all items match predicate
pub fn all(comptime T: type, iter: anytype, predicate: *const fn (T) bool) bool {
    while (iter.next()) |item| {
        if (!predicate(item)) return false;
    }
    return true;
}

/// Generic any function - check if any item matches predicate
pub fn any(comptime T: type, iter: anytype, predicate: *const fn (T) bool) bool {
    while (iter.next()) |item| {
        if (predicate(item)) return true;
    }
    return false;
}

/// Generic find function - find first item matching predicate
pub fn find(comptime T: type, iter: anytype, predicate: *const fn (T) bool) ?T {
    while (iter.next()) |item| {
        if (predicate(item)) return item;
    }
    return null;
}

/// Generic position function - find index of first match
pub fn position(comptime T: type, iter: anytype, predicate: *const fn (T) bool) ?usize {
    var index: usize = 0;
    while (iter.next()) |item| {
        if (predicate(item)) return index;
        index += 1;
    }
    return null;
}

/// Generic fold/reduce function
pub fn fold(comptime T: type, comptime Acc: type, iter: anytype, initial: Acc, func: *const fn (Acc, T) Acc) Acc {
    var accumulator = initial;
    while (iter.next()) |item| {
        accumulator = func(accumulator, item);
    }
    return accumulator;
}
// ANCHOR_END: generic_operations

// ANCHOR: example_implementations
/// Example iterator implementations for testing

pub fn RangeIterator(comptime T: type) type {
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
            if (self.step > 0 and self.current >= self.end) return null;
            if (self.step < 0 and self.current <= self.end) return null;

            const value = self.current;
            self.current += self.step;
            return value;
        }
    };
}

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
    };
}
// ANCHOR_END: example_implementations

test "isIterator check" {
    try testing.expect(isIterator(RangeIterator(i32)));
    try testing.expect(isIterator(SliceIterator(i32)));

    const NotAnIterator = struct {
        value: i32,
    };
    try testing.expect(!isIterator(NotAnIterator));
}

test "collect from range iterator" {
    var iter = RangeIterator(i32).init(0, 5, 1);

    var list = try collect(?i32, testing.allocator, &iter);
    defer list.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 5), list.items.len);
    try testing.expectEqual(@as(?i32, 0), list.items[0]);
    try testing.expectEqual(@as(?i32, 4), list.items[4]);
}

test "collect from slice iterator" {
    const items = [_]i32{ 10, 20, 30 };
    var iter = SliceIterator(i32).init(&items);

    var list = try collect(?i32, testing.allocator, &iter);
    defer list.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 3), list.items.len);
    try testing.expectEqual(@as(?i32, 10), list.items[0]);
}

test "count iterator items" {
    var iter = RangeIterator(i32).init(0, 10, 1);
    const total = count(&iter);
    try testing.expectEqual(@as(usize, 10), total);
}

fn isPositive(n: ?i32) bool {
    if (n) |val| {
        return val > 0;
    }
    return false;
}

test "all predicate - true case" {
    var iter = RangeIterator(i32).init(1, 6, 1);
    try testing.expect(all(?i32, &iter, isPositive));
}

test "all predicate - false case" {
    var iter = RangeIterator(i32).init(-1, 3, 1);
    try testing.expect(!all(?i32, &iter, isPositive));
}

test "any predicate - true case" {
    var iter = RangeIterator(i32).init(-5, 5, 1);
    try testing.expect(any(?i32, &iter, isPositive));
}

test "any predicate - false case" {
    var iter = RangeIterator(i32).init(-5, 0, 1);
    try testing.expect(!any(?i32, &iter, isPositive));
}

fn isEven(n: ?i32) bool {
    if (n) |val| {
        return @mod(val, 2) == 0;
    }
    return false;
}

test "find first match" {
    var iter = RangeIterator(i32).init(1, 10, 1);
    const result = find(?i32, &iter, isEven);

    try testing.expect(result != null);
    try testing.expectEqual(@as(i32, 2), result.?);
}

test "find no match" {
    var iter = RangeIterator(i32).init(1, 5, 2); // 1, 3
    const result = find(?i32, &iter, isEven);

    try testing.expect(result == null);
}

test "position of first match" {
    var iter = RangeIterator(i32).init(1, 10, 1);
    const pos = position(?i32, &iter, isEven);

    try testing.expect(pos != null);
    try testing.expectEqual(@as(usize, 1), pos.?); // Second item (index 1) is 2
}

test "position no match" {
    var iter = RangeIterator(i32).init(1, 5, 2);
    const pos = position(?i32, &iter, isEven);

    try testing.expect(pos == null);
}

fn sum(acc: i32, item: ?i32) i32 {
    if (item) |val| {
        return acc + val;
    }
    return acc;
}

test "fold/reduce sum" {
    var iter = RangeIterator(i32).init(1, 6, 1);
    const result = fold(?i32, i32, &iter, 0, sum);

    try testing.expectEqual(@as(i32, 15), result); // 1+2+3+4+5
}

fn product(acc: i32, item: ?i32) i32 {
    if (item) |val| {
        return acc * val;
    }
    return acc;
}

test "fold/reduce product" {
    var iter = RangeIterator(i32).init(1, 5, 1);
    const result = fold(?i32, i32, &iter, 1, product);

    try testing.expectEqual(@as(i32, 24), result); // 1*2*3*4
}

test "empty iterator" {
    var iter = RangeIterator(i32).init(5, 5, 1);

    try testing.expectEqual(@as(usize, 0), count(&iter));

    var iter2 = RangeIterator(i32).init(5, 5, 1);
    try testing.expect(all(?i32, &iter2, isPositive));

    var iter3 = RangeIterator(i32).init(5, 5, 1);
    try testing.expect(!any(?i32, &iter3, isPositive));
}

test "protocol works with different iterator types" {
    // Range iterator
    var range_iter = RangeIterator(i32).init(0, 3, 1);
    try testing.expectEqual(@as(usize, 3), count(&range_iter));

    // Slice iterator
    const items = [_]i32{ 1, 2, 3 };
    var slice_iter = SliceIterator(i32).init(&items);
    try testing.expectEqual(@as(usize, 3), count(&slice_iter));
}

test "chaining protocol operations" {
    const items = [_]i32{ 1, 2, 3, 4, 5, 6 };
    var iter = SliceIterator(i32).init(&items);

    // Find first even number
    const first_even = find(?i32, &iter, isEven);
    try testing.expectEqual(@as(i32, 2), first_even.?);

    // After find, iterator is positioned after the match
    // Continue finding
    const second_even = find(?i32, &iter, isEven);
    try testing.expectEqual(@as(i32, 4), second_even.?);
}

test "memory safety - protocol operations don't allocate" {
    var iter = RangeIterator(i32).init(0, 100, 1);

    _ = count(&iter);

    var iter2 = RangeIterator(i32).init(0, 100, 1);
    _ = all(?i32, &iter2, isPositive);

    var iter3 = RangeIterator(i32).init(0, 100, 1);
    _ = fold(?i32, i32, &iter3, 0, sum);
}

test "security - protocol handles iterator bounds" {
    // Test that protocol functions safely handle exhausted iterators
    var iter = RangeIterator(i32).init(0, 3, 1);

    // Exhaust iterator
    var list = try collect(?i32, testing.allocator, &iter);
    defer list.deinit(testing.allocator);

    // Calling on exhausted iterator should be safe
    try testing.expectEqual(@as(usize, 0), count(&iter));
}
