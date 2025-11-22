// Recipe 2.8: Combining and concatenating strings
// Target Zig Version: 0.15.2
//
// This recipe demonstrates various ways to combine and concatenate strings
// using allocators, ArrayList, join, and format functions.

const std = @import("std");
const testing = std.testing;
const mem = std.mem;

/// Concatenate two strings (allocates new string)
// ANCHOR: basic_concat
pub fn concat(
    allocator: mem.Allocator,
    a: []const u8,
    b: []const u8,
) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    try result.appendSlice(allocator, a);
    try result.appendSlice(allocator, b);

    return result.toOwnedSlice(allocator);
}

/// Concatenate multiple strings (allocates new string)
pub fn concatMultiple(
    allocator: mem.Allocator,
    strings: []const []const u8,
) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    for (strings) |str| {
        try result.appendSlice(allocator, str);
    }

    return result.toOwnedSlice(allocator);
}
// ANCHOR_END: basic_concat

/// Join strings with a separator (allocates new string)
// ANCHOR: join_strings
pub fn join(
    allocator: mem.Allocator,
    separator: []const u8,
    strings: []const []const u8,
) ![]u8 {
    if (strings.len == 0) return allocator.dupe(u8, "");
    if (strings.len == 1) return allocator.dupe(u8, strings[0]);

    // Calculate total size
    var total_size: usize = 0;
    for (strings) |str| {
        total_size += str.len;
    }
    total_size += separator.len * (strings.len - 1);

    var result = try allocator.alloc(u8, total_size);
    errdefer allocator.free(result);

    var pos: usize = 0;
    for (strings, 0..) |str, i| {
        @memcpy(result[pos..][0..str.len], str);
        pos += str.len;

        if (i < strings.len - 1) {
            @memcpy(result[pos..][0..separator.len], separator);
            pos += separator.len;
        }
    }

    return result;
}

/// Join strings using stdlib mem.join
pub fn joinStdlib(
    allocator: mem.Allocator,
    separator: []const u8,
    strings: []const []const u8,
) ![]u8 {
    return mem.join(allocator, separator, strings);
}
// ANCHOR_END: join_strings

/// Build string using ArrayList
// ANCHOR: string_builder
pub fn buildString(
    allocator: mem.Allocator,
    parts: []const []const u8,
) ![]u8 {
    var builder = std.ArrayList(u8){};
    errdefer builder.deinit(allocator);

    for (parts) |part| {
        try builder.appendSlice(allocator, part);
    }

    return builder.toOwnedSlice(allocator);
}

/// Repeat a string n times (allocates new string)
pub fn repeat(
    allocator: mem.Allocator,
    text: []const u8,
    count: usize,
) ![]u8 {
    if (count == 0) return allocator.dupe(u8, "");

    const total_size = text.len * count;
    var result = try allocator.alloc(u8, total_size);
    errdefer allocator.free(result);

    var pos: usize = 0;
    var i: usize = 0;
    while (i < count) : (i += 1) {
        @memcpy(result[pos..][0..text.len], text);
        pos += text.len;
    }

    return result;
}
// ANCHOR_END: string_builder

/// Pad string to width with character (left aligned)
pub fn padRight(
    allocator: mem.Allocator,
    text: []const u8,
    width: usize,
    pad_char: u8,
) ![]u8 {
    if (text.len >= width) return allocator.dupe(u8, text);

    var result = try allocator.alloc(u8, width);
    errdefer allocator.free(result);

    @memcpy(result[0..text.len], text);

    var i: usize = text.len;
    while (i < width) : (i += 1) {
        result[i] = pad_char;
    }

    return result;
}

/// Pad string to width with character (right aligned)
pub fn padLeft(
    allocator: mem.Allocator,
    text: []const u8,
    width: usize,
    pad_char: u8,
) ![]u8 {
    if (text.len >= width) return allocator.dupe(u8, text);

    var result = try allocator.alloc(u8, width);
    errdefer allocator.free(result);

    const pad_count = width - text.len;
    var i: usize = 0;
    while (i < pad_count) : (i += 1) {
        result[i] = pad_char;
    }

    @memcpy(result[pad_count..][0..text.len], text);

    return result;
}

/// Center string in width with character
pub fn center(
    allocator: mem.Allocator,
    text: []const u8,
    width: usize,
    pad_char: u8,
) ![]u8 {
    if (text.len >= width) return allocator.dupe(u8, text);

    var result = try allocator.alloc(u8, width);
    errdefer allocator.free(result);

    const total_padding = width - text.len;
    const left_padding = total_padding / 2;

    var i: usize = 0;
    while (i < left_padding) : (i += 1) {
        result[i] = pad_char;
    }

    @memcpy(result[left_padding..][0..text.len], text);

    i = left_padding + text.len;
    while (i < width) : (i += 1) {
        result[i] = pad_char;
    }

    return result;
}

/// Intersperse a separator between characters
pub fn intersperse(
    allocator: mem.Allocator,
    text: []const u8,
    separator: []const u8,
) ![]u8 {
    if (text.len == 0) return allocator.dupe(u8, "");
    if (text.len == 1) return allocator.dupe(u8, text);

    const total_size = text.len + separator.len * (text.len - 1);
    var result = try allocator.alloc(u8, total_size);
    errdefer allocator.free(result);

    var pos: usize = 0;
    for (text, 0..) |char, i| {
        result[pos] = char;
        pos += 1;

        if (i < text.len - 1) {
            @memcpy(result[pos..][0..separator.len], separator);
            pos += separator.len;
        }
    }

    return result;
}

