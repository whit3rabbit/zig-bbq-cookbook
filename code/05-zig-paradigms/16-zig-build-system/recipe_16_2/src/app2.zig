const std = @import("std");
const mylib = @import("mylib");

pub fn main() !void {
    std.debug.print("Application 2\n", .{});
    const result = mylib.multiply(5, 7);
    std.debug.print("5 * 7 = {d}\n", .{result});
    mylib.greet("from App2");
}
