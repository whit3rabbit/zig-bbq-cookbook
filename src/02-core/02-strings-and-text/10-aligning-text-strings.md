## Problem

You need to align text for tables, reports, or structured output - left-aligning, right-aligning, centering, or formatting columns with proper padding.

## Solution

Create alignment functions for left, right, and center alignment with custom fill characters:

### Left, Right, and Center Alignment

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_10.zig:basic_alignment}}
```

## Discussion

### Formatting Tables

**Format table rows with aligned columns:**

```zig
pub fn formatRow(
    allocator: mem.Allocator,
    columns: []const []const u8,
    widths: []const usize,
    separator: []const u8,
) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    for (columns, widths, 0..) |col, width, i| {
        const padded = try alignLeft(allocator, col, width, ' ');
        defer allocator.free(padded);

        try result.appendSlice(allocator, padded);

        if (i < columns.len - 1) {
            try result.appendSlice(allocator, separator);
        }
    }

    return result.toOwnedSlice(allocator);
}

// Usage
const columns = [_][]const u8{ "Name", "Age", "City" };
const widths = [_]usize{ 10, 5, 15 };
const row = try formatRow(allocator, &columns, &widths, " | ");
defer allocator.free(row);
// row is "Name       | Age   | City           "
```

**Create divider lines:**

```zig
pub fn divider(
    allocator: mem.Allocator,
    width: usize,
    char: u8,
) ![]u8 {
    const result = try allocator.alloc(u8, width);
    @memset(result, char);
    return result;
}

// Usage
const div = try divider(allocator, 40, '-');
defer allocator.free(div);
// div is "----------------------------------------"
```

**Complete table example:**

```zig
const header = [_][]const u8{ "ID", "Name", "Status" };
const widths = [_]usize{ 5, 15, 10 };

// Format header
const header_row = try formatRow(allocator, &header, &widths, " | ");
defer allocator.free(header_row);

// Create divider
const div = try divider(allocator, header_row.len, '-');
defer allocator.free(div);

// Format data rows
const row1 = [_][]const u8{ "1", "Alice", "Active" };
const data_row = try formatRow(allocator, &row1, &widths, " | ");
defer allocator.free(data_row);

// Output:
// ID    | Name            | Status
// --------------------------------
// 1     | Alice           | Active
```

### Text Boxes

**Create bordered text boxes:**

```zig
pub fn textBox(
    allocator: mem.Allocator,
    text: []const u8,
    padding: usize,
) ![]u8 {
    const inner_width = text.len + (padding * 2);

    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    // Top border
    try result.append(allocator, '+');
    var i: usize = 0;
    while (i < inner_width) : (i += 1) {
        try result.append(allocator, '-');
    }
    try result.append(allocator, '+');
    try result.append(allocator, '\n');

    // Content with padding
    try result.append(allocator, '|');
    i = 0;
    while (i < padding) : (i += 1) {
        try result.append(allocator, ' ');
    }
    try result.appendSlice(allocator, text);
    i = 0;
    while (i < padding) : (i += 1) {
        try result.append(allocator, ' ');
    }
    try result.append(allocator, '|');
    try result.append(allocator, '\n');

    // Bottom border
    try result.append(allocator, '+');
    i = 0;
    while (i < inner_width) : (i += 1) {
        try result.append(allocator, '-');
    }
    try result.append(allocator, '+');

    return result.toOwnedSlice(allocator);
}

// Usage
const box = try textBox(allocator, "Hello", 2);
defer allocator.free(box);
// Output:
// +---------+
// |  Hello  |
// +---------+
```

### Text Truncation

**Truncate text with ellipsis:**

```zig
pub fn truncate(
    allocator: mem.Allocator,
    text: []const u8,
    width: usize,
) ![]u8 {
    if (text.len <= width) return allocator.dupe(u8, text);

    if (width < 3) {
        return allocator.dupe(u8, text[0..width]);
    }

    var result = try allocator.alloc(u8, width);
    @memcpy(result[0 .. width - 3], text[0 .. width - 3]);
    result[width - 3] = '.';
    result[width - 2] = '.';
    result[width - 1] = '.';

    return result;
}

// Usage
const long_text = "This is a very long text that needs truncation";
const short = try truncate(allocator, long_text, 20);
defer allocator.free(short);
// short is "This is a very l..."
```

### Practical Examples

**Format financial reports:**

```zig
// Right-align numbers for proper column alignment
const amount1 = try alignRight(allocator, "$9.99", 10, ' ');
defer allocator.free(amount1);
// "     $9.99"

