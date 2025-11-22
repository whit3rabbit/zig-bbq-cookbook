// Recipe 3.11: Picking things at random
// Target Zig Version: 0.15.2
//
// This recipe demonstrates using Zig's random number generation facilities
// for various randomization tasks using std.rand.

const std = @import("std");
const testing = std.testing;
const Random = std.Random;

// ANCHOR: basic_random
/// Initialize a seeded PRNG
pub fn initPrng(seed: u64) Random.DefaultPrng {
    return Random.DefaultPrng.init(seed);
}

/// Generate random integer in range [min, max]
pub fn randomInRange(comptime T: type, rng: Random, min: T, max: T) T {
    return rng.intRangeAtMost(T, min, max);
}

/// Generate random integer less than bound [0, bound)
pub fn randomBelow(comptime T: type, rng: Random, bound: T) T {
    return rng.intRangeLessThan(T, 0, bound);
}

/// Generate random boolean with given probability (0.0 to 1.0)
pub fn randomBool(rng: Random, probability: f64) bool {
    return rng.float(f64) < probability;
}

/// Generate random float in range [0.0, 1.0)
pub fn randomFloat(comptime T: type, rng: Random) T {
    return rng.float(T);
}

/// Generate random float in range [min, max)
pub fn randomFloatInRange(comptime T: type, rng: Random, min: T, max: T) T {
    const r = rng.float(T);
    return min + r * (max - min);
}
// ANCHOR_END: basic_random

// ANCHOR: collection_sampling
/// Select random element from slice
pub fn randomChoice(comptime T: type, rng: Random, slice: []const T) ?T {
    if (slice.len == 0) return null;
    const index = rng.intRangeLessThan(usize, 0, slice.len);
    return slice[index];
}

/// Select N random elements from slice without replacement
pub fn randomSample(comptime T: type, allocator: std.mem.Allocator, rng: Random, slice: []const T, count: usize) ![]T {
    if (count > slice.len) return error.SampleTooLarge;
    if (count == 0) return try allocator.alloc(T, 0);

    // Copy slice to temporary array
    const temp = try allocator.alloc(T, slice.len);
    defer allocator.free(temp);
    @memcpy(temp, slice);

    // Shuffle first count elements using Fisher-Yates
    var i: usize = 0;
    while (i < count) : (i += 1) {
        const j = rng.intRangeAtMost(usize, i, slice.len - 1);
        const tmp = temp[i];
        temp[i] = temp[j];
        temp[j] = tmp;
    }

    // Return first count elements
    const result = try allocator.alloc(T, count);
    @memcpy(result, temp[0..count]);
    return result;
}

/// Shuffle slice in place using Fisher-Yates algorithm
pub fn shuffle(comptime T: type, rng: Random, slice: []T) void {
    if (slice.len < 2) return;

    var i: usize = slice.len - 1;
    while (i > 0) : (i -= 1) {
        const j = rng.intRangeLessThan(usize, 0, i + 1);
        const tmp = slice[i];
        slice[i] = slice[j];
        slice[j] = tmp;
    }
}

/// Generate random bytes
pub fn randomBytes(rng: Random, buffer: []u8) void {
    rng.bytes(buffer);
}

/// Generate random hex string
pub fn randomHexString(allocator: std.mem.Allocator, rng: Random, length: usize) ![]u8 {
    const hex_chars = "0123456789abcdef";
    const result = try allocator.alloc(u8, length);
    errdefer allocator.free(result);

    for (result) |*c| {
        const index = rng.intRangeLessThan(usize, 0, hex_chars.len);
        c.* = hex_chars[index];
    }

    return result;
}
// ANCHOR_END: collection_sampling

// ANCHOR: advanced_random
/// Weighted random choice
pub fn weightedChoice(comptime T: type, rng: Random, items: []const T, weights: []const f64) ?T {
    if (items.len == 0 or items.len != weights.len) return null;

    // Calculate total weight
    var total: f64 = 0.0;
    for (weights) |w| {
        total += w;
    }

    if (total <= 0.0) return null;

    // Generate random value in [0, total)
    const r = rng.float(f64) * total;

    // Find corresponding item
    var cumulative: f64 = 0.0;
    for (items, weights) |item, weight| {
        cumulative += weight;
        if (r < cumulative) return item;
    }

    // Fallback to last item (handles floating point edge cases)
    return items[items.len - 1];
}
// ANCHOR_END: advanced_random

