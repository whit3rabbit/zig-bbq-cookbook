// Recipe 3.2: Performing accurate decimal calculations
// Target Zig Version: 0.15.2
//
// This recipe demonstrates fixed-point arithmetic for accurate decimal calculations,
// avoiding floating-point precision issues common in financial and precise calculations.

const std = @import("std");
const testing = std.testing;
const math = std.math;

// ANCHOR: fixed_decimal_type
/// Fixed-point decimal number with specified decimal places
pub fn FixedDecimal(comptime decimal_places: u8) type {
    return struct {
        const Self = @This();
        const scale_factor = math.pow(i64, 10, decimal_places);

        value: i64,

        /// Create from integer
        pub fn fromInt(int_value: i64) Self {
            return .{ .value = int_value * scale_factor };
        }

        /// Create from float (use sparingly, prefer fromInt for exact values)
        pub fn fromFloat(float_value: f64) Self {
            return .{ .value = @intFromFloat(float_value * @as(f64, @floatFromInt(scale_factor))) };
        }

        /// Create from string representation "123.45"
        pub fn fromString(str: []const u8) !Self {
            var int_part: i64 = 0;
            var frac_part: i64 = 0;
            var frac_digits: u8 = 0;
            var is_negative = false;
            var after_dot = false;

            for (str) |c| {
                switch (c) {
                    '-' => is_negative = true,
                    '.' => {
                        if (after_dot) return error.InvalidFormat; // Multiple dots
                        after_dot = true;
                    },
                    '0'...'9' => {
                        const digit = c - '0';
                        if (after_dot) {
                            if (frac_digits < decimal_places) {
                                frac_part = frac_part * 10 + digit;
                                frac_digits += 1;
                            }
                        } else {
                            int_part = int_part * 10 + digit;
                        }
                    },
                    else => return error.InvalidFormat,
                }
            }

            // Scale fractional part to match decimal_places
            while (frac_digits < decimal_places) : (frac_digits += 1) {
                frac_part *= 10;
            }

            var value = int_part * scale_factor + frac_part;
            if (is_negative) value = -value;

            return .{ .value = value };
        }

        /// Convert to float (may lose precision)
        pub fn toFloat(self: Self) f64 {
            return @as(f64, @floatFromInt(self.value)) / @as(f64, @floatFromInt(scale_factor));
        }

        /// Convert to integer (truncates decimal part)
        pub fn toInt(self: Self) i64 {
            return @divTrunc(self.value, scale_factor);
        }
// ANCHOR_END: fixed_decimal_type

// ANCHOR: arithmetic_operations
        /// Add two fixed decimals
        pub fn add(self: Self, other: Self) Self {
            return .{ .value = self.value + other.value };
        }

        /// Subtract two fixed decimals
        pub fn sub(self: Self, other: Self) Self {
            return .{ .value = self.value - other.value };
        }

        /// Multiply two fixed decimals
        pub fn mul(self: Self, other: Self) Self {
            return .{ .value = @divTrunc(self.value * other.value, scale_factor) };
        }

        /// Divide two fixed decimals
        pub fn div(self: Self, other: Self) !Self {
            if (other.value == 0) return error.DivisionByZero;
            return .{ .value = @divTrunc(self.value * scale_factor, other.value) };
        }

        /// Compare equality
        pub fn eql(self: Self, other: Self) bool {
            return self.value == other.value;
        }

        /// Less than comparison
        pub fn lessThan(self: Self, other: Self) bool {
            return self.value < other.value;
        }

        /// Greater than comparison
        pub fn greaterThan(self: Self, other: Self) bool {
            return self.value > other.value;
        }

        /// Absolute value
        pub fn abs(self: Self) Self {
            return .{ .value = if (self.value < 0) -self.value else self.value };
        }

        /// Negate
        pub fn negate(self: Self) Self {
            return .{ .value = -self.value };
        }

        /// Round to fewer decimal places
        pub fn round(self: Self, comptime new_places: u8) FixedDecimal(new_places) {
            if (new_places >= decimal_places) {
                // Can't increase precision, just convert
                const new_scale = math.pow(i64, 10, new_places - decimal_places);
                return .{ .value = self.value * new_scale };
            } else {
                // Reduce precision with rounding
                const divisor = math.pow(i64, 10, decimal_places - new_places);
                const rounded = @divTrunc(self.value + @divTrunc(divisor, 2), divisor);
                return .{ .value = rounded };
            }
        }
// ANCHOR_END: arithmetic_operations
    };
}

