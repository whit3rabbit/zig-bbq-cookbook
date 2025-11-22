// Recipe 5.22: Common File I/O Errors and Solutions
// Target Zig Version: 0.15.2
//
// This recipe demonstrates common file I/O errors and how to handle them properly.
// Understanding these errors helps write robust file handling code.

const std = @import("std");
const testing = std.testing;

// ANCHOR: file_not_found
/// Handle FileNotFound gracefully
pub fn openOrCreate(path: []const u8) !std.fs.File {
    // Try to open existing file
    const file = std.fs.cwd().openFile(path, .{ .mode = .read_write }) catch |err| switch (err) {
        error.FileNotFound => {
            // File doesn't exist, create it
            std.debug.print("File not found, creating: {s}\n", .{path});
            return try std.fs.cwd().createFile(path, .{ .read = true });
        },
        else => return err,
    };

    return file;
}

/// Fallback to default file if primary doesn't exist
pub fn openWithFallback(
    allocator: std.mem.Allocator,
    primary_path: []const u8,
    fallback_path: []const u8,
) ![]u8 {
    const file = std.fs.cwd().openFile(primary_path, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Primary not found, trying fallback: {s}\n", .{fallback_path});
            return try std.fs.cwd().openFile(fallback_path, .{});
        },
        else => return err,
    };
    defer file.close();

    return try file.readToEndAlloc(allocator, 1024 * 1024);
}
// ANCHOR_END: file_not_found

// ANCHOR: path_already_exists
/// Handle PathAlreadyExists when creating directories
pub fn ensureDirectory(path: []const u8) !void {
    std.fs.cwd().makeDir(path) catch |err| switch (err) {
        error.PathAlreadyExists => {
            // Directory already exists, that's fine
            std.debug.print("Directory already exists: {s}\n", .{path});
            return;
        },
        else => return err,
    };
}

/// Create nested directories safely
pub fn ensureNestedDirectory(path: []const u8) !void {
    // makePath creates all parent directories and succeeds if already exists
    try std.fs.cwd().makePath(path);
}

/// Exclusive file creation (fail if exists)
pub fn createExclusive(path: []const u8) !std.fs.File {
    // Using .exclusive = true fails if file already exists
    const file = std.fs.cwd().createFile(path, .{
        .exclusive = true,
    }) catch |err| switch (err) {
        error.PathAlreadyExists => {
            std.debug.print("File already exists: {s}\n", .{path});
            return err;
        },
        else => return err,
    };

    return file;
}
// ANCHOR_END: path_already_exists

// ANCHOR: is_dir_not_dir
/// Handle IsDir error (trying to open directory as file)
pub fn safeOpenFile(path: []const u8) !std.fs.File {
    // First check if it's a directory
    const stat = std.fs.cwd().statFile(path) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("File not found: {s}\n", .{path});
            return error.FileNotFound;
        },
        else => return err,
    };

    if (stat.kind == .directory) {
        std.debug.print("Path is a directory, not a file: {s}\n", .{path});
        return error.IsDir;
    }

    return try std.fs.cwd().openFile(path, .{});
}

/// Detect if path is file or directory
pub fn openFileOrDir(path: []const u8) !union(enum) {
    file: std.fs.File,
    dir: std.fs.Dir,
} {
    // Check what kind of object it is
    const stat = try std.fs.cwd().statFile(path);

    if (stat.kind == .directory) {
        const dir = try std.fs.cwd().openDir(path, .{});
        return .{ .dir = dir };
    } else {
        const file = try std.fs.cwd().openFile(path, .{});
        return .{ .file = file };
    }
}
// ANCHOR_END: is_dir_not_dir

// ANCHOR: access_denied
/// Handle permission errors
pub fn readWithPermissionCheck(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| switch (err) {
        error.AccessDenied => {
            std.debug.print("Permission denied: {s}\n", .{path});
            std.debug.print("Check file permissions\n", .{});
            return error.AccessDenied;
        },
        error.FileNotFound => {
            std.debug.print("File not found: {s}\n", .{path});
            return error.FileNotFound;
        },
        else => return err,
    };
    defer file.close();

    return try file.readToEndAlloc(allocator, 1024 * 1024);
}

