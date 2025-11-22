# Recipe 14.3: Testing for exceptional conditions in unit tests

## Problem

You need to verify that your code correctly handles error conditions. You want to test that functions return the right errors, propagate errors properly, and recover from failures as expected.

## Solution

Use `testing.expectError` to verify that functions return specific errors:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_3.zig:basic_error_testing}}
```

## Discussion

Error handling is critical in Zig. Testing error conditions ensures your code fails gracefully and provides meaningful feedback to callers.

### Testing Multiple Error Conditions

Create comprehensive tests for all possible error cases:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_3.zig:multiple_errors}}
```

Test every error in your error set to ensure complete coverage. This catches bugs where the wrong error is returned for a condition.

### Error Context and Validation

Test complex validation logic with descriptive errors:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_3.zig:error_context}}
```

### Error Propagation Through Call Stacks

Verify that errors propagate correctly through multiple function calls:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_3.zig:error_propagation}}
```

The `try` keyword automatically propagates errors up the call stack. Test this behavior to ensure errors flow correctly.

### Checking Error Union Values

Sometimes you need to inspect error unions directly:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_3.zig:error_union_checking}}
```

This pattern is useful when you need to handle both success and error cases in the same test or when the specific error matters.

### Testing Error Recovery

Test code that recovers from errors:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_3.zig:error_recovery}}
```

Retry logic and fallback mechanisms need careful testing to ensure they handle transient failures correctly.

### Custom Error Messages and Context

Test parser and state machine errors:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_3.zig:custom_error_messages}}
```

State machines and parsers often have complex error conditions that need thorough testing.

### Testing Functions with anyerror

When functions use `anyerror`, test the specific errors they can return:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_3.zig:anyerror_testing}}
```

Even with `anyerror`, you can still test for specific error values.

### Testing Error Traces

Test errors that occur at different stages of multi-step processes:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_3.zig:error_trace}}
```

This ensures each processing step validates correctly and returns appropriate errors.

### Best Practices

1. **Test every error case**: Cover all possible errors in your error set
2. **Test the happy path too**: Always include tests for successful operations
3. **Use specific error assertions**: Prefer `expectError` over generic checks
4. **Test error propagation**: Verify errors flow correctly through call chains
5. **Test error recovery**: Ensure retry and fallback logic works
6. **Document error conditions**: Explain when each error occurs

### Error Testing Patterns

**Pattern 1: Exhaustive Error Testing**
```zig
test "all error conditions" {
    try testing.expectError(error.Case1, function(input1));
    try testing.expectError(error.Case2, function(input2));
    try testing.expectError(error.Case3, function(input3));
    // Test success case last
    _ = try function(validInput);
}
```

**Pattern 2: Error Set Verification**
```zig
test "error belongs to set" {
    const result = riskyOperation();
    if (result) |_| {
        try testing.expect(false); // Should have failed
    } else |err| {
        // Verify error is one of the expected ones
        try testing.expect(err == error.Type1 or err == error.Type2);
    }
}
```

**Pattern 3: State After Error**
```zig
test "state preserved after error" {
    var obj = Object.init();
    defer obj.deinit();

    _ = obj.operation() catch {};  // May fail
    try testing.expect(obj.isValid());  // But object still valid
}
```

### Common Gotchas

**Testing wrong error**: Make sure you test for the specific error the function should return, not just any error:

```zig
// Wrong - too broad
try testing.expect(result == error.NotFound or result == error.PermissionDenied);

// Right - specific
try testing.expectError(error.NotFound, result);
```

**Forgetting the success case**: Always test that valid inputs succeed:

```zig
test "complete validation testing" {
    // Test all error cases
    try testing.expectError(error.Invalid, validate(bad_input));

    // Don't forget the success case!
    try validate(good_input);
}
```

**Not testing error propagation**: Errors should propagate through `try`. Test this:

```zig
test "error propagates correctly" {
    // This ensures inner function errors reach outer
    try testing.expectError(error.Inner, outerFunction());
}
```

### Testing Error Messages

When errors include context, you might want to test the error and related data separately:

```zig
const ResultWithContext = struct {
    data: ?[]const u8,
    error_detail: ?[]const u8,
};

fn operationWithContext() !ResultWithContext {
    // ... operation that might fail with context
}

test "error provides context" {
    const result = operationWithContext() catch |err| {
        try testing.expectEqual(error.OperationFailed, err);
        // Check error was logged, state updated, etc.
        return;
    };
    try testing.expect(result.data != null);
}
```

## See Also

- Recipe 14.1: Testing program output sent to stdout
- Recipe 14.2: Patching objects in unit tests
- Recipe 0.11: Optionals, Errors, and Resource Cleanup
- Recipe 1.2: Error Handling Patterns

Full compilable example: `code/04-specialized/14-testing-debugging/recipe_14_3.zig`
