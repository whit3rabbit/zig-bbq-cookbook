// ANCHOR: multiple_artifacts
const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    // Build a library
    const lib = b.addStaticLibrary(.{
        .name = "mylib",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lib.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(lib);

    // Build first executable that uses the library
    const exe1 = b.addExecutable(.{
        .name = "app1",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/app1.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe1.root_module.linkLibrary(lib);
    b.installArtifact(exe1);

    // Build second executable
    const exe2 = b.addExecutable(.{
        .name = "app2",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/app2.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe2.root_module.linkLibrary(lib);
    b.installArtifact(exe2);

    // Create run steps for each executable
    const run_app1 = b.addRunArtifact(exe1);
    const run_app2 = b.addRunArtifact(exe2);

    const run_app1_step = b.step("run-app1", "Run application 1");
    run_app1_step.dependOn(&run_app1.step);

    const run_app2_step = b.step("run-app2", "Run application 2");
    run_app2_step.dependOn(&run_app2.step);

    // Build a shared library
    const shared_lib = b.addSharedLibrary(.{
        .name = "shared",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/shared.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
    });
    b.installArtifact(shared_lib);
}
// ANCHOR_END: multiple_artifacts
