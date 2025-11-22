// Recipe 5.21: File Position and Buffering Gotchas
// Target Zig Version: 0.15.2
//
// This recipe demonstrates common file I/O pitfalls that beginners encounter,
// particularly around file positions, read/write permissions, and buffering.

const std = @import("std");
const testing = std.testing;

// ANCHOR: write_then_read_wrong
/// GOTCHA: Writing then reading without resetting position
pub fn writeAndReadWrong(path: []const u8) ![]const u8 {
    const allocator = std.heap.page_allocator;

    const file = try std.fs.cwd().createFile(path, .{ .read = true });
    defer file.close();

    // Write data
    try file.writeAll("Hello, Zig!");

    // Try to read immediately - WRONG!
    var buf: [100]u8 = undefined;
    const n = try file.read(&buf); // n will be 0 - we're at EOF!

    return try allocator.dupe(u8, buf[0..n]); // Returns empty string!
}

/// CORRECT: Reset file position before reading
pub fn writeAndReadCorrect(path: []const u8) ![]const u8 {
    const allocator = std.heap.page_allocator;

    const file = try std.fs.cwd().createFile(path, .{ .read = true });
    defer file.close();

    // Write data
    try file.writeAll("Hello, Zig!");

    // Reset position to beginning
    try file.seekTo(0);

    // Now read works correctly
    var buf: [100]u8 = undefined;
    const n = try file.read(&buf);

    return try allocator.dupe(u8, buf[0..n]);
}
// ANCHOR_END: write_then_read_wrong

// ANCHOR: missing_read_permission
/// GOTCHA: Creating file without read permission
pub fn createWithoutReadPermission(path: []const u8) ![]const u8 {
    const allocator = std.heap.page_allocator;

    // Created without .read = true
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    try file.writeAll("Data");

    try file.seekTo(0);

    var buf: [100]u8 = undefined;
    const n = file.read(&buf) catch |err| {
        // Returns error.AccessDenied!
        std.debug.print("Error reading: {}\n", .{err});
        return err;
    };

    return try allocator.dupe(u8, buf[0..n]);
}

/// CORRECT: Create with read permission
pub fn createWithReadPermission(path: []const u8) ![]const u8 {
    const allocator = std.heap.page_allocator;

    // Create with .read = true
    const file = try std.fs.cwd().createFile(path, .{ .read = true });
    defer file.close();

    try file.writeAll("Data");
    try file.seekTo(0);

    var buf: [100]u8 = undefined;
    const n = try file.read(&buf);

    return try allocator.dupe(u8, buf[0..n]);
}
// ANCHOR_END: missing_read_permission

// ANCHOR: buffering_gotchas
/// GOTCHA: Not flushing buffered writer (Zig 0.15.2)
pub fn writeWithoutFlushing(path: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    try writer.writeAll("Important data");

    // MISSING: try writer.flush();
    // Data might not be written to disk!
}

/// CORRECT: Always flush buffered writers
pub fn writeWithFlushing(path: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    try writer.writeAll("Important data");

    // Always flush before closing!
    try writer.flush();
}

/// Understanding file position with buffered I/O
pub fn bufferedPositionExample(path: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{ .read = true });
    defer file.close();

    // Write with buffered writer
    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    try writer.writeAll("Line 1\n");
    try writer.writeAll("Line 2\n");
    try writer.flush(); // Flush to ensure data is written

    // Get position after writing
    const pos = try file.getPos();
    std.debug.print("Position after write: {}\n", .{pos});

    // Reset to read
    try file.seekTo(0);

    // Read with buffered reader
    var read_buf: [4096]u8 = undefined;
    var file_reader = file.reader(&read_buf);
    const reader = &file_reader.interface;

    var line_buf: [100]u8 = undefined;
    if (try reader.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        std.debug.print("Read line: {s}\n", .{line});
    }
}
// ANCHOR_END: buffering_gotchas

