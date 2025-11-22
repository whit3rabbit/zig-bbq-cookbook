## Problem

You need to create temporary files or directories for testing or temporary storage that are automatically cleaned up and have unique names to avoid conflicts.

## Solution

### Basic Temp Files

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_17.zig:basic_temp_files}}
```

### Self Deleting

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_17.zig:self_deleting}}
```

### Cleanup Helpers

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_17.zig:cleanup_helpers}}
```

## Discussion

### Using Testing Temporary Directory

For unit tests, use `std.testing.tmpDir`:

```zig
pub fn createTestTempDir() !std.testing.TmpDir {
    return std.testing.tmpDir(.{});
}

test "temp dir for testing" {
    var tmp = try std.testing.tmpDir(.{});
    defer tmp.cleanup();

    // Create file in temp dir
    const file = try tmp.dir.createFile("test.txt", .{});
    defer file.close();

    try file.writeAll("Test data");

    // Read it back
    const content = try tmp.dir.readFileAlloc(std.testing.allocator, "test.txt", 1024);
    defer std.testing.allocator.free(content);

    try std.testing.expectEqualStrings("Test data", content);
}
```

### Creating Unique Temp Files

Generate unique filenames:

```zig
pub fn makeTempPath(allocator: std.mem.Allocator, dir: []const u8, prefix: []const u8) ![]u8 {
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const random = prng.random();

    var buf: [32]u8 = undefined;
    const random_part = std.fmt.bufPrint(&buf, "{x}", .{random.int(u64)}) catch unreachable;

    return std.fmt.allocPrint(allocator, "{s}/{s}_{s}", .{ dir, prefix, random_part });
}

test "unique temp paths" {
    const allocator = std.testing.allocator;

    const path1 = try makeTempPath(allocator, "/tmp", "test");
    defer allocator.free(path1);

    const path2 = try makeTempPath(allocator, "/tmp", "test");
    defer allocator.free(path2);

    // Paths should be different
    try std.testing.expect(!std.mem.eql(u8, path1, path2));
}
```

### Temporary Directories

Create temp directories:

```zig
pub fn createTempDir(allocator: std.mem.Allocator, prefix: []const u8) ![]u8 {
    const path = try makeTempPath(allocator, "/tmp", prefix);
    errdefer allocator.free(path);

    try std.fs.cwd().makeDir(path);

    return path;
}

pub fn removeTempDir(path: []const u8) !void {
    try std.fs.cwd().deleteTree(path);
}

