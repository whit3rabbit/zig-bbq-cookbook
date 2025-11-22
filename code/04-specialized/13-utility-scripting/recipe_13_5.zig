const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_exec
/// Execute a command and capture its output
fn executeCommand(allocator: std.mem.Allocator, argv: []const []const u8) ![]const u8 {
    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    const stdout = try child.stdout.?.readToEndAlloc(allocator, 1024 * 1024);
    errdefer allocator.free(stdout);

    _ = try child.wait();

    return stdout;
}

test "execute command concept" {
    // We test the structure without actually running a command
    const argv = [_][]const u8{ "echo", "hello" };
    _ = argv;
    // In actual use: const output = try executeCommand(allocator, &argv);
}
// ANCHOR_END: basic_exec

// ANCHOR: exec_with_status
/// Execute command and return output with exit status
pub const CommandResult = struct {
    stdout: []const u8,
    stderr: []const u8,
    exit_code: u8,

    pub fn deinit(self: *CommandResult, allocator: std.mem.Allocator) void {
        allocator.free(self.stdout);
        allocator.free(self.stderr);
    }
};

fn executeWithStatus(allocator: std.mem.Allocator, argv: []const []const u8) !CommandResult {
    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    const stdout = try child.stdout.?.readToEndAlloc(allocator, 1024 * 1024);
    errdefer allocator.free(stdout);

    const stderr = try child.stderr.?.readToEndAlloc(allocator, 1024 * 1024);
    errdefer allocator.free(stderr);

    const term = try child.wait();

    const exit_code: u8 = switch (term) {
        .Exited => |code| code,
        .Signal => |sig| 128 + @as(u8, @intCast(sig)),
        .Stopped => |sig| 128 + @as(u8, @intCast(sig)),
        .Unknown => |code| @intCast(code),
    };

    return CommandResult{
        .stdout = stdout,
        .stderr = stderr,
        .exit_code = exit_code,
    };
}

test "command result structure" {
    var result = CommandResult{
        .stdout = try testing.allocator.dupe(u8, "output"),
        .stderr = try testing.allocator.dupe(u8, "error"),
        .exit_code = 0,
    };
    defer result.deinit(testing.allocator);

    try testing.expectEqualStrings("output", result.stdout);
    try testing.expectEqual(0, result.exit_code);
}
// ANCHOR_END: exec_with_status

// ANCHOR: exec_with_input
/// Execute command with stdin input
fn executeWithInput(
    allocator: std.mem.Allocator,
    argv: []const []const u8,
    input: []const u8,
) ![]const u8 {
    var child = std.process.Child.init(argv, allocator);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    // Write to stdin
    try child.stdin.?.writeAll(input);
    child.stdin.?.close();
    child.stdin = null;

    const stdout = try child.stdout.?.readToEndAlloc(allocator, 1024 * 1024);
    errdefer allocator.free(stdout);

    _ = try child.wait();

    return stdout;
}

test "execute with input concept" {
    // Just verify the structure compiles
    const argv = [_][]const u8{ "cat" };
    _ = argv;
    // In actual use: const output = try executeWithInput(allocator, &argv, "input data");
}
// ANCHOR_END: exec_with_input

// ANCHOR: exec_with_timeout
/// Timeout monitoring helper
const TimeoutMonitor = struct {
    child_id: std.process.Child.Id,
    timeout_ms: u64,
    timed_out: *std.atomic.Value(bool),

    fn monitor(self: *TimeoutMonitor) void {
        std.Thread.sleep(self.timeout_ms * std.time.ns_per_ms);
        self.timed_out.store(true, .release);

        // Send termination signal on POSIX systems
        // NOTE: Windows limitation - cannot safely terminate the child process here
        // due to Zig stdlib design flaw (github.com/ziglang/zig/issues/16820).
        // Using Child.kill() or TerminateProcess would race with the main thread's
        // readToEndAlloc(), potentially closing pipes while they're being read.
        // On Windows, the timeout flag is set but the process continues until
        // natural termination.
        if (@import("builtin").os.tag != .windows) {
            std.posix.kill(self.child_id, std.posix.SIG.TERM) catch {};
        }
    }
};

