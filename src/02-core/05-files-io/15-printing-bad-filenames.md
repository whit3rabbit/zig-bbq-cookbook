## Problem

You need to print or display filenames that may contain invalid UTF-8, control characters, or other problematic sequences.

## Solution

### Safe Printing

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_15.zig:safe_printing}}
```

### Special Formatting

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_15.zig:special_formatting}}
```

### JSON Escaping

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_15.zig:json_escaping}}
```

## Discussion

### Safe Terminal Output

Display filenames without breaking terminal:

```zig
pub fn printToTerminal(filename: []const u8) !void {
    const stdout = std.io.getStdOut().writer();

    // Escape control characters that could affect terminal
    for (filename) |byte| {
        if (byte >= 32 and byte < 127) {
            try stdout.writeByte(byte);
        } else if (byte == '\n') {
            try stdout.writeAll("\\n");
        } else if (byte == '\r') {
            try stdout.writeAll("\\r");
        } else if (byte == '\t') {
            try stdout.writeAll("\\t");
        } else {
            try std.fmt.format(stdout, "\\x{X:0>2}", .{byte});
        }
    }
    try stdout.writeByte('\n');
}
```

### Unicode Replacement Character

Replace invalid sequences with Unicode replacement character:

```zig
pub fn printWithReplacement(
    writer: anytype,
    filename: []const u8,
) !void {
    if (std.unicode.utf8ValidateSlice(filename)) {
        try writer.writeAll(filename);
        return;
    }

    var i: usize = 0;
    while (i < filename.len) {
        const len = std.unicode.utf8ByteSequenceLength(filename[i]) catch {
            // Invalid UTF-8, use replacement character
            try writer.writeAll("\u{FFFD}");
            i += 1;
            continue;
        };

        if (i + len > filename.len) {
            // Incomplete sequence
            try writer.writeAll("\u{FFFD}");
            break;
        }

        // Check if it's a control character
        if (filename[i] < 32) {
            try std.fmt.format(writer, "\\x{X:0>2}", .{filename[i]});
            i += 1;
        } else {
            try writer.writeAll(filename[i .. i + len]);
            i += len;
        }
    }
}

test "print with replacement" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    const writer = buffer.writer(allocator);

    // Valid UTF-8
    try printWithReplacement(writer, "test.txt");
    try std.testing.expectEqualStrings("test.txt", buffer.items);

    buffer.clearRetainingCapacity();

    // Invalid UTF-8
    const invalid = [_]u8{ 't', 'e', 's', 't', 0xFF, '.', 't', 'x', 't' };
    try printWithReplacement(writer, &invalid);
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "\u{FFFD}") != null);
}
```

### Quoted Output

Print filenames with shell-safe quoting:

```zig
pub fn printQuoted(writer: anytype, filename: []const u8) !void {
    try writer.writeByte('"');

    for (filename) |byte| {
        switch (byte) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            0...31, 127...255 => try std.fmt.format(writer, "\\x{X:0>2}", .{byte}),
            else => try writer.writeByte(byte),
        }
    }

    try writer.writeByte('"');
}

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
```

### Listing Directory with Safe Display

List directory contents with safe filename display:

```zig
pub fn listDirectorySafe(allocator: std.mem.Allocator, path: []const u8) !void {
    const stdout = std.io.getStdOut().writer();

    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        try stdout.writeAll("  ");
        try printSafeFilename(stdout, entry.name);
        try stdout.writeByte('\n');
    }
}
```

### Truncated Display

Display long filenames with truncation:

```zig
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

