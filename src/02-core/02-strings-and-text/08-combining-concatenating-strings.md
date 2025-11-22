## Problem

You need to combine multiple strings together - concatenating, joining with separators, or building complex strings from multiple parts.

## Solution

Use Zig's `std.ArrayList(u8)` for building strings and `std.mem.join` for joining with separators:

### Basic Concatenation and Multiple Strings

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_8.zig:basic_concat}}
```

### Joining with Separators

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_8.zig:join_strings}}
```

### Building Strings with ArrayList

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_8.zig:string_builder}}
```

## Discussion

### String Concatenation Approaches

Zig provides several ways to combine strings, each with different trade-offs:

**ArrayList approach** - Most flexible, efficient for multiple appends:
```zig
var builder = std.ArrayList(u8){};
defer builder.deinit(allocator);

try builder.appendSlice(allocator, "part1");
try builder.appendSlice(allocator, "part2");

const result = try builder.toOwnedSlice(allocator);
defer allocator.free(result);
```

**mem.join** - Best for joining with separators:
```zig
const parts = [_][]const u8{ "a", "b", "c" };
const joined = try mem.join(allocator, "-", &parts);
defer allocator.free(joined);
// joined is "a-b-c"
```

**Manual allocation** - Most control, efficient when size known:
```zig
const a = "hello";
const b = " world";
const size = a.len + b.len;

var result = try allocator.alloc(u8, size);
@memcpy(result[0..a.len], a);
@memcpy(result[a.len..][0..b.len], b);
// result is "hello world"
```

### Joining Strings

The `mem.join` function is highly optimized:

```zig
pub fn join(
    allocator: mem.Allocator,
    separator: []const u8,
    strings: []const []const u8,
) ![]u8 {
    if (strings.len == 0) return allocator.dupe(u8, "");
    if (strings.len == 1) return allocator.dupe(u8, strings[0]);

    // Calculate total size
    var total_size: usize = 0;
    for (strings) |str| {
        total_size += str.len;
    }
    total_size += separator.len * (strings.len - 1);

    // Allocate once
    var result = try allocator.alloc(u8, total_size);
    errdefer allocator.free(result);

    // Copy all parts
    var pos: usize = 0;
    for (strings, 0..) |str, i| {
        @memcpy(result[pos..][0..str.len], str);
        pos += str.len;

        if (i < strings.len - 1) {
            @memcpy(result[pos..][0..separator.len], separator);
            pos += separator.len;
        }
    }

    return result;
}
```

### String Repetition

Repeat a string multiple times:

```zig
pub fn repeat(
    allocator: mem.Allocator,
    text: []const u8,
    count: usize,
) ![]u8 {
    if (count == 0) return allocator.dupe(u8, "");

    const total_size = text.len * count;
    var result = try allocator.alloc(u8, total_size);
    errdefer allocator.free(result);

    var pos: usize = 0;
    var i: usize = 0;
    while (i < count) : (i += 1) {
        @memcpy(result[pos..][0..text.len], text);
        pos += text.len;
    }

    return result;
}

// Create divider line
const divider = try repeat(allocator, "-", 40);
defer allocator.free(divider);
// divider is "----------------------------------------"
```

### String Padding

Pad strings to a fixed width:

**Left-aligned (pad right):**
```zig
pub fn padRight(
    allocator: mem.Allocator,
    text: []const u8,
    width: usize,
    pad_char: u8,
) ![]u8 {
    if (text.len >= width) return allocator.dupe(u8, text);

    var result = try allocator.alloc(u8, width);
    @memcpy(result[0..text.len], text);

    var i: usize = text.len;
    while (i < width) : (i += 1) {
        result[i] = pad_char;
    }

    return result;
}

const padded = try padRight(allocator, "hello", 10, ' ');
defer allocator.free(padded);
// padded is "hello     "
```

**Right-aligned (pad left):**
```zig
pub fn padLeft(
    allocator: mem.Allocator,
    text: []const u8,
    width: usize,
    pad_char: u8,
) ![]u8 {
    if (text.len >= width) return allocator.dupe(u8, text);

    var result = try allocator.alloc(u8, width);
    const pad_count = width - text.len;

    var i: usize = 0;
    while (i < pad_count) : (i += 1) {
        result[i] = pad_char;
    }

    @memcpy(result[pad_count..][0..text.len], text);
    return result;
}

const number = try padLeft(allocator, "42", 5, '0');
defer allocator.free(number);
// number is "00042"
```

**Centered:**
```zig
pub fn center(
    allocator: mem.Allocator,
    text: []const u8,
    width: usize,
    pad_char: u8,
) ![]u8 {
    if (text.len >= width) return allocator.dupe(u8, text);

    var result = try allocator.alloc(u8, width);
    const total_padding = width - text.len;
    const left_padding = total_padding / 2;

    var i: usize = 0;
    while (i < left_padding) : (i += 1) {
        result[i] = pad_char;
    }

    @memcpy(result[left_padding..][0..text.len], text);

    i = left_padding + text.len;
    while (i < width) : (i += 1) {
        result[i] = pad_char;
    }

    return result;
}

