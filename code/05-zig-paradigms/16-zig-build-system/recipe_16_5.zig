const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");

// This file demonstrates cross-compilation concepts

// ANCHOR: target_info
// Target platform information
pub const TargetInfo = struct {
    arch: []const u8,
    os: []const u8,
    abi: []const u8,

    pub fn init(arch: []const u8, os: []const u8, abi: []const u8) TargetInfo {
        return .{
            .arch = arch,
            .os = os,
            .abi = abi,
        };
    }

    pub fn targetTriple(self: TargetInfo, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "{s}-{s}-{s}", .{ self.arch, self.os, self.abi });
    }

    pub fn isNative(self: TargetInfo) bool {
        return std.mem.eql(u8, self.arch, @tagName(builtin.cpu.arch)) and
            std.mem.eql(u8, self.os, @tagName(builtin.os.tag));
    }
};

test "target info" {
    const target = TargetInfo.init("x86_64", "linux", "gnu");
    const triple = try target.targetTriple(testing.allocator);
    defer testing.allocator.free(triple);

    try testing.expect(std.mem.eql(u8, triple, "x86_64-linux-gnu"));
}
// ANCHOR_END: target_info

// ANCHOR: cross_compile_config
// Cross-compilation configuration
pub const CrossCompileConfig = struct {
    target: TargetInfo,
    optimize: []const u8,
    strip: bool,

    pub fn init(target: TargetInfo, optimize: []const u8) CrossCompileConfig {
        return .{
            .target = target,
            .optimize = optimize,
            .strip = false,
        };
    }

    pub fn withStrip(self: CrossCompileConfig) CrossCompileConfig {
        var result = self;
        result.strip = true;
        return result;
    }

    pub fn isOptimized(self: CrossCompileConfig) bool {
        return !std.mem.eql(u8, self.optimize, "Debug");
    }
};

test "cross compile config" {
    const target = TargetInfo.init("aarch64", "macos", "none");
    const config = CrossCompileConfig.init(target, "ReleaseFast");

    try testing.expect(config.isOptimized());
    try testing.expect(!config.strip);

    const stripped = config.withStrip();
    try testing.expect(stripped.strip);
}
// ANCHOR_END: cross_compile_config

// ANCHOR: target_query
// Target query and filtering
pub const TargetQuery = struct {
    arch_filter: ?[]const u8,
    os_filter: ?[]const u8,

    pub fn init() TargetQuery {
        return .{
            .arch_filter = null,
            .os_filter = null,
        };
    }

    pub fn filterByArch(self: TargetQuery, arch: []const u8) TargetQuery {
        var result = self;
        result.arch_filter = arch;
        return result;
    }

    pub fn filterByOS(self: TargetQuery, os: []const u8) TargetQuery {
        var result = self;
        result.os_filter = os;
        return result;
    }

    pub fn matches(self: TargetQuery, target: TargetInfo) bool {
        if (self.arch_filter) |arch| {
            if (!std.mem.eql(u8, arch, target.arch)) return false;
        }
        if (self.os_filter) |os| {
            if (!std.mem.eql(u8, os, target.os)) return false;
        }
        return true;
    }
};

test "target query" {
    const query = TargetQuery.init().filterByArch("x86_64").filterByOS("linux");

    const linux_target = TargetInfo.init("x86_64", "linux", "gnu");
    const windows_target = TargetInfo.init("x86_64", "windows", "gnu");

    try testing.expect(query.matches(linux_target));
    try testing.expect(!query.matches(windows_target));
}
// ANCHOR_END: target_query

// ANCHOR: platform_features
// Platform-specific features
pub const PlatformFeatures = struct {
    target: TargetInfo,
    features: []const []const u8,

    pub fn init(target: TargetInfo, features: []const []const u8) PlatformFeatures {
        return .{
            .target = target,
            .features = features,
        };
    }

    pub fn hasFeature(self: PlatformFeatures, feature: []const u8) bool {
        for (self.features) |f| {
            if (std.mem.eql(u8, f, feature)) return true;
        }
        return false;
    }

    pub fn featureCount(self: PlatformFeatures) usize {
        return self.features.len;
    }
};

