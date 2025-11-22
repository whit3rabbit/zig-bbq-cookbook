// Recipe 2.5: Searching and replacing text
// Target Zig Version: 0.15.2
//
// This recipe demonstrates various approaches to replacing text in strings,
// including single replacement, global replacement, and replace all.

const std = @import("std");
const testing = std.testing;
const mem = std.mem;

/// Replace all occurrences of needle with replacement
/// Returns number of replacements made
// ANCHOR: replace_all
pub fn replaceAll(
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
        if (mem.indexOf(u8, text[pos..], needle)) |found| {
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
        if (mem.indexOf(u8, text[src_pos..], needle)) |found| {
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
// ANCHOR_END: replace_all

/// Replace first occurrence only
// ANCHOR: replace_first
pub fn replaceFirst(
    allocator: mem.Allocator,
    text: []const u8,
    needle: []const u8,
    replacement: []const u8,
) ![]u8 {
    if (mem.indexOf(u8, text, needle)) |pos| {
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
// ANCHOR_END: replace_first

/// Replace using a callback function that writes to an ArrayList
/// The callback receives the allocator, matched needle, and output buffer.
/// This API ensures clear ownership: the callback writes directly to the output buffer,
/// avoiding ambiguity about memory allocation and preventing leaks.
// ANCHOR: replace_with_callback
pub fn replaceWith(
    allocator: mem.Allocator,
    text: []const u8,
    needle: []const u8,
    context: anytype,
    replaceFn: *const fn (@TypeOf(context), mem.Allocator, []const u8, *std.ArrayList(u8)) anyerror!void,
) ![]u8 {
    if (needle.len == 0) {
        return allocator.dupe(u8, text);
    }

    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    var pos: usize = 0;
    while (pos < text.len) {
        if (mem.indexOf(u8, text[pos..], needle)) |found| {
            // Append text before needle
            try result.appendSlice(allocator, text[pos..][0..found]);

            // Let callback write replacement directly to result
            try replaceFn(context, allocator, needle, &result);

            pos += found + needle.len;
        } else {
            // Append remaining text
            try result.appendSlice(allocator, text[pos..]);
            break;
        }
    }

    return result.toOwnedSlice(allocator);
}
// ANCHOR_END: replace_with_callback

/// Remove all occurrences of substring
pub fn removeAll(
    allocator: mem.Allocator,
    text: []const u8,
    needle: []const u8,
) ![]u8 {
    return replaceAll(allocator, text, needle, "");
}

/// Replacement pair type
pub const ReplacePair = struct {
    needle: []const u8,
    replacement: []const u8,
};

/// Replace multiple patterns - BASIC METHOD
/// Simple but inefficient: performs multiple passes over the text,
/// creating intermediate allocations for each replacement pair.
///
/// Time complexity: O(n * m) where n = text length, m = number of patterns
/// Space complexity: O(n * m) due to intermediate allocations
///
/// Use when:
/// - You have only 2-3 replacement pairs
/// - The text is small (< 1KB)
/// - Code simplicity is more important than performance
/// - Replacements might interfere with each other (order matters)
pub fn replaceMany(
    allocator: mem.Allocator,
    text: []const u8,
    replacements: []const ReplacePair,
) ![]u8 {
    var result = try allocator.dupe(u8, text);

    for (replacements) |pair| {
        const new_result = try replaceAll(allocator, result, pair.needle, pair.replacement);
        allocator.free(result);
        result = new_result;
    }

    return result;
}

/// Replace multiple patterns - OPTIMIZED METHOD
/// Single-pass algorithm that finds the earliest occurrence of any pattern
/// and performs replacement in one go.
///
/// Time complexity: O(n * m) for search but only one pass
/// Space complexity: O(n) single output buffer
///
/// Use when:
/// - You have many replacement pairs (4+)
/// - The text is large (> 1KB)
/// - Performance is critical
/// - You want to minimize memory allocations
/// - Replacement order doesn't matter (processes left to right)
pub fn replaceManyOptimized(
    allocator: mem.Allocator,
    text: []const u8,
    replacements: []const ReplacePair,
) ![]u8 {
    if (replacements.len == 0) {
        return allocator.dupe(u8, text);
    }

    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    var pos: usize = 0;

    while (pos < text.len) {
        // Find the earliest occurrence of any pattern
        var earliest_match: ?struct {
            index: usize,
            pair_idx: usize,
        } = null;

        for (replacements, 0..) |pair, pair_idx| {
            if (pair.needle.len == 0) continue;

            if (mem.indexOf(u8, text[pos..], pair.needle)) |found_offset| {
                const absolute_pos = pos + found_offset;

                if (earliest_match == null or absolute_pos < earliest_match.?.index) {
                    earliest_match = .{
                        .index = absolute_pos,
                        .pair_idx = pair_idx,
                    };
                }
            }
        }

        if (earliest_match) |match| {
            // Append text before the match
            try result.appendSlice(allocator, text[pos..match.index]);

            // Append the replacement
            const pair = replacements[match.pair_idx];
            try result.appendSlice(allocator, pair.replacement);

            // Move position past the matched needle
            pos = match.index + pair.needle.len;
        } else {
            // No more matches found, append remaining text
            try result.appendSlice(allocator, text[pos..]);
            break;
        }
    }

    return result.toOwnedSlice(allocator);
}

test "replace all occurrences" {
    const text = "hello hello world";
    const result = try replaceAll(testing.allocator, text, "hello", "hi");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hi hi world", result);
}

test "replace first occurrence only" {
    const text = "hello hello world";
    const result = try replaceFirst(testing.allocator, text, "hello", "hi");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hi hello world", result);
}

test "replace with empty string (remove)" {
    const text = "hello world";
    const result = try replaceAll(testing.allocator, text, " ", "");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("helloworld", result);
}

test "replace with longer string" {
    const text = "hi there";
    const result = try replaceAll(testing.allocator, text, "hi", "hello");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello there", result);
}

test "replace with shorter string" {
    const text = "hello world";
    const result = try replaceAll(testing.allocator, text, "hello", "hi");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hi world", result);
}

test "replace not found" {
    const text = "hello world";
    const result = try replaceAll(testing.allocator, text, "xyz", "abc");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello world", result);
}

test "replace empty needle" {
    const text = "hello";
    const result = try replaceAll(testing.allocator, text, "", "x");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello", result);
}

test "replace in empty text" {
    const text = "";
    const result = try replaceAll(testing.allocator, text, "hello", "hi");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("", result);
}

test "remove all occurrences" {
    const text = "hello, hello, world!";
    const result = try removeAll(testing.allocator, text, "hello, ");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("world!", result);
}

test "replace punctuation" {
    const text = "Hello, World!";
    const result = try replaceAll(testing.allocator, text, ",", "");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Hello World!", result);
}

test "replace line breaks" {
    const text = "line1\nline2\nline3";
    const result = try replaceAll(testing.allocator, text, "\n", " ");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("line1 line2 line3", result);
}

test "replace tabs with spaces" {
    const text = "col1\tcol2\tcol3";
    const result = try replaceAll(testing.allocator, text, "\t", "    ");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("col1    col2    col3", result);
}

test "normalize whitespace" {
    const text = "hello  world";
    const result = try replaceAll(testing.allocator, text, "  ", " ");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello world", result);
}

test "replace URL protocol" {
    const url = "http://example.com";
    const result = try replaceAll(testing.allocator, url, "http://", "https://");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("https://example.com", result);
}

test "replace file extension" {
    const filename = "document.txt";
    const result = try replaceAll(testing.allocator, filename, ".txt", ".md");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("document.md", result);
}

test "replace HTML entities" {
    const html = "Tom &amp; Jerry";
    const result = try replaceAll(testing.allocator, html, "&amp;", "&");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Tom & Jerry", result);
}

test "replace quotes" {
    const text = "She said 'hello'";
    const result = try replaceAll(testing.allocator, text, "'", "\"");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("She said \"hello\"", result);
}

test "replace multiple patterns" {
    const text = "hello world";
    const replacements = [_]ReplacePair{
        .{ .needle = "hello", .replacement = "hi" },
        .{ .needle = "world", .replacement = "there" },
    };

    const result = try replaceMany(testing.allocator, text, &replacements);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hi there", result);
}

test "censor profanity" {
    const text = "This is bad word";
    const result = try replaceAll(testing.allocator, text, "bad", "***");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("This is *** word", result);
}

/// Collapse runs of spaces into single spaces (single-pass algorithm)
fn collapseSpaces(allocator: mem.Allocator, text: []const u8) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    var in_space = false;
    for (text) |char| {
        if (char == ' ') {
            if (!in_space) {
                try result.append(allocator, ' ');
                in_space = true;
            }
            // Skip additional spaces
        } else {
            try result.append(allocator, char);
            in_space = false;
        }
    }

    return result.toOwnedSlice(allocator);
}

test "collapse multiple spaces - basic" {
    const text = "hello    world";
    const result = try collapseSpaces(testing.allocator, text);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello world", result);
}

test "collapse multiple spaces - edge cases" {
    // Leading spaces
    {
        const result = try collapseSpaces(testing.allocator, "   hello");
        defer testing.allocator.free(result);
        try testing.expectEqualStrings(" hello", result);
    }

    // Trailing spaces
    {
        const result = try collapseSpaces(testing.allocator, "hello   ");
        defer testing.allocator.free(result);
        try testing.expectEqualStrings("hello ", result);
    }

    // Mixed spacing
    {
        const result = try collapseSpaces(testing.allocator, "a  b   c    d");
        defer testing.allocator.free(result);
        try testing.expectEqualStrings("a b c d", result);
    }

    // No spaces
    {
        const result = try collapseSpaces(testing.allocator, "helloworld");
        defer testing.allocator.free(result);
        try testing.expectEqualStrings("helloworld", result);
    }

    // Only spaces
    {
        const result = try collapseSpaces(testing.allocator, "     ");
        defer testing.allocator.free(result);
        try testing.expectEqualStrings(" ", result);
    }
}

test "replaceWith - uppercase callback" {
    const Context = struct {
        fn upperCase(_: @This(), allocator: mem.Allocator, matched: []const u8, output: *std.ArrayList(u8)) !void {
            const upper = try std.ascii.allocUpperString(allocator, matched);
            defer allocator.free(upper);
            try output.appendSlice(allocator, upper);
        }
    };

    const text = "hello world hello";
    const result = try replaceWith(testing.allocator, text, "hello", Context{}, Context.upperCase);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("HELLO world HELLO", result);
}

test "replaceWith - dynamic replacement" {
    const Context = struct {
        count: usize = 0,

        fn numbered(self: *@This(), allocator: mem.Allocator, _: []const u8, output: *std.ArrayList(u8)) !void {
            self.count += 1;
            const num_str = try std.fmt.allocPrint(allocator, "[{d}]", .{self.count});
            defer allocator.free(num_str);
            try output.appendSlice(allocator, num_str);
        }
    };

    var ctx = Context{};
    const text = "X marks the X on the X";
    const result = try replaceWith(testing.allocator, text, "X", &ctx, Context.numbered);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("[1] marks the [2] on the [3]", result);
}

test "replaceWith - context-free simple replacement" {
    const Context = struct {
        fn simple(_: @This(), allocator: mem.Allocator, _: []const u8, output: *std.ArrayList(u8)) !void {
            try output.appendSlice(allocator, "REPLACED");
        }
    };

    const text = "foo bar foo";
    const result = try replaceWith(testing.allocator, text, "foo", Context{}, Context.simple);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("REPLACED bar REPLACED", result);
}

test "replaceWith - memory safety" {
    const Context = struct {
        fn allocatingCallback(_: @This(), allocator: mem.Allocator, matched: []const u8, output: *std.ArrayList(u8)) !void {
            // This callback allocates temporary memory, demonstrating safe cleanup
            const temp = try allocator.alloc(u8, matched.len * 2);
            defer allocator.free(temp);

            @memset(temp, '*');
            try output.appendSlice(allocator, temp);
        }
    };

    const text = "a b a";
    const result = try replaceWith(testing.allocator, text, "a", Context{}, Context.allocatingCallback);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("** b **", result);
    // testing.allocator will detect any leaks from the callback
}

test "replace overlapping patterns" {
    const text = "aaaa";
    const result = try replaceAll(testing.allocator, text, "aa", "b");
    defer testing.allocator.free(result);

    // Non-overlapping: "aa|aa" -> "bb"
    try testing.expectEqualStrings("bb", result);
}

test "replace with special characters" {
    const text = "Hello World";
    const result = try replaceAll(testing.allocator, text, " ", "_");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Hello_World", result);
}

test "replace path separators" {
    const path = "C:\\Users\\Name\\file.txt";
    const result = try replaceAll(testing.allocator, path, "\\", "/");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("C:/Users/Name/file.txt", result);
}

test "memory safety - proper cleanup" {
    const text = "test test test";
    const result = try replaceAll(testing.allocator, text, "test", "replaced");
    defer testing.allocator.free(result);

    // testing.allocator will detect leaks
    try testing.expect(result.len > 0);
}

test "security - large replacement" {
    const text = "x";
    const result = try replaceAll(testing.allocator, text, "x", "replacement");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("replacement", result);
}

test "UTF-8 replacement" {
    const text = "Hello World";
    const result = try replaceAll(testing.allocator, text, "World", "世界");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Hello 世界", result);
}

// Tests for optimized multi-pattern replacement

test "replaceManyOptimized - basic functionality" {
    const text = "hello world";
    const replacements = [_]ReplacePair{
        .{ .needle = "hello", .replacement = "hi" },
        .{ .needle = "world", .replacement = "there" },
    };

    const result = try replaceManyOptimized(testing.allocator, text, &replacements);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hi there", result);
}

test "replaceManyOptimized vs replaceMany - same result" {
    const text = "The quick brown fox jumps over the lazy dog";
    const replacements = [_]ReplacePair{
        .{ .needle = "quick", .replacement = "fast" },
        .{ .needle = "brown", .replacement = "red" },
        .{ .needle = "lazy", .replacement = "sleepy" },
    };

    const result1 = try replaceMany(testing.allocator, text, &replacements);
    defer testing.allocator.free(result1);

    const result2 = try replaceManyOptimized(testing.allocator, text, &replacements);
    defer testing.allocator.free(result2);

    try testing.expectEqualStrings(result1, result2);
}

test "replaceManyOptimized - HTML entity decoding" {
    const html = "&lt;div&gt;Hello &amp; goodbye&lt;/div&gt;";
    const entities = [_]ReplacePair{
        .{ .needle = "&lt;", .replacement = "<" },
        .{ .needle = "&gt;", .replacement = ">" },
        .{ .needle = "&amp;", .replacement = "&" },
        .{ .needle = "&quot;", .replacement = "\"" },
    };

    const result = try replaceManyOptimized(testing.allocator, html, &entities);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("<div>Hello & goodbye</div>", result);
}

test "replaceManyOptimized - overlapping patterns processed left-to-right" {
    const text = "aaabbbccc";
    const replacements = [_]ReplacePair{
        .{ .needle = "aaa", .replacement = "X" },
        .{ .needle = "bbb", .replacement = "Y" },
        .{ .needle = "ccc", .replacement = "Z" },
    };

    const result = try replaceManyOptimized(testing.allocator, text, &replacements);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("XYZ", result);
}

test "replaceManyOptimized - earliest match wins" {
    const text = "test testing";
    const replacements = [_]ReplacePair{
        .{ .needle = "testing", .replacement = "LONG" },
        .{ .needle = "test", .replacement = "SHORT" },
    };

    const result = try replaceManyOptimized(testing.allocator, text, &replacements);
    defer testing.allocator.free(result);

    // First "test" at position 0 is replaced with "SHORT"
    // Then "testing" at position 5 is replaced with "LONG"
    // When patterns match at the same position, first in array wins
    try testing.expectEqualStrings("SHORT LONG", result);
}

test "replaceManyOptimized - pattern order matters at same position" {
    const text = "testing";

    // When "test" is first in array
    const replacements1 = [_]ReplacePair{
        .{ .needle = "test", .replacement = "SHORT" },
        .{ .needle = "testing", .replacement = "LONG" },
    };
    const result1 = try replaceManyOptimized(testing.allocator, text, &replacements1);
    defer testing.allocator.free(result1);
    // "test" wins (first in array), result is "SHORTing"
    try testing.expectEqualStrings("SHORTing", result1);

    // When "testing" is first in array
    const replacements2 = [_]ReplacePair{
        .{ .needle = "testing", .replacement = "LONG" },
        .{ .needle = "test", .replacement = "SHORT" },
    };
    const result2 = try replaceManyOptimized(testing.allocator, text, &replacements2);
    defer testing.allocator.free(result2);
    // "testing" wins (first in array), result is "LONG"
    try testing.expectEqualStrings("LONG", result2);
}

test "replaceManyOptimized - no patterns" {
    const text = "hello world";
    const replacements = [_]ReplacePair{};

    const result = try replaceManyOptimized(testing.allocator, text, &replacements);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello world", result);
}

test "replaceManyOptimized - empty needles ignored" {
    const text = "hello world";
    const replacements = [_]ReplacePair{
        .{ .needle = "", .replacement = "X" },
        .{ .needle = "world", .replacement = "there" },
    };

    const result = try replaceManyOptimized(testing.allocator, text, &replacements);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello there", result);
}

test "replaceManyOptimized - programming language sanitization" {
    const code = "var x = 10; var y = 20; const z = 30;";
    const replacements = [_]ReplacePair{
        .{ .needle = "var ", .replacement = "let " },
        .{ .needle = "const ", .replacement = "let " },
    };

    const result = try replaceManyOptimized(testing.allocator, code, &replacements);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("let x = 10; let y = 20; let z = 30;", result);
}

test "replaceManyOptimized - text normalization" {
    const messy = "Hello...world!!!How   are  you???";
    const replacements = [_]ReplacePair{
        .{ .needle = "...", .replacement = ". " },
        .{ .needle = "!!!", .replacement = "! " },
        .{ .needle = "???", .replacement = "? " },
        .{ .needle = "   ", .replacement = " " },
        .{ .needle = "  ", .replacement = " " },
    };

    const result = try replaceManyOptimized(testing.allocator, messy, &replacements);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Hello. world! How are you? ", result);
}

test "replaceManyOptimized - path separator normalization" {
    const path = "C:\\Users\\Name\\Documents\\file.txt";
    const replacements = [_]ReplacePair{
        .{ .needle = "\\", .replacement = "/" },
        .{ .needle = "C:", .replacement = "/c" },
    };

    const result = try replaceManyOptimized(testing.allocator, path, &replacements);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("/c/Users/Name/Documents/file.txt", result);
}

test "replaceManyOptimized - markdown to HTML basic" {
    const markdown = "**bold** and *italic* text";
    const replacements = [_]ReplacePair{
        .{ .needle = "**", .replacement = "<strong>" },
        .{ .needle = "*", .replacement = "<em>" },
    };

    const result = try replaceManyOptimized(testing.allocator, markdown, &replacements);
    defer testing.allocator.free(result);

    // Note: naive replacement, just demonstrating the concept
    try testing.expectEqualStrings("<strong>bold<strong> and <em>italic<em> text", result);
}

test "replaceManyOptimized - memory safety with many patterns" {
    const text = "a b c d e f g h i j k";
    const replacements = [_]ReplacePair{
        .{ .needle = "a", .replacement = "1" },
        .{ .needle = "b", .replacement = "2" },
        .{ .needle = "c", .replacement = "3" },
        .{ .needle = "d", .replacement = "4" },
        .{ .needle = "e", .replacement = "5" },
        .{ .needle = "f", .replacement = "6" },
        .{ .needle = "g", .replacement = "7" },
        .{ .needle = "h", .replacement = "8" },
        .{ .needle = "i", .replacement = "9" },
        .{ .needle = "j", .replacement = "10" },
    };

    const result = try replaceManyOptimized(testing.allocator, text, &replacements);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("1 2 3 4 5 6 7 8 9 10 k", result);
    // testing.allocator will detect any memory leaks
}

test "performance comparison - small text" {
    const text = "small test text";
    const replacements = [_]ReplacePair{
        .{ .needle = "small", .replacement = "tiny" },
        .{ .needle = "test", .replacement = "sample" },
    };

    // Both methods should work fine on small text
    const result1 = try replaceMany(testing.allocator, text, &replacements);
    defer testing.allocator.free(result1);

    const result2 = try replaceManyOptimized(testing.allocator, text, &replacements);
    defer testing.allocator.free(result2);

    try testing.expectEqualStrings(result1, result2);
}

test "performance comparison - many patterns" {
    const text = "The quick brown fox jumps over the lazy dog and runs through the forest";
    const replacements = [_]ReplacePair{
        .{ .needle = "quick", .replacement = "fast" },
        .{ .needle = "brown", .replacement = "red" },
        .{ .needle = "fox", .replacement = "wolf" },
        .{ .needle = "jumps", .replacement = "leaps" },
        .{ .needle = "lazy", .replacement = "sleeping" },
        .{ .needle = "dog", .replacement = "cat" },
        .{ .needle = "runs", .replacement = "sprints" },
        .{ .needle = "forest", .replacement = "woods" },
    };

    // With 8 patterns, optimized version creates fewer allocations
    const result1 = try replaceMany(testing.allocator, text, &replacements);
    defer testing.allocator.free(result1);

    const result2 = try replaceManyOptimized(testing.allocator, text, &replacements);
    defer testing.allocator.free(result2);

    // Results should be identical
    try testing.expectEqualStrings(result1, result2);
}
