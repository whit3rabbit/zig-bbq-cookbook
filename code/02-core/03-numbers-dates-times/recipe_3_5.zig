// Recipe 3.5: Packing/unpacking large integers from bytes
// Target Zig Version: 0.15.2
//
// This recipe demonstrates converting integers to/from byte sequences with proper
// endianness handling using std.mem functions for network protocols and binary formats.

const std = @import("std");
const testing = std.testing;
const mem = std.mem;

// ANCHOR: basic_packing
/// Pack u16 to bytes (little-endian)
pub fn packU16LE(value: u16) [2]u8 {
    var bytes: [2]u8 = undefined;
    mem.writeInt(u16, &bytes, value, .little);
    return bytes;
}

/// Pack u16 to bytes (big-endian)
pub fn packU16BE(value: u16) [2]u8 {
    var bytes: [2]u8 = undefined;
    mem.writeInt(u16, &bytes, value, .big);
    return bytes;
}

/// Pack u32 to bytes (little-endian)
pub fn packU32LE(value: u32) [4]u8 {
    var bytes: [4]u8 = undefined;
    mem.writeInt(u32, &bytes, value, .little);
    return bytes;
}

/// Pack u32 to bytes (big-endian)
pub fn packU32BE(value: u32) [4]u8 {
    var bytes: [4]u8 = undefined;
    mem.writeInt(u32, &bytes, value, .big);
    return bytes;
}

/// Pack u64 to bytes (little-endian)
pub fn packU64LE(value: u64) [8]u8 {
    var bytes: [8]u8 = undefined;
    mem.writeInt(u64, &bytes, value, .little);
    return bytes;
}

/// Pack u64 to bytes (big-endian)
pub fn packU64BE(value: u64) [8]u8 {
    var bytes: [8]u8 = undefined;
    mem.writeInt(u64, &bytes, value, .big);
    return bytes;
}

/// Pack u128 to bytes (little-endian)
pub fn packU128LE(value: u128) [16]u8 {
    var bytes: [16]u8 = undefined;
    mem.writeInt(u128, &bytes, value, .little);
    return bytes;
}

/// Pack u128 to bytes (big-endian)
pub fn packU128BE(value: u128) [16]u8 {
    var bytes: [16]u8 = undefined;
    mem.writeInt(u128, &bytes, value, .big);
    return bytes;
}

/// Unpack bytes to u16 (little-endian)
pub fn unpackU16LE(bytes: *const [2]u8) u16 {
    return mem.readInt(u16, bytes, .little);
}

/// Unpack bytes to u16 (big-endian)
pub fn unpackU16BE(bytes: *const [2]u8) u16 {
    return mem.readInt(u16, bytes, .big);
}

/// Unpack bytes to u32 (little-endian)
pub fn unpackU32LE(bytes: *const [4]u8) u32 {
    return mem.readInt(u32, bytes, .little);
}

/// Unpack bytes to u32 (big-endian)
pub fn unpackU32BE(bytes: *const [4]u8) u32 {
    return mem.readInt(u32, bytes, .big);
}

/// Unpack bytes to u64 (little-endian)
pub fn unpackU64LE(bytes: *const [8]u8) u64 {
    return mem.readInt(u64, bytes, .little);
}

/// Unpack bytes to u64 (big-endian)
pub fn unpackU64BE(bytes: *const [8]u8) u64 {
    return mem.readInt(u64, bytes, .big);
}

/// Unpack bytes to u128 (little-endian)
pub fn unpackU128LE(bytes: *const [16]u8) u128 {
    return mem.readInt(u128, bytes, .little);
}

/// Unpack bytes to u128 (big-endian)
pub fn unpackU128BE(bytes: *const [16]u8) u128 {
    return mem.readInt(u128, bytes, .big);
}
// ANCHOR_END: basic_packing

// ANCHOR: batch_operations
/// Pack signed integers (i32 example)
pub fn packI32LE(value: i32) [4]u8 {
    var bytes: [4]u8 = undefined;
    mem.writeInt(i32, &bytes, value, .little);
    return bytes;
}

/// Unpack to signed integer (i32 example)
pub fn unpackI32LE(bytes: *const [4]u8) i32 {
    return mem.readInt(i32, bytes, .little);
}

/// Pack multiple integers into byte buffer
pub fn packMultiple(buffer: []u8, values: []const u32, endian: std.builtin.Endian) !void {
    if (buffer.len < values.len * @sizeOf(u32)) return error.BufferTooSmall;

    var offset: usize = 0;
    for (values) |value| {
        mem.writeInt(u32, buffer[offset..][0..4], value, endian);
        offset += 4;
    }
}

/// Unpack multiple integers from byte buffer
pub fn unpackMultiple(
    allocator: mem.Allocator,
    buffer: []const u8,
    count: usize,
    endian: std.builtin.Endian,
) ![]u32 {
    if (buffer.len < count * @sizeOf(u32)) return error.BufferTooSmall;

    const result = try allocator.alloc(u32, count);
    errdefer allocator.free(result);

    var offset: usize = 0;
    for (result) |*value| {
        value.* = mem.readInt(u32, buffer[offset..][0..4], endian);
        offset += 4;
    }

    return result;
}
// ANCHOR_END: batch_operations

