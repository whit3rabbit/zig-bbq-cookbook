const std = @import("std");

/// Join path components with correct separator
pub fn joinPaths(allocator: std.mem.Allocator, components: []const []const u8) ![]u8 {
    return try std.fs.path.join(allocator, components);
}

/// Get the basename (final component) of a path
pub fn getBasename(path: []const u8) []const u8 {
    return std.fs.path.basename(path);
}

/// Get the directory portion of a path
pub fn getDirname(path: []const u8) ?[]const u8 {
    return std.fs.path.dirname(path);
}

/// Get the file extension
pub fn getExtension(path: []const u8) []const u8 {
    return std.fs.path.extension(path);
}

/// Get the filename without extension
pub fn getStem(path: []const u8) []const u8 {
    return std.fs.path.stem(path);
}

/// Check if path is absolute
pub fn isAbsolutePath(path: []const u8) bool {
    return std.fs.path.isAbsolute(path);
}

/// Compute relative path from one to another
pub fn relativePath(allocator: std.mem.Allocator, from: []const u8, to: []const u8) ![]u8 {
    return try std.fs.path.relative(allocator, from, to);
}

/// Split path into components
pub fn splitPath(allocator: std.mem.Allocator, path: []const u8) ![][]const u8 {
    var components: std.ArrayList([]const u8) = .{};
    errdefer components.deinit(allocator);

    var iter = std.mem.splitScalar(u8, path, std.fs.path.sep);
    while (iter.next()) |component| {
        if (component.len > 0) {
            try components.append(allocator, component);
        }
    }

    return components.toOwnedSlice(allocator);
}

/// Normalize path by removing redundant separators and resolving dots
pub fn normalizePath(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var result: std.ArrayList(u8) = .{};
    errdefer result.deinit(allocator);

    var iter = std.mem.splitScalar(u8, path, std.fs.path.sep);
    var components: std.ArrayList([]const u8) = .{};
    defer components.deinit(allocator);

    while (iter.next()) |component| {
        if (component.len == 0 or std.mem.eql(u8, component, ".")) {
            continue;
        } else if (std.mem.eql(u8, component, "..")) {
            if (components.items.len > 0) {
                _ = components.pop();
            }
        } else {
            try components.append(allocator, component);
        }
    }

    // Rebuild path
    for (components.items, 0..) |component, i| {
        if (i > 0) {
            try result.append(allocator, std.fs.path.sep);
        }
        try result.appendSlice(allocator, component);
    }

    return result.toOwnedSlice(allocator);
}

