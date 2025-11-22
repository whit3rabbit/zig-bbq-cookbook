// Logging module - used by other modules in the package
const std = @import("std");

pub const Level = enum {
    debug,
    info,
    warn,
    err,
};

pub fn log(level: Level, msg: []const u8) void {
    const prefix = switch (level) {
        .debug => "[DEBUG]",
        .info => "[INFO]",
        .warn => "[WARN]",
        .err => "[ERROR]",
    };
    std.debug.print("{s} {s}\n", .{ prefix, msg });
}

pub fn debug(msg: []const u8) void {
    log(.debug, msg);
}

pub fn info(msg: []const u8) void {
    log(.info, msg);
}
