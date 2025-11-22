const std = @import("std");

/// List all entries in a directory
pub fn listDirectory(allocator: std.mem.Allocator, path: []const u8) ![][]const u8 {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var entries = std.ArrayList([]const u8){};
    errdefer {
        for (entries.items) |item| {
            allocator.free(item);
        }
        entries.deinit(allocator);
    }

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        const name = try allocator.dupe(u8, entry.name);
        try entries.append(allocator, name);
    }

    // toOwnedSlice transfers ownership of the internal buffer to the caller
    // Caller must free each string and then the slice itself
    return entries.toOwnedSlice(allocator);
}

/// Directory contents separated by type
pub const DirContents = struct {
    files: [][]const u8,
    directories: [][]const u8,

    /// Frees all allocated memory
    /// The slices were created by toOwnedSlice(), which transfers ownership of
    /// the internal ArrayList buffer to the caller. We must:
    /// 1. Free each individual string (allocated via dupe)
    /// 2. Free the slice itself (allocated by toOwnedSlice)
    pub fn deinit(self: *DirContents, allocator: std.mem.Allocator) void {
        // Free each file path string
        for (self.files) |file| {
            allocator.free(file);
        }
        // Free the files slice itself
        allocator.free(self.files);

        // Free each directory path string
        for (self.directories) |dir| {
            allocator.free(dir);
        }
        // Free the directories slice itself
        allocator.free(self.directories);
    }
};

/// List directory contents separated by type
pub fn listByType(allocator: std.mem.Allocator, path: []const u8) !DirContents {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var files = std.ArrayList([]const u8){};
    errdefer {
        for (files.items) |item| {
            allocator.free(item);
        }
        files.deinit(allocator);
    }

    var directories = std.ArrayList([]const u8){};
    errdefer {
        for (directories.items) |item| {
            allocator.free(item);
        }
        directories.deinit(allocator);
    }

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        const name = try allocator.dupe(u8, entry.name);
        errdefer allocator.free(name);

        switch (entry.kind) {
            .file => try files.append(allocator, name),
            .directory => try directories.append(allocator, name),
            else => allocator.free(name),
        }
    }

    return DirContents{
        .files = try files.toOwnedSlice(allocator),
        .directories = try directories.toOwnedSlice(allocator),
    };
}

/// List files with specific extension
pub fn listByExtension(
    allocator: std.mem.Allocator,
    path: []const u8,
    ext: []const u8,
) ![][]const u8 {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var entries = std.ArrayList([]const u8){};
    errdefer {
        for (entries.items) |item| {
            allocator.free(item);
        }
        entries.deinit(allocator);
    }

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;

        const file_ext = std.fs.path.extension(entry.name);
        if (std.mem.eql(u8, file_ext, ext)) {
            const name = try allocator.dupe(u8, entry.name);
            try entries.append(allocator, name);
        }
    }

    return entries.toOwnedSlice(allocator);
}

/// Recursively walk directory tree
pub fn walkDirectory(
    allocator: std.mem.Allocator,
    path: []const u8,
    results: *std.ArrayList([]const u8),
) !void {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        const full_path = try std.fs.path.join(allocator, &[_][]const u8{ path, entry.name });
        errdefer allocator.free(full_path);

        try results.append(allocator, full_path);

        if (entry.kind == .directory) {
            try walkDirectory(allocator, full_path, results);
        }
    }
}

/// List directory recursively
pub fn listRecursive(allocator: std.mem.Allocator, path: []const u8) ![][]const u8 {
    var results = std.ArrayList([]const u8){};
    errdefer {
        for (results.items) |item| {
            allocator.free(item);
        }
        results.deinit(allocator);
    }

    try walkDirectory(allocator, path, &results);

    return results.toOwnedSlice(allocator);
}

/// List directory entries in sorted order
pub fn listSorted(allocator: std.mem.Allocator, path: []const u8) ![][]const u8 {
    const entries = try listDirectory(allocator, path);
    errdefer {
        for (entries) |entry| {
            allocator.free(entry);
        }
        allocator.free(entries);
    }

    std.mem.sort([]const u8, entries, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.order(u8, a, b) == .lt;
        }
    }.lessThan);

    return entries;
}

/// File information entry
pub const FileInfo = struct {
    name: []const u8,
    size: u64,
    is_dir: bool,
    mtime: i128,

    /// Frees the allocated name string
    pub fn deinit(self: *FileInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }
};

