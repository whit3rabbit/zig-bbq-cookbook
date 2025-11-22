// Recipe 3.4: Working with binary, octal, and hexadecimal integers
// Target Zig Version: 0.15.2
//
// This recipe demonstrates working with integers in different bases: binary, octal,
// and hexadecimal - including parsing, conversion, and bitwise operations.

const std = @import("std");
const testing = std.testing;
const fmt = std.fmt;
const mem = std.mem;

// ANCHOR: parsing_bases
/// Parse binary string to integer
pub fn parseBinary(str: []const u8) !u64 {
    if (str.len == 0) return error.InvalidBinary;
    var result: u64 = 0;
    for (str) |c| {
        const digit: u64 = switch (c) {
            '0' => 0,
            '1' => 1,
            ' ', '_' => continue, // Allow separators
            else => return error.InvalidBinary,
        };
        result = result * 2 + digit;
    }
    return result;
}

/// Parse octal string to integer
pub fn parseOctal(str: []const u8) !u64 {
    var result: u64 = 0;
    for (str) |c| {
        const digit: u64 = switch (c) {
            '0'...'7' => c - '0',
            ' ', '_' => continue, // Allow separators
            else => return error.InvalidOctal,
        };
        result = result * 8 + digit;
    }
    return result;
}

/// Parse hexadecimal string to integer
pub fn parseHex(str: []const u8) !u64 {
    var result: u64 = 0;
    for (str) |c| {
        const digit: u64 = switch (c) {
            '0'...'9' => c - '0',
            'a'...'f' => c - 'a' + 10,
            'A'...'F' => c - 'A' + 10,
            ' ', '_' => continue, // Allow separators
            else => return error.InvalidHex,
        };
        result = result * 16 + digit;
    }
    return result;
}

/// Parse integer with prefix (0b, 0o, 0x)
pub fn parseWithPrefix(str: []const u8) !u64 {
    if (str.len < 2) return error.InvalidFormat;

    if (mem.startsWith(u8, str, "0b") or mem.startsWith(u8, str, "0B")) {
        return parseBinary(str[2..]);
    } else if (mem.startsWith(u8, str, "0o") or mem.startsWith(u8, str, "0O")) {
        return parseOctal(str[2..]);
    } else if (mem.startsWith(u8, str, "0x") or mem.startsWith(u8, str, "0X")) {
        return parseHex(str[2..]);
    } else {
        // Try parsing as decimal
        return fmt.parseInt(u64, str, 10);
    }
}
// ANCHOR_END: parsing_bases

// ANCHOR: converting_bases
/// Convert integer to binary string
pub fn toBinary(allocator: mem.Allocator, value: u64) ![]u8 {
    return fmt.allocPrint(allocator, "{b}", .{value});
}

/// Convert integer to octal string
pub fn toOctal(allocator: mem.Allocator, value: u64) ![]u8 {
    return fmt.allocPrint(allocator, "{o}", .{value});
}

/// Convert integer to hexadecimal string
pub fn toHex(allocator: mem.Allocator, value: u64, uppercase: bool) ![]u8 {
    if (uppercase) {
        return fmt.allocPrint(allocator, "{X}", .{value});
    } else {
        return fmt.allocPrint(allocator, "{x}", .{value});
    }
}
// ANCHOR_END: converting_bases

// ANCHOR: bitwise_operations
/// Count set bits (population count)
pub fn countSetBits(value: u64) u8 {
    return @popCount(value);
}

/// Get bit at position
pub fn getBit(value: u64, position: u6) bool {
    return (value & (@as(u64, 1) << position)) != 0;
}

/// Set bit at position
pub fn setBit(value: u64, position: u6) u64 {
    return value | (@as(u64, 1) << position);
}

/// Clear bit at position
pub fn clearBit(value: u64, position: u6) u64 {
    return value & ~(@as(u64, 1) << position);
}

/// Toggle bit at position
pub fn toggleBit(value: u64, position: u6) u64 {
    return value ^ (@as(u64, 1) << position);
}

/// Rotate left
pub fn rotateLeft(value: u64, amount: u6) u64 {
    return std.math.rotl(u64, value, amount);
}

/// Rotate right
pub fn rotateRight(value: u64, amount: u6) u64 {
    return std.math.rotr(u64, value, amount);
}

