# Recipe 10.11: Distributing Packages

## Problem

You want to package your Zig code for distribution so others can use it as a dependency, similar to publishing to PyPI in Python. You need to manage metadata, versioning, dependencies, and public APIs.

## Solution

Zig uses a Git-based package system with `build.zig.zon` for metadata, rather than a central package repository like PyPI. This recipe demonstrates patterns for creating distributable Zig packages.

### Package Metadata

Define package information in a structured format:

```zig
{{#include ../../../code/03-advanced/10-modules-build-system/recipe_10_11.zig:package_metadata}}
```

Example usage:

```zig
const pkg = PackageMetadata{
    .name = "my-awesome-lib",
    .version = .{ .major = 1, .minor = 2, .patch = 3 },
    .description = "An awesome Zig library",
    .author = "Jane Developer",
    .license = "MIT",
    .repository = "https://github.com/user/my-awesome-lib",
    .homepage = "https://my-awesome-lib.dev",
};
```

### Semantic Versioning

Implement proper semantic versioning with compatibility checks:

```zig
pub const SemanticVersion = struct {
    major: u32,
    minor: u32,
    patch: u32,
    prerelease: ?[]const u8 = null,
    build: ?[]const u8 = null,

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
```

Version compatibility examples:
- `1.2.3` is compatible with `1.2.0` ✓
- `1.2.3` is compatible with `1.1.0` ✓
- `1.2.3` is NOT compatible with `2.0.0` ✗
- `0.2.0` is NOT compatible with `0.1.0` ✗ (0.x.x is unstable)

### Dependency Specification

Define dependencies with URLs and optional version/hash constraints:

```zig
pub const DependencySpec = struct {
    name: []const u8,
    url: []const u8,
    hash: ?[]const u8 = null,
    version: ?SemanticVersion = null,

    pub fn isValid(self: DependencySpec) bool {
        return self.name.len > 0 and self.url.len > 0;
    }
};
```

Example:

```zig
const dep = DependencySpec{
    .name = "zlib",
    .url = "https://github.com/madler/zlib",
    .hash = "1234567890abcdef",
    .version = .{ .major = 1, .minor = 3, .patch = 0 },
};
```

## Discussion

### Python vs Zig Package Distribution

The approaches differ fundamentally:

**Python (PyPI):**
```python
# setup.py
from setuptools import setup

setup(
    name='my-package',
    version='1.2.3',
    description='My awesome package',
    author='Jane Developer',
    install_requires=[
        'requests>=2.28.0',
        'numpy>=1.20.0',
    ],
    # ... more metadata
)

# Publish:
# python setup.py sdist upload
```

**Zig (Git-based):**
```zig
// build.zig.zon
.{
    .name = "my-package",
    .version = "1.2.3",
    .dependencies = .{
        .httpz = .{
            .url = "https://github.com/karlseguin/http.zig/archive/master.tar.gz",
            .hash = "1220abcdef...",
        },
    },
}

// Publish:
// git tag v1.2.3
// git push origin v1.2.3
```

Key differences:
- **Distribution**: Zig uses Git tags; Python uses PyPI
- **Dependencies**: Zig references Git URLs; Python uses package names
- **Verification**: Zig uses content hashes; Python uses signatures
- **Centralization**: Zig is decentralized; Python has a central repository

### Public API Design

Design a clean, stable public API for your package:

```zig
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
```

Usage:

```zig
const result = PublicAPI.process(10);

const options = PublicAPI.ProcessOptions{ .double = true, .add_ten = true };
const result2 = PublicAPI.processWithOptions(10, options);

const values = [_]i32{ 1, 2, 3 };
const results = try PublicAPI.processAdvanced(allocator, &values);
defer allocator.free(results);
```

### Library Organization

Organize exports into logical namespaces:

```zig
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
```

Usage:

```zig
Library.core.initialize();
defer Library.core.shutdown();

const result = Library.utils.helper(10);
const config = Library.types.Config{};
```

### Package Builder Pattern

Use the builder pattern for constructing package manifests:

```zig
var builder = PackageBuilder.init(allocator, metadata);
defer builder.deinit();

try builder.addDependency(.{
    .name = "dep1",
    .url = "https://example.com/dep1",
});

try builder.addDependency(.{
    .name = "dep2",
    .url = "https://example.com/dep2",
    .version = .{ .major = 1, .minor = 0, .patch = 0 },
});

const manifest = try builder.build();
defer manifest.deinit(allocator);
```

### Package Validation

Validate package metadata before distribution:

```zig
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

        if (pkg.version.major == 0 and
            pkg.version.minor == 0 and
            pkg.version.patch == 0) {
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
```

Usage:

```zig
try PackageValidator.validate(metadata);
```

### License Management

Define and validate licenses:

```zig
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
```

### Build Configuration

Define build options for different scenarios:

```zig
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
```

### Documentation Metadata

Embed documentation in your package:

```zig
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
```

## Best Practices

