# Recipe 19.5: Custom Allocators for Freestanding Targets

## Problem

Freestanding WebAssembly targets don't have a system allocator. You need to implement custom memory allocation strategies for dynamic memory management.

## Solution

Implement allocators that work within WebAssembly's linear memory constraints.

### Bump Allocator (Fast, No Individual Frees)

Simple allocator that never frees individual allocations:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_5.zig:bump_allocator}}
```

Set up a global instance:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_5.zig:global_allocator}}
```

Use it for allocations:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_5.zig:using_allocator}}
```

### Arena Allocator (Bulk Freeing)

Group allocations for efficient bulk freeing:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_5.zig:arena_allocator}}
```

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_5.zig:using_arena}}
```

### Fixed Buffer Allocator (Stack-Like)

Local stack-allocated buffer for temporary work:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_5.zig:fixed_buffer_allocator}}
```

### Pool Allocator (Fixed-Size Objects)

Efficient allocation for same-sized objects:

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_5.zig:pool_allocator}}
```

```zig
{{#include ../../../code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_5.zig:using_pool}}
```

## Discussion

### Why Custom Allocators?

Freestanding WASM has no malloc/free. You must provide memory management. The standard library's allocators won't work without OS support.

### Bump Allocator Characteristics

**Pros:**
- Extremely fast: O(1) allocation
- Simple implementation
- No fragmentation
- Predictable memory usage

**Cons:**
- Cannot free individual allocations
- Must reset all at once
- Memory grows until reset

**Best for:**
- Request/response cycles (allocate, process, reset)
- Temporary computations
- Single-pass algorithms

### Arena Allocator Characteristics

**Pros:**
- Fast allocation
- Bulk freeing
- Can wrap any backing allocator
- Good for hierarchical lifetimes

**Cons:**
- Cannot free individual items
- Memory grows until reset
- Requires backing allocator

**Best for:**
- Processing requests (allocate many, free all at end)
- Tree/graph construction then disposal
- Grouped temporary data

Example pattern:

```javascript
// JavaScript calls WASM for each request
for (const request of requests) {
    wasm.processRequest(request);
    wasm.resetArena(); // Free all allocations
}
```

### Pool Allocator Characteristics

**Pros:**
- O(1) allocation and deallocation
- No fragmentation
- Perfect for fixed-size objects
- Can free individual items

**Cons:**
- Fixed capacity
- Wasted space if object sizes vary
- Requires knowing max object count

**Best for:**
- Particle systems
- Object pools (network packets, DOM nodes)
- Fixed-size data structures

### Choosing an Allocator

| Allocator | Free Individual? | Reset All? | Best Use Case |
|-----------|------------------|------------|---------------|
| Bump | No | Yes | Single pass, request/response |
| Arena | No | Yes | Hierarchical lifetimes |
| Pool | Yes | Yes | Fixed-size objects |
| FixedBuffer | Yes | N/A | Local temporary buffers |

### Memory Layout in WASM

WASM linear memory starts at address 0. Typical layout:

```
0x0000   - Stack (grows down)
...
0x????   - Global variables
0x????   - __heap_base (start of dynamic memory)
...      - Your allocators work here
0xFFFF   - End of initial memory (can grow)
```

The compiler sets `__heap_base` to mark where dynamic allocation can begin.

### Implementing Custom VTable

The allocator interface requires four functions:

```zig
pub const VTable = struct {
    alloc: fn(*anyopaque, usize, Alignment, usize) ?[*]u8,
    resize: fn(*anyopaque, []u8, Alignment, usize, usize) bool,
    free: fn(*anyopaque, []u8, Alignment, usize) void,
    remap: fn(*anyopaque, []u8, Alignment, usize, usize) ?[*]u8,
};
```

- `alloc`: Allocate new memory
- `resize`: Try to resize in place
- `free`: Deallocate memory
- `remap`: Reallocate (move if needed)

Simple allocators can return failure for resize/remap.

### Growing WASM Memory

WASM memory can grow at runtime:

```zig
// Not in freestanding, but in WASI or with custom imports
extern "env" fn __wasm_memory_grow(pages: i32) i32;

export fn growMemory(pages: i32) bool {
    const result = __wasm_memory_grow(pages);
    return result != -1; // -1 means failure
}
```

Pages are 64KB each. Most allocators work within initial memory.

### Combining Allocators

Layer allocators for different use cases:

```zig
// Large backing buffer with bump allocator
var backing: [1024 * 1024]u8 = undefined; // 1MB
var bump = BumpAllocator.init(&backing);

// Arena for request processing
var arena = std.heap.ArenaAllocator.init(bump.allocator());

// Use arena for request
const data = try arena.allocator().alloc(u8, size);
// ... process ...
_ = arena.reset(.free_all);
```

### Error Handling

Allocations can fail. Handle errors properly:

```zig
export fn allocateArray(size: usize) i32 {
    const allocator = global_allocator.allocator();
    const array = allocator.alloc(i32, size) catch {
        return -1; // Signal error to JavaScript
    };
    return @intCast(@intFromPtr(array.ptr));
}
```

From JavaScript:

```javascript
const ptr = wasm.allocateArray(1000);
if (ptr === -1) {
    console.error('Allocation failed');
}
```

### Thread Safety

These allocators are not thread-safe. For multi-threaded WASM:

1. Use separate allocators per thread
2. Add mutex protection
3. Use atomic operations

Example with mutex:

```zig
const Mutex = std.Thread.Mutex;

var allocator_mutex = Mutex{};
var global_alloc = BumpAllocator.init(&heap);

export fn threadSafeAlloc(size: usize) ?[*]u8 {
    allocator_mutex.lock();
    defer allocator_mutex.unlock();

    return global_alloc.allocator().alloc(u8, size) catch null;
}
```

### Debugging Allocations

Track allocation stats:

```zig
const TrackedAllocator = struct {
    backing: BumpAllocator,
    alloc_count: usize = 0,
    bytes_allocated: usize = 0,

    pub fn allocator(self: *TrackedAllocator) std.mem.Allocator {
        // Wrap backing allocator, increment counters
    }
};
```

Export stats for JavaScript to monitor:

```zig
export fn getAllocStats() usize {
    return tracked_alloc.bytes_allocated;
}
```

## See Also

- Recipe 19.1: Building a basic WebAssembly module
- Recipe 19.4: Passing strings and data between Zig and JavaScript
- Recipe 19.6: Implementing a panic handler for WASM
- Recipe 0.12: Understanding Allocators (fundamentals)

Full compilable example: `code/05-zig-paradigms/19-webassembly-freestanding/recipe_19_5.zig`
