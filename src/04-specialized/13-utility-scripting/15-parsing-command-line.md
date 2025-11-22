# Recipe 13.15: Parsing Command-Line Options

## Problem

You need to parse command-line arguments with support for flags, options with values, and positional arguments.

## Solution

Start with a simple argument parser for basic needs:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_15.zig:simple_args}}
```

## Discussion

Command-line parsing is essential for making scripts and tools user-friendly. Zig provides low-level access to arguments through `std.process.argsAlloc()`.

### Option Parser

Build a more sophisticated parser for flags and options:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_15.zig:option_parser}}
```

The OptionParser supports:
- Short flags: `-v`, `-h`
- Long flags: `--verbose`, `--help`
- Options with values: `-o file.txt`, `--output=file.txt`
- Positional arguments (non-option args)

### Structured Command-Line Interface

Create a declarative CLI with help text:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_15.zig:command_line}}
```

The CommandLine struct provides:
- Automatic help generation
- Required vs optional arguments
- Type-safe option access
- Clear error messages

### Subcommands

Support git-style subcommands:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_15.zig:subcommands}}
```

Subcommands enable complex tools with multiple operations (like `git commit`, `git push`, etc.).

### Argument Validation

Validate arguments with helpful error messages:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_15.zig:arg_validator}}
```

Validation catches errors early with clear feedback to users.

### Environment Variable Fallback

Use environment variables as defaults:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_15.zig:env_fallback}}
```

This pattern lets users configure tools via environment variables, useful for CI/CD and containerized environments.

### Best Practices

1. **Provide help** - Always support `-h` and `--help`
2. **Use long names** - `--verbose` is clearer than `-v`
3. **Support both formats** - Short and long options for convenience
4. **Validate early** - Check arguments before starting work
5. **Clear errors** - Tell users exactly what's wrong
6. **Default values** - Make tools usable without configuration
7. **Document examples** - Show common usage in help text

### Common Patterns

**Boolean flags:**
```zig
const verbose = parser.hasFlag('v', "--verbose");
const debug = parser.hasFlag('d', "--debug");

if (verbose) {
    std.debug.print("Verbose mode enabled\n", .{});
}
```

**Required options:**
```zig
const output = parser.getOption('o', "--output") orelse {
    std.debug.print("Error: --output is required\n", .{});
    return error.MissingOutput;
};
```

**Optional with default:**
```zig
const host = parser.getOption('h', "--host") orelse "localhost";
const port_str = parser.getOption('p', "--port") orelse "8080";
const port = try std.fmt.parseInt(u16, port_str, 10);
```

**Multiple positionals:**
```zig
const files = try parser.positionals();
defer allocator.free(files);

if (files.len == 0) {
    std.debug.print("Error: no input files specified\n", .{});
    return error.NoInput;
}

for (files) |file| {
    try processFile(file);
}
```

### Help Text Examples

**Simple help:**
```zig
fn printHelp(program_name: []const u8) !void {
    const stderr = std.fs.File{ .handle = 2 };
    try stderr.writeAll("Usage: ");
    try stderr.writeAll(program_name);
    try stderr.writeAll(" [OPTIONS] FILES...\n\n");
    try stderr.writeAll("Options:\n");
    try stderr.writeAll("  -h, --help       Show this help message\n");
    try stderr.writeAll("  -v, --verbose    Verbose output\n");
    try stderr.writeAll("  -o, --output=FILE  Output file\n");
}
```

**Detailed help:**
```zig
fn printDetailedHelp() !void {
    const stderr = std.fs.File{ .handle = 2 };
    try stderr.writeAll(
        \\Usage: mycommand [OPTIONS] <input> <output>
        \\
        \\Process files with various options.
        \\
        \\Arguments:
        \\  <input>          Input file path
        \\  <output>         Output file path
        \\
        \\Options:
        \\  -h, --help            Show this help
        \\  -v, --verbose         Enable verbose logging
        \\  -q, --quiet           Suppress output
        \\  -f, --format=FORMAT   Output format (json|text)
        \\  -c, --config=FILE     Config file path
        \\
        \\Examples:
        \\  mycommand input.txt output.txt
        \\  mycommand --format=json input.txt output.txt
        \\  mycommand -v --config=my.conf input.txt output.txt
        \\
    );
}
```

### Complete Example