test "initialize PRNG with seed" {
    const prng = initPrng(42);
    _ = prng;
}

test "generate random integers in range" {
    var prng = initPrng(12345);
    const rng = prng.random();

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const value = randomInRange(i32, rng, 1, 10);
        try testing.expect(value >= 1 and value <= 10);
    }
}

test "generate random integers below bound" {
    var prng = initPrng(54321);
    const rng = prng.random();

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const value = randomBelow(usize, rng, 50);
        try testing.expect(value < 50);
    }
}

test "generate random boolean" {
    var prng = initPrng(99999);
    const rng = prng.random();

    // With 100% probability
    try testing.expect(randomBool(rng, 1.0) == true);

    // With 0% probability
    try testing.expect(randomBool(rng, 0.0) == false);

    // With 50% probability (test that it varies)
    var true_count: usize = 0;
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        if (randomBool(rng, 0.5)) true_count += 1;
    }
    // Should be roughly 500, allow variance
    try testing.expect(true_count > 400 and true_count < 600);
}

test "generate random float" {
    var prng = initPrng(777);
    const rng = prng.random();

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const value = randomFloat(f64, rng);
        try testing.expect(value >= 0.0 and value < 1.0);
    }
}

test "generate random float in range" {
    var prng = initPrng(888);
    const rng = prng.random();

    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const value = randomFloatInRange(f64, rng, 5.0, 10.0);
        try testing.expect(value >= 5.0 and value < 10.0);
    }
}

test "select random element from slice" {
    var prng = initPrng(111);
    const rng = prng.random();

    const items = [_]i32{ 1, 2, 3, 4, 5 };

    var i: usize = 0;
    while (i < 50) : (i += 1) {
        const choice = randomChoice(i32, rng, &items);
        try testing.expect(choice != null);

        // Verify it's one of the items
        var found = false;
        for (items) |item| {
            if (choice.? == item) found = true;
        }
        try testing.expect(found);
    }
}

test "random choice from empty slice" {
    var prng = initPrng(222);
    const rng = prng.random();

    const empty: []const i32 = &[_]i32{};
    const choice = randomChoice(i32, rng, empty);
    try testing.expect(choice == null);
}

test "random sample without replacement" {
    var prng = initPrng(333);
    const rng = prng.random();

    const items = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };

    const sample = try randomSample(i32, testing.allocator, rng, &items, 5);
    defer testing.allocator.free(sample);

    try testing.expectEqual(@as(usize, 5), sample.len);

    // Check no duplicates
    var i: usize = 0;
    while (i < sample.len) : (i += 1) {
        var j: usize = i + 1;
        while (j < sample.len) : (j += 1) {
            try testing.expect(sample[i] != sample[j]);
        }
    }

    // Check all elements are from original
    for (sample) |elem| {
        var found = false;
        for (items) |item| {
            if (elem == item) found = true;
        }
        try testing.expect(found);
    }
}

test "random sample error cases" {
    var prng = initPrng(444);
    const rng = prng.random();

    const items = [_]i32{ 1, 2, 3 };

    // Sample larger than slice
    const result = randomSample(i32, testing.allocator, rng, &items, 5);
    try testing.expectError(error.SampleTooLarge, result);

    // Empty sample
    const empty_sample = try randomSample(i32, testing.allocator, rng, &items, 0);
    defer testing.allocator.free(empty_sample);
    try testing.expectEqual(@as(usize, 0), empty_sample.len);
}

test "shuffle array" {
    var prng = initPrng(555);
    const rng = prng.random();

    var items = [_]i32{ 1, 2, 3, 4, 5 };
    const original = items;

    shuffle(i32, rng, &items);

    // Should contain same elements (just reordered)
    for (original) |orig| {
        var found = false;
        for (items) |item| {
            if (orig == item) found = true;
        }
        try testing.expect(found);
    }
}

test "shuffle single element" {
    var prng = initPrng(666);
    const rng = prng.random();

    var items = [_]i32{42};
    shuffle(i32, rng, &items);
    try testing.expectEqual(@as(i32, 42), items[0]);
}

