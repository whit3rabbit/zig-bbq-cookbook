// Recipe 2.13: Sanitizing and Cleaning Up Text
// Target Zig Version: 0.15.2
//
// Advanced text sanitization including whitespace normalization, line ending
// conversion, URL encoding/decoding, ANSI escape code removal, and HTML entity
// encoding/decoding.

const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const Allocator = mem.Allocator;

// ANCHOR: whitespace_line_endings
// ============================================================================
// Whitespace Normalization
// ============================================================================

/// Normalize all whitespace characters (spaces, tabs, newlines) to single spaces.
/// Multiple consecutive whitespace characters are collapsed into one space.
/// Leading and trailing whitespace is removed.
pub fn normalizeWhitespace(allocator: Allocator, text: []const u8) ![]u8 {
    if (text.len == 0) return try allocator.dupe(u8, "");

    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    var in_whitespace = true; // Start true to skip leading whitespace
    for (text) |c| {
        const is_ws = c == ' ' or c == '\t' or c == '\n' or c == '\r';

        if (is_ws) {
            if (!in_whitespace) {
                try result.append(allocator, ' ');
                in_whitespace = true;
            }
        } else {
            try result.append(allocator, c);
            in_whitespace = false;
        }
    }

    // Remove trailing space if present (more efficient: pop before converting to slice)
    if (result.items.len > 0 and result.items[result.items.len - 1] == ' ') {
        _ = result.pop();
    }

    return try result.toOwnedSlice(allocator);
}

test "normalizeWhitespace - basic" {
    const input = "  hello   world  \n\t  foo  ";
    const result = try normalizeWhitespace(testing.allocator, input);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello world foo", result);
}

test "normalizeWhitespace - empty and whitespace only" {
    const empty = try normalizeWhitespace(testing.allocator, "");
    defer testing.allocator.free(empty);
    try testing.expectEqualStrings("", empty);

    const ws_only = try normalizeWhitespace(testing.allocator, "   \t\n  ");
    defer testing.allocator.free(ws_only);
    try testing.expectEqualStrings("", ws_only);
}

// ============================================================================
// Line Ending Normalization
// ============================================================================

pub const LineEnding = enum {
    lf,    // Unix/Linux/macOS (\n)
    crlf,  // Windows (\r\n)
    cr,    // Classic Mac (\r)
};

/// Convert all line endings in text to the specified format.
pub fn normalizeLineEndings(allocator: Allocator, text: []const u8, target: LineEnding) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    const target_bytes = switch (target) {
        .lf => "\n",
        .crlf => "\r\n",
        .cr => "\r",
    };

    var i: usize = 0;
    while (i < text.len) {
        if (i + 1 < text.len and text[i] == '\r' and text[i + 1] == '\n') {
            // CRLF -> target
            try result.appendSlice(allocator, target_bytes);
            i += 2;
        } else if (text[i] == '\r') {
            // CR -> target
            try result.appendSlice(allocator, target_bytes);
            i += 1;
        } else if (text[i] == '\n') {
            // LF -> target
            try result.appendSlice(allocator, target_bytes);
            i += 1;
        } else {
            try result.append(allocator, text[i]);
            i += 1;
        }
    }

    return result.toOwnedSlice(allocator);
}

test "normalizeLineEndings - CRLF to LF" {
    const input = "line1\r\nline2\r\nline3";
    const result = try normalizeLineEndings(testing.allocator, input, .lf);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("line1\nline2\nline3", result);
}

test "normalizeLineEndings - mixed to CRLF" {
    const input = "line1\nline2\r\nline3\rline4";
    const result = try normalizeLineEndings(testing.allocator, input, .crlf);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("line1\r\nline2\r\nline3\r\nline4", result);
}

test "normalizeLineEndings - LF to CR" {
    const input = "line1\nline2\nline3";
    const result = try normalizeLineEndings(testing.allocator, input, .cr);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("line1\rline2\rline3", result);
}
// ANCHOR_END: whitespace_line_endings

// ANCHOR: url_encoding
// ============================================================================
// URL Encoding/Decoding
// ============================================================================

/// Check if a character should be percent-encoded in URLs.
/// Unreserved characters (A-Z, a-z, 0-9, -, _, ., ~) are not encoded.
fn shouldEncodeUrlChar(c: u8) bool {
    return switch (c) {
        'A'...'Z', 'a'...'z', '0'...'9', '-', '_', '.', '~' => false,
        else => true,
    };
}

