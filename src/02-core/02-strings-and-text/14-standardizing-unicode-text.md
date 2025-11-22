## Problem

You need to compare or process Unicode strings that look identical but have different byte representations. For example, the character "é" can be represented as:
- A single pre-composed character (U+00E9)
- A letter 'e' followed by a combining acute accent (U+0065 + U+0301)

These look identical but have completely different bytes, causing string comparisons to fail. Additionally, Zig's `std.ascii` functions only handle ASCII case conversions and don't understand complex Unicode rules like the German "ß" becoming "SS" in uppercase.

**Important Note:** This recipe focuses on teaching C interoperability patterns. For production Zig code, consider pure-Zig alternatives like the **Ziglyph** library, which provides Unicode normalization without C dependencies or version-specific quirks.

## Solution

For robust Unicode standardization, interface with the ICU (International Components for Unicode) C library. This requires linking the library in `build.zig` and creating safe Zig wrappers around its C functions.

### ICU Setup and C Interop

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_14.zig:icu_setup}}
```

### Unicode Normalization

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_14.zig:unicode_normalization}}
```

### Case Folding

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_14.zig:case_folding}}
```

## Discussion

### Educational Focus: Why This Recipe Uses ICU

This recipe uses ICU specifically to teach C interoperability fundamentals:

- How to use @cImport correctly
- Memory management across FFI boundaries
- Converting between C and Zig types (UTF-8 ↔ UTF-16)
- Error handling with C libraries
- Linking system libraries in build.zig

**For actual Unicode work in Zig, use the Ziglyph library.** ICU is the industry standard for C/C++ (used by Chrome, Firefox, Node.js), but brings unnecessary complexity to Zig projects.

### ICU Capabilities

ICU provides:

- Correct implementations of all Unicode standards
- Support for all normalization forms (NFC, NFD, NFKC, NFKD)
- Proper case-folding (more complex than simple lowercasing)
- Regular updates for new Unicode versions
- Grapheme cluster handling for proper "character" counting

### What is Unicode Normalization?

Unicode allows the same visual character to be represented multiple ways. Normalization converts text to a standard form so byte comparisons work correctly.

**Example - The letter é:**

```zig
// Two ways to write the same character
const composed = "café";     // é is U+00E9 (1 codepoint)
const decomposed = "cafe\u{0301}"; // é is e + ́ (2 codepoints)

// These look identical but have different bytes
std.debug.print("Same? {}\n", .{std.mem.eql(u8, composed, decomposed)});
// Output: Same? false

// After normalization, they become identical
const norm1 = try normalizeNFC(allocator, composed);
defer allocator.free(norm1);

const norm2 = try normalizeNFC(allocator, decomposed);
defer allocator.free(norm2);

std.debug.print("Same? {}\n", .{std.mem.eql(u8, norm1, norm2)});
// Output: Same? true
```

### Normalization Forms

**NFC (Normalization Form C - Canonical Composition)**

Combines base characters and combining marks into single pre-composed characters where possible. This is the most common form for:
- Web content
- Database storage
- File names on macOS
- Most user-facing text

```zig
const text = "e\u{0301}";  // e + combining acute
const nfc = try normalizeNFC(allocator, text);
defer allocator.free(nfc);
// Result: "é" (single codepoint U+00E9)
```

**NFD (Normalization Form D - Canonical Decomposition)**

Decomposes pre-composed characters into base letter + combining marks. Useful for:
- Text processing where you need to strip accents
- Linguistic analysis
- Some legacy systems

```zig
const text = "é";  // Composed é (U+00E9)
const nfd = try normalizeNFD(allocator, text);
defer allocator.free(nfd);
// Result: "e\u{0301}" (e + combining acute)
```

**NFKC and NFKD (Compatibility Forms)**

These also normalize "compatibility equivalents" like:
- Ligatures: ﬁ → fi
- Fractions: ½ → 1/2
- Width variants: Ａ → A (fullwidth to regular)
- Super/subscripts: ² → 2

Use these when you want maximum normalization, but be aware they're lossy (you can't get the original form back).

### Case Folding vs Lowercasing

Simple lowercasing with `std.ascii.toLower` is insufficient for Unicode. Case folding is the proper way to prepare strings for case-insensitive comparison.

**Why case folding matters:**

```zig
// German sharp s (ß) has no uppercase/lowercase distinction
const german = "Straße";

// std.ascii.toLower doesn't touch ß
const ascii_lower = try std.ascii.allocLowerString(allocator, german);
defer allocator.free(ascii_lower);
std.debug.print("{s}\n", .{ascii_lower});
// Output: "straße" (ß unchanged)

