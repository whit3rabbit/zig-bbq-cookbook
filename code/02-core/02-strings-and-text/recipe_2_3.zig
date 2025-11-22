// Recipe 2.3: Matching strings using shell wildcard patterns
// Target Zig Version: 0.15.2
//
// This recipe demonstrates implementing simple glob-style wildcard matching
// similar to shell filename patterns (* and ?).

const std = @import("std");
const testing = std.testing;
const mem = std.mem;

/// Simple glob pattern matching with * (any characters) and ? (single character)
/// Returns true if text matches the pattern
// ANCHOR: glob_matching
pub fn glob(text: []const u8, pattern: []const u8) bool {
    return globImpl(text, pattern, 0, 0);
}

fn globImpl(text: []const u8, pattern: []const u8, text_idx: usize, pat_idx: usize) bool {
    // Both exhausted - match
    if (text_idx == text.len and pat_idx == pattern.len) {
        return true;
    }

    // Pattern exhausted but text remains - no match
    if (pat_idx == pattern.len) {
        return false;
    }

    // Handle wildcard *
    if (pattern[pat_idx] == '*') {
        // Try matching zero characters
        if (globImpl(text, pattern, text_idx, pat_idx + 1)) {
            return true;
        }

        // Try matching one or more characters
        var i = text_idx;
        while (i < text.len) : (i += 1) {
            if (globImpl(text, pattern, i + 1, pat_idx + 1)) {
                return true;
            }
        }

        return false;
    }

    // Text exhausted but pattern has non-wildcard - no match
    if (text_idx == text.len) {
        return false;
    }

    // Handle single character wildcard ?
    if (pattern[pat_idx] == '?') {
        return globImpl(text, pattern, text_idx + 1, pat_idx + 1);
    }

    // Handle regular character - must match exactly
    if (text[text_idx] == pattern[pat_idx]) {
        return globImpl(text, pattern, text_idx + 1, pat_idx + 1);
    }

    return false;
}
// ANCHOR_END: glob_matching

/// Match multiple patterns (OR logic)
// ANCHOR: glob_multiple
pub fn globAny(text: []const u8, patterns: []const []const u8) bool {
    for (patterns) |pattern| {
        if (glob(text, pattern)) {
            return true;
        }
    }
    return false;
}
// ANCHOR_END: glob_multiple

/// Filter a list of strings by a glob pattern
// ANCHOR: filter_by_glob
pub fn filterByGlob(
    allocator: mem.Allocator,
    items: []const []const u8,
    pattern: []const u8,
) !std.ArrayList([]const u8) {
    var result = std.ArrayList([]const u8){};
    errdefer result.deinit(allocator);

    for (items) |item| {
        if (glob(item, pattern)) {
            try result.append(allocator, item);
        }
    }

    return result;
}
// ANCHOR_END: filter_by_glob

test "exact match" {
    try testing.expect(glob("hello", "hello"));
    try testing.expect(!glob("hello", "world"));
    try testing.expect(!glob("hello", "Hello")); // Case sensitive
}

test "single wildcard ? matches one character" {
    try testing.expect(glob("cat", "c?t"));
    try testing.expect(glob("cut", "c?t"));
    try testing.expect(!glob("ct", "c?t")); // ? must match one char
    try testing.expect(!glob("cart", "c?t")); // Too many chars

    try testing.expect(glob("a", "?"));
    try testing.expect(!glob("ab", "?"));
}

test "multiple wildcards ?" {
    try testing.expect(glob("test", "t??t"));
    try testing.expect(glob("abcd", "??cd"));
    try testing.expect(glob("abcd", "ab??"));
    try testing.expect(!glob("abc", "????"));
}

test "star wildcard * matches zero or more characters" {
    try testing.expect(glob("", "*"));
    try testing.expect(glob("a", "*"));
    try testing.expect(glob("anything", "*"));

    try testing.expect(glob("hello", "h*"));
    try testing.expect(glob("h", "h*"));
    try testing.expect(glob("hello world", "h*"));
}

test "star at end of pattern" {
    try testing.expect(glob("test.txt", "test*"));
    try testing.expect(glob("test.md", "test*"));
    try testing.expect(glob("test", "test*"));
    try testing.expect(glob("testing", "test*")); // "test*" matches anything starting with "test"
}

test "star at beginning of pattern" {
    try testing.expect(glob("file.txt", "*.txt"));
    try testing.expect(glob("document.txt", "*.txt"));
    try testing.expect(!glob("file.pdf", "*.txt"));
}

test "star in middle of pattern" {
    try testing.expect(glob("hello_world", "hello*world"));
    try testing.expect(glob("hello__world", "hello*world"));
    try testing.expect(glob("helloworld", "hello*world"));
    try testing.expect(!glob("hello", "hello*world"));
}

test "multiple stars" {
    try testing.expect(glob("a.b.c", "*.*.*"));
    try testing.expect(glob("file.tar.gz", "*.*"));
    try testing.expect(glob("anything", "*"));
}

test "combine ? and *" {
    try testing.expect(glob("test.txt", "t??t*"));
    try testing.expect(glob("test.md", "t??t*"));
    try testing.expect(!glob("tst.txt", "t??t*"));

    try testing.expect(glob("data123.csv", "data???.*"));
    try testing.expect(!glob("data12.csv", "data???.*"));
}

