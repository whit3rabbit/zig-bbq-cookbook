## Problem

You need to check if a file or directory exists before performing operations on it.

## Solution

### Basic Existence

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_12.zig:basic_existence}}
```

### File Metadata

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_12.zig:file_metadata}}
```

### Multiple Paths

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_12.zig:multiple_paths}}
```

## Discussion

### Basic Existence Check

The simplest way to check if a path exists:

```zig
pub fn pathExists(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}
```

This works for both files and directories. It only checks if the path exists, not whether you have permission to read or write it.

### Checking File vs Directory

Distinguish between files and directories:

```zig
pub fn isFile(path: []const u8) bool {
    const stat = std.fs.cwd().statFile(path) catch return false;
    return stat.kind == .file;
}

pub fn isDirectory(path: []const u8) bool {
    const stat = std.fs.cwd().statFile(path) catch return false;
    return stat.kind == .directory;
}

test "file vs directory" {
    // File check
    {
        const file = try std.fs.cwd().createFile("/tmp/test_file.txt", .{});
        defer file.close();
    }
    defer std.fs.cwd().deleteFile("/tmp/test_file.txt") catch {};

    try std.testing.expect(isFile("/tmp/test_file.txt"));
    try std.testing.expect(!isDirectory("/tmp/test_file.txt"));

    // Directory check
    try std.fs.cwd().makeDir("/tmp/test_dir");
    defer std.fs.cwd().deleteDir("/tmp/test_dir") catch {};

    try std.testing.expect(isDirectory("/tmp/test_dir"));
    try std.testing.expect(!isFile("/tmp/test_dir"));
}
```

### Checking with Permissions

Verify you can actually access the file:

```zig
pub fn canRead(path: []const u8) bool {
    std.fs.cwd().access(path, .{ .mode = .read_only }) catch return false;
    return true;
}

pub fn canWrite(path: []const u8) bool {
    // Try opening for writing
    const file = std.fs.cwd().openFile(path, .{ .mode = .write_only }) catch return false;
    file.close();
    return true;
}

pub fn canExecute(path: []const u8) bool {
    // Platform-specific executable check
    const stat = std.fs.cwd().statFile(path) catch return false;

    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        // On Windows, check extension
        const ext = std.fs.path.extension(path);
        return std.mem.eql(u8, ext, ".exe") or
               std.mem.eql(u8, ext, ".bat") or
               std.mem.eql(u8, ext, ".cmd");
    } else {
        // On Unix, check file mode
        return (stat.mode & 0o111) != 0;
    }
}
```

### Getting File Type

Determine the type of filesystem object:

```zig
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
```

### Checking File Age

Check when a file was last modified:

```zig
pub fn isNewerThan(path1: []const u8, path2: []const u8) !bool {
    const stat1 = try std.fs.cwd().statFile(path1);
    const stat2 = try std.fs.cwd().statFile(path2);

    return stat1.mtime > stat2.mtime;
}

pub fn isOlderThan(path: []const u8, seconds: i128) !bool {
    const stat = try std.fs.cwd().statFile(path);
    const now = std.time.nanoTimestamp();
    const age = now - stat.mtime;

    return age > (seconds * std.time.ns_per_s);
}

test "file age" {
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
    std.time.sleep(10 * std.time.ns_per_ms);

    // Create second file
    {
        const file = try std.fs.cwd().createFile(path2, .{});
        defer file.close();
    }

    // path2 is newer than path1
    try std.testing.expect(try isNewerThan(path2, path1));
}
```

### Waiting for File Creation

Wait for a file to be created:

```zig
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

        std.time.sleep(100 * std.time.ns_per_ms);
    }
}

test "wait for file" {
    const path = "/tmp/test_wait.txt";
    defer std.fs.cwd().deleteFile(path) catch {};

    // Start a background task to create the file
    const thread = try std.Thread.spawn(.{}, struct {
        fn create(file_path: []const u8) void {
            std.time.sleep(200 * std.time.ns_per_ms);
            const file = std.fs.cwd().createFile(file_path, .{}) catch return;
            file.close();
        }
    }.create, .{path});
    thread.detach();

    // Wait for file creation
    try waitForFile(path, 5000);
    try std.testing.expect(pathExists(path));
}
```

### Checking Symlinks

Work with symbolic links:

```zig
pub fn isSymlink(path: []const u8) bool {
    // Use lstat to not follow symlinks
    var buffer: [std.fs.max_path_bytes]u8 = undefined;
    const absolute = std.fs.cwd().realpath(path, &buffer) catch return false;

    const stat = std.fs.cwd().statFile(absolute) catch return false;
    return stat.kind == .sym_link;
}

