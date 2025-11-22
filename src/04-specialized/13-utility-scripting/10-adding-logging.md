# Recipe 13.10: Adding Logging to Simple Scripts

## Problem

You need to add logging to scripts to track execution, debug issues, and monitor behavior without cluttering stdout.

## Solution

Create a simple logger that writes to stderr with log levels:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_10.zig:log_level}}
```

Use the SimpleLogger for basic script logging:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_10.zig:simple_logger}}
```

## Discussion

Logging is essential for understanding script behavior, especially when things go wrong. Unlike print statements, logs can be filtered by level, redirected to files, and include contextual information.

### Log Levels

The standard log levels in order of severity:

- **debug** - Detailed information for diagnosing issues
- **info** - General informational messages
- **warn** - Warning messages for potentially harmful situations
- **error** - Error messages for failures

Set a minimum level to control verbosity. Messages below the minimum level are filtered out.

### Structured Logging

Add key-value pairs for machine-readable logs:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_10.zig:structured_logger}}
```

Structured logging makes it easier to query and analyze logs later. Each log entry includes additional context as key-value pairs.

### File-Based Logging

Write logs to files with automatic rotation:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_10.zig:file_logger}}
```

File rotation prevents log files from growing indefinitely. When a file reaches the maximum size, it's renamed with a timestamp and a new file is started.

### Context Logger

Carry persistent context through multiple log entries:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_10.zig:context_logger}}
```

Context loggers automatically include common fields (like request ID or user) in every log message, reducing repetition.

### Timed Operations

Measure and log execution time:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_10.zig:timed_operation}}
```

Timed operations help identify performance bottlenecks. The duration is automatically logged when the operation completes.

### JSON Formatting

Format logs as JSON for integration with log aggregation systems:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_10.zig:log_formatter}}
```

JSON logs are easy to parse and index. They work well with tools like Elasticsearch, Splunk, or CloudWatch.

### Rate Limiting

Prevent log spam from repeated messages:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_10.zig:rate_limited_logger}}
```

Rate limiting prevents flooding logs with duplicate messages. Useful for errors that occur in tight loops.

### Best Practices

1. **Log to stderr** - Keep stdout clean for actual program output
2. **Use appropriate levels** - Debug for development, info for production
3. **Include context** - Log relevant details (IDs, paths, values)
4. **Avoid logging secrets** - Never log passwords, keys, or tokens
5. **Structured over unstructured** - Use key-value pairs for important data
6. **Timestamps matter** - Include timestamps for debugging time-sensitive issues
7. **Rotate log files** - Prevent disk space issues

### When to Log

**Do log:**
- Application start/stop
- Configuration loaded
- Important state changes
- Errors and warnings
- Long-running operations
- External service calls

**Don't log:**
- Every function call (too verbose)
- Secrets or sensitive data
- Binary data (use base64 if needed)
- Inside tight loops (consider rate limiting)
- Successful trivial operations

### Log Level Guidelines

**Debug:**
- Variable values
- Function entry/exit
- Detailed execution flow
- Only enabled during development

**Info:**
- Normal operations
- State transitions
- Configuration details
- Generally useful information

**Warn:**
- Deprecated feature usage
- Degraded performance
- Recoverable errors
- Potential issues

**Error:**
- Operation failures
- Invalid input
- Resource unavailable
- Exceptions/errors

### Integration Example

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};\n    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create logger
    var logger = SimpleLogger.init(.info);
    logger.info("Application starting", .{});

    // Process data with logging
    const result = processData(&logger, "input.txt") catch |err| {
        logger.err("Failed to process data: {}", .{err});
        return err;
    };

    logger.info("Processed {d} records", .{result.count});
}

fn processData(logger: *const SimpleLogger, path: []const u8) !ProcessResult {
    logger.debug("Opening file: {s}", .{path});

    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        logger.warn("Could not open file {s}: {}", .{ path, err });
        return err;
    };
    defer file.close();

    logger.info("Processing file {s}", .{path});

    // ... process file ...

    return ProcessResult{ .count = 42 };
}
```

### Environment-Based Configuration

Control logging via environment variables:

```zig
const log_level_str = std.process.getEnvVarOwned(allocator, "LOG_LEVEL") catch "info";
defer allocator.free(log_level_str);