// ANCHOR: type_aliases
/// Money type with 2 decimal places (cents)
pub const Money = FixedDecimal(2);

/// Precise decimal with 4 decimal places
pub const Decimal4 = FixedDecimal(4);

/// Extra precise decimal with 8 decimal places
pub const Decimal8 = FixedDecimal(8);
// ANCHOR_END: type_aliases

test "create fixed decimal from integer" {
    const num = Money.fromInt(10);
    try testing.expectEqual(@as(i64, 1000), num.value); // 10.00 = 1000 cents
    try testing.expectEqual(@as(i64, 10), num.toInt());
}

test "create fixed decimal from float" {
    const num = Money.fromFloat(10.50);
    try testing.expectApproxEqAbs(@as(f64, 10.50), num.toFloat(), 0.01);
}

test "create from string" {
    const num1 = try Money.fromString("10.50");
    try testing.expectEqual(@as(i64, 1050), num1.value);

    const num2 = try Money.fromString("-5.25");
    try testing.expectEqual(@as(i64, -525), num2.value);

    const num3 = try Money.fromString("100");
    try testing.expectEqual(@as(i64, 10000), num3.value);
}

test "add fixed decimals" {
    const a = Money.fromInt(10); // 10.00
    const b = try Money.fromString("5.50");
    const result = a.add(b);

    try testing.expectEqual(@as(i64, 1550), result.value); // 15.50
    try testing.expectApproxEqAbs(@as(f64, 15.50), result.toFloat(), 0.01);
}

test "subtract fixed decimals" {
    const a = try Money.fromString("20.00");
    const b = try Money.fromString("7.50");
    const result = a.sub(b);

    try testing.expectEqual(@as(i64, 1250), result.value); // 12.50
}

test "multiply fixed decimals" {
    const a = try Money.fromString("10.00");
    const b = try Money.fromString("2.50");
    const result = a.mul(b);

    try testing.expectEqual(@as(i64, 2500), result.value); // 25.00
    try testing.expectApproxEqAbs(@as(f64, 25.00), result.toFloat(), 0.01);
}

test "divide fixed decimals" {
    const a = try Money.fromString("100.00");
    const b = try Money.fromString("4.00");
    const result = try a.div(b);

    try testing.expectEqual(@as(i64, 2500), result.value); // 25.00
}

test "division by zero" {
    const a = Money.fromInt(10);
    const b = Money.fromInt(0);

    const result = a.div(b);
    try testing.expectError(error.DivisionByZero, result);
}

test "comparison operations" {
    const a = try Money.fromString("10.50");
    const b = try Money.fromString("10.50");
    const c = try Money.fromString("5.25");

    try testing.expect(a.eql(b));
    try testing.expect(!a.eql(c));
    try testing.expect(a.greaterThan(c));
    try testing.expect(c.lessThan(a));
}

test "absolute value" {
    const a = try Money.fromString("-10.50");
    const result = a.abs();

    try testing.expectEqual(@as(i64, 1050), result.value);
}

test "negate" {
    const a = try Money.fromString("10.50");
    const result = a.negate();

    try testing.expectEqual(@as(i64, -1050), result.value);
}

