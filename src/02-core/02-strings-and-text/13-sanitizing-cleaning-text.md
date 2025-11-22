## Problem

You need to perform advanced text sanitization beyond basic trimming. This includes:

- Normalizing whitespace and line endings from different platforms
- Encoding text for URLs (percent encoding)
- Removing ANSI escape codes from terminal output
- Encoding/decoding HTML entities for safe web display
- Building sanitization pipelines for complex text cleanup

These tasks are common when cleaning user input, preparing text for web display, processing log files, or building web APIs.

## Solution

Zig provides powerful string manipulation tools through `std.mem` and `std.ArrayList` that make text sanitization straightforward and safe.

### Whitespace and Line Ending Normalization

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_13.zig:whitespace_line_endings}}
```

### URL Encoding

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_13.zig:url_encoding}}
```

### HTML and ANSI Cleanup

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_13.zig:html_ansi_cleanup}}
```

### HTML Entity Encoding and Decoding

Prevent XSS attacks by encoding HTML special characters:

```zig
pub fn htmlEncode(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    const entities = [_]struct { char: u8, entity: []const u8 }{
        .{ .char = '<', .entity = "&lt;" },
        .{ .char = '>', .entity = "&gt;" },
        .{ .char = '&', .entity = "&amp;" },
        .{ .char = '"', .entity = "&quot;" },
        .{ .char = '\'', .entity = "&#39;" },
    };

    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    for (text) |c| {
        var found = false;
        for (entities) |entity| {
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

test "HTML encoding prevents XSS" {
    const allocator = std.testing.allocator;

    const malicious_input = "<script>alert('XSS')</script>";
    const safe_output = try htmlEncode(allocator, malicious_input);
    defer allocator.free(safe_output);

    try std.testing.expectEqualStrings(
        "&lt;script&gt;alert(&#39;XSS&#39;)&lt;/script&gt;",
        safe_output
    );
}
```

### Sanitization Pipeline

Combine multiple sanitization steps for complex text cleanup:

```zig
pub const SanitizeOptions = struct {
    normalize_whitespace: bool = true,
    normalize_line_endings: ?LineEnding = null,
    remove_ansi_codes: bool = false,
    html_encode: bool = false,
    url_encode: bool = false,
    trim: bool = true,
};

pub fn sanitizeText(
    allocator: std.mem.Allocator,
    text: []const u8,
    options: SanitizeOptions,
) ![]u8 {
    var current = try allocator.dupe(u8, text);
    errdefer allocator.free(current);

    // Apply sanitization steps in order
    if (options.remove_ansi_codes) {
        const temp = try removeAnsiCodes(allocator, current);
        allocator.free(current);
        current = temp;
    }

    if (options.normalize_line_endings) |ending| {
        const temp = try normalizeLineEndings(allocator, current, ending);
        allocator.free(current);
        current = temp;
    }

    if (options.normalize_whitespace) {
        const temp = try normalizeWhitespace(allocator, current);
        allocator.free(current);
        current = temp;
    }

    if (options.trim and !options.normalize_whitespace) {
        const trimmed = std.mem.trim(u8, current, &[_]u8{ ' ', '\t', '\n', '\r' });
        const temp = try allocator.dupe(u8, trimmed);
        allocator.free(current);
        current = temp;
    }

    if (options.html_encode) {
        const temp = try htmlEncode(allocator, current);
        allocator.free(current);
        current = temp;
    }

    if (options.url_encode) {
        const temp = try urlEncode(allocator, current);
        allocator.free(current);
        current = temp;
    }

    return current;
}

test "sanitization pipeline for web display" {
    const allocator = std.testing.allocator;

    const user_input = "  <script>alert('test')</script>  \r\n  ";

    const result = try sanitizeText(allocator, user_input, .{
        .normalize_whitespace = true,
        .html_encode = true,
    });
    defer allocator.free(result);

    // Safe to display in HTML
    try std.testing.expectEqualStrings(
        "&lt;script&gt;alert(&#39;test&#39;)&lt;/script&gt;",
        result
    );
}
```

## Discussion

### Security Considerations

Text sanitization is critical for security. The most common use cases are:

1. **XSS Prevention**: Always HTML-encode user content before displaying in web pages. Even seemingly safe data can contain malicious scripts.

2. **URL Safety**: Encode data before using in URLs to prevent injection attacks and ensure proper parsing.

3. **Log Injection**: Clean ANSI codes from logs before storing to prevent terminal escape sequence attacks.

### Performance Tips

- **Chain operations carefully**: Each sanitization step allocates new memory. Consider which steps are truly necessary.

- **Pre-allocate when possible**: If you know the approximate output size, use `ArrayList.ensureTotalCapacity` to reduce allocations.

- **Avoid redundant operations**: Don't normalize whitespace if you're about to URL-encode (which handles spaces anyway).

### Memory Management

All sanitization functions follow Zig's allocator pattern:

- The caller provides an allocator
- Functions return owned slices that must be freed
- Use `defer allocator.free(result)` immediately after receiving the result
- Use `errdefer` inside functions to clean up on errors

### Real-World Examples

**Cleaning terminal output for storage:**
```zig
const log_output = "\x1B[32mSUCCESS:\x1B[0m Build completed\r\n";
const clean = try sanitizeText(allocator, log_output, .{
    .remove_ansi_codes = true,
    .normalize_line_endings = .lf,
    .normalize_whitespace = false,
    .trim = false,
});
```

**Preparing search query for URL:**
```zig
const query = "Zig programming language";
const url_param = try sanitizeText(allocator, query, .{
    .url_encode = true,
    .normalize_whitespace = false,
    .trim = false,
});
// Use in: https://example.com/search?q=...
```

**Sanitizing user content for HTML:**
```zig
const user_comment = "<b>Check this out!</b>";
const safe_html = try sanitizeText(allocator, user_comment, .{
    .normalize_whitespace = true,
    .html_encode = true,
});
// Safe to insert into: <div class="comment">...</div>
```

### UTF-8 Considerations

All sanitization functions work correctly with UTF-8 text:

- Byte-level operations (like ANSI code removal) don't corrupt multi-byte UTF-8 sequences
- URL encoding works on bytes, which is correct for UTF-8
- HTML entities are ASCII, so encoding preserves UTF-8 content
- Whitespace normalization treats each byte individually, preserving UTF-8 sequences

### When to Use Each Technique

- **Normalize whitespace**: Cleaning user input, standardizing search queries, preparing text for comparison
- **Normalize line endings**: Cross-platform file processing, git automation, standardizing logs
- **URL encoding**: Building query strings, encoding path segments, form data
- **Remove ANSI codes**: Archiving colored terminal output, processing CI/CD logs
- **HTML encoding**: Displaying any user content in HTML, preventing XSS attacks

### Comparison with Recipe 2.7

Recipe 2.7 covered basic trimming and simple character removal. This recipe focuses on:

- **Context-aware encoding** (HTML vs URL require different handling)
- **Multi-step pipelines** (chaining sanitization operations)
- **Format conversion** (line endings, whitespace normalization)
- **Security-focused operations** (XSS prevention, injection protection)

For simple trimming, use Recipe 2.7's `std.mem.trim`. For complex sanitization, use the pipelines shown here.

## See Also

- Recipe 2.7: Stripping unwanted characters (basic trimming)
- Recipe 2.14: Standardizing Unicode text (advanced Unicode normalization with C libraries)
- Recipe 6.2: Reading and writing JSON (for data encoding)
- Recipe 11.1: HTTP services (for web application security)
