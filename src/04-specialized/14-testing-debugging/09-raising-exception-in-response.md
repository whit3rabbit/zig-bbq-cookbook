# Recipe 14.9: Raising an exception in response to another exception

## Problem

You need to catch one error and return a different error, transforming low-level errors into high-level ones or adding context. You want to maintain error information while crossing abstraction boundaries.

## Solution

Catch an error and return a new error with appropriate context:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_9.zig:error_transformation}}
```

## Discussion

Error transformation is essential for maintaining clean abstraction layers. Low-level errors (like file I/O errors) should be transformed into domain-specific errors (like configuration errors) at API boundaries.

### Error Context Chaining

Chain errors through multiple layers while preserving context:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_9.zig:error_context_chain}}
```

Error chaining helps debug complex failures by showing which layer failed and why.

### Wrapping Errors with Metadata

Wrap errors in structs to preserve both the original error and additional context:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_9.zig:wrapping_errors}}
```

This pattern is useful when you need to preserve the original error for debugging while providing user-friendly error information.

### Conditional Error Wrapping

Transform errors selectively based on type and context:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_9.zig:conditional_wrapping}}
```

Conditional wrapping lets you classify errors by recoverability, making retry logic easier to implement.

### Error Enrichment

Add metadata like timestamps and categorization to errors:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_9.zig:error_enrichment}}
```

Enrichment helps with error analytics and determining appropriate recovery strategies.

### Multi-Layer Error Wrapping

Transform errors through multiple abstraction layers:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_9.zig:multi_layer_wrapping}}
```

Each layer wraps the error from the layer below, creating a chain of transformations.

### Error Recovery Strategy Chain

Use error information to determine recovery strategies:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_9.zig:error_recovery_chain}}
```

Strategy-based recovery makes error handling more maintainable and testable.

### Error Stack Tracking

Track the full error propagation path:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_9.zig:error_stack_tracking}}
```

Error stack tracking provides detailed debugging information showing exactly where and how errors propagated.

### Best Practices

1. **Transform at boundaries**: Convert errors when crossing abstraction layers
2. **Preserve original errors**: Keep original error information for debugging
3. **Add context**: Include meaningful context like operation names and parameters
4. **Use type safety**: Leverage Zig's error sets to enforce error handling
5. **Document transformations**: Explain why errors are transformed
6. **Consider recovery**: Design error transformations to support retry and fallback
7. **Log before transforming**: Record original error before wrapping

### Error Transformation Patterns

**Pattern 1: Simple Mapping**
```zig
lowLevelOp() catch |err| {
    return switch (err) {
        error.FileNotFound => error.ConfigMissing,
        error.AccessDenied => error.Unauthorized,
        else => error.OperationFailed,
    };
};
```

**Pattern 2: Context Preservation**
```zig
lowLevelOp() catch |err| {
    std.debug.print("Failed: {s}\n", .{@errorName(err)});
    return error.HighLevelFailure;
};
```

**Pattern 3: Conditional Transformation**
```zig
lowLevelOp() catch |err| {
    if (isRetryable(err)) return error.ShouldRetry;
    if (isFatal(err)) return error.Abort;
    return err; // Propagate unchanged
};
```

### Common Gotchas

**Losing error information**: Always log or store original errors before transforming:

```zig
// Wrong - original error lost
lowLevelOp() catch {
    return error.Failed;
};

// Right - original error logged
lowLevelOp() catch |err| {
    std.debug.print("Original error: {s}\n", .{@errorName(err)});
    return error.Failed;
};
```

**Over-transforming**: Don't transform errors unnecessarily:

```zig
// Wrong - error transformed at every layer
fn layer1() !void { return error.Failed; }
fn layer2() !void { layer1() catch return error.L2Failed; }
fn layer3() !void { layer2() catch return error.L3Failed; }

// Right - only transform at API boundaries
fn layer1() !void { return error.Failed; }
fn layer2() !void { try layer1(); }  // Propagate unchanged
fn apiFunction() !void { layer2() catch return error.ApiFailed; }
```

**Incorrect error categorization**: Ensure error transformations are accurate:

```zig
// Wrong - timeout is retryable, not permanent
operation() catch |err| switch (err) {
    error.Timeout => error.PermanentFailure,  // Should be retryable
    else => err,
};

// Right - categorize appropriately
operation() catch |err| switch (err) {
    error.Timeout => error.Retryable,
    error.NotFound => error.Permanent,
    else => err,
};
```

### When to Transform Errors

**Transform when:**
- Crossing abstraction boundaries (file errors → config errors)
- Hiding implementation details from users
- Adding domain-specific context
- Supporting retry/fallback logic
- Aggregating multiple error sources

**Don't transform when:**
- Within the same abstraction layer
- Error information would be lost
- Original error is already meaningful
- No value added by transformation

### Integration with Error Recovery

Error transformation enables sophisticated recovery:

```zig
const result = operation() catch |err| {
    const category = categorize(err);

    return switch (category) {
        .transient => {
            std.time.sleep(1000);
            return operation(); // Retry
        },
        .permanent => {
            return fallbackOperation(); // Fallback
        },
        .fatal => {
            std.debug.panic("Unrecoverable: {s}", .{@errorName(err)});
        },
    };
};
```

### Error Transformation and Testing

Test both the transformation logic and error paths:

```zig
test "error transformation" {
    // Test that low-level errors are transformed
    try expectError(error.ConfigError, loadConfig("missing.conf"));

    // Test that context is preserved (via logging)
    // Test that original error can be recovered from metadata
}
```

### Performance Considerations

Error transformation has minimal overhead:
- No memory allocation (errors are `u16` values)
- No runtime cost for error set checks
- Logging and metadata structures may allocate
- Consider using stack-allocated error context structs

## See Also

- Recipe 14.8: Creating custom exception types
- Recipe 14.10: Reraising the last exception
- Recipe 14.6: Handling multiple exceptions at once
- Recipe 1.2: Error Handling Patterns
- Recipe 0.11: Optionals, Errors, and Resource Cleanup

Full compilable example: `code/04-specialized/14-testing-debugging/recipe_14_9.zig`
