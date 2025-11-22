# Recipe 17.4: Generic Data Structure Generation

## Problem

You need to create reusable container types that work with any payload type while maintaining type safety and performance. You want generic data structures that adapt to different types at compile time without runtime overhead or code duplication.

## Solution

Zig's comptime system lets you write functions that return types, enabling powerful generic programming. These type-generating functions can inspect their parameters and create optimized containers tailored to specific use cases.

### Basic Generic List

A simple dynamic array that works with any type:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_4.zig:basic_generic_list}}
```

### Type-Aware Optimization

Adapt container behavior based on type characteristics:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_4.zig:type_aware_optimization}}
```

### Generic Result Type

Error handling container that works with any success and error types:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_4.zig:result_type}}
```

### Pair/Tuple Types

Generic pairs with type-safe operations:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_4.zig:pair_tuple}}
```

### Enhanced Optional Wrapper

Build richer optional types with additional methods:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_4.zig:optional_wrapper}}
```

### Generic Tree Node

Recursive data structures that work with any comparable type:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_4.zig:tree_node}}
```

### Circular Buffer

Fixed-size ring buffer with compile-time capacity:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_4.zig:circular_buffer}}
```

### Tagged Union Generation

Programmatically create tagged unions from type lists:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_4.zig:tagged_union}}
```

## Discussion

Generic data structure generation is one of Zig's most powerful features, enabling type-safe containers without templates, runtime overhead, or code bloat.

### How Type Functions Work

Functions that return `type` are the foundation of generic programming in Zig:

```zig
fn Container(comptime T: type) type {
    return struct {
        value: T,
        // ... methods ...
    };
}
```

These functions:
- Execute at compile time only
- Return types, not values
- Can inspect their parameters using `@typeInfo()`
- Generate specialized code for each concrete type
- Create zero-cost abstractions

### The `comptime` Parameter Pattern

Mark parameters as `comptime` when they must be known at compilation:

```zig
fn Array(comptime T: type, comptime size: usize) type
```

This enables:
- Type parameters (`T: type`)
- Compile-time constants (buffer sizes, capacities)
- Configuration flags
- Any value needed to generate the type

### Type-Specific Optimizations

Use compile-time introspection to adapt behavior:

**Size-Based Decisions**: Choose inline storage for small types, heap allocation for large ones.

**Comparison Operators**: Only generate `<` operators for types that support comparison.

**Memory Management**: Use `memcpy` for simple types, proper copy constructors for complex types.

The Stack example demonstrates this: small types get larger inline buffers, while large types use smaller buffers to conserve stack space.

### The `Self` Pattern

Most generic types use this idiom:

```zig
fn Container(comptime T: type) type {
    return struct {
        const Self = @This();

        pub fn method(self: *Self) void {
            // ...
        }
    };
}
```

`@This()` returns the current struct type, enabling methods to reference their containing type before it's fully defined.

### Generic Methods

Methods can have their own type parameters:

```zig
pub fn map(self: Self, comptime U: type, f: fn (T) U) Maybe(U)
```

This creates higher-order functions that transform container types while maintaining type safety.

### Building Types with @Type

For advanced cases, use `@Type()` to construct types from metadata:

1. Create field arrays with proper types and names
2. Build enum or struct definitions
3. Pass to `@Type()` to generate the actual type

The `TaggedUnion` example shows this process: generating both an enum tag and union fields from a type list.

### Memory Management Patterns

Generic containers handle allocation in two ways:

**Owned Allocation**: Container owns memory and requires an allocator (List, TreeNode).

**Stack Allocation**: Fixed-size containers use stack memory (Stack, CircularBuffer).

Choose based on use case:
- Dynamic sizing → heap allocation
- Known bounds → stack allocation
- Temporary data → stack or arena allocator

### Common Patterns

**Result/Option Types**: Wrap success values and errors or nulls with rich APIs.

**Collection Wrappers**: Build Lists, Stacks, Queues, Trees, Graphs with type-safe interfaces.

**Metaprogramming Helpers**: Create Pair, Tuple, Variant types for generic programming.

**Fixed-Size Buffers**: Generate CircularBuffer, RingBuffer, Pool types with compile-time capacity.

### Zero-Cost Abstractions

Generic types in Zig are zero-cost:

- No runtime type information (RTTI)
- No vtables or dynamic dispatch
- No template code bloat
- Each instantiation is a separate, specialized type
- Optimized as if hand-written for that type

### Limitations and Workarounds

**No Default Parameters**: Can't specify default type arguments, but can use wrapper functions.

**No Variadic Generics**: Use slices or tuples of types instead.

**Name Collisions**: Each instantiation creates a new type, so `List(i32)` and `List(u32)` are completely different types.

### Testing Strategies

Test generic code with:
- Multiple concrete types (small, large, complex)
- Edge cases (empty containers, single elements)
- Memory leak detection (use testing.allocator)
- Type-specific behavior (compare numeric vs non-numeric)

## See Also

- Recipe 17.1: Type-Level Pattern Matching
- Recipe 17.3: Compile-Time Assertion and Contract Validation
- Recipe 9.11: Using comptime to control instance creation
- Recipe 9.16: Defining structs programmatically

Full compilable example: `code/05-zig-paradigms/17-advanced-comptime/recipe_17_4.zig`
