## Problem

You need to read text from a file or write text to a file efficiently, handling line-by-line processing or bulk data operations.

## Solution

### Writing and Reading Text

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_1.zig:write_read_text}}
```

### Line Processing

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_1.zig:line_processing}}
```

### Stream Transform

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_1.zig:stream_transform}}
```

## Original Solution

Use Zig's `std.fs` module to open files, and wrap file handles with buffered readers and writers for efficient I/O operations.

### Writing Text to a File

```zig
const std = @import("std");

pub fn writeTextFile(path: []const u8, content: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    try writer.writeAll(content);
    try writer.flush();
}

// Usage
try writeTextFile("output.txt", "Hello, Zig!\nThis is a test.\n");
```

### Reading Text from a File

```zig
pub fn readTextFile(
    allocator: std.mem.Allocator,
    path: []const u8,
) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = (try file.stat()).size;
    const buffer = try allocator.alloc(u8, file_size);

    const bytes_read = try file.readAll(buffer);
    return buffer[0..bytes_read];
}

// Usage
const content = try readTextFile(allocator, "input.txt");
defer allocator.free(content);
std.debug.print("File content:\n{s}\n", .{content});
```

### Reading Line by Line

```zig
pub fn readLines(
    allocator: std.mem.Allocator,
    path: []const u8,
) !void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var read_buf: [4096]u8 = undefined;
    var file_reader = file.reader(&read_buf);
    const reader = &file_reader.interface;

    var line_writer = std.Io.Writer.Allocating.init(allocator);
    defer line_writer.deinit();

    var line_num: usize = 1;

    while (true) {
        _ = reader.streamDelimiter(&line_writer.writer, '\n') catch |err| {
            if (err == error.EndOfStream) break else return err;
        };
        _ = reader.toss(1); // Skip newline

        std.debug.print("Line {}: {s}\n", .{ line_num, line_writer.written() });
        line_num += 1;
        line_writer.clearRetainingCapacity();
    }
}
```

### Writing Line by Line with Formatting

```zig
pub fn writeFormattedLines(
    path: []const u8,
    data: []const i32,
) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    for (data, 0..) |value, i| {
        try writer.print("Item {}: {}\n", .{ i, value });
    }

    try writer.flush();
}
```

### Reading and Processing Large Files

```zig
pub fn processLargeFile(
    allocator: std.mem.Allocator,
    input_path: []const u8,
    output_path: []const u8,
) !usize {
    const input = try std.fs.cwd().openFile(input_path, .{});
    defer input.close();

    const output = try std.fs.cwd().createFile(output_path, .{});
    defer output.close();

    var read_buf: [4096]u8 = undefined;
    var write_buf: [4096]u8 = undefined;

    var input_reader = input.reader(&read_buf);
    var output_writer = output.writer(&write_buf);

    const reader = &input_reader.interface;
    const writer = &output_writer.interface;

    var line_count: usize = 0;
    var line_writer = std.Io.Writer.Allocating.init(allocator);
    defer line_writer.deinit();

    while (true) {
        _ = reader.streamDelimiter(&line_writer.writer, '\n') catch |err| {
            if (err == error.EndOfStream) break else return err;
        };
        _ = reader.toss(1); // Skip newline
        line_count += 1;

        // Process line (e.g., uppercase conversion)
        const line = line_writer.written();
        for (line) |c| {
            const upper = if (c >= 'a' and c <= 'z') c - 32 else c;
            try writer.writeByte(upper);
        }
        try writer.writeByte('\n');
        line_writer.clearRetainingCapacity();
    }

    try writer.flush();
    return line_count;
}
```

## Discussion

### Zig 0.15.2 I/O API

Starting with Zig 0.15.1, the I/O system was redesigned with buffered I/O as the default. Key changes:

- **Explicit buffers required**: Pass a buffer to `file.reader(&buffer)` and `file.writer(&buffer)`
- **Access via interface**: Get the reader/writer interface with `&file_reader.interface`
- **Manual flushing**: Always call `.flush()` on writers to ensure data is written
- **New line reading**: Use `reader.streamDelimiter()` instead of `readUntilDelimiter()`
- **ArrayList changes**: Use `std.array_list.Managed(T)` instead of `std.ArrayList(T)`

These changes provide better performance but require explicit buffer management and flush calls.

### Buffered I/O Benefits

Buffered readers and writers significantly improve performance by reducing the number of system calls. Instead of reading or writing one byte at a time, they work with larger chunks of data.

**Without buffering:**
- Each `readByte()` or `writeByte()` call triggers a system call
- Extremely slow for large files
- High overhead

**With buffering:**
- Data is read/written in blocks (typically 4KB)
- Dramatically reduces system calls
- Much better performance

### Buffer Sizes

The standard library uses reasonable default buffer sizes (4096 bytes). You can customize buffer sizes if needed:

```zig
var buffer: [8192]u8 = undefined;
var buffered = std.io.bufferedReaderSize(4096, file.reader());
```

### Error Handling

File operations can fail for many reasons:

- File doesn't exist (`error.FileNotFound`)
- Permission denied (`error.AccessDenied`)
- Disk full (`error.NoSpaceLeft`)
- I/O errors (`error.InputOutput`)

Always handle errors explicitly with `try`, `catch`, or proper error propagation:

```zig
const file = std.fs.cwd().openFile(path, .{}) catch |err| {
    std.debug.print("Failed to open {s}: {}\n", .{ path, err });
    return err;
};
```

### Memory Management

When reading entire files into memory:

1. Always free allocated memory with `defer allocator.free(content)`
2. Be aware of file sizes before allocating
3. Consider streaming for very large files
4. Use `ArenaAllocator` for batch processing

```zig
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();
const arena_alloc = arena.allocator();