// ICU case folding correctly converts ß to ss
const folded = try caseFold(allocator, german);
defer allocator.free(folded);
std.debug.print("{s}\n", .{folded});
// Output: "strasse" (ß became ss)
```

**Other case folding examples:**

- Turkish: "I" → "ı" (dotless i)
- Greek: "Σ" → "σ" or "ς" depending on position
- Cherokee: "Ꭰ" → "ꭰ"

### Implementing ICU Integration

Here's how to interface with ICU from Zig:

**Step 1: Import ICU headers**

```zig
const icu = @cImport({
    @cInclude("unicode/unorm2.h"); // Normalization
    @cInclude("unicode/ustring.h"); // String operations
});
```

**Important:** Only use one `@cImport` block per application to avoid symbol collisions. If you have multiple C libraries, import them all in one block or in a dedicated `c.zig` file.

**Step 2: Handle UTF-16 conversion**

ICU uses UTF-16 internally, but Zig strings are UTF-8. You need conversion functions:

```zig
fn utf8ToUtf16(allocator: Allocator, utf8: []const u8) ![]u16 {
    // Calculate required length
    var utf16_len: usize = 0;
    var i: usize = 0;
    while (i < utf8.len) {
        const cp_len = try std.unicode.utf8ByteSequenceLength(utf8[i]);
        const codepoint = try std.unicode.utf8Decode(utf8[i .. i + cp_len]);

        if (codepoint >= 0x10000) {
            utf16_len += 2;  // Surrogate pair
        } else {
            utf16_len += 1;
        }
        i += cp_len;
    }

    // Allocate and encode...
    // (See code/02-core/02-strings-and-text/recipe_2_14.zig for full implementation)
}
```

**Step 3: Call ICU with proper error handling**

ICU uses a two-call pattern: first call with null buffer to get size, second call to perform operation.

```zig
pub fn normalizeNFC(allocator: Allocator, text: []const u8) ![]u8 {
    // Convert to UTF-16
    const utf16_input = try utf8ToUtf16(allocator, text);
    defer allocator.free(utf16_input);

    // Get normalizer instance
    var status: icu.UErrorCode = icu.U_ZERO_ERROR;
    const normalizer = icu.unorm2_getNFCInstance(&status);
    if (status != icu.U_ZERO_ERROR) {
        return error.InitFailed;
    }

    // First call: get required buffer size
    status = icu.U_ZERO_ERROR;
    const required_len = icu.unorm2_normalize(
        normalizer,
        utf16_input.ptr,
        @intCast(utf16_input.len),
        null,  // NULL pointer to get size
        0,
        &status,
    );

    // U_BUFFER_OVERFLOW_ERROR is expected when probing size
    if (status != icu.U_BUFFER_OVERFLOW_ERROR and status != icu.U_ZERO_ERROR) {
        return error.NormalizationFailed;
    }

    // Allocate output buffer
    const utf16_output = try allocator.alloc(u16, @intCast(required_len));
    defer allocator.free(utf16_output);

    // Second call: perform normalization
    status = icu.U_ZERO_ERROR;
    const actual_len = icu.unorm2_normalize(
        normalizer,
        utf16_input.ptr,
        @intCast(utf16_input.len),
        utf16_output.ptr,
        @intCast(utf16_output.len),
        &status,
    );

    if (status != icu.U_ZERO_ERROR) {
        return error.NormalizationFailed;
    }

    // Convert back to UTF-8
    return utf16ToUtf8(allocator, utf16_output[0..@intCast(actual_len)]);
}
```

### Memory Management

ICU integration requires careful memory management across the FFI boundary:

**Multiple allocations per operation:**

```zig
pub fn normalizeNFC(allocator: Allocator, text: []const u8) ![]u8 {
    // Allocation 1: UTF-8 → UTF-16
    const utf16_input = try utf8ToUtf16(allocator, text);
    defer allocator.free(utf16_input);  // Always freed

    // Allocation 2: ICU output buffer
    const utf16_output = try allocator.alloc(u16, required_len);
    defer allocator.free(utf16_output);  // Always freed

    // Allocation 3: UTF-16 → UTF-8 (returned to caller)
    return utf16ToUtf8(allocator, utf16_output[0..actual_len]);
}
```

**Key patterns:**

- Use `defer` for intermediate buffers that are always freed
- Use `errdefer` for buffers that should only be freed on error
- Pass allocator as first parameter (Zig convention)
- Use `testing.allocator` in tests to automatically detect leaks

**Memory safety:**

```zig
test "memory safety - no leaks" {
    const text = "café";

    // testing.allocator will detect any leaks
    const nfc = try normalizeNFC(testing.allocator, text);
    defer testing.allocator.free(nfc);

    const nfd = try normalizeNFD(testing.allocator, text);
    defer testing.allocator.free(nfd);

    // If we forgot a defer, test would fail with leak error
}
```

### Error Handling

ICU uses `UErrorCode` enum for error reporting. Convert these to Zig errors:

```zig
const ICUError = error{
    InitFailed,
    NormalizationFailed,
    CaseFoldFailed,
    InvalidUtf8,
};

