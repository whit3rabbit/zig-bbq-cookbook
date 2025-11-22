const std = @import("std");
const testing = std.testing;

// ANCHOR: find_by_name
/// Find files by exact name match using iterative Walker
/// This prevents file descriptor exhaustion in deeply nested directories
fn findFilesByName(
    allocator: std.mem.Allocator,
    dir_path: []const u8,
    target_name: []const u8,
) ![][]const u8 {
    var results = std.ArrayList([]const u8){};
    errdefer {
        for (results.items) |item| allocator.free(item);
        results.deinit(allocator);
    }

    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        const basename = std.fs.path.basename(entry.path);
        if (std.mem.eql(u8, basename, target_name)) {
            const full_path = try std.fs.path.join(allocator, &.{ dir_path, entry.path });
            try results.append(allocator, full_path);
        }
    }

    return results.toOwnedSlice(allocator);
}

test "find files by name" {
    const test_dir = "zig-cache/test_find";
    std.fs.cwd().deleteTree(test_dir) catch {};
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    // Create test structure
    try std.fs.cwd().makePath("zig-cache/test_find/a");
    try std.fs.cwd().makePath("zig-cache/test_find/b");

    {
        const file = try std.fs.cwd().createFile("zig-cache/test_find/target.txt", .{});
        file.close();
    }
    {
        const file = try std.fs.cwd().createFile("zig-cache/test_find/a/target.txt", .{});
        file.close();
    }

    const results = try findFilesByName(testing.allocator, test_dir, "target.txt");
    defer {
        for (results) |path| testing.allocator.free(path);
        testing.allocator.free(results);
    }

    try testing.expectEqual(2, results.len);
}
// ANCHOR_END: find_by_name

// ANCHOR: find_by_pattern
/// Find files matching a pattern (simple glob-like)
fn findFilesByPattern(
    allocator: std.mem.Allocator,
    dir_path: []const u8,
    pattern: []const u8,
) ![][]const u8 {
    var results = std.ArrayList([]const u8){};
    errdefer {
        for (results.items) |item| allocator.free(item);
        results.deinit(allocator);
    }

    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        const basename = std.fs.path.basename(entry.path);
        if (matchesPattern(basename, pattern)) {
            const full_path = try std.fs.path.join(allocator, &.{ dir_path, entry.path });
            try results.append(allocator, full_path);
        }
    }

    return results.toOwnedSlice(allocator);
}

fn matchesPattern(name: []const u8, pattern: []const u8) bool {
    // Simple pattern matching: * matches anything
    if (std.mem.indexOf(u8, pattern, "*")) |star_pos| {
        const prefix = pattern[0..star_pos];
        const suffix = pattern[star_pos + 1 ..];

        if (!std.mem.startsWith(u8, name, prefix)) return false;
        if (!std.mem.endsWith(u8, name, suffix)) return false;

        return true;
    }

    return std.mem.eql(u8, name, pattern);
}

test "pattern matching" {
    try testing.expect(matchesPattern("test.txt", "*.txt"));
    try testing.expect(matchesPattern("file.log", "*.log"));
    try testing.expect(matchesPattern("README.md", "README.*"));
    try testing.expect(!matchesPattern("test.txt", "*.log"));
}

test "find files by pattern" {
    const test_dir = "zig-cache/test_pattern";
    std.fs.cwd().deleteTree(test_dir) catch {};
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    try std.fs.cwd().makePath(test_dir);
    {
        const file = try std.fs.cwd().createFile("zig-cache/test_pattern/file1.txt", .{});
        file.close();
    }
    {
        const file = try std.fs.cwd().createFile("zig-cache/test_pattern/file2.log", .{});
        file.close();
    }

    const results = try findFilesByPattern(testing.allocator, test_dir, "*.txt");
    defer {
        for (results) |path| testing.allocator.free(path);
        testing.allocator.free(results);
    }

    try testing.expectEqual(1, results.len);
}
// ANCHOR_END: find_by_pattern

// ANCHOR: find_by_extension
/// Find files by extension
fn findFilesByExtension(
    allocator: std.mem.Allocator,
    dir_path: []const u8,
    extension: []const u8,
) ![][]const u8 {
    var results = std.ArrayList([]const u8){};
    errdefer {
        for (results.items) |item| allocator.free(item);
        results.deinit(allocator);
    }

    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind == .file) {
            const basename = std.fs.path.basename(entry.path);
            if (std.mem.endsWith(u8, basename, extension)) {
                const full_path = try std.fs.path.join(allocator, &.{ dir_path, entry.path });
                try results.append(allocator, full_path);
            }
        }
    }

    return results.toOwnedSlice(allocator);
}

test "find files by extension" {
    const test_dir = "zig-cache/test_ext";
    std.fs.cwd().deleteTree(test_dir) catch {};
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    try std.fs.cwd().makePath(test_dir);
    {
        const file = try std.fs.cwd().createFile("zig-cache/test_ext/file.zig", .{});
        file.close();
    }
    {
        const file = try std.fs.cwd().createFile("zig-cache/test_ext/other.txt", .{});
        file.close();
    }

    const results = try findFilesByExtension(testing.allocator, test_dir, ".zig");
    defer {
        for (results) |path| testing.allocator.free(path);
        testing.allocator.free(results);
    }

    try testing.expectEqual(1, results.len);
}
// ANCHOR_END: find_by_extension

