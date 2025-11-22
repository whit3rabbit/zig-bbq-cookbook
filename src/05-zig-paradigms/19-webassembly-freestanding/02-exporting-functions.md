# Recipe 19.2: Exporting Functions to JavaScript

## Problem

You need to export complex functions from Zig to WebAssembly, including functions that return multiple values, work with pointers, or maintain state across calls.

## Solution

### Maintaining State with Global Variables

Export getter and setter functions to manage state:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_2.zig:global_state}}
```

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_2.zig:counter_functions}}
```

### Returning Multiple Values via Pointers

Use pointer parameters to return additional values:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_2.zig:divide_with_remainder}}
```

From JavaScript:

```javascript
// Allocate memory for the remainder
const remainderPtr = wasm.__heap_base || 0;
const quotient = wasm.divideWithRemainder(17, 5, remainderPtr);

// Read remainder from WASM linear memory
const memView = new Int32Array(wasm.memory.buffer);
const remainder = memView[remainderPtr / 4];

console.log(`17 ÷ 5 = ${quotient} remainder ${remainder}`);
// Output: 17 ÷ 5 = 3 remainder 2
```

### Storing Calculation Results

Combine computation with state storage:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_2.zig:distance_calculation}}
```

### Working with Structured Data

Define structures and export functions that work with pointers:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_2.zig:point_struct}}
```

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_2.zig:point_operations}}
```

### Boolean Returns

WASM doesn't have a native boolean type, but Zig automatically converts them:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_2.zig:range_check}}
```

In JavaScript, this returns `0` (false) or `1` (true), but JavaScript automatically treats them as boolean values in conditional contexts.

## Discussion

### Global State in WASM

Global variables in Zig become mutable locations in WASM linear memory. This allows you to:

- Maintain state across function calls
- Implement stateful APIs
- Cache computation results

However, be aware:
- All WASM instances share the same globals
- No thread safety guarantees (single-threaded by default)
- State persists for the lifetime of the WASM instance

### Pointer Parameters for Multiple Returns

WASM functions can only return a single value (or multiple values with the multi-value proposal, which isn't universally supported). To return multiple values:

1. **Pass pointer parameters**: The caller allocates memory, you write results to it
2. **Use structs**: Return a struct by pointer (see point operations example)
3. **Use global state**: Store additional results in globals (less clean)

The pointer approach works like this:

```javascript
// Allocate space in WASM memory (simplified)
const ptr = wasm.__heap_base || 0;

// Call function that writes to that address
const result1 = wasm.functionWithMultipleReturns(arg1, arg2, ptr);

// Read additional return value from memory
const view = new Int32Array(wasm.memory.buffer);
const result2 = view[ptr / 4];  // Divide by 4 for i32 indexing
```

### Memory Layout and Addressing

WASM uses a flat linear memory model:
- Memory is a contiguous array of bytes
- Pointers are `i32` addresses into this array
- Structures layout matches C ABI by default
- `__heap_base` marks where dynamic allocation could start

For the `Point` struct:

```zig
const Point = struct {
    x: f64,  // 8 bytes
    y: f64,  // 8 bytes
};  // Total: 16 bytes
```

If a `Point` is at address `0x100`:
- `x` is at `0x100` (bytes 0-7)
- `y` is at `0x108` (bytes 8-15)

### Static Buffers vs Allocators

The `createPoint` example uses a static buffer:

```zig
const static = struct {
    var points_buffer: [100]Point = undefined;
    var next_index: usize = 0;
};
```

This is simple but limited:
- Fixed capacity (100 points)
- No deallocation
- Reuses slots when full (circular buffer behavior)

For production code, use a proper allocator (see Recipe 19.5).

### Type Conversions

JavaScript to WASM conversions:

| JavaScript | Zig Type | WASM Type | Notes |
|------------|----------|-----------|-------|
| `number` (integer) | `i32`, `i64` | `i32`, `i64` | Truncated to integer |
| `number` (float) | `f32`, `f64` | `f32`, `f64` | Direct conversion |
| `boolean` | `bool` | `i32` | `false=0`, `true=1` |
| Pointer value | `*T` | `i32` | Memory address |

When returning from WASM to JavaScript:
- `i32` → JavaScript `number` (integer)
- `f64` → JavaScript `number` (float)
- `bool` → JavaScript `number` (`0` or `1`, but truthy/falsy)

### Accessing WASM Memory from JavaScript

Three ways to read WASM memory:

**1. Typed Arrays (for primitives):**
```javascript
const i32View = new Int32Array(wasm.memory.buffer);
const f64View = new Float64Array(wasm.memory.buffer);
```

**2. DataView (for mixed types):**
```javascript
const view = new DataView(wasm.memory.buffer);
const x = view.getFloat64(ptr + 0, true);  // Little-endian
const y = view.getFloat64(ptr + 8, true);
```

**3. Manual byte manipulation:**
```javascript
const u8View = new Uint8Array(wasm.memory.buffer);
```

### Calling Conventions

When JavaScript calls an exported function:
1. JavaScript values are converted to WASM types
2. Function executes in WASM
3. Return value is converted back to JavaScript
4. Any pointer writes update the shared linear memory

## See Also

- Recipe 19.1: Building a basic WebAssembly module
- Recipe 19.3: Importing and calling JavaScript functions
- Recipe 19.4: Passing strings and data between Zig and JavaScript
- Recipe 19.5: Custom allocators for freestanding targets

Full compilable example: `code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_2.zig`
