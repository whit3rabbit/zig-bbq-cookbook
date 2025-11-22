// Recipe 0.4: Variables, Constants, and Type Inference
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to declare variables and constants,
// understand mutability, and work with type inference.

const std = @import("std");
const testing = std.testing;

// ANCHOR: const_vs_var
// Constants vs Variables
//
// Zig has two ways to declare values:
// - `const` for values that never change (immutable)
// - `var` for values that can change (mutable)
//
// The Zig philosophy: use `const` by default, `var` only when needed.

test "const values cannot be changed" {
    const x = 42;

    // This would cause a compile error:
    // x = 43;  // error: cannot assign to constant

    try testing.expectEqual(@as(i32, 42), x);
}

test "var values can be changed" {
    var x: i32 = 42;

    // This is allowed because x is var
    x = 43;

    try testing.expectEqual(@as(i32, 43), x);
}

test "const by default" {
    // Coming from other languages, you might think var is the default
    // In Zig, think const-first

    const name = "Alice"; // Won't change
    const age = 30; // Won't change
    var score: i32 = 0; // Will change

    score += 10;
    score += 5;

    try testing.expect(name.len > 0);
    try testing.expectEqual(@as(i32, 30), age);
    try testing.expectEqual(@as(i32, 15), score);
}

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
// ANCHOR_END: const_vs_var

// ANCHOR: type_inference
// Type Inference
//
// Zig can often figure out types automatically, but you can also
// specify them explicitly when needed.

test "type inference basics" {
    // Zig infers the type from the value
    const x = 42; // Inferred as comptime_int
    const y = 3.14; // Inferred as comptime_float
    const z = true; // Inferred as bool
    const s = "hello"; // Inferred as *const [5:0]u8

    // Comptime integers are flexible
    try testing.expectEqual(42, x);
    try testing.expectEqual(3.14, y);
    try testing.expectEqual(true, z);
    try testing.expect(s.len == 5);
}

test "explicit type annotations" {
    // Sometimes you need to be explicit
    const x: i32 = 42; // Explicitly i32
    const y: u64 = 100; // Explicitly u64
    const z: f64 = 3.14; // Explicitly f64

    try testing.expectEqual(@as(i32, 42), x);
    try testing.expectEqual(@as(u64, 100), y);
    try testing.expectEqual(@as(f64, 3.14), z);
}

test "when type inference needs help" {
    // Empty array needs type hint
    // const arr = [];  // error: unable to infer type

    const arr: [0]i32 = [_]i32{}; // Explicit type
    try testing.expectEqual(@as(usize, 0), arr.len);

    // Function calls sometimes need type hints
    const list = std.ArrayList(i32){}; // Type parameter required
    try testing.expectEqual(@as(usize, 0), list.items.len);
}

test "type inference with operations" {
    // When you mix types, you might need to be explicit
    const a: i32 = 10;
    const b: i64 = 20;

    // This won't compile:
    // const sum = a + b;  // error: mismatched types

    // Be explicit about the conversion:
    const sum: i64 = @as(i64, a) + b;
    try testing.expectEqual(@as(i64, 30), sum);
}
// ANCHOR_END: type_inference

// ANCHOR: type_casting
// Type Casting and Conversion
//
// Zig doesn't do implicit type conversions. You must be explicit.

test "explicit type casting with @as" {
    // @as performs type casting
    const x: i32 = 42;
    const y: i64 = @as(i64, x); // Cast i32 to i64

    try testing.expectEqual(@as(i64, 42), y);
}

test "integer type conversions" {
    const small: i8 = 42;

    // Widening (safe)
    const big: i32 = @as(i32, small);
    try testing.expectEqual(@as(i32, 42), big);

    // Narrowing (potentially unsafe, checked in debug)
    const value: i32 = 127;
    const narrow: i8 = @intCast(value); // Checked cast
    try testing.expectEqual(@as(i8, 127), narrow);

    // This would panic in debug mode:
    // const too_big: i32 = 999;
    // const overflow: i8 = @intCast(too_big);  // panic!
}

test "float conversions" {
    const f32_val: f32 = 3.14;
    const f64_val: f64 = @as(f64, f32_val);

    // Float precision: f32 has less precision than f64
    // so we check the f64 value is close enough
    try testing.expect(@abs(f64_val - 3.14) < 0.01);

    // Float to int (truncates)
    const float: f32 = 3.99;
    const int: i32 = @intFromFloat(float);
    try testing.expectEqual(@as(i32, 3), int); // Truncated, not rounded
}

test "unsigned and signed conversions" {
    const unsigned: u32 = 42;
    const signed: i32 = @intCast(unsigned);

    try testing.expectEqual(@as(i32, 42), signed);

    // Use @bitCast for reinterpretation (advanced)
    const bits: u32 = @bitCast(signed);
    try testing.expectEqual(@as(u32, 42), bits);

    // Be careful with negative numbers and unsigned types
    // const neg: i32 = -5;
    // const wrong: u32 = @intCast(neg);  // Would panic in debug!
}

test "comptime_int to specific type" {
    // Literal integers are comptime_int by default
    const x = 42; // comptime_int

    // They automatically convert to compatible types
    const i8_val: i8 = x;
    const i32_val: i32 = x;
    const u64_val: u64 = x;

    try testing.expectEqual(@as(i8, 42), i8_val);
    try testing.expectEqual(@as(i32, 42), i32_val);
    try testing.expectEqual(@as(u64, 42), u64_val);

    // But only if the value fits
    // const too_big: i8 = 999;  // error: value doesn't fit
}
// ANCHOR_END: type_casting

// Additional examples

test "undefined and uninitialized values" {
    // You can declare without initializing using undefined
    var x: i32 = undefined;

    // But reading it before assignment is undefined behavior
    // try testing.expectEqual(0, x);  // DON'T DO THIS

    // Initialize before using
    x = 42;
    try testing.expectEqual(@as(i32, 42), x);
}

test "multiple declarations" {
    // You can declare multiple values in one line with destructuring
    const a, const b, const c = .{ 1, 2, 3 };

    try testing.expectEqual(@as(i32, 1), a);
    try testing.expectEqual(@as(i32, 2), b);
    try testing.expectEqual(@as(i32, 3), c);
}

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

// Summary:
// - Use `const` by default, `var` only when values change
// - Zig infers types when possible, but you can be explicit
// - No implicit type conversions - use @as, @intCast, @intFromFloat
// - Comptime integers are flexible until assigned to a specific type
// - Use `undefined` for delayed initialization, but assign before reading
