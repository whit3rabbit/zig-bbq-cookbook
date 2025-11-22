## Problem

You need to efficiently access large binary files, especially for random access patterns, without explicitly reading data into buffers.

## Solution

### Basic Memory Mapping

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_10.zig:basic_mmap}}
```

### Structured Memory Mapping

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_10.zig:structured_mmap}}
```

## Discussion

### What is Memory Mapping?

Memory mapping maps file contents into virtual memory, allowing you to access files as if they were in-memory arrays. The OS handles paging data in and out as needed.

**Advantages:**
- Fast random access
- No explicit read calls
- OS manages caching automatically
- Multiple processes can share read-only mappings
- Works with files larger than available RAM

**When to use:**
- Random access patterns
- Large files (especially > 1MB)
- Multiple reads from different locations
- Database files
- Binary search in sorted files

**When NOT to use:**
- Sequential scans (buffered reading is better)
- Small files (< 4KB)
- Files that change frequently
- Network filesystems (can be slow)

### Basic Memory Mapping

Map a file for reading:

```zig
pub fn mapFileReadOnly(path: []const u8) ![]align(std.mem.page_size) const u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    errdefer file.close();

    const file_size = (try file.stat()).size;

    const data = try std.posix.mmap(
        null,                      // Let OS choose address
        file_size,                 // Map entire file
        std.posix.PROT.READ,      // Read-only access
        .{ .TYPE = .SHARED },     // Share mapping with other processes
        file.handle,               // File descriptor
        0,                         // Start at beginning
    );

    // Note: file can be closed immediately after mmap
    // The mapping keeps file data accessible
    file.close();

    return data;
}

test "map read only" {
    const test_path = "/tmp/test_mmap.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create test file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("Hello, Memory Map!");
    }

    // Map and read
    const data = try mapFileReadOnly(test_path);
    defer std.posix.munmap(data);

    try std.testing.expectEqualStrings("Hello, Memory Map!", data);
}
```

### Memory Mapping for Read-Write

Map a file for both reading and writing:

```zig
pub fn mapFileReadWrite(path: []const u8) !struct {
    data: []align(std.mem.page_size) u8,
    file: std.fs.File,
} {
    const file = try std.fs.cwd().openFile(path, .{ .mode = .read_write });
    errdefer file.close();

    const file_size = (try file.stat()).size;

    const data = try std.posix.mmap(
        null,
        file_size,
        std.posix.PROT.READ | std.posix.PROT.WRITE,
        .{ .TYPE = .SHARED },  // Changes written back to file
        file.handle,
        0,
    );

    return .{ .data = data, .file = file };
}

pub fn unmapFile(mapping: anytype) void {
    std.posix.munmap(mapping.data);
    mapping.file.close();
}

test "map read write" {
    const test_path = "/tmp/test_mmap_rw.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create test file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("AAAA");
    }

    // Map, modify, and sync
    {
        const mapping = try mapFileReadWrite(test_path);
        defer unmapFile(mapping);

        // Modify in place
        mapping.data[0] = 'B';
        mapping.data[1] = 'B';

        // Force write to disk
        try std.posix.msync(mapping.data, std.posix.MSF.SYNC);
    }

    // Verify changes persisted
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var buffer: [4]u8 = undefined;
    _ = try file.read(&buffer);

    try std.testing.expectEqualStrings("BBAA", &buffer);
}
```

### Private vs Shared Mappings

**Shared mappings** (`.TYPE = .SHARED`):
- Changes visible to other processes
- Changes written back to file
- Use for: IPC, database files, config files

**Private mappings** (`.TYPE = .PRIVATE`):
- Changes only visible to this process
- Changes NOT written to file (copy-on-write)
- Use for: Templates, loading executables

```zig
pub fn mapFilePrivate(path: []const u8) ![]align(std.mem.page_size) u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = (try file.stat()).size;

    const data = try std.posix.mmap(
        null,
        file_size,
        std.posix.PROT.READ | std.posix.PROT.WRITE,
        .{ .TYPE = .PRIVATE },  // Copy-on-write
        file.handle,
        0,
    );

    return data;
}
```

