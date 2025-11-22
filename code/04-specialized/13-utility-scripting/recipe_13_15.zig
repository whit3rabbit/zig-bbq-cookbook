const std = @import("std");
const testing = std.testing;

// ANCHOR: simple_args
/// Simple argument parser
pub const SimpleArgs = struct {
    args: [][]const u8,
    allocator: std.mem.Allocator,

    pub fn parse(allocator: std.mem.Allocator) !SimpleArgs {
        const args = try std.process.argsAlloc(allocator);
        return .{
            .args = args,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SimpleArgs) void {
        std.process.argsFree(self.allocator, self.args);
    }

    pub fn programName(self: *const SimpleArgs) []const u8 {
        return if (self.args.len > 0) self.args[0] else "program";
    }

    pub fn get(self: *const SimpleArgs, index: usize) ?[]const u8 {
        if (index >= self.args.len) return null;
        return self.args[index];
    }

    pub fn count(self: *const SimpleArgs) usize {
        return self.args.len;
    }
};

test "simple args" {
    const args = [_][]const u8{ "program", "arg1", "arg2" };
    const simple = SimpleArgs{
        .args = @constCast(&args),
        .allocator = testing.allocator,
    };

    try testing.expectEqualStrings("program", simple.programName());
    try testing.expectEqual(3, simple.count());
    try testing.expectEqualStrings("arg1", simple.get(1).?);
    try testing.expect(simple.get(10) == null);
}
// ANCHOR_END: simple_args

// ANCHOR: option_parser
/// Command-line option parser
pub const OptionParser = struct {
    args: [][]const u8,
    current: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, args: [][]const u8) OptionParser {
        return .{
            .args = args,
            .current = 1, // Skip program name
            .allocator = allocator,
        };
    }

    pub fn next(self: *OptionParser) ?[]const u8 {
        if (self.current >= self.args.len) return null;
        const arg = self.args[self.current];
        self.current += 1;
        return arg;
    }

    pub fn hasFlag(self: *OptionParser, short: u8, long: []const u8) bool {
        var i = self.current;
        while (i < self.args.len) : (i += 1) {
            const arg = self.args[i];
            if (arg.len == 2 and arg[0] == '-' and arg[1] == short) return true;
            if (std.mem.eql(u8, arg, long)) return true;
        }
        return false;
    }

    pub fn getOption(self: *OptionParser, short: u8, long: []const u8) ?[]const u8 {
        var i = self.current;
        while (i < self.args.len) : (i += 1) {
            const arg = self.args[i];

            // Short option: -o value
            if (arg.len == 2 and arg[0] == '-' and arg[1] == short) {
                if (i + 1 < self.args.len) {
                    return self.args[i + 1];
                }
                return null;
            }

            // Long option: --output=value
            if (std.mem.startsWith(u8, arg, long)) {
                if (std.mem.indexOf(u8, arg, "=")) |eq_pos| {
                    return arg[eq_pos + 1 ..];
                }
                // Long option: --output value
                if (i + 1 < self.args.len) {
                    return self.args[i + 1];
                }
            }
        }
        return null;
    }

    pub fn positionals(self: *const OptionParser) ![][]const u8 {
        var result = std.ArrayList([]const u8){};
        errdefer result.deinit(self.allocator);

        var i = self.current;
        while (i < self.args.len) : (i += 1) {
            const arg = self.args[i];

            // Not an option - it's a positional
            if (!std.mem.startsWith(u8, arg, "-")) {
                try result.append(self.allocator, arg);
            }
        }

        return try result.toOwnedSlice(self.allocator);
    }
};

test "option parser flags" {
    const args = [_][]const u8{ "program", "-v", "--help", "file.txt" };
    var parser = OptionParser.init(testing.allocator, @constCast(&args));

    try testing.expect(parser.hasFlag('v', "--verbose"));
    try testing.expect(parser.hasFlag('h', "--help"));
    try testing.expect(!parser.hasFlag('x', "--extra"));
}

test "option parser with values" {
    const args = [_][]const u8{ "program", "-o", "output.txt", "--input=input.txt" };
    var parser = OptionParser.init(testing.allocator, @constCast(&args));

    const output = parser.getOption('o', "--output");
    try testing.expectEqualStrings("output.txt", output.?);

    const input = parser.getOption('i', "--input");
    try testing.expectEqualStrings("input.txt", input.?);
}

test "option parser positionals" {
    const args = [_][]const u8{ "program", "-v", "file1.txt", "--output=out.txt", "file2.txt" };
    var parser = OptionParser.init(testing.allocator, @constCast(&args));

    const pos = try parser.positionals();
    defer testing.allocator.free(pos);

    try testing.expectEqual(2, pos.len);
    try testing.expectEqualStrings("file1.txt", pos[0]);
    try testing.expectEqualStrings("file2.txt", pos[1]);
}
// ANCHOR_END: option_parser

