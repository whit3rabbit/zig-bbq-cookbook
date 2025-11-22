// Recipe 2.4: Matching and searching for text patterns
// Target Zig Version: 0.15.2
//
// This recipe demonstrates various string searching techniques in Zig
// using std.mem functions for substring search and pattern matching.

const std = @import("std");
const testing = std.testing;
const mem = std.mem;

/// Find first occurrence of substring, returns index or null
// ANCHOR: basic_search
pub fn indexOf(text: []const u8, needle: []const u8) ?usize {
    return mem.indexOf(u8, text, needle);
}

/// Find last occurrence of substring, returns index or null
pub fn lastIndexOf(text: []const u8, needle: []const u8) ?usize {
    return mem.lastIndexOf(u8, text, needle);
}

/// Find first occurrence of any character in set
pub fn indexOfAny(text: []const u8, chars: []const u8) ?usize {
    return mem.indexOfAny(u8, text, chars);
}
// ANCHOR_END: basic_search

/// Find first occurrence NOT in character set
pub fn indexOfNone(text: []const u8, chars: []const u8) ?usize {
    return mem.indexOfNone(u8, text, chars);
}

/// Find first occurrence of a single character
pub fn indexOfScalar(text: []const u8, char: u8) ?usize {
    return mem.indexOfScalar(u8, text, char);
}

/// Check if text contains substring
pub fn contains(text: []const u8, needle: []const u8) bool {
    return mem.indexOf(u8, text, needle) != null;
}

/// Count occurrences of substring (non-overlapping)
// ANCHOR: count_find_all
pub fn count(text: []const u8, needle: []const u8) usize {
    if (needle.len == 0) return 0;

    var occurrences: usize = 0;
    var pos: usize = 0;

    while (pos < text.len) {
        if (mem.indexOf(u8, text[pos..], needle)) |found| {
            occurrences += 1;
            pos += found + needle.len;
        } else {
            break;
        }
    }

    return occurrences;
}

/// Find all occurrences of substring, returns ArrayList of indices
pub fn findAll(
    allocator: mem.Allocator,
    text: []const u8,
    needle: []const u8,
) !std.ArrayList(usize) {
    var result = std.ArrayList(usize){};
    errdefer result.deinit(allocator);

    if (needle.len == 0) return result;

    var pos: usize = 0;
    while (pos < text.len) {
        if (mem.indexOf(u8, text[pos..], needle)) |found| {
            try result.append(allocator, pos + found);
            pos += found + needle.len;
        } else {
            break;
        }
    }

    return result;
}
// ANCHOR_END: count_find_all

/// Check if text contains any of the given needles
// ANCHOR: contains_multiple
pub fn containsAny(text: []const u8, needles: []const []const u8) bool {
    for (needles) |needle| {
        if (contains(text, needle)) {
            return true;
        }
    }
    return false;
}

/// Check if text contains all of the given needles
pub fn containsAll(text: []const u8, needles: []const []const u8) bool {
    for (needles) |needle| {
        if (!contains(text, needle)) {
            return false;
        }
    }
    return true;
}
// ANCHOR_END: contains_multiple

test "find substring - basic" {
    const text = "hello world";

    try testing.expectEqual(@as(?usize, 0), indexOf(text, "hello"));
    try testing.expectEqual(@as(?usize, 6), indexOf(text, "world"));
    try testing.expectEqual(@as(?usize, 4), indexOf(text, "o"));
    try testing.expectEqual(@as(?usize, null), indexOf(text, "xyz"));
}

test "find last occurrence" {
    const text = "hello hello world";

    try testing.expectEqual(@as(?usize, 6), lastIndexOf(text, "hello"));
    try testing.expectEqual(@as(?usize, 9), lastIndexOf(text, "lo"));
    try testing.expectEqual(@as(?usize, null), lastIndexOf(text, "xyz"));
}

