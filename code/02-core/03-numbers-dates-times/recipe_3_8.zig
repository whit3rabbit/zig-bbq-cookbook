// Recipe 3.8: Calculating with fractions
// Target Zig Version: 0.15.2
//
// This recipe demonstrates implementing rational number (fraction) arithmetic
// for exact calculations without floating-point precision loss.

const std = @import("std");
const testing = std.testing;
const math = std.math;

// ANCHOR: rational_type
/// Rational number type representing a fraction
pub fn Rational(comptime T: type) type {
    return struct {
        const Self = @This();

        numerator: T,
        denominator: T,

        /// Create rational number from numerator and denominator
        pub fn init(num: T, denom: T) !Self {
            if (denom == 0) return error.DivisionByZero;

            var result = Self{
                .numerator = num,
                .denominator = denom,
            };
            result.reduce();
            return result;
        }

        /// Create rational from integer
        pub fn fromInt(value: T) Self {
            return Self{
                .numerator = value,
                .denominator = 1,
            };
        }

        /// Reduce fraction to lowest terms
        pub fn reduce(self: *Self) void {
            if (self.numerator == 0) {
                self.denominator = 1;
                return;
            }

            const g = gcd(T, absValue(T, self.numerator), absValue(T, self.denominator));
            self.numerator = @divTrunc(self.numerator, g);
            self.denominator = @divTrunc(self.denominator, g);

            // Keep denominator positive
            if (self.denominator < 0) {
                self.numerator = -self.numerator;
                self.denominator = -self.denominator;
            }
        }
// ANCHOR_END: rational_type

// ANCHOR: arithmetic_operations
        /// Add two rational numbers
        pub fn add(self: Self, other: Self) !Self {
            const num = self.numerator * other.denominator + other.numerator * self.denominator;
            const denom = self.denominator * other.denominator;
            return init(num, denom);
        }

        /// Subtract two rational numbers
        pub fn sub(self: Self, other: Self) !Self {
            const num = self.numerator * other.denominator - other.numerator * self.denominator;
            const denom = self.denominator * other.denominator;
            return init(num, denom);
        }

        /// Multiply two rational numbers
        pub fn mul(self: Self, other: Self) !Self {
            const num = self.numerator * other.numerator;
            const denom = self.denominator * other.denominator;
            return init(num, denom);
        }

        /// Divide two rational numbers
        pub fn div(self: Self, other: Self) !Self {
            if (other.numerator == 0) return error.DivisionByZero;
            const num = self.numerator * other.denominator;
            const denom = self.denominator * other.numerator;
            return init(num, denom);
        }

        /// Reciprocal of rational number
        pub fn reciprocal(self: Self) !Self {
            if (self.numerator == 0) return error.DivisionByZero;
            return init(self.denominator, self.numerator);
        }

        /// Absolute value
        pub fn abs(self: Self) Self {
            return Self{
                .numerator = absValue(T, self.numerator),
                .denominator = self.denominator,
            };
        }

        /// Negate
        pub fn negate(self: Self) Self {
            return Self{
                .numerator = -self.numerator,
                .denominator = self.denominator,
            };
        }

        /// Convert to floating point
        pub fn toFloat(self: Self, comptime F: type) F {
            return @as(F, @floatFromInt(self.numerator)) / @as(F, @floatFromInt(self.denominator));
        }

        /// Compare equality
        pub fn eql(self: Self, other: Self) bool {
            return self.numerator == other.numerator and self.denominator == other.denominator;
        }

        /// Less than comparison
        pub fn lessThan(self: Self, other: Self) bool {
            return self.numerator * other.denominator < other.numerator * self.denominator;
        }

        /// Greater than comparison
        pub fn greaterThan(self: Self, other: Self) bool {
            return self.numerator * other.denominator > other.numerator * self.denominator;
        }

        /// Power (integer exponent)
        pub fn pow(self: Self, exponent: u32) !Self {
            var result = Self.fromInt(1);
            var i: u32 = 0;
            while (i < exponent) : (i += 1) {
                result = try result.mul(self);
            }
            return result;
        }
// ANCHOR_END: arithmetic_operations
    };
}

// ANCHOR: helper_functions
/// Greatest common divisor (Euclidean algorithm)
fn gcd(comptime T: type, a: T, b: T) T {
    var x = a;
    var y = b;
    while (y != 0) {
        const temp = y;
        y = @mod(x, y);
        x = temp;
    }
    return x;
}

