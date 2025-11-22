# Recipe 19.6: Implementing a Panic Handler for WASM

## Problem

Freestanding WebAssembly targets require a custom panic handler. Without one, your code won't compile. You need to handle panics appropriately for web environments.

## Solution

Implement a `panic` function that reports errors to JavaScript and prevents undefined behavior.

### Simple Panic Handler

Minimal implementation that halts execution:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_6.zig:simple_panic_handler}}
```

### Logging Panic Handler

Report panics to JavaScript for debugging:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_6.zig:extern_panic_callback}}
```

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_6.zig:logging_panic_handler}}
```

### Enhanced Panic with Context

Include additional debugging information:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_6.zig:panic_with_context}}
```

### Retrieving Panic Information

Export functions for JavaScript to access panic details:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_6.zig:get_panic_info}}
```

### JavaScript Integration

Provide panic handlers when loading WASM:

```javascript
const importObject = {
    env: {
        jsPanic: (msgPtr, msgLen) => {
            const bytes = new Uint8Array(wasm.memory.buffer, msgPtr, msgLen);
            const message = new TextDecoder().decode(bytes);
            console.error(`WASM PANIC: ${message}`);
            alert(`Fatal error: ${message}`);
        },
        jsLogPanic: (msgPtr, msgLen) => {
            const bytes = new Uint8Array(wasm.memory.buffer, msgPtr, msgLen);
            const message = new TextDecoder().decode(bytes);
            console.error(message);
        }
    }
};

const { instance } = await WebAssembly.instantiate(bytes, importObject);
```

## Discussion

### Why Panic Handlers Are Required

Freestanding targets have no operating system to handle crashes. The standard library's default panic handler uses OS features (stderr, stack traces) that don't exist in WASM.

You must provide your own handler or compilation fails:

```
error: 'panic' is not marked as a 'pub fn' in the root source file
```

### Panic Handler Signature

The exact signature required:

```zig
pub fn panic(
    msg: []const u8,
    error_return_trace: ?*std.builtin.StackTrace,
    ret_addr: ?usize
) noreturn
```

Must be:
- `pub` - Visible to the compiler
- Named `panic` - Compiler looks for this exact name
- `noreturn` - Function never returns
- In root source file - Usually your main `.zig` file

### The Infinite Loop

Panic handlers must never return (`noreturn`). The infinite loop is standard:

```zig
while (true) {}
```

This prevents undefined behavior. In WASM:
- Execution halts at the loop
- JavaScript can detect the hang (timeout)
- Memory state is preserved for debugging

Alternative: Use `@trap()` (Zig builtin):

```zig
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = msg;
    _ = error_return_trace;
    _ = ret_addr;
    @trap(); // Explicitly trap
}
```

### Common Panic Triggers

Functions that can panic:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_6.zig:panic_triggering_functions}}
```

Each triggers a panic for safety:
- Integer division by zero
- Array index out of bounds
- Failed assertion
- Null pointer unwrap

### Reporting to JavaScript

Three strategies for reporting panics:

**1. Immediate callback:**
```zig
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    jsPanic(msg.ptr, msg.len); // Call immediately
    while (true) {}
}
```

**2. Store message for later:**
```zig
var panic_buffer: [256]u8 = undefined;
var panic_len: usize = 0;

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    const len = @min(msg.len, panic_buffer.len);
    @memcpy(panic_buffer[0..len], msg[0..len]);
    panic_len = len;
    while (true) {}
}

export fn getPanicMessage() [*]const u8 {
    return &panic_buffer;
}
```

**3. Hybrid approach (used in enhanced handler):**
- Call JavaScript immediately
- Store message in buffer
- Provide exports for access

### Stack Traces

The `error_return_trace` parameter contains stack information:

```zig
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    if (error_return_trace) |trace| {
        // Stack trace available (error returns)
        // Access via trace.instruction_addresses
    }

    if (ret_addr) |addr| {
        // Return address available
        // Use for debugging: address of panic call
    }

    // ...
}
```

Note: Stack traces are limited in WASM without debug info. Return addresses help locate panic sites.

### Cleanup Before Panic

Attempt cleanup before hanging:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_6.zig:panic_with_cleanup}}
```

Use cases:
- Flush pending writes
- Release critical resources
- Log final state
- Signal JavaScript

### Panic vs Error Returns

Prefer error returns for recoverable failures:

```zig
// Bad: Panic for expected errors
export fn processData(ptr: [*]const u8, len: usize) void {
    if (len == 0) @panic("Empty data"); // Don't do this!
}

// Good: Return error code
export fn processData(ptr: [*]const u8, len: usize) i32 {
    if (len == 0) return -1; // Error code
    // ... process ...
    return 0; // Success
}
```

Reserve panics for:
- Programming errors (assertions)
- Impossible states
- Unrecoverable conditions

### Development vs Production Handlers

Use different handlers for dev/prod:

```zig
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    if (builtin.mode == .Debug) {
        // Verbose logging for development
        jsLogPanic(msg.ptr, msg.len);
        if (ret_addr) |addr| {
            const addr_msg = std.fmt.comptimePrint("Address: 0x{x}", .{addr});
            jsLogPanic(addr_msg.ptr, addr_msg.len);
        }
    } else {
        // Minimal reporting for production
        jsPanic("Fatal error".ptr, 11);
    }

    while (true) {}
}
```

### Testing Panic Handlers

Cannot directly test panics (they halt execution), but test the logic:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_6.zig:test_panic_info}}
```

Test panic-triggering conditions without actually panicking:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_6.zig:test_bounds_check}}
```

### Debugging Panics

When a panic occurs in production:

1. **Check browser console** - Your `jsPanic` logs should appear
2. **Inspect WASM state** - Use browser DevTools WASM debugging
3. **Read panic message** - Via exported getter functions
4. **Check return address** - Correlate with source maps

Example JavaScript debugging:

```javascript
try {
    wasm.someFunction();
} catch (e) {
    // WASM execution might throw on infinite loop timeout
    console.error('WASM panic detected');

    // Retrieve stored panic message
    const msgPtr = wasm.getLastPanicMessage();
    const msgLen = wasm.getLastPanicLength();
    const bytes = new Uint8Array(wasm.memory.buffer, msgPtr, msgLen);
    const message = new TextDecoder().decode(bytes);

    console.error(`Panic message: ${message}`);
}
```

### Panic and Memory Leaks

Panics don't run destructors or free memory. In WASM:
- Memory is frozen at panic
- Page reload clears all state
- No OS-level cleanup needed

For critical cleanup, use `defer` and `errdefer` before operations that might panic.

## See Also

- Recipe 19.1: Building a basic WebAssembly module
- Recipe 19.3: Importing and calling JavaScript functions
- Recipe 0.11: Optionals, Errors, and Resource Cleanup
- Recipe 14.8: Creating custom exception types

Full compilable example: `code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_6.zig`