test "contains substring" {
    const text = "The quick brown fox";

    try testing.expect(contains(text, "quick"));
    try testing.expect(contains(text, "fox"));
    try testing.expect(!contains(text, "lazy"));
    try testing.expect(!contains(text, "Quick")); // Case sensitive
}

test "find character in set" {
    const text = "hello world";

    try testing.expectEqual(@as(?usize, 1), indexOfAny(text, "aeiou")); // First vowel
    try testing.expectEqual(@as(?usize, 0), indexOfAny(text, "h")); // First 'h'
    try testing.expectEqual(@as(?usize, null), indexOfAny(text, "xyz"));
}

test "find first character NOT in set" {
    const text = "   hello";

    try testing.expectEqual(@as(?usize, 3), indexOfNone(text, " ")); // First non-space

    const digits = "123abc";
    try testing.expectEqual(@as(?usize, 3), indexOfNone(digits, "0123456789"));
}

test "find single character" {
    const text = "hello world";

    try testing.expectEqual(@as(?usize, 4), indexOfScalar(text, 'o'));
    try testing.expectEqual(@as(?usize, 2), indexOfScalar(text, 'l'));
    try testing.expectEqual(@as(?usize, null), indexOfScalar(text, 'x'));
}

test "count occurrences" {
    const text = "hello hello world";

    try testing.expectEqual(@as(usize, 2), count(text, "hello"));
    try testing.expectEqual(@as(usize, 5), count(text, "l")); // 2 in first "hello", 2 in second "hello", 1 in "world"
    try testing.expectEqual(@as(usize, 1), count(text, "world"));
    try testing.expectEqual(@as(usize, 0), count(text, "xyz"));
}

test "count overlapping pattern" {
    // Non-overlapping count
    const text = "aaaa";
    try testing.expectEqual(@as(usize, 2), count(text, "aa")); // "aa|aa", not "a|a|a|a"
}

test "find all occurrences" {
    const text = "hello hello world";

    var positions = try findAll(testing.allocator, text, "hello");
    defer positions.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 2), positions.items.len);
    try testing.expectEqual(@as(usize, 0), positions.items[0]);
    try testing.expectEqual(@as(usize, 6), positions.items[1]);
}

test "find all single character" {
    const text = "hello world";

    var positions = try findAll(testing.allocator, text, "l");
    defer positions.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 3), positions.items.len);
    try testing.expectEqual(@as(usize, 2), positions.items[0]);
    try testing.expectEqual(@as(usize, 3), positions.items[1]);
    try testing.expectEqual(@as(usize, 9), positions.items[2]);
}

test "contains any of multiple needles" {
    const text = "The quick brown fox";
    const words = [_][]const u8{ "quick", "lazy", "dog" };

    try testing.expect(containsAny(text, &words)); // Contains "quick"

    const words2 = [_][]const u8{ "lazy", "dog", "cat" };
    try testing.expect(!containsAny(text, &words2)); // Contains none
}

test "contains all needles" {
    const text = "The quick brown fox";
    const words = [_][]const u8{ "quick", "brown", "fox" };

    try testing.expect(containsAll(text, &words));

    const words2 = [_][]const u8{ "quick", "lazy" };
    try testing.expect(!containsAll(text, &words2)); // Missing "lazy"
}

test "search in empty string" {
    const empty = "";

    try testing.expectEqual(@as(?usize, null), indexOf(empty, "test"));
    try testing.expectEqual(@as(usize, 0), count(empty, "test"));
    try testing.expect(!contains(empty, "test"));
}

test "search for empty string" {
    const text = "hello";

    // Empty needle matches at position 0
    try testing.expectEqual(@as(?usize, 0), indexOf(text, ""));
    try testing.expect(contains(text, ""));
}

test "find URL in text" {
    const text = "Visit https://example.com for more info";

    try testing.expect(contains(text, "https://"));
    try testing.expectEqual(@as(?usize, 6), indexOf(text, "https://"));
}

