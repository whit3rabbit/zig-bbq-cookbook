// Advanced math operations module
// This is a leaf module in the hierarchy

const std = @import("std");

/// Calculate power (a^b)
pub fn power(a: i32, b: u32) i64 {
    if (b == 0) return 1;

    var result: i64 = 1;
    var i: u32 = 0;
    while (i < b) : (i += 1) {
        result *= a;
    }
    return result;
}

/// Calculate factorial
pub fn factorial(n: u32) u64 {
    if (n == 0 or n == 1) return 1;

    var result: u64 = 1;
    var i: u32 = 2;
    while (i <= n) : (i += 1) {
        result *= i;
    }
    return result;
}

/// Check if number is prime
pub fn isPrime(n: u32) bool {
    if (n < 2) return false;
    if (n == 2) return true;
    if (n % 2 == 0) return false;

    var i: u32 = 3;
    while (i * i <= n) : (i += 2) {
        if (n % i == 0) return false;
    }
    return true;
}
