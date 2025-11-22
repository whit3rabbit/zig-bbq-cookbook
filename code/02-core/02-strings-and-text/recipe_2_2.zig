// Recipe 2.2: Matching text at the start or end of a string
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to check if strings start with or end with
// specific prefixes or suffixes using Zig's standard library.

const std = @import("std");
const testing = std.testing;
const mem = std.mem;

/// Check if string starts with prefix
// ANCHOR: basic_prefix_suffix
pub fn startsWith(text: []const u8, prefix: []const u8) bool {
    return mem.startsWith(u8, text, prefix);
}

/// Check if string ends with suffix
pub fn endsWith(text: []const u8, suffix: []const u8) bool {
    return mem.endsWith(u8, text, suffix);
}
// ANCHOR_END: basic_prefix_suffix

/// Check if string starts with any of the given prefixes
// ANCHOR: check_multiple
pub fn startsWithAny(text: []const u8, prefixes: []const []const u8) bool {
    for (prefixes) |prefix| {
        if (mem.startsWith(u8, text, prefix)) {
            return true;
        }
    }
    return false;
}

/// Check if string ends with any of the given suffixes
pub fn endsWithAny(text: []const u8, suffixes: []const []const u8) bool {
    for (suffixes) |suffix| {
        if (mem.endsWith(u8, text, suffix)) {
            return true;
        }
    }
    return false;
}
// ANCHOR_END: check_multiple

/// Remove prefix if present, return original if not
// ANCHOR: strip_affixes
pub fn stripPrefix(text: []const u8, prefix: []const u8) []const u8 {
    if (mem.startsWith(u8, text, prefix)) {
        return text[prefix.len..];
    }
    return text;
}

/// Remove suffix if present, return original if not
pub fn stripSuffix(text: []const u8, suffix: []const u8) []const u8 {
    if (mem.endsWith(u8, text, suffix)) {
        return text[0 .. text.len - suffix.len];
    }
    return text;
}
// ANCHOR_END: strip_affixes


test "basic startsWith" {
    try testing.expect(startsWith("hello world", "hello"));
    try testing.expect(startsWith("hello world", "h"));
    try testing.expect(startsWith("hello world", "hello world"));
    try testing.expect(!startsWith("hello world", "world"));
    try testing.expect(!startsWith("hello world", "Hello")); // Case sensitive
}

test "basic endsWith" {
    try testing.expect(endsWith("hello world", "world"));
    try testing.expect(endsWith("hello world", "d"));
    try testing.expect(endsWith("hello world", "hello world"));
    try testing.expect(!endsWith("hello world", "hello"));
    try testing.expect(!endsWith("hello world", "World")); // Case sensitive
}

test "check file extensions" {
    const filename = "document.pdf";

    try testing.expect(endsWith(filename, ".pdf"));
    try testing.expect(!endsWith(filename, ".txt"));
    try testing.expect(!endsWith(filename, ".docx"));
}

test "check URL protocols" {
    const url1 = "https://example.com";
    const url2 = "http://example.com";
    const url3 = "ftp://files.example.com";

    try testing.expect(startsWith(url1, "https://"));
    try testing.expect(startsWith(url2, "http://"));
    try testing.expect(startsWith(url3, "ftp://"));
    try testing.expect(!startsWith(url1, "http://"));
}

test "starts with any prefix" {
    const text = "https://example.com";
    const protocols = [_][]const u8{ "http://", "https://", "ftp://" };

    try testing.expect(startsWithAny(text, &protocols));

    const text2 = "file:///path/to/file";
    try testing.expect(!startsWithAny(text2, &protocols));
}

test "ends with any suffix" {
    const filename = "document.pdf";
    const doc_extensions = [_][]const u8{ ".pdf", ".doc", ".docx", ".txt" };

    try testing.expect(endsWithAny(filename, &doc_extensions));

    const image = "photo.jpg";
    try testing.expect(!endsWithAny(image, &doc_extensions));
}

test "strip prefix" {
    const text = "https://example.com";
    const result = stripPrefix(text, "https://");

    try testing.expectEqualStrings("example.com", result);

    // Doesn't modify if prefix not present
    const text2 = "example.com";
    const result2 = stripPrefix(text2, "https://");
    try testing.expectEqualStrings("example.com", result2);
}

test "strip suffix" {
    const filename = "document.pdf";
    const name = stripSuffix(filename, ".pdf");

    try testing.expectEqualStrings("document", name);

    // Doesn't modify if suffix not present
    const filename2 = "readme";
    const name2 = stripSuffix(filename2, ".pdf");
    try testing.expectEqualStrings("readme", name2);
}

test "strip both prefix and suffix" {
    const url = "https://example.com/path";
    const stripped = stripSuffix(stripPrefix(url, "https://"), "/path");

    try testing.expectEqualStrings("example.com", stripped);
}

