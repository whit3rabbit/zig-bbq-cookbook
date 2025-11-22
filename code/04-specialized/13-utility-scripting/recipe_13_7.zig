const std = @import("std");
const testing = std.testing;

// SECURITY: Archive format limits to prevent Denial of Service attacks
// These limits protect against malicious archives that claim unreasonable sizes
// to exhaust memory or processing resources without providing actual data.

/// Maximum size for an individual archive entry (100MB)
/// Rationale: Prevents attackers from causing OOM by claiming multi-GB entries
/// without providing data. 100MB is reasonable for most file types while being
/// small enough to avoid exhausting memory on resource-constrained systems.
/// This matches common cloud service limits and the existing readFileAlloc limit.
const MAX_ENTRY_SIZE: u32 = 100 * 1024 * 1024;

/// Maximum length for an entry name/path (4096 bytes)
/// Rationale: Prevents path traversal exploits and excessive memory allocation.
/// 4096 is a common filesystem path limit on modern systems, well above typical
/// needs (Linux PATH_MAX is 4096, Windows MAX_PATH is 260 but can be extended).
/// Prevents attackers from forcing allocation of multi-MB name buffers.
const MAX_PATH_LENGTH: u32 = 4096;

/// Maximum number of entries in a single archive (1 million)
/// Rationale: Prevents death by a thousand cuts - attackers could create archives
/// with millions of tiny entries to exhaust memory through metadata alone.
/// 1 million entries is far beyond typical use while preventing abuse.
/// At ~100 bytes overhead per entry, this caps metadata at ~100MB.
const MAX_ENTRY_COUNT: u32 = 1_000_000;

/// Maximum total size of all entries combined (512MB)
/// Rationale: Prevents aggregate memory DoS where an attacker creates many entries
/// that individually pass MAX_ENTRY_SIZE checks but collectively exhaust memory.
/// Example attack: 50 entries × 99MB each = 4.95GB, bypassing per-entry limits.
/// 512MB is a reasonable cap for in-memory archives while preventing OOM attacks.
const MAX_TOTAL_ARCHIVE_SIZE: u64 = 512 * 1024 * 1024;

// ANCHOR: archive_entry
/// Simple archive entry
pub const ArchiveEntry = struct {
    name: []const u8,
    data: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, data: []const u8) !ArchiveEntry {
        return .{
            .name = try allocator.dupe(u8, name),
            .data = try allocator.dupe(u8, data),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ArchiveEntry) void {
        self.allocator.free(self.name);
        self.allocator.free(self.data);
    }
};

