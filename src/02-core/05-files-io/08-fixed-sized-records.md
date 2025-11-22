## Problem

You need to read a binary file containing fixed-size records, processing them one at a time or in batches.

## Solution

### Record Iterator

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_8.zig:record_iterator}}
```

### Random Access

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_8.zig:random_access}}
```

### Batch Processing

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_8.zig:batch_processing}}
```

## Discussion

### Fixed-Size Record Formats

Binary files often store data as sequences of fixed-size records. Each record has the same size, making it easy to seek and iterate:

```zig
const PlayerRecord = extern struct {
    player_id: u32,
    score: u32,
    level: u16,
    lives: u8,
    padding: u8 = 0,
};

comptime {
    // Ensure record has expected size
    std.debug.assert(@sizeOf(PlayerRecord) == 12);
}
```

Use `extern struct` to ensure C-compatible memory layout without padding reordering.

### Basic Record Iterator

The simplest iterator reads one record at a time:

```zig
pub fn RecordIterator(comptime T: type) type {
    return struct {
        file: std.fs.File,
        buffer: [@sizeOf(T)]u8 = undefined,

        const Self = @This();

        pub fn init(file: std.fs.File) Self {
            return .{ .file = file };
        }

        pub fn next(self: *Self) !?T {
            const bytes_read = try self.file.read(&self.buffer);

            if (bytes_read == 0) return null;
            if (bytes_read < @sizeOf(T)) return error.PartialRecord;

            return @bitCast(self.buffer);
        }
    };
}
```

Usage:
```zig
const file = try std.fs.cwd().openFile("data.bin", .{});
defer file.close();

var iter = RecordIterator(PlayerRecord).init(file);
while (try iter.next()) |record| {
    std.debug.print("Player {d}: score {d}\n", .{ record.player_id, record.score });
}
```

### Buffered Record Iterator

For better performance, read multiple records at once:

```zig
pub fn BufferedRecordIterator(comptime T: type, comptime buffer_count: usize) type {
    return struct {
        file: std.fs.File,
        buffer: [buffer_count * @sizeOf(T)]u8 = undefined,
        position: usize = 0,
        count: usize = 0,

        const Self = @This();
        const record_size = @sizeOf(T);

        pub fn init(file: std.fs.File) Self {
            return .{ .file = file };
        }

        pub fn next(self: *Self) !?T {
            // Refill buffer if empty
            if (self.position >= self.count) {
                const bytes_read = try self.file.read(&self.buffer);
                if (bytes_read == 0) return null;

                self.count = bytes_read / record_size;
                self.position = 0;

                // Check for partial record
                if (bytes_read % record_size != 0) {
                    return error.PartialRecord;
                }
            }

            const offset = self.position * record_size;
            const record_bytes = self.buffer[offset..][0..record_size];
            self.position += 1;

            return @bitCast(record_bytes.*);
        }
    };
}
```

### Seeking to Specific Records

Jump directly to a record by index:

```zig
pub fn RecordFile(comptime T: type) type {
    return struct {
        file: std.fs.File,

        const Self = @This();
        const record_size = @sizeOf(T);

        pub fn init(file: std.fs.File) Self {
            return .{ .file = file };
        }

        pub fn seekToRecord(self: *Self, index: usize) !void {
            try self.file.seekTo(index * record_size);
        }

        pub fn readRecord(self: *Self) !T {
            var buffer: [record_size]u8 = undefined;
            const bytes_read = try self.file.read(&buffer);

            if (bytes_read < record_size) return error.PartialRecord;

            return @bitCast(buffer);
        }

        pub fn writeRecord(self: *Self, record: T) !void {
            const bytes: [record_size]u8 = @bitCast(record);
            try self.file.writeAll(&bytes);
        }

        pub fn getRecordCount(self: *Self) !usize {
            const size = (try self.file.stat()).size;
            return size / record_size;
        }
    };
}
```

Usage:
```zig
var record_file = RecordFile(PlayerRecord).init(file);

// Jump to record 100
try record_file.seekToRecord(100);
const record = try record_file.readRecord();

// Get total number of records
const total = try record_file.getRecordCount();
```

### Reading Records in Reverse

Iterate backwards through records:

```zig
pub fn readRecordReverse(comptime T: type, file: std.fs.File, index: usize) !T {
    const record_size = @sizeOf(T);
    const offset = index * record_size;

    try file.seekTo(offset);

    var buffer: [record_size]u8 = undefined;
    const bytes_read = try file.read(&buffer);

    if (bytes_read < record_size) return error.PartialRecord;

    return @bitCast(buffer);
}

