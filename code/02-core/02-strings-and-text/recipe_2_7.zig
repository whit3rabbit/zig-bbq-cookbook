// Recipe 2.7: Stripping unwanted characters
// Target Zig Version: 0.15.2
//
// This recipe demonstrates removing unwanted characters from strings,
// including whitespace trimming, character filtering, and cleanup operations.

const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const ascii = std.ascii;

/// Remove whitespace from both ends
// ANCHOR: basic_trimming
pub fn trim(text: []const u8) []const u8 {
    return mem.trim(u8, text, " \t\n\r");
}

/// Remove whitespace from start only
pub fn trimLeft(text: []const u8) []const u8 {
    return mem.trimLeft(u8, text, " \t\n\r");
}

/// Remove whitespace from end only
pub fn trimRight(text: []const u8) []const u8 {
    return mem.trimRight(u8, text, " \t\n\r");
}

/// Remove specific characters from both ends
pub fn trimChars(text: []const u8, chars: []const u8) []const u8 {
    return mem.trim(u8, text, chars);
}

/// Remove specific characters from start
pub fn trimLeftChars(text: []const u8, chars: []const u8) []const u8 {
    return mem.trimLeft(u8, text, chars);
}

/// Remove specific characters from end
pub fn trimRightChars(text: []const u8, chars: []const u8) []const u8 {
    return mem.trimRight(u8, text, chars);
}
// ANCHOR_END: basic_trimming

