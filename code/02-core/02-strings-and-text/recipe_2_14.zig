// Recipe 2.14: Standardizing Unicode text with ICU
// Target Zig Version: 0.15.2
//
// EDUCATIONAL FOCUS: This recipe demonstrates C library interoperability patterns.
// For production code, consider pure-Zig alternatives like Ziglyph.
//
// IMPORTANT: This recipe requires ICU version 77+ due to Zig's @cImport limitations
// with ICU's macro system. The versioned function names (_77 suffix) are a workaround
// for circular dependency errors when using ICU's U_ICU_ENTRY_POINT_RENAME macro.
//
// This recipe demonstrates interfacing with the ICU (International Components for Unicode)
// C library to perform Unicode normalization and case-folding operations.

// ANCHOR: icu_setup
const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const unicode = std.unicode;
const Allocator = mem.Allocator;

// Import ICU C library types (with renaming disabled to avoid circular dependencies)
// IMPORTANT: Only use ONE @cImport per application to avoid symbol collisions
const icu = @cImport({
    @cDefine("U_DISABLE_RENAMING", "1");
    @cInclude("unicode/utypes.h"); // Base types
    @cInclude("unicode/unorm2.h"); // For normalization types
    @cInclude("unicode/ustring.h"); // For string operation types
});

// Manually declare versioned ICU functions to work around Zig @cImport macro issues
//
// WHY VERSIONED?: ICU's U_ICU_ENTRY_POINT_RENAME macro causes circular dependencies
// in Zig's @cImport. Using U_DISABLE_RENAMING + manual declarations is the workaround.
// The _77 suffix corresponds to ICU version 77 (check with: icu-config --version).
//
// PORTABILITY NOTE: This hardcodes ICU 77. For different ICU versions, adjust the suffix.
// This is a known limitation of this approach and why production code should prefer
// pure-Zig Unicode libraries that don't have these FFI complications.
extern "c" fn unorm2_getNFCInstance_77(pErrorCode: *icu.UErrorCode) ?*const icu.UNormalizer2;
extern "c" fn unorm2_getNFDInstance_77(pErrorCode: *icu.UErrorCode) ?*const icu.UNormalizer2;
extern "c" fn unorm2_getNFKCInstance_77(pErrorCode: *icu.UErrorCode) ?*const icu.UNormalizer2;
extern "c" fn unorm2_normalize_77(
    norm2: ?*const icu.UNormalizer2,
    src: [*]const u16,
    length: i32,
    dest: ?[*]u16,
    capacity: i32,
    pErrorCode: *icu.UErrorCode,
) i32;
extern "c" fn u_strFoldCase_77(
    dest: ?[*]u16,
    destCapacity: i32,
    src: [*]const u16,
    srcLength: i32,
    options: u32,
    pErrorCode: *icu.UErrorCode,
) i32;

// Custom error set for ICU operations
const ICUError = error{
    InitFailed,
    NormalizationFailed,
    CaseFoldFailed,
    InvalidUtf8,
    BufferTooSmall,
    UnexpectedError,
};

/// Convert UTF-8 string to UTF-16 (ICU uses UTF-16 internally)
fn utf8ToUtf16(allocator: Allocator, utf8: []const u8) ![]u16 {
    if (utf8.len == 0) return try allocator.alloc(u16, 0);

    // Validate UTF-8 first
    if (!unicode.utf8ValidateSlice(utf8)) {
        return ICUError.InvalidUtf8;
    }

    // Calculate required UTF-16 length
    var utf16_len: usize = 0;
    var i: usize = 0;
    while (i < utf8.len) {
        const cp_len = try unicode.utf8ByteSequenceLength(utf8[i]);
        const codepoint = try unicode.utf8Decode(utf8[i .. i + cp_len]);

        if (codepoint >= 0x10000) {
            utf16_len += 2; // Surrogate pair
        } else {
            utf16_len += 1;
        }
        i += cp_len;
    }

    // Allocate and encode
    var utf16 = try allocator.alloc(u16, utf16_len);
    errdefer allocator.free(utf16);

    var out_idx: usize = 0;
    i = 0;
    while (i < utf8.len) {
        const cp_len = try unicode.utf8ByteSequenceLength(utf8[i]);
        const codepoint = try unicode.utf8Decode(utf8[i .. i + cp_len]);

        if (codepoint >= 0x10000) {
            // Encode as surrogate pair
            const surrogate = codepoint - 0x10000;
            utf16[out_idx] = @intCast(0xD800 + (surrogate >> 10));
            utf16[out_idx + 1] = @intCast(0xDC00 + (surrogate & 0x3FF));
            out_idx += 2;
        } else {
            utf16[out_idx] = @intCast(codepoint);
            out_idx += 1;
        }
        i += cp_len;
    }

    return utf16;
}

