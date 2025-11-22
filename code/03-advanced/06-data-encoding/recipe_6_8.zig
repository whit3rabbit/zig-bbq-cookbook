const std = @import("std");

// ANCHOR: basic_base64
/// Encode data to Base64
pub fn encodeBase64(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    const encoder = std.base64.standard.Encoder;
    const encoded_len = encoder.calcSize(data.len);

    const encoded = try allocator.alloc(u8, encoded_len);
    errdefer allocator.free(encoded);

    _ = encoder.encode(encoded, data);
    return encoded;
}

/// Decode Base64 to bytes
pub fn decodeBase64(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    const decoder = std.base64.standard.Decoder;
    const decoded_len = try decoder.calcSizeForSlice(encoded);

    const decoded = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(decoded);

    try decoder.decode(decoded, encoded);
    return decoded;
}
// ANCHOR_END: basic_base64

// ANCHOR: url_safe_base64
/// Encode data to URL-safe Base64
pub fn encodeBase64Url(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    const encoder = std.base64.url_safe.Encoder;
    const encoded_len = encoder.calcSize(data.len);

    const encoded = try allocator.alloc(u8, encoded_len);
    errdefer allocator.free(encoded);

    _ = encoder.encode(encoded, data);
    return encoded;
}

/// Decode URL-safe Base64 to bytes
pub fn decodeBase64Url(allocator: std.mem.Allocator, encoded: []const u8) ![]u8 {
    const decoder = std.base64.url_safe.Decoder;
    const decoded_len = try decoder.calcSizeForSlice(encoded);

    const decoded = try allocator.alloc(u8, decoded_len);
    errdefer allocator.free(decoded);

    try decoder.decode(decoded, encoded);
    return decoded;
}
// ANCHOR_END: url_safe_base64

/// Encode data to Base64 without padding
pub fn encodeBase64NoPad(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    const encoder = std.base64.standard_no_pad.Encoder;
    const encoded_len = encoder.calcSize(data.len);

    const encoded = try allocator.alloc(u8, encoded_len);
    errdefer allocator.free(encoded);

    _ = encoder.encode(encoded, data);
    return encoded;
}

// ANCHOR: streaming_base64
/// Encode data to Base64 in streaming fashion
pub fn encodeBase64Stream(
    writer: anytype,
    data: []const u8,
    chunk_size: usize,
) !void {
    const encoder = std.base64.standard.Encoder;

    // Adjust chunk size to be multiple of 3 for proper Base64 encoding
    const adjusted_chunk = (chunk_size / 3) * 3;
    if (adjusted_chunk == 0) return error.ChunkTooSmall;

    var i: usize = 0;
    while (i < data.len) {
        const is_last = (i + adjusted_chunk >= data.len);
        const end = if (is_last) data.len else i + adjusted_chunk;
        const chunk = data[i..end];

        const encoded_len = encoder.calcSize(chunk.len);
        var buffer: [4096]u8 = undefined;

        _ = encoder.encode(buffer[0..encoded_len], chunk);
        try writer.writeAll(buffer[0..encoded_len]);

        i = end;
    }
}
// ANCHOR_END: streaming_base64

/// Validate Base64 string
pub fn isValidBase64(input: []const u8) bool {
    const decoder = std.base64.standard.Decoder;

    // Check length
    if (input.len == 0) return true;
    if (input.len % 4 != 0) return false;

    // Try to allocate and decode to validate
    var buffer: [4096]u8 = undefined;
    if (input.len / 4 * 3 > buffer.len) return false;

    const size = decoder.calcSizeForSlice(input) catch return false;
    decoder.decode(buffer[0..size], input) catch return false;

    return true;
}

/// Encode binary data to Base64
pub fn encodeBinaryToBase64(
    allocator: std.mem.Allocator,
    data: []const u8,
) ![]u8 {
    const encoder = std.base64.standard.Encoder;
    const encoded_len = encoder.calcSize(data.len);

    const encoded = try allocator.alloc(u8, encoded_len);
    errdefer allocator.free(encoded);

    _ = encoder.encode(encoded, data);
    return encoded;
}

/// Encode to fixed buffer
pub fn encodeBase64Buf(data: []const u8, out: []u8) ![]u8 {
    const encoder = std.base64.standard.Encoder;
    const encoded_len = encoder.calcSize(data.len);

    if (out.len < encoded_len) {
        return error.BufferTooSmall;
    }

    _ = encoder.encode(out[0..encoded_len], data);
    return out[0..encoded_len];
}

/// Decode Base64 with whitespace tolerance
pub fn decodeBase64Lenient(
    allocator: std.mem.Allocator,
    encoded: []const u8,
) ![]u8 {
    // Remove whitespace
    var cleaned = std.ArrayList(u8){};
    errdefer cleaned.deinit(allocator);

    for (encoded) |char| {
        if (!std.ascii.isWhitespace(char)) {
            try cleaned.append(allocator, char);
        }
    }

    const clean_data = try cleaned.toOwnedSlice(allocator);
    defer allocator.free(clean_data);

    return decodeBase64(allocator, clean_data);
}

// Tests

test "encode and decode base64" {
    const allocator = std.testing.allocator;

    const original = "Hello, World!";

    const encoded = try encodeBase64(allocator, original);
    defer allocator.free(encoded);

    try std.testing.expectEqualStrings("SGVsbG8sIFdvcmxkIQ==", encoded);

    const decoded = try decodeBase64(allocator, encoded);
    defer allocator.free(decoded);

    try std.testing.expectEqualStrings(original, decoded);
}

