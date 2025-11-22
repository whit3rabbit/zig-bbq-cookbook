const std = @import("std");

// ANCHOR: basic_hex_conversion
/// Convert bytes to hexadecimal string (lowercase)
pub fn bytesToHex(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    var list = std.ArrayList(u8){};
    errdefer list.deinit(allocator);

    for (bytes) |byte| {
        try list.writer(allocator).print("{x:0>2}", .{byte});
    }

    return list.toOwnedSlice(allocator);
}

/// Convert hexadecimal string to bytes
pub fn hexToBytes(allocator: std.mem.Allocator, hex: []const u8) ![]u8 {
    if (hex.len % 2 != 0) {
        return error.InvalidHexLength;
    }

    var result = try allocator.alloc(u8, hex.len / 2);
    errdefer allocator.free(result);

    for (0..result.len) |i| {
        const high = try hexCharToNibble(hex[i * 2]);
        const low = try hexCharToNibble(hex[i * 2 + 1]);
        result[i] = (high << 4) | low;
    }

    return result;
}
// ANCHOR_END: basic_hex_conversion

/// Convert hex character to nibble (4 bits)
fn hexCharToNibble(char: u8) !u8 {
    return switch (char) {
        '0'...'9' => char - '0',
        'a'...'f' => char - 'a' + 10,
        'A'...'F' => char - 'A' + 10,
        else => error.InvalidHexCharacter,
    };
}

/// Convert bytes to hexadecimal string (uppercase)
pub fn bytesToHexUpper(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    var list = std.ArrayList(u8){};
    errdefer list.deinit(allocator);

    for (bytes) |byte| {
        try list.writer(allocator).print("{X:0>2}", .{byte});
    }

    return list.toOwnedSlice(allocator);
}

/// Convert bytes to hex with separator
pub fn bytesToHexWithSep(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    separator: []const u8,
) ![]u8 {
    if (bytes.len == 0) {
        return allocator.alloc(u8, 0);
    }

    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    for (bytes, 0..) |byte, i| {
        if (i > 0) {
            try result.appendSlice(allocator, separator);
        }
        const hex = try std.fmt.allocPrint(allocator, "{x:0>2}", .{byte});
        defer allocator.free(hex);
        try result.appendSlice(allocator, hex);
    }

    return result.toOwnedSlice(allocator);
}

// ANCHOR: hex_dump
/// Create hex dump with ASCII representation
pub fn hexDump(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    var offset: usize = 0;
    while (offset < bytes.len) {
        const line_len = @min(16, bytes.len - offset);
        const line = bytes[offset .. offset + line_len];

        // Offset
        const offset_str = try std.fmt.allocPrint(allocator, "{x:0>8}  ", .{offset});
        defer allocator.free(offset_str);
        try result.appendSlice(allocator, offset_str);

        // Hex bytes
        for (line, 0..) |byte, i| {
            if (i == 8) {
                try result.append(allocator, ' ');
            }
            const hex = try std.fmt.allocPrint(allocator, "{x:0>2} ", .{byte});
            defer allocator.free(hex);
            try result.appendSlice(allocator, hex);
        }

        // Padding
        if (line_len < 16) {
            var i: usize = line_len;
            while (i < 16) : (i += 1) {
                try result.appendSlice(allocator, "   ");
                if (i == 7) {
                    try result.append(allocator, ' ');
                }
            }
        }

        // ASCII
        try result.appendSlice(allocator, " |");
        for (line) |byte| {
            const char = if (std.ascii.isPrint(byte)) byte else '.';
            try result.append(allocator, char);
        }
        try result.appendSlice(allocator, "|\n");

        offset += line_len;
    }

    return result.toOwnedSlice(allocator);
}
// ANCHOR_END: hex_dump

/// Convert u32 to hex string
pub fn u32ToHex(allocator: std.mem.Allocator, value: u32) ![]u8 {
    return std.fmt.allocPrint(allocator, "{x}", .{value});
}

/// Convert u32 to padded hex string
pub fn u32ToHexPadded(allocator: std.mem.Allocator, value: u32) ![]u8 {
    return std.fmt.allocPrint(allocator, "{x:0>8}", .{value});
}

/// Parse hex string to u32
pub fn hexToU32(hex: []const u8) !u32 {
    return try std.fmt.parseInt(u32, hex, 16);
}

/// Parse hex string to u64
pub fn hexToU64(hex: []const u8) !u64 {
    return try std.fmt.parseInt(u64, hex, 16);
}

/// Check if string is valid hexadecimal
pub fn isValidHex(hex: []const u8) bool {
    if (hex.len == 0 or hex.len % 2 != 0) {
        return false;
    }

    for (hex) |char| {
        switch (char) {
            '0'...'9', 'a'...'f', 'A'...'F' => {},
            else => return false,
        }
    }

    return true;
}