/// Simple archive format (custom, for demonstration)
pub const SimpleArchive = struct {
    entries: std.ArrayList(ArchiveEntry),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) SimpleArchive {
        return .{
            .entries = std.ArrayList(ArchiveEntry){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SimpleArchive) void {
        for (self.entries.items) |*entry| {
            entry.deinit();
        }
        self.entries.deinit(self.allocator);
    }

    pub fn addFile(self: *SimpleArchive, name: []const u8, data: []const u8) !void {
        const entry = try ArchiveEntry.init(self.allocator, name, data);
        try self.entries.append(self.allocator, entry);
    }

    pub fn addFileFromDisk(self: *SimpleArchive, path: []const u8) !void {
        // Use MAX_ENTRY_SIZE constant for consistency with load() validation
        const data = try std.fs.cwd().readFileAlloc(self.allocator, path, MAX_ENTRY_SIZE);
        errdefer self.allocator.free(data);

        const entry = ArchiveEntry{
            .name = try self.allocator.dupe(u8, path),
            .data = data,
            .allocator = self.allocator,
        };

        try self.entries.append(self.allocator, entry);
    }

    pub fn save(self: *const SimpleArchive, path: []const u8) !void {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();

        // Write number of entries
        const num_entries: u32 = @intCast(self.entries.items.len);
        var buf: [4]u8 = undefined;
        std.mem.writeInt(u32, &buf, num_entries, .little);
        try file.writeAll(&buf);

        // Write each entry
        for (self.entries.items) |entry| {
            // Write name length and name
            const name_len: u32 = @intCast(entry.name.len);
            std.mem.writeInt(u32, &buf, name_len, .little);
            try file.writeAll(&buf);
            try file.writeAll(entry.name);

            // Write data length and data
            const data_len: u32 = @intCast(entry.data.len);
            std.mem.writeInt(u32, &buf, data_len, .little);
            try file.writeAll(&buf);
            try file.writeAll(entry.data);
        }
    }

    pub fn load(allocator: std.mem.Allocator, path: []const u8) !SimpleArchive {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        var archive = SimpleArchive.init(allocator);
        errdefer archive.deinit();

        // Read number of entries
        var buf: [4]u8 = undefined;
        _ = try file.readAll(&buf);
        const num_entries = std.mem.readInt(u32, &buf, .little);

        // SECURITY: Validate entry count before processing to prevent DoS
        // A malicious archive could claim billions of entries to exhaust memory
        // through metadata overhead alone (death by a thousand cuts attack).
        if (num_entries > MAX_ENTRY_COUNT) {
            return error.TooManyEntries;
        }

        // SECURITY: Track cumulative allocation to prevent aggregate memory DoS
        // An attacker could create many entries that individually pass size checks
        // but collectively exhaust memory (e.g., 50 × 99MB = 4.95GB). This counter
        // ensures the total memory footprint stays within MAX_TOTAL_ARCHIVE_SIZE.
        var total_allocated: u64 = 0;

        var i: u32 = 0;
        while (i < num_entries) : (i += 1) {
            // Read name length
            _ = try file.readAll(&buf);
            const name_len = std.mem.readInt(u32, &buf, .little);

            // SECURITY: Validate name length before allocation to prevent DoS
            // Without this check, an attacker could claim 4GB name lengths and
            // crash the program with OOM even if the file contains no data.
            // This also mitigates path traversal by rejecting unreasonably long paths.
            if (name_len > MAX_PATH_LENGTH) {
                return error.PathTooLong;
            }
            if (name_len == 0) {
                return error.EmptyPath;
            }

            // SECURITY: Check cumulative allocation before allocating name
            // This prevents aggregate DoS from many large names
            if (total_allocated + name_len > MAX_TOTAL_ARCHIVE_SIZE) {
                return error.ArchiveTooLarge;
            }

            // Read name (safe to allocate - validated above)
            const name = try allocator.alloc(u8, name_len);
            errdefer allocator.free(name);
            _ = try file.readAll(name);
            total_allocated += name_len;

            // Read data length
            _ = try file.readAll(&buf);
            const data_len = std.mem.readInt(u32, &buf, .little);

            // SECURITY: Validate data size before allocation to prevent DoS
            // This is the primary DoS vector: attacker claims 4GB data without
            // providing it, causing instant OOM crash. This check prevents that
            // by rejecting unreasonable sizes before attempting allocation.
            // The limit is generous (100MB) but prevents resource exhaustion.
            if (data_len > MAX_ENTRY_SIZE) {
                return error.EntryTooLarge;
            }

            // SECURITY: Check cumulative allocation before allocating data
            // This is the main aggregate DoS protection. Even if each entry is
            // under MAX_ENTRY_SIZE (100MB), an attacker could create 50 entries
            // of 99MB each (4.95GB total) to cause OOM. This check ensures the
            // total memory footprint stays within MAX_TOTAL_ARCHIVE_SIZE (512MB).
            if (total_allocated + data_len > MAX_TOTAL_ARCHIVE_SIZE) {
                return error.ArchiveTooLarge;
            }

            // Read data (safe to allocate - validated above)
            const data = try allocator.alloc(u8, data_len);
            errdefer allocator.free(data);
            _ = try file.readAll(data);
            total_allocated += data_len;

            const entry = ArchiveEntry{
                .name = name,
                .data = data,
                .allocator = allocator,
            };

            try archive.entries.append(allocator, entry);
        }

        return archive;
    }

    pub fn extract(self: *const SimpleArchive, output_dir: []const u8) !void {
        // SECURITY: Open the output directory once to constrain all operations within it
        var out_dir = try std.fs.cwd().makeOpenPath(output_dir, .{});
        defer out_dir.close();

        for (self.entries.items) |entry| {
            // SECURITY: Validate path to prevent path traversal attacks
            // Reject absolute paths that could write anywhere on the filesystem
            if (std.fs.path.isAbsolute(entry.name)) {
                return error.InvalidEntryPath;
            }

            // SECURITY: Check for ".." path components using proper path parsing
            // This prevents path traversal while allowing filenames containing ".."
            // (e.g., "file..txt" is safe, but "subdir/../../../etc/passwd" is not)
            var iter = try std.fs.path.componentIterator(entry.name);
            while (iter.next()) |component| {
                // Reject if any path component is exactly ".."
                if (std.mem.eql(u8, component.name, "..")) {
                    return error.InvalidEntryPath;
                }
            }

            // Create parent directories if needed (constrained within out_dir)
            if (std.fs.path.dirname(entry.name)) |dir| {
                try out_dir.makePath(dir);
            }

            // Write file using the directory handle (stays within output_dir)
            try out_dir.writeFile(.{ .sub_path = entry.name, .data = entry.data });
        }
    }

    pub fn list(self: *const SimpleArchive) void {
        for (self.entries.items) |entry| {
            std.debug.print("{s} ({d} bytes)\n", .{ entry.name, entry.data.len });
        }
    }
};

test "simple archive" {
    const archive_path = "zig-cache/test.archive";
    std.fs.cwd().deleteFile(archive_path) catch {};
    defer std.fs.cwd().deleteFile(archive_path) catch {};

    // Create archive
    {
        var archive = SimpleArchive.init(testing.allocator);
        defer archive.deinit();

        try archive.addFile("file1.txt", "Content of file 1");
        try archive.addFile("file2.txt", "Content of file 2");

        try archive.save(archive_path);
    }

    // Load archive
    {
        var archive = try SimpleArchive.load(testing.allocator, archive_path);
        defer archive.deinit();

        try testing.expectEqual(2, archive.entries.items.len);
        try testing.expectEqualStrings("file1.txt", archive.entries.items[0].name);
        try testing.expectEqualStrings("Content of file 1", archive.entries.items[0].data);
    }
}
// ANCHOR_END: archive_entry

// ANCHOR: directory_archive
/// Archive an entire directory
pub fn archiveDirectory(allocator: std.mem.Allocator, dir_path: []const u8, archive_path: []const u8) !void {
    var archive = SimpleArchive.init(allocator);
    defer archive.deinit();

    try addDirectoryToArchive(allocator, &archive, dir_path, "");

    try archive.save(archive_path);
}

fn addDirectoryToArchive(
    allocator: std.mem.Allocator,
    archive: *SimpleArchive,
    dir_path: []const u8,
    prefix: []const u8,
) !void {
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        const entry_name = if (prefix.len > 0)
            try std.fs.path.join(allocator, &.{ prefix, entry.name })
        else
            try allocator.dupe(u8, entry.name);
        defer allocator.free(entry_name);

        const full_path = try std.fs.path.join(allocator, &.{ dir_path, entry.name });
        defer allocator.free(full_path);

        if (entry.kind == .file) {
            // Use MAX_ENTRY_SIZE constant for consistency
            const data = try std.fs.cwd().readFileAlloc(allocator, full_path, MAX_ENTRY_SIZE);
            errdefer allocator.free(data);

            const stored_entry = ArchiveEntry{
                .name = try allocator.dupe(u8, entry_name),
                .data = data,
                .allocator = allocator,
            };

            try archive.entries.append(allocator, stored_entry);
        } else if (entry.kind == .directory) {
            try addDirectoryToArchive(allocator, archive, full_path, entry_name);
        }
    }
}

