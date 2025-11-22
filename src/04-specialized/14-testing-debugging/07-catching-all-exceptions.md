# Recipe 14.7: Catching all exceptions

## Problem

You need to handle any error that might occur without knowing the specific error types in advance. You want generic error handling for logging, recovery, or providing fallback behavior.

## Solution

Use `catch` without specifying an error type to catch all errors. Access the error with `|err|`:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_7.zig:anyerror_catch}}
```

## Discussion

Zig's `catch` keyword handles all errors when used without a specific error set. This is useful for logging, providing defaults, or implementing fallback behavior.

### Catching and Logging

Catch all errors while logging them for debugging:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_7.zig:catch_and_log}}
```

This pattern ensures errors don't crash your program while still recording what went wrong.

### Inspecting Error Names

Use `@errorName()` to get the error name as a string:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_7.zig:error_name_inspection}}
```

Error name inspection allows dynamic error handling based on naming conventions.

### Global Error Handler

Create a centralized error handler:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_7.zig:global_error_handler}}
```

Global error handlers track metrics and provide consistent error handling across your application.

### Try-Or-Default Pattern

Provide default values when operations fail:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_7.zig:try_or_default}}
```

This generic function works with any error-returning operation.

### Panic on Unexpected Errors

For operations that must succeed, panic on any error:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_7.zig:panic_on_error}}
```

Use this pattern sparingly, only for truly unrecoverable situations.

### Explicit Result Types

Return both results and error flags:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_7.zig:catch_all_pattern}}
```

This pattern lets callers know an error occurred without propagating the error.

### Error Tracking

Track all errors encountered during execution:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_7.zig:error_tracking}}
```

Error tracking is useful for batch operations where you want to collect all failures.

### Fallback Chains

Try multiple approaches before giving up:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_7.zig:fallback_chain}}
```

Fallback chains provide graceful degradation when primary methods fail.

### Error Metrics

Collect statistics about errors:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_7.zig:error_metrics}}
```

Metrics help identify error patterns and reliability issues.

### Error Categorization

Categorize errors for appropriate handling:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_7.zig:error_categorization}}
```

Categorization enables policy-based error handling.

### Best Practices

1. **Catch specifically when possible**: Only use catch-all when you truly don't know error types
2. **Always log**: When catching all errors, log them for debugging
3. **Provide context**: Include information about what operation failed
4. **Use `@errorName()`**: Get error names for logging and categorization
5. **Track errors**: Collect errors for analysis and reporting
6. **Implement fallbacks**: Try alternative approaches before failing
7. **Categorize errors**: Group errors by type for appropriate handling

### Catch-All Patterns

**Pattern 1: Log and Continue**
```zig
operation() catch |err| {
    logger.log("Operation failed: {s}", .{@errorName(err)});
    continue; // or return default
};
```

**Pattern 2: Retry with Backoff**
```zig
var attempt: usize = 0;
while (attempt < MAX_RETRIES) : (attempt += 1) {
    operation() catch |err| {
        if (isFatal(err)) return err;
        std.time.sleep(backoff_ms * (attempt + 1));
        continue;
    };
    break;
}
```

**Pattern 3: Error Transformation**
```zig
const result = operation() catch |err| {
    std.debug.print("Failed: {s}\n", .{@errorName(err)});
    return error.OperationFailed;
};
```

### Common Gotchas

**Catching too broadly**: Don't use catch-all when you can handle specific errors:

```zig
// Wrong - loses type safety
operation() catch |err| { ... }

// Right - handle known errors
operation() catch |err| switch (err) {
    error.NotFound => handleNotFound(),
    error.PermissionDenied => handlePermission(),
    else => return err,
};
```

**Forgetting to log**: Always log caught errors:

```zig
// Wrong - error silently discarded
_ = operation() catch {};

// Right - error logged
operation() catch |err| {
    std.debug.print("Error: {s}\n", .{@errorName(err)});
};
```

**Inappropriate panics**: Only panic for truly unrecoverable errors:

```zig
// Wrong - panic on recoverable error
operation() catch |err| std.debug.panic("Failed: {s}", .{@errorName(err)});

// Right - handle gracefully
const result = operation() catch fallbackValue;
```

### Error Recovery Strategies

**By Category**:
```zig
operation() catch |err| switch (categorizeError(err)) {
    .validation => return error.BadInput,
    .network => retryWithBackoff(),
    .system => reportAndAbort(err),
    .unknown => std.debug.panic("Unexpected: {s}", .{@errorName(err)}),
};
```

**By Severity**:
```zig
operation() catch |err| {
    if (isCritical(err)) return err;
    if (isWarning(err)) log.warn("{s}", .{@errorName(err)});
    return defaultValue;
};
```

### Integration with Libraries

Libraries should generally avoid catch-all to preserve error information:

```zig
// Library code - preserve specific errors
pub fn libraryFunction() !Result {
    return innerOperation(); // Propagate specific error
}

// Application code - can catch all
pub fn main() !void {
    libraryFunction() catch |err| {
        std.debug.print("Application error: {s}\n", .{@errorName(err)});
        std.process.exit(1);
    };
}
```

## See Also

- Recipe 14.3: Testing for exceptional conditions in unit tests
- Recipe 14.6: Handling multiple exceptions at once
- Recipe 1.2: Error Handling Patterns
- Recipe 0.11: Optionals, Errors, and Resource Cleanup

Full compilable example: `code/04-specialized/14-testing-debugging/recipe_14_7.zig`
