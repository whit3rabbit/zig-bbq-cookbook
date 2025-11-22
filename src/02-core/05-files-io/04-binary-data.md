## Problem

You need to read or write binary data to a file, such as integers, floats, or packed structures, with control over byte order and data layout.

## Solution

### Binary Integers

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_4.zig:binary_integers}}
```

### Binary Structs

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_4.zig:binary_structs}}
```

### Endianness Validation

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_4.zig:endianness_validation}}
```

## Discussion

### Endianness

Endianness determines the byte order when storing multi-byte values:

**Little-endian (.little):**
- Least significant byte first
- Used by x86, x86-64, ARM (usually)
- Example: `0x12345678` stored as `78 56 34 12`

**Big-endian (.big):**
- Most significant byte first
- Network byte order (TCP/IP)
- Some RISC processors
- Example: `0x12345678` stored as `12 34 56 78`

**Best practices:**
- Always specify endianness explicitly with `writeInt()` and `readInt()`
- Use `.little` for local files on modern systems
- Use `.big` for network protocols (matches network byte order)
- Document the endianness in file format specifications
- Use `@byteSwap()` to convert between endiannesses if needed

### Binary File Structure

Well-designed binary files typically include:

1. **Magic number** - Identifies file type (e.g., `0x89504E47` for PNG)
2. **Version** - Allows format evolution
3. **Header** - Metadata about the file contents
4. **Data sections** - The actual payload
5. **Checksums** - Verify data integrity

```zig
const FileHeader = packed struct {
    magic: u32,      // File type identifier
    version: u16,    // Format version
    flags: u16,      // Feature flags
    data_size: u64,  // Payload size in bytes
};
```

### Packed vs Regular Structs

**Packed structs:**
- Guarantee no padding between fields
- Fields stored in declaration order
- Exact memory layout control
- Good for binary file formats
- May be slower to access

**Regular structs:**
- Compiler can reorder and pad fields
- Better performance
- Not suitable for binary I/O
- Use for in-memory data

For binary files, always use explicit field-by-field reading/writing or carefully designed packed structs.

### Type Punning with @bitCast

To write floats as binary data, use `@bitCast` to reinterpret the bits:

```zig
const float_value: f32 = 3.14;
const int_bits: u32 = @bitCast(float_value);
try writer.writeInt(u32, int_bits, .little);

// Reading back
const read_bits = try reader.readInt(u32, .little);
const float_back: f32 = @bitCast(read_bits);
```

This preserves the exact binary representation without conversion.

### Error Handling

Binary I/O can fail in specific ways:

- `error.EndOfStream` - Unexpected end of file
- `error.UnexpectedEndOfFile` - Read fewer bytes than expected
- `error.InvalidFormat` - Wrong magic number or version
- `error.Overflow` - Size field too large

Always validate:
- Magic numbers match expected values
- Version numbers are supported
- Size fields are reasonable
- Checksums are correct

### Performance Tips

**Buffering is crucial:**
```zig
// Good - buffered
var buf: [8192]u8 = undefined;
var buffered_reader = file.reader(&buf);
const reader = &buffered_reader.interface;

// Reading many small values is efficient
for (0..1000) |_| {
    const val = try reader.readInt(u32, .little);
}
```

**Avoid byte-by-byte reads:**
```zig
// Slow - many syscalls
for (buffer) |*byte| {
    byte.* = try reader.readByte();
}

// Fast - single read
_ = try reader.readAll(buffer);
```

**Use readAll for known-size data:**
```zig
var buffer: [1024]u8 = undefined;
const bytes_read = try reader.readAll(&buffer);
if (bytes_read != buffer.len) return error.UnexpectedEndOfFile;
```

### Memory Safety

When reading binary data:

1. **Validate sizes before allocation:**
```zig
const size = try reader.readInt(u64, .little);
if (size > 100_000_000) return error.SizeTooLarge;
const data = try allocator.alloc(u8, size);
```

2. **Use errdefer for cleanup:**
```zig
const data = try allocator.alloc(u8, size);
errdefer allocator.free(data);
// ... reading can fail ...
```

3. **Check read lengths:**
```zig
const bytes_read = try reader.readAll(data);
if (bytes_read != data.len) return error.UnexpectedEndOfFile;
```

### Comparison with Other Languages

**Python:**
```python
import struct
# Write binary
with open('data.bin', 'wb') as f:
    f.write(struct.pack('<I', 42))  # Little-endian u32

# Read binary
with open('data.bin', 'rb') as f:
    value = struct.unpack('<I', f.read(4))[0]
```

**C:**
```c
FILE *f = fopen("data.bin", "wb");
uint32_t value = 42;
fwrite(&value, sizeof(value), 1, f);
fclose(f);
```

**Zig's approach** provides explicit control over endianness, clear error handling, and compile-time size checking without the risks of C or the performance overhead of Python.

## See Also

- `code/02-core/05-files-io/recipe_5_4.zig` - Full implementations and tests
- Recipe 5.1: Reading and writing text data
- Recipe 3.5: Packing/unpacking large integers from bytes
- Recipe 6.9: Reading and writing binary arrays of structures
