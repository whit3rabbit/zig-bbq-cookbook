# Recipe 16.6: Build Options and Configurations

## Problem

You need to make your build process configurable with options that users can customize without modifying build.zig, and you want to inject configuration values into your code at compile time.

## Solution

Use Zig's build options system to create configurable builds. Define options in build.zig and access them in your code:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_6/build.zig:build_options}}
```

Then use these options in your source code:

```zig
const build_options = @import("build_options");

pub fn main() !void {
    if (build_options.enable_logging) {
        // Logging code
    }
}
```

## Discussion

Build options let you configure builds at compile time. They're evaluated during compilation, allowing the compiler to optimize away unused code paths.

### Build Configuration

Structure your configuration logically:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_6.zig:build_config}}
```

This creates a typed configuration structure that can be validated and reasoned about.

### Option Types

Zig supports various option types:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_6.zig:option_types}}
```

Common option types:
- **Boolean**: Enable/disable features (`bool`)
- **String**: Names, paths, URLs (`[]const u8`)
- **Integer**: Ports, limits, sizes (`u32`, `i64`, etc.)
- **Enum**: Predefined choices (`enum { dev, prod }`)

### Feature Flags

Manage feature flags systematically:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_6.zig:feature_flags}}
```

Feature flags control optional functionality:
- Enable experimental features
- Toggle debugging tools
- Control API versions
- Manage deprecated code paths

### Environment Configuration

Different environments need different settings:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_6.zig:environment_config}}
```

Common environments:
- **Development**: Debug logging, hot reload, relaxed validation
- **Staging**: Production-like with debug capabilities
- **Production**: Optimized, minimal logging, strict validation

### Conditional Compilation

Use comptime to conditionally include code:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_6.zig:conditional_compilation}}
```

This enables:
- Platform-specific code
- Feature-gated functionality
- Debug-only instrumentation
- Version-specific compatibility layers

### Optimization Profiles

Create named optimization profiles:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_6.zig:optimization_profiles}}
```

Profiles combine multiple settings:
- Optimization mode (Debug, ReleaseFast, ReleaseSmall, ReleaseSafe)
- Debug symbol stripping
- Link-time optimization (LTO)
- Assertions and safety checks

### Platform Options

Handle platform-specific configuration:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_6.zig:platform_options}}
```

Platform options control:
- System library linking
- Platform-specific features
- OS-specific code paths
- Architecture optimizations

## Using Build Options

Pass options on the command line:

```bash
# Boolean options
zig build -Denable-logging=true

# String options
zig build -Dserver-name=prod-server-01

# Integer options
zig build -Dmax-connections=500

# Enum options
zig build -Denvironment=production

# Multiple options
zig build -Denable-logging=true -Dmax-connections=1000 -Denvironment=production

# With optimization and target
zig build -Doptimize=ReleaseFast -Dtarget=x86_64-linux-musl -Denable-logging=false
```

## Accessing Options in Code

Import and use the generated options module:

```zig
const std = @import("std");
const build_options = @import("build_options");

pub fn main() !void {
    // Use boolean options
    if (build_options.enable_logging) {
        std.log.info("Logging enabled", .{});
    }

    // Use string options
    std.debug.print("Server: {s}\n", .{build_options.server_name});

    // Use integer options
    const max = build_options.max_connections;
    std.debug.print("Max connections: {d}\n", .{max});

    // Use enum options
    switch (build_options.environment) {
        .development => std.debug.print("Dev mode\n", .{}),
        .staging => std.debug.print("Staging mode\n", .{}),
        .production => std.debug.print("Production mode\n", .{}),
    }
}
```

## Conditional Compilation

Use options for conditional compilation:

```zig
const build_options = @import("build_options");

pub fn process() !void {
    // This code is completely removed if logging is disabled
    if (build_options.enable_logging) {
        std.log.debug("Processing started", .{});
    }

    // Do work...

    if (build_options.enable_logging) {
        std.log.debug("Processing complete", .{});
    }
}

// Feature-gated function
pub const experimentalFeature = if (build_options.enable_experimental)
    struct {
        pub fn doThing() void {
            // Implementation
        }
    }
else
    struct {
        pub fn doThing() void {
            @compileError("Experimental features not enabled");
        }
    };
```

## Best Practices

**Provide Sensible Defaults**: All options should have reasonable defaults. Don't force users to specify every option.

**Document Options**: Add clear descriptions to every option. Users see these with `zig build --help`.

**Validate Options**: Check option values in build.zig. Fail fast with clear error messages if values are invalid.

**Group Related Options**: Use consistent naming prefixes for related options (`db-host`, `db-port`, `db-name`).

**Version Configuration**: Include version info and build metadata in options for debugging production issues.

**Environment Variables**: Consider reading from environment variables as fallbacks:
```zig
const log_level = b.option([]const u8, "log-level", "Log level") orelse
    std.process.getEnvVarOwned(b.allocator, "LOG_LEVEL") catch "info";
```

**Avoid Magic Values**: Use enums instead of strings or integers for predefined choices.

## Common Patterns

**Feature Flags**:
```bash
zig build -Denable-metrics=true -Denable-tracing=true
```

**Environment Profiles**:
```bash
zig build -Denv=production -Dlog-level=error
```

**Debug Builds**:
```bash
zig build -Doptimize=Debug -Denable-logging=true -Denable-asserts=true
```

**Release Builds**:
```bash
zig build -Doptimize=ReleaseFast -Dstrip=true -Denable-logging=false
```

**CI/CD Builds**:
```bash
zig build -Denv=production -Dversion=$GIT_TAG -Dbuild-id=$CI_JOB_ID
```

## Listing Available Options

Users can see all available options:

```bash
# Show all build options
zig build --help

# Example output:
# Project-Specific Options:
#   -Denable-logging=[bool]        Enable debug logging (default: false)
#   -Dserver-name=[string]         Server name (default: myserver)
#   -Dmax-connections=[int]        Maximum connections (default: 100)
#   -Denvironment=[enum]           Deployment environment (default: development)
```

## See Also

- Recipe 16.1: Basic build.zig setup
- Recipe 16.4: Custom build steps
- Recipe 16.5: Cross-compilation

Full compilable example: `code/05-zig-paradigms/16-zig-build-system/recipe_16_6.zig`
