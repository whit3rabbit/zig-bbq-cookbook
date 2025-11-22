const std = @import("std");

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

pub fn multiply(a: i32, b: i32) i32 {
    return a * b;
}

pub fn greet(name: []const u8) void {
    std.debug.print("Hello, {s}!\n", .{name});
}

test "library functions" {
    const testing = std.testing;
    try testing.expectEqual(@as(i32, 5), add(2, 3));
    try testing.expectEqual(@as(i32, 6), multiply(2, 3));
}
