const std = @import("std");

/// Create a temporary file with unique name
pub fn createTempFile(allocator: std.mem.Allocator, prefix: []const u8) !struct {
    file: std.fs.File,
    path: []const u8,
} {
    var buf: [64]u8 = undefined;
    const name = try std.fmt.bufPrint(&buf, "{s}_{d}", .{ prefix, std.time.milliTimestamp() });

    const path = try std.fs.path.join(allocator, &[_][]const u8{ "/tmp", name });
    errdefer allocator.free(path);

    const file = try std.fs.cwd().createFile(path, .{ .read = true });

    return .{ .file = file, .path = path };
}

/// Generate unique temporary path
pub fn makeTempPath(allocator: std.mem.Allocator, dir: []const u8, prefix: []const u8) ![]u8 {
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const random = prng.random();

    var buf: [32]u8 = undefined;
    const random_part = std.fmt.bufPrint(&buf, "{x}", .{random.int(u64)}) catch unreachable;

    return std.fmt.allocPrint(allocator, "{s}/{s}_{s}", .{ dir, prefix, random_part });
}

/// Create temporary directory
pub fn createTempDir(allocator: std.mem.Allocator, prefix: []const u8) ![]u8 {
    const path = try makeTempPath(allocator, "/tmp", prefix);
    errdefer allocator.free(path);

    try std.fs.cwd().makeDir(path);

    return path;
}

/// Remove temporary directory and contents
pub fn removeTempDir(path: []const u8) !void {
    try std.fs.cwd().deleteTree(path);
}

/// Self-deleting temporary file
pub const SelfDeletingFile = struct {
    file: std.fs.File,
    path: []const u8,
    allocator: std.mem.Allocator,

    pub fn create(allocator: std.mem.Allocator, prefix: []const u8) !SelfDeletingFile {
        const temp = try createTempFile(allocator, prefix);
        return .{
            .file = temp.file,
            .path = temp.path,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SelfDeletingFile) void {
        self.file.close();
        std.fs.cwd().deleteFile(self.path) catch {};
        self.allocator.free(self.path);
    }

    pub fn writeAll(self: *SelfDeletingFile, bytes: []const u8) !void {
        return self.file.writeAll(bytes);
    }

    pub fn read(self: *SelfDeletingFile, buffer: []u8) !usize {
        return self.file.read(buffer);
    }
};

/// Create temp file with initial content
pub fn createTempFileWithContent(
    allocator: std.mem.Allocator,
    prefix: []const u8,
    content: []const u8,
) !struct {
    file: std.fs.File,
    path: []const u8,
} {
    const temp = try createTempFile(allocator, prefix);
    errdefer {
        temp.file.close();
        allocator.free(temp.path);
        std.fs.cwd().deleteFile(temp.path) catch {};
    }

    try temp.file.writeAll(content);
    try temp.file.seekTo(0);

    return .{ .file = temp.file, .path = temp.path };
}

/// Create named temporary file with extension
pub fn createNamedTempFile(
    allocator: std.mem.Allocator,
    name: []const u8,
    extension: []const u8,
) !struct {
    file: std.fs.File,
    path: []const u8,
} {
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const random = prng.random();

    const path = try std.fmt.allocPrint(
        allocator,
        "/tmp/{s}_{x}.{s}",
        .{ name, random.int(u32), extension },
    );
    errdefer allocator.free(path);

    const file = try std.fs.cwd().createFile(path, .{ .read = true });

    return .{ .file = file, .path = path };
}

/// Create unique temp file atomically
pub fn createUniqueTempFile(
    allocator: std.mem.Allocator,
    prefix: []const u8,
    max_attempts: usize,
) !struct {
    file: std.fs.File,
    path: []const u8,
} {
    var attempts: usize = 0;
    while (attempts < max_attempts) : (attempts += 1) {
        const path = try makeTempPath(allocator, "/tmp", prefix);
        errdefer allocator.free(path);

        const file = std.fs.cwd().createFile(path, .{
            .read = true,
            .exclusive = true,
        }) catch |err| switch (err) {
            error.PathAlreadyExists => {
                allocator.free(path);
                continue;
            },
            else => return err,
        };

        return .{ .file = file, .path = path };
    }

    return error.TooManyAttempts;
}

/// Clean up temporary file
pub fn cleanupTempFile(path: []const u8, allocator: std.mem.Allocator) void {
    std.fs.cwd().deleteFile(path) catch {};
    allocator.free(path);
}

/// Clean up temporary directory
pub fn cleanupTempDir(path: []const u8, allocator: std.mem.Allocator) void {
    std.fs.cwd().deleteTree(path) catch {};
    allocator.free(path);
}

/// Get platform-specific temp directory
pub fn getTempDir(allocator: std.mem.Allocator) ![]u8 {
    const builtin = @import("builtin");

    if (builtin.os.tag == .windows) {
        return std.process.getEnvVarOwned(allocator, "TEMP") catch |err| switch (err) {
            error.EnvironmentVariableNotFound => try allocator.dupe(u8, "C:\\Temp"),
            else => return err,
        };
    } else {
        return std.process.getEnvVarOwned(allocator, "TMPDIR") catch |err| switch (err) {
            error.EnvironmentVariableNotFound => try allocator.dupe(u8, "/tmp"),
            else => return err,
        };
    }
}

/// Create memory-backed temporary file (Linux only)
pub fn createMemoryTempFile() !std.fs.File {
    const builtin = @import("builtin");
    if (builtin.os.tag == .linux) {
        const fd = try std.posix.memfd_create("memtemp", 0);
        return std.fs.File{ .handle = fd };
    } else {
        return error.NotSupported;
    }
}

// Tests

// ANCHOR: basic_temp_files
test "create temp file" {
    const allocator = std.testing.allocator;

    const temp = try createTempFile(allocator, "test");
    defer temp.file.close();
    defer allocator.free(temp.path);
    defer std.fs.cwd().deleteFile(temp.path) catch {};

    try temp.file.writeAll("Temporary data");

    try temp.file.seekTo(0);
    var buffer: [20]u8 = undefined;
    const n = try temp.file.read(&buffer);

    try std.testing.expectEqualStrings("Temporary data", buffer[0..n]);
}

test "temp dir for testing" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const file = try tmp.dir.createFile("test.txt", .{});
    defer file.close();

    try file.writeAll("Test data");

    const content = try tmp.dir.readFileAlloc(std.testing.allocator, "test.txt", 1024);
    defer std.testing.allocator.free(content);

    try std.testing.expectEqualStrings("Test data", content);
}
// ANCHOR_END: basic_temp_files

