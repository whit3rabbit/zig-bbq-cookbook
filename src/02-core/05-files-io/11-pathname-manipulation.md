## Problem

You need to manipulate file paths in a cross-platform way, handling different path separators and path formats across operating systems.

## Solution

### Basic Manipulation

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_11.zig:basic_manipulation}}
```

### Normalize Paths

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_11.zig:normalize_paths}}
```

### Safe Join

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_11.zig:safe_join}}
```

## Discussion

### Path Separators

Different operating systems use different path separators:
- **Unix/Linux/macOS**: `/` (forward slash)
- **Windows**: `\` (backslash)

Zig's `std.fs.path` handles this automatically:

```zig
// Current platform's separator
const sep = std.fs.path.sep;

test "path separator" {
    if (@import("builtin").os.tag == .windows) {
        try std.testing.expectEqual(@as(u8, '\\'), std.fs.path.sep);
    } else {
        try std.testing.expectEqual(@as(u8, '/'), std.fs.path.sep);
    }
}
```

### Joining Paths

Combine path components with the correct separator:

```zig
pub fn joinPaths(allocator: std.mem.Allocator, components: []const []const u8) ![]u8 {
    return try std.fs.path.join(allocator, components);
}

test "join paths" {
    const allocator = std.testing.allocator;

    const path = try std.fs.path.join(allocator, &.{ "usr", "local", "bin" });
    defer allocator.free(path);

    // On Unix: "usr/local/bin"
    // On Windows: "usr\local\bin"
    try std.testing.expect(path.len > 0);
}
```

### Getting Basename

Extract the final component of a path:

```zig
pub fn getBasename(path: []const u8) []const u8 {
    return std.fs.path.basename(path);
}

test "basename" {
    try std.testing.expectEqualStrings("file.txt", std.fs.path.basename("/home/user/file.txt"));
    try std.testing.expectEqualStrings("file.txt", std.fs.path.basename("file.txt"));
    try std.testing.expectEqualStrings("user", std.fs.path.basename("/home/user/"));
}
```

### Getting Directory Name

Get the directory portion of a path:

```zig
pub fn getDirname(path: []const u8) ?[]const u8 {
    return std.fs.path.dirname(path);
}

test "dirname" {
    try std.testing.expectEqualStrings("/home/user", std.fs.path.dirname("/home/user/file.txt").?);
    try std.testing.expectEqualStrings("/home", std.fs.path.dirname("/home/user/").?);
    try std.testing.expect(std.fs.path.dirname("file.txt") == null);
}
```

### Getting File Extension

Extract the file extension:

```zig
pub fn getExtension(path: []const u8) []const u8 {
    return std.fs.path.extension(path);
}

test "extension" {
    try std.testing.expectEqualStrings(".txt", std.fs.path.extension("file.txt"));
    try std.testing.expectEqualStrings(".tar.gz", std.fs.path.extension("archive.tar.gz"));
    try std.testing.expectEqualStrings("", std.fs.path.extension("noext"));
    try std.testing.expectEqualStrings("", std.fs.path.extension(".hidden"));
}
```

### Getting Stem (Name Without Extension)

Get filename without extension:

```zig
pub fn getStem(path: []const u8) []const u8 {
    return std.fs.path.stem(path);
}

test "stem" {
    try std.testing.expectEqualStrings("file", std.fs.path.stem("file.txt"));
    try std.testing.expectEqualStrings("archive.tar", std.fs.path.stem("archive.tar.gz"));
    try std.testing.expectEqualStrings("noext", std.fs.path.stem("noext"));
}
```

### Resolving Paths

Join and normalize paths:

```zig
pub fn resolvePath(allocator: std.mem.Allocator, components: []const []const u8) ![]u8 {
    const joined = try std.fs.path.join(allocator, components);
    errdefer allocator.free(joined);

    // Resolve removes redundant separators and dots
    return try std.fs.path.resolve(allocator, &.{joined});
}

test "resolve path" {
    const allocator = std.testing.allocator;

    const path = try std.fs.path.resolve(allocator, &.{ "a/b", "../c" });
    defer allocator.free(path);

    // Normalizes path components
    try std.testing.expect(path.len > 0);
}
```

### Checking if Path is Absolute

Determine if path is absolute or relative:

```zig
pub fn isAbsolutePath(path: []const u8) bool {
    return std.fs.path.isAbsolute(path);
}

