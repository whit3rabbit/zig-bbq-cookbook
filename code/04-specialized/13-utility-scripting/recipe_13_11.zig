const std = @import("std");
const testing = std.testing;

// ANCHOR: logger_interface
/// Logger interface for libraries
pub const Logger = struct {
    context: *anyopaque,
    logFn: *const fn (context: *anyopaque, level: LogLevel, message: []const u8) void,

    pub const LogLevel = enum {
        debug,
        info,
        warn,
        err,
    };

    pub fn log(self: Logger, level: LogLevel, comptime fmt: []const u8, args: anytype) void {
        var buf: [1024]u8 = undefined;
        const message = std.fmt.bufPrint(&buf, fmt, args) catch return;
        self.logFn(self.context, level, message);
    }

    pub fn debug(self: Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.debug, fmt, args);
    }

    pub fn info(self: Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.info, fmt, args);
    }

    pub fn warn(self: Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.warn, fmt, args);
    }

    pub fn err(self: Logger, comptime fmt: []const u8, args: anytype) void {
        self.log(.err, fmt, args);
    }
};

test "logger interface" {
    var log_count: usize = 0;

    const TestLogger = struct {
        fn logCallback(context: *anyopaque, level: Logger.LogLevel, message: []const u8) void {
            const count: *usize = @ptrCast(@alignCast(context));
            count.* += 1;
            _ = level;
            _ = message;
        }
    };

    const logger = Logger{
        .context = &log_count,
        .logFn = TestLogger.logCallback,
    };

    logger.info("Test message", .{});
    try testing.expectEqual(1, log_count);

    logger.debug("Another message", .{});
    try testing.expectEqual(2, log_count);
}
// ANCHOR_END: logger_interface

// ANCHOR: optional_logger
/// Library with optional logging
pub const DataProcessor = struct {
    allocator: std.mem.Allocator,
    logger: ?Logger,

    pub fn init(allocator: std.mem.Allocator, logger: ?Logger) DataProcessor {
        return .{
            .allocator = allocator,
            .logger = logger,
        };
    }

    pub fn process(self: *DataProcessor, data: []const u8) !void {
        if (self.logger) |log| {
            log.info("Processing {d} bytes", .{data.len});
        }

        // Do actual processing (simulated)
        if (data.len == 0) return error.EmptyData;

        if (self.logger) |log| {
            log.debug("Processing complete", .{});
        }
    }

    pub fn validate(self: *DataProcessor, value: i32) !void {
        if (value < 0) {
            if (self.logger) |log| {
                log.err("Validation failed: negative value {d}", .{value});
            }
            return error.InvalidValue;
        }

        if (self.logger) |log| {
            log.debug("Validated value: {d}", .{value});
        }
    }
};

test "optional logger" {
    var processor = DataProcessor.init(testing.allocator, null);
    try processor.process("test data");
    try processor.validate(42);
}
// ANCHOR_END: optional_logger

// ANCHOR: logger_adapter
/// Adapter for standard library logging
pub const StdLogger = struct {
    level: Logger.LogLevel,

    pub fn init(level: Logger.LogLevel) StdLogger {
        return .{ .level = level };
    }

    pub fn logger(self: *StdLogger) Logger {
        return .{
            .context = self,
            .logFn = logCallback,
        };
    }

    fn logCallback(context: *anyopaque, level: Logger.LogLevel, message: []const u8) void {
        const self: *StdLogger = @ptrCast(@alignCast(context));

        if (@intFromEnum(level) < @intFromEnum(self.level)) return;

        const prefix = switch (level) {
            .debug => "[DEBUG]",
            .info => "[INFO]",
            .warn => "[WARN]",
            .err => "[ERROR]",
        };

        std.debug.print("{s} {s}\n", .{ prefix, message });
    }
};

test "std logger adapter" {
    var std_logger = StdLogger.init(.info);
    var processor = DataProcessor.init(testing.allocator, std_logger.logger());

    try processor.process("test");
}
// ANCHOR_END: logger_adapter

// ANCHOR: file_logger
/// File-based logger adapter
pub const FileLogger = struct {
    file: std.fs.File,
    min_level: Logger.LogLevel,
    use_timestamps: bool,

    pub fn init(file: std.fs.File, min_level: Logger.LogLevel, use_timestamps: bool) FileLogger {
        return .{
            .file = file,
            .min_level = min_level,
            .use_timestamps = use_timestamps,
        };
    }

    pub fn logger(self: *FileLogger) Logger {
        return .{
            .context = self,
            .logFn = logCallback,
        };
    }

    fn logCallback(context: *anyopaque, level: Logger.LogLevel, message: []const u8) void {
        const self: *FileLogger = @ptrCast(@alignCast(context));

        if (@intFromEnum(level) < @intFromEnum(self.min_level)) return;

        const level_str = switch (level) {
            .debug => "DEBUG",
            .info => "INFO",
            .warn => "WARN",
            .err => "ERROR",
        };

        var buf: [2048]u8 = undefined;
        const line = if (self.use_timestamps)
            std.fmt.bufPrint(&buf, "{d} [{s}] {s}\n", .{ std.time.milliTimestamp(), level_str, message }) catch return
        else
            std.fmt.bufPrint(&buf, "[{s}] {s}\n", .{ level_str, message }) catch return;

        self.file.writeAll(line) catch {};
    }
};

