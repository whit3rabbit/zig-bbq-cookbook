const std = @import("std");

// ANCHOR: string_buffer_io
/// Parse a number from a string buffer
pub fn parseFromString(data: []const u8) !u32 {
    var fbs = std.io.fixedBufferStream(data);
    const reader = fbs.reader();

    // Read line by line
    var line_buf: [64]u8 = undefined;
    const line = try reader.readUntilDelimiter(&line_buf, '\n');

    return try std.fmt.parseInt(u32, line, 10);
}

/// Format a log message using a buffer stream
pub fn formatMessage(allocator: std.mem.Allocator, level: []const u8, text: []const u8) ![]u8 {
    var buffer: [512]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    const timestamp = std.time.timestamp();
    try writer.print("[{d}] {s}: {s}", .{ timestamp, level, text });

    return try allocator.dupe(u8, fbs.getWritten());
}

/// Item for report building
pub const Item = struct {
    name: []const u8,
    price: f64,
};

/// Build a formatted report
pub fn buildReport(allocator: std.mem.Allocator, items: []const Item) ![]u8 {
    var buffer: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    try writer.writeAll("REPORT\n");
    try writer.writeAll("======\n\n");

    for (items, 0..) |item, i| {
        try writer.print("{d}. {s}: ${d:.2}\n", .{ i + 1, item.name, item.price });
    }

    try writer.writeAll("\n");

    return try allocator.dupe(u8, fbs.getWritten());
}
// ANCHOR_END: string_buffer_io

// ANCHOR: binary_buffers
/// Write data to any writer (for testing)
fn writeData(writer: anytype, value: u32) !void {
    try writer.print("Value: {d}\n", .{value});
}

/// Parse binary header from memory
pub fn parseHeader(data: []const u8) !struct { magic: u32, version: u16 } {
    var fbs = std.io.fixedBufferStream(data);
    const reader = fbs.reader();

    var buf: [4]u8 = undefined;
    _ = try reader.read(&buf);
    const magic = std.mem.readInt(u32, &buf, .little);

    var buf2: [2]u8 = undefined;
    _ = try reader.read(&buf2);
    const version = std.mem.readInt(u16, &buf2, .little);

    return .{ .magic = magic, .version = version };
}

/// Build a binary packet
pub fn buildPacket(allocator: std.mem.Allocator, msg_type: u8, payload: []const u8) ![]u8 {
    var buffer: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    // Write header
    try writer.writeByte(msg_type);

    var len_buf: [2]u8 = undefined;
    std.mem.writeInt(u16, &len_buf, @intCast(payload.len), .little);
    try writer.writeAll(&len_buf);

    // Write payload
    try writer.writeAll(payload);

    return try allocator.dupe(u8, fbs.getWritten());
}
// ANCHOR_END: binary_buffers

// Tests

test "basic string I/O" {
    var buffer: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);

    // Write to buffer
    const writer = fbs.writer();
    try writer.writeAll("Hello, ");
    try writer.print("{s}!", .{"World"});

    // Get written data
    const written = fbs.getWritten();
    try std.testing.expectEqualStrings("Hello, World!", written);
}

test "parse from string" {
    const data = "42\nmore data";
    const value = try parseFromString(data);
    try std.testing.expectEqual(@as(u32, 42), value);
}

test "format message" {
    const allocator = std.testing.allocator;
    const result = try formatMessage(allocator, "INFO", "test message");
    defer allocator.free(result);

    // Check that it contains the expected parts
    try std.testing.expect(std.mem.indexOf(u8, result, "INFO") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "test message") != null);
}

test "seeking in buffer" {
    var buffer: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    // Write data
    try writer.writeAll("0123456789");

    // Seek to position 5
    fbs.pos = 5;

    // Overwrite from position 5
    try writer.writeAll("ABCDE");

    const written = fbs.getWritten();
    try std.testing.expectEqualStrings("01234ABCDE", written);
}

test "write then read" {
    var buffer: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);

    // Write data
    const writer = fbs.writer();
    try writer.writeAll("test data");

    // Get what was written
    const written = fbs.getWritten();

    // Create new stream over written data for reading
    var read_fbs = std.io.fixedBufferStream(written);
    const reader = read_fbs.reader();
    var read_buf: [10]u8 = undefined;
    const bytes_read = try reader.read(&read_buf);

    try std.testing.expectEqualStrings("test data", read_buf[0..bytes_read]);
}

test "build report" {
    const allocator = std.testing.allocator;

    const items = [_]Item{
        .{ .name = "Apple", .price = 1.50 },
        .{ .name = "Banana", .price = 0.75 },
        .{ .name = "Orange", .price = 2.00 },
    };

    const report = try buildReport(allocator, &items);
    defer allocator.free(report);

    try std.testing.expect(std.mem.indexOf(u8, report, "REPORT") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "Apple") != null);
    try std.testing.expect(std.mem.indexOf(u8, report, "1.50") != null);
}

test "writeData output" {
    var buffer: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);

    try writeData(fbs.writer(), 42);

    try std.testing.expectEqualStrings("Value: 42\n", fbs.getWritten());
}