/// Convert Windows path to Unix format
pub fn convertToUnixPath(allocator: std.mem.Allocator, windows_path: []const u8) ![]u8 {
    var result: std.ArrayList(u8) = .{};
    errdefer result.deinit(allocator);

    for (windows_path) |c| {
        if (c == '\\') {
            try result.append(allocator, '/');
        } else {
            try result.append(allocator, c);
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Convert Unix path to Windows format
pub fn convertToWindowsPath(allocator: std.mem.Allocator, unix_path: []const u8) ![]u8 {
    var result: std.ArrayList(u8) = .{};
    errdefer result.deinit(allocator);

    for (unix_path) |c| {
        if (c == '/') {
            try result.append(allocator, '\\');
        } else {
            try result.append(allocator, c);
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Path iterator for traversing components
pub const PathIterator = struct {
    path: []const u8,
    index: usize = 0,

    pub fn init(path: []const u8) PathIterator {
        return .{ .path = path };
    }

    pub fn next(self: *PathIterator) ?[]const u8 {
        while (self.index < self.path.len) {
            const start = self.index;

            // Find next separator
            while (self.index < self.path.len and self.path[self.index] != std.fs.path.sep) {
                self.index += 1;
            }

            const component = self.path[start..self.index];

            // Skip separator
            if (self.index < self.path.len) {
                self.index += 1;
            }

            // Return non-empty components
            if (component.len > 0) {
                return component;
            }
        }

        return null;
    }
};

/// Find common prefix of multiple paths
pub fn commonPrefix(allocator: std.mem.Allocator, paths: []const []const u8) ![]u8 {
    if (paths.len == 0) return try allocator.dupe(u8, "");
    if (paths.len == 1) return try allocator.dupe(u8, paths[0]);

    // Split all paths into components
    var all_components: std.ArrayList([][]const u8) = .{};
    defer {
        for (all_components.items) |components| {
            allocator.free(components);
        }
        all_components.deinit(allocator);
    }

    for (paths) |path| {
        const components = try splitPath(allocator, path);
        try all_components.append(allocator, components);
    }

    // Find common prefix length
    var prefix_len: usize = 0;
    const min_len = blk: {
        var min: usize = all_components.items[0].len;
        for (all_components.items[1..]) |components| {
            min = @min(min, components.len);
        }
        break :blk min;
    };

    outer: while (prefix_len < min_len) : (prefix_len += 1) {
        const component = all_components.items[0][prefix_len];
        for (all_components.items[1..]) |components| {
            if (!std.mem.eql(u8, component, components[prefix_len])) {
                break :outer;
            }
        }
    }

    // Rebuild prefix path
    if (prefix_len == 0) {
        return try allocator.dupe(u8, "");
    }

    return try std.fs.path.join(allocator, all_components.items[0][0..prefix_len]);
}

/// Safe path joining that prevents directory traversal
pub fn safeJoin(allocator: std.mem.Allocator, base: []const u8, sub: []const u8) ![]u8 {
    // Reject absolute paths in sub
    if (std.fs.path.isAbsolute(sub)) {
        return error.AbsolutePathNotAllowed;
    }

    // Reject paths with ..
    if (std.mem.indexOf(u8, sub, "..") != null) {
        return error.ParentDirectoryNotAllowed;
    }

    return try std.fs.path.join(allocator, &.{ base, sub });
}

// Tests

// ANCHOR: basic_manipulation
test "join paths" {
    const allocator = std.testing.allocator;

    const path = try joinPaths(allocator, &.{ "usr", "local", "bin" });
    defer allocator.free(path);

    try std.testing.expect(path.len > 0);
    try std.testing.expect(std.mem.indexOf(u8, path, "usr") != null);
    try std.testing.expect(std.mem.indexOf(u8, path, "local") != null);
    try std.testing.expect(std.mem.indexOf(u8, path, "bin") != null);
}

test "join empty components" {
    const allocator = std.testing.allocator;

    const path = try joinPaths(allocator, &.{});
    defer allocator.free(path);

    try std.testing.expectEqualStrings("", path);
}

test "join single component" {
    const allocator = std.testing.allocator;

    const path = try joinPaths(allocator, &.{"single"});
    defer allocator.free(path);

    try std.testing.expectEqualStrings("single", path);
}

test "basename" {
    try std.testing.expectEqualStrings("file.txt", getBasename("/home/user/file.txt"));
    try std.testing.expectEqualStrings("file.txt", getBasename("file.txt"));
    try std.testing.expectEqualStrings("user", getBasename("/home/user/"));
    try std.testing.expectEqualStrings("", getBasename("/"));
}

test "dirname" {
    try std.testing.expectEqualStrings("/home/user", getDirname("/home/user/file.txt").?);
    try std.testing.expectEqualStrings("/home", getDirname("/home/user/").?);
    try std.testing.expect(getDirname("file.txt") == null);
    try std.testing.expectEqualStrings("/", getDirname("/file.txt").?);
}

test "extension" {
    try std.testing.expectEqualStrings(".txt", getExtension("file.txt"));
    try std.testing.expectEqualStrings(".gz", getExtension("archive.tar.gz")); // Only returns last extension
    try std.testing.expectEqualStrings("", getExtension("noext"));
    try std.testing.expectEqualStrings("", getExtension(".hidden"));
    try std.testing.expectEqualStrings(".conf", getExtension("/etc/app.conf"));
}

test "stem" {
    try std.testing.expectEqualStrings("file", getStem("file.txt"));
    try std.testing.expectEqualStrings("archive.tar", getStem("archive.tar.gz"));
    try std.testing.expectEqualStrings("noext", getStem("noext"));
    try std.testing.expectEqualStrings(".hidden", getStem(".hidden"));
}
// ANCHOR_END: basic_manipulation

test "is absolute" {
    try std.testing.expect(isAbsolutePath("/home/user"));
    try std.testing.expect(!isAbsolutePath("relative/path"));
    try std.testing.expect(!isAbsolutePath(""));

    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        try std.testing.expect(isAbsolutePath("C:\\Users"));
        try std.testing.expect(isAbsolutePath("\\\\server\\share"));
    }
}

test "relative path" {
    const allocator = std.testing.allocator;

    const rel = try relativePath(allocator, "/home/user", "/home/user/docs/file.txt");
    defer allocator.free(rel);

    try std.testing.expectEqualStrings("docs/file.txt", rel);
}

test "relative path same directory" {
    const allocator = std.testing.allocator;

    const rel = try relativePath(allocator, "/home/user", "/home/user");
    defer allocator.free(rel);

    // Same directory returns empty string, not "."
    try std.testing.expectEqualStrings("", rel);
}

test "split path" {
    const allocator = std.testing.allocator;

    const components = try splitPath(allocator, "home/user/file.txt");
    defer allocator.free(components);

    try std.testing.expectEqual(@as(usize, 3), components.len);
    try std.testing.expectEqualStrings("home", components[0]);
    try std.testing.expectEqualStrings("user", components[1]);
    try std.testing.expectEqualStrings("file.txt", components[2]);
}

test "split path with leading separator" {
    const allocator = std.testing.allocator;

    const components = try splitPath(allocator, "/home/user");
    defer allocator.free(components);

    try std.testing.expectEqual(@as(usize, 2), components.len);
    try std.testing.expectEqualStrings("home", components[0]);
    try std.testing.expectEqualStrings("user", components[1]);
}

test "split empty path" {
    const allocator = std.testing.allocator;

    const components = try splitPath(allocator, "");
    defer allocator.free(components);

    try std.testing.expectEqual(@as(usize, 0), components.len);
}

// ANCHOR: normalize_paths
test "normalize path" {
    const allocator = std.testing.allocator;

    const normalized = try normalizePath(allocator, "a/./b/../c");
    defer allocator.free(normalized);

    try std.testing.expectEqualStrings("a/c", normalized);
}

test "normalize path with multiple dots" {
    const allocator = std.testing.allocator;

    const normalized = try normalizePath(allocator, "a/b/../../c");
    defer allocator.free(normalized);

    try std.testing.expectEqualStrings("c", normalized);
}

test "normalize path with redundant separators" {
    const allocator = std.testing.allocator;

    const normalized = try normalizePath(allocator, "a//b///c");
    defer allocator.free(normalized);

    try std.testing.expectEqualStrings("a/b/c", normalized);
}
// ANCHOR_END: normalize_paths

test "convert to unix path" {
    const allocator = std.testing.allocator;

    const unix = try convertToUnixPath(allocator, "C:\\Users\\name\\file.txt");
    defer allocator.free(unix);

    try std.testing.expectEqualStrings("C:/Users/name/file.txt", unix);
}

test "convert to windows path" {
    const allocator = std.testing.allocator;

    const windows = try convertToWindowsPath(allocator, "home/user/file.txt");
    defer allocator.free(windows);

    try std.testing.expectEqualStrings("home\\user\\file.txt", windows);
}

test "path iterator" {
    var iter = PathIterator.init("home/user/file.txt");

    try std.testing.expectEqualStrings("home", iter.next().?);
    try std.testing.expectEqualStrings("user", iter.next().?);
    try std.testing.expectEqualStrings("file.txt", iter.next().?);
    try std.testing.expect(iter.next() == null);
}

test "path iterator with leading separator" {
    var iter = PathIterator.init("/home/user");

    try std.testing.expectEqualStrings("home", iter.next().?);
    try std.testing.expectEqualStrings("user", iter.next().?);
    try std.testing.expect(iter.next() == null);
}

test "path iterator empty" {
    var iter = PathIterator.init("");
    try std.testing.expect(iter.next() == null);
}

test "common prefix two paths" {
    const allocator = std.testing.allocator;

    const paths = [_][]const u8{
        "home/user/docs/file1.txt",
        "home/user/docs/file2.txt",
    };

    const prefix = try commonPrefix(allocator, &paths);
    defer allocator.free(prefix);

    try std.testing.expectEqualStrings("home/user/docs", prefix);
}

test "common prefix no common" {
    const allocator = std.testing.allocator;

    const paths = [_][]const u8{
        "home/user/docs",
        "var/log/app",
    };

    const prefix = try commonPrefix(allocator, &paths);
    defer allocator.free(prefix);

    try std.testing.expectEqualStrings("", prefix);
}

test "common prefix single path" {
    const allocator = std.testing.allocator;

    const paths = [_][]const u8{"home/user/docs"};

    const prefix = try commonPrefix(allocator, &paths);
    defer allocator.free(prefix);

    try std.testing.expectEqualStrings("home/user/docs", prefix);
}

test "common prefix empty" {
    const allocator = std.testing.allocator;

    const paths: []const []const u8 = &.{};

    const prefix = try commonPrefix(allocator, paths);
    defer allocator.free(prefix);

    try std.testing.expectEqualStrings("", prefix);
}

// ANCHOR: safe_join
test "safe join valid" {
    const allocator = std.testing.allocator;

    const path = try safeJoin(allocator, "/base", "sub/file.txt");
    defer allocator.free(path);

    try std.testing.expect(std.mem.indexOf(u8, path, "base") != null);
    try std.testing.expect(std.mem.indexOf(u8, path, "sub") != null);
}

test "safe join rejects parent directory" {
    const allocator = std.testing.allocator;

    const result = safeJoin(allocator, "/base", "../etc");
    try std.testing.expectError(error.ParentDirectoryNotAllowed, result);
}

test "safe join rejects absolute path" {
    const allocator = std.testing.allocator;

    const result = safeJoin(allocator, "/base", "/etc/passwd");
    try std.testing.expectError(error.AbsolutePathNotAllowed, result);
}
// ANCHOR_END: safe_join

test "path separator" {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        try std.testing.expectEqual(@as(u8, '\\'), std.fs.path.sep);
    } else {
        try std.testing.expectEqual(@as(u8, '/'), std.fs.path.sep);
    }
}

test "multiple join operations" {
    const allocator = std.testing.allocator;

    const path1 = try joinPaths(allocator, &.{ "a", "b" });
    defer allocator.free(path1);

    const path2 = try joinPaths(allocator, &.{ path1, "c" });
    defer allocator.free(path2);

    try std.testing.expect(std.mem.indexOf(u8, path2, "a") != null);
    try std.testing.expect(std.mem.indexOf(u8, path2, "b") != null);
    try std.testing.expect(std.mem.indexOf(u8, path2, "c") != null);
}

test "basename with multiple dots" {
    try std.testing.expectEqualStrings("archive.tar.gz", getBasename("/backup/archive.tar.gz"));
    try std.testing.expectEqualStrings("config.yaml.bak", getBasename("config.yaml.bak"));
}

test "normalize complex path" {
    const allocator = std.testing.allocator;

    const normalized = try normalizePath(allocator, "./a/b/../c/./d");
    defer allocator.free(normalized);

    try std.testing.expectEqualStrings("a/c/d", normalized);
}
