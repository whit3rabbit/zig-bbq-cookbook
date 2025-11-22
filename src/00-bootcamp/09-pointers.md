# Understanding Pointers and References

## Problem

You're coming from Python, JavaScript, or Java where references are automatic and garbage collected. In Zig, you need to understand when and how to use pointers explicitly.

What's the difference between `*T`, `[*]T`, and `[]T`? When do you use `&` and `.*`? When should you pass by value vs pointer? This is essential knowledge that garbage-collected languages hide from you.

## Solution

Zig has three pointer types, each for different use cases:

1. **Single-item pointer `*T`** - Points to exactly one value
2. **Many-item pointer `[*]T`** - Points to unknown number of values (like C pointers)
3. **Slice `[]T`** - Pointer + length (safest, most common)

The key operations:
- Use `&` to take the address of a value
- Use `.*` to dereference a pointer
- Use `*const T` for read-only pointers
- Prefer slices over raw pointers

Understanding pointers is the bridge between high-level and systems programming.

## Discussion

### Part 1: Single-Item Pointers `*T`

```zig
{{#include ../../code/00-bootcamp/recipe_0_9.zig:single_item_pointer}}
```

**Coming from Python/JavaScript:** These languages hide all pointer operations. When you write `obj.field = value`, the language automatically handles the reference. In Zig, these operations are explicit.

**Coming from C++:** Zig's `*T` is like C++'s `T*`, and `.*` is like C++'s `*ptr`. But Zig auto-dereferences for struct field access.

### Part 2: Many-Item Pointers `[*]T` and Slices `[]T`

```zig
{{#include ../../code/00-bootcamp/recipe_0_9.zig:many_item_pointer}}
```

Functions that accept `[]const T` work with any array size - this is the idiomatic way to pass arrays in Zig.

### Part 3: When to Use Pointers vs Values

```zig
{{#include ../../code/00-bootcamp/recipe_0_9.zig:when_to_use_pointers}}
```

`*[5]i32` knows the size at compile time (it's part of the type). `[]i32` knows the size at runtime (it's a field in the slice).

### Advanced: Sentinel-Terminated Pointers

C strings use null termination. Zig represents this with `[*:0]u8`:

```zig
test "sentinel-terminated pointers" {
    // [*:0]u8 - many-item pointer terminated by 0 (for C strings)
    const c_string: [*:0]const u8 = "hello";

    // Can iterate until sentinel
    var len: usize = 0;
    while (c_string[len] != 0) : (len += 1) {}

    try testing.expectEqual(@as(usize, 5), len);

    // Better: use std.mem.span to convert to slice
    const slice = std.mem.span(c_string);
    try testing.expectEqual(@as(usize, 5), slice.len);
    try testing.expect(std.mem.eql(u8, slice, "hello"));
}
```

Use `std.mem.span` to convert C strings to slices.

### Comparing Pointers vs Values

```zig
test "comparing pointers vs comparing values" {
    var x: i32 = 42;
    var y: i32 = 42;

    const ptr_x: *i32 = &x;
    const ptr_y: *i32 = &y;

    // Different pointers (different addresses)
    try testing.expect(ptr_x != ptr_y);

    // Same values
    try testing.expectEqual(ptr_x.*, ptr_y.*);

    // Pointer to same location
    const also_ptr_x: *i32 = &x;
    try testing.expect(ptr_x == also_ptr_x);
}
```

Comparing pointers (`ptr_x == ptr_y`) checks if they point to the same address. Comparing values (`ptr_x.* == ptr_y.*`) checks if the values are equal.

### Avoiding Dangling Pointers

Never return a pointer to a local variable:

```zig
test "avoiding dangling pointers" {
    // This is BAD - don't do this!
    // fn getBadPointer() *i32 {
    //     var x: i32 = 42;
    //     return &x;  // x goes out of scope!
    // }

    // Instead, return the value
    const getGoodValue = struct {
        fn call() i32 {
            const x: i32 = 42;
            return x;
        }
    }.call;

    const value = getGoodValue();
    try testing.expectEqual(@as(i32, 42), value);
}
```

When a function returns, its local variables are freed. Returning a pointer to them creates a dangling pointer that points to invalid memory.

**Solutions:**
1. Return by value (for small data)
2. Use an allocator and return heap-allocated memory
3. Have the caller provide the memory

### Decision Tree

**Should I use a pointer?**

- Need to modify the value? → Use `*T`
- Struct is large (> 64 bytes)? → Use `*const T` for read-only
- Working with arrays/strings? → Use `[]T` (slice)
- C interop? → Might need `[*]T` or `[*:0]T`
- Otherwise → Pass by value

**Which pointer type?**

- Single value, known at compile time → `*T` or `*const T`
- Array without length tracking → `[*]T` (rare, prefer slices)
- Array with length → `[]T` (slice - most common)
- Nullable pointer → `?*T`

### Common Mistakes

**Returning pointer to local variable:**
```zig
fn bad() *i32 {
    var x: i32 = 42;
    return &x;  // BAD: x is freed when function returns
}
```

**Forgetting to dereference:**
```zig
var x: i32 = 42;
const ptr: *i32 = &x;
const value = ptr;  // error: ptr is *i32, not i32
const value = ptr.*;  // fixed
```

**Using many-item pointer when you need a slice:**
```zig
fn process(ptr: [*]i32) void {
    // How many elements? You don't know!
}

fn process(slice: []i32) void {
    // Much better - you have slice.len
}
```

**Modifying through const pointer:**
```zig
var x: i32 = 42;
const ptr: *const i32 = &x;
ptr.* = 100;  // error: cannot assign to constant
```

## See Also

- Recipe 0.6: Arrays, ArrayLists, and Slices - Understanding slice types
- Recipe 0.10: Structs, Enums, and Simple Data Models - Using pointers with structs
- Recipe 0.12: Understanding Allocators - Heap-allocated pointers

Full compilable example: `code/00-bootcamp/recipe_0_9.zig`