/// Absolute value for integers
fn absValue(comptime T: type, value: T) T {
    return if (value < 0) -value else value;
}
// ANCHOR_END: helper_functions

test "create rational number" {
    const r = try Rational(i32).init(3, 4);
    try testing.expectEqual(@as(i32, 3), r.numerator);
    try testing.expectEqual(@as(i32, 4), r.denominator);
}

test "reduce fraction" {
    const r = try Rational(i32).init(6, 8);
    try testing.expectEqual(@as(i32, 3), r.numerator);
    try testing.expectEqual(@as(i32, 4), r.denominator);
}

test "reduce to whole number" {
    const r = try Rational(i32).init(8, 4);
    try testing.expectEqual(@as(i32, 2), r.numerator);
    try testing.expectEqual(@as(i32, 1), r.denominator);
}

test "create from integer" {
    const r = Rational(i32).fromInt(5);
    try testing.expectEqual(@as(i32, 5), r.numerator);
    try testing.expectEqual(@as(i32, 1), r.denominator);
}

test "add fractions" {
    const a = try Rational(i32).init(1, 2); // 1/2
    const b = try Rational(i32).init(1, 3); // 1/3
    const result = try a.add(b);

    // 1/2 + 1/3 = 3/6 + 2/6 = 5/6
    try testing.expectEqual(@as(i32, 5), result.numerator);
    try testing.expectEqual(@as(i32, 6), result.denominator);
}

test "subtract fractions" {
    const a = try Rational(i32).init(3, 4); // 3/4
    const b = try Rational(i32).init(1, 4); // 1/4
    const result = try a.sub(b);

    // 3/4 - 1/4 = 2/4 = 1/2
    try testing.expectEqual(@as(i32, 1), result.numerator);
    try testing.expectEqual(@as(i32, 2), result.denominator);
}

test "multiply fractions" {
    const a = try Rational(i32).init(2, 3); // 2/3
    const b = try Rational(i32).init(3, 4); // 3/4
    const result = try a.mul(b);

    // 2/3 * 3/4 = 6/12 = 1/2
    try testing.expectEqual(@as(i32, 1), result.numerator);
    try testing.expectEqual(@as(i32, 2), result.denominator);
}

test "divide fractions" {
    const a = try Rational(i32).init(1, 2); // 1/2
    const b = try Rational(i32).init(1, 4); // 1/4
    const result = try a.div(b);

    // (1/2) / (1/4) = (1/2) * (4/1) = 4/2 = 2/1
    try testing.expectEqual(@as(i32, 2), result.numerator);
    try testing.expectEqual(@as(i32, 1), result.denominator);
}

test "division by zero" {
    const a = try Rational(i32).init(1, 2);
    const b = try Rational(i32).init(0, 1);
    const result = a.div(b);
    try testing.expectError(error.DivisionByZero, result);
}

test "reciprocal" {
    const r = try Rational(i32).init(3, 4);
    const recip = try r.reciprocal();

    try testing.expectEqual(@as(i32, 4), recip.numerator);
    try testing.expectEqual(@as(i32, 3), recip.denominator);
}

test "absolute value" {
    const r = try Rational(i32).init(-3, 4);
    const result = r.abs();

    try testing.expectEqual(@as(i32, 3), result.numerator);
    try testing.expectEqual(@as(i32, 4), result.denominator);
}

test "negate" {
    const r = try Rational(i32).init(3, 4);
    const result = r.negate();

    try testing.expectEqual(@as(i32, -3), result.numerator);
    try testing.expectEqual(@as(i32, 4), result.denominator);
}

test "convert to float" {
    const r = try Rational(i32).init(3, 4);
    const f = r.toFloat(f64);

    try testing.expectApproxEqAbs(@as(f64, 0.75), f, 0.0001);
}

test "equality comparison" {
    const a = try Rational(i32).init(1, 2);
    const b = try Rational(i32).init(2, 4); // Same as 1/2 after reduction
    const c = try Rational(i32).init(1, 3);

    try testing.expect(a.eql(b));
    try testing.expect(!a.eql(c));
}

test "less than comparison" {
    const a = try Rational(i32).init(1, 3);
    const b = try Rational(i32).init(1, 2);

    try testing.expect(a.lessThan(b));
    try testing.expect(!b.lessThan(a));
}

