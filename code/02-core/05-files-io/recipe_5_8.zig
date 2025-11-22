const std = @import("std");

// ANCHOR: record_iterator
/// Basic record iterator
pub fn RecordIterator(comptime T: type) type {
    return struct {
        file: std.fs.File,
        buffer: [@sizeOf(T)]u8 = undefined,

        const Self = @This();

        pub fn init(file: std.fs.File) Self {
            return .{ .file = file };
        }

        pub fn next(self: *Self) !?T {
            const bytes_read = try self.file.read(&self.buffer);

            if (bytes_read == 0) return null;
            if (bytes_read < @sizeOf(T)) return error.PartialRecord;

            return @bitCast(self.buffer);
        }
    };
}

/// Buffered record iterator for better performance
pub fn BufferedRecordIterator(comptime T: type, comptime buffer_count: usize) type {
    return struct {
        file: std.fs.File,
        buffer: [buffer_count * @sizeOf(T)]u8 = undefined,
        position: usize = 0,
        count: usize = 0,

        const Self = @This();
        const record_size = @sizeOf(T);

        pub fn init(file: std.fs.File) Self {
            return .{ .file = file };
        }

        pub fn next(self: *Self) !?T {
            // Refill buffer if empty
            if (self.position >= self.count) {
                const bytes_read = try self.file.read(&self.buffer);
                if (bytes_read == 0) return null;

                self.count = bytes_read / record_size;
                self.position = 0;

                // Check for partial record
                if (bytes_read % record_size != 0) {
                    return error.PartialRecord;
                }
            }

            const offset = self.position * record_size;
            const record_bytes = self.buffer[offset..][0..record_size];
            self.position += 1;

            return @bitCast(record_bytes.*);
        }
    };
}
// ANCHOR_END: record_iterator

// ANCHOR: random_access
/// Random-access record file
pub fn RecordFile(comptime T: type) type {
    return struct {
        file: std.fs.File,

        const Self = @This();
        const record_size = @sizeOf(T);

        pub fn init(file: std.fs.File) Self {
            return .{ .file = file };
        }

        pub fn seekToRecord(self: *Self, index: usize) !void {
            try self.file.seekTo(index * record_size);
        }

        pub fn readRecord(self: *Self) !T {
            var buffer: [record_size]u8 = undefined;
            const bytes_read = try self.file.read(&buffer);

            if (bytes_read < record_size) return error.PartialRecord;

            return @bitCast(buffer);
        }

        pub fn writeRecord(self: *Self, record: T) !void {
            const bytes: [record_size]u8 = @bitCast(record);
            try self.file.writeAll(&bytes);
        }

        pub fn getRecordCount(self: *Self) !usize {
            const size = (try self.file.stat()).size;
            return size / record_size;
        }
    };
}

/// Read a record in reverse order
pub fn readRecordReverse(comptime T: type, file: std.fs.File, index: usize) !T {
    const record_size = @sizeOf(T);
    const offset = index * record_size;

    try file.seekTo(offset);

    var buffer: [record_size]u8 = undefined;
    const bytes_read = try file.read(&buffer);

    if (bytes_read < record_size) return error.PartialRecord;

    return @bitCast(buffer);
}
// ANCHOR_END: random_access

// ANCHOR: batch_processing
/// Process records in batches
pub fn processBatch(
    comptime T: type,
    file: std.fs.File,
    allocator: std.mem.Allocator,
    batch_size: usize,
    processor: *const fn ([]const T) anyerror!void,
) !void {
    const record_size = @sizeOf(T);
    const buffer = try allocator.alignedAlloc(u8, std.mem.Alignment.of(T), batch_size * record_size);
    defer allocator.free(buffer);

    while (true) {
        const bytes_read = try file.read(buffer);
        if (bytes_read == 0) break;

        const record_count = bytes_read / record_size;
        if (bytes_read % record_size != 0) return error.PartialRecord;

        // Cast buffer to record slice
        const records = std.mem.bytesAsSlice(T, buffer[0 .. record_count * record_size]);
        try processor(records);
    }
}
// ANCHOR_END: batch_processing

// Test record types

