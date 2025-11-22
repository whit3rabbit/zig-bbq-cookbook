## Problem

You're familiar with Python's approach where you can run a package directly (`python -m mypackage` or `python mypackage.zip`). You want to create a runnable Zig package with a clear entry point. You need to understand how Zig's compiled approach differs from Python's interpreted model for creating executable packages.

## Solution

Use Zig's build system to define executable entry points. Unlike Python's runtime discovery of `__main__.py`, Zig requires explicit configuration in `build.zig` and a public `main` function in your entry point file. The build system produces standalone executables, not zip files with source code.

### Understanding Entry Points

Zig's approach differs from Python:

```zig
// In Python: python -m mypackage
// or: python mypackage.zip
//
// In Zig: zig build run
// or: ./zig-out/bin/myapp
//
// Entry point is defined in build.zig, not by file location
```

Python discovers entry points at runtime; Zig specifies them at build time.

### The Main Function

A runnable Zig program requires a public main function:

```zig
{{#include ../../../code/03-advanced/10-modules-build-system/recipe_10_7.zig:main_function}}
```

The `!void` return type means the function returns nothing or an error.

## Discussion

### Application Structure

Typical application organization:

```zig
// Typical application structure:
// src/
// ├── main.zig (this file - entry point)
// ├── app/ (application logic)
// │   ├── app.zig
// │   ├── commands.zig
// │   └── config.zig
// └── lib/ (reusable library code)
//     ├── utils.zig
//     └── types.zig
//
// build.zig at project root defines how to build
```

The `build.zig` file specifies which file contains your entry point.

### Error Sets

Define explicit error sets for better type safety:

```zig
const CommandError = error{
    InvalidArguments,
    ExecutionFailed,
    ResourceNotFound,
};
```

Avoid using `anyerror` - be specific about what can fail.

### Command Pattern

Structure commands with clear interfaces:

```zig
const Command = struct {
    name: []const u8,
    description: []const u8,
    run: *const fn () CommandError!void,
};

fn runHelp() !void {
    // Command implementation omitted for testing - not called at compile time
    _ = "help";
}

fn runVersion() !void {
    // Command implementation omitted for testing - not called at compile time
    _ = "version";
}

const commands = [_]Command{
    .{ .name = "help", .description = "Show help", .run = runHelp },
    .{ .name = "version", .description = "Show version", .run = runVersion },
};
```

This pattern allows for extensible command-line applications.

### Testing Entry Points

Test the application structure without calling main:

```zig
test "application has main entry point" {
    // The presence of pub fn main() makes this file executable
    // Tests verify application logic, not main() itself

    // Verify command structure
    try testing.expectEqual(@as(usize, 2), commands.len);
    try testing.expectEqualStrings("help", commands[0].name);
    try testing.expectEqualStrings("version", commands[1].name);
}
```

You can't easily test `main()` directly, but you can test the components it uses.

### Package Metadata

Include version and package information:

```zig
pub const PackageInfo = struct {
    name: []const u8,
    version: []const u8,
    description: []const u8,
    author: []const u8,
};

pub const package_info = PackageInfo{
    .name = "recipe_10_7",
    .version = "1.0.0",
    .description = "Executable package example",
    .author = "Zig BBQ Cookbook",
};
```

Test metadata accessibility:

```zig
test "package metadata" {
    try testing.expectEqualStrings("recipe_10_7", package_info.name);
    try testing.expectEqualStrings("1.0.0", package_info.version);
}
```

### Build Configuration

Configure your executable in `build.zig`:

```zig
// Build configuration (would be in build.zig):
//
// const exe = b.addExecutable(.{
//     .name = "recipe_10_7",
//     .root_source_file = b.path("src/recipe_10_7.zig"),
//     .target = target,
//     .optimize = optimize,
// });
//
// b.installArtifact(exe);
//
// const run_cmd = b.addRunArtifact(exe);
// const run_step = b.step("run", "Run the app");
// run_step.dependOn(&run_cmd.step);
```

This tells the build system how to create your executable.

### Argument Parsing

Parse command-line arguments:

