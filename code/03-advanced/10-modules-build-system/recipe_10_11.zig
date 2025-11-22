// Recipe 10.11: Distributing Packages
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to prepare and distribute Zig packages.
// Unlike Python's setup.py and PyPI, Zig uses build.zig.zon and Git-based packages.
//
// Key concepts:
// - Package metadata in build.zig.zon
// - Semantic versioning
// - Dependency declarations
// - Library vs executable distribution
// - Public API design
// - Package documentation

const std = @import("std");
const testing = std.testing;

// ANCHOR: package_metadata
// Package metadata (typically in build.zig.zon)
pub const PackageMetadata = struct {
    name: []const u8,
    version: SemanticVersion,
    description: []const u8,
    author: []const u8,
    license: []const u8,
    repository: ?[]const u8,
    homepage: ?[]const u8,

    pub fn format(
        self: PackageMetadata,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s} v{}", .{ self.name, self.version });
    }
};

test "package metadata" {
    const pkg = PackageMetadata{
        .name = "my-awesome-lib",
        .version = .{ .major = 1, .minor = 2, .patch = 3 },
        .description = "An awesome Zig library",
        .author = "Jane Developer",
        .license = "MIT",
        .repository = "https://github.com/user/my-awesome-lib",
        .homepage = "https://my-awesome-lib.dev",
    };

    try testing.expectEqualStrings("my-awesome-lib", pkg.name);
    try testing.expectEqual(@as(u32, 1), pkg.version.major);
}
// ANCHOR_END: package_metadata

// ANCHOR: semantic_version
pub const SemanticVersion = struct {
    major: u32,
    minor: u32,
    patch: u32,
    prerelease: ?[]const u8 = null,
    build: ?[]const u8 = null,

    pub fn format(
        self: SemanticVersion,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{d}.{d}.{d}", .{ self.major, self.minor, self.patch });
        if (self.prerelease) |pre| {
            try writer.print("-{s}", .{pre});
        }
        if (self.build) |b| {
            try writer.print("+{s}", .{b});
        }
    }

    pub fn isCompatible(self: SemanticVersion, required: SemanticVersion) bool {
        // Major version must match for compatibility
        if (self.major != required.major) return false;

        // Special case: 0.x.x versions are unstable
        // Minor version must match exactly for 0.x.x
        if (self.major == 0) {
            if (self.minor != required.minor) return false;
            // Patch can be >= for 0.x.x within same minor version
            return self.patch >= required.patch;
        }

        // For stable versions (1.x.x+), minor.patch must be >= required
        if (self.minor < required.minor) return false;
        if (self.minor == required.minor and self.patch < required.patch) return false;

        return true;
    }
};

test "semantic version formatting" {
    const v1 = SemanticVersion{ .major = 1, .minor = 2, .patch = 3 };
    const v2 = SemanticVersion{
        .major = 2,
        .minor = 0,
        .patch = 0,
        .prerelease = "beta.1",
        .build = "20250115",
    };

    _ = v1;
    _ = v2;
}

test "semantic version compatibility" {
    const v1_2_3 = SemanticVersion{ .major = 1, .minor = 2, .patch = 3 };
    const v1_2_0 = SemanticVersion{ .major = 1, .minor = 2, .patch = 0 };
    const v1_1_0 = SemanticVersion{ .major = 1, .minor = 1, .patch = 0 };
    const v2_0_0 = SemanticVersion{ .major = 2, .minor = 0, .patch = 0 };

    try testing.expect(v1_2_3.isCompatible(v1_2_0));
    try testing.expect(v1_2_3.isCompatible(v1_1_0));
    try testing.expect(!v1_2_3.isCompatible(v2_0_0));
    try testing.expect(!v1_1_0.isCompatible(v1_2_0));
}
// ANCHOR_END: semantic_version

// ANCHOR: dependency_spec
pub const DependencySpec = struct {
    name: []const u8,
    url: []const u8,
    hash: ?[]const u8 = null,
    version: ?SemanticVersion = null,

    pub fn isValid(self: DependencySpec) bool {
        return self.name.len > 0 and self.url.len > 0;
    }
};

