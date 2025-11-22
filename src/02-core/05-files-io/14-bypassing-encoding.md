## Problem

You need to work with filenames that may contain invalid UTF-8 sequences or operate at the raw OS path level without encoding assumptions.

## Solution

### Raw Byte Handling

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_14.zig:raw_byte_handling}}
```

### Sanitize Paths

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_14.zig:sanitize_paths}}
```

### Path Normalization

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_14.zig:path_normalization}}
```

## Discussion

### Understanding Zig Path Handling

Zig treats paths as byte slices without encoding assumptions:

```zig
// Paths are just []const u8 - no UTF-8 requirement
pub fn openRawPath(path: []const u8) !std.fs.File {
    // Direct byte-level access, no validation
    return std.fs.cwd().openFile(path, .{});
}
```

This differs from languages that require UTF-8 validation for strings.

### Working with OS-Native Paths

Access platform-specific path representations:

```zig
pub fn getOSPath(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const builtin = @import("builtin");

    if (builtin.os.tag == .windows) {
        // Windows uses UTF-16
        const wide_len = try std.os.windows.sliceToPrefixedFileW(null, path);
        var wide_path = try allocator.alloc(u16, wide_len);
        errdefer allocator.free(wide_path);

        _ = try std.os.windows.sliceToPrefixedFileW(wide_path, path);
        return std.mem.sliceAsBytes(wide_path);
    } else {
        // Unix uses raw bytes
        return allocator.dupe(u8, path);
    }
}
```

### Comparing Byte-Level Paths

Compare paths without encoding concerns:

```zig
pub fn pathsEqual(path1: []const u8, path2: []const u8) bool {
    // Direct byte comparison
    return std.mem.eql(u8, path1, path2);
}

pub fn pathStartsWith(path: []const u8, prefix: []const u8) bool {
    return std.mem.startsWith(u8, path, prefix);
}

test "path comparison" {
    try std.testing.expect(pathsEqual("/tmp/test", "/tmp/test"));
    try std.testing.expect(!pathsEqual("/tmp/test", "/tmp/Test"));

    try std.testing.expect(pathStartsWith("/tmp/test/file.txt", "/tmp/test"));
}
```

### Handling Invalid UTF-8

Detect and handle potentially invalid UTF-8 in filenames:

```zig
pub fn isValidUtf8Path(path: []const u8) bool {
    return std.unicode.utf8ValidateSlice(path);
}

pub fn sanitizePath(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    if (std.unicode.utf8ValidateSlice(path)) {
        return allocator.dupe(u8, path);
    }

    // Replace invalid sequences with replacement character
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

test "invalid UTF-8 detection" {
    try std.testing.expect(isValidUtf8Path("/tmp/test.txt"));

    // Invalid UTF-8 byte sequence
    const invalid = [_]u8{ '/'.try std.testing.expect(!isValidUtf8Path(&invalid));
}
```

### Converting Between Encodings

Handle path encoding conversions:

```zig
pub fn pathToUtf8(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const builtin = @import("builtin");

    if (builtin.os.tag == .windows) {
        // Assume input is UTF-16 on Windows
        const wide_path = std.mem.bytesAsSlice(u16, path);
        return std.unicode.utf16LeToUtf8Alloc(allocator, wide_path);
    } else {
        // Unix paths are already bytes
        return allocator.dupe(u8, path);
    }
}
```

### Reading Directory with Encoding Issues

Handle directories that may contain problematic filenames:

```zig
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
```

### Creating Files with Raw Names

Create files using raw byte sequences:

```zig
pub fn createFileRaw(dir_path: []const u8, filename: []const u8) !std.fs.File {
    var dir = try std.fs.cwd().openDir(dir_path, .{});
    defer dir.close();

    // No encoding validation - direct byte-level operation
    return dir.createFile(filename, .{});
}

test "create file raw" {
    const dir_path = "/tmp/test_raw_create";
    try std.fs.cwd().makeDir(dir_path);
    defer std.fs.cwd().deleteTree(dir_path) catch {};

    const filename = "test.txt";
    const file = try createFileRaw(dir_path, filename);
    file.close();

    // Verify file exists using raw bytes
    var dir = try std.fs.cwd().openDir(dir_path, .{});
    defer dir.close();

    const stat = try dir.statFile(filename);
    try std.testing.expect(stat.kind == .file);
}
```

### Path Normalization

Normalize paths while preserving raw bytes:

```zig
pub fn normalizePath(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    // Resolve relative components without encoding assumptions
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

    // Rebuild path
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

test "normalize path" {
    const allocator = std.testing.allocator;

    const result1 = try normalizePath(allocator, "/tmp/./test/../file.txt");
    defer allocator.free(result1);
    try std.testing.expectEqualStrings("/tmp/file.txt", result1);

    const result2 = try normalizePath(allocator, "/tmp//test/./file.txt");
    defer allocator.free(result2);
    try std.testing.expectEqualStrings("/tmp/test/file.txt", result2);
}
```

### Hexadecimal Escaping

Display problematic filenames using hex escaping:

```zig
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

test "escape path" {
    const allocator = std.testing.allocator;

    const normal = try escapePath(allocator, "/tmp/test.txt");
    defer allocator.free(normal);
    try std.testing.expectEqualStrings("/tmp/test.txt", normal);

    const with_newline = try escapePath(allocator, "/tmp/test\nfile.txt");
    defer allocator.free(with_newline);
    try std.testing.expect(std.mem.indexOf(u8, with_newline, "\\x0A") != null);
}
```

### Platform Differences

**Unix/Linux:**
- Paths are arbitrary byte sequences
- Only `/` and NUL are special
- No encoding requirements
- Case-sensitive

**Windows:**
- Native APIs use UTF-16
- Zig converts to/from UTF-8
- Path separators: `\` and `/`
- Case-insensitive (usually)
- Additional restrictions (reserved names, etc.)

**Cross-platform handling:**
```zig
pub fn openFileAnyEncoding(path: []const u8) !std.fs.File {
    const builtin = @import("builtin");

    if (builtin.os.tag == .windows) {
        // Windows path handling with UTF-16 conversion
        return std.fs.cwd().openFile(path, .{});
    } else {
        // Unix direct byte access
        return std.fs.cwd().openFile(path, .{});
    }
}
```

### Best Practices

**Working with raw paths:**
- Store paths as `[]const u8` without assumptions
- Validate UTF-8 only when needed for display
- Use byte-level comparison for path matching
- Handle platform differences explicitly

**Error handling:**
```zig
pub fn safeOpenRaw(path: []const u8) !std.fs.File {
    return std.fs.cwd().openFile(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return error.PathNotFound,
        error.InvalidUtf8 => return error.EncodingError,
        else => return err,
    };
}
```

### Related Functions

- `std.unicode.utf8ValidateSlice()` - Validate UTF-8
- `std.unicode.utf8ByteSequenceLength()` - Get UTF-8 byte length
- `std.unicode.utf16LeToUtf8Alloc()` - Convert UTF-16 to UTF-8
- `std.mem.eql()` - Byte-level comparison
- `std.fs.path` - Path manipulation utilities
- `std.os.windows.sliceToPrefixedFileW()` - Windows UTF-16 conversion