// ANCHOR: endianness_utilities
/// Pack to native endianness
pub fn packNative(value: u32) [4]u8 {
    var bytes: [4]u8 = undefined;
    const native_endian = @import("builtin").cpu.arch.endian();
    mem.writeInt(u32, &bytes, value, native_endian);
    return bytes;
}

/// Detect system endianness at compile time
pub fn isLittleEndian() bool {
    const native_endian = @import("builtin").cpu.arch.endian();
    return native_endian == .little;
}

/// Swap endianness
pub fn swapEndianness(comptime T: type, value: T) T {
    return @byteSwap(value);
}
// ANCHOR_END: endianness_utilities

test "pack u16 little-endian" {
    const bytes = packU16LE(0x1234);
    try testing.expectEqual(@as(u8, 0x34), bytes[0]);
    try testing.expectEqual(@as(u8, 0x12), bytes[1]);
}

test "pack u16 big-endian" {
    const bytes = packU16BE(0x1234);
    try testing.expectEqual(@as(u8, 0x12), bytes[0]);
    try testing.expectEqual(@as(u8, 0x34), bytes[1]);
}

test "unpack u16 little-endian" {
    const bytes = [_]u8{ 0x34, 0x12 };
    const value = unpackU16LE(&bytes);
    try testing.expectEqual(@as(u16, 0x1234), value);
}

test "unpack u16 big-endian" {
    const bytes = [_]u8{ 0x12, 0x34 };
    const value = unpackU16BE(&bytes);
    try testing.expectEqual(@as(u16, 0x1234), value);
}

test "pack and unpack u32" {
    const original: u32 = 0xDEADBEEF;

    const bytes_le = packU32LE(original);
    const unpacked_le = unpackU32LE(&bytes_le);
    try testing.expectEqual(original, unpacked_le);

    const bytes_be = packU32BE(original);
    const unpacked_be = unpackU32BE(&bytes_be);
    try testing.expectEqual(original, unpacked_be);
}

test "pack and unpack u64" {
    const original: u64 = 0x0123456789ABCDEF;

    const bytes_le = packU64LE(original);
    const unpacked_le = unpackU64LE(&bytes_le);
    try testing.expectEqual(original, unpacked_le);

    const bytes_be = packU64BE(original);
    const unpacked_be = unpackU64BE(&bytes_be);
    try testing.expectEqual(original, unpacked_be);
}

test "pack and unpack u128" {
    const original: u128 = 0x0123456789ABCDEF_FEDCBA9876543210;

    const bytes_le = packU128LE(original);
    const unpacked_le = unpackU128LE(&bytes_le);
    try testing.expectEqual(original, unpacked_le);

    const bytes_be = packU128BE(original);
    const unpacked_be = unpackU128BE(&bytes_be);
    try testing.expectEqual(original, unpacked_be);
}

test "pack signed integer" {
    const original: i32 = -12345;

    const bytes = packI32LE(original);
    const unpacked = unpackI32LE(&bytes);
    try testing.expectEqual(original, unpacked);
}

test "endianness differences" {
    const value: u32 = 0x12345678;

    const le_bytes = packU32LE(value);
    const be_bytes = packU32BE(value);

    // Little-endian: least significant byte first
    try testing.expectEqual(@as(u8, 0x78), le_bytes[0]);
    try testing.expectEqual(@as(u8, 0x56), le_bytes[1]);
    try testing.expectEqual(@as(u8, 0x34), le_bytes[2]);
    try testing.expectEqual(@as(u8, 0x12), le_bytes[3]);

    // Big-endian: most significant byte first
    try testing.expectEqual(@as(u8, 0x12), be_bytes[0]);
    try testing.expectEqual(@as(u8, 0x34), be_bytes[1]);
    try testing.expectEqual(@as(u8, 0x56), be_bytes[2]);
    try testing.expectEqual(@as(u8, 0x78), be_bytes[3]);
}

test "pack multiple integers" {
    var buffer: [12]u8 = undefined;
    const values = [_]u32{ 0x11111111, 0x22222222, 0x33333333 };

    try packMultiple(&buffer, &values, .little);

    // Verify first value
    try testing.expectEqual(@as(u8, 0x11), buffer[0]);
    try testing.expectEqual(@as(u8, 0x11), buffer[1]);
    try testing.expectEqual(@as(u8, 0x11), buffer[2]);
    try testing.expectEqual(@as(u8, 0x11), buffer[3]);
}

