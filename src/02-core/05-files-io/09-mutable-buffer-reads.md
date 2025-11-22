## Problem

You need to read binary data from a file into a mutable buffer that you can modify or process in place.

## Solution

### Basic Buffer Reads

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_9.zig:basic_buffer_reads}}
```

### Advanced Buffer Operations

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_9.zig:advanced_buffer_ops}}
```

## Discussion

### Stack-Allocated Buffers

The most efficient approach uses stack-allocated fixed-size buffers:

```zig
var buffer: [4096]u8 = undefined;
const bytes_read = try file.read(&buffer);

// Process buffer[0..bytes_read]
```

Advantages:
- No allocator needed
- Fast allocation (stack)
- Deterministic memory usage
- No cleanup required

### Handling Partial Reads

File reads may return fewer bytes than the buffer size:

```zig
pub fn readExact(file: std.fs.File, buffer: []u8) !void {
    var index: usize = 0;
    while (index < buffer.len) {
        const bytes_read = try file.read(buffer[index..]);
        if (bytes_read == 0) return error.UnexpectedEndOfFile;
        index += bytes_read;
    }
}

test "read exact amount" {
    const test_path = "/tmp/test_exact.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write exactly 100 bytes
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        const data = [_]u8{42} ** 100;
        try file.writeAll(&data);
    }

    // Read exactly 100 bytes
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var buffer: [100]u8 = undefined;
    try readExact(file, &buffer);

    try std.testing.expect(std.mem.allEqual(u8, &buffer, 42));
}
```

### Reading into Slices

Read into slices of existing arrays:

```zig
var data: [1024]u8 = undefined;

// Read into first half
const first_half = try file.read(data[0..512]);

// Read into second half
const second_half = try file.read(data[512..]);

// Total bytes read
const total = first_half + second_half;
```

### Reusing Buffers

Reuse the same buffer for multiple reads:

```zig
pub fn processFileInChunks(
    file: std.fs.File,
    processor: fn ([]const u8) anyerror!void,
) !void {
    var buffer: [4096]u8 = undefined;

    while (true) {
        const bytes_read = try file.read(&buffer);
        if (bytes_read == 0) break;

        try processor(buffer[0..bytes_read]);
    }
}

test "reuse buffer" {
    const test_path = "/tmp/test_reuse.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write large file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();

        var i: usize = 0;
        while (i < 10000) : (i += 1) {
            try file.writeAll("X");
        }
    }

    // Count chunks
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const Counter = struct {
        var count: usize = 0;
        fn process(data: []const u8) !void {
            _ = data;
            count += 1;
        }
    };

    Counter.count = 0;
    try processFileInChunks(file, Counter.process);

    try std.testing.expect(Counter.count > 0);
}
```

### Reading with Different Buffer Types

Read into different kinds of buffers:

```zig
// Fixed array
var array_buffer: [256]u8 = undefined;
_ = try file.read(&array_buffer);

// Slice from heap
const slice_buffer = try allocator.alloc(u8, 1024);
defer allocator.free(slice_buffer);
_ = try file.read(slice_buffer);

// ArrayList
var list_buffer: std.ArrayList(u8) = .{};
defer list_buffer.deinit(allocator);
try list_buffer.resize(allocator, 512);
_ = try file.read(list_buffer.items);
```

### Zero-Copy with Buffered Readers

Use buffered readers to minimize system calls:

```zig
pub fn readWithBufferedReader(file: std.fs.File) !void {
    var file_buffer: [8192]u8 = undefined;
    var buffered = file.reader(&file_buffer);

    var process_buffer: [256]u8 = undefined;

    while (true) {
        const bytes_read = try buffered.read(&process_buffer);
        if (bytes_read == 0) break;

        // Process process_buffer[0..bytes_read]
        // The file_buffer acts as a read-ahead cache
    }
}
```

### Reading Structured Binary Data

Read binary data into typed structures:

```zig
pub fn readStruct(comptime T: type, file: std.fs.File) !T {
    var buffer: [@sizeOf(T)]u8 = undefined;
    const bytes_read = try file.read(&buffer);

    if (bytes_read < @sizeOf(T)) return error.PartialRead;

    return @bitCast(buffer);
}

const Header = extern struct {
    magic: u32,
    version: u16,
    flags: u16,
};

test "read struct" {
    const test_path = "/tmp/test_struct.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write header
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();

        const header = Header{
            .magic = 0xDEADBEEF,
            .version = 1,
            .flags = 0x0042,
        };
        const bytes: [@sizeOf(Header)]u8 = @bitCast(header);
        try file.writeAll(&bytes);
    }

    // Read header
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const header = try readStruct(Header, file);

    try std.testing.expectEqual(@as(u32, 0xDEADBEEF), header.magic);
    try std.testing.expectEqual(@as(u16, 1), header.version);
}
```

### Reading Multiple Buffers (Scatter Read)

Read into multiple buffers in one operation:

```zig
pub fn readScatter(file: std.fs.File, buffers: [][]u8) !usize {
    var total: usize = 0;

    for (buffers) |buffer| {
        const bytes_read = try file.read(buffer);
        total += bytes_read;
        if (bytes_read < buffer.len) break;
    }

    return total;
}

test "scatter read" {
    const test_path = "/tmp/test_scatter.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write test data
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("AAAABBBBCCCC");
    }

    // Read into multiple buffers
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var buf1: [4]u8 = undefined;
    var buf2: [4]u8 = undefined;
    var buf3: [4]u8 = undefined;

    var buffers = [_][]u8{ &buf1, &buf2, &buf3 };
    const total = try readScatter(file, &buffers);

    try std.testing.expectEqual(@as(usize, 12), total);
    try std.testing.expectEqualStrings("AAAA", &buf1);
    try std.testing.expectEqualStrings("BBBB", &buf2);
    try std.testing.expectEqualStrings("CCCC", &buf3);
}
```

### Reading with Offset

Read from a specific position without seeking:

```zig
pub fn readAtOffset(file: std.fs.File, buffer: []u8, offset: u64) !usize {
    const original_pos = try file.getPos();
    defer file.seekTo(original_pos) catch {};

    try file.seekTo(offset);
    return try file.read(buffer);
}

test "read at offset" {
    const test_path = "/tmp/test_offset.dat";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write test data
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("0123456789");
    }

    // Read from offset 5
    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    var buffer: [3]u8 = undefined;
    const bytes_read = try readAtOffset(file, &buffer, 5);

    try std.testing.expectEqual(@as(usize, 3), bytes_read);
    try std.testing.expectEqualStrings("567", &buffer);

    // File position unchanged
    try std.testing.expectEqual(@as(u64, 0), try file.getPos());
}
```

### Ring Buffer Reading

Continuously read into a ring buffer:

```zig
pub const RingBuffer = struct {
    buffer: []u8,
    read_pos: usize = 0,
    write_pos: usize = 0,
    count: usize = 0,

    pub fn init(buffer: []u8) RingBuffer {
        return .{ .buffer = buffer };
    }

    pub fn readFromFile(self: *RingBuffer, file: std.fs.File) !usize {
        if (self.count == self.buffer.len) return 0; // Buffer full

        const write_idx = self.write_pos;
        const available = self.buffer.len - self.count;

        const to_end = self.buffer.len - write_idx;
        const read_size = @min(available, to_end);

        const bytes_read = try file.read(self.buffer[write_idx..][0..read_size]);
        if (bytes_read == 0) return 0;

        self.write_pos = (write_idx + bytes_read) % self.buffer.len;
        self.count += bytes_read;

        return bytes_read;
    }

    pub fn consume(self: *RingBuffer, amount: usize) []const u8 {
        const to_read = @min(amount, self.count);
        const read_idx = self.read_pos;

        const to_end = self.buffer.len - read_idx;
        const chunk_size = @min(to_read, to_end);

        const result = self.buffer[read_idx..][0..chunk_size];

        self.read_pos = (read_idx + chunk_size) % self.buffer.len;
        self.count -= chunk_size;

        return result;
    }
};
```

### Error Handling

Handle common read errors:

```zig
pub fn safeRead(file: std.fs.File, buffer: []u8) !usize {
    return file.read(buffer) catch |err| switch (err) {
        error.InputOutput => {
            std.debug.print("I/O error reading file\n", .{});
            return error.ReadFailed;
        },
        error.AccessDenied => {
            std.debug.print("Access denied\n", .{});
            return error.PermissionDenied;
        },
        error.BrokenPipe => return 0, // Treat as EOF
        else => return err,
    };
}
```

### Performance Tips

**Buffer Size:**
- Use 4KB-64KB buffers for best performance
- Align with filesystem block size when possible
- Larger isn't always better (cache effects)

**Stack vs Heap:**
```zig
// Fast: Stack allocation (< 4KB recommended)
var small_buffer: [4096]u8 = undefined;

// Slower: Heap allocation (use for > 4KB)
const large_buffer = try allocator.alloc(u8, 65536);
defer allocator.free(large_buffer);
```

**Buffered Readers:**
- Use buffered readers for small, frequent reads
- Reduces system calls dramatically
- Adds one level of copying but worth it

**Avoid:**
```zig
// Bad: Reading one byte at a time
for (0..file_size) |_| {
    var byte: [1]u8 = undefined;
    _ = try file.read(&byte);
}

// Good: Read in chunks
var buffer: [4096]u8 = undefined;
while (true) {
    const n = try file.read(&buffer);
    if (n == 0) break;
    // Process buffer[0..n]
}
```

### Memory Safety

Always initialize buffers before reading sensitive data:

```zig
// Unsafe: Uninitialized buffer may leak data
var buffer: [1024]u8 = undefined;
const n = try file.read(&buffer);
// buffer[n..] contains uninitialized data!

// Safe: Zero-initialize
var buffer = [_]u8{0} ** 1024;
const n = try file.read(&buffer);
// buffer[n..] is all zeros
```

Or only use the read portion:

```zig
var buffer: [1024]u8 = undefined;
const n = try file.read(&buffer);
const valid_data = buffer[0..n]; // Only use what was read
```

### Related Functions

- `std.fs.File.read()` - Read into buffer
- `std.fs.File.readAll()` - Read until buffer full or EOF
- `std.fs.File.reader()` - Get buffered reader
- `std.Io.Reader.read()` - Generic reader interface
- `std.Io.Reader.readAtLeast()` - Read minimum number of bytes
- `std.mem.readInt()` - Read integer from bytes
