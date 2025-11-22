## Problem

You want to use I/O operations (readers and writers) on in-memory string data instead of files, useful for testing, parsing, or building formatted output.

## Solution

### String Buffer I/O

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_6.zig:string_buffer_io}}
```

### Binary Buffers

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_6.zig:binary_buffers}}
```

## Original Solution

Use `std.io.fixedBufferStream` to create an I/O interface over a byte buffer.

## Discussion

### Fixed Buffer Streams

A `fixedBufferStream` wraps a fixed-size byte array and provides reader/writer interfaces:

```zig
var buffer: [256]u8 = undefined;
var fbs = std.io.fixedBufferStream(&buffer);

// Get reader and writer
const reader = fbs.reader();
const writer = fbs.writer();
```

The stream maintains a position that advances as you read or write:

```zig
var buf: [50]u8 = undefined;
var fbs = std.io.fixedBufferStream(&buf);
const writer = fbs.writer();

try writer.writeAll("First");
try writer.writeAll(" Second");

const written = fbs.getWritten();
// written is "First Second"
```

### Reading from String Buffers

You can treat existing string data as a readable stream:

```zig
pub fn parseFromString(data: []const u8) !u32 {
    var fbs = std.io.fixedBufferStream(data);
    const reader = fbs.reader();

    // Read line by line
    var line_buf: [64]u8 = undefined;
    const line = try reader.readUntilDelimiter(&line_buf, '\n');

    return try std.fmt.parseInt(u32, line, 10);
}

test "parse from string" {
    const data = "42\nmore data";
    const value = try parseFromString(data);
    try std.testing.expectEqual(@as(u32, 42), value);
}
```

### Writing to String Buffers

Build formatted strings using writer operations:

```zig
pub fn formatMessage(allocator: std.mem.Allocator, level: []const u8, text: []const u8) ![]u8 {
    var buffer: [512]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    const timestamp = std.time.timestamp();
    try writer.print("[{d}] {s}: {s}", .{ timestamp, level, text });

    return try allocator.dupe(u8, fbs.getWritten());
}
```

### Seeking Within Buffers

You can manipulate the stream position for random access:

```zig
test "seeking in buffer" {
    var buffer: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    // Write data
    try writer.writeAll("0123456789");

    // Seek to position 5
    fbs.pos = 5;

    // Overwrite from position 5
    try writer.writeAll("ABCDE");

    const written = fbs.getWritten();
    try std.testing.expectEqualStrings("01234ABCDE", written);
}
```

Reset to read what was written:

```zig
test "write then read" {
    var buffer: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);

    // Write data
    const writer = fbs.writer();
    try writer.writeAll("test data");

    // Reset to beginning
    fbs.pos = 0;

    // Read data
    const reader = fbs.reader();
    var read_buf: [10]u8 = undefined;
    const bytes_read = try reader.read(&read_buf);

    try std.testing.expectEqualStrings("test data", read_buf[0..bytes_read]);
}
```

### Practical Use Cases

**Building Complex Strings:**

```zig
pub fn buildReport(allocator: std.mem.Allocator, items: []const Item) ![]u8 {
    var buffer: [4096]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    try writer.writeAll("REPORT\n");
    try writer.writeAll("======\n\n");

    for (items, 0..) |item, i| {
        try writer.print("{d}. {s}: ${d:.2}\n", .{ i + 1, item.name, item.price });
    }

    try writer.writeAll("\n");

    return try allocator.dupe(u8, fbs.getWritten());
}
```

**Testing I/O Code:**

```zig
fn writeData(writer: anytype, value: u32) !void {
    try writer.print("Value: {d}\n", .{value});
}

test "writeData output" {
    var buffer: [100]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);

    try writeData(fbs.writer(), 42);

    try std.testing.expectEqualStrings("Value: 42\n", fbs.getWritten());
}
```

**Parsing Binary Data from Memory:**

```zig
pub fn parseHeader(data: []const u8) !struct { magic: u32, version: u16 } {
    var fbs = std.io.fixedBufferStream(data);
    const reader = fbs.reader();

    const magic = try reader.readInt(u32, .little);
    const version = try reader.readInt(u16, .little);

    return .{ .magic = magic, .version = version };
}
```

**Building Binary Data in Memory:**

```zig
pub fn buildPacket(allocator: std.mem.Allocator, msg_type: u8, payload: []const u8) ![]u8 {
    var buffer: [1024]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    // Write header
    try writer.writeByte(msg_type);
    try writer.writeInt(u16, @intCast(payload.len), .little);

    // Write payload
    try writer.writeAll(payload);

    return try allocator.dupe(u8, fbs.getWritten());
}
```

### Dynamic vs Fixed Buffers

For dynamic growth, use `std.ArrayList(u8)`:

```zig
test "dynamic string building" {
    const allocator = std.testing.allocator;
    var list: std.ArrayList(u8) = .{};
    defer list.deinit(allocator);

    const writer = list.writer(allocator);

    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        try writer.print("{d} ", .{i});
    }

    const result = try list.toOwnedSlice(allocator);
    defer allocator.free(result);

    try std.testing.expect(result.len > 100);
}
```

Fixed buffers are stack-allocated and faster but have size limits. Dynamic buffers grow as needed but require an allocator.

### Error Handling

Fixed buffer streams can fail if you exceed capacity:

```zig
test "buffer overflow" {
    var buffer: [10]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);
    const writer = fbs.writer();

    const result = writer.writeAll("This is too long");
    try std.testing.expectError(error.NoSpaceLeft, result);
}
```

### Comparison with Other Approaches

**Fixed Buffer Stream:**
- Stack-allocated, fast
- Fixed capacity
- Supports seek operations
- Best for bounded output

**ArrayList Writer:**
- Heap-allocated, slower
- Dynamic growth
- No seek support
- Best for unbounded output

**Direct Buffer Manipulation:**
```zig
// Manual approach
var buffer: [100]u8 = undefined;
var pos: usize = 0;

const text = "Hello";
@memcpy(buffer[pos..][0..text.len], text);
pos += text.len;
```

Using streams is more idiomatic and composable with generic writer code.

### Related Functions

- `std.io.fixedBufferStream()` - Create stream over fixed buffer
- `std.ArrayList(u8).writer()` - Dynamic buffer writer
- `std.io.countingWriter()` - Count bytes written
- `std.io.limitedReader()` - Limit bytes read
