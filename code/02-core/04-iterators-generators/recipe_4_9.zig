// Recipe 4.9: Iterating over all possible combinations or permutations
// Target Zig Version: 0.15.2
//
// This recipe demonstrates algorithms for generating combinations and permutations,
// from basic recursive approaches to advanced iterative algorithms like Knuth's
// Algorithm L and Gosper's Hack.

const std = @import("std");
const testing = std.testing;

// Maximum recursion depth for safety (prevents stack overflow)
const MAX_RECURSION_DEPTH: usize = 1000;

// ============================================================================
// BASIC: Simple Combinations and Permutations
// ============================================================================

// ANCHOR: basic_combinations_permutations
/// Basic combination generator (recursive, allocates)
pub fn generateCombinations(
    comptime T: type,
    allocator: std.mem.Allocator,
    items: []const T,
    k: usize,
) !std.ArrayList([]T) {
    var result: std.ArrayList([]T) = .{};
    errdefer {
        for (result.items) |combo| {
            allocator.free(combo);
        }
        result.deinit(allocator);
    }

    if (k > items.len) return result;
    if (k == 0) return result;

    // Safety check: prevent excessive recursion depth
    if (k > MAX_RECURSION_DEPTH) return error.RecursionLimitExceeded;

    const current = try allocator.alloc(T, k);
    defer allocator.free(current);

    try combineRecursive(T, allocator, items, k, 0, 0, current, &result);
    return result;
}

fn combineRecursive(
    comptime T: type,
    allocator: std.mem.Allocator,
    items: []const T,
    k: usize,
    start: usize,
    index: usize,
    current: []T,
    result: *std.ArrayList([]T),
) !void {
    if (index == k) {
        const combo = try allocator.alloc(T, k);
        @memcpy(combo, current);
        try result.append(allocator, combo);
        return;
    }

    var i = start;
    while (i < items.len) : (i += 1) {
        current[index] = items[i];
        try combineRecursive(T, allocator, items, k, i + 1, index + 1, current, result);
    }
}

/// Basic permutation generator using non-recursive Heap's algorithm
/// This is ~3x faster than recursive approaches due to better cache behavior
pub fn generatePermutations(
    comptime T: type,
    allocator: std.mem.Allocator,
    items: []const T,
) !std.ArrayList([]T) {
    var result: std.ArrayList([]T) = .{};
    errdefer {
        for (result.items) |perm| {
            allocator.free(perm);
        }
        result.deinit(allocator);
    }

    if (items.len == 0) return result;

    const current = try allocator.dupe(T, items);
    defer allocator.free(current);

    const n = items.len;
    const c = try allocator.alloc(usize, n);
    defer allocator.free(c);
    @memset(c, 0);

    // Add first permutation
    const first = try allocator.dupe(T, current);
    try result.append(allocator, first);

    // Heap's algorithm (non-recursive)
    var i: usize = 0;
    while (i < n) {
        if (c[i] < i) {
            if (i % 2 == 0) {
                // i is even: swap first with i-th element
                std.mem.swap(T, &current[0], &current[i]);
            } else {
                // i is odd: swap c[i]-th with i-th element
                std.mem.swap(T, &current[c[i]], &current[i]);
            }

            const perm = try allocator.dupe(T, current);
            try result.append(allocator, perm);

            c[i] += 1;
            i = 0;
        } else {
            c[i] = 0;
            i += 1;
        }
    }

    return result;
}
// ANCHOR_END: basic_combinations_permutations

// ============================================================================
// INTERMEDIATE: Lexicographic Iterators
// ============================================================================

