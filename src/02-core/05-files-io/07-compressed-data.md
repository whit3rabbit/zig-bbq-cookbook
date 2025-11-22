## Problem

You need to read and decompress files compressed with gzip or zlib.

## Solution

### Decompress Gzip

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_7.zig:decompress_gzip}}
```

## Discussion

### Decompression Formats

Zig's standard library supports decompressing three formats via `std.compress.flate.Container`:

- `.gzip` - Standard gzip format (most common)
- `.zlib` - Zlib format (used in PNG, some protocols)
- `.raw` - Raw DEFLATE data (no headers or checksums)

All three formats use the same DEFLATE algorithm but differ in headers and checksums.

### Buffer Requirements

The `Decompress.init()` function requires a buffer for the sliding window:

```zig
var decompress_buffer: [std.compress.flate.max_window_len]u8 = undefined;
```

The constant `max_window_len` is 65536 bytes (64 KB), which is the maximum DEFLATE window size. You can also pass an empty slice to use direct mode (no windowing), but this is slower:

```zig
// Direct mode (slower, no extra buffer needed)
var decompressor = std.compress.flate.Decompress.init(
    &file_reader.interface,
    .gzip,
    &.{} // empty slice = direct mode
);
```

### Streaming Decompression

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_7.zig:stream_decompress}}
```

### Error Handling

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_7.zig:error_handling}}
```

Common error types:
- `error.BadGzipHeader` / `error.BadZlibHeader` - Invalid file format
- `error.WrongGzipChecksum` / `error.WrongZlibChecksum` - Data corruption
- `error.EndOfStream` - Truncated file
- `error.InvalidCode` - Malformed compressed data

### Memory Management

Always free decompressed data:

```zig
test "proper cleanup" {
    const allocator = std.testing.allocator;

    const data = try readGzipFile("test.gz", allocator);
    defer allocator.free(data); // Always free!

    // Use data...
}
```

For large files, consider streaming to avoid memory issues:

```zig
// Bad: Loads entire file into memory
const data = try readGzipFile("huge.gz", allocator);

// Good: Streams to output file
try streamDecompressFile("huge.gz", "huge.txt");
```

### Platform Compatibility

Zig's decompression is pure Zig and works on all platforms:
- No external dependencies
- Same behavior on all platforms
- Compatible with standard gzip/zlib tools

Verify compatibility:
```bash
# Compress with system gzip
gzip -c input.txt > input.gz

# Decompress with Zig
zig run decompress.zig -- input.gz output.txt

# Verify
diff input.txt output.txt
```

### Performance Considerations

**Buffer Sizes:**
- Larger reader buffers (8-16 KB) improve performance
- The decompress buffer must be exactly `max_window_len`

**Memory vs Speed:**
- Use streaming for large files (saves memory)
- Use `readAlloc` for small files (faster, simpler)

**Direct vs Buffered Mode:**
```zig
// Buffered mode (faster)
var buffer: [std.compress.flate.max_window_len]u8 = undefined;
var dec = Decompress.init(&reader, .gzip, &buffer);

// Direct mode (slower, less memory)
var dec = Decompress.init(&reader, .gzip, &.{});
```

### Note on Compression

As of Zig 0.15.2, the compression side of `std.compress.flate` is not yet fully implemented. For creating gzip/zlib files, you'll need to:

1. Use external tools (`gzip`, `zlib`)
2. Wait for Zig stdlib completion
3. Use a third-party Zig compression library

Decompression (reading) works perfectly and is production-ready.

### Related Functions

- `std.compress.flate.Decompress.init()` - Initialize decompressor
- `std.compress.flate.Container` - Format types (.gzip, .zlib, .raw)
- `std.compress.flate.max_window_len` - Required buffer size constant
- `std.Io.Reader.readAlloc()` - Read all decompressed data
- `std.Io.Reader.readSliceShort()` - Read chunk of decompressed data