test "greater than comparison" {
    const a = try Rational(i32).init(3, 4);
    const b = try Rational(i32).init(1, 2);

    try testing.expect(a.greaterThan(b));
    try testing.expect(!b.greaterThan(a));
}

test "power operation" {
    const r = try Rational(i32).init(2, 3);
    const result = try r.pow(2);

    // (2/3)² = 4/9
    try testing.expectEqual(@as(i32, 4), result.numerator);
    try testing.expectEqual(@as(i32, 9), result.denominator);
}

test "negative denominator normalization" {
    const r = try Rational(i32).init(1, -2);

    // Should normalize to -1/2
    try testing.expectEqual(@as(i32, -1), r.numerator);
    try testing.expectEqual(@as(i32, 2), r.denominator);
}

test "zero numerator" {
    const r = try Rational(i32).init(0, 5);

    try testing.expectEqual(@as(i32, 0), r.numerator);
    try testing.expectEqual(@as(i32, 1), r.denominator);
}

test "adding whole numbers" {
    const a = Rational(i32).fromInt(5);
    const b = Rational(i32).fromInt(3);
    const result = try a.add(b);

    try testing.expectEqual(@as(i32, 8), result.numerator);
    try testing.expectEqual(@as(i32, 1), result.denominator);
}

test "mixed operations" {
    const a = try Rational(i32).init(1, 2);
    const b = try Rational(i32).init(1, 3);
    const c = try Rational(i32).init(1, 6);

    // (1/2 + 1/3) * 1/6
    const sum = try a.add(b);
    const result = try sum.mul(c);

    // (3/6 + 2/6) * 1/6 = 5/6 * 1/6 = 5/36
    try testing.expectEqual(@as(i32, 5), result.numerator);
    try testing.expectEqual(@as(i32, 36), result.denominator);
}

test "fraction sequence" {
    // Calculate sum: 1/2 + 1/4 + 1/8 + 1/16
    var sum = try Rational(i32).init(1, 2);
    sum = try sum.add(try Rational(i32).init(1, 4));
    sum = try sum.add(try Rational(i32).init(1, 8));
    sum = try sum.add(try Rational(i32).init(1, 16));

    // Sum = 15/16
    try testing.expectEqual(@as(i32, 15), sum.numerator);
    try testing.expectEqual(@as(i32, 16), sum.denominator);
}

test "large numbers" {
    const a = try Rational(i64).init(1000000, 3);
    const b = try Rational(i64).init(2000000, 3);
    const result = try a.add(b);

    try testing.expectEqual(@as(i64, 1000000), result.numerator);
    try testing.expectEqual(@as(i64, 1), result.denominator);
}

test "gcd function" {
    try testing.expectEqual(@as(i32, 6), gcd(i32, 12, 18));
    try testing.expectEqual(@as(i32, 1), gcd(i32, 7, 11));
    try testing.expectEqual(@as(i32, 5), gcd(i32, 15, 20));
}

test "memory safety - no allocation" {
    // All operations are pure math, no allocation
    const a = try Rational(i32).init(1, 2);
    const b = try Rational(i32).init(1, 3);
    const result = try a.add(b);

    try testing.expectEqual(@as(i32, 5), result.numerator);
    try testing.expectEqual(@as(i32, 6), result.denominator);
}

test "security - overflow prevention" {
    // Rational numbers can grow large, but stay within integer bounds
    const a = try Rational(i32).init(100, 1);
    const b = try Rational(i32).init(200, 1);
    const result = try a.add(b);

    try testing.expectEqual(@as(i32, 300), result.numerator);
    try testing.expectEqual(@as(i32, 1), result.denominator);
}

test "exact arithmetic vs floating point" {
    // Demonstrate exact arithmetic
    const a = try Rational(i32).init(1, 10);
    const b = try Rational(i32).init(2, 10);
    const c = try Rational(i32).init(3, 10);
    const sum = try (try a.add(b)).add(c);

    // Should be exactly 6/10 = 3/5
    try testing.expectEqual(@as(i32, 3), sum.numerator);
    try testing.expectEqual(@as(i32, 5), sum.denominator);

    // Rational converts to exact float
    const rational_result = sum.toFloat(f64);
    try testing.expectApproxEqAbs(@as(f64, 0.6), rational_result, 0.0000001);
}