test "print truncated" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    const writer = buffer.writer(allocator);

    // Short name
    try printTruncated(writer, "short.txt", 20);
    try std.testing.expectEqualStrings("short.txt", buffer.items);

    buffer.clearRetainingCapacity();

    // Long name
    try printTruncated(writer, "very_long_filename_that_should_be_truncated.txt", 20);
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "...") != null);
}
```

### Column Formatting

Format filenames in columns:

```zig
pub fn printInColumns(
    writer: anytype,
    filenames: []const []const u8,
    columns: usize,
    width: usize,
) !void {
    var col: usize = 0;

    for (filenames) |filename| {
        var buffer: [256]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buffer);
        try printSafeFilename(fbs.writer(), filename);

        const display = fbs.getWritten();

        try writer.writeAll(display);

        // Pad to column width
        if (display.len < width) {
            const padding = width - display.len;
            try writer.writeByteNTimes(' ', padding);
        }

        col += 1;
        if (col >= columns) {
            try writer.writeByte('\n');
            col = 0;
        } else {
            try writer.writeAll("  ");
        }
    }

    if (col > 0) {
        try writer.writeByte('\n');
    }
}
```

### Color-Coded Output

Add color for different file types:

```zig
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

pub fn printColored(
    writer: anytype,
    filename: []const u8,
    color: Color,
) !void {
    try writer.writeAll(color.code());
    try printSafeFilename(writer, filename);
    try writer.writeAll(Color.reset.code());
}

test "print colored" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    const writer = buffer.writer(allocator);

    try printColored(writer, "test.txt", .green);
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "\x1b[32m") != null);
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "test.txt") != null);
}
```

### Verbose Mode

Show additional information:

```zig
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

    // Show encoding status
    if (!std.unicode.utf8ValidateSlice(filename)) {
        try writer.writeAll(" (invalid UTF-8)");
    }

    try writer.writeByte('\n');
}
```

### Comparison Display

Show two filenames side by side:

```zig
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

    // Show differences
    if (!std.mem.eql(u8, filename1, filename2)) {
        try writer.writeAll("Different\n");
    } else {
        try writer.writeAll("Identical\n");
    }
}
```

### Logging Filenames

Log filenames safely:

```zig
pub fn logFilename(filename: []const u8, level: std.log.Level) !void {
    var buffer: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    try printSafeFilename(writer, filename);

    switch (level) {
        .info => std.log.info("{s}", .{fbs.getWritten()}),
        .warn => std.log.warn("{s}", .{fbs.getWritten()}),
        .err => std.log.err("{s}", .{fbs.getWritten()}),
        else => {},
    }
}
```

### JSON-Safe Output

Escape for JSON:

```zig
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
            0...31, 127 => try std.fmt.format(writer, "\\u{0:0>4X}", .{byte}),
            else => try writer.writeByte(byte),
        }
    }

    try writer.writeByte('"');
}

test "print JSON safe" {
    const allocator = std.testing.allocator;
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(allocator);

    const writer = buffer.writer(allocator);

    try printJsonSafe(writer, "test.txt");
    try std.testing.expectEqualStrings("\"test.txt\"", buffer.items);

    buffer.clearRetainingCapacity();

    try printJsonSafe(writer, "test\nfile.txt");
    try std.testing.expect(std.mem.indexOf(u8, buffer.items, "\\n") != null);
}
```

### Best Practices

**Display considerations:**
- Always escape control characters
- Use replacement character for invalid UTF-8
- Quote filenames with spaces or special characters
- Consider terminal capabilities

**Error handling:**
```zig
pub fn safePrint(filename: []const u8) void {
    const stdout = std.io.getStdOut().writer();
    printSafeFilename(stdout, filename) catch {
        // Fallback to hex dump
        for (filename) |byte| {
            std.fmt.format(stdout, "{X:0>2}", .{byte}) catch {};
        }
    };
    stdout.writeByte('\n') catch {};
}
```

**Performance:**
- Pre-allocate buffers for large listings
- Use buffered writers
- Validate UTF-8 once, cache result

### Related Functions

- `std.unicode.utf8ValidateSlice()` - Validate UTF-8
- `std.fmt.format()` - Formatted output
- `std.io.Writer` - Writer interface
- `std.mem.indexOf()` - Find substrings
- `std.log` - Logging framework
