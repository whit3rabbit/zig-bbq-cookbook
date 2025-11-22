const std = @import("std");

/// Check if a path exists
pub fn pathExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

/// Check if path is a file
pub fn isFile(path: []const u8) bool {
    const stat = std.fs.cwd().statFile(path) catch return false;
    return stat.kind == .file;
}

/// Check if path is a directory
pub fn isDirectory(path: []const u8) bool {
    const stat = std.fs.cwd().statFile(path) catch return false;
    return stat.kind == .directory;
}

/// Check if file can be read
pub fn canRead(path: []const u8) bool {
    std.fs.cwd().access(path, .{ .mode = .read_only }) catch return false;
    return true;
}

/// Check if file can be written
pub fn canWrite(path: []const u8) bool {
    const file = std.fs.cwd().openFile(path, .{ .mode = .write_only }) catch return false;
    file.close();
    return true;
}

/// File type enumeration
pub const FileType = enum {
    file,
    directory,
    symlink,
    block_device,
    character_device,
    named_pipe,
    unix_domain_socket,
    unknown,
};

/// Get the type of filesystem object
pub fn getFileType(path: []const u8) !FileType {
    const stat = try std.fs.cwd().statFile(path);

    return switch (stat.kind) {
        .file => .file,
        .directory => .directory,
        .sym_link => .symlink,
        .block_device => .block_device,
        .character_device => .character_device,
        .named_pipe => .named_pipe,
        .unix_domain_socket => .unix_domain_socket,
        else => .unknown,
    };
}

/// Check if path1 is newer than path2
pub fn isNewerThan(path1: []const u8, path2: []const u8) !bool {
    const stat1 = try std.fs.cwd().statFile(path1);
    const stat2 = try std.fs.cwd().statFile(path2);

    return stat1.mtime > stat2.mtime;
}

/// Check if file is older than specified seconds
pub fn isOlderThan(path: []const u8, seconds: i128) !bool {
    const stat = try std.fs.cwd().statFile(path);
    const now = std.time.nanoTimestamp();
    const age = now - stat.mtime;

    return age > (seconds * std.time.ns_per_s);
}

/// Wait for a file to be created with timeout
pub fn waitForFile(path: []const u8, timeout_ms: u64) !void {
    const start = std.time.milliTimestamp();

    while (true) {
        if (pathExists(path)) {
            return;
        }

        const elapsed = std.time.milliTimestamp() - start;
        if (elapsed > timeout_ms) {
            return error.Timeout;
        }

        std.Thread.sleep(100 * std.time.ns_per_ms);
    }
}

/// Safe existence check with explicit error handling
pub fn safeExists(path: []const u8) !bool {
    std.fs.cwd().access(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return false,
        error.AccessDenied => return error.PermissionDenied,
        else => return err,
    };
    return true;
}

/// Check if all paths exist
pub fn allExist(paths: []const []const u8) bool {
    for (paths) |path| {
        if (!pathExists(path)) {
            return false;
        }
    }
    return true;
}

/// Check if any path exists
pub fn anyExists(paths: []const []const u8) bool {
    for (paths) |path| {
        if (pathExists(path)) {
            return true;
        }
    }
    return false;
}

/// Find first existing file from list
pub fn findFirstExisting(paths: []const []const u8) ?[]const u8 {
    for (paths) |path| {
        if (pathExists(path)) {
            return path;
        }
    }
    return null;
}

/// Check if parent directory exists
pub fn parentDirExists(path: []const u8) bool {
    const dir = std.fs.path.dirname(path) orelse return true;
    return isDirectory(dir);
}

/// Ensure parent directory exists, creating if necessary
pub fn ensureParentDir(path: []const u8) !void {
    const dir = std.fs.path.dirname(path) orelse return;

    std.fs.cwd().makePath(dir) catch |err| switch (err) {
        error.PathAlreadyExists => return,
        else => return err,
    };
}

// Tests

// ANCHOR: basic_existence
test "file exists" {
    const path = "/tmp/test_exists.txt";
    defer std.fs.cwd().deleteFile(path) catch {};

    // File doesn't exist yet
    try std.testing.expect(!pathExists(path));

    // Create file
    {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
    }

    // File exists now
    try std.testing.expect(pathExists(path));
}

test "file does not exist" {
    try std.testing.expect(!pathExists("/tmp/does_not_exist_12345.txt"));
}

test "is file" {
    const path = "/tmp/test_is_file.txt";
    defer std.fs.cwd().deleteFile(path) catch {};

    {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
    }

    try std.testing.expect(isFile(path));
    try std.testing.expect(!isDirectory(path));
}

test "is directory" {
    const path = "/tmp/test_is_dir";
    try std.fs.cwd().makeDir(path);
    defer std.fs.cwd().deleteDir(path) catch {};

    try std.testing.expect(isDirectory(path));
    try std.testing.expect(!isFile(path));
}
// ANCHOR_END: basic_existence

test "can read" {
    const path = "/tmp/test_can_read.txt";
    defer std.fs.cwd().deleteFile(path) catch {};

    {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
    }

    try std.testing.expect(canRead(path));
}

test "can write" {
    const path = "/tmp/test_can_write.txt";
    defer std.fs.cwd().deleteFile(path) catch {};

    {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
    }

    try std.testing.expect(canWrite(path));
}

test "get file type" {
    const file_path = "/tmp/test_type_file.txt";
    const dir_path = "/tmp/test_type_dir";

    defer std.fs.cwd().deleteFile(file_path) catch {};
    defer std.fs.cwd().deleteDir(dir_path) catch {};

    // Create file
    {
        const file = try std.fs.cwd().createFile(file_path, .{});
        defer file.close();
    }

    // Create directory
    try std.fs.cwd().makeDir(dir_path);

    // Check types
    try std.testing.expectEqual(FileType.file, try getFileType(file_path));
    try std.testing.expectEqual(FileType.directory, try getFileType(dir_path));
}

