// Basic math operations module
// This is a leaf module in the hierarchy

const std = @import("std");

/// Add two numbers
pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

/// Subtract two numbers
pub fn subtract(a: i32, b: i32) i32 {
    return a - b;
}

/// Multiply two numbers
pub fn multiply(a: i32, b: i32) i32 {
    return a * b;
}

/// Divide two numbers (returns error on division by zero)
pub fn divide(a: i32, b: i32) !i32 {
    if (b == 0) {
        return error.DivisionByZero;
    }
    return @divTrunc(a, b);
}
