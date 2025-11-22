## Problem

You need to check if a string starts with or ends with specific text, similar to Python's `str.startswith()` and `str.endswith()` or JavaScript's `String.startsWith()` and `String.endsWith()`.

## Solution

Zig's standard library provides `mem.startsWith` and `mem.endsWith` for these checks:

### Basic Prefix and Suffix Checking

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_2.zig:basic_prefix_suffix}}
```

### Check File Extensions

```zig
const filename = "document.pdf";

if (mem.endsWith(u8, filename, ".pdf")) {
    // It's a PDF file
}
```

### Check URL Protocols

```zig
const url = "https://example.com";

if (mem.startsWith(u8, url, "https://")) {
    // Secure connection
}
```

### Check Multiple Possibilities

```zig
pub fn startsWithAny(text: []const u8, prefixes: []const []const u8) bool {
    for (prefixes) |prefix| {
        if (mem.startsWith(u8, text, prefix)) {
            return true;
        }
    }
    return false;
}

// Usage
const protocols = [_][]const u8{ "http://", "https://", "ftp://" };
if (startsWithAny(url, &protocols)) {
    // URL has a known protocol
}
```

### Strip Prefixes and Suffixes

```zig
pub fn stripPrefix(text: []const u8, prefix: []const u8) []const u8 {
    if (mem.startsWith(u8, text, prefix)) {
        return text[prefix.len..];
    }
    return text;
}

pub fn stripSuffix(text: []const u8, suffix: []const u8) []const u8 {
    if (mem.endsWith(u8, text, suffix)) {
        return text[0 .. text.len - suffix.len];
    }
    return text;
}

// Usage
const url = "https://example.com";
const domain = stripPrefix(url, "https://");
// domain is "example.com"

const filename = "document.pdf";
const name = stripSuffix(filename, ".pdf");
// name is "document"
```

### Chain Stripping

```zig
const url = "https://example.com/path";
const result = stripSuffix(stripPrefix(url, "https://"), "/path");
// result is "example.com"
```

## Discussion

### Memory Efficiency

`startsWith` and `endsWith` don't allocate memory - they perform direct byte comparison:

```zig
const has_prefix = mem.startsWith(u8, text, "prefix");
// No allocation, just compares bytes
```

The strip functions return slices into the original string, also without allocation:

```zig
const stripped = stripPrefix(text, "http://");
// stripped is a slice view into text, no allocation
```

### Case Sensitivity

These functions are case-sensitive by default:

```zig
mem.startsWith(u8, "Hello", "hello") // false
mem.startsWith(u8, "Hello", "Hello") // true
```

For case-insensitive matching, you'd need to normalize case first (covered in a later recipe).

### Edge Cases

**Empty Strings:**
```zig
mem.startsWith(u8, "", "")     // true
mem.endsWith(u8, "", "")       // true
mem.startsWith(u8, "", "text") // false
```

**Exact Match:**
```zig
mem.startsWith(u8, "exact", "exact") // true
mem.endsWith(u8, "exact", "exact")   // true
```

**Prefix/Suffix Longer than String:**
```zig
mem.startsWith(u8, "hi", "hello") // false
// Safely returns false, no buffer overflow
```

### Practical Examples

**Filter Files by Extension:**
```zig
const files = [_][]const u8{ "main.zig", "test.zig", "README.md" };

for (files) |file| {
    if (mem.endsWith(u8, file, ".zig")) {
        // Process Zig file
    }
}
```

**Remove URL Protocol:**
```zig
var url: []const u8 = "https://example.com";

// Remove protocol if present
if (mem.startsWith(u8, url, "https://")) {
    url = url[8..]; // Skip "https://"
} else if (mem.startsWith(u8, url, "http://")) {
    url = url[7..]; // Skip "http://"
}
```

**Strip Multiple Prefixes:**
```zig
const text = "re: re: important message";

var result: []const u8 = text;
while (mem.startsWith(u8, result, "re: ")) {
    result = stripPrefix(result, "re: ");
}
// result is "important message"
```

**Check Comment Lines:**
```zig
const lines = [_][]const u8{
    "// This is a comment",
    "const x = 5;",
    "# Another comment style",
};

for (lines) |line| {
    const trimmed = mem.trim(u8, line, " \t");
    if (mem.startsWith(u8, trimmed, "//") or mem.startsWith(u8, trimmed, "#")) {
        // This is a comment
    }
}
```

### UTF-8 Compatibility

These functions work at the byte level, which is compatible with UTF-8:

```zig
const text = "Hello 世界";

mem.startsWith(u8, text, "Hello")  // true
mem.endsWith(u8, text, "世界")      // true
```

Multi-byte UTF-8 sequences are handled correctly since we're comparing complete byte sequences:

```zig
const chinese = "你好世界";
mem.startsWith(u8, chinese, "你好") // true
mem.endsWith(u8, chinese, "世界")   // true
```

### Security

Zig's bounds checking prevents common security issues:

```zig
// This is safe - won't overflow
const safe = mem.startsWith(u8, "short", "very long prefix");
// Returns false, doesn't crash
```

All slice operations are bounds-checked in debug mode, and length checks prevent out-of-bounds access.

### Performance

These operations are O(n) where n is the length of the prefix/suffix being checked:

- `startsWith`: Compares up to `prefix.len` bytes
- `endsWith`: Compares up to `suffix.len` bytes

No scanning of the entire string is needed, making them very efficient.

### Comparison with Other Languages

**Python:**
```python
text.startswith('hello')
text.endswith('world')
text.removeprefix('hello')  # Python 3.9+
text.removesuffix('world')  # Python 3.9+
```

**JavaScript:**
```javascript
text.startsWith('hello')
text.endsWith('world')
```

**Zig:**
```zig
mem.startsWith(u8, text, "hello")
mem.endsWith(u8, text, "world")
stripPrefix(text, "hello")  // Custom function
stripSuffix(text, "world")  // Custom function
```

Zig's approach is more explicit but equally efficient, with the advantage of no hidden allocations.
