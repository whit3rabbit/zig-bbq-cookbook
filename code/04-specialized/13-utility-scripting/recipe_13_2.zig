const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_exit
/// Exit with an error code
fn exitWithError(code: u8) noreturn {
    std.process.exit(code);
}

// We can't test functions that call exit(), but we can demonstrate the pattern
test "exit codes are u8 values" {
    // Standard exit codes
    const success: u8 = 0;
    const general_error: u8 = 1;
    const misuse: u8 = 2;

    try testing.expectEqual(0, success);
    try testing.expectEqual(1, general_error);
    try testing.expectEqual(2, misuse);
}
// ANCHOR_END: basic_exit

// ANCHOR: error_to_stderr
/// Print error message to stderr and return error code
fn reportError(comptime fmt: []const u8, args: anytype) u8 {
    // std.debug.print writes to stderr
    std.debug.print(fmt, args);
    return 1;
}

test "error messages use stderr" {
    // We can verify the function returns the right error code
    const code = reportError("Error: {s}\n", .{"something went wrong"});
    try testing.expectEqual(1, code);
}
// ANCHOR_END: error_to_stderr

// ANCHOR: custom_error_types
/// Common exit codes for command-line tools
pub const ExitCode = enum(u8) {
    success = 0,
    general_error = 1,
    misuse_of_shell_builtins = 2,
    command_not_found = 127,
    invalid_exit_code = 128,

    pub fn toInt(self: ExitCode) u8 {
        return @intFromEnum(self);
    }
};

test "exit code enum" {
    try testing.expectEqual(0, ExitCode.success.toInt());
    try testing.expectEqual(1, ExitCode.general_error.toInt());
    try testing.expectEqual(127, ExitCode.command_not_found.toInt());
}
// ANCHOR_END: custom_error_types

// ANCHOR: error_with_context
/// Error with context information
pub const CommandError = struct {
    message: []const u8,
    code: ExitCode,

    pub fn report(self: CommandError) void {
        std.debug.print("Error: {s}\n", .{self.message});
    }

    pub fn exit(self: CommandError) noreturn {
        self.report();
        std.process.exit(self.code.toInt());
    }
};

test "command error structure" {
    const err = CommandError{
        .message = "file not found",
        .code = ExitCode.general_error,
    };

    try testing.expectEqualStrings("file not found", err.message);
    try testing.expectEqual(ExitCode.general_error, err.code);
}
// ANCHOR_END: error_with_context

// ANCHOR: fatal_error
/// Fatal error function that prints to stderr and exits
fn fatal(comptime fmt: []const u8, args: anytype) noreturn {
    std.debug.print("Fatal: ", .{});
    std.debug.print(fmt, args);
    std.debug.print("\n", .{});
    std.process.exit(1);
}

// We test the pattern without actually calling fatal
test "fatal error pattern" {
    // Just verify we can format the same way fatal does
    var buf: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const writer = fbs.writer();

    try writer.print("Fatal: ", .{});
    try writer.print("{s}", .{"configuration file missing"});
    try writer.print("\n", .{});

    try testing.expect(std.mem.startsWith(u8, fbs.getWritten(), "Fatal:"));
}
// ANCHOR_END: fatal_error

// ANCHOR: error_with_usage
/// Print error with usage information
fn usageError(program_name: []const u8, message: []const u8) u8 {
    std.debug.print("Error: {s}\n\n", .{message});
    std.debug.print("Usage: {s} [options] <file>\n", .{program_name});
    std.debug.print("Try '{s} --help' for more information.\n", .{program_name});

    return ExitCode.misuse_of_shell_builtins.toInt();
}

test "usage error includes program name" {
    const code = usageError("mytool", "missing required argument");
    try testing.expectEqual(2, code);
}
// ANCHOR_END: error_with_usage

// ANCHOR: error_categories
/// Different categories of errors
pub const ErrorCategory = enum {
    usage, // Command-line usage error
    io, // File or I/O error
    permission, // Permission denied
    not_found, // Resource not found
    internal, // Internal program error

    pub fn exitCode(self: ErrorCategory) u8 {
        return switch (self) {
            .usage => 2,
            .io => 1,
            .permission => 77,
            .not_found => 127,
            .internal => 70,
        };
    }

    pub fn prefix(self: ErrorCategory) []const u8 {
        return switch (self) {
            .usage => "Usage error",
            .io => "I/O error",
            .permission => "Permission denied",
            .not_found => "Not found",
            .internal => "Internal error",
        };
    }
};

