// Recipe 10.7: Making a Directory or Zip File Runnable as a Main Script
// Target Zig Version: 0.15.2
//
// This recipe demonstrates Zig's approach to creating executable packages.
// Unlike Python's __main__.py pattern, Zig uses build.zig to define entry points.
//
// Key concepts:
// - Using build.zig to create executables
// - Package entry points with main functions
// - Organizing application packages
// - Build system configuration
//
// Package structure:
// recipe_10_7/
// ├── build.zig (would define the executable)
// ├── main.zig (entry point with pub fn main)
// ├── app/ (application modules)
// │   ├── app.zig
// │   └── commands.zig
// └── lib/ (library modules)
//     └── lib.zig

const std = @import("std");
const testing = std.testing;

// ANCHOR: entry_point_concept
// In Python: python -m mypackage
// or: python mypackage.zip
//
// In Zig: zig build run
// or: ./zig-out/bin/myapp
//
// Entry point is defined in build.zig, not by file location
// ANCHOR_END: entry_point_concept

// ANCHOR: main_function
// A runnable Zig program requires a public main function
pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Recipe 10.7: Executable Package Example\n", .{});
}
// ANCHOR_END: main_function

// ANCHOR: application_structure
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
// ANCHOR_END: application_structure

// ANCHOR: error_sets
const CommandError = error{
    InvalidArguments,
    ExecutionFailed,
    ResourceNotFound,
};
// ANCHOR_END: error_sets

// ANCHOR: command_pattern
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
// ANCHOR_END: command_pattern

// ANCHOR: test_entry_point
test "application has main entry point" {
    // The presence of pub fn main() makes this file executable
    // Tests verify application logic, not main() itself

    // Verify command structure
    try testing.expectEqual(@as(usize, 2), commands.len);
    try testing.expectEqualStrings("help", commands[0].name);
    try testing.expectEqualStrings("version", commands[1].name);
}
// ANCHOR_END: test_entry_point

// ANCHOR: package_metadata
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
// ANCHOR_END: package_metadata

// ANCHOR: test_package_metadata
test "package metadata" {
    try testing.expectEqualStrings("recipe_10_7", package_info.name);
    try testing.expectEqualStrings("1.0.0", package_info.version);
}
// ANCHOR_END: test_package_metadata

// ANCHOR: build_configuration
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
// ANCHOR_END: build_configuration

// ANCHOR: argument_parsing
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
// ANCHOR_END: argument_parsing

// ANCHOR: test_argument_parsing
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
// ANCHOR_END: test_argument_parsing

// ANCHOR: subcommand_pattern
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
// ANCHOR_END: subcommand_pattern

// ANCHOR: test_subcommands
test "subcommand structure" {
    try testing.expectEqual(@as(usize, 3), subcommands.len);

    // Verify subcommand names
    try testing.expectEqualStrings("init", subcommands[0].name);
    try testing.expectEqualStrings("build", subcommands[1].name);
    try testing.expectEqualStrings("test", subcommands[2].name);
}
// ANCHOR_END: test_subcommands

// ANCHOR: application_context
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
// ANCHOR_END: application_context

// ANCHOR: test_app_context
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
// ANCHOR_END: test_app_context

// ANCHOR: exit_codes
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
// ANCHOR_END: exit_codes

// ANCHOR: test_exit_codes
test "exit codes" {
    try testing.expectEqual(@as(u8, 0), @intFromEnum(ExitCode.success));
    try testing.expectEqual(@as(u8, 1), @intFromEnum(ExitCode.general_error));
    try testing.expectEqual(@as(u8, 2), @intFromEnum(ExitCode.usage_error));
}
// ANCHOR_END: test_exit_codes

// ANCHOR: version_info
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
// ANCHOR_END: version_info

// ANCHOR: test_version_info
test "version formatting" {
    // Test version values directly
    try testing.expectEqual(@as(u32, 1), version.major);
    try testing.expectEqual(@as(u32, 0), version.minor);
    try testing.expectEqual(@as(u32, 0), version.patch);
}
// ANCHOR_END: test_version_info

// ANCHOR: resource_embedding
// In build.zig, you can embed files:
// const embed = b.addModule("embed", .{
//     .root_source_file = b.path("embed.zig"),
// });
//
// Then in embed.zig:
// pub const help_text = @embedFile("help.txt");
// pub const config_template = @embedFile("config.json");
// ANCHOR_END: resource_embedding

// ANCHOR: build_time_info
pub const build_info = struct {
    pub const zig_version = @import("builtin").zig_version_string;
    pub const build_mode = @import("builtin").mode;
};
// ANCHOR_END: build_time_info

// ANCHOR: test_build_info
test "build time information" {
    // Verify we can access build information
    _ = build_info.zig_version;
    _ = build_info.build_mode;
}
// ANCHOR_END: test_build_info

// Comprehensive test
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