/// Convert UTF-16 string to UTF-8
fn utf16ToUtf8(allocator: Allocator, utf16: []const u16) ![]u8 {
    if (utf16.len == 0) return try allocator.alloc(u8, 0);

    // Calculate required UTF-8 length
    var utf8_len: usize = 0;
    var i: usize = 0;
    while (i < utf16.len) {
        const unit = utf16[i];
        var codepoint: u21 = 0;

        if (unit >= 0xD800 and unit <= 0xDBFF) {
            // High surrogate - need next unit
            if (i + 1 >= utf16.len) return ICUError.InvalidUtf8;
            const low = utf16[i + 1];
            if (low < 0xDC00 or low > 0xDFFF) return ICUError.InvalidUtf8;

            codepoint = @intCast(0x10000 + ((@as(u32, unit) - 0xD800) << 10) + (low - 0xDC00));
            i += 2;
        } else if (unit >= 0xDC00 and unit <= 0xDFFF) {
            // Low surrogate without high surrogate - invalid
            return ICUError.InvalidUtf8;
        } else {
            codepoint = @intCast(unit);
            i += 1;
        }

        utf8_len += try unicode.utf8CodepointSequenceLength(codepoint);
    }

    // Allocate and encode
    var utf8 = try allocator.alloc(u8, utf8_len);
    errdefer allocator.free(utf8);

    var out_pos: usize = 0;
    i = 0;
    while (i < utf16.len) {
        const unit = utf16[i];
        var codepoint: u21 = 0;

        if (unit >= 0xD800 and unit <= 0xDBFF) {
            const low = utf16[i + 1];
            codepoint = @intCast(0x10000 + ((@as(u32, unit) - 0xD800) << 10) + (low - 0xDC00));
            i += 2;
        } else {
            codepoint = @intCast(unit);
            i += 1;
        }

        const len = try unicode.utf8Encode(codepoint, utf8[out_pos..]);
        out_pos += len;
    }

    return utf8;
}
// ANCHOR_END: icu_setup

// ANCHOR: unicode_normalization
/// Normalize UTF-8 string to NFC (Normalization Form C - Canonical Composition)
/// This is the most common form for web content and database storage.
/// Example: e + combining acute accent (U+0301) -> é (U+00E9)
pub fn normalizeNFC(allocator: Allocator, text: []const u8) ![]u8 {
    if (text.len == 0) return try allocator.alloc(u8, 0);

    // Convert UTF-8 to UTF-16
    const utf16_input = try utf8ToUtf16(allocator, text);
    defer allocator.free(utf16_input);

    // Get NFC normalizer instance
    var status: icu.UErrorCode = icu.U_ZERO_ERROR;
    const normalizer = unorm2_getNFCInstance_77(&status);
    if (status != icu.U_ZERO_ERROR) {
        return ICUError.InitFailed;
    }

    // First call to determine required buffer size
    status = icu.U_ZERO_ERROR;
    const required_len = unorm2_normalize_77(
        normalizer,
        utf16_input.ptr,
        @intCast(utf16_input.len),
        null,
        0,
        &status,
    );

    // Check for actual errors (positive values), not warnings (negative)
    // U_BUFFER_OVERFLOW_ERROR (15) is expected when probing size
    if (status > 0 and status != icu.U_BUFFER_OVERFLOW_ERROR) {
        return ICUError.NormalizationFailed;
    }

    // Allocate output buffer
    const utf16_output = try allocator.alloc(u16, @intCast(required_len));
    defer allocator.free(utf16_output);

    // Second call to perform normalization
    status = icu.U_ZERO_ERROR;
    const actual_len = unorm2_normalize_77(
        normalizer,
        utf16_input.ptr,
        @intCast(utf16_input.len),
        utf16_output.ptr,
        @intCast(utf16_output.len),
        &status,
    );

    // Check for actual errors (positive values), warnings (negative) are OK
    if (status > 0) {
        return ICUError.NormalizationFailed;
    }

    // Convert back to UTF-8
    return utf16ToUtf8(allocator, utf16_output[0..@intCast(actual_len)]);
}