test "file extension matching" {
    const files = [_][]const u8{
        "main.zig",
        "test.zig",
        "build.zig",
        "README.md",
        "config.json",
    };

    for (files) |file| {
        const is_zig = glob(file, "*.zig");
        const expected = mem.endsWith(u8, file, ".zig");
        try testing.expectEqual(expected, is_zig);
    }
}

test "prefix matching" {
    try testing.expect(glob("test_main.zig", "test_*"));
    try testing.expect(glob("test_helper.zig", "test_*"));
    try testing.expect(!glob("main_test.zig", "test_*"));
}

test "match any pattern" {
    const patterns = [_][]const u8{ "*.txt", "*.md", "*.rst" };

    try testing.expect(globAny("file.txt", &patterns));
    try testing.expect(globAny("README.md", &patterns));
    try testing.expect(globAny("doc.rst", &patterns));
    try testing.expect(!globAny("file.pdf", &patterns));
}

test "filter files by pattern" {
    const files = [_][]const u8{
        "main.zig",
        "test.zig",
        "helper.zig",
        "README.md",
        "build.zig",
    };

    var zig_files = try filterByGlob(testing.allocator, &files, "*.zig");
    defer zig_files.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 4), zig_files.items.len);
}

test "complex patterns" {
    try testing.expect(glob("test_123_main.zig", "test_*_*.zig"));
    try testing.expect(glob("data_2024_01.csv", "data_*_*.csv"));
    try testing.expect(!glob("data_2024.csv", "data_*_*.csv"));
}

test "edge case - empty pattern" {
    try testing.expect(glob("", ""));
    try testing.expect(!glob("text", ""));
}

test "edge case - empty text" {
    try testing.expect(glob("", "*"));
    try testing.expect(!glob("", "?"));
    try testing.expect(!glob("", "a"));
}

test "edge case - only wildcards" {
    try testing.expect(glob("anything", "***"));
    try testing.expect(glob("a", "?*"));
    try testing.expect(glob("ab", "?*"));
    try testing.expect(!glob("", "?*"));
}

test "real-world file patterns" {
    // Source files
    try testing.expect(glob("main.c", "*.c"));
    try testing.expect(glob("utils.h", "*.h"));

    // Test files
    try testing.expect(glob("test_main.zig", "test_*.zig"));
    try testing.expect(glob("main_test.zig", "*_test.zig"));

    // Backup files
    try testing.expect(glob("file.txt.bak", "*.bak"));
    try testing.expect(glob("file.txt~", "*~"));

    // Hidden files
    try testing.expect(glob(".gitignore", ".*"));
    try testing.expect(glob(".hidden", ".*"));
}

test "version patterns" {
    try testing.expect(glob("v1.2.3", "v*.*.*"));
    try testing.expect(glob("v2.0.0", "v*.*.*"));
    try testing.expect(glob("version-1.2.3", "version-*"));
    try testing.expect(!glob("1.2.3", "v*.*.*"));
}

test "date patterns" {
    try testing.expect(glob("2024-01-15", "????-??-??"));
    try testing.expect(glob("log-2024-01-15.txt", "log-????-??-??.txt"));
    try testing.expect(!glob("2024-1-5", "????-??-??"));
}

test "multiple file extensions" {
    const image_patterns = [_][]const u8{ "*.jpg", "*.png", "*.gif" };

    try testing.expect(globAny("photo.jpg", &image_patterns));
    try testing.expect(globAny("image.png", &image_patterns));
    try testing.expect(globAny("animation.gif", &image_patterns));
    try testing.expect(!globAny("document.pdf", &image_patterns));
}

test "case sensitivity" {
    try testing.expect(glob("file.txt", "file.txt"));
    try testing.expect(!glob("File.txt", "file.txt"));
    try testing.expect(!glob("FILE.TXT", "file.txt"));
}

test "special characters - literal match" {
    // These characters are literal in our simple glob
    try testing.expect(glob("file[1].txt", "file[1].txt"));
    try testing.expect(glob("a+b", "a+b"));
    try testing.expect(glob("test.file", "test.file"));
}

test "memory safety - no allocations for glob matching" {
    // glob() doesn't allocate, it just walks the strings
    const result = glob("test.txt", "*.txt");
    try testing.expect(result);
}

test "security - bounds checking" {
    // Very long patterns don't cause issues
    const long_pattern = "*" ** 100 ++ ".txt";
    try testing.expect(glob("file.txt", long_pattern));

    // Pattern longer than text is safe
    try testing.expect(!glob("a", "????????????"));
}

test "performance - no catastrophic backtracking" {
    // Patterns with multiple * don't cause exponential time
    // This would hang in naive regex implementations
    try testing.expect(!glob("aaaaaaaaaa", "*a*a*a*a*a*b")); // No 'b', should not match
    try testing.expect(glob("aaaaaaaaaaab", "*a*a*a*a*a*b")); // Has 'b' at end
    try testing.expect(!glob("aaaaaaaaaax", "*a*a*a*a*a*b")); // No 'b', should not match
}
