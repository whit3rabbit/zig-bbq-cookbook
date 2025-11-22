## Problem

You need to read or write binary files containing arrays of structured data, such as records from a database or network packets.

## Solution

### Basic Binary I/O

```zig
{{#include ../../../code/03-advanced/06-data-encoding/recipe_6_9.zig:basic_binary_io}}
```

### Endianness Handling

```zig
{{#include ../../../code/03-advanced/06-data-encoding/recipe_6_9.zig:endianness_handling}}
```

### Memory Mapping

```zig
{{#include ../../../code/03-advanced/06-data-encoding/recipe_6_9.zig:memory_mapping}}
```
        const file = try tmp_dir.createFile("records.bin", .{});
        defer file.close();
        try writeRecords(file, &records);
    }

    // Read
    {
        const file = try tmp_dir.openFile("records.bin", .{});
        defer file.close();

        const read_records = try readRecords(allocator, file);
        defer allocator.free(read_records);

        try std.testing.expectEqual(@as(usize, 2), read_records.len);
        try std.testing.expectEqual(records[0].id, read_records[0].id);
        try std.testing.expectEqual(records[0].x, read_records[0].x);
    }
}
```

## Discussion

### Packed Structs for Binary Formats

Use `packed struct` to control memory layout:

```zig
const BitmapHeader = packed struct {
    magic: u16,           // "BM"
    file_size: u32,
    reserved1: u16,
    reserved2: u16,
    offset: u32,
};

pub fn writeBitmapHeader(file: std.fs.File, header: BitmapHeader) !void {
    const bytes = std.mem.asBytes(&header);
    try file.writeAll(bytes);
}

pub fn readBitmapHeader(file: std.fs.File) !BitmapHeader {
    var header: BitmapHeader = undefined;
    const bytes = std.mem.asBytes(&header);
    const bytes_read = try file.readAll(bytes);

    if (bytes_read != bytes.len) {
        return error.UnexpectedEof;
    }

    return header;
}

test "bitmap header" {
    const header = BitmapHeader{
        .magic = 0x4D42, // "BM" in little-endian
        .file_size = 1024,
        .reserved1 = 0,
        .reserved2 = 0,
        .offset = 54,
    };

    // Packed struct size (may have padding)
    try std.testing.expect(@sizeOf(BitmapHeader) >= 14);

    var tmp = std.testing.tmpDir(.{});
    var tmp_dir = tmp.dir;
    defer tmp.cleanup();

    {
        const file = try tmp_dir.createFile("header.bin", .{});
        defer file.close();
        try writeBitmapHeader(file, header);
    }

    {
        const file = try tmp_dir.openFile("header.bin", .{});
        defer file.close();

        const read_header = try readBitmapHeader(file);
        try std.testing.expectEqual(header.magic, read_header.magic);
        try std.testing.expectEqual(header.file_size, read_header.file_size);
    }
}
```

### Endianness Handling

Handle byte order for cross-platform files:

```zig
const NetworkPacket = struct {
    version: u16,
    length: u32,
    sequence: u64,

    pub fn toBytes(self: NetworkPacket, endian: std.builtin.Endian) ![14]u8 {
        var bytes: [14]u8 = undefined;
        std.mem.writeInt(u16, bytes[0..2], self.version, endian);
        std.mem.writeInt(u32, bytes[2..6], self.length, endian);
        std.mem.writeInt(u64, bytes[6..14], self.sequence, endian);
        return bytes;
    }

    pub fn fromBytes(bytes: []const u8, endian: std.builtin.Endian) !NetworkPacket {
        if (bytes.len < 14) return error.BufferTooSmall;

        return NetworkPacket{
            .version = std.mem.readInt(u16, bytes[0..2], endian),
            .length = std.mem.readInt(u32, bytes[2..6], endian),
            .sequence = std.mem.readInt(u64, bytes[6..14], endian),
        };
    }
};

