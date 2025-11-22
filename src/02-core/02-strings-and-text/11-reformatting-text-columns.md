## Problem

You need to reformat text to fit within a fixed column width - wrapping lines at word boundaries, breaking long lines, or reflowing paragraphs for display or output.

## Solution

Implement text wrapping functions that break text at word boundaries or fixed positions:

### Word-Based Wrapping

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_11.zig:text_wrapping}}
```

## Discussion

### Text Indentation

**Add prefix to every line:**

```zig
pub fn indent(
    allocator: mem.Allocator,
    text: []const u8,
    prefix: []const u8,
) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    var lines = mem.tokenizeScalar(u8, text, '\n');
    var first = true;

    while (lines.next()) |line| {
        if (!first) {
            try result.append(allocator, '\n');
        }
        first = false;

        try result.appendSlice(allocator, prefix);
        try result.appendSlice(allocator, line);
    }

    return result.toOwnedSlice(allocator);
}

// Usage - indent code comments
const comment = "This is a long comment";
const indented = try indent(allocator, comment, "// ");
defer allocator.free(indented);
// Result: "// This is a long comment"
```

### Paragraph Formatting

**Format with first-line and hanging indents:**

```zig
pub fn formatParagraph(
    allocator: mem.Allocator,
    text: []const u8,
    width: usize,
    first_line_indent: usize,
    subsequent_indent: usize,
) ![]u8 {
    // First wrap the text
    const wrapped = try wrapText(allocator, text, width);
    defer allocator.free(wrapped);

    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    var lines = mem.tokenizeScalar(u8, wrapped, '\n');
    var first = true;

    while (lines.next()) |line| {
        if (!first) {
            try result.append(allocator, '\n');
        }

        // Add indentation
        const indent_size = if (first) first_line_indent else subsequent_indent;
        var i: usize = 0;
        while (i < indent_size) : (i += 1) {
            try result.append(allocator, ' ');
        }

        try result.appendSlice(allocator, line);
        first = false;
    }

    return result.toOwnedSlice(allocator);
}

// Usage - format with hanging indent
const para = "This is a long paragraph that needs proper formatting";
const formatted = try formatParagraph(allocator, para, 40, 4, 2);
defer allocator.free(formatted);
// First line: 4-space indent
// Other lines: 2-space indent
```

### Splitting into Lines

**Get array of wrapped lines:**

```zig
pub fn splitIntoLines(
    allocator: mem.Allocator,
    text: []const u8,
    width: usize,
) !std.ArrayList([]const u8) {
    var lines = std.ArrayList([]const u8){};
    errdefer lines.deinit(allocator);

    var line_start: usize = 0;

    while (line_start < text.len) {
        var line_end = @min(line_start + width, text.len);

        if (line_end < text.len) {
            var break_pos = line_end;
            while (break_pos > line_start) : (break_pos -= 1) {
                if (text[break_pos] == ' ') {
                    line_end = break_pos;
                    break;
                }
            }

            if (break_pos == line_start) {
                line_end = line_start + width;
            }
        }

        const line = mem.trim(u8, text[line_start..line_end], " ");
        try lines.append(allocator, line);

        line_start = line_end;
        while (line_start < text.len and text[line_start] == ' ') {
            line_start += 1;
        }
    }

    return lines;
}

// Usage
var lines = try splitIntoLines(allocator, long_text, 80);
defer lines.deinit(allocator);

for (lines.items) |line| {
    // Process each line
}
```

### Practical Examples

**Format code comments:**

```zig
const comment_text = "This is a very long comment that should be wrapped";
const wrapped = try wrapText(allocator, comment_text, 70);
defer allocator.free(wrapped);

const commented = try indent(allocator, wrapped, "// ");
defer allocator.free(commented);

// Result:
// "// This is a very long comment that should be wrapped"
// (on multiple lines if needed)
```

**Format block quotes:**

```zig
const quote = "Life is what happens when you're busy making other plans";
const quoted = try indent(allocator, quote, "> ");
defer allocator.free(quoted);

// Result: "> Life is what happens when you're busy making other plans"
```

**Format email replies:**

```zig
const original = "Original message text here";
const reply_quoted = try indent(allocator, original, "> ");
defer allocator.free(reply_quoted);

