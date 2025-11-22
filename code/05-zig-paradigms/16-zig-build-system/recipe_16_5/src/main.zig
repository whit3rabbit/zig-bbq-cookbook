const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    std.debug.print("Running on {s}-{s}\n", .{
        @tagName(builtin.cpu.arch),
        @tagName(builtin.os.tag),
    });
}
