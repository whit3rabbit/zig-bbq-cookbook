// Recipe 2.6: Searching and replacing case-insensitive text
// Target Zig Version: 0.15.2
//
// This recipe demonstrates case-insensitive string operations including
// searching, replacing, and comparing text regardless of case.

const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const ascii = std.ascii;

/// Case-insensitive equality check
// ANCHOR: case_insensitive_compare
pub fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
    return ascii.eqlIgnoreCase(a, b);
}

/// Find first occurrence of needle (case-insensitive), returns index or null
pub fn indexOfIgnoreCase(text: []const u8, needle: []const u8) ?usize {
    if (needle.len == 0) return 0;
    if (needle.len > text.len) return null;

    var i: usize = 0;
    while (i <= text.len - needle.len) : (i += 1) {
        if (ascii.eqlIgnoreCase(text[i..][0..needle.len], needle)) {
            return i;
        }
    }
    return null;
}
// ANCHOR_END: case_insensitive_compare

/// Find last occurrence of needle (case-insensitive), returns index or null
pub fn lastIndexOfIgnoreCase(text: []const u8, needle: []const u8) ?usize {
    if (needle.len == 0) return text.len;
    if (needle.len > text.len) return null;

    var i: usize = text.len - needle.len + 1;
    while (i > 0) {
        i -= 1;
        if (ascii.eqlIgnoreCase(text[i..][0..needle.len], needle)) {
            return i;
        }
    }
    return null;
}

/// Check if text contains needle (case-insensitive)
// ANCHOR: case_insensitive_search
pub fn containsIgnoreCase(text: []const u8, needle: []const u8) bool {
    return indexOfIgnoreCase(text, needle) != null;
}

/// Count occurrences of needle (case-insensitive, non-overlapping)
pub fn countIgnoreCase(text: []const u8, needle: []const u8) usize {
    if (needle.len == 0) return 0;

    var occurrences: usize = 0;
    var pos: usize = 0;

    while (pos < text.len) {
        if (indexOfIgnoreCase(text[pos..], needle)) |found| {
            occurrences += 1;
            pos += found + needle.len;
        } else {
            break;
        }
    }

    return occurrences;
}
// ANCHOR_END: case_insensitive_search

/// Replace all occurrences of needle with replacement (case-insensitive)
/// Returns newly allocated string
// ANCHOR: case_insensitive_replace
pub fn replaceAllIgnoreCase(
    allocator: mem.Allocator,
    text: []const u8,
    needle: []const u8,
    replacement: []const u8,
) ![]u8 {
    if (needle.len == 0) {
        return allocator.dupe(u8, text);
    }

    // Count occurrences to pre-allocate
    var count: usize = 0;
    var pos: usize = 0;
    while (pos < text.len) {
        if (indexOfIgnoreCase(text[pos..], needle)) |found| {
            count += 1;
            pos += found + needle.len;
        } else {
            break;
        }
    }

    if (count == 0) {
        return allocator.dupe(u8, text);
    }

    // Calculate final size
    const new_len = text.len - (count * needle.len) + (count * replacement.len);
    var result = try allocator.alloc(u8, new_len);
    errdefer allocator.free(result);

    // Perform replacement
    var src_pos: usize = 0;
    var dest_pos: usize = 0;

    while (src_pos < text.len) {
        if (indexOfIgnoreCase(text[src_pos..], needle)) |found| {
            // Copy text before needle
            @memcpy(result[dest_pos..][0..found], text[src_pos..][0..found]);
            dest_pos += found;

            // Copy replacement
            @memcpy(result[dest_pos..][0..replacement.len], replacement);
            dest_pos += replacement.len;

            src_pos += found + needle.len;
        } else {
            // Copy remaining text
            const remaining = text[src_pos..];
            @memcpy(result[dest_pos..][0..remaining.len], remaining);
            break;
        }
    }

    return result;
}
// ANCHOR_END: case_insensitive_replace

/// Replace first occurrence only (case-insensitive)
pub fn replaceFirstIgnoreCase(
    allocator: mem.Allocator,
    text: []const u8,
    needle: []const u8,
    replacement: []const u8,
) ![]u8 {
    if (indexOfIgnoreCase(text, needle)) |pos| {
        const new_len = text.len - needle.len + replacement.len;
        var result = try allocator.alloc(u8, new_len);
        errdefer allocator.free(result);

        // Copy before needle
        @memcpy(result[0..pos], text[0..pos]);

        // Copy replacement
        @memcpy(result[pos..][0..replacement.len], replacement);

        // Copy after needle
        const after_start = pos + needle.len;
        const after_len = text.len - after_start;
        @memcpy(result[pos + replacement.len ..][0..after_len], text[after_start..]);

        return result;
    }

    return allocator.dupe(u8, text);
}