const SimpleRecord = extern struct {
    id: u32,
    value: f32,
    flags: u8,
    padding: [3]u8 = undefined,
};

const PlayerRecord = extern struct {
    player_id: u32,
    score: u32,
    level: u16,
    lives: u8,
    padding: u8 = 0,
};

// Tests

test "basic record iterator" {
    const test_path = "/tmp/test_records.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write test records
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();

        const records = [_]SimpleRecord{
            .{ .id = 1, .value = 1.5, .flags = 0 },
            .{ .id = 2, .value = 2.5, .flags = 1 },
            .{ .id = 3, .value = 3.5, .flags = 2 },
        };

        for (records) |record| {
            const bytes: [@sizeOf(SimpleRecord)]u8 = @bitCast(record);
            try file.writeAll(&bytes);
        }
    }

    // Read and verify
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var iter = RecordIterator(SimpleRecord).init(file);

    const r1 = (try iter.next()).?;
    try std.testing.expectEqual(@as(u32, 1), r1.id);
    try std.testing.expectEqual(@as(f32, 1.5), r1.value);

    const r2 = (try iter.next()).?;
    try std.testing.expectEqual(@as(u32, 2), r2.id);

    const r3 = (try iter.next()).?;
    try std.testing.expectEqual(@as(u32, 3), r3.id);

    try std.testing.expectEqual(@as(?SimpleRecord, null), try iter.next());
}

test "buffered record iterator" {
    const test_path = "/tmp/test_buffered_records.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write many records
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();

        var i: u32 = 0;
        while (i < 100) : (i += 1) {
            const record = SimpleRecord{
                .id = i,
                .value = @floatFromInt(i),
                .flags = @intCast(i % 256),
            };
            const bytes: [@sizeOf(SimpleRecord)]u8 = @bitCast(record);
            try file.writeAll(&bytes);
        }
    }

    // Read with buffered iterator
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var iter = BufferedRecordIterator(SimpleRecord, 10).init(file);
    var count: u32 = 0;

    while (try iter.next()) |record| {
        try std.testing.expectEqual(count, record.id);
        count += 1;
    }

    try std.testing.expectEqual(@as(u32, 100), count);
}

test "record file random access" {
    const test_path = "/tmp/test_random_access.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write records
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();

        var record_file = RecordFile(PlayerRecord).init(file);

        var i: u32 = 0;
        while (i < 10) : (i += 1) {
            const record = PlayerRecord{
                .player_id = i,
                .score = i * 100,
                .level = @intCast(i + 1),
                .lives = 3,
            };
            try record_file.writeRecord(record);
        }
    }

    // Read random access
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var record_file = RecordFile(PlayerRecord).init(file);

    // Get count
    const count = try record_file.getRecordCount();
    try std.testing.expectEqual(@as(usize, 10), count);

    // Seek to record 5
    try record_file.seekToRecord(5);
    const r5 = try record_file.readRecord();
    try std.testing.expectEqual(@as(u32, 5), r5.player_id);
    try std.testing.expectEqual(@as(u32, 500), r5.score);

    // Seek to record 0
    try record_file.seekToRecord(0);
    const r0 = try record_file.readRecord();
    try std.testing.expectEqual(@as(u32, 0), r0.player_id);
}

test "read record in reverse" {
    const test_path = "/tmp/test_reverse.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write records
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();

        var i: u32 = 0;
        while (i < 5) : (i += 1) {
            const record = SimpleRecord{
                .id = i,
                .value = @floatFromInt(i),
                .flags = @intCast(i),
            };
            const bytes: [@sizeOf(SimpleRecord)]u8 = @bitCast(record);
            try file.writeAll(&bytes);
        }
    }

    // Read in reverse
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var index: usize = 5;
    while (index > 0) {
        index -= 1;
        const record = try readRecordReverse(SimpleRecord, file, index);
        try std.testing.expectEqual(@as(u32, @intCast(index)), record.id);
    }
}