// ANCHOR: command_line
/// Structured command-line interface
pub const CommandLine = struct {
    pub const Option = struct {
        short: ?u8,
        long: []const u8,
        description: []const u8,
        value_name: ?[]const u8,
        required: bool,
    };

    program_name: []const u8,
    description: []const u8,
    options: []const Option,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, desc: []const u8, opts: []const Option) CommandLine {
        return .{
            .program_name = name,
            .description = desc,
            .options = opts,
            .allocator = allocator,
        };
    }

    pub fn printHelp(self: *const CommandLine) !void {
        const stderr = std.fs.File{ .handle = 2 };

        try stderr.writeAll("Usage: ");
        try stderr.writeAll(self.program_name);
        try stderr.writeAll(" [OPTIONS]\n\n");
        try stderr.writeAll(self.description);
        try stderr.writeAll("\n\nOptions:\n");

        for (self.options) |opt| {
            var buf: [256]u8 = undefined;
            var line = std.ArrayList(u8){};
            defer line.deinit(self.allocator);

            try line.appendSlice(self.allocator, "  ");

            if (opt.short) |s| {
                const short_str = try std.fmt.bufPrint(&buf, "-{c}", .{s});
                try line.appendSlice(self.allocator, short_str);
                try line.appendSlice(self.allocator, ", ");
            } else {
                try line.appendSlice(self.allocator, "    ");
            }

            try line.appendSlice(self.allocator, opt.long);

            if (opt.value_name) |vname| {
                try line.appendSlice(self.allocator, "=");
                try line.appendSlice(self.allocator, vname);
            }

            // Padding
            const needed_padding = if (30 > line.items.len) 30 - line.items.len else 1;
            var i: usize = 0;
            while (i < needed_padding) : (i += 1) {
                try line.append(self.allocator, ' ');
            }

            try line.appendSlice(self.allocator, opt.description);

            if (opt.required) {
                try line.appendSlice(self.allocator, " (required)");
            }

            try line.append(self.allocator, '\n');

            try stderr.writeAll(line.items);
        }
    }

    pub fn parse(self: *const CommandLine, args: [][]const u8) !ParsedArgs {
        var parser = OptionParser.init(self.allocator, args);
        var values = std.StringHashMap([]const u8).init(self.allocator);
        errdefer values.deinit();

        // Check for help flag
        if (parser.hasFlag('h', "--help")) {
            try self.printHelp();
            return error.HelpRequested;
        }

        // Parse all defined options
        for (self.options) |opt| {
            const short = opt.short orelse 0;
            const value = parser.getOption(short, opt.long);

            if (value) |v| {
                try values.put(opt.long, v);
            } else if (opt.required) {
                const stderr = std.fs.File{ .handle = 2 };
                var buf: [256]u8 = undefined;
                const msg = try std.fmt.bufPrint(&buf, "Error: required option {s} not provided\n", .{opt.long});
                try stderr.writeAll(msg);
                return error.MissingRequiredOption;
            }
        }

        const pos = try parser.positionals();

        return .{
            .values = values,
            .positionals = pos,
            .allocator = self.allocator,
        };
    }
};

pub const ParsedArgs = struct {
    values: std.StringHashMap([]const u8),
    positionals: [][]const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *ParsedArgs) void {
        self.values.deinit();
        self.allocator.free(self.positionals);
    }

    pub fn get(self: *const ParsedArgs, key: []const u8) ?[]const u8 {
        return self.values.get(key);
    }

    pub fn getOrDefault(self: *const ParsedArgs, key: []const u8, default: []const u8) []const u8 {
        return self.values.get(key) orelse default;
    }
};

test "command line interface" {
    const options = [_]CommandLine.Option{
        .{
            .short = 'o',
            .long = "--output",
            .description = "Output file",
            .value_name = "FILE",
            .required = false,
        },
        .{
            .short = 'v',
            .long = "--verbose",
            .description = "Verbose output",
            .value_name = null,
            .required = false,
        },
    };

    const cli = CommandLine.init(testing.allocator, "myprogram", "A test program", &options);

    const args = [_][]const u8{ "myprogram", "--output=out.txt", "input.txt" };
    var parsed = try cli.parse(@constCast(&args));
    defer parsed.deinit();

    try testing.expectEqualStrings("out.txt", parsed.get("--output").?);
    try testing.expectEqual(1, parsed.positionals.len);
}
// ANCHOR_END: command_line