test "file logger adapter" {
    const log_path = "zig-cache/test_library.log";
    std.fs.cwd().deleteFile(log_path) catch {};
    defer std.fs.cwd().deleteFile(log_path) catch {};

    const file = try std.fs.cwd().createFile(log_path, .{});
    defer file.close();

    var file_logger = FileLogger.init(file, .debug, false);
    var processor = DataProcessor.init(testing.allocator, file_logger.logger());

    try processor.process("test data");
    try processor.validate(100);

    // Verify log file contains entries
    try file.sync();
    const content = try std.fs.cwd().readFileAlloc(testing.allocator, log_path, 1024);
    defer testing.allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "[INFO]") != null);
    try testing.expect(std.mem.indexOf(u8, content, "Processing") != null);
}
// ANCHOR_END: file_logger

// ANCHOR: contextual_logger
/// Logger with context information
pub const ContextualLogger = struct {
    base: Logger,
    context_name: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, base: Logger, context_name: []const u8) !ContextualLogger {
        return .{
            .base = base,
            .context_name = try allocator.dupe(u8, context_name),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ContextualLogger) void {
        self.allocator.free(self.context_name);
    }

    pub fn logger(self: *ContextualLogger) Logger {
        return .{
            .context = self,
            .logFn = logCallback,
        };
    }

    fn logCallback(context: *anyopaque, level: Logger.LogLevel, message: []const u8) void {
        const self: *ContextualLogger = @ptrCast(@alignCast(context));

        var buf: [2048]u8 = undefined;
        const contextual_message = std.fmt.bufPrint(&buf, "[{s}] {s}", .{ self.context_name, message }) catch return;

        self.base.logFn(self.base.context, level, contextual_message);
    }
};

test "contextual logger" {
    var log_count: usize = 0;
    var last_message: [256]u8 = undefined;
    var message_len: usize = 0;

    const TestContext = struct {
        count: *usize,
        buffer: *[256]u8,
        len: *usize,

        fn logCallback(ctx: *anyopaque, level: Logger.LogLevel, message: []const u8) void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.count.* += 1;
            _ = level;
            @memcpy(self.buffer[0..message.len], message);
            self.len.* = message.len;
        }
    };

    var test_ctx = TestContext{
        .count = &log_count,
        .buffer = &last_message,
        .len = &message_len,
    };

    const base_logger = Logger{
        .context = &test_ctx,
        .logFn = TestContext.logCallback,
    };

    var ctx_logger = try ContextualLogger.init(testing.allocator, base_logger, "MyModule");
    defer ctx_logger.deinit();

    const logger = ctx_logger.logger();
    logger.info("Operation complete", .{});

    try testing.expectEqual(1, log_count);
    const logged = last_message[0..message_len];
    try testing.expect(std.mem.indexOf(u8, logged, "[MyModule]") != null);
    try testing.expect(std.mem.indexOf(u8, logged, "Operation complete") != null);
}
// ANCHOR_END: contextual_logger

// ANCHOR: multi_logger
/// Logger that forwards to multiple loggers
pub const MultiLogger = struct {
    loggers: []Logger,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, loggers: []const Logger) !MultiLogger {
        const owned = try allocator.alloc(Logger, loggers.len);
        @memcpy(owned, loggers);
        return .{
            .loggers = owned,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MultiLogger) void {
        self.allocator.free(self.loggers);
    }

    pub fn logger(self: *MultiLogger) Logger {
        return .{
            .context = self,
            .logFn = logCallback,
        };
    }

    fn logCallback(context: *anyopaque, level: Logger.LogLevel, message: []const u8) void {
        const self: *MultiLogger = @ptrCast(@alignCast(context));

        for (self.loggers) |log| {
            log.logFn(log.context, level, message);
        }
    }
};

test "multi logger" {
    var count1: usize = 0;
    var count2: usize = 0;

    const Counter = struct {
        fn logCallback(context: *anyopaque, level: Logger.LogLevel, message: []const u8) void {
            const count: *usize = @ptrCast(@alignCast(context));
            count.* += 1;
            _ = level;
            _ = message;
        }
    };

    const logger1 = Logger{ .context = &count1, .logFn = Counter.logCallback };
    const logger2 = Logger{ .context = &count2, .logFn = Counter.logCallback };

    const loggers = [_]Logger{ logger1, logger2 };
    var multi = try MultiLogger.init(testing.allocator, &loggers);
    defer multi.deinit();

    const logger = multi.logger();
    logger.info("Test", .{});

    try testing.expectEqual(1, count1);
    try testing.expectEqual(1, count2);
}
// ANCHOR_END: multi_logger

