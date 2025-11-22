const std = @import("std");
const testing = std.testing;

// ANCHOR: log_level
/// Log levels for simple scripts
pub const LogLevel = enum {
    debug,
    info,
    warn,
    err,

    pub fn asString(self: LogLevel) []const u8 {
        return switch (self) {
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
        };
    }

    pub fn fromString(s: []const u8) ?LogLevel {
        if (std.mem.eql(u8, s, "debug")) return .debug;
        if (std.mem.eql(u8, s, "info")) return .info;
        if (std.mem.eql(u8, s, "warn")) return .warn;
        if (std.mem.eql(u8, s, "error")) return .err;
        return null;
    }
};

test "log level string conversion" {
    try testing.expectEqualStrings("INFO", LogLevel.info.asString());
    try testing.expectEqualStrings("ERROR", LogLevel.err.asString());

    try testing.expectEqual(LogLevel.debug, LogLevel.fromString("debug").?);
    try testing.expectEqual(LogLevel.info, LogLevel.fromString("info").?);
    try testing.expect(LogLevel.fromString("invalid") == null);
}
// ANCHOR_END: log_level

// ANCHOR: simple_logger
/// Simple logger for scripts
pub const SimpleLogger = struct {
    min_level: LogLevel,
    file: ?std.fs.File,
    use_timestamps: bool,
    use_colors: bool,

    pub fn init(min_level: LogLevel) SimpleLogger {
        return .{
            .min_level = min_level,
            .file = null,
            .use_timestamps = true,
            .use_colors = false,
        };
    }

    pub fn initWithFile(min_level: LogLevel, file: std.fs.File) SimpleLogger {
        return .{
            .min_level = min_level,
            .file = file,
            .use_timestamps = true,
            .use_colors = false,
        };
    }

    pub fn log(self: *const SimpleLogger, level: LogLevel, comptime fmt: []const u8, args: anytype) void {
        if (@intFromEnum(level) < @intFromEnum(self.min_level)) return;

        const file = if (self.file) |f| f else std.fs.File{ .handle = 2 };

        // Buffer entire log line to prevent interleaving with other threads
        var buf: [2048]u8 = undefined;
        var stream = std.io.fixedBufferStream(&buf);
        const writer = stream.writer();

        if (self.use_timestamps) {
            const timestamp = std.time.timestamp();
            const seconds = @mod(timestamp, 60);
            const minutes = @mod(@divFloor(timestamp, 60), 60);
            const hours = @mod(@divFloor(timestamp, 3600), 24);

            writer.print("[{d:0>2}:{d:0>2}:{d:0>2}] ", .{ hours, minutes, seconds }) catch return;
        }

        writer.print("[{s}] ", .{level.asString()}) catch return;
        writer.print(fmt, args) catch return;
        writer.writeByte('\n') catch return;

        // Single write operation for atomicity
        file.writeAll(stream.getWritten()) catch return;
    }

    pub fn debug(self: *const SimpleLogger, comptime fmt: []const u8, args: anytype) void {
        self.log(.debug, fmt, args);
    }

    pub fn info(self: *const SimpleLogger, comptime fmt: []const u8, args: anytype) void {
        self.log(.info, fmt, args);
    }

    pub fn warn(self: *const SimpleLogger, comptime fmt: []const u8, args: anytype) void {
        self.log(.warn, fmt, args);
    }

    pub fn err(self: *const SimpleLogger, comptime fmt: []const u8, args: anytype) void {
        self.log(.err, fmt, args);
    }
};

test "simple logger basic usage" {
    var logger = SimpleLogger.init(.info);
    logger.use_timestamps = false;

    logger.info("Test message: {d}", .{42});
    logger.debug("This should not appear", .{});
    logger.warn("Warning: {s}", .{"test"});
    logger.err("Error occurred", .{});
}

test "simple logger with file" {
    const test_file = "zig-cache/test_log.txt";
    std.fs.cwd().deleteFile(test_file) catch {};
    defer std.fs.cwd().deleteFile(test_file) catch {};

    const file = try std.fs.cwd().createFile(test_file, .{});
    defer file.close();

    var logger = SimpleLogger.initWithFile(.debug, file);
    logger.use_timestamps = false;

    logger.info("Test log entry", .{});
    logger.debug("Debug entry", .{});

    const content = try std.fs.cwd().readFileAlloc(testing.allocator, test_file, 1024);
    defer testing.allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "[INFO] Test log entry") != null);
    try testing.expect(std.mem.indexOf(u8, content, "[DEBUG] Debug entry") != null);
}
// ANCHOR_END: simple_logger