/// List directory with file information
pub fn listWithInfo(allocator: std.mem.Allocator, path: []const u8) ![]FileInfo {
    var dir = try std.fs.cwd().openDir(path, .{});
    defer dir.close();

    var entries = std.ArrayList(FileInfo){};
    errdefer {
        for (entries.items) |*item| {
            allocator.free(item.name);
        }
        entries.deinit(allocator);
    }

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        const stat = dir.statFile(entry.name) catch continue;

        const name = try allocator.dupe(u8, entry.name);
        errdefer allocator.free(name);

        try entries.append(allocator, .{
            .name = name,
            .size = stat.size,
            .is_dir = entry.kind == .directory,
            .mtime = stat.mtime,
        });
    }

    return entries.toOwnedSlice(allocator);
}

/// Check if name matches wildcard pattern
pub fn matchesPattern(name: []const u8, pattern: []const u8) bool {
    if (std.mem.indexOf(u8, pattern, "*")) |star_pos| {
        const prefix = pattern[0..star_pos];
        const suffix = pattern[star_pos + 1 ..];

        if (!std.mem.startsWith(u8, name, prefix)) return false;
        if (!std.mem.endsWith(u8, name, suffix)) return false;

        return true;
    }

    return std.mem.eql(u8, name, pattern);
}

/// List files matching pattern
pub fn listByPattern(
    allocator: std.mem.Allocator,
    path: []const u8,
    pattern: []const u8,
) ![][]const u8 {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var entries = std.ArrayList([]const u8){};
    errdefer {
        for (entries.items) |item| {
            allocator.free(item);
        }
        entries.deinit(allocator);
    }

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (matchesPattern(entry.name, pattern)) {
            const name = try allocator.dupe(u8, entry.name);
            try entries.append(allocator, name);
        }
    }

    return entries.toOwnedSlice(allocator);
}

/// Check if filename is hidden (Unix-style)
pub fn isHidden(name: []const u8) bool {
    return name.len > 0 and name[0] == '.';
}

/// List visible files (exclude hidden)
pub fn listVisible(allocator: std.mem.Allocator, path: []const u8) ![][]const u8 {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var entries = std.ArrayList([]const u8){};
    errdefer {
        for (entries.items) |item| {
            allocator.free(item);
        }
        entries.deinit(allocator);
    }

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (!isHidden(entry.name)) {
            const name = try allocator.dupe(u8, entry.name);
            try entries.append(allocator, name);
        }
    }

    return entries.toOwnedSlice(allocator);
}

/// List limited number of entries
pub fn listN(allocator: std.mem.Allocator, path: []const u8, max_count: usize) ![][]const u8 {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var entries = std.ArrayList([]const u8){};
    errdefer {
        for (entries.items) |item| {
            allocator.free(item);
        }
        entries.deinit(allocator);
    }

    var iter = dir.iterate();
    var count: usize = 0;
    while (try iter.next()) |entry| {
        if (count >= max_count) break;

        const name = try allocator.dupe(u8, entry.name);
        try entries.append(allocator, name);
        count += 1;
    }

    return entries.toOwnedSlice(allocator);
}

/// List directory with safe error handling
pub fn safeListing(allocator: std.mem.Allocator, path: []const u8) ![][]const u8 {
    var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return error.DirectoryNotFound,
        error.NotDir => return error.NotADirectory,
        error.AccessDenied => return error.PermissionDenied,
        else => return err,
    };
    defer dir.close();

    var entries = std.ArrayList([]const u8){};
    errdefer {
        for (entries.items) |item| {
            allocator.free(item);
        }
        entries.deinit(allocator);
    }

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        const name = try allocator.dupe(u8, entry.name);
        try entries.append(allocator, name);
    }

    return entries.toOwnedSlice(allocator);
}

// Tests

