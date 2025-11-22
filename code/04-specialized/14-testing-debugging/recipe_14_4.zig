const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_file_logging
const TestLogger = struct {
    file: std.fs.File,
    allocator: std.mem.Allocator,

    fn init(path: []const u8, allocator: std.mem.Allocator) !TestLogger {
        const file = try std.fs.cwd().createFile(path, .{});
        return .{
            .file = file,
            .allocator = allocator,
        };
    }

    fn deinit(self: *TestLogger) void {
        self.file.close();
    }

    fn log(self: *TestLogger, comptime fmt: []const u8, args: anytype) !void {
        const msg = try std.fmt.allocPrint(self.allocator, fmt ++ "\n", args);
        defer self.allocator.free(msg);
        try self.file.writeAll(msg);
    }
};

test "write test logs to file" {
    var logger = try TestLogger.init("test_output.log", testing.allocator);
    defer logger.deinit();
    defer std.fs.cwd().deleteFile("test_output.log") catch {};

    try logger.log("Test started", .{});
    try logger.log("Processing item {d}", .{42});
    try logger.log("Test completed", .{});

    // Verify file was written
    const content = try std.fs.cwd().readFileAlloc(testing.allocator, "test_output.log", 1024);
    defer testing.allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "Test started") != null);
    try testing.expect(std.mem.indexOf(u8, content, "Processing item 42") != null);
}
// ANCHOR_END: basic_file_logging

// ANCHOR: timestamped_logging
const TimestampedLogger = struct {
    file: std.fs.File,
    allocator: std.mem.Allocator,
    start_time: i64,

    fn init(path: []const u8, allocator: std.mem.Allocator) !TimestampedLogger {
        const file = try std.fs.cwd().createFile(path, .{});
        return .{
            .file = file,
            .allocator = allocator,
            .start_time = std.time.milliTimestamp(),
        };
    }

    fn deinit(self: *TimestampedLogger) void {
        self.file.close();
    }

    fn log(self: *TimestampedLogger, level: []const u8, comptime fmt: []const u8, args: anytype) !void {
        const elapsed = std.time.milliTimestamp() - self.start_time;
        const msg = try std.fmt.allocPrint(self.allocator, "[{d}ms] [{s}] " ++ fmt ++ "\n", .{ elapsed, level } ++ args);
        defer self.allocator.free(msg);
        try self.file.writeAll(msg);
    }
};

test "timestamped test logging" {
    var logger = try TimestampedLogger.init("timestamped.log", testing.allocator);
    defer logger.deinit();
    defer std.fs.cwd().deleteFile("timestamped.log") catch {};

    try logger.log("INFO", "Test initialization", .{});
    std.Thread.sleep(10 * std.time.ns_per_ms); // Sleep 10ms
    try logger.log("DEBUG", "Processing data", .{});
    try logger.log("INFO", "Test complete", .{});

    const content = try std.fs.cwd().readFileAlloc(testing.allocator, "timestamped.log", 1024);
    defer testing.allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "[INFO]") != null);
    try testing.expect(std.mem.indexOf(u8, content, "[DEBUG]") != null);
}
// ANCHOR_END: timestamped_logging

// ANCHOR: temp_file_logging
fn runTestWithTempLog(allocator: std.mem.Allocator) ![]const u8 {
    // Create temporary file for test logs
    var tmp_dir = std.testing.tmpDir(.{});
    var dir = tmp_dir.dir;
    defer tmp_dir.cleanup();

    const log_file = try dir.createFile("test.log", .{ .read = true });
    defer log_file.close();

    try log_file.writeAll("Test execution started\n");
    try log_file.writeAll("Running validation checks\n");
    try log_file.writeAll("All checks passed\n");

    // Read back the log
    try log_file.seekTo(0);
    return log_file.readToEndAlloc(allocator, 1024 * 1024);
}

test "use temporary directory for test logs" {
    const log_content = try runTestWithTempLog(testing.allocator);
    defer testing.allocator.free(log_content);

    try testing.expect(std.mem.indexOf(u8, log_content, "Test execution started") != null);
    try testing.expect(std.mem.indexOf(u8, log_content, "All checks passed") != null);
}
// ANCHOR_END: temp_file_logging