test "directory archive" {
    const test_dir = "zig-cache/test_archive_dir";
    const archive_path = "zig-cache/test_dir.archive";
    const extract_dir = "zig-cache/test_extract_dir";

    std.fs.cwd().deleteTree(test_dir) catch {};
    std.fs.cwd().deleteFile(archive_path) catch {};
    std.fs.cwd().deleteTree(extract_dir) catch {};
    defer std.fs.cwd().deleteTree(test_dir) catch {};
    defer std.fs.cwd().deleteFile(archive_path) catch {};
    defer std.fs.cwd().deleteTree(extract_dir) catch {};

    // Create test directory structure
    try std.fs.cwd().makePath(test_dir ++ "/subdir");
    try std.fs.cwd().writeFile(.{ .sub_path = test_dir ++ "/file1.txt", .data = "File 1" });
    try std.fs.cwd().writeFile(.{ .sub_path = test_dir ++ "/subdir/file2.txt", .data = "File 2" });

    // Archive directory
    try archiveDirectory(testing.allocator, test_dir, archive_path);

    // Extract archive
    var archive = try SimpleArchive.load(testing.allocator, archive_path);
    defer archive.deinit();

    try archive.extract(extract_dir);

    // Verify extracted files
    const content1 = try std.fs.cwd().readFileAlloc(testing.allocator, extract_dir ++ "/file1.txt", 1024);
    defer testing.allocator.free(content1);
    try testing.expectEqualStrings("File 1", content1);

    const content2 = try std.fs.cwd().readFileAlloc(testing.allocator, extract_dir ++ "/subdir/file2.txt", 1024);
    defer testing.allocator.free(content2);
    try testing.expectEqualStrings("File 2", content2);
}
// ANCHOR_END: directory_archive