test "shuffle empty array" {
    var prng = initPrng(777);
    const rng = prng.random();

    var items: [0]i32 = undefined;
    shuffle(i32, rng, &items);
}

test "generate random bytes" {
    var prng = initPrng(888);
    const rng = prng.random();

    var buffer: [16]u8 = undefined;
    randomBytes(rng, &buffer);

    // Just verify we got some variation
    var all_same = true;
    const first = buffer[0];
    for (buffer) |byte| {
        if (byte != first) all_same = false;
    }
    try testing.expect(!all_same);
}

test "generate random hex string" {
    var prng = initPrng(999);
    const rng = prng.random();

    const hex = try randomHexString(testing.allocator, rng, 16);
    defer testing.allocator.free(hex);

    try testing.expectEqual(@as(usize, 16), hex.len);

    // Verify all characters are valid hex
    const valid_chars = "0123456789abcdef";
    for (hex) |c| {
        var found = false;
        for (valid_chars) |valid| {
            if (c == valid) found = true;
        }
        try testing.expect(found);
    }
}

test "weighted random choice" {
    var prng = initPrng(1010);
    const rng = prng.random();

    const items = [_][]const u8{ "rare", "common", "uncommon" };
    const weights = [_]f64{ 0.1, 0.7, 0.2 }; // 10%, 70%, 20%

    var counts = [_]usize{ 0, 0, 0 };

    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        const choice = weightedChoice([]const u8, rng, &items, &weights);
        try testing.expect(choice != null);

        if (std.mem.eql(u8, choice.?, "rare")) counts[0] += 1;
        if (std.mem.eql(u8, choice.?, "common")) counts[1] += 1;
        if (std.mem.eql(u8, choice.?, "uncommon")) counts[2] += 1;
    }

    // Common should be most frequent
    try testing.expect(counts[1] > counts[0]);
    try testing.expect(counts[1] > counts[2]);

    // Rare should be least frequent
    try testing.expect(counts[0] < counts[1]);
    try testing.expect(counts[0] < counts[2]);
}

test "weighted choice edge cases" {
    var prng = initPrng(1111);
    const rng = prng.random();

    const items = [_]i32{ 1, 2, 3 };

    // Empty arrays
    const empty_items: []const i32 = &[_]i32{};
    const empty_weights: []const f64 = &[_]f64{};
    try testing.expect(weightedChoice(i32, rng, empty_items, empty_weights) == null);

    // Mismatched lengths
    const bad_weights = [_]f64{1.0};
    try testing.expect(weightedChoice(i32, rng, &items, &bad_weights) == null);

    // All zero weights
    const zero_weights = [_]f64{ 0.0, 0.0, 0.0 };
    try testing.expect(weightedChoice(i32, rng, &items, &zero_weights) == null);
}

test "deterministic seeding" {
    // Same seed should produce same sequence
    var prng1 = initPrng(42);
    var prng2 = initPrng(42);

    const rng1 = prng1.random();
    const rng2 = prng2.random();

    var i: usize = 0;
    while (i < 10) : (i += 1) {
        const val1 = rng1.int(u32);
        const val2 = rng2.int(u32);
        try testing.expectEqual(val1, val2);
    }
}

test "different seeds produce different sequences" {
    var prng1 = initPrng(42);
    var prng2 = initPrng(43);

    const rng1 = prng1.random();
    const rng2 = prng2.random();

    const val1 = rng1.int(u64);
    const val2 = rng2.int(u64);

    try testing.expect(val1 != val2);
}

test "memory safety - no allocation for basic operations" {
    var prng = initPrng(1234);
    const rng = prng.random();

    // These operations don't allocate
    _ = randomInRange(i32, rng, 1, 100);
    _ = randomFloat(f64, rng);
    _ = randomBool(rng, 0.5);

    var buffer: [32]u8 = undefined;
    randomBytes(rng, &buffer);
}

test "security - cryptographic note" {
    // DefaultPrng is NOT cryptographically secure
    // For security-critical applications, use std.crypto.random
    const prng = initPrng(42);
    _ = prng;

    // For comparison, std.crypto.random is available but not tested here
    // as it requires OS entropy and isn't deterministic
}
