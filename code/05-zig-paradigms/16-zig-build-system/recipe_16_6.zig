const std = @import("std");
const testing = std.testing;

// This file demonstrates build options and configuration concepts

// ANCHOR: build_config
// Build configuration structure
pub const BuildConfig = struct {
    enable_logging: bool,
    max_connections: u32,
    server_name: []const u8,
    port: u16,

    pub fn init(logging: bool, max_conn: u32, name: []const u8, port: u16) BuildConfig {
        return .{
            .enable_logging = logging,
            .max_connections = max_conn,
            .server_name = name,
            .port = port,
        };
    }

    pub fn isProduction(self: BuildConfig) bool {
        return !self.enable_logging and self.max_connections > 100;
    }
};

test "build config" {
    const config = BuildConfig.init(true, 50, "dev-server", 8080);

    try testing.expect(!config.isProduction());
    try testing.expectEqual(@as(u16, 8080), config.port);
    try testing.expect(std.mem.eql(u8, config.server_name, "dev-server"));
}
// ANCHOR_END: build_config

// ANCHOR: option_types
// Different types of build options
pub const OptionTypes = struct {
    // Boolean option
    pub const BoolOption = struct {
        name: []const u8,
        default: bool,
        description: []const u8,

        pub fn init(name: []const u8, default: bool, desc: []const u8) BoolOption {
            return .{ .name = name, .default = default, .description = desc };
        }
    };

    // String option
    pub const StringOption = struct {
        name: []const u8,
        default: ?[]const u8,
        description: []const u8,

        pub fn init(name: []const u8, default: ?[]const u8, desc: []const u8) StringOption {
            return .{ .name = name, .default = default, .description = desc };
        }

        pub fn hasDefault(self: StringOption) bool {
            return self.default != null;
        }
    };

    // Integer option
    pub const IntOption = struct {
        name: []const u8,
        default: i64,
        min: ?i64,
        max: ?i64,
        description: []const u8,

        pub fn init(name: []const u8, default: i64, desc: []const u8) IntOption {
            return .{ .name = name, .default = default, .min = null, .max = null, .description = desc };
        }

        pub fn withRange(self: IntOption, min: i64, max: i64) IntOption {
            var result = self;
            result.min = min;
            result.max = max;
            return result;
        }

        pub fn isValid(self: IntOption, value: i64) bool {
            if (self.min) |min| {
                if (value < min) return false;
            }
            if (self.max) |max| {
                if (value > max) return false;
            }
            return true;
        }
    };
};

test "option types" {
    const bool_opt = OptionTypes.BoolOption.init("enable-feature", true, "Enable feature");
    try testing.expect(bool_opt.default);

    const str_opt = OptionTypes.StringOption.init("name", "default", "Server name");
    try testing.expect(str_opt.hasDefault());

    const int_opt = OptionTypes.IntOption.init("port", 8080, "Server port").withRange(1024, 65535);
    try testing.expect(int_opt.isValid(8080));
    try testing.expect(!int_opt.isValid(80));
}
// ANCHOR_END: option_types

// ANCHOR: feature_flags
// Feature flag management
pub const FeatureFlags = struct {
    flags: std.StringHashMap(bool),

    pub fn init(allocator: std.mem.Allocator) FeatureFlags {
        return .{ .flags = std.StringHashMap(bool).init(allocator) };
    }

    pub fn deinit(self: *FeatureFlags) void {
        self.flags.deinit();
    }

    pub fn enable(self: *FeatureFlags, feature: []const u8) !void {
        try self.flags.put(feature, true);
    }

    pub fn disable(self: *FeatureFlags, feature: []const u8) !void {
        try self.flags.put(feature, false);
    }

    pub fn isEnabled(self: FeatureFlags, feature: []const u8) bool {
        return self.flags.get(feature) orelse false;
    }

    pub fn count(self: FeatureFlags) usize {
        return self.flags.count();
    }
};

test "feature flags" {
    var flags = FeatureFlags.init(testing.allocator);
    defer flags.deinit();

    try flags.enable("logging");
    try flags.enable("metrics");
    try flags.disable("deprecated-api");

    try testing.expect(flags.isEnabled("logging"));
    try testing.expect(!flags.isEnabled("deprecated-api"));
    try testing.expect(!flags.isEnabled("nonexistent"));
    try testing.expectEqual(@as(usize, 3), flags.count());
}
// ANCHOR_END: feature_flags

