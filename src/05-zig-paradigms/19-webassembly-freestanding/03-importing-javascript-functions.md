# Recipe 19.3: Importing and Calling JavaScript Functions

## Problem

You need to call JavaScript functions from Zig code running in WebAssembly, such as logging to the console, generating random numbers, or using browser APIs.

## Solution

Use `extern "env"` to declare JavaScript functions that will be provided when instantiating the WASM module.

### Declaring External Functions

Declare JavaScript functions with matching signatures:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_3.zig:console_log_import}}
```

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_3.zig:math_imports}}
```

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_3.zig:callback_imports}}
```

### Using Imported Functions

Call them like regular Zig functions:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_3.zig:using_console_log}}
```

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_3.zig:using_math}}
```

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_3.zig:using_random}}
```

### Providing Implementations from JavaScript

When loading the WASM module, supply the import object:

```javascript
const importObject = {
    env: {
        consoleLog: (value) => {
            console.log(`[WASM] ${value}`);
        },
        consoleLogInt: (value) => {
            console.log(`[WASM] ${value}`);
        },
        consoleLogStr: (ptr, len) => {
            const bytes = new Uint8Array(wasm.memory.buffer, ptr, len);
            const str = new TextDecoder().decode(bytes);
            console.log(`[WASM] "${str}"`);
        },
        jsRandom: () => Math.random(),
        jsDateNow: () => Date.now(),
        jsMathPow: (base, exp) => Math.pow(base, exp),
        jsMathSin: (x) => Math.sin(x),
        jsMathCos: (x) => Math.cos(x),
        jsCallback: (value) => {
            console.log(`Callback received: ${value}`);
        },
        jsProcessData: (data) => data * 3 + 7
    }
};

const { instance } = await WebAssembly.instantiate(bytes, importObject);
```

## Discussion

### The `extern` Keyword

The `extern` keyword declares a function implemented externally. The string `"env"` specifies the namespace where JavaScript will provide these functions.

```zig
extern "env" fn functionName(args: Type) ReturnType;
```

This creates an import entry in the WASM binary. When JavaScript instantiates the module, it must provide matching implementations in the import object.

### Import Namespaces

While `"env"` is conventional, you can use any namespace:

```zig
extern "custom" fn myFunction() void;
```

Then provide it in JavaScript:

```javascript
const importObject = {
    custom: {
        myFunction: () => { /* implementation */ }
    }
};
```

The `"env"` namespace is standard and expected by most WASM tooling and runtimes.

### Type Conversions

WASM only supports `i32`, `i64`, `f32`, and `f64`. Zig handles conversions automatically:

| Zig Type | WASM Type | Notes |
|----------|-----------|-------|
| `i32`, `u32` | `i32` | Direct mapping |
| `i64`, `u64` | `i64` | Direct mapping |
| `f32` | `f32` | Direct mapping |
| `f64` | `f64` | Direct mapping |
| `bool` | `i32` | `false=0`, `true=1` |
| `*T`, `[*]T` | `i32` | Memory address |
| `usize`, `isize` | `i32` | On wasm32 |

### Passing Strings

Strings require passing a pointer and length:

```zig
extern "env" fn consoleLogStr(ptr: [*]const u8, len: usize) void;
```

JavaScript reads from linear memory:

```javascript
consoleLogStr: (ptr, len) => {
    const bytes = new Uint8Array(wasm.memory.buffer, ptr, len);
    const str = new TextDecoder().decode(bytes);
    console.log(str);
}
```

The pointer (`i32`) is an offset into `wasm.memory.buffer`. The Uint8Array view provides access to the string bytes.

### Random Numbers

WebAssembly has no source of entropy. For random numbers, import JavaScript's `Math.random()`:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_3.zig:using_random}}
```

This pattern works for any browser API or JavaScript function you need.

### Timestamps and Timing

Get current time from JavaScript:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_3.zig:using_timestamp}}
```

Useful for benchmarking and profiling:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_3.zig:benchmark_example}}
```

### Callbacks and Event Handling

Use callbacks to send data back to JavaScript:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_3.zig:using_callbacks}}
```

This pattern enables:
- Event notifications
- Progress updates
- Streaming results
- Bidirectional communication

### Testing with Stubs

Since external functions aren't available during `zig test`, provide stubs:

```zig
const builtin = @import("builtin");

comptime {
    if (builtin.is_test) {
        @export(&stub_jsRandom, .{ .name = "jsRandom" });
    }
}

fn stub_jsRandom() callconv(.c) f64 {
    return 0.5; // Deterministic for testing
}
```

This allows testing the Zig logic without JavaScript dependencies.

### Error Handling

External functions can't return Zig errors. Use sentinel values or callbacks:

```zig
extern "env" fn jsOperation(input: i32) i32;

export fn safeOperation(input: i32) ?i32 {
    const result = jsOperation(input);
    if (result < 0) return null; // -1 indicates error
    return result;
}
```

Or use a callback pattern:

```zig
extern "env" fn reportError(code: i32) void;

export fn operation(input: i32) i32 {
    if (input < 0) {
        reportError(1); // Send error code to JavaScript
        return 0;
    }
    return input * 2;
}
```

### Performance Considerations

Each call across the WASM/JavaScript boundary has overhead. For performance-critical code:

1. **Batch operations**: Process arrays in Zig, minimize crossings
2. **Cache results**: Store JavaScript values in Zig memory
3. **Minimize callbacks**: Reduce back-and-forth communication

Example of batching:

```zig
// Bad: One call per element
export fn processItems(items: [*]i32, len: usize) void {
    for (0..len) |i| {
        items[i] = jsProcessOne(items[i]); // Many boundary crossings
    }
}

// Good: Process in Zig, call once
export fn processItemsBatch(items: [*]i32, len: usize) void {
    // Do Zig processing
    for (0..len) |i| {
        items[i] = items[i] * 2 + 10;
    }
    // Single callback when done
    jsNotifyComplete();
}
```

### Common Patterns

**Console logging:**
```zig
extern "env" fn jsLog(ptr: [*]const u8, len: usize) void;
```

**DOM manipulation:**
```zig
extern "env" fn jsSetElementText(id_ptr: [*]const u8, id_len: usize,
                                  text_ptr: [*]const u8, text_len: usize) void;
```

**Fetch/XHR:**
```zig
extern "env" fn jsFetchUrl(url_ptr: [*]const u8, url_len: usize,
                            callback_id: i32) void;
```

**Local storage:**
```zig
extern "env" fn jsLocalStorageSet(key_ptr: [*]const u8, key_len: usize,
                                   value_ptr: [*]const u8, value_len: usize) void;
```

## See Also

- Recipe 19.1: Building a basic WebAssembly module
- Recipe 19.2: Exporting functions to JavaScript
- Recipe 19.4: Passing strings and data between Zig and JavaScript
- Recipe 19.5: Custom allocators for freestanding targets

Full compilable example: `code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_3.zig`
