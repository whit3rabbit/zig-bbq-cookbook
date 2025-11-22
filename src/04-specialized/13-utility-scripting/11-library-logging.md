# Recipe 13.11: Adding Logging to a Library

## Problem

You're writing a library and want to add logging without forcing users into a specific logging framework or implementation.

## Solution

Define a logger interface that users can implement with their preferred logging backend:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_11.zig:logger_interface}}
```

## Discussion

Adding logging to libraries is tricky. You want observability but can't impose a specific logging framework on users. The solution is to provide a pluggable interface that users can adapt to their needs.

### Optional Logging

Make logging optional so libraries work without any logger:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_11.zig:optional_logger}}
```

The `?Logger` optional type means:
- Library works without logging (`null` logger)
- No overhead when logging is disabled
- Users opt-in by providing a logger

### Standard Library Adapter

Adapt the interface to stdlib logging:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_11.zig:logger_adapter}}
```

This pattern lets users provide any backing implementation they want.

### File Logger Adapter

Write logs to a file:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_11.zig:file_logger}}
```

Users can create file-based logging without library changes.

### Contextual Logging

Add context information to log messages:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_11.zig:contextual_logger}}
```

Contextual loggers help track which component generated each log message.

### Multi-Target Logging

Forward logs to multiple destinations:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_11.zig:multi_logger}}
```

This allows logging to console AND file simultaneously, or any combination.

### Filtered Logging

Apply custom filtering logic:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_11.zig:filtered_logger}}
```

Filters enable:
- Level-based filtering (errors only, etc.)
- Pattern matching on messages
- Rate limiting
- Custom business logic

### Buffered Logging

Improve performance with buffering:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_11.zig:buffered_logger}}
```

Buffering reduces I/O overhead by batching log writes.

### Null Logger

Provide a no-op implementation:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_11.zig:null_logger}}
```

Use when you want to disable logging entirely with zero overhead.

## Best Practices

1. **Make logging optional** - Use `?Logger` so libraries work without logging
2. **Use interface pattern** - Define abstract logger interface for pluggability
3. **No allocations in log path** - Log functions should be allocation-free
4. **Buffer formatting** - Use stack buffers for message formatting
5. **Provide adapters** - Include common adapters (file, stdout, etc.)
6. **Document logger interface** - Clear docs help users implement custom loggers
7. **Zero cost when disabled** - Ensure logging adds no overhead when null

### Library Design Patterns

**Interface-based logging:**
```zig
pub const MyLibrary = struct {
    allocator: std.mem.Allocator,
    logger: ?Logger,

    pub fn init(allocator: std.mem.Allocator, logger: ?Logger) MyLibrary {
        return .{
            .allocator = allocator,
            .logger = logger,
        };
    }

    fn doWork(self: *MyLibrary) !void {
        if (self.logger) |log| {
            log.info("Starting work", .{});
        }

        // Actual work here

        if (self.logger) |log| {
            log.debug("Work complete", .{});
        }
    }
};
```

**Builder pattern with logger:**
```zig
pub const Config = struct {
    allocator: std.mem.Allocator,
    logger: ?Logger = null,
    timeout: u64 = 30,
    retries: u32 = 3,

    pub fn withLogger(self: Config, logger: Logger) Config {
        var config = self;
        config.logger = logger;
        return config;
    }
};

// Usage
const config = Config{
    .allocator = allocator,
}.withLogger(my_logger);
```

### User Integration Examples

**Console logging:**
```zig
var std_logger = StdLogger.init(.info);
var lib = MyLibrary.init(allocator, std_logger.logger());
```

**File logging:**
```zig
const log_file = try std.fs.cwd().createFile("app.log", .{});
defer log_file.close();

var file_logger = FileLogger.init(log_file, .debug, true);
var lib = MyLibrary.init(allocator, file_logger.logger());
```

**Multi-destination logging:**
```zig
var std_logger = StdLogger.init(.info);
var file_logger = FileLogger.init(log_file, .debug, true);

const loggers = [_]Logger{
    std_logger.logger(),
    file_logger.logger(),
};

var multi = try MultiLogger.init(allocator, &loggers);
defer multi.deinit();

var lib = MyLibrary.init(allocator, multi.logger());
```

**Contextual logging:**
```zig
var base_logger = StdLogger.init(.info);
var ctx_logger = try ContextualLogger.init(
    allocator,
    base_logger.logger(),
    "DatabaseModule"
);
defer ctx_logger.deinit();

