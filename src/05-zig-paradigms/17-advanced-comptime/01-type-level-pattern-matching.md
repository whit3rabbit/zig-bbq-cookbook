# Recipe 17.1: Type-Level Pattern Matching

## Problem

You need to write generic functions that behave differently based on the characteristics of the types they operate on, such as whether a type is numeric, its size, or what fields a struct contains. This requires compile-time type inspection and pattern matching.

## Solution

Zig provides powerful compile-time reflection through `@typeInfo()`, which returns detailed information about any type. You can use this to match types against patterns and implement type-aware generic functions.

### Basic Type Matching

Check if a type belongs to a specific category:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_1.zig:basic_type_matching}}
```

### Categorizing Types

Create broader type categories for more flexible matching:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_1.zig:type_categories}}
```

### Generic Zero Values

Generate appropriate zero values for any numeric type:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_1.zig:generic_zero}}
```

### Container Depth Analysis

Calculate how deeply nested a type is:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_1.zig:container_depth}}
```

### Unwrapping Nested Types

Peel away layers of pointers, arrays, and optionals to get the innermost type:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_1.zig:unwrap_type}}
```

### Size-Based Dispatch

Choose different strategies based on type size:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_1.zig:size_based_dispatch}}
```

### Integer Signedness Matching

Inspect and transform integer signedness at compile time:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_1.zig:signedness_matching}}
```

### Struct Field Matching

Check for the presence of specific fields and get their types:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_1.zig:struct_field_matching}}
```

### Polymorphic Serializer

Build a generic serializer that adapts to different types automatically:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_1.zig:polymorphic_serializer}}
```

## Discussion

Type-level pattern matching is one of Zig's most powerful metaprogramming features. Unlike runtime reflection in other languages, Zig's type introspection happens entirely at compile time, meaning zero runtime overhead.

### How @typeInfo Works

The `@typeInfo()` builtin returns a `std.builtin.Type` union that describes the type's structure. You can switch on this union to handle different type categories:

- `.int` and `.comptime_int` for integer types
- `.float` and `.comptime_float` for floating-point types
- `.pointer` for pointers (with information about mutability, child type, and size)
- `.array` for fixed-size arrays
- `.@"struct"` for struct types (with field information)
- `.@"enum"` and `.@"union"` for enums and unions
- `.optional` for optional types
- `.error_union` for error unions

### Pattern Matching Strategies

**Simple Category Checks**: Use basic switches to check if a type belongs to a family like numeric types, containers, or aggregates.

**Recursive Type Analysis**: Many type properties require recursion, like calculating nesting depth or unwrapping nested containers. These functions call themselves with child types until reaching a base case.

**Type Construction**: Use `@Type()` to build new types based on patterns you've matched. This is how `toggleSignedness()` creates unsigned versions of signed integers.

**Field Iteration**: When inspecting struct fields, use `inline for` to iterate at compile time. The compiler unrolls the loop and each iteration can access comptime-only information like field types.

### Compile-Time Guarantees

Since all type matching happens at compile time:

- Invalid operations are caught immediately with `@compileError()`
- No runtime type checks or casts are needed
- The generated code is as efficient as hand-written type-specific code
- You get full type safety without performance cost

### Practical Applications

**Generic Collections**: Adapt container behavior based on element types (use memcpy for simple types, proper cleanup for complex types).

**Serialization**: Automatically serialize any type by inspecting its structure, as shown in the polymorphic serializer example.

**Memory Optimization**: Choose allocation strategies based on type size and alignment requirements.

**API Validation**: Enforce constraints on generic parameters, like requiring certain struct fields or numeric bounds.

**Zero-Cost Abstractions**: Create high-level interfaces that compile down to optimal machine code tailored to each concrete type.

## See Also

- Recipe 9.16: Defining structs programmatically
- Recipe 9.11: Using comptime to control instance creation
- Recipe 17.2: Compile-Time String Processing and Code Generation
- Recipe 17.4: Generic Data Structure Generation

Full compilable example: `code/05-zig-paradigms/17-advanced-comptime/recipe_17_1.zig`