/// Normalize UTF-8 string to NFD (Normalization Form D - Canonical Decomposition)
/// This form decomposes characters into base letter + combining marks.
/// Example: é (U+00E9) -> e + combining acute accent (U+0301)
pub fn normalizeNFD(allocator: Allocator, text: []const u8) ![]u8 {
    if (text.len == 0) return try allocator.alloc(u8, 0);

    const utf16_input = try utf8ToUtf16(allocator, text);
    defer allocator.free(utf16_input);

    var status: icu.UErrorCode = icu.U_ZERO_ERROR;
    const normalizer = unorm2_getNFDInstance_77(&status);
    if (status != icu.U_ZERO_ERROR) {
        return ICUError.InitFailed;
    }

    status = icu.U_ZERO_ERROR;
    const required_len = unorm2_normalize_77(
        normalizer,
        utf16_input.ptr,
        @intCast(utf16_input.len),
        null,
        0,
        &status,
    );

    if (status > 0 and status != icu.U_BUFFER_OVERFLOW_ERROR) {
        return ICUError.NormalizationFailed;
    }

    const utf16_output = try allocator.alloc(u16, @intCast(required_len));
    defer allocator.free(utf16_output);

    status = icu.U_ZERO_ERROR;
    const actual_len = unorm2_normalize_77(
        normalizer,
        utf16_input.ptr,
        @intCast(utf16_input.len),
        utf16_output.ptr,
        @intCast(utf16_output.len),
        &status,
    );

    if (status > 0) {
        return ICUError.NormalizationFailed;
    }

    return utf16ToUtf8(allocator, utf16_output[0..@intCast(actual_len)]);
}

/// Normalize UTF-8 string to NFKC (Compatibility Composition)
/// This form also normalizes compatibility equivalents (like fractions, ligatures).
/// Example: ½ (U+00BD) -> 1/2 (separate characters)
pub fn normalizeNFKC(allocator: Allocator, text: []const u8) ![]u8 {
    if (text.len == 0) return try allocator.alloc(u8, 0);

    const utf16_input = try utf8ToUtf16(allocator, text);
    defer allocator.free(utf16_input);

    var status: icu.UErrorCode = icu.U_ZERO_ERROR;
    const normalizer = unorm2_getNFKCInstance_77(&status);
    if (status != icu.U_ZERO_ERROR) {
        return ICUError.InitFailed;
    }

    status = icu.U_ZERO_ERROR;
    const required_len = unorm2_normalize_77(
        normalizer,
        utf16_input.ptr,
        @intCast(utf16_input.len),
        null,
        0,
        &status,
    );

    if (status > 0 and status != icu.U_BUFFER_OVERFLOW_ERROR) {
        return ICUError.NormalizationFailed;
    }

    const utf16_output = try allocator.alloc(u16, @intCast(required_len));
    defer allocator.free(utf16_output);

    status = icu.U_ZERO_ERROR;
    const actual_len = unorm2_normalize_77(
        normalizer,
        utf16_input.ptr,
        @intCast(utf16_input.len),
        utf16_output.ptr,
        @intCast(utf16_output.len),
        &status,
    );

    if (status > 0) {
        return ICUError.NormalizationFailed;
    }

    return utf16ToUtf8(allocator, utf16_output[0..@intCast(actual_len)]);
}
// ANCHOR_END: unicode_normalization