/// Execute command with timeout
///
/// PLATFORM LIMITATIONS:
/// - POSIX (Linux/macOS): Works for processes that respond to SIGTERM
/// - Windows: Timeout flag is set, but process cannot be forcibly terminated
///   due to Zig stdlib limitations. The function will wait for the process
///   to exit naturally before returning error.Timeout.
///
/// KNOWN ISSUES (Zig 0.15.2):
/// This implementation works around a fundamental design flaw in std.process.Child
/// (see github.com/ziglang/zig/issues/16820). Concurrent killing and stream reading
/// causes race conditions because Child.kill() closes streams while another thread
/// may be reading from them.
///
/// RECOMMENDED WORKAROUNDS:
/// 1. Use system timeout command: ["timeout", "5s", "your-command"] (cross-platform)
/// 2. Use non-blocking I/O with manual polling (complex, not shown here)
/// 3. Accept the limitation for well-behaved commands
fn executeWithTimeout(
    allocator: std.mem.Allocator,
    argv: []const []const u8,
    timeout_ms: u64,
) !CommandResult {
    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    var timed_out = std.atomic.Value(bool).init(false);
    var monitor = TimeoutMonitor{
        .child_id = child.id,
        .timeout_ms = timeout_ms,
        .timed_out = &timed_out,
    };

    // Start timeout monitor thread
    const monitor_thread = try std.Thread.spawn(.{}, TimeoutMonitor.monitor, .{&monitor});
    defer monitor_thread.join();

    // Read process output (blocks until process ends or is killed)
    const stdout = child.stdout.?.readToEndAlloc(allocator, 1024 * 1024) catch |err| {
        _ = child.kill() catch {};
        return err;
    };
    errdefer allocator.free(stdout);

    const stderr = child.stderr.?.readToEndAlloc(allocator, 1024 * 1024) catch |err| {
        allocator.free(stdout);
        _ = child.kill() catch {};
        return err;
    };
    errdefer allocator.free(stderr);

    // Wait for process to complete
    const term = child.wait() catch |err| {
        allocator.free(stdout);
        allocator.free(stderr);
        return err;
    };

    // Check if timeout occurred
    if (timed_out.load(.acquire)) {
        allocator.free(stdout);
        allocator.free(stderr);
        return error.Timeout;
    }

    const exit_code: u8 = switch (term) {
        .Exited => |code| code,
        .Signal => |sig| 128 + @as(u8, @intCast(sig)),
        .Stopped => |sig| 128 + @as(u8, @intCast(sig)),
        .Unknown => |code| @intCast(code),
    };

    return CommandResult{
        .stdout = stdout,
        .stderr = stderr,
        .exit_code = exit_code,
    };
}

test "execute with timeout - normal completion" {
    const argv = [_][]const u8{ "echo", "test" };
    var result = try executeWithTimeout(testing.allocator, &argv, 5000);
    defer result.deinit(testing.allocator);

    try testing.expect(std.mem.indexOf(u8, result.stdout, "test") != null);
    try testing.expectEqual(0, result.exit_code);
}

test "execute with timeout - signal handling" {
    if (@import("builtin").os.tag == .windows) return error.SkipZigTest;

    // Test with a command that can be terminated (sleep responds to SIGTERM)
    const argv = [_][]const u8{ "sleep", "10" };
    const result = executeWithTimeout(testing.allocator, &argv, 100);

    // Should timeout and kill the process
    try testing.expectError(error.Timeout, result);
}