/// Check if file is readable before opening
pub fn canRead(path: []const u8) bool {
    std.fs.cwd().access(path, .{ .mode = .read_only }) catch return false;
    return true;
}

/// Check if file is writable
pub fn canWrite(path: []const u8) bool {
    const file = std.fs.cwd().openFile(path, .{ .mode = .write_only }) catch return false;
    file.close();
    return true;
}
// ANCHOR_END: access_denied

// ANCHOR: comprehensive_error_handling
/// Comprehensive error handling for file operations
pub const FileError = error{
    NotFound,
    PermissionDenied,
    IsDirectory,
    DiskFull,
    NameTooLong,
    Unknown,
};

pub fn robustFileOperation(path: []const u8, data: []const u8) FileError!void {
    const file = std.fs.cwd().createFile(path, .{}) catch |err| {
        return switch (err) {
            error.FileNotFound => FileError.NotFound,
            error.AccessDenied => FileError.PermissionDenied,
            error.IsDir => FileError.IsDirectory,
            error.NoSpaceLeft => FileError.DiskFull,
            error.NameTooLong => FileError.NameTooLong,
            else => {
                std.debug.print("Unexpected error: {}\n", .{err});
                return FileError.Unknown;
            },
        };
    };
    defer file.close();

    file.writeAll(data) catch |err| {
        return switch (err) {
            error.NoSpaceLeft => FileError.DiskFull,
            error.AccessDenied => FileError.PermissionDenied,
            else => FileError.Unknown,
        };
    };
}

/// Error context for better debugging
pub const FileErrorContext = struct {
    path: []const u8,
    operation: []const u8,
    error_code: anyerror,

    pub fn format(
        self: FileErrorContext,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Error during {s} on {s}: {any}", .{
            self.operation,
            self.path,
            self.error_code,
        });
    }
};

pub fn operationWithContext(path: []const u8) !void {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        const ctx = FileErrorContext{
            .path = path,
            .operation = "open",
            .error_code = err,
        };
        std.debug.print("{}\n", .{ctx});
        return err;
    };
    defer file.close();

    // Continue with operation
}
// ANCHOR_END: comprehensive_error_handling

// ANCHOR: retry_logic
/// Retry file operation with backoff
pub fn retryOperation(
    path: []const u8,
    max_attempts: usize,
    comptime operation: fn ([]const u8) anyerror!void,
) !void {
    var attempts: usize = 0;
    while (attempts < max_attempts) : (attempts += 1) {
        operation(path) catch |err| {
            switch (err) {
                error.DeviceBusy, error.FileBusy => {
                    // Transient error, retry after delay
                    std.debug.print("Device busy, retrying ({}/{})\n", .{ attempts + 1, max_attempts });
                    std.Thread.sleep(100 * std.time.ns_per_ms * (attempts + 1));
                    continue;
                },
                else => return err, // Non-transient error, fail immediately
            }
        };

        // Success
        return;
    }

    return error.MaxRetriesExceeded;
}
// ANCHOR_END: retry_logic

// ANCHOR: cleanup_on_error
/// Ensure cleanup even on errors
///
/// Cross-platform atomicity notes:
/// - POSIX: rename() is atomic and replaces existing files
/// - Windows: Zig uses FILE_RENAME_POSIX_SEMANTICS (requires Windows 10+ and NTFS)
/// - Network shares and FAT filesystems may have limitations
///
/// For production code, consider using std.fs.AtomicFile instead, which handles
/// all platform-specific edge cases and provides additional safety guarantees.
pub fn writeWithCleanup(path: []const u8, temp_path: []const u8, data: []const u8) !void {
    // Write to temporary file first
    const temp_file = try std.fs.cwd().createFile(temp_path, .{});
    errdefer {
        temp_file.close();
        std.fs.cwd().deleteFile(temp_path) catch {};
    }

    try temp_file.writeAll(data);
    temp_file.close();

    // Atomically rename to final location (overwrites if exists)
    try std.fs.cwd().rename(temp_path, path);
}