// Check ICU status and convert to Zig error
var status: icu.UErrorCode = icu.U_ZERO_ERROR;
const normalizer = icu.unorm2_getNFCInstance(&status);
if (status != icu.U_ZERO_ERROR) {
    return ICUError.InitFailed;
}
```

**Expected vs unexpected errors:**

```zig
// U_BUFFER_OVERFLOW_ERROR is EXPECTED when probing size
if (status != icu.U_BUFFER_OVERFLOW_ERROR and status != icu.U_ZERO_ERROR) {
    return error.SizeProbeFailed;
}

// U_ZERO_ERROR means success
if (status != icu.U_ZERO_ERROR) {
    return error.NormalizationFailed;
}
```

### Linking ICU in build.zig

To use ICU, update your `build.zig` to link the libraries:

```zig
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run tests");

    // Add test for ICU recipe
    const icu_test = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("code/02-core/02-strings-and-text/recipe_2_14.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Link C standard library (required for @cImport)
    icu_test.linkLibC();

    // Link ICU libraries
    icu_test.linkSystemLibrary("icuuc");   // ICU Common
    icu_test.linkSystemLibrary("icui18n"); // ICU Internationalization

    const run_icu_test = b.addRunArtifact(icu_test);
    test_step.dependOn(&run_icu_test.step);
}
```

### Installing ICU

**Version Requirement:** This recipe requires ICU 77 or later. The code uses versioned function names (e.g., `_77` suffix) to work around Zig @cImport limitations with ICU's macro system. If you have a different ICU version, you'll need to adjust the suffix in the code.

ICU must be installed on your system before building. The build system automatically detects ICU and only runs tests if the library is found.

**macOS:**

```bash
# Install ICU via Homebrew
brew install icu4c

# Verify installation
ls /opt/homebrew/opt/icu4c/lib/  # Apple Silicon
# or
ls /usr/local/opt/icu4c/lib/      # Intel Mac
```

The build.zig automatically detects ICU in Homebrew's keg-only location (both Apple Silicon and Intel paths). No additional environment variables needed.

**Troubleshooting:**

If the ICU tests are skipped with "ICU library not found" warning:

```bash
# macOS - Check if ICU is installed
brew list icu4c

# If not installed
brew install icu4c

# Verify the library files exist
ls -la /opt/homebrew/opt/icu4c/lib/libicu*

# Linux - Check if ICU is installed
ldconfig -p | grep libicu

# Ubuntu/Debian - Install if missing
sudo apt-get install libicu-dev

# Arch - Install if missing
sudo pacman -S icu
```

The build system automatically detects ICU on your platform and only runs the tests if the library is available. This prevents build failures on systems where ICU is not installed.

**Ubuntu/Debian:**

```bash
sudo apt-get install libicu-dev

# Verify installation
ldconfig -p | grep libicu
# or
ls /usr/lib/x86_64-linux-gnu/libicuuc.so
```

The build.zig automatically detects ICU in standard Linux system library paths.

**Arch Linux:**

```bash
sudo pacman -S icu

# Verify installation
pacman -Ql icu | grep lib
# or
ls /usr/lib/libicuuc.so
```

The build.zig automatically detects ICU in `/usr/lib`.

**Windows:**

More complex - either build from source or use vcpkg:

```bash
vcpkg install icu