const level = LogLevel.fromString(log_level_str) orelse .info;
var logger = SimpleLogger.init(level);
```

This allows users to enable debug logging without recompiling:

```bash
LOG_LEVEL=debug ./my_script
```

### Multiple Loggers

Use different loggers for different subsystems:

```zig
var general_logger = SimpleLogger.init(.info);
var debug_logger = SimpleLogger.init(.debug);

// General operations
general_logger.info("Starting server", .{});

// Verbose debugging for specific module
debug_logger.debug("Parsing config: {s}", .{config_data});
```

### Performance Considerations

**Buffering:**
- File loggers benefit from buffering
- Buffer writes to reduce syscall overhead
- Flush on errors or periodically

**String formatting:**
- Formatting is relatively expensive
- Check log level before formatting
- Use comptime format strings when possible

**Allocation:**
- Minimize allocations in hot paths
- Reuse buffers where possible
- Consider a ring buffer for in-memory logs

**Stack vs Heap:**
FileLogger uses an optimized allocation strategy to minimize heap churn:
- Normal messages (< 4KB) use a stack buffer, avoiding heap allocations entirely
- Large messages automatically fall back to heap allocation
- This reduces GC pressure and improves performance in the common case

```zig
// FileLogger implementation uses stack-first strategy
var stack_buf: [4096]u8 = undefined;
const msg = std.fmt.bufPrint(&stack_buf, fmt, args) catch blk: {
    // Only allocate on heap if message exceeds stack buffer
    break :blk try std.fmt.allocPrint(allocator, fmt, args);
};
defer if (is_heap_allocated) allocator.free(msg);
```

### Thread Safety

The loggers in this recipe buffer entire log messages before writing to prevent output interleaving when called from multiple threads. Each log entry is written with a single `writeAll()` call, which typically provides atomicity for small messages on POSIX systems.

**Limitations:**

Scripts are usually single-threaded, so full thread safety is not implemented. If you need thread-safe logging:

1. **Add a mutex** to serialize log calls:
```zig
pub const ThreadSafeLogger = struct {
    base: SimpleLogger,
    mutex: std.Thread.Mutex,

    pub fn init(min_level: LogLevel) ThreadSafeLogger {
        return .{
            .base = SimpleLogger.init(min_level),
            .mutex = .{},
        };
    }

    pub fn log(self: *ThreadSafeLogger, level: LogLevel, comptime fmt: []const u8, args: anytype) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.base.log(level, fmt, args);
    }
};
```

2. **FileLogger rotation** is not thread-safe. Use external log rotation tools (like logrotate) for multi-threaded applications.

3. **Rate limiting and context** access is not synchronized. Wrap in a mutex if accessed from multiple threads.

For production multi-threaded applications, consider using `std.log` with a custom logger implementation that provides full thread safety.

### Testing with Logs

Capture log output in tests:

```zig
test "operation logs correctly" {
    const log_file = "zig-cache/test_logs.txt";
    defer std.fs.cwd().deleteFile(log_file) catch {};

    const file = try std.fs.cwd().createFile(log_file, .{});
    defer file.close();

    var logger = SimpleLogger.initWithFile(.debug, file);
    logger.use_timestamps = false;

    doOperation(&logger);

    const content = try std.fs.cwd().readFileAlloc(testing.allocator, log_file, 1024);
    defer testing.allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "[INFO] Operation complete") != null);
}
```

### Common Patterns

**Logging errors with context:**
```zig
file.write(data) catch |err| {
    logger.err("Failed to write to {s}: {}", .{ path, err });
    return err;
};
```

**Conditional debug logging:**
```zig
if (logger.min_level == .debug) {
    logger.debug("Complex state: {any}", .{complex_struct});
}
```

**Logging with cleanup:**
```zig
logger.info("Starting operation", .{});
defer logger.info("Operation complete", .{});
errdefer logger.err("Operation failed", .{});
```

## See Also

- Recipe 13.2: Terminating a program with an error message
- Recipe 13.9: Reading configuration files
- Recipe 13.11: Adding logging to a library

Full compilable example: `code/04-specialized/13-utility-scripting/recipe_13_10.zig`