// ANCHOR: filtered_logger
/// Logger with custom filtering
pub const FilteredLogger = struct {
    base: Logger,
    filter_fn: *const fn (level: Logger.LogLevel, message: []const u8) bool,

    pub fn init(base: Logger, filter_fn: *const fn (level: Logger.LogLevel, message: []const u8) bool) FilteredLogger {
        return .{
            .base = base,
            .filter_fn = filter_fn,
        };
    }

    pub fn logger(self: *FilteredLogger) Logger {
        return .{
            .context = self,
            .logFn = logCallback,
        };
    }

    fn logCallback(context: *anyopaque, level: Logger.LogLevel, message: []const u8) void {
        const self: *FilteredLogger = @ptrCast(@alignCast(context));

        if (self.filter_fn(level, message)) {
            self.base.logFn(self.base.context, level, message);
        }
    }
};

fn errorOnlyFilter(level: Logger.LogLevel, message: []const u8) bool {
    _ = message;
    return level == .err;
}

test "filtered logger" {
    var count: usize = 0;

    const Counter = struct {
        fn logCallback(context: *anyopaque, level: Logger.LogLevel, message: []const u8) void {
            const c: *usize = @ptrCast(@alignCast(context));
            c.* += 1;
            _ = level;
            _ = message;
        }
    };

    const base_logger = Logger{ .context = &count, .logFn = Counter.logCallback };
    var filtered = FilteredLogger.init(base_logger, errorOnlyFilter);
    const logger = filtered.logger();

    logger.info("Info message", .{});
    try testing.expectEqual(0, count);

    logger.err("Error message", .{});
    try testing.expectEqual(1, count);
}
// ANCHOR_END: filtered_logger

// ANCHOR: buffered_logger
/// Buffered logger for performance
pub const BufferedLogger = struct {
    base: Logger,
    buffer: std.ArrayList(LogEntry),
    allocator: std.mem.Allocator,
    auto_flush_threshold: usize,

    const LogEntry = struct {
        level: Logger.LogLevel,
        message: []u8,
    };

    pub fn init(allocator: std.mem.Allocator, base: Logger, auto_flush_threshold: usize) BufferedLogger {
        return .{
            .base = base,
            .buffer = std.ArrayList(LogEntry){},
            .allocator = allocator,
            .auto_flush_threshold = auto_flush_threshold,
        };
    }

    pub fn deinit(self: *BufferedLogger) void {
        self.flush();
        for (self.buffer.items) |entry| {
            self.allocator.free(entry.message);
        }
        self.buffer.deinit(self.allocator);
    }

    pub fn logger(self: *BufferedLogger) Logger {
        return .{
            .context = self,
            .logFn = logCallback,
        };
    }

    fn logCallback(context: *anyopaque, level: Logger.LogLevel, message: []const u8) void {
        const self: *BufferedLogger = @ptrCast(@alignCast(context));

        const owned_message = self.allocator.dupe(u8, message) catch return;
        const entry = LogEntry{
            .level = level,
            .message = owned_message,
        };

        self.buffer.append(self.allocator, entry) catch {
            self.allocator.free(owned_message);
            return;
        };

        if (self.buffer.items.len >= self.auto_flush_threshold) {
            self.flush();
        }
    }

    pub fn flush(self: *BufferedLogger) void {
        for (self.buffer.items) |entry| {
            self.base.logFn(self.base.context, entry.level, entry.message);
            self.allocator.free(entry.message);
        }
        self.buffer.clearRetainingCapacity();
    }
};

test "buffered logger" {
    var count: usize = 0;

    const Counter = struct {
        fn logCallback(context: *anyopaque, level: Logger.LogLevel, message: []const u8) void {
            const c: *usize = @ptrCast(@alignCast(context));
            c.* += 1;
            _ = level;
            _ = message;
        }
    };

    const base_logger = Logger{ .context = &count, .logFn = Counter.logCallback };
    var buffered = BufferedLogger.init(testing.allocator, base_logger, 3);
    defer buffered.deinit();

    const logger = buffered.logger();

    logger.info("Message 1", .{});
    try testing.expectEqual(0, count); // Buffered

    logger.info("Message 2", .{});
    try testing.expectEqual(0, count); // Still buffered

    logger.info("Message 3", .{});
    try testing.expectEqual(3, count); // Auto-flushed

    logger.info("Message 4", .{});
    try testing.expectEqual(3, count); // Buffered again

    buffered.flush();
    try testing.expectEqual(4, count); // Manual flush
}
// ANCHOR_END: buffered_logger

// ANCHOR: null_logger
/// No-op logger for when logging is disabled
pub const NullLogger = struct {
    pub fn logger(self: *NullLogger) Logger {
        return .{
            .context = self,
            .logFn = logCallback,
        };
    }

    fn logCallback(context: *anyopaque, level: Logger.LogLevel, message: []const u8) void {
        _ = context;
        _ = level;
        _ = message;
    }
};

test "null logger" {
    var null_logger = NullLogger{};
    var processor = DataProcessor.init(testing.allocator, null_logger.logger());

    try processor.process("test");
    try processor.validate(42);
}
// ANCHOR_END: null_logger
