# Recipe 15.2: Writing a Zig Library Callable from C

## Problem

You want to create a library in Zig that can be called from C code, exposing Zig functions through a C-compatible API.

## Solution

Use the `export` keyword to make Zig functions accessible from C. Exported functions follow the C ABI and can be called from any language that supports C linkage.

Here's a basic exported function:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_2.zig:basic_export}}
```

Build as a library:

```bash
zig build-lib recipe_15_2.zig        # Static library
zig build-lib recipe_15_2.zig -dynamic   # Shared library
```

## Discussion

### Exporting Functions

The `export` keyword makes a function part of the library's public API with C linkage. The function follows the C calling convention and can be called from C code.

For better C compatibility, use C types:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_2.zig:export_with_c_types}}
```

### Exporting Struct-Based APIs

Create structs with C-compatible layout using `extern struct`:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_2.zig:export_struct}}
```

The `extern struct` keyword ensures the struct uses C memory layout, making it safe to pass across the C/Zig boundary.

### Array Operations

Export functions that work with array pointers for C compatibility:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_2.zig:export_array_operations}}
```

Use `[*]T` for many-item pointers and pass the length separately, as C does not track array sizes.

### String Operations

Work with C-style NULL-terminated strings using `[*:0]const u8`:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_2.zig:export_string_operations}}
```

The `:0` sentinel in the type indicates a NULL-terminated string.

### Error Handling

Since Zig's error unions don't translate to C, use return codes:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_2.zig:export_error_handling}}
```

Common patterns:
- Return 0 for success, negative values for errors
- Use output parameters for return values
- Document error codes clearly

### Opaque Types for Encapsulation

Hide implementation details using opaque pointers:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_2.zig:export_opaque_type}}
```

This pattern provides:
- Encapsulation of internal state
- Memory safety through controlled allocation/deallocation
- ABI stability (C code doesn't depend on struct layout)

### Callback Functions

Accept function pointers from C code:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_2.zig:export_callback}}
```

The `callconv(.c)` specifies C calling convention for the callback.

### Buffer Modifications

Export functions that modify buffers in place:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_2.zig:export_buffer_operations}}
```

### Exporting Global Variables

Variables can also be exported:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_2.zig:export_variable}}
```

Be cautious with global state in multi-threaded environments.

### Building and Using the Library

To build a static library:

```bash
zig build-lib mylib.zig
```

This creates `libmylib.a` (or `mylib.lib` on Windows).

To build a shared/dynamic library:

```bash
zig build-lib mylib.zig -dynamic
```

This creates `libmylib.so` (Linux), `libmylib.dylib` (macOS), or `mylib.dll` (Windows).

### Using from C

From C code, declare the functions:

```c
// mylib.h
#include <stdint.h>

int32_t add(int32_t a, int32_t b);
int32_t multiply(int32_t a, int32_t b);
```

Then compile and link:

```bash
gcc main.c -L. -lmylib -o main
```

### Important Considerations

1. **C ABI Compatibility**: Use C types (`c_int`, `c_long`, etc.) for guaranteed compatibility
2. **Memory Management**: Document who owns and frees memory
3. **NULL Safety**: Always check for NULL pointers from C code
4. **Thread Safety**: Make exported functions thread-safe if they'll be called from multiple threads
5. **Error Handling**: Use return codes, not Zig error unions
6. **Struct Layout**: Use `extern struct` for C-compatible layout
7. **String Handling**: Use sentinel-terminated pointers `[*:0]u8` for C strings

### Header Generation

Zig can generate C headers automatically. In your build.zig:

```zig
const lib = b.addLibrary(.{
    .name = "mylib",
    .root_source_file = b.path("mylib.zig"),
});
lib.emit_h = true;  // Generate header file
```

## See Also

- Recipe 15.1: Accessing C Code from Zig
- Recipe 15.3: Passing Arrays Between C and Zig
- Recipe 15.6: Calling Zig Functions from C
- Recipe 15.7: Managing Memory Across the C/Zig Boundary

Full compilable example: `code/04-specialized/15-c-interoperability/recipe_15_2.zig`
