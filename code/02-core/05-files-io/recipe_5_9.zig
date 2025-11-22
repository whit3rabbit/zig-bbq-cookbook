const std = @import("std");

// ANCHOR: basic_buffer_reads
/// Basic read into buffer
pub fn readIntoBuffer(file: std.fs.File, buffer: []u8) !usize {
    const bytes_read = try file.read(buffer);
    return bytes_read;
}

/// Read exact amount, error if not enough data
pub fn readExact(file: std.fs.File, buffer: []u8) !void {
    var index: usize = 0;
    while (index < buffer.len) {
        const bytes_read = try file.read(buffer[index..]);
        if (bytes_read == 0) return error.UnexpectedEndOfFile;
        index += bytes_read;
    }
}

/// Process file in chunks with callback
pub fn processFileInChunks(
    file: std.fs.File,
    processor: *const fn ([]const u8) anyerror!void,
) !void {
    var buffer: [4096]u8 = undefined;

    while (true) {
        const bytes_read = try file.read(&buffer);
        if (bytes_read == 0) break;

        try processor(buffer[0..bytes_read]);
    }
}

/// Read structured binary data
pub fn readStruct(comptime T: type, file: std.fs.File) !T {
    var buffer: [@sizeOf(T)]u8 = undefined;
    const bytes_read = try file.read(&buffer);

    if (bytes_read < @sizeOf(T)) return error.PartialRead;

    return @bitCast(buffer);
}
// ANCHOR_END: basic_buffer_reads

// ANCHOR: advanced_buffer_ops
/// Scatter read into multiple buffers
pub fn readScatter(file: std.fs.File, buffers: [][]u8) !usize {
    var total: usize = 0;

    for (buffers) |buffer| {
        const bytes_read = try file.read(buffer);
        total += bytes_read;
        if (bytes_read < buffer.len) break;
    }

    return total;
}

/// Read from specific position without changing file position
pub fn readAtOffset(file: std.fs.File, buffer: []u8, offset: u64) !usize {
    const original_pos = try file.getPos();
    defer file.seekTo(original_pos) catch {};

    try file.seekTo(offset);
    return try file.read(buffer);
}

/// Ring buffer for continuous reading
pub const RingBuffer = struct {
    buffer: []u8,
    read_pos: usize = 0,
    write_pos: usize = 0,
    count: usize = 0,

    pub fn init(buffer: []u8) RingBuffer {
        return .{ .buffer = buffer };
    }

    pub fn readFromFile(self: *RingBuffer, file: std.fs.File) !usize {
        if (self.count == self.buffer.len) return 0; // Buffer full

        const write_idx = self.write_pos;
        const available = self.buffer.len - self.count;

        const to_end = self.buffer.len - write_idx;
        const read_size = @min(available, to_end);

        const bytes_read = try file.read(self.buffer[write_idx..][0..read_size]);
        if (bytes_read == 0) return 0;

        self.write_pos = (write_idx + bytes_read) % self.buffer.len;
        self.count += bytes_read;

        return bytes_read;
    }

    pub fn consume(self: *RingBuffer, amount: usize) []const u8 {
        const to_read = @min(amount, self.count);
        const read_idx = self.read_pos;

        const to_end = self.buffer.len - read_idx;
        const chunk_size = @min(to_read, to_end);

        const result = self.buffer[read_idx..][0..chunk_size];

        self.read_pos = (read_idx + chunk_size) % self.buffer.len;
        self.count -= chunk_size;

        return result;
    }
};

/// Safe read with error handling
pub fn safeRead(file: std.fs.File, buffer: []u8) !usize {
    return file.read(buffer) catch |err| switch (err) {
        error.InputOutput => {
            std.debug.print("I/O error reading file\n", .{});
            return error.ReadFailed;
        },
        error.AccessDenied => {
            std.debug.print("Access denied\n", .{});
            return error.PermissionDenied;
        },
        error.BrokenPipe => return 0, // Treat as EOF
        else => return err,
    };
}
// ANCHOR_END: advanced_buffer_ops

// Test structures

const Header = extern struct {
    magic: u32,
    version: u16,
    flags: u16,
};

// Tests

