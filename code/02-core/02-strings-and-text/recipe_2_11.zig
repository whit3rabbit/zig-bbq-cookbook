// Recipe 2.11: Reformatting text to fixed columns
// Target Zig Version: 0.15.2
//
// This recipe demonstrates text wrapping, word breaking, and reformatting
// text to fit within fixed column widths.

const std = @import("std");
const testing = std.testing;
const mem = std.mem;

// ANCHOR: text_wrapping
/// Wrap text to fit within specified width (word boundaries)
pub fn wrapText(
    allocator: mem.Allocator,
    text: []const u8,
    width: usize,
) ![]u8 {
    if (width == 0) return allocator.dupe(u8, "");
    if (text.len <= width) return allocator.dupe(u8, text);

    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    var pos: usize = 0;
    var line_start: usize = 0;

    while (pos < text.len) {
        // Find end of line or width limit
        var line_end = @min(line_start + width, text.len);

        // If we're not at the end, try to break at a word boundary
        if (line_end < text.len) {
            // Look back for a space
            var break_pos = line_end;
            while (break_pos > line_start) : (break_pos -= 1) {
                if (text[break_pos] == ' ') {
                    line_end = break_pos;
                    break;
                }
            }

            // If no space found, use hard break at width
            if (break_pos == line_start) {
                line_end = line_start + width;
            }
        }

        // Add line
        const line = mem.trim(u8, text[line_start..line_end], " ");
        try result.appendSlice(allocator, line);

        // Add newline if not last line
        if (line_end < text.len) {
            try result.append(allocator, '\n');
        }

        // Move to next line
        line_start = line_end;
        // Skip any spaces at start of next line
        while (line_start < text.len and text[line_start] == ' ') {
            line_start += 1;
        }

        pos = line_start;
    }

    return result.toOwnedSlice(allocator);
}

/// Hard wrap text (break at exact width)
pub fn hardWrap(
    allocator: mem.Allocator,
    text: []const u8,
    width: usize,
) ![]u8 {
    if (width == 0) return allocator.dupe(u8, "");
    if (text.len <= width) return allocator.dupe(u8, text);

    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    var pos: usize = 0;
    while (pos < text.len) {
        const chunk_end = @min(pos + width, text.len);
        try result.appendSlice(allocator, text[pos..chunk_end]);

        if (chunk_end < text.len) {
            try result.append(allocator, '\n');
        }

        pos = chunk_end;
    }

    return result.toOwnedSlice(allocator);
}
// ANCHOR_END: text_wrapping

// ANCHOR: split_lines
/// Split text into lines of maximum width
pub fn splitIntoLines(
    allocator: mem.Allocator,
    text: []const u8,
    width: usize,
) !std.ArrayList([]const u8) {
    var lines = std.ArrayList([]const u8){};
    errdefer lines.deinit(allocator);

    var pos: usize = 0;
    var line_start: usize = 0;

    while (pos < text.len) {
        var line_end = @min(line_start + width, text.len);

        if (line_end < text.len) {
            var break_pos = line_end;
            while (break_pos > line_start) : (break_pos -= 1) {
                if (text[break_pos] == ' ') {
                    line_end = break_pos;
                    break;
                }
            }

            if (break_pos == line_start) {
                line_end = line_start + width;
            }
        }

        const line = mem.trim(u8, text[line_start..line_end], " ");
        try lines.append(allocator, line);

        line_start = line_end;
        while (line_start < text.len and text[line_start] == ' ') {
            line_start += 1;
        }

        pos = line_start;
    }

    return lines;
}
// ANCHOR_END: split_lines

// ANCHOR: indentation
/// Indent text with prefix
pub fn indent(
    allocator: mem.Allocator,
    text: []const u8,
    prefix: []const u8,
) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    var lines = mem.tokenizeScalar(u8, text, '\n');
    var first = true;

    while (lines.next()) |line| {
        if (!first) {
            try result.append(allocator, '\n');
        }
        first = false;

        try result.appendSlice(allocator, prefix);
        try result.appendSlice(allocator, line);
    }

    return result.toOwnedSlice(allocator);
}

/// Format paragraph with indentation
pub fn formatParagraph(
    allocator: mem.Allocator,
    text: []const u8,
    width: usize,
    first_line_indent: usize,
    subsequent_indent: usize,
) ![]u8 {
    // First wrap the text
    const wrapped = try wrapText(allocator, text, width);
    defer allocator.free(wrapped);

    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    var lines = mem.tokenizeScalar(u8, wrapped, '\n');
    var first = true;

    while (lines.next()) |line| {
        if (!first) {
            try result.append(allocator, '\n');
        }

        // Add indentation
        const indent_size = if (first) first_line_indent else subsequent_indent;
        var i: usize = 0;
        while (i < indent_size) : (i += 1) {
            try result.append(allocator, ' ');
        }

        try result.appendSlice(allocator, line);
        first = false;
    }

    return result.toOwnedSlice(allocator);
}
// ANCHOR_END: indentation

