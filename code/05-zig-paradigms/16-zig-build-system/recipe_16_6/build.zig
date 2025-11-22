// ANCHOR: build_options
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Boolean option
    const enable_logging = b.option(
        bool,
        "enable-logging",
        "Enable debug logging (default: false)",
    ) orelse false;

    // String option
    const server_name = b.option(
        []const u8,
        "server-name",
        "Server name (default: myserver)",
    ) orelse "myserver";

    // Integer option
    const max_connections = b.option(
        u32,
        "max-connections",
        "Maximum connections (default: 100)",
    ) orelse 100;

    // Enum option
    const Environment = enum { development, staging, production };
    const environment = b.option(
        Environment,
        "environment",
        "Deployment environment (default: development)",
    ) orelse .development;

    // Create a build options module
    const options = b.addOptions();
    options.addOption(bool, "enable_logging", enable_logging);
    options.addOption([]const u8, "server_name", server_name);
    options.addOption(u32, "max_connections", max_connections);
    options.addOption(Environment, "environment", environment);
    options.addOption([]const u8, "version", "1.0.0");
    options.addOption([]const u8, "build_date", getBuildDate(b));

    // Create executable with options
    const exe = b.addExecutable(.{
        .name = "myapp",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.root_module.addImport("build_options", options.createModule());
    b.installArtifact(exe);

    // Run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);

    // Print configuration
    const print_config = b.addSystemCommand(&[_][]const u8{"echo", "Build Configuration:"});
    const print_step = b.step("config", "Print build configuration");
    print_step.dependOn(&print_config.step);
}

fn getBuildDate(b: *std.Build) []const u8 {
    _ = b;
    return "2025-11-20";
}
// ANCHOR_END: build_options
