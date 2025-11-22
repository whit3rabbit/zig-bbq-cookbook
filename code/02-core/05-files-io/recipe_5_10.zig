const std = @import("std");

const page_size_min = std.heap.page_size_min;

// ANCHOR: basic_mmap
/// Map file for reading only
pub fn mapFileReadOnly(path: []const u8) !struct {
    data: []align(page_size_min) const u8,
    file: std.fs.File,
} {
    const file = try std.fs.cwd().openFile(path, .{});
    errdefer file.close();

    const file_size = (try file.stat()).size;

    // Can't map empty files
    if (file_size == 0) {
        return error.EmptyFile;
    }

    const data = try std.posix.mmap(
        null,
        file_size,
        std.posix.PROT.READ,
        .{ .TYPE = .SHARED },
        file.handle,
        0,
    );

    return .{ .data = data, .file = file };
}

/// Map file for reading and writing
pub fn mapFileReadWrite(path: []const u8) !struct {
    data: []align(page_size_min) u8,
    file: std.fs.File,
} {
    const file = try std.fs.cwd().openFile(path, .{ .mode = .read_write });
    errdefer file.close();

    const file_size = (try file.stat()).size;

    const data = try std.posix.mmap(
        null,
        file_size,
        std.posix.PROT.READ | std.posix.PROT.WRITE,
        .{ .TYPE = .SHARED },
        file.handle,
        0,
    );

    return .{ .data = data, .file = file };
}

/// Map file with private copy-on-write mapping
pub fn mapFilePrivate(path: []const u8) !struct {
    data: []align(page_size_min) u8,
    file: std.fs.File,
} {
    const file = try std.fs.cwd().openFile(path, .{});
    errdefer file.close();

    const file_size = (try file.stat()).size;

    const data = try std.posix.mmap(
        null,
        file_size,
        std.posix.PROT.READ | std.posix.PROT.WRITE,
        .{ .TYPE = .PRIVATE },
        file.handle,
        0,
    );

    return .{ .data = data, .file = file };
}

/// Unmap and close file
pub fn unmapFile(mapping: anytype) void {
    std.posix.munmap(mapping.data);
    mapping.file.close();
}

/// Sync changes to disk
pub fn syncMapping(data: []align(page_size_min) u8, async_sync: bool) !void {
    const flags: c_int = if (async_sync) @intCast(std.posix.MSF.ASYNC) else @intCast(std.posix.MSF.SYNC);
    try std.posix.msync(data, flags);
}

/// Create anonymous memory mapping
pub fn createAnonymousMapping(size: usize) ![]align(page_size_min) u8 {
    const data = try std.posix.mmap(
        null,
        size,
        std.posix.PROT.READ | std.posix.PROT.WRITE,
        .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
        -1,
        0,
    );

    return data;
}
// ANCHOR_END: basic_mmap

// ANCHOR: structured_mmap
/// Mapped struct file for random access
pub fn MappedStructFile(comptime T: type) type {
    return struct {
        data: []align(page_size_min) const u8,
        file: std.fs.File,

        const Self = @This();
        const record_size = @sizeOf(T);

        pub fn init(path: []const u8) !Self {
            const file = try std.fs.cwd().openFile(path, .{});
            errdefer file.close();

            const file_size = (try file.stat()).size;

            const data = try std.posix.mmap(
                null,
                file_size,
                std.posix.PROT.READ,
                .{ .TYPE = .SHARED },
                file.handle,
                0,
            );

            return .{ .data = data, .file = file };
        }

        pub fn deinit(self: *Self) void {
            std.posix.munmap(self.data);
            self.file.close();
        }

        pub fn get(self: Self, index: usize) !T {
            const offset = index * record_size;
            if (offset + record_size > self.data.len) {
                return error.OutOfBounds;
            }

            const record_bytes = self.data[offset..][0..record_size];
            return @bitCast(record_bytes.*);
        }

        pub fn count(self: Self) usize {
            return self.data.len / record_size;
        }

        pub fn slice(self: Self) []const T {
            return std.mem.bytesAsSlice(T, self.data);
        }
    };
}

/// Binary search in mapped file
pub fn binarySearchMapped(
    comptime T: type,
    data: []align(page_size_min) const u8,
    key: T,
    comptime lessThan: fn (T, T) bool,
) ?usize {
    const records = std.mem.bytesAsSlice(T, data);

    var left: usize = 0;
    var right: usize = records.len;

    while (left < right) {
        const mid = left + (right - left) / 2;

        // Check if records[mid] == key by the ordering
        if (!lessThan(records[mid], key) and !lessThan(key, records[mid])) {
            return mid;
        } else if (lessThan(records[mid], key)) {
            left = mid + 1;
        } else {
            right = mid;
        }
    }

    return null;
}
// ANCHOR_END: structured_mmap

