// Recipe 4.3: Creating new iteration patterns
// Target Zig Version: 0.15.2
//
// This recipe demonstrates creating custom iterator patterns with complex
// state management, including stateful generators and iterators with memory.

const std = @import("std");
const testing = std.testing;

// ANCHOR: stateful_iterators
/// Fibonacci sequence iterator
pub const FibonacciIterator = struct {
    const Self = @This();

    prev: u64,
    curr: u64,
    count: usize,
    max_count: ?usize,

    pub fn init(max_count: ?usize) Self {
        return Self{
            .prev = 0,
            .curr = 1,
            .count = 0,
            .max_count = max_count,
        };
    }

    pub fn next(self: *Self) ?u64 {
        if (self.max_count) |max| {
            if (self.count >= max) return null;
        }

        const result = self.prev;
        const tmp = self.curr;
        // Use wrapping addition to handle overflow gracefully
        self.curr = self.prev +% self.curr;
        self.prev = tmp;
        self.count += 1;

        return result;
    }
};
// ANCHOR_END: stateful_iterators

// ANCHOR: advanced_patterns
/// Iterator that cycles through items infinitely (with optional limit)
pub fn CycleIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        index: usize,
        cycles_remaining: ?usize,

        pub fn init(items: []const T, max_cycles: ?usize) Self {
            return Self{
                .items = items,
                .index = 0,
                .cycles_remaining = max_cycles,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.items.len == 0) return null;

            if (self.index >= self.items.len) {
                // Check if we have cycles remaining
                if (self.cycles_remaining) |*remaining| {
                    if (remaining.* <= 1) return null; // Used all cycles
                    remaining.* -= 1;
                }
                self.index = 0;
            }

            const item = self.items[self.index];
            self.index += 1;
            return item;
        }
    };
}

/// Iterator with lookahead capability
pub fn PeekableIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        index: usize,
        peeked: ?T,

        pub fn init(items: []const T) Self {
            return Self{
                .items = items,
                .index = 0,
                .peeked = null,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.peeked) |value| {
                self.peeked = null;
                self.index += 1; // Advance after consuming peeked value
                return value;
            }

            if (self.index >= self.items.len) return null;
            const item = self.items[self.index];
            self.index += 1;
            return item;
        }

        pub fn peek(self: *Self) ?T {
            if (self.peeked) |value| {
                return value;
            }

            if (self.index >= self.items.len) return null;
            const item = self.items[self.index];
            self.peeked = item;
            return item;
        }
    };
}

/// Iterator that generates a range with a custom step function
pub fn GeneratorIterator(comptime T: type) type {
    return struct {
        const Self = @This();
        const GeneratorFn = *const fn (T) ?T;

        current: T,
        generator: GeneratorFn,
        count: usize,
        max_count: ?usize,

        pub fn init(start: T, generator: GeneratorFn, max_count: ?usize) Self {
            return Self{
                .current = start,
                .generator = generator,
                .count = 0,
                .max_count = max_count,
            };
        }

        pub fn next(self: *Self) ?T {
            if (self.max_count) |max| {
                if (self.count >= max) return null;
            }

            const result = self.current;
            if (self.generator(self.current)) |new_value| {
                self.current = new_value;
                self.count += 1;
                return result;
            }

            // Generator returned null, iteration done
            return null;
        }
    };
}

/// Iterator that windows over a slice
pub fn WindowIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        window_size: usize,
        index: usize,

        pub fn init(items: []const T, window_size: usize) Self {
            return Self{
                .items = items,
                .window_size = window_size,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?[]const T {
            if (self.window_size == 0) return null;
            if (self.index + self.window_size > self.items.len) return null;

            const window = self.items[self.index .. self.index + self.window_size];
            self.index += 1;
            return window;
        }
    };
}
// ANCHOR_END: advanced_patterns

// ANCHOR: composition_iterators
/// Iterator that zips two iterators together
pub fn ZipIterator(comptime T1: type, comptime T2: type) type {
    return struct {
        const Self = @This();

        pub const Item = struct {
            first: T1,
            second: T2,
        };

        first: []const T1,
        second: []const T2,
        index: usize,

        pub fn init(first: []const T1, second: []const T2) Self {
            return Self{
                .first = first,
                .second = second,
                .index = 0,
            };
        }

        pub fn next(self: *Self) ?Item {
            if (self.index >= self.first.len) return null;
            if (self.index >= self.second.len) return null;

            const item = Item{
                .first = self.first[self.index],
                .second = self.second[self.index],
            };
            self.index += 1;
            return item;
        }
    };
}

