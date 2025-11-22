## Problem

You need to convert Zig structs and data types to bytes for file storage, network transmission, or inter-process communication.

## Solution

### Basic Serialization

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_19.zig:basic_serialization}}
```

### Endianness Handling

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_19.zig:endianness_handling}}
```

### Array Serialization

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_19.zig:array_serialization}}
```

### Custom Serialization

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_19.zig:custom_serialization}}
```

## Discussion

### Binary Serialization with std.mem

Convert structs to byte slices:

```zig
pub fn structToBytes(comptime T: type, value: *const T) []const u8 {
    return std.mem.asBytes(value);
}

pub fn bytesToStruct(comptime T: type, bytes: []const u8) !T {
    if (bytes.len != @sizeOf(T)) {
        return error.InvalidSize;
    }

    var value: T = undefined;
    @memcpy(std.mem.asBytes(&value), bytes);
    return value;
}

test "struct to bytes" {
    const Point = struct {
        x: i32,
        y: i32,
    };

    const point = Point{ .x = 10, .y = 20 };
    const bytes = structToBytes(Point, &point);

    try std.testing.expectEqual(@sizeOf(Point), bytes.len);

    const restored = try bytesToStruct(Point, bytes);
    try std.testing.expectEqual(point.x, restored.x);
    try std.testing.expectEqual(point.y, restored.y);
}
```

### Packed Structs for Binary Layouts

Control memory layout:

```zig
pub const PackedData = packed struct {
    flags: u8,
    value: u16,
    id: u32,
};

pub fn serializePacked(data: PackedData) [@sizeOf(PackedData)]u8 {
    return @bitCast(data);
}

pub fn deserializePacked(bytes: [@sizeOf(PackedData)]u8) PackedData {
    return @bitCast(bytes);
}

test "packed struct serialization" {
    const data = PackedData{
        .flags = 0xFF,
        .value = 0x1234,
        .id = 0xDEADBEEF,
    };

    const bytes = serializePacked(data);
    const restored = deserializePacked(bytes);

    try std.testing.expectEqual(data.flags, restored.flags);
    try std.testing.expectEqual(data.value, restored.value);
    try std.testing.expectEqual(data.id, restored.id);
}
```

### Endianness Handling

Handle byte order:

```zig
pub fn serializeInt(comptime T: type, value: T, endian: std.builtin.Endian) [@sizeOf(T)]u8 {
    var bytes: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &bytes, value, endian);
    return bytes;
}

pub fn deserializeInt(comptime T: type, bytes: *const [@sizeOf(T)]u8, endian: std.builtin.Endian) T {
    return std.mem.readInt(T, bytes, endian);
}

test "endianness handling" {
    const value: u32 = 0x12345678;

    const be_bytes = serializeInt(u32, value, .big);
    const le_bytes = serializeInt(u32, value, .little);

    try std.testing.expectEqual(value, deserializeInt(u32, &be_bytes, .big));
    try std.testing.expectEqual(value, deserializeInt(u32, &le_bytes, .little));

    // Big endian puts most significant byte first
    try std.testing.expectEqual(@as(u8, 0x12), be_bytes[0]);
    try std.testing.expectEqual(@as(u8, 0x78), le_bytes[0]);
}
```

### JSON Serialization

Use `std.json` for text-based serialization:

```zig
const User = struct {
    id: u32,
    name: []const u8,
    active: bool,
};

pub fn serializeToJson(allocator: std.mem.Allocator, user: User) ![]u8 {
    return std.json.stringifyAlloc(allocator, user, .{});
}

pub fn deserializeFromJson(allocator: std.mem.Allocator, json: []const u8) !User {
    const parsed = try std.json.parseFromSlice(User, allocator, json, .{});
    defer parsed.deinit();

    return User{
        .id = parsed.value.id,
        .name = try allocator.dupe(u8, parsed.value.name),
        .active = parsed.value.active,
    };
}

test "JSON serialization" {
    const allocator = std.testing.allocator;

    const user = User{
        .id = 42,
        .name = "Alice",
        .active = true,
    };

    const json = try serializeToJson(allocator, user);
    defer allocator.free(json);

    const restored = try deserializeFromJson(allocator, json);
    defer allocator.free(restored.name);

    try std.testing.expectEqual(user.id, restored.id);
    try std.testing.expectEqualStrings(user.name, restored.name);
    try std.testing.expectEqual(user.active, restored.active);
}
```