// ANCHOR: structured_logger
/// Structured logger with key-value pairs
pub const StructuredLogger = struct {
    base: SimpleLogger,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, min_level: LogLevel) StructuredLogger {
        return .{
            .base = SimpleLogger.init(min_level),
            .allocator = allocator,
        };
    }

    pub fn logWithFields(
        self: *const StructuredLogger,
        level: LogLevel,
        message: []const u8,
        fields: anytype,
    ) !void {
        if (@intFromEnum(level) < @intFromEnum(self.base.min_level)) return;

        const file = if (self.base.file) |f| f else std.fs.File{ .handle = 2 };

        // Buffer entire log line to prevent interleaving
        var buf: [2048]u8 = undefined;
        var stream = std.io.fixedBufferStream(&buf);
        const writer = stream.writer();

        try writer.print("[{s}] {s}", .{ level.asString(), message });

        inline for (@typeInfo(@TypeOf(fields)).@"struct".fields) |field| {
            const value = @field(fields, field.name);

            switch (@TypeOf(value)) {
                []const u8 => try writer.print(" {s}=\"{s}\"", .{ field.name, value }),
                else => try writer.print(" {s}={any}", .{ field.name, value }),
            }
        }

        try writer.writeByte('\n');

        // Single write operation for atomicity
        try file.writeAll(stream.getWritten());
    }
};

test "structured logger" {
    var logger = StructuredLogger.init(testing.allocator, .info);
    logger.base.use_timestamps = false;

    try logger.logWithFields(.info, "User logged in", .{
        .user_id = 123,
        .ip_address = "192.168.1.1",
    });

    try logger.logWithFields(.warn, "High memory usage", .{
        .memory_mb = 512,
        .threshold_mb = 256,
    });
}
// ANCHOR_END: structured_logger

// ANCHOR: file_logger
/// Logger with automatic file rotation
pub const FileLogger = struct {
    allocator: std.mem.Allocator,
    base_path: []const u8,
    current_file: ?std.fs.File,
    max_size: usize,
    current_size: usize,
    min_level: LogLevel,

    pub fn init(allocator: std.mem.Allocator, base_path: []const u8, max_size: usize) !FileLogger {
        const file = try std.fs.cwd().createFile(base_path, .{ .truncate = false });

        return .{
            .allocator = allocator,
            .base_path = try allocator.dupe(u8, base_path),
            .current_file = file,
            .max_size = max_size,
            .current_size = 0,
            .min_level = .info,
        };
    }

    pub fn deinit(self: *FileLogger) void {
        if (self.current_file) |f| f.close();
        self.allocator.free(self.base_path);
    }

    fn rotate(self: *FileLogger) !void {
        if (self.current_file) |f| f.close();

        const timestamp = std.time.timestamp();
        const rotated_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}.{d}",
            .{ self.base_path, timestamp },
        );
        defer self.allocator.free(rotated_path);

        std.fs.cwd().rename(self.base_path, rotated_path) catch |err| {
            // On Windows, file might be locked by another process
            // Continue logging to the same file instead of failing
            std.debug.print("Warning: Failed to rotate log file: {}\n", .{err});

            // Reopen the current file in append mode
            self.current_file = try std.fs.cwd().openFile(self.base_path, .{ .mode = .write_only });
            try self.current_file.?.seekFromEnd(0);
            // Get actual file size to track correctly after failed rotation
            self.current_size = (try self.current_file.?.stat()).size;
            return;
        };

        // Rename succeeded, create new file
        self.current_file = try std.fs.cwd().createFile(self.base_path, .{});
        self.current_size = 0;
    }

    pub fn log(self: *FileLogger, level: LogLevel, comptime fmt: []const u8, args: anytype) !void {
        if (@intFromEnum(level) < @intFromEnum(self.min_level)) return;

        const file = self.current_file orelse return error.NoFileOpen;

        const timestamp = std.time.timestamp();

        // Try stack buffer first to avoid heap allocation
        var stack_buf: [4096]u8 = undefined;
        const msg = std.fmt.bufPrint(
            &stack_buf,
            "[{d}] [{s}] " ++ fmt ++ "\n",
            .{ timestamp, level.asString() } ++ args,
        ) catch blk: {
            // Message too large for stack buffer, fall back to heap
            break :blk try std.fmt.allocPrint(
                self.allocator,
                "[{d}] [{s}] " ++ fmt ++ "\n",
                .{ timestamp, level.asString() } ++ args,
            );
        };

        // Free heap allocation if we used it (check if pointer is outside stack buffer)
        const is_heap = @intFromPtr(msg.ptr) != @intFromPtr(&stack_buf[0]);
        defer if (is_heap) self.allocator.free(msg);

        try file.writeAll(msg);
        self.current_size += msg.len;

        if (self.current_size >= self.max_size) {
            try self.rotate();
        }
    }
};