test "read into buffer" {
    const test_path = "/tmp/test_buffer.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write test data
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("Hello, World!");
    }

    // Read into buffer
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var buffer: [32]u8 = undefined;
    const bytes_read = try readIntoBuffer(file, &buffer);

    try std.testing.expectEqual(@as(usize, 13), bytes_read);
    try std.testing.expectEqualStrings("Hello, World!", buffer[0..bytes_read]);
}

test "read exact amount" {
    const test_path = "/tmp/test_exact.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write exactly 100 bytes
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        const data = [_]u8{42} ** 100;
        try file.writeAll(&data);
    }

    // Read exactly 100 bytes
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var buffer: [100]u8 = undefined;
    try readExact(file, &buffer);

    try std.testing.expect(std.mem.allEqual(u8, &buffer, 42));
}

test "read exact fails on short file" {
    const test_path = "/tmp/test_exact_short.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write 50 bytes
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        const data = [_]u8{42} ** 50;
        try file.writeAll(&data);
    }

    // Try to read 100 bytes
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var buffer: [100]u8 = undefined;
    const result = readExact(file, &buffer);

    try std.testing.expectError(error.UnexpectedEndOfFile, result);
}

test "read into slices" {
    const test_path = "/tmp/test_slices.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write test data
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("A" ** 512 ++ "B" ** 512);
    }

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var data: [1024]u8 = undefined;

    // Read into first half
    const first_half = try file.read(data[0..512]);
    try std.testing.expectEqual(@as(usize, 512), first_half);

    // Read into second half
    const second_half = try file.read(data[512..]);
    try std.testing.expectEqual(@as(usize, 512), second_half);

    // Verify
    try std.testing.expect(std.mem.allEqual(u8, data[0..512], 'A'));
    try std.testing.expect(std.mem.allEqual(u8, data[512..], 'B'));
}

test "reuse buffer" {
    const test_path = "/tmp/test_reuse.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write large file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();

        var i: usize = 0;
        while (i < 10000) : (i += 1) {
            try file.writeAll("X");
        }
    }

    // Count chunks
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const Counter = struct {
        var count: usize = 0;
        fn process(data: []const u8) !void {
            _ = data;
            count += 1;
        }
    };

    Counter.count = 0;
    try processFileInChunks(file, Counter.process);

    try std.testing.expect(Counter.count > 0);
}

test "read struct" {
    const test_path = "/tmp/test_struct.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write header
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();

        const header = Header{
            .magic = 0xDEADBEEF,
            .version = 1,
            .flags = 0x0042,
        };
        const bytes: [@sizeOf(Header)]u8 = @bitCast(header);
        try file.writeAll(&bytes);
    }

    // Read header
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const header = try readStruct(Header, file);

    try std.testing.expectEqual(@as(u32, 0xDEADBEEF), header.magic);
    try std.testing.expectEqual(@as(u16, 1), header.version);
}

test "scatter read" {
    const test_path = "/tmp/test_scatter.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write test data
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("AAAABBBBCCCC");
    }

    // Read into multiple buffers
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var buf1: [4]u8 = undefined;
    var buf2: [4]u8 = undefined;
    var buf3: [4]u8 = undefined;

    var buffers = [_][]u8{ &buf1, &buf2, &buf3 };
    const total = try readScatter(file, &buffers);

    try std.testing.expectEqual(@as(usize, 12), total);
    try std.testing.expectEqualStrings("AAAA", &buf1);
    try std.testing.expectEqualStrings("BBBB", &buf2);
    try std.testing.expectEqualStrings("CCCC", &buf3);
}

test "read at offset" {
    const test_path = "/tmp/test_offset.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write test data
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("0123456789");
    }

    // Read from offset 5
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var buffer: [3]u8 = undefined;
    const bytes_read = try readAtOffset(file, &buffer, 5);

    try std.testing.expectEqual(@as(usize, 3), bytes_read);
    try std.testing.expectEqualStrings("567", &buffer);

    // File position unchanged
    try std.testing.expectEqual(@as(u64, 0), try file.getPos());
}