```zig
const ParseError = error{
    UnknownCommand,
};

fn parseArgs(args: []const []const u8) ParseError!?[]const u8 {
    if (args.len < 2) {
        return null; // No command specified
    }

    // Find command
    const cmd_name = args[1];
    for (commands) |cmd| {
        if (std.mem.eql(u8, cmd.name, cmd_name)) {
            return cmd.name;
        }
    }

    // Command not found
    return ParseError.UnknownCommand;
}
```

Test argument parsing:

```zig
test "argument parsing" {
    // No arguments
    const args1 = [_][]const u8{"program"};
    const result1 = try parseArgs(&args1);
    try testing.expect(result1 == null);

    // Valid command
    const args2 = [_][]const u8{ "program", "help" };
    const result2 = try parseArgs(&args2);
    try testing.expect(result2 != null);
    try testing.expectEqualStrings("help", result2.?);

    // Another valid command
    const args3 = [_][]const u8{ "program", "version" };
    const result3 = try parseArgs(&args3);
    try testing.expectEqualStrings("version", result3.?);

    // Invalid command
    const args4 = [_][]const u8{ "program", "invalid" };
    const result4 = parseArgs(&args4);
    try testing.expectError(ParseError.UnknownCommand, result4);
}
```

Always test both success and error cases.

### Subcommand Pattern

Structure applications with subcommands:

```zig
const SubCommandError = error{
    InvalidArguments,
    InitFailed,
    BuildFailed,
    TestFailed,
};

const SubCommand = struct {
    name: []const u8,
    handler: *const fn ([]const []const u8) SubCommandError!void,
};

fn handleInit(args: []const []const u8) !void {
    _ = args;
    // Implementation omitted - not called at compile time
}

fn handleBuild(args: []const []const u8) !void {
    _ = args;
    // Implementation omitted - not called at compile time
}

fn handleTest(args: []const []const u8) !void {
    _ = args;
    // Implementation omitted - not called at compile time
}

const subcommands = [_]SubCommand{
    .{ .name = "init", .handler = handleInit },
    .{ .name = "build", .handler = handleBuild },
    .{ .name = "test", .handler = handleTest },
};
```

Subcommands allow complex CLI tools like `git`, where you have `git commit`, `git push`, etc.

Test subcommand structure:

```zig
test "subcommand structure" {
    try testing.expectEqual(@as(usize, 3), subcommands.len);

    // Verify subcommand names
    try testing.expectEqualStrings("init", subcommands[0].name);
    try testing.expectEqualStrings("build", subcommands[1].name);
    try testing.expectEqualStrings("test", subcommands[2].name);
}
```

### Application Context

Manage application state:

```zig
const AppContext = struct {
    allocator: std.mem.Allocator,
    verbose: bool,
    config_path: ?[]const u8,

    pub fn init(allocator: std.mem.Allocator) AppContext {
        return .{
            .allocator = allocator,
            .verbose = false,
            .config_path = null,
        };
    }

    pub fn setVerbose(self: *AppContext, verbose: bool) void {
        self.verbose = verbose;
    }

    pub fn setConfigPath(self: *AppContext, path: []const u8) void {
        self.config_path = path;
    }
};
```

Test context management:

```zig
test "application context" {
    var ctx = AppContext.init(testing.allocator);

    try testing.expect(!ctx.verbose);
    try testing.expect(ctx.config_path == null);

    ctx.setVerbose(true);
    try testing.expect(ctx.verbose);

    ctx.setConfigPath("config.json");
    try testing.expect(ctx.config_path != null);
    try testing.expectEqualStrings("config.json", ctx.config_path.?);
}
```

The context pattern centralizes application state.

### Exit Codes

Define standard exit codes:

```zig
pub const ExitCode = enum(u8) {
    success = 0,
    general_error = 1,
    usage_error = 2,
    config_error = 3,
    runtime_error = 4,
};

fn exitWithCode(code: ExitCode) noreturn {
    std.process.exit(@intFromEnum(code));
}
```

Test exit code values:

```zig
test "exit codes" {
    try testing.expectEqual(@as(u8, 0), @intFromEnum(ExitCode.success));
    try testing.expectEqual(@as(u8, 1), @intFromEnum(ExitCode.general_error));
    try testing.expectEqual(@as(u8, 2), @intFromEnum(ExitCode.usage_error));
}
```