/// Remove all occurrences of specific characters (allocates new string)
// ANCHOR: remove_keep_chars
pub fn removeChars(
    allocator: mem.Allocator,
    text: []const u8,
    chars_to_remove: []const u8,
) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    for (text) |char| {
        var should_keep = true;
        for (chars_to_remove) |remove_char| {
            if (char == remove_char) {
                should_keep = false;
                break;
            }
        }
        if (should_keep) {
            try result.append(allocator, char);
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Keep only specific characters (allocates new string)
pub fn keepChars(
    allocator: mem.Allocator,
    text: []const u8,
    chars_to_keep: []const u8,
) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    for (text) |char| {
        for (chars_to_keep) |keep_char| {
            if (char == keep_char) {
                try result.append(allocator, char);
                break;
            }
        }
    }

    return result.toOwnedSlice(allocator);
}
// ANCHOR_END: remove_keep_chars

/// Remove non-alphanumeric characters (allocates new string)
// ANCHOR: filter_by_type
pub fn removeNonAlphanumeric(
    allocator: mem.Allocator,
    text: []const u8,
) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    for (text) |char| {
        if (ascii.isAlphanumeric(char)) {
            try result.append(allocator, char);
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Remove non-alphabetic characters (allocates new string)
pub fn removeNonAlphabetic(
    allocator: mem.Allocator,
    text: []const u8,
) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    for (text) |char| {
        if (ascii.isAlphabetic(char)) {
            try result.append(allocator, char);
        }
    }

    return result.toOwnedSlice(allocator);
}
// ANCHOR_END: filter_by_type

/// Remove non-digit characters (allocates new string)
pub fn removeNonDigits(
    allocator: mem.Allocator,
    text: []const u8,
) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    for (text) |char| {
        if (ascii.isDigit(char)) {
            try result.append(allocator, char);
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Collapse multiple spaces into single space (allocates new string)
pub fn collapseSpaces(
    allocator: mem.Allocator,
    text: []const u8,
) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    var prev_was_space = false;
    for (text) |char| {
        const is_space = char == ' ';
        if (is_space and prev_was_space) {
            continue; // Skip consecutive spaces
        }
        try result.append(allocator, char);
        prev_was_space = is_space;
    }

    return result.toOwnedSlice(allocator);
}

/// Remove control characters (allocates new string)
pub fn removeControlChars(
    allocator: mem.Allocator,
    text: []const u8,
) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    for (text) |char| {
        if (!ascii.isControl(char)) {
            try result.append(allocator, char);
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Strip prefix if present, returns slice or original
pub fn stripPrefix(text: []const u8, prefix: []const u8) []const u8 {
    if (mem.startsWith(u8, text, prefix)) {
        return text[prefix.len..];
    }
    return text;
}

/// Strip suffix if present, returns slice or original
pub fn stripSuffix(text: []const u8, suffix: []const u8) []const u8 {
    if (mem.endsWith(u8, text, suffix)) {
        return text[0 .. text.len - suffix.len];
    }
    return text;
}

test "trim whitespace from both ends" {
    try testing.expectEqualStrings("hello", trim("  hello  "));
    try testing.expectEqualStrings("hello", trim("\t\nhello\r\n"));
    try testing.expectEqualStrings("hello world", trim("  hello world  "));
    try testing.expectEqualStrings("", trim("   "));
}

test "trim whitespace from left" {
    try testing.expectEqualStrings("hello  ", trimLeft("  hello  "));
    try testing.expectEqualStrings("hello\r\n", trimLeft("\t\nhello\r\n"));
}

test "trim whitespace from right" {
    try testing.expectEqualStrings("  hello", trimRight("  hello  "));
    try testing.expectEqualStrings("\t\nhello", trimRight("\t\nhello\r\n"));
}

test "trim specific characters" {
    try testing.expectEqualStrings("hello", trimChars("...hello...", "."));
    try testing.expectEqualStrings("world", trimChars("===world===", "="));
    try testing.expectEqualStrings("test", trimChars("--test--", "-"));
}

test "trim multiple character set" {
    try testing.expectEqualStrings("hello", trimChars(".,!hello!,.", ".,!"));
    try testing.expectEqualStrings("world", trimChars("123world321", "123"));
}

test "remove all occurrences of characters" {
    const result = try removeChars(testing.allocator, "hello, world!", ",!");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello world", result);
}

test "remove spaces" {
    const result = try removeChars(testing.allocator, "h e l l o", " ");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello", result);
}

test "keep only specific characters" {
    const result = try keepChars(testing.allocator, "abc123xyz789", "0123456789");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("123789", result);
}

test "remove non-alphanumeric" {
    const result = try removeNonAlphanumeric(testing.allocator, "hello, world! 123");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("helloworld123", result);
}

test "remove non-alphabetic" {
    const result = try removeNonAlphabetic(testing.allocator, "hello123world456");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("helloworld", result);
}

test "remove non-digits" {
    const result = try removeNonDigits(testing.allocator, "Product ID: 12345");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("12345", result);
}

test "extract phone number digits" {
    const result = try removeNonDigits(testing.allocator, "(555) 123-4567");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("5551234567", result);
}

test "collapse multiple spaces" {
    const result = try collapseSpaces(testing.allocator, "hello    world");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello world", result);
}

test "collapse multiple spaces in text" {
    const result = try collapseSpaces(testing.allocator, "too   many    spaces");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("too many spaces", result);
}

test "remove control characters" {
    const text = "hello\x00world\x01test\x1F";
    const result = try removeControlChars(testing.allocator, text);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("helloworldtest", result);
}

test "strip prefix" {
    try testing.expectEqualStrings("world", stripPrefix("hello world", "hello "));
    try testing.expectEqualStrings("example.com", stripPrefix("http://example.com", "http://"));
    try testing.expectEqualStrings("test", stripPrefix("test", "missing"));
}

test "strip suffix" {
    try testing.expectEqualStrings("document", stripSuffix("document.txt", ".txt"));
    try testing.expectEqualStrings("image", stripSuffix("image.jpg", ".jpg"));
    try testing.expectEqualStrings("test", stripSuffix("test", "missing"));
}

test "sanitize filename" {
    const filename = "my file/name\\with:bad*chars?.txt";
    const result = try removeChars(testing.allocator, filename, "/\\:*?");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("my filenamewithbadchars.txt", result);
}

test "clean up user input" {
    const input = "  hello   world  ";
    const trimmed = trim(input);
    const result = try collapseSpaces(testing.allocator, trimmed);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello world", result);
}

test "extract numbers from text" {
    const text = "Price: $123.45";
    const result = try removeNonDigits(testing.allocator, text);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("12345", result);
}

test "remove punctuation" {
    const text = "Hello, World! How are you?";
    const result = try removeChars(testing.allocator, text, ",.!?");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Hello World How are you", result);
}

test "clean URL" {
    const url = "https://example.com/path";
    const cleaned = stripPrefix(url, "https://");

    try testing.expectEqualStrings("example.com/path", cleaned);
}

test "trim quotes" {
    try testing.expectEqualStrings("hello", trimChars("\"hello\"", "\""));
    try testing.expectEqualStrings("world", trimChars("'world'", "'"));
}

test "normalize whitespace" {
    const text = "  hello\t\nworld  ";
    const trimmed = trim(text);

    try testing.expectEqualStrings("hello\t\nworld", trimmed);
}

test "strip path separators" {
    try testing.expectEqualStrings("file.txt", trimChars("/file.txt", "/"));
    try testing.expectEqualStrings("dir", trimChars("/dir/", "/"));
}

test "memory safety - trim operations" {
    // Trim doesn't allocate, just returns slice
    const result = trim("  test  ");
    try testing.expect(result.len > 0);
}

test "memory safety - remove operations" {
    const result = try removeChars(testing.allocator, "test123", "123");
    defer testing.allocator.free(result);

    // testing.allocator will detect leaks
    try testing.expect(result.len > 0);
}

test "UTF-8 trimming" {
    const text = "  Hello 世界  ";
    const trimmed = trim(text);

    try testing.expectEqualStrings("Hello 世界", trimmed);
}

test "empty string operations" {
    try testing.expectEqualStrings("", trim(""));
    try testing.expectEqualStrings("", trim("   "));

    const result = try removeChars(testing.allocator, "", "abc");
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("", result);
}

test "no characters to remove" {
    const result = try removeChars(testing.allocator, "hello", "xyz");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello", result);
}

test "security - bounds checking" {
    // Safe operations, won't overflow
    try testing.expectEqualStrings("", trim(""));
    const result = try removeChars(testing.allocator, "test", "very long character set");
    defer testing.allocator.free(result);
    try testing.expect(result.len <= "test".len);
}