/// Encode a string for use in URLs (percent encoding).
/// Encodes all characters except unreserved characters per RFC 3986.
pub fn urlEncode(allocator: Allocator, text: []const u8) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    for (text) |c| {
        if (shouldEncodeUrlChar(c)) {
            try result.append(allocator, '%');
            const hex = "0123456789ABCDEF";
            try result.append(allocator, hex[(c >> 4) & 0xF]);
            try result.append(allocator, hex[c & 0xF]);
        } else {
            try result.append(allocator, c);
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Decode a percent-encoded URL string.
/// Returns error.InvalidPercentEncoding if the encoding is malformed.
pub fn urlDecode(allocator: Allocator, text: []const u8) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < text.len) {
        if (text[i] == '%') {
            if (i + 2 >= text.len) return error.InvalidPercentEncoding;

            const hex_digits = text[i + 1 .. i + 3];
            const value = std.fmt.parseInt(u8, hex_digits, 16) catch {
                return error.InvalidPercentEncoding;
            };

            try result.append(allocator, value);
            i += 3;
        } else {
            try result.append(allocator, text[i]);
            i += 1;
        }
    }

    return result.toOwnedSlice(allocator);
}

test "urlEncode - basic" {
    const input = "hello world!";
    const result = try urlEncode(testing.allocator, input);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello%20world%21", result);
}

test "urlEncode - special characters" {
    const input = "name=John Doe&age=30";
    const result = try urlEncode(testing.allocator, input);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("name%3DJohn%20Doe%26age%3D30", result);
}

test "urlDecode - basic" {
    const input = "hello%20world%21";
    const result = try urlDecode(testing.allocator, input);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("hello world!", result);
}

test "url encode/decode round trip" {
    const original = "The quick brown fox jumps over the lazy dog! #2024 @user";
    const encoded = try urlEncode(testing.allocator, original);
    defer testing.allocator.free(encoded);

    const decoded = try urlDecode(testing.allocator, encoded);
    defer testing.allocator.free(decoded);

    try testing.expectEqualStrings(original, decoded);
}

test "urlDecode - invalid encoding" {
    try testing.expectError(error.InvalidPercentEncoding, urlDecode(testing.allocator, "test%2"));
    try testing.expectError(error.InvalidPercentEncoding, urlDecode(testing.allocator, "test%ZZ"));
}
// ANCHOR_END: url_encoding

// ANCHOR: html_ansi_cleanup
// ============================================================================
// ANSI Escape Code Removal
// ============================================================================

/// Remove ANSI escape codes from text (e.g., terminal color codes).
/// ANSI codes are sequences starting with ESC (0x1B) followed by '[' and
/// terminated by a letter (typically 'm' for colors).
pub fn removeAnsiCodes(allocator: Allocator, text: []const u8) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < text.len) {
        // Check for ESC [ sequence
        if (i + 1 < text.len and text[i] == 0x1B and text[i + 1] == '[') {
            // Skip until we find a letter (the terminator)
            i += 2;
            while (i < text.len) : (i += 1) {
                const c = text[i];
                if ((c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z')) {
                    i += 1;
                    break;
                }
            }
        } else {
            try result.append(allocator, text[i]);
            i += 1;
        }
    }

    return result.toOwnedSlice(allocator);
}

test "removeAnsiCodes - colored text" {
    // Red "Hello" + reset + green "World"
    const input = "\x1B[31mHello\x1B[0m \x1B[32mWorld\x1B[0m";
    const result = try removeAnsiCodes(testing.allocator, input);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Hello World", result);
}

test "removeAnsiCodes - no codes" {
    const input = "Plain text with no codes";
    const result = try removeAnsiCodes(testing.allocator, input);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings(input, result);
}

test "removeAnsiCodes - complex codes" {
    // Bold + underline + color
    const input = "\x1B[1m\x1B[4m\x1B[33mWarning:\x1B[0m Check logs";
    const result = try removeAnsiCodes(testing.allocator, input);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Warning: Check logs", result);
}

// ============================================================================
// HTML Entity Encoding/Decoding
// ============================================================================

/// Common HTML named entities for encoding
const HtmlEntity = struct {
    char: u8,
    entity: []const u8,
};

const html_entities = [_]HtmlEntity{
    .{ .char = '<', .entity = "&lt;" },
    .{ .char = '>', .entity = "&gt;" },
    .{ .char = '&', .entity = "&amp;" },
    .{ .char = '"', .entity = "&quot;" },
    .{ .char = '\'', .entity = "&#39;" },
};