test "dependency specification" {
    const dep = DependencySpec{
        .name = "zlib",
        .url = "https://github.com/madler/zlib",
        .hash = "1234567890abcdef",
        .version = .{ .major = 1, .minor = 3, .patch = 0 },
    };

    try testing.expect(dep.isValid());
    try testing.expectEqualStrings("zlib", dep.name);
}
// ANCHOR_END: dependency_spec

// ANCHOR: public_api
// A well-designed public API for a distributed package
pub const PublicAPI = struct {
    // Version information
    pub const version = SemanticVersion{ .major = 1, .minor = 0, .patch = 0 };

    // Main functionality
    pub fn process(value: i32) i32 {
        return value * 2;
    }

    pub fn processWithOptions(value: i32, options: ProcessOptions) i32 {
        var result = value;
        if (options.double) result *= 2;
        if (options.add_ten) result += 10;
        return result;
    }

    // Configuration
    pub const ProcessOptions = struct {
        double: bool = true,
        add_ten: bool = false,
    };

    // Error types
    pub const Error = error{
        InvalidInput,
        ProcessingFailed,
    };

    // Advanced functionality
    /// Process multiple values and return owned slice.
    /// Caller owns returned memory and must free it.
    pub fn processAdvanced(allocator: std.mem.Allocator, values: []const i32) ![]i32 {
        const result = try allocator.alloc(i32, values.len);
        errdefer allocator.free(result);

        for (values, 0..) |val, i| {
            result[i] = val * 2;
        }
        return result;
    }
};

test "public API usage" {
    const result = PublicAPI.process(10);
    try testing.expectEqual(@as(i32, 20), result);

    const options = PublicAPI.ProcessOptions{ .double = true, .add_ten = true };
    const result2 = PublicAPI.processWithOptions(10, options);
    try testing.expectEqual(@as(i32, 30), result2);

    const values = [_]i32{ 1, 2, 3 };
    const results = try PublicAPI.processAdvanced(testing.allocator, &values);
    defer testing.allocator.free(results);

    try testing.expectEqual(@as(i32, 2), results[0]);
    try testing.expectEqual(@as(i32, 4), results[1]);
    try testing.expectEqual(@as(i32, 6), results[2]);
}
// ANCHOR_END: public_api

// ANCHOR: library_exports
// Pattern for organizing library exports
pub const Library = struct {
    // Core functionality
    pub const core = struct {
        pub fn initialize() void {}
        pub fn shutdown() void {}
    };

    // Utilities
    pub const utils = struct {
        pub fn helper(value: i32) i32 {
            return value + 1;
        }
    };

    // Types
    pub const types = struct {
        pub const Config = struct {
            enabled: bool = true,
            timeout: u32 = 5000,
        };
    };

    // Constants
    pub const constants = struct {
        pub const MAX_SIZE: usize = 1024;
        pub const DEFAULT_TIMEOUT: u32 = 5000;
    };
};

test "library exports" {
    Library.core.initialize();
    defer Library.core.shutdown();

    const result = Library.utils.helper(10);
    try testing.expectEqual(@as(i32, 11), result);

    const config = Library.types.Config{};
    try testing.expect(config.enabled);
    try testing.expectEqual(@as(u32, 5000), config.timeout);

    try testing.expectEqual(@as(usize, 1024), Library.constants.MAX_SIZE);
}
// ANCHOR_END: library_exports

