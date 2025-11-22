// Recipe 3.3: Formatting numbers for output
// Target Zig Version: 0.15.2
//
// This recipe demonstrates various ways to format numbers for output using
// Zig's std.fmt formatting capabilities for integers and floating-point numbers.

const std = @import("std");
const testing = std.testing;
const fmt = std.fmt;
const mem = std.mem;

// ANCHOR: basic_formatting
/// Format integer with thousands separator
pub fn formatWithSeparator(
    allocator: mem.Allocator,
    value: i64,
    separator: u8,
) ![]u8 {
    const abs_value = if (value < 0) -value else value;
    const is_negative = value < 0;

    // Convert to string
    const num_str = try fmt.allocPrint(allocator, "{d}", .{abs_value});
    defer allocator.free(num_str);

    // Calculate size with separators
    const num_separators = if (num_str.len > 3) (num_str.len - 1) / 3 else 0;
    const total_size = num_str.len + num_separators + (if (is_negative) @as(usize, 1) else 0);

    var result = try allocator.alloc(u8, total_size);
    var write_pos = total_size;
    var digit_count: usize = 0;

    // Write digits from right to left
    var i = num_str.len;
    while (i > 0) {
        i -= 1;
        write_pos -= 1;
        result[write_pos] = num_str[i];
        digit_count += 1;

        // Add separator every 3 digits (but not at the beginning)
        if (digit_count % 3 == 0 and i > 0) {
            write_pos -= 1;
            result[write_pos] = separator;
        }
    }

    // Add negative sign
    if (is_negative) {
        write_pos -= 1;
        result[write_pos] = '-';
    }

    return result;
}

/// Format float with fixed decimal places
pub fn formatFloat(
    allocator: mem.Allocator,
    value: f64,
    comptime decimal_places: usize,
) ![]u8 {
    const format_str = switch (decimal_places) {
        0 => "{d:.0}",
        1 => "{d:.1}",
        2 => "{d:.2}",
        3 => "{d:.3}",
        4 => "{d:.4}",
        5 => "{d:.5}",
        6 => "{d:.6}",
        else => "{d:.6}", // Default to 6
    };
    return fmt.allocPrint(allocator, format_str, .{value});
}
// ANCHOR_END: basic_formatting

// ANCHOR: currency_formatting
/// Format as currency (2 decimal places with thousands separator)
pub fn formatCurrency(
    allocator: mem.Allocator,
    value: f64,
    currency_symbol: []const u8,
) ![]u8 {
    const is_negative = value < 0;
    const abs_value = if (is_negative) -value else value;

    // Get integer and fractional parts
    const int_part = @as(i64, @intFromFloat(@floor(abs_value)));
    const frac_part = @as(u8, @intFromFloat(@round((abs_value - @floor(abs_value)) * 100.0)));

    // Format integer part with separator
    const int_str = try formatWithSeparator(allocator, int_part, ',');
    defer allocator.free(int_str);

    // Combine parts
    if (is_negative) {
        return fmt.allocPrint(
            allocator,
            "-{s}{s}.{d:0>2}",
            .{ currency_symbol, int_str, frac_part },
        );
    } else {
        return fmt.allocPrint(
            allocator,
            "{s}{s}.{d:0>2}",
            .{ currency_symbol, int_str, frac_part },
        );
    }
}

/// Format in scientific notation
pub fn formatScientific(
    allocator: mem.Allocator,
    value: f64,
    comptime precision: usize,
) ![]u8 {
    const format_str = switch (precision) {
        0 => "{e:.0}",
        1 => "{e:.1}",
        2 => "{e:.2}",
        3 => "{e:.3}",
        4 => "{e:.4}",
        5 => "{e:.5}",
        6 => "{e:.6}",
        else => "{e:.6}",
    };
    return fmt.allocPrint(allocator, format_str, .{value});
}

/// Format as percentage
pub fn formatPercentage(
    allocator: mem.Allocator,
    value: f64,
    comptime decimal_places: usize,
) ![]u8 {
    const percent_value = value * 100.0;
    const num_str = try formatFloat(allocator, percent_value, decimal_places);
    defer allocator.free(num_str);

    return fmt.allocPrint(allocator, "{s}%", .{num_str});
}
// ANCHOR_END: currency_formatting

/// Format with padding
pub fn formatPadded(
    allocator: mem.Allocator,
    value: i64,
    width: usize,
    fill_char: u8,
) ![]u8 {
    _ = fill_char; // Currently unused, Zig uses space by default
    // Right-aligned by default
    const num_str = try fmt.allocPrint(allocator, "{d}", .{value});
    defer allocator.free(num_str);

    if (num_str.len >= width) {
        return allocator.dupe(u8, num_str);
    }

    var result = try allocator.alloc(u8, width);
    const padding = width - num_str.len;

    // Fill with spaces
    @memset(result[0..padding], ' ');
    @memcpy(result[padding..], num_str);

    return result;
}

// ANCHOR: base_conversion
/// Format in binary
pub fn formatBinary(allocator: mem.Allocator, value: u64) ![]u8 {
    return fmt.allocPrint(allocator, "{b}", .{value});
}

/// Format in octal
pub fn formatOctal(allocator: mem.Allocator, value: u64) ![]u8 {
    return fmt.allocPrint(allocator, "{o}", .{value});
}

/// Format in hexadecimal
pub fn formatHex(allocator: mem.Allocator, value: u64, uppercase: bool) ![]u8 {
    if (uppercase) {
        return fmt.allocPrint(allocator, "{X}", .{value});
    } else {
        return fmt.allocPrint(allocator, "{x}", .{value});
    }
}
// ANCHOR_END: base_conversion

