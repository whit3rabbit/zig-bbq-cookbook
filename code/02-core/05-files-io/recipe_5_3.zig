// Recipe 5.3: Printing with different separators and line endings
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to customize output formatting with different
// separators, delimiters, and line endings for various file formats.

const std = @import("std");
const testing = std.testing;

// ANCHOR: delimited_output
/// Print rows with tab separators
pub fn printTabDelimited(
    path: []const u8,
    rows: []const []const []const u8,
) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    for (rows) |row| {
        for (row, 0..) |cell, i| {
            try writer.writeAll(cell);
            if (i < row.len - 1) {
                try writer.writeAll("\t");
            }
        }
        try writer.writeAll("\n");
    }

    try writer.flush();
}

/// Print CSV with proper escaping
pub fn printCsv(
    path: []const u8,
    rows: []const []const []const u8,
) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    for (rows) |row| {
        for (row, 0..) |cell, i| {
            // Escape cells containing commas or quotes
            if (std.mem.indexOf(u8, cell, ",") != null or
                std.mem.indexOf(u8, cell, "\"") != null)
            {
                try writer.writeAll("\"");
                // Escape internal quotes by doubling them
                for (cell) |c| {
                    if (c == '"') {
                        try writer.writeAll("\"\"");
                    } else {
                        try writer.writeByte(c);
                    }
                }
                try writer.writeAll("\"");
            } else {
                try writer.writeAll(cell);
            }

            if (i < row.len - 1) {
                try writer.writeAll(",");
            }
        }
        try writer.writeAll("\n");
    }

    try writer.flush();
}

/// Print values with a custom separator
pub fn printWithSeparator(
    path: []const u8,
    values: []const []const u8,
    separator: []const u8,
) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    for (values, 0..) |value, i| {
        try writer.writeAll(value);
        if (i < values.len - 1) {
            try writer.writeAll(separator);
        }
    }

    try writer.flush();
}
// ANCHOR_END: delimited_output

// ANCHOR: line_endings
/// Print lines with Windows CRLF line endings
pub fn printWithCrlf(
    path: []const u8,
    lines: []const []const u8,
) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    for (lines) |line| {
        try writer.writeAll(line);
        try writer.writeAll("\r\n");
    }

    try writer.flush();
}

/// Print numbers with custom separator and precision
pub fn printNumbersWithFormat(
    path: []const u8,
    numbers: []const f64,
    separator: []const u8,
    precision: usize,
) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    for (numbers, 0..) |num, i| {
        switch (precision) {
            0 => try writer.print("{d:.0}", .{num}),
            1 => try writer.print("{d:.1}", .{num}),
            2 => try writer.print("{d:.2}", .{num}),
            3 => try writer.print("{d:.3}", .{num}),
            else => try writer.print("{d:.4}", .{num}),
        }

        if (i < numbers.len - 1) {
            try writer.writeAll(separator);
        }
    }

    try writer.flush();
}

/// Print chunks concatenated with no line endings
pub fn printConcatenated(
    path: []const u8,
    chunks: []const []const u8,
) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    for (chunks) |chunk| {
        try writer.writeAll(chunk);
    }

    try writer.flush();
}

/// Line ending styles
pub const LineEnding = enum {
    lf,    // Unix: \n
    crlf,  // Windows: \r\n
    cr,    // Old Mac: \r
};

/// Print lines with configurable line endings
pub fn printWithLineEnding(
    path: []const u8,
    lines: []const []const u8,
    ending: LineEnding,
) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    const line_end = switch (ending) {
        .lf => "\n",
        .crlf => "\r\n",
        .cr => "\r",
    };

    for (lines) |line| {
        try writer.writeAll(line);
        try writer.writeAll(line_end);
    }

    try writer.flush();
}
// ANCHOR_END: line_endings