test "temp directory" {
    const allocator = std.testing.allocator;

    const dir_path = try createTempDir(allocator, "testdir");
    defer allocator.free(dir_path);
    defer removeTempDir(dir_path) catch {};

    // Create file in temp dir
    var dir = try std.fs.cwd().openDir(dir_path, .{});
    defer dir.close();

    const file = try dir.createFile("test.txt", .{});
    defer file.close();

    try file.writeAll("In temp dir");
}
```

### Self-Deleting Temp File

File that deletes itself on close:

```zig
pub const SelfDeletingFile = struct {
    file: std.fs.File,
    path: []const u8,
    allocator: std.mem.Allocator,

    pub fn create(allocator: std.mem.Allocator, prefix: []const u8) !SelfDeletingFile {
        const temp = try createTempFile(allocator, prefix);
        return .{
            .file = temp.file,
            .path = temp.path,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SelfDeletingFile) void {
        self.file.close();
        std.fs.cwd().deleteFile(self.path) catch {};
        self.allocator.free(self.path);
    }

    pub fn writer(self: *SelfDeletingFile) std.fs.File.Writer {
        var buf: [4096]u8 = undefined;
        return self.file.writer(&buf);
    }
};

test "self-deleting file" {
    const allocator = std.testing.allocator;

    var temp = try SelfDeletingFile.create(allocator, "self_delete");
    defer temp.deinit();

    try temp.file.writeAll("Auto-deleted");

    // File exists now
    const stat = try std.fs.cwd().statFile(temp.path);
    try std.testing.expect(stat.kind == .file);
}
```

### Temporary File with Content

Create temp file with initial content:

```zig
pub fn createTempFileWithContent(
    allocator: std.mem.Allocator,
    prefix: []const u8,
    content: []const u8,
) !struct {
    file: std.fs.File,
    path: []const u8,
} {
    const temp = try createTempFile(allocator, prefix);
    errdefer {
        temp.file.close();
        allocator.free(temp.path);
        std.fs.cwd().deleteFile(temp.path) catch {};
    }

    try temp.file.writeAll(content);
    try temp.file.seekTo(0);

    return temp;
}

test "temp file with content" {
    const allocator = std.testing.allocator;

    const temp = try createTempFileWithContent(allocator, "content", "Initial content");
    defer temp.file.close();
    defer allocator.free(temp.path);
    defer std.fs.cwd().deleteFile(temp.path) catch {};

    var buffer: [20]u8 = undefined;
    const n = try temp.file.read(&buffer);

    try std.testing.expectEqualStrings("Initial content", buffer[0..n]);
}
```

### Named Temporary File

Create temp file that preserves extension:

```zig
pub fn createNamedTempFile(
    allocator: std.mem.Allocator,
    name: []const u8,
    extension: []const u8,
) !struct {
    file: std.fs.File,
    path: []const u8,
} {
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const random = prng.random();

    const path = try std.fmt.allocPrint(
        allocator,
        "/tmp/{s}_{x}.{s}",
        .{ name, random.int(u32), extension },
    );
    errdefer allocator.free(path);

    const file = try std.fs.cwd().createFile(path, .{ .read = true });

    return .{ .file = file, .path = path };
}

test "named temp file" {
    const allocator = std.testing.allocator;

    const temp = try createNamedTempFile(allocator, "myfile", "txt");
    defer temp.file.close();
    defer allocator.free(temp.path);
    defer std.fs.cwd().deleteFile(temp.path) catch {};

    try std.testing.expect(std.mem.endsWith(u8, temp.path, ".txt"));
}
```

### Atomic Temp File Creation

Safely create temp file that doesn't already exist:

```zig
pub fn createUniqueTempFile(
    allocator: std.mem.Allocator,
    prefix: []const u8,
    max_attempts: usize,
) !struct {
    file: std.fs.File,
    path: []const u8,
} {
    var attempts: usize = 0;
    while (attempts < max_attempts) : (attempts += 1) {
        const path = try makeTempPath(allocator, "/tmp", prefix);
        errdefer allocator.free(path);

        const file = std.fs.cwd().createFile(path, .{
            .read = true,
            .exclusive = true,
        }) catch |err| switch (err) {
            error.PathAlreadyExists => {
                allocator.free(path);
                continue;
            },
            else => return err,
        };

        return .{ .file = file, .path = path };
    }

    return error.TooManyAttempts;
}

test "unique temp file" {
    const allocator = std.testing.allocator;

    const temp = try createUniqueTempFile(allocator, "unique", 10);
    defer temp.file.close();
    defer allocator.free(temp.path);
    defer std.fs.cwd().deleteFile(temp.path) catch {};

    try temp.file.writeAll("Unique file");
}
```

### Temporary Directory Iterator

Iterate over temp dir contents:

```zig
pub fn iterateTempDir(tmp: *std.testing.TmpDir) !void {
    var iter = tmp.dir.iterate();
    while (try iter.next()) |entry| {
        std.debug.print("Entry: {s}\n", .{entry.name});
    }
}

test "iterate temp dir" {
    var tmp = try std.testing.tmpDir(.{});
    defer tmp.cleanup();

    // Create some files
    {
        const file1 = try tmp.dir.createFile("file1.txt", .{});
        defer file1.close();
        const file2 = try tmp.dir.createFile("file2.txt", .{});
        defer file2.close();
    }

    var count: usize = 0;
    var iter = tmp.dir.iterate();
    while (try iter.next()) |_| {
        count += 1;
    }

    try std.testing.expectEqual(@as(usize, 2), count);
}
```

### Cleanup Helpers

Safe cleanup of temp resources:

```zig
pub fn cleanupTempFile(path: []const u8, allocator: std.mem.Allocator) void {
    std.fs.cwd().deleteFile(path) catch {};
    allocator.free(path);
}

pub fn cleanupTempDir(path: []const u8, allocator: std.mem.Allocator) void {
    std.fs.cwd().deleteTree(path) catch {};
    allocator.free(path);
}
```

### Platform-Specific Temp Directories

Get platform temp directory:

```zig
pub fn getTempDir(allocator: std.mem.Allocator) ![]u8 {
    const builtin = @import("builtin");

    if (builtin.os.tag == .windows) {
        // Windows temp dir
        return std.process.getEnvVarOwned(allocator, "TEMP") catch |err| switch (err) {
            error.EnvironmentVariableNotFound => try allocator.dupe(u8, "C:\\Temp"),
            else => return err,
        };
    } else {
        // Unix temp dir
        return std.process.getEnvVarOwned(allocator, "TMPDIR") catch |err| switch (err) {
            error.EnvironmentVariableNotFound => try allocator.dupe(u8, "/tmp"),
            else => return err,
        };
    }
}

test "get temp dir" {
    const allocator = std.testing.allocator;

    const temp_dir = try getTempDir(allocator);
    defer allocator.free(temp_dir);

    try std.testing.expect(temp_dir.len > 0);
}
```

### Memory-Based Temporary Files

Use memory instead of disk (Linux):

```zig
pub fn createMemoryTempFile() !std.fs.File {
    const builtin = @import("builtin");
    if (builtin.os.tag == .linux) {
        const fd = try std.posix.memfd_create("memtemp", 0);
        return std.fs.File{ .handle = fd };
    } else {
        return error.NotSupported;
    }
}

test "memory temp file" {
    const builtin = @import("builtin");
    if (builtin.os.tag != .linux) return error.SkipZigTest;

    const file = try createMemoryTempFile();
    defer file.close();

    try file.writeAll("In memory");

    try file.seekTo(0);
    var buffer: [20]u8 = undefined;
    const n = try file.read(&buffer);

    try std.testing.expectEqualStrings("In memory", buffer[0..n]);
}
```

### Best Practices

**Temp file naming:**
- Include timestamp or random component
- Use descriptive prefixes
- Preserve extensions when needed
- Check for conflicts with `exclusive` flag

**Cleanup:**
```zig
// Always cleanup temp resources
var tmp = try std.testing.tmpDir(.{});
defer tmp.cleanup(); // Automatically removes directory and contents

// For manual temp files
const temp = try createTempFile(allocator, "prefix");
defer temp.file.close();
defer allocator.free(temp.path);
defer std.fs.cwd().deleteFile(temp.path) catch {}; // Ignore errors
```

**Security:**
- Use `exclusive` flag to prevent race conditions
- Set appropriate permissions
- Clean up on all error paths with `errdefer`
- Don't use predictable names

**Testing:**
- Use `std.testing.tmpDir` for tests
- Clean up in `defer` blocks
- Test cleanup failure paths

### Related Functions

- `std.testing.tmpDir()` - Create temporary test directory
- `std.testing.TmpDir.cleanup()` - Clean up temp directory
- `std.fs.cwd().createFile()` - Create file
- `std.fs.cwd().makeDir()` - Create directory
- `std.fs.cwd().deleteFile()` - Delete file
- `std.fs.cwd().deleteTree()` - Delete directory recursively
- `std.posix.memfd_create()` - Create memory-backed file (Linux)
- `std.process.getEnvVarOwned()` - Get environment variable
- `std.Random` - Generate random values
- `std.time.milliTimestamp()` - Get current timestamp