/// Iterator with accumulating state
pub fn ScanIterator(comptime T: type, comptime State: type) type {
    return struct {
        const Self = @This();
        const ScanFn = *const fn (State, T) State;

        items: []const T,
        index: usize,
        state: State,
        scan_fn: ScanFn,

        pub fn init(items: []const T, initial_state: State, scan_fn: ScanFn) Self {
            return Self{
                .items = items,
                .index = 0,
                .state = initial_state,
                .scan_fn = scan_fn,
            };
        }

        pub fn next(self: *Self) ?State {
            if (self.index >= self.items.len) return null;

            const item = self.items[self.index];
            self.state = self.scan_fn(self.state, item);
            self.index += 1;
            return self.state;
        }
    };
}
// ANCHOR_END: composition_iterators

test "fibonacci iterator" {
    var fib = FibonacciIterator.init(10);

    try testing.expectEqual(@as(?u64, 0), fib.next());
    try testing.expectEqual(@as(?u64, 1), fib.next());
    try testing.expectEqual(@as(?u64, 1), fib.next());
    try testing.expectEqual(@as(?u64, 2), fib.next());
    try testing.expectEqual(@as(?u64, 3), fib.next());
    try testing.expectEqual(@as(?u64, 5), fib.next());
    try testing.expectEqual(@as(?u64, 8), fib.next());
    try testing.expectEqual(@as(?u64, 13), fib.next());
    try testing.expectEqual(@as(?u64, 21), fib.next());
    try testing.expectEqual(@as(?u64, 34), fib.next());
    try testing.expectEqual(@as(?u64, null), fib.next());
}

test "fibonacci unlimited" {
    var fib = FibonacciIterator.init(null);

    // Just verify first few values
    try testing.expectEqual(@as(?u64, 0), fib.next());
    try testing.expectEqual(@as(?u64, 1), fib.next());
    try testing.expectEqual(@as(?u64, 1), fib.next());

    // Can continue indefinitely (until overflow)
    var i: usize = 3;
    while (i < 50) : (i += 1) {
        _ = fib.next();
    }
}

test "cycle iterator finite" {
    const items = [_]i32{ 1, 2, 3 };
    var iter = CycleIterator(i32).init(&items, 2);

    // First cycle
    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());

    // Second cycle
    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());

    // Done
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "cycle iterator infinite (limited test)" {
    const items = [_]i32{ 1, 2 };
    var iter = CycleIterator(i32).init(&items, null);

    // Verify it cycles multiple times
    var count: usize = 0;
    while (count < 10) : (count += 1) {
        _ = iter.next();
    }
}

test "cycle empty slice" {
    const items: []const i32 = &[_]i32{};
    var iter = CycleIterator(i32).init(items, 5);

    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "peekable iterator" {
    const items = [_]i32{ 1, 2, 3 };
    var iter = PeekableIterator(i32).init(&items);

    // Peek multiple times without consuming
    try testing.expectEqual(@as(?i32, 1), iter.peek());
    try testing.expectEqual(@as(?i32, 1), iter.peek());

    // Now consume
    try testing.expectEqual(@as(?i32, 1), iter.next());

    // Peek again
    try testing.expectEqual(@as(?i32, 2), iter.peek());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.peek());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

fn doubleValue(n: i32) ?i32 {
    if (n > 1000) return null;
    return n * 2;
}

test "generator iterator" {
    var iter = GeneratorIterator(i32).init(1, doubleValue, 10);

    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, 8), iter.next());
    try testing.expectEqual(@as(?i32, 16), iter.next());
}

fn addOne(n: i32) ?i32 {
    if (n >= 5) return null;
    return n + 1;
}