// ANCHOR: archive_size
/// Get total size of archive
pub fn getArchiveSize(archive: *const SimpleArchive) usize {
    var total: usize = 0;
    for (archive.entries.items) |entry| {
        total += entry.data.len;
    }
    return total;
}

/// Find entry by name
pub fn findEntry(archive: *const SimpleArchive, name: []const u8) ?*const ArchiveEntry {
    for (archive.entries.items) |*entry| {
        if (std.mem.eql(u8, entry.name, name)) {
            return entry;
        }
    }
    return null;
}

test "archive utilities" {
    var archive = SimpleArchive.init(testing.allocator);
    defer archive.deinit();

    try archive.addFile("file1.txt", "Content 1");
    try archive.addFile("file2.txt", "Content 2 is longer");

    const size = getArchiveSize(&archive);
    try testing.expectEqual(28, size);  // 9 + 19 = 28 bytes

    const entry = findEntry(&archive, "file2.txt");
    try testing.expect(entry != null);
    try testing.expectEqualStrings("Content 2 is longer", entry.?.data);

    const missing = findEntry(&archive, "missing.txt");
    try testing.expect(missing == null);
}
// ANCHOR_END: archive_size

// ANCHOR: security_tests
test "security: reject path traversal attempts" {
    const test_dir = "zig-cache/security_test";
    std.fs.cwd().deleteTree(test_dir) catch {};
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    var archive = SimpleArchive.init(testing.allocator);
    defer archive.deinit();

    // Add malicious entry attempting path traversal
    try archive.addFile("../../etc/passwd", "malicious");

    // Extraction should fail with InvalidEntryPath
    const result = archive.extract(test_dir);
    try testing.expectError(error.InvalidEntryPath, result);
}

test "security: reject absolute paths" {
    const test_dir = "zig-cache/security_absolute_test";
    std.fs.cwd().deleteTree(test_dir) catch {};
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    var archive = SimpleArchive.init(testing.allocator);
    defer archive.deinit();

    // Add malicious entry with absolute path
    try archive.addFile("/tmp/malicious.txt", "malicious");

    // Extraction should fail with InvalidEntryPath
    const result = archive.extract(test_dir);
    try testing.expectError(error.InvalidEntryPath, result);
}

test "security: allow safe relative paths" {
    const test_dir = "zig-cache/security_safe_test";
    std.fs.cwd().deleteTree(test_dir) catch {};
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    var archive = SimpleArchive.init(testing.allocator);
    defer archive.deinit();

    // Add safe entries
    try archive.addFile("file.txt", "safe content");
    try archive.addFile("subdir/nested.txt", "also safe");

    // Extraction should succeed
    try archive.extract(test_dir);

    // Verify files were created
    const content1 = try std.fs.cwd().readFileAlloc(testing.allocator, test_dir ++ "/file.txt", 1024);
    defer testing.allocator.free(content1);
    try testing.expectEqualStrings("safe content", content1);

    const content2 = try std.fs.cwd().readFileAlloc(testing.allocator, test_dir ++ "/subdir/nested.txt", 1024);
    defer testing.allocator.free(content2);
    try testing.expectEqualStrings("also safe", content2);
}

