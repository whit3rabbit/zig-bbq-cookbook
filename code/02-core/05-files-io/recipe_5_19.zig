const std = @import("std");

/// Simple struct for testing
const Person = struct {
    age: u32,
    height: f32,
    name: [20]u8,
};

/// Serialize struct to file
pub fn serializeToDisk(file: std.fs.File, person: Person) !void {
    const bytes = std.mem.asBytes(&person);
    try file.writeAll(bytes);
}

/// Deserialize struct from file
pub fn deserializeFromDisk(file: std.fs.File) !Person {
    var person: Person = undefined;
    const bytes = std.mem.asBytes(&person);
    const n = try file.readAll(bytes);

    if (n != bytes.len) {
        return error.UnexpectedEof;
    }

    return person;
}

/// Convert struct to byte slice
pub fn structToBytes(comptime T: type, value: *const T) []const u8 {
    return std.mem.asBytes(value);
}

/// Convert bytes to struct
pub fn bytesToStruct(comptime T: type, bytes: []const u8) !T {
    if (bytes.len != @sizeOf(T)) {
        return error.InvalidSize;
    }

    var value: T = undefined;
    @memcpy(std.mem.asBytes(&value), bytes);
    return value;
}

/// Packed struct for binary layouts
pub const PackedData = packed struct {
    flags: u8,
    value: u16,
    id: u32,
};

/// Serialize packed struct
pub fn serializePacked(data: PackedData) [@sizeOf(PackedData)]u8 {
    var bytes: [@sizeOf(PackedData)]u8 = undefined;
    @memcpy(std.mem.asBytes(&bytes), std.mem.asBytes(&data));
    return bytes;
}

/// Deserialize packed struct
pub fn deserializePacked(bytes: [@sizeOf(PackedData)]u8) PackedData {
    var data: PackedData = undefined;
    @memcpy(std.mem.asBytes(&data), std.mem.asBytes(&bytes));
    return data;
}

/// Serialize integer with endianness
pub fn serializeInt(comptime T: type, value: T, endian: std.builtin.Endian) [@sizeOf(T)]u8 {
    var bytes: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &bytes, value, endian);
    return bytes;
}

/// Deserialize integer with endianness
pub fn deserializeInt(comptime T: type, bytes: *const [@sizeOf(T)]u8, endian: std.builtin.Endian) T {
    return std.mem.readInt(T, bytes, endian);
}

/// User struct for JSON serialization
const User = struct {
    id: u32,
    name: []const u8,
    active: bool,
};

/// Serialize to JSON (manual implementation for Zig 0.15.2)
pub fn serializeToJson(allocator: std.mem.Allocator, user: User) ![]u8 {
    return std.fmt.allocPrint(allocator,
        \\{{"id":{d},"name":"{s}","active":{s}}}
    , .{ user.id, user.name, if (user.active) "true" else "false" });
}

/// Deserialize from JSON
pub fn deserializeFromJson(allocator: std.mem.Allocator, json: []const u8) !User {
    const parsed = try std.json.parseFromSlice(User, allocator, json, .{});
    defer parsed.deinit();

    return User{
        .id = parsed.value.id,
        .name = try allocator.dupe(u8, parsed.value.name),
        .active = parsed.value.active,
    };
}

/// Write array of structs to file
pub fn writeStructArray(comptime T: type, file: std.fs.File, items: []const T) !void {
    // Write count first
    const count: u32 = @intCast(items.len);
    var count_bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &count_bytes, count, .little);
    try file.writeAll(&count_bytes);

    // Write each struct
    for (items) |item| {
        const bytes = std.mem.asBytes(&item);
        try file.writeAll(bytes);
    }
}

/// Read array of structs from file
pub fn readStructArray(comptime T: type, allocator: std.mem.Allocator, file: std.fs.File) ![]T {
    // Read count
    var count_bytes: [4]u8 = undefined;
    const n = try file.readAll(&count_bytes);
    if (n != 4) {
        return error.UnexpectedEof;
    }
    const count = std.mem.readInt(u32, &count_bytes, .little);

    // Allocate array
    const items = try allocator.alloc(T, count);
    errdefer allocator.free(items);

    // Read each struct
    for (items) |*item| {
        const bytes = std.mem.asBytes(item);
        const bytes_read = try file.readAll(bytes);
        if (bytes_read != bytes.len) {
            return error.UnexpectedEof;
        }
    }

    return items;
}

/// Custom data with custom serialization
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

/// Versioned data structure
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

// Tests