// Result:
// "> Original message text here"
```

**Format help text:**

```zig
const help_text = "This command does something useful with the specified arguments";
const formatted = try formatParagraph(allocator, help_text, 60, 0, 4);
defer allocator.free(formatted);

// First line starts at column 0
// Subsequent lines indented by 4 spaces
```

**Format terminal output:**

```zig
// Wrap to terminal width (commonly 80 columns)
const terminal_width = 80;
const output = try wrapText(allocator, long_message, terminal_width);
defer allocator.free(output);
```

**Format log messages:**

```zig
const log_msg = "Very long log message that exceeds normal width";
const wrapped_log = try wrapText(allocator, log_msg, 100);
defer allocator.free(wrapped_log);

const with_timestamp = try indent(allocator, wrapped_log, "[INFO] ");
defer allocator.free(with_timestamp);
```

### Word Wrapping Algorithms

**Smart wrapping considers:**
1. **Word boundaries** - Don't break words unless necessary
2. **Whitespace** - Trim leading/trailing spaces from lines
3. **Minimum line length** - Avoid very short lines
4. **Hyphenation** - Not implemented (complex, language-specific)

**Hard wrapping:**
- Breaks at exact width
- Used for URLs, hashes, non-text content
- Simpler and faster

### Performance

**Wrapping is O(n):**
- Single pass through text
- Efficient word boundary detection
- Minimal allocations

**Optimization for repeated wrapping:**

```zig
// Reuse ArrayList for multiple wraps
var wrapper = std.ArrayList(u8).init(allocator);
defer wrapper.deinit();

for (paragraphs) |para| {
    wrapper.clearRetainingCapacity();
    // Use wrapper for wrapping
    // Extract result
}
```

### Memory Management

All wrapping functions allocate:

```zig
const wrapped = try wrapText(allocator, text, width);
defer allocator.free(wrapped);  // Required

const indented = try indent(allocator, text, prefix);
defer allocator.free(indented);  // Required
```

### UTF-8 Considerations

Current implementation works at byte level:

```zig
// Works with UTF-8 but counts bytes, not visual width
const text = "Hello 世界";
const wrapped = try wrapText(allocator, text, 10);
defer allocator.free(wrapped);

// Chinese characters take 6 bytes but display as 2 characters
// Visual wrapping may look off
```

For proper visual wrapping with multi-byte characters:
1. Use Unicode library for grapheme counting
2. Track display width vs byte width
3. Handle combining characters
4. Consider language-specific rules

For ASCII/English text, byte-level wrapping works perfectly.

### Security

All operations are bounds-safe:

```zig
// Safe - handles edge cases
const empty_wrap = try wrapText(allocator, "", 80);
defer allocator.free(empty_wrap);

const zero_width = try wrapText(allocator, text, 0);
defer allocator.free(zero_width);
```

### Common Patterns

**Format documentation:**

```zig
fn formatDocComment(
    allocator: mem.Allocator,
    text: []const u8,
    width: usize,
) ![]u8 {
    const wrapped = try wrapText(allocator, text, width - 4);
    defer allocator.free(wrapped);

    return indent(allocator, wrapped, "/// ");
}
```

**Format markdown quotes:**

```zig
fn formatQuote(
    allocator: mem.Allocator,
    text: []const u8,
) ![]u8 {
    const wrapped = try wrapText(allocator, text, 76);  // 80 - 4 for "> "
    defer allocator.free(wrapped);

    return indent(allocator, wrapped, "> ");
}
```

**Format list items:**

```zig
fn formatListItem(
    allocator: mem.Allocator,
    text: []const u8,
    bullet: []const u8,
) ![]u8 {
    const width = 76;
    const wrapped = try wrapText(allocator, text, width);
    defer allocator.free(wrapped);

    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    var lines = mem.tokenizeScalar(u8, wrapped, '\n');
    var first = true;

    while (lines.next()) |line| {
        if (!first) {
            try result.append('\n');
        }

        if (first) {
            try result.appendSlice(bullet);
        } else {
            // Indent continuation lines
            var i: usize = 0;
            while (i < bullet.len) : (i += 1) {
                try result.append(' ');
            }
        }

        try result.appendSlice(line);
        first = false;
    }

    return result.toOwnedSlice();
}

// Usage:
// - First line of text
//   continues here
//   and here
```

This comprehensive text reformatting system handles word wrapping, line breaking, and indentation for terminal output, documentation, and formatted text display.