// ANCHOR: basic_listing
test "list directory" {
    const allocator = std.testing.allocator;

    const test_dir = "/tmp/test_list_dir";
    try std.fs.cwd().makeDir(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    // Create test files
    {
        const file1 = try std.fs.cwd().createFile("/tmp/test_list_dir/file1.txt", .{});
        defer file1.close();
        const file2 = try std.fs.cwd().createFile("/tmp/test_list_dir/file2.txt", .{});
        defer file2.close();
    }

    // List directory
    const entries = try listDirectory(allocator, test_dir);
    defer {
        for (entries) |entry| {
            allocator.free(entry);
        }
        allocator.free(entries);
    }

    try std.testing.expectEqual(@as(usize, 2), entries.len);
}

test "list empty directory" {
    const allocator = std.testing.allocator;

    const test_dir = "/tmp/test_empty_dir";
    try std.fs.cwd().makeDir(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    const entries = try listDirectory(allocator, test_dir);
    defer allocator.free(entries);

    try std.testing.expectEqual(@as(usize, 0), entries.len);
}

test "list by type" {
    const allocator = std.testing.allocator;

    const test_dir = "/tmp/test_by_type";
    try std.fs.cwd().makeDir(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    // Create files and subdirectory
    {
        const file1 = try std.fs.cwd().createFile("/tmp/test_by_type/file1.txt", .{});
        defer file1.close();
        const file2 = try std.fs.cwd().createFile("/tmp/test_by_type/file2.txt", .{});
        defer file2.close();
    }
    try std.fs.cwd().makeDir("/tmp/test_by_type/subdir");

    var contents = try listByType(allocator, test_dir);
    defer contents.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 2), contents.files.len);
    try std.testing.expectEqual(@as(usize, 1), contents.directories.len);
}
// ANCHOR_END: basic_listing

test "list by extension" {
    const allocator = std.testing.allocator;

    const test_dir = "/tmp/test_by_ext";
    try std.fs.cwd().makeDir(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    // Create files with different extensions
    {
        const file1 = try std.fs.cwd().createFile("/tmp/test_by_ext/file1.txt", .{});
        defer file1.close();
        const file2 = try std.fs.cwd().createFile("/tmp/test_by_ext/file2.txt", .{});
        defer file2.close();
        const file3 = try std.fs.cwd().createFile("/tmp/test_by_ext/file3.md", .{});
        defer file3.close();
    }

    const entries = try listByExtension(allocator, test_dir, ".txt");
    defer {
        for (entries) |entry| {
            allocator.free(entry);
        }
        allocator.free(entries);
    }

    try std.testing.expectEqual(@as(usize, 2), entries.len);
}

// ANCHOR: filtered_listing
test "list recursive" {
    const allocator = std.testing.allocator;

    const test_dir = "/tmp/test_recursive";
    try std.fs.cwd().makeDir(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    // Create nested structure
    {
        const file1 = try std.fs.cwd().createFile("/tmp/test_recursive/file1.txt", .{});
        defer file1.close();
    }
    try std.fs.cwd().makeDir("/tmp/test_recursive/subdir");
    {
        const file2 = try std.fs.cwd().createFile("/tmp/test_recursive/subdir/file2.txt", .{});
        defer file2.close();
    }

    const entries = try listRecursive(allocator, test_dir);
    defer {
        for (entries) |entry| {
            allocator.free(entry);
        }
        allocator.free(entries);
    }

    // Should have: file1.txt, subdir, subdir/file2.txt
    try std.testing.expect(entries.len >= 3);
}

test "list sorted" {
    const allocator = std.testing.allocator;

    const test_dir = "/tmp/test_sorted";
    try std.fs.cwd().makeDir(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    // Create files in non-alphabetical order
    {
        const file_c = try std.fs.cwd().createFile("/tmp/test_sorted/c.txt", .{});
        defer file_c.close();
        const file_a = try std.fs.cwd().createFile("/tmp/test_sorted/a.txt", .{});
        defer file_a.close();
        const file_b = try std.fs.cwd().createFile("/tmp/test_sorted/b.txt", .{});
        defer file_b.close();
    }

    const entries = try listSorted(allocator, test_dir);
    defer {
        for (entries) |entry| {
            allocator.free(entry);
        }
        allocator.free(entries);
    }

    try std.testing.expectEqual(@as(usize, 3), entries.len);
    // Verify alphabetical order
    try std.testing.expectEqualStrings("a.txt", entries[0]);
    try std.testing.expectEqualStrings("b.txt", entries[1]);
    try std.testing.expectEqualStrings("c.txt", entries[2]);
}

// ANCHOR: advanced_listing
test "list with info" {
    const allocator = std.testing.allocator;

    const test_dir = "/tmp/test_with_info";
    try std.fs.cwd().makeDir(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    // Create file with content
    {
        const file = try std.fs.cwd().createFile("/tmp/test_with_info/file.txt", .{});
        defer file.close();
        try file.writeAll("Hello, World!");
    }

    const entries = try listWithInfo(allocator, test_dir);
    defer {
        for (entries) |*entry| {
            entry.deinit(allocator);
        }
        allocator.free(entries);
    }

    try std.testing.expectEqual(@as(usize, 1), entries.len);
    try std.testing.expectEqualStrings("file.txt", entries[0].name);
    try std.testing.expect(entries[0].size > 0);
    try std.testing.expect(!entries[0].is_dir);
}

test "matches pattern" {
    try std.testing.expect(matchesPattern("test.txt", "*.txt"));
    try std.testing.expect(matchesPattern("readme.md", "readme.*"));
    try std.testing.expect(matchesPattern("test", "test"));
    try std.testing.expect(!matchesPattern("test.md", "*.txt"));
}

test "list by pattern" {
    const allocator = std.testing.allocator;

    const test_dir = "/tmp/test_pattern";
    try std.fs.cwd().makeDir(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    // Create files
    {
        const file1 = try std.fs.cwd().createFile("/tmp/test_pattern/test1.txt", .{});
        defer file1.close();
        const file2 = try std.fs.cwd().createFile("/tmp/test_pattern/test2.txt", .{});
        defer file2.close();
        const file3 = try std.fs.cwd().createFile("/tmp/test_pattern/readme.md", .{});
        defer file3.close();
    }

    const entries = try listByPattern(allocator, test_dir, "test*.txt");
    defer {
        for (entries) |entry| {
            allocator.free(entry);
        }
        allocator.free(entries);
    }

    try std.testing.expectEqual(@as(usize, 2), entries.len);
}
// ANCHOR_END: filtered_listing

test "is hidden" {
    try std.testing.expect(isHidden(".hidden"));
    try std.testing.expect(isHidden("."));
    try std.testing.expect(!isHidden("visible"));
    try std.testing.expect(!isHidden(""));
}

test "list visible" {
    const allocator = std.testing.allocator;

    const test_dir = "/tmp/test_visible";
    try std.fs.cwd().makeDir(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    // Create visible and hidden files
    {
        const file1 = try std.fs.cwd().createFile("/tmp/test_visible/visible.txt", .{});
        defer file1.close();
        const file2 = try std.fs.cwd().createFile("/tmp/test_visible/.hidden", .{});
        defer file2.close();
    }

    const entries = try listVisible(allocator, test_dir);
    defer {
        for (entries) |entry| {
            allocator.free(entry);
        }
        allocator.free(entries);
    }

    try std.testing.expectEqual(@as(usize, 1), entries.len);
    try std.testing.expectEqualStrings("visible.txt", entries[0]);
}

test "list N entries" {
    const allocator = std.testing.allocator;

    const test_dir = "/tmp/test_list_n";
    try std.fs.cwd().makeDir(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    // Create multiple files
    {
        const file1 = try std.fs.cwd().createFile("/tmp/test_list_n/file1.txt", .{});
        defer file1.close();
        const file2 = try std.fs.cwd().createFile("/tmp/test_list_n/file2.txt", .{});
        defer file2.close();
        const file3 = try std.fs.cwd().createFile("/tmp/test_list_n/file3.txt", .{});
        defer file3.close();
    }

    const entries = try listN(allocator, test_dir, 2);
    defer {
        for (entries) |entry| {
            allocator.free(entry);
        }
        allocator.free(entries);
    }

    try std.testing.expectEqual(@as(usize, 2), entries.len);
}

test "safe listing - not found" {
    const allocator = std.testing.allocator;

    const result = safeListing(allocator, "/tmp/does_not_exist_dir_12345");
    try std.testing.expectError(error.DirectoryNotFound, result);
}

test "safe listing - success" {
    const allocator = std.testing.allocator;

    const test_dir = "/tmp/test_safe_list";
    try std.fs.cwd().makeDir(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    {
        const file = try std.fs.cwd().createFile("/tmp/test_safe_list/file.txt", .{});
        defer file.close();
    }

    const entries = try safeListing(allocator, test_dir);
    defer {
        for (entries) |entry| {
            allocator.free(entry);
        }
        allocator.free(entries);
    }

    try std.testing.expectEqual(@as(usize, 1), entries.len);
}

test "list nonexistent directory" {
    const allocator = std.testing.allocator;

    const result = listDirectory(allocator, "/tmp/does_not_exist_12345");
    try std.testing.expectError(error.FileNotFound, result);
}
// ANCHOR_END: advanced_listing