/// Encode text for safe display in HTML by escaping special characters.
/// Handles: <, >, &, ", '
pub fn htmlEncode(allocator: Allocator, text: []const u8) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    for (text) |c| {
        var found = false;
        for (html_entities) |entity| {
            if (c == entity.char) {
                try result.appendSlice(allocator, entity.entity);
                found = true;
                break;
            }
        }
        if (!found) {
            try result.append(allocator, c);
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Decode HTML entities back to their original characters.
/// Handles both named entities (&lt;, &gt;, etc.) and numeric entities (&#65;, &#x41;).
pub fn htmlDecode(allocator: Allocator, text: []const u8) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < text.len) {
        if (text[i] == '&') {
            // Try to find the semicolon
            const end = mem.indexOfScalarPos(u8, text, i, ';') orelse {
                // No semicolon found, just append the &
                try result.append(allocator, '&');
                i += 1;
                continue;
            };

            const entity = text[i .. end + 1];

            // Check for numeric entity
            if (entity.len > 3 and entity[1] == '#') {
                const is_hex = entity.len > 4 and (entity[2] == 'x' or entity[2] == 'X');
                const num_start: usize = if (is_hex) 3 else 2;
                const num_str = entity[num_start .. entity.len - 1];

                const base: u8 = if (is_hex) 16 else 10;
                const value = std.fmt.parseInt(u8, num_str, base) catch {
                    // Invalid numeric entity, keep as-is
                    try result.appendSlice(allocator, entity);
                    i = end + 1;
                    continue;
                };

                try result.append(allocator, value);
                i = end + 1;
                continue;
            }

            // Check for named entities
            var decoded = false;
            for (html_entities) |ent| {
                if (mem.eql(u8, entity, ent.entity)) {
                    try result.append(allocator, ent.char);
                    decoded = true;
                    break;
                }
            }

            if (!decoded) {
                // Unknown entity, keep as-is
                try result.appendSlice(allocator, entity);
            }

            i = end + 1;
        } else {
            try result.append(allocator, text[i]);
            i += 1;
        }
    }

    return result.toOwnedSlice(allocator);
}

test "htmlEncode - special characters" {
    const input = "<div class=\"test\">Hello & goodbye</div>";
    const result = try htmlEncode(testing.allocator, input);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("&lt;div class=&quot;test&quot;&gt;Hello &amp; goodbye&lt;/div&gt;", result);
}

test "htmlEncode - prevents XSS" {
    const input = "<script>alert('XSS')</script>";
    const result = try htmlEncode(testing.allocator, input);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("&lt;script&gt;alert(&#39;XSS&#39;)&lt;/script&gt;", result);
}

test "htmlDecode - named entities" {
    const input = "&lt;div&gt;Hello &amp; goodbye&lt;/div&gt;";
    const result = try htmlDecode(testing.allocator, input);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("<div>Hello & goodbye</div>", result);
}

test "htmlDecode - numeric entities decimal" {
    const input = "Hello &#65;&#66;&#67;";
    const result = try htmlDecode(testing.allocator, input);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Hello ABC", result);
}

test "htmlDecode - numeric entities hex" {
    const input = "Hello &#x41;&#x42;&#x43;";
    const result = try htmlDecode(testing.allocator, input);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Hello ABC", result);
}

test "htmlDecode - mixed entities" {
    const input = "&lt;tag attr=&quot;&#x48;ello&quot;&gt;&#65; &amp; B&lt;/tag&gt;";
    const result = try htmlDecode(testing.allocator, input);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("<tag attr=\"Hello\">A & B</tag>", result);
}

test "html encode/decode round trip" {
    const original = "<p>The price is $5 & the tax is 'high'!</p>";
    const encoded = try htmlEncode(testing.allocator, original);
    defer testing.allocator.free(encoded);

    const decoded = try htmlDecode(testing.allocator, encoded);
    defer testing.allocator.free(decoded);

    try testing.expectEqualStrings(original, decoded);
}
// ANCHOR_END: html_ansi_cleanup

// ============================================================================
// Comprehensive Sanitization Pipeline
// ============================================================================

/// Configuration for text sanitization pipeline
pub const SanitizeOptions = struct {
    normalize_whitespace: bool = true,
    normalize_line_endings: ?LineEnding = null,
    remove_ansi_codes: bool = false,
    html_encode: bool = false,
    url_encode: bool = false,
    trim: bool = true,
};