1. **Semantic Versioning**: Follow semantic versioning strictly (MAJOR.MINOR.PATCH)
2. **Stable Public API**: Don't break APIs in MINOR or PATCH releases
3. **Clear Documentation**: Document all public functions with `///` comments
4. **License Clarity**: Always include a LICENSE file and specify in metadata
5. **Version Compatibility**: Test against minimum required versions
6. **Change Tracking**: Maintain a CHANGELOG.md for each release
7. **Git Tags**: Use annotated tags for releases: `git tag -a v1.2.3 -m "Release 1.2.3"`
8. **Hash Verification**: Include content hashes for all dependencies
9. **Minimal Dependencies**: Keep dependency count low for reliability
10. **Testing**: Provide comprehensive tests that users can run

## Creating a Distributable Package

### Step 1: Prepare Your Code

Organize your project:

```
my-package/
├── build.zig
├── build.zig.zon
├── LICENSE
├── README.md
├── CHANGELOG.md
├── src/
│   └── main.zig (or lib.zig for libraries)
├── examples/
│   └── basic.zig
└── tests/
    └── test_main.zig
```

### Step 2: Create build.zig.zon

```zig
.{
    .name = "my-package",
    .version = "1.0.0",
    .dependencies = .{
        .somelib = .{
            .url = "https://github.com/user/somelib/archive/v1.0.0.tar.gz",
            .hash = "1220abcdef0123456789...",
        },
    },
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
        "README.md",
        "LICENSE",
    },
}
```

### Step 3: Design build.zig for Library Use

```zig
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create library artifact
    const lib = b.addStaticLibrary(.{
        .name = "my-package",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Install library
    b.installArtifact(lib);

    // Create module for downstream users
    _ = b.addModule("my-package", .{
        .root_source_file = b.path("src/main.zig"),
    });

    // Add tests
    const tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_tests.step);
}
```

### Step 4: Write README.md

```markdown
# My Package

Description of your package.

## Installation

Add to your `build.zig.zon`:

\`\`\`zig
.dependencies = .{
    .my_package = .{
        .url = "https://github.com/user/my-package/archive/v1.0.0.tar.gz",
        .hash = "1220...",
    },
},
\`\`\`

Then in your `build.zig`:

\`\`\`zig
const my_package = b.dependency("my_package", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("my-package", my_package.module("my-package"));
\`\`\`

## Usage

\`\`\`zig
const my_package = @import("my-package");

pub fn main() !void {
    const result = my_package.process(42);
}
\`\`\`

## License

MIT
```

### Step 5: Tag and Publish

```bash
# Commit all changes
git add .
git commit -m "Release v1.0.0"

# Create annotated tag
git tag -a v1.0.0 -m "Release version 1.0.0"

# Push tag to remote
git push origin v1.0.0

# Push commits
git push origin main
```

### Step 6: Generate Hash for build.zig.zon

Users will need the hash of your release tarball:

```bash
# Get the hash
zig fetch --save https://github.com/user/my-package/archive/v1.0.0.tar.gz

# This prints the hash like: 1220abcdef...
# Users add this to their build.zig.zon
```

## Common Patterns

**Versioned API Exports:**
```zig
pub const v1 = struct {
    pub fn oldFunction() void {}
};

pub const v2 = struct {
    pub fn newFunction() void {}
    pub fn improvedFunction() void {}
};

// Default to latest
pub usingnamespace v2;
```

**Feature Flags:**
```zig
pub const Features = struct {
    enable_networking: bool = false,
    enable_crypto: bool = true,
};

pub fn build(comptime features: Features) type {
    return struct {
        pub fn process() void {
            if (features.enable_networking) {
                // Network code
            }
        }
    };
}
```

**Backward Compatibility:**
```zig
// Deprecated but still available
pub const oldName = newName;

/// Deprecated: Use `newFunction` instead.
pub const oldFunction = newFunction;
```

## Troubleshooting

**Hash Mismatch:**
- Run `zig fetch --save <url>` to get the correct hash
- Verify the tag/commit hasn't changed
- Check for trailing whitespace in build.zig.zon

**Dependency Not Found:**
- Ensure the URL is accessible
- Check that the path in the archive matches expectations
- Verify Git tag exists

**Version Conflicts:**
- Use `zig build --verbose` to see dependency resolution
- Check for diamond dependencies with incompatible versions
- Consider relaxing version constraints

**Build Failures:**
- Ensure build.zig exposes the module correctly
- Check that all source files are in `.paths`
- Verify Zig version compatibility

## See Also

- Recipe 10.1: Making a Hierarchical Package of Modules - Module organization
- Recipe 10.9: Adding Directories to the Build Path - Multi-directory projects
- Recipe 1.3: Testing Strategy - Testing your package
- Recipe 9.11: Using Comptime to Control Instance Creation - Feature flags

Full compilable example: `code/03-advanced/10-modules-build-system/recipe_10_11.zig`
