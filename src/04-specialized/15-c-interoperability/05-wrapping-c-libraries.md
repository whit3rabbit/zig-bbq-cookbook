# Recipe 15.5: Wrapping Existing C Libraries

## Problem

You want to create idiomatic Zig wrappers around existing C library functions to provide better type safety, error handling, and a more Zig-friendly API.

## Solution

Import C headers with `@cImport` and create wrapper functions that translate between C and Zig conventions.

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_5.zig:c_library_import}}
```

## Discussion

### Basic Memory Function Wrappers

Wrap C's `malloc`/`free` with Zig-friendly types:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_5.zig:basic_wrapper}}
```

### Error Handling Wrappers

Convert C error conventions to Zig error unions:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_5.zig:error_handling_wrapper}}
```

This wrapper:
- Returns Zig error types instead of relying on C conventions
- Validates input before calling C functions
- Checks results for error conditions (NaN, infinity)

### String Function Wrappers

Wrap C string functions with Zig slices:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_5.zig:string_wrapper}}
```

### RAII-Style Resource Wrappers

Create structs that manage C resources automatically:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_5.zig:resource_wrapper}}
```

This pattern:
- Wraps C file handle in a Zig struct
- Provides idiomatic methods
- Uses `defer` for cleanup
- Returns errors instead of error codes

### Type-Safe Allocator Wrappers

Add compile-time type safety to C allocations:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_5.zig:type_safe_wrapper}}
```

### Callback Wrappers

Wrap C functions that accept callbacks:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_5.zig:callback_wrapper}}
```

### Const-Correct Wrappers

Enforce const correctness in wrapped functions:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_5.zig:const_wrapper}}
```

### Best Practices

1. **Error Handling**: Convert C error codes to Zig error types
2. **Memory Safety**: Add NULL checks and bounds validation
3. **Type Safety**: Use specific Zig types instead of raw pointers
4. **Resource Management**: Use RAII patterns with structs and `defer`
5. **Const Correctness**: Mark read-only parameters as `const`
6. **Documentation**: Document ownership and lifetime expectations
7. **Testing**: Write comprehensive tests for wrapped functions

## See Also

- Recipe 15.1: Accessing C Code from Zig
- Recipe 15.2: Writing a Zig Library Callable from C
- Recipe 15.7: Managing Memory Across the C/Zig Boundary

Full compilable example: `code/04-specialized/15-c-interoperability/recipe_15_5.zig`