test "error categories have codes and prefixes" {
    try testing.expectEqual(2, ErrorCategory.usage.exitCode());
    try testing.expectEqualStrings("Usage error", ErrorCategory.usage.prefix());

    try testing.expectEqual(127, ErrorCategory.not_found.exitCode());
    try testing.expectEqualStrings("Not found", ErrorCategory.not_found.prefix());
}
// ANCHOR_END: error_categories

// ANCHOR: categorized_error
/// Print categorized error message
fn reportCategorizedError(category: ErrorCategory, message: []const u8) u8 {
    std.debug.print("{s}: {s}\n", .{ category.prefix(), message });
    return category.exitCode();
}

test "categorized error reporting" {
    const code = reportCategorizedError(.not_found, "config.json");
    try testing.expectEqual(127, code);
}
// ANCHOR_END: categorized_error

// ANCHOR: error_builder
/// Builder pattern for error messages
pub const ErrorBuilder = struct {
    category: ErrorCategory,
    message: []const u8,
    hint: ?[]const u8 = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, category: ErrorCategory, message: []const u8) ErrorBuilder {
        return .{
            .allocator = allocator,
            .category = category,
            .message = message,
        };
    }

    pub fn withHint(self: *ErrorBuilder, hint: []const u8) *ErrorBuilder {
        self.hint = hint;
        return self;
    }

    pub fn report(self: ErrorBuilder) u8 {
        std.debug.print("{s}: {s}\n", .{ self.category.prefix(), self.message });

        if (self.hint) |h| {
            std.debug.print("Hint: {s}\n", .{h});
        }

        return self.category.exitCode();
    }
};

test "error builder pattern" {
    var builder = ErrorBuilder.init(
        testing.allocator,
        .io,
        "cannot read file"
    );

    _ = builder.withHint("check file permissions");

    const code = builder.report();
    try testing.expectEqual(1, code);
}
// ANCHOR_END: error_builder

// ANCHOR: stack_trace_error
/// Capture error with stack trace information
pub fn panicHandler(msg: []const u8, trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = trace;
    _ = ret_addr;

    std.debug.print("PANIC: {s}\n", .{msg});
    std.process.exit(1);
}

test "panic handler writes to stderr" {
    // We can't actually test the panic handler,
    // but we verify the signature is correct
    const HandlerType = @TypeOf(panicHandler);
    _ = HandlerType;
}
// ANCHOR_END: stack_trace_error

// ANCHOR: multi_error_accumulation
/// Accumulate multiple errors before exiting
pub const ErrorAccumulator = struct {
    errors: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ErrorAccumulator {
        return .{
            .errors = std.ArrayList([]const u8){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ErrorAccumulator) void {
        for (self.errors.items) |err_msg| {
            self.allocator.free(err_msg);
        }
        self.errors.deinit(self.allocator);
    }

    pub fn add(self: *ErrorAccumulator, message: []const u8) !void {
        const copy = try self.allocator.dupe(u8, message);
        try self.errors.append(self.allocator, copy);
    }

    pub fn hasErrors(self: *const ErrorAccumulator) bool {
        return self.errors.items.len > 0;
    }

    pub fn report(self: *const ErrorAccumulator) u8 {
        if (self.errors.items.len == 0) return 0;

        std.debug.print("Found {d} error(s):\n", .{self.errors.items.len});

        for (self.errors.items, 0..) |err_msg, i| {
            std.debug.print("  {d}. {s}\n", .{ i + 1, err_msg });
        }

        return 1;
    }
};

test "error accumulator" {
    var acc = ErrorAccumulator.init(testing.allocator);
    defer acc.deinit();

    try testing.expect(!acc.hasErrors());

    try acc.add("first error");
    try acc.add("second error");

    try testing.expect(acc.hasErrors());
    try testing.expectEqual(2, acc.errors.items.len);

    const code = acc.report();
    try testing.expectEqual(1, code);
}
// ANCHOR_END: multi_error_accumulation
