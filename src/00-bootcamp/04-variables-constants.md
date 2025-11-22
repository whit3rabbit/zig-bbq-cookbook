# Variables, Constants, and Type Inference

## Problem

You need to store and manipulate data in your Zig programs. How do you declare values? What's the difference between `const` and `var`? When do you need to specify types explicitly?

## Solution

Zig has two keywords for declaring values:

- `const` - For values that never change (immutable)
- `var` - For values that can change (mutable)

The Zig philosophy: **use `const` by default, `var` only when needed**.

```zig
{{#include ../../code/00-bootcamp/recipe_0_4.zig:const_vs_var}}
```

## Discussion

Why prefer `const`?
- **Clarity**: When you see `const`, you know the value won't change
- **Safety**: The compiler prevents accidental modification
- **Optimization**: The compiler can make better decisions
- **Correctness**: Most values in programs don't actually need to change

### Const Pointers vs Const Values

This can be confusing: `const` on a pointer declaration means the pointer itself can't change, not necessarily what it points to:

```zig
test "const pointers vs const values" {
    var value: i32 = 42;

    // Pointer to mutable value
    const ptr: *i32 = &value;
    ptr.* = 43; // Can modify through pointer
    try testing.expectEqual(@as(i32, 43), value);

    // Pointer to immutable value
    const const_value: i32 = 99;
    const const_ptr: *const i32 = &const_value;
    // const_ptr.* = 100;  // error: cannot assign to const

    try testing.expectEqual(@as(i32, 99), const_ptr.*);
}
```

Key distinction:
- `const ptr: *i32` - The pointer address can't change, but the value it points to can
- `const ptr: *const i32` - The pointer AND the value are both immutable

### Type Inference

Zig can often figure out types automatically:

```zig
{{#include ../../code/00-bootcamp/recipe_0_4.zig:type_inference}}
```

This is different from C or Python, where numeric types get automatically promoted. In Zig, you must be explicit.

### Type Casting and Conversion

Zig doesn't do implicit type conversions. Use these built-in functions:

```zig
{{#include ../../code/00-bootcamp/recipe_0_4.zig:type_casting}}
```

### Undefined and Uninitialized Values

You can delay initialization using `undefined`:

```zig
test "undefined and uninitialized values" {
    // You can declare without initializing using undefined
    var x: i32 = undefined;

    // But reading it before assignment is undefined behavior
    // try testing.expectEqual(0, x);  // DON'T DO THIS

    // Initialize before using
    x = 42;
    try testing.expectEqual(@as(i32, 42), x);
}
```

`undefined` is useful for:
- Arrays that will be filled later
- Temporary buffers
- Performance-critical code (skips initialization)

But be careful - reading `undefined` values is undefined behavior (might be any value, might crash).

### Multiple Declarations

Zig supports destructuring for multiple declarations:

```zig
test "multiple declarations" {
    // You can declare multiple values in one line with destructuring
    const a, const b, const c = .{ 1, 2, 3 };

    try testing.expectEqual(@as(i32, 1), a);
    try testing.expectEqual(@as(i32, 2), b);
    try testing.expectEqual(@as(i32, 3), c);
}
```

### Scope

Variables are scoped to their block:

```zig
test "scope and local declarations" {
    const x = 42;
    try testing.expectEqual(@as(i32, 42), x);

    {
        // Inner scope has its own declarations
        const y = 99;
        try testing.expectEqual(@as(i32, 99), y);
        // x from outer scope is also accessible here
        try testing.expectEqual(@as(i32, 42), x);
    }

    // y is not accessible here (out of scope)
    // Original x is still accessible
    try testing.expectEqual(@as(i32, 42), x);
}
```

### Common Beginner Mistakes

**Using var when const would work:**
```zig
var x = 42;  // Unnecessary var
const y = 42;  // Better - communicates intent
```

**Forgetting type annotations when needed:**
```zig
const arr = [_]i32{};  // error: can't infer empty array type
const arr: [0]i32 = [_]i32{};  // Fixed
```

**Trying to use implicit conversions:**
```zig
const x: i32 = 10;
const y: i64 = 20;
const sum = x + y;  // error: mismatched types!
const sum = @as(i64, x) + y;  // Fixed
```

**Reading undefined values:**
```zig
var x: i32 = undefined;
const y = x;  // Undefined behavior!
```

## See Also

- Recipe 0.5: Primitive Data and Basic Arrays - Working with different data types
- Recipe 0.9: Understanding Pointers and References - More on `*const` vs `*`
- Recipe 1.2: Standard Allocator Usage Patterns - const vs var in real programs

Full compilable example: `code/00-bootcamp/recipe_0_4.zig`
