const std = @import("std");
const testing = std.testing;

// ANCHOR: panic_handler
// Custom panic handler required for freestanding targets
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = msg;
    _ = error_return_trace;
    _ = ret_addr;
    while (true) {}
}
// ANCHOR_END: panic_handler

// ANCHOR: basic_export
// Export a simple function that JavaScript can call
export fn add(a: i32, b: i32) i32 {
    return a + b;
}
// ANCHOR_END: basic_export

// ANCHOR: multiply_export
// Another exported function
export fn multiply(a: i32, b: i32) i32 {
    return a * b;
}
// ANCHOR_END: multiply_export

// ANCHOR: fibonacci_export
// More complex exported function
export fn fibonacci(n: i32) i32 {
    if (n <= 1) return n;

    var prev: i32 = 0;
    var curr: i32 = 1;
    var i: i32 = 2;

    while (i <= n) : (i += 1) {
        const next = prev + curr;
        prev = curr;
        curr = next;
    }

    return curr;
}
// ANCHOR_END: fibonacci_export

// ANCHOR: is_prime_export
// Check if a number is prime
export fn isPrime(n: i32) bool {
    if (n < 2) return false;
    if (n == 2) return true;
    if (@rem(n, 2) == 0) return false;

    var i: i32 = 3;
    while (i * i <= n) : (i += 2) {
        if (@rem(n, i) == 0) return false;
    }

    return true;
}
// ANCHOR_END: is_prime_export

// Tests verify the logic works correctly
// Note: These tests run on the host system, not in WASM

// ANCHOR: test_add
test "add function" {
    try testing.expectEqual(@as(i32, 5), add(2, 3));
    try testing.expectEqual(@as(i32, 0), add(-5, 5));
    try testing.expectEqual(@as(i32, -10), add(-7, -3));
}
// ANCHOR_END: test_add

// ANCHOR: test_multiply
test "multiply function" {
    try testing.expectEqual(@as(i32, 6), multiply(2, 3));
    try testing.expectEqual(@as(i32, -25), multiply(-5, 5));
    try testing.expectEqual(@as(i32, 21), multiply(-7, -3));
    try testing.expectEqual(@as(i32, 0), multiply(0, 100));
}
// ANCHOR_END: test_multiply

// ANCHOR: test_fibonacci
test "fibonacci function" {
    try testing.expectEqual(@as(i32, 0), fibonacci(0));
    try testing.expectEqual(@as(i32, 1), fibonacci(1));
    try testing.expectEqual(@as(i32, 1), fibonacci(2));
    try testing.expectEqual(@as(i32, 2), fibonacci(3));
    try testing.expectEqual(@as(i32, 3), fibonacci(4));
    try testing.expectEqual(@as(i32, 5), fibonacci(5));
    try testing.expectEqual(@as(i32, 8), fibonacci(6));
    try testing.expectEqual(@as(i32, 55), fibonacci(10));
}
// ANCHOR_END: test_fibonacci

// ANCHOR: test_is_prime
test "isPrime function" {
    try testing.expect(!isPrime(0));
    try testing.expect(!isPrime(1));
    try testing.expect(isPrime(2));
    try testing.expect(isPrime(3));
    try testing.expect(!isPrime(4));
    try testing.expect(isPrime(5));
    try testing.expect(!isPrime(6));
    try testing.expect(isPrime(7));
    try testing.expect(!isPrime(8));
    try testing.expect(!isPrime(9));
    try testing.expect(!isPrime(10));
    try testing.expect(isPrime(11));
    try testing.expect(isPrime(13));
    try testing.expect(!isPrime(15));
    try testing.expect(isPrime(17));
}
// ANCHOR_END: test_is_prime

// ANCHOR: test_edge_cases
test "edge cases" {
    // Test with maximum values
    const max_i32 = std.math.maxInt(i32);
    try testing.expectEqual(max_i32, add(max_i32, 0));

    // Test with minimum values
    const min_i32 = std.math.minInt(i32);
    try testing.expectEqual(min_i32, add(min_i32, 0));
}
// ANCHOR_END: test_edge_cases
