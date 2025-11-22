const std = @import("std");
const testing = std.testing;

// This file demonstrates build system concepts through testable code
// The actual build.zig files are in the recipe_16_1/ subdirectory

// ANCHOR: build_concepts
// Build system concepts demonstrated through types

pub const BuildMode = enum {
    Debug,
    ReleaseSafe,
    ReleaseFast,
    ReleaseSmall,

    pub fn description(self: BuildMode) []const u8 {
        return switch (self) {
            .Debug => "Fast compilation, safety checks, slow runtime",
            .ReleaseSafe => "Optimized with safety checks",
            .ReleaseFast => "Maximum performance, no safety checks",
            .ReleaseSmall => "Optimized for size",
        };
    }
};

test "build modes" {
    try testing.expect(std.mem.eql(u8, BuildMode.Debug.description(), "Fast compilation, safety checks, slow runtime"));
    try testing.expect(std.mem.eql(u8, BuildMode.ReleaseFast.description(), "Maximum performance, no safety checks"));
}
// ANCHOR_END: build_concepts

// ANCHOR: target_triple
// Understanding target triples
pub const TargetTriple = struct {
    arch: []const u8,
    os: []const u8,
    abi: []const u8,

    pub fn format(self: TargetTriple, allocator: std.mem.Allocator) ![]const u8 {
        return std.fmt.allocPrint(allocator, "{s}-{s}-{s}", .{ self.arch, self.os, self.abi });
    }
};

test "target triple formatting" {
    const target = TargetTriple{
        .arch = "x86_64",
        .os = "linux",
        .abi = "gnu",
    };

    const formatted = try target.format(testing.allocator);
    defer testing.allocator.free(formatted);

    try testing.expect(std.mem.eql(u8, formatted, "x86_64-linux-gnu"));
}
// ANCHOR_END: target_triple

// ANCHOR: build_options
// Simulating build options pattern
pub const BuildOptions = struct {
    version: []const u8,
    enable_logging: bool,
    max_connections: u32,

    pub fn init(version: []const u8, enable_logging: bool, max_connections: u32) BuildOptions {
        return .{
            .version = version,
            .enable_logging = enable_logging,
            .max_connections = max_connections,
        };
    }
};

test "build options" {
    const options = BuildOptions.init("1.0.0", true, 100);
    try testing.expect(std.mem.eql(u8, options.version, "1.0.0"));
    try testing.expectEqual(true, options.enable_logging);
    try testing.expectEqual(@as(u32, 100), options.max_connections);
}
// ANCHOR_END: build_options

// ANCHOR: artifact_types
// Different artifact types in the build system
pub const ArtifactType = enum {
    Executable,
    StaticLibrary,
    DynamicLibrary,
    Object,
    Test,

    pub fn extension(self: ArtifactType, os: std.Target.Os.Tag) []const u8 {
        return switch (self) {
            .Executable => if (os == .windows) ".exe" else "",
            .StaticLibrary => if (os == .windows) ".lib" else ".a",
            .DynamicLibrary => if (os == .windows) ".dll" else if (os == .macos) ".dylib" else ".so",
            .Object => ".o",
            .Test => "",
        };
    }
};

test "artifact extensions" {
    try testing.expect(std.mem.eql(u8, ArtifactType.Executable.extension(.linux), ""));
    try testing.expect(std.mem.eql(u8, ArtifactType.Executable.extension(.windows), ".exe"));
    try testing.expect(std.mem.eql(u8, ArtifactType.StaticLibrary.extension(.linux), ".a"));
    try testing.expect(std.mem.eql(u8, ArtifactType.DynamicLibrary.extension(.macos), ".dylib"));
}
// ANCHOR_END: artifact_types

// ANCHOR: dependency_resolution
// Simulating dependency resolution
pub const Dependency = struct {
    name: []const u8,
    version: []const u8,
    url: ?[]const u8,

    pub fn init(name: []const u8, version: []const u8, url: ?[]const u8) Dependency {
        return .{
            .name = name,
            .version = version,
            .url = url,
        };
    }

    pub fn isLocal(self: Dependency) bool {
        return self.url == null;
    }
};

test "dependency handling" {
    const local_dep = Dependency.init("mylib", "1.0.0", null);
    const remote_dep = Dependency.init("thirdparty", "2.1.0", "https://example.com/lib.git");

    try testing.expect(local_dep.isLocal());
    try testing.expect(!remote_dep.isLocal());
}
// ANCHOR_END: dependency_resolution

// ANCHOR: build_steps
// Build step management
pub const BuildStep = struct {
    name: []const u8,
    description: []const u8,
    dependencies: []const []const u8,

    pub fn init(name: []const u8, description: []const u8, dependencies: []const []const u8) BuildStep {
        return .{
            .name = name,
            .description = description,
            .dependencies = dependencies,
        };
    }

    pub fn hasDependency(self: BuildStep, dep_name: []const u8) bool {
        for (self.dependencies) |dep| {
            if (std.mem.eql(u8, dep, dep_name)) return true;
        }
        return false;
    }
};

test "build step dependencies" {
    const deps = [_][]const u8{ "compile", "link" };
    const step = BuildStep.init("run", "Run the application", &deps);

    try testing.expect(step.hasDependency("compile"));
    try testing.expect(step.hasDependency("link"));
    try testing.expect(!step.hasDependency("test"));
}
// ANCHOR_END: build_steps

// ANCHOR: install_directory
// Install directory structure
pub const InstallDir = enum {
    Prefix,
    Bin,
    Lib,
    Include,
    Share,

    pub fn path(self: InstallDir, prefix: []const u8, allocator: std.mem.Allocator) ![]const u8 {
        const subdir = switch (self) {
            .Prefix => "",
            .Bin => "bin",
            .Lib => "lib",
            .Include => "include",
            .Share => "share",
        };

        if (subdir.len == 0) {
            return try allocator.dupe(u8, prefix);
        }

        return try std.fs.path.join(allocator, &[_][]const u8{ prefix, subdir });
    }
};

test "install directories" {
    const prefix = "/usr/local";

    const bin_path = try InstallDir.Bin.path(prefix, testing.allocator);
    defer testing.allocator.free(bin_path);
    try testing.expect(std.mem.eql(u8, bin_path, "/usr/local/bin"));

    const lib_path = try InstallDir.Lib.path(prefix, testing.allocator);
    defer testing.allocator.free(lib_path);
    try testing.expect(std.mem.eql(u8, lib_path, "/usr/local/lib"));
}
// ANCHOR_END: install_directory

// ANCHOR: module_system
// Module system concepts
pub const Module = struct {
    name: []const u8,
    root_file: []const u8,
    dependencies: []const []const u8,

    pub fn init(name: []const u8, root_file: []const u8, dependencies: []const []const u8) Module {
        return .{
            .name = name,
            .root_file = root_file,
            .dependencies = dependencies,
        };
    }

    pub fn dependsOn(self: Module, module_name: []const u8) bool {
        for (self.dependencies) |dep| {
            if (std.mem.eql(u8, dep, module_name)) return true;
        }
        return false;
    }
};

test "module dependencies" {
    const deps = [_][]const u8{ "std", "network" };
    const mod = Module.init("app", "src/main.zig", &deps);

    try testing.expect(mod.dependsOn("std"));
    try testing.expect(mod.dependsOn("network"));
    try testing.expect(!mod.dependsOn("database"));
}
// ANCHOR_END: module_system