### Writing Multiple Structs

Serialize arrays of structs:

```zig
pub fn writeStructArray(comptime T: type, file: std.fs.File, items: []const T) !void {
    // Write count first
    const count: u32 = @intCast(items.len);
    try file.writeInt(u32, count, .little);

    // Write each struct
    for (items) |item| {
        const bytes = std.mem.asBytes(&item);
        try file.writeAll(bytes);
    }
}

pub fn readStructArray(comptime T: type, allocator: std.mem.Allocator, file: std.fs.File) ![]T {
    // Read count
    const count = try file.readInt(u32, .little);

    // Allocate array
    const items = try allocator.alloc(T, count);
    errdefer allocator.free(items);

    // Read each struct
    for (items) |*item| {
        const bytes = std.mem.asBytes(item);
        const n = try file.readAll(bytes);
        if (n != bytes.len) {
            return error.UnexpectedEof;
        }
    }

    return items;
}

test "struct array serialization" {
    const allocator = std.testing.allocator;

    const Point = struct {
        x: i32,
        y: i32,
    };

    const points = [_]Point{
        .{ .x = 1, .y = 2 },
        .{ .x = 3, .y = 4 },
        .{ .x = 5, .y = 6 },
    };

    const file = try std.fs.cwd().createFile("/tmp/points.bin", .{ .read = true });
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/points.bin") catch {};

    try writeStructArray(Point, file, &points);

    try file.seekTo(0);
    const loaded = try readStructArray(Point, allocator, file);
    defer allocator.free(loaded);

    try std.testing.expectEqual(points.len, loaded.len);
    for (points, loaded) |original, restored| {
        try std.testing.expectEqual(original.x, restored.x);
        try std.testing.expectEqual(original.y, restored.y);
    }
}
```

### Custom Serialization

Implement custom serialize/deserialize:

```zig
const CustomData = struct {
    version: u8,
    data: []const u8,

    pub fn serialize(self: CustomData, allocator: std.mem.Allocator) ![]u8 {
        var list = std.ArrayList(u8){};
        errdefer list.deinit(allocator);

        // Write version
        try list.append(allocator, self.version);

        // Write data length
        const len: u32 = @intCast(self.data.len);
        var len_bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &len_bytes, len, .little);
        try list.appendSlice(allocator, &len_bytes);

        // Write data
        try list.appendSlice(allocator, self.data);

        return list.toOwnedSlice(allocator);
    }

    pub fn deserialize(allocator: std.mem.Allocator, bytes: []const u8) !CustomData {
        if (bytes.len < 5) {
            return error.InvalidData;
        }

        const version = bytes[0];
        const len = std.mem.readInt(u32, bytes[1..5][0..4], .little);

        if (bytes.len < 5 + len) {
            return error.InvalidData;
        }

        const data = try allocator.dupe(u8, bytes[5 .. 5 + len]);

        return CustomData{
            .version = version,
            .data = data,
        };
    }
};

test "custom serialization" {
    const allocator = std.testing.allocator;

    const original = CustomData{
        .version = 1,
        .data = "Hello, World!",
    };

    const bytes = try original.serialize(allocator);
    defer allocator.free(bytes);

    const restored = try CustomData.deserialize(allocator, bytes);
    defer allocator.free(restored.data);

    try std.testing.expectEqual(original.version, restored.version);
    try std.testing.expectEqualStrings(original.data, restored.data);
}
```

### Versioned Serialization

Handle format versioning:

