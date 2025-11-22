const std = @import("std");

pub fn main() !void {
    std.debug.print("Custom build steps example\n", .{});
}

test "basic test" {
    try std.testing.expect(true);
}
