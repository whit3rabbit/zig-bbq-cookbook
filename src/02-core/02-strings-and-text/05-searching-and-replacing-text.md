## Problem

You need to replace text in strings, from simple single replacements to complex multi-pattern substitutions. You want to choose the right approach based on your performance requirements.

## Solution

Zig provides several approaches for text replacement, each with different trade-offs:

### Basic Single Replacement

For replacing a single pattern, use `replaceAll` which pre-calculates the final size and performs replacement in one pass:

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_5.zig:replace_all}}
```

### Replace First Occurrence Only

When you only want to replace the first match:

```zig
const text = "hello hello world";
const result = try replaceFirst(allocator, text, "hello", "hi");
defer allocator.free(result);

std.debug.print("{s}\n", .{result}); // "hi hello world"
```

### Multiple Pattern Replacement - Choose Your Strategy

When replacing multiple patterns, you have two choices:

#### 1. Basic Method - Simple but Less Efficient

Good for 2-3 patterns or small text:

```zig
const text = "hello world";
const replacements = [_]ReplacePair{
    .{ .needle = "hello", .replacement = "hi" },
    .{ .needle = "world", .replacement = "there" },
};

const result = try replaceMany(allocator, text, &replacements);
defer allocator.free(result);
```

**Characteristics:**
- Multiple passes over the text
- Creates intermediate allocations for each pattern
- Time: O(n * m) where n = text length, m = number of patterns
- Space: O(n * m) due to intermediate copies
- Simple code, easy to understand

**Use when:**
- You have only 2-3 replacement pairs
- The text is small (less than 1KB)
- Code simplicity matters more than performance
- Replacements might interfere with each other (order matters)

#### 2. Optimized Method - Single Pass Algorithm

Good for many patterns or large text:

```zig
const text = "The quick brown fox jumps over the lazy dog";
const replacements = [_]ReplacePair{
    .{ .needle = "quick", .replacement = "fast" },
    .{ .needle = "brown", .replacement = "red" },
    .{ .needle = "fox", .replacement = "wolf" },
    .{ .needle = "jumps", .replacement = "leaps" },
    .{ .needle = "lazy", .replacement = "sleeping" },
};

const result = try replaceManyOptimized(allocator, text, &replacements);
defer allocator.free(result);
```

**Characteristics:**
- Single pass through the text
- One output buffer (ArrayList)
- Time: O(n * m) for searches but only one pass
- Space: O(n) single output allocation
- More complex code

**Use when:**
- You have many replacement pairs (4 or more)
- The text is large (greater than 1KB)
- Performance is critical
- You want to minimize memory allocations
- Replacement order doesn't matter (processes left to right)

## Real-World Examples

### HTML Entity Decoding

```zig
const html = "&lt;div&gt;Hello &amp; goodbye&lt;/div&gt;";
const entities = [_]ReplacePair{
    .{ .needle = "&lt;", .replacement = "<" },
    .{ .needle = "&gt;", .replacement = ">" },
    .{ .needle = "&amp;", .replacement = "&" },
    .{ .needle = "&quot;", .replacement = "\"" },
};

const result = try replaceManyOptimized(allocator, html, &entities);
defer allocator.free(result);
// Result: "<div>Hello & goodbye</div>"
```

### Text Normalization

```zig
const messy = "Hello...world!!!How   are  you???";
const replacements = [_]ReplacePair{
    .{ .needle = "...", .replacement = ". " },
    .{ .needle = "!!!", .replacement = "! " },
    .{ .needle = "???", .replacement = "? " },
    .{ .needle = "   ", .replacement = " " },
    .{ .needle = "  ", .replacement = " " },
};

const result = try replaceManyOptimized(allocator, messy, &replacements);
defer allocator.free(result);
// Result: "Hello. world! How are you? "
```

### Path Separator Normalization

```zig
const path = "C:\\Users\\Name\\Documents\\file.txt";
const replacements = [_]ReplacePair{
    .{ .needle = "\\", .replacement = "/" },
    .{ .needle = "C:", .replacement = "/c" },
};

const result = try replaceManyOptimized(allocator, path, &replacements);
defer allocator.free(result);
// Result: "/c/Users/Name/Documents/file.txt"
```

## Discussion

### Understanding the Trade-offs

The key difference between `replaceMany` and `replaceManyOptimized` is allocation strategy:

**replaceMany (Basic):**
1. Start with original text
2. Replace pattern 1, allocate new string
3. Replace pattern 2 in new string, allocate another new string
4. Repeat for each pattern
5. Free intermediate allocations

**replaceManyOptimized (Advanced):**
1. Create single ArrayList for output
2. Scan text for earliest occurrence of any pattern
3. Append text before match and replacement to ArrayList
4. Continue from after the match
5. One final allocation when converting ArrayList to slice

### Performance Comparison

For 8 replacements in a 72-character string:
- **Basic**: 8 allocations, 8 full text scans
- **Optimized**: 1 allocation (ArrayList grows as needed), 1 text scan

For larger texts (1KB+) with many patterns (10+), the optimized version can be 3-5x faster.

### Memory Safety

Both approaches are memory-safe when using Zig's testing allocator:

```zig
test "memory safety check" {
    const text = "test test test";
    const result = try replaceAll(testing.allocator, text, "test", "replaced");
    defer testing.allocator.free(result);
    // testing.allocator will detect any leaks
}
```

### Handling Edge Cases

Both methods handle common edge cases:
- Empty needles are ignored or return unchanged text
- No matches returns a copy of the original
- Overlapping patterns are processed left-to-right
- UTF-8 strings work correctly (byte-level replacement)

### When Order Matters

If replacement order is important (replacements depend on each other), use `replaceMany`:

```zig
// Want to replace "test" with "exam", then "exam" with "final"
const replacements = [_]ReplacePair{
    .{ .needle = "test", .replacement = "exam" },
    .{ .needle = "exam", .replacement = "final" },
};

// replaceMany: "test" -> "exam" -> "final" (sequential)
// replaceManyOptimized: "test" -> "exam" (only first occurrence)
```

## Zig-Specific Considerations

1. **Explicit Allocators**: All functions require you to pass an allocator. This gives you control over memory allocation strategy.

2. **Error Handling**: All functions return `![]u8` because allocation can fail. Use `try` or `catch` appropriately.

3. **Memory Ownership**: The caller owns the returned slice and must free it using the same allocator.

4. **No Hidden Allocations**: Unlike higher-level languages, Zig makes all allocations explicit through the allocator parameter.

5. **UTF-8 Awareness**: These are byte-level operations. For Unicode-aware replacements, you'd need to use `std.unicode` utilities.

## Performance Tips

1. **Pre-size if possible**: For `replaceAll`, we count occurrences first to pre-allocate the exact size needed.

2. **Use ArrayList for dynamic growth**: The optimized version uses ArrayList to avoid resizing calculations.

3. **Avoid repeated small replacements**: If you're calling replace in a loop, consider batching into a single call with multiple patterns.

4. **Consider std.mem.replace**: For simple cases, check if the standard library's built-in functions meet your needs first.

## Complete Example

See `code/02-core/02-strings-and-text/recipe_2_5.zig` for full compilable code including:
- All replacement strategies
- Comprehensive tests
- Performance comparisons
- Memory safety demonstrations

Run tests with:
```bash
zig test code/02-core/02-strings-and-text/recipe_2_5.zig
```