test "endianness handling" {
    const packet = NetworkPacket{
        .version = 1,
        .length = 256,
        .sequence = 0x123456789ABCDEF0,
    };

    const big_endian = try packet.toBytes(.big);
    const little_endian = try packet.toBytes(.little);

    // Different byte order
    try std.testing.expect(!std.mem.eql(u8, &big_endian, &little_endian));

    // But both decode correctly
    const from_big = try NetworkPacket.fromBytes(&big_endian, .big);
    const from_little = try NetworkPacket.fromBytes(&little_endian, .little);

    try std.testing.expectEqual(packet.version, from_big.version);
    try std.testing.expectEqual(packet.version, from_little.version);
}
```

### Variable-Length Records

Handle records with variable-length fields:

```zig
const VarRecord = struct {
    id: u32,
    name_len: u32,
    name: []const u8,

    pub fn write(self: VarRecord, writer: anytype) !void {
        try writer.writeInt(u32, self.id, .little);
        try writer.writeInt(u32, @intCast(self.name.len), .little);
        try writer.writeAll(self.name);
    }

    pub fn read(allocator: std.mem.Allocator, reader: anytype) !VarRecord {
        const id = try reader.readInt(u32, .little);
        const name_len = try reader.readInt(u32, .little);

        const name = try allocator.alloc(u8, name_len);
        errdefer allocator.free(name);

        const bytes_read = try reader.readAll(name);
        if (bytes_read != name_len) {
            return error.UnexpectedEof;
        }

        return VarRecord{
            .id = id,
            .name_len = name_len,
            .name = name,
        };
    }

    pub fn deinit(self: VarRecord, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
    }
};

test "variable-length records" {
    const allocator = std.testing.allocator;

    const record = VarRecord{
        .id = 42,
        .name_len = 5,
        .name = "Alice",
    };

    var buffer: [256]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buffer);

    try record.write(fbs.writer());

    fbs.pos = 0;
    const read_record = try VarRecord.read(allocator, fbs.reader());
    defer read_record.deinit(allocator);

    try std.testing.expectEqual(record.id, read_record.id);
    try std.testing.expectEqualStrings(record.name, read_record.name);
}
```

### Struct Arrays with Padding

Handle alignment and padding:

```zig
const AlignedRecord = struct {
    a: u8,
    // Padding will be inserted here
    b: u32,
    c: u16,
    // Padding may be inserted here too

    pub fn serialize(self: AlignedRecord) [7]u8 {
        var bytes = [_]u8{0} ** 7;
        bytes[0] = self.a;
        std.mem.writeInt(u32, bytes[1..5], self.b, .little);
        std.mem.writeInt(u16, bytes[5..7], self.c, .little);
        return bytes;
    }

    pub fn deserialize(bytes: [7]u8) AlignedRecord {
        return .{
            .a = bytes[0],
            .b = std.mem.readInt(u32, bytes[1..5], .little),
            .c = std.mem.readInt(u16, bytes[5..7], .little),
        };
    }
};

test "aligned records" {
    const record = AlignedRecord{
        .a = 0x12,
        .b = 0x34567890,
        .c = 0xABCD,
    };

    // Regular struct has padding
    const struct_size = @sizeOf(AlignedRecord);
    try std.testing.expect(struct_size > 7); // Has padding

    // Serialized form is compact
    const bytes = record.serialize();
    try std.testing.expectEqual(@as(usize, 7), bytes.len);

    const deserialized = AlignedRecord.deserialize(bytes);
    try std.testing.expectEqual(record.a, deserialized.a);
    try std.testing.expectEqual(record.b, deserialized.b);
    try std.testing.expectEqual(record.c, deserialized.c);
}
```

### Writing Records Individually

Write records one at a time for sequential processing:

```zig
pub fn writeRecordsBuf(
    file: std.fs.File,
    records: []const Record,
) !void {
    for (records) |record| {
        const bytes = std.mem.asBytes(&record);
        try file.writeAll(bytes);
    }
}

pub fn readRecordsBuf(
    allocator: std.mem.Allocator,
    file: std.fs.File,
    count: usize,
) ![]Record {
    const records = try allocator.alloc(Record, count);
    errdefer allocator.free(records);

    for (records) |*record| {
        const bytes = std.mem.asBytes(record);
        const bytes_read = try file.readAll(bytes);
        if (bytes_read != bytes.len) {
            return error.UnexpectedEof;
        }
    }

    return records;
}