pub fn reverseIterator(comptime T: type, file: std.fs.File) !struct {
    file: std.fs.File,
    count: usize,
    index: usize,

    pub fn next(self: *@This()) !?T {
        if (self.index == 0) return null;
        self.index -= 1;
        return readRecordReverse(T, self.file, self.index);
    }
} {
    const size = (try file.stat()).size;
    const record_count = size / @sizeOf(T);

    return .{
        .file = file,
        .count = record_count,
        .index = record_count,
    };
}
```

### Handling Different Endianness

Convert byte order when reading cross-platform files:

```zig
const NetworkRecord = extern struct {
    id: u32,
    timestamp: u64,
    value: u16,
    padding: u16 = 0,

    pub fn fromBigEndian(self: NetworkRecord) NetworkRecord {
        return .{
            .id = std.mem.bigToNative(u32, self.id),
            .timestamp = std.mem.bigToNative(u64, self.timestamp),
            .value = std.mem.bigToNative(u16, self.value),
        };
    }

    pub fn toBigEndian(self: NetworkRecord) NetworkRecord {
        return .{
            .id = std.mem.nativeToBig(u32, self.id),
            .timestamp = std.mem.nativeToBig(u64, self.timestamp),
            .value = std.mem.nativeToBig(u16, self.value),
        };
    }
};
```

### Batch Processing Records

Process records in batches for better performance:

```zig
pub fn processBatch(
    comptime T: type,
    file: std.fs.File,
    allocator: std.mem.Allocator,
    batch_size: usize,
    processor: fn ([]const T) anyerror!void,
) !void {
    const record_size = @sizeOf(T);
    const buffer = try allocator.alloc(u8, batch_size * record_size);
    defer allocator.free(buffer);

    while (true) {
        const bytes_read = try file.read(buffer);
        if (bytes_read == 0) break;

        const record_count = bytes_read / record_size;
        if (bytes_read % record_size != 0) return error.PartialRecord;

        // Cast buffer to record slice
        const records = std.mem.bytesAsSlice(T, buffer[0 .. record_count * record_size]);
        try processor(records);
    }
}
```

### Validating Records

Add validation to ensure record integrity:

```zig
pub fn ValidatedRecordIterator(comptime T: type) type {
    return struct {
        file: std.fs.File,
        buffer: [@sizeOf(T)]u8 = undefined,
        validator: *const fn (T) bool,

        const Self = @This();

        pub fn init(file: std.fs.File, validator: *const fn (T) bool) Self {
            return .{ .file = file, .validator = validator };
        }

        pub fn next(self: *Self) !?T {
            while (true) {
                const bytes_read = try self.file.read(&self.buffer);
                if (bytes_read == 0) return null;
                if (bytes_read < @sizeOf(T)) return error.PartialRecord;

                const record: T = @bitCast(self.buffer);

                if (self.validator(record)) {
                    return record;
                }
                // Skip invalid record and continue
            }
        }
    };
}

fn validatePlayer(record: PlayerRecord) bool {
    return record.lives <= 3 and record.level > 0;
}
```

### Memory-Mapped Record Access

For very large files, use memory mapping:

```zig
pub fn MappedRecordFile(comptime T: type) type {
    return struct {
        data: []align(std.mem.page_size) const u8,

        const Self = @This();
        const record_size = @sizeOf(T);

        pub fn init(file: std.fs.File) !Self {
            const size = (try file.stat()).size;
            const data = try std.posix.mmap(
                null,
                size,
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

### Error Handling

Common errors when working with fixed-size records:

```zig
pub const RecordError = error{
    PartialRecord,
    InvalidAlignment,
    CorruptedData,
};

pub fn safeReadRecord(comptime T: type, file: std.fs.File) RecordError!T {
    var buffer: [@sizeOf(T)]u8 = undefined;
    const bytes_read = file.read(&buffer) catch return error.CorruptedData;

    if (bytes_read == 0) return error.PartialRecord;
    if (bytes_read < @sizeOf(T)) return error.PartialRecord;

    const record: T = @bitCast(buffer);

    // Add custom validation here

    return record;
}
```

### Performance Tips

**Buffer Reads:**
- Read multiple records at once (buffered iterator)
- Reduces system calls significantly

**Alignment:**
- Use `extern struct` for predictable layout
- Ensure proper padding for alignment

**Memory Mapping:**
- Best for random access patterns
- Avoids explicit I/O calls
- Let OS handle caching

**Batch Processing:**
- Process records in groups
- Better cache locality
- Amortize function call overhead

### Related Functions

- `std.fs.File.read()` - Read bytes from file
- `std.fs.File.seekTo()` - Seek to position
- `std.mem.bytesAsSlice()` - Reinterpret bytes as typed slice
- `@bitCast()` - Convert between types of same size
- `std.posix.mmap()` - Memory-map a file