// ANCHOR: package_builder
/// Builder pattern for constructing package manifests.
///
/// Example:
///     var builder = PackageBuilder.init(allocator, metadata);
///     defer builder.deinit();
///     try builder.addDependency(dep1);
///     try builder.addDependency(dep2);
///     const manifest = try builder.build();
///     defer manifest.deinit(allocator);
pub const PackageBuilder = struct {
    metadata: PackageMetadata,
    dependencies: std.ArrayList(DependencySpec),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, metadata: PackageMetadata) PackageBuilder {
        return .{
            .metadata = metadata,
            .dependencies = std.ArrayList(DependencySpec){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *PackageBuilder) void {
        self.dependencies.deinit(self.allocator);
    }

    pub fn addDependency(self: *PackageBuilder, dep: DependencySpec) !void {
        try self.dependencies.append(self.allocator, dep);
    }

    pub fn build(self: *PackageBuilder) !PackageManifest {
        return PackageManifest{
            .metadata = self.metadata,
            .dependencies = try self.dependencies.toOwnedSlice(self.allocator),
        };
    }
};

pub const PackageManifest = struct {
    metadata: PackageMetadata,
    dependencies: []DependencySpec,

    pub fn deinit(self: PackageManifest, allocator: std.mem.Allocator) void {
        allocator.free(self.dependencies);
    }
};

test "package builder" {
    const metadata = PackageMetadata{
        .name = "test-package",
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
        .description = "Test package",
        .author = "Test Author",
        .license = "MIT",
        .repository = null,
        .homepage = null,
    };

    var builder = PackageBuilder.init(testing.allocator, metadata);
    defer builder.deinit();

    try builder.addDependency(.{
        .name = "dep1",
        .url = "https://example.com/dep1",
    });

    const manifest = try builder.build();
    defer manifest.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 1), manifest.dependencies.len);
}
// ANCHOR_END: package_builder

// ANCHOR: compatibility_check
pub const CompatibilityChecker = struct {
    pub fn checkVersion(
        provided: SemanticVersion,
        required: SemanticVersion,
    ) CompatibilityResult {
        if (provided.major != required.major) {
            return .incompatible;
        }

        if (provided.major == 0) {
            // Pre-1.0, minor version must match
            if (provided.minor != required.minor) {
                return .incompatible;
            }
        }

        if (provided.minor < required.minor) {
            return .incompatible;
        }

        if (provided.minor == required.minor and provided.patch < required.patch) {
            return .incompatible;
        }

        if (provided.minor > required.minor or provided.patch > required.patch) {
            return .compatible_newer;
        }

        return .compatible_exact;
    }
};

pub const CompatibilityResult = enum {
    compatible_exact,
    compatible_newer,
    incompatible,
};

test "compatibility checker" {
    const v1_0_0 = SemanticVersion{ .major = 1, .minor = 0, .patch = 0 };
    const v1_1_0 = SemanticVersion{ .major = 1, .minor = 1, .patch = 0 };
    const v2_0_0 = SemanticVersion{ .major = 2, .minor = 0, .patch = 0 };

    const result1 = CompatibilityChecker.checkVersion(v1_0_0, v1_0_0);
    try testing.expectEqual(CompatibilityResult.compatible_exact, result1);

    const result2 = CompatibilityChecker.checkVersion(v1_1_0, v1_0_0);
    try testing.expectEqual(CompatibilityResult.compatible_newer, result2);

    const result3 = CompatibilityChecker.checkVersion(v1_0_0, v2_0_0);
    try testing.expectEqual(CompatibilityResult.incompatible, result3);
}
// ANCHOR_END: compatibility_check

// ANCHOR: documentation_metadata
pub const Documentation = struct {
    summary: []const u8,
    detailed: []const u8,
    examples: []const Example,

    pub const Example = struct {
        title: []const u8,
        code: []const u8,
        description: []const u8,
    };
};

pub const module_docs = Documentation{
    .summary = "A package distribution example for Zig",
    .detailed = "This module demonstrates patterns for distributing Zig packages.",
    .examples = &.{
        .{
            .title = "Basic usage",
            .code = "const result = PublicAPI.process(10);",
            .description = "Process a value using the public API",
        },
    },
};

test "documentation metadata" {
    try testing.expectEqualStrings("A package distribution example for Zig", module_docs.summary);
    try testing.expectEqual(@as(usize, 1), module_docs.examples.len);
}
// ANCHOR_END: documentation_metadata

