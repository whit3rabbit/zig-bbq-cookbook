# Working with Slices

## Problem

You need to work with portions of arrays, pass variable-length data to functions, or manipulate sequences of data without copying.

## Solution

Zig's slice type `[]T` is a fat pointer containing both a pointer to data and a length. Slices are your go-to tool for working with sequences:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_2.zig:basic_slice}}
```

## Discussion

### Slices vs Arrays

Arrays in Zig have a fixed size known at compile time. Slices are runtime-sized views into arrays:

```zig
// Array: size is part of the type
const array: [5]i32 = [_]i32{ 1, 2, 3, 4, 5 };

// Slice: size is runtime value
const slice: []const i32 = &array;
```

### Creating Slices

You can create slices from arrays using the address-of operator:

```zig
const array = [_]i32{ 10, 20, 30, 40, 50 };
const all: []const i32 = &array;     // Entire array
const partial: []const i32 = array[1..4];  // Elements 1, 2, 3
const from_start: []const i32 = array[0..3];  // Elements 0, 1, 2
const to_end: []const i32 = array[2..];       // Elements 2, 3, 4
```

### Slice Syntax

Use range syntax `start..end` to create sub-slices:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_2.zig:range_syntax}}
```

### Const vs Mutable Slices

Slices can be const (read-only) or mutable:

```zig
var array = [_]i32{ 1, 2, 3 };

// Const slice - can't modify elements
const const_slice: []const i32 = &array;
// const_slice[0] = 99;  // Error!

// Mutable slice - can modify elements
const mut_slice: []i32 = &array;
mut_slice[0] = 99;  // OK
```

### Iterating Over Slices

Slices work great with for loops:

```zig
const items = [_]i32{ 10, 20, 30 };
const slice: []const i32 = &items;

// Iterate over values
for (slice) |value| {
    // Use value
}

// Iterate with index (Zig 0.13+)
for (slice, 0..) |value, i| {
    // Use both value and index
}
```

### Slices as Function Parameters

Always prefer slices over raw pointers for function parameters:

```zig
// Good: Slice carries length information
fn sum(numbers: []const i32) i32 {
    var total: i32 = 0;
    for (numbers) |n| {
        total += n;
    }
    return total;
}

// Avoid: Requires separate length parameter
fn sumOld(numbers: [*]const i32, len: usize) i32 {
    var total: i32 = 0;
    var i: usize = 0;
    while (i < len) : (i += 1) {
        total += numbers[i];
    }
    return total;
}
```

### Slice Operations

Common slice operations using `std.mem`:

```zig
const std = @import("std");

// Copy data
var dest: [5]i32 = undefined;
const src = [_]i32{ 1, 2, 3, 4, 5 };
@memcpy(&dest, &src);

// Compare slices
const equal = std.mem.eql(i32, &src, &dest);  // true

// Find values
const haystack = [_]i32{ 1, 2, 3, 4, 5 };
const needle = [_]i32{ 3, 4 };
const index = std.mem.indexOf(i32, &haystack, &needle);  // Some(2)
```

### Dynamic Slices with ArrayList

For dynamically-sized collections, use `ArrayList`:

```zig
var list = std.ArrayList(i32).init(allocator);
defer list.deinit();

try list.append(1);
try list.append(2);
try list.append(3);

// Get a slice view of the ArrayList
const slice: []const i32 = list.items;
```

### Zero-Length Slices

Empty slices are valid and useful:

```zig
const empty: []const i32 = &[_]i32{};
// empty.len == 0
```

### Sentinel-Terminated Slices

Slices can have sentinel values (like null-terminated strings):

```zig
const str: [:0]const u8 = "hello";  // Null-terminated
// str.len == 5, but memory contains 6 bytes (including 0)
```

## See Also

- Recipe 1.11: Naming Slices (using constants for meaningful indices)
- Recipe 1.16: Filtering sequence elements
- Chapter 2: Strings and Text (slices of `u8`)
- Recipe 5.9: Reading binary data into a mutable buffer

Full compilable example: `code/02-core/01-data-structures/recipe_1_2.zig`
