// Recipe 5.4: Reading and writing binary data
// Target Zig Version: 0.15.2
//
// This recipe demonstrates reading and writing binary data to files, including
// integers, floats, packed structs, and handling endianness for cross-platform files.

const std = @import("std");
const testing = std.testing;

// ANCHOR: binary_integers
/// Helper to write an integer to a writer using a buffer
fn writeIntToWriter(writer: anytype, comptime T: type, value: T, endian: std.builtin.Endian) !void {
    var buf: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &buf, value, endian);
    try writer.writeAll(&buf);
}

/// Helper to read an integer by reading raw bytes
fn readIntFromFile(file: std.fs.File, comptime T: type, endian: std.builtin.Endian) !T {
    var buf: [@sizeOf(T)]u8 = undefined;
    const bytes_read = try file.read(&buf);
    if (bytes_read != @sizeOf(T)) return error.UnexpectedEndOfFile;
    return std.mem.readInt(T, &buf, endian);
}

/// Write various integer types to a binary file
pub fn writeIntegers(path: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    // Write unsigned integers
    try writeIntToWriter(writer, u8, 255, .little);
    try writeIntToWriter(writer, u16, 65535, .little);
    try writeIntToWriter(writer, u32, 4294967295, .little);
    try writeIntToWriter(writer, u64, 123456789012345, .little);

    // Write signed integers
    try writeIntToWriter(writer, i8, -128, .little);
    try writeIntToWriter(writer, i16, -32768, .little);
    try writeIntToWriter(writer, i32, -2147483648, .little);

    try writer.flush();
}

/// Read integers from a binary file
pub fn readIntegers(path: []const u8) ![7]i64 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var results: [7]i64 = undefined;
    results[0] = try readIntFromFile(file, u8, .little);
    results[1] = try readIntFromFile(file, u16, .little);
    results[2] = try readIntFromFile(file, u32, .little);
    results[3] = @intCast(try readIntFromFile(file, u64, .little));
    results[4] = try readIntFromFile(file, i8, .little);
    results[5] = try readIntFromFile(file, i16, .little);
    results[6] = try readIntFromFile(file, i32, .little);

    return results;
}
// ANCHOR_END: binary_integers

// ANCHOR: binary_structs
/// Write floating point numbers as binary
pub fn writeBinaryFloats(path: []const u8, values: []const f64) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    for (values) |value| {
        const bits: u64 = @bitCast(value);
        try writeIntToWriter(writer, u64, bits, .little);
    }

    try writer.flush();
}

/// Read floating point numbers from binary file
pub fn readBinaryFloats(
    allocator: std.mem.Allocator,
    path: []const u8,
) ![]f64 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = (try file.stat()).size;
    const count = file_size / @sizeOf(f64);

    const values = try allocator.alloc(f64, count);
    errdefer allocator.free(values);

    for (values) |*value| {
        const bits = try readIntFromFile(file, u64, .little);
        value.* = @bitCast(bits);
    }

    return values;
}

/// Binary file header structure
pub const BinaryHeader = packed struct {
    magic: u32,
    version: u16,
    flags: u16,
    data_size: u64,
};

/// Write a binary header to file
pub fn writeStructHeader(path: []const u8, header: BinaryHeader) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    try writeIntToWriter(writer, u32, header.magic, .little);
    try writeIntToWriter(writer, u16, header.version, .little);
    try writeIntToWriter(writer, u16, header.flags, .little);
    try writeIntToWriter(writer, u64, header.data_size, .little);

    try writer.flush();
}

/// Read a binary header from file
pub fn readStructHeader(path: []const u8) !BinaryHeader {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    return BinaryHeader{
        .magic = try readIntFromFile(file, u32, .little),
        .version = try readIntFromFile(file, u16, .little),
        .flags = try readIntFromFile(file, u16, .little),
        .data_size = try readIntFromFile(file, u64, .little),
    };
}

/// Write raw bytes with length prefix
pub fn writeRawBytes(path: []const u8, data: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    try writeIntToWriter(writer, u64, data.len, .little);
    try writer.writeAll(data);
    try writer.flush();
}

/// Read raw bytes with length prefix
pub fn readRawBytes(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const length = try readIntFromFile(file, u64, .little);
    const data = try allocator.alloc(u8, length);
    errdefer allocator.free(data);

    const bytes_read = try file.read(data);
    if (bytes_read != length) return error.UnexpectedEndOfFile;

    return data;
}

