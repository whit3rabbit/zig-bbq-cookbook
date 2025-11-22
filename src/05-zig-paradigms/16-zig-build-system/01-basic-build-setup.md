# Recipe 16.1: Basic build.zig Setup

## Problem

You need to create a build configuration for your Zig project that handles compilation, optimization levels, and target platforms.

## Solution

Create a `build.zig` file that uses the modern Zig build system API:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_1/build.zig:basic_build}}
```

Build and run your project:

```bash
zig build                    # Build with default settings (Debug)
zig build -Doptimize=ReleaseFast  # Build optimized
zig build run                # Build and run
zig build run -- arg1 arg2   # Pass arguments
```

## Discussion

### The Build Function

Every `build.zig` file exports a `build` function that receives a `*std.Build` parameter. This is the entry point for the build system.

### Optimization Options

The `standardOptimizeOption` method provides four build modes:

**Debug** (default)
- Fast compilation
- Safety checks enabled
- Slow runtime performance
- Useful for development

**ReleaseSafe**
- Optimized code
- Safety checks enabled
- Good balance for production

**ReleaseFast**
- Maximum performance
- Safety checks disabled
- Use when performance is critical

**ReleaseSmall**
- Optimized for binary size
- Safety checks disabled
- Useful for embedded systems

### Target Options

The `standardTargetOptions` method allows cross-compilation:

```bash
# Build for Linux x86_64
zig build -Dtarget=x86_64-linux

# Build for Windows
zig build -Dtarget=x86_64-windows

# Build for ARM
zig build -Dtarget=aarch64-linux
```

### Creating Executables

The `addExecutable` method creates an executable artifact:

```zig
const exe = b.addExecutable(.{
    .name = "myapp",              // Output name
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    }),
});
```

### Installing Artifacts

`installArtifact` copies the built executable to `zig-out/bin/`:

```zig
b.installArtifact(exe);
```

This runs automatically when you execute `zig build`.

### Run Steps

Create a run step to execute your program:

```zig
const run_cmd = b.addRunArtifact(exe);
run_cmd.step.dependOn(b.getInstallStep());

// Allow command-line arguments
if (b.args) |args| {
    run_cmd.addArgs(args);
}

const run_step = b.step("run", "Run the application");
run_step.dependOn(&run_cmd.step);
```

Now you can use `zig build run`.

### Build Modes in Detail

**Debug Mode:**
```bash
zig build
# - Safety checks: ON
# - Optimizations: OFF
# - Assertions: ON
# - Best for: Development
```

**ReleaseSafe Mode:**
```bash
zig build -Doptimize=ReleaseSafe
# - Safety checks: ON
# - Optimizations: ON
# - Assertions: OFF
# - Best for: Production with safety
```

**ReleaseFast Mode:**
```bash
zig build -Doptimize=ReleaseFast
# - Safety checks: OFF
# - Optimizations: MAXIMUM
# - Assertions: OFF
# - Best for: Performance-critical production
```

**ReleaseSmall Mode:**
```bash
zig build -Doptimize=ReleaseSmall
# - Safety checks: OFF
# - Optimizations: SIZE
# - Assertions: OFF
# - Best for: Embedded systems, small binaries
```

### Common Build Commands

```bash
# List all build steps
zig build --help

# Clean build artifacts
rm -rf zig-out .zig-cache

# Verbose output
zig build --verbose

# Summary output
zig build --summary all
```

### Project Structure

A typical Zig project structure:

```
myproject/
├── build.zig           # Build configuration
├── build.zig.zon       # Dependencies (optional)
├── src/
│   └── main.zig       # Main source file
└── zig-out/           # Build output (created by build)
    └── bin/
        └── myapp      # Executable
```

### Best Practices

1. **Use `b.path()` for file paths** - Ensures correct resolution
2. **Add standard options** - Makes your build flexible
3. **Create run steps** - Makes testing easier
4. **Install artifacts** - Ensures outputs go to standard locations
5. **Handle arguments** - Allow passing args to your program
6. **Document custom steps** - Use descriptive step names

### Advanced Configuration

You can add custom build options:

```zig
const enable_logging = b.option(bool, "logging", "Enable logging") orelse false;
const max_threads = b.option(u32, "threads", "Maximum threads") orelse 4;
```

Use them:

```bash
zig build -Dlogging=true -Dthreads=8
```

## See Also

- Recipe 16.2: Multiple Executables and Libraries
- Recipe 16.5: Cross-compilation
- Recipe 16.6: Build Options and Configurations

Full example: `code/05-zig-paradigms/16-zig-build-system/recipe_16_1/`