// ANCHOR: build_configuration
pub const BuildConfig = struct {
    optimization: OptimizationMode = .Debug,
    target_arch: ?[]const u8 = null,
    target_os: ?[]const u8 = null,
    strip_debug: bool = false,
    enable_tests: bool = true,

    pub const OptimizationMode = enum {
        Debug,
        ReleaseSafe,
        ReleaseFast,
        ReleaseSmall,
    };

    pub fn isRelease(self: BuildConfig) bool {
        return self.optimization != .Debug;
    }
};

test "build configuration" {
    const debug_config = BuildConfig{};
    try testing.expect(!debug_config.isRelease());

    const release_config = BuildConfig{ .optimization = .ReleaseFast };
    try testing.expect(release_config.isRelease());
}
// ANCHOR_END: build_configuration

// ANCHOR: package_validator
pub const PackageValidator = struct {
    pub const ValidationError = error{
        InvalidName,
        InvalidVersion,
        MissingDescription,
        MissingLicense,
        InvalidDependency,
    };

    pub fn validate(pkg: PackageMetadata) ValidationError!void {
        if (pkg.name.len == 0) {
            return ValidationError.InvalidName;
        }

        if (pkg.version.major == 0 and pkg.version.minor == 0 and pkg.version.patch == 0) {
            return ValidationError.InvalidVersion;
        }

        if (pkg.description.len == 0) {
            return ValidationError.MissingDescription;
        }

        if (pkg.license.len == 0) {
            return ValidationError.MissingLicense;
        }
    }
};

test "package validator" {
    const valid_pkg = PackageMetadata{
        .name = "valid-package",
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
        .description = "A valid package",
        .author = "Author",
        .license = "MIT",
        .repository = null,
        .homepage = null,
    };

    try PackageValidator.validate(valid_pkg);

    const invalid_pkg = PackageMetadata{
        .name = "",
        .version = .{ .major = 0, .minor = 0, .patch = 0 },
        .description = "",
        .author = "",
        .license = "",
        .repository = null,
        .homepage = null,
    };

    const result = PackageValidator.validate(invalid_pkg);
    try testing.expectError(PackageValidator.ValidationError.InvalidName, result);
}
// ANCHOR_END: package_validator

// ANCHOR: license_info
pub const License = enum {
    MIT,
    Apache2,
    GPL3,
    BSD3Clause,
    Custom,

    pub fn getSPDXIdentifier(self: License) []const u8 {
        return switch (self) {
            .MIT => "MIT",
            .Apache2 => "Apache-2.0",
            .GPL3 => "GPL-3.0-or-later",
            .BSD3Clause => "BSD-3-Clause",
            .Custom => "SEE LICENSE IN LICENSE",
        };
    }

    pub fn requiresAttribution(self: License) bool {
        // All these licenses require copyright notice preservation
        return switch (self) {
            .MIT, .Apache2, .BSD3Clause, .GPL3 => true,
            .Custom => true, // Assume yes for safety
        };
    }
};

test "license info" {
    const mit = License.MIT;
    try testing.expectEqualStrings("MIT", mit.getSPDXIdentifier());
    try testing.expect(mit.requiresAttribution());
}
// ANCHOR_END: license_info

// Comprehensive test
test "comprehensive package distribution" {
    // Package metadata
    const metadata = PackageMetadata{
        .name = "example-lib",
        .version = .{ .major = 1, .minor = 0, .patch = 0 },
        .description = "Example library",
        .author = "Developer",
        .license = "MIT",
        .repository = "https://github.com/user/example-lib",
        .homepage = null,
    };

    // Validate package
    try PackageValidator.validate(metadata);

    // Version compatibility
    const v1_1_0 = SemanticVersion{ .major = 1, .minor = 1, .patch = 0 };
    try testing.expect(v1_1_0.isCompatible(metadata.version));

    // Public API usage
    const result = PublicAPI.process(5);
    try testing.expectEqual(@as(i32, 10), result);

    // License check
    const license = License.MIT;
    try testing.expect(license.requiresAttribution());
}
