## Problem

You need to match strings against simple wildcard patterns like `*.txt` or `test_?.zig`, similar to shell glob patterns or SQL's `LIKE` operator.

## Solution

Implement a simple glob matcher that supports `*` (match any characters) and `?` (match exactly one character):

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_3.zig:glob_matching}}
```

### Basic Usage

```zig
// Exact match
glob("hello", "hello")  // true

// Wildcard * - matches any characters
glob("hello.txt", "*.txt")      // true
glob("document.pdf", "*.txt")   // false

// Wildcard ? - matches exactly one character
glob("cat", "c?t")    // true
glob("cart", "c?t")   // false (too many chars)
```

### File Extension Matching

```zig
const filename = "document.pdf";

if (glob(filename, "*.pdf")) {
    // PDF file
}

if (glob(filename, "*.txt") or glob(filename, "*.md")) {
    // Text or markdown file
}
```

### Match Multiple Patterns

```zig
pub fn globAny(text: []const u8, patterns: []const []const u8) bool {
    for (patterns) |pattern| {
        if (glob(text, pattern)) {
            return true;
        }
    }
    return false;
}

// Usage
const image_patterns = [_][]const u8{ "*.jpg", "*.png", "*.gif" };
if (globAny("photo.jpg", &image_patterns)) {
    // Image file
}
```

### Filter Lists by Pattern

```zig
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

// Usage
const files = [_][]const u8{ "main.zig", "test.zig", "README.md" };
var zig_files = try filterByGlob(allocator, &files, "*.zig");
defer zig_files.deinit(allocator);
// zig_files contains ["main.zig", "test.zig"]
```

## Discussion

### Pattern Syntax

**`*` (asterisk)** - Matches zero or more characters:
```zig
glob("test", "test*")       // true
glob("testing", "test*")    // true
glob("test.txt", "test*")   // true
glob("", "*")               // true
```

**`?` (question mark)** - Matches exactly one character:
```zig
glob("cat", "c?t")      // true
glob("cut", "c?t")      // true
glob("ct", "c?t")       // false (? must match one char)
glob("cart", "c?t")     // false (too many chars)
```

**Combining wildcards:**
```zig
glob("data123.csv", "data???.*")     // true
glob("test.tar.gz", "*.*.*")         // true
glob("hello_world", "hello*world")   // true
```

### Common Use Cases

**File Extension Filtering:**
```zig
const files = [_][]const u8{ "main.zig", "test.zig", "README.md" };

for (files) |file| {
    if (glob(file, "*.zig")) {
        // Process Zig source file
    }
}
```

**Test File Detection:**
```zig
if (glob(filename, "test_*.zig") or glob(filename, "*_test.zig")) {
    // This is a test file
}
```

**Backup File Detection:**
```zig
if (glob(filename, "*.bak") or glob(filename, "*~")) {
    // This is a backup file
}
```

**Version String Matching:**
```zig
glob("v1.2.3", "v*.*.*")        // true
glob("version-1.0.0", "version-*")  // true
```

**Date Pattern Matching:**
```zig
glob("2024-01-15", "????-??-??")              // true
glob("log-2024-01-15.txt", "log-????-??-??.txt")  // true
```

### Limitations

This simple implementation:
- Is case-sensitive (use `std.ascii.toLower` for case-insensitive matching)
- Doesn't support character classes like `[abc]` or `[0-9]`
- Doesn't support negation like `[!abc]`
- Doesn't support brace expansion like `{a,b,c}`
- Treats special characters literally (except `*` and `?`)

For full glob support with character classes and ranges, you'd need a more complex implementation or a third-party library.

### Performance

The recursive implementation can handle complex patterns efficiently:

```zig
// Multiple * wildcards don't cause exponential time
glob("file.tar.gz", "*.*.*")  // Fast
```

However, very complex patterns with many wildcards could be slow. For production use with untrusted patterns, consider adding depth limits or timeouts.

### Memory Efficiency

The glob function doesn't allocate memory - it uses recursion with simple integer indices:

```zig
const matched = glob("file.txt", "*.txt");
// No allocation, stack-based recursion only
```

For filtering, only the result list allocates:

```zig
var results = try filterByGlob(allocator, files, "*.zig");
defer results.deinit(allocator);
// Only the result list is allocated
```

### Case Sensitivity

The implementation is case-sensitive by default:

```zig
glob("File.txt", "file.txt")  // false
glob("File.txt", "File.txt")  // true
```

For case-insensitive matching, normalize both strings first:

```zig
const text_lower = try std.ascii.allocLowerString(allocator, text);
defer allocator.free(text_lower);
const pattern_lower = try std.ascii.allocLowerString(allocator, pattern);
defer allocator.free(pattern_lower);

const matched = glob(text_lower, pattern_lower);
```

### Security

The implementation is memory-safe:
- Bounds checking prevents buffer overflows
- Recursion depth is limited by pattern complexity
- No undefined behavior with malformed patterns

```zig
// Safe - won't crash or overflow
glob("short", "very*long*pattern*with*many*wildcards")
```

### Comparison with Regex

Glob patterns are simpler and faster than full regular expressions:

**Glob advantages:**
- Simpler syntax
- Faster for basic patterns
- More intuitive for file matching
- No regex engine needed

**Regex advantages:**
- More powerful (lookahead, groups, etc.)
- Character classes and ranges
- Anchors and boundaries
- More complex patterns

For simple file matching, glob is perfect. For complex text processing, use a regex library.

### Real-World Examples

**Find All Test Files:**
```zig
const all_files = try listDirectory(allocator, "src");
defer all_files.deinit(allocator);

var test_files = try filterByGlob(allocator, all_files.items, "*_test.zig");
defer test_files.deinit(allocator);
```

**Process Specific File Types:**
```zig
for (files) |file| {
    if (globAny(file, &[_][]const u8{ "*.jpg", "*.png", "*.gif" })) {
        try processImage(file);
    } else if (globAny(file, &[_][]const u8{ "*.mp4", "*.avi", "*.mkv" })) {
        try processVideo(file);
    }
}
```

This glob implementation provides efficient, memory-safe wildcard matching perfect for file filtering and simple pattern matching tasks.