/// Reverse bits
pub fn reverseBits(value: u64) u64 {
    return @bitReverse(value);
}

/// Get lowest set bit position
pub fn lowestSetBit(value: u64) ?u7 {
    if (value == 0) return null;
    return @ctz(value);
}

/// Get highest set bit position
pub fn highestSetBit(value: u64) ?u7 {
    if (value == 0) return null;
    return @as(u7, @intCast(63 - @clz(value)));
}

/// Check if power of two
pub fn isPowerOfTwo(value: u64) bool {
    return value != 0 and (value & (value - 1)) == 0;
}

/// Get next power of two
pub fn nextPowerOfTwo(value: u64) u64 {
    if (value == 0) return 1;
    if (isPowerOfTwo(value)) return value;

    var v = value;
    v -= 1;
    v |= v >> 1;
    v |= v >> 2;
    v |= v >> 4;
    v |= v >> 8;
    v |= v >> 16;
    v |= v >> 32;
    v += 1;
    return v;
}
// ANCHOR_END: bitwise_operations

test "parse binary string" {
    try testing.expectEqual(@as(u64, 5), try parseBinary("101"));
    try testing.expectEqual(@as(u64, 15), try parseBinary("1111"));
    try testing.expectEqual(@as(u64, 0), try parseBinary("0"));
}

test "parse binary with separators" {
    try testing.expectEqual(@as(u64, 255), try parseBinary("1111_1111"));
    try testing.expectEqual(@as(u64, 42), try parseBinary("10 10 10"));
}

test "parse octal string" {
    try testing.expectEqual(@as(u64, 8), try parseOctal("10"));
    try testing.expectEqual(@as(u64, 64), try parseOctal("100"));
    try testing.expectEqual(@as(u64, 511), try parseOctal("777"));
}

test "parse hex string" {
    try testing.expectEqual(@as(u64, 255), try parseHex("FF"));
    try testing.expectEqual(@as(u64, 255), try parseHex("ff"));
    try testing.expectEqual(@as(u64, 4096), try parseHex("1000"));
}

test "parse hex with separators" {
    try testing.expectEqual(@as(u64, 0xDEADBEEF), try parseHex("DEAD_BEEF"));
}

test "parse with prefix" {
    try testing.expectEqual(@as(u64, 5), try parseWithPrefix("0b101"));
    try testing.expectEqual(@as(u64, 64), try parseWithPrefix("0o100"));
    try testing.expectEqual(@as(u64, 255), try parseWithPrefix("0xFF"));
    try testing.expectEqual(@as(u64, 42), try parseWithPrefix("42"));
}

test "parse errors" {
    try testing.expectError(error.InvalidBinary, parseBinary("102"));
    try testing.expectError(error.InvalidOctal, parseOctal("8"));
    try testing.expectError(error.InvalidHex, parseHex("XYZ"));
}

test "convert to binary" {
    const result = try toBinary(testing.allocator, 42);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("101010", result);
}

test "convert to octal" {
    const result = try toOctal(testing.allocator, 64);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("100", result);
}

test "convert to hex" {
    const result = try toHex(testing.allocator, 255, false);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("ff", result);
}

test "count set bits" {
    try testing.expectEqual(@as(u8, 0), countSetBits(0));
    try testing.expectEqual(@as(u8, 1), countSetBits(1));
    try testing.expectEqual(@as(u8, 3), countSetBits(0b111));
    try testing.expectEqual(@as(u8, 8), countSetBits(0xFF));
}

test "get bit" {
    const value: u64 = 0b1010;
    try testing.expect(!getBit(value, 0));
    try testing.expect(getBit(value, 1));
    try testing.expect(!getBit(value, 2));
    try testing.expect(getBit(value, 3));
}

test "set bit" {
    const value: u64 = 0b1000;
    const result = setBit(value, 0);
    try testing.expectEqual(@as(u64, 0b1001), result);
}

test "clear bit" {
    const value: u64 = 0b1111;
    const result = clearBit(value, 1);
    try testing.expectEqual(@as(u64, 0b1101), result);
}

test "toggle bit" {
    const value: u64 = 0b1010;
    const result1 = toggleBit(value, 0);
    try testing.expectEqual(@as(u64, 0b1011), result1);

    const result2 = toggleBit(value, 1);
    try testing.expectEqual(@as(u64, 0b1000), result2);
}