Standard exit codes help shell scripts handle errors.

### Version Information

Implement custom version formatting:

```zig
pub const Version = struct {
    major: u32,
    minor: u32,
    patch: u32,

    pub fn format(
        self: Version,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{d}.{d}.{d}", .{ self.major, self.minor, self.patch });
    }
};

pub const version = Version{ .major = 1, .minor = 0, .patch = 0 };
```

Test version handling:

```zig
test "version formatting" {
    // Test version values directly
    try testing.expectEqual(@as(u32, 1), version.major);
    try testing.expectEqual(@as(u32, 0), version.minor);
    try testing.expectEqual(@as(u32, 0), version.patch);
}
```

The `format()` function enables `std.fmt.print("{}", .{version})`.

### Resource Embedding

Embed files at compile time:

```zig
// In build.zig, you can embed files:
// const embed = b.addModule("embed", .{
//     .root_source_file = b.path("embed.zig"),
// });
//
// Then in embed.zig:
// pub const help_text = @embedFile("help.txt");
// pub const config_template = @embedFile("config.json");
```

Embedded files become part of the binary.

### Build-Time Information

Access build information:

```zig
pub const build_info = struct {
    pub const zig_version = @import("builtin").zig_version_string;
    pub const build_mode = @import("builtin").mode;
};
```

Test build information access:

```zig
test "build time information" {
    // Verify we can access build information
    _ = build_info.zig_version;
    _ = build_info.build_mode;
}
```

Use this for debugging and diagnostics.

### Complete Example

A comprehensive application structure:

```zig
test "comprehensive executable package patterns" {
    // Package metadata
    try testing.expectEqualStrings("recipe_10_7", package_info.name);

    // Command structure
    try testing.expectEqual(@as(usize, 2), commands.len);

    // Subcommands
    try testing.expectEqual(@as(usize, 3), subcommands.len);

    // Application context
    var ctx = AppContext.init(testing.allocator);
    ctx.setVerbose(true);
    try testing.expect(ctx.verbose);

    // Exit codes
    try testing.expectEqual(@as(u8, 0), @intFromEnum(ExitCode.success));

    // Version
    try testing.expectEqual(@as(u32, 1), version.major);
    try testing.expectEqual(@as(u32, 0), version.minor);
    try testing.expectEqual(@as(u32, 0), version.patch);
}
```

All components work together to create a complete application.

### Python vs Zig Comparison

**Python Approach (Interpreted):**
```python
# Directory structure:
# mypackage/
#   __init__.py
#   __main__.py  # Discovered at runtime
#   commands.py

# Run with:
python -m mypackage

# Or package as zip:
python mypackage.zip
```

**Zig Approach (Compiled):**
```zig
// Directory structure:
// src/
//   main.zig  // Specified in build.zig
//   commands.zig
// build.zig  // Defines entry point

// Build and run:
zig build run

// Or run the binary:
./zig-out/bin/myapp
```

Key difference: Zig produces standalone executables, not zip files with source.

### Build.zig Example

A complete build configuration:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Define the executable
    const exe = b.addExecutable(.{
        .name = "myapp",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Install the executable
    b.installArtifact(exe);

    // Add run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // Allow passing args: zig build run -- arg1 arg2
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Add tests
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
```

This creates both `zig build run` and `zig build test` commands.

### Command Execution Pattern

Implement a complete command dispatcher:

```zig
pub fn executeCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    const cmd_name = try parseArgs(args) orelse {
        try showHelp();
        return;
    };

    for (commands) |cmd| {
        if (std.mem.eql(u8, cmd.name, cmd_name)) {
            try cmd.run();
            return;
        }
    }

    return ParseError.UnknownCommand;
}

fn showHelp() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Available commands:\n", .{});
    for (commands) |cmd| {
        try stdout.print("  {s}: {s}\n", .{ cmd.name, cmd.description });
    }
}
```

This pattern dispatches to the appropriate command handler.

### Argument Handling

Process arguments in main:

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get command-line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Execute command
    executeCommand(allocator, args) catch |err| {
        const stderr = std.io.getStdErr().writer();
        try stderr.print("Error: {}\n", .{err});
        std.process.exit(@intFromEnum(ExitCode.general_error));
    };
}
```

