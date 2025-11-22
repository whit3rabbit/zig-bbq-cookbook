// Recipe 18.3: Memory-Mapped I/O for Large Files
// This recipe demonstrates using memory-mapped files for efficient access to large files,
// zero-copy operations, and shared memory patterns.

const std = @import("std");
const testing = std.testing;
const fs = std.fs;
const os = std.posix;

// ANCHOR: basic_mmap
// Basic memory-mapped file reading
test "basic memory-mapped file" {
    const filename = "test_mmap_basic.dat";
    defer fs.cwd().deleteFile(filename) catch {};

    // Create test file
    {
        const file = try fs.cwd().createFile(filename, .{});
        defer file.close();

        const data = "Hello, Memory-Mapped World!";
        try file.writeAll(data);
    }

    // Memory-map the file
    {
        const file = try fs.cwd().openFile(filename, .{});
        defer file.close();

        const file_size = (try file.stat()).size;
        const mapped = try os.mmap(
            null,
            file_size,
            os.PROT.READ,
            .{ .TYPE = .SHARED },
            file.handle,
            0,
        );
        defer os.munmap(mapped);

        try testing.expectEqualStrings("Hello, Memory-Mapped World!", mapped);
    }
}
// ANCHOR_END: basic_mmap

// ANCHOR: write_mmap
// Memory-mapped file for writing
test "memory-mapped file writing" {
    const filename = "test_mmap_write.dat";
    defer fs.cwd().deleteFile(filename) catch {};

    const data_size = 4096;

    // Create file with desired size
    {
        const file = try fs.cwd().createFile(filename, .{});
        defer file.close();

        try file.setEndPos(data_size);
    }

    // Memory-map for writing
    {
        const file = try fs.cwd().openFile(filename, .{ .mode = .read_write });
        defer file.close();

        const mapped = try os.mmap(
            null,
            data_size,
            os.PROT.READ | os.PROT.WRITE,
            .{ .TYPE = .SHARED },
            file.handle,
            0,
        );
        defer os.munmap(mapped);

        // Write to mapped memory
        const message = "Written via mmap";
        @memcpy(mapped[0..message.len], message);

        // Note: msync is platform-specific, skipped for portability
    }

    // Verify the write
    {
        const file = try fs.cwd().openFile(filename, .{});
        defer file.close();

        var buffer: [100]u8 = undefined;
        const bytes_read = try file.read(&buffer);
        try testing.expectEqualStrings("Written via mmap", buffer[0..16]);
        try testing.expect(bytes_read >= 16);
    }
}
// ANCHOR_END: write_mmap

// ANCHOR: large_file_search
// Efficient large file searching with mmap
fn searchInMappedFile(mapped: []const u8, needle: []const u8) ?usize {
    return std.mem.indexOf(u8, mapped, needle);
}

test "searching in memory-mapped file" {
    const filename = "test_mmap_search.dat";
    defer fs.cwd().deleteFile(filename) catch {};

    // Create file with test data
    {
        const file = try fs.cwd().createFile(filename, .{});
        defer file.close();

        var buffer: [4096]u8 = undefined;
        var i: usize = 0;
        while (i < 1000) : (i += 1) {
            const line = try std.fmt.bufPrint(&buffer, "Line {d}: Some test data here\n", .{i});
            try file.writeAll(line);
        }
        try file.writeAll("FINDME: This is the target line\n");
        i = 0;
        while (i < 1000) : (i += 1) {
            const line = try std.fmt.bufPrint(&buffer, "Line {d}: More test data\n", .{i + 1000});
            try file.writeAll(line);
        }
    }

    // Memory-map and search
    {
        const file = try fs.cwd().openFile(filename, .{});
        defer file.close();

        const file_size = (try file.stat()).size;
        const mapped = try os.mmap(
            null,
            file_size,
            os.PROT.READ,
            .{ .TYPE = .SHARED },
            file.handle,
            0,
        );
        defer os.munmap(mapped);

        const pos = searchInMappedFile(mapped, "FINDME");
        try testing.expect(pos != null);
        try testing.expect(pos.? > 0);
    }
}
// ANCHOR_END: large_file_search

// ANCHOR: binary_file_processing
// Processing binary data with mmap
const BinaryRecord = packed struct {
    id: u32,
    value: f64,
    flags: u32,
};

fn processRecords(data: []align(@alignOf(BinaryRecord)) const u8) !u64 {
    const records = std.mem.bytesAsSlice(BinaryRecord, data);
    var sum: u64 = 0;

    for (records) |record| {
        sum += record.id;
    }

    return sum;
}