test "concatenate two strings" {
    const result = try concat(testing.allocator, "hello", " world");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello world", result);
}

test "concatenate empty strings" {
    const result = try concat(testing.allocator, "", "hello");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello", result);
}

test "concatenate multiple strings" {
    const strings = [_][]const u8{ "one", "two", "three" };
    const result = try concatMultiple(testing.allocator, &strings);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("onetwothree", result);
}

test "join with separator" {
    const strings = [_][]const u8{ "apple", "banana", "cherry" };
    const result = try join(testing.allocator, ", ", &strings);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("apple, banana, cherry", result);
}

test "join with space separator" {
    const strings = [_][]const u8{ "hello", "world" };
    const result = try join(testing.allocator, " ", &strings);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello world", result);
}

test "join empty array" {
    const strings = [_][]const u8{};
    const result = try join(testing.allocator, ", ", &strings);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("", result);
}

test "join single string" {
    const strings = [_][]const u8{"only"};
    const result = try join(testing.allocator, ", ", &strings);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("only", result);
}

test "join stdlib" {
    const strings = [_][]const u8{ "a", "b", "c" };
    const result = try joinStdlib(testing.allocator, "-", &strings);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("a-b-c", result);
}

test "build string with ArrayList" {
    const parts = [_][]const u8{ "Hello", ", ", "World", "!" };
    const result = try buildString(testing.allocator, &parts);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Hello, World!", result);
}

test "repeat string" {
    const result = try repeat(testing.allocator, "ab", 3);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("ababab", result);
}

test "repeat zero times" {
    const result = try repeat(testing.allocator, "test", 0);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("", result);
}

test "repeat once" {
    const result = try repeat(testing.allocator, "test", 1);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("test", result);
}

test "pad right" {
    const result = try padRight(testing.allocator, "hello", 10, ' ');
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello     ", result);
}

test "pad right no padding needed" {
    const result = try padRight(testing.allocator, "hello", 5, ' ');
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello", result);
}

test "pad left" {
    const result = try padLeft(testing.allocator, "42", 5, '0');
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("00042", result);
}

test "pad left no padding needed" {
    const result = try padLeft(testing.allocator, "hello", 3, ' ');
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello", result);
}

test "center string" {
    const result = try center(testing.allocator, "hi", 6, ' ');
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("  hi  ", result);
}

test "center string odd padding" {
    const result = try center(testing.allocator, "hi", 7, ' ');
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("  hi   ", result);
}

test "intersperse characters" {
    const result = try intersperse(testing.allocator, "abc", "-");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("a-b-c", result);
}

test "intersperse empty string" {
    const result = try intersperse(testing.allocator, "", "-");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("", result);
}

test "intersperse single char" {
    const result = try intersperse(testing.allocator, "a", "-");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("a", result);
}

test "build CSV line" {
    const fields = [_][]const u8{ "Name", "Age", "City" };
    const result = try join(testing.allocator, ",", &fields);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Name,Age,City", result);
}

test "build path" {
    const parts = [_][]const u8{ "home", "user", "documents", "file.txt" };
    const result = try join(testing.allocator, "/", &parts);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("home/user/documents/file.txt", result);
}

test "build HTML tag" {
    const tag_parts = [_][]const u8{ "<", "div", ">" };
    const result = try concatMultiple(testing.allocator, &tag_parts);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("<div>", result);
}

test "build table row" {
    const columns = [_][]const u8{ "10", "20", "30" };
    const result = try join(testing.allocator, " | ", &columns);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("10 | 20 | 30", result);
}

test "create divider line" {
    const result = try repeat(testing.allocator, "-", 40);
    defer testing.allocator.free(result);

    try testing.expectEqual(@as(usize, 40), result.len);
    for (result) |c| {
        try testing.expectEqual(@as(u8, '-'), c);
    }
}

test "format phone number" {
    const parts = [_][]const u8{ "(555)", " ", "123", "-", "4567" };
    const result = try concatMultiple(testing.allocator, &parts);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("(555) 123-4567", result);
}

test "memory safety - concatenation" {
    const result = try concat(testing.allocator, "test", "123");
    defer testing.allocator.free(result);

    // testing.allocator will detect leaks
    try testing.expect(result.len > 0);
}

test "UTF-8 concatenation" {
    const result = try concat(testing.allocator, "Hello ", "世界");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Hello 世界", result);
}

test "UTF-8 join" {
    const strings = [_][]const u8{ "Hello", "世界", "Zig" };
    const result = try join(testing.allocator, " ", &strings);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Hello 世界 Zig", result);
}

test "security - large concatenation" {
    const strings = [_][]const u8{ "a", "b", "c", "d", "e" };
    const result = try concatMultiple(testing.allocator, &strings);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("abcde", result);
}

test "security - empty parts" {
    const strings = [_][]const u8{ "", "", "" };
    const result = try concatMultiple(testing.allocator, &strings);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("", result);
}