/// Resource cleanup with defer and errdefer
pub fn multipleFilesWithCleanup(path1: []const u8, path2: []const u8, data: []const u8) !void {
    const file1 = try std.fs.cwd().createFile(path1, .{});
    defer file1.close();
    errdefer std.fs.cwd().deleteFile(path1) catch {};

    try file1.writeAll(data);

    const file2 = try std.fs.cwd().createFile(path2, .{});
    defer file2.close();
    errdefer std.fs.cwd().deleteFile(path2) catch {};

    try file2.writeAll(data);

    // If we reach here, both files written successfully
}

/// Production-ready atomic file writing using std.fs.AtomicFile
///
/// std.fs.AtomicFile provides:
/// - Automatic temp file generation
/// - Platform-specific atomic rename
/// - Proper cleanup on error
/// - Handles all edge cases (Windows races, network shares, etc.)
pub fn atomicFileWrite(path: []const u8, data: []const u8) !void {
    const dir = std.fs.cwd();

    // Buffer for atomic file operations (Zig 0.15.2 requires write_buffer)
    var buffer: [4096]u8 = undefined;

    // AtomicFile writes to temp, then atomically renames
    var atomic_file = try dir.atomicFile(path, .{ .write_buffer = &buffer });
    defer atomic_file.deinit();

    // Write to the file through the buffered writer interface
    try atomic_file.file_writer.interface.writeAll(data);

    // Atomically move temp file to destination (calls flush then rename)
    try atomic_file.finish();
}
// ANCHOR_END: cleanup_on_error

// Tests

test "open or create file" {
    const test_path = "/tmp/test_open_or_create.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // First call creates file
    const file1 = try openOrCreate(test_path);
    defer file1.close();

    // Second call opens existing file
    const file2 = try openOrCreate(test_path);
    defer file2.close();
}

test "ensure directory idempotent" {
    const test_dir = "/tmp/test_ensure_dir";
    defer std.fs.cwd().deleteDir(test_dir) catch {};

    // First call creates
    try ensureDirectory(test_dir);

    // Second call succeeds even though exists
    try ensureDirectory(test_dir);
}

test "ensure nested directory" {
    const test_dir = "/tmp/test_nested/a/b/c";
    defer std.fs.cwd().deleteTree("/tmp/test_nested") catch {};

    try ensureNestedDirectory(test_dir);

    // Verify it exists
    var dir = try std.fs.cwd().openDir(test_dir, .{});
    defer dir.close();
}

test "exclusive file creation" {
    const test_path = "/tmp/test_exclusive.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // First creation succeeds
    const file1 = try createExclusive(test_path);
    defer file1.close();

    // Second creation fails
    const result = createExclusive(test_path);
    try testing.expectError(error.PathAlreadyExists, result);
}

test "safe open file detects directory" {
    const test_dir = "/tmp/test_safe_open";
    try std.fs.cwd().makeDir(test_dir);
    defer std.fs.cwd().deleteDir(test_dir) catch {};

    const result = safeOpenFile(test_dir);
    try testing.expectError(error.IsDir, result);
}

test "open file or dir" {
    const file_path = "/tmp/test_file_or_dir_file.txt";
    const dir_path = "/tmp/test_file_or_dir_dir";

    defer std.fs.cwd().deleteFile(file_path) catch {};
    defer std.fs.cwd().deleteDir(dir_path) catch {};

    // Create file
    {
        const file = try std.fs.cwd().createFile(file_path, .{});
        defer file.close();
    }

    // Create directory
    try std.fs.cwd().makeDir(dir_path);

    // Open file
    const file_result = try openFileOrDir(file_path);
    switch (file_result) {
        .file => |f| f.close(),
        .dir => return error.ExpectedFile,
    }

    // Open directory
    var dir_result = try openFileOrDir(dir_path);
    switch (dir_result) {
        .file => return error.ExpectedDirectory,
        .dir => |*d| d.close(),
    }
}

