const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");

// ANCHOR: terminal_size
/// Terminal dimensions
pub const TerminalSize = struct {
    rows: u16,
    cols: u16,
};

/// Get terminal size for Unix-like systems
fn getTerminalSizeUnix() !TerminalSize {
    if (builtin.os.tag == .windows) {
        return error.UnsupportedPlatform;
    }

    const stdout_fd = std.posix.STDOUT_FILENO;
    var winsize: std.posix.winsize = .{
        .row = 0,
        .col = 0,
        .xpixel = 0,
        .ypixel = 0,
    };

    const err = std.posix.system.ioctl(stdout_fd, std.posix.T.IOCGWINSZ, @intFromPtr(&winsize));
    if (std.posix.errno(err) != .SUCCESS) {
        return error.IoctlFailed;
    }

    return TerminalSize{
        .rows = winsize.row,
        .cols = winsize.col,
    };
}

test "terminal size structure" {
    const size = TerminalSize{ .rows = 24, .cols = 80 };
    try testing.expectEqual(24, size.rows);
    try testing.expectEqual(80, size.cols);
}
// ANCHOR_END: terminal_size

// ANCHOR: fallback_size
/// Get terminal size with fallback to defaults
fn getTerminalSizeWithFallback() TerminalSize {
    return getTerminalSizeUnix() catch TerminalSize{
        .rows = 24,
        .cols = 80,
    };
}

test "fallback size" {
    const size = getTerminalSizeWithFallback();
    // Just verify it returns something reasonable
    try testing.expect(size.rows > 0);
    try testing.expect(size.cols > 0);
}
// ANCHOR_END: fallback_size

// ANCHOR: environment_size
/// Get terminal size from environment variables (LINES and COLUMNS)
fn getTerminalSizeFromEnv(allocator: std.mem.Allocator) !TerminalSize {
    const lines_str = std.process.getEnvVarOwned(allocator, "LINES") catch null;
    defer if (lines_str) |s| allocator.free(s);

    const cols_str = std.process.getEnvVarOwned(allocator, "COLUMNS") catch null;
    defer if (cols_str) |s| allocator.free(s);

    const rows = if (lines_str) |s| try std.fmt.parseInt(u16, s, 10) else return error.EnvVarNotFound;
    const cols = if (cols_str) |s| try std.fmt.parseInt(u16, s, 10) else return error.EnvVarNotFound;

    return TerminalSize{ .rows = rows, .cols = cols };
}

test "parse terminal size from values" {
    // Just test the parsing logic
    const rows_str = "30";
    const cols_str = "120";

    const rows = try std.fmt.parseInt(u16, rows_str, 10);
    const cols = try std.fmt.parseInt(u16, cols_str, 10);

    try testing.expectEqual(30, rows);
    try testing.expectEqual(120, cols);
}
// ANCHOR_END: environment_size

// ANCHOR: adaptive_terminal
/// Get terminal size with multiple fallback strategies
fn getTerminalSizeBestEffort(allocator: std.mem.Allocator) TerminalSize {
    // Try ioctl first
    if (getTerminalSizeUnix()) |size| {
        return size;
    } else |_| {}

    // Try environment variables
    if (getTerminalSizeFromEnv(allocator)) |size| {
        return size;
    } else |_| {}

    // Fall back to standard defaults
    return TerminalSize{ .rows = 24, .cols = 80 };
}

test "best effort terminal size" {
    const size = getTerminalSizeBestEffort(testing.allocator);
    try testing.expect(size.rows > 0);
    try testing.expect(size.cols > 0);
}
// ANCHOR_END: adaptive_terminal

// ANCHOR: responsive_output
/// Format text to fit terminal width
fn wrapText(allocator: std.mem.Allocator, text: []const u8, width: usize) ![]const u8 {
    var lines = std.ArrayList(u8){};
    errdefer lines.deinit(allocator);

    var words = std.mem.tokenizeAny(u8, text, " \t\n");
    var current_line_len: usize = 0;
    var first_word = true;

    while (words.next()) |word| {
        const word_len = word.len;

        // Check if adding this word would exceed width
        const space_len: usize = if (first_word) 0 else 1;
        if (current_line_len + space_len + word_len > width and current_line_len > 0) {
            try lines.append(allocator, '\n');
            current_line_len = 0;
            first_word = true;
        }

        // Add space before word (except for first word on line)
        if (!first_word) {
            try lines.append(allocator, ' ');
            current_line_len += 1;
        }

        // Add the word
        try lines.appendSlice(allocator, word);
        current_line_len += word_len;
        first_word = false;
    }

    return lines.toOwnedSlice(allocator);
}

test "text wrapping" {
    const text = "The quick brown fox jumps over the lazy dog";
    const wrapped = try wrapText(testing.allocator, text, 20);
    defer testing.allocator.free(wrapped);

    // Should contain newlines due to wrapping
    try testing.expect(std.mem.indexOf(u8, wrapped, "\n") != null);
}

test "text wrapping exact width" {
    const text = "Hello World Test";
    const wrapped = try wrapText(testing.allocator, text, 15);
    defer testing.allocator.free(wrapped);

    try testing.expect(wrapped.len > 0);
}
// ANCHOR_END: responsive_output