// ANCHOR: lexicographic_iterators
/// Lexicographic combination iterator (choose k from n)
/// Based on the "next combination" algorithm
/// Uses internal buffer for zero-allocation iteration
pub fn CombinationIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        indices: []usize,
        buffer: []T,
        k: usize,
        first: bool,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, items: []const T, k: usize) !Self {
            if (k > items.len) return error.InvalidSize;

            const indices = try allocator.alloc(usize, k);
            errdefer allocator.free(indices);

            for (indices, 0..) |*idx, i| {
                idx.* = i;
            }

            const buffer = try allocator.alloc(T, k);

            return Self{
                .items = items,
                .indices = indices,
                .buffer = buffer,
                .k = k,
                .first = true,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.indices);
            self.allocator.free(self.buffer);
        }

        pub fn next(self: *Self) ?[]const T {
            if (self.k == 0) return null;

            if (self.first) {
                self.first = false;
                return self.getCurrentCombination();
            }

            // Find rightmost element that can be incremented
            var i: usize = self.k;
            while (i > 0) {
                i -= 1;
                if (self.indices[i] < self.items.len - self.k + i) {
                    self.indices[i] += 1;

                    // Reset all indices to the right
                    var j = i + 1;
                    while (j < self.k) : (j += 1) {
                        self.indices[j] = self.indices[j - 1] + 1;
                    }

                    return self.getCurrentCombination();
                }
            }

            return null;
        }

        fn getCurrentCombination(self: *Self) []const T {
            // Fill internal buffer with current combination
            for (self.indices, 0..) |idx, i| {
                self.buffer[i] = self.items[idx];
            }
            return self.buffer;
        }

        pub fn collect(self: *Self, allocator: std.mem.Allocator) ![]T {
            var result = try allocator.alloc(T, self.k);
            for (self.indices, 0..) |idx, i| {
                result[i] = self.items[idx];
            }
            return result;
        }
    };
}

/// Lexicographic permutation iterator
/// Implements Knuth's Algorithm L (next permutation in lexicographic order)
pub fn PermutationIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []T,
        first: bool,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, items: []const T) !Self {
            const buffer = try allocator.dupe(T, items);

            // Sort for lexicographic order
            std.mem.sort(T, buffer, {}, struct {
                fn lessThan(_: void, a: T, b: T) bool {
                    return a < b;
                }
            }.lessThan);

            return Self{
                .items = buffer,
                .first = true,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.items);
        }

        pub fn next(self: *Self) ?[]const T {
            if (self.items.len == 0) return null;

            if (self.first) {
                self.first = false;
                return self.items;
            }

            // Knuth's Algorithm L: Find next permutation
            // Step 1: Find largest index k such that items[k] < items[k+1]
            var k: ?usize = null;
            var i: usize = self.items.len - 1;
            while (i > 0) {
                i -= 1;
                if (self.items[i] < self.items[i + 1]) {
                    k = i;
                    break;
                }
            }

            if (k == null) return null; // Last permutation

            // Step 2: Find largest index l > k such that items[k] < items[l]
            var l: usize = self.items.len - 1;
            while (l > k.?) {
                if (self.items[k.?] < self.items[l]) {
                    break;
                }
                l -= 1;
            }

            // Step 3: Swap items[k] and items[l]
            const temp = self.items[k.?];
            self.items[k.?] = self.items[l];
            self.items[l] = temp;

            // Step 4: Reverse the sequence from items[k+1] to end
            var left = k.? + 1;
            var right = self.items.len - 1;
            while (left < right) {
                const t = self.items[left];
                self.items[left] = self.items[right];
                self.items[right] = t;
                left += 1;
                right -= 1;
            }

            return self.items;
        }
    };
}
// ANCHOR_END: lexicographic_iterators

// ============================================================================
// ADVANCED: k-Combinations, k-Permutations, and Optimized Algorithms
// ============================================================================

