// Recipe 0.8: Control Flow and Iteration
// Target Zig Version: 0.15.2
//
// This recipe demonstrates Zig's control flow constructs: if, switch, while, for,
// and how to use break, continue, and labeled blocks.

const std = @import("std");
const testing = std.testing;

// ANCHOR: if_else
// If/Else Statements
//
// Zig's if statements are similar to other languages, but conditions must be bool
// (no truthy/falsy values like in C or JavaScript)

test "basic if statement" {
    const x: i32 = 10;

    if (x > 5) {
        try testing.expect(true);
    } else {
        try testing.expect(false);
    }
}

test "if expressions return values" {
    const x: i32 = 10;

    // if is an expression - it returns a value
    const result = if (x > 5) "big" else "small";

    try testing.expect(std.mem.eql(u8, result, "big"));
}

test "if with optional unwrapping" {
    const maybe_value: ?i32 = 42;

    // Unwrap optional with if
    if (maybe_value) |value| {
        try testing.expectEqual(@as(i32, 42), value);
    } else {
        try testing.expect(false); // This won't run
    }
}

test "if with error unwrapping" {
    const result: anyerror!i32 = 42;

    // Unwrap error union with if
    if (result) |value| {
        try testing.expectEqual(@as(i32, 42), value);
    } else |err| {
        _ = err;
        try testing.expect(false); // This won't run
    }
}

test "conditions must be bool" {
    const x: i32 = 1;

    // This works (explicit comparison)
    if (x != 0) {
        try testing.expect(true);
    }

    // This would NOT compile (no implicit conversion to bool):
    // if (x) { }  // error: expected bool, found i32
}
// ANCHOR_END: if_else

// ANCHOR: switch_statement
// Switch Statements
//
// Zig's switch is powerful and used as an expression.
// All cases must be handled (exhaustive).

test "basic switch" {
    const x: i32 = 2;

    const result = switch (x) {
        1 => "one",
        2 => "two",
        3 => "three",
        else => "other",
    };

    try testing.expect(std.mem.eql(u8, result, "two"));
}

test "switch with multiple values" {
    const x: i32 = 5;

    const result = switch (x) {
        1, 2, 3 => "small",
        4, 5, 6 => "medium",
        7, 8, 9 => "large",
        else => "other",
    };

    try testing.expect(std.mem.eql(u8, result, "medium"));
}

test "switch with ranges" {
    const x: i32 = 15;

    const result = switch (x) {
        0...9 => "single digit",
        10...99 => "double digit",
        100...999 => "triple digit",
        else => "other",
    };

    try testing.expect(std.mem.eql(u8, result, "double digit"));
}

test "switch must be exhaustive" {
    const x: u2 = 2;

    // For small types, you can enumerate all cases
    const category = switch (x) {
        0 => "zero",
        1 => "one",
        2 => "two",
        3 => "three",
        // No else needed - all u2 values covered
    };

    try testing.expect(std.mem.eql(u8, category, "two"));
}

test "switch with blocks" {
    const x: i32 = 2;

    const result = switch (x) {
        1 => blk: {
            // Can use blocks for complex logic
            const val = x * 10;
            break :blk val;
        },
        2 => blk: {
            const val = x * 20;
            break :blk val;
        },
        else => 0,
    };

    try testing.expectEqual(@as(i32, 40), result);
}
// ANCHOR_END: switch_statement

// ANCHOR: while_loops
// While Loops
//
// Zig has while loops with optional continue expressions

test "basic while loop" {
    var i: i32 = 0;
    var sum: i32 = 0;

    while (i < 5) {
        sum += i;
        i += 1;
    }

    try testing.expectEqual(@as(i32, 10), sum);
}

test "while with continue expression" {
    var sum: i32 = 0;
    var i: i32 = 0;

    // The continue expression runs after each iteration
    while (i < 5) : (i += 1) {
        sum += i;
    }

    try testing.expectEqual(@as(i32, 10), sum);
}

test "while with break" {
    var i: i32 = 0;

    while (true) {
        if (i >= 5) break;
        i += 1;
    }

    try testing.expectEqual(@as(i32, 5), i);
}

test "while with continue" {
    var sum: i32 = 0;
    var i: i32 = 0;

    while (i < 10) : (i += 1) {
        // Skip even numbers
        if (@rem(i, 2) == 0) continue;
        sum += i;
    }

    // Sum of odd numbers: 1+3+5+7+9 = 25
    try testing.expectEqual(@as(i32, 25), sum);
}

