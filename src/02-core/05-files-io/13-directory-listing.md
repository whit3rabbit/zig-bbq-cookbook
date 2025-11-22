## Problem

You need to list files and directories, optionally filtering by type or pattern, and sometimes recursively traversing subdirectories.

## Solution

### Basic Listing

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_13.zig:basic_listing}}
```

### Filtered Listing

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_13.zig:filtered_listing}}
```

### Advanced Listing

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_13.zig:advanced_listing}}
```

## Discussion

### Basic Directory Iteration

The simplest way to list directory contents:

```zig
pub fn printDirectory(path: []const u8) !void {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        std.debug.print("{s}\n", .{entry.name});
    }
}
```

### Filtering by File Type

Separate files from directories:

```zig
pub const DirContents = struct {
    files: [][]const u8,
    directories: [][]const u8,

    pub fn deinit(self: *DirContents, allocator: std.mem.Allocator) void {
        for (self.files) |file| {
            allocator.free(file);
        }
        allocator.free(self.files);

        for (self.directories) |dir| {
            allocator.free(dir);
        }
        allocator.free(self.directories);
    }
};

pub fn listByType(allocator: std.mem.Allocator, path: []const u8) !DirContents {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var files = std.ArrayList([]const u8).init(allocator);
    errdefer files.deinit();

    var directories = std.ArrayList([]const u8).init(allocator);
    errdefer directories.deinit();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        const name = try allocator.dupe(u8, entry.name);
        errdefer allocator.free(name);

        switch (entry.kind) {
            .file => try files.append(name),
            .directory => try directories.append(name),
            else => allocator.free(name), // Skip other types
        }
    }

    return DirContents{
        .files = try files.toOwnedSlice(),
        .directories = try directories.toOwnedSlice(),
    };
}
```

### Filtering by Extension

List only files with specific extension:

```zig
pub fn listByExtension(
    allocator: std.mem.Allocator,
    path: []const u8,
    ext: []const u8,
) ![][]const u8 {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var entries = std.ArrayList([]const u8).init(allocator);
    errdefer entries.deinit();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;

        const file_ext = std.fs.path.extension(entry.name);
        if (std.mem.eql(u8, file_ext, ext)) {
            const name = try allocator.dupe(u8, entry.name);
            try entries.append(name);
        }
    }

    return entries.toOwnedSlice();
}
```

### Recursive Directory Walking

Walk entire directory tree:

```zig
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

        try results.append(full_path);

        if (entry.kind == .directory) {
            try walkDirectory(allocator, full_path, results);
        }
    }
}

pub fn listRecursive(allocator: std.mem.Allocator, path: []const u8) ![][]const u8 {
    var results = std.ArrayList([]const u8).init(allocator);
    errdefer results.deinit();

    try walkDirectory(allocator, path, &results);

    return results.toOwnedSlice();
}
```

### Sorting Directory Entries

Sort entries alphabetically:

```zig
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
```

### Getting File Information

Include size and modification time:

```zig
pub const FileInfo = struct {
    name: []const u8,
    size: u64,
    is_dir: bool,
    mtime: i128,

    pub fn deinit(self: *FileInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }
};

pub fn listWithInfo(allocator: std.mem.Allocator, path: []const u8) ![]FileInfo {
    var dir = try std.fs.cwd().openDir(path, .{});
    defer dir.close();

    var entries = std.ArrayList(FileInfo).init(allocator);
    errdefer entries.deinit();

    var iter = try dir.iterate();
    while (try iter.next()) |entry| {
        const stat = dir.statFile(entry.name) catch continue;

        try entries.append(.{
            .name = try allocator.dupe(u8, entry.name),
            .size = stat.size,
            .is_dir = entry.kind == .directory,
            .mtime = stat.mtime,
        });
    }

    return entries.toOwnedSlice();
}
```

### Pattern Matching

Filter using wildcard patterns:

```zig
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

pub fn listByPattern(
    allocator: std.mem.Allocator,
    path: []const u8,
    pattern: []const u8,
) ![][]const u8 {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var entries = std.ArrayList([]const u8).init(allocator);
    errdefer entries.deinit();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (matchesPattern(entry.name, pattern)) {
            const name = try allocator.dupe(u8, entry.name);
            try entries.append(name);
        }
    }

    return entries.toOwnedSlice();
}
```

### Hidden Files

Handle hidden files (Unix-style):

```zig
pub fn isHidden(name: []const u8) bool {
    return name.len > 0 and name[0] == '.';
}

pub fn listVisible(allocator: std.mem.Allocator, path: []const u8) ![][]const u8 {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var entries = std.ArrayList([]const u8).init(allocator);
    errdefer entries.deinit();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (!isHidden(entry.name)) {
            const name = try allocator.dupe(u8, entry.name);
            try entries.append(name);
        }
    }

    return entries.toOwnedSlice();
}
```

### Limiting Results

Limit number of entries returned:

```zig
pub fn listN(allocator: std.mem.Allocator, path: []const u8, max_count: usize) ![][]const u8 {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    defer dir.close();

    var entries = std.ArrayList([]const u8).init(allocator);
    errdefer entries.deinit();

    var iter = dir.iterate();
    var count: usize = 0;
    while (try iter.next()) |entry| {
        if (count >= max_count) break;

        const name = try allocator.dupe(u8, entry.name);
        try entries.append(name);
        count += 1;
    }

    return entries.toOwnedSlice();
}
```

### Error Handling

Handle common directory errors:

```zig
pub fn safeListing(allocator: std.mem.Allocator, path: []const u8) ![][]const u8 {
    var dir = std.fs.cwd().openDir(path, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return error.DirectoryNotFound,
        error.NotDir => return error.NotADirectory,
        error.AccessDenied => return error.PermissionDenied,
        else => return err,
    };
    defer dir.close();

    var entries = std.ArrayList([]const u8).init(allocator);
    errdefer entries.deinit();

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        const name = try allocator.dupe(u8, entry.name);
        try entries.append(name);
    }

    return entries.toOwnedSlice();
}
```

### Performance Considerations

**Iterator vs. Reading All:**
- `iterate()` is memory-efficient for large directories
- Process entries one at a time
- Can stop early if needed

**Caching:**
```zig
// Cache directory listing
var cached_entries: ?[][]const u8 = null;

pub fn getCachedListing(allocator: std.mem.Allocator, path: []const u8) ![][]const u8 {
    if (cached_entries) |entries| {
        return entries;
    }

    cached_entries = try listDirectory(allocator, path);
    return cached_entries.?;
}
```

### Platform Differences

**Entry ordering:**
- Order is filesystem-dependent
- Not guaranteed to be alphabetical
- Sort explicitly if order matters

**Hidden files:**
- Unix: Start with `.`
- Windows: Have hidden attribute
- Use platform-specific checks for full support

### Related Functions

- `std.fs.Dir.iterate()` - Iterate directory entries
- `std.fs.Dir.walk()` - Recursive directory walker
- `std.fs.Dir.statFile()` - Get file metadata
- `std.fs.path.extension()` - Get file extension
- `std.fs.path.basename()` - Get filename without path
- `std.mem.sort()` - Sort entries