// ANCHOR: advanced_algorithms
/// k-permutations: permutations of length k from n items
/// Implements Python's itertools.permutations algorithm
/// Uses internal buffer for zero-allocation iteration
pub fn KPermutationIterator(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        k: usize,
        indices: []usize,
        cycles: []usize,
        buffer: []T,
        first: bool,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, items: []const T, k: usize) !Self {
            if (k > items.len) return error.InvalidSize;

            const indices = try allocator.alloc(usize, items.len);
            errdefer allocator.free(indices);

            const cycles = try allocator.alloc(usize, k);
            errdefer allocator.free(cycles);

            const buffer = try allocator.alloc(T, k);

            for (indices, 0..) |*idx, i| {
                idx.* = i;
            }

            for (cycles, 0..) |*cycle, i| {
                cycle.* = items.len - i;
            }

            return Self{
                .items = items,
                .k = k,
                .indices = indices,
                .cycles = cycles,
                .buffer = buffer,
                .first = true,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.indices);
            self.allocator.free(self.cycles);
            self.allocator.free(self.buffer);
        }

        pub fn next(self: *Self) ?[]const T {
            if (self.k == 0 or self.k > self.items.len) return null;

            if (self.first) {
                self.first = false;
                // Fill buffer with first k items
                return self.getCurrentPermutation();
            }

            // Python-style itertools.permutations algorithm
            var i: usize = self.k;
            while (i > 0) {
                i -= 1;
                self.cycles[i] -= 1;

                if (self.cycles[i] == 0) {
                    // Rotate indices[i:] left by one
                    const temp = self.indices[i];
                    var j = i;
                    while (j < self.indices.len - 1) : (j += 1) {
                        self.indices[j] = self.indices[j + 1];
                    }
                    self.indices[self.indices.len - 1] = temp;
                    self.cycles[i] = self.items.len - i;
                } else {
                    const j = self.indices.len - self.cycles[i];
                    const temp = self.indices[i];
                    self.indices[i] = self.indices[j];
                    self.indices[j] = temp;

                    // Build and return current permutation
                    return self.getCurrentPermutation();
                }
            }

            return null;
        }

        fn getCurrentPermutation(self: *Self) []const T {
            // Fill internal buffer with current k-permutation
            for (0..self.k) |i| {
                self.buffer[i] = self.items[self.indices[i]];
            }
            return self.buffer;
        }

        pub fn collect(self: *Self, allocator: std.mem.Allocator) ![]T {
            var result = try allocator.alloc(T, self.k);
            for (0..self.k) |i| {
                result[i] = self.items[self.indices[i]];
            }
            return result;
        }
    };
}

/// Gosper's Hack for combinations (bitset-based, very fast)
/// Generates all n-bit numbers with exactly k bits set
pub fn GosperCombinations() type {
    return struct {
        const Self = @This();

        n: usize,
        k: usize,
        current: usize,
        limit: usize,

        pub fn init(n: usize, k: usize) Self {
            // Check for overflow: n and k must fit in usize bit operations
            const max_bits = @bitSizeOf(usize) - 1;
            if (k > n or k == 0 or n > max_bits or k > max_bits) {
                return Self{
                    .n = n,
                    .k = k,
                    .current = 0,
                    .limit = 0,
                };
            }

            const initial = (@as(usize, 1) << @intCast(k)) - 1;
            return Self{
                .n = n,
                .k = k,
                .current = initial,
                .limit = @as(usize, 1) << @intCast(n),
            };
        }

        pub inline fn next(self: *Self) ?usize {
            if (self.current >= self.limit) return null;

            const result = self.current;

            // Gosper's Hack: compute next combination
            const c = self.current & -%self.current;
            const r = self.current + c;
            self.current = (((r ^ self.current) >> 2) / c) | r;

            return result;
        }

        pub fn indicesToArray(bitset: usize, allocator: std.mem.Allocator) ![]usize {
            var count: usize = 0;
            var temp = bitset;
            while (temp != 0) : (temp >>= 1) {
                if (temp & 1 != 0) count += 1;
            }

            var result = try allocator.alloc(usize, count);
            var idx: usize = 0;
            var pos: usize = 0;
            temp = bitset;

            while (temp != 0) : (pos += 1) {
                if (temp & 1 != 0) {
                    result[idx] = pos;
                    idx += 1;
                }
                temp >>= 1;
            }

            return result;
        }
    };
}

/// Cartesian product of two sequences
pub fn CartesianProduct(comptime T1: type, comptime T2: type) type {
    return struct {
        const Self = @This();

        pub const Pair = struct {
            first: T1,
            second: T2,
        };

        first: []const T1,
        second: []const T2,
        i: usize,
        j: usize,

        pub fn init(first: []const T1, second: []const T2) Self {
            return Self{
                .first = first,
                .second = second,
                .i = 0,
                .j = 0,
            };
        }

        pub inline fn next(self: *Self) ?Pair {
            if (self.first.len == 0 or self.second.len == 0) return null;
            if (self.i >= self.first.len) return null;

            const pair = Pair{
                .first = self.first[self.i],
                .second = self.second[self.j],
            };

            self.j += 1;
            if (self.j >= self.second.len) {
                self.j = 0;
                self.i += 1;
            }

            return pair;
        }
    };
}