test "individual record IO" {
    const allocator = std.testing.allocator;

    const records = [_]Record{
        .{ .id = 1, .x = 1.0, .y = 2.0, .flags = 1 },
        .{ .id = 2, .x = 3.0, .y = 4.0, .flags = 2 },
        .{ .id = 3, .x = 5.0, .y = 6.0, .flags = 3 },
    };

    var tmp = std.testing.tmpDir(.{});
    var tmp_dir = tmp.dir;
    defer tmp.cleanup();

    {
        const file = try tmp_dir.createFile("records.bin", .{});
        defer file.close();
        try writeRecordsBuf(file, &records);
    }

    {
        const file = try tmp_dir.openFile("records.bin", .{});
        defer file.close();

        const read_records = try readRecordsBuf(allocator, file, records.len);
        defer allocator.free(read_records);

        try std.testing.expectEqual(records.len, read_records.len);
        for (records, read_records) |orig, read| {
            try std.testing.expectEqual(orig.id, read.id);
        }
    }
}
```

### Memory-Mapped Files

Use memory mapping for large datasets:

```zig
pub fn readRecordsMmap(file: std.fs.File) ![]align(4096) const Record {
    const file_size = (try file.stat()).size;

    const mapped = try std.posix.mmap(
        null,
        file_size,
        std.posix.PROT.READ,
        std.posix.MAP{ .TYPE = .SHARED },
        file.handle,
        0,
    );

    return std.mem.bytesAsSlice(Record, mapped);
}

test "memory-mapped records" {
    const records = [_]Record{
        .{ .id = 1, .x = 10.0, .y = 20.0, .flags = 1 },
        .{ .id = 2, .x = 30.0, .y = 40.0, .flags = 2 },
    };

    var tmp = std.testing.tmpDir(.{});
    var tmp_dir = tmp.dir;
    defer tmp.cleanup();

    {
        const file = try tmp_dir.createFile("mmap.bin", .{});
        defer file.close();
        try writeRecords(file, &records);
    }

    {
        const file = try tmp_dir.openFile("mmap.bin", .{});
        defer file.close();

        const mapped_records = try readRecordsMmap(file);
        defer std.posix.munmap(@alignCast(std.mem.sliceAsBytes(mapped_records)));

        try std.testing.expectEqual(@as(usize, 2), mapped_records.len);
        try std.testing.expectEqual(records[0].id, mapped_records[0].id);
    }
}
```

### Best Practices

**Struct Layout:**
- Use `packed struct` for exact binary formats
- Be aware of alignment and padding in regular structs
- Document expected binary layout
- Consider using explicit serialization for portability

**Endianness:**
```zig
// Always specify endianness for cross-platform files
const bytes = try std.mem.writeInt(u32, buffer, value, .little);

// Use native endian only for temp files
const native_bytes = try std.mem.writeInt(u32, buffer, value, .native);
```

**Error Handling:**
```zig
// Always check for unexpected EOF
const bytes_read = try file.readAll(buffer);
if (bytes_read != buffer.len) {
    return error.UnexpectedEof;
}

// Validate file size
const file_size = (try file.stat()).size;
if (file_size % @sizeOf(Record) != 0) {
    return error.InvalidFileSize;
}
```

**Performance:**
- Use memory mapping for large read-only datasets
- Batch writes when possible by using slices
- Consider alignment for direct I/O
- Profile before optimizing

**Struct Size:**
- Packed structs may still have alignment padding
- Use `@sizeOf()` to verify actual size
- For exact binary layout, use manual serialization

### Related Functions

- `std.mem.asBytes()` - Convert value to byte slice
- `std.mem.bytesAsSlice()` - Convert bytes to typed slice
- `std.mem.sliceAsBytes()` - Convert slice to bytes
- `std.mem.readInt()` - Read integer with endianness
- `std.mem.writeInt()` - Write integer with endianness
- `std.io.bufferedReader()` - Create buffered reader
- `std.io.bufferedWriter()` - Create buffered writer
- `std.posix.mmap()` - Memory-map a file
- `std.posix.munmap()` - Unmap memory