Always clean up allocated arguments.

### Error Handling Strategy

Handle errors at the appropriate level:

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) {
            std.debug.print("Memory leak detected!\n", .{});
        }
    }
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Try to execute, catch and report errors
    executeCommand(allocator, args) catch |err| switch (err) {
        ParseError.UnknownCommand => {
            const stderr = std.io.getStdErr().writer();
            try stderr.print("Unknown command. Use 'help' for available commands.\n", .{});
            std.process.exit(@intFromEnum(ExitCode.usage_error));
        },
        else => {
            const stderr = std.io.getStdErr().writer();
            try stderr.print("Error: {}\n", .{err});
            std.process.exit(@intFromEnum(ExitCode.general_error));
        },
    };
}
```

Different error types should result in different exit codes.

### Configuration Files

Load configuration at startup:

```zig
const Config = struct {
    verbose: bool,
    log_level: i32,
    output_path: []const u8,

    pub fn loadFromFile(allocator: std.mem.Allocator, path: []const u8) !Config {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const contents = try file.readToEndAlloc(allocator, 1024 * 1024);
        defer allocator.free(contents);

        // Parse config file (JSON, TOML, etc.)
        // Return parsed config
    }
};
```

Load config early in main and pass to commands.

### Directory vs Executable

Unlike Python, Zig doesn't execute directories:

**Python:**
```bash
# Python can execute a directory
python mypackage/

# Or a zip file
python mypackage.zip
```

**Zig:**
```bash
# Zig produces a binary
zig build

# Execute the binary
./zig-out/bin/myapp

# Or run directly
zig build run
```

Zig's approach produces faster, standalone executables.

### Best Practices

**Use Explicit Error Sets:**
```zig
// Good: Specific errors
const ParseError = error{
    UnknownCommand,
    MissingArgument,
};

// Bad: Too general
fn parseArgs(args: []const u8) anyerror!void { ... }
```

**Centralize Application State:**
```zig
// Good: Single context
const AppContext = struct {
    allocator: std.mem.Allocator,
    config: Config,
    verbose: bool,
};

// Bad: Global variables
var verbose: bool = false;
var config: Config = undefined;
```

**Provide Help Text:**
```zig
const commands = [_]Command{
    .{ .name = "help", .description = "Show this help message", .run = showHelp },
    .{ .name = "version", .description = "Show version information", .run = showVersion },
    .{ .name = "build", .description = "Build the project", .run = runBuild },
};
```

**Handle Signals Gracefully:**
```zig
// Catch Ctrl+C for cleanup
const signal_action = std.os.Sigaction{
    .handler = .{ .handler = handleSignal },
    .mask = std.os.empty_sigset,
    .flags = 0,
};
try std.os.sigaction(std.os.SIG.INT, &signal_action, null);
```

### Testing CLI Applications

Test components individually:

```zig
test "command parsing" {
    // Test argument parsing
    const result = try parseArgs(&.{ "myapp", "build", "--release" });
    try testing.expectEqualStrings("build", result.?);
}

test "config loading" {
    // Test configuration
    const config = try Config.loadDefaults(testing.allocator);
    try testing.expect(!config.verbose);
}

test "error handling" {
    // Test error cases
    const result = parseArgs(&.{ "myapp", "invalid" });
    try testing.expectError(ParseError.UnknownCommand, result);
}
```

Integration tests can spawn the actual binary and test output.

### Summary

Key differences between Python and Zig executable packages:

**Python:**
- Runtime discovery of entry points
- Can execute directories and zip files
- Slower startup (interpreter overhead)
- Requires Python installed

**Zig:**
- Build-time specification in build.zig
- Produces standalone binaries
- Fast startup (native code)
- No runtime dependencies

Both approaches work, but Zig's compiled model offers better performance and simpler deployment.

## See Also

- Recipe 10.1: Making a hierarchical package of modules
- Recipe 10.4: Splitting a module into multiple files
- Recipe 10.6: Reloading modules

Full compilable example: `code/03-advanced/10-modules-build-system/recipe_10_7.zig`