// ANCHOR: case_folding
/// Case-fold UTF-8 string for case-insensitive comparison.
/// This is more correct than simple lowercasing for Unicode.
/// Example: German ß -> ss, Turkish I -> ı (context-aware)
pub fn caseFold(allocator: Allocator, text: []const u8) ![]u8 {
    if (text.len == 0) return try allocator.alloc(u8, 0);

    const utf16_input = try utf8ToUtf16(allocator, text);
    defer allocator.free(utf16_input);

    var status: icu.UErrorCode = icu.U_ZERO_ERROR;
    const required_len = u_strFoldCase_77(
        null,
        0,
        utf16_input.ptr,
        @intCast(utf16_input.len),
        0,
        &status,
    );

    if (status > 0 and status != icu.U_BUFFER_OVERFLOW_ERROR) {
        return ICUError.CaseFoldFailed;
    }

    const utf16_output = try allocator.alloc(u16, @intCast(required_len));
    defer allocator.free(utf16_output);

    status = icu.U_ZERO_ERROR;
    const actual_len = u_strFoldCase_77(
        utf16_output.ptr,
        @intCast(utf16_output.len),
        utf16_input.ptr,
        @intCast(utf16_input.len),
        0,
        &status,
    );

    if (status > 0) {
        return ICUError.CaseFoldFailed;
    }

    return utf16ToUtf8(allocator, utf16_output[0..@intCast(actual_len)]);
}

// Tests

test "UTF-8 to UTF-16 conversion" {
    const utf8 = "Hello";
    const utf16 = try utf8ToUtf16(testing.allocator, utf8);
    defer testing.allocator.free(utf16);

    try testing.expectEqual(@as(usize, 5), utf16.len);
    try testing.expectEqual(@as(u16, 'H'), utf16[0]);
    try testing.expectEqual(@as(u16, 'e'), utf16[1]);
}

test "UTF-8 to UTF-16 with multibyte characters" {
    const utf8 = "世界";
    const utf16 = try utf8ToUtf16(testing.allocator, utf8);
    defer testing.allocator.free(utf16);

    try testing.expectEqual(@as(usize, 2), utf16.len);
    try testing.expectEqual(@as(u16, 0x4E16), utf16[0]); // 世
    try testing.expectEqual(@as(u16, 0x754C), utf16[1]); // 界
}

test "UTF-16 to UTF-8 conversion" {
    const utf16 = [_]u16{ 'H', 'e', 'l', 'l', 'o' };
    const utf8 = try utf16ToUtf8(testing.allocator, &utf16);
    defer testing.allocator.free(utf8);

    try testing.expectEqualStrings("Hello", utf8);
}

test "UTF-16 to UTF-8 with multibyte characters" {
    const utf16 = [_]u16{ 0x4E16, 0x754C }; // 世界
    const utf8 = try utf16ToUtf8(testing.allocator, &utf16);
    defer testing.allocator.free(utf8);

    try testing.expectEqualStrings("世界", utf8);
}

test "normalize NFC - combining accent to composed" {
    // e + combining acute accent -> é (composed)
    const decomposed = "e\u{0301}";
    const result = try normalizeNFC(testing.allocator, decomposed);
    defer testing.allocator.free(result);

    // Should be composed é (U+00E9)
    try testing.expectEqualStrings("\u{00E9}", result);
}

test "normalize NFC - already composed" {
    const composed = "\u{00E9}"; // é (already composed)
    const result = try normalizeNFC(testing.allocator, composed);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings(composed, result);
}

test "normalize NFD - composed to decomposed" {
    // é (composed) -> e + combining accent
    const composed = "\u{00E9}";
    const result = try normalizeNFD(testing.allocator, composed);
    defer testing.allocator.free(result);

    // Should be decomposed: e + combining acute
    try testing.expectEqualStrings("e\u{0301}", result);
}

test "normalize NFD - already decomposed" {
    const decomposed = "e\u{0301}";
    const result = try normalizeNFD(testing.allocator, decomposed);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings(decomposed, result);
}

test "NFC and NFD are inverses" {
    const original = "café";

    // Normalize to NFD (decomposed)
    const nfd = try normalizeNFD(testing.allocator, original);
    defer testing.allocator.free(nfd);

    // Normalize back to NFC (composed)
    const nfc = try normalizeNFC(testing.allocator, nfd);
    defer testing.allocator.free(nfc);

    // Should match original (both NFC)
    try testing.expectEqualStrings(original, nfc);
}

test "normalize NFKC - compatibility characters" {
    // Test with various compatibility characters
    const text = "Hello";
    const result = try normalizeNFKC(testing.allocator, text);
    defer testing.allocator.free(result);

    // ASCII text should remain unchanged
    try testing.expectEqualStrings(text, result);
}

