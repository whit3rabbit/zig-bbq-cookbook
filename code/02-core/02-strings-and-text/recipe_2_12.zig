// Recipe 2.12: Handling byte strings vs unicode strings
// Target Zig Version: 0.15.2
//
// This recipe demonstrates the difference between byte strings and Unicode strings,
// UTF-8 iteration, validation, and proper Unicode handling in Zig.

const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const unicode = std.unicode;

// ANCHOR: utf8_validation
/// Validate UTF-8 string
pub fn isValidUtf8(text: []const u8) bool {
    return unicode.utf8ValidateSlice(text);
}

/// Count UTF-8 codepoints (not bytes)
pub fn countCodepoints(text: []const u8) !usize {
    var count: usize = 0;
    var i: usize = 0;

    while (i < text.len) {
        const cp_len = try unicode.utf8ByteSequenceLength(text[i]);
        i += cp_len;
        count += 1;
    }

    return count;
}

/// Iterate UTF-8 codepoints
pub fn iterateCodepoints(
    allocator: mem.Allocator,
    text: []const u8,
) !std.ArrayList(u21) {
    var codepoints = std.ArrayList(u21){};
    errdefer codepoints.deinit(allocator);

    var i: usize = 0;
    while (i < text.len) {
        const cp_len = try unicode.utf8ByteSequenceLength(text[i]);
        const codepoint = try unicode.utf8Decode(text[i .. i + cp_len]);
        try codepoints.append(allocator, codepoint);
        i += cp_len;
    }

    return codepoints;
}
// ANCHOR_END: utf8_validation

// ANCHOR: codepoint_access
/// Get byte at index (not codepoint)
pub fn byteAt(text: []const u8, index: usize) ?u8 {
    if (index >= text.len) return null;
    return text[index];
}

/// Get codepoint at index (UTF-8 aware)
pub fn codepointAt(text: []const u8, index: usize) !?u21 {
    var count: usize = 0;
    var i: usize = 0;

    while (i < text.len) {
        if (count == index) {
            const cp_len = try unicode.utf8ByteSequenceLength(text[i]);
            const codepoint = try unicode.utf8Decode(text[i .. i + cp_len]);
            return codepoint;
        }

        const cp_len = try unicode.utf8ByteSequenceLength(text[i]);
        i += cp_len;
        count += 1;
    }

    return null;
}

/// Convert codepoint to UTF-8 bytes
pub fn codepointToUtf8(
    allocator: mem.Allocator,
    codepoint: u21,
) ![]u8 {
    var buf: [4]u8 = undefined;
    const len = try unicode.utf8Encode(codepoint, &buf);
    return allocator.dupe(u8, buf[0..len]);
}
// ANCHOR_END: codepoint_access

// ANCHOR: utf8_operations
/// Reverse string (UTF-8 aware)
pub fn reverseUtf8(
    allocator: mem.Allocator,
    text: []const u8,
) ![]u8 {
    // First collect all codepoints
    var codepoints = try iterateCodepoints(allocator, text);
    defer codepoints.deinit(allocator);

    // Calculate total size needed
    var total_bytes: usize = 0;
    for (codepoints.items) |cp| {
        total_bytes += unicode.utf8CodepointSequenceLength(cp) catch continue;
    }

    var result = try allocator.alloc(u8, total_bytes);
    errdefer allocator.free(result);

    var pos: usize = 0;
    var i: usize = codepoints.items.len;

    while (i > 0) {
        i -= 1;
        const cp = codepoints.items[i];
        const len = try unicode.utf8Encode(cp, result[pos..]);
        pos += len;
    }

    return result;
}

/// Substring by codepoint index (not byte index)
pub fn substringByCodepoint(
    allocator: mem.Allocator,
    text: []const u8,
    start: usize,
    end: usize,
) ![]u8 {
    if (start >= end) return allocator.dupe(u8, "");

    var byte_start: ?usize = null;
    var byte_end: ?usize = null;
    var count: usize = 0;
    var i: usize = 0;

    while (i < text.len) {
        if (count == start) byte_start = i;
        if (count == end) {
            byte_end = i;
            break;
        }

        const cp_len = try unicode.utf8ByteSequenceLength(text[i]);
        i += cp_len;
        count += 1;
    }

    if (byte_start == null) return allocator.dupe(u8, "");
    const actual_end = byte_end orelse text.len;

    return allocator.dupe(u8, text[byte_start.?..actual_end]);
}
// ANCHOR_END: utf8_operations

/// Check if byte is UTF-8 continuation byte
pub fn isContinuationByte(byte: u8) bool {
    return (byte & 0b11000000) == 0b10000000;
}

/// Get UTF-8 byte sequence length from first byte
pub fn getSequenceLength(first_byte: u8) !usize {
    const len = try unicode.utf8ByteSequenceLength(first_byte);
    return @as(usize, len);
}

test "validate UTF-8" {
    try testing.expect(isValidUtf8("Hello"));
    try testing.expect(isValidUtf8("Hello 世界"));
    try testing.expect(isValidUtf8(""));
    try testing.expect(isValidUtf8("こんにちは"));
}

test "count codepoints vs bytes" {
    const text = "Hello 世界";

    // Byte length
    try testing.expectEqual(@as(usize, 12), text.len);

    // Codepoint count
    const count = try countCodepoints(text);
    try testing.expectEqual(@as(usize, 8), count); // "Hello " = 6, 世界 = 2
}

test "count ASCII codepoints" {
    const text = "Hello";
    const count = try countCodepoints(text);

    try testing.expectEqual(@as(usize, 5), count);
    try testing.expectEqual(@as(usize, 5), text.len);
}