test "parse binary header" {
    var buffer: [6]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    // Write header
    var magic_buf: [4]u8 = undefined;
    std.mem.writeInt(u32, &magic_buf, 0xDEADBEEF, .little);
    try writer.writeAll(&magic_buf);

    var version_buf: [2]u8 = undefined;
    std.mem.writeInt(u16, &version_buf, 123, .little);
    try writer.writeAll(&version_buf);

    // Parse it
    const header = try parseHeader(&buffer);
    try std.testing.expectEqual(@as(u32, 0xDEADBEEF), header.magic);
    try std.testing.expectEqual(@as(u16, 123), header.version);
}

test "build packet" {
    const allocator = std.testing.allocator;
    const packet = try buildPacket(allocator, 5, "hello");
    defer allocator.free(packet);

    // Verify packet structure
    try std.testing.expectEqual(@as(u8, 5), packet[0]); // msg_type

    const payload_len = std.mem.readInt(u16, packet[1..3], .little);
    try std.testing.expectEqual(@as(u16, 5), payload_len);

    try std.testing.expectEqualStrings("hello", packet[3..]);
}

test "dynamic string building" {
    const allocator = std.testing.allocator;
    var list: std.ArrayList(u8) = .{};
    defer list.deinit(allocator);

    const writer = list.writer(allocator);

    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        try writer.print("{d} ", .{i});
    }

    const result = try list.toOwnedSlice(allocator);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("0 1 2 3 4 5 6 7 8 9 ", result);
}

test "buffer overflow" {
    var buffer: [10]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    const result = writer.writeAll("This is too long");
    try std.testing.expectError(error.NoSpaceLeft, result);
}

test "multiple writes and reads" {
    var buffer: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);

    // Write multiple items
    const writer = fbs.writer();
    try writer.writeAll("line 1\n");
    try writer.writeAll("line 2\n");
    try writer.writeAll("line 3\n");

    // Reset and read
    fbs.pos = 0;
    const reader = fbs.reader();

    var line_buf: [20]u8 = undefined;

    const line1 = try reader.readUntilDelimiter(&line_buf, '\n');
    try std.testing.expectEqualStrings("line 1", line1);

    const line2 = try reader.readUntilDelimiter(&line_buf, '\n');
    try std.testing.expectEqualStrings("line 2", line2);

    const line3 = try reader.readUntilDelimiter(&line_buf, '\n');
    try std.testing.expectEqualStrings("line 3", line3);
}

test "getWritten vs getPos" {
    var buffer: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    try writer.writeAll("test");

    // pos tracks current position
    try std.testing.expectEqual(@as(usize, 4), fbs.pos);

    // getWritten returns slice up to current position
    try std.testing.expectEqualStrings("test", fbs.getWritten());
}

test "reset and reuse buffer" {
    var buffer: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    // First use
    try writer.writeAll("first");
    try std.testing.expectEqualStrings("first", fbs.getWritten());

    // Reset
    fbs.reset();
    try std.testing.expectEqual(@as(usize, 0), fbs.pos);

    // Second use
    try writer.writeAll("second");
    try std.testing.expectEqualStrings("second", fbs.getWritten());
}

test "reader read methods" {
    const data = "Hello\nWorld\n123";
    var fbs = std.io.fixedBufferStream(data);
    const reader = fbs.reader();

    // Read until delimiter
    var buf: [20]u8 = undefined;
    const line1 = try reader.readUntilDelimiter(&buf, '\n');
    try std.testing.expectEqualStrings("Hello", line1);

    // Read exact number of bytes
    var exact: [5]u8 = undefined;
    try reader.readNoEof(&exact);
    try std.testing.expectEqualStrings("World", &exact);
}

test "counting bytes written" {
    var buffer: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    const start_pos = fbs.pos;
    try writer.writeAll("test data");
    const bytes_written = fbs.pos - start_pos;

    try std.testing.expectEqual(@as(usize, 9), bytes_written);
}

test "partial reads" {
    const data = "0123456789";
    var fbs = std.io.fixedBufferStream(data);
    const reader = fbs.reader();

    var buf: [5]u8 = undefined;

    // First read
    const read1 = try reader.read(&buf);
    try std.testing.expectEqual(@as(usize, 5), read1);
    try std.testing.expectEqualStrings("01234", buf[0..read1]);

    // Second read
    const read2 = try reader.read(&buf);
    try std.testing.expectEqual(@as(usize, 5), read2);
    try std.testing.expectEqualStrings("56789", buf[0..read2]);

    // Third read (EOF)
    const read3 = try reader.read(&buf);
    try std.testing.expectEqual(@as(usize, 0), read3);
}

test "mixing read and write operations" {
    var buffer: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);

    // Write initial data
    try fbs.writer().writeAll("initial");

    // Read from beginning
    fbs.pos = 0;
    var read_buf: [7]u8 = undefined;
    try fbs.reader().readNoEof(&read_buf);
    try std.testing.expectEqualStrings("initial", &read_buf);

    // Continue writing
    try fbs.writer().writeAll(" more");

    try std.testing.expectEqualStrings("initial more", fbs.getWritten());
}
