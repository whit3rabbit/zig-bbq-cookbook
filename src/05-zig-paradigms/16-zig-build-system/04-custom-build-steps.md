# Recipe 16.4: Custom Build Steps

## Problem

You need to extend your build process with custom commands like code generation, formatting, running external tools, or creating complex build pipelines.

## Solution

Use Zig's build system API to create custom build steps. Here's a comprehensive example showing various custom steps:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_4/build.zig:custom_steps}}
```

## Discussion

Custom build steps let you extend the build process beyond compiling code. The build system provides APIs for running commands, generating files, and orchestrating complex workflows.

### Step Information

Track metadata about build steps:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_4.zig:step_info}}
```

Each step has a name, description, and configuration. Steps can be marked as default (run when no target specified) or optional.

### Running External Commands

Execute external programs during the build:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_4.zig:command_step}}
```

Use `b.addSystemCommand()` to run any external command. You can:
- Pass arguments as an array of strings
- Set the working directory
- Capture stdout/stderr
- Chain commands together

### File Generation

Generate source files during the build process:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_4.zig:file_generation}}
```

Code generation is common in Zig projects. You might generate:
- Bindings from C headers
- Code from schema files (JSON, Protobuf, etc.)
- Configuration constants from build-time data
- Documentation or API clients

### Step Dependencies

Create dependency relationships between steps:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_4.zig:step_dependency}}
```

Use `step.dependOn()` to ensure steps run in the correct order. For example, code generation must complete before compilation starts.

### Installation Steps

Control where artifacts are installed:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_4.zig:install_step}}
```

Installation steps copy built artifacts to the output directory (typically `zig-out/`). You can customize:
- Destination directory (bin, lib, share, etc.)
- Subdirectories within destinations
- File permissions and names

### Run Steps

Create named run configurations:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_4.zig:run_step}}
```

Run steps execute built artifacts. Use them for:
- Running your application with specific arguments
- Running tests
- Benchmarking
- Development servers

### Check Steps

Add validation and linting:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_4.zig:check_step}}
```

Check steps verify code quality without building. Common checks include:
- Formatting (`zig fmt --check`)
- Compilation checks without code generation
- Custom linters
- License header validation

### Custom Targets

Group multiple steps into named targets:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_4.zig:custom_target}}
```

Custom targets orchestrate complex workflows. For example, a "release" target might:
1. Run all tests
2. Format code
3. Build optimized artifacts
4. Generate documentation
5. Create distribution archives

### Build Options

Add configurable options to your build:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_4.zig:build_option}}
```

Build options let users customize the build process:
```bash
zig build -Denable-logging=true
zig build -Dstrip=true -Doptimize=ReleaseFast
```

Options can be:
- Booleans (`bool`)
- Strings (`[]const u8`)
- Enums (custom types)
- Integers (`u32`, `i64`, etc.)

## Best Practices

**Order Steps Logically**: Use `dependOn()` to create clear dependency chains. Code generation before compilation, testing after building, etc.

**Capture Output When Needed**: Use `captureStdOut()` and `captureStdErr()` to work with command output. This is essential for code generation steps.

**Make Steps Optional**: Don't make every custom step a dependency of the default build. Let users opt-in with `zig build fmt` or `zig build docs`.

**Provide Descriptions**: Always add clear descriptions to custom steps. Users see these with `zig build --help`.

**Fail Fast**: Custom steps should exit with non-zero status on errors. Zig will stop the build and show the error.

**Use Caching**: Zig automatically caches build artifacts. Make sure custom steps support incremental builds by only regenerating changed files.

## Common Custom Steps

**Code Formatting**:
```bash
zig build fmt          # Format all source files
zig build fmt-check    # Check formatting without modifying
```

**Code Generation**:
```bash
zig build codegen      # Generate bindings, schemas, etc.
```

**Running Tools**:
```bash
zig build docs         # Generate documentation
zig build bench        # Run benchmarks
zig build lint         # Run custom linters
```

**Composite Workflows**:
```bash
zig build all          # Format, test, build, docs
zig build ci           # Full CI pipeline
zig build release      # Prepare release artifacts
```

## Common Commands

```bash
# List all available steps
zig build --help

# Run a custom step
zig build codegen

# Run multiple steps
zig build fmt test

# Pass arguments to run steps
zig build run -- --verbose --config=prod

# Run steps in verbose mode
zig build --verbose fmt test

# Check what would run without executing
zig build --dry-run all
```

## See Also

- Recipe 16.1: Basic build.zig setup
- Recipe 16.2: Multiple executables and libraries
- Recipe 16.3: Managing dependencies
- Recipe 16.6: Build options and configurations
- Recipe 16.7: Testing in build system

Full compilable example: `code/05-zig-paradigms/16-zig-build-system/recipe_16_4.zig`
