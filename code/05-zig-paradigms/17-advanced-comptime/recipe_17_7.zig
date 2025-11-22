// Recipe 17.7: Comptime Function Memoization and Optimization
// This recipe demonstrates how to cache expensive compile-time computations,
// build lookup tables, and create optimization hints at compile time.

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_memoization
/// Fibonacci with compile-time memoization via lookup table
fn fibonacci(comptime n: u32) u64 {
    if (n == 0) return 0;
    if (n == 1) return 1;

    var cache: [n + 1]u64 = undefined;
    cache[0] = 0;
    cache[1] = 1;

    for (2..n + 1) |i| {
        cache[i] = cache[i - 1] + cache[i - 2];
    }

    return cache[n];
}

test "basic memoization" {
    try testing.expectEqual(@as(u64, 0), comptime fibonacci(0));
    try testing.expectEqual(@as(u64, 1), comptime fibonacci(1));
    try testing.expectEqual(@as(u64, 55), comptime fibonacci(10));
    try testing.expectEqual(@as(u64, 6765), comptime fibonacci(20));

    // Computed at compile time, zero runtime cost
    const fib30 = comptime fibonacci(30);
    try testing.expectEqual(@as(u64, 832040), fib30);
}
// ANCHOR_END: basic_memoization

// ANCHOR: precompute_table
/// Generate a complete lookup table at compile time
fn generateFibTable(comptime max_n: usize) [max_n]u64 {
    comptime {
        var table: [max_n]u64 = undefined;
        table[0] = 0;
        if (max_n > 1) {
            table[1] = 1;

            for (2..max_n) |i| {
                table[i] = table[i - 1] + table[i - 2];
            }
        }

        return table;
    }
}

const fib_table = generateFibTable(50);

test "precomputed lookup table" {
    try testing.expectEqual(@as(u64, 55), fib_table[10]);
    try testing.expectEqual(@as(u64, 6765), fib_table[20]);
    try testing.expectEqual(@as(u64, 832040), fib_table[30]);

    // Instant O(1) lookup, no computation
    const val = fib_table[40];
    try testing.expectEqual(@as(u64, 102334155), val);
}
// ANCHOR_END: precompute_table

// ANCHOR: prime_cache
/// Cache prime numbers at compile time
fn isPrime(comptime n: u64) bool {
    if (n < 2) return false;
    if (n == 2) return true;
    if (n % 2 == 0) return false;

    var i: u64 = 3;
    while (i * i <= n) : (i += 2) {
        if (n % i == 0) return false;
    }

    return true;
}

fn generatePrimes(comptime max: u64) []const u64 {
    comptime {
        @setEvalBranchQuota(100000);

        var count: usize = 0;
        var n: u64 = 2;
        while (n < max) : (n += 1) {
            if (isPrime(n)) {
                count += 1;
            }
        }

        var primes: [count]u64 = undefined;
        var idx: usize = 0;
        n = 2;
        while (n < max) : (n += 1) {
            if (isPrime(n)) {
                primes[idx] = n;
                idx += 1;
            }
        }

        const result = primes;
        return &result;
    }
}

const primes_under_100 = generatePrimes(100);

test "cached prime numbers" {
    try testing.expectEqual(@as(usize, 25), primes_under_100.len);
    try testing.expectEqual(@as(u64, 2), primes_under_100[0]);
    try testing.expectEqual(@as(u64, 97), primes_under_100[24]);

    // Check a few primes
    try testing.expect(std.mem.indexOfScalar(u64, primes_under_100, 17) != null);
    try testing.expect(std.mem.indexOfScalar(u64, primes_under_100, 53) != null);
}
// ANCHOR_END: prime_cache

// ANCHOR: factorial_table
/// Precompute factorial values
fn factorial(comptime n: u64) u64 {
    if (n == 0 or n == 1) return 1;

    var result: u64 = 1;
    for (2..n + 1) |i| {
        result *= i;
    }

    return result;
}

fn generateFactorialTable(comptime max: usize) [max]u64 {
    comptime {
        var table: [max]u64 = undefined;

        for (0..max) |i| {
            table[i] = factorial(i);
        }

        return table;
    }
}

const factorials = generateFactorialTable(21);

test "factorial table" {
    try testing.expectEqual(@as(u64, 1), factorials[0]);
    try testing.expectEqual(@as(u64, 1), factorials[1]);
    try testing.expectEqual(@as(u64, 2), factorials[2]);
    try testing.expectEqual(@as(u64, 6), factorials[3]);
    try testing.expectEqual(@as(u64, 24), factorials[4]);
    try testing.expectEqual(@as(u64, 120), factorials[5]);
    try testing.expectEqual(@as(u64, 3628800), factorials[10]);
}
// ANCHOR_END: factorial_table

// ANCHOR: string_hash_table
/// Precompute string hashes
fn hashString(comptime str: []const u8) u64 {
    var hash: u64 = 0;
    for (str) |byte| {
        hash = hash *% 31 +% byte;
    }
    return hash;
}

fn hashStringRuntime(str: []const u8) u64 {
    var hash: u64 = 0;
    for (str) |byte| {
        hash = hash *% 31 +% byte;
    }
    return hash;
}

fn StringHashMap(comptime strings: []const []const u8) type {
    return struct {
        const Entry = struct {
            hash: u64,
            str: []const u8,
        };

        const entries = blk: {
            var result: [strings.len]Entry = undefined;
            for (strings, 0..) |str, i| {
                result[i] = .{
                    .hash = hashString(str),
                    .str = str,
                };
            }
            break :blk result;
        };

        pub fn getHash(str: []const u8) ?u64 {
            const h = hashStringRuntime(str);
            inline for (entries) |entry| {
                if (entry.hash == h and std.mem.eql(u8, entry.str, str)) {
                    return entry.hash;
                }
            }
            return null;
        }

        pub fn contains(str: []const u8) bool {
            return getHash(str) != null;
        }
    };
}