// ANCHOR: find_by_size
/// Find files larger than a given size
fn findFilesLargerThan(
    allocator: std.mem.Allocator,
    dir_path: []const u8,
    min_size: u64,
) ![][]const u8 {
    var results = std.ArrayList([]const u8){};
    errdefer {
        for (results.items) |item| allocator.free(item);
        results.deinit(allocator);
    }

    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind == .file) {
            const entry_path = try std.fs.path.join(allocator, &.{ dir_path, entry.path });
            defer allocator.free(entry_path);

            const file = try std.fs.cwd().openFile(entry_path, .{});
            defer file.close();

            const stat = try file.stat();
            if (stat.size >= min_size) {
                const full_path = try std.fs.path.join(allocator, &.{ dir_path, entry.path });
                try results.append(allocator, full_path);
            }
        }
    }

    return results.toOwnedSlice(allocator);
}

test "find files by size" {
    const test_dir = "zig-cache/test_size";
    std.fs.cwd().deleteTree(test_dir) catch {};
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    try std.fs.cwd().makePath(test_dir);
    {
        const file = try std.fs.cwd().createFile("zig-cache/test_size/small.txt", .{});
        defer file.close();
        try file.writeAll("tiny");
    }
    {
        const file = try std.fs.cwd().createFile("zig-cache/test_size/large.txt", .{});
        defer file.close();
        try file.writeAll("A" ** 1000);
    }

    const results = try findFilesLargerThan(testing.allocator, test_dir, 100);
    defer {
        for (results) |path| testing.allocator.free(path);
        testing.allocator.free(results);
    }

    try testing.expectEqual(1, results.len);
}
// ANCHOR_END: find_by_size

// ANCHOR: find_predicate
/// Find files matching a custom predicate
fn findFilesMatching(
    allocator: std.mem.Allocator,
    dir_path: []const u8,
    predicate: *const fn (entry: std.fs.Dir.Entry) bool,
) ![][]const u8 {
    var results = std.ArrayList([]const u8){};
    errdefer {
        for (results.items) |item| allocator.free(item);
        results.deinit(allocator);
    }

    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        // Convert Walker.Entry to Dir.Entry for predicate
        const dir_entry = std.fs.Dir.Entry{
            .name = std.fs.path.basename(entry.path),
            .kind = entry.kind,
        };

        if (predicate(dir_entry)) {
            const full_path = try std.fs.path.join(allocator, &.{ dir_path, entry.path });
            try results.append(allocator, full_path);
        }
    }

    return results.toOwnedSlice(allocator);
}

fn isZigFile(entry: std.fs.Dir.Entry) bool {
    return entry.kind == .file and std.mem.endsWith(u8, entry.name, ".zig");
}

test "find files with predicate" {
    const test_dir = "zig-cache/test_predicate";
    std.fs.cwd().deleteTree(test_dir) catch {};
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    try std.fs.cwd().makePath(test_dir);
    {
        const file = try std.fs.cwd().createFile("zig-cache/test_predicate/main.zig", .{});
        file.close();
    }
    {
        const file = try std.fs.cwd().createFile("zig-cache/test_predicate/readme.txt", .{});
        file.close();
    }

    const results = try findFilesMatching(testing.allocator, test_dir, &isZigFile);
    defer {
        for (results) |path| testing.allocator.free(path);
        testing.allocator.free(results);
    }

    try testing.expectEqual(1, results.len);
}
// ANCHOR_END: find_predicate

// ANCHOR: find_empty_files
/// Find empty files
fn findEmptyFiles(allocator: std.mem.Allocator, dir_path: []const u8) ![][]const u8 {
    var results = std.ArrayList([]const u8){};
    errdefer {
        for (results.items) |item| allocator.free(item);
        results.deinit(allocator);
    }

    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind == .file) {
            const entry_path = try std.fs.path.join(allocator, &.{ dir_path, entry.path });
            defer allocator.free(entry_path);

            const file = try std.fs.cwd().openFile(entry_path, .{});
            defer file.close();

            const stat = try file.stat();
            if (stat.size == 0) {
                const full_path = try std.fs.path.join(allocator, &.{ dir_path, entry.path });
                try results.append(allocator, full_path);
            }
        }
    }

    return results.toOwnedSlice(allocator);
}

test "find empty files" {
    const test_dir = "zig-cache/test_empty";
    std.fs.cwd().deleteTree(test_dir) catch {};
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    try std.fs.cwd().makePath(test_dir);
    {
        const file = try std.fs.cwd().createFile("zig-cache/test_empty/empty.txt", .{});
        file.close();
    }
    {
        const file = try std.fs.cwd().createFile("zig-cache/test_empty/full.txt", .{});
        defer file.close();
        try file.writeAll("content");
    }

    const results = try findEmptyFiles(testing.allocator, test_dir);
    defer {
        for (results) |path| testing.allocator.free(path);
        testing.allocator.free(results);
    }

    try testing.expectEqual(1, results.len);
}
// ANCHOR_END: find_empty_files