```zig
const VersionedData = struct {
    const VERSION: u8 = 2;

    id: u32,
    name: []const u8,
    extra: ?[]const u8, // Added in version 2

    pub fn serialize(self: VersionedData, allocator: std.mem.Allocator) ![]u8 {
        var list = std.ArrayList(u8){};
        errdefer list.deinit(allocator);

        // Write version
        try list.append(allocator, VERSION);

        // Write ID
        var id_bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &id_bytes, self.id, .little);
        try list.appendSlice(allocator, &id_bytes);

        // Write name length and data
        const name_len: u32 = @intCast(self.name.len);
        var name_len_bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &name_len_bytes, name_len, .little);
        try list.appendSlice(allocator, &name_len_bytes);
        try list.appendSlice(allocator, self.name);

        // Write extra (version 2+)
        if (self.extra) |extra| {
            try list.append(allocator, 1); // Has extra
            const extra_len: u32 = @intCast(extra.len);
            var extra_len_bytes: [4]u8 = undefined;
            std.mem.writeInt(u32, &extra_len_bytes, extra_len, .little);
            try list.appendSlice(allocator, &extra_len_bytes);
            try list.appendSlice(allocator, extra);
        } else {
            try list.append(allocator, 0); // No extra
        }

        return list.toOwnedSlice(allocator);
    }

    pub fn deserialize(allocator: std.mem.Allocator, bytes: []const u8) !VersionedData {
        var pos: usize = 0;

        const version = bytes[pos];
        pos += 1;

        const id = std.mem.readInt(u32, bytes[pos..][0..4], .little);
        pos += 4;

        const name_len = std.mem.readInt(u32, bytes[pos..][0..4], .little);
        pos += 4;

        const name = try allocator.dupe(u8, bytes[pos .. pos + name_len]);
        errdefer allocator.free(name);
        pos += name_len;

        var extra: ?[]const u8 = null;
        if (version >= 2) {
            const has_extra = bytes[pos];
            pos += 1;

            if (has_extra == 1) {
                const extra_len = std.mem.readInt(u32, bytes[pos..][0..4], .little);
                pos += 4;

                extra = try allocator.dupe(u8, bytes[pos .. pos + extra_len]);
            }
        }

        return VersionedData{
            .id = id,
            .name = name,
            .extra = extra,
        };
    }
};

test "versioned serialization" {
    const allocator = std.testing.allocator;

    const data = VersionedData{
        .id = 123,
        .name = "Test",
        .extra = "Extra data",
    };

    const bytes = try data.serialize(allocator);
    defer allocator.free(bytes);

    const restored = try VersionedData.deserialize(allocator, bytes);
    defer allocator.free(restored.name);
    defer if (restored.extra) |extra| allocator.free(extra);

    try std.testing.expectEqual(data.id, restored.id);
    try std.testing.expectEqualStrings(data.name, restored.name);
    try std.testing.expectEqualStrings(data.extra.?, restored.extra.?);
}
```

### Best Practices

**Binary format:**
- Use packed structs for exact control
- Handle endianness explicitly for portability
- Document struct alignment and padding
- Include version numbers in formats

**Memory management:**
```zig
const Data = struct {
    allocator: std.mem.Allocator,
    items: []Item,

    pub fn deinit(self: *Data) void {
        self.allocator.free(self.items);
    }
};
```

**Error handling:**
- Validate data before deserializing
- Check buffer sizes
- Handle version mismatches gracefully
- Use `errdefer` for cleanup on errors

**Performance:**
- Use `@bitCast` for simple types
- Avoid allocations in hot paths
- Consider using fixed-size buffers
- Profile serialization overhead

### Related Functions

- `std.mem.asBytes()` - Convert value to byte slice
- `std.mem.bytesAsValue()` - Convert bytes to value
- `std.mem.readInt()` - Read integer with endianness
- `std.mem.writeInt()` - Write integer with endianness
- `std.json.stringify()` - Serialize to JSON
- `std.json.parseFromSlice()` - Parse JSON
- `@bitCast()` - Reinterpret bits as different type
- `@sizeOf()` - Get type size in bytes
