# Recipe 13.7: Creating and Unpacking Archives

## Problem

You need to create archives of files and directories, and extract their contents.

## Solution

Create a simple archive format for bundling files:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_7.zig:archive_entry}}
```

## Discussion

Archives are essential for distributing software, backing up files, and transferring multiple files as a single unit. This recipe demonstrates a custom archive format for educational purposes.

### Creating Archives

The SimpleArchive struct provides basic archiving functionality:

**Adding files:**
```zig
var archive = SimpleArchive.init(allocator);
defer archive.deinit();

try archive.addFile("readme.txt", "This is the readme");
try archive.addFileFromDisk("config.json");

try archive.save("myfiles.archive");
```

**Loading archives:**
```zig
var archive = try SimpleArchive.load(allocator, "myfiles.archive");
defer archive.deinit();

// List contents
archive.list();
```

**Extracting archives:**
```zig
try archive.extract("output_directory");
```

### Archiving Directories

Archive entire directory trees recursively:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_7.zig:directory_archive}}
```

This recursively walks the directory structure and adds all files to the archive while preserving the directory hierarchy.

### Archive Utilities

Helper functions for working with archives:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_7.zig:archive_size}}
```

These utilities help inspect archive contents and retrieve specific files.

### Best Practices

1. **Validate paths** - Prevent directory traversal attacks
2. **Limit file sizes** - Avoid memory exhaustion
3. **Check available space** - Ensure extraction won't fill the disk
4. **Preserve permissions** - Keep file mode bits when possible
5. **Handle errors gracefully** - Some files may be unreadable
6. **Use standard formats** - tar, zip for production
7. **Compress large archives** - Save space with gzip/zstd

### Archive Format

The custom format used in this recipe:

```
[4 bytes] Number of entries (little-endian u32)
For each entry:
  [4 bytes] Name length (u32)
  [N bytes] Name (UTF-8)
  [4 bytes] Data length (u32)
  [M bytes] Data
```

This simple format is easy to understand but not suitable for production. Use standard formats like tar or zip for real applications.

### Production Formats

**TAR (Tape Archive):**
- Standard Unix archive format
- No built-in compression
- Preserves permissions and metadata
- Use with gzip (.tar.gz) or xz (.tar.xz)

**ZIP:**
- Cross-platform format
- Built-in compression
- Random access to entries
- Wide tool support

**Recommendation:** Use tar for Unix systems, zip for cross-platform compatibility. Zig's standard library may add support for these formats in the future.

### Common Patterns

**Selective extraction:**
```zig
fn extractFile(archive: *const SimpleArchive, name: []const u8, output_path: []const u8) !void {
    const entry = findEntry(archive, name) orelse return error.FileNotFound;
    try std.fs.cwd().writeFile(.{ .sub_path = output_path, .data = entry.data });
}
```

**Archive filtering:**
```zig
fn extractMatching(archive: *const SimpleArchive, pattern: []const u8, output_dir: []const u8) !void {
    for (archive.entries.items) |entry| {
        if (std.mem.indexOf(u8, entry.name, pattern)) |_| {
            const output_path = try std.fs.path.join(allocator, &.{ output_dir, entry.name });
            defer allocator.free(output_path);
            try std.fs.cwd().writeFile(.{ .sub_path = output_path, .data = entry.data });
        }
    }
}
```

**Progress reporting:**
```zig
fn archiveWithProgress(allocator: std.mem.Allocator, dir_path: []const u8, archive_path: []const u8) !void {
    var archive = SimpleArchive.init(allocator);
    defer archive.deinit();

    var file_count: usize = 0;
    // Add files and count
    try addDirectoryToArchive(allocator, &archive, dir_path, "");

    std.debug.print("Archiving {d} files...\n", .{archive.entries.items.len});

    try archive.save(archive_path);

    std.debug.print("Created archive: {s}\n", .{archive_path});
}
```

### Security Considerations

Path traversal vulnerabilities are a critical security concern when extracting archives. A malicious archive could contain entries with paths like `../../etc/passwd` that escape the intended extraction directory.

**The extract function includes built-in protection against path traversal attacks:**

1. Opens a directory handle for the output directory to constrain all operations
2. Rejects absolute paths that could write anywhere on the filesystem
3. Rejects paths containing ".." that could escape the output directory
4. Uses the directory handle for all write operations

The implementation validates each entry before extraction:

```zig
// Security validation in extract function:
if (std.fs.path.isAbsolute(entry.name)) {
    return error.InvalidEntryPath;
}

