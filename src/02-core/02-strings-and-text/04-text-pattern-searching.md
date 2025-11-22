## Problem

You need to search for text patterns within strings - finding substrings, checking for presence, or locating specific characters.

## Solution

Zig's `std.mem` provides comprehensive string search functions:

### Basic Substring Search

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_4.zig:basic_search}}
```

### Find Last Occurrence

```zig
const text = "hello hello world";

if (mem.lastIndexOf(u8, text, "hello")) |pos| {
    // Found at position 6 (second "hello")
}
```

### Find Any Character in Set

```zig
const text = "hello world";

// Find first vowel
if (mem.indexOfAny(u8, text, "aeiou")) |pos| {
    // Found 'e' at position 1
}

// Find first digit
const mixed = "Product ID: 12345";
if (mem.indexOfAny(u8, mixed, "0123456789")) |pos| {
    // Found '1' at position 12
}
```

### Find Character NOT in Set

```zig
const text = "   hello";

// Find first non-whitespace
if (mem.indexOfNone(u8, text, " \t\n\r")) |pos| {
    // Found 'h' at position 3
}
```

### Count Occurrences

```zig
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

// Usage
const text = "hello hello world";
const cnt = count(text, "hello");  // 2
```

### Find All Occurrences

```zig
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

// Usage
var positions = try findAll(allocator, "hello hello world", "hello");
defer positions.deinit(allocator);
// positions.items is [0, 6]
```

## Discussion

### Available Search Functions

Zig provides several search functions in `std.mem`:

**`indexOf(u8, text, needle)`** - Find first occurrence of substring
- Returns `?usize` (index or null)
- Efficient O(n*m) search

**`lastIndexOf(u8, text, needle)`** - Find last occurrence
- Returns `?usize`
- Searches from end backward

**`indexOfAny(u8, text, chars)`** - Find any character in set
- Returns `?usize`
- Useful for finding delimiters, digits, etc.

**`indexOfNone(u8, text, chars)`** - Find character NOT in set
- Returns `?usize`
- Useful for skipping whitespace, etc.

**`indexOfScalar(u8, text, char)`** - Find single character
- Returns `?usize`
- Optimized for single character search

### Practical Examples

**Extract Domain from Email:**
```zig
const email = "user@example.com";

if (mem.indexOf(u8, email, "@")) |at_pos| {
    const domain = email[at_pos + 1..];
    // domain is "example.com"
}
```

**Find File Extension:**
```zig
const path = "/path/to/file.txt";

if (mem.lastIndexOf(u8, path, ".")) |dot_pos| {
    const ext = path[dot_pos..];
    // ext is ".txt"
}
```

**Validate Password Requirements:**
```zig
const password = "MyP@ssw0rd";

const has_upper = mem.indexOfAny(u8, password, "ABCDEFGHIJKLMNOPQRSTUVWXYZ") != null;
const has_lower = mem.indexOfAny(u8, password, "abcdefghijklmnopqrstuvwxyz") != null;
const has_digit = mem.indexOfAny(u8, password, "0123456789") != null;
const has_special = mem.indexOfAny(u8, password, "!@#$%^&*") != null;

if (has_upper and has_lower and has_digit and has_special) {
    // Password meets requirements
}
```

**Find Balanced Brackets:**
```zig
const text = "array[index]";

const open = mem.indexOf(u8, text, "[");
const close = mem.indexOf(u8, text, "]");

if (open != null and close != null and close.? > open.?) {
    const content = text[open.? + 1 .. close.?];
    // content is "index"
}
```

**Count Line Breaks:**
```zig
const text = "line1\nline2\nline3";
const line_count = count(text, "\n") + 1;  // 3 lines
```

### Helper Functions

**Contains (simpler syntax):**
```zig
pub fn contains(text: []const u8, needle: []const u8) bool {
    return mem.indexOf(u8, text, needle) != null;
}

if (contains("hello world", "world")) {
    // Found
}
```

**Contains Any:**
```zig
pub fn containsAny(text: []const u8, needles: []const []const u8) bool {
    for (needles) |needle| {
        if (mem.indexOf(u8, text, needle) != null) {
            return true;
        }
    }
    return false;
}

const keywords = [_][]const u8{ "error", "warning", "critical" };
if (containsAny(log_line, &keywords)) {
    // Important log entry
}
```

**Contains All:**
```zig
pub fn containsAll(text: []const u8, needles: []const []const u8) bool {
    for (needles) |needle| {
        if (mem.indexOf(u8, text, needle) == null) {
            return false;
        }
    }
    return true;
}
```

### Performance

Search operations are O(n*m) where:
- n = length of text
- m = length of needle

For repeated searches in the same text, consider:
1. Boyer-Moore algorithm (faster for long needles)
2. KMP algorithm (better worst-case)
3. Aho-Corasick (multiple needles)

For simple cases, `indexOf` is fast and sufficient.

### Case Sensitivity

All search functions are case-sensitive:

```zig
mem.indexOf(u8, "Hello", "hello")  // null
mem.indexOf(u8, "Hello", "Hello")  // 0
```

For case-insensitive search, convert both to lowercase first (covered in Recipe 2.6).

### UTF-8 Compatibility

Functions work at the byte level, which is compatible with UTF-8:

```zig
const text = "Hello 世界";

mem.indexOf(u8, text, "世界")  // Returns byte position 6
mem.indexOf(u8, text, "世")    // Returns byte position 6
```

Multi-byte UTF-8 sequences are handled correctly since we search complete byte sequences.

### Memory Efficiency

Basic search functions don't allocate:

```zig
const idx = mem.indexOf(u8, text, "needle");
// No allocation, just pointer arithmetic
```

Only `findAll` allocates to store the result list:

```zig
var positions = try findAll(allocator, text, "needle");
defer positions.deinit(allocator);
```

### Security

All operations are bounds-safe:

```zig
// Safe - won't overflow
mem.indexOf(u8, "short", "very long needle that is much longer")
// Returns null, doesn't crash
```

Zig's bounds checking prevents buffer overflows in debug mode, and length checks prevent out-of-bounds access.

### When to Use Regex

For these simple patterns, built-in functions are faster than regex:
- Substring search → `indexOf`
- Character in set → `indexOfAny`
- Contains check → `indexOf != null`

Use regex when you need:
- Complex patterns (lookahead, groups)
- Character classes and ranges
- Alternation and repetition
- Capture groups

For most string searching tasks, Zig's built-in functions are faster and simpler.

### Real-World Examples

**Parse Log Levels:**
```zig
const log_line = "[ERROR] Connection failed";

if (mem.indexOf(u8, log_line, "[ERROR]")) |_| {
    // Handle error log
} else if (mem.indexOf(u8, log_line, "[WARNING]")) |_| {
    // Handle warning log
}
```

**Find URLs in Text:**
```zig
const text = "Visit https://example.com for info";

if (mem.indexOf(u8, text, "https://")) |pos| {
    // Found secure URL at position pos
}
```

**Check Code Comments:**
```zig
const line = "// This is a comment";
const trimmed = mem.trim(u8, line, " \t");

if (mem.indexOf(u8, trimmed, "//") == 0) {
    // This line starts with a comment
}
```

This comprehensive set of search functions covers most text searching needs efficiently and safely.