test "iterate codepoints" {
    const text = "Hi世";
    var codepoints = try iterateCodepoints(testing.allocator, text);
    defer codepoints.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 3), codepoints.items.len);
    try testing.expectEqual(@as(u21, 'H'), codepoints.items[0]);
    try testing.expectEqual(@as(u21, 'i'), codepoints.items[1]);
    try testing.expectEqual(@as(u21, 0x4E16), codepoints.items[2]); // 世
}

test "byte at index" {
    const text = "Hello";

    try testing.expectEqual(@as(u8, 'H'), byteAt(text, 0).?);
    try testing.expectEqual(@as(u8, 'e'), byteAt(text, 1).?);
    try testing.expectEqual(@as(?u8, null), byteAt(text, 10));
}

test "codepoint at index" {
    const text = "Hi世界";

    try testing.expectEqual(@as(u21, 'H'), (try codepointAt(text, 0)).?);
    try testing.expectEqual(@as(u21, 'i'), (try codepointAt(text, 1)).?);
    try testing.expectEqual(@as(u21, 0x4E16), (try codepointAt(text, 2)).?); // 世
    try testing.expectEqual(@as(u21, 0x754C), (try codepointAt(text, 3)).?); // 界
}

test "codepoint to UTF-8" {
    const utf8 = try codepointToUtf8(testing.allocator, 0x4E16);
    defer testing.allocator.free(utf8);

    try testing.expectEqualStrings("世", utf8);
}

test "ASCII codepoint to UTF-8" {
    const utf8 = try codepointToUtf8(testing.allocator, 'A');
    defer testing.allocator.free(utf8);

    try testing.expectEqualStrings("A", utf8);
}

test "reverse UTF-8 string" {
    const text = "ABC";
    const reversed = try reverseUtf8(testing.allocator, text);
    defer testing.allocator.free(reversed);

    try testing.expectEqualStrings("CBA", reversed);
}

test "reverse UTF-8 with multibyte" {
    const text = "Hi世";
    const reversed = try reverseUtf8(testing.allocator, text);
    defer testing.allocator.free(reversed);

    try testing.expectEqualStrings("世iH", reversed);
}

test "substring by codepoint" {
    const text = "Hello世界";
    const sub = try substringByCodepoint(testing.allocator, text, 0, 5);
    defer testing.allocator.free(sub);

    try testing.expectEqualStrings("Hello", sub);
}

test "substring multibyte characters" {
    const text = "Hello世界";
    const sub = try substringByCodepoint(testing.allocator, text, 5, 7);
    defer testing.allocator.free(sub);

    try testing.expectEqualStrings("世界", sub);
}

test "substring out of bounds" {
    const text = "Hi";
    const sub = try substringByCodepoint(testing.allocator, text, 10, 20);
    defer testing.allocator.free(sub);

    try testing.expectEqualStrings("", sub);
}

test "is continuation byte" {
    // ASCII byte
    try testing.expect(!isContinuationByte('A'));

    // UTF-8 continuation bytes start with 10xxxxxx
    try testing.expect(isContinuationByte(0b10000000));
    try testing.expect(isContinuationByte(0b10111111));

    // UTF-8 start bytes
    try testing.expect(!isContinuationByte(0b11000000));
}

test "get sequence length" {
    // ASCII (1 byte)
    try testing.expectEqual(@as(usize, 1), try getSequenceLength('A'));

    // 2-byte sequence (110xxxxx)
    try testing.expectEqual(@as(usize, 2), try getSequenceLength(0b11000000));

    // 3-byte sequence (1110xxxx)
    try testing.expectEqual(@as(usize, 3), try getSequenceLength(0b11100000));

    // 4-byte sequence (11110xxx)
    try testing.expectEqual(@as(usize, 4), try getSequenceLength(0b11110000));
}

test "byte vs codepoint indexing" {
    const text = "A世B";

    // Byte indexing
    try testing.expectEqual(@as(usize, 5), text.len); // 1 + 3 + 1

    // Codepoint indexing
    const count = try countCodepoints(text);
    try testing.expectEqual(@as(usize, 3), count);
}

test "empty string operations" {
    const empty = "";

    try testing.expect(isValidUtf8(empty));
    try testing.expectEqual(@as(usize, 0), try countCodepoints(empty));

    var codepoints = try iterateCodepoints(testing.allocator, empty);
    defer codepoints.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 0), codepoints.items.len);
}

test "single multibyte character" {
    const text = "世";

    try testing.expectEqual(@as(usize, 3), text.len); // 3 bytes
    try testing.expectEqual(@as(usize, 1), try countCodepoints(text));
}

test "memory safety - UTF-8 operations" {
    const text = "Hello世界";

    var codepoints = try iterateCodepoints(testing.allocator, text);
    defer codepoints.deinit(testing.allocator);

    const reversed = try reverseUtf8(testing.allocator, text);
    defer testing.allocator.free(reversed);

    // testing.allocator will detect leaks
    try testing.expect(codepoints.items.len > 0);
    try testing.expect(reversed.len > 0);
}

test "UTF-8 emoji" {
    const text = "Hello 👋";

    try testing.expect(isValidUtf8(text));
    try testing.expectEqual(@as(usize, 7), try countCodepoints(text));
}

test "various Unicode scripts" {
    const cyrillic = "Привет";
    const arabic = "مرحبا";
    const chinese = "你好";

    try testing.expect(isValidUtf8(cyrillic));
    try testing.expect(isValidUtf8(arabic));
    try testing.expect(isValidUtf8(chinese));
}

test "security - invalid UTF-8" {
    // These are invalid UTF-8 sequences
    const invalid1 = [_]u8{ 0xFF, 0xFF };
    const invalid2 = [_]u8{ 0xC0, 0x80 }; // Overlong encoding

    try testing.expect(!isValidUtf8(&invalid1));
    try testing.expect(!isValidUtf8(&invalid2));
}