// ANCHOR: position_tracking
/// Track file position explicitly
pub const PositionTracker = struct {
    file: std.fs.File,
    expected_pos: u64,

    pub fn init(file: std.fs.File) PositionTracker {
        return .{ .file = file, .expected_pos = 0 };
    }

    pub fn write(self: *PositionTracker, data: []const u8) !void {
        try self.file.writeAll(data);
        self.expected_pos += data.len;
    }

    pub fn resetForReading(self: *PositionTracker) !void {
        try self.file.seekTo(0);
        self.expected_pos = 0;
    }

    pub fn read(self: *PositionTracker, buffer: []u8) !usize {
        const n = try self.file.read(buffer);
        self.expected_pos += n;
        return n;
    }

    pub fn currentPosition(self: *PositionTracker) u64 {
        return self.expected_pos;
    }

    pub fn verifyPosition(self: *PositionTracker) !void {
        const actual = try self.file.getPos();
        if (actual != self.expected_pos) {
            std.debug.print("Position mismatch! Expected: {}, Actual: {}\n", .{ self.expected_pos, actual });
            return error.PositionMismatch;
        }
    }
};
// ANCHOR_END: position_tracking

// ANCHOR: append_gotcha
/// GOTCHA: Appending and then trying to read
pub fn appendAndReadWrong(path: []const u8) ![]const u8 {
    const allocator = std.heap.page_allocator;

    // Open for writing (append mode)
    const file = try std.fs.cwd().openFile(path, .{
        .mode = .read_write,
    });
    defer file.close();

    // Seek to end for appending
    try file.seekFromEnd(0);

    // Write new data
    try file.writeAll("\nNew line");

    // Try to read - but we're at end of file!
    var buf: [100]u8 = undefined;
    const n = try file.read(&buf); // n will be 0

    return try allocator.dupe(u8, buf[0..n]); // Empty!
}

/// CORRECT: Seek to beginning before reading
pub fn appendAndReadCorrect(path: []const u8) ![]const u8 {
    const allocator = std.heap.page_allocator;

    const file = try std.fs.cwd().openFile(path, .{
        .mode = .read_write,
    });
    defer file.close();

    // Append new data
    try file.seekFromEnd(0);
    try file.writeAll("\nNew line");

    // Reset to beginning to read all content
    try file.seekTo(0);

    // Now we can read everything
    return try file.readToEndAlloc(allocator, 1024);
}
// ANCHOR_END: append_gotcha

// ANCHOR: partial_read_gotcha
/// GOTCHA: Assuming read() always fills the buffer
pub fn assumeFullRead(path: []const u8) !void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var buf: [1000]u8 = undefined;

    // WRONG: Assumes buffer is completely filled
    _ = try file.read(&buf);
    // If file is smaller than 1000 bytes, buf contains garbage!

    // What if we want to process the data?
    // This would include uninitialized memory!
    for (buf) |byte| {
        _ = byte; // Processing garbage data!
    }
}

/// CORRECT: Use the return value from read()
pub fn correctPartialRead(path: []const u8) !usize {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var buf: [1000]u8 = undefined;

    // Use the return value
    const bytes_read = try file.read(&buf);

    // Only process the bytes actually read
    for (buf[0..bytes_read]) |byte| {
        _ = byte; // Process only valid data
    }

    return bytes_read;
}

/// Use readAll() when you need the entire buffer filled
pub fn ensureFullRead(path: []const u8) !void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var buf: [1000]u8 = undefined;

    // readAll() returns error.EndOfStream if buffer can't be filled
    const bytes_read = try file.readAll(&buf);

    // Now we know buf is completely filled
    for (buf[0..bytes_read]) |byte| {
        _ = byte;
    }
}
// ANCHOR_END: partial_read_gotcha

// Tests

test "write then read without seek - demonstrates gotcha" {
    const test_path = "/tmp/test_write_read_wrong.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const result_wrong = try writeAndReadWrong(test_path);
    defer std.heap.page_allocator.free(result_wrong);

    // Result is empty because we didn't seek!
    try testing.expectEqual(@as(usize, 0), result_wrong.len);
}

test "write then read with seek - correct way" {
    const test_path = "/tmp/test_write_read_correct.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const result_correct = try writeAndReadCorrect(test_path);
    defer std.heap.page_allocator.free(result_correct);

    try testing.expectEqualStrings("Hello, Zig!", result_correct);
}

test "create without read permission fails" {
    const test_path = "/tmp/test_no_read.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const result = createWithoutReadPermission(test_path);
    try testing.expectError(error.NotOpenForReading, result);
}

