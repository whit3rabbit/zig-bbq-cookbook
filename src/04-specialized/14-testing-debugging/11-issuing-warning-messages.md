# Recipe 14.11: Issuing warning messages

## Problem

You need to alert users about potential issues, deprecated features, or suboptimal conditions without failing the program. You want to provide informative warnings that help with debugging and maintenance.

## Solution

Use `std.debug.print` for simple warnings or `std.log` for structured logging:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_11.zig:basic_debug_warning}}
```

## Discussion

Zig doesn't have a built-in warning system like some languages, but provides powerful logging and debug printing capabilities. Warnings help users understand issues without halting execution.

### Structured Logging

Use `std.log` for categorized, scoped warnings:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_11.zig:structured_logging}}
```

The logging system supports different levels (debug, info, warn, err) and can be filtered at compile time.

### Warnings with Context

Include file, line, and context information:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_11.zig:warning_with_context}}
```

Context-rich warnings make it easier to locate and fix issues.

### Warning Levels

Categorize warnings by severity:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_11.zig:warning_levels}}
```

Different warning levels help prioritize which issues to address first.

### Conditional Warnings

Control warning output based on configuration:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_11.zig:conditional_warnings}}
```

Conditional warnings reduce noise in production while providing detail during development.

### Deprecation Warnings

Warn users about deprecated APIs:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_11.zig:deprecation_warnings}}
```

Deprecation warnings help users migrate to new APIs gradually.

### Warning Accumulation

Collect warnings for batch processing:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_11.zig:warning_accumulator}}
```

Accumulation is useful for validation where you want to report all issues at once.

### Warning Callbacks

Use callbacks for custom warning handling:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_11.zig:warning_callback}}
```

Callbacks enable integration with logging systems, file output, or network reporting.

### Categorized Warnings

Organize warnings by category:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_11.zig:warning_categories}}
```

Categories help users filter and respond to different warning types.

### Runtime Assertions with Warnings

Issue warnings for assertion violations without crashing:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_11.zig:runtime_assertions}}
```

Soft assertions continue execution while alerting to issues.

### Warning Suppression

Allow selective warning suppression:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_11.zig:warning_suppression}}
```

Suppression is useful when certain warnings are expected and acceptable.

### Best Practices

1. **Be specific**: Include relevant context in warning messages
2. **Use appropriate levels**: Match severity to impact (info < warn < err)
3. **Make actionable**: Suggest how to fix the issue
4. **Don't spam**: Warn once per condition, not repeatedly
5. **Log strategically**: Use structured logging for production code
6. **Provide context**: Include file, line, and operation details
7. **Allow suppression**: Let users disable expected warnings

### Warning Patterns

**Pattern 1: Validation Warning**
```zig
if (value < min or value > max) {
    std.log.warn("Value {d} out of range [{d}, {d}]", .{ value, min, max });
    return clamp(value, min, max);
}
```

**Pattern 2: Deprecation Notice**
```zig
fn deprecatedFunction() void {
    std.log.warn("deprecatedFunction() is deprecated, use newFunction()", .{});
    // ... old implementation
}
```

**Pattern 3: Performance Warning**
```zig
if (array.len > 10000) {
    std.log.warn("Large array ({d} elements) may impact performance", .{array.len});
}
```

**Pattern 4: Configuration Warning**
```zig
if (config.cache_size < recommended_minimum) {
    std.log.warn("Cache size {d} below recommended {d}", .{
        config.cache_size,
        recommended_minimum,
    });
}
```

### Common Gotchas

**Warning spam**: Don't emit the same warning repeatedly:

```zig
// Wrong - warns on every iteration
for (items) |item| {
    if (item.deprecated) {
        std.log.warn("Deprecated item", .{});
    }
}

// Right - warn once
var warned = false;
for (items) |item| {
    if (item.deprecated and !warned) {
        std.log.warn("{d} deprecated items found", .{count_deprecated(items)});
        warned = true;
    }
}
```

**Insufficient context**: Provide enough information to act:

```zig
// Wrong - what value? where?
std.log.warn("Invalid value", .{});

// Right - specific and actionable
std.log.warn("Invalid temperature {d}C at sensor {s}: must be 0-100C", .{
    temp,
    sensor_id,
});
```

**Wrong log level**: Match severity appropriately:

```zig
// Wrong - this isn't an error, it's a warning
std.log.err("Cache miss", .{});

// Right - cache misses are expected, info level
std.log.info("Cache miss for key: {s}", .{key});
```

### Compile-Time Warnings

For compile-time issues, use `@compileError` or `@compileLog`:

```zig
fn validateConfig(comptime config: Config) void {
    if (config.size < 10) {
        @compileError("Config size must be at least 10");
    }
}
```

Note: Zig doesn't have `@compileWarn`, use `@compileLog` for non-fatal messages.

### Integration with Logging Systems

Integrate with structured logging:

```zig
pub const std_options = struct {
    pub const log_level = .warn;
    pub const log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .cookbook, .level = .debug },
    };
};
```

This configuration controls which warnings appear.

### Warning Output Formatting

Format warnings for clarity:

```zig
const fmt_warning =
    \\Warning: {s}
    \\  Location: {s}:{d}
    \\  Suggestion: {s}
;

std.debug.print(fmt_warning, .{
    "Deprecated usage",
    file,
    line,
    "Use newApi() instead",
});
```

### Testing Warning Output

Test that warnings are emitted:

```zig
test "deprecated function warns" {
    // In practice, you'd capture output or use a test logger
    deprecatedFunction(); // Should emit warning
}
```

For production code, consider injectable loggers that can be mocked in tests.

### Performance Considerations

Warnings have minimal overhead:
- `std.debug.print` writes directly to stderr
- `std.log` can be compile-time filtered
- Log levels below the threshold compile to nothing
- No allocations for simple formatted output

However, be cautious with:
- Warnings in hot loops
- Complex string formatting in warnings
- Accumulating warnings that allocate memory

## See Also

- Recipe 14.12: Debugging basic program crashes
- Recipe 0.13: Testing and Debugging Fundamentals
- Recipe 13.10: Adding logging to simple scripts
- Recipe 13.11: Adding logging to a library

Full compilable example: `code/04-specialized/14-testing-debugging/recipe_14_11.zig`