test "rotate left" {
    const value: u64 = 0b1010;
    const result = rotateLeft(value, 1);
    // Rotates all 64 bits
    try testing.expect(result != value);
}

test "rotate right" {
    const value: u64 = 0b1010;
    const result = rotateRight(value, 1);
    try testing.expect(result != value);
}

test "reverse bits" {
    const value: u64 = 0b1010;
    const result = reverseBits(value);
    // Reverses all 64 bits
    try testing.expect(result != value);
}

test "lowest set bit" {
    try testing.expectEqual(@as(?u7, null), lowestSetBit(0));
    try testing.expectEqual(@as(u7, 0), lowestSetBit(1).?);
    try testing.expectEqual(@as(u7, 1), lowestSetBit(0b1010).?);
    try testing.expectEqual(@as(u7, 3), lowestSetBit(0b1000).?);
}

test "highest set bit" {
    try testing.expectEqual(@as(?u7, null), highestSetBit(0));
    try testing.expectEqual(@as(u7, 0), highestSetBit(1).?);
    try testing.expectEqual(@as(u7, 3), highestSetBit(0b1010).?);
    try testing.expectEqual(@as(u7, 7), highestSetBit(0xFF).?);
}

test "is power of two" {
    try testing.expect(isPowerOfTwo(1));
    try testing.expect(isPowerOfTwo(2));
    try testing.expect(isPowerOfTwo(4));
    try testing.expect(isPowerOfTwo(8));
    try testing.expect(!isPowerOfTwo(0));
    try testing.expect(!isPowerOfTwo(3));
    try testing.expect(!isPowerOfTwo(6));
}

test "next power of two" {
    try testing.expectEqual(@as(u64, 1), nextPowerOfTwo(0));
    try testing.expectEqual(@as(u64, 1), nextPowerOfTwo(1));
    try testing.expectEqual(@as(u64, 4), nextPowerOfTwo(3));
    try testing.expectEqual(@as(u64, 8), nextPowerOfTwo(5));
    try testing.expectEqual(@as(u64, 16), nextPowerOfTwo(9));
    try testing.expectEqual(@as(u64, 8), nextPowerOfTwo(8));
}

test "bitwise AND operation" {
    const a: u64 = 0b1100;
    const b: u64 = 0b1010;
    const result = a & b;
    try testing.expectEqual(@as(u64, 0b1000), result);
}

test "bitwise OR operation" {
    const a: u64 = 0b1100;
    const b: u64 = 0b1010;
    const result = a | b;
    try testing.expectEqual(@as(u64, 0b1110), result);
}

test "bitwise XOR operation" {
    const a: u64 = 0b1100;
    const b: u64 = 0b1010;
    const result = a ^ b;
    try testing.expectEqual(@as(u64, 0b0110), result);
}

test "bitwise NOT operation" {
    const value: u8 = 0b1010;
    const result = ~value;
    try testing.expectEqual(@as(u8, 0b11110101), result);
}

test "left shift" {
    const value: u64 = 0b1010;
    const result = value << 2;
    try testing.expectEqual(@as(u64, 0b101000), result);
}

test "right shift" {
    const value: u64 = 0b1010;
    const result = value >> 1;
    try testing.expectEqual(@as(u64, 0b101), result);
}

test "extract bits" {
    const value: u64 = 0b11110000;
    // Extract lower 4 bits
    const lower = value & 0b1111;
    try testing.expectEqual(@as(u64, 0), lower);

    // Extract upper 4 bits
    const upper = (value >> 4) & 0b1111;
    try testing.expectEqual(@as(u64, 0b1111), upper);
}

test "memory safety - no allocation for bitwise ops" {
    // All bitwise operations are pure integer operations
    const value: u64 = 42;
    const result1 = setBit(value, 0);
    const result2 = clearBit(value, 1);
    const result3 = toggleBit(value, 2);

    try testing.expect(result1 != value);
    try testing.expect(result2 != value);
    try testing.expect(result3 != value);
}

test "security - parse bounds checking" {
    // Empty string
    try testing.expectError(error.InvalidBinary, parseBinary(""));

    // Very long valid string should work
    const long_binary = "1" ** 64;
    _ = try parseBinary(long_binary[0..63]); // 63 ones is valid u64
}
