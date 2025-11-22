// Recipe 2.10: Aligning text strings
// Target Zig Version: 0.15.2
//
// This recipe demonstrates text alignment and formatting for tables,
// columns, and structured output.

const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const fmt = std.fmt;

// ANCHOR: basic_alignment
/// Align text left with padding
pub fn alignLeft(
    allocator: mem.Allocator,
    text: []const u8,
    width: usize,
    fill_char: u8,
) ![]u8 {
    if (text.len >= width) return allocator.dupe(u8, text);

    var result = try allocator.alloc(u8, width);
    errdefer allocator.free(result);

    @memcpy(result[0..text.len], text);

    var i: usize = text.len;
    while (i < width) : (i += 1) {
        result[i] = fill_char;
    }

    return result;
}

/// Align text right with padding
pub fn alignRight(
    allocator: mem.Allocator,
    text: []const u8,
    width: usize,
    fill_char: u8,
) ![]u8 {
    if (text.len >= width) return allocator.dupe(u8, text);

    var result = try allocator.alloc(u8, width);
    errdefer allocator.free(result);

    const padding = width - text.len;

    var i: usize = 0;
    while (i < padding) : (i += 1) {
        result[i] = fill_char;
    }

    @memcpy(result[padding..][0..text.len], text);

    return result;
}

/// Align text center with padding
pub fn alignCenter(
    allocator: mem.Allocator,
    text: []const u8,
    width: usize,
    fill_char: u8,
) ![]u8 {
    if (text.len >= width) return allocator.dupe(u8, text);

    var result = try allocator.alloc(u8, width);
    errdefer allocator.free(result);

    const total_padding = width - text.len;
    const left_padding = total_padding / 2;

    var i: usize = 0;
    while (i < left_padding) : (i += 1) {
        result[i] = fill_char;
    }

    @memcpy(result[left_padding..][0..text.len], text);

    i = left_padding + text.len;
    while (i < width) : (i += 1) {
        result[i] = fill_char;
    }

    return result;
}
// ANCHOR_END: basic_alignment