# Then add to PATH or configure build.zig with custom library paths
```

### When to Use ICU vs Native Zig

**Use ICU when:**

- You're learning C interoperability (this recipe's purpose!)
- You need Unicode normalization and already have ICU installed
- You need collation (sorting in different languages)
- You're interfacing with existing C/C++ codebases that use ICU

**Use Zig std.unicode when:**

- You only need UTF-8 validation
- You only need codepoint iteration
- You want to avoid C dependencies
- You're building for constrained environments

**Recommended for Production: Ziglyph**

The **Ziglyph** library provides pure-Zig Unicode normalization without C dependencies or version-specific issues. **Use Ziglyph for production Zig code** because:

- ✓ No C library dependency
- ✓ No version suffix complications
- ✓ Easier cross-compilation
- ✓ Pure Zig - follows Zig idioms
- ✓ Works on all platforms Zig supports

**This recipe uses ICU specifically to teach C interop patterns**, not because it's the best choice for Unicode in Zig. The manual UTF-8↔UTF-16 conversion, error handling, and memory management techniques shown here apply to interfacing with many C libraries.

### Practical Examples

**Normalizing user input before database storage:**

```zig
fn saveUsername(db: *Database, raw_name: []const u8) !void {
    // Normalize to NFC for consistent storage
    const normalized = try normalizeNFC(allocator, raw_name);
    defer allocator.free(normalized);

    // Also case-fold for case-insensitive lookup
    const lookup_key = try caseFold(allocator, normalized);
    defer allocator.free(lookup_key);

    try db.insert(normalized, lookup_key);
}
```

**Case-insensitive string comparison:**

```zig
fn equalsCaseInsensitive(a: []const u8, b: []const u8) !bool {
    const a_folded = try caseFold(allocator, a);
    defer allocator.free(a_folded);

    const b_folded = try caseFold(allocator, b);
    defer allocator.free(b_folded);

    return std.mem.eql(u8, a_folded, b_folded);
}
```

**Stripping accents (using NFD):**

```zig
fn stripAccents(allocator: Allocator, text: []const u8) ![]u8 {
    // Decompose to separate base letters from combining marks
    const decomposed = try normalizeNFD(allocator, text);
    defer allocator.free(decomposed);

    // Filter out combining marks (U+0300 - U+036F range)
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    var i: usize = 0;
    while (i < decomposed.len) {
        const cp_len = try std.unicode.utf8ByteSequenceLength(decomposed[i]);
        const codepoint = try std.unicode.utf8Decode(decomposed[i .. i + cp_len]);

        // Skip combining diacritical marks
        if (codepoint < 0x0300 or codepoint > 0x036F) {
            try result.appendSlice(decomposed[i .. i + cp_len]);
        }

        i += cp_len;
    }

    return result.toOwnedSlice();
}

// Usage
const with_accents = "café résumé";
const without = try stripAccents(allocator, with_accents);
defer allocator.free(without);
// Result: "cafe resume"
```

### Performance Considerations

**UTF-8 ↔ UTF-16 conversion has overhead:**

- Each operation requires 2 conversions plus ICU processing
- For ASCII-only text, stick with `std.ascii` functions
- For repeated operations on the same text, normalize once and cache

**Normalization is O(n) but with a large constant:**

```zig
// Bad: Normalize repeatedly in a loop
for (strings) |str| {
    const norm = try normalizeNFC(allocator, str);
    defer allocator.free(norm);
    // Process norm...
}

// Good: Normalize once upfront
var normalized_strings = std.ArrayList([]u8).init(allocator);
defer {
    for (normalized_strings.items) |s| allocator.free(s);
    normalized_strings.deinit();
}

for (strings) |str| {
    try normalized_strings.append(try normalizeNFC(allocator, str));
}

// Now process normalized_strings multiple times without re-normalizing
```

### Security Considerations

**Always validate UTF-8 from untrusted sources:**

```zig
fn processUserInput(allocator: Allocator, input: []const u8) ![]u8 {
    // Validate UTF-8 first
    if (!std.unicode.utf8ValidateSlice(input)) {
        return error.InvalidUtf8;
    }

    // Now safe to normalize
    return normalizeNFC(allocator, input);
}
```

**Normalization can change string length:**

```zig
// A single character might decompose to multiple
const composed = "é";  // 2 bytes (UTF-8 encoded U+00E9)
const decomposed = try normalizeNFD(allocator, composed);
defer allocator.free(decomposed);
// Result: 3 bytes (e + combining acute in UTF-8)
```

**Be aware of homograph attacks:**

Normalization alone doesn't prevent look-alike characters (like Latin 'a' vs Cyrillic 'а'). For security-sensitive applications like domain names, additional confusable detection is needed.

### Testing Your Normalization

```zig
test "normalization equivalence" {
    const forms = [_][]const u8{
        "café",           // Mixed ASCII and accented
        "cafe\u{0301}",  // Decomposed accent
    };

    // All forms should normalize to same result
    const first_norm = try normalizeNFC(testing.allocator, forms[0]);
    defer testing.allocator.free(first_norm);

    for (forms[1..]) |form| {
        const norm = try normalizeNFC(testing.allocator, form);
        defer testing.allocator.free(norm);

        try testing.expectEqualStrings(first_norm, norm);
    }
}
```

This recipe demonstrates how to integrate C libraries safely in Zig while solving real-world Unicode text processing problems. The patterns shown here (memory management, error handling, FFI boundaries) apply to interfacing with any C library.

### Known Limitations

**ICU Version Dependency:** This code is tied to ICU 77 due to Zig's @cImport limitations with ICU's macro system. The `_77` suffix in function names is a workaround for circular dependency errors. Different ICU versions require changing these suffixes, which is why production code should avoid this approach.

**Better Alternatives for Production:**
- **Ziglyph**: Pure-Zig Unicode library (recommended)
- **zig-icu**: Community Zig bindings that handle versioning better
- **std.unicode**: Built-in Zig for basic UTF-8 operations

This recipe's value is in teaching FFI patterns, not in being production-ready Unicode normalization.
