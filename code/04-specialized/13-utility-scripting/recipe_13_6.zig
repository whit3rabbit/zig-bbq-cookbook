const std = @import("std");
const testing = std.testing;

// ANCHOR: copy_file
/// Copy a file from source to destination
fn copyFile(src_path: []const u8, dest_path: []const u8) !void {
    const src_file = try std.fs.cwd().openFile(src_path, .{});
    defer src_file.close();

    const dest_file = try std.fs.cwd().createFile(dest_path, .{});
    defer dest_file.close();

    const stat_info = try src_file.stat();
    const permissions = std.fs.File.Permissions{
        .inner = .{ .mode = stat_info.mode },
    };
    try dest_file.setPermissions(permissions);

    var buffer: [4096]u8 = undefined;
    while (true) {
        const bytes_read = try src_file.read(&buffer);
        if (bytes_read == 0) break;
        try dest_file.writeAll(buffer[0..bytes_read]);
    }
}

test "copy file operation" {
    const test_dir = "zig-cache/test_copy";
    std.fs.cwd().makeDir(test_dir) catch {};
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    const src = "zig-cache/test_copy/source.txt";
    const dest = "zig-cache/test_copy/dest.txt";

    // Create source file
    {
        const file = try std.fs.cwd().createFile(src, .{});
        defer file.close();
        try file.writeAll("test content");
    }

    // Copy it
    try copyFile(src, dest);

    // Verify
    const content = try std.fs.cwd().readFileAlloc(testing.allocator, dest, 1024);
    defer testing.allocator.free(content);
    try testing.expectEqualStrings("test content", content);
}
// ANCHOR_END: copy_file

// ANCHOR: move_file
/// Move a file from source to destination
fn moveFile(src_path: []const u8, dest_path: []const u8) !void {
    // Try rename first (fast if on same filesystem)
    std.fs.cwd().rename(src_path, dest_path) catch {
        // Fall back to copy + delete if rename fails
        try copyFile(src_path, dest_path);
        try std.fs.cwd().deleteFile(src_path);
    };
}

test "move file operation" {
    const test_dir = "zig-cache/test_move";
    std.fs.cwd().makeDir(test_dir) catch {};
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    const src = "zig-cache/test_move/source.txt";
    const dest = "zig-cache/test_move/dest.txt";

    // Create source
    {
        const file = try std.fs.cwd().createFile(src, .{});
        defer file.close();
        try file.writeAll("move test");
    }

    // Move it
    try moveFile(src, dest);

    // Verify source is gone
    const src_exists = std.fs.cwd().access(src, .{}) catch |err| {
        try testing.expectEqual(error.FileNotFound, err);
        return;
    };
    _ = src_exists;
    try testing.expect(false); // Should not reach here
}
// ANCHOR_END: move_file

// ANCHOR: copy_directory
/// Copy a directory recursively
fn copyDirectory(allocator: std.mem.Allocator, src_path: []const u8, dest_path: []const u8) !void {
    // Create destination directory
    try std.fs.cwd().makePath(dest_path);

    var src_dir = try std.fs.cwd().openDir(src_path, .{ .iterate = true });
    defer src_dir.close();

    var iter = src_dir.iterate();
    while (try iter.next()) |entry| {
        const src_sub = try std.fs.path.join(allocator, &.{ src_path, entry.name });
        defer allocator.free(src_sub);

        const dest_sub = try std.fs.path.join(allocator, &.{ dest_path, entry.name });
        defer allocator.free(dest_sub);

        switch (entry.kind) {
            .file => try copyFile(src_sub, dest_sub),
            .directory => try copyDirectory(allocator, src_sub, dest_sub),
            else => {}, // Skip symlinks, etc.
        }
    }
}

test "copy directory recursively" {
    const test_dir = "zig-cache/test_copy_dir";
    std.fs.cwd().deleteTree(test_dir) catch {};
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    // Create source structure
    try std.fs.cwd().makePath("zig-cache/test_copy_dir/src/sub");
    {
        const file = try std.fs.cwd().createFile("zig-cache/test_copy_dir/src/file1.txt", .{});
        defer file.close();
        try file.writeAll("content1");
    }
    {
        const file = try std.fs.cwd().createFile("zig-cache/test_copy_dir/src/sub/file2.txt", .{});
        defer file.close();
        try file.writeAll("content2");
    }

    // Copy directory
    try copyDirectory(testing.allocator, "zig-cache/test_copy_dir/src", "zig-cache/test_copy_dir/dest");

    // Verify
    const content = try std.fs.cwd().readFileAlloc(
        testing.allocator,
        "zig-cache/test_copy_dir/dest/sub/file2.txt",
        1024
    );
    defer testing.allocator.free(content);
    try testing.expectEqualStrings("content2", content);
}
// ANCHOR_END: copy_directory

// ANCHOR: move_directory
/// Move a directory
fn moveDirectory(allocator: std.mem.Allocator, src_path: []const u8, dest_path: []const u8) !void {
    std.fs.cwd().rename(src_path, dest_path) catch {
        try copyDirectory(allocator, src_path, dest_path);
        try std.fs.cwd().deleteTree(src_path);
    };
}

