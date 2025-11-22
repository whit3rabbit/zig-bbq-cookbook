const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create a test step to run all recipe code tests
    const test_step = b.step("test", "Run all recipe tests");

    // Test Phase 1 Foundation
    addTest(b, test_step, target, optimize, "code/01-foundation/idiomatic_examples.zig");
    addTest(b, test_step, target, optimize, "code/01-foundation/error_handling.zig");
    addTest(b, test_step, target, optimize, "code/01-foundation/testing_examples.zig");

    // Test Phase 2 Core - Chapter 2: Strings and Text
    // Recipe 2.14 requires ICU C library - only test if available
    // Install: brew install icu4c (macOS), apt-get install libicu-dev (Ubuntu), pacman -S icu (Arch)
    if (tryAddICUTest(b, test_step, target, optimize)) {
        // ICU test added successfully
    } else {
        std.log.warn("ICU library not found - skipping recipe 2.14 tests. Install ICU to test Unicode normalization.", .{});
    }

    // Note: To build and serve the website, install Zine separately:
    //   zig fetch --save git+https://github.com/kristoff-it/zine
    //   zine         # Start dev server
    //   zine build   # Build static site
}

fn addTest(
    b: *std.Build,
    test_step: *std.Build.Step,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    path: []const u8,
) void {
    const test_exe = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path(path),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_test = b.addRunArtifact(test_exe);
    test_step.dependOn(&run_test.step);
}

/// Try to add ICU test - returns true if successful, false if ICU not found
fn tryAddICUTest(
    b: *std.Build,
    test_step: *std.Build.Step,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) bool {
    // Check if ICU is available by looking for common installation paths
    const icu_found = checkICUAvailable(target.result.os.tag);
    if (!icu_found) {
        return false;
    }

    const test_exe = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("code/02-core/02-strings-and-text/recipe_2_14.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Link C standard library
    test_exe.linkLibC();

    // Add ICU library paths based on OS
    if (target.result.os.tag == .macos) {
        // macOS Homebrew paths (keg-only formula)
        // Apple Silicon: /opt/homebrew/opt/icu4c
        // Intel Mac: /usr/local/opt/icu4c
        test_exe.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/opt/icu4c/lib" });
        test_exe.addIncludePath(.{ .cwd_relative = "/opt/homebrew/opt/icu4c/include" });
        test_exe.addLibraryPath(.{ .cwd_relative = "/usr/local/opt/icu4c/lib" });
        test_exe.addIncludePath(.{ .cwd_relative = "/usr/local/opt/icu4c/include" });
    } else if (target.result.os.tag == .linux) {
        // Linux: ICU is usually in standard system paths, but add common locations
        // Ubuntu/Debian: /usr/lib/x86_64-linux-gnu or /usr/lib/aarch64-linux-gnu
        // Arch: /usr/lib
        test_exe.addLibraryPath(.{ .cwd_relative = "/usr/lib" });
        test_exe.addLibraryPath(.{ .cwd_relative = "/usr/lib/x86_64-linux-gnu" });
        test_exe.addLibraryPath(.{ .cwd_relative = "/usr/lib/aarch64-linux-gnu" });
        test_exe.addIncludePath(.{ .cwd_relative = "/usr/include" });
    }
    // Windows: Users would need to set up paths manually or use vcpkg

    // Link ICU libraries
    test_exe.linkSystemLibrary("icuuc");
    test_exe.linkSystemLibrary("icui18n");

    const run_test = b.addRunArtifact(test_exe);
    test_step.dependOn(&run_test.step);

    return true;
}

/// Check if ICU library is available on the system
fn checkICUAvailable(os_tag: std.Target.Os.Tag) bool {
    if (os_tag == .macos) {
        // Check common macOS Homebrew locations
        const paths = [_][]const u8{
            "/opt/homebrew/opt/icu4c/lib/libicuuc.dylib",
            "/usr/local/opt/icu4c/lib/libicuuc.dylib",
        };
        for (paths) |path| {
            std.fs.accessAbsolute(path, .{}) catch continue;
            return true; // Found!
        }
        return false;
    } else if (os_tag == .linux) {
        // Check common Linux locations
        const paths = [_][]const u8{
            "/usr/lib/libicuuc.so",
            "/usr/lib/x86_64-linux-gnu/libicuuc.so",
            "/usr/lib/aarch64-linux-gnu/libicuuc.so",
        };
        for (paths) |path| {
            std.fs.accessAbsolute(path, .{}) catch continue;
            return true; // Found!
        }
        return false;
    } else if (os_tag == .windows) {
        // Windows users typically need to set up ICU manually
        // For now, assume not available unless they've set it up
        return false;
    }

    // Unknown OS - assume not available
    return false;
}
