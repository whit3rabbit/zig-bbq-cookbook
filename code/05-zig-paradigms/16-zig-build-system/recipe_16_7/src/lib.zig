const std = @import("std");
const testing = std.testing;

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

pub fn multiply(a: i32, b: i32) i32 {
    return a * b;
}

test "add" {
    try testing.expectEqual(@as(i32, 5), add(2, 3));
}

test "fast: multiply" {
    try testing.expectEqual(@as(i32, 6), multiply(2, 3));
}

test "multiply zero" {
    try testing.expectEqual(@as(i32, 0), multiply(5, 0));
}
