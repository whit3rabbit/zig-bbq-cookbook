// ANCHOR: using_dependencies
const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    // Get a dependency from build.zig.zon
    const my_dep = b.dependency("my-dependency", .{
        .target = target,
        .optimize = optimize,
    });

    // Create executable
    const exe = b.addExecutable(.{
        .name = "myapp",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Import the dependency as a module
    exe.root_module.addImport("my-dependency", my_dep.module("my-dependency"));

    b.installArtifact(exe);
}
// ANCHOR_END: using_dependencies