// ANCHOR: table_formatting
/// Format table row with aligned columns
pub fn formatRow(
    allocator: mem.Allocator,
    columns: []const []const u8,
    widths: []const usize,
    separator: []const u8,
) ![]u8 {
    if (columns.len != widths.len) return error.ColumnWidthMismatch;

    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    for (columns, widths, 0..) |col, width, i| {
        const padded = try alignLeft(allocator, col, width, ' ');
        defer allocator.free(padded);

        try result.appendSlice(allocator, padded);

        if (i < columns.len - 1) {
            try result.appendSlice(allocator, separator);
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Create horizontal divider line
pub fn divider(
    allocator: mem.Allocator,
    width: usize,
    char: u8,
) ![]u8 {
    const result = try allocator.alloc(u8, width);
    @memset(result, char);
    return result;
}
// ANCHOR_END: table_formatting

// ANCHOR: advanced_formatting
/// Format text in a box
pub fn textBox(
    allocator: mem.Allocator,
    text: []const u8,
    padding: usize,
) ![]u8 {
    const inner_width = text.len + (padding * 2);

    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    // Top border
    try result.append(allocator, '+');
    var i: usize = 0;
    while (i < inner_width) : (i += 1) {
        try result.append(allocator, '-');
    }
    try result.append(allocator, '+');
    try result.append(allocator, '\n');

    // Content line with padding
    try result.append(allocator, '|');
    i = 0;
    while (i < padding) : (i += 1) {
        try result.append(allocator, ' ');
    }
    try result.appendSlice(allocator, text);
    i = 0;
    while (i < padding) : (i += 1) {
        try result.append(allocator, ' ');
    }
    try result.append(allocator, '|');
    try result.append(allocator, '\n');

    // Bottom border
    try result.append(allocator, '+');
    i = 0;
    while (i < inner_width) : (i += 1) {
        try result.append(allocator, '-');
    }
    try result.append(allocator, '+');

    return result.toOwnedSlice(allocator);
}

/// Truncate text to width with ellipsis
pub fn truncate(
    allocator: mem.Allocator,
    text: []const u8,
    width: usize,
) ![]u8 {
    if (text.len <= width) return allocator.dupe(u8, text);

    if (width < 3) {
        // Too narrow for ellipsis
        return allocator.dupe(u8, text[0..width]);
    }

    var result = try allocator.alloc(u8, width);
    errdefer allocator.free(result);

    @memcpy(result[0 .. width - 3], text[0 .. width - 3]);
    result[width - 3] = '.';
    result[width - 2] = '.';
    result[width - 1] = '.';

    return result;
}
// ANCHOR_END: advanced_formatting

test "align left" {
    const result = try alignLeft(testing.allocator, "hello", 10, ' ');
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello     ", result);
}

test "align left - no padding needed" {
    const result = try alignLeft(testing.allocator, "hello", 5, ' ');
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello", result);
}

test "align right" {
    const result = try alignRight(testing.allocator, "42", 5, '0');
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("00042", result);
}

test "align right - no padding needed" {
    const result = try alignRight(testing.allocator, "hello", 3, ' ');
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello", result);
}

test "align center" {
    const result = try alignCenter(testing.allocator, "hi", 6, ' ');
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("  hi  ", result);
}

test "align center - odd padding" {
    const result = try alignCenter(testing.allocator, "hi", 7, ' ');
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("  hi   ", result);
}

test "format table row" {
    const columns = [_][]const u8{ "Name", "Age", "City" };
    const widths = [_]usize{ 10, 5, 15 };
    const result = try formatRow(testing.allocator, &columns, &widths, " | ");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Name       | Age   | City           ", result);
}

test "format single column" {
    const columns = [_][]const u8{"Test"};
    const widths = [_]usize{10};
    const result = try formatRow(testing.allocator, &columns, &widths, " | ");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Test      ", result);
}

test "format row with custom separator" {
    const columns = [_][]const u8{ "A", "B", "C" };
    const widths = [_]usize{ 5, 5, 5 };
    const result = try formatRow(testing.allocator, &columns, &widths, "|");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("A    |B    |C    ", result);
}

test "create divider" {
    const result = try divider(testing.allocator, 20, '-');
    defer testing.allocator.free(result);

    try testing.expectEqual(@as(usize, 20), result.len);
    for (result) |c| {
        try testing.expectEqual(@as(u8, '-'), c);
    }
}

test "create divider with different character" {
    const result = try divider(testing.allocator, 10, '=');
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("==========", result);
}

test "text box" {
    const result = try textBox(testing.allocator, "Hello", 2);
    defer testing.allocator.free(result);

    const expected = "+---------+\n|  Hello  |\n+---------+";
    try testing.expectEqualStrings(expected, result);
}

test "text box - no padding" {
    const result = try textBox(testing.allocator, "Test", 0);
    defer testing.allocator.free(result);

    const expected = "+----+\n|Test|\n+----+";
    try testing.expectEqualStrings(expected, result);
}

test "truncate long text" {
    const result = try truncate(testing.allocator, "This is a very long text", 15);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("This is a ve...", result);
}

test "truncate - no truncation needed" {
    const result = try truncate(testing.allocator, "short", 10);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("short", result);
}

test "truncate - exact length" {
    const result = try truncate(testing.allocator, "exactly10!", 10);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("exactly10!", result);
}

test "truncate very narrow" {
    const result = try truncate(testing.allocator, "longtext", 2);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("lo", result);
}

test "format header and rows" {
    const header = [_][]const u8{ "ID", "Name", "Status" };
    const widths = [_]usize{ 5, 15, 10 };

    const header_row = try formatRow(testing.allocator, &header, &widths, " | ");
    defer testing.allocator.free(header_row);

    const div = try divider(testing.allocator, header_row.len, '-');
    defer testing.allocator.free(div);

    try testing.expect(header_row.len > 0);
    try testing.expectEqual(header_row.len, div.len);
}

test "align numbers for table" {
    const num1 = try alignRight(testing.allocator, "42", 8, ' ');
    defer testing.allocator.free(num1);

    const num2 = try alignRight(testing.allocator, "1000", 8, ' ');
    defer testing.allocator.free(num2);

    try testing.expectEqualStrings("      42", num1);
    try testing.expectEqualStrings("    1000", num2);
}

test "format price column" {
    const price1 = try alignRight(testing.allocator, "$9.99", 10, ' ');
    defer testing.allocator.free(price1);

    const price2 = try alignRight(testing.allocator, "$129.99", 10, ' ');
    defer testing.allocator.free(price2);

    try testing.expectEqualStrings("     $9.99", price1);
    try testing.expectEqualStrings("   $129.99", price2);
}

test "center title" {
    const title = try alignCenter(testing.allocator, "Report", 40, '=');
    defer testing.allocator.free(title);

    try testing.expectEqual(@as(usize, 40), title.len);
    try testing.expect(mem.indexOf(u8, title, "Report") != null);
}

test "memory safety - alignment" {
    const result = try alignLeft(testing.allocator, "test", 10, ' ');
    defer testing.allocator.free(result);

    // testing.allocator will detect leaks
    try testing.expect(result.len == 10);
}

test "UTF-8 text alignment" {
    const result = try alignLeft(testing.allocator, "Hello 世界", 20, ' ');
    defer testing.allocator.free(result);

    try testing.expect(result.len == 20);
    try testing.expect(mem.indexOf(u8, result, "Hello 世界") != null);
}

test "security - large width" {
    const result = try alignLeft(testing.allocator, "test", 1000, ' ');
    defer testing.allocator.free(result);

    try testing.expectEqual(@as(usize, 1000), result.len);
}

test "format empty column" {
    const columns = [_][]const u8{""};
    const widths = [_]usize{5};
    const result = try formatRow(testing.allocator, &columns, &widths, " | ");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("     ", result);
}
