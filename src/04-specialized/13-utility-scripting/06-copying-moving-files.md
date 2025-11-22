# Recipe 13.6: Copying or Moving Files and Directory Trees

## Problem

You need to copy or move files and directories in your script, preserving their content and potentially their metadata.

## Solution

For basic file copying, read from source and write to destination:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_6.zig:copy_file}}
```

To move files, try rename first, then fall back to copy-and-delete:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_6.zig:move_file}}
```

## Discussion

File operations are fundamental to system administration scripts. Zig provides low-level file system APIs that give you precise control.

### Recursive Directory Copying

Copy entire directory trees:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_6.zig:copy_directory}}
```

This recursively walks the source directory and replicates the structure in the destination.

### Moving Directories

Move works similarly to copy but removes the source:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_6.zig:move_directory}}
```

The `rename` operation is atomic and fast when source and destination are on the same filesystem. When they're on different filesystems, we fall back to copy-and-delete.

### Progress Tracking

Monitor copy operations for large files:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_6.zig:copy_with_progress}}
```

Progress callbacks let you show status bars or percentage completion.

### Safe Overwrites

Use atomic operations to prevent data loss:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_6.zig:safe_overwrite}}
```

This creates a temporary file first, then atomically renames it. If the process crashes midway, the original file remains intact.

### Preserving Metadata

Copy files with their permissions and attributes:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_6.zig:copy_preserve_metadata}}
```

Permissions are preserved by querying the source file's stat information and applying it to the destination.

### Batch Operations

Process multiple files efficiently:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_6.zig:batch_operations}}
```

Batch operations are useful for build scripts and deployment tools.

### Filtered Copying

Copy only files matching certain criteria:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_6.zig:filter_copy}}
```

Filters let you copy only specific file types or patterns, useful for selective backups.

### Best Practices

1. **Check space first** - Verify destination has enough free space
2. **Use atomic operations** - Prevent partial copies from crashes
3. **Preserve permissions** - Copy file metadata when appropriate
4. **Handle errors gracefully** - Some files may be unreadable
5. **Provide progress feedback** - Keep users informed for large operations
6. **Clean up on failure** - Remove partial copies if operation fails
7. **Test thoroughly** - Verify both source and destination after copy

### Error Handling

Common errors to handle:
- `error.FileNotFound` - Source doesn't exist
- `error.AccessDenied` - No permission to read/write
- `error.DiskFull` - Not enough space
- `error.FileExists` - Destination already exists (for exclusive creation)
- `error.NotDir` - Expected directory but found file
- `error.IsDir` - Expected file but found directory

Always use `errdefer` to clean up partial copies on errors.

### Platform Considerations

**Unix/Linux/macOS:**
- Permissions use Unix mode bits (owner/group/other)
- Symbolic links require special handling
- Extended attributes may need preservation

**Windows:**
- Different permission model (ACLs)
- Case-insensitive filesystems by default
- Different path separators

Test on all target platforms.

### Performance Tips

1. **Use larger buffers** for better performance on large files
2. **Avoid unnecessary stat calls** - Cache metadata when possible
3. **Use rename when possible** - Much faster than copy-delete
4. **Consider memory mapping** for very large files
5. **Batch small files** - Reduce system call overhead

### Example Usage

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Simple file copy
    try copyFile("source.txt", "destination.txt");

    // Copy directory
    try copyDirectory(allocator, "src_dir", "dest_dir");

    // Move file
    try moveFile("old_location.txt", "new_location.txt");

    // Copy with progress
    var progress = CopyProgress{
        .total_bytes = 0,
        .callback = &progressCallback,
    };
    try copyFileWithProgress("large_file.bin", "copy.bin", &progress);

    // Filtered copy
    try copyDirectoryFiltered(
        allocator,
        "source",
        "destination",
        &isTextFile
    );
}
```

### Common Patterns

**Backup Files:**
```zig
const backup_name = try std.fmt.allocPrint(
    allocator,
    "{s}.backup",
    .{original_name}
);
defer allocator.free(backup_name);
try copyFile(original_name, backup_name);
```

**Deploy Build Artifacts:**
```zig
const artifacts = [_]FileCopyOp{
    .{ .src = "zig-out/bin/app", .dest = "/usr/local/bin/app" },
    .{ .src = "zig-out/lib/libfoo.so", .dest = "/usr/local/lib/libfoo.so" },
};
try batchCopy(allocator, &artifacts);
```

**Temporary File Pattern:**
```zig
// Copy to temp location
const temp = try std.fmt.allocPrint(allocator, "{s}.tmp", .{dest});
defer allocator.free(temp);
try copyFile(src, temp);

// Do work on temp file
processFile(temp);

// Atomic rename
try std.fs.cwd().rename(temp, dest);
```

### Safety Considerations

**Avoiding Data Loss:**
- Always verify source exists before copying
- Check destination doesn't exist (or explicitly allow overwrite)
- Use atomic rename for final step
- Verify copied data matches source

**Security:**
- Validate all paths to prevent directory traversal
- Check permissions before operations
- Don't follow symlinks blindly
- Be careful with user-supplied paths

## See Also

- Recipe 13.5: Executing an external command and getting its output
- Recipe 13.7: Creating and unpacking archives
- Recipe 13.8: Finding files by name
- Recipe 5.13: Directory listing

Full compilable example: `code/04-specialized/13-utility-scripting/recipe_13_6.zig`