// ANCHOR: structured_logging
const StructuredLogger = struct {
    file: std.fs.File,
    allocator: std.mem.Allocator,
    test_name: []const u8,

    fn init(path: []const u8, test_name: []const u8, allocator: std.mem.Allocator) !StructuredLogger {
        const file = try std.fs.cwd().createFile(path, .{});
        var self = StructuredLogger{
            .file = file,
            .allocator = allocator,
            .test_name = test_name,
        };
        try self.logTestStart();
        return self;
    }

    fn deinit(self: *StructuredLogger) void {
        self.logTestEnd() catch {};
        self.file.close();
    }

    fn logTestStart(self: *StructuredLogger) !void {
        const msg = try std.fmt.allocPrint(self.allocator, "{{\"event\":\"test_start\",\"name\":\"{s}\"}}\n", .{self.test_name});
        defer self.allocator.free(msg);
        try self.file.writeAll(msg);
    }

    fn logTestEnd(self: *StructuredLogger) !void {
        const msg = try std.fmt.allocPrint(self.allocator, "{{\"event\":\"test_end\",\"name\":\"{s}\"}}\n", .{self.test_name});
        defer self.allocator.free(msg);
        try self.file.writeAll(msg);
    }

    fn logAssertion(self: *StructuredLogger, assertion: []const u8, passed: bool) !void {
        const msg = try std.fmt.allocPrint(self.allocator, "{{\"event\":\"assertion\",\"name\":\"{s}\",\"passed\":{}}}\n", .{ assertion, passed });
        defer self.allocator.free(msg);
        try self.file.writeAll(msg);
    }
};

test "structured JSON logging" {
    var logger = try StructuredLogger.init("structured.log", "validation_test", testing.allocator);
    defer std.fs.cwd().deleteFile("structured.log") catch {};

    try logger.logAssertion("value_is_positive", true);
    try logger.logAssertion("value_within_range", true);
    try logger.logAssertion("value_not_zero", false);

    logger.deinit(); // Close file before reading

    const content = try std.fs.cwd().readFileAlloc(testing.allocator, "structured.log", 1024);
    defer testing.allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "test_start") != null);
    try testing.expect(std.mem.indexOf(u8, content, "assertion") != null);
    try testing.expect(std.mem.indexOf(u8, content, "test_end") != null);
}
// ANCHOR_END: structured_logging

// ANCHOR: multi_test_logging
const TestSuite = struct {
    log_file: std.fs.File,
    allocator: std.mem.Allocator,
    tests_run: usize = 0,
    tests_passed: usize = 0,

    fn init(path: []const u8, allocator: std.mem.Allocator) !TestSuite {
        const file = try std.fs.cwd().createFile(path, .{});
        return .{
            .log_file = file,
            .allocator = allocator,
        };
    }

    fn deinit(self: *TestSuite) void {
        self.writeSummary() catch {};
        self.log_file.close();
    }

    fn runTest(self: *TestSuite, name: []const u8, passed: bool) !void {
        self.tests_run += 1;
        if (passed) self.tests_passed += 1;

        const status = if (passed) "PASS" else "FAIL";
        const msg = try std.fmt.allocPrint(self.allocator, "[{s}] {s}\n", .{ status, name });
        defer self.allocator.free(msg);
        try self.log_file.writeAll(msg);
    }

    fn writeSummary(self: *TestSuite) !void {
        const msg = try std.fmt.allocPrint(self.allocator, "\nSummary: {d}/{d} tests passed\n", .{ self.tests_passed, self.tests_run });
        defer self.allocator.free(msg);
        try self.log_file.writeAll(msg);
    }
};

test "log multiple test results" {
    var suite = try TestSuite.init("suite.log", testing.allocator);
    defer std.fs.cwd().deleteFile("suite.log") catch {};

    try suite.runTest("test_addition", true);
    try suite.runTest("test_subtraction", true);
    try suite.runTest("test_division", false);
    try suite.runTest("test_multiplication", true);

    suite.deinit(); // Close file before reading

    const content = try std.fs.cwd().readFileAlloc(testing.allocator, "suite.log", 1024);
    defer testing.allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "[PASS] test_addition") != null);
    try testing.expect(std.mem.indexOf(u8, content, "[FAIL] test_division") != null);
    try testing.expect(std.mem.indexOf(u8, content, "Summary: 3/4 tests passed") != null);
}
// ANCHOR_END: multi_test_logging

// ANCHOR: error_logging
const ErrorLogger = struct {
    file: std.fs.File,
    allocator: std.mem.Allocator,

    fn init(path: []const u8, allocator: std.mem.Allocator) !ErrorLogger {
        const file = try std.fs.cwd().createFile(path, .{});
        return .{
            .file = file,
            .allocator = allocator,
        };
    }

    fn deinit(self: *ErrorLogger) void {
        self.file.close();
    }

    fn logError(self: *ErrorLogger, err: anyerror, context: []const u8) !void {
        const msg = try std.fmt.allocPrint(self.allocator, "ERROR: {s} - {s}\n", .{ @errorName(err), context });
        defer self.allocator.free(msg);
        try self.file.writeAll(msg);
    }

    fn logSuccess(self: *ErrorLogger, operation: []const u8) !void {
        const msg = try std.fmt.allocPrint(self.allocator, "SUCCESS: {s}\n", .{operation});
        defer self.allocator.free(msg);
        try self.file.writeAll(msg);
    }
};

