const std = @import("std");
const testing = std.testing;

// This file demonstrates building multiple artifacts through testable code
// The actual build.zig is in recipe_16_2/ subdirectory

// ANCHOR: library_types
// Different types of libraries
pub const LibraryType = enum {
    Static,
    Dynamic,
    Object,

    pub fn fileName(self: LibraryType, name: []const u8, os: std.Target.Os.Tag, allocator: std.mem.Allocator) ![]const u8 {
        const prefix = if (os != .windows) "lib" else "";
        const ext = switch (self) {
            .Static => if (os == .windows) ".lib" else ".a",
            .Dynamic => if (os == .windows) ".dll" else if (os == .macos) ".dylib" else ".so",
            .Object => ".o",
        };
        return try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ prefix, name, ext });
    }
};

test "library file names" {
    const name = try LibraryType.Static.fileName("mylib", .linux, testing.allocator);
    defer testing.allocator.free(name);
    try testing.expect(std.mem.eql(u8, name, "libmylib.a"));

    const dyn_name = try LibraryType.Dynamic.fileName("mylib", .macos, testing.allocator);
    defer testing.allocator.free(dyn_name);
    try testing.expect(std.mem.eql(u8, dyn_name, "libmylib.dylib"));
}
// ANCHOR_END: library_types

// ANCHOR: executable_configuration
// Executable configuration
pub const ExecutableConfig = struct {
    name: []const u8,
    source_file: []const u8,
    link_libc: bool,
    dependencies: []const []const u8,

    pub fn init(name: []const u8, source_file: []const u8) ExecutableConfig {
        return .{
            .name = name,
            .source_file = source_file,
            .link_libc = false,
            .dependencies = &[_][]const u8{},
        };
    }

    pub fn withLibc(self: ExecutableConfig) ExecutableConfig {
        var config = self;
        config.link_libc = true;
        return config;
    }

    pub fn hasDependency(self: ExecutableConfig, dep: []const u8) bool {
        for (self.dependencies) |d| {
            if (std.mem.eql(u8, d, dep)) return true;
        }
        return false;
    }
};

test "executable configuration" {
    const config = ExecutableConfig.init("myapp", "src/main.zig").withLibc();
    try testing.expect(std.mem.eql(u8, config.name, "myapp"));
    try testing.expectEqual(true, config.link_libc);
}
// ANCHOR_END: executable_configuration

// ANCHOR: artifact_linking
// Artifact linking relationships
pub const LinkageType = enum {
    Static,
    Dynamic,

    pub fn description(self: LinkageType) []const u8 {
        return switch (self) {
            .Static => "Statically linked at compile time",
            .Dynamic => "Dynamically linked at runtime",
        };
    }
};

pub const LinkedArtifact = struct {
    name: []const u8,
    linkage: LinkageType,

    pub fn init(name: []const u8, linkage: LinkageType) LinkedArtifact {
        return .{ .name = name, .linkage = linkage };
    }

    pub fn isStatic(self: LinkedArtifact) bool {
        return self.linkage == .Static;
    }
};

test "artifact linking" {
    const artifact = LinkedArtifact.init("mylib", .Static);
    try testing.expect(artifact.isStatic());
    try testing.expect(std.mem.eql(u8, artifact.name, "mylib"));
}
// ANCHOR_END: artifact_linking

// ANCHOR: install_artifacts
// Install artifact management
pub const InstallArtifact = struct {
    name: []const u8,
    destination: []const u8,
    artifact_type: enum { Executable, Library, Header },

    pub fn init(name: []const u8, destination: []const u8, artifact_type: @TypeOf(artifact_type)) InstallArtifact {
        return .{
            .name = name,
            .destination = destination,
            .artifact_type = artifact_type,
        };
    }

    pub fn fullPath(self: InstallArtifact, prefix: []const u8, allocator: std.mem.Allocator) ![]const u8 {
        return try std.fs.path.join(allocator, &[_][]const u8{ prefix, self.destination, self.name });
    }
};

test "install artifact paths" {
    const artifact = InstallArtifact.init("myapp", "bin", .Executable);
    const path = try artifact.fullPath("/usr/local", testing.allocator);
    defer testing.allocator.free(path);
    try testing.expect(std.mem.eql(u8, path, "/usr/local/bin/myapp"));
}
// ANCHOR_END: install_artifacts

