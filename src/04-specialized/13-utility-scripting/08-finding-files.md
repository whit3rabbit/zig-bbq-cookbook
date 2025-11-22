# Recipe 13.8: Finding Files by Name

## Problem

You need to search for files in a directory tree by name, pattern, or other criteria.

## Solution

Search recursively for files matching an exact name:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_8.zig:find_by_name}}
```

## Discussion

Finding files is a common task in system administration and build scripts. Zig's filesystem APIs make it straightforward to implement custom search logic.

All the file-finding functions use `std.fs.Dir.Walker`, which provides iterative directory traversal. This prevents file descriptor exhaustion that can occur with recursive approaches in deeply nested directory structures. Walker maintains only 1-2 open file descriptors regardless of directory depth, making it safe for arbitrarily deep trees.

### Pattern Matching

Find files matching wildcards:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_8.zig:find_by_pattern}}
```

This implements simple glob-style pattern matching with `*` as a wildcard.

### Find by Extension

A common case is finding all files with a specific extension:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_8.zig:find_by_extension}}
```

This is more efficient than pattern matching when you only care about file extensions.

### Find by Size

Locate files larger than a threshold:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_8.zig:find_by_size}}
```

Useful for finding large files consuming disk space.

### Custom Predicates

Use arbitrary logic to filter files:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_8.zig:find_predicate}}
```

Predicates give you complete control over matching logic.

### Finding Empty Files

Locate files with zero bytes:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_8.zig:find_empty_files}}
```

Empty files often indicate errors or incomplete operations.

### Best Practices

1. **Handle permissions gracefully** - Skip directories you can't access
2. **Use Walker for traversal** - Prevents file descriptor exhaustion
3. **Use errdefer** - Clean up partial results on error
4. **Consider memory** - Large directory trees can use significant memory
5. **Provide progress** - Show feedback for long searches
6. **Filter early** - Skip unnecessary checks in the walker loop
7. **Test edge cases** - Empty directories, no matches, permission errors

### Performance Considerations

**Memory Usage:**
- Results list grows with matches
- Consider streaming results instead of collecting all
- Free paths as you process them

**Speed:**
- Pattern matching is slower than exact matching
- Size checks require stat calls
- Consider parallel directory scanning for very large trees

**Optimizations:**
- Early exit when possible
- Skip known directories (.git, node_modules)
- Use iterators instead of collecting results
- Cache stat results when checking multiple conditions

### Error Handling

Common errors:
- `error.AccessDenied` - Can't read directory (handle gracefully)
- `error.FileNotFound` - Directory disappeared during scan
- `error.OutOfMemory` - Too many results

Always handle permission errors gracefully. Some directories may be unreadable even by root.

Note: Using `std.fs.Dir.Walker` eliminates the `error.SystemResources` (file descriptor exhaustion) issue that can occur with recursive directory traversal.

### Platform Considerations

**Unix/Linux:**
- Case-sensitive filenames
- Supports symbolic links
- Hidden files start with `.`

**macOS:**
- Case-insensitive by default (HFS+)
- But case-preserving
- Extended attributes

**Windows:**
- Case-insensitive
- Different path separators (`\` vs `/`)
- Hidden attribute instead of dot prefix

### Example Usage

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Find all .zig files
    const zig_files = try findFilesByExtension(allocator, "src", ".zig");
    defer {
        for (zig_files) |path| allocator.free(path);
        allocator.free(zig_files);
    }

    std.debug.print("Found {} Zig files:\n", .{zig_files.len});
    for (zig_files) |path| {
        std.debug.print("  {s}\n", .{path});
    }

    // Find large files
    const large_files = try findFilesLargerThan(allocator, ".", 1024 * 1024);
    defer {
        for (large_files) |path| allocator.free(path);
        allocator.free(large_files);
    }

    std.debug.print("\nFiles larger than 1MB:\n", .{});
    for (large_files) |path| {
        std.debug.print("  {s}\n", .{path});
    }
}
```

### Common Patterns

**Find Source Files:**
```zig
fn isSourceFile(entry: std.fs.Dir.Entry) bool {
    if (entry.kind != .file) return false;
    return std.mem.endsWith(u8, entry.name, ".zig") or
           std.mem.endsWith(u8, entry.name, ".c") or
           std.mem.endsWith(u8, entry.name, ".cpp");
}

const sources = try findFilesMatching(allocator, ".", &isSourceFile);
```

**Find Recent Files:**
```zig
fn findModifiedSince(
    allocator: std.mem.Allocator,
    dir_path: []const u8,
    since: i64,  // Unix timestamp
) ![][]const u8 {
    // Implementation checks file.stat().mtime
}
```

**Exclude Directories:**
```zig
fn shouldSkipDir(name: []const u8) bool {
    return std.mem.eql(u8, name, ".git") or
           std.mem.eql(u8, name, "node_modules") or
           std.mem.eql(u8, name, "zig-cache");
}

// Walker automatically handles subdirectories
// You can check basename to skip specific directories:
const basename = std.fs.path.basename(entry.path);
if (shouldSkipDir(basename)) continue;
```

### Advanced Features

**Depth-Limited Search:**
```zig
fn findFilesMaxDepth(
    allocator: std.mem.Allocator,
    dir_path: []const u8,
    pattern: []const u8,
    max_depth: usize,
) ![][]const u8 {
    // Pass depth counter through recursive calls
}
```

**Follow Symlinks:**
```zig
// Be careful - can cause infinite loops!
if (entry.kind == .sym_link) {
    const target = try dir.readLink(entry.name, &link_buffer);
    // Process symlink target
}
```

**Multi-Pattern Search:**
```zig
fn findMultiplePatterns(
    allocator: std.mem.Allocator,
    dir_path: []const u8,
    patterns: []const []const u8,
) ![][]const u8 {
    // Match any of the patterns
}
```

### Safety Considerations

**Symlink Loops:**
- Walker handles symlinks safely by default
- Track visited directories if following symlinks explicitly
- Consider canonical paths for complex scenarios

**Resource Exhaustion:**
- Walker handles file descriptors efficiently (1-2 FDs regardless of depth)
- Stream results instead of collecting all
- Consider batch processing for very large result sets

**Path Traversal:**
- Validate paths don't escape intended directory
- Be careful with user-supplied search patterns
- Check for `..` in paths

## See Also

- Recipe 13.6: Copying or moving files and directory trees
- Recipe 13.7: Creating and unpacking archives
- Recipe 5.13: Directory listing
- Recipe 5.12: File existence

Full compilable example: `code/04-specialized/13-utility-scripting/recipe_13_8.zig`
