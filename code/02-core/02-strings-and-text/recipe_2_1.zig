// Recipe 2.1: Splitting strings on any of multiple delimiters
// Target Zig Version: 0.15.2
//
// This recipe demonstrates various approaches to splitting strings in Zig
// using the standard library's tokenization and splitting functions.

const std = @import("std");
const testing = std.testing;
const mem = std.mem;

/// Split string on any of multiple delimiters using tokenizeAny
/// Returns an iterator that yields non-empty tokens
// ANCHOR: basic_tokenize
pub fn tokenizeAny(text: []const u8, delimiters: []const u8) mem.TokenIterator(u8, .any) {
    return mem.tokenizeAny(u8, text, delimiters);
}

/// Split string on a sequence of delimiters using tokenizeSequence
/// Returns an iterator that yields non-empty tokens
pub fn tokenizeSequence(text: []const u8, delimiter: []const u8) mem.TokenIterator(u8, .sequence) {
    return mem.tokenizeSequence(u8, text, delimiter);
}
// ANCHOR_END: basic_tokenize

/// Split string but keep empty tokens using splitAny
// ANCHOR: split_preserve_empty
pub fn splitAny(text: []const u8, delimiters: []const u8) mem.SplitIterator(u8, .any) {
    return mem.splitAny(u8, text, delimiters);
}

/// Split string on sequence but keep empty tokens
pub fn splitSequence(text: []const u8, delimiter: []const u8) mem.SplitIterator(u8, .sequence) {
    return mem.splitSequence(u8, text, delimiter);
}
// ANCHOR_END: split_preserve_empty

/// Collect all tokens into an ArrayList for convenience
pub fn collectTokens(
    allocator: mem.Allocator,
    text: []const u8,
    delimiters: []const u8,
) !std.ArrayList([]const u8) {
    var result = std.ArrayList([]const u8){};
    errdefer result.deinit(allocator);

    var iter = tokenizeAny(text, delimiters);
    while (iter.next()) |token| {
        try result.append(allocator, token);
    }

    return result;
}

/// Split on whitespace (space, tab, newline, carriage return)
// ANCHOR: practical_splitting
pub fn splitWhitespace(text: []const u8) mem.TokenIterator(u8, .any) {
    return mem.tokenizeAny(u8, text, " \t\n\r");
}

/// Parse CSV-like data (comma-separated values)
pub fn splitCSV(text: []const u8) mem.SplitIterator(u8, .scalar) {
    return mem.splitScalar(u8, text, ',');
}

/// Split lines preserving empty lines
pub fn splitLines(text: []const u8) mem.SplitIterator(u8, .scalar) {
    return mem.splitScalar(u8, text, '\n');
}
// ANCHOR_END: practical_splitting

test "split on any of multiple delimiters" {
    const text = "hello,world;foo:bar|baz";
    var iter = tokenizeAny(text, ",;:|");

    try testing.expectEqualStrings("hello", iter.next().?);
    try testing.expectEqualStrings("world", iter.next().?);
    try testing.expectEqualStrings("foo", iter.next().?);
    try testing.expectEqualStrings("bar", iter.next().?);
    try testing.expectEqualStrings("baz", iter.next().?);
    try testing.expect(iter.next() == null);
}

test "split on whitespace" {
    const text = "  hello   world\tfoo\n\nbar  ";
    var iter = splitWhitespace(text);

    try testing.expectEqualStrings("hello", iter.next().?);
    try testing.expectEqualStrings("world", iter.next().?);
    try testing.expectEqualStrings("foo", iter.next().?);
    try testing.expectEqualStrings("bar", iter.next().?);
    try testing.expect(iter.next() == null);
}

test "split on sequence delimiter" {
    const text = "foo::bar::baz::qux";
    var iter = tokenizeSequence(text, "::");

    try testing.expectEqualStrings("foo", iter.next().?);
    try testing.expectEqualStrings("bar", iter.next().?);
    try testing.expectEqualStrings("baz", iter.next().?);
    try testing.expectEqualStrings("qux", iter.next().?);
    try testing.expect(iter.next() == null);
}

test "split preserving empty tokens" {
    const text = "a,,b,c,";
    var iter = splitAny(text, ",");

    try testing.expectEqualStrings("a", iter.next().?);
    try testing.expectEqualStrings("", iter.next().?); // Empty token
    try testing.expectEqualStrings("b", iter.next().?);
    try testing.expectEqualStrings("c", iter.next().?);
    try testing.expectEqualStrings("", iter.next().?); // Trailing empty
    try testing.expect(iter.next() == null);
}

test "tokenize vs split - different behavior" {
    const text = "a,,b";

    // tokenize skips empty tokens
    var tok_iter = tokenizeAny(text, ",");
    try testing.expectEqualStrings("a", tok_iter.next().?);
    try testing.expectEqualStrings("b", tok_iter.next().?);
    try testing.expect(tok_iter.next() == null);

    // split keeps empty tokens
    var split_iter = splitAny(text, ",");
    try testing.expectEqualStrings("a", split_iter.next().?);
    try testing.expectEqualStrings("", split_iter.next().?);
    try testing.expectEqualStrings("b", split_iter.next().?);
    try testing.expect(split_iter.next() == null);
}

