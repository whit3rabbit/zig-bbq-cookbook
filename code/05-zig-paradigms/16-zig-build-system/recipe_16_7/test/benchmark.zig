const std = @import("std");
const testing = std.testing;

test "benchmark: performance" {
    var sum: u64 = 0;
    var i: u32 = 0;
    while (i < 1000) : (i += 1) {
        sum += i;
    }
    try testing.expect(sum > 0);
}
