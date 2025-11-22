## Problem

You need to remove unwanted characters from strings - trimming whitespace, removing special characters, or filtering text to keep only specific characters.

## Solution

Use Zig's `std.mem.trim` functions and custom filters for character removal:

### Trimming Whitespace and Specific Characters

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_7.zig:basic_trimming}}
```

### Removing and Keeping Specific Characters

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_7.zig:remove_keep_chars}}
```

## Discussion

### Available Trimming Functions

Zig's `std.mem` provides basic trimming:

**`mem.trim(u8, text, chars)`** - Remove characters from both ends
- Returns slice of original string (no allocation)
- Removes any character in `chars` string
- Common: `" \t\n\r"` for whitespace

**`mem.trimLeft(u8, text, chars)`** - Remove from start only
- Returns slice of original string
- Stops at first character not in `chars`

**`mem.trimRight(u8, text, chars)`** - Remove from end only
- Returns slice of original string
- Stops at last character not in `chars`

### Character Classification

Use `std.ascii` for common character categories:

**Remove non-alphanumeric:**
```zig
const ascii = std.ascii;

pub fn removeNonAlphanumeric(
    allocator: mem.Allocator,
    text: []const u8,
) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    for (text) |char| {
        if (ascii.isAlphanumeric(char)) {
            try result.append(allocator, char);
        }
    }

    return result.toOwnedSlice(allocator);
}

// Usage
const text = "hello, world! 123";
const clean = try removeNonAlphanumeric(allocator, text);
defer allocator.free(clean);
// clean is "helloworld123"
```

**Remove non-alphabetic:**
```zig
pub fn removeNonAlphabetic(
    allocator: mem.Allocator,
    text: []const u8,
) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    for (text) |char| {
        if (ascii.isAlphabetic(char)) {
            try result.append(allocator, char);
        }
    }

    return result.toOwnedSlice(allocator);
}
```

**Extract digits only:**
```zig
pub fn removeNonDigits(
    allocator: mem.Allocator,
    text: []const u8,
) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    for (text) |char| {
        if (ascii.isDigit(char)) {
            try result.append(allocator, char);
        }
    }

    return result.toOwnedSlice(allocator);
}
```

### Practical Examples

**Sanitize Filename:**
```zig
const filename = "my*file/name?.txt";
const safe = try removeChars(allocator, filename, "/*?<>|:");
defer allocator.free(safe);
// safe is "myfilename.txt"
```

**Extract Phone Number Digits:**
```zig
const phone = "(555) 123-4567";
const digits = try removeNonDigits(allocator, phone);
defer allocator.free(digits);
// digits is "5551234567"
```

**Clean User Input:**
```zig
// Remove extra whitespace
const input = "  hello   world  ";
const trimmed = mem.trim(u8, input, " \t\n\r");

// Collapse multiple spaces
pub fn collapseSpaces(
    allocator: mem.Allocator,
    text: []const u8,
) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    var prev_was_space = false;
    for (text) |char| {
        const is_space = char == ' ';
        if (is_space and prev_was_space) {
            continue; // Skip consecutive spaces
        }
        try result.append(allocator, char);
        prev_was_space = is_space;
    }

    return result.toOwnedSlice(allocator);
}

const collapsed = try collapseSpaces(allocator, trimmed);
defer allocator.free(collapsed);
// collapsed is "hello world"
```

**Remove Punctuation:**
```zig
const text = "Hello, World! How are you?";
const cleaned = try removeChars(allocator, text, ",.!?;:");
defer allocator.free(cleaned);
// cleaned is "Hello World How are you"
```

**Strip URL Protocol:**
```zig
pub fn stripPrefix(text: []const u8, prefix: []const u8) []const u8 {
    if (mem.startsWith(u8, text, prefix)) {
        return text[prefix.len..];
    }
    return text;
}

const url = "https://example.com";
const domain = stripPrefix(url, "https://");
// domain is "example.com"
```

**Strip File Extension:**
```zig
pub fn stripSuffix(text: []const u8, suffix: []const u8) []const u8 {
    if (mem.endsWith(u8, text, suffix)) {
        return text[0 .. text.len - suffix.len];
    }
    return text;
}

const filename = "document.txt";
const name = stripSuffix(filename, ".txt");
// name is "document"
```

### Allocation vs Slicing

Important distinction:

