## Problem

You need to work with Unicode strings properly - distinguishing between byte length and character count, iterating over codepoints instead of bytes, and handling multi-byte UTF-8 sequences correctly.

## Solution

Use Zig's `std.unicode` module for UTF-8 validation, iteration, and proper Unicode handling:

### UTF-8 Validation and Basics

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_12.zig:utf8_validation}}
```

### Accessing Codepoints

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_12.zig:codepoint_access}}
```

### UTF-8 Operations

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_12.zig:utf8_operations}}
```

## Discussion

### UTF-8 Basics in Zig

**Zig strings are byte arrays** (`[]const u8`):
- Not null-terminated (unlike C)
- UTF-8 by default (source files are UTF-8)
- No special "string" type
- Length is byte count, not character count

**UTF-8 encoding:**
- 1 byte: ASCII (0x00-0x7F)
- 2 bytes: Latin, Greek, Cyrillic, etc.
- 3 bytes: Most of CJK, Arabic, Hebrew
- 4 bytes: Emoji, rare characters

### Byte vs Codepoint Indexing

**Byte indexing (what `text[i]` does):**

```zig
const text = "A世B";

// Byte indexing
text[0];  // 'A' (1 byte)
text[1];  // First byte of '世' (3 bytes)
text[2];  // Second byte of '世'
text[3];  // Third byte of '世'
text[4];  // 'B' (1 byte)

// Total: 5 bytes
```

**Codepoint indexing (what you usually want):**

```zig
pub fn codepointAt(text: []const u8, index: usize) !?u21 {
    var count: usize = 0;
    var i: usize = 0;

    while (i < text.len) {
        if (count == index) {
            const cp_len = try unicode.utf8ByteSequenceLength(text[i]);
            const codepoint = try unicode.utf8Decode(text[i .. i + cp_len]);
            return codepoint;
        }

        const cp_len = try unicode.utf8ByteSequenceLength(text[i]);
        i += cp_len;
        count += 1;
    }

    return null;
}

// Usage
const text = "A世B";
const cp0 = try codepointAt(text, 0);  // 'A'
const cp1 = try codepointAt(text, 1);  // '世' (0x4E16)
const cp2 = try codepointAt(text, 2);  // 'B'
// Total: 3 codepoints
```

### UTF-8 Sequence Length

**Determine sequence length from first byte:**

```zig
pub fn getSequenceLength(first_byte: u8) !usize {
    const len = try unicode.utf8ByteSequenceLength(first_byte);
    return @as(usize, len);
}

// Usage
const len1 = try getSequenceLength('A');        // 1 byte
const len2 = try getSequenceLength(0xC0);       // 2 bytes
const len3 = try getSequenceLength(0xE0);       // 3 bytes
const len4 = try getSequenceLength(0xF0);       // 4 bytes
```

**Check if byte is continuation byte:**

```zig
pub fn isContinuationByte(byte: u8) bool {
    return (byte & 0b11000000) == 0b10000000;
}

// Continuation bytes: 10xxxxxx
// Start bytes: 0xxxxxxx (ASCII) or 11xxxxxx (multibyte)
```

### Converting Codepoints

**Codepoint to UTF-8:**

```zig
pub fn codepointToUtf8(
    allocator: mem.Allocator,
    codepoint: u21,
) ![]u8 {
    var buf: [4]u8 = undefined;
    const len = try unicode.utf8Encode(codepoint, &buf);
    return allocator.dupe(u8, buf[0..len]);
}

// Usage
const utf8 = try codepointToUtf8(allocator, 0x4E16);
defer allocator.free(utf8);
// utf8 is "世" (3 bytes)
```

### Substring by Codepoint

**Extract substring by codepoint positions:**

```zig
pub fn substringByCodepoint(
    allocator: mem.Allocator,
    text: []const u8,
    start: usize,
    end: usize,
) ![]u8 {
    if (start >= end) return allocator.dupe(u8, "");

    var byte_start: ?usize = null;
    var byte_end: ?usize = null;
    var count: usize = 0;
    var i: usize = 0;

    while (i < text.len) {
        if (count == start) byte_start = i;
        if (count == end) {
            byte_end = i;
            break;
        }

        const cp_len = try unicode.utf8ByteSequenceLength(text[i]);
        i += cp_len;
        count += 1;
    }

    if (byte_start == null) return allocator.dupe(u8, "");
    const actual_end = byte_end orelse text.len;

    return allocator.dupe(u8, text[byte_start.?..actual_end]);
}

// Usage
const text = "Hello世界";
const sub = try substringByCodepoint(allocator, text, 5, 7);
defer allocator.free(sub);
// sub is "世界" (codepoints 5-7, not bytes)
```

### Reversing UTF-8 Strings

**Reverse by codepoints, not bytes:**

```zig
pub fn reverseUtf8(
    allocator: mem.Allocator,
    text: []const u8,
) ![]u8 {
    // First collect all codepoints
    var codepoints = try iterateCodepoints(allocator, text);
    defer codepoints.deinit(allocator);

    // Calculate total bytes needed
    var total_bytes: usize = 0;
    for (codepoints.items) |cp| {
        total_bytes += unicode.utf8CodepointSequenceLength(cp) catch continue;
    }

    var result = try allocator.alloc(u8, total_bytes);
    var pos: usize = 0;
    var i: usize = codepoints.items.len;

    while (i > 0) {
        i -= 1;
        const cp = codepoints.items[i];
        const len = try unicode.utf8Encode(cp, result[pos..]);
        pos += len;
    }

    return result;
}