// ANCHOR: subcommands
/// Subcommand support
pub const SubcommandParser = struct {
    pub const Command = struct {
        name: []const u8,
        description: []const u8,
        handler: *const fn (args: [][]const u8) anyerror!void,
    };

    program_name: []const u8,
    commands: []const Command,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, cmds: []const Command) SubcommandParser {
        return .{
            .program_name = name,
            .commands = cmds,
            .allocator = allocator,
        };
    }

    pub fn printHelp(self: *const SubcommandParser) !void {
        const stderr = std.fs.File{ .handle = 2 };

        try stderr.writeAll("Usage: ");
        try stderr.writeAll(self.program_name);
        try stderr.writeAll(" <command> [args]\n\nCommands:\n");

        for (self.commands) |cmd| {
            var buf: [256]u8 = undefined;
            const line = try std.fmt.bufPrint(&buf, "  {s:<15} {s}\n", .{ cmd.name, cmd.description });
            try stderr.writeAll(line);
        }
    }

    pub fn execute(self: *const SubcommandParser, args: [][]const u8) !void {
        if (args.len < 2) {
            try self.printHelp();
            return error.NoCommand;
        }

        const cmd_name = args[1];

        for (self.commands) |cmd| {
            if (std.mem.eql(u8, cmd.name, cmd_name)) {
                return cmd.handler(args[2..]);
            }
        }

        const stderr = std.fs.File{ .handle = 2 };
        var buf: [256]u8 = undefined;
        const msg = try std.fmt.bufPrint(&buf, "Error: unknown command '{s}'\n", .{cmd_name});
        try stderr.writeAll(msg);
        return error.UnknownCommand;
    }
};

fn testHandler(args: [][]const u8) !void {
    _ = args;
    // Test handler does nothing
}

test "subcommand parser" {
    const commands = [_]SubcommandParser.Command{
        .{
            .name = "build",
            .description = "Build the project",
            .handler = testHandler,
        },
        .{
            .name = "test",
            .description = "Run tests",
            .handler = testHandler,
        },
    };

    const parser = SubcommandParser.init(testing.allocator, "tool", &commands);

    const args = [_][]const u8{ "tool", "build", "--release" };
    try parser.execute(@constCast(&args));
}
// ANCHOR_END: subcommands

// ANCHOR: arg_validator
/// Validate arguments
pub const ArgValidator = struct {
    pub fn requirePositionals(args: [][]const u8, min: usize) !void {
        if (args.len < min) {
            const stderr = std.fs.File{ .handle = 2 };
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "Error: expected at least {d} arguments, got {d}\n", .{ min, args.len });
            try stderr.writeAll(msg);
            return error.TooFewArguments;
        }
    }

    pub fn validateChoice(value: []const u8, choices: []const []const u8) !void {
        for (choices) |choice| {
            if (std.mem.eql(u8, value, choice)) return;
        }

        const stderr = std.fs.File{ .handle = 2 };
        try stderr.writeAll("Error: invalid choice '");
        try stderr.writeAll(value);
        try stderr.writeAll("'. Valid choices: ");

        for (choices, 0..) |choice, i| {
            try stderr.writeAll(choice);
            if (i < choices.len - 1) {
                try stderr.writeAll(", ");
            }
        }
        try stderr.writeAll("\n");

        return error.InvalidChoice;
    }

    pub fn validateInteger(value: []const u8, comptime T: type) !T {
        return std.fmt.parseInt(T, value, 10) catch {
            const stderr = std.fs.File{ .handle = 2 };
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "Error: '{s}' is not a valid integer\n", .{value});
            try stderr.writeAll(msg);
            return error.InvalidInteger;
        };
    }

    pub fn validateRange(value: anytype, min: @TypeOf(value), max: @TypeOf(value)) !void {
        if (value < min or value > max) {
            const stderr = std.fs.File{ .handle = 2 };
            var buf: [256]u8 = undefined;
            const msg = try std.fmt.bufPrint(&buf, "Error: value {d} out of range [{d}, {d}]\n", .{ value, min, max });
            try stderr.writeAll(msg);
            return error.OutOfRange;
        }
    }
};

test "arg validator" {
    const args = [_][]const u8{ "file1.txt", "file2.txt" };
    try ArgValidator.requirePositionals(@constCast(&args), 2);

    const choices = [_][]const u8{ "fast", "slow", "medium" };
    try ArgValidator.validateChoice("fast", @constCast(&choices));

    const num = try ArgValidator.validateInteger("42", i32);
    try testing.expectEqual(42, num);

    try ArgValidator.validateRange(50, 0, 100);
}
// ANCHOR_END: arg_validator

// ANCHOR: env_fallback
/// Use environment variables as fallback
pub fn getArgOrEnv(allocator: std.mem.Allocator, arg_value: ?[]const u8, env_var: []const u8, default: []const u8) ![]const u8 {
    if (arg_value) |val| {
        return val;
    }

    if (std.process.getEnvVarOwned(allocator, env_var)) |env_val| {
        return env_val;
    } else |_| {
        return default;
    }
}

test "arg or env fallback" {
    const result1 = try getArgOrEnv(testing.allocator, "from_arg", "SOME_VAR", "default");
    try testing.expectEqualStrings("from_arg", result1);

    const result2 = try getArgOrEnv(testing.allocator, null, "NONEXISTENT_VAR", "default");
    try testing.expectEqualStrings("default", result2);
}
// ANCHOR_END: env_fallback
