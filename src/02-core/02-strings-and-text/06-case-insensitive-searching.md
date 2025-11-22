## Problem

You need to search, compare, or replace text without worrying about whether letters are uppercase or lowercase.

## Solution

Use Zig's `std.ascii` functions for case-insensitive operations:

### Basic Case-Insensitive Comparison

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_6.zig:case_insensitive_compare}}
```

### Case-Insensitive Search

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_6.zig:case_insensitive_search}}
```

### Case Conversion

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_6.zig:case_conversion}}
```

### Case-Insensitive Replace

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_6.zig:case_insensitive_replace}}
```

## Discussion

### Available Case-Insensitive Functions

Zig's `std.ascii` provides the foundation for case operations:

**`ascii.eqlIgnoreCase(a, b)`** - Compare strings ignoring case
- Returns `bool`
- Works only with ASCII characters
- Efficient byte-by-byte comparison

**`ascii.allocLowerString(allocator, text)`** - Convert to lowercase
- Returns `![]u8` (allocates new string)
- ASCII-only conversion
- Preserves non-ASCII bytes unchanged

**`ascii.allocUpperString(allocator, text)`** - Convert to uppercase
- Returns `![]u8` (allocates new string)
- ASCII-only conversion
- Preserves non-ASCII bytes unchanged

### Building on the Foundation

The standard library provides basic case comparison, but you'll often need to implement higher-level operations:

**Custom indexOfIgnoreCase:**
```zig
pub fn indexOfIgnoreCase(text: []const u8, needle: []const u8) ?usize {
    if (needle.len > text.len) return null;

    var i: usize = 0;
    while (i <= text.len - needle.len) : (i += 1) {
        if (ascii.eqlIgnoreCase(text[i..][0..needle.len], needle)) {
            return i;
        }
    }
    return null;
}
```

**Count occurrences (case-insensitive):**
```zig
pub fn countIgnoreCase(text: []const u8, needle: []const u8) usize {
    var count: usize = 0;
    var pos: usize = 0;

    while (pos < text.len) {
        if (indexOfIgnoreCase(text[pos..], needle)) |found| {
            count += 1;
            pos += found + needle.len;
        } else {
            break;
        }
    }

    return count;
}
```

### Practical Examples

**File Extension Checking:**
```zig
pub fn endsWithIgnoreCase(text: []const u8, suffix: []const u8) bool {
    if (suffix.len > text.len) return false;
    return ascii.eqlIgnoreCase(text[text.len - suffix.len..], suffix);
}

const filename = "document.PDF";
if (endsWithIgnoreCase(filename, ".pdf")) {
    // It's a PDF file
}
```

**URL Protocol Detection:**
```zig
pub fn startsWithIgnoreCase(text: []const u8, prefix: []const u8) bool {
    if (prefix.len > text.len) return false;
    return ascii.eqlIgnoreCase(text[0..prefix.len], prefix);
}

const url = "HTTP://example.com";
if (startsWithIgnoreCase(url, "http://")) {
    // HTTP URL
}
```

**Normalize Text for Comparison:**
```zig
// Convert both strings to same case for comparison
const text1 = try ascii.allocLowerString(allocator, "Hello World");
defer allocator.free(text1);

const text2 = try ascii.allocLowerString(allocator, "hello world");
defer allocator.free(text2);

if (mem.eql(u8, text1, text2)) {
    // Strings are equal (ignoring case)
}
```

**Case-Insensitive Sorting:**
```zig
fn compareLowercase(context: void, a: []const u8, b: []const u8) bool {
    _ = context;
    const len = @min(a.len, b.len);
    var i: usize = 0;

    while (i < len) : (i += 1) {
        const a_lower = ascii.toLower(a[i]);
        const b_lower = ascii.toLower(b[i]);
        if (a_lower != b_lower) {
            return a_lower < b_lower;
        }
    }

    return a.len < b.len;
}

// Use with std.sort
std.sort.heap([]const u8, items, {}, compareLowercase);
```

### ASCII-Only Limitation

Important: `std.ascii` functions work only with ASCII characters (0-127). Non-ASCII characters are left unchanged:

```zig
const text = "Hello 世界";
const lower = try ascii.allocLowerString(allocator, text);
defer allocator.free(lower);

// Result: "hello 世界" (Chinese characters unchanged)
```