pub fn symlinkTarget(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var buffer: [std.fs.max_path_bytes]u8 = undefined;
    const target = try std.posix.readlink(path, &buffer);
    return try allocator.dupe(u8, target);
}
```

### Safe Existence Check

Handle all error cases explicitly:

```zig
pub fn safeExists(path: []const u8) !bool {
    std.fs.cwd().access(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return false,
        error.AccessDenied => return error.PermissionDenied,
        else => return err,
    };
    return true;
}
```

### Checking Multiple Files

Check if multiple files exist:

```zig
pub fn allExist(paths: []const []const u8) bool {
    for (paths) |path| {
        if (!pathExists(path)) {
            return false;
        }
    }
    return true;
}

pub fn anyExists(paths: []const []const u8) bool {
    for (paths) |path| {
        if (pathExists(path)) {
            return true;
        }
    }
    return false;
}

test "multiple files" {
    const path1 = "/tmp/test_multi1.txt";
    const path2 = "/tmp/test_multi2.txt";

    defer std.fs.cwd().deleteFile(path1) catch {};
    defer std.fs.cwd().deleteFile(path2) catch {};

    // Create one file
    {
        const file = try std.fs.cwd().createFile(path1, .{});
        defer file.close();
    }

    const paths = [_][]const u8{ path1, path2 };

    try std.testing.expect(!allExist(&paths));
    try std.testing.expect(anyExists(&paths));
}
```

### Finding First Existing File

Find the first file that exists from a list:

```zig
pub fn findFirstExisting(paths: []const []const u8) ?[]const u8 {
    for (paths) |path| {
        if (pathExists(path)) {
            return path;
        }
    }
    return null;
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
```

### Checking Parent Directory

Verify parent directory exists before creating file:

```zig
pub fn parentDirExists(path: []const u8) bool {
    const dir = std.fs.path.dirname(path) orelse return true;
    return isDirectory(dir);
}

pub fn ensureParentDir(path: []const u8) !void {
    const dir = std.fs.path.dirname(path) orelse return;

    std.fs.cwd().makePath(dir) catch |err| switch (err) {
        error.PathAlreadyExists => return,
        else => return err,
    };
}
```

### Performance Considerations

**Existence checks:**
- `access()` is fastest (doesn't return file info)
- `statFile()` slower but gives file metadata
- Cache results if checking repeatedly

**Best practices:**
```zig
// Good: Check then open
if (fileExists(path)) {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    // ...
}

// Better: Just try to open (EAFP style)
const file = std.fs.cwd().openFile(path, .{}) catch |err| switch (err) {
    error.FileNotFound => {
        // Handle missing file
        return;
    },
    else => return err,
};
defer file.close();
// File definitely exists here
```

**EAFP (Easier to Ask for Forgiveness than Permission):**
- More efficient (one system call instead of two)
- Handles race conditions better
- Preferred in Zig

### Platform Differences

**Windows:**
- Case-insensitive filesystem (usually)
- Different path separators
- Different file permissions model

**Unix/Linux:**
- Case-sensitive filesystem
- POSIX permissions (rwx)
- Special files (devices, sockets, pipes)

**Cross-platform code:**
```zig
pub fn exists(path: []const u8) bool {
    const builtin = @import("builtin");

    if (builtin.os.tag == .windows) {
        // Windows-specific checks if needed
        return pathExists(path);
    } else {
        // Unix checks
        return pathExists(path);
    }
}
```

### Related Functions

- `std.fs.Dir.access()` - Check if path exists
- `std.fs.Dir.statFile()` - Get file metadata
- `std.fs.Dir.openFile()` - Open file (fails if doesn't exist)
- `std.fs.Dir.makeDir()` - Create directory
- `std.fs.Dir.deleteFile()` - Delete file
- `std.posix.readlink()` - Read symlink target
- `std.fs.path.dirname()` - Get parent directory