// ANCHOR: advanced_hex_ops
/// Encode bytes to hex in pre-allocated buffer
pub fn bytesToHexBuf(bytes: []const u8, out: []u8) !void {
    if (out.len < bytes.len * 2) {
        return error.BufferTooSmall;
    }

    const hex_chars = "0123456789abcdef";
    for (bytes, 0..) |byte, i| {
        out[i * 2] = hex_chars[byte >> 4];
        out[i * 2 + 1] = hex_chars[byte & 0x0F];
    }
}

/// Decode hex string to bytes, skipping invalid characters
pub fn hexToBytesLenient(allocator: std.mem.Allocator, hex: []const u8) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i + 1 < hex.len) {
        const high = hexCharToNibble(hex[i]) catch {
            i += 1;
            continue;
        };
        const low = hexCharToNibble(hex[i + 1]) catch {
            i += 1;
            continue;
        };

        try result.append(allocator, (high << 4) | low);
        i += 2;
    }

    return result.toOwnedSlice(allocator);
}
// ANCHOR_END: advanced_hex_ops

// Tests

test "bytes to hex" {
    const allocator = std.testing.allocator;

    const bytes = [_]u8{ 0xDE, 0xAD, 0xBE, 0xEF };
    const hex = try bytesToHex(allocator, &bytes);
    defer allocator.free(hex);

    try std.testing.expectEqualStrings("deadbeef", hex);
}

test "hex to bytes" {
    const allocator = std.testing.allocator;

    const bytes = try hexToBytes(allocator, "deadbeef");
    defer allocator.free(bytes);

    try std.testing.expectEqual(@as(usize, 4), bytes.len);
    try std.testing.expectEqual(@as(u8, 0xDE), bytes[0]);
    try std.testing.expectEqual(@as(u8, 0xAD), bytes[1]);
    try std.testing.expectEqual(@as(u8, 0xBE), bytes[2]);
    try std.testing.expectEqual(@as(u8, 0xEF), bytes[3]);
}

test "bytes to hex uppercase" {
    const allocator = std.testing.allocator;

    const bytes = [_]u8{ 0xDE, 0xAD, 0xBE, 0xEF };
    const hex = try bytesToHexUpper(allocator, &bytes);
    defer allocator.free(hex);

    try std.testing.expectEqualStrings("DEADBEEF", hex);
}

test "hex with separator" {
    const allocator = std.testing.allocator;

    const bytes = [_]u8{ 0xDE, 0xAD, 0xBE, 0xEF };
    const hex = try bytesToHexWithSep(allocator, &bytes, ":");
    defer allocator.free(hex);

    try std.testing.expectEqualStrings("de:ad:be:ef", hex);
}

test "hex with space separator" {
    const allocator = std.testing.allocator;

    const bytes = [_]u8{ 0x01, 0x02, 0x03 };
    const hex = try bytesToHexWithSep(allocator, &bytes, " ");
    defer allocator.free(hex);

    try std.testing.expectEqualStrings("01 02 03", hex);
}

test "hex dump" {
    const allocator = std.testing.allocator;

    const bytes = "Hello, World!\x00\xFF";
    const dump = try hexDump(allocator, bytes);
    defer allocator.free(dump);

    try std.testing.expect(std.mem.indexOf(u8, dump, "48 65 6c 6c") != null);
    try std.testing.expect(std.mem.indexOf(u8, dump, "|Hello, World") != null);
}

test "integer to hex" {
    const allocator = std.testing.allocator;

    const hex1 = try u32ToHex(allocator, 0xDEADBEEF);
    defer allocator.free(hex1);
    try std.testing.expectEqualStrings("deadbeef", hex1);

    const hex2 = try u32ToHexPadded(allocator, 0x42);
    defer allocator.free(hex2);
    try std.testing.expectEqualStrings("00000042", hex2);
}

test "hex to integer" {
    try std.testing.expectEqual(@as(u32, 0xDEADBEEF), try hexToU32("DEADBEEF"));
    try std.testing.expectEqual(@as(u32, 0xDEADBEEF), try hexToU32("deadbeef"));
    try std.testing.expectEqual(@as(u64, 0x123456789ABCDEF0), try hexToU64("123456789ABCDEF0"));
}

test "validate hex" {
    try std.testing.expect(isValidHex("deadbeef"));
    try std.testing.expect(isValidHex("DEADBEEF"));
    try std.testing.expect(isValidHex("0123456789abcdefABCDEF0f"));

    try std.testing.expect(!isValidHex("xyz"));
    try std.testing.expect(!isValidHex("dead ")); // contains space
    try std.testing.expect(!isValidHex(""));
    try std.testing.expect(!isValidHex("abc")); // odd length
}

