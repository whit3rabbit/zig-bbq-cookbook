## Problem

You want to print data to a file with custom separators between values (like tabs, commas, or pipes) or use different line endings (like Windows CRLF or no line endings at all).

## Solution

### Delimited Output

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_3.zig:delimited_output}}
```

### Line Endings

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_3.zig:line_endings}}
```

### Format Variations

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_3.zig:format_variations}}
```

## Discussion

### Separator Strategies

When printing tabular or structured data, choosing the right separator is important:

**Tab-separated (\t):**
- Good for terminal display with aligned columns
- Easy to parse
- Works well with spreadsheet applications
- Not great for data containing actual tabs

**Comma-separated (,):**
- Standard CSV format
- Widely supported
- Requires escaping commas in data
- Need to handle quoted fields

**Pipe-separated (|):**
- Less common in data
- Easy to visually parse
- Good for log files
- Still need escaping if data contains pipes

**Custom separators:**
- Use unique strings like `::` or `|||`
- Reduce collision risk
- May be harder to parse with standard tools

### CSV Escaping Rules

Proper CSV formatting requires careful escaping:

1. **Quoted fields:** If a field contains a comma, newline, or quote, wrap it in quotes
2. **Escaped quotes:** Double any quote marks inside quoted fields: `"He said ""Hi"""`
3. **Newlines:** Can be preserved inside quoted fields
4. **Leading/trailing spaces:** May need quoting depending on implementation

Our simple implementation handles basic cases. For production CSV writing, consider using a dedicated library.

### Line Endings

Different platforms use different line endings:

**Unix/Linux/macOS (LF):** `\n`
- Single character
- Modern standard
- Used by most modern tools

**Windows (CRLF):** `\r\n`
- Two characters
- Required by some Windows applications
- Notepad, older Windows tools

**Old Mac (CR):** `\r`
- Single character
- Rarely seen today
- Pre-OS X Macintosh systems

**Best practices:**
- Default to LF (`\n`) for cross-platform compatibility
- Use CRLF only when targeting Windows-specific tools
- Be consistent within a file
- Modern editors handle any line ending

### Performance Considerations

**Buffered writes are crucial:** The examples use buffered writers which batch multiple small writes into larger syscalls. This is much faster than writing one character at a time.

**Separator choice affects performance:**
- Single-character separators (`\t`, `,`) are fastest
- Multi-character separators require more write calls
- Complex escaping (CSV) adds overhead

**For maximum throughput:**
```zig
// Use larger buffer for bulk data
var write_buf: [16384]u8 = undefined;  // 16KB buffer
var file_writer = file.writer(&write_buf);
const writer = &file_writer.interface;

// Batch many writes before flushing
for (many_rows) |row| {
    // ... write row ...
}
try writer.flush();  // Single flush at end
```

### Cross-Platform Considerations

When writing files that will be used on different platforms:

1. **Document your format:** Specify line endings and encoding in comments/docs
2. **Be consistent:** Don't mix line endings within a file
3. **Test on target platforms:** Windows text mode can auto-convert `\n` to `\r\n`
4. **Consider binary mode:** For precise control, use binary mode and explicit line endings

### Comparison with Other Languages

**Python:**
```python
# Custom separator
print(*values, sep="|", file=f)

# Custom line ending
print("line", end="\r\n", file=f)

# CSV module
import csv
writer = csv.writer(f, delimiter='\t')
writer.writerow(row)
```

**Zig's approach** requires more explicit code but gives you complete control over formatting, buffering, and error handling with no hidden behavior.

## See Also

- `code/02-core/05-files-io/recipe_5_3.zig` - Full implementations and tests
- Recipe 5.2: Printing to a file
- Recipe 5.1: Reading and writing text data
- Recipe 6.1: Reading and writing CSV data