// ANCHOR: format_variations
/// Print JSON array with optional indentation
pub fn printJsonArray(
    path: []const u8,
    values: []const []const u8,
    indent: bool,
) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    try writer.writeAll("[");
    if (indent) try writer.writeAll("\n");

    for (values, 0..) |value, i| {
        if (indent) try writer.writeAll("  ");
        try writer.print("\"{s}\"", .{value});
        if (i < values.len - 1) {
            try writer.writeAll(",");
        }
        if (indent) try writer.writeAll("\n");
    }

    try writer.writeAll("]");
    if (indent) try writer.writeAll("\n");

    try writer.flush();
}

/// Key-value pair type
pub const KeyValue = struct {
    key: []const u8,
    value: []const u8,
};

/// Print key-value pairs with custom format
pub fn printKeyValuePairs(
    path: []const u8,
    pairs: []const KeyValue,
    pair_separator: []const u8,
    kv_separator: []const u8,
) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    for (pairs, 0..) |pair, i| {
        try writer.writeAll(pair.key);
        try writer.writeAll(kv_separator);
        try writer.writeAll(pair.value);
        if (i < pairs.len - 1) {
            try writer.writeAll(pair_separator);
        }
    }

    try writer.flush();
}
// ANCHOR_END: format_variations

// Tests

test "print tab delimited" {
    const test_path = "test_tab_delimited.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const row1 = [_][]const u8{ "Name", "Age", "City" };
    const row2 = [_][]const u8{ "Alice", "30", "NYC" };
    const row3 = [_][]const u8{ "Bob", "25", "LA" };
    const rows = [_][]const []const u8{ &row1, &row2, &row3 };

    try printTabDelimited(test_path, &rows);

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(testing.allocator, 1024);
    defer testing.allocator.free(content);

    _ = std.mem.indexOf(u8, content, "Name\tAge\tCity") orelse return error.TestFailed;
    _ = std.mem.indexOf(u8, content, "Alice\t30\tNYC") orelse return error.TestFailed;
}

test "print csv with escaping" {
    const test_path = "test_csv.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const row1 = [_][]const u8{ "Name", "Description", "Price" };
    const row2 = [_][]const u8{ "Widget", "A nice, useful widget", "$10" };
    const row3 = [_][]const u8{ "Gadget", "Has \"quotes\"", "$20" };
    const rows = [_][]const []const u8{ &row1, &row2, &row3 };

    try printCsv(test_path, &rows);

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(testing.allocator, 1024);
    defer testing.allocator.free(content);

    // Check for proper escaping
    _ = std.mem.indexOf(u8, content, "\"A nice, useful widget\"") orelse return error.TestFailed;
    _ = std.mem.indexOf(u8, content, "\"Has \"\"quotes\"\"\"") orelse return error.TestFailed;
}

test "print with custom separator" {
    const test_path = "test_custom_sep.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const values = [_][]const u8{ "apple", "banana", "cherry", "date" };
    try printWithSeparator(test_path, &values, " | ");

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(testing.allocator, 1024);
    defer testing.allocator.free(content);

    try testing.expectEqualStrings("apple | banana | cherry | date", content);
}

test "print with CRLF line endings" {
    const test_path = "test_crlf.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const lines = [_][]const u8{ "Line 1", "Line 2", "Line 3" };
    try printWithCrlf(test_path, &lines);

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(testing.allocator, 1024);
    defer testing.allocator.free(content);

    try testing.expectEqualStrings("Line 1\r\nLine 2\r\nLine 3\r\n", content);
}

test "print numbers with format" {
    const test_path = "test_numbers_format.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const numbers = [_]f64{ 3.14159, 2.71828, 1.41421 };
    try printNumbersWithFormat(test_path, &numbers, ", ", 2);

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(testing.allocator, 1024);
    defer testing.allocator.free(content);

    _ = std.mem.indexOf(u8, content, "3.14") orelse return error.TestFailed;
    _ = std.mem.indexOf(u8, content, "2.72") orelse return error.TestFailed;
    _ = std.mem.indexOf(u8, content, "1.41") orelse return error.TestFailed;
}

