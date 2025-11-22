// ANCHOR: basic_build
const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard optimization options
    const optimize = b.standardOptimizeOption(.{});

    // Standard target options
    const target = b.standardTargetOptions(.{});

    // Create an executable
    const exe = b.addExecutable(.{
        .name = "hello",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Install the executable
    b.installArtifact(exe);

    // Create a run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // Allow passing arguments
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Create the run step
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);
}
// ANCHOR_END: basic_build