**Trim operations return slices** (no allocation):
```zig
const trimmed = mem.trim(u8, "  hello  ", " ");
// No need to free - trimmed is just a slice
```

**Remove operations allocate** (must free):
```zig
const cleaned = try removeChars(allocator, "hello!", "!");
defer allocator.free(cleaned);  // Must free
```

### Performance

**Trim operations are O(n):**
- Single pass to find first/last non-whitespace
- Returns slice, no copying

**Remove operations are O(n*m):**
- n = length of text
- m = length of chars_to_remove
- Must allocate and build new string

**Optimization for repeated checks:**
```zig
// Build a lookup table for O(1) checks
var to_remove = [_]bool{false} ** 256;
for (chars_to_remove) |c| {
    to_remove[c] = true;
}

// Now check is O(1)
for (text) |char| {
    if (!to_remove[char]) {
        // Keep character
    }
}
```

### Control Characters

Remove non-printable characters:

```zig
pub fn removeControlChars(
    allocator: mem.Allocator,
    text: []const u8,
) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    for (text) |char| {
        if (!ascii.isControl(char)) {
            try result.append(allocator, char);
        }
    }

    return result.toOwnedSlice(allocator);
}

const text = "hello\x00world\x01";
const clean = try removeControlChars(allocator, text);
defer allocator.free(clean);
// clean is "helloworld"
```

### UTF-8 Considerations

Trim and remove work at byte level, which is safe for UTF-8:

```zig
const text = "  Hello 世界  ";
const trimmed = mem.trim(u8, text, " ");
// trimmed is "Hello 世界"
// UTF-8 characters preserved correctly
```

However, character-by-character operations assume single-byte characters:

```zig
// This works for ASCII punctuation
removeChars(allocator, "Hello, 世界!", ",!")
// Result: "Hello 世界"

// This won't work correctly for multi-byte UTF-8 punctuation
// Need proper UTF-8 iterator for that
```

### Common Patterns

**Normalize Whitespace:**
```zig
pub fn normalizeWhitespace(
    allocator: mem.Allocator,
    text: []const u8,
) ![]u8 {
    // Trim ends
    const trimmed = mem.trim(u8, text, " \t\n\r");

    // Collapse internal spaces
    return collapseSpaces(allocator, trimmed);
}
```

**Clean Quotes:**
```zig
const quoted = "\"hello world\"";
const unquoted = mem.trim(u8, quoted, "\"");
// unquoted is "hello world"
```

**Strip Path Separators:**
```zig
const path = "/usr/local/bin/";
const clean = mem.trim(u8, path, "/");
// clean is "usr/local/bin"
```

### Security

All operations are bounds-safe:

```zig
// Safe - won't overflow
mem.trim(u8, "", " ")  // Returns ""
removeChars(allocator, "test", "xyz")  // Safe, returns copy
```

Zig's bounds checking prevents buffer overflows in debug mode.

### Memory Management

Always free allocated results:

```zig
const cleaned = try removeChars(allocator, text, unwanted);
defer allocator.free(cleaned);  // Clean up

// Use errdefer for error handling
pub fn processText(allocator: mem.Allocator, text: []const u8) ![]u8 {
    const step1 = try removeChars(allocator, text, ",");
    errdefer allocator.free(step1);  // Clean up if later step fails

    const step2 = try collapseSpaces(allocator, step1);
    allocator.free(step1);  // Don't need step1 anymore

    return step2;
}
```

### Real-World Examples

**Validate Username:**
```zig
pub fn sanitizeUsername(
    allocator: mem.Allocator,
    input: []const u8,
) ![]u8 {
    // Remove whitespace and special chars
    const cleaned = try removeNonAlphanumeric(allocator, input);
    errdefer allocator.free(cleaned);

    // Convert to lowercase (assuming ASCII)
    return ascii.allocLowerString(allocator, cleaned);
}
```

**Parse CSV Field:**
```zig
pub fn cleanCsvField(field: []const u8) []const u8 {
    // Remove quotes and trim
    const unquoted = mem.trim(u8, field, "\"");
    return mem.trim(u8, unquoted, " \t");
}
```

**Extract Numbers from String:**
```zig
const price = "Price: $19.99";
const numbers = try removeNonDigits(allocator, price);
defer allocator.free(numbers);
// numbers is "1999" (cents)
```

This comprehensive set of string cleaning operations handles most text sanitization needs efficiently and safely.