test "timeout monitor structure" {
    var timed_out = std.atomic.Value(bool).init(false);
    const monitor = TimeoutMonitor{
        .child_id = 0,
        .timeout_ms = 50,
        .timed_out = &timed_out,
    };

    try testing.expectEqual(false, timed_out.load(.acquire));

    // Simulate timeout
    timed_out.store(true, .release);
    try testing.expectEqual(true, timed_out.load(.acquire));

    _ = monitor; // Keep monitor alive
}
// ANCHOR_END: exec_with_timeout

// ANCHOR: exec_with_env
/// Execute command with custom environment
fn executeWithEnv(
    allocator: std.mem.Allocator,
    argv: []const []const u8,
    env_map: *const std.process.EnvMap,
) ![]const u8 {
    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.env_map = env_map;

    try child.spawn();

    const stdout = try child.stdout.?.readToEndAlloc(allocator, 1024 * 1024);
    errdefer allocator.free(stdout);

    _ = try child.wait();

    return stdout;
}

test "execute with environment" {
    var env_map = try std.process.getEnvMap(testing.allocator);
    defer env_map.deinit();

    try env_map.put("MY_VAR", "test_value");

    // Test structure
    const argv = [_][]const u8{ "env" };
    _ = argv;
    // In actual use: const output = try executeWithEnv(allocator, &argv, &env_map);
}
// ANCHOR_END: exec_with_env

// ANCHOR: exec_in_directory
/// Execute command in specific directory
fn executeInDirectory(
    allocator: std.mem.Allocator,
    argv: []const []const u8,
    cwd: []const u8,
) ![]const u8 {
    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.cwd = cwd;

    try child.spawn();

    const stdout = try child.stdout.?.readToEndAlloc(allocator, 1024 * 1024);
    errdefer allocator.free(stdout);

    _ = try child.wait();

    return stdout;
}

test "execute in directory concept" {
    const argv = [_][]const u8{ "pwd" };
    _ = argv;
    // In actual use: const output = try executeInDirectory(allocator, &argv, "/tmp");
}
// ANCHOR_END: exec_in_directory

// ANCHOR: exec_pipeline
/// Execute a pipeline of commands (cmd1 | cmd2)
fn executePipeline(
    allocator: std.mem.Allocator,
    cmd1_argv: []const []const u8,
    cmd2_argv: []const []const u8,
) ![]const u8 {
    // Start first command
    var child1 = std.process.Child.init(cmd1_argv, allocator);
    child1.stdout_behavior = .Pipe;
    child1.stderr_behavior = .Pipe;
    try child1.spawn();

    // Read output from first command
    const cmd1_output = try child1.stdout.?.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(cmd1_output);

    _ = try child1.wait();

    // Start second command with first command's output as input
    var child2 = std.process.Child.init(cmd2_argv, allocator);
    child2.stdin_behavior = .Pipe;
    child2.stdout_behavior = .Pipe;
    child2.stderr_behavior = .Pipe;
    try child2.spawn();

    // Write first command's output to second command's stdin
    try child2.stdin.?.writeAll(cmd1_output);
    child2.stdin.?.close();
    child2.stdin = null;

    const output = try child2.stdout.?.readToEndAlloc(allocator, 1024 * 1024);
    errdefer allocator.free(output);

    _ = try child2.wait();

    return output;
}

test "pipeline concept" {
    const cmd1 = [_][]const u8{ "echo", "hello" };
    const cmd2 = [_][]const u8{ "cat" };
    _ = cmd1;
    _ = cmd2;
    // In actual use: const output = try executePipeline(allocator, &cmd1, &cmd2);
}
// ANCHOR_END: exec_pipeline

// ANCHOR: exec_streaming
/// Execute command with streaming output callback
fn executeStreaming(
    allocator: std.mem.Allocator,
    argv: []const []const u8,
    callback: *const fn (line: []const u8) void,
) !void {
    var child = std.process.Child.init(argv, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    // Read line by line
    const reader = child.stdout.?.reader();
    var buf: [4096]u8 = undefined;

    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        callback(line);
    }

    _ = try child.wait();
}