test "can read and write checks" {
    const test_path = "/tmp/test_can_access.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // File doesn't exist yet
    try testing.expect(!canRead(test_path));

    // Create file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
    }

    // Now should be readable and writable
    try testing.expect(canRead(test_path));
    try testing.expect(canWrite(test_path));
}

test "robust file operation with error handling" {
    const test_path = "/tmp/test_robust.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    try robustFileOperation(test_path, "Test data");

    // Verify file was created
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var buf: [20]u8 = undefined;
    const n = try file.read(&buf);
    try testing.expectEqualStrings("Test data", buf[0..n]);
}

test "write with cleanup on success" {
    const final_path = "/tmp/test_cleanup_final.txt";
    const temp_path = "/tmp/test_cleanup_temp.txt";

    defer std.fs.cwd().deleteFile(final_path) catch {};
    defer std.fs.cwd().deleteFile(temp_path) catch {};

    try writeWithCleanup(final_path, temp_path, "Data");

    // Final file should exist
    const file = try std.fs.cwd().openFile(final_path, .{});
    defer file.close();

    // Temp file should not exist
    const temp_result = std.fs.cwd().openFile(temp_path, .{});
    try testing.expectError(error.FileNotFound, temp_result);
}

test "multiple files with cleanup on error" {
    const path1 = "/tmp/test_multi1.txt";
    const path2 = "/tmp/test_multi2.txt";

    defer std.fs.cwd().deleteFile(path1) catch {};
    defer std.fs.cwd().deleteFile(path2) catch {};

    try multipleFilesWithCleanup(path1, path2, "Data");

    // Both files should exist
    {
        const file1 = try std.fs.cwd().openFile(path1, .{});
        defer file1.close();

        const file2 = try std.fs.cwd().openFile(path2, .{});
        defer file2.close();
    }
}

test "error context creation" {
    const ctx = FileErrorContext{
        .path = "/tmp/test.txt",
        .operation = "open",
        .error_code = error.FileNotFound,
    };

    // Verify struct fields
    try testing.expectEqualStrings("/tmp/test.txt", ctx.path);
    try testing.expectEqualStrings("open", ctx.operation);
    try testing.expectEqual(error.FileNotFound, ctx.error_code);
}

test "comprehensive error scenarios" {
    // Test various error conditions
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    // FileNotFound
    {
        const result = std.fs.cwd().openFile("/tmp/does_not_exist_12345.txt", .{});
        try testing.expectError(error.FileNotFound, result);
    }

    // PathAlreadyExists
    {
        const test_path = "/tmp/test_already_exists.txt";
        defer std.fs.cwd().deleteFile(test_path) catch {};

        const file1 = try std.fs.cwd().createFile(test_path, .{});
        defer file1.close();

        const result = std.fs.cwd().createFile(test_path, .{ .exclusive = true });
        try testing.expectError(error.PathAlreadyExists, result);
    }
}

test "atomic file write with std.fs.AtomicFile" {
    const test_path = "/tmp/test_atomic_write.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write using AtomicFile
    try atomicFileWrite(test_path, "Atomic data");

    // Verify file was created with correct content
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var buf: [20]u8 = undefined;
    const n = try file.read(&buf);
    try testing.expectEqualStrings("Atomic data", buf[0..n]);

    // Overwrite with new data
    try atomicFileWrite(test_path, "New atomic data");

    // Verify overwrite succeeded
    const file2 = try std.fs.cwd().openFile(test_path, .{});
    defer file2.close();

    var buf2: [30]u8 = undefined;
    const n2 = try file2.read(&buf2);
    try testing.expectEqualStrings("New atomic data", buf2[0..n2]);
}
