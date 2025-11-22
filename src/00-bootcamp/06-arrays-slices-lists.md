# Arrays, ArrayLists, and Slices

This is the **#1 confusion point** for Zig beginners. Understanding these three types is critical for writing effective Zig code.

## The Three Sequence Types

| Type | Size | Memory | Allocator | Use Case |
|------|------|--------|-----------|----------|
| `[N]T` | Compile-time | Stack | No | Fixed-size data |
| `[]T` | Runtime | Borrowed | No | Function parameters, views |
| `ArrayList` | Runtime | Heap | Yes | Growing collections |

## Part 1: Fixed Arrays `[N]T`

Arrays have compile-time known size. The size is part of the type itself - `[3]i32` and `[5]i32` are completely different types.

```zig
{{#include ../../code/00-bootcamp/recipe_0_6.zig:fixed_arrays}}
```

**Key points:**
- Size must be known at compile time
- Lives on the stack (no allocator needed)
- Cannot grow or shrink
- Passed by value (copied) unless you use a pointer

## Part 2: Slices `[]T`

Slices are "views" into arrays. They're just a pointer plus a length. Use them when you don't know the size at compile time or want to pass arrays to functions.

```zig
{{#include ../../code/00-bootcamp/recipe_0_6.zig:slices_views}}
```

**Key points:**
- A slice is `(pointer, length)` - that's it
- Size known at runtime
- Doesn't own memory - just borrows it
- Perfect for function parameters
- Can slice any array: `array[start..end]`

## Part 3: ArrayList - Growable Arrays

When you need to add or remove elements dynamically, use `ArrayList`. This is like Python's `list` or Java's `ArrayList`.

```zig
{{#include ../../code/00-bootcamp/recipe_0_6.zig:arraylist_growable}}
```

**Key points:**
- Requires an allocator (manages heap memory)
- Can grow and shrink at runtime
- Must call `deinit()` to free memory
- Access elements via `.items` (which is a slice)

## Quick Reference

```
When to use what:

[N]T (Fixed Array)
  - Know exact size at compile time
  - Small, fixed data sets
  - No heap allocation needed

[]T (Slice)
  - Function parameters (accept any size)
  - Referencing part of an array
  - String handling ([]const u8)

ArrayList
  - Size changes at runtime
  - Building collections dynamically
  - Reading unknown amounts of data
```

## Common Patterns

**Strings are byte slices:**
```zig
const name: []const u8 = "hello";  // String slice
```

**Function that works with any array size:**
```zig
fn sum(values: []const i32) i32 { ... }
```

**Building a string dynamically:**
```zig
var buffer = std.ArrayList(u8){};
defer buffer.deinit(allocator);
try buffer.appendSlice(allocator, "Hello");
```

## See Also

- Recipe 0.9: Understanding Pointers and References
- Recipe 0.12: Understanding Allocators
- Recipe 1.7: Ordered HashMap (more data structures)

Full compilable example: `code/00-bootcamp/recipe_0_6.zig`