test "generator with early termination" {
    var iter = GeneratorIterator(i32).init(0, addOne, null);

    try testing.expectEqual(@as(?i32, 0), iter.next());
    try testing.expectEqual(@as(?i32, 1), iter.next());
    try testing.expectEqual(@as(?i32, 2), iter.next());
    try testing.expectEqual(@as(?i32, 3), iter.next());
    try testing.expectEqual(@as(?i32, 4), iter.next());
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "window iterator" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = WindowIterator(i32).init(&items, 3);

    const w1 = iter.next();
    try testing.expect(w1 != null);
    try testing.expectEqual(@as(usize, 3), w1.?.len);
    try testing.expectEqual(@as(i32, 1), w1.?[0]);
    try testing.expectEqual(@as(i32, 3), w1.?[2]);

    const w2 = iter.next();
    try testing.expect(w2 != null);
    try testing.expectEqual(@as(i32, 2), w2.?[0]);

    const w3 = iter.next();
    try testing.expect(w3 != null);
    try testing.expectEqual(@as(i32, 3), w3.?[0]);

    try testing.expect(iter.next() == null);
}

test "window size larger than slice" {
    const items = [_]i32{ 1, 2 };
    var iter = WindowIterator(i32).init(&items, 5);

    try testing.expect(iter.next() == null);
}

test "zip iterator" {
    const first = [_]i32{ 1, 2, 3 };
    const second = [_][]const u8{ "a", "b", "c" };

    var iter = ZipIterator(i32, []const u8).init(&first, &second);

    const item1 = iter.next();
    try testing.expect(item1 != null);
    try testing.expectEqual(@as(i32, 1), item1.?.first);
    try testing.expect(std.mem.eql(u8, "a", item1.?.second));

    const item2 = iter.next();
    try testing.expect(item2 != null);
    try testing.expectEqual(@as(i32, 2), item2.?.first);

    const item3 = iter.next();
    try testing.expect(item3 != null);
    try testing.expectEqual(@as(i32, 3), item3.?.first);

    try testing.expect(iter.next() == null);
}

test "zip unequal lengths" {
    const first = [_]i32{ 1, 2, 3, 4, 5 };
    const second = [_]i32{ 10, 20 };

    var iter = ZipIterator(i32, i32).init(&first, &second);

    _ = iter.next();
    _ = iter.next();
    // Stops at shortest
    try testing.expect(iter.next() == null);
}

fn sumAccumulator(state: i32, item: i32) i32 {
    return state + item;
}

test "scan iterator accumulating state" {
    const items = [_]i32{ 1, 2, 3, 4, 5 };
    var iter = ScanIterator(i32, i32).init(&items, 0, sumAccumulator);

    try testing.expectEqual(@as(?i32, 1), iter.next());  // 0 + 1
    try testing.expectEqual(@as(?i32, 3), iter.next());  // 1 + 2
    try testing.expectEqual(@as(?i32, 6), iter.next());  // 3 + 3
    try testing.expectEqual(@as(?i32, 10), iter.next()); // 6 + 4
    try testing.expectEqual(@as(?i32, 15), iter.next()); // 10 + 5
    try testing.expectEqual(@as(?i32, null), iter.next());
}

fn productAccumulator(state: i32, item: i32) i32 {
    return state * item;
}

test "scan iterator with product" {
    const items = [_]i32{ 2, 3, 4 };
    var iter = ScanIterator(i32, i32).init(&items, 1, productAccumulator);

    try testing.expectEqual(@as(?i32, 2), iter.next());   // 1 * 2
    try testing.expectEqual(@as(?i32, 6), iter.next());   // 2 * 3
    try testing.expectEqual(@as(?i32, 24), iter.next());  // 6 * 4
    try testing.expectEqual(@as(?i32, null), iter.next());
}

test "memory safety - stateful iterators" {
    // All iterators use stack allocation only
    var fib = FibonacciIterator.init(5);
    while (fib.next()) |_| {}

    const items = [_]i32{ 1, 2, 3 };
    var cycle = CycleIterator(i32).init(&items, 2);
    while (cycle.next()) |_| {}
}

test "security - state overflow protection" {
    // Fibonacci will eventually overflow, but safely
    var fib = FibonacciIterator.init(100);
    var last: u64 = 0;
    var count: usize = 0;

    while (fib.next()) |val| {
        if (count > 0) {
            // Values should be monotonically increasing until overflow
            if (val < last) {
                // Overflow detected (wrapped around)
                break;
            }
        }
        last = val;
        count += 1;
    }

    // Should have gotten some values before overflow
    try testing.expect(count > 10);
}