const amount2 = try alignRight(allocator, "$129.99", 10, ' ');
defer allocator.free(amount2);
// "   $129.99"

// Both align properly in a column
```

**Create report headers:**

```zig
const title = try alignCenter(allocator, "MONTHLY REPORT", 60, '=');
defer allocator.free(title);
// "=======================MONTHLY REPORT======================="
```

**Format log entries:**

```zig
const level_columns = [_][]const u8{ "INFO", "12:34:56", "Server started" };
const widths = [_]usize{ 8, 10, 40 };
const log_line = try formatRow(allocator, &level_columns, &widths, " | ");
defer allocator.free(log_line);
// "INFO     | 12:34:56   | Server started                          "
```

**Create ASCII tables:**

```zig
// Build a complete table
const header = [_][]const u8{ "Product", "Price", "Stock" };
const widths = [_]usize{ 20, 10, 8 };

const header_row = try formatRow(allocator, &header, &widths, " | ");
defer allocator.free(header_row);

const div = try divider(allocator, header_row.len, '-');
defer allocator.free(div);

const row1 = [_][]const u8{ "Widget A", "$19.99", "150" };
const row2 = [_][]const u8{ "Widget B", "$29.99", "75" };

const data1 = try formatRow(allocator, &row1, &widths, " | ");
defer allocator.free(data1);

const data2 = try formatRow(allocator, &row2, &widths, " | ");
defer allocator.free(data2);

// Output:
// Product              | Price      | Stock
// ----------------------------------------
// Widget A             | $19.99     | 150
// Widget B             | $29.99     | 75
```

**Format code listings with line numbers:**

```zig
const line_num = try alignRight(allocator, "42", 4, ' ');
defer allocator.free(line_num);
const code = "    const x = 10;";

// Combine: "  42    const x = 10;"
```

### Performance

**Alignment allocates new strings:**

```zig
const result = try alignLeft(allocator, "text", 10, ' ');
defer allocator.free(result);  // Must free
```

**Pre-calculate sizes for efficiency:**

```zig
// Calculate total row width once
const total_width = widths[0] + separator.len + widths[1] + separator.len + widths[2];

// Use for divider
const div = try divider(allocator, total_width, '-');
defer allocator.free(div);
```

### Memory Management

All alignment functions allocate:

```zig
const aligned = try alignLeft(allocator, "text", width, ' ');
defer allocator.free(aligned);  // Required

// formatRow also allocates
const row = try formatRow(allocator, &cols, &widths, " | ");
defer allocator.free(row);  // Required
```

### UTF-8 Considerations

Alignment works at byte level, which may cause issues with multi-byte UTF-8 characters:

```zig
// This works but counts bytes, not visual characters
const result = try alignLeft(allocator, "Hello 世界", 20, ' ');
defer allocator.free(result);
// The Chinese characters take 6 bytes but appear as 2 characters
// Visual alignment may look off
```

For proper visual alignment with UTF-8, you need to:
1. Count grapheme clusters (visual characters)
2. Use a Unicode library
3. Or handle ASCII-only scenarios

For most programming contexts (logs, tables), byte-level alignment is acceptable.

### Security

All operations are bounds-safe:

```zig
// Safe - checks length before allocation
const result = try alignLeft(allocator, "test", 1000, ' ');
defer allocator.free(result);

// Safe - won't overflow
const truncated = try truncate(allocator, long_text, width);
defer allocator.free(truncated);
```

### Common Patterns

**Three-column layout:**

```zig
const left_col = try alignLeft(allocator, "Left", 20, ' ');
defer allocator.free(left_col);

const center_col = try alignCenter(allocator, "Center", 20, ' ');
defer allocator.free(center_col);

const right_col = try alignRight(allocator, "Right", 20, ' ');
defer allocator.free(right_col);
```

**Fixed-width output:**

```zig
// Truncate long values, pad short ones
var display_text: []u8 = undefined;
if (text.len > width) {
    display_text = try truncate(allocator, text, width);
} else {
    display_text = try alignLeft(allocator, text, width, ' ');
}
defer allocator.free(display_text);
```

**Numbered lists:**

```zig
var i: u32 = 1;
while (i <= 10) : (i += 1) {
    const num_str = try std.fmt.allocPrint(allocator, "{d}.", .{i});
    defer allocator.free(num_str);

    const padded = try alignRight(allocator, num_str, 4, ' ');
    defer allocator.free(padded);

    // "   1." through "  10."
}
```

This comprehensive text alignment system provides the building blocks for creating well-formatted tables, reports, and structured text output in Zig.
