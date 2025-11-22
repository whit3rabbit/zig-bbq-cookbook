// ANCHOR: cross_compilation
const std = @import("std");

pub fn build(b: *std.Build) void {
    // Target and optimization from command line
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

    // Predefined cross-compilation targets
    const targets = [_]std.Build.ResolvedTarget{
        b.resolveTargetQuery(.{
            .cpu_arch = .x86_64,
            .os_tag = .linux,
            .abi = .gnu,
        }),
        b.resolveTargetQuery(.{
            .cpu_arch = .x86_64,
            .os_tag = .windows,
            .abi = .gnu,
        }),
        b.resolveTargetQuery(.{
            .cpu_arch = .aarch64,
            .os_tag = .macos,
        }),
        b.resolveTargetQuery(.{
            .cpu_arch = .aarch64,
            .os_tag = .linux,
            .abi = .musl,
        }),
    };

    // Create build step for all targets
    const all_step = b.step("all-targets", "Build for all predefined targets");

    for (targets) |cross_target| {
        const cross_exe = b.addExecutable(.{
            .name = "myapp",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = cross_target,
                .optimize = optimize,
            }),
        });

        const install_artifact = b.addInstallArtifact(cross_exe, .{});
        all_step.dependOn(&install_artifact.step);
    }

    // Platform-specific builds
    const linux_x64 = b.step("linux-x64", "Build for Linux x86_64");
    const linux_exe = b.addExecutable(.{
        .name = "myapp-linux",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .x86_64,
                .os_tag = .linux,
                .abi = .gnu,
            }),
            .optimize = optimize,
        }),
    });
    const install_linux = b.addInstallArtifact(linux_exe, .{});
    linux_x64.dependOn(&install_linux.step);

    const windows_x64 = b.step("windows-x64", "Build for Windows x86_64");
    const windows_exe = b.addExecutable(.{
        .name = "myapp-windows",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .x86_64,
                .os_tag = .windows,
                .abi = .gnu,
            }),
            .optimize = optimize,
        }),
    });
    const install_windows = b.addInstallArtifact(windows_exe, .{});
    windows_x64.dependOn(&install_windows.step);

    const macos_arm = b.step("macos-arm", "Build for macOS ARM64");
    const macos_exe = b.addExecutable(.{
        .name = "myapp-macos",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .aarch64,
                .os_tag = .macos,
            }),
            .optimize = optimize,
        }),
    });
    const install_macos = b.addInstallArtifact(macos_exe, .{});
    macos_arm.dependOn(&install_macos.step);
}
// ANCHOR_END: cross_compilation