// Test structures

const Record = extern struct {
    id: u32,
    value: f32,

    pub fn eql(self: Record, other: Record) bool {
        return self.id == other.id and self.value == other.value;
    }
};

// Tests

test "map read only" {
    const test_path = "/tmp/test_mmap_ro.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create test file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("Hello, Memory Map!");
    }

    // Map and read
    const mapping = try mapFileReadOnly(test_path);
    defer unmapFile(mapping);

    try std.testing.expectEqualStrings("Hello, Memory Map!", mapping.data);
}

test "map read write" {
    const test_path = "/tmp/test_mmap_rw.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create test file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("AAAA");
    }

    // Map, modify, and sync
    {
        const mapping = try mapFileReadWrite(test_path);
        defer unmapFile(mapping);

        // Modify in place
        mapping.data[0] = 'B';
        mapping.data[1] = 'B';

        // Sync to disk
        try syncMapping(mapping.data, false);
    }

    // Verify changes persisted
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var buffer: [4]u8 = undefined;
    _ = try file.read(&buffer);

    try std.testing.expectEqualStrings("BBAA", &buffer);
}

test "map private copy-on-write" {
    const test_path = "/tmp/test_mmap_private.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create test file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("AAAA");
    }

    // Map with private mapping
    {
        const mapping = try mapFilePrivate(test_path);
        defer unmapFile(mapping);

        // Modify mapping (copy-on-write)
        mapping.data[0] = 'B';
        mapping.data[1] = 'B';

        // Changes are in memory but NOT written to file
    }

    // Verify file unchanged
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var buffer: [4]u8 = undefined;
    _ = try file.read(&buffer);

    try std.testing.expectEqualStrings("AAAA", &buffer);
}

test "anonymous mapping" {
    const size = page_size_min;
    const data = try createAnonymousMapping(size);
    defer std.posix.munmap(data);

    // Write to anonymous mapping
    @memset(data, 42);

    // Verify
    try std.testing.expect(std.mem.allEqual(u8, data, 42));
}

test "mapped struct file" {
    const test_path = "/tmp/test_mmap_struct.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create file with records
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();

        var i: u32 = 0;
        while (i < 10) : (i += 1) {
            const record = Record{
                .id = i,
                .value = @floatFromInt(i),
            };
            const bytes: [@sizeOf(Record)]u8 = @bitCast(record);
            try file.writeAll(&bytes);
        }
    }

    // Map and access
    var mapped = try MappedStructFile(Record).init(test_path);
    defer mapped.deinit();

    // Check count
    try std.testing.expectEqual(@as(usize, 10), mapped.count());

    // Random access
    const record5 = try mapped.get(5);
    try std.testing.expectEqual(@as(u32, 5), record5.id);
    try std.testing.expectEqual(@as(f32, 5.0), record5.value);

    // Slice access
    const all_records = mapped.slice();
    try std.testing.expectEqual(@as(usize, 10), all_records.len);
}

test "mapped struct file out of bounds" {
    const test_path = "/tmp/test_mmap_bounds.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create small file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();

        const record = Record{ .id = 1, .value = 1.0 };
        const bytes: [@sizeOf(Record)]u8 = @bitCast(record);
        try file.writeAll(&bytes);
    }

    var mapped = try MappedStructFile(Record).init(test_path);
    defer mapped.deinit();

    // Try to access out of bounds
    const result = mapped.get(10);
    try std.testing.expectError(error.OutOfBounds, result);
}

test "binary search in mapped file" {
    const test_path = "/tmp/test_mmap_search.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create sorted records
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();

        var i: u32 = 0;
        while (i < 100) : (i += 1) {
            const record = Record{
                .id = i * 2, // Even numbers only
                .value = @floatFromInt(i),
            };
            const bytes: [@sizeOf(Record)]u8 = @bitCast(record);
            try file.writeAll(&bytes);
        }
    }

    // Map and search
    const mapping = try mapFileReadOnly(test_path);
    defer unmapFile(mapping);

    const lessThan = struct {
        fn lt(a: Record, b: Record) bool {
            return a.id < b.id;
        }
    }.lt;

    // Search for existing key
    const found = binarySearchMapped(Record, mapping.data, Record{ .id = 50, .value = 0 }, lessThan);
    try std.testing.expect(found != null);
    try std.testing.expectEqual(@as(usize, 25), found.?);

    // Search for non-existing key
    const not_found = binarySearchMapped(Record, mapping.data, Record{ .id = 51, .value = 0 }, lessThan);
    try std.testing.expect(not_found == null);
}