fn riskyOperation(value: i32) !i32 {
    if (value < 0) return error.InvalidValue;
    if (value > 100) return error.OutOfRange;
    return value * 2;
}

test "log errors during testing" {
    var logger = try ErrorLogger.init("errors.log", testing.allocator);
    defer logger.deinit();
    defer std.fs.cwd().deleteFile("errors.log") catch {};

    // Test error cases
    if (riskyOperation(-5)) |_| {
        try logger.logSuccess("negative value handling");
    } else |err| {
        try logger.logError(err, "processing negative value");
    }

    if (riskyOperation(200)) |_| {
        try logger.logSuccess("large value handling");
    } else |err| {
        try logger.logError(err, "processing large value");
    }

    // Test success case
    if (riskyOperation(50)) |_| {
        try logger.logSuccess("valid value processing");
    } else |err| {
        try logger.logError(err, "processing valid value");
    }

    const content = try std.fs.cwd().readFileAlloc(testing.allocator, "errors.log", 1024);
    defer testing.allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "ERROR: InvalidValue") != null);
    try testing.expect(std.mem.indexOf(u8, content, "ERROR: OutOfRange") != null);
    try testing.expect(std.mem.indexOf(u8, content, "SUCCESS: valid value processing") != null);
}
// ANCHOR_END: error_logging

// ANCHOR: buffered_logging
const BufferedTestLogger = struct {
    buffer: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) BufferedTestLogger {
        return .{
            .buffer = std.ArrayList(u8){},
            .allocator = allocator,
        };
    }

    fn deinit(self: *BufferedTestLogger) void {
        self.buffer.deinit(self.allocator);
    }

    fn log(self: *BufferedTestLogger, comptime fmt: []const u8, args: anytype) !void {
        const writer = self.buffer.writer(self.allocator);
        try writer.print(fmt, args);
        try writer.writeAll("\n");
    }

    fn writeToFile(self: *BufferedTestLogger, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        try file.writeAll(self.buffer.items);
    }
};

test "buffered logging with file write" {
    var logger = BufferedTestLogger.init(testing.allocator);
    defer logger.deinit();

    try logger.log("Starting test suite", .{});
    try logger.log("Test 1: {s}", .{"PASSED"});
    try logger.log("Test 2: {s}", .{"PASSED"});
    try logger.log("Test 3: {s}", .{"FAILED"});

    // Write buffer to file
    try logger.writeToFile("buffered.log");
    defer std.fs.cwd().deleteFile("buffered.log") catch {};

    const content = try std.fs.cwd().readFileAlloc(testing.allocator, "buffered.log", 1024);
    defer testing.allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "Starting test suite") != null);
    try testing.expect(std.mem.indexOf(u8, content, "Test 3: FAILED") != null);
}
// ANCHOR_END: buffered_logging

// ANCHOR: performance_logging
const PerfLogger = struct {
    file: std.fs.File,
    allocator: std.mem.Allocator,

    fn init(path: []const u8, allocator: std.mem.Allocator) !PerfLogger {
        const file = try std.fs.cwd().createFile(path, .{});
        return .{
            .file = file,
            .allocator = allocator,
        };
    }

    fn deinit(self: *PerfLogger) void {
        self.file.close();
    }

    fn logTiming(self: *PerfLogger, operation: []const u8, duration_ns: u64) !void {
        const duration_ms = @as(f64, @floatFromInt(duration_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms));
        const msg = try std.fmt.allocPrint(self.allocator, "{s}: {d:.3}ms\n", .{ operation, duration_ms });
        defer self.allocator.free(msg);
        try self.file.writeAll(msg);
    }
};

fn benchmarkOperation() void {
    var sum: u64 = 0;
    var i: u64 = 0;
    while (i < 1000000) : (i += 1) {
        sum +%= i;
    }
    std.mem.doNotOptimizeAway(sum);
}

test "log performance metrics" {
    var logger = try PerfLogger.init("perf.log", testing.allocator);
    defer logger.deinit();
    defer std.fs.cwd().deleteFile("perf.log") catch {};

    const start = std.time.nanoTimestamp();
    benchmarkOperation();
    const end = std.time.nanoTimestamp();

    try logger.logTiming("benchmark_operation", @intCast(end - start));

    const content = try std.fs.cwd().readFileAlloc(testing.allocator, "perf.log", 1024);
    defer testing.allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "benchmark_operation") != null);
    try testing.expect(std.mem.indexOf(u8, content, "ms") != null);
}
// ANCHOR_END: performance_logging