test "find email pattern" {
    const text = "Contact us at support@example.com for help";

    if (indexOf(text, "@")) |at_pos| {
        try testing.expectEqual(@as(usize, 21), at_pos);

        // Extract domain (simplified)
        const after_at = text[at_pos + 1 ..];
        try testing.expect(mem.startsWith(u8, after_at, "example.com"));
    } else {
        try testing.expect(false); // Should find @
    }
}

test "check file extension in path" {
    const path = "/path/to/file.txt";

    if (lastIndexOf(path, ".")) |dot_pos| {
        const ext = path[dot_pos..];
        try testing.expectEqualStrings(".txt", ext);
    }
}

test "find line breaks" {
    const text = "line1\nline2\nline3";

    var positions = try findAll(testing.allocator, text, "\n");
    defer positions.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 2), positions.items.len);
}

test "search for quotes" {
    const text = "She said \"hello\" and \"goodbye\"";

    var quotes = try findAll(testing.allocator, text, "\"");
    defer quotes.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 4), quotes.items.len);
}

test "find first digit" {
    const text = "Product ID: 12345";

    if (indexOfAny(text, "0123456789")) |pos| {
        try testing.expectEqual(@as(usize, 12), pos);
    } else {
        try testing.expect(false);
    }
}

test "find first non-whitespace" {
    const text = "   hello world";

    if (indexOfNone(text, " \t\n\r")) |pos| {
        try testing.expectEqual(@as(usize, 3), pos);
    } else {
        try testing.expect(false);
    }
}

test "validate password requirements" {
    const password = "MyP@ssw0rd";

    // Check for uppercase
    try testing.expect(indexOfAny(password, "ABCDEFGHIJKLMNOPQRSTUVWXYZ") != null);

    // Check for lowercase
    try testing.expect(indexOfAny(password, "abcdefghijklmnopqrstuvwxyz") != null);

    // Check for digit
    try testing.expect(indexOfAny(password, "0123456789") != null);

    // Check for special char
    try testing.expect(indexOfAny(password, "!@#$%^&*") != null);
}

test "find balanced brackets" {
    const text = "array[index]";

    const open = indexOf(text, "[");
    const close = indexOf(text, "]");

    try testing.expect(open != null and close != null);
    try testing.expect(close.? > open.?);
}

test "search case sensitivity" {
    const text = "Hello World";

    try testing.expect(contains(text, "Hello"));
    try testing.expect(!contains(text, "hello")); // Case sensitive
    try testing.expect(contains(text, "World"));
    try testing.expect(!contains(text, "world"));
}

test "UTF-8 substring search" {
    const text = "Hello 世界";

    try testing.expect(contains(text, "Hello"));
    try testing.expect(contains(text, "世界"));
    try testing.expect(contains(text, "世"));

    if (indexOf(text, "世界")) |pos| {
        try testing.expectEqual(@as(usize, 6), pos); // Byte position
    }
}

test "performance - multiple searches" {
    const text = "The quick brown fox jumps over the lazy dog";

    // Multiple searches should be fast
    try testing.expect(contains(text, "quick"));
    try testing.expect(contains(text, "brown"));
    try testing.expect(contains(text, "fox"));
    try testing.expect(contains(text, "lazy"));
    try testing.expect(contains(text, "dog"));
}

test "memory safety - no allocations for basic search" {
    const text = "hello world";

    // These operations don't allocate
    const idx = indexOf(text, "world");
    const has = contains(text, "hello");
    const cnt = count(text, "l");

    try testing.expect(idx != null);
    try testing.expect(has);
    try testing.expectEqual(@as(usize, 3), cnt);
}

test "security - bounds checking" {
    const text = "safe";

    // Won't overflow even with needle longer than text
    try testing.expectEqual(@as(?usize, null), indexOf(text, "very long needle"));
    try testing.expect(!contains(text, "very long needle that is much longer than text"));
}
