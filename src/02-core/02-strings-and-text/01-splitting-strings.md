## Problem

You need to split a string into parts based on one or more delimiter characters, similar to Python's `str.split()` or JavaScript's `String.split()`.

## Solution

Zig's standard library provides several functions for splitting strings, each with different behavior:

### Split on Any of Multiple Delimiters

Use `tokenizeAny` to split on any character in a delimiter set, skipping empty tokens:

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_1.zig:basic_tokenize}}
```

### Split on Whitespace

A common pattern is splitting on any whitespace character:

```zig
const text = "  hello   world\tfoo\n\nbar  ";
var iter = mem.tokenizeAny(u8, text, " \t\n\r");

while (iter.next()) |token| {
    // token is "hello", "world", "foo", "bar"
}
```

### Split on a Sequence

Use `tokenizeSequence` for multi-character delimiters:

```zig
const text = "foo::bar::baz::qux";
var iter = mem.tokenizeSequence(u8, text, "::");

while (iter.next()) |token| {
    // token is "foo", "bar", "baz", "qux"
}
```

### Preserve Empty Tokens

Use `splitAny` instead of `tokenizeAny` to keep empty strings:

```zig
const text = "a,,b,c,";
var iter = mem.splitAny(u8, text, ",");

// Returns: "a", "", "b", "c", ""
while (iter.next()) |token| {
    // Empty tokens are included
}
```

### Collect Tokens into an ArrayList

For convenience, collect all tokens at once:

```zig
pub fn collectTokens(
    allocator: mem.Allocator,
    text: []const u8,
    delimiters: []const u8,
) !std.ArrayList([]const u8) {
    var result = std.ArrayList([]const u8){};
    errdefer result.deinit(allocator);

    var iter = mem.tokenizeAny(u8, text, delimiters);
    while (iter.next()) |token| {
        try result.append(allocator, token);
    }

    return result;
}

// Usage
var tokens = try collectTokens(allocator, "a,b,c", ",");
defer tokens.deinit(allocator);
// tokens.items is ["a", "b", "c"]
```

## Discussion

### Tokenize vs Split

Zig provides two families of functions with different behavior:

**`tokenize*` functions** skip empty tokens:
```zig
const text = "a,,b";
var iter = mem.tokenizeAny(u8, text, ",");
// Returns: "a", "b" (empty token skipped)
```

**`split*` functions** preserve empty tokens:
```zig
const text = "a,,b";
var iter = mem.splitAny(u8, text, ",");
// Returns: "a", "", "b"
```

Choose `tokenize` when you want to ignore consecutive delimiters (like splitting on whitespace). Use `split` when empty values are meaningful (like CSV parsing).

### Iterator Variants

Zig provides four main splitting functions:

- `mem.tokenizeAny(u8, text, delims)` - Skip empty, any delimiter
- `mem.tokenizeSequence(u8, text, delim)` - Skip empty, sequence delimiter
- `mem.splitAny(u8, text, delims)` - Keep empty, any delimiter
- `mem.splitSequence(u8, text, delim)` - Keep empty, sequence delimiter
- `mem.tokenizeScalar(u8, text, delim)` - Skip empty, single char
- `mem.splitScalar(u8, text, delim)` - Keep empty, single char

### Parsing CSV and Similar Formats

For CSV parsing, use `splitScalar` to preserve empty fields:

```zig
const csv = "name,age,city\nAlice,30,NYC\nBob,25,LA";
var lines = mem.splitScalar(u8, csv, '\n');

while (lines.next()) |line| {
    var cols = mem.splitScalar(u8, line, ',');
    while (cols.next()) |col| {
        // Process each column
    }
}
```

### Memory Efficiency

String iterators in Zig don't allocate memory - they return slices into the original string:

```zig
const text = "a,b,c";
var iter = mem.tokenizeAny(u8, text, ",");

// Each token is just a slice view into 'text'
const token = iter.next().?; // No allocation!
```

This is extremely efficient, but means the original string must remain valid while you're using the tokens.

### UTF-8 Considerations

Zig's split functions work on bytes (`u8`). For proper UTF-8 handling:

- Single-byte delimiters (like `,` or `\n`) work correctly with UTF-8
- Multi-byte delimiters work as byte sequences
- To split on Unicode grapheme clusters, you'd need additional Unicode handling

### Parsing Paths

Split file paths using the path separator:

```zig
const path = "/usr/local/bin/zig";
var iter = mem.tokenizeAny(u8, path, "/");

while (iter.next()) |component| {
    // component is "usr", "local", "bin", "zig"
}
```

For proper path handling, use `std.fs.path` functions instead.

### Security

Zig's string operations are memory-safe:
- Bounds checking prevents buffer overflows
- Slices know their length
- No null-terminated string pitfalls
- Iterator operations are safe

### Comparison with Other Languages

**Python:**
```python
text.split(',')  # Returns list
```

**JavaScript:**
```javascript
text.split(',')  // Returns array
```

**Zig:**
```zig
var iter = mem.tokenizeAny(u8, text, ",");
// Returns iterator (no allocation)
```

Zig's approach is more memory-efficient since it returns an iterator rather than allocating an array. If you need all tokens at once, use the `collectTokens` helper function.
