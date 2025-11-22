# Recipe 8.2: Customizing String Formatting

## Problem

You need advanced string formatting control beyond basic custom format functions, such as conditional formatting, format wrappers, or builder patterns.

## Solution

Create format wrapper types and builder patterns for flexible formatting:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_2.zig:format_wrappers}}
```

## Discussion

### Format Builder Pattern

Build complex formatted output incrementally:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_2.zig:string_builder}}
```

### Conditional Formatting

Format based on runtime state:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_2.zig:conditional_format}}
```

### Format with Width and Alignment

Create formatters that respect padding:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_2.zig:padded_formatter}}
```

### Table Formatter

Format data in tabular layout:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_2.zig:table_formatter}}
```

### JSON-like Formatter

Create structured output formats:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_2.zig:json_formatter}}
```

### Color Formatter (ANSI codes)

Add terminal colors to output:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_2.zig:color_formatter}}
```

### List Formatter

Format collections with custom separators:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_2.zig:list_formatter}}
```

### Best Practices

**Format Wrapper Pattern:**
- Create a `formatter()` method that returns a formatting type
- The formatter type implements `format()` with custom logic
- Allows multiple format styles for the same data

**Builder Pattern:**
- Use for incremental construction of formatted output
- Track allocations and provide `deinit()`
- Separate concerns: building vs. rendering

**Performance:**
- Pre-calculate sizes when possible
- Minimize allocations in format functions
- Use buffered writers for multiple writes
- Consider streaming for large outputs

**Testing:**
- Test each format variant separately
- Use `std.io.fixedBufferStream()` for testing
- Verify exact output strings with `expectEqualStrings()`

### Related Functions

- `std.fmt.format()` - Core formatting
- `std.io.fixedBufferStream()` - Testing formatters
- `std.mem.join()` - Joining strings
- `std.ArrayList(u8)` - Dynamic string building

## See Also

- Recipe 8.1: String Representation - Basic custom format functions
- Recipe 8.3: Context Management Protocol - Resource cleanup patterns

Full compilable example: `code/03-advanced/08-structs-unions-objects/recipe_8_2.zig`