test "binary file processing with mmap" {
    const filename = "test_mmap_binary.dat";
    defer fs.cwd().deleteFile(filename) catch {};

    const record_count = 100;

    // Create binary file
    {
        const file = try fs.cwd().createFile(filename, .{});
        defer file.close();

        var i: u32 = 0;
        while (i < record_count) : (i += 1) {
            const record = BinaryRecord{
                .id = i,
                .value = @as(f64, @floatFromInt(i)) * 1.5,
                .flags = i % 2,
            };
            const bytes = std.mem.asBytes(&record);
            try file.writeAll(bytes);
        }
    }

    // Memory-map and process
    {
        const file = try fs.cwd().openFile(filename, .{});
        defer file.close();

        const file_size = (try file.stat()).size;
        const mapped = try os.mmap(
            null,
            file_size,
            os.PROT.READ,
            .{ .TYPE = .SHARED },
            file.handle,
            0,
        );
        defer os.munmap(mapped);

        // Process records directly from mapped memory
        const sum = try processRecords(@alignCast(mapped));

        // Sum of 0..99 = 4950
        try testing.expectEqual(@as(u64, 4950), sum);
    }
}
// ANCHOR_END: binary_file_processing

// ANCHOR: safe_mmap_wrapper
// Safe memory-mapped file wrapper
const MappedFile = struct {
    file: fs.File,
    data: []align(std.heap.page_size_min) const u8,

    pub fn init(path: []const u8) !MappedFile {
        const file = try fs.cwd().openFile(path, .{});
        errdefer file.close();

        const file_size = (try file.stat()).size;
        if (file_size == 0) {
            return error.EmptyFile;
        }

        const mapped = try os.mmap(
            null,
            file_size,
            os.PROT.READ,
            .{ .TYPE = .SHARED },
            file.handle,
            0,
        );

        return .{
            .file = file,
            .data = mapped,
        };
    }

    pub fn deinit(self: *MappedFile) void {
        os.munmap(self.data);
        self.file.close();
    }

    pub fn slice(self: MappedFile) []const u8 {
        return self.data;
    }
};

test "safe mapped file wrapper" {
    const filename = "test_mmap_wrapper.dat";
    defer fs.cwd().deleteFile(filename) catch {};

    // Create test file
    {
        const file = try fs.cwd().createFile(filename, .{});
        defer file.close();
        try file.writeAll("Test data for wrapper");
    }

    // Use wrapper
    var mapped = try MappedFile.init(filename);
    defer mapped.deinit();

    try testing.expectEqualStrings("Test data for wrapper", mapped.slice());
}
// ANCHOR_END: safe_mmap_wrapper

// ANCHOR: performance_comparison
// Performance comparison: mmap vs read
test "mmap vs read performance" {
    const filename = "test_mmap_perf.dat";
    defer fs.cwd().deleteFile(filename) catch {};

    // Create large file (1 MB)
    const file_size = 1024 * 1024;
    {
        const file = try fs.cwd().createFile(filename, .{});
        defer file.close();

        var i: usize = 0;
        while (i < file_size) : (i += 1) {
            const byte = [_]u8{@as(u8, @intCast(i % 256))};
            try file.writeAll(&byte);
        }
    }

    // Test regular read
    var read_timer = try std.time.Timer.start();
    {
        const file = try fs.cwd().openFile(filename, .{});
        defer file.close();

        var buffer: [file_size]u8 = undefined;
        _ = try file.readAll(&buffer);

        var sum: u64 = 0;
        for (buffer) |byte| {
            sum += byte;
        }
        try testing.expect(sum > 0);
    }
    const read_ns = read_timer.read();

    // Test mmap
    var mmap_timer = try std.time.Timer.start();
    {
        const file = try fs.cwd().openFile(filename, .{});
        defer file.close();

        const mapped = try os.mmap(
            null,
            file_size,
            os.PROT.READ,
            .{ .TYPE = .SHARED },
            file.handle,
            0,
        );
        defer os.munmap(mapped);

        var sum: u64 = 0;
        for (mapped) |byte| {
            sum += byte;
        }
        try testing.expect(sum > 0);
    }
    const mmap_ns = mmap_timer.read();

    std.debug.print("\nRead: {d}ns, Mmap: {d}ns, Speedup: {d:.2}x\n", .{
        read_ns,
        mmap_ns,
        @as(f64, @floatFromInt(read_ns)) / @as(f64, @floatFromInt(mmap_ns)),
    });
}
// ANCHOR_END: performance_comparison
