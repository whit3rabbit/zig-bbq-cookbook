// Utility functions module
// This is a peer module to math.zig

const std = @import("std");

/// Convert integer to string
pub fn intToString(allocator: std.mem.Allocator, value: i32) ![]u8 {
    return std.fmt.allocPrint(allocator, "{d}", .{value});
}

/// Check if string is numeric
pub fn isNumeric(str: []const u8) bool {
    if (str.len == 0) return false;

    var start: usize = 0;
    if (str[0] == '-' or str[0] == '+') {
        if (str.len == 1) return false;
        start = 1;
    }

    for (str[start..]) |c| {
        if (c < '0' or c > '9') return false;
    }
    return true;
}

/// Parse integer from string
pub fn parseInt(str: []const u8) !i32 {
    return std.fmt.parseInt(i32, str, 10);
}

/// Clamp value between min and max
pub fn clamp(value: i32, min: i32, max: i32) i32 {
    if (value < min) return min;
    if (value > max) return max;
    return value;
}