test "collect tokens into ArrayList" {
    const text = "apple,banana,cherry,date";
    var tokens = try collectTokens(testing.allocator, text, ",");
    defer tokens.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 4), tokens.items.len);
    try testing.expectEqualStrings("apple", tokens.items[0]);
    try testing.expectEqualStrings("banana", tokens.items[1]);
    try testing.expectEqualStrings("cherry", tokens.items[2]);
    try testing.expectEqualStrings("date", tokens.items[3]);
}

test "parse CSV data" {
    const csv = "name,age,city\nAlice,30,NYC\nBob,25,LA";
    var lines = splitLines(csv);

    // Header line
    const header = lines.next().?;
    var header_cols = splitCSV(header);
    try testing.expectEqualStrings("name", header_cols.next().?);
    try testing.expectEqualStrings("age", header_cols.next().?);
    try testing.expectEqualStrings("city", header_cols.next().?);

    // First data line
    const line1 = lines.next().?;
    var cols1 = splitCSV(line1);
    try testing.expectEqualStrings("Alice", cols1.next().?);
    try testing.expectEqualStrings("30", cols1.next().?);
    try testing.expectEqualStrings("NYC", cols1.next().?);

    // Second data line
    const line2 = lines.next().?;
    var cols2 = splitCSV(line2);
    try testing.expectEqualStrings("Bob", cols2.next().?);
    try testing.expectEqualStrings("25", cols2.next().?);
    try testing.expectEqualStrings("LA", cols2.next().?);
}

test "split on multiple character delimiters" {
    const text = "one->two->three->four";
    var iter = tokenizeSequence(text, "->");

    try testing.expectEqualStrings("one", iter.next().?);
    try testing.expectEqualStrings("two", iter.next().?);
    try testing.expectEqualStrings("three", iter.next().?);
    try testing.expectEqualStrings("four", iter.next().?);
    try testing.expect(iter.next() == null);
}

test "split path-like strings" {
    const path = "/usr/local/bin/zig";
    var iter = tokenizeAny(path, "/");

    try testing.expectEqualStrings("usr", iter.next().?);
    try testing.expectEqualStrings("local", iter.next().?);
    try testing.expectEqualStrings("bin", iter.next().?);
    try testing.expectEqualStrings("zig", iter.next().?);
    try testing.expect(iter.next() == null);
}

test "split empty string" {
    const text = "";
    var iter = tokenizeAny(text, ",");

    try testing.expect(iter.next() == null);
}

test "split string with no delimiters" {
    const text = "hello";
    var iter = tokenizeAny(text, ",");

    try testing.expectEqualStrings("hello", iter.next().?);
    try testing.expect(iter.next() == null);
}

test "split with only delimiters" {
    const text = ",,,";

    // tokenize returns no tokens
    var tok_iter = tokenizeAny(text, ",");
    try testing.expect(tok_iter.next() == null);

    // split returns empty strings
    var split_iter = splitAny(text, ",");
    try testing.expectEqualStrings("", split_iter.next().?);
    try testing.expectEqualStrings("", split_iter.next().?);
    try testing.expectEqualStrings("", split_iter.next().?);
    try testing.expectEqualStrings("", split_iter.next().?);
    try testing.expect(split_iter.next() == null);
}

test "parse email addresses" {
    const text = "user@example.com, admin@test.org; developer@code.io";
    var iter = tokenizeAny(text, " ,;");

    try testing.expectEqualStrings("user@example.com", iter.next().?);
    try testing.expectEqualStrings("admin@test.org", iter.next().?);
    try testing.expectEqualStrings("developer@code.io", iter.next().?);
    try testing.expect(iter.next() == null);
}

test "split on tabs and newlines" {
    const text = "col1\tcol2\tcol3\nval1\tval2\tval3";
    var lines = splitLines(text);

    const line1 = lines.next().?;
    var cols1 = mem.tokenizeScalar(u8, line1, '\t');
    try testing.expectEqualStrings("col1", cols1.next().?);
    try testing.expectEqualStrings("col2", cols1.next().?);
    try testing.expectEqualStrings("col3", cols1.next().?);

    const line2 = lines.next().?;
    var cols2 = mem.tokenizeScalar(u8, line2, '\t');
    try testing.expectEqualStrings("val1", cols2.next().?);
    try testing.expectEqualStrings("val2", cols2.next().?);
    try testing.expectEqualStrings("val3", cols2.next().?);
}

test "memory safety - no allocations for iterators" {
    // Iterators don't allocate, they just slice the original string
    const text = "a,b,c,d,e";
    var iter = tokenizeAny(text, ",");

    var count: usize = 0;
    while (iter.next()) |_| {
        count += 1;
    }

    try testing.expectEqual(@as(usize, 5), count);
}

test "security - no buffer overflows" {
    // Zig's string operations are bounds-checked
    const text = "safe";
    var iter = tokenizeAny(text, ",");

    const first = iter.next().?;
    try testing.expectEqualStrings("safe", first);

    // This is safe - slices know their length
    try testing.expect(first.len == 4);
}
