// Recipe 0.5: Primitive Data and Basic Arrays
// Target Zig Version: 0.15.2
//
// This recipe demonstrates Zig's primitive types (integers, floats, booleans)
// and basic fixed-size arrays.

const std = @import("std");
const testing = std.testing;

// ANCHOR: integer_types
// Integer Types
//
// Zig has explicit integer types with specific sizes.
// Unlike C where `int` size varies by platform, Zig is explicit.
//
// Signed: i8, i16, i32, i64, i128
// Unsigned: u8, u16, u32, u64, u128
// Platform-specific: isize, usize (pointer-sized)

test "signed integers" {
    const tiny: i8 = -128; // 8-bit signed (-128 to 127)
    const small: i16 = -32_768; // 16-bit signed
    const medium: i32 = -2_147_483_648; // 32-bit signed
    const large: i64 = -9_223_372_036_854_775_808; // 64-bit signed

    try testing.expectEqual(@as(i8, -128), tiny);
    try testing.expectEqual(@as(i16, -32_768), small);
    try testing.expectEqual(@as(i32, -2_147_483_648), medium);
    try testing.expectEqual(@as(i64, -9_223_372_036_854_775_808), large);
}

test "unsigned integers" {
    const byte: u8 = 255; // 8-bit unsigned (0 to 255)
    const word: u16 = 65_535; // 16-bit unsigned
    const dword: u32 = 4_294_967_295; // 32-bit unsigned
    const qword: u64 = 18_446_744_073_709_551_615; // 64-bit unsigned

    try testing.expectEqual(@as(u8, 255), byte);
    try testing.expectEqual(@as(u16, 65_535), word);
    try testing.expectEqual(@as(u32, 4_294_967_295), dword);
    try testing.expectEqual(@as(u64, 18_446_744_073_709_551_615), qword);
}

test "pointer-sized integers" {
    // usize and isize are the size of a pointer on your platform
    // On 64-bit: usize = u64, isize = i64
    // On 32-bit: usize = u32, isize = i32

    const index: usize = 0; // Use for array indices
    const offset: isize = -5; // Use for pointer arithmetic

    try testing.expect(index == 0);
    try testing.expect(offset == -5);

    // usize is commonly used for lengths and indices
    const arr = [_]i32{ 1, 2, 3 };
    const len: usize = arr.len;
    try testing.expectEqual(@as(usize, 3), len);
}

test "arbitrary bit-width integers" {
    // Zig supports integers of any bit width
    const i3_val: i3 = -4; // 3-bit signed (-4 to 3)
    const u7_val: u7 = 127; // 7-bit unsigned (0 to 127)
    const i33_val: i33 = 0; // 33-bit signed

    try testing.expectEqual(@as(i3, -4), i3_val);
    try testing.expectEqual(@as(u7, 127), u7_val);
    try testing.expectEqual(@as(i33, 0), i33_val);
}

test "integer literals and underscores" {
    // Use underscores for readability (like commas in numbers)
    const million: i32 = 1_000_000;
    const byte_value: u8 = 0xFF; // Hexadecimal
    const binary: u8 = 0b1111_0000; // Binary
    const octal: u16 = 0o755; // Octal (755 in base 8 = 493 in base 10)

    try testing.expectEqual(@as(i32, 1_000_000), million);
    try testing.expectEqual(@as(u8, 255), byte_value);
    try testing.expectEqual(@as(u8, 240), binary);
    try testing.expectEqual(@as(u16, 493), octal);
}
// ANCHOR_END: integer_types

// ANCHOR: float_types
// Floating Point Types
//
// Zig has two float types: f32 and f64
// Plus f16 and f128 on some platforms

test "float types" {
    const small: f32 = 3.14; // 32-bit float (single precision)
    const large: f64 = 2.718281828; // 64-bit float (double precision)

    try testing.expect(small > 3.0 and small < 3.2);
    try testing.expect(large > 2.7 and large < 2.8);
}

test "float literals" {
    const scientific: f64 = 1.23e10; // Scientific notation
    const tiny: f64 = 1.23e-10;

    try testing.expect(scientific > 1e10);
    try testing.expect(tiny < 1e-9);
}

test "float operations" {
    const x: f32 = 10.5;
    const y: f32 = 2.5;

    const sum = x + y;
    const product = x * y;
    const quotient = x / y;

    try testing.expectEqual(@as(f32, 13.0), sum);
    try testing.expectEqual(@as(f32, 26.25), product);
    try testing.expectEqual(@as(f32, 4.2), quotient);
}

