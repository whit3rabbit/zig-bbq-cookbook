## Problem

You want to create and write to a file only if it doesn't already exist, preventing accidental overwrites of existing data.

## Solution

### Exclusive Creation

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_5.zig:exclusive_creation}}
```

### Atomic Operations

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_5.zig:atomic_operations}}
```

## Original Solution

Use the `exclusive` flag when creating files to ensure atomic creation.

## Discussion

### Exclusive Creation Flags

The `exclusive` flag in `CreateFlags` ensures that file creation is atomic and fails if the file already exists. This is equivalent to the POSIX `O_EXCL | O_CREAT` flags.

Without `exclusive = true`, `createFile` will truncate existing files:

```zig
// This WILL overwrite existing files (default behavior)
const file = try std.fs.cwd().createFile("data.txt", .{});

// This will NOT overwrite - fails with PathAlreadyExists
const file = try std.fs.cwd().createFile("data.txt", .{
    .exclusive = true,
});
```

### Error Handling

When a file already exists, the operation returns `error.PathAlreadyExists`:

```zig
const result = std.fs.cwd().createFile(path, .{ .exclusive = true });
if (result) |file| {
    defer file.close();
    // File created successfully, write data
    try file.writeAll(data);
} else |err| switch (err) {
    error.PathAlreadyExists => {
        // File exists - decide what to do
        std.debug.print("File already exists: {s}\n", .{path});
        return err;
    },
    else => return err,
}
```

### Use Cases

**Lock Files**: Prevent multiple processes from running simultaneously:

```zig
pub fn acquireLock(lock_path: []const u8) !std.fs.File {
    return std.fs.cwd().createFile(lock_path, .{
        .exclusive = true,
    });
}

pub fn releaseLock(lock: std.fs.File, lock_path: []const u8) void {
    lock.close();
    std.fs.cwd().deleteFile(lock_path) catch {};
}
```

**Unique Temporary Files**: Generate unique filenames until creation succeeds:

```zig
pub fn createUniqueFile(allocator: std.mem.Allocator, prefix: []const u8) !struct { path: []const u8, file: std.fs.File } {
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    const random = prng.random();

    var attempts: usize = 0;
    while (attempts < 100) : (attempts += 1) {
        const suffix = random.int(u32);
        const path = try std.fmt.allocPrint(allocator, "{s}_{d}.tmp", .{ prefix, suffix });
        errdefer allocator.free(path);

        const file = std.fs.cwd().createFile(path, .{
            .exclusive = true,
        }) catch |err| {
            if (err == error.PathAlreadyExists) {
                allocator.free(path);
                continue;
            }
            return err;
        };

        return .{ .path = path, .file = file };
    }

    return error.TooManyAttempts;
}
```

**Safe Configuration File Updates**: Write to temporary file, then atomically rename:

```zig
pub fn safeUpdateConfig(config_path: []const u8, new_content: []const u8, allocator: std.mem.Allocator) !void {
    // Create unique temp file
    const temp_path = try std.fmt.allocPrint(allocator, "{s}.tmp", .{config_path});
    defer allocator.free(temp_path);

    // Write to temp file with exclusive creation
    {
        const file = try std.fs.cwd().createFile(temp_path, .{
            .exclusive = true,
        });
        defer file.close();
        try file.writeAll(new_content);
    }

    // Atomically replace original file
    try std.fs.cwd().rename(temp_path, config_path);
}
```

### Platform Considerations

Exclusive file creation is atomic on all platforms Zig supports:

- **Linux/macOS**: Uses `O_EXCL | O_CREAT` flags
- **Windows**: Uses `CREATE_NEW` disposition
- **WASI**: Implements atomic file creation

The operation is thread-safe and process-safe, making it suitable for inter-process synchronization.

### Related Functions

- `std.fs.Dir.createFile()` - Create file with options
- `std.fs.Dir.openFile()` - Open existing file
- `std.fs.Dir.atomicFile()` - Create temporary file for atomic updates
- `std.fs.Dir.rename()` - Atomically replace file

### Memory Safety

Always use `defer` to ensure files are closed, and `errdefer` to clean up on errors:

```zig
pub fn writeExclusiveWithCleanup(path: []const u8, data: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{
        .exclusive = true,
    });
    errdefer {
        file.close();
        // Clean up partial file on error
        std.fs.cwd().deleteFile(path) catch {};
    }
    defer file.close();

    try file.writeAll(data);
}
```