### Partial File Mapping

Map only part of a large file:

```zig
pub fn mapFileRange(
    path: []const u8,
    offset: u64,
    length: usize,
) ![]align(std.mem.page_size) const u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    // Offset must be page-aligned
    const page_size = std.mem.page_size;
    const aligned_offset = (offset / page_size) * page_size;
    const offset_diff = offset - aligned_offset;
    const aligned_length = length + offset_diff;

    const data = try std.posix.mmap(
        null,
        aligned_length,
        std.posix.PROT.READ,
        .{ .TYPE = .SHARED },
        file.handle,
        aligned_offset,
    );

    // Return view starting at actual offset
    return data[offset_diff..][0..length];
}
```

### Structured Data Access

Access structured binary data through memory mapping:

```zig
pub fn MappedStructFile(comptime T: type) type {
    return struct {
        data: []align(std.mem.page_size) const u8,

        const Self = @This();
        const record_size = @sizeOf(T);

        pub fn init(path: []const u8) !Self {
            const file = try std.fs.cwd().openFile(path, .{});
            defer file.close();

            const file_size = (try file.stat()).size;

            const data = try std.posix.mmap(
                null,
                file_size,
                std.posix.PROT.READ,
                .{ .TYPE = .SHARED },
                file.handle,
                0,
            );

            return .{ .data = data };
        }

        pub fn deinit(self: *Self) void {
            std.posix.munmap(self.data);
        }

        pub fn get(self: Self, index: usize) !T {
            const offset = index * record_size;
            if (offset + record_size > self.data.len) {
                return error.OutOfBounds;
            }

            const record_bytes = self.data[offset..][0..record_size];
            return @bitCast(record_bytes.*);
        }

        pub fn count(self: Self) usize {
            return self.data.len / record_size;
        }

        pub fn slice(self: Self) []const T {
            return std.mem.bytesAsSlice(T, self.data);
        }
    };
}
```

### Anonymous Memory Mappings

Create memory mappings not backed by a file:

```zig
pub fn createAnonymousMapping(size: usize) ![]align(std.mem.page_size) u8 {
    const data = try std.posix.mmap(
        null,
        size,
        std.posix.PROT.READ | std.posix.PROT.WRITE,
        .{ .TYPE = .PRIVATE, .ANONYMOUS = true },
        -1,  // No file descriptor
        0,
    );

    return data;
}
```

Use cases:
- Large temporary buffers
- Shared memory between parent/child processes
- Custom memory allocators

### Advising the Kernel

Give hints about access patterns:

```zig
pub fn adviseMappedFile(data: []align(std.mem.page_size) const u8, advice: enum {
    Normal,
    Random,
    Sequential,
    WillNeed,
    DontNeed,
}) !void {
    const linux_advice: i32 = switch (advice) {
        .Normal => std.os.linux.MADV.NORMAL,
        .Random => std.os.linux.MADV.RANDOM,
        .Sequential => std.os.linux.MADV.SEQUENTIAL,
        .WillNeed => std.os.linux.MADV.WILLNEED,
        .DontNeed => std.os.linux.MADV.DONTNEED,
    };

    _ = std.os.linux.madvise(data.ptr, data.len, linux_advice);
}
```

**Advice hints:**
- `Normal` - Default behavior
- `Random` - No readahead, aggressive page reclaim
- `Sequential` - Aggressive readahead, free pages behind
- `WillNeed` - Prefetch pages into memory now
- `DontNeed` - Don't need pages anymore, can free

### Syncing Changes to Disk

Control when changes are written:

```zig
pub fn syncMapping(data: []align(std.mem.page_size) u8, sync_type: enum {
    Async,
    Sync,
    Invalidate,
}) !void {
    const flags: c_int = switch (sync_type) {
        .Async => std.posix.MSF.ASYNC,       // Queue changes
        .Sync => std.posix.MSF.SYNC,         // Wait for completion
        .Invalidate => std.posix.MSF.INVALIDATE,  // Invalidate caches
    };

    try std.posix.msync(data, flags);
}
```

### Handling Large Files

Work with files larger than address space (32-bit systems):

```zig
pub fn processLargeFileMapped(
    path: []const u8,
    processor: *const fn ([]const u8) anyerror!void,
) !void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = (try file.stat()).size;
    const chunk_size = 256 * 1024 * 1024; // 256MB windows

    var offset: usize = 0;
    while (offset < file_size) {
        const remaining = file_size - offset;
        const map_size = @min(remaining, chunk_size);

        const data = try std.posix.mmap(
            null,
            map_size,
            std.posix.PROT.READ,
            .{ .TYPE = .SHARED },
            file.handle,
            offset,
        );
        defer std.posix.munmap(data);

        try processor(data);

        offset += map_size;
    }
}
```

### Binary Search in Mapped Files

Efficiently search sorted mapped files:

```zig
pub fn binarySearchMapped(
    comptime T: type,
    data: []align(std.mem.page_size) const u8,
    key: T,
) ?usize {
    const records = std.mem.bytesAsSlice(T, data);

    var left: usize = 0;
    var right: usize = records.len;

    while (left < right) {
        const mid = left + (right - left) / 2;

        if (records[mid] == key) {
            return mid;
        } else if (records[mid] < key) {
            left = mid + 1;
        } else {
            right = mid;
        }
    }

    return null;
}
```

### Error Handling

Handle common mapping errors:

```zig
pub fn safeMmap(path: []const u8) ![]align(std.mem.page_size) const u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = (try file.stat()).size;
    if (file_size == 0) return error.EmptyFile;

    return std.posix.mmap(
        null,
        file_size,
        std.posix.PROT.READ,
        .{ .TYPE = .SHARED },
        file.handle,
        0,
    ) catch |err| switch (err) {
        error.MemoryMappingNotSupported => {
            std.debug.print("Memory mapping not supported\n", .{});
            return error.MappingFailed;
        },
        error.AccessDenied => {
            std.debug.print("Permission denied\n", .{});
            return error.PermissionDenied;
        },
        error.OutOfMemory => {
            std.debug.print("Out of address space\n", .{});
            return error.AddressSpaceExhausted;
        },
        else => return err,
    };
}
```

### Performance Considerations

**Memory mapping is faster when:**
- Random access (no sequential access penalty)
- Multiple reads from same data
- File larger than typical buffer (> 1MB)
- Data accessed repeatedly

**Regular I/O is faster when:**
- Sequential scans (better cache locality)
- Small files (< 4KB)
- Single pass over data
- Network filesystems

**Page faults:**
- First access to each page causes page fault
- Can cause unpredictable latency
- Use `MADV.WILLNEED` to prefetch if needed

**Memory usage:**
- Mapping doesn't use RAM immediately
- Pages loaded on access
- OS may keep pages cached
- Multiple processes can share pages

### Platform Differences

**Linux-specific features:**
```zig
// Huge pages for better TLB efficiency
std.os.linux.mmap(
    null,
    size,
    std.os.linux.PROT.READ,
    std.os.linux.MAP.PRIVATE | std.os.linux.MAP.HUGETLB,
    -1,
    0,
);
```

**Cross-platform portable code:**
```zig
// Use std.posix for portable APIs
const data = try std.posix.mmap(...);  // Works on Linux, macOS, BSDs
```

### Related Functions

- `std.posix.mmap()` - Map file into memory
- `std.posix.munmap()` - Unmap memory region
- `std.posix.msync()` - Sync changes to disk
- `std.os.linux.madvise()` - Give usage advice (Linux)
- `std.os.linux.mprotect()` - Change protection
- `std.mem.page_size` - System page size constant
