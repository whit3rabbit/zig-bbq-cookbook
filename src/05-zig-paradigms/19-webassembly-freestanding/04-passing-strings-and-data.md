# Recipe 19.4: Passing Strings and Data Between Zig and JavaScript

## Problem

You need to pass strings and complex data between Zig and JavaScript in WebAssembly, handling encoding, memory management, and bidirectional communication.

## Solution

Use linear memory with pointer/length pairs for passing strings, and static buffers for returning data.

### Setting Up a String Buffer

Create a buffer for returning strings to JavaScript:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_4.zig:string_buffer}}
```

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_4.zig:string_exports}}
```

### Processing Input Strings

Accept strings via pointer and length:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_4.zig:process_string}}
```

### Returning Modified Strings

Write results to the buffer for JavaScript to read:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_4.zig:uppercase_string}}
```

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_4.zig:reverse_string}}
```

### Working with Multiple Strings

Process multiple string parameters:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_4.zig:concatenate_strings}}
```

### String to Number Conversion

Parse numbers from strings:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_4.zig:parse_number}}
```

### Number to String Formatting

Format numbers as strings:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_4.zig:format_number}}
```

### JavaScript Integration

From JavaScript, use TextEncoder/TextDecoder:

```javascript
// Write string to WASM memory
function writeString(str) {
    const encoder = new TextEncoder();
    const bytes = encoder.encode(str);
    const ptr = wasm.allocateBytes(bytes.length);
    const view = new Uint8Array(wasm.memory.buffer);
    for (let i = 0; i < bytes.length; i++) {
        view[ptr + i] = bytes[i];
    }
    return { ptr, len: bytes.length };
}

// Read string from WASM buffer
function readStringFromBuffer() {
    const ptr = wasm.getStringPtr();
    const len = wasm.getStringLen();
    const bytes = new Uint8Array(wasm.memory.buffer, ptr, len);
    return new TextDecoder().decode(bytes);
}

// Usage
const { ptr, len } = writeString("hello");
wasm.uppercaseString(ptr, len);
const result = readStringFromBuffer(); // "HELLO"
```

## Discussion

### Memory Layout for Strings

Strings in WASM are just byte sequences in linear memory. The pattern is:

1. **Passing to Zig**: JavaScript writes bytes to WASM memory, passes pointer and length
2. **Returning from Zig**: Zig writes to a known buffer, JavaScript reads from that buffer

This avoids complex memory management while allowing efficient string operations.

### The Pointer-Length Pattern

Every string function takes two parameters:

```zig
fn processString(ptr: [*]const u8, len: usize) ResultType
```

This pattern:
- Works with any string encoding (UTF-8, ASCII, etc.)
- Avoids null-termination overhead
- Matches Zig's slice semantics
- Is efficient (no copying unless needed)

Convert to a slice inside the function:

```zig
const input = ptr[0..len]; // Creates slice
```

### UTF-8 Encoding

Zig strings are UTF-8 by default. JavaScript's TextEncoder/TextDecoder also use UTF-8:

```javascript
const encoder = new TextEncoder(); // UTF-8
const bytes = encoder.encode("Hello 世界"); // Works with Unicode

const decoder = new TextDecoder(); // UTF-8
const str = decoder.decode(bytes);
```

For ASCII-only operations, you can work with bytes directly. For Unicode-aware operations, use `std.unicode`:

```zig
const std = @import("std");

// Count UTF-8 codepoints (not bytes)
fn countCodepoints(ptr: [*]const u8, len: usize) usize {
    const input = ptr[0..len];
    var count: usize = 0;
    var i: usize = 0;
    while (i < input.len) {
        const cp_len = std.unicode.utf8ByteSequenceLength(input[i]) catch 1;
        count += 1;
        i += cp_len;
    }
    return count;
}
```

### Static Buffers vs Dynamic Allocation

This recipe uses static buffers:

```zig
var string_buffer: [1024]u8 = undefined;
```

Advantages:
- Simple, no allocator needed
- Fast, no allocation overhead
- Deterministic memory usage

Disadvantages:
- Fixed size limit
- Can't return multiple strings simultaneously
- Not thread-safe (for multi-threaded WASM)

For more flexibility, use a proper allocator (see Recipe 19.5).

### Alternative: Direct Memory Access

For large data or many operations, consider having JavaScript work directly in WASM memory:

```zig
export fn getWorkBuffer() [*]u8 {
    const static = struct {
        var buffer: [4096]u8 = undefined;
    };
    return &static.buffer;
}
```

JavaScript can then read/write directly:

```javascript
const bufPtr = wasm.getWorkBuffer();
const view = new Uint8Array(wasm.memory.buffer, bufPtr, 4096);

// Write directly
const encoder = new TextEncoder();
const bytes = encoder.encode("Hello");
view.set(bytes);

// Call WASM function that works in-place
wasm.processInPlace(bytes.length);

// Read result
const decoder = new TextDecoder();
const result = decoder.decode(view.slice(0, wasm.getResultLen()));
```

### Word Counting Example

Demonstrates more complex string processing:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_4.zig:word_count}}
```

This shows:
- State tracking across loop iterations
- Character classification
- No memory allocation needed

### Handling Large Strings

For strings larger than your buffer:

1. **Chunk processing**: Process in pieces
2. **Streaming**: Use callbacks to send results incrementally
3. **Dynamic allocation**: Use a proper allocator (Recipe 19.5)
4. **Compression**: Compress before passing

Example of chunked processing:

```zig
export fn processChunk(ptr: [*]const u8, len: usize, chunk_index: usize) void {
    const input = ptr[0..len];
    // Process this chunk
    // Store results keyed by chunk_index
}
```

### JSON and Structured Data

For complex data, use JSON:

```javascript
// JavaScript side
const data = { name: "Alice", age: 30 };
const json = JSON.stringify(data);
const { ptr, len } = writeString(json);
wasm.processJSON(ptr, len);
```

In Zig, parse the JSON string:

```zig
const std = @import("std");

export fn processJSON(ptr: [*]const u8, len: usize) void {
    const input = ptr[0..len];
    // Parse with std.json (needs allocator)
    // Or write custom parser for known structure
}
```

### Performance Tips

1. **Minimize crossings**: Do bulk work in Zig, pass results once
2. **Reuse buffers**: Don't allocate for each operation
3. **Use views**: Uint8Array views are cheap
4. **Batch operations**: Process arrays of strings together

Example of batching:

```javascript
// Bad: Many boundary crossings
for (const str of strings) {
    const { ptr, len } = writeString(str);
    results.push(wasm.processString(ptr, len));
}

// Better: Write all strings, process in batch
const allStrings = strings.join('\0'); // Null-separated
const { ptr, len } = writeString(allStrings);
wasm.processBatch(ptr, len, strings.length);
```

## See Also

- Recipe 19.1: Building a basic WebAssembly module
- Recipe 19.2: Exporting functions to JavaScript
- Recipe 19.3: Importing and calling JavaScript functions
- Recipe 19.5: Custom allocators for freestanding targets

Full compilable example: `code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_4.zig`