// ANCHOR: basic_serialization
test "serialize to disk" {
    var person = Person{
        .age = 30,
        .height = 1.75,
        .name = undefined,
    };
    @memcpy(&person.name, "Alice" ++ ([_]u8{0} ** 15));

    const file = try std.fs.cwd().createFile("/tmp/person.bin", .{ .read = true });
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/person.bin") catch {};

    try serializeToDisk(file, person);

    try file.seekTo(0);
    const loaded = try deserializeFromDisk(file);

    try std.testing.expectEqual(person.age, loaded.age);
    try std.testing.expectEqual(person.height, loaded.height);
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

test "bytes to struct size validation" {
    const Point = struct {
        x: i32,
        y: i32,
    };

    const bad_bytes = [_]u8{1} ** 4; // Too small
    const result = bytesToStruct(Point, &bad_bytes);

    try std.testing.expectError(error.InvalidSize, result);
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

test "packed struct size" {
    // Note: @sizeOf returns alignment-adjusted size (8), @bitSizeOf returns 56 (7 bytes)
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(PackedData));
    try std.testing.expectEqual(@as(usize, 56), @bitSizeOf(PackedData));
}
// ANCHOR_END: basic_serialization

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

// ANCHOR: endianness_handling
test "endianness different values" {
    const value: u16 = 0xABCD;

    const be_bytes = serializeInt(u16, value, .big);
    const le_bytes = serializeInt(u16, value, .little);

    try std.testing.expectEqual(@as(u8, 0xAB), be_bytes[0]);
    try std.testing.expectEqual(@as(u8, 0xCD), be_bytes[1]);
    try std.testing.expectEqual(@as(u8, 0xCD), le_bytes[0]);
    try std.testing.expectEqual(@as(u8, 0xAB), le_bytes[1]);
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

test "JSON contains expected fields" {
    const allocator = std.testing.allocator;

    const user = User{
        .id = 123,
        .name = "Bob",
        .active = false,
    };

    const json = try serializeToJson(allocator, user);
    defer allocator.free(json);

    // Verify JSON contains expected data
    try std.testing.expect(std.mem.indexOf(u8, json, "123") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "Bob") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "false") != null);
}
// ANCHOR_END: endianness_handling

// ANCHOR: array_serialization
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

test "empty struct array" {
    const allocator = std.testing.allocator;

    const Point = struct {
        x: i32,
        y: i32,
    };

    const points: []const Point = &.{};

    const file = try std.fs.cwd().createFile("/tmp/empty_points.bin", .{ .read = true });
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/empty_points.bin") catch {};

    try writeStructArray(Point, file, points);

    try file.seekTo(0);
    const loaded = try readStructArray(Point, allocator, file);
    defer allocator.free(loaded);

    try std.testing.expectEqual(@as(usize, 0), loaded.len);
}
// ANCHOR_END: array_serialization

// ANCHOR: custom_serialization
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

test "custom serialization empty data" {
    const allocator = std.testing.allocator;

    const original = CustomData{
        .version = 5,
        .data = "",
    };

    const bytes = try original.serialize(allocator);
    defer allocator.free(bytes);

    const restored = try CustomData.deserialize(allocator, bytes);
    defer allocator.free(restored.data);

    try std.testing.expectEqual(original.version, restored.version);
    try std.testing.expectEqual(@as(usize, 0), restored.data.len);
}

test "custom deserialization invalid data" {
    const allocator = std.testing.allocator;

    const bad_bytes = [_]u8{1} ** 3; // Too small
    const result = CustomData.deserialize(allocator, &bad_bytes);

    try std.testing.expectError(error.InvalidData, result);
}

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

test "versioned serialization without extra" {
    const allocator = std.testing.allocator;

    const data = VersionedData{
        .id = 456,
        .name = "NoExtra",
        .extra = null,
    };

    const bytes = try data.serialize(allocator);
    defer allocator.free(bytes);

    const restored = try VersionedData.deserialize(allocator, bytes);
    defer allocator.free(restored.name);

    try std.testing.expectEqual(data.id, restored.id);
    try std.testing.expectEqualStrings(data.name, restored.name);
    try std.testing.expectEqual(@as(?[]const u8, null), restored.extra);
}

test "versioned data includes version" {
    const allocator = std.testing.allocator;

    const data = VersionedData{
        .id = 789,
        .name = "Versioned",
        .extra = "Data",
    };

    const bytes = try data.serialize(allocator);
    defer allocator.free(bytes);

    // First byte should be version
    try std.testing.expectEqual(VersionedData.VERSION, bytes[0]);
}

test "size calculation" {
    const Point = struct {
        x: i32,
        y: i32,
    };

    try std.testing.expectEqual(@as(usize, 8), @sizeOf(Point));

    const point = Point{ .x = 0, .y = 0 };
    const bytes = structToBytes(Point, &point);

    try std.testing.expectEqual(@sizeOf(Point), bytes.len);
}
// ANCHOR_END: custom_serialization
