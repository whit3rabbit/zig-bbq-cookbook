# Recipe 14.6: Handling multiple exceptions at once

## Problem

You need to handle different types of errors in a single function or manage multiple errors from parallel operations. You want to apply different recovery strategies based on error type and context.

## Solution

Use error unions and switch statements to handle different error types:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_6.zig:error_union}}
```

## Discussion

Zig's error handling shines when dealing with multiple error types. Error unions (`||`) combine error sets, and switch statements let you handle each error appropriately.

### Switching on Error Types

Handle each error with custom logic:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_6.zig:switch_errors}}
```

This pattern tests all error paths systematically.

### Error Context and Messages

Provide meaningful messages for each error type:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_6.zig:error_context}}
```

Separating error handling from error messages improves maintainability.

### Cascading Error Handlers

Try multiple recovery strategies in sequence:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_6.zig:cascading_errors}}
```

This pattern gracefully degrades through fallback options.

### Recovery Strategies

Apply different strategies based on error severity:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_6.zig:error_recovery}}
```

Recovery strategies include:
- **Retry**: Try the operation again (for transient failures)
- **Fallback**: Use default values
- **Abort**: Propagate the error immediately

### Grouped Error Handling

Group related errors for common handling:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_6.zig:grouped_handling}}
```

This reduces code duplication when errors need similar handling.

### Error Aggregation

Collect multiple errors from a sequence of operations:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_6.zig:error_aggregation}}
```

Error aggregation is useful for validation where you want to report all errors, not just the first one.

### Error Chains

Preserve error context through call stacks:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_6.zig:error_chain}}
```

Error chains help debug issues by showing the full error path.

### Error Priority

Handle errors by priority or severity:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_6.zig:error_priority}}
```

Critical errors get immediate attention while minor errors can be ignored.

### Parallel Operations

Collect errors from parallel or batch operations:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_6.zig:parallel_errors}}
```

This pattern reports all failures rather than stopping at the first error.

### Best Practices

1. **Use error unions**: Combine error sets with `||` operator
2. **Switch exhaustively**: Handle all possible errors explicitly
3. **Provide context**: Include helpful error messages
4. **Cascade gracefully**: Try fallbacks before giving up
5. **Aggregate when appropriate**: Collect multiple errors for batch operations
6. **Chain for debugging**: Preserve error history through call stacks
7. **Prioritize correctly**: Handle critical errors first

### Error Handling Patterns

**Pattern 1: Type-Based Dispatch**
```zig
if (operation()) |value| {
    // Success
} else |err| switch (err) {
    error.NotFound => handleNotFound(),
    error.PermissionDenied => handlePermission(),
    else => return err,
}
```

**Pattern 2: Error Transformation**
```zig
const data = readFile(path) catch |err| switch (err) {
    error.FileNotFound => return error.ConfigMissing,
    error.AccessDenied => return error.PermissionError,
    else => return err,
};
```

**Pattern 3: Batch Processing**
```zig
var errors = ErrorList.init(allocator);
for (items) |item| {
    process(item) catch |err| {
        try errors.append(err);
        continue;
    };
}
if (errors.count() > 0) {
    return error.BatchProcessingFailed;
}
```

### Common Gotchas

**Not exhausting all cases**: Always handle all possible errors:

```zig
// Wrong - compiler error if new errors added
if (err == error.NotFound) { ... }

// Right - compiler enforces exhaustiveness
switch (err) {
    error.NotFound => { ... },
    error.PermissionDenied => { ... },
    // All errors must be handled
}
```

**Losing error context**: Preserve context when wrapping errors:

```zig
// Loses context
fn wrapper() !void {
    try innerFunction(); // Error info lost
}

// Preserves context
fn wrapper() !void {
    innerFunction() catch |err| {
        std.debug.print("Failed in wrapper: {s}\n", .{@errorName(err)});
        return err;
    };
}
```

**Ignoring partial failures**: In batch operations, track both successes and failures:

```zig
var result = BatchResult.init();
for (items) |item| {
    if (process(item)) {
        result.recordSuccess();
    } else |err| {
        result.recordError(err);
    }
}
```

### Advanced Techniques

**Error transformation pipeline**:
```zig
const result = step1()
    catch |err| transformError(err, .step1)
    catch step2()
    catch |err| transformError(err, .step2);
```

**Conditional retries**:
```zig
var attempt: usize = 0;
while (attempt < MAX_RETRIES) : (attempt += 1) {
    if (operation()) |val| return val else |err| {
        if (err == error.Permanent) return err;
        continue; // Retry on transient errors
    }
}
```

## See Also

- Recipe 14.3: Testing for exceptional conditions in unit tests
- Recipe 14.7: Catching all exceptions
- Recipe 1.2: Error Handling Patterns
- Recipe 0.11: Optionals, Errors, and Resource Cleanup

Full compilable example: `code/04-specialized/14-testing-debugging/recipe_14_6.zig`
