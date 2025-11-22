# Recipe 14.2: Patching objects in unit tests

## Problem

You need to test code that depends on external systems (databases, APIs, file systems) without actually using those systems. You want to replace dependencies with test doubles that provide controlled behavior.

## Solution

Use dependency injection with function pointers to swap real implementations for test implementations. Design your code to accept dependencies rather than creating them internally:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_2.zig:dependency_injection}}
```

## Discussion

Zig doesn't have traditional mocking frameworks, but its explicit design and compile-time features make testing flexible and straightforward. The key is designing for testability from the start.

### Interface Pattern with Function Pointers

Create interfaces using structs with function pointers. This allows complete control over behavior during testing:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_2.zig:interface_pattern}}
```

This pattern gives you:
- Complete isolation from external dependencies
- Control over return values and errors
- No need for complex mocking libraries

### Tracking State in Tests

Create test doubles that capture calls and state for verification:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_2.zig:state_tracking}}
```

The test logger captures all log messages, letting you verify logging behavior without polluting test output.

### Simulating Errors

Test error handling by creating implementations that return specific errors:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_2.zig:error_simulation}}
```

This ensures your error handling works correctly without needing actual failures.

### Compile-Time Test Mode

Use `comptime` parameters to switch between test and production code:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_2.zig:comptime_switching}}
```

The compiler eliminates the test code in release builds, giving you zero runtime overhead.

### Counting Function Calls

Verify that functions are called the expected number of times:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_2.zig:call_counting}}
```

### Returning Sequences of Values

Test code that makes multiple calls by returning different values each time:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_2.zig:return_sequence}}
```

This lets you simulate changing conditions or progressive state.

### Design Patterns for Testability

**1. Dependency Injection**
Pass dependencies as parameters rather than creating them internally:

```zig
// Hard to test
fn processData() !void {
    const db = Database.connect("localhost");  // Fixed dependency
    // ...
}

// Easy to test
fn processData(db: *const Database) !void {
    // db can be real or mock
}
```

**2. Function Pointer Tables**
Use structs with function pointers as lightweight interfaces:

```zig
const Storage = struct {
    saveFn: *const fn(*anyopaque, []const u8) anyerror!void,
    ctx: *anyopaque,
};
```

**3. Comptime Switching**
Use comptime parameters for test-specific behavior:

```zig
fn Client(comptime testing: bool) type {
    // Different behavior based on testing flag
}
```

### Best Practices

1. **Accept interfaces, not concrete types**: Use function pointers for flexibility
2. **Keep context opaque**: Use `*anyopaque` for context pointers
3. **Design for injection**: Pass dependencies rather than creating them
4. **Leverage comptime**: Use compile-time switches for test modes
5. **Create test builders**: Make helper functions to create test doubles
6. **Document test doubles**: Explain what behavior they simulate

### Common Gotchas

**Type safety with anyopaque**: When casting from `*anyopaque`, you must use both `@ptrCast` and `@alignCast`:

```zig
const self: *MyType = @ptrCast(@alignCast(ctx));
```

**Context lifetime**: The context pointer must outlive all uses of the struct containing it. Stack-allocated contexts work fine for tests.

**Error set compatibility**: Test implementations must return errors compatible with the expected error set. Use `anyerror` if needed, but prefer explicit error sets.

## See Also

- Recipe 14.1: Testing program output sent to stdout
- Recipe 14.3: Testing for exceptional conditions in unit tests
- Recipe 0.13: Testing and Debugging Fundamentals
- Recipe 8.12: Defining an interface

Full compilable example: `code/04-specialized/14-testing-debugging/recipe_14_2.zig`
