# Recipe 18.1: Custom Allocator Implementation

## Problem

You need to implement custom memory allocation strategies for specific use cases like bump allocation, tracking allocations, or testing allocation failures. You want to understand the Allocator interface and create allocators that integrate seamlessly with Zig's allocation system.

## Solution

Zig's `std.mem.Allocator` interface allows you to create custom allocators by implementing a virtual table with four required functions: `alloc`, `resize`, `remap`, and `free`.

### Basic Bump Allocator

A simple bump allocator that allocates from a fixed buffer:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_1.zig:basic_allocator}}
```

### Counting Allocator Wrapper

Track allocations and bytes allocated by wrapping another allocator:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_1.zig:counting_allocator}}
```

### Fail Allocator for Testing

Simulate allocation failures after a certain number of allocations:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_1.zig:fail_allocator}}
```

## Discussion

Custom allocators give you precise control over memory management, enabling specialized allocation strategies for performance, testing, or resource-constrained environments.

### The Allocator Interface

In Zig 0.15.2, the `std.mem.Allocator` interface requires a VTable with four functions:

**alloc**: Allocate memory of a given size and alignment. Returns a pointer or null on failure.

**resize**: Attempt to resize an existing allocation in place. Returns true if successful, false otherwise.

**remap**: Attempt to reallocate memory to a new size, potentially moving it. Returns a new pointer or null.

**free**: Release previously allocated memory.

Each function receives:
- `ctx`: Opaque pointer to the allocator instance
- `len` or `buf`: Size information or existing buffer
- `ptr_align` or `buf_align`: Alignment as `std.mem.Alignment` type
- `ret_addr`: Return address for debugging

### Alignment Handling

Zig 0.15.2 introduced `std.mem.Alignment` as a type-safe replacement for raw `u8` values:

```zig
fn alloc(ctx: *anyopaque, len: usize, ptr_align: std.mem.Alignment, ret_addr: usize) ?[*]u8
```

Convert alignment to bytes using `.toByteUnits()`:

```zig
const align_offset = std.mem.alignForward(usize, self.offset, ptr_align.toByteUnits());
```

This ensures proper alignment for all types while preventing alignment-related bugs.

### Bump Allocator Pattern

The bump allocator is the simplest allocation strategy:

1. Maintain an offset into a fixed buffer
2. On allocation, align the offset and increment it
3. Return pointer to the aligned region
4. Never actually free memory (reset clears all at once)

This is extremely fast but only suitable for:
- Short-lived allocations that can all be freed together
- Arena-style allocation patterns
- Temporary scratch buffers

The `reset()` method allows reusing the buffer for a new batch of allocations.

### Wrapper Allocator Pattern

Wrapper allocators delegate to a parent allocator while adding functionality:

**Counting**: Track allocation statistics
**Logging**: Record all allocations for debugging
**Limiting**: Enforce memory budgets
**Testing**: Inject failures or validate usage

The wrapper pattern uses `rawAlloc`, `rawResize`, `rawRemap`, and `rawFree` to call the parent's VTable functions directly:

```zig
const result = self.parent.rawAlloc(len, ptr_align, ret_addr);
```

This avoids the overhead of going through the `Allocator` interface twice.

### Testing with FailAllocator

The fail allocator is invaluable for testing error handling:

```zig
var fail_alloc = FailAllocator.init(testing.allocator, 2);
const allocator = fail_alloc.allocator();

const slice1 = try allocator.alloc(u8, 10); // Success
const slice2 = try allocator.alloc(u8, 20); // Success
const slice3 = allocator.alloc(u8, 30);     // Returns error.OutOfMemory
```

This verifies your code correctly handles allocation failures, a critical requirement for robust Zig programs.

### The remap Function

The `remap` function is required in Zig 0.15.2's allocator interface. It attempts to reallocate memory to a new size, potentially moving it to a different location.

For simple allocators that don't support reallocation:

```zig
fn remap(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
    _ = ctx;
    _ = buf;
    _ = buf_align;
    _ = new_len;
    _ = ret_addr;
    return null;
}
```

Returning `null` indicates the allocator doesn't support remapping, and the caller should allocate new memory and copy.

### Performance Considerations

**Bump Allocator**:
- Allocation: O(1) with minimal overhead (just offset increment)
- Deallocation: O(1) for reset, individual frees are no-ops
- Memory overhead: Zero (no metadata)
- Best for: Temporary allocations, request handling, batch processing

**Wrapper Allocators**:
- Allocation: O(1) + parent allocator cost
- Overhead: Minimal (just tracking variables)
- Best for: Debugging, monitoring, testing

### Common Pitfalls

**Alignment Bugs**: Always use `std.mem.alignForward` and respect alignment requirements. Misaligned allocations cause crashes on many architectures.

**Buffer Overflow**: Check that allocations fit in the buffer before incrementing the offset.

**Double Free**: Wrapper allocators must carefully manage which allocations they own.

**Leaking in Tests**: Use `defer` to ensure allocated memory is freed, even in wrapper allocators.

### Best Practices

**Type Safety**: Cast `*anyopaque` to your allocator type immediately to get type checking:

```zig
const self: *BumpAllocator = @ptrCast(@alignCast(ctx));
```

**Error Handling**: Return `null` on allocation failure, not an error. The caller converts this to `error.OutOfMemory`.

**Testing**: Always test with `std.testing.allocator` which detects memory leaks automatically.

**Documentation**: Document allocation strategy, thread safety, and any limitations clearly.

**Debugging**: Include return address tracking for allocators that need to identify allocation sites.

### Integration with Standard Library

Custom allocators work with all standard library containers:

```zig
var bump = BumpAllocator.init(&buffer);
const allocator = bump.allocator();

var list = std.ArrayList(u32).init(allocator);
defer list.deinit();

var map = std.AutoHashMap(u32, []const u8).init(allocator);
defer map.deinit();
```

This makes custom allocators extremely powerful for controlling memory usage across your entire program.

### When to Use Custom Allocators

**Performance**: Bump allocators are 10-100x faster than general-purpose allocators for short-lived allocations.

**Determinism**: Fixed-buffer allocators provide predictable performance for real-time systems.

**Testing**: Fail allocators ensure robust error handling.

**Debugging**: Counting and logging allocators help track down memory issues.

**Resource Constraints**: Embedded systems often use custom allocators for precise control.

## See Also

- Recipe 18.2: Arena Allocator Patterns for Request Handling
- Recipe 18.6: Tracking and Debugging Memory Usage
- Recipe 0.12: Understanding Allocators

Full compilable example: `code/05-zig-paradigms/18-memory-management/recipe_18_1.zig`
