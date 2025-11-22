# Primitive Data and Basic Arrays

## Problem

You need to work with different types of data in Zig. What integer types are available? How do floats work? How do you create and use arrays?

## Solution

Zig has explicit types for everything. Unlike C where `int` size varies by platform, Zig is completely explicit about sizes.

**Integers:**
- Signed: `i8`, `i16`, `i32`, `i64`, `i128`
- Unsigned: `u8`, `u16`, `u32`, `u64`, `u128`
- Platform-specific: `isize`, `usize` (pointer-sized)

**Floats:**
- `f32` - 32-bit float (single precision)
- `f64` - 64-bit float (double precision)

**Arrays:**
- Fixed-size: `[N]T` where N is the size and T is the type
- The size is part of the type!

## Discussion

### Integer Types

```zig
{{#include ../../code/00-bootcamp/recipe_0_5.zig:integer_types}}
```

### Floating Point Types

```zig
{{#include ../../code/00-bootcamp/recipe_0_5.zig:float_types}}
```

### Fixed-Size Arrays

```zig
{{#include ../../code/00-bootcamp/recipe_0_5.zig:fixed_arrays}}
```

### Boolean Type

Zig has a proper boolean type:

```zig
test "boolean type" {
    const yes: bool = true;
    const no: bool = false;

    try testing.expect(yes);
    try testing.expect(!no);

    // Booleans in conditions
    const value: i32 = 10;
    const is_positive: bool = value > 0;
    try testing.expect(is_positive);
}
```

Unlike C where any non-zero value is "true", Zig only has `true` and `false`.

### Void Type

The `void` type represents "no value":

```zig
test "void type" {
    // void means "no value"
    // Functions that return nothing return void

    const nothing: void = {};
    _ = nothing; // Suppress unused variable warning

    // Common use: functions that perform actions but return nothing
    // fn doSomething() void { }
}
```

You'll rarely use `void` as a variable type, but you'll see it as return types for functions.

### Choosing the Right Type

**For integers:**
- Use `i32` or `u32` as your default
- Use `usize` for array indices and lengths
- Use `u8` for bytes and raw data
- Use `i64/u64` for timestamps and large values
- Use smaller types (`i8`, `i16`) only when you need to save space

**For floats:**
- Use `f64` as your default (more precision)
- Use `f32` when interfacing with graphics APIs or saving memory

**For arrays:**
- Use `[N]T` when size is known at compile time
- You'll learn about slices `[]T` in Recipe 0.6 (for runtime-sized data)

## See Also

- Recipe 0.6: Arrays, ArrayLists, and Slices - The three fundamental sequence types (CRITICAL next recipe!)
- Recipe 0.4: Variables, Constants, and Type Inference - How to declare these types
- Recipe 3.4: Working with Binary, Octal, and Hexadecimal - More on number formats

Full compilable example: `code/00-bootcamp/recipe_0_5.zig`