/// Apply multiple sanitization steps to text in a single pass.
/// Steps are applied in this order:
/// 1. Remove ANSI codes (if enabled)
/// 2. Normalize line endings (if specified)
/// 3. Normalize whitespace (if enabled)
/// 4. Trim (if enabled)
/// 5. HTML encode (if enabled)
/// 6. URL encode (if enabled)
pub fn sanitizeText(allocator: Allocator, text: []const u8, options: SanitizeOptions) ![]u8 {
    var current = try allocator.dupe(u8, text);
    errdefer allocator.free(current);

    // Step 1: Remove ANSI codes
    if (options.remove_ansi_codes) {
        const temp = try removeAnsiCodes(allocator, current);
        allocator.free(current);
        current = temp;
    }

    // Step 2: Normalize line endings
    if (options.normalize_line_endings) |ending| {
        const temp = try normalizeLineEndings(allocator, current, ending);
        allocator.free(current);
        current = temp;
    }

    // Step 3: Normalize whitespace
    if (options.normalize_whitespace) {
        const temp = try normalizeWhitespace(allocator, current);
        allocator.free(current);
        current = temp;
    }

    // Step 4: Trim (already done by normalizeWhitespace, but handle separately if not normalizing)
    if (options.trim and !options.normalize_whitespace) {
        const trimmed = mem.trim(u8, current, &[_]u8{ ' ', '\t', '\n', '\r' });
        const temp = try allocator.dupe(u8, trimmed);
        allocator.free(current);
        current = temp;
    }

    // Step 5: HTML encode
    if (options.html_encode) {
        const temp = try htmlEncode(allocator, current);
        allocator.free(current);
        current = temp;
    }

    // Step 6: URL encode
    if (options.url_encode) {
        const temp = try urlEncode(allocator, current);
        allocator.free(current);
        current = temp;
    }

    return current;
}

test "sanitizeText - pipeline example: clean log file" {
    // Simulating colored log output with extra whitespace
    const input = "\x1B[31m[ERROR]\x1B[0m   Multiple   spaces\n\n\nand  newlines";

    const result = try sanitizeText(testing.allocator, input, .{
        .remove_ansi_codes = true,
        .normalize_whitespace = true,
        .normalize_line_endings = .lf,
    });
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("[ERROR] Multiple spaces and newlines", result);
}

test "sanitizeText - pipeline example: prepare for HTML display" {
    const input = "  <script>alert('test')</script>  \r\n  ";

    const result = try sanitizeText(testing.allocator, input, .{
        .normalize_whitespace = true,
        .html_encode = true,
    });
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("&lt;script&gt;alert(&#39;test&#39;)&lt;/script&gt;", result);
}

test "sanitizeText - pipeline example: prepare for URL parameter" {
    const input = "  Hello World!  ";

    const result = try sanitizeText(testing.allocator, input, .{
        .trim = true,
        .url_encode = true,
    });
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Hello%20World%21", result);
}

test "sanitizeText - no modifications" {
    const input = "Hello World";

    const result = try sanitizeText(testing.allocator, input, .{
        .normalize_whitespace = false,
        .trim = false,
    });
    defer testing.allocator.free(result);

    try testing.expectEqualStrings(input, result);
}

// ============================================================================
// Real-World Examples
// ============================================================================

test "real-world: sanitizing user input for web display" {
    const user_input = "  <b>Check out my site:</b> http://evil.com?param=<script>alert('xss')</script>  ";

    const sanitized = try sanitizeText(testing.allocator, user_input, .{
        .normalize_whitespace = true,
        .html_encode = true,
    });
    defer testing.allocator.free(sanitized);

    // Should be safe to display in HTML
    try testing.expect(mem.indexOf(u8, sanitized, "<script>") == null);
    try testing.expect(mem.indexOf(u8, sanitized, "&lt;script&gt;") != null);
}

test "real-world: cleaning terminal output for storage" {
    const terminal_output = "\x1B[32mSUCCESS:\x1B[0m Build completed\r\n\x1B[33mWarning:\x1B[0m 2 warnings found\r\n";

    const cleaned = try sanitizeText(testing.allocator, terminal_output, .{
        .remove_ansi_codes = true,
        .normalize_line_endings = .lf,
        .normalize_whitespace = false,
        .trim = false,
    });
    defer testing.allocator.free(cleaned);

    try testing.expectEqualStrings("SUCCESS: Build completed\nWarning: 2 warnings found\n", cleaned);
}

test "real-world: preparing text for URL parameter" {
    const search_query = "Zig programming language";

    const url_safe = try sanitizeText(testing.allocator, search_query, .{
        .url_encode = true,
        .normalize_whitespace = false,
        .trim = false,
    });
    defer testing.allocator.free(url_safe);

    // Can be safely used in: https://example.com/search?q=...
    try testing.expectEqualStrings("Zig%20programming%20language", url_safe);
}
