const std = @import("std");
const mylib = @import("mylib");

pub fn main() !void {
    std.debug.print("Application 1\n", .{});
    const result = mylib.add(10, 20);
    std.debug.print("10 + 20 = {d}\n", .{result});
    mylib.greet("from App1");
}