test "is absolute" {
    try std.testing.expect(std.fs.path.isAbsolute("/home/user"));
    try std.testing.expect(!std.fs.path.isAbsolute("relative/path"));

    if (@import("builtin").os.tag == .windows) {
        try std.testing.expect(std.fs.path.isAbsolute("C:\\Users"));
    }
}
```

### Relative Paths

Compute relative path from one to another:

```zig
pub fn relativePath(allocator: std.mem.Allocator, from: []const u8, to: []const u8) ![]u8 {
    return try std.fs.path.relative(allocator, from, to);
}

test "relative path" {
    const allocator = std.testing.allocator;

    const rel = try std.fs.path.relative(allocator, "/home/user", "/home/user/docs/file.txt");
    defer allocator.free(rel);

    try std.testing.expectEqualStrings("docs/file.txt", rel);
}
```

### Splitting Paths

Split path into components:

```zig
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

test "split path" {
    const allocator = std.testing.allocator;

    const components = try splitPath(allocator, "home/user/file.txt");
    defer allocator.free(components);

    try std.testing.expectEqual(@as(usize, 3), components.len);
    try std.testing.expectEqualStrings("home", components[0]);
    try std.testing.expectEqualStrings("user", components[1]);
    try std.testing.expectEqualStrings("file.txt", components[2]);
}
```

### Normalizing Paths

Clean up redundant separators and resolve dots:

```zig
pub fn normalizePath(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    // Remove redundant separators and resolve . and ..
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

test "normalize path" {
    const allocator = std.testing.allocator;

    const normalized = try normalizePath(allocator, "a/./b/../c");
    defer allocator.free(normalized);

    try std.testing.expectEqualStrings("a/c", normalized);
}
```

### Converting Windows/Unix Paths

Convert between path formats:

```zig
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
```

### Path Iterator

Iterate over path components:

```zig
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

test "path iterator" {
    var iter = PathIterator.init("home/user/file.txt");

    try std.testing.expectEqualStrings("home", iter.next().?);
    try std.testing.expectEqualStrings("user", iter.next().?);
    try std.testing.expectEqualStrings("file.txt", iter.next().?);
    try std.testing.expect(iter.next() == null);
}
```

### Finding Common Path Prefix

Find shared prefix of multiple paths:

```zig
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
```

### Safe Path Joining

Prevent path traversal attacks:

```zig
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

test "safe join" {
    const allocator = std.testing.allocator;

    // Valid join
    const valid = try safeJoin(allocator, "/base", "sub/file.txt");
    defer allocator.free(valid);

    // Invalid joins
    try std.testing.expectError(error.ParentDirectoryNotAllowed, safeJoin(allocator, "/base", "../etc"));
    try std.testing.expectError(error.AbsolutePathNotAllowed, safeJoin(allocator, "/base", "/etc/passwd"));
}
```

### Platform-Specific Paths

Handle platform-specific path formats:

```zig
pub fn getPlatformPath(allocator: std.mem.Allocator, generic: []const u8) ![]u8 {
    const builtin = @import("builtin");

    if (builtin.os.tag == .windows) {
        // Convert to Windows path
        return try convertToWindowsPath(allocator, generic);
    } else {
        // Unix path (no conversion needed)
        return try allocator.dupe(u8, generic);
    }
}
```

### Performance Tips

**Path operations:**
- `basename`, `dirname`, `extension` are zero-allocation (return slices)
- `join`, `resolve`, `relative` allocate new strings
- Cache results if used repeatedly

**Best practices:**
```zig
// Good: Single allocation
const path = try std.fs.path.join(allocator, &.{ "a", "b", "c" });
defer allocator.free(path);

// Bad: Multiple allocations
const temp1 = try std.fs.path.join(allocator, &.{ "a", "b" });
defer allocator.free(temp1);
const temp2 = try std.fs.path.join(allocator, &.{ temp1, "c" });
defer allocator.free(temp2);
```

### Related Functions

- `std.fs.path.join()` - Join path components
- `std.fs.path.basename()` - Get final path component
- `std.fs.path.dirname()` - Get directory portion
- `std.fs.path.extension()` - Get file extension
- `std.fs.path.stem()` - Get name without extension
- `std.fs.path.isAbsolute()` - Check if path is absolute
- `std.fs.path.relative()` - Compute relative path
- `std.fs.path.resolve()` - Resolve and normalize path
- `std.fs.path.sep` - Platform path separator