if (std.mem.indexOf(u8, entry.name, "..") != null) {
    return error.InvalidEntryPath;
}
```

See the security tests in the full example:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_7.zig:security_tests}}
```

**File size limits:**
```zig
const MAX_FILE_SIZE = 100 * 1024 * 1024;  // 100 MB

fn addFileWithLimit(archive: *SimpleArchive, path: []const u8) !void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    if (stat.size > MAX_FILE_SIZE) {
        return error.FileTooLarge;
    }

    const data = try std.fs.cwd().readFileAlloc(archive.allocator, path, MAX_FILE_SIZE);
    // ... add to archive
}
```

**Decompression bombs:**
- Limit extracted file sizes
- Limit total extraction size
- Count files extracted
- Set timeout for extraction

### Example Usage

Complete archive creation and extraction:

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create archive from directory
    try archiveDirectory(allocator, "my_project", "project.archive");

    std.debug.print("Created archive\n", .{});

    // Load and inspect
    var archive = try SimpleArchive.load(allocator, "project.archive");
    defer archive.deinit();

    std.debug.print("Archive contains {d} files:\n", .{archive.entries.items.len});
    archive.list();

    const size = getArchiveSize(&archive);
    std.debug.print("Total size: {d} bytes\n", .{size});

    // Extract to new directory
    try archive.extract("extracted_project");

    std.debug.print("Extracted to extracted_project/\n", .{});
}
```

### Working with Standard Formats

While Zig doesn't have built-in tar/zip support (yet), you can use external tools:

**Creating tar archives:**
```zig
const result = try std.process.Child.run(.{
    .allocator = allocator,
    .argv = &[_][]const u8{ "tar", "-czf", "archive.tar.gz", "directory/" },
});
defer allocator.free(result.stdout);
defer allocator.free(result.stderr);

if (result.term.Exited != 0) {
    return error.TarFailed;
}
```

**Extracting tar archives:**
```zig
const result = try std.process.Child.run(.{
    .allocator = allocator,
    .argv = &[_][]const u8{ "tar", "-xzf", "archive.tar.gz", "-C", "output/" },
});
defer allocator.free(result.stdout);
defer allocator.free(result.stderr);
```

### Streaming Archives

For large archives, use streaming instead of loading everything into memory:

```zig
// Conceptual example (not implemented above)
const StreamingArchive = struct {
    file: std.fs.File,

    pub fn addFileStreaming(self: *StreamingArchive, name: []const u8, data_file: std.fs.File) !void {
        const stat = try data_file.stat();

        // Write header
        var buf: [4]u8 = undefined;
        std.mem.writeInt(u32, &buf, @intCast(name.len), .little);
        try self.file.writeAll(&buf);
        try self.file.writeAll(name);

        std.mem.writeInt(u32, &buf, @intCast(stat.size), .little);
        try self.file.writeAll(&buf);

        // Stream file data
        var buffer: [4096]u8 = undefined;
        while (true) {
            const n = try data_file.read(&buffer);
            if (n == 0) break;
            try self.file.writeAll(buffer[0..n]);
        }
    }
};
```

### Performance Considerations

**Memory usage:**
- Current implementation loads entire archive into memory
- Use streaming for large files
- Consider memory-mapped files for very large archives

**Speed:**
- Binary format is fast to read/write
- No compression overhead (but larger files)
- Directory traversal can be slow for deep trees

**Optimizations:**
- Parallel file reading for multi-file archives
- Buffered I/O for many small files
- Index file for quick lookups in large archives

### Future Improvements

For production use, consider:
- Compression support (gzip, zstd)
- Metadata preservation (timestamps, permissions)
- Incremental updates
- Archive verification (checksums)
- Encryption support
- Cross-platform path handling

## See Also

- Recipe 13.6: Copying or moving files and directory trees
- Recipe 13.8: Finding files by name
- Recipe 5.13: Directory listing

Full compilable example: `code/04-specialized/13-utility-scripting/recipe_13_7.zig`