// ANCHOR: version_management
// Library versioning
pub const LibraryVersion = struct {
    major: u32,
    minor: u32,
    patch: u32,

    pub fn init(major: u32, minor: u32, patch: u32) LibraryVersion {
        return .{ .major = major, .minor = minor, .patch = patch };
    }

    pub fn format(self: LibraryVersion, allocator: std.mem.Allocator) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "{d}.{d}.{d}", .{ self.major, self.minor, self.patch });
    }

    pub fn isCompatible(self: LibraryVersion, required: LibraryVersion) bool {
        if (self.major != required.major) return false;
        if (self.minor < required.minor) return false;
        return true;
    }
};

test "library versioning" {
    const version = LibraryVersion.init(1, 2, 3);
    const version_str = try version.format(testing.allocator);
    defer testing.allocator.free(version_str);
    try testing.expect(std.mem.eql(u8, version_str, "1.2.3"));

    const required = LibraryVersion.init(1, 1, 0);
    try testing.expect(version.isCompatible(required));

    const incompatible = LibraryVersion.init(2, 0, 0);
    try testing.expect(!version.isCompatible(incompatible));
}
// ANCHOR_END: version_management

// ANCHOR: run_steps
// Run step configuration
pub const RunStep = struct {
    artifact_name: []const u8,
    args: []const []const u8,
    cwd: ?[]const u8,

    pub fn init(artifact_name: []const u8) RunStep {
        return .{
            .artifact_name = artifact_name,
            .args = &[_][]const u8{},
            .cwd = null,
        };
    }

    pub fn withArgs(self: RunStep, args: []const []const u8) RunStep {
        var step = self;
        step.args = args;
        return step;
    }

    pub fn hasArgs(self: RunStep) bool {
        return self.args.len > 0;
    }
};

test "run step configuration" {
    const args = [_][]const u8{ "--verbose", "--debug" };
    const step = RunStep.init("myapp").withArgs(&args);
    try testing.expect(step.hasArgs());
    try testing.expectEqual(@as(usize, 2), step.args.len);
}
// ANCHOR_END: run_steps

// ANCHOR: multi_target_build
// Multi-target build configuration
pub const TargetConfig = struct {
    arch: []const u8,
    os: []const u8,
    abi: []const u8,

    pub fn init(arch: []const u8, os: []const u8, abi: []const u8) TargetConfig {
        return .{ .arch = arch, .os = os, .abi = abi };
    }

    pub fn triple(self: TargetConfig, allocator: std.mem.Allocator) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "{s}-{s}-{s}", .{ self.arch, self.os, self.abi });
    }

    pub fn isNative(self: TargetConfig) bool {
        const builtin = @import("builtin");
        const native_arch = @tagName(builtin.cpu.arch);
        const native_os = @tagName(builtin.os.tag);
        return std.mem.eql(u8, self.arch, native_arch) and std.mem.eql(u8, self.os, native_os);
    }
};

test "target configuration" {
    const target = TargetConfig.init("x86_64", "linux", "gnu");
    const triple = try target.triple(testing.allocator);
    defer testing.allocator.free(triple);
    try testing.expect(std.mem.eql(u8, triple, "x86_64-linux-gnu"));
}
// ANCHOR_END: multi_target_build

// ANCHOR: build_dependencies
// Build step dependencies
pub const BuildDependency = struct {
    name: []const u8,
    depends_on: []const []const u8,

    pub fn init(name: []const u8, depends_on: []const []const u8) BuildDependency {
        return .{ .name = name, .depends_on = depends_on };
    }

    pub fn hasDependency(self: BuildDependency, dep_name: []const u8) bool {
        for (self.depends_on) |dep| {
            if (std.mem.eql(u8, dep, dep_name)) return true;
        }
        return false;
    }

    pub fn dependencyCount(self: BuildDependency) usize {
        return self.depends_on.len;
    }
};

test "build dependencies" {
    const deps = [_][]const u8{ "compile", "link", "install" };
    const build_dep = BuildDependency.init("run", &deps);
    try testing.expect(build_dep.hasDependency("compile"));
    try testing.expectEqual(@as(usize, 3), build_dep.dependencyCount());
}
// ANCHOR_END: build_dependencies
