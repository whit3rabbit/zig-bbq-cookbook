// Recipe 5.1: Reading and writing text data
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to efficiently read and write text files using
// buffered I/O operations, handle line-by-line processing, and manage file resources.

const std = @import("std");
const testing = std.testing;

// ANCHOR: write_read_text
/// Write text content to a file using buffered I/O
pub fn writeTextFile(path: []const u8, content: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    try writer.writeAll(content);
    try writer.flush();
}

/// Read entire text file into memory
pub fn readTextFile(
    allocator: std.mem.Allocator,
    path: []const u8,
) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = (try file.stat()).size;
    const buffer = try allocator.alloc(u8, file_size);

    const bytes_read = try file.readAll(buffer);
    return buffer[0..bytes_read];
}
// ANCHOR_END: write_read_text

// ANCHOR: line_processing
/// Process a file line by line and collect lines into an array
pub fn readLinesIntoList(
    allocator: std.mem.Allocator,
    path: []const u8,
) !std.array_list.Managed([]u8) {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var read_buf: [4096]u8 = undefined;
    var file_reader = file.reader(&read_buf);
    const reader = &file_reader.interface;

    var lines = std.array_list.Managed([]u8).init(allocator);
    errdefer {
        for (lines.items) |line| {
            allocator.free(line);
        }
        lines.deinit();
    }

    var line_writer = std.Io.Writer.Allocating.init(allocator);
    defer line_writer.deinit();

    while (true) {
        _ = reader.streamDelimiter(&line_writer.writer, '\n') catch |err| {
            if (err == error.EndOfStream) break else return err;
        };
        _ = reader.toss(1); // Skip the newline delimiter

        const line_copy = try allocator.dupe(u8, line_writer.written());
        try lines.append(line_copy);
        line_writer.clearRetainingCapacity();
    }

    // Handle last line if no trailing newline
    if (line_writer.written().len > 0) {
        const line_copy = try allocator.dupe(u8, line_writer.written());
        try lines.append(line_copy);
    }

    return lines;
}
// ANCHOR_END: line_processing

// ANCHOR: stream_transform
/// Write formatted lines to a file
pub fn writeFormattedLines(
    path: []const u8,
    data: []const i32,
) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    for (data, 0..) |value, i| {
        try writer.print("Item {}: {}\n", .{ i, value });
    }

    try writer.flush();
}

/// Read from one file and write to another, transforming content
pub fn processLargeFile(
    allocator: std.mem.Allocator,
    input_path: []const u8,
    output_path: []const u8,
) !usize {
    const input = try std.fs.cwd().openFile(input_path, .{});
    defer input.close();

    const output = try std.fs.cwd().createFile(output_path, .{});
    defer output.close();

    var read_buf: [4096]u8 = undefined;
    var write_buf: [4096]u8 = undefined;

    var input_reader = input.reader(&read_buf);
    var output_writer = output.writer(&write_buf);

    const reader = &input_reader.interface;
    const writer = &output_writer.interface;

    var line_count: usize = 0;
    var line_writer = std.Io.Writer.Allocating.init(allocator);
    defer line_writer.deinit();

    while (true) {
        _ = reader.streamDelimiter(&line_writer.writer, '\n') catch |err| {
            if (err == error.EndOfStream) break else return err;
        };
        _ = reader.toss(1); // Skip newline

        line_count += 1;

        // Transform: convert to uppercase
        const line = line_writer.written();
        for (line) |c| {
            const upper = if (c >= 'a' and c <= 'z') c - 32 else c;
            try writer.writeByte(upper);
        }
        try writer.writeByte('\n');
        line_writer.clearRetainingCapacity();
    }

    // Handle last line if no trailing newline
    if (line_writer.written().len > 0) {
        line_count += 1;
        const line = line_writer.written();
        for (line) |c| {
            const upper = if (c >= 'a' and c <= 'z') c - 32 else c;
            try writer.writeByte(upper);
        }
        try writer.writeByte('\n');
    }

    try writer.flush();
    return line_count;
}
// ANCHOR_END: stream_transform

/// Append text to an existing file
pub fn appendToFile(path: []const u8, content: []const u8) !void {
    const file = try std.fs.cwd().openFile(path, .{
        .mode = .read_write,
    });
    defer file.close();

    const end_pos = try file.getEndPos();
    try file.seekTo(end_pos);

    // Use unbuffered write for append to avoid issues with file positioning
    _ = try file.write(content);
}

/// Count lines in a file without loading entire file into memory
pub fn countLines(allocator: std.mem.Allocator, path: []const u8) !usize {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var read_buf: [4096]u8 = undefined;
    var file_reader = file.reader(&read_buf);
    const reader = &file_reader.interface;

    var count: usize = 0;
    var line_writer = std.Io.Writer.Allocating.init(allocator);
    defer line_writer.deinit();

    while (true) {
        _ = reader.streamDelimiter(&line_writer.writer, '\n') catch |err| {
            if (err == error.EndOfStream) break else return err;
        };
        _ = reader.toss(1); // Skip newline
        count += 1;
        line_writer.clearRetainingCapacity();
    }

    // Handle last line if no trailing newline
    if (line_writer.written().len > 0) {
        count += 1;
    }

    return count;
}

