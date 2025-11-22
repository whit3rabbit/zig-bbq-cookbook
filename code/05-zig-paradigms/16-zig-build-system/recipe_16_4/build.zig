// ANCHOR: custom_steps
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create executable
    const exe = b.addExecutable(.{
        .name = "myapp",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);

    // Custom run step with arguments
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // Forward command line arguments
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);

    // Custom step: Run formatter
    const fmt_cmd = b.addSystemCommand(&[_][]const u8{
        "zig",
        "fmt",
        "src",
    });

    const fmt_step = b.step("fmt", "Format source code");
    fmt_step.dependOn(&fmt_cmd.step);

    // Custom step: Generate code
    const codegen_cmd = b.addSystemCommand(&[_][]const u8{
        "echo",
        "// Generated code",
    });

    const codegen_output = codegen_cmd.captureStdOut();
    const write_generated = b.addWriteFiles();
    _ = write_generated.addCopyFile(codegen_output, "generated.zig");

    const codegen_step = b.step("codegen", "Generate code");
    codegen_step.dependOn(&write_generated.step);

    // Custom step: Run tests
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // Custom step: Check compilation without building
    const check = b.addExecutable(.{
        .name = "check",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const check_step = b.step("check", "Check compilation");
    check_step.dependOn(&check.step);

    // Custom composite step
    const all_step = b.step("all", "Run fmt, codegen, build, and test");
    all_step.dependOn(fmt_step);
    all_step.dependOn(codegen_step);
    all_step.dependOn(b.getInstallStep());
    all_step.dependOn(test_step);
}
// ANCHOR_END: custom_steps