test "batch processing" {
    const test_path = "/tmp/test_batch.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write records
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();

        var i: u32 = 0;
        while (i < 20) : (i += 1) {
            const record = SimpleRecord{
                .id = i,
                .value = @floatFromInt(i),
                .flags = 0,
            };
            const bytes: [@sizeOf(SimpleRecord)]u8 = @bitCast(record);
            try file.writeAll(&bytes);
        }
    }

    // Process in batches
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const TestContext = struct {
        var total: u32 = 0;

        fn processor(records: []const SimpleRecord) !void {
            for (records) |_| {
                total += 1;
            }
        }
    };

    TestContext.total = 0;
    try processBatch(SimpleRecord, file, std.testing.allocator, 5, TestContext.processor);

    try std.testing.expectEqual(@as(u32, 20), TestContext.total);
}

test "empty file iteration" {
    const test_path = "/tmp/test_empty.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create empty file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
    }

    // Iterate
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var iter = RecordIterator(SimpleRecord).init(file);
    try std.testing.expectEqual(@as(?SimpleRecord, null), try iter.next());
}

test "partial record detection" {
    const test_path = "/tmp/test_partial.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write incomplete record
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();

        const partial_data = [_]u8{ 1, 2, 3, 4, 5 }; // Less than record size
        try file.writeAll(&partial_data);
    }

    // Try to read
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var iter = RecordIterator(SimpleRecord).init(file);
    const result = iter.next();

    try std.testing.expectError(error.PartialRecord, result);
}

test "record file update" {
    const test_path = "/tmp/test_update.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write initial records
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();

        var record_file = RecordFile(PlayerRecord).init(file);

        var i: u32 = 0;
        while (i < 5) : (i += 1) {
            const record = PlayerRecord{
                .player_id = i,
                .score = 0,
                .level = 1,
                .lives = 3,
            };
            try record_file.writeRecord(record);
        }
    }

    // Update record 2
    {
        const file = try std.fs.cwd().openFile(test_path, .{ .mode = .read_write });
        defer file.close();

        var record_file = RecordFile(PlayerRecord).init(file);

        try record_file.seekToRecord(2);
        const updated = PlayerRecord{
            .player_id = 2,
            .score = 9999,
            .level = 10,
            .lives = 1,
        };
        try record_file.writeRecord(updated);
    }

    // Verify update
    {
        const file = try std.fs.cwd().openFile(test_path, .{});
        defer file.close();

        var record_file = RecordFile(PlayerRecord).init(file);

        try record_file.seekToRecord(2);
        const record = try record_file.readRecord();

        try std.testing.expectEqual(@as(u32, 9999), record.score);
        try std.testing.expectEqual(@as(u16, 10), record.level);
    }
}

test "large file iteration" {
    const test_path = "/tmp/test_large.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const record_count = 10000;

    // Write large file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();

        var i: u32 = 0;
        while (i < record_count) : (i += 1) {
            const record = SimpleRecord{
                .id = i,
                .value = @floatFromInt(i),
                .flags = @intCast(i % 256),
            };
            const bytes: [@sizeOf(SimpleRecord)]u8 = @bitCast(record);
            try file.writeAll(&bytes);
        }
    }

    // Read and verify
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var iter = BufferedRecordIterator(SimpleRecord, 100).init(file);
    var count: u32 = 0;

    while (try iter.next()) |record| {
        try std.testing.expectEqual(count, record.id);
        count += 1;
    }

    try std.testing.expectEqual(@as(u32, record_count), count);
}

test "mixed read and write" {
    const test_path = "/tmp/test_mixed.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const file = try std.fs.cwd().createFile(test_path, .{ .read = true });
    defer file.close();

    var record_file = RecordFile(SimpleRecord).init(file);

    // Write
    try record_file.writeRecord(.{ .id = 1, .value = 1.0, .flags = 0 });
    try record_file.writeRecord(.{ .id = 2, .value = 2.0, .flags = 0 });

    // Seek and read
    try record_file.seekToRecord(0);
    const r1 = try record_file.readRecord();
    try std.testing.expectEqual(@as(u32, 1), r1.id);

    // Write another
    try record_file.seekToRecord(2);
    try record_file.writeRecord(.{ .id = 3, .value = 3.0, .flags = 0 });

    // Verify count
    const count = try record_file.getRecordCount();
    try std.testing.expectEqual(@as(usize, 3), count);
}