Full CLI application:

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try SimpleArgs.parse(allocator);
    defer args.deinit();

    // Define CLI
    const options = [_]CommandLine.Option{
        .{
            .short = 'o',
            .long = "--output",
            .description = "Output file",
            .value_name = "FILE",
            .required = true,
        },
        .{
            .short = 'v',
            .long = "--verbose",
            .description = "Verbose output",
            .value_name = null,
            .required = false,
        },
        .{
            .short = 'f',
            .long = "--format",
            .description = "Output format",
            .value_name = "FORMAT",
            .required = false,
        },
    };

    const cli = CommandLine.init(
        allocator,
        args.programName(),
        "Process files and generate output",
        &options,
    );

    // Parse arguments
    var parsed = cli.parse(args.args) catch |err| {
        if (err == error.HelpRequested) {
            return;  // Help already printed
        }
        return err;
    };
    defer parsed.deinit();

    // Get values
    const output = parsed.get("--output").?;
    const verbose = parsed.get("--verbose") != null;
    const format = parsed.getOrDefault("--format", "text");

    // Validate format
    const valid_formats = [_][]const u8{ "text", "json", "xml" };
    try ArgValidator.validateChoice(format, &valid_formats);

    // Process files
    if (parsed.positionals.len == 0) {
        std.debug.print("Error: no input files specified\n", .{});
        return error.NoInput;
    }

    if (verbose) {
        std.debug.print("Processing {d} files...\n", .{parsed.positionals.len});
        std.debug.print("Output: {s}\n", .{output});
        std.debug.print("Format: {s}\n", .{format});
    }

    for (parsed.positionals) |input| {
        try processFile(input, output, format);
    }
}
```

### Subcommand Example

Git-style CLI:

```zig
fn buildCommand(args: [][]const u8) !void {
    std.debug.print("Building project...\n", .{});
    for (args) |arg| {
        std.debug.print("  arg: {s}\n", .{arg});
    }
}

fn testCommand(args: [][]const u8) !void {
    std.debug.print("Running tests...\n", .{});
    _ = args;
}

fn cleanCommand(args: [][]const u8) !void {
    std.debug.print("Cleaning build artifacts...\n", .{});
    _ = args;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try SimpleArgs.parse(allocator);
    defer args.deinit();

    const commands = [_]SubcommandParser.Command{
        .{
            .name = "build",
            .description = "Build the project",
            .handler = buildCommand,
        },
        .{
            .name = "test",
            .description = "Run tests",
            .handler = testCommand,
        },
        .{
            .name = "clean",
            .description = "Clean build artifacts",
            .handler = cleanCommand,
        },
    };

    const parser = SubcommandParser.init(allocator, args.programName(), &commands);

    try parser.execute(args.args);
}
```

### Option Formats

**Supported formats:**
- Short flag: `-v`
- Long flag: `--verbose`
- Short with value: `-o file.txt`
- Long with =: `--output=file.txt`
- Long with space: `--output file.txt`

**Not supported (use = instead):**
- Combined short options: `-vvv` (use `-v -v -v`)
- No-prefix long options: `verbose` (use `--verbose`)

### Error Handling

**Missing required:**
```zig
Error: required option --output not provided
```

**Invalid choice:**
```zig
Error: invalid choice 'yaml'. Valid choices: text, json, xml
```

**Invalid integer:**
```zig
Error: 'abc' is not a valid integer
```

**Out of range:**
```zig
Error: value 200 out of range [0, 100]
```

### Integration with Config Files

Combine CLI and config:

```zig
// Load defaults from config
var config = try loadConfig(allocator, "config.txt");
defer config.deinit();

// Parse CLI args
var parsed = try cli.parse(args.args);
defer parsed.deinit();

// CLI overrides config
const output = parsed.get("--output") orelse
               config.get("output") orelse
               "default.txt";

const verbose = parsed.get("--verbose") != null or
                std.mem.eql(u8, config.get("verbose") orelse "false", "true");
```

### Testing CLI

Test argument parsing:

```zig
test "cli parsing" {
    const args = [_][]const u8{ "program", "--output=test.txt", "-v", "input.txt" };

    var parser = OptionParser.init(testing.allocator, @constCast(&args));

    try testing.expect(parser.hasFlag('v', "--verbose"));

    const output = parser.getOption('o', "--output");
    try testing.expectEqualStrings("test.txt", output.?);

    const pos = try parser.positionals();
    defer testing.allocator.free(pos);
    try testing.expectEqual(1, pos.len);
    try testing.expectEqualStrings("input.txt", pos[0]);
}
```

### Performance Notes

- Argument parsing is fast (microseconds for typical CLIs)
- Use hashmaps for many options (O(1) lookup)
- Don't parse in hot loops
- Validate once at startup

### Security Considerations

**Command injection:**
- Never pass user args directly to shell
- Use `std.process.Child` with arg array
- Validate file paths

**Path traversal:**
- Validate paths don't escape intended directory
- Use absolute paths or validate carefully
- Check for `..` in paths

**Resource limits:**
- Limit number of positional args
- Validate numeric ranges
- Set reasonable defaults

## See Also

- Recipe 13.2: Terminating a program with an error message
- Recipe 13.9: Reading configuration files
- Recipe 13.10: Adding logging to simple scripts

Full compilable example: `code/04-specialized/13-utility-scripting/recipe_13_15.zig`