// ANCHOR: column_layout
/// Format data in columns that fit terminal width
pub const ColumnFormatter = struct {
    allocator: std.mem.Allocator,
    terminal_width: usize,
    column_width: usize,
    num_columns: usize,

    pub fn init(allocator: std.mem.Allocator, terminal_width: usize, column_width: usize) ColumnFormatter {
        const num_columns = @max(1, terminal_width / (column_width + 2)); // +2 for spacing
        return .{
            .allocator = allocator,
            .terminal_width = terminal_width,
            .column_width = column_width,
            .num_columns = num_columns,
        };
    }

    pub fn format(self: ColumnFormatter, items: []const []const u8) ![]const u8 {
        var result = std.ArrayList(u8){};
        errdefer result.deinit(self.allocator);

        for (items, 0..) |item, i| {
            // Truncate if too long
            const display = if (item.len > self.column_width)
                item[0..self.column_width]
            else
                item;

            try result.appendSlice(self.allocator, display);

            // Pad to column width
            const padding = self.column_width - display.len;
            var j: usize = 0;
            while (j < padding) : (j += 1) {
                try result.append(self.allocator, ' ');
            }

            // Add spacing between columns or newline
            if ((i + 1) % self.num_columns == 0) {
                try result.append(self.allocator, '\n');
            } else {
                try result.appendSlice(self.allocator, "  ");
            }
        }

        return result.toOwnedSlice(self.allocator);
    }
};

test "column formatter" {
    const items = [_][]const u8{ "apple", "banana", "cherry", "date" };
    const formatter = ColumnFormatter.init(testing.allocator, 40, 10);

    const result = try formatter.format(&items);
    defer testing.allocator.free(result);

    try testing.expect(result.len > 0);
    try testing.expect(std.mem.indexOf(u8, result, "apple") != null);
}
// ANCHOR_END: column_layout

// ANCHOR: progress_bar
/// Draw a progress bar that fits the terminal
fn drawProgressBar(
    allocator: std.mem.Allocator,
    current: usize,
    total: usize,
    width: usize,
) ![]const u8 {
    const percent = if (total > 0) (current * 100) / total else 0;

    // Reserve space for percentage and brackets
    const bar_width = if (width > 10) width - 10 else 10;

    const filled = (bar_width * current) / total;
    const empty = bar_width - filled;

    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    try result.append(allocator, '[');

    var i: usize = 0;
    while (i < filled) : (i += 1) {
        try result.append(allocator, '=');
    }

    i = 0;
    while (i < empty) : (i += 1) {
        try result.append(allocator, ' ');
    }

    try result.append(allocator, ']');
    try std.fmt.format(result.writer(allocator), " {d}%", .{percent});

    return result.toOwnedSlice(allocator);
}

test "progress bar" {
    const bar = try drawProgressBar(testing.allocator, 50, 100, 40);
    defer testing.allocator.free(bar);

    try testing.expect(std.mem.indexOf(u8, bar, "[") != null);
    try testing.expect(std.mem.indexOf(u8, bar, "]") != null);
    try testing.expect(std.mem.indexOf(u8, bar, "50%") != null);
}

test "progress bar full" {
    const bar = try drawProgressBar(testing.allocator, 100, 100, 30);
    defer testing.allocator.free(bar);

    try testing.expect(std.mem.indexOf(u8, bar, "100%") != null);
}
// ANCHOR_END: progress_bar

// ANCHOR: truncate_output
/// Truncate text to fit terminal width
fn truncateToWidth(allocator: std.mem.Allocator, text: []const u8, width: usize) ![]const u8 {
    if (text.len <= width) {
        return try allocator.dupe(u8, text);
    }

    if (width < 3) {
        return try allocator.dupe(u8, text[0..width]);
    }

    // Truncate with ellipsis
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    try result.appendSlice(allocator, text[0 .. width - 3]);
    try result.appendSlice(allocator, "...");

    return result.toOwnedSlice(allocator);
}

test "truncate short text" {
    const text = "Hello";
    const truncated = try truncateToWidth(testing.allocator, text, 10);
    defer testing.allocator.free(truncated);

    try testing.expectEqualStrings("Hello", truncated);
}

test "truncate long text" {
    const text = "This is a very long line of text that needs truncation";
    const truncated = try truncateToWidth(testing.allocator, text, 20);
    defer testing.allocator.free(truncated);

    try testing.expectEqual(20, truncated.len);
    try testing.expect(std.mem.endsWith(u8, truncated, "..."));
}
// ANCHOR_END: truncate_output

// ANCHOR: center_text
/// Center text in terminal width
fn centerText(allocator: std.mem.Allocator, text: []const u8, width: usize) ![]const u8 {
    if (text.len >= width) {
        return try allocator.dupe(u8, text);
    }

    const padding = width - text.len;
    const left_pad = padding / 2;
    const right_pad = padding - left_pad;

    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < left_pad) : (i += 1) {
        try result.append(allocator, ' ');
    }

    try result.appendSlice(allocator, text);

    i = 0;
    while (i < right_pad) : (i += 1) {
        try result.append(allocator, ' ');
    }

    return result.toOwnedSlice(allocator);
}

test "center text" {
    const text = "Hello";
    const centered = try centerText(testing.allocator, text, 15);
    defer testing.allocator.free(centered);

    try testing.expectEqual(15, centered.len);
    try testing.expect(std.mem.indexOf(u8, centered, "Hello") != null);
}

test "center text already wide" {
    const text = "Very long text here";
    const centered = try centerText(testing.allocator, text, 10);
    defer testing.allocator.free(centered);

    try testing.expectEqualStrings(text, centered);
}
// ANCHOR_END: center_text