For full Unicode case folding, you would need:
1. A Unicode library (like `ziglyph`)
2. Or linking to ICU (International Components for Unicode)
3. Or implementing Unicode case tables manually

For most English text and programming contexts, ASCII operations are sufficient and much faster.

### Performance

**Case-insensitive search is O(n*m):**
- n = length of text
- m = length of needle
- Each position tests `eqlIgnoreCase` which is O(m)

**Optimization strategy:**
```zig
// For repeated searches, normalize once
const text_lower = try ascii.allocLowerString(allocator, text);
defer allocator.free(text_lower);

const needle_lower = try ascii.allocLowerString(allocator, needle);
defer allocator.free(needle_lower);

// Now use fast byte comparison
const pos = mem.indexOf(u8, text_lower, needle_lower);
```

This converts O(n*m) case-insensitive search to O(n+m) normalization + O(n) byte search.

### Memory Management

Case conversion functions allocate new strings:

```zig
const upper = try ascii.allocUpperString(allocator, "hello");
defer allocator.free(upper);  // Must free

// Original string unchanged
```

For in-place conversion (if you own the buffer):

```zig
pub fn lowerInPlace(text: []u8) void {
    for (text) |*c| {
        c.* = ascii.toLower(c.*);
    }
}

var buffer = [_]u8{'H', 'e', 'l', 'l', 'o'};
lowerInPlace(&buffer);
// buffer is now "hello"
```

### Security

All operations are bounds-safe:

```zig
// Safe - won't overflow
ascii.eqlIgnoreCase("short", "very long string");  // false

// Safe - returns null for impossible matches
indexOfIgnoreCase("abc", "longer needle");  // null
```

Zig's bounds checking prevents buffer overflows in debug mode.

### Common Patterns

**Case-Insensitive String Matching:**
```zig
pub fn matchesIgnoreCase(text: []const u8, pattern: []const u8) bool {
    return ascii.eqlIgnoreCase(text, pattern);
}
```

**Case-Insensitive List Search:**
```zig
pub fn containsAnyIgnoreCase(
    text: []const u8,
    needles: []const []const u8
) bool {
    for (needles) |needle| {
        if (containsIgnoreCase(text, needle)) {
            return true;
        }
    }
    return false;
}

// Check for keywords
const keywords = [_][]const u8{ "error", "warning", "critical" };
if (containsAnyIgnoreCase(log_line, &keywords)) {
    // Important log entry
}
```

**Case-Insensitive Key Lookup:**
```zig
pub fn findKeyIgnoreCase(
    map: std.StringHashMap(Value),
    key: []const u8,
) ?Value {
    var iter = map.iterator();
    while (iter.next()) |entry| {
        if (ascii.eqlIgnoreCase(entry.key_ptr.*, key)) {
            return entry.value_ptr.*;
        }
    }
    return null;
}
```

### When to Use Case-Insensitive Operations

**Good use cases:**
- User input comparison (usernames, commands)
- File extension checking
- Protocol/scheme detection (HTTP, FTP)
- Configuration key lookup
- Natural language search

**Avoid when:**
- Exact matching required (passwords, hashes)
- Binary data processing
- Performance-critical inner loops
- Non-Latin scripts (use Unicode libraries)

### Real-World Examples

**Command Parser:**
```zig
pub fn parseCommand(input: []const u8) ?Command {
    if (ascii.eqlIgnoreCase(input, "help")) return .Help;
    if (ascii.eqlIgnoreCase(input, "quit")) return .Quit;
    if (ascii.eqlIgnoreCase(input, "exit")) return .Exit;
    return null;
}
```

**File Type Detection:**
```zig
pub fn isImageFile(filename: []const u8) bool {
    return endsWithIgnoreCase(filename, ".jpg") or
           endsWithIgnoreCase(filename, ".jpeg") or
           endsWithIgnoreCase(filename, ".png") or
           endsWithIgnoreCase(filename, ".gif");
}
```

**Log Level Parsing:**
```zig
pub fn parseLogLevel(text: []const u8) ?LogLevel {
    if (containsIgnoreCase(text, "ERROR")) return .Error;
    if (containsIgnoreCase(text, "WARN")) return .Warning;
    if (containsIgnoreCase(text, "INFO")) return .Info;
    if (containsIgnoreCase(text, "DEBUG")) return .Debug;
    return null;
}
```

This comprehensive set of case-insensitive operations handles most text processing needs efficiently and safely within the ASCII character range.
