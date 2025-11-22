# Recipe 15.7: Calling C Functions with Variadic Arguments

## Problem

You need to call C functions that accept a variable number of arguments (`printf`, `sprintf`, etc.) or create your own variadic functions for C interop.

## Solution

When calling C variadic functions, explicitly cast all literals to fixed-size types. For defining variadic functions, use `@cVaStart`, `@cVaArg`, and `@cVaEnd`.

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_7.zig:calling_printf}}
```

## Discussion

### Calling C Variadic Functions

C's most common variadic function is `printf`:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_7.zig:calling_sprintf}}
```

Key requirement: **All integer and float literals must be explicitly cast** to fixed-size types (`c_int`, `f64`, etc.) when passed to variadic functions.

### Defining Variadic Functions

Create your own variadic functions using special builtins:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_7.zig:defining_variadic}}
```

Builtins for variadic functions:
- `@cVaStart()` - Initialize argument list
- `@cVaArg(&ap, Type)` - Get next argument of Type
- `@cVaEnd(&ap)` - Clean up argument list

### Variadic Wrappers

Wrap C variadic functions with type-safe Zig interfaces:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_7.zig:variadic_wrapper}}
```

### Type-Safe Alternatives

Instead of variadic functions, use explicit parameter lists when possible:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_7.zig:type_checking}}
```

This approach:
- Provides type safety at compile time
- Eliminates runtime type confusion
- Is easier to debug and maintain

### Forwarding Variadic Arguments

Note that forwarding `va_list` between functions is limited in Zig:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_7.zig:forwarding_varargs}}
```

### Mixed Type Arguments

Handle different types in a variadic function:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_7.zig:mixed_types}}
```

This pattern uses type tags to identify argument types at runtime.

### Safer Alternatives

Use Zig's compile-time features instead of runtime variadic functions:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_7.zig:safer_alternative}}
```

Benefits:
- Compile-time type checking
- No casting required
- Better error messages
- More idiomatic Zig

### Examining Arguments

Process variadic arguments in a loop:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_7.zig:examining_varargs}}
```

### Best Practices

1. **Cast Literals**: Always cast integer/float literals to fixed-size types
2. **Prefer Tuples**: Use tuples (`anytype`) over variadic functions in Zig
3. **Type Tags**: Use type indicators when mixing types
4. **Limit Scope**: Keep variadic functions at the C boundary
5. **Document Types**: Clearly document expected argument types
6. **Error Handling**: Validate argument counts and types when possible
7. **Platform Testing**: Test on multiple platforms (varargs are platform-specific)

### Platform Limitations

Some platforms have limitations with variadic functions:
- **ARM64 (non-macOS)**: May skip tests due to ABI issues
- **Windows x86_64**: May skip tests due to calling convention differences

Always test variadic code on target platforms.

### Common Pitfalls

**Wrong: Missing casts**
```zig
printf("%d", 42);  // Error: must cast literal
```

**Right: Explicit casts**
```zig
printf("%d", @as(c_int, 42));  // Correct
```

**Wrong: Forgetting @cVaEnd**
```zig
fn bad(...) callconv(.c) void {
    var ap = @cVaStart();
    // Missing @cVaEnd(&ap)
}
```

**Right: Always cleanup**
```zig
fn good(...) callconv(.c) void {
    var ap = @cVaStart();
    defer @cVaEnd(&ap);  // Ensures cleanup
}
```

## See Also

- Recipe 15.1: Accessing C Code from Zig
- Recipe 15.6: Passing NULL-terminated Strings to C Functions

Full compilable example: `code/04-specialized/15-c-interoperability/recipe_15_7.zig`
