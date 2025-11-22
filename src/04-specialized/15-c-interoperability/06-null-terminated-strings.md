# Recipe 15.6: Passing NULL-terminated Strings to C Functions

## Problem

You need to work with C strings (NULL-terminated character arrays) from Zig code, handling conversions between Zig slices and C string conventions.

## Solution

Use Zig's sentinel-terminated pointer type `[*:0]const u8` for C strings:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_6.zig:sentinel_pointer}}
```

## Discussion

### Sentinel-Terminated Pointers

The `:0` in `[*:0]const u8` indicates a NULL-terminated pointer, matching C's string convention.

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_6.zig:zig_to_c_string}}
```

### Allocating C Strings

Create NULL-terminated strings dynamically:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_6.zig:allocate_c_string}}
```

Use `allocSentinel` to ensure the NULL terminator is included.

### String Conversion Utilities

Convert between Zig and C string representations:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_6.zig:string_conversion}}
```

Helper methods:
- `fromC`: Convert C string to Zig slice
- `toC`: Allocate C string from Zig slice
- `freeC`: Free allocated C string properly

### Arrays of C Strings

Pass multiple strings to C:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_6.zig:string_array}}
```

### String Concatenation

Combine C strings safely:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_6.zig:string_concatenation}}
```

### String Comparison

Use C comparison functions:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_6.zig:string_comparison}}
```

### String Search Operations

Find substrings and characters:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_6.zig:string_search}}
```

### String Manipulation

Modify strings in place or create copies:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_6.zig:string_manipulation}}
```

### Formatting C Strings

Format strings for C consumption:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_6.zig:format_string}}
```

### Best Practices

1. **Use Sentinel Types**: Always use `[*:0]const u8` for C strings
2. **Allocate with Sentinel**: Use `allocSentinel` or `dupeZ` for allocations
3. **Free Correctly**: Remember to include the NULL terminator in the free size
4. **Check for NULL**: Validate pointers before dereferencing
5. **Prefer Slices**: Convert to Zig slices for safer manipulation
6. **Document Ownership**: Clearly specify who allocates and frees strings
7. **Use `.ptr`**: Access the pointer from string literals with `.ptr`

### Common Patterns

**Passing literal string to C:**
```zig
c_function("literal string".ptr);
```

**Converting C string to Zig:**
```zig
const zig_slice = c_str[0..std.mem.len(c_str)];
```

**Allocating C string:**
```zig
const c_str = try allocator.dupeZ(u8, zig_slice);
defer allocator.free(c_str[0..c_str.len + 1]);
```

## See Also

- Recipe 15.1: Accessing C Code from Zig
- Recipe 15.3: Passing Arrays Between C and Zig

Full compilable example: `code/04-specialized/15-c-interoperability/recipe_15_6.zig`