/// 3D point structure with binary I/O
pub const Point3D = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn write(self: Point3D, writer: anytype) !void {
        try writeIntToWriter(writer, u32, @bitCast(self.x), .little);
        try writeIntToWriter(writer, u32, @bitCast(self.y), .little);
        try writeIntToWriter(writer, u32, @bitCast(self.z), .little);
    }

    pub fn read(file: std.fs.File) !Point3D {
        return Point3D{
            .x = @bitCast(try readIntFromFile(file, u32, .little)),
            .y = @bitCast(try readIntFromFile(file, u32, .little)),
            .z = @bitCast(try readIntFromFile(file, u32, .little)),
        };
    }
};

/// Write an array of 3D points to file
pub fn writeMesh(path: []const u8, points: []const Point3D) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    try writeIntToWriter(writer, u64, points.len, .little);

    for (points) |point| {
        try point.write(writer);
    }

    try writer.flush();
}

/// Read an array of 3D points from file
pub fn readMesh(allocator: std.mem.Allocator, path: []const u8) ![]Point3D {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const count = try readIntFromFile(file, u64, .little);
    const points = try allocator.alloc(Point3D, count);
    errdefer allocator.free(points);

    for (points) |*point| {
        point.* = try Point3D.read(file);
    }

    return points;
}
// ANCHOR_END: binary_structs

// ANCHOR: endianness_validation
/// Write with big-endian byte order
pub fn writeWithBigEndian(path: []const u8, value: u32) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    try writeIntToWriter(writer, u32, value, .big);
    try writer.flush();
}

/// Read with specified endianness
pub fn readWithEndianness(path: []const u8, endian: std.builtin.Endian) !u32 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    return try readIntFromFile(file, u32, endian);
}

/// Write mixed binary data (header + payload)
pub fn writeCompleteFile(
    path: []const u8,
    magic: u32,
    data: []const u8,
) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    const header = BinaryHeader{
        .magic = magic,
        .version = 1,
        .flags = 0,
        .data_size = data.len,
    };

    try writeIntToWriter(writer, u32, header.magic, .little);
    try writeIntToWriter(writer, u16, header.version, .little);
    try writeIntToWriter(writer, u16, header.flags, .little);
    try writeIntToWriter(writer, u64, header.data_size, .little);
    try writer.writeAll(data);

    try writer.flush();
}

/// Read and validate complete binary file
pub fn readCompleteFile(
    allocator: std.mem.Allocator,
    path: []const u8,
    expected_magic: u32,
) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const header = BinaryHeader{
        .magic = try readIntFromFile(file, u32, .little),
        .version = try readIntFromFile(file, u16, .little),
        .flags = try readIntFromFile(file, u16, .little),
        .data_size = try readIntFromFile(file, u64, .little),
    };

    if (header.magic != expected_magic) return error.InvalidMagicNumber;
    if (header.data_size > 100_000_000) return error.SizeTooLarge;

    const data = try allocator.alloc(u8, header.data_size);
    errdefer allocator.free(data);

    const bytes_read = try file.read(data);
    if (bytes_read != header.data_size) return error.UnexpectedEndOfFile;

    return data;
}
// ANCHOR_END: endianness_validation

// Tests

test "write and read integers" {
    const test_path = "test_integers.bin";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    try writeIntegers(test_path);
    const results = try readIntegers(test_path);

    try testing.expectEqual(@as(i64, 255), results[0]);
    try testing.expectEqual(@as(i64, 65535), results[1]);
    try testing.expectEqual(@as(i64, 4294967295), results[2]);
    try testing.expectEqual(@as(i64, 123456789012345), results[3]);
    try testing.expectEqual(@as(i64, -128), results[4]);
    try testing.expectEqual(@as(i64, -32768), results[5]);
    try testing.expectEqual(@as(i64, -2147483648), results[6]);
}

test "write and read floats" {
    const allocator = testing.allocator;
    const test_path = "test_floats.bin";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const input = [_]f64{ 3.14159, 2.71828, 1.41421, -273.15 };
    try writeBinaryFloats(test_path, &input);

    const output = try readBinaryFloats(allocator, test_path);
    defer allocator.free(output);

    try testing.expectEqual(@as(usize, 4), output.len);
    try testing.expectApproxEqAbs(3.14159, output[0], 0.00001);
    try testing.expectApproxEqAbs(2.71828, output[1], 0.00001);
    try testing.expectApproxEqAbs(1.41421, output[2], 0.00001);
    try testing.expectApproxEqAbs(-273.15, output[3], 0.00001);
}