test "security: allow filenames containing dots" {
    const test_dir = "zig-cache/security_dots_test";
    std.fs.cwd().deleteTree(test_dir) catch {};
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    var archive = SimpleArchive.init(testing.allocator);
    defer archive.deinit();

    // SECURITY: These filenames contain ".." but are safe because ".." is not
    // a path component (directory separator). Using proper path parsing with
    // ComponentIterator allows these legitimate filenames while still blocking
    // path traversal attacks like "../../etc/passwd"
    try archive.addFile("file..txt", "double dots in filename");
    try archive.addFile("upload..images.jpg", "dots between words");
    try archive.addFile("subdir/config..backup.conf", "dots in nested file");

    // Extraction should succeed - these are legitimate filenames
    try archive.extract(test_dir);

    // Verify files were created
    const content1 = try std.fs.cwd().readFileAlloc(testing.allocator, test_dir ++ "/file..txt", 1024);
    defer testing.allocator.free(content1);
    try testing.expectEqualStrings("double dots in filename", content1);

    const content2 = try std.fs.cwd().readFileAlloc(testing.allocator, test_dir ++ "/upload..images.jpg", 1024);
    defer testing.allocator.free(content2);
    try testing.expectEqualStrings("dots between words", content2);

    const content3 = try std.fs.cwd().readFileAlloc(testing.allocator, test_dir ++ "/subdir/config..backup.conf", 1024);
    defer testing.allocator.free(content3);
    try testing.expectEqualStrings("dots in nested file", content3);
}

test "security: reject excessive entry count DoS" {
    const archive_path = "zig-cache/dos_entry_count.archive";
    std.fs.cwd().deleteFile(archive_path) catch {};
    defer std.fs.cwd().deleteFile(archive_path) catch {};

    // Create a malicious archive claiming billions of entries
    const file = try std.fs.cwd().createFile(archive_path, .{});
    defer file.close();

    var buf: [4]u8 = undefined;
    // Write entry count exceeding MAX_ENTRY_COUNT
    std.mem.writeInt(u32, &buf, MAX_ENTRY_COUNT + 1, .little);
    try file.writeAll(&buf);

    // Attempt to load should fail before allocating any memory
    const result = SimpleArchive.load(testing.allocator, archive_path);
    try testing.expectError(error.TooManyEntries, result);
}

test "security: reject excessive name length DoS" {
    const archive_path = "zig-cache/dos_name_length.archive";
    std.fs.cwd().deleteFile(archive_path) catch {};
    defer std.fs.cwd().deleteFile(archive_path) catch {};

    // Create a malicious archive with enormous name length claim
    const file = try std.fs.cwd().createFile(archive_path, .{});
    defer file.close();

    var buf: [4]u8 = undefined;
    // Write 1 entry
    std.mem.writeInt(u32, &buf, 1, .little);
    try file.writeAll(&buf);

    // Write name length exceeding MAX_PATH_LENGTH (e.g., claim 4GB)
    std.mem.writeInt(u32, &buf, MAX_PATH_LENGTH + 1, .little);
    try file.writeAll(&buf);
    // No actual name data provided - this would cause OOM without validation

    // Attempt to load should fail before allocating the massive buffer
    const result = SimpleArchive.load(testing.allocator, archive_path);
    try testing.expectError(error.PathTooLong, result);
}

test "security: reject excessive data size DoS" {
    const archive_path = "zig-cache/dos_data_size.archive";
    std.fs.cwd().deleteFile(archive_path) catch {};
    defer std.fs.cwd().deleteFile(archive_path) catch {};

    // Create a malicious archive claiming 4GB entry without providing data
    const file = try std.fs.cwd().createFile(archive_path, .{});
    defer file.close();

    var buf: [4]u8 = undefined;
    // Write 1 entry
    std.mem.writeInt(u32, &buf, 1, .little);
    try file.writeAll(&buf);

    // Write small valid name
    const name = "evil.bin";
    std.mem.writeInt(u32, &buf, @as(u32, @intCast(name.len)), .little);
    try file.writeAll(&buf);
    try file.writeAll(name);

    // Write massive data length claim exceeding MAX_ENTRY_SIZE
    std.mem.writeInt(u32, &buf, MAX_ENTRY_SIZE + 1, .little);
    try file.writeAll(&buf);
    // No actual data provided - this would cause instant OOM without validation

    // Attempt to load should fail before allocating 4GB+ buffer
    const result = SimpleArchive.load(testing.allocator, archive_path);
    try testing.expectError(error.EntryTooLarge, result);
}

