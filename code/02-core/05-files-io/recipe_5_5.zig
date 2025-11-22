const std = @import("std");

// ANCHOR: exclusive_creation
/// Create a file exclusively (fails if file already exists)
pub fn createExclusive(path: []const u8, data: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{
        .exclusive = true,
    });
    defer file.close();

    try file.writeAll(data);
}

/// Acquire a lock file (fails if lock already held)
pub fn acquireLock(lock_path: []const u8) !std.fs.File {
    return std.fs.cwd().createFile(lock_path, .{
        .exclusive = true,
    });
}

/// Release a lock file
pub fn releaseLock(lock: std.fs.File, lock_path: []const u8) void {
    lock.close();
    std.fs.cwd().deleteFile(lock_path) catch {};
}

/// Create a unique temporary file with random suffix
pub fn createUniqueFile(allocator: std.mem.Allocator, prefix: []const u8) !struct { path: []const u8, file: std.fs.File } {
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    const random = prng.random();

    var attempts: usize = 0;
    while (attempts < 100) : (attempts += 1) {
        const suffix = random.int(u32);
        const path = try std.fmt.allocPrint(allocator, "{s}_{d}.tmp", .{ prefix, suffix });
        errdefer allocator.free(path);

        const file = std.fs.cwd().createFile(path, .{
            .exclusive = true,
        }) catch |err| {
            if (err == error.PathAlreadyExists) {
                allocator.free(path);
                continue;
            }
            return err;
        };

        return .{ .path = path, .file = file };
    }

    return error.TooManyAttempts;
}
// ANCHOR_END: exclusive_creation

// ANCHOR: atomic_operations
/// Safely update a configuration file using atomic rename
pub fn safeUpdateConfig(config_path: []const u8, new_content: []const u8, allocator: std.mem.Allocator) !void {
    // Create unique temp file
    const temp_path = try std.fmt.allocPrint(allocator, "{s}.tmp", .{config_path});
    defer allocator.free(temp_path);

    // Write to temp file with exclusive creation
    {
        const file = try std.fs.cwd().createFile(temp_path, .{
            .exclusive = true,
        });
        defer file.close();
        try file.writeAll(new_content);
    }

    // Atomically replace original file
    try std.fs.cwd().rename(temp_path, config_path);
}

/// Write exclusively with error cleanup
pub fn writeExclusiveWithCleanup(path: []const u8, data: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{
        .exclusive = true,
    });
    errdefer {
        file.close();
        // Clean up partial file on error
        std.fs.cwd().deleteFile(path) catch {};
    }
    defer file.close();

    try file.writeAll(data);
}
// ANCHOR_END: atomic_operations

// Tests

test "exclusive file creation" {
    const test_path = "/tmp/exclusive_test.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // First creation succeeds
    try createExclusive(test_path, "first write");

    // Second attempt fails
    const result = createExclusive(test_path, "second write");
    try std.testing.expectError(error.PathAlreadyExists, result);

    // Original content preserved
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();
    var buf: [32]u8 = undefined;
    const bytes_read = try file.read(&buf);
    try std.testing.expectEqualStrings("first write", buf[0..bytes_read]);
}

test "non-exclusive overwrites" {
    const test_path = "/tmp/non_exclusive_test.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // First write
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("first");
    }

    // Second write overwrites (default behavior)
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("second");
    }

    // Second content is present
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();
    var buf: [32]u8 = undefined;
    const bytes_read = try file.read(&buf);
    try std.testing.expectEqualStrings("second", buf[0..bytes_read]);
}

test "exclusive creation error handling" {
    const test_path = "/tmp/exclusive_error_test.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create initial file
    try createExclusive(test_path, "data");

    // Try to create again with error handling
    const result = std.fs.cwd().createFile(test_path, .{ .exclusive = true });
    if (result) |file| {
        file.close();
        try std.testing.expect(false); // Should not reach here
    } else |err| switch (err) {
        error.PathAlreadyExists => {
            // Expected error
        },
        else => return err,
    }
}

test "lock file acquire and release" {
    const lock_path = "/tmp/test.lock";
    defer std.fs.cwd().deleteFile(lock_path) catch {};

    // Acquire lock
    const lock = try acquireLock(lock_path);

    // Try to acquire again (should fail)
    const result = acquireLock(lock_path);
    try std.testing.expectError(error.PathAlreadyExists, result);

    // Release lock
    releaseLock(lock, lock_path);

    // Can acquire again after release
    const lock2 = try acquireLock(lock_path);
    releaseLock(lock2, lock_path);
}

