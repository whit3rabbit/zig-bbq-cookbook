const std = @import("std");

/// Print filename safely, escaping control characters and invalid UTF-8
pub fn printSafeFilename(writer: anytype, filename: []const u8) !void {
    // Always escape control characters
    for (filename) |byte| {
        if (byte >= 32 and byte < 127) {
            try writer.writeByte(byte);
        } else {
            try std.fmt.format(writer, "\\x{X:0>2}", .{byte});
        }
    }
}

/// Print to terminal with control character escaping
pub fn printToTerminal(writer: anytype, filename: []const u8) !void {
    for (filename) |byte| {
        if (byte >= 32 and byte < 127) {
            try writer.writeByte(byte);
        } else if (byte == '\n') {
            try writer.writeAll("\\n");
        } else if (byte == '\r') {
            try writer.writeAll("\\r");
        } else if (byte == '\t') {
            try writer.writeAll("\\t");
        } else {
            try std.fmt.format(writer, "\\x{X:0>2}", .{byte});
        }
    }
    try writer.writeByte('\n');
}

/// Print with Unicode replacement character for invalid sequences
pub fn printWithReplacement(writer: anytype, filename: []const u8) !void {
    if (std.unicode.utf8ValidateSlice(filename)) {
        try writer.writeAll(filename);
        return;
    }

    var i: usize = 0;
    while (i < filename.len) {
        const len = std.unicode.utf8ByteSequenceLength(filename[i]) catch {
            try writer.writeAll("\u{FFFD}");
            i += 1;
            continue;
        };

        if (i + len > filename.len) {
            try writer.writeAll("\u{FFFD}");
            break;
        }

        if (filename[i] < 32) {
            try std.fmt.format(writer, "\\x{X:0>2}", .{filename[i]});
            i += 1;
        } else {
            try writer.writeAll(filename[i .. i + len]);
            i += len;
        }
    }
}

/// Print filename with shell-safe quoting
pub fn printQuoted(writer: anytype, filename: []const u8) !void {
    try writer.writeByte('"');

    for (filename) |byte| {
        switch (byte) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            0...8, 11, 12, 14...31, 127...255 => try std.fmt.format(writer, "\\x{X:0>2}", .{byte}),
            else => try writer.writeByte(byte),
        }
    }

    try writer.writeByte('"');
}

/// Print filename with truncation
pub fn printTruncated(
    writer: anytype,
    filename: []const u8,
    max_len: usize,
) !void {
    if (filename.len <= max_len) {
        try printSafeFilename(writer, filename);
        return;
    }

    const half = max_len / 2 - 2;
    try printSafeFilename(writer, filename[0..half]);
    try writer.writeAll("...");
    try printSafeFilename(writer, filename[filename.len - half ..]);
}

/// Color codes for terminal output
pub const Color = enum {
    reset,
    red,
    green,
    blue,
    yellow,

    pub fn code(self: Color) []const u8 {
        return switch (self) {
            .reset => "\x1b[0m",
            .red => "\x1b[31m",
            .green => "\x1b[32m",
            .blue => "\x1b[34m",
            .yellow => "\x1b[33m",
        };
    }
};

/// Print filename with color
pub fn printColored(
    writer: anytype,
    filename: []const u8,
    color: Color,
) !void {
    try writer.writeAll(color.code());
    try printSafeFilename(writer, filename);
    try writer.writeAll(Color.reset.code());
}

/// Print filename with verbose information
pub fn printVerbose(
    writer: anytype,
    filename: []const u8,
    show_bytes: bool,
) !void {
    try printSafeFilename(writer, filename);

    if (show_bytes) {
        try writer.writeAll(" [bytes: ");
        for (filename, 0..) |byte, i| {
            if (i > 0) try writer.writeByte(' ');
            try std.fmt.format(writer, "{X:0>2}", .{byte});
        }
        try writer.writeByte(']');
    }

    if (!std.unicode.utf8ValidateSlice(filename)) {
        try writer.writeAll(" (invalid UTF-8)");
    }

    try writer.writeByte('\n');
}

/// Print two filenames for comparison
pub fn printComparison(
    writer: anytype,
    filename1: []const u8,
    filename2: []const u8,
) !void {
    try writer.writeAll("Original: ");
    try printSafeFilename(writer, filename1);
    try writer.writeByte('\n');

    try writer.writeAll("Modified: ");
    try printSafeFilename(writer, filename2);
    try writer.writeByte('\n');

    if (!std.mem.eql(u8, filename1, filename2)) {
        try writer.writeAll("Different\n");
    } else {
        try writer.writeAll("Identical\n");
    }
}

