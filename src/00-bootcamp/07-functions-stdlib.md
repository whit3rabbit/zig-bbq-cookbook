# Functions and the Standard Library

## Problem

You need to organize code into reusable functions, leverage Zig's standard library, and understand why some error messages mention "comptime". How do you define functions? What's in the standard library? What does `comptime` mean and why do generic functions need it?

## Solution

Zig provides:

1. **Explicit function definitions** - All parameter and return types must be declared
2. **Error returns with `!T`** - Built-in error handling mechanism
3. **Rich standard library** - Modules for strings, math, collections, I/O, and more
4. **Comptime for generics** - Write functions that work with any type using compile-time parameters

These features combine to create safe, reusable code without hidden behavior.

## Discussion

### Part 1: Basic Function Definition

```zig
{{#include ../../code/00-bootcamp/recipe_0_7.zig:basic_function}}
```

**Coming from Python/JavaScript:** There's no default parameter values, no keyword arguments, and all types must be explicit. Zig doesn't infer function signatures from usage.

### Part 2: Functions Returning Errors

```zig
{{#include ../../code/00-bootcamp/recipe_0_7.zig:error_return}}
```

**Coming from Java/C++:** Zig doesn't use exceptions. Errors are values returned from functions, making error paths explicit in the code.

### Part 3: Using the Standard Library

```zig
{{#include ../../code/00-bootcamp/recipe_0_7.zig:stdlib_usage}}
```

**Key std library modules:**
- `std.mem` - Memory operations (copy, compare, search)
- `std.math` - Mathematical functions
- `std.fmt` - Formatting and printing
- `std.ArrayList` - Growable arrays
- `std.HashMap` - Hash maps
- `std.fs` - File system operations
- `std.io` - Input/output
- `std.debug` - Debug utilities

### Part 4: Comptime Basics - Generic Functions

```zig
{{#include ../../code/00-bootcamp/recipe_0_7.zig:comptime_basics}}
```

The `comptime T: type` parameter tells Zig that `T` is a type known at compile time. This lets the function work with any type.

### Why Comptime is Needed

Type information doesn't exist at runtime in Zig. To work with types, you need `comptime`:

```zig
fn typeInfo(comptime T: type) void {
    const name = @typeName(T);
    std.debug.print("Type: {s}\n", .{name});

    const size = @sizeOf(T);
    std.debug.print("Size: {d} bytes\n", .{size});
}

test "type introspection with comptime" {
    typeInfo(i32);    // Type: i32, Size: 4 bytes
    typeInfo(f64);    // Type: f64, Size: 8 bytes
    typeInfo([10]u8); // Type: [10]u8, Size: 10 bytes
}
```

### Understanding Comptime Errors

The most common comptime error is trying to use a runtime value where a compile-time value is required:

```zig
test "understanding comptime errors" {
    // This works - comptime known
    const size: usize = 5;
    var arr1: [size]i32 = undefined;

    // This would NOT work - runtime value:
    // var runtime_size: usize = 5;
    // var arr2: [runtime_size]i32 = undefined;
    // error: unable to resolve comptime value

    // For runtime-sized collections, use ArrayList
    var list = std.ArrayList(i32){};
    defer list.deinit(testing.allocator);

    const runtime_size: usize = 5;
    for (0..runtime_size) |_| {
        try list.append(testing.allocator, 0);
    }
}
```

**When you see "unable to resolve comptime value":**
- You're trying to use a runtime value in a place that requires compile-time information
- Common cases: array sizes, type parameters
- Solution: Use ArrayList or other runtime collections instead

### Putting It All Together

Here's a generic function that combines errors, comptime, and the standard library:

```zig
test "putting it all together" {
    const findMax = struct {
        fn call(comptime T: type, items: []const T) !T {
            if (items.len == 0) {
                return error.EmptySlice;
            }
            var max_val = items[0];
            for (items[1..]) |item| {
                if (item > max_val) {
                    max_val = item;
                }
            }
            return max_val;
        }
    }.call;

    const numbers = [_]i32{ 3, 7, 2, 9, 1 };
    const max_num = try findMax(i32, &numbers);
    try testing.expectEqual(@as(i32, 9), max_num);

    // Error case
    const empty: [0]i32 = .{};
    const err = findMax(i32, &empty);
    try testing.expectError(error.EmptySlice, err);
}
```

This function:
- Uses `comptime T: type` to work with any type
- Returns `!T` to handle errors (empty slice)
- Uses `try` for error handling
- Works with slices from the standard library

**Coming from C++:** Zig's comptime is like templates but runs actual Zig code at compile time. It's more powerful and easier to debug than text-based template metaprogramming.

**Coming from Java:** Think of comptime as generics, but resolved entirely at compile time with full type safety and no runtime overhead.

### Common Patterns

**Function returning errors:**
```zig
fn doSomething() !void {
    // Can return errors
    if (bad_condition) return error.SomethingWrong;
}
```

**Generic function:**
```zig
fn process(comptime T: type, value: T) T {
    // Works with any type
    return value;
}
```

**Using standard library:**
```zig
const std = @import("std");

// Use std modules
const result = std.mem.eql(u8, "hello", "hello");
```

### Common Mistakes

**Forgetting to handle errors:**
```zig
const result = divide(10, 0);  // error: expected type 'i32', found 'anyerror!i32'
const result = try divide(10, 0);  // fixed
```

**Using runtime value for comptime parameter:**
```zig
var size: usize = 5;
var arr: [size]i32 = undefined;  // error: unable to resolve comptime value

const size: usize = 5;  // fixed - const is comptime known
var arr: [size]i32 = undefined;
```

**Wrong format specifier:**
```zig
std.debug.print("{s}\n", .{42});  // error: {s} is for strings
std.debug.print("{d}\n", .{42});  // fixed - {d} for integers
```

## See Also

- Recipe 0.11: Optionals, Errors, and Resource Cleanup - More on error handling with errdefer
- Recipe 0.12: Understanding Allocators - Why functions need allocator parameters
- Recipe 0.13: Testing and Debugging Fundamentals - Using std.testing

Full compilable example: `code/00-bootcamp/recipe_0_7.zig`
