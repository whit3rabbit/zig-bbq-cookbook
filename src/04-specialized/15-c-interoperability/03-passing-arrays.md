# Recipe 15.3: Passing Arrays Between C and Zig

## Problem

You need to pass arrays between C and Zig code, handling the differences in how each language represents arrays and pointers.

## Solution

Use many-item pointers (`[*]T`) combined with a length parameter to pass arrays between C and Zig. This matches C's convention of passing arrays as pointers with separate length tracking.

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_3.zig:many_item_pointer}}
```

## Discussion

### Understanding Pointer Types

Zig has several pointer types for C interop:

- `[*]T` - Many-item pointer (preferred for C arrays)
- `[*c]T` - C pointer (auto-generated from `@cImport`, allows NULL)
- `*T` - Single-item pointer
- `[*:0]T` - Sentinel-terminated pointer (for C strings)

### Modifying C Arrays

Zig functions can modify C arrays in place:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_3.zig:modifying_array}}
```

### Returning Arrays to C

Use output parameters to return array data to C callers:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_3.zig:returning_array}}
```

This pattern is safer than returning a pointer, as the caller manages the memory.

### Working with C Pointers

When working with auto-generated bindings, you'll encounter `[*c]T` pointers:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_3.zig:c_pointer_conversion}}
```

C pointers support NULL checking and coerce to other pointer types.

### Multidimensional Arrays

Handle 2D arrays as arrays of pointers:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_3.zig:multidimensional_arrays}}
```

This matches C's convention where a 2D array is an array of row pointers.

### Arrays of Structs

Pass arrays of C-compatible structs using `extern struct`:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_3.zig:struct_array}}
```

### Converting Slices to C Arrays

Zig slices have `.ptr` and `.len` fields that map naturally to C conventions:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_3.zig:slice_to_c_array}}
```

### Dynamic Array Allocation

Allocate arrays that C code will use:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_3.zig:dynamic_array_allocation}}
```

Key points:
- Use `std.heap.c_allocator` for C-compatible allocation
- Return the pointer (`arr.ptr`) to C
- Provide a `free` function for C to deallocate
- Always check for allocation failures

### Byte Array Operations

Byte arrays (`[*]u8`) are common for buffers and binary data:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_3.zig:byte_array_operations}}
```

### Safe Array Access

Add bounds checking for safer C APIs:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_3.zig:array_bounds_safety}}
```

Return a boolean to indicate success/failure instead of potentially accessing invalid memory.

### Best Practices

1. **Always pass length**: C doesn't track array sizes, so pass the length explicitly
2. **Use many-item pointers**: Prefer `[*]T` over `[*c]T` when you control the interface
3. **Document ownership**: Clearly specify who allocates and frees memory
4. **Check for NULL**: Always validate pointers from C before dereferencing
5. **Bounds checking**: Add safety checks when accessing array elements
6. **Use const**: Mark arrays as `const` when they shouldn't be modified
7. **extern struct**: Use `extern struct` for C-compatible struct layout
8. **Sentinel pointers**: Use `[*:0]T` for NULL-terminated arrays (especially strings)

### Common Patterns

**Reading from C array:**
```zig
export fn process(arr: [*]const c_int, len: usize) c_int {
    for (0..len) |i| {
        // Process arr[i]
    }
}
```

**Modifying C array:**
```zig
export fn transform(arr: [*]c_int, len: usize) void {
    for (0..len) |i| {
        arr[i] = /* transformation */;
    }
}
```

**Output parameter:**
```zig
export fn fill_array(out: [*]c_int, len: usize, value: c_int) void {
    for (0..len) |i| {
        out[i] = value;
    }
}
```

### Memory Safety

When allocating arrays for C:
- Use `std.heap.c_allocator` (compatible with C's `malloc/free`)
- Provide a corresponding `free` function
- Return NULL on allocation failure
- Document ownership clearly

When accepting arrays from C:
- Validate pointers are not NULL
- Trust but verify the length parameter
- Don't assume array lifetime extends beyond the call
- Consider copying data if you need to retain it

## See Also

- Recipe 15.1: Accessing C Code from Zig
- Recipe 15.2: Writing a Zig Library Callable from C
- Recipe 15.7: Managing Memory Across the C/Zig Boundary
- Recipe 15.8: Passing NULL-terminated Strings to C Functions

Full compilable example: `code/04-specialized/15-c-interoperability/recipe_15_3.zig`