test "unique temp paths" {
    const allocator = std.testing.allocator;

    const path1 = try makeTempPath(allocator, "/tmp", "test");
    defer allocator.free(path1);

    // Small delay to ensure different timestamp
    std.Thread.sleep(1 * std.time.ns_per_ms);

    const path2 = try makeTempPath(allocator, "/tmp", "test");
    defer allocator.free(path2);

    try std.testing.expect(!std.mem.eql(u8, path1, path2));
}

test "temp directory" {
    const allocator = std.testing.allocator;

    const dir_path = try createTempDir(allocator, "testdir");
    defer allocator.free(dir_path);
    defer removeTempDir(dir_path) catch {};

    var dir = try std.fs.cwd().openDir(dir_path, .{});
    defer dir.close();

    const file = try dir.createFile("test.txt", .{});
    defer file.close();

    try file.writeAll("In temp dir");
}

// ANCHOR: self_deleting
test "self-deleting file" {
    const allocator = std.testing.allocator;

    var temp = try SelfDeletingFile.create(allocator, "self_delete");
    defer temp.deinit();

    try temp.writeAll("Auto-deleted");

    const stat = try std.fs.cwd().statFile(temp.path);
    try std.testing.expect(stat.kind == .file);
}

test "temp file with content" {
    const allocator = std.testing.allocator;

    const temp = try createTempFileWithContent(allocator, "content", "Initial content");
    defer temp.file.close();
    defer allocator.free(temp.path);
    defer std.fs.cwd().deleteFile(temp.path) catch {};

    var buffer: [20]u8 = undefined;
    const n = try temp.file.read(&buffer);

    try std.testing.expectEqualStrings("Initial content", buffer[0..n]);
}

