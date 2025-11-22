# Recipe 15.1: Accessing C Code from Zig

## Problem

You need to call C library functions from your Zig code, such as using standard C library functions like `printf`, `sqrt`, or `strlen`.

## Solution

Zig provides `@cImport` to import C headers directly. This builtin function translates C declarations into Zig code at compile time, allowing you to call C functions naturally.

Here's how to import C headers:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_1.zig:basic_cimport}}
```

Once imported, you can call C functions directly:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_1.zig:calling_printf}}
```

## Discussion

### Basic C Import

The `@cImport` function takes a compile-time expression that can include multiple `@cInclude` directives. Each directive imports a C header file, making its functions, types, and constants available to your Zig code.

When you compile code that uses `@cImport`, you need to link with the C library using the `-lc` flag:

```bash
zig test recipe_15_1.zig -lc
```

### Using C Math Functions

C standard library functions work seamlessly:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_1.zig:calling_math}}
```

### C Type Primitives

Zig provides C-compatible types that guarantee the correct ABI:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_1.zig:c_types}}
```

Available C types include:
- `c_char`, `c_short`, `c_int`, `c_long`, `c_longlong`
- `c_ushort`, `c_uint`, `c_ulong`, `c_ulonglong`
- `c_longdouble`

For C's `void*`, use `?*anyopaque` in Zig.

### Working with C Strings

C functions that take strings work with Zig's string pointers:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_1.zig:strlen_example}}
```

### Using Preprocessor Defines

You can set C preprocessor macros using `@cDefine`:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_1.zig:cdefine_example}}
```

### Conditional Imports

Import different headers based on compile-time conditions:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_1.zig:conditional_import}}
```

This is useful for cross-platform code where different operating systems require different headers.

### Accessing C Constants

C preprocessor constants and definitions are available:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_1.zig:c_constants}}
```

### Working with C Buffers

You can pass Zig buffers to C functions that write data:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_1.zig:allocator_with_c}}
```

Note that variadic C functions require explicit type casts for literals.

### Multiple Related Headers

Import multiple headers in a single `@cImport` block:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_1.zig:multiple_headers}}
```

### Error Handling

C functions often use return codes or NULL pointers to indicate errors. Handle these explicitly in Zig:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_1.zig:error_handling}}
```

### Void Pointers

C's `void*` maps to `?*anyopaque` in Zig:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_1.zig:c_void_pointer}}
```

### Important Considerations

1. **Linking**: Always use `-lc` when compiling code that uses C library functions
2. **Type Safety**: Use C type primitives (`c_int`, `c_long`, etc.) for ABI compatibility
3. **Variadic Functions**: Cast integer and float literals explicitly when calling variadic C functions
4. **Null Safety**: C pointers are nullable; handle NULL cases explicitly
5. **Translation Caching**: Zig caches C translations for faster subsequent builds

### Alternative: zig translate-c

For more control, you can use the `zig translate-c` CLI tool to generate Zig bindings from C headers, then edit the generated code manually.

## See Also

- Recipe 15.2: Writing a Zig Library Callable from C
- Recipe 15.5: Wrapping Existing C Libraries
- Recipe 15.8: Passing NULL-terminated Strings to C Functions
- Recipe 15.10: Calling C Functions with Variadic Arguments

Full compilable example: `code/04-specialized/15-c-interoperability/recipe_15_1.zig`