test "wrap text at word boundaries" {
    const text = "The quick brown fox jumps over the lazy dog";
    const result = try wrapText(testing.allocator, text, 20);
    defer testing.allocator.free(result);

    try testing.expect(mem.indexOf(u8, result, "\n") != null);
}

test "wrap short text - no wrapping needed" {
    const text = "Short";
    const result = try wrapText(testing.allocator, text, 20);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Short", result);
}

test "wrap exact length" {
    const text = "Exactly twenty chars";
    const result = try wrapText(testing.allocator, text, 20);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Exactly twenty chars", result);
}

test "wrap with no spaces - hard break" {
    const text = "Superlongwordwithoutanyspaces";
    const result = try wrapText(testing.allocator, text, 10);
    defer testing.allocator.free(result);

    try testing.expect(mem.indexOf(u8, result, "\n") != null);
}

test "hard wrap text" {
    const text = "This is a test of hard wrapping";
    const result = try hardWrap(testing.allocator, text, 10);
    defer testing.allocator.free(result);

    const expected = "This is a \ntest of ha\nrd wrappin\ng";
    try testing.expectEqualStrings(expected, result);
}

test "hard wrap exact length" {
    const text = "TenLetters";
    const result = try hardWrap(testing.allocator, text, 10);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("TenLetters", result);
}

test "split into lines" {
    const text = "The quick brown fox jumps over the lazy dog";
    var lines = try splitIntoLines(testing.allocator, text, 20);
    defer lines.deinit(testing.allocator);

    try testing.expect(lines.items.len > 1);
}

test "split short text" {
    const text = "Short";
    var lines = try splitIntoLines(testing.allocator, text, 20);
    defer lines.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 1), lines.items.len);
    try testing.expectEqualStrings("Short", lines.items[0]);
}

test "indent text" {
    const text = "Line 1\nLine 2\nLine 3";
    const result = try indent(testing.allocator, text, "  ");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("  Line 1\n  Line 2\n  Line 3", result);
}

test "indent single line" {
    const text = "Single line";
    const result = try indent(testing.allocator, text, "> ");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("> Single line", result);
}

test "format paragraph with indentation" {
    const text = "This is a paragraph that needs to be formatted with proper indentation";
    const result = try formatParagraph(testing.allocator, text, 30, 4, 2);
    defer testing.allocator.free(result);

    // First line should have 4-space indent
    try testing.expect(mem.startsWith(u8, result, "    "));
}

test "format paragraph - no indent" {
    const text = "Short text";
    const result = try formatParagraph(testing.allocator, text, 40, 0, 0);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Short text", result);
}

test "wrap empty string" {
    const result = try wrapText(testing.allocator, "", 20);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("", result);
}

test "wrap zero width" {
    const result = try wrapText(testing.allocator, "test", 0);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("", result);
}

test "format code comment" {
    const text = "This is a very long comment that should be wrapped to fit within 80 characters per line";
    const wrapped = try wrapText(testing.allocator, text, 70);
    defer testing.allocator.free(wrapped);

    const result = try indent(testing.allocator, wrapped, "// ");
    defer testing.allocator.free(result);

    try testing.expect(mem.startsWith(u8, result, "// "));
}

test "format quote" {
    const text = "Life is what happens when you're busy making other plans";
    const result = try indent(testing.allocator, text, "> ");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("> Life is what happens when you're busy making other plans", result);
}

test "wrap long URL" {
    const url = "https://example.com/very/long/path/to/resource/that/exceeds/normal/width";
    const result = try hardWrap(testing.allocator, url, 40);
    defer testing.allocator.free(result);

    try testing.expect(mem.indexOf(u8, result, "\n") != null);
}

test "memory safety - wrapping" {
    const text = "Test text for wrapping";
    const result = try wrapText(testing.allocator, text, 10);
    defer testing.allocator.free(result);

    // testing.allocator will detect leaks
    try testing.expect(result.len > 0);
}

test "UTF-8 text wrapping" {
    const text = "Hello 世界 how are you";
    const result = try wrapText(testing.allocator, text, 15);
    defer testing.allocator.free(result);

    try testing.expect(result.len > 0);
}

test "security - large width" {
    const text = "test";
    const result = try wrapText(testing.allocator, text, 1000);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("test", result);
}