test "map empty file" {
    const test_path = "/tmp/test_mmap_empty.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create empty file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
    }

    // Try to map empty file - should fail
    const result = mapFileReadOnly(test_path);
    try std.testing.expectError(error.EmptyFile, result);
}

test "map large file" {
    const test_path = "/tmp/test_mmap_large.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const size: usize = 1024 * 1024; // 1MB

    // Create large file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();

        const chunk = [_]u8{'X'} ** page_size_min;
        var remaining: usize = size;
        while (remaining > 0) {
            const to_write = @min(remaining, chunk.len);
            try file.writeAll(chunk[0..to_write]);
            remaining -= to_write;
        }
    }

    // Map and verify
    const mapping = try mapFileReadOnly(test_path);
    defer unmapFile(mapping);

    try std.testing.expectEqual(size, mapping.data.len);
    try std.testing.expect(std.mem.allEqual(u8, mapping.data, 'X'));
}

test "multiple mappings of same file" {
    const test_path = "/tmp/test_mmap_multiple.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create test file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("Shared Data");
    }

    // Create two mappings
    const mapping1 = try mapFileReadOnly(test_path);
    defer unmapFile(mapping1);

    const mapping2 = try mapFileReadOnly(test_path);
    defer unmapFile(mapping2);

    // Both should see same data
    try std.testing.expectEqualStrings("Shared Data", mapping1.data);
    try std.testing.expectEqualStrings("Shared Data", mapping2.data);
}

test "modify through one shared mapping visible in another" {
    const test_path = "/tmp/test_mmap_shared.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create test file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("AAAA");
    }

    // Create two read-write mappings
    const mapping1 = try mapFileReadWrite(test_path);
    defer unmapFile(mapping1);

    const mapping2 = try mapFileReadWrite(test_path);
    defer unmapFile(mapping2);

    // Modify through first mapping
    mapping1.data[0] = 'B';
    try syncMapping(mapping1.data, false);

    // Sync second mapping to see changes
    try syncMapping(mapping2.data, false);

    // Changes should be visible (though behavior may vary by system)
    try std.testing.expectEqual(@as(u8, 'B'), mapping2.data[0]);
}

test "page alignment" {
    const test_path = "/tmp/test_mmap_align.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create test file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("Test");
    }

    const mapping = try mapFileReadOnly(test_path);
    defer unmapFile(mapping);

    // Check that mapping is page-aligned
    const addr = @intFromPtr(mapping.data.ptr);
    try std.testing.expectEqual(@as(usize, 0), addr % page_size_min);
}

test "sync async vs sync" {
    const test_path = "/tmp/test_mmap_sync.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create test file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("AAAA");
    }

    const mapping = try mapFileReadWrite(test_path);
    defer unmapFile(mapping);

    // Modify
    mapping.data[0] = 'X';

    // Async sync (queues changes)
    try syncMapping(mapping.data, true);

    // Sync sync (waits for completion)
    try syncMapping(mapping.data, false);
}

test "access after file close" {
    const test_path = "/tmp/test_mmap_after_close.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create test file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("Data persists!");
    }

    var data: []align(page_size_min) const u8 = undefined;

    // Map file and close immediately
    {
        const mapping = try mapFileReadOnly(test_path);
        data = mapping.data;
        // File closed here via defer, but mapping still valid
        mapping.file.close();
    }

    // Data still accessible through mapping
    try std.testing.expectEqualStrings("Data persists!", data);

    // Clean up mapping
    std.posix.munmap(data);
}

test "random access pattern" {
    const test_path = "/tmp/test_mmap_random.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create file with identifiable data
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();

        var i: u8 = 0;
        while (i < 255) : (i += 1) {
            try file.writeAll(&[_]u8{i});
        }
    }

    const mapping = try mapFileReadOnly(test_path);
    defer unmapFile(mapping);

    // Random access
    try std.testing.expectEqual(@as(u8, 0), mapping.data[0]);
    try std.testing.expectEqual(@as(u8, 100), mapping.data[100]);
    try std.testing.expectEqual(@as(u8, 50), mapping.data[50]);
    try std.testing.expectEqual(@as(u8, 200), mapping.data[200]);
}