test "hex to buffer" {
    const bytes = [_]u8{ 0xDE, 0xAD, 0xBE, 0xEF };
    var buf: [8]u8 = undefined;

    try bytesToHexBuf(&bytes, &buf);

    try std.testing.expectEqualStrings("deadbeef", &buf);
}

test "hex to buffer too small" {
    const bytes = [_]u8{ 0xDE, 0xAD, 0xBE, 0xEF };
    var buf: [6]u8 = undefined;

    const result = bytesToHexBuf(&bytes, &buf);
    try std.testing.expectError(error.BufferTooSmall, result);
}

test "hex lenient parsing" {
    const allocator = std.testing.allocator;

    const bytes = try hexToBytesLenient(allocator, "de:ad:be:ef");
    defer allocator.free(bytes);

    try std.testing.expectEqual(@as(usize, 4), bytes.len);
    try std.testing.expectEqual(@as(u8, 0xDE), bytes[0]);
    try std.testing.expectEqual(@as(u8, 0xAD), bytes[1]);
}

test "hex lenient with spaces" {
    const allocator = std.testing.allocator;

    const bytes = try hexToBytesLenient(allocator, "de ad be ef");
    defer allocator.free(bytes);

    try std.testing.expectEqual(@as(usize, 4), bytes.len);
}

test "empty bytes to hex" {
    const allocator = std.testing.allocator;

    const bytes: []const u8 = &.{};
    const hex = try bytesToHex(allocator, bytes);
    defer allocator.free(hex);

    try std.testing.expectEqualStrings("", hex);
}

test "empty hex to bytes" {
    const allocator = std.testing.allocator;

    const bytes = try hexToBytes(allocator, "");
    defer allocator.free(bytes);

    try std.testing.expectEqual(@as(usize, 0), bytes.len);
}

test "single byte hex" {
    const allocator = std.testing.allocator;

    const bytes = [_]u8{0xFF};
    const hex = try bytesToHex(allocator, &bytes);
    defer allocator.free(hex);

    try std.testing.expectEqualStrings("ff", hex);
}

test "hex case insensitive decode" {
    const allocator = std.testing.allocator;

    const bytes1 = try hexToBytes(allocator, "abcdef");
    defer allocator.free(bytes1);

    const bytes2 = try hexToBytes(allocator, "ABCDEF");
    defer allocator.free(bytes2);

    const bytes3 = try hexToBytes(allocator, "AbCdEf");
    defer allocator.free(bytes3);

    try std.testing.expectEqualSlices(u8, bytes1, bytes2);
    try std.testing.expectEqualSlices(u8, bytes1, bytes3);
}

test "invalid hex length" {
    const allocator = std.testing.allocator;

    const result = hexToBytes(allocator, "abc");
    try std.testing.expectError(error.InvalidHexLength, result);
}

test "invalid hex character" {
    const allocator = std.testing.allocator;

    const result = hexToBytes(allocator, "abcg");
    try std.testing.expectError(error.InvalidHexCharacter, result);
}

test "hex nibble conversion" {
    try std.testing.expectEqual(@as(u8, 0), try hexCharToNibble('0'));
    try std.testing.expectEqual(@as(u8, 9), try hexCharToNibble('9'));
    try std.testing.expectEqual(@as(u8, 10), try hexCharToNibble('a'));
    try std.testing.expectEqual(@as(u8, 15), try hexCharToNibble('f'));
    try std.testing.expectEqual(@as(u8, 10), try hexCharToNibble('A'));
    try std.testing.expectEqual(@as(u8, 15), try hexCharToNibble('F'));

    try std.testing.expectError(error.InvalidHexCharacter, hexCharToNibble('g'));
    try std.testing.expectError(error.InvalidHexCharacter, hexCharToNibble('G'));
    try std.testing.expectError(error.InvalidHexCharacter, hexCharToNibble(' '));
}

test "zero padded hex" {
    const allocator = std.testing.allocator;

    const hex = try u32ToHexPadded(allocator, 0x00);
    defer allocator.free(hex);

    try std.testing.expectEqualStrings("00000000", hex);
}

test "hex separator empty bytes" {
    const allocator = std.testing.allocator;

    const bytes: []const u8 = &.{};
    const hex = try bytesToHexWithSep(allocator, bytes, ":");
    defer allocator.free(hex);

    try std.testing.expectEqualStrings("", hex);
}

test "large hex conversion" {
    const allocator = std.testing.allocator;

    var bytes: [256]u8 = undefined;
    for (&bytes, 0..) |*byte, i| {
        byte.* = @intCast(i);
    }

    const hex = try bytesToHex(allocator, &bytes);
    defer allocator.free(hex);

    try std.testing.expectEqual(@as(usize, 512), hex.len);

    const decoded = try hexToBytes(allocator, hex);
    defer allocator.free(decoded);

    try std.testing.expectEqualSlices(u8, &bytes, decoded);
}
