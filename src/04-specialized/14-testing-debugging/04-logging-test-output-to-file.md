# Recipe 14.4: Logging test output to a file

## Problem

You need to capture test output to files for later analysis, debugging, or record-keeping. You want structured logs that can be reviewed after tests complete, especially for long-running test suites or CI/CD pipelines.

## Solution

Create a logger that writes test output to files. Use file I/O to capture logs and verify them after tests complete:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_4.zig:basic_file_logging}}
```

## Discussion

File logging helps debug test failures, analyze performance, and maintain test records. Unlike console output, file logs persist and can be parsed by other tools.

### Timestamped Logging

Add timestamps to track test execution timing:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_4.zig:timestamped_logging}}
```

Timestamps help identify slow tests and understand execution flow.

### Using Temporary Directories

Use temporary directories for test logs to avoid cluttering your workspace:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_4.zig:temp_file_logging}}
```

Temporary directories are automatically cleaned up, keeping your file system clean.

### Structured JSON Logging

Log structured data for programmatic analysis:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_4.zig:structured_logging}}
```

JSON logs can be parsed by log aggregation tools and analyzed programmatically.

### Logging Multiple Test Results

Track results from multiple tests in a single log file:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_4.zig:multi_test_logging}}
```

This pattern is useful for test runners and reporting tools.

### Error Logging

Capture and log errors during testing:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_4.zig:error_logging}}
```

Error logs help diagnose failures and track error patterns.

### Buffered Logging

Buffer log entries in memory before writing to reduce I/O:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_4.zig:buffered_logging}}
```

Buffering improves performance when writing many small log entries.

### Performance Logging

Log timing information to identify slow tests:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_4.zig:performance_logging}}
```

Performance logs help optimize slow tests and identify regressions.

### Best Practices

1. **Close files before reading**: Call `deinit()` before reading log files to ensure all data is flushed
2. **Use temporary directories**: Leverage `std.testing.tmpDir` for automatic cleanup
3. **Structure your logs**: Use JSON or other structured formats for easier parsing
4. **Include timestamps**: Help correlate log entries with test execution
5. **Log errors separately**: Make errors easy to find and analyze
6. **Clean up test files**: Always delete log files after tests complete
7. **Buffer when appropriate**: Use buffering for high-frequency logging

### File Logging Patterns

**Pattern 1: Logger with Auto-flush**
```zig
const Logger = struct {
    file: std.fs.File,

    fn deinit(self: *Logger) void {
        self.file.sync() catch {}; // Ensure data is written
        self.file.close();
    }
};
```

**Pattern 2: Test Suite Logger**
```zig
fn runTestSuite(log_path: []const u8) !void {
    var logger = try Logger.init(log_path);
    defer logger.deinit();

    // Run tests, logging results
    logger.logStart();
    defer logger.logEnd();
}
```

**Pattern 3: Hierarchical Logs**
```zig
// tests/
//   ├── suite1.log
//   ├── suite2.log
//   └── summary.log

// Each test suite writes to its own file
// Summary aggregates all results
```

### Common Gotchas

**Not flushing before reading**: Files must be closed or synced before reading:

```zig
// Wrong - file not yet flushed
logger.log("test");
const content = try std.fs.cwd().readFileAlloc(...);

// Right - close first
logger.log("test");
logger.deinit(); // Flushes and closes
const content = try std.fs.cwd().readFileAlloc(...);
```

**Forgetting cleanup**: Always delete test log files:

```zig
test "example" {
    var logger = try Logger.init("test.log");
    defer logger.deinit();
    defer std.fs.cwd().deleteFile("test.log") catch {}; // Don't forget!
}
```

**Wrong file permissions**: Open files with `.read = true` if you need to read back:

```zig
// For read-write access
const file = try dir.createFile("log.txt", .{ .read = true });
```

### Integration with CI/CD

File logs integrate well with continuous integration:

```zig
// CI-friendly logging
const ci_mode = std.process.getEnvVarOwned(allocator, "CI") catch null;
const logger = if (ci_mode != null)
    try StructuredLogger.init("ci-results.json")
else
    try ConsoleLogger.init();
```

This allows different logging strategies for local development versus CI environments.

## See Also

- Recipe 14.1: Testing program output sent to stdout
- Recipe 13.10: Adding logging to simple scripts
- Recipe 13.11: Adding logging to a library
- Recipe 14.13: Profiling and timing your program

Full compilable example: `code/04-specialized/14-testing-debugging/recipe_14_4.zig`