test "format with thousands separator" {
    const result = try formatWithSeparator(testing.allocator, 1234567, ',');
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("1,234,567", result);
}

test "format negative with separator" {
    const result = try formatWithSeparator(testing.allocator, -1234567, ',');
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("-1,234,567", result);
}

test "format with underscore separator" {
    const result = try formatWithSeparator(testing.allocator, 1000000, '_');
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("1_000_000", result);
}

test "format small number with separator" {
    const result = try formatWithSeparator(testing.allocator, 123, ',');
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("123", result);
}

test "format float with fixed decimals" {
    const result1 = try formatFloat(testing.allocator, 3.14159, 2);
    defer testing.allocator.free(result1);
    try testing.expectEqualStrings("3.14", result1);

    const result2 = try formatFloat(testing.allocator, 3.14159, 4);
    defer testing.allocator.free(result2);
    try testing.expectEqualStrings("3.1416", result2);
}

test "format float with zero decimals" {
    const result = try formatFloat(testing.allocator, 3.7, 0);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("4", result);
}

test "format currency - positive" {
    const result = try formatCurrency(testing.allocator, 1234.56, "$");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("$1,234.56", result);
}

test "format currency - negative" {
    const result = try formatCurrency(testing.allocator, -1234.56, "$");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("-$1,234.56", result);
}

test "format currency - large amount" {
    const result = try formatCurrency(testing.allocator, 1000000.99, "$");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("$1,000,000.99", result);
}

test "format currency - euro" {
    const result = try formatCurrency(testing.allocator, 500.75, "€");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("€500.75", result);
}

test "format scientific notation" {
    const result1 = try formatScientific(testing.allocator, 1234.5, 2);
    defer testing.allocator.free(result1);
    try testing.expect(mem.startsWith(u8, result1, "1.23e"));

    const result2 = try formatScientific(testing.allocator, 0.00012, 3);
    defer testing.allocator.free(result2);
    try testing.expect(mem.startsWith(u8, result2, "1.200e"));
}

test "format percentage" {
    const result1 = try formatPercentage(testing.allocator, 0.5, 1);
    defer testing.allocator.free(result1);
    try testing.expectEqualStrings("50.0%", result1);

    const result2 = try formatPercentage(testing.allocator, 0.1234, 2);
    defer testing.allocator.free(result2);
    try testing.expectEqualStrings("12.34%", result2);
}

test "format percentage - edge cases" {
    const result1 = try formatPercentage(testing.allocator, 1.0, 0);
    defer testing.allocator.free(result1);
    try testing.expectEqualStrings("100%", result1);

    const result2 = try formatPercentage(testing.allocator, 0.001, 3);
    defer testing.allocator.free(result2);
    try testing.expectEqualStrings("0.100%", result2);
}

test "format with padding" {
    const result = try formatPadded(testing.allocator, 42, 10, ' ');
    defer testing.allocator.free(result);

    try testing.expect(result.len >= 10);
    try testing.expect(mem.endsWith(u8, result, "42"));
}

test "format binary" {
    const result = try formatBinary(testing.allocator, 42);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("101010", result);
}

test "format octal" {
    const result = try formatOctal(testing.allocator, 64);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("100", result);
}

test "format hex lowercase" {
    const result = try formatHex(testing.allocator, 255, false);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("ff", result);
}

test "format hex uppercase" {
    const result = try formatHex(testing.allocator, 255, true);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("FF", result);
}

test "format zero" {
    const result = try formatWithSeparator(testing.allocator, 0, ',');
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("0", result);
}

test "using std.fmt directly - integers" {
    // Direct std.fmt usage examples
    const result1 = try fmt.allocPrint(testing.allocator, "{d}", .{42});
    defer testing.allocator.free(result1);
    try testing.expectEqualStrings("42", result1);

    const result2 = try fmt.allocPrint(testing.allocator, "{d:5}", .{42});
    defer testing.allocator.free(result2);
    try testing.expect(result2.len >= 5);

    const result3 = try fmt.allocPrint(testing.allocator, "{d:0>5}", .{42});
    defer testing.allocator.free(result3);
    try testing.expectEqualStrings("00042", result3);
}

test "using std.fmt directly - floats" {
    const result1 = try fmt.allocPrint(testing.allocator, "{d:.2}", .{3.14159});
    defer testing.allocator.free(result1);
    try testing.expectEqualStrings("3.14", result1);

    const result2 = try fmt.allocPrint(testing.allocator, "{e:.2}", .{1234.5});
    defer testing.allocator.free(result2);
    try testing.expect(mem.startsWith(u8, result2, "1.23e"));
}

test "memory safety - all allocations freed" {
    // testing.allocator will catch any leaks
    const result1 = try formatWithSeparator(testing.allocator, 1000, ',');
    defer testing.allocator.free(result1);

    const result2 = try formatCurrency(testing.allocator, 100.50, "$");
    defer testing.allocator.free(result2);

    const result3 = try formatPercentage(testing.allocator, 0.5, 2);
    defer testing.allocator.free(result3);

    try testing.expect(result1.len > 0);
    try testing.expect(result2.len > 0);
    try testing.expect(result3.len > 0);
}

test "security - large numbers" {
    // Ensure large numbers are handled safely
    const large: i64 = 9223372036854775807; // i64 max
    const result = try formatWithSeparator(testing.allocator, large, ',');
    defer testing.allocator.free(result);

    try testing.expect(result.len > 0);
    try testing.expect(mem.indexOf(u8, result, ",") != null);
}