// Usage
const reversed = try reverseUtf8(allocator, "Hi世");
defer allocator.free(reversed);
// reversed is "世iH"
```

### Practical Examples

**Count visual characters:**

```zig
const text = "Hello 世界 👋";
const byte_len = text.len;           // Bytes
const char_count = try countCodepoints(text);  // Characters

// byte_len might be 17, char_count is 9
```

**Validate user input:**

```zig
fn validateInput(input: []const u8) bool {
    if (!isValidUtf8(input)) {
        return false;  // Invalid UTF-8
    }

    const cp_count = countCodepoints(input) catch return false;
    if (cp_count == 0 or cp_count > 100) {
        return false;  // Too short or too long
    }

    return true;
}
```

**Truncate to character limit:**

```zig
fn truncateToCharLimit(
    allocator: mem.Allocator,
    text: []const u8,
    max_chars: usize,
) ![]u8 {
    const cp_count = try countCodepoints(text);
    if (cp_count <= max_chars) {
        return allocator.dupe(u8, text);
    }

    return substringByCodepoint(allocator, text, 0, max_chars);
}
```

**Check for emoji:**

```zig
fn containsEmoji(text: []const u8) !bool {
    var codepoints = try iterateCodepoints(allocator, text);
    defer codepoints.deinit(allocator);

    for (codepoints.items) |cp| {
        // Emoji typically in these ranges
        if (cp >= 0x1F600 and cp <= 0x1F64F) return true;  // Emoticons
        if (cp >= 0x1F300 and cp <= 0x1F5FF) return true;  // Misc symbols
        if (cp >= 0x1F680 and cp <= 0x1F6FF) return true;  // Transport
        if (cp >= 0x2600 and cp <= 0x26FF) return true;    // Misc symbols
    }

    return false;
}
```

### Performance

**UTF-8 iteration is O(n):**
- Must scan each byte to find boundaries
- Cannot random-access codepoints
- Trade-off for compact encoding

**For repeated access:**

```zig
// Cache codepoint positions if accessing frequently
var positions = std.ArrayList(usize).init(allocator);
defer positions.deinit();

var i: usize = 0;
while (i < text.len) {
    try positions.append(i);
    const len = try unicode.utf8ByteSequenceLength(text[i]);
    i += len;
}

// Now can quickly access any codepoint by index
```

### Memory Management

All UTF-8 operations that allocate must be freed:

```zig
var codepoints = try iterateCodepoints(allocator, text);
defer codepoints.deinit(allocator);

const utf8_bytes = try codepointToUtf8(allocator, codepoint);
defer allocator.free(utf8_bytes);

const substring = try substringByCodepoint(allocator, text, start, end);
defer allocator.free(substring);
```

### Security

**Always validate UTF-8 from untrusted sources:**

```zig
fn processUserInput(input: []const u8) !void {
    // Validate first
    if (!isValidUtf8(input)) {
        return error.InvalidUtf8;
    }

    // Now safe to process
    const count = try countCodepoints(input);
    // ...
}
```

**Invalid UTF-8 can cause:**
- Buffer overruns (if not validated)
- Incorrect string operations
- Security vulnerabilities

**Zig's UTF-8 functions handle errors:**

```zig
// Returns error if invalid
const len = unicode.utf8ByteSequenceLength(byte) catch {
    // Handle invalid UTF-8
    return error.InvalidUtf8;
};
```

### Common Pitfalls

**❌ Wrong: Byte indexing for characters**

```zig
const text = "世界";
const char = text[0];  // Just first byte of '世', not complete character
```

**✓ Right: Codepoint indexing**

```zig
const text = "世界";
const char = try codepointAt(text, 0);  // Complete '世' codepoint
```

**❌ Wrong: Using .len for character count**

```zig
const text = "世界";
if (text.len > 10) {  // Comparing bytes, not characters
    // ...
}
```

**✓ Right: Counting codepoints**

```zig
const text = "世界";
const count = try countCodepoints(text);
if (count > 10) {  // Comparing characters
    // ...
}
```

### UTF-8 Invariants

Zig guarantees:
1. Source files are UTF-8
2. String literals are UTF-8
3. No automatic conversions
4. Explicit validation required for untrusted input

### When to Use Bytes vs Codepoints

**Use byte operations when:**
- Working with ASCII-only text
- Performance critical (avoid iteration)
- Binary data or protocols
- File I/O or network transmission

**Use codepoint operations when:**
- Displaying to users
- Character counting/limits
- Text manipulation (reverse, substring)
- Unicode-aware processing

This comprehensive guide covers proper UTF-8 handling in Zig, distinguishing between byte and codepoint operations for correct Unicode support.
