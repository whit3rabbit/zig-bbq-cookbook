const std = @import("std");
const build_options = @import("build_options");

pub fn main() !void {
    std.debug.print("Server: {s}\n", .{build_options.server_name});
    std.debug.print("Max Connections: {d}\n", .{build_options.max_connections});
    std.debug.print("Logging: {}\n", .{build_options.enable_logging});
    std.debug.print("Environment: {s}\n", .{@tagName(build_options.environment)});
    std.debug.print("Version: {s}\n", .{build_options.version});
    std.debug.print("Build Date: {s}\n", .{build_options.build_date});

    if (build_options.enable_logging) {
        std.debug.print("[DEBUG] Logging is enabled\n", .{});
    }
}