/// Power set iterator (all subsets)
pub fn PowerSet(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []const T,
        current: usize,
        limit: usize,

        pub fn init(items: []const T) Self {
            // Check for overflow: items.len must fit in usize bit operations
            const max_bits = @bitSizeOf(usize) - 1;
            const limit = if (items.len > max_bits)
                0 // Invalid, will cause next() to immediately return null
            else
                @as(usize, 1) << @intCast(items.len);

            return Self{
                .items = items,
                .current = 0,
                .limit = limit,
            };
        }

        pub inline fn next(self: *Self) ?usize {
            if (self.current >= self.limit) return null;

            const result = self.current;
            self.current += 1;
            return result;
        }

        pub fn collectSubset(
            self: *const Self,
            bitset: usize,
            allocator: std.mem.Allocator,
        ) ![]T {
            var count: usize = 0;
            var temp = bitset;
            while (temp != 0) : (temp >>= 1) {
                if (temp & 1 != 0) count += 1;
            }

            var result = try allocator.alloc(T, count);
            var idx: usize = 0;

            for (self.items, 0..) |item, i| {
                if ((bitset >> @intCast(i)) & 1 != 0) {
                    result[idx] = item;
                    idx += 1;
                }
            }

            return result;
        }
    };
}
// ANCHOR_END: advanced_algorithms

// ============================================================================
// TESTS
// ============================================================================

test "basic combinations 3 choose 2" {
    const items = [_]i32{ 1, 2, 3 };

    var result = try generateCombinations(i32, testing.allocator, &items, 2);
    defer {
        for (result.items) |combo| {
            testing.allocator.free(combo);
        }
        result.deinit(testing.allocator);
    }

    try testing.expectEqual(@as(usize, 3), result.items.len);
    // {1,2}, {1,3}, {2,3}
}

test "basic permutations of 3 items" {
    const items = [_]i32{ 1, 2, 3 };

    var result = try generatePermutations(i32, testing.allocator, &items);
    defer {
        for (result.items) |perm| {
            testing.allocator.free(perm);
        }
        result.deinit(testing.allocator);
    }

    try testing.expectEqual(@as(usize, 6), result.items.len);
    // 3! = 6 permutations
}

test "lexicographic permutation iterator" {
    const items = [_]i32{ 1, 2, 3 };

    var iter = try PermutationIterator(i32).init(testing.allocator, &items);
    defer iter.deinit();

    var count: usize = 0;
    while (iter.next()) |_| {
        count += 1;
    }

    try testing.expectEqual(@as(usize, 6), count);
}

test "gosper combinations basic" {
    var iter = GosperCombinations().init(5, 3);

    var count: usize = 0;
    while (iter.next()) |_| {
        count += 1;
    }

    // C(5,3) = 10
    try testing.expectEqual(@as(usize, 10), count);
}

test "gosper combinations indices" {
    var iter = GosperCombinations().init(4, 2);

    const first = iter.next().?;
    const indices = try GosperCombinations().indicesToArray(first, testing.allocator);
    defer testing.allocator.free(indices);

    try testing.expectEqual(@as(usize, 2), indices.len);
    try testing.expectEqual(@as(usize, 0), indices[0]);
    try testing.expectEqual(@as(usize, 1), indices[1]);
}

test "cartesian product" {
    const first = [_]i32{ 1, 2 };
    const second = [_]u8{ 'a', 'b', 'c' };

    var iter = CartesianProduct(i32, u8).init(&first, &second);

    var count: usize = 0;
    while (iter.next()) |_| {
        count += 1;
    }

    try testing.expectEqual(@as(usize, 6), count);
}

test "power set" {
    const items = [_]i32{ 1, 2, 3 };

    var iter = PowerSet(i32).init(&items);

    var count: usize = 0;
    while (iter.next()) |_| {
        count += 1;
    }

    // 2^3 = 8 subsets
    try testing.expectEqual(@as(usize, 8), count);
}