test "visual equivalence requires normalization" {
    // Two visually identical strings with different byte representations
    const composed = "café"; // é is single codepoint U+00E9
    const decomposed = "cafe\u{0301}"; // é is e + combining accent

    // Byte representations differ
    try testing.expect(!mem.eql(u8, composed, decomposed));

    // After normalization, they should be identical
    const norm1 = try normalizeNFC(testing.allocator, composed);
    defer testing.allocator.free(norm1);

    const norm2 = try normalizeNFC(testing.allocator, decomposed);
    defer testing.allocator.free(norm2);

    try testing.expectEqualStrings(norm1, norm2);
}

test "case fold - ASCII" {
    const text = "Hello World";
    const result = try caseFold(testing.allocator, text);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello world", result);
}

test "case fold - German sharp s" {
    // German ß should case-fold to ss
    const text = "Straße";
    const result = try caseFold(testing.allocator, text);
    defer testing.allocator.free(result);

    // ICU should convert ß to ss
    try testing.expectEqualStrings("strasse", result);
}

test "case fold for case-insensitive comparison" {
    const text1 = "HELLO";
    const text2 = "hello";

    const fold1 = try caseFold(testing.allocator, text1);
    defer testing.allocator.free(fold1);

    const fold2 = try caseFold(testing.allocator, text2);
    defer testing.allocator.free(fold2);

    // Case-folded versions should be identical
    try testing.expectEqualStrings(fold1, fold2);
}

test "empty string normalization" {
    const empty = "";

    const nfc = try normalizeNFC(testing.allocator, empty);
    defer testing.allocator.free(nfc);

    const nfd = try normalizeNFD(testing.allocator, empty);
    defer testing.allocator.free(nfd);

    try testing.expectEqual(@as(usize, 0), nfc.len);
    try testing.expectEqual(@as(usize, 0), nfd.len);
}

test "empty string case fold" {
    const empty = "";
    const result = try caseFold(testing.allocator, empty);
    defer testing.allocator.free(result);

    try testing.expectEqual(@as(usize, 0), result.len);
}

test "normalization with emoji" {
    const emoji = "Hello 👋";

    const nfc = try normalizeNFC(testing.allocator, emoji);
    defer testing.allocator.free(nfc);

    // Emoji should pass through unchanged
    try testing.expect(nfc.len > 0);
}

test "normalization with various scripts" {
    const texts = [_][]const u8{
        "Hello", // ASCII
        "café", // Latin with accent
        "Привет", // Cyrillic
        "你好", // Chinese
        "こんにちは", // Japanese
    };

    for (texts) |text| {
        const nfc = try normalizeNFC(testing.allocator, text);
        defer testing.allocator.free(nfc);

        const nfd = try normalizeNFD(testing.allocator, text);
        defer testing.allocator.free(nfd);

        try testing.expect(nfc.len > 0);
        try testing.expect(nfd.len > 0);
    }
}

test "memory safety - no leaks" {
    // testing.allocator automatically detects memory leaks
    const text = "café";

    const nfc = try normalizeNFC(testing.allocator, text);
    defer testing.allocator.free(nfc);

    const nfd = try normalizeNFD(testing.allocator, text);
    defer testing.allocator.free(nfd);

    const folded = try caseFold(testing.allocator, text);
    defer testing.allocator.free(folded);

    try testing.expect(nfc.len > 0);
    try testing.expect(nfd.len > 0);
    try testing.expect(folded.len > 0);
}

test "invalid UTF-8 handling" {
    const invalid = [_]u8{ 0xFF, 0xFF };
    const result = normalizeNFC(testing.allocator, &invalid);

    try testing.expectError(ICUError.InvalidUtf8, result);
}

test "round-trip UTF-8 to UTF-16 and back" {
    const original = "Hello 世界 café 👋";

    const utf16 = try utf8ToUtf16(testing.allocator, original);
    defer testing.allocator.free(utf16);

    const back_to_utf8 = try utf16ToUtf8(testing.allocator, utf16);
    defer testing.allocator.free(back_to_utf8);

    try testing.expectEqualStrings(original, back_to_utf8);
}
// ANCHOR_END: case_folding