test "platform features" {
    const target = TargetInfo.init("x86_64", "linux", "gnu");
    const features = [_][]const u8{ "sse4", "avx2" };
    const platform = PlatformFeatures.init(target, &features);

    try testing.expectEqual(@as(usize, 2), platform.featureCount());
    try testing.expect(platform.hasFeature("avx2"));
    try testing.expect(!platform.hasFeature("neon"));
}
// ANCHOR_END: platform_features

// ANCHOR: target_triple_parsing
// Parse target triple strings
pub const TargetTriple = struct {
    raw: []const u8,

    pub fn init(triple: []const u8) TargetTriple {
        return .{ .raw = triple };
    }

    pub fn parse(self: TargetTriple, allocator: std.mem.Allocator) !TargetInfo {
        var parts = std.mem.splitSequence(u8, self.raw, "-");

        const arch = parts.next() orelse return error.InvalidTriple;
        const os = parts.next() orelse return error.InvalidTriple;
        const abi = parts.next() orelse return error.InvalidTriple;

        const arch_copy = try allocator.dupe(u8, arch);
        errdefer allocator.free(arch_copy);

        const os_copy = try allocator.dupe(u8, os);
        errdefer allocator.free(os_copy);

        const abi_copy = try allocator.dupe(u8, abi);

        return TargetInfo.init(arch_copy, os_copy, abi_copy);
    }

    pub fn isValid(self: TargetTriple) bool {
        var count: usize = 0;
        var iter = std.mem.splitSequence(u8, self.raw, "-");
        while (iter.next()) |_| {
            count += 1;
        }
        return count >= 3;
    }
};

test "target triple parsing" {
    const triple = TargetTriple.init("x86_64-linux-gnu");
    try testing.expect(triple.isValid());

    const target = try triple.parse(testing.allocator);
    defer {
        testing.allocator.free(target.arch);
        testing.allocator.free(target.os);
        testing.allocator.free(target.abi);
    }

    try testing.expect(std.mem.eql(u8, target.arch, "x86_64"));
    try testing.expect(std.mem.eql(u8, target.os, "linux"));
}
// ANCHOR_END: target_triple_parsing

// ANCHOR: build_matrix
// Multi-target build matrix
pub const BuildMatrix = struct {
    targets: []const TargetInfo,
    optimizations: []const []const u8,

    pub fn init(targets: []const TargetInfo, opts: []const []const u8) BuildMatrix {
        return .{
            .targets = targets,
            .optimizations = opts,
        };
    }

    pub fn totalBuilds(self: BuildMatrix) usize {
        return self.targets.len * self.optimizations.len;
    }

    pub fn targetCount(self: BuildMatrix) usize {
        return self.targets.len;
    }
};

test "build matrix" {
    const targets = [_]TargetInfo{
        TargetInfo.init("x86_64", "linux", "gnu"),
        TargetInfo.init("x86_64", "windows", "gnu"),
        TargetInfo.init("aarch64", "linux", "gnu"),
    };
    const opts = [_][]const u8{ "Debug", "ReleaseFast", "ReleaseSmall" };
    const matrix = BuildMatrix.init(&targets, &opts);

    try testing.expectEqual(@as(usize, 9), matrix.totalBuilds());
    try testing.expectEqual(@as(usize, 3), matrix.targetCount());
}
// ANCHOR_END: build_matrix

// ANCHOR: native_detection
// Detect native platform
pub const NativeDetection = struct {
    pub fn detect() TargetInfo {
        return TargetInfo.init(
            @tagName(builtin.cpu.arch),
            @tagName(builtin.os.tag),
            @tagName(builtin.abi),
        );
    }

    pub fn isLinux() bool {
        return builtin.os.tag == .linux;
    }

    pub fn isWindows() bool {
        return builtin.os.tag == .windows;
    }

    pub fn isMacOS() bool {
        return builtin.os.tag == .macos;
    }

    pub fn is64Bit() bool {
        return @sizeOf(usize) == 8;
    }
};

test "native detection" {
    const native = NativeDetection.detect();
    try testing.expect(native.arch.len > 0);
    try testing.expect(native.os.len > 0);

    // At least one should be true
    const has_os = NativeDetection.isLinux() or
        NativeDetection.isWindows() or
        NativeDetection.isMacOS();
    try testing.expect(has_os);
}
// ANCHOR_END: native_detection