test "empty string edge cases" {
    const empty = "";

    try testing.expect(startsWith(empty, ""));
    try testing.expect(endsWith(empty, ""));
    try testing.expect(!startsWith(empty, "hello"));
    try testing.expect(!endsWith(empty, "hello"));
}

test "prefix longer than string" {
    const text = "hi";

    try testing.expect(!startsWith(text, "hello"));
    try testing.expect(!endsWith(text, "world"));
}

test "exact match" {
    const text = "exact";

    try testing.expect(startsWith(text, "exact"));
    try testing.expect(endsWith(text, "exact"));

    const stripped1 = stripPrefix(text, "exact");
    try testing.expectEqualStrings("", stripped1);

    const stripped2 = stripSuffix(text, "exact");
    try testing.expectEqualStrings("", stripped2);
}

test "filter files by extension" {
    const files = [_][]const u8{
        "main.zig",
        "test.zig",
        "build.zig",
        "README.md",
        "config.json",
    };

    var zig_count: usize = 0;
    for (files) |file| {
        if (endsWith(file, ".zig")) {
            zig_count += 1;
        }
    }

    try testing.expectEqual(@as(usize, 3), zig_count);
}

test "filter URLs by protocol" {
    const urls = [_][]const u8{
        "https://secure.example.com",
        "http://example.com",
        "https://another-secure.com",
        "ftp://files.example.com",
    };

    var https_count: usize = 0;
    for (urls) |url| {
        if (startsWith(url, "https://")) {
            https_count += 1;
        }
    }

    try testing.expectEqual(@as(usize, 2), https_count);
}

test "remove common path prefix" {
    const paths = [_][]const u8{
        "/home/user/project/src/main.zig",
        "/home/user/project/src/test.zig",
        "/home/user/project/build.zig",
    };

    const prefix = "/home/user/project/";

    for (paths) |path| {
        const relative = stripPrefix(path, prefix);
        try testing.expect(!startsWith(relative, "/"));
    }

    try testing.expectEqualStrings("src/main.zig", stripPrefix(paths[0], prefix));
    try testing.expectEqualStrings("src/test.zig", stripPrefix(paths[1], prefix));
    try testing.expectEqualStrings("build.zig", stripPrefix(paths[2], prefix));
}

test "multiple extension check" {
    const compressed_extensions = [_][]const u8{ ".gz", ".zip", ".tar", ".bz2", ".xz" };

    try testing.expect(endsWithAny("archive.tar.gz", &compressed_extensions));
    try testing.expect(endsWithAny("data.zip", &compressed_extensions));
    try testing.expect(!endsWithAny("document.pdf", &compressed_extensions));
}

test "strip multiple prefixes" {
    const text = "re: re: important message";

    var result: []const u8 = text;
    while (startsWith(result, "re: ")) {
        result = stripPrefix(result, "re: ");
    }

    try testing.expectEqualStrings("important message", result);
}

test "normalize URL - strip trailing slash" {
    const urls = [_][]const u8{
        "https://example.com/",
        "https://example.com/path/",
        "https://example.com",
    };

    for (urls) |url| {
        const normalized = stripSuffix(url, "/");
        try testing.expect(!endsWith(normalized, "/"));
    }
}

test "check comment line" {
    const lines = [_][]const u8{
        "// This is a comment",
        "const x = 5;",
        "# Another comment style",
        "  // Indented comment",
    };

    var comment_count: usize = 0;
    for (lines) |line| {
        const trimmed = mem.trim(u8, line, " \t");
        if (startsWith(trimmed, "//") or startsWith(trimmed, "#")) {
            comment_count += 1;
        }
    }

    try testing.expectEqual(@as(usize, 3), comment_count);
}

test "memory safety - no allocations" {
    // startsWith and endsWith don't allocate
    const text = "hello world";

    const has_prefix = startsWith(text, "hello");
    const has_suffix = endsWith(text, "world");

    try testing.expect(has_prefix);
    try testing.expect(has_suffix);
}

test "security - bounds checking" {
    // Zig's mem.startsWith and endsWith are bounds-safe
    const text = "short";

    // These won't overflow or access out of bounds
    try testing.expect(!startsWith(text, "very long prefix that is much longer"));
    try testing.expect(!endsWith(text, "very long suffix that is much longer"));
}

test "UTF-8 compatibility" {
    const text = "Hello 世界";

    // Byte-level matching works with UTF-8
    try testing.expect(startsWith(text, "Hello"));
    try testing.expect(endsWith(text, "世界"));

    // Multi-byte UTF-8 sequences work correctly
    const chinese = "你好世界";
    try testing.expect(startsWith(chinese, "你好"));
    try testing.expect(endsWith(chinese, "世界"));
}
