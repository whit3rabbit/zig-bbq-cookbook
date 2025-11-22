# Recipe 14.12: Debugging basic program crashes

## Problem

You need to diagnose and fix program crashes, null pointer dereferences, buffer overflows, and other common bugs. You want tools and techniques to identify the root cause of crashes quickly.

## Solution

Use Zig's built-in debugging features like stack traces, assertions, and safe unwrapping:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_12.zig:stack_trace_basics}}
```

## Discussion

Zig provides excellent debugging tools at both compile-time and runtime. Debug builds include stack traces, bounds checking, and assertions that help catch bugs early.

### Panic with Informative Messages

Use `std.debug.panic` to halt execution with context:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_12.zig:panic_with_message}}
```

Panics include stack traces in debug mode, making it easy to trace the call chain.

### Debug Assertions

Add runtime checks that only run in debug mode:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_12.zig:debug_assertions}}
```

Assertions are zero-cost in release builds but catch bugs during development.

### Safe Optional Unwrapping

Prevent null pointer crashes with safe unwrapping:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_12.zig:safe_unwrapping}}
```

Using `if` or `orelse` for optionals is safer than `.?` which panics on null.

### Bounds Checking

Manually check array bounds to prevent crashes:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_12.zig:bounds_checking}}
```

Zig automatically checks bounds in debug/safe modes, but explicit checks provide better error messages.

### Null Pointer Checks

Safely handle potentially null pointers:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_12.zig:null_checks}}
```

The `orelse` pattern converts null pointers into errors instead of crashes.

### Overflow Detection

Detect arithmetic overflow before it causes bugs:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_12.zig:overflow_detection}}
```

`@addWithOverflow` returns a tuple `{result, overflow_flag}` for safe arithmetic.

### Debug Print Inspection

Add debug printing to track program state:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_12.zig:debug_print_inspection}}
```

Debug methods help visualize data structures during execution.

### Error Trace Debugging

Track errors through the call stack:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_12.zig:error_trace}}
```

Error return traces show the path errors take through your program.

### Memory Debugging

Use testing allocator to catch memory leaks:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_12.zig:memory_debugging}}
```

The testing allocator automatically detects memory leaks and double-frees.

### Conditional Debugging

Enable debug output only in debug builds:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_12.zig:conditional_debugging}}
```

Conditional debug code compiles to nothing in release builds.

### Crash Report Pattern

Generate detailed crash reports:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_12.zig:crash_handler}}
```

Structured crash reports include context for easier debugging.

### Debugging with Intermediate Values

Print intermediate steps in complex computations:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_12.zig:debug_symbols}}
```

Step-by-step output helps identify where calculations go wrong.

### Handling Unreachable Code

Use exhaustive switches to eliminate unreachable code:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_12.zig:unreachable_code}}
```

Zig's compiler ensures all cases are handled, preventing unexpected crashes.

### Best Practices

1. **Use debug builds**: Always develop with `-Doptimize=Debug`
2. **Enable safety checks**: Use `-Doptimize=ReleaseSafe` for production
3. **Test with allocators**: Use `testing.allocator` to catch leaks
4. **Add assertions**: Use `std.debug.assert` liberally during development
5. **Safe unwrapping**: Prefer `orelse` and `if` over `.?`
6. **Print strategically**: Add debug output at key decision points
7. **Check return values**: Always handle errors, never ignore them

### Debugging Workflow

**Step 1: Reproduce**
```zig
test "reproduce the crash" {
    // Minimal test case that triggers the crash
    try problematicFunction();
}
```

**Step 2: Add Debug Output**
```zig
fn problematicFunction() !void {
    std.debug.print("Entering function\n", .{});
    const value = try getValue();
    std.debug.print("Got value: {d}\n", .{value});
    // ...
}
```

**Step 3: Identify Root Cause**
```zig
// Add assertions to catch invalid state
std.debug.assert(value >= 0);
std.debug.assert(pointer != null);
```

**Step 4: Fix and Verify**
```zig
test "verify fix" {
    // Ensure the crash no longer occurs
    try problematicFunction();
}
```

### Common Crash Patterns

**Pattern 1: Null Pointer Dereference**
```zig
// Wrong - crashes if null
const value = ptr.?.*;

// Right - safe handling
const value = if (ptr) |p| p.* else return error.NullPointer;
```

**Pattern 2: Out of Bounds Access**
```zig
// Wrong - crashes on invalid index
const item = array[index];

// Right - bounds checked
const item = if (index < array.len) array[index] else return error.OutOfBounds;
```

**Pattern 3: Integer Overflow**
```zig
// Wrong - silent overflow in release mode
const result = a + b;

// Right - explicit overflow checking
const overflow = @addWithOverflow(a, b);
if (overflow[1] != 0) return error.Overflow;
const result = overflow[0];
```

**Pattern 4: Use After Free**
```zig
// Wrong - dangling pointer
allocator.free(buffer);
return buffer[0]; // Crash!

// Right - use before free
const value = buffer[0];
allocator.free(buffer);
return value;
```

### Build Modes and Debugging

**Debug Mode** (`-Doptimize=Debug`):
- Full stack traces
- Runtime bounds checking
- Assertions enabled
- No optimizations
- Best for development

**ReleaseSafe** (`-Doptimize=ReleaseSafe`):
- Optimizations enabled
- Runtime safety checks preserved
- Assertions enabled
- Good for production with safety priority

**ReleaseFast** (`-Doptimize=ReleaseFast`):
- Maximum performance
- No safety checks
- Assertions disabled
- Use only when safety is verified

### Debugging Tools

**Built-in Tools:**
- `std.debug.print` - Console output
- `std.debug.panic` - Immediate halt with stack trace
- `std.debug.assert` - Development-time checks
- `@breakpoint()` - Debugger breakpoint
- Error return traces - Automatic error tracking

**External Tools:**
- `gdb` or `lldb` - Interactive debuggers
- `valgrind` - Memory error detection (Linux)
- Address Sanitizer - Memory safety (via `-fsanitize=address`)

### Stack Trace Analysis

When you get a crash, read the stack trace from bottom to top:

```
thread 12345 panic: index out of bounds
/path/to/project/src/main.zig:42:13: 0x1234 in processArray (main)
    return array[index];
            ^
/path/to/project/src/main.zig:100:5: 0x5678 in main (main)
    processArray(data, 999);
    ^
```

This shows:
1. Root cause: index out of bounds at line 42
2. Called from: main at line 100 with index 999

### Memory Leak Detection

```zig
test "detect memory leaks" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.debug.print("Memory leak detected!\n", .{});
        }
    }

    const allocator = gpa.allocator();
    // Your code here - leaks will be detected
}
```

### Integration with IDEs

Most IDEs support Zig debugging:
- VSCode: Zig Language extension + CodeLLDB
- CLion: Native Zig support
- Neovim/Vim: DAP integration

Set breakpoints and inspect variables interactively.

## See Also

- Recipe 14.11: Issuing warning messages
- Recipe 14.13: Profiling and timing your program
- Recipe 0.13: Testing and Debugging Fundamentals
- Recipe 1.3: Testing Strategy

Full compilable example: `code/04-specialized/14-testing-debugging/recipe_14_12.zig`