const centered = try center(allocator, "hi", 6, ' ');
defer allocator.free(centered);
// centered is "  hi  "
```

### Interspersing

Insert a separator between every character:

```zig
pub fn intersperse(
    allocator: mem.Allocator,
    text: []const u8,
    separator: []const u8,
) ![]u8 {
    if (text.len == 0) return allocator.dupe(u8, "");
    if (text.len == 1) return allocator.dupe(u8, text);

    const total_size = text.len + separator.len * (text.len - 1);
    var result = try allocator.alloc(u8, total_size);

    var pos: usize = 0;
    for (text, 0..) |char, i| {
        result[pos] = char;
        pos += 1;

        if (i < text.len - 1) {
            @memcpy(result[pos..][0..separator.len], separator);
            pos += separator.len;
        }
    }

    return result;
}

const spaced = try intersperse(allocator, "abc", "-");
defer allocator.free(spaced);
// spaced is "a-b-c"
```

### Practical Examples

**Build CSV Line:**
```zig
const fields = [_][]const u8{ "Name", "Age", "City" };
const csv_line = try mem.join(allocator, ",", &fields);
defer allocator.free(csv_line);
// csv_line is "Name,Age,City"
```

**Build File Path:**
```zig
const parts = [_][]const u8{ "home", "user", "documents", "file.txt" };
const path = try mem.join(allocator, "/", &parts);
defer allocator.free(path);
// path is "home/user/documents/file.txt"
```

**Format Table Row:**
```zig
const columns = [_][]const u8{ "10", "20", "30" };
const row = try mem.join(allocator, " | ", &columns);
defer allocator.free(row);
// row is "10 | 20 | 30"
```

**Build HTML Tag:**
```zig
var builder = std.ArrayList(u8){};
defer builder.deinit(allocator);

try builder.appendSlice(allocator, "<");
try builder.appendSlice(allocator, "div");
try builder.appendSlice(allocator, " class=\"");
try builder.appendSlice(allocator, "container");
try builder.appendSlice(allocator, "\">");

const tag = try builder.toOwnedSlice(allocator);
defer allocator.free(tag);
// tag is "<div class=\"container\">"
```

**Format Phone Number:**
```zig
const parts = [_][]const u8{ "(555)", " ", "123", "-", "4567" };
const phone = try concatMultiple(allocator, &parts);
defer allocator.free(phone);
// phone is "(555) 123-4567"
```

### Performance

**ArrayList is efficient for building strings:**
- Amortized O(1) append operations
- Grows capacity exponentially (1.5x or 2x)
- Single allocation for final result

**Pre-calculating size is faster:**
```zig
// Calculate size first
var total: usize = 0;
for (parts) |part| {
    total += part.len;
}

// Single allocation
var result = try allocator.alloc(u8, total);
// ... copy parts
```

**mem.join is optimized:**
- Calculates total size once
- Single allocation
- Efficient memcpy operations

### Memory Management

All concatenation operations allocate new strings:

```zig
const result = try concat(allocator, "a", "b");
defer allocator.free(result);  // Must free

// ArrayList also needs cleanup
var builder = std.ArrayList(u8){};
defer builder.deinit(allocator);  // Even if toOwnedSlice called
```

When using `toOwnedSlice`, the ArrayList no longer owns the memory, but you must still call `deinit`:

```zig
var builder = std.ArrayList(u8){};
defer builder.deinit(allocator);  // Clean up ArrayList metadata

try builder.appendSlice(allocator, "data");
const result = try builder.toOwnedSlice(allocator);
defer allocator.free(result);  // Also free the result
```

### UTF-8 Safety

Concatenation is safe with UTF-8:

```zig
const result = try concat(allocator, "Hello ", "世界");
defer allocator.free(result);
// result is "Hello 世界" - correct UTF-8
```

Byte-level operations preserve multi-byte sequences:

```zig
const parts = [_][]const u8{ "Hello", "世界", "Zig" };
const joined = try mem.join(allocator, " ", &parts);
defer allocator.free(joined);
// joined is "Hello 世界 Zig" - correct UTF-8
```

### Security

All operations are bounds-safe:

```zig
// Safe - no overflow possible
const empty = [_][]const u8{};
const result = try mem.join(allocator, ",", &empty);
defer allocator.free(result);
// result is ""
```

Zig's runtime checks prevent buffer overflows in debug builds.

### When to Use Each Approach

**Use ArrayList when:**
- Building string incrementally
- Unknown final size
- Many small appends
- Need flexibility

**Use mem.join when:**
- Joining with separator
- Known array of strings
- Want stdlib optimization

**Use manual allocation when:**
- Know exact final size
- Maximum performance needed
- Minimal memory overhead important

**Use formatting when:**
- Need type conversion (covered in Recipe 2.12)
- Complex string interpolation
- Debugging output

This comprehensive set of string combination operations handles most text building needs efficiently, safely, and idiomatically in Zig.