// ANCHOR: case_conversion
/// Convert string to lowercase (allocates new string)
pub fn toLower(allocator: mem.Allocator, text: []const u8) ![]u8 {
    return ascii.allocLowerString(allocator, text);
}

/// Convert string to uppercase (allocates new string)
pub fn toUpper(allocator: mem.Allocator, text: []const u8) ![]u8 {
    return ascii.allocUpperString(allocator, text);
}
// ANCHOR_END: case_conversion

/// Check if text starts with prefix (case-insensitive)
pub fn startsWithIgnoreCase(text: []const u8, prefix: []const u8) bool {
    if (prefix.len > text.len) return false;
    return ascii.eqlIgnoreCase(text[0..prefix.len], prefix);
}

/// Check if text ends with suffix (case-insensitive)
pub fn endsWithIgnoreCase(text: []const u8, suffix: []const u8) bool {
    if (suffix.len > text.len) return false;
    return ascii.eqlIgnoreCase(text[text.len - suffix.len ..], suffix);
}

test "case-insensitive equality" {
    try testing.expect(eqlIgnoreCase("hello", "HELLO"));
    try testing.expect(eqlIgnoreCase("Hello", "hello"));
    try testing.expect(eqlIgnoreCase("HeLLo", "hEllO"));
    try testing.expect(!eqlIgnoreCase("hello", "world"));
}

test "case-insensitive indexOf" {
    const text = "Hello World";

    try testing.expectEqual(@as(?usize, 0), indexOfIgnoreCase(text, "hello"));
    try testing.expectEqual(@as(?usize, 0), indexOfIgnoreCase(text, "HELLO"));
    try testing.expectEqual(@as(?usize, 6), indexOfIgnoreCase(text, "world"));
    try testing.expectEqual(@as(?usize, 6), indexOfIgnoreCase(text, "WORLD"));
    try testing.expectEqual(@as(?usize, null), indexOfIgnoreCase(text, "xyz"));
}

test "case-insensitive lastIndexOf" {
    const text = "Hello hello world";

    try testing.expectEqual(@as(?usize, 6), lastIndexOfIgnoreCase(text, "hello"));
    try testing.expectEqual(@as(?usize, 6), lastIndexOfIgnoreCase(text, "HELLO"));
    try testing.expectEqual(@as(?usize, null), lastIndexOfIgnoreCase(text, "xyz"));
}

test "case-insensitive contains" {
    const text = "The Quick Brown Fox";

    try testing.expect(containsIgnoreCase(text, "quick"));
    try testing.expect(containsIgnoreCase(text, "QUICK"));
    try testing.expect(containsIgnoreCase(text, "QuIcK"));
    try testing.expect(containsIgnoreCase(text, "brown"));
    try testing.expect(!containsIgnoreCase(text, "lazy"));
}

test "case-insensitive count" {
    const text = "Hello hello HELLO world";

    try testing.expectEqual(@as(usize, 3), countIgnoreCase(text, "hello"));
    try testing.expectEqual(@as(usize, 3), countIgnoreCase(text, "HELLO"));
    try testing.expectEqual(@as(usize, 1), countIgnoreCase(text, "world"));
    try testing.expectEqual(@as(usize, 0), countIgnoreCase(text, "xyz"));
}

test "case-insensitive replace all" {
    const text = "Hello hello HELLO world";
    const result = try replaceAllIgnoreCase(testing.allocator, text, "hello", "hi");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hi hi hi world", result);
}

test "case-insensitive replace first" {
    const text = "Hello hello HELLO world";
    const result = try replaceFirstIgnoreCase(testing.allocator, text, "hello", "hi");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hi hello HELLO world", result);
}

test "case-insensitive replace mixed case" {
    const text = "The Quick Brown Fox";
    const result = try replaceAllIgnoreCase(testing.allocator, text, "QUICK", "Slow");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("The Slow Brown Fox", result);
}

test "case-insensitive replace not found" {
    const text = "hello world";
    const result = try replaceAllIgnoreCase(testing.allocator, text, "XYZ", "abc");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello world", result);
}

test "convert to lowercase" {
    const text = "Hello WORLD";
    const result = try toLower(testing.allocator, text);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello world", result);
}

test "convert to uppercase" {
    const text = "Hello world";
    const result = try toUpper(testing.allocator, text);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("HELLO WORLD", result);
}

