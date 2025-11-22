# Control Flow and Iteration

## Problem

You need to make decisions and repeat operations in your Zig programs. How do if statements work? What about loops? How do you break out of nested loops?

## Solution

Zig has familiar control flow constructs with some unique twists:

- **if/else** - Conditions must be `bool` (no truthy/falsy)
- **switch** - Exhaustive pattern matching (as an expression)
- **while** - Loops with optional continue expressions
- **for** - Iterates over arrays, slices, and ranges
- **Labeled blocks** - Control nested loops precisely

All control flow in Zig is explicit and predictable - no hidden behavior.

## Discussion

### If/Else Statements

```zig
{{#include ../../code/00-bootcamp/recipe_0_8.zig:if_else}}
```

This might feel restrictive at first, but it prevents bugs. Your intent is clear.

### Switch Statements

```zig
{{#include ../../code/00-bootcamp/recipe_0_8.zig:switch_statement}}
```

The `...` syntax creates an inclusive range (0 through 9, not 0 to 8).

Use labeled blocks (`blk:`) when you need multiple statements in a case.

### While Loops

```zig
{{#include ../../code/00-bootcamp/recipe_0_8.zig:while_loops}}
```

Note: Use `@rem` for remainder with signed integers (not `%`).

### For Loops

```zig
{{#include ../../code/00-bootcamp/recipe_0_8.zig:for_loops}}
```

The `0..` creates an infinite range, but it only iterates as far as the array.

The `else` branch runs if the loop completes without breaking.

### Labeled Blocks and Nested Loops

```zig
{{#include ../../code/00-bootcamp/recipe_0_8.zig:labeled_blocks}}
```

Labeled blocks let you return values from complex control flow.

### Combining Everything

Real code often combines multiple control flow constructs:

```zig
test "combining control flow" {
    const numbers = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    var result: i32 = 0;

    for (numbers) |n| {
        // Skip numbers less than 3
        if (n < 3) continue;

        // Stop at 8
        if (n > 8) break;

        // Add only odd numbers
        if (@rem(n, 2) == 0) continue;

        result += n;
    }

    // Sum of 3, 5, 7 = 15
    try testing.expectEqual(@as(i32, 15), result);
}
```

### Key Differences from Other Languages

**From JavaScript/Python:**
- No truthy/falsy values - conditions must be `bool`
- `switch` must be exhaustive (all cases handled)
- No `for...in` or `for...of` - use `for (array) |item|`

**From C:**
- Switch doesn't fall through (no `break` needed in each case)
- For loops don't use C-style `for (init; cond; inc)`
- Conditions must be `bool`, not any integer type

**From Rust:**
- Similar `if let` pattern for optional unwrapping
- Similar exhaustive `match` (Zig's `switch`)
- Labeled loops work the same way

### Common Beginner Mistakes

**Using non-bool in conditions:**
```zig
const x: i32 = 1;
if (x) { }  // error: expected bool, found i32
if (x != 0) { }  // fixed
```

**Forgetting else in switch:**
```zig
const x: i32 = 5;
const result = switch (x) {
    1 => "one",
    2 => "two",
    // Missing else!
};
// error: switch must handle all possibilities
```

**Using % with signed integers:**
```zig
if (x % 2 == 0) { }  // error
if (@rem(x, 2) == 0) { }  // fixed
```

**Wrong for loop syntax:**
```zig
// Old C-style (doesn't work)
for (var i = 0; i < 10; i++) { }

// Zig way
for (0..10) |i| { }
```

## See Also

- Recipe 0.6: Arrays, ArrayLists, and Slices - Iterating collections
- Recipe 0.11: Optionals, Errors, and Resource Cleanup - More on unwrapping
- Recipe 0.10: Structs, Enums, and Simple Data Models - Using switch with enums

Full compilable example: `code/00-bootcamp/recipe_0_8.zig`