// ANCHOR: file_metadata
test "file age comparison" {
    const path1 = "/tmp/test_age1.txt";
    const path2 = "/tmp/test_age2.txt";

    defer std.fs.cwd().deleteFile(path1) catch {};
    defer std.fs.cwd().deleteFile(path2) catch {};

    // Create first file
    {
        const file = try std.fs.cwd().createFile(path1, .{});
        defer file.close();
    }

    // Wait a bit
    std.Thread.sleep(10 * std.time.ns_per_ms);

    // Create second file
    {
        const file = try std.fs.cwd().createFile(path2, .{});
        defer file.close();
    }

    // path2 is newer than path1
    try std.testing.expect(try isNewerThan(path2, path1));
}

test "is older than" {
    const path = "/tmp/test_older.txt";
    defer std.fs.cwd().deleteFile(path) catch {};

    {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
    }

    // File is not older than 1 second (just created)
    try std.testing.expect(!try isOlderThan(path, 1));
}

test "wait for file creation" {
    const path = "/tmp/test_wait.txt";
    defer std.fs.cwd().deleteFile(path) catch {};

    // Start background thread to create file
    const thread = try std.Thread.spawn(.{}, struct {
        fn create(file_path: []const u8) void {
            std.Thread.sleep(200 * std.time.ns_per_ms);
            const file = std.fs.cwd().createFile(file_path, .{}) catch return;
            file.close();
        }
    }.create, .{path});
    thread.detach();

    // Wait for file
    try waitForFile(path, 5000);
    try std.testing.expect(pathExists(path));
}

test "wait for file timeout" {
    const path = "/tmp/test_wait_timeout.txt";

    // File is never created, should timeout
    const result = waitForFile(path, 100);
    try std.testing.expectError(error.Timeout, result);
}
// ANCHOR_END: file_metadata

test "safe exists" {
    const path = "/tmp/test_safe_exists.txt";
    defer std.fs.cwd().deleteFile(path) catch {};

    // Doesn't exist
    try std.testing.expect(!try safeExists(path));

    // Create file
    {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
    }

    // Exists
    try std.testing.expect(try safeExists(path));
}

// ANCHOR: multiple_paths
test "all exist" {
    const path1 = "/tmp/test_all1.txt";
    const path2 = "/tmp/test_all2.txt";

    defer std.fs.cwd().deleteFile(path1) catch {};
    defer std.fs.cwd().deleteFile(path2) catch {};

    // Create one file
    {
        const file = try std.fs.cwd().createFile(path1, .{});
        defer file.close();
    }

    const paths = [_][]const u8{ path1, path2 };

    // Not all exist
    try std.testing.expect(!allExist(&paths));

    // Create second file
    {
        const file = try std.fs.cwd().createFile(path2, .{});
        defer file.close();
    }

    // All exist now
    try std.testing.expect(allExist(&paths));
}

test "any exists" {
    const path1 = "/tmp/does_not_exist1.txt";
    const path2 = "/tmp/test_any.txt";

    defer std.fs.cwd().deleteFile(path2) catch {};

    // Create one file
    {
        const file = try std.fs.cwd().createFile(path2, .{});
        defer file.close();
    }

    const paths = [_][]const u8{ path1, path2 };

    // At least one exists
    try std.testing.expect(anyExists(&paths));
}

test "any exists none" {
    const paths = [_][]const u8{
        "/tmp/does_not_exist1.txt",
        "/tmp/does_not_exist2.txt",
    };

    try std.testing.expect(!anyExists(&paths));
}

test "find first existing" {
    const path1 = "/tmp/does_not_exist1.txt";
    const path2 = "/tmp/test_first.txt";
    const path3 = "/tmp/does_not_exist2.txt";

    defer std.fs.cwd().deleteFile(path2) catch {};

    // Create middle file
    {
        const file = try std.fs.cwd().createFile(path2, .{});
        defer file.close();
    }

    const paths = [_][]const u8{ path1, path2, path3 };
    const found = findFirstExisting(&paths);

    try std.testing.expect(found != null);
    try std.testing.expectEqualStrings(path2, found.?);
}

test "find first existing none" {
    const paths = [_][]const u8{
        "/tmp/does_not_exist1.txt",
        "/tmp/does_not_exist2.txt",
    };

    const found = findFirstExisting(&paths);
    try std.testing.expect(found == null);
}
// ANCHOR_END: multiple_paths

test "parent dir exists" {
    // /tmp exists, so parent dir check should pass
    try std.testing.expect(parentDirExists("/tmp/some_file.txt"));

    // Root has no parent but returns true
    try std.testing.expect(parentDirExists("/"));
}

test "ensure parent dir" {
    const nested_path = "/tmp/test_parent/nested/file.txt";
    const dir_path = "/tmp/test_parent/nested";

    defer std.fs.cwd().deleteTree("/tmp/test_parent") catch {};

    // Create parent directories
    try ensureParentDir(nested_path);

    // Parent should exist
    try std.testing.expect(isDirectory(dir_path));
}

test "ensure parent dir idempotent" {
    const path = "/tmp/test_idem/file.txt";
    defer std.fs.cwd().deleteTree("/tmp/test_idem") catch {};

    // Create once
    try ensureParentDir(path);

    // Create again (should not error)
    try ensureParentDir(path);

    try std.testing.expect(isDirectory("/tmp/test_idem"));
}

test "empty path" {
    // Empty path should not exist
    try std.testing.expect(!pathExists(""));
}

test "root directory exists" {
    // Root should always exist
    try std.testing.expect(pathExists("/"));
    try std.testing.expect(isDirectory("/"));
}