test "case-insensitive startsWith" {
    const text = "Hello World";

    try testing.expect(startsWithIgnoreCase(text, "hello"));
    try testing.expect(startsWithIgnoreCase(text, "HELLO"));
    try testing.expect(startsWithIgnoreCase(text, "HeLLo"));
    try testing.expect(!startsWithIgnoreCase(text, "world"));
}

test "case-insensitive endsWith" {
    const text = "Hello World";

    try testing.expect(endsWithIgnoreCase(text, "world"));
    try testing.expect(endsWithIgnoreCase(text, "WORLD"));
    try testing.expect(endsWithIgnoreCase(text, "WoRLd"));
    try testing.expect(!endsWithIgnoreCase(text, "hello"));
}

test "search in mixed case text" {
    const text = "ThE qUiCk BrOwN fOx JuMpS oVeR tHe LaZy DoG";

    try testing.expect(containsIgnoreCase(text, "quick"));
    try testing.expect(containsIgnoreCase(text, "BROWN"));
    try testing.expect(containsIgnoreCase(text, "fox"));
    try testing.expect(containsIgnoreCase(text, "LAZY"));
}

test "case-insensitive file extension check" {
    const filename1 = "document.PDF";
    const filename2 = "image.Jpg";
    const filename3 = "script.TXT";

    try testing.expect(endsWithIgnoreCase(filename1, ".pdf"));
    try testing.expect(endsWithIgnoreCase(filename2, ".jpg"));
    try testing.expect(endsWithIgnoreCase(filename3, ".txt"));
}

test "case-insensitive URL protocol" {
    const url1 = "HTTP://example.com";
    const url2 = "Https://secure.com";

    try testing.expect(startsWithIgnoreCase(url1, "http://"));
    try testing.expect(startsWithIgnoreCase(url2, "https://"));
}

test "case-insensitive email search" {
    const text = "Contact us at SUPPORT@EXAMPLE.COM for help";

    try testing.expect(containsIgnoreCase(text, "support@example.com"));
    try testing.expect(containsIgnoreCase(text, "SUPPORT@EXAMPLE.COM"));
}

test "normalize text for comparison" {
    const text1 = "Hello World";
    const text2 = "hello world";

    const lower1 = try toLower(testing.allocator, text1);
    defer testing.allocator.free(lower1);

    const lower2 = try toLower(testing.allocator, text2);
    defer testing.allocator.free(lower2);

    try testing.expectEqualStrings(lower1, lower2);
}

test "case-insensitive replace preserves case context" {
    // Note: This is a simple replace that doesn't preserve original case
    // Just replaces with exact replacement text
    const text = "Hello HELLO hello";
    const result = try replaceAllIgnoreCase(testing.allocator, text, "hello", "Goodbye");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Goodbye Goodbye Goodbye", result);
}

test "memory safety - case-insensitive operations" {
    const text = "Test TEST test";
    const result = try replaceAllIgnoreCase(testing.allocator, text, "test", "pass");
    defer testing.allocator.free(result);

    // testing.allocator will detect leaks
    try testing.expect(result.len > 0);
}

test "UTF-8 with case operations" {
    const text = "Hello 世界";
    const lower = try toLower(testing.allocator, text);
    defer testing.allocator.free(lower);

    // ASCII lowercase, UTF-8 characters unchanged
    try testing.expectEqualStrings("hello 世界", lower);
}

test "empty string case operations" {
    const empty = "";

    try testing.expect(eqlIgnoreCase(empty, ""));
    try testing.expectEqual(@as(?usize, null), indexOfIgnoreCase(empty, "test"));

    const result = try replaceAllIgnoreCase(testing.allocator, empty, "test", "replace");
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("", result);
}

test "single character case-insensitive" {
    try testing.expect(eqlIgnoreCase("a", "A"));
    try testing.expect(eqlIgnoreCase("Z", "z"));
    try testing.expectEqual(@as(?usize, 0), indexOfIgnoreCase("Hello", "h"));
}

test "case-insensitive with special characters" {
    const text = "Hello, World!";

    try testing.expect(containsIgnoreCase(text, "HELLO,"));
    try testing.expect(containsIgnoreCase(text, "world!"));
}

test "security - case-insensitive bounds checking" {
    const text = "short";

    // Won't overflow
    try testing.expectEqual(@as(?usize, null), indexOfIgnoreCase(text, "very long needle"));
    try testing.expect(!containsIgnoreCase(text, "very long needle that is much longer than text"));
}