test "write and read struct header" {
    const test_path = "test_header.bin";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const header = BinaryHeader{
        .magic = 0x12345678,
        .version = 1,
        .flags = 0x00FF,
        .data_size = 1024,
    };

    try writeStructHeader(test_path, header);
    const read_header = try readStructHeader(test_path);

    try testing.expectEqual(header.magic, read_header.magic);
    try testing.expectEqual(header.version, read_header.version);
    try testing.expectEqual(header.flags, read_header.flags);
    try testing.expectEqual(header.data_size, read_header.data_size);
}

test "write and read raw bytes" {
    const allocator = testing.allocator;
    const test_path = "test_raw_bytes.bin";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const input = "Hello, Binary World!";
    try writeRawBytes(test_path, input);

    const output = try readRawBytes(allocator, test_path);
    defer allocator.free(output);

    try testing.expectEqualStrings(input, output);
}

test "write and read mesh" {
    const allocator = testing.allocator;
    const test_path = "test_mesh.bin";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const input_points = [_]Point3D{
        .{ .x = 1.0, .y = 2.0, .z = 3.0 },
        .{ .x = 4.0, .y = 5.0, .z = 6.0 },
        .{ .x = 7.0, .y = 8.0, .z = 9.0 },
    };

    try writeMesh(test_path, &input_points);

    const output_points = try readMesh(allocator, test_path);
    defer allocator.free(output_points);

    try testing.expectEqual(@as(usize, 3), output_points.len);
    try testing.expectApproxEqAbs(1.0, output_points[0].x, 0.0001);
    try testing.expectApproxEqAbs(2.0, output_points[0].y, 0.0001);
    try testing.expectApproxEqAbs(3.0, output_points[0].z, 0.0001);
    try testing.expectApproxEqAbs(7.0, output_points[2].x, 0.0001);
    try testing.expectApproxEqAbs(8.0, output_points[2].y, 0.0001);
    try testing.expectApproxEqAbs(9.0, output_points[2].z, 0.0001);
}

test "big-endian vs little-endian" {
    const test_path = "test_endian.bin";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const value: u32 = 0x12345678;
    try writeWithBigEndian(test_path, value);

    const big_result = try readWithEndianness(test_path, .big);
    try testing.expectEqual(value, big_result);

    // Reading with wrong endianness gives swapped bytes
    const little_result = try readWithEndianness(test_path, .little);
    try testing.expectEqual(@as(u32, 0x78563412), little_result);
}

test "complete file with validation" {
    const allocator = testing.allocator;
    const test_path = "test_complete.bin";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const magic: u32 = 0xDEADBEEF;
    const data = "Test payload data";

    try writeCompleteFile(test_path, magic, data);

    const output = try readCompleteFile(allocator, test_path, magic);
    defer allocator.free(output);

    try testing.expectEqualStrings(data, output);
}

test "invalid magic number" {
    const allocator = testing.allocator;
    const test_path = "test_bad_magic.bin";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    try writeCompleteFile(test_path, 0x12345678, "data");

    const result = readCompleteFile(allocator, test_path, 0xABCDEF00);
    try testing.expectError(error.InvalidMagicNumber, result);
}

test "empty binary data" {
    const allocator = testing.allocator;
    const test_path = "test_empty.bin";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    try writeRawBytes(test_path, "");

    const output = try readRawBytes(allocator, test_path);
    defer allocator.free(output);

    try testing.expectEqual(@as(usize, 0), output.len);
}

test "large binary array" {
    const allocator = testing.allocator;
    const test_path = "test_large.bin";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create array of 1000 floats
    const input = try allocator.alloc(f64, 1000);
    defer allocator.free(input);

    for (input, 0..) |*val, i| {
        val.* = @as(f64, @floatFromInt(i)) * 1.5;
    }

    try writeBinaryFloats(test_path, input);

    const output = try readBinaryFloats(allocator, test_path);
    defer allocator.free(output);

    try testing.expectEqual(input.len, output.len);
    for (input, output) |in, out| {
        try testing.expectApproxEqAbs(in, out, 0.0001);
    }
}

test "memory safety with errdefer" {
    const allocator = testing.allocator;
    const test_path = "test_truncated.bin";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Write incomplete file
    const file = try std.fs.cwd().createFile(test_path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    // Write length but no data
    try writeIntToWriter(writer, u64, 100, .little);
    try writer.flush();

    // This should fail and not leak memory
    const result = readRawBytes(allocator, test_path);
    try testing.expectError(error.UnexpectedEndOfFile, result);
}

test "binary file size calculation" {
    const test_path = "test_size.bin";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const values = [_]f64{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    try writeBinaryFloats(test_path, &values);

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const file_size = (try file.stat()).size;
    const expected_size = values.len * @sizeOf(f64);

    try testing.expectEqual(expected_size, file_size);
}