test "unpack multiple integers" {
    const buffer = [_]u8{
        0x11, 0x11, 0x11, 0x11,
        0x22, 0x22, 0x22, 0x22,
        0x33, 0x33, 0x33, 0x33,
    };

    const result = try unpackMultiple(testing.allocator, &buffer, 3, .little);
    defer testing.allocator.free(result);

    try testing.expectEqual(@as(usize, 3), result.len);
    try testing.expectEqual(@as(u32, 0x11111111), result[0]);
    try testing.expectEqual(@as(u32, 0x22222222), result[1]);
    try testing.expectEqual(@as(u32, 0x33333333), result[2]);
}

test "pack and unpack round-trip" {
    // Test that packing and unpacking preserves values
    const original: u64 = 0x123456789ABCDEF0;
    const packed_bytes = packU64LE(original);
    const unpacked = unpackU64LE(&packed_bytes);
    try testing.expectEqual(original, unpacked);
}

test "buffer too small error" {
    var buffer: [8]u8 = undefined;
    const values = [_]u32{ 1, 2, 3 }; // Needs 12 bytes, have 8

    const result = packMultiple(&buffer, &values, .little);
    try testing.expectError(error.BufferTooSmall, result);
}

test "native endianness" {
    const value: u32 = 0x12345678;
    const bytes = packNative(value);

    // Just verify it can be unpacked
    const native_endian = @import("builtin").cpu.arch.endian();
    const unpacked = mem.readInt(u32, &bytes, native_endian);
    try testing.expectEqual(value, unpacked);
}

test "detect endianness" {
    // Just verify the function runs
    const is_little = isLittleEndian();
    _ = is_little; // Most systems are little-endian, but don't assume
}

test "swap endianness" {
    const value: u32 = 0x12345678;
    const swapped = swapEndianness(u32, value);

    // Verify bytes are reversed
    const original_bytes = packU32LE(value);
    const swapped_bytes = packU32LE(swapped);

    try testing.expectEqual(original_bytes[0], swapped_bytes[3]);
    try testing.expectEqual(original_bytes[1], swapped_bytes[2]);
    try testing.expectEqual(original_bytes[2], swapped_bytes[1]);
    try testing.expectEqual(original_bytes[3], swapped_bytes[0]);
}

test "zero values" {
    const zero: u64 = 0;
    const bytes = packU64LE(zero);

    for (bytes) |byte| {
        try testing.expectEqual(@as(u8, 0), byte);
    }

    const unpacked = unpackU64LE(&bytes);
    try testing.expectEqual(zero, unpacked);
}

test "max values" {
    const max_u16: u16 = std.math.maxInt(u16);
    const bytes = packU16LE(max_u16);
    const unpacked = unpackU16LE(&bytes);
    try testing.expectEqual(max_u16, unpacked);

    const max_u64: u64 = std.math.maxInt(u64);
    const bytes64 = packU64LE(max_u64);
    const unpacked64 = unpackU64LE(&bytes64);
    try testing.expectEqual(max_u64, unpacked64);
}

test "network byte order (big-endian)" {
    // Network protocols typically use big-endian
    const port: u16 = 8080;
    const bytes = packU16BE(port);

    // Simulate sending over network
    const received_port = unpackU16BE(&bytes);
    try testing.expectEqual(port, received_port);
}

test "file format with mixed endianness" {
    // Some file formats mix endianness
    var buffer: [8]u8 = undefined;

    // Magic number in big-endian
    mem.writeInt(u32, buffer[0..4], 0xCAFEBABE, .big);

    // Version in little-endian
    mem.writeInt(u32, buffer[4..8], 1, .little);

    // Read back
    const magic = mem.readInt(u32, buffer[0..4], .big);
    const version = mem.readInt(u32, buffer[4..8], .little);

    try testing.expectEqual(@as(u32, 0xCAFEBABE), magic);
    try testing.expectEqual(@as(u32, 1), version);
}

test "partial buffer packing" {
    var buffer: [100]u8 = undefined;
    const value: u32 = 0x12345678;

    // Pack at different offsets
    mem.writeInt(u32, buffer[0..4], value, .little);
    mem.writeInt(u32, buffer[10..14], value, .big);

    const unpacked_le = mem.readInt(u32, buffer[0..4], .little);
    const unpacked_be = mem.readInt(u32, buffer[10..14], .big);

    try testing.expectEqual(value, unpacked_le);
    try testing.expectEqual(value, unpacked_be);
}

test "memory safety - no allocation for basic packing" {
    // Basic packing doesn't allocate
    const value: u64 = 12345;
    const bytes = packU64LE(value);
    const unpacked = unpackU64LE(&bytes);
    try testing.expectEqual(value, unpacked);
}

test "memory safety - proper cleanup for multiple unpack" {
    const buffer = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const result = try unpackMultiple(testing.allocator, &buffer, 2, .little);
    defer testing.allocator.free(result);

    try testing.expectEqual(@as(usize, 2), result.len);
}

test "security - bounds checking" {
    // Ensure we handle buffer size correctly
    const small_buffer = [_]u8{ 1, 2 };

    // Should error when trying to unpack more data than available
    const result = unpackMultiple(testing.allocator, &small_buffer, 2, .little);
    try testing.expectError(error.BufferTooSmall, result);
}
