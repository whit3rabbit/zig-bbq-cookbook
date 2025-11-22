## Problem

You need to decide whether to pass function arguments by value or by pointer. Passing by value is simple but can be inefficient for large types. Passing by pointer is efficient but requires understanding mutability, aliasing, and lifetime rules.

## Solution

Zig gives you explicit control over how data flows through your program. Follow these guidelines:

- **Small types** (primitives, small structs): Pass by value
- **Need to modify**: Pass by mutable pointer (`*T`)
- **Large types, read-only**: Pass by const pointer (`*const T`)
- **Slices**: Already pointers, don't double-pointer
- **Returning data**: Return by value for small types, use caller-allocated pattern for large types

### Small Types: Pass by Value

Primitives and small structs are cheap to copy:

```zig
{{#include ../../code/01-foundation/recipe_1_4.zig:small_types_by_value}}
```

Types under 16-32 bytes are generally passed by value. Copying a few bytes is faster than dereferencing a pointer.

### Mutation Requires Pointers

If a function needs to modify its argument, pass a mutable pointer:

```zig
{{#include ../../code/01-foundation/recipe_1_4.zig:mutation_by_pointer}}
```

The `&` operator takes the address of a variable. The `.*` syntax dereferences the pointer to access or modify the value.

## Discussion

### Large Types: Use Const Pointers

For large structs, pass by const pointer to avoid copying:

```zig
{{#include ../../code/01-foundation/recipe_1_4.zig:large_types_const_pointer}}
```

The `*const` syntax creates a read-only pointer. This avoids the copy while preventing accidental modification.

### Const Pointers Prevent Mutation

The type system enforces immutability for const pointers:

```zig
{{#include ../../code/01-foundation/recipe_1_4.zig:const_pointer_immutability}}
```

Use `*const T` when you only need read access. This communicates intent and catches bugs at compile time.

### Slices Are Already Pointers

Slices are fat pointers (pointer + length). Never take a pointer to a slice:

```zig
{{#include ../../code/01-foundation/recipe_1_4.zig:slices_already_pointers}}
```

A slice already contains a pointer to the data, so passing by value is efficient.

### Returning Values

Return small types by value:

```zig
{{#include ../../code/01-foundation/recipe_1_4.zig:return_by_value}}
```

Returning by value is clear and safe. The compiler handles the memory efficiently.

### Caller-Allocated Pattern

For large types, use the caller-allocated pattern:

```zig
{{#include ../../code/01-foundation/recipe_1_4.zig:caller_allocated}}
```

The caller allocates the memory, and the function fills it in. This avoids copying large objects on return.

### Struct Method Conventions

Struct methods follow a consistent pattern for `self`:

```zig
{{#include ../../code/01-foundation/recipe_1_4.zig:struct_methods_self}}
```

Use `*const Self` for read-only methods, `*Self` for mutating methods, and `Self` for consuming methods.

### Optional Pointers

Use optional pointers to return references that might not exist:

```zig
{{#include ../../code/01-foundation/recipe_1_4.zig:optional_pointers}}
```

The `?*const T` type represents an optional pointer. Return `null` when there's no valid reference.

### Pointer Size Awareness

Pointers are always 8 bytes on 64-bit systems, regardless of what they point to:

```zig
{{#include ../../code/01-foundation/recipe_1_4.zig:pointer_size_awareness}}
```

When the value is larger than a pointer (typically 8 bytes), consider passing by pointer.

### Multiple Return Values

Return multiple values using a struct, not out-parameters:

```zig
{{#include ../../code/01-foundation/recipe_1_4.zig:multi_return_values}}
```

Returning a struct is clearer and safer than using pointer out-parameters.

### Pointer Aliasing

Be aware that two pointers can refer to the same memory:

```zig
{{#include ../../code/01-foundation/recipe_1_4.zig:aliasing_concerns}}
```

When `a` and `b` point to the same location, both assignments affect the same value.

### Performance Considerations

The performance difference becomes significant for types larger than about 16-32 bytes:

- **Small types (≤16 bytes)**: Pass by value (simple and fast)
- **Medium types (16-100 bytes)**: Consider const pointer if frequently passed
- **Large types (>100 bytes)**: Always use const pointer

For actual benchmarking, use `std.time.Timer` and run operations in a loop. The compiler optimizes aggressively, so always measure in realistic scenarios.

### Decision Tree

Use this decision tree when choosing how to pass arguments:

1. **Need to modify the argument?**
   - Yes → Use `*T` (mutable pointer)
   - No → Continue

2. **Is it a slice or array-like type?**
   - Yes → Use `[]T` or `[]const T` (already a pointer)
   - No → Continue

3. **Is the type large (>16 bytes)?**
   - Yes → Use `*const T` (const pointer)
   - No → Continue

4. **Default: Pass by value** (`T`)

### Common Patterns

**Read-only large data:**
```zig
fn process(data: *const LargeStruct) Result
```

**Mutating argument:**
```zig
fn modify(data: *LargeStruct) void
```

**Slice (read-only):**
```zig
fn sum(items: []const i32) i32
```

**Slice (mutable):**
```zig
fn fill(items: []i32, value: i32) void
```

**Optional reference:**
```zig
fn find(items: []const Item) ?*const Item
```

**Multiple returns:**
```zig
fn parse(input: []const u8) struct { result: T, remaining: []const u8 }
```

### Memory Safety

Zig's pointer rules ensure memory safety:

- Pointers must point to valid memory
- Const pointers cannot be used to modify data
- Dangling pointers are prevented by the compiler when possible
- Lifetime analysis catches many use-after-free bugs

The type system guides you toward safe patterns while giving you low-level control when needed.

## See Also

- Recipe 0.9: Understanding Pointers and References
- Recipe 1.1: Writing Idiomatic Zig Code
- Recipe 2.6: Implementing a custom container

Full compilable example: `code/01-foundation/recipe_1_4.zig`