test "while with optional unwrapping" {
    var maybe: ?i32 = 10;

    // Loop while optional has a value
    while (maybe) |value| {
        try testing.expectEqual(@as(i32, 10), value);
        maybe = null; // Exit loop
    }

    try testing.expectEqual(@as(?i32, null), maybe);
}
// ANCHOR_END: while_loops

// ANCHOR: for_loops
// For Loops
//
// Zig's for loops iterate over arrays, slices, and ranges

test "for loop over array" {
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    var sum: i32 = 0;

    for (numbers) |n| {
        sum += n;
    }

    try testing.expectEqual(@as(i32, 15), sum);
}

test "for loop with index" {
    const numbers = [_]i32{ 10, 20, 30 };

    // Modern Zig syntax for index
    for (numbers, 0..) |n, i| {
        try testing.expectEqual(numbers[i], n);
    }
}

test "for loop over range" {
    var sum: i32 = 0;

    // Loop from 0 to 4 (not including 5)
    for (0..5) |i| {
        sum += @intCast(i);
    }

    try testing.expectEqual(@as(i32, 10), sum);
}

test "for loop with break" {
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    var found = false;

    for (numbers) |n| {
        if (n == 3) {
            found = true;
            break;
        }
    }

    try testing.expect(found);
}

test "for loop with continue" {
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    var sum: i32 = 0;

    for (numbers) |n| {
        // Skip even numbers
        if (@rem(n, 2) == 0) continue;
        sum += n;
    }

    // Sum of odd numbers: 1+3+5 = 9
    try testing.expectEqual(@as(i32, 9), sum);
}

test "for loop as expression with else" {
    const numbers = [_]i32{ 2, 4, 6, 8 };

    // Find first odd number, or return 0
    const first_odd = for (numbers) |n| {
        if (@rem(n, 2) == 1) break n;
    } else 0;

    try testing.expectEqual(@as(i32, 0), first_odd);
}

test "iterating multiple arrays simultaneously" {
    const a = [_]i32{ 1, 2, 3 };
    const b = [_]i32{ 10, 20, 30 };
    var sum: i32 = 0;

    // Iterate both arrays together
    for (a, b) |x, y| {
        sum += x + y;
    }

    try testing.expectEqual(@as(i32, 66), sum);
}
// ANCHOR_END: for_loops

// ANCHOR: labeled_blocks
// Labeled Blocks and Nested Loops
//
// Use labels to break/continue outer loops from inner loops

test "labeled break in nested loops" {
    var count: i32 = 0;

    outer: for (0..3) |i| {
        for (0..3) |j| {
            count += 1;
            if (i == 1 and j == 1) {
                break :outer; // Break out of outer loop
            }
        }
    }

    // Iterations: (0,0), (0,1), (0,2), (1,0), (1,1) = 5
    try testing.expectEqual(@as(i32, 5), count);
}

test "labeled continue in nested loops" {
    var sum: i32 = 0;

    outer: for (0..3) |i| {
        for (0..3) |j| {
            if (j == 1) continue :outer; // Skip to next outer iteration
            sum += @as(i32, @intCast(i * 10 + j));
        }
    }

    // Only processes j=0 for each i: 00, 10, 20
    try testing.expectEqual(@as(i32, 30), sum);
}

test "labeled blocks for complex control flow" {
    const result = blk: {
        var i: i32 = 0;
        while (i < 10) : (i += 1) {
            if (i == 5) break :blk i * 2;
        }
        break :blk 0;
    };

    try testing.expectEqual(@as(i32, 10), result);
}

test "nested labeled blocks" {
    const result = outer: {
        const inner_result = inner: {
            break :inner 42;
        };
        break :outer inner_result * 2;
    };

    try testing.expectEqual(@as(i32, 84), result);
}
// ANCHOR_END: labeled_blocks

// Additional examples

test "inline for loops (compile-time iteration)" {
    const numbers = [_]i32{ 1, 2, 3 };

    // inline keyword unrolls loop at compile time
    var sum: i32 = 0;
    inline for (numbers) |n| {
        sum += n;
    }

    try testing.expectEqual(@as(i32, 6), sum);
}

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

// Summary:
// - if conditions must be bool (no truthy/falsy)
// - if is an expression (returns a value)
// - switch must be exhaustive (all cases covered)
// - switch is an expression (most common use)
// - while loops have optional continue expressions
// - for loops iterate arrays, slices, and ranges
// - Use labeled blocks for nested loop control
// - break exits loops, continue skips to next iteration
// - Labels let you break/continue outer loops from inner loops
