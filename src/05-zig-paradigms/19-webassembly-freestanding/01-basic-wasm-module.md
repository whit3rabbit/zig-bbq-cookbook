# Recipe 19.1: Building a Basic WebAssembly Module

## Problem

You want to compile Zig code to WebAssembly and call it from JavaScript in a web browser or other WASM runtime.

## Solution

Create a Zig file with exported functions and compile it to the `wasm32-freestanding` target. The `export` keyword makes functions visible to JavaScript.

First, implement a custom panic handler, which is required for freestanding targets:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_1.zig:panic_handler}}
```

Export simple functions that JavaScript can call:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_1.zig:basic_export}}
```

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_1.zig:multiply_export}}
```

More complex exported functions work the same way:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_1.zig:fibonacci_export}}
```

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_1.zig:is_prime_export}}
```

Build the WebAssembly module:

```bash
zig build-lib -O ReleaseSmall -target wasm32-freestanding -dynamic -rdynamic recipe_19_1.zig
```

This produces `recipe_19_1.wasm`, which you can load in JavaScript:

```javascript
async function loadWasm() {
    const response = await fetch('recipe_19_1.wasm');
    const bytes = await response.arrayBuffer();
    const { instance } = await WebAssembly.instantiate(bytes);
    const wasm = instance.exports;

    // Call exported functions
    console.log(wasm.add(5, 3));           // 8
    console.log(wasm.multiply(7, 6));       // 42
    console.log(wasm.fibonacci(10));        // 55
    console.log(wasm.isPrime(17));          // true
}
```

## Discussion

### The `export` Keyword

The `export` keyword makes functions visible in the compiled WebAssembly module. Without it, functions remain internal to the WASM binary and cannot be called from JavaScript.

The difference between `pub` and `export`:
- `pub` makes functions visible to other Zig modules at compile time
- `export` makes functions visible in the compiled binary's symbol table
- For WASM, you need `export` to call functions from JavaScript

### Freestanding Target Requirements

The `wasm32-freestanding` target runs without an operating system. This means:

1. **Custom panic handler required**: The standard library's panic implementation relies on OS features not available in freestanding environments. Your panic handler must be marked `noreturn` and handle all errors.

2. **No standard I/O**: You cannot use `std.debug.print` or `std.io` functions that rely on file descriptors.

3. **No filesystem**: File operations are not available unless provided by the WASM runtime.

4. **Explicit memory management**: No system allocator exists by default (covered in Recipe 19.5).

### Build Flags Explained

```bash
zig build-lib -O ReleaseSmall -target wasm32-freestanding -dynamic -rdynamic recipe_19_1.zig
```

- `-O ReleaseSmall`: Optimizes for small binary size, critical for web distribution
- `-target wasm32-freestanding`: Targets WebAssembly without OS support
- `-dynamic`: Builds a dynamic library (WASM module)
- `-rdynamic`: Ensures exported symbols remain visible in the binary

The `-rdynamic` flag is essential. Without it, the linker may strip exported symbols, making them unavailable to JavaScript.

### Type Considerations

WASM natively supports these types:
- `i32`, `i64`: Signed integers
- `f32`, `f64`: Floating-point numbers

Zig automatically maps compatible types:
- `bool` becomes `i32` (0 or 1)
- Smaller integers promote to `i32`
- Pointers become `i32` (memory addresses)

For complex types like strings or structs, you'll need to pass them through linear memory (see Recipe 19.4).

### Testing WASM Functions

The tests in the Zig file verify logic but run on your host system, not in WASM. They use standard Zig test infrastructure:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_1.zig:test_add}}
```

Run tests with:

```bash
zig test recipe_19_1.zig
```

These tests ensure the logic is correct before compiling to WASM, where debugging is more difficult.

### Using the Module in a Browser

See `code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_1.html` for a complete working example. The key steps:

1. Fetch the WASM file
2. Instantiate it with `WebAssembly.instantiate()`
3. Access exported functions via `instance.exports`
4. Call functions normally

### Debugging and Inspecting WASM

Use browser developer tools to inspect WASM:
1. Open DevTools → Sources tab
2. Find the .wasm file in the file tree
3. View disassembled WebAssembly code

Use `wasm-objdump` to inspect the binary:

```bash
wasm-objdump -x recipe_19_1.wasm
```

## See Also

- Recipe 19.2: Exporting functions to JavaScript (advanced exports)
- Recipe 19.3: Importing and calling JavaScript functions
- Recipe 19.5: Custom allocators for freestanding targets
- Recipe 19.6: Implementing a panic handler for WASM

Full compilable example: `code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_1.zig`