test "ring buffer reading" {
    const test_path = "/tmp/test_ring.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write test data
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("ABCDEFGHIJKLMNOP");
    }

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var backing_buffer: [8]u8 = undefined;
    var ring = RingBuffer.init(&backing_buffer);

    // Read first chunk
    const read1 = try ring.readFromFile(file);
    try std.testing.expectEqual(@as(usize, 8), read1);
    try std.testing.expectEqual(@as(usize, 8), ring.count);

    // Consume 4 bytes
    const chunk1 = ring.consume(4);
    try std.testing.expectEqualStrings("ABCD", chunk1);
    try std.testing.expectEqual(@as(usize, 4), ring.count);

    // Read more (wraps around)
    const read2 = try ring.readFromFile(file);
    try std.testing.expectEqual(@as(usize, 4), read2);
    try std.testing.expectEqual(@as(usize, 8), ring.count);

    // Consume all
    const chunk2 = ring.consume(4);
    try std.testing.expectEqualStrings("EFGH", chunk2);

    const chunk3 = ring.consume(4);
    try std.testing.expectEqualStrings("IJKL", chunk3);

    try std.testing.expectEqual(@as(usize, 0), ring.count);
}

test "ring buffer full" {
    const test_path = "/tmp/test_ring_full.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write test data
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("ABCDEFGHIJKLMNOP");
    }

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var backing_buffer: [8]u8 = undefined;
    var ring = RingBuffer.init(&backing_buffer);

    // Fill buffer
    const read1 = try ring.readFromFile(file);
    try std.testing.expectEqual(@as(usize, 8), read1);

    // Try to read when full
    const read2 = try ring.readFromFile(file);
    try std.testing.expectEqual(@as(usize, 0), read2);
}

test "safe read with error handling" {
    const test_path = "/tmp/test_safe.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write test data
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("Safe read test");
    }

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var buffer: [32]u8 = undefined;
    const bytes_read = try safeRead(file, &buffer);

    try std.testing.expectEqual(@as(usize, 14), bytes_read);
    try std.testing.expectEqualStrings("Safe read test", buffer[0..bytes_read]);
}

test "read empty file" {
    const test_path = "/tmp/test_empty.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create empty file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
    }

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var buffer: [32]u8 = undefined;
    const bytes_read = try readIntoBuffer(file, &buffer);

    try std.testing.expectEqual(@as(usize, 0), bytes_read);
}

test "partial struct read fails" {
    const test_path = "/tmp/test_partial_struct.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write partial header
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        const partial_data = [_]u8{ 1, 2, 3, 4 }; // Less than Header size
        try file.writeAll(&partial_data);
    }

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const result = readStruct(Header, file);

    try std.testing.expectError(error.PartialRead, result);
}

test "read with buffer smaller than file" {
    const test_path = "/tmp/test_small_buffer.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write large data
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("A" ** 1000);
    }

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var buffer: [100]u8 = undefined;
    const bytes_read = try readIntoBuffer(file, &buffer);

    // Should read buffer size, not file size
    try std.testing.expectEqual(@as(usize, 100), bytes_read);
    try std.testing.expect(std.mem.allEqual(u8, &buffer, 'A'));
}

test "multiple reads from same file" {
    const test_path = "/tmp/test_multiple.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write test data
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("AAAABBBBCCCC");
    }

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var buf1: [4]u8 = undefined;
    var buf2: [4]u8 = undefined;
    var buf3: [4]u8 = undefined;

    const read1 = try readIntoBuffer(file, &buf1);
    const read2 = try readIntoBuffer(file, &buf2);
    const read3 = try readIntoBuffer(file, &buf3);

    try std.testing.expectEqual(@as(usize, 4), read1);
    try std.testing.expectEqual(@as(usize, 4), read2);
    try std.testing.expectEqual(@as(usize, 4), read3);

    try std.testing.expectEqualStrings("AAAA", &buf1);
    try std.testing.expectEqualStrings("BBBB", &buf2);
    try std.testing.expectEqualStrings("CCCC", &buf3);
}

test "scatter read with partial last buffer" {
    const test_path = "/tmp/test_scatter_partial.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write 10 bytes
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("AAAABBBBCC");
    }

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var buf1: [4]u8 = undefined;
    var buf2: [4]u8 = undefined;
    var buf3: [4]u8 = undefined;

    var buffers = [_][]u8{ &buf1, &buf2, &buf3 };
    const total = try readScatter(file, &buffers);

    // Should read 10 bytes total (4 + 4 + 2)
    try std.testing.expectEqual(@as(usize, 10), total);
    try std.testing.expectEqualStrings("AAAA", &buf1);
    try std.testing.expectEqualStrings("BBBB", &buf2);
    // buf3 only partially filled
}
