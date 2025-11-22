const std = @import("std");

/// List filenames as raw bytes without encoding validation
pub fn listRawFilenames(allocator: std.mem.Allocator, path: []const u8) ![][]const u8 {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var entries = std.ArrayList([]const u8){};
    errdefer entries.deinit(allocator);

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        const name = try allocator.dupe(u8, entry.name);
        try entries.append(allocator, name);
    }

    return entries.toOwnedSlice(allocator);
}

/// Open file using raw byte path
pub fn openRawPath(path: []const u8) !std.fs.File {
    return std.fs.cwd().openFile(path, .{});
}

/// Compare paths at byte level
pub fn pathsEqual(path1: []const u8, path2: []const u8) bool {
    return std.mem.eql(u8, path1, path2);
}

/// Check if path starts with prefix
pub fn pathStartsWith(path: []const u8, prefix: []const u8) bool {
    return std.mem.startsWith(u8, path, prefix);
}

/// Check if path is valid UTF-8
pub fn isValidUtf8Path(path: []const u8) bool {
    return std.unicode.utf8ValidateSlice(path);
}

/// Sanitize path by replacing invalid UTF-8 sequences
pub fn sanitizePath(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    if (std.unicode.utf8ValidateSlice(path)) {
        return allocator.dupe(u8, path);
    }

    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < path.len) {
        const len = std.unicode.utf8ByteSequenceLength(path[i]) catch {
            // Invalid UTF-8, use replacement character
            try result.appendSlice(allocator, "\u{FFFD}");
            i += 1;
            continue;
        };

        if (i + len > path.len) {
            // Incomplete sequence
            try result.appendSlice(allocator, "\u{FFFD}");
            break;
        }

        try result.appendSlice(allocator, path[i .. i + len]);
        i += len;
    }

    return result.toOwnedSlice(allocator);
}

/// Path entry with encoding information
pub const PathEntry = struct {
    raw_bytes: []const u8,
    is_valid_utf8: bool,
    display_name: []const u8,

    pub fn deinit(self: *PathEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.raw_bytes);
        if (!self.is_valid_utf8) {
            allocator.free(self.display_name);
        }
    }
};

/// List directory entries with encoding information
pub fn listWithEncoding(allocator: std.mem.Allocator, path: []const u8) ![]PathEntry {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var entries = std.ArrayList(PathEntry){};
    errdefer entries.deinit(allocator);

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        const raw = try allocator.dupe(u8, entry.name);
        errdefer allocator.free(raw);

        const is_valid = std.unicode.utf8ValidateSlice(raw);
        const display = if (is_valid)
            raw
        else
            try sanitizePath(allocator, raw);

        try entries.append(allocator, .{
            .raw_bytes = raw,
            .is_valid_utf8 = is_valid,
            .display_name = display,
        });
    }

    return entries.toOwnedSlice(allocator);
}

/// Create file using raw byte filename
pub fn createFileRaw(dir_path: []const u8, filename: []const u8) !std.fs.File {
    var dir = try std.fs.cwd().openDir(dir_path, .{});
    defer dir.close();

    return dir.createFile(filename, .{});
}

/// Normalize path without encoding assumptions
pub fn normalizePath(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var components = std.ArrayList([]const u8){};
    defer components.deinit(allocator);

    var iter = std.mem.splitScalar(u8, path, '/');
    while (iter.next()) |component| {
        if (component.len == 0 or std.mem.eql(u8, component, ".")) {
            continue;
        }

        if (std.mem.eql(u8, component, "..")) {
            if (components.items.len > 0) {
                _ = components.pop();
            }
        } else {
            try components.append(allocator, component);
        }
    }

    if (components.items.len == 0) {
        return allocator.dupe(u8, "/");
    }

    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    for (components.items) |component| {
        try result.append(allocator, '/');
        try result.appendSlice(allocator, component);
    }

    return result.toOwnedSlice(allocator);
}