test "unique file creation" {
    const allocator = std.testing.allocator;

    // Create first unique file
    const result1 = try createUniqueFile(allocator, "/tmp/unique");
    defer {
        result1.file.close();
        std.fs.cwd().deleteFile(result1.path) catch {};
        allocator.free(result1.path);
    }

    // Create second unique file (different path)
    const result2 = try createUniqueFile(allocator, "/tmp/unique");
    defer {
        result2.file.close();
        std.fs.cwd().deleteFile(result2.path) catch {};
        allocator.free(result2.path);
    }

    // Paths should be different
    try std.testing.expect(!std.mem.eql(u8, result1.path, result2.path));

    // Both files should exist
    try result1.file.writeAll("file1");
    try result2.file.writeAll("file2");
}

test "safe config update" {
    const allocator = std.testing.allocator;
    const config_path = "/tmp/config.json";
    defer std.fs.cwd().deleteFile(config_path) catch {};

    // Initial config
    try safeUpdateConfig(config_path, "{ \"version\": 1 }", allocator);

    // Verify initial content
    {
        const file = try std.fs.cwd().openFile(config_path, .{});
        defer file.close();
        var buf: [64]u8 = undefined;
        const bytes_read = try file.read(&buf);
        try std.testing.expectEqualStrings("{ \"version\": 1 }", buf[0..bytes_read]);
    }

    // Update config
    try safeUpdateConfig(config_path, "{ \"version\": 2 }", allocator);

    // Verify updated content
    {
        const file = try std.fs.cwd().openFile(config_path, .{});
        defer file.close();
        var buf: [64]u8 = undefined;
        const bytes_read = try file.read(&buf);
        try std.testing.expectEqualStrings("{ \"version\": 2 }", buf[0..bytes_read]);
    }
}

test "write exclusive with cleanup" {
    const test_path = "/tmp/exclusive_cleanup_test.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write successfully
    try writeExclusiveWithCleanup(test_path, "test data");

    // Verify content
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();
    var buf: [32]u8 = undefined;
    const bytes_read = try file.read(&buf);
    try std.testing.expectEqualStrings("test data", buf[0..bytes_read]);
}

test "multiple exclusive attempts" {
    const test_path = "/tmp/multi_exclusive_test.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Try creating multiple times
    try createExclusive(test_path, "first");

    var failures: usize = 0;
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        createExclusive(test_path, "attempt") catch {
            failures += 1;
            continue;
        };
    }

    // All subsequent attempts should fail
    try std.testing.expectEqual(@as(usize, 10), failures);
}

test "exclusive with empty content" {
    const test_path = "/tmp/exclusive_empty_test.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create with empty content
    try createExclusive(test_path, "");

    // Verify file exists and is empty
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();
    const stat = try file.stat();
    try std.testing.expectEqual(@as(u64, 0), stat.size);
}

test "exclusive creation in subdirectory" {
    const dir_path = "/tmp/test_subdir";
    const test_path = "/tmp/test_subdir/exclusive.txt";

    // Create directory
    std.fs.cwd().makeDir(dir_path) catch {};
    defer std.fs.cwd().deleteTree(dir_path) catch {};

    // Create file exclusively
    const file = try std.fs.cwd().createFile(test_path, .{
        .exclusive = true,
    });
    defer file.close();
    try file.writeAll("content");

    // Verify
    const read_file = try std.fs.cwd().openFile(test_path, .{});
    defer read_file.close();
    var buf: [32]u8 = undefined;
    const bytes_read = try read_file.read(&buf);
    try std.testing.expectEqualStrings("content", buf[0..bytes_read]);
}

test "lock pattern with defer" {
    const lock_path = "/tmp/test_defer.lock";
    defer std.fs.cwd().deleteFile(lock_path) catch {};

    // Acquire and auto-release with defer
    {
        const lock = try acquireLock(lock_path);
        defer releaseLock(lock, lock_path);

        // Lock is held here
        const result = acquireLock(lock_path);
        try std.testing.expectError(error.PathAlreadyExists, result);
    }

    // Lock released, can acquire again
    const lock2 = try acquireLock(lock_path);
    releaseLock(lock2, lock_path);
}