var lib = MyLibrary.init(allocator, ctx_logger.logger());
```

**No logging:**
```zig
var lib = MyLibrary.init(allocator, null);
```

### Performance Considerations

**Zero-cost abstraction:**
- Optional logger compiles to simple null check
- No virtual dispatch overhead (direct function pointers)
- Stack-allocated buffers for formatting
- Inline-able log calls

**Buffering:**
- Reduces syscall overhead
- Groups related messages
- Adjustable flush threshold
- Manual flush control

**Filtering:**
- Early exit for disabled levels
- No message formatting if filtered
- Custom filter logic possible
- Compile-time optimization opportunities

### Advanced Patterns

**Structured logging:**
```zig
pub const StructuredLogger = struct {
    base: Logger,
    fields: std.StringHashMap([]const u8),

    pub fn withField(self: *StructuredLogger, key: []const u8, value: []const u8) !void {
        try self.fields.put(key, value);
    }

    fn logCallback(context: *anyopaque, level: Logger.LogLevel, message: []const u8) void {
        const self: *StructuredLogger = @ptrCast(@alignCast(context));

        var buf: [2048]u8 = undefined;
        var stream = std.io.fixedBufferStream(&buf);
        const writer = stream.writer();

        writer.print("{s}", .{message}) catch return;

        var iter = self.fields.iterator();
        while (iter.next()) |entry| {
            writer.print(" {s}={s}", .{ entry.key_ptr.*, entry.value_ptr.* }) catch return;
        }

        self.base.logFn(self.base.context, level, stream.getWritten());
    }
};
```

**Async-safe logging:**
```zig
pub const AsyncSafeLogger = struct {
    base: Logger,
    mutex: std.Thread.Mutex,

    pub fn init(base: Logger) AsyncSafeLogger {
        return .{
            .base = base,
            .mutex = .{},
        };
    }

    fn logCallback(context: *anyopaque, level: Logger.LogLevel, message: []const u8) void {
        const self: *AsyncSafeLogger = @ptrCast(@alignCast(context));

        self.mutex.lock();
        defer self.mutex.unlock();

        self.base.logFn(self.base.context, level, message);
    }
};
```

**Rate-limited logging:**
```zig
pub const RateLimitedLogger = struct {
    base: Logger,
    last_log_time: i64,
    min_interval_ns: i64,

    pub fn init(base: Logger, min_interval_ms: i64) RateLimitedLogger {
        return .{
            .base = base,
            .last_log_time = 0,
            .min_interval_ns = min_interval_ms * std.time.ns_per_ms,
        };
    }

    fn logCallback(context: *anyopaque, level: Logger.LogLevel, message: []const u8) void {
        const self: *RateLimitedLogger = @ptrCast(@alignCast(context));

        const now = std.time.nanoTimestamp();
        if (now - self.last_log_time < self.min_interval_ns) {
            return; // Rate limited
        }

        self.last_log_time = now;
        self.base.logFn(self.base.context, level, message);
    }
};
```

### Testing with Loggers

**Capture logs in tests:**
```zig
test "library operations are logged" {
    var log_messages = std.ArrayList([]const u8){};
    defer {
        for (log_messages.items) |msg| {
            testing.allocator.free(msg);
        }
        log_messages.deinit(testing.allocator);
    }

    const TestLogger = struct {
        fn logCallback(context: *anyopaque, level: Logger.LogLevel, message: []const u8) void {
            const list: *std.ArrayList([]const u8) = @ptrCast(@alignCast(context));
            const owned = list.allocator.dupe(u8, message) catch return;
            list.append(list.allocator, owned) catch return;
            _ = level;
        }
    };

    const logger = Logger{
        .context = &log_messages,
        .logFn = TestLogger.logCallback,
    };

    var lib = MyLibrary.init(testing.allocator, logger);
    try lib.doWork();

    try testing.expect(log_messages.items.len > 0);
    try testing.expect(std.mem.indexOf(u8, log_messages.items[0], "Starting work") != null);
}
```

**Verify log levels:**
```zig
test "errors are logged at error level" {
    var error_count: usize = 0;

    const ErrorCounter = struct {
        fn logCallback(context: *anyopaque, level: Logger.LogLevel, message: []const u8) void {
            if (level == .err) {
                const count: *usize = @ptrCast(@alignCast(context));
                count.* += 1;
            }
            _ = message;
        }
    };

    const logger = Logger{
        .context = &error_count,
        .logFn = ErrorCounter.logCallback,
    };

    var lib = MyLibrary.init(testing.allocator, logger);
    _ = lib.failingOperation() catch {};

    try testing.expectEqual(1, error_count);
}
```

### Security Considerations

**Sensitive data:**
- Never log passwords, API keys, tokens
- Redact sensitive fields automatically
- Use separate logger for audit trails
- Consider log file permissions

**Log injection:**
- Sanitize user input before logging
- Prevent newline injection
- Validate log message format
- Limit message length

**Resource limits:**
- Limit log file size
- Implement rotation
- Set buffer size limits
- Monitor disk usage

### Integration with Existing Frameworks

**Zig std.log:**
```zig
pub fn stdLogAdapter() Logger {
    return .{
        .context = undefined,
        .logFn = struct {
            fn logCallback(context: *anyopaque, level: Logger.LogLevel, message: []const u8) void {
                _ = context;
                switch (level) {
                    .debug => std.log.debug("{s}", .{message}),
                    .info => std.log.info("{s}", .{message}),
                    .warn => std.log.warn("{s}", .{message}),
                    .err => std.log.err("{s}", .{message}),
                }
            }
        }.logCallback,
    };
}
```

**Custom application logger:**
```zig
pub fn appLoggerAdapter(app_logger: *YourAppLogger) Logger {
    return .{
        .context = app_logger,
        .logFn = struct {
            fn logCallback(context: *anyopaque, level: Logger.LogLevel, message: []const u8) void {
                const logger: *YourAppLogger = @ptrCast(@alignCast(context));
                logger.log(@intFromEnum(level), message);
            }
        }.logCallback,
    };
}
```

## See Also

- Recipe 13.10: Adding logging to simple scripts
- Recipe 13.2: Terminating a program with an error message
- Recipe 14.4: Logging test output to a file

Full compilable example: `code/04-specialized/13-utility-scripting/recipe_13_11.zig`
