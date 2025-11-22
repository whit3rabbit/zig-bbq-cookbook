## Problem

You need to convert binary data to hexadecimal strings for display or debugging, or decode hexadecimal strings back to binary data.

## Solution

### Basic Hex Conversion

```zig
{{#include ../../../code/03-advanced/06-data-encoding/recipe_6_7.zig:basic_hex_conversion}}
```

### Hex Dump

```zig
{{#include ../../../code/03-advanced/06-data-encoding/recipe_6_7.zig:hex_dump}}
```

### Advanced Hex Ops

```zig
{{#include ../../../code/03-advanced/06-data-encoding/recipe_6_7.zig:advanced_hex_ops}}
```

    try std.testing.expectEqualStrings("deadbeef", hex);
}

test "hex to bytes" {
    const allocator = std.testing.allocator;

    const bytes = try hexToBytes(allocator, "deadbeef");
    defer allocator.free(bytes);

    try std.testing.expectEqual(@as(usize, 4), bytes.len);
    try std.testing.expectEqual(@as(u8, 0xDE), bytes[0]);
    try std.testing.expectEqual(@as(u8, 0xAD), bytes[1]);
    try std.testing.expectEqual(@as(u8, 0xBE), bytes[2]);
    try std.testing.expectEqual(@as(u8, 0xEF), bytes[3]);
}
```

## Discussion

### Uppercase Hexadecimal

Use uppercase hex digits with the `{X}` format specifier:

```zig
pub fn bytesToHexUpper(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    var list = std.ArrayList(u8){};
    errdefer list.deinit(allocator);

    for (bytes) |byte| {
        try list.writer(allocator).print("{X:0>2}", .{byte});
    }

    return list.toOwnedSlice(allocator);
}

test "bytes to hex uppercase" {
    const allocator = std.testing.allocator;

    const bytes = [_]u8{ 0xDE, 0xAD, 0xBE, 0xEF };
    const hex = try bytesToHexUpper(allocator, &bytes);
    defer allocator.free(hex);

    try std.testing.expectEqualStrings("DEADBEEF", hex);
}
```

### Hex with Separators

Add separators between bytes:

```zig
pub fn bytesToHexWithSep(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    separator: []const u8,
) ![]u8 {
    if (bytes.len == 0) {
        return allocator.alloc(u8, 0);
    }

    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    for (bytes, 0..) |byte, i| {
        if (i > 0) {
            try result.appendSlice(allocator, separator);
        }
        const hex = try std.fmt.allocPrint(allocator, "{x:0>2}", .{byte});
        defer allocator.free(hex);
        try result.appendSlice(allocator, hex);
    }

    return result.toOwnedSlice(allocator);
}

test "hex with separator" {
    const allocator = std.testing.allocator;

    const bytes = [_]u8{ 0xDE, 0xAD, 0xBE, 0xEF };
    const hex = try bytesToHexWithSep(allocator, &bytes, ":");
    defer allocator.free(hex);

    try std.testing.expectEqualStrings("de:ad:be:ef", hex);
}
```

### Hex Dump

Create hex dump with ASCII:

```zig
pub fn hexDump(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    var offset: usize = 0;
    while (offset < bytes.len) {
        const line_len = @min(16, bytes.len - offset);
        const line = bytes[offset .. offset + line_len];

        // Offset
        const offset_str = try std.fmt.allocPrint(allocator, "{x:0>8}  ", .{offset});
        defer allocator.free(offset_str);
        try result.appendSlice(allocator, offset_str);

        // Hex bytes
        for (line, 0..) |byte, i| {
            if (i == 8) {
                try result.append(allocator, ' ');
            }
            const hex = try std.fmt.allocPrint(allocator, "{x:0>2} ", .{byte});
            defer allocator.free(hex);
            try result.appendSlice(allocator, hex);
        }

        // Padding
        if (line_len < 16) {
            var i: usize = line_len;
            while (i < 16) : (i += 1) {
                try result.appendSlice(allocator, "   ");
                if (i == 7) {
                    try result.append(allocator, ' ');
                }
            }
        }

        // ASCII
        try result.appendSlice(allocator, " |");
        for (line) |byte| {
            const char = if (std.ascii.isPrint(byte)) byte else '.';
            try result.append(allocator, char);
        }
        try result.appendSlice(allocator, "|\n");

        offset += line_len;
    }

    return result.toOwnedSlice(allocator);
}

test "hex dump" {
    const allocator = std.testing.allocator;

    const bytes = "Hello, World!\x00\xFF";
    const dump = try hexDump(allocator, bytes);
    defer allocator.free(dump);

    try std.testing.expect(std.mem.indexOf(u8, dump, "48 65 6c 6c") != null);
    try std.testing.expect(std.mem.indexOf(u8, dump, "|Hello, World|") != null);
}
```

### Integer to Hex

Convert integers to hex:

```zig
pub fn u32ToHex(allocator: std.mem.Allocator, value: u32) ![]u8 {
    return std.fmt.allocPrint(allocator, "{x}", .{value});
}