test "move directory" {
    const test_dir = "zig-cache/test_move_dir";
    std.fs.cwd().deleteTree(test_dir) catch {};
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    // Create source
    try std.fs.cwd().makePath("zig-cache/test_move_dir/src");
    {
        const file = try std.fs.cwd().createFile("zig-cache/test_move_dir/src/file.txt", .{});
        defer file.close();
        try file.writeAll("test");
    }

    // Move
    try moveDirectory(testing.allocator, "zig-cache/test_move_dir/src", "zig-cache/test_move_dir/dest");

    // Verify
    const stat = std.fs.cwd().statFile("zig-cache/test_move_dir/dest/file.txt") catch |err| {
        try testing.expect(false);
        return err;
    };
    try testing.expect(stat.kind == .file);
}
// ANCHOR_END: move_directory

// ANCHOR: copy_with_progress
/// Copy with progress callback
pub const CopyProgress = struct {
    bytes_copied: usize = 0,
    total_bytes: usize,
    callback: ?*const fn (current: usize, total: usize) void = null,
};

fn copyFileWithProgress(
    src_path: []const u8,
    dest_path: []const u8,
    progress: *CopyProgress,
) !void {
    const src_file = try std.fs.cwd().openFile(src_path, .{});
    defer src_file.close();

    const dest_file = try std.fs.cwd().createFile(dest_path, .{});
    defer dest_file.close();

    const stat_info = try src_file.stat();
    progress.total_bytes = stat_info.size;

    var buffer: [4096]u8 = undefined;
    while (true) {
        const bytes_read = try src_file.read(&buffer);
        if (bytes_read == 0) break;

        try dest_file.writeAll(buffer[0..bytes_read]);
        progress.bytes_copied += bytes_read;

        if (progress.callback) |cb| {
            cb(progress.bytes_copied, progress.total_bytes);
        }
    }
}

fn progressCallback(current: usize, total: usize) void {
    const percent = if (total > 0) (current * 100) / total else 0;
    std.debug.print("\rProgress: {}%", .{percent});
}

test "copy with progress tracking" {
    const test_dir = "zig-cache/test_progress";
    std.fs.cwd().makeDir(test_dir) catch {};
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    const src = "zig-cache/test_progress/source.txt";
    const dest = "zig-cache/test_progress/dest.txt";

    // Create source
    {
        const file = try std.fs.cwd().createFile(src, .{});
        defer file.close();
        try file.writeAll("A" ** 1000);
    }

    var progress = CopyProgress{ .total_bytes = 0 };
    try copyFileWithProgress(src, dest, &progress);

    try testing.expectEqual(1000, progress.bytes_copied);
    _ = progressCallback;
}
// ANCHOR_END: copy_with_progress

// ANCHOR: safe_overwrite
/// Copy with safe overwrite (atomic replacement)
fn copyFileSafe(src_path: []const u8, dest_path: []const u8, allocator: std.mem.Allocator) !void {
    // Create temporary file
    const temp_path = try std.fmt.allocPrint(allocator, "{s}.tmp", .{dest_path});
    defer allocator.free(temp_path);

    // Copy to temporary location
    try copyFile(src_path, temp_path);

    // Atomic rename
    try std.fs.cwd().rename(temp_path, dest_path);
}

test "safe copy with atomic rename" {
    const test_dir = "zig-cache/test_safe";
    std.fs.cwd().makeDir(test_dir) catch {};
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    const src = "zig-cache/test_safe/source.txt";
    const dest = "zig-cache/test_safe/dest.txt";

    // Create source
    {
        const file = try std.fs.cwd().createFile(src, .{});
        defer file.close();
        try file.writeAll("safe copy");
    }

    try copyFileSafe(src, dest, testing.allocator);

    // Verify
    const content = try std.fs.cwd().readFileAlloc(testing.allocator, dest, 1024);
    defer testing.allocator.free(content);
    try testing.expectEqualStrings("safe copy", content);
}
// ANCHOR_END: safe_overwrite

// ANCHOR: copy_preserve_metadata
/// Copy file preserving all metadata
fn copyFilePreserveAll(src_path: []const u8, dest_path: []const u8) !void {
    const src_file = try std.fs.cwd().openFile(src_path, .{});
    defer src_file.close();

    const dest_file = try std.fs.cwd().createFile(dest_path, .{});
    defer dest_file.close();

    // Preserve permissions
    const stat_info = try src_file.stat();
    const permissions = std.fs.File.Permissions{
        .inner = .{ .mode = stat_info.mode },
    };
    try dest_file.setPermissions(permissions);

    // Copy content
    var buffer: [4096]u8 = undefined;
    while (true) {
        const bytes_read = try src_file.read(&buffer);
        if (bytes_read == 0) break;
        try dest_file.writeAll(buffer[0..bytes_read]);
    }

    // Note: Preserving timestamps requires platform-specific code
}