test "special float values" {
    // Infinity and NaN are available
    const inf = std.math.inf(f64);
    const neg_inf = -std.math.inf(f64);
    const nan = std.math.nan(f64);

    try testing.expect(std.math.isInf(inf));
    try testing.expect(std.math.isInf(neg_inf));
    try testing.expect(std.math.isNan(nan));
}
// ANCHOR_END: float_types

// ANCHOR: fixed_arrays
// Fixed-Size Arrays
//
// Arrays in Zig have compile-time known size: [N]T
// The size is part of the type!

test "basic array declaration" {
    // Declare and initialize array
    const numbers = [5]i32{ 1, 2, 3, 4, 5 };

    try testing.expectEqual(@as(usize, 5), numbers.len);
    try testing.expectEqual(@as(i32, 1), numbers[0]);
    try testing.expectEqual(@as(i32, 5), numbers[4]);
}

test "array type inference" {
    // Use [_] to let Zig infer the size
    const inferred = [_]i32{ 10, 20, 30 };

    try testing.expectEqual(@as(usize, 3), inferred.len);
    try testing.expectEqual(@as(i32, 10), inferred[0]);
}

test "array initialization patterns" {
    // All zeros
    const zeros = [_]i32{0} ** 5; // [0, 0, 0, 0, 0]
    try testing.expectEqual(@as(i32, 0), zeros[0]);
    try testing.expectEqual(@as(i32, 0), zeros[4]);

    // Repeat a pattern
    const pattern = [_]i32{ 1, 2 } ** 3; // [1, 2, 1, 2, 1, 2]
    try testing.expectEqual(@as(usize, 6), pattern.len);
    try testing.expectEqual(@as(i32, 1), pattern[0]);
    try testing.expectEqual(@as(i32, 2), pattern[1]);
    try testing.expectEqual(@as(i32, 1), pattern[2]);
}

test "multidimensional arrays" {
    // Arrays of arrays
    const matrix = [3][3]i32{
        [_]i32{ 1, 2, 3 },
        [_]i32{ 4, 5, 6 },
        [_]i32{ 7, 8, 9 },
    };

    try testing.expectEqual(@as(i32, 1), matrix[0][0]);
    try testing.expectEqual(@as(i32, 5), matrix[1][1]);
    try testing.expectEqual(@as(i32, 9), matrix[2][2]);
}

test "modifying array elements" {
    var mutable = [_]i32{ 1, 2, 3 };

    // Can modify elements of var array
    mutable[0] = 10;
    mutable[1] = 20;

    try testing.expectEqual(@as(i32, 10), mutable[0]);
    try testing.expectEqual(@as(i32, 20), mutable[1]);
}

test "array iteration" {
    const values = [_]i32{ 10, 20, 30, 40, 50 };

    // Iterate with for loop
    var sum: i32 = 0;
    for (values) |value| {
        sum += value;
    }

    try testing.expectEqual(@as(i32, 150), sum);
}

test "array bounds are checked" {
    const arr = [_]i32{ 1, 2, 3 };

    // This is fine
    const first = arr[0];
    try testing.expectEqual(@as(i32, 1), first);

    // This would panic at runtime (in debug mode):
    // const oob = arr[10];  // Index out of bounds!
}

test "string literals are arrays" {
    // String literals are arrays of bytes with null terminator
    const hello: *const [5:0]u8 = "hello";
    // *const = pointer to const
    // [5:0] = array of 5 bytes with 0 terminator (sentinel)
    // u8 = unsigned 8-bit integer (byte)

    try testing.expectEqual(@as(usize, 5), hello.len);
    try testing.expectEqual(@as(u8, 'h'), hello[0]);
    try testing.expectEqual(@as(u8, 'o'), hello[4]);
}

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

test "void type" {
    // void means "no value"
    // Functions that return nothing return void

    const nothing: void = {};
    _ = nothing; // Suppress unused variable warning

    // Common use: functions that perform actions but return nothing
    // fn doSomething() void { }
}
// ANCHOR_END: fixed_arrays

// Summary:
// - Zig has explicit integer types: i8, i16, i32, i64, u8, u16, u32, u64
// - Use usize for array indices and lengths
// - Floats: f32 (single) and f64 (double precision)
// - Fixed arrays have compile-time size: [N]T
// - Array size is part of the type
// - Use [_] for size inference
// - Bounds checking happens in debug mode
// - String literals are sentinel-terminated byte arrays