fn printLine(line: []const u8) void {
    std.debug.print("{s}\n", .{line});
}

test "streaming execution concept" {
    const argv = [_][]const u8{ "echo", "line1\nline2" };
    _ = argv;
    // In actual use: try executeStreaming(allocator, &argv, &printLine);
    _ = printLine;
}
// ANCHOR_END: exec_streaming

// ANCHOR: exec_shell
/// Execute a shell command string
fn executeShell(allocator: std.mem.Allocator, command: []const u8) ![]const u8 {
    const argv = [_][]const u8{ "sh", "-c", command };
    return executeCommand(allocator, &argv);
}

test "shell execution concept" {
    // Just verify structure
    const command = "echo hello | tr a-z A-Z";
    _ = command;
    // In actual use: const output = try executeShell(allocator, command);
}
// ANCHOR_END: exec_shell

// ANCHOR: exec_safe
/// Safely execute command with validation
pub const CommandBuilder = struct {
    allocator: std.mem.Allocator,
    argv: std.ArrayList([]const u8),
    env_map: ?*std.process.EnvMap = null,
    cwd: ?[]const u8 = null,
    timeout_ms: ?u64 = null,

    pub fn init(allocator: std.mem.Allocator, program: []const u8) !CommandBuilder {
        var argv = std.ArrayList([]const u8){};
        try argv.append(allocator, program);

        return .{
            .allocator = allocator,
            .argv = argv,
        };
    }

    pub fn deinit(self: *CommandBuilder) void {
        self.argv.deinit(self.allocator);
    }

    pub fn arg(self: *CommandBuilder, argument: []const u8) !*CommandBuilder {
        try self.argv.append(self.allocator, argument);
        return self;
    }

    pub fn args(self: *CommandBuilder, arguments: []const []const u8) !*CommandBuilder {
        for (arguments) |argument| {
            try self.argv.append(self.allocator, argument);
        }
        return self;
    }

    pub fn env(self: *CommandBuilder, env_map: *std.process.EnvMap) *CommandBuilder {
        self.env_map = env_map;
        return self;
    }

    pub fn workDir(self: *CommandBuilder, cwd: []const u8) *CommandBuilder {
        self.cwd = cwd;
        return self;
    }

    pub fn timeout(self: *CommandBuilder, ms: u64) *CommandBuilder {
        self.timeout_ms = ms;
        return self;
    }

    pub fn execute(self: *CommandBuilder) !CommandResult {
        var child = std.process.Child.init(self.argv.items, self.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        if (self.env_map) |em| {
            child.env_map = em;
        }

        if (self.cwd) |dir| {
            child.cwd = dir;
        }

        try child.spawn();

        const stdout = try child.stdout.?.readToEndAlloc(self.allocator, 1024 * 1024);
        errdefer self.allocator.free(stdout);

        const stderr = try child.stderr.?.readToEndAlloc(self.allocator, 1024 * 1024);
        errdefer self.allocator.free(stderr);

        const term = try child.wait();

        const exit_code: u8 = switch (term) {
            .Exited => |code| code,
            .Signal => |sig| 128 + @as(u8, @intCast(sig)),
            .Stopped => |sig| 128 + @as(u8, @intCast(sig)),
            .Unknown => |code| @intCast(code),
        };

        return CommandResult{
            .stdout = stdout,
            .stderr = stderr,
            .exit_code = exit_code,
        };
    }
};

test "command builder" {
    var builder = try CommandBuilder.init(testing.allocator, "echo");
    defer builder.deinit();

    _ = try builder.arg("hello");
    _ = try builder.arg("world");

    try testing.expectEqual(3, builder.argv.items.len);
    try testing.expectEqualStrings("echo", builder.argv.items[0]);
    try testing.expectEqualStrings("hello", builder.argv.items[1]);
}
// ANCHOR_END: exec_safe