// All allocations cleaned up together
const content1 = try readTextFile(arena_alloc, "file1.txt");
const content2 = try readTextFile(arena_alloc, "file2.txt");
// No individual frees needed
```

### Line Endings

Zig treats `\n` as the line delimiter. For cross-platform text files:

- Unix/Linux/macOS: `\n` (LF)
- Windows: `\r\n` (CRLF)
- Old Mac: `\r` (CR)

To handle Windows-style line endings:

```zig
const trimmed = std.mem.trimRight(u8, line, "\r");
```

### File Modes

When creating files, specify the mode:

```zig
// Truncate existing file (default)
const file = try std.fs.cwd().createFile(path, .{});

// Append to existing file
const file = try std.fs.cwd().openFile(path, .{
    .mode = .write_only,
});
try file.seekFromEnd(0);

// Create only if doesn't exist
const file = try std.fs.cwd().createFile(path, .{
    .exclusive = true,
});
```

### Reading Strategies

Choose the right strategy based on your needs:

**Full file read** - Good for small to medium files:
```zig
const content = try file.readToEndAlloc(allocator, max_size);
```

**Line by line** - Best for large files or when processing sequentially:
```zig
while (try reader.readUntilDelimiterOrEof(&buffer, '\n')) |line| {
    // Process line
}
```

**Fixed chunks** - For binary data or custom processing:
```zig
const bytes_read = try reader.read(buffer);
```

### Performance Considerations

The generic Reader interface used in these examples prioritizes simplicity, portability, and correctness. For most applications, this provides excellent performance with proper buffering.

**When performance matters most:**
- The generic `streamDelimiter()` reads byte-by-byte through the Reader interface
- For high-performance scenarios (processing many large files), direct BufferedReader access with SIMD-optimized `std.mem.indexOfScalar()` can be 2-15x faster
- This advanced optimization trades simplicity for speed and is covered in advanced recipes

For the vast majority of use cases, the patterns shown here are the right choice.

### Comparison with Other Languages

**Python:**
```python
# Read entire file
with open('file.txt', 'r') as f:
    content = f.read()

# Line by line
with open('file.txt', 'r') as f:
    for line in f:
        print(line)
```

**Zig's approach** requires explicit resource management (`defer file.close()`) and explicit error handling, but provides more control and no hidden allocations.

## See Also

- `code/02-core/05-files-io/recipe_5_1.zig` - Full implementations and tests
- Recipe 5.2: Printing to a file
- Recipe 5.4: Reading and writing binary data
- Recipe 5.6: Performing I/O operations on a string