test "security: reject empty path" {
    const archive_path = "zig-cache/empty_path.archive";
    std.fs.cwd().deleteFile(archive_path) catch {};
    defer std.fs.cwd().deleteFile(archive_path) catch {};

    // Create an archive with zero-length path
    const file = try std.fs.cwd().createFile(archive_path, .{});
    defer file.close();

    var buf: [4]u8 = undefined;
    // Write 1 entry
    std.mem.writeInt(u32, &buf, 1, .little);
    try file.writeAll(&buf);

    // Write zero-length name
    std.mem.writeInt(u32, &buf, 0, .little);
    try file.writeAll(&buf);

    // Attempt to load should fail
    const result = SimpleArchive.load(testing.allocator, archive_path);
    try testing.expectError(error.EmptyPath, result);
}

test "security: accept maximum valid sizes" {
    const archive_path = "zig-cache/max_valid_sizes.archive";
    std.fs.cwd().deleteFile(archive_path) catch {};
    defer std.fs.cwd().deleteFile(archive_path) catch {};

    // Create archive with entries at the maximum allowed sizes
    {
        var archive = SimpleArchive.init(testing.allocator);
        defer archive.deinit();

        // Create a name at MAX_PATH_LENGTH
        const max_name = try testing.allocator.alloc(u8, MAX_PATH_LENGTH);
        defer testing.allocator.free(max_name);
        @memset(max_name, 'a');

        // Small data to keep test fast
        try archive.addFile(max_name, "data");

        try archive.save(archive_path);
    }

    // Should load successfully since it's within limits
    var loaded = try SimpleArchive.load(testing.allocator, archive_path);
    defer loaded.deinit();

    try testing.expectEqual(1, loaded.entries.items.len);
    try testing.expectEqual(MAX_PATH_LENGTH, loaded.entries.items[0].name.len);
}

test "security: reject aggregate memory DoS" {
    const archive_path = "zig-cache/dos_aggregate.archive";
    std.fs.cwd().deleteFile(archive_path) catch {};
    defer std.fs.cwd().deleteFile(archive_path) catch {};

    // Demonstrate aggregate DoS: many entries that individually pass MAX_ENTRY_SIZE
    // but collectively exceed MAX_TOTAL_ARCHIVE_SIZE (512MB).
    // Strategy: 9 entries × 60MB = 540MB (the 9th should trigger error)
    // We write full data to keep file structure valid and test realistic
    const file = try std.fs.cwd().createFile(archive_path, .{});
    defer file.close();

    var buf: [4]u8 = undefined;
    const num_entries: u32 = 9;
    const entry_size: u32 = 60 * 1024 * 1024; // 60MB per entry (under 100MB limit)

    std.mem.writeInt(u32, &buf, num_entries, .little);
    try file.writeAll(&buf);

    // Allocate one 60MB buffer to reuse (avoids repeated allocation)
    const entry_data = try testing.allocator.alloc(u8, entry_size);
    defer testing.allocator.free(entry_data);
    @memset(entry_data, 0x42);

    // Write entries: first 8 will load fine (480MB), 9th will exceed 512MB limit
    var i: u32 = 0;
    while (i < num_entries) : (i += 1) {
        var name_buf: [32]u8 = undefined;
        const name = try std.fmt.bufPrint(&name_buf, "file_{d}.bin", .{i});

        std.mem.writeInt(u32, &buf, @as(u32, @intCast(name.len)), .little);
        try file.writeAll(&buf);
        try file.writeAll(name);

        std.mem.writeInt(u32, &buf, entry_size, .little);
        try file.writeAll(&buf);
        try file.writeAll(entry_data);
    }

    // Loading should fail on the 9th entry when total would be 540MB > 512MB
    // The check prevents allocation, so no OOM crash occurs
    const result = SimpleArchive.load(testing.allocator, archive_path);
    try testing.expectError(error.ArchiveTooLarge, result);
}
// ANCHOR_END: security_tests