test "print concatenated without line endings" {
    const test_path = "test_concatenated.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const chunks = [_][]const u8{ "Hello", " ", "World", "!" };
    try printConcatenated(test_path, &chunks);

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(testing.allocator, 1024);
    defer testing.allocator.free(content);

    try testing.expectEqualStrings("Hello World!", content);
}

test "print with different line endings" {
    const allocator = testing.allocator;

    const lines = [_][]const u8{ "Line 1", "Line 2", "Line 3" };

    // Test LF (Unix)
    {
        const test_path = "test_lf.txt";
        defer std.fs.cwd().deleteFile(test_path) catch {};

        try printWithLineEnding(test_path, &lines, .lf);

        const file = try std.fs.cwd().openFile(test_path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1024);
        defer allocator.free(content);

        try testing.expectEqualStrings("Line 1\nLine 2\nLine 3\n", content);
    }

    // Test CRLF (Windows)
    {
        const test_path = "test_crlf2.txt";
        defer std.fs.cwd().deleteFile(test_path) catch {};

        try printWithLineEnding(test_path, &lines, .crlf);

        const file = try std.fs.cwd().openFile(test_path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1024);
        defer allocator.free(content);

        try testing.expectEqualStrings("Line 1\r\nLine 2\r\nLine 3\r\n", content);
    }

    // Test CR (Old Mac)
    {
        const test_path = "test_cr.txt";
        defer std.fs.cwd().deleteFile(test_path) catch {};

        try printWithLineEnding(test_path, &lines, .cr);

        const file = try std.fs.cwd().openFile(test_path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1024);
        defer allocator.free(content);

        try testing.expectEqualStrings("Line 1\rLine 2\rLine 3\r", content);
    }
}

test "print json array" {
    const allocator = testing.allocator;

    const values = [_][]const u8{ "apple", "banana", "cherry" };

    // Test without indentation
    {
        const test_path = "test_json_compact.txt";
        defer std.fs.cwd().deleteFile(test_path) catch {};

        try printJsonArray(test_path, &values, false);

        const file = try std.fs.cwd().openFile(test_path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1024);
        defer allocator.free(content);

        try testing.expectEqualStrings("[\"apple\",\"banana\",\"cherry\"]", content);
    }

    // Test with indentation
    {
        const test_path = "test_json_indent.txt";
        defer std.fs.cwd().deleteFile(test_path) catch {};

        try printJsonArray(test_path, &values, true);

        const file = try std.fs.cwd().openFile(test_path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1024);
        defer allocator.free(content);

        _ = std.mem.indexOf(u8, content, "[\n  \"apple\",\n") orelse return error.TestFailed;
    }
}

test "print key-value pairs" {
    const test_path = "test_kvpairs.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const pairs = [_]KeyValue{
        .{ .key = "name", .value = "Alice" },
        .{ .key = "age", .value = "30" },
        .{ .key = "city", .value = "NYC" },
    };

    try printKeyValuePairs(test_path, &pairs, "; ", "=");

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(testing.allocator, 1024);
    defer testing.allocator.free(content);

    try testing.expectEqualStrings("name=Alice; age=30; city=NYC", content);
}

test "empty input handling" {
    const test_path = "test_empty.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const empty: []const []const u8 = &[_][]const u8{};
    try printWithSeparator(test_path, empty, ",");

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(testing.allocator, 1024);
    defer testing.allocator.free(content);

    try testing.expectEqual(@as(usize, 0), content.len);
}

test "single value no separator" {
    const test_path = "test_single.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const values = [_][]const u8{"single"};
    try printWithSeparator(test_path, &values, ",");

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(testing.allocator, 1024);
    defer testing.allocator.free(content);

    try testing.expectEqualStrings("single", content);
}
