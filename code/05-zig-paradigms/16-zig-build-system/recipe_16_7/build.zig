// ANCHOR: testing_setup
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create library
    const lib = b.addStaticLibrary(.{
        .name = "mylib",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lib.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(lib);

    // Unit tests for the library
    const lib_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lib.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_lib_tests = b.addRunArtifact(lib_tests);

    // Integration tests
    const integration_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/integration.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Link integration tests with the library
    integration_tests.root_module.linkLibrary(lib);
    const run_integration_tests = b.addRunArtifact(integration_tests);

    // Default test step (runs all tests)
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_lib_tests.step);
    test_step.dependOn(&run_integration_tests.step);

    // Unit tests only
    const unit_test_step = b.step("test-unit", "Run unit tests");
    unit_test_step.dependOn(&run_lib_tests.step);

    // Integration tests only
    const integration_test_step = b.step("test-integration", "Run integration tests");
    integration_test_step.dependOn(&run_integration_tests.step);

    // Filtered tests
    const fast_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lib.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    fast_tests.filters = &[_][]const u8{"fast"};

    const run_fast_tests = b.addRunArtifact(fast_tests);
    const fast_test_step = b.step("test-fast", "Run fast tests only");
    fast_test_step.dependOn(&run_fast_tests.step);

    // Benchmark tests
    const bench_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/benchmark.zig"),
            .target = target,
            .optimize = .ReleaseFast,
        }),
    });

    const run_bench = b.addRunArtifact(bench_tests);
    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&run_bench.step);

    // Create executable for testing
    const exe = b.addExecutable(.{
        .name = "myapp",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.root_module.linkLibrary(lib);
    b.installArtifact(exe);

    // Create a check step (compile without running)
    const check_step = b.step("check", "Check if code compiles");
    check_step.dependOn(&lib.step);
    check_step.dependOn(&exe.step);
    check_step.dependOn(&lib_tests.step);
    check_step.dependOn(&integration_tests.step);
}
// ANCHOR_END: testing_setup
