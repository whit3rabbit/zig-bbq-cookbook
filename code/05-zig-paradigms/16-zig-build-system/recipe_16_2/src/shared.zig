const std = @import("std");

export fn sharedAdd(a: i32, b: i32) i32 {
    return a + b;
}

export fn sharedMultiply(a: i32, b: i32) i32 {
    return a * b;
}

test "shared library functions" {
    const testing = std.testing;
    try testing.expectEqual(@as(i32, 8), sharedAdd(3, 5));
    try testing.expectEqual(@as(i32, 15), sharedMultiply(3, 5));
}