test "power set collect subset" {
    const items = [_]i32{ 1, 2, 3 };
    const iter = PowerSet(i32).init(&items);

    // Bitset 5 (binary 101) represents {1, 3}
    const subset = try iter.collectSubset(5, testing.allocator);
    defer testing.allocator.free(subset);

    try testing.expectEqual(@as(usize, 2), subset.len);
    try testing.expectEqual(@as(i32, 1), subset[0]);
    try testing.expectEqual(@as(i32, 3), subset[1]);
}

test "empty combinations" {
    const items = [_]i32{ 1, 2, 3 };

    var result = try generateCombinations(i32, testing.allocator, &items, 0);
    defer result.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 0), result.items.len);
}

test "combinations k > n" {
    const items = [_]i32{ 1, 2 };

    var result = try generateCombinations(i32, testing.allocator, &items, 5);
    defer result.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 0), result.items.len);
}

test "memory safety - permutations cleanup" {
    const items = [_]i32{ 1, 2, 3, 4 };

    var result = try generatePermutations(i32, testing.allocator, &items);
    defer {
        for (result.items) |perm| {
            testing.allocator.free(perm);
        }
        result.deinit(testing.allocator);
    }

    try testing.expect(result.items.len > 0);
}

test "security - gosper bounds check" {
    var iter = GosperCombinations().init(10, 20);

    try testing.expectEqual(@as(?usize, null), iter.next());
}

test "combination iterator returns actual values" {
    const items = [_]i32{ 1, 2, 3, 4 };

    var iter = try CombinationIterator(i32).init(testing.allocator, &items, 2);
    defer iter.deinit();

    // First combination should be {1, 2}
    const first = iter.next().?;
    try testing.expectEqual(@as(usize, 2), first.len);
    try testing.expectEqual(@as(i32, 1), first[0]);
    try testing.expectEqual(@as(i32, 2), first[1]);

    // Second combination should be {1, 3}
    const second = iter.next().?;
    try testing.expectEqual(@as(i32, 1), second[0]);
    try testing.expectEqual(@as(i32, 3), second[1]);

    // Count remaining
    var count: usize = 2;
    while (iter.next()) |_| {
        count += 1;
    }

    // C(4,2) = 6 total combinations
    try testing.expectEqual(@as(usize, 6), count);
}

test "k-permutation iterator returns actual values" {
    const items = [_]i32{ 1, 2, 3 };

    var iter = try KPermutationIterator(i32).init(testing.allocator, &items, 2);
    defer iter.deinit();

    // First k-permutation should be {1, 2}
    const first = iter.next().?;
    try testing.expectEqual(@as(usize, 2), first.len);
    try testing.expectEqual(@as(i32, 1), first[0]);
    try testing.expectEqual(@as(i32, 2), first[1]);

    // Count all k-permutations
    var count: usize = 1;
    while (iter.next()) |perm| {
        count += 1;
        // Verify length is always k
        try testing.expectEqual(@as(usize, 2), perm.len);
    }

    // P(3,2) = 3!/(3-2)! = 6
    try testing.expectEqual(@as(usize, 6), count);
}

test "security - recursion depth limit" {
    const items = [_]i32{1} ** 2000; // Large array

    const result = generateCombinations(i32, testing.allocator, &items, 1500);
    try testing.expectError(error.RecursionLimitExceeded, result);
}

test "security - overflow protection gosper" {
    // Try to create with n > bitsize - should return empty iterator
    const max_bits = @bitSizeOf(usize);
    var iter = GosperCombinations().init(max_bits + 10, 5);

    // Should immediately return null due to overflow protection
    try testing.expectEqual(@as(?usize, null), iter.next());
}

test "security - overflow protection powerset" {
    const max_bits = @bitSizeOf(usize);
    const items = [_]i32{1} ** (max_bits + 10);

    var iter = PowerSet(i32).init(&items);

    // Should immediately return null due to overflow protection
    try testing.expectEqual(@as(?usize, null), iter.next());
}