/// Print filename JSON-safe
pub fn printJsonSafe(writer: anytype, filename: []const u8) !void {
    try writer.writeByte('"');

    for (filename) |byte| {
        switch (byte) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            '\x08' => try writer.writeAll("\\b"),
            '\x0C' => try writer.writeAll("\\f"),
            0...7, 11, 14...31, 127 => try std.fmt.format(writer, "\\u{X:0>4}", .{byte}),
            else => try writer.writeByte(byte),
        }
    }

    try writer.writeByte('"');
}

// Tests

// ANCHOR: safe_printing
test "print safe filename - valid" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    const writer = buffer.writer(allocator);

    try printSafeFilename(writer, "normal.txt");
    try std.testing.expectEqualStrings("normal.txt", buffer.items);
}

test "print safe filename - with null byte" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    const writer = buffer.writer(allocator);

    const bad_name = [_]u8{ 'b', 'a', 'd', 0x00, 'n', 'a', 'm', 'e' };
    try printSafeFilename(writer, &bad_name);
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "\\x00") != null);
}

test "print to terminal" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    const writer = buffer.writer(allocator);

    try printToTerminal(writer, "test.txt");
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "test.txt") != null);

    buffer.clearRetainingCapacity();

    try printToTerminal(writer, "test\nfile.txt");
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "\\n") != null);
}

test "print with replacement" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    const writer = buffer.writer(allocator);

    try printWithReplacement(writer, "test.txt");
    try std.testing.expectEqualStrings("test.txt", buffer.items);

    buffer.clearRetainingCapacity();

    const invalid = [_]u8{ 't', 'e', 's', 't', 0xFF, '.', 't', 'x', 't' };
    try printWithReplacement(writer, &invalid);
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "\u{FFFD}") != null);
}
// ANCHOR_END: safe_printing

test "print quoted" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    const writer = buffer.writer(allocator);

    try printQuoted(writer, "test.txt");
    try std.testing.expectEqualStrings("\"test.txt\"", buffer.items);

    buffer.clearRetainingCapacity();

    try printQuoted(writer, "test\nfile.txt");
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "\\n") != null);
}

test "print quoted with quote" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    const writer = buffer.writer(allocator);

    try printQuoted(writer, "test\"file.txt");
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "\\\"") != null);
}

test "print truncated - short name" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    const writer = buffer.writer(allocator);

    try printTruncated(writer, "short.txt", 20);
    try std.testing.expectEqualStrings("short.txt", buffer.items);
}

// ANCHOR: special_formatting
test "print truncated - long name" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    const writer = buffer.writer(allocator);

    try printTruncated(writer, "very_long_filename_that_should_be_truncated.txt", 20);
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "...") != null);
}

test "color codes" {
    try std.testing.expectEqualStrings("\x1b[31m", Color.red.code());
    try std.testing.expectEqualStrings("\x1b[32m", Color.green.code());
    try std.testing.expectEqualStrings("\x1b[34m", Color.blue.code());
    try std.testing.expectEqualStrings("\x1b[33m", Color.yellow.code());
    try std.testing.expectEqualStrings("\x1b[0m", Color.reset.code());
}

test "print colored" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    const writer = buffer.writer(allocator);

    try printColored(writer, "test.txt", .green);
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "\x1b[32m") != null);
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "test.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "\x1b[0m") != null);
}

test "print verbose without bytes" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    const writer = buffer.writer(allocator);

    try printVerbose(writer, "test.txt", false);
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "test.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "[bytes:") == null);
}

test "print verbose with bytes" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    const writer = buffer.writer(allocator);

    try printVerbose(writer, "test.txt", true);
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "test.txt") != null);
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "[bytes:") != null);
}

test "print verbose with invalid UTF-8" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    const writer = buffer.writer(allocator);

    const invalid = [_]u8{ 't', 'e', 's', 't', 0xFF };
    try printVerbose(writer, &invalid, false);
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "(invalid UTF-8)") != null);
}

test "print comparison - identical" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    const writer = buffer.writer(allocator);

    try printComparison(writer, "test.txt", "test.txt");
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "Identical") != null);
}

test "print comparison - different" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    const writer = buffer.writer(allocator);

    try printComparison(writer, "test.txt", "other.txt");
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "Different") != null);
}
// ANCHOR_END: special_formatting

// ANCHOR: json_escaping
test "print JSON safe - normal" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    const writer = buffer.writer(allocator);

    try printJsonSafe(writer, "test.txt");
    try std.testing.expectEqualStrings("\"test.txt\"", buffer.items);
}

test "print JSON safe - with newline" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    const writer = buffer.writer(allocator);

    try printJsonSafe(writer, "test\nfile.txt");
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "\\n") != null);
}

test "print JSON safe - with tab" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    const writer = buffer.writer(allocator);

    try printJsonSafe(writer, "test\tfile.txt");
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "\\t") != null);
}

test "print JSON safe - with backspace" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    const writer = buffer.writer(allocator);

    try printJsonSafe(writer, "test\x08file.txt");
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "\\b") != null);
}
// ANCHOR_END: json_escaping