/// Escape path for display using hex escaping
pub fn escapePath(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    for (path) |byte| {
        if (byte >= 32 and byte < 127 and byte != '\\') {
            try result.append(allocator, byte);
        } else {
            const hex = try std.fmt.allocPrint(allocator, "\\x{X:0>2}", .{byte});
            defer allocator.free(hex);
            try result.appendSlice(allocator, hex);
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Safe open with detailed error handling
pub fn safeOpenRaw(path: []const u8) !std.fs.File {
    return std.fs.cwd().openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return error.PathNotFound,
        else => return err,
    };
}

// Tests

// ANCHOR: raw_byte_handling
test "list raw filenames" {
    const allocator = std.testing.allocator;

    const test_dir = "/tmp/test_raw_list";
    try std.fs.cwd().makeDir(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    {
        const file = try std.fs.cwd().createFile("/tmp/test_raw_list/normal.txt", .{});
        defer file.close();
    }

    const entries = try listRawFilenames(allocator, test_dir);
    defer {
        for (entries) |entry| {
            allocator.free(entry);
        }
        allocator.free(entries);
    }

    try std.testing.expect(entries.len > 0);
}

test "open raw path" {
    const test_path = "/tmp/test_raw_open.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
    }

    // Open using raw path
    const file = try openRawPath(test_path);
    defer file.close();

    const stat = try file.stat();
    try std.testing.expect(stat.kind == .file);
}

test "paths equal" {
    try std.testing.expect(pathsEqual("/tmp/test", "/tmp/test"));
    try std.testing.expect(!pathsEqual("/tmp/test", "/tmp/Test"));
    try std.testing.expect(!pathsEqual("/tmp/test", "/tmp/test2"));
}

test "path starts with" {
    try std.testing.expect(pathStartsWith("/tmp/test/file.txt", "/tmp/test"));
    try std.testing.expect(pathStartsWith("/tmp/test", "/tmp"));
    try std.testing.expect(!pathStartsWith("/tmp/test", "/var"));
}

test "valid UTF-8 path" {
    try std.testing.expect(isValidUtf8Path("/tmp/test.txt"));
    try std.testing.expect(isValidUtf8Path("/tmp/テスト.txt"));

    // Invalid UTF-8
    const invalid = [_]u8{ '/', 't', 'm', 'p', '/', 0xFF, 0xFE };
    try std.testing.expect(!isValidUtf8Path(&invalid));
}
// ANCHOR_END: raw_byte_handling

// ANCHOR: sanitize_paths
test "sanitize path" {
    const allocator = std.testing.allocator;

    // Valid UTF-8
    const valid = try sanitizePath(allocator, "/tmp/test.txt");
    defer allocator.free(valid);
    try std.testing.expectEqualStrings("/tmp/test.txt", valid);

    // Invalid UTF-8 - contains replacement character
    const invalid = [_]u8{ '/', 't', 'm', 'p', '/', 0xFF };
    const sanitized = try sanitizePath(allocator, &invalid);
    defer allocator.free(sanitized);
    try std.testing.expect(sanitized.len > 5);
}

test "list with encoding" {
    const allocator = std.testing.allocator;

    const test_dir = "/tmp/test_encoding";
    try std.fs.cwd().makeDir(test_dir);
    defer std.fs.cwd().deleteTree(test_dir) catch {};

    // Create test files
    {
        const file1 = try std.fs.cwd().createFile("/tmp/test_encoding/normal.txt", .{});
        defer file1.close();
        const file2 = try std.fs.cwd().createFile("/tmp/test_encoding/test2.txt", .{});
        defer file2.close();
    }

    const entries = try listWithEncoding(allocator, test_dir);
    defer {
        for (entries) |*entry| {
            var mut_entry = entry;
            mut_entry.deinit(allocator);
        }
        allocator.free(entries);
    }

    try std.testing.expect(entries.len > 0);
    for (entries) |entry| {
        try std.testing.expect(entry.is_valid_utf8);
    }
}

test "create file raw" {
    const dir_path = "/tmp/test_raw_create";
    try std.fs.cwd().makeDir(dir_path);
    defer std.fs.cwd().deleteTree(dir_path) catch {};

    const filename = "test.txt";
    const file = try createFileRaw(dir_path, filename);
    file.close();

    // Verify file exists
    var dir = try std.fs.cwd().openDir(dir_path, .{});
    defer dir.close();

    const stat = try dir.statFile(filename);
    try std.testing.expect(stat.kind == .file);
}
// ANCHOR_END: sanitize_paths

// ANCHOR: path_normalization
test "normalize path" {
    const allocator = std.testing.allocator;

    const result1 = try normalizePath(allocator, "/tmp/./test/../file.txt");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("/tmp/file.txt", result1);

    const result2 = try normalizePath(allocator, "/tmp//test/./file.txt");
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("/tmp/test/file.txt", result2);

    const result3 = try normalizePath(allocator, "/tmp/test/..");
    defer allocator.free(result3);
    try std.testing.expectEqualStrings("/tmp", result3);

    const result4 = try normalizePath(allocator, "/");
    defer allocator.free(result4);
    try std.testing.expectEqualStrings("/", result4);
}

test "escape path normal" {
    const allocator = std.testing.allocator;

    const normal = try escapePath(allocator, "/tmp/test.txt");
    defer allocator.free(normal);
    try std.testing.expectEqualStrings("/tmp/test.txt", normal);
}

test "escape path with special chars" {
    const allocator = std.testing.allocator;

    const with_newline = try escapePath(allocator, "/tmp/test\nfile.txt");
    defer allocator.free(with_newline);
    try std.testing.expect(std.mem.indexOf(u8, with_newline, "\\x0A") != null);

    const with_tab = try escapePath(allocator, "/tmp/test\tfile.txt");
    defer allocator.free(with_tab);
    try std.testing.expect(std.mem.indexOf(u8, with_tab, "\\x09") != null);
}

test "safe open raw - not found" {
    const result = safeOpenRaw("/tmp/does_not_exist_12345.txt");
    try std.testing.expectError(error.PathNotFound, result);
}

test "safe open raw - success" {
    const test_path = "/tmp/test_safe_open.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
    }

    // Open safely
    const file = try safeOpenRaw(test_path);
    defer file.close();

    const stat = try file.stat();
    try std.testing.expect(stat.kind == .file);
}

test "empty path handling" {
    const allocator = std.testing.allocator;

    const result = try normalizePath(allocator, "");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("/", result);

    try std.testing.expect(pathsEqual("", ""));
    // Empty prefix matches any string
    try std.testing.expect(pathStartsWith("/tmp", ""));
}

test "path with only dots" {
    const allocator = std.testing.allocator;

    const result1 = try normalizePath(allocator, "/././.");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("/", result1);

    const result2 = try normalizePath(allocator, "/tmp/./././");
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("/tmp", result2);
}
// ANCHOR_END: path_normalization
