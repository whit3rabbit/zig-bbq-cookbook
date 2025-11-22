# Unpacking and Destructuring

## Problem

You have a tuple or an array and you want to assign its elements to separate variables without writing verbose indexing code.

## Solution

Zig supports destructuring via multiple `const` or `var` declarations in a single statement:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_1.zig:basic_destructuring}}
```

## Discussion

### Tuple Destructuring

Tuples in Zig are created with the anonymous struct literal syntax `.{ ... }`. You can unpack them directly:

```zig
const point = .{ 10, 20 };
const x, const y = point;
// x = 10, y = 20
```

This works with any tuple, including those with mixed types:

```zig
const person = .{ "Alice", 30, true };
const name, const age, const is_active = person;
// name = "Alice", age = 30, is_active = true
```

### Array Destructuring

You can also destructure arrays, but you must match the exact number of elements:

```zig
const coords = [3]i32{ 1, 2, 3 };
const a, const b, const c = coords;
// a = 1, b = 2, c = 3
```

### Ignoring Values

Use `_` to ignore values you don't need:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_1.zig:ignoring_values}}
```

### Function Return Values

This is particularly useful when functions return multiple values as tuples:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_1.zig:practical_examples}}
```

### Limitations

Note that you cannot partially destructure - you must unpack all elements or use indexing:

```zig
// This works - unpack all
const tuple = .{ 1, 2, 3, 4 };
const a, const b, const c, const d = tuple;

// This doesn't work - can't partially destructure
// const a, const b = tuple; // Error!

// Instead, use indexing for partial access
const first = tuple[0];
const second = tuple[1];
```

### Mutable Variables

You can also destructure into mutable variables:

```zig
var point = .{ 5, 10 };
var x, var y = point;
x += 1;
y += 2;
// x = 6, y = 12
```

## See Also

- Recipe 1.11: Naming Slices (using constants for indices)
- Recipe 1.18: Mapping names to sequence elements (structs vs tuples)
- Recipe 4.10: Iterating over index-value pairs

Full compilable example: `code/02-core/01-data-structures/recipe_1_1.zig`