// ANCHOR: environment_config
// Environment-specific configuration
pub const EnvironmentConfig = struct {
    pub const Environment = enum {
        development,
        staging,
        production,

        pub fn isProduction(self: Environment) bool {
            return self == .production;
        }

        pub fn isDevelopment(self: Environment) bool {
            return self == .development;
        }
    };

    env: Environment,
    debug_mode: bool,
    optimize_level: []const u8,

    pub fn init(env: Environment) EnvironmentConfig {
        return .{
            .env = env,
            .debug_mode = env.isDevelopment(),
            .optimize_level = if (env.isProduction()) "ReleaseFast" else "Debug",
        };
    }

    pub fn shouldLog(self: EnvironmentConfig) bool {
        return self.debug_mode;
    }
};

test "environment config" {
    const dev = EnvironmentConfig.init(.development);
    try testing.expect(dev.debug_mode);
    try testing.expect(dev.shouldLog());

    const prod = EnvironmentConfig.init(.production);
    try testing.expect(!prod.debug_mode);
    try testing.expect(!prod.shouldLog());
    try testing.expect(std.mem.eql(u8, prod.optimize_level, "ReleaseFast"));
}
// ANCHOR_END: environment_config

// ANCHOR: conditional_compilation
// Conditional compilation configuration
pub const ConditionalCompilation = struct {
    pub fn hasFeature(comptime feature: []const u8) bool {
        _ = feature;
        // In real code, this would check build options
        return true;
    }

    pub fn getVersion() []const u8 {
        return "1.0.0";
    }

    pub fn getConfig(comptime T: type) T {
        // Return compile-time configuration
        return undefined;
    }
};

test "conditional compilation" {
    try testing.expect(ConditionalCompilation.hasFeature("test"));
    const version = ConditionalCompilation.getVersion();
    try testing.expect(version.len > 0);
}
// ANCHOR_END: conditional_compilation

// ANCHOR: optimization_profiles
// Optimization profiles
pub const OptimizationProfile = struct {
    name: []const u8,
    mode: []const u8,
    strip_debug: bool,
    lto: bool,

    pub fn init(name: []const u8, mode: []const u8) OptimizationProfile {
        return .{
            .name = name,
            .mode = mode,
            .strip_debug = !std.mem.eql(u8, mode, "Debug"),
            .lto = std.mem.eql(u8, mode, "ReleaseFast"),
        };
    }

    pub fn isDebug(self: OptimizationProfile) bool {
        return std.mem.eql(u8, self.mode, "Debug");
    }

    pub fn isRelease(self: OptimizationProfile) bool {
        return !self.isDebug();
    }
};

test "optimization profiles" {
    const debug = OptimizationProfile.init("debug", "Debug");
    try testing.expect(debug.isDebug());
    try testing.expect(!debug.strip_debug);

    const release = OptimizationProfile.init("release", "ReleaseFast");
    try testing.expect(release.isRelease());
    try testing.expect(release.strip_debug);
    try testing.expect(release.lto);
}
// ANCHOR_END: optimization_profiles

// ANCHOR: platform_options
// Platform-specific options
pub const PlatformOptions = struct {
    target_os: []const u8,
    target_arch: []const u8,
    use_libc: bool,

    pub fn init(os: []const u8, arch: []const u8, libc: bool) PlatformOptions {
        return .{
            .target_os = os,
            .target_arch = arch,
            .use_libc = libc,
        };
    }

    pub fn isUnix(self: PlatformOptions) bool {
        return std.mem.eql(u8, self.target_os, "linux") or
            std.mem.eql(u8, self.target_os, "macos");
    }

    pub fn isWindows(self: PlatformOptions) bool {
        return std.mem.eql(u8, self.target_os, "windows");
    }

    pub fn is64Bit(self: PlatformOptions) bool {
        return std.mem.eql(u8, self.target_arch, "x86_64") or
            std.mem.eql(u8, self.target_arch, "aarch64");
    }
};

test "platform options" {
    const linux = PlatformOptions.init("linux", "x86_64", true);
    try testing.expect(linux.isUnix());
    try testing.expect(!linux.isWindows());
    try testing.expect(linux.is64Bit());

    const windows = PlatformOptions.init("windows", "x86_64", false);
    try testing.expect(windows.isWindows());
    try testing.expect(!windows.isUnix());
}
// ANCHOR_END: platform_options