test "URL-safe base64" {
    const allocator = std.testing.allocator;

    const data = [_]u8{ 0xFF, 0xEF, 0xBE };

    const encoded = try encodeBase64Url(allocator, &data);
    defer allocator.free(encoded);

    // URL-safe uses '-' and '_' instead of '+' and '/'
    try std.testing.expect(std.mem.indexOf(u8, encoded, "+") == null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "/") == null);

    const decoded = try decodeBase64Url(allocator, encoded);
    defer allocator.free(decoded);

    try std.testing.expectEqualSlices(u8, &data, decoded);
}

test "base64 without padding" {
    const allocator = std.testing.allocator;

    const data = "Hello";

    const encoded = try encodeBase64NoPad(allocator, data);
    defer allocator.free(encoded);

    // Should not end with '='
    try std.testing.expect(encoded[encoded.len - 1] != '=');
    try std.testing.expectEqualStrings("SGVsbG8", encoded);
}

test "streaming base64 encoding" {
    const allocator = std.testing.allocator;

    const data = "The quick brown fox jumps over the lazy dog";

    var list = std.ArrayList(u8){};
    errdefer list.deinit(allocator);

    try encodeBase64Stream(list.writer(allocator), data, 10);

    const encoded = try list.toOwnedSlice(allocator);
    defer allocator.free(encoded);

    // Verify it decodes correctly
    const decoded = try decodeBase64(allocator, encoded);
    defer allocator.free(decoded);

    try std.testing.expectEqualStrings(data, decoded);
}

test "validate base64" {
    try std.testing.expect(isValidBase64("SGVsbG8="));
    try std.testing.expect(isValidBase64("SGVsbG8sIFdvcmxkIQ=="));

    try std.testing.expect(!isValidBase64("SGVsb!!!"));
    try std.testing.expect(!isValidBase64("Not valid"));
}

test "encode binary data" {
    const allocator = std.testing.allocator;

    const binary = [_]u8{ 0x00, 0xFF, 0x42, 0xAA, 0x55 };

    const encoded = try encodeBinaryToBase64(allocator, &binary);
    defer allocator.free(encoded);

    const decoded = try decodeBase64(allocator, encoded);
    defer allocator.free(decoded);

    try std.testing.expectEqualSlices(u8, &binary, decoded);
}

test "fixed buffer encoding" {
    const data = "Hello, World!";
    var buffer: [256]u8 = undefined;

    const encoded = try encodeBase64Buf(data, &buffer);

    try std.testing.expectEqualStrings("SGVsbG8sIFdvcmxkIQ==", encoded);
}

test "buffer too small" {
    const data = "Hello, World!";
    var buffer: [10]u8 = undefined;

    const result = encodeBase64Buf(data, &buffer);
    try std.testing.expectError(error.BufferTooSmall, result);
}

test "decode with whitespace" {
    const allocator = std.testing.allocator;

    const encoded = "SGVs bG8s\nIFdv cmxk\r\nIQ==";

    const decoded = try decodeBase64Lenient(allocator, encoded);
    defer allocator.free(decoded);

    try std.testing.expectEqualStrings("Hello, World!", decoded);
}

test "empty string" {
    const allocator = std.testing.allocator;

    const encoded = try encodeBase64(allocator, "");
    defer allocator.free(encoded);

    try std.testing.expectEqualStrings("", encoded);

    const decoded = try decodeBase64(allocator, "");
    defer allocator.free(decoded);

    try std.testing.expectEqualStrings("", decoded);
}

test "single character" {
    const allocator = std.testing.allocator;

    const encoded = try encodeBase64(allocator, "A");
    defer allocator.free(encoded);

    try std.testing.expectEqualStrings("QQ==", encoded);

    const decoded = try decodeBase64(allocator, encoded);
    defer allocator.free(decoded);

    try std.testing.expectEqualStrings("A", decoded);
}

test "all byte values" {
    const allocator = std.testing.allocator;

    var bytes: [256]u8 = undefined;
    for (&bytes, 0..) |*byte, i| {
        byte.* = @intCast(i);
    }

    const encoded = try encodeBase64(allocator, &bytes);
    defer allocator.free(encoded);

    const decoded = try decodeBase64(allocator, encoded);
    defer allocator.free(decoded);

    try std.testing.expectEqualSlices(u8, &bytes, decoded);
}

test "roundtrip with special characters" {
    const allocator = std.testing.allocator;

    const original = "Hello\x00World\xFF\x01\x02";

    const encoded = try encodeBase64(allocator, original);
    defer allocator.free(encoded);

    const decoded = try decodeBase64(allocator, encoded);
    defer allocator.free(decoded);

    try std.testing.expectEqualStrings(original, decoded);
}

test "URL-safe vs standard" {
    const allocator = std.testing.allocator;

    // Data that will produce '+' or '/' in standard encoding
    const data = [_]u8{ 0xFB, 0xFF };

    const standard = try encodeBase64(allocator, &data);
    defer allocator.free(standard);

    const url_safe = try encodeBase64Url(allocator, &data);
    defer allocator.free(url_safe);

    // They should be different
    try std.testing.expect(!std.mem.eql(u8, standard, url_safe));

    // But both should decode to the same data
    const decoded_standard = try decodeBase64(allocator, standard);
    defer allocator.free(decoded_standard);

    const decoded_url = try decodeBase64Url(allocator, url_safe);
    defer allocator.free(decoded_url);

    try std.testing.expectEqualSlices(u8, &data, decoded_standard);
    try std.testing.expectEqualSlices(u8, &data, decoded_url);
}