test "file logger rotation" {
    const test_log = "zig-cache/rotate_test.log";
    std.fs.cwd().deleteFile(test_log) catch {};
    defer std.fs.cwd().deleteFile(test_log) catch {};

    var logger = try FileLogger.init(testing.allocator, test_log, 100);
    defer logger.deinit();

    logger.min_level = .debug;

    try logger.log(.info, "First message", .{});
    try logger.log(.info, "Second message that will trigger rotation", .{});

    const content = try std.fs.cwd().readFileAlloc(testing.allocator, test_log, 1024);
    defer testing.allocator.free(content);

    try testing.expect(content.len < 150);
}

test "file logger large message heap fallback" {
    const test_log = "zig-cache/large_log_test.log";
    std.fs.cwd().deleteFile(test_log) catch {};
    defer std.fs.cwd().deleteFile(test_log) catch {};

    var logger = try FileLogger.init(testing.allocator, test_log, 100000);
    defer logger.deinit();

    // Create a message larger than the 4096 byte stack buffer
    var large_data: [5000]u8 = undefined;
    @memset(&large_data, 'X');

    try logger.log(.info, "Large: {s}", .{large_data});

    const content = try std.fs.cwd().readFileAlloc(testing.allocator, test_log, 10000);
    defer testing.allocator.free(content);

    // Verify the large message was logged correctly
    try testing.expect(content.len > 5000);
    try testing.expect(std.mem.indexOf(u8, content, "[INFO]") != null);
}
// ANCHOR_END: file_logger

// ANCHOR: context_logger
/// Logger that carries context information
pub const ContextLogger = struct {
    base: SimpleLogger,
    context: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, min_level: LogLevel) ContextLogger {
        return .{
            .base = SimpleLogger.init(min_level),
            .context = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ContextLogger) void {
        var iter = self.context.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.context.deinit();
    }

    pub fn setContext(self: *ContextLogger, key: []const u8, value: []const u8) !void {
        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);

        const value_copy = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(value_copy);

        const result = try self.context.fetchPut(key_copy, value_copy);
        if (result) |old| {
            self.allocator.free(old.key);
            self.allocator.free(old.value);
        }
    }

    pub fn log(self: *ContextLogger, level: LogLevel, comptime fmt: []const u8, args: anytype) !void {
        if (@intFromEnum(level) < @intFromEnum(self.base.min_level)) return;

        const file = std.fs.File{ .handle = 2 };

        // Buffer entire log line to prevent interleaving
        var buf: [2048]u8 = undefined;
        var stream = std.io.fixedBufferStream(&buf);
        const writer = stream.writer();

        try writer.print("[{s}] ", .{level.asString()});
        try writer.print(fmt, args);

        var iter = self.context.iterator();
        while (iter.next()) |entry| {
            try writer.print(" {s}={s}", .{ entry.key_ptr.*, entry.value_ptr.* });
        }

        try writer.writeByte('\n');

        // Single write operation for atomicity
        try file.writeAll(stream.getWritten());
    }
};

test "context logger" {
    var logger = ContextLogger.init(testing.allocator, .info);
    defer logger.deinit();

    try logger.setContext("request_id", "abc-123");
    try logger.setContext("user", "alice");

    try logger.log(.info, "Processing request", .{});
}
// ANCHOR_END: context_logger