// Tests

test "write and read text file" {
    const allocator = testing.allocator;
    const test_path = "test_write_read.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const content = "Hello, Zig!\nThis is a test file.\nWith multiple lines.";

    // Write file
    try writeTextFile(test_path, content);

    // Read file
    const read_content = try readTextFile(allocator, test_path);
    defer allocator.free(read_content);

    try testing.expectEqualStrings(content, read_content);
}

test "read lines into list" {
    const allocator = testing.allocator;
    const test_path = "test_lines.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const content = "Line 1\nLine 2\nLine 3";
    try writeTextFile(test_path, content);

    var lines = try readLinesIntoList(allocator, test_path);
    defer {
        for (lines.items) |line| {
            allocator.free(line);
        }
        lines.deinit();
    }

    try testing.expectEqual(@as(usize, 3), lines.items.len);
    try testing.expectEqualStrings("Line 1", lines.items[0]);
    try testing.expectEqualStrings("Line 2", lines.items[1]);
    try testing.expectEqualStrings("Line 3", lines.items[2]);
}

test "write formatted lines" {
    const allocator = testing.allocator;
    const test_path = "test_formatted.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const data = [_]i32{ 10, 20, 30, 40, 50 };
    try writeFormattedLines(test_path, &data);

    const content = try readTextFile(allocator, test_path);
    defer allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "Item 0: 10") != null);
    try testing.expect(std.mem.indexOf(u8, content, "Item 4: 50") != null);
}

test "process large file with transformation" {
    const allocator = testing.allocator;
    const input_path = "test_input.txt";
    const output_path = "test_output.txt";
    defer std.fs.cwd().deleteFile(input_path) catch {};
    defer std.fs.cwd().deleteFile(output_path) catch {};

    const content = "hello world\nzig is awesome\nfile io test";
    try writeTextFile(input_path, content);

    const line_count = try processLargeFile(allocator, input_path, output_path);
    try testing.expectEqual(@as(usize, 3), line_count);

    const output_content = try readTextFile(allocator, output_path);
    defer allocator.free(output_content);

    try testing.expect(std.mem.indexOf(u8, output_content, "HELLO WORLD") != null);
    try testing.expect(std.mem.indexOf(u8, output_content, "ZIG IS AWESOME") != null);
}

test "append to file" {
    const allocator = testing.allocator;
    const test_path = "test_append.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write initial content
    try writeTextFile(test_path, "First line\n");

    // Append more content
    try appendToFile(test_path, "Second line\n");
    try appendToFile(test_path, "Third line\n");

    const content = try readTextFile(allocator, test_path);
    defer allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "First line") != null);
    try testing.expect(std.mem.indexOf(u8, content, "Second line") != null);
    try testing.expect(std.mem.indexOf(u8, content, "Third line") != null);
}

test "count lines" {
    const allocator = testing.allocator;
    const test_path = "test_count.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const content = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5";
    try writeTextFile(test_path, content);

    const count = try countLines(allocator, test_path);
    try testing.expectEqual(@as(usize, 5), count);
}

test "handle empty file" {
    const allocator = testing.allocator;
    const test_path = "test_empty.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    try writeTextFile(test_path, "");

    const content = try readTextFile(allocator, test_path);
    defer allocator.free(content);

    try testing.expectEqual(@as(usize, 0), content.len);

    const count = try countLines(allocator, test_path);
    try testing.expectEqual(@as(usize, 0), count);
}

test "handle file with single line no newline" {
    const allocator = testing.allocator;
    const test_path = "test_single.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    try writeTextFile(test_path, "Single line");

    const content = try readTextFile(allocator, test_path);
    defer allocator.free(content);

    try testing.expectEqualStrings("Single line", content);

    const count = try countLines(allocator, test_path);
    try testing.expectEqual(@as(usize, 1), count);
}

test "handle windows line endings" {
    const allocator = testing.allocator;
    const test_path = "test_crlf.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const content = "Line 1\r\nLine 2\r\nLine 3\r\n";
    try writeTextFile(test_path, content);

    var lines = try readLinesIntoList(allocator, test_path);
    defer {
        for (lines.items) |line| {
            allocator.free(line);
        }
        lines.deinit();
    }

    try testing.expectEqual(@as(usize, 3), lines.items.len);

    // Note: lines will have \r at the end, need to trim
    const line1 = std.mem.trimRight(u8, lines.items[0], "\r");
    try testing.expectEqualStrings("Line 1", line1);
}

test "memory safety with arena allocator" {
    const test_path = "test_arena.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const content = "Line 1\nLine 2\nLine 3\nLine 4\nLine 5\n";
    try writeTextFile(test_path, content);

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    // Read file multiple times - all allocations cleaned up together
    const read1 = try readTextFile(arena_alloc, test_path);
    const read2 = try readTextFile(arena_alloc, test_path);

    try testing.expectEqualStrings(content, read1);
    try testing.expectEqualStrings(content, read2);
    // No individual frees needed - arena.deinit() handles everything
}