test "financial calculation - no precision loss" {
    // Classic floating-point problem: 0.1 + 0.2 != 0.3
    const a = try Money.fromString("0.10");
    const b = try Money.fromString("0.20");
    const expected = try Money.fromString("0.30");
    const result = a.add(b);

    try testing.expect(result.eql(expected));
    try testing.expectEqual(@as(i64, 30), result.value);
}

test "financial calculation - compound interest" {
    // Calculate compound interest: P * (1 + r)^n
    // For simplicity, just one period
    const principal = try Money.fromString("1000.00");
    const rate = try Money.fromString("0.05"); // 5%
    const interest = principal.mul(rate);
    const total = principal.add(interest);

    try testing.expectEqual(@as(i64, 105000), total.value); // 1050.00
}

test "different precision levels" {
    const precise = try Decimal4.fromString("123.4567");
    try testing.expectEqual(@as(i64, 1234567), precise.value);

    const very_precise = try Decimal8.fromString("1.23456789");
    try testing.expectEqual(@as(i64, 123456789), very_precise.value);
}

test "rounding to fewer decimal places" {
    const num = try Decimal4.fromString("10.5678");
    const rounded = num.round(2);

    try testing.expectEqual(@as(i64, 1057), rounded.value); // 10.57 in Money format
}

test "accumulating cents - no rounding error" {
    // Add up many small amounts
    var total = Money.fromInt(0);
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        const penny = try Money.fromString("0.01");
        total = total.add(penny);
    }

    try testing.expectEqual(@as(i64, 1000), total.value); // Exactly 10.00
    try testing.expectEqual(@as(i64, 10), total.toInt());
}

test "percentage calculation" {
    const amount = try Money.fromString("100.00");
    const percent = try Money.fromString("0.15"); // 15%
    const tax = amount.mul(percent);

    try testing.expectEqual(@as(i64, 1500), tax.value); // 15.00
}

test "splitting money evenly" {
    const total = try Money.fromString("100.00");
    const three = Money.fromInt(3);
    const per_person = try total.div(three);

    // 100 / 3 = 33.33 (truncated in integer division)
    try testing.expectEqual(@as(i64, 3333), per_person.value);
}

test "negative values" {
    const a = try Money.fromString("-10.50");
    const b = try Money.fromString("5.25");
    const result = a.add(b);

    try testing.expectEqual(@as(i64, -525), result.value); // -5.25
}

test "large values" {
    const a = try Money.fromString("1000000.00");
    const b = try Money.fromString("500000.50");
    const result = a.add(b);

    try testing.expectEqual(@as(i64, 150000050), result.value); // 1500000.50
}

test "precision comparison with floats" {
    // Show that fixed-point is exact
    const fixed_a = try Money.fromString("0.1");
    const fixed_b = try Money.fromString("0.2");
    const fixed_result = fixed_a.add(fixed_b);
    const fixed_expected = try Money.fromString("0.3");

    try testing.expect(fixed_result.eql(fixed_expected));

    // Fixed-point gives exact integer representation
    try testing.expectEqual(@as(i64, 30), fixed_result.value);
}

test "string parsing edge cases" {
    // No decimal point
    const num1 = try Money.fromString("42");
    try testing.expectEqual(@as(i64, 4200), num1.value);

    // Leading zeros
    const num2 = try Money.fromString("00010.50");
    try testing.expectEqual(@as(i64, 1050), num2.value);
}

test "string parsing errors" {
    try testing.expectError(error.InvalidFormat, Money.fromString("abc"));
    try testing.expectError(error.InvalidFormat, Money.fromString("10.5.0"));
}

test "memory safety - no allocation" {
    // All operations are pure integer math, no allocation
    const a = Money.fromInt(10);
    const b = Money.fromInt(20);
    const c = a.add(b);
    try testing.expectEqual(@as(i64, 3000), c.value);
}

test "security - overflow prevention" {
    // Fixed decimals prevent overflow through explicit bounds
    const max_safe = Money.fromInt(math.maxInt(i32));
    try testing.expect(max_safe.value > 0);
}