// ANCHOR: timed_operation
/// Log with execution time measurement
pub fn timedOperation(
    logger: *const SimpleLogger,
    operation_name: []const u8,
    comptime func: anytype,
    args: anytype,
) @TypeOf(@call(.auto, func, args)) {
    const start = std.time.nanoTimestamp();
    defer {
        const end = std.time.nanoTimestamp();
        const duration_ms = @divFloor(end - start, std.time.ns_per_ms);
        logger.info("{s} completed in {d}ms", .{ operation_name, duration_ms });
    }

    return @call(.auto, func, args);
}

fn slowOperation(n: u64) u64 {
    var sum: u64 = 0;
    var i: u64 = 0;
    while (i < n) : (i += 1) {
        sum +%= i;
    }
    return sum;
}

test "timed operation" {
    var logger = SimpleLogger.init(.info);
    logger.use_timestamps = false;

    const result = timedOperation(&logger, "slow_operation", slowOperation, .{1000});
    try testing.expect(result > 0);
}
// ANCHOR_END: timed_operation

// ANCHOR: log_formatter
/// Custom log message formatter
pub const LogFormatter = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) LogFormatter {
        return .{ .allocator = allocator };
    }

    pub fn formatJson(
        self: LogFormatter,
        level: LogLevel,
        message: []const u8,
        fields: anytype,
    ) ![]u8 {
        var buffer = std.ArrayList(u8){};
        errdefer buffer.deinit(self.allocator);

        try buffer.appendSlice(self.allocator, "{\"level\":\"");
        try buffer.appendSlice(self.allocator, level.asString());
        try buffer.appendSlice(self.allocator, "\",\"message\":\"");
        try buffer.appendSlice(self.allocator, message);
        try buffer.append(self.allocator, '"');

        inline for (@typeInfo(@TypeOf(fields)).@"struct".fields) |field| {
            try buffer.appendSlice(self.allocator, ",\"");
            try buffer.appendSlice(self.allocator, field.name);
            try buffer.appendSlice(self.allocator, "\":");

            const value = @field(fields, field.name);
            switch (@TypeOf(value)) {
                []const u8 => {
                    try buffer.append(self.allocator, '"');
                    try buffer.appendSlice(self.allocator, value);
                    try buffer.append(self.allocator, '"');
                },
                else => {
                    var buf: [32]u8 = undefined;
                    const num_str = try std.fmt.bufPrint(&buf, "{any}", .{value});
                    try buffer.appendSlice(self.allocator, num_str);
                },
            }
        }

        try buffer.append(self.allocator, '}');

        return try buffer.toOwnedSlice(self.allocator);
    }
};

test "json formatter" {
    const formatter = LogFormatter.init(testing.allocator);

    const json = try formatter.formatJson(.info, "User action", .{
        .user_id = 42,
        .action = "login",
    });
    defer testing.allocator.free(json);

    try testing.expect(std.mem.indexOf(u8, json, "\"level\":\"INFO\"") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"message\":\"User action\"") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"user_id\":42") != null);
}
// ANCHOR_END: log_formatter

// ANCHOR: rate_limited_logger
/// Logger with rate limiting to prevent log spam
pub const RateLimitedLogger = struct {
    base: SimpleLogger,
    last_log_time: std.StringHashMap(i128),
    min_interval_ns: i128,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, min_level: LogLevel, min_interval_ms: i64) RateLimitedLogger {
        return .{
            .base = SimpleLogger.init(min_level),
            .last_log_time = std.StringHashMap(i128).init(allocator),
            .min_interval_ns = @as(i128, min_interval_ms) * std.time.ns_per_ms,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RateLimitedLogger) void {
        var iter = self.last_log_time.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.last_log_time.deinit();
    }

    pub fn log(self: *RateLimitedLogger, key: []const u8, level: LogLevel, comptime fmt: []const u8, args: anytype) !void {
        const now = std.time.nanoTimestamp();

        if (self.last_log_time.get(key)) |last_time| {
            if (now - last_time < self.min_interval_ns) {
                return;
            }
        }

        self.base.log(level, fmt, args);

        const key_copy = try self.allocator.dupe(u8, key);
        try self.last_log_time.put(key_copy, now);
    }
};

test "rate limited logger" {
    var logger = RateLimitedLogger.init(testing.allocator, .info, 100);
    defer logger.deinit();
    logger.base.use_timestamps = false;

    try logger.log("test_key", .info, "First message", .{});
    try logger.log("test_key", .info, "Should be suppressed", .{});

    try logger.log("other_key", .info, "Different key allowed", .{});
}
// ANCHOR_END: rate_limited_logger