test "named temp file" {
    const allocator = std.testing.allocator;

    const temp = try createNamedTempFile(allocator, "myfile", "txt");
    defer temp.file.close();
    defer allocator.free(temp.path);
    defer std.fs.cwd().deleteFile(temp.path) catch {};

    try std.testing.expect(std.mem.endsWith(u8, temp.path, ".txt"));
}
// ANCHOR_END: self_deleting

test "unique temp file" {
    const allocator = std.testing.allocator;

    const temp = try createUniqueTempFile(allocator, "unique", 10);
    defer temp.file.close();
    defer allocator.free(temp.path);
    defer std.fs.cwd().deleteFile(temp.path) catch {};

    try temp.file.writeAll("Unique file");
}

// ANCHOR: cleanup_helpers
test "iterate temp dir" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    // Create some files
    {
        const file1 = try tmp.dir.createFile("file1.txt", .{});
        defer file1.close();
        const file2 = try tmp.dir.createFile("file2.txt", .{});
        defer file2.close();
    }

    var count: usize = 0;
    var iter = tmp.dir.iterate();
    while (try iter.next()) |_| {
        count += 1;
    }

    try std.testing.expectEqual(@as(usize, 2), count);
}

test "get temp dir" {
    const allocator = std.testing.allocator;

    const temp_dir = try getTempDir(allocator);
    defer allocator.free(temp_dir);

    try std.testing.expect(temp_dir.len > 0);
}

test "memory temp file" {
    const builtin = @import("builtin");
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const file = try createMemoryTempFile();
    defer file.close();

    try file.writeAll("In memory");

    try file.seekTo(0);
    var buffer: [20]u8 = undefined;
    const n = try file.read(&buffer);

    try std.testing.expectEqualStrings("In memory", buffer[0..n]);
}

test "cleanup helpers" {
    const allocator = std.testing.allocator;

    // Create temp file
    const temp = try createTempFile(allocator, "cleanup");
    try temp.file.writeAll("test");
    temp.file.close();

    // Verify exists
    const stat = try std.fs.cwd().statFile(temp.path);
    try std.testing.expect(stat.kind == .file);

    // Make a copy of path for later check
    const path_copy = try allocator.dupe(u8, temp.path);
    defer allocator.free(path_copy);

    // Cleanup (frees temp.path)
    cleanupTempFile(temp.path, allocator);

    // Should not exist (use path_copy)
    const result = std.fs.cwd().statFile(path_copy);
    try std.testing.expectError(error.FileNotFound, result);
}

test "temp dir cleanup" {
    const allocator = std.testing.allocator;

    const dir_path = try createTempDir(allocator, "cleanup_dir");

    // Create file in it
    var dir = try std.fs.cwd().openDir(dir_path, .{});
    const file = try dir.createFile("file.txt", .{});
    file.close();
    dir.close();

    // Verify exists
    const stat = try std.fs.cwd().statFile(dir_path);
    try std.testing.expect(stat.kind == .directory);

    // Make a copy of path for later check
    const path_copy = try allocator.dupe(u8, dir_path);
    defer allocator.free(path_copy);

    // Cleanup (frees dir_path)
    cleanupTempDir(dir_path, allocator);

    // Should not exist (use path_copy)
    const result = std.fs.cwd().statFile(path_copy);
    try std.testing.expectError(error.FileNotFound, result);
}

test "multiple temp files" {
    const allocator = std.testing.allocator;

    const temp1 = try createTempFile(allocator, "multi");
    defer temp1.file.close();
    defer allocator.free(temp1.path);
    defer std.fs.cwd().deleteFile(temp1.path) catch {};

    std.Thread.sleep(2 * std.time.ns_per_ms);

    const temp2 = try createTempFile(allocator, "multi");
    defer temp2.file.close();
    defer allocator.free(temp2.path);
    defer std.fs.cwd().deleteFile(temp2.path) catch {};

    // Paths should be different
    try std.testing.expect(!std.mem.eql(u8, temp1.path, temp2.path));
}
// ANCHOR_END: cleanup_helpers