test "create with read permission succeeds" {
    const test_path = "/tmp/test_with_read.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const result = try createWithReadPermission(test_path);
    defer std.heap.page_allocator.free(result);

    try testing.expectEqualStrings("Data", result);
}

test "buffered write without flush may lose data" {
    const test_path = "/tmp/test_no_flush.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    try writeWithoutFlushing(test_path);

    // Data might not be written - this is platform-dependent
    // On some systems, closing the file flushes automatically
    // But you should ALWAYS flush explicitly!
}

test "buffered write with flush ensures data" {
    const test_path = "/tmp/test_with_flush.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    try writeWithFlushing(test_path);

    // Verify data was written
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var buf: [100]u8 = undefined;
    const n = try file.read(&buf);

    try testing.expectEqualStrings("Important data", buf[0..n]);
}

test "position tracker" {
    const test_path = "/tmp/test_position.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const file = try std.fs.cwd().createFile(test_path, .{ .read = true });
    defer file.close();

    var tracker = PositionTracker.init(file);

    // Write some data
    try tracker.write("Hello");
    try testing.expectEqual(@as(u64, 5), tracker.currentPosition());

    try tracker.write(" World");
    try testing.expectEqual(@as(u64, 11), tracker.currentPosition());

    // Verify actual position matches
    try tracker.verifyPosition();

    // Reset for reading
    try tracker.resetForReading();
    try testing.expectEqual(@as(u64, 0), tracker.currentPosition());

    // Read data
    var buf: [100]u8 = undefined;
    _ = try tracker.read(&buf);
    try testing.expectEqual(@as(u64, 11), tracker.currentPosition());
}

test "append and read gotcha" {
    const test_path = "/tmp/test_append.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create initial file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("Initial content");
    }

    // Try wrong way
    const result_wrong = try appendAndReadWrong(test_path);
    defer std.heap.page_allocator.free(result_wrong);

    try testing.expectEqual(@as(usize, 0), result_wrong.len);

    // Try correct way
    const result_correct = try appendAndReadCorrect(test_path);
    defer std.heap.page_allocator.free(result_correct);

    try testing.expect(std.mem.indexOf(u8, result_correct, "Initial content") != null);
    try testing.expect(std.mem.indexOf(u8, result_correct, "New line") != null);
}

test "partial read demonstration" {
    const test_path = "/tmp/test_partial_read.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create small file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("Small");
    }

    const bytes_read = try correctPartialRead(test_path);
    try testing.expectEqual(@as(usize, 5), bytes_read);
}

test "readAll with file smaller than buffer succeeds" {
    const test_path = "/tmp/test_readall_small.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create small file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("Tiny");
    }

    // readAll with larger buffer succeeds
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var buf: [100]u8 = undefined;
    const n = try file.readAll(&buf);

    try testing.expectEqual(@as(usize, 4), n);
}

test "multiple writes and seeks" {
    const test_path = "/tmp/test_multi_seek.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const file = try std.fs.cwd().createFile(test_path, .{ .read = true });
    defer file.close();

    // Write at beginning
    try file.writeAll("Start");

    // Seek to position 0 and overwrite
    try file.seekTo(0);
    try file.writeAll("Begin");

    // Seek to end and append
    try file.seekFromEnd(0);
    try file.writeAll("End");

    // Read everything
    try file.seekTo(0);
    var buf: [100]u8 = undefined;
    const n = try file.read(&buf);

    try testing.expectEqualStrings("BeginEnd", buf[0..n]);
}

test "file position after truncate" {
    const test_path = "/tmp/test_truncate_pos.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const file = try std.fs.cwd().createFile(test_path, .{ .read = true });
    defer file.close();

    // Write data
    try file.writeAll("Hello, World!");

    // Truncate to 5 bytes
    try file.setEndPos(5);

    // Position might be beyond end of file now!
    const pos = try file.getPos();
    try testing.expectEqual(@as(u64, 13), pos); // Still at write position

    // Seek to beginning to read truncated content
    try file.seekTo(0);
    var buf: [100]u8 = undefined;
    const n = try file.read(&buf);

    try testing.expectEqualStrings("Hello", buf[0..n]);
}
