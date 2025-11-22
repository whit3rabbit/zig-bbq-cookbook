# Recipe 14.10: Reraising the last exception

## Problem

You need to propagate an error up the call stack after performing cleanup, logging, or conditional handling. You want to reraise errors without losing information or breaking the error handling chain.

## Solution

Use `try` to automatically reraise errors, or `catch |err|` followed by `return err` to reraise after custom logic:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_10.zig:basic_reraise}}
```

## Discussion

Reraising errors is fundamental to Zig's error handling. The `try` keyword automatically propagates errors, while explicit reraising with `catch` gives you control for logging, cleanup, or conditional handling.

### Conditional Reraising with Logging

Log errors before reraising them:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_10.zig:conditional_reraise}}
```

This pattern ensures errors are logged while still being propagated to calling code.

### Reraising with Cleanup

Use `defer` and `errdefer` with error reraising:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_10.zig:reraise_with_cleanup}}
```

When `try` encounters an error, `defer` blocks run before the error is reraised, ensuring proper cleanup.

### Selective Reraising

Reraise some errors while handling others:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_10.zig:selective_reraise}}
```

This pattern lets you recover from specific errors while propagating critical ones.

### Reraising with Context

Add context before reraising:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_10.zig:reraise_with_context}}
```

Context tracking helps debug complex error scenarios by recording operation details.

### Error Reraising Chain

Reraise errors through multiple layers:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_10.zig:reraise_chain}}
```

Each layer can log or inspect the error before passing it up.

### Reraising with Errdefer

Combine `errdefer` with error propagation:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_10.zig:errdefer_reraise}}
```

`errdefer` runs cleanup only on error paths, then the error is automatically reraised.

### Reraising or Default

Return a default value for some errors, reraise others:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_10.zig:reraise_or_default}}
```

This pattern provides graceful degradation for recoverable errors.

### Transparent Reraising

Reraise errors from multiple operations:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_10.zig:transparent_reraise}}
```

Using `try` keeps error handling transparent and composable.

### Tracking Reraise Metrics

Track which errors are reraised vs. handled:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_10.zig:reraise_with_metric}}
```

Metrics help understand error patterns and recovery effectiveness.

### Best Practices

1. **Use `try` when possible**: Simplest and clearest way to reraise
2. **Log before reraising**: Record error context without suppressing the error
3. **Clean up with defer/errdefer**: Ensure resources are freed before reraising
4. **Selective reraising**: Handle recoverable errors, reraise critical ones
5. **Preserve error type**: Don't transform errors unnecessarily when reraising
6. **Document reraising**: Make it clear which functions reraise errors
7. **Test error paths**: Ensure reraised errors propagate correctly

### Reraising Patterns

**Pattern 1: Transparent Propagation**
```zig
fn wrapper() !T {
    return try innerFunction(); // Simple reraise
}
```

**Pattern 2: Log and Reraise**
```zig
fn wrapper() !T {
    return innerFunction() catch |err| {
        log.error("Operation failed: {s}", .{@errorName(err)});
        return err;
    };
}
```

**Pattern 3: Cleanup and Reraise**
```zig
fn wrapper() !T {
    var resource = try acquire();
    defer release(resource);
    return try useResource(resource);
}
```

**Pattern 4: Conditional Reraise**
```zig
fn wrapper() !T {
    return innerFunction() catch |err| {
        if (isRecoverable(err)) return fallback();
        return err; // Reraise non-recoverable
    };
}
```

### Common Gotchas

**Forgetting to reraise**: Always reraise unless you intentionally handle the error:

```zig
// Wrong - error silently swallowed
operation() catch |err| {
    log.error("Failed: {s}", .{@errorName(err)});
    // Missing: return err;
};

// Right - error logged and reraised
operation() catch |err| {
    log.error("Failed: {s}", .{@errorName(err)});
    return err;
};
```

**Transforming when reraising**: Don't change error types unnecessarily:

```zig
// Wrong - loses specific error information
operation() catch |err| {
    return error.GenericFailure;
};

// Right - reraise original error
operation() catch |err| {
    log.error("Error: {s}", .{@errorName(err)});
    return err;
};
```

**Cleanup order issues**: Remember `defer` runs in reverse order:

```zig
// Wrong - may close file before buffer flush
var file = try open();
defer file.close();
var buffer = try allocate();
defer free(buffer);
return try processFile(file, buffer);

// Right - buffer freed first, then file closed
var file = try open();
errdefer file.close();
var buffer = try allocate();
errdefer free(buffer);
const result = try processFile(file, buffer);
defer file.close();
defer free(buffer);
return result;
```

### When to Reraise

**Reraise when:**
- Error cannot be handled at current level
- Need to log or track error before propagating
- Performing cleanup before propagation
- Error is critical and must reach top level
- Implementing middleware or wrapper functions

**Don't reraise when:**
- Error can be fully handled at current level
- You have a valid fallback value
- Error is expected and part of normal flow
- Transforming to a more appropriate error type
- Aggregating errors for batch reporting

### Difference Between `try` and Explicit Reraising

**Using `try`:**
```zig
fn simple() !void {
    try operation(); // Concise, automatic reraise
}
```

**Explicit catch and return:**
```zig
fn explicit() !void {
    operation() catch |err| {
        // Can add logic here
        std.debug.print("Error: {s}\n", .{@errorName(err)});
        return err; // Explicit reraise
    };
}
```

Both achieve the same result, but explicit reraising allows custom logic.

### Testing Reraised Errors

Verify errors propagate correctly:

```zig
test "errors are reraised" {
    try expectError(error.Specific, topLevelFunction());
}

test "cleanup happens before reraise" {
    // Verify resources are freed even when errors are reraised
    var tracker = ResourceTracker.init();
    _ = functionThatReraises() catch {};
    try expect(tracker.allFreed());
}
```

### Performance Considerations

Reraising has minimal overhead:
- No stack unwinding like exceptions
- Errors are just `u16` values
- `try` compiles to a simple branch
- Cleanup with `defer` is zero-cost when successful
- No memory allocation for error propagation

### Integration with Error Recovery

Reraising enables layered error handling:

```zig
fn application() void {
    businessLogic() catch |err| {
        handleApplicationError(err);
        return;
    };
}

fn businessLogic() !void {
    return try dataLayer(); // Reraise to application
}

fn dataLayer() !void {
    return try database(); // Reraise to business logic
}
```

Each layer can inspect errors without breaking the propagation chain.

## See Also

- Recipe 14.9: Raising an exception in response to another exception
- Recipe 14.8: Creating custom exception types
- Recipe 14.6: Handling multiple exceptions at once
- Recipe 1.2: Error Handling Patterns
- Recipe 0.11: Optionals, Errors, and Resource Cleanup

Full compilable example: `code/04-specialized/14-testing-debugging/recipe_14_10.zig`