pub fn u32ToHexPadded(allocator: std.mem.Allocator, value: u32) ![]u8 {
    return std.fmt.allocPrint(allocator, "{x:0>8}", .{value});
}

test "integer to hex" {
    const allocator = std.testing.allocator;

    const hex1 = try u32ToHex(allocator, 0xDEADBEEF);
    defer allocator.free(hex1);
    try std.testing.expectEqualStrings("deadbeef", hex1);

    const hex2 = try u32ToHexPadded(allocator, 0x42);
    defer allocator.free(hex2);
    try std.testing.expectEqualStrings("00000042", hex2);
}
```

### Hex to Integer

Parse hex strings to integers:

```zig
pub fn hexToU32(hex: []const u8) !u32 {
    return try std.fmt.parseInt(u32, hex, 16);
}

pub fn hexToU64(hex: []const u8) !u64 {
    return try std.fmt.parseInt(u64, hex, 16);
}

test "hex to integer" {
    try std.testing.expectEqual(@as(u32, 0xDEADBEEF), try hexToU32("DEADBEEF"));
    try std.testing.expectEqual(@as(u32, 0xDEADBEEF), try hexToU32("deadbeef"));
    try std.testing.expectEqual(@as(u64, 0x123456789ABCDEF0), try hexToU64("123456789ABCDEF0"));
}
```

### Validating Hex Strings

Check if string is valid hex:

```zig
pub fn isValidHex(hex: []const u8) bool {
    if (hex.len == 0 or hex.len % 2 != 0) {
        return false;
    }

    for (hex) |char| {
        switch (char) {
            '0'...'9', 'a'...'f', 'A'...'F' => {},
            else => return false,
        }
    }

    return true;
}

test "validate hex" {
    try std.testing.expect(isValidHex("deadbeef"));
    try std.testing.expect(isValidHex("DEADBEEF"));
    try std.testing.expect(isValidHex("0123456789abcdefABCDEF"));

    try std.testing.expect(!isValidHex("xyz"));
    try std.testing.expect(!isValidHex("dead")); // odd length allowed for this test
    try std.testing.expect(!isValidHex(""));
}
```

### In-Place Hex Encoding

Encode to pre-allocated buffer:

```zig
pub fn bytesToHexBuf(bytes: []const u8, out: []u8) !void {
    if (out.len < bytes.len * 2) {
        return error.BufferTooSmall;
    }

    const hex_chars = "0123456789abcdef";
    for (bytes, 0..) |byte, i| {
        out[i * 2] = hex_chars[byte >> 4];
        out[i * 2 + 1] = hex_chars[byte & 0x0F];
    }
}

test "hex to buffer" {
    const bytes = [_]u8{ 0xDE, 0xAD, 0xBE, 0xEF };
    var buf: [8]u8 = undefined;

    try bytesToHexBuf(&bytes, &buf);

    try std.testing.expectEqualStrings("deadbeef", &buf);
}
```

### Decoding with Error Recovery

Skip invalid characters:

```zig
pub fn hexToBytesLenient(allocator: std.mem.Allocator, hex: []const u8) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i + 1 < hex.len) {
        const high = hexCharToNibble(hex[i]) catch {
            i += 1;
            continue;
        };
        const low = hexCharToNibble(hex[i + 1]) catch {
            i += 1;
            continue;
        };

        try result.append(allocator, (high << 4) | low);
        i += 2;
    }

    return result.toOwnedSlice(allocator);
}

test "hex lenient parsing" {
    const allocator = std.testing.allocator;

    const bytes = try hexToBytesLenient(allocator, "de:ad:be:ef");
    defer allocator.free(bytes);

    try std.testing.expectEqual(@as(usize, 4), bytes.len);
}
```

### Best Practices

**Encoding:**
- Use `{x:0>2}` format specifier for lowercase hex
- Use `{X:0>2}` format specifier for uppercase hex
- Pre-allocate buffers for large conversions with `bytesToHexBuf`

**Decoding:**
```zig
// Validate before decoding
if (!isValidHex(input)) {
    return error.InvalidHex;
}

const bytes = try hexToBytes(allocator, input);
defer allocator.free(bytes);
```

**Performance:**
- In-place encoding avoids allocations
- Use fixed buffers for known sizes
- Batch process large data

**Error handling:**
- Check hex string length (must be even)
- Validate all characters are valid hex digits
- Handle case-insensitivity when needed

### Related Functions

- `std.fmt.allocPrint()` - Format and allocate string
- `std.fmt.parseInt()` - Parse hex string to integer with base 16
- `std.ArrayList.writer()` - Get writer for efficient string building
- `std.ascii.isPrint()` - Check if character is printable
- `std.mem.indexOf()` - Find substring