const Keywords = StringHashMap(&[_][]const u8{
    "if",
    "else",
    "while",
    "for",
    "return",
    "break",
    "continue",
});

test "string hash table" {
    try testing.expect(Keywords.contains("if"));
    try testing.expect(Keywords.contains("while"));
    try testing.expect(!Keywords.contains("unknown"));

    const hash = Keywords.getHash("return");
    try testing.expect(hash != null);
}
// ANCHOR_END: string_hash_table

// ANCHOR: power_of_two
/// Cache powers of 2 for fast lookups
fn generatePowersOfTwo(comptime max_exp: usize) [max_exp]u64 {
    comptime {
        var table: [max_exp]u64 = undefined;
        var pow: u64 = 1;

        for (0..max_exp) |i| {
            table[i] = pow;
            if (i + 1 < max_exp) {
                pow *= 2;
            }
        }

        return table;
    }
}

const powers_of_2 = generatePowersOfTwo(63);

test "powers of two table" {
    try testing.expectEqual(@as(u64, 1), powers_of_2[0]);
    try testing.expectEqual(@as(u64, 2), powers_of_2[1]);
    try testing.expectEqual(@as(u64, 4), powers_of_2[2]);
    try testing.expectEqual(@as(u64, 1024), powers_of_2[10]);
    try testing.expectEqual(@as(u64, 1 << 20), powers_of_2[20]);
}
// ANCHOR_END: power_of_two

// ANCHOR: sin_table
/// Precompute sine values for fast lookup
fn generateSinTable(comptime resolution: usize) [resolution]f64 {
    comptime {
        var table: [resolution]f64 = undefined;
        const step = 2.0 * std.math.pi / @as(f64, @floatFromInt(resolution));

        for (0..resolution) |i| {
            const angle = @as(f64, @floatFromInt(i)) * step;
            table[i] = @sin(angle);
        }

        return table;
    }
}

const sin_table = generateSinTable(360);

fn fastSin(angle_degrees: f64) f64 {
    const normalized = @mod(angle_degrees, 360.0);
    const index = @as(usize, @intFromFloat(@round(normalized)));
    return sin_table[index];
}

test "sine lookup table" {
    const epsilon = 0.01;

    // 0 degrees
    try testing.expect(@abs(fastSin(0.0) - 0.0) < epsilon);

    // 90 degrees
    try testing.expect(@abs(fastSin(90.0) - 1.0) < epsilon);

    // 180 degrees
    try testing.expect(@abs(fastSin(180.0) - 0.0) < epsilon);

    // 270 degrees
    try testing.expect(@abs(fastSin(270.0) - (-1.0)) < epsilon);
}
// ANCHOR_END: sin_table

// ANCHOR: memoized_generic
/// Generic memoization wrapper
fn Memoized(comptime F: type, comptime f: F, comptime max_n: usize) type {
    return struct {
        const cache = blk: {
            var result: [max_n]u64 = undefined;
            for (0..max_n) |i| {
                result[i] = f(i);
            }
            break :blk result;
        };

        pub fn call(n: usize) u64 {
            if (n >= max_n) {
                @panic("Input exceeds cache size");
            }
            return cache[n];
        }
    };
}

fn slowSquare(n: usize) u64 {
    return @as(u64, n) * @as(u64, n);
}

const MemoizedSquare = Memoized(@TypeOf(slowSquare), slowSquare, 100);

test "generic memoization" {
    try testing.expectEqual(@as(u64, 0), MemoizedSquare.call(0));
    try testing.expectEqual(@as(u64, 1), MemoizedSquare.call(1));
    try testing.expectEqual(@as(u64, 100), MemoizedSquare.call(10));
    try testing.expectEqual(@as(u64, 9801), MemoizedSquare.call(99));
}
// ANCHOR_END: memoized_generic

// ANCHOR: build_time_optimization
/// Choose implementation based on compile-time computation
fn optimizedSum(comptime size: usize) fn ([]const u32) u64 {
    if (size <= 4) {
        // For small arrays, use simple loop
        return struct {
            fn sum(arr: []const u32) u64 {
                var result: u64 = 0;
                for (arr) |val| {
                    result += val;
                }
                return result;
            }
        }.sum;
    } else {
        // For larger arrays, use unrolled loop
        return struct {
            fn sum(arr: []const u32) u64 {
                var result: u64 = 0;
                var i: usize = 0;

                // Process 4 at a time
                while (i + 4 <= arr.len) : (i += 4) {
                    result += arr[i];
                    result += arr[i + 1];
                    result += arr[i + 2];
                    result += arr[i + 3];
                }

                // Handle remainder
                while (i < arr.len) : (i += 1) {
                    result += arr[i];
                }

                return result;
            }
        }.sum;
    }
}

test "compile-time optimization selection" {
    const small_arr = [_]u32{ 1, 2, 3 };
    const small_fn = optimizedSum(small_arr.len);
    try testing.expectEqual(@as(u64, 6), small_fn(&small_arr));

    const large_arr = [_]u32{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const large_fn = optimizedSum(large_arr.len);
    try testing.expectEqual(@as(u64, 36), large_fn(&large_arr));
}
// ANCHOR_END: build_time_optimization