test "copy preserving metadata" {
    const test_dir = "zig-cache/test_metadata";
    std.fs.cwd().makeDir(test_dir) catch {};
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    const src = "zig-cache/test_metadata/source.txt";
    const dest = "zig-cache/test_metadata/dest.txt";

    // Create source
    {
        const file = try std.fs.cwd().createFile(src, .{});
        defer file.close();
        try file.writeAll("metadata test");
    }

    try copyFilePreserveAll(src, dest);

    // Verify content
    const content = try std.fs.cwd().readFileAlloc(testing.allocator, dest, 1024);
    defer testing.allocator.free(content);
    try testing.expectEqualStrings("metadata test", content);
}
// ANCHOR_END: copy_preserve_metadata

// ANCHOR: batch_operations
/// Batch copy operations
pub const FileCopyOp = struct {
    src: []const u8,
    dest: []const u8,
};

fn batchCopy(allocator: std.mem.Allocator, operations: []const FileCopyOp) !void {
    for (operations) |op| {
        copyFile(op.src, op.dest) catch |err| {
            std.debug.print("Failed to copy {s} to {s}: {}\n", .{ op.src, op.dest, err });
            return err;
        };
    }
    _ = allocator;
}

test "batch copy operations" {
    const test_dir = "zig-cache/test_batch";
    std.fs.cwd().deleteTree(test_dir) catch {};
    defer std.fs.cwd().deleteTree(test_dir) catch {};
    try std.fs.cwd().makePath(test_dir);

    // Create sources
    {
        const file = try std.fs.cwd().createFile("zig-cache/test_batch/file1.txt", .{});
        defer file.close();
        try file.writeAll("content1");
    }
    {
        const file = try std.fs.cwd().createFile("zig-cache/test_batch/file2.txt", .{});
        defer file.close();
        try file.writeAll("content2");
    }

    const ops = [_]FileCopyOp{
        .{ .src = "zig-cache/test_batch/file1.txt", .dest = "zig-cache/test_batch/copy1.txt" },
        .{ .src = "zig-cache/test_batch/file2.txt", .dest = "zig-cache/test_batch/copy2.txt" },
    };

    try batchCopy(testing.allocator, &ops);

    // Verify
    const content1 = try std.fs.cwd().readFileAlloc(testing.allocator, "zig-cache/test_batch/copy1.txt", 1024);
    defer testing.allocator.free(content1);
    try testing.expectEqualStrings("content1", content1);
}
// ANCHOR_END: batch_operations

// ANCHOR: filter_copy
/// Copy directory with file filter
fn copyDirectoryFiltered(
    allocator: std.mem.Allocator,
    src_path: []const u8,
    dest_path: []const u8,
    filter: *const fn (name: []const u8) bool,
) !void {
    try std.fs.cwd().makePath(dest_path);

    var src_dir = try std.fs.cwd().openDir(src_path, .{ .iterate = true });
    defer src_dir.close();

    var iter = src_dir.iterate();
    while (try iter.next()) |entry| {
        if (!filter(entry.name)) continue;

        const src_sub = try std.fs.path.join(allocator, &.{ src_path, entry.name });
        defer allocator.free(src_sub);

        const dest_sub = try std.fs.path.join(allocator, &.{ dest_path, entry.name });
        defer allocator.free(dest_sub);

        switch (entry.kind) {
            .file => try copyFile(src_sub, dest_sub),
            .directory => try copyDirectoryFiltered(allocator, src_sub, dest_sub, filter),
            else => {},
        }
    }
}

fn isTextFile(name: []const u8) bool {
    return std.mem.endsWith(u8, name, ".txt") or std.mem.endsWith(u8, name, ".md");
}

test "filtered directory copy" {
    const test_dir = "zig-cache/test_filter";
    std.fs.cwd().deleteTree(test_dir) catch {};
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    // Create source with mixed files
    try std.fs.cwd().makePath("zig-cache/test_filter/src");
    {
        const file = try std.fs.cwd().createFile("zig-cache/test_filter/src/keep.txt", .{});
        defer file.close();
        try file.writeAll("keep");
    }
    {
        const file = try std.fs.cwd().createFile("zig-cache/test_filter/src/skip.bin", .{});
        defer file.close();
        try file.writeAll("skip");
    }

    try copyDirectoryFiltered(testing.allocator, "zig-cache/test_filter/src", "zig-cache/test_filter/dest", &isTextFile);

    // Verify only .txt file was copied
    const stat = std.fs.cwd().statFile("zig-cache/test_filter/dest/keep.txt") catch |err| {
        try testing.expect(false);
        return err;
    };
    try testing.expect(stat.kind == .file);

    // Binary file should not exist
    _ = std.fs.cwd().statFile("zig-cache/test_filter/dest/skip.bin") catch |err| {
        try testing.expectEqual(error.FileNotFound, err);
        return;
    };
    try testing.expect(false);
}
// ANCHOR_END: filter_copy
