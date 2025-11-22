# Recipe 18.2: Arena Allocator Patterns for Request Handling

## Problem

You need to manage memory for short-lived operations like request handling, batch processing, or temporary computations. You want automatic cleanup of all allocations together without tracking individual frees, and you need better performance than general-purpose allocators.

## Solution

Zig's `std.heap.ArenaAllocator` groups related allocations together and frees them all at once, making it ideal for request/response lifecycles and batch processing patterns.

### Basic Arena Usage

Create an arena and allocate freely without worrying about individual frees:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_2.zig:basic_arena}}
```

### Request/Response Lifecycle

Use arenas to automatically clean up all request and response data:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_2.zig:request_response}}
```

### Batch Processing with Reset

Reuse arena memory across multiple batches:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_2.zig:batch_processing}}
```

### Nested Arena Scopes

Create hierarchical memory management with parent and child arenas:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_2.zig:nested_arenas}}
```

### Performance Benefits

Arena allocators are significantly faster than general-purpose allocators:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_2.zig:arena_vs_general}}
```

This example shows arena allocation being 7-10x faster because:
- No per-allocation bookkeeping
- No individual frees
- Better cache locality
- Reduced fragmentation

### Scoped Arena Pattern

Use arenas for function-scoped temporary allocations:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_2.zig:scoped_arena}}
```

### Arena with Retained State

Combine arena memory management with persistent state:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_2.zig:arena_state}}
```

### Multiple Arenas for Different Lifetimes

Use separate arenas for config (long-lived) and requests (short-lived):

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_2.zig:multi_arena}}
```

### Arena with Preallocated Buffer

Optimize further by using stack memory for small arenas:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_2.zig:arena_optimization}}
```

## Discussion

Arena allocators simplify memory management for short-lived data by grouping related allocations and freeing them all at once, providing both convenience and performance benefits.

### How Arena Allocators Work

An arena allocator:

1. Allocates large blocks from a backing allocator
2. Serves individual allocations from these blocks using bump allocation
3. Tracks allocated blocks in a linked list
4. Frees all blocks at once on `deinit()` or `reset()`

The result is O(1) allocation (just incrementing an offset) and O(1) deallocation for all memory (freeing the block list).

### When to Use Arenas

**Perfect For:**
- Request/response handling in servers
- Batch processing jobs
- Parsing and compilation passes
- Temporary computation buffers
- Game frame allocations

**Avoid When:**
- Allocations have mixed lifetimes
- Memory must be freed selectively
- Long-running processes without clear reset points
- Very large allocations (arena overhead becomes significant)

### Reset vs Deinit

**`deinit()`**: Frees all memory back to the backing allocator and destroys the arena.

**`reset()`**: Frees memory internally but retains the allocated blocks for reuse.

```zig
_ = arena.reset(.retain_capacity);  // Keep blocks, reuse memory
_ = arena.reset(.free_all);         // Free blocks back to backing allocator
```

Use `retain_capacity` when processing many similar-sized batches to avoid repeated heap allocations.

### Request Handler Pattern

The request/response pattern is the classic arena use case:

```zig
fn handleRequest(backing_allocator: Allocator, request_data: []const u8) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(backing_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Parse request, build response, all using arena
    const request = try parseRequest(allocator, request_data);
    const response = try processRequest(allocator, request);
    return try formatResponse(allocator, response);

    // All memory freed automatically on return
}
```

This pattern:
- Ensures no memory leaks (everything freed together)
- Simplifies error handling (no cleanup in error paths)
- Improves performance (fast bump allocation)
- Reduces code complexity (no individual `defer`s)

### Nested Arena Hierarchies

Nested arenas provide fine-grained lifetime control:

**Parent Arena**: Lives for entire server lifetime, holds config and long-lived data
**Child Arena**: Lives for a request, holds request/response data
**Grandchild Arena**: Lives for a sub-operation, holds temporary parsing data

This hierarchy matches the natural lifetimes of server data, preventing memory from accumulating over many requests.

### The Reset Pattern

For repeated operations, reset the arena instead of creating new ones:

```zig
var processor = RequestProcessor.init(allocator);
defer processor.deinit();

for (requests) |req| {
    _ = processor.arena.reset(.retain_capacity);
    try processor.process(req);
}
```

This reuses the underlying memory blocks, avoiding repeated heap allocations and fragmentation.

### Memory Overhead

Arena allocators have minimal overhead:

**Per-Arena**: Linked list node (~24 bytes) plus backing allocator state
**Per-Block**: Block header (~16 bytes) for tracking purposes
**Per-Allocation**: Zero overhead (bump allocation has no metadata)

For typical request sizes (KB to MB), this overhead is negligible compared to the performance benefits.

### Performance Characteristics

**Allocation**: O(1) bump allocation within current block, O(1) amortized for new blocks
**Deallocation**: O(1) individual frees are no-ops, O(n) for deinit/reset where n is block count
**Memory Usage**: Can waste space at end of each block (internal fragmentation)
**Cache Performance**: Excellent - sequential allocations have excellent locality

Benchmarks typically show 5-10x speedup over general-purpose allocators for allocation-heavy workloads.

### Common Pitfalls

**Dangling Pointers**: After `reset()` or `deinit()`, all pointers into the arena are invalid.

```zig
const data = try arena.allocator().alloc(u8, 100);
_ = arena.reset(.retain_capacity);
// data is now invalid! Accessing it is undefined behavior
```

**Mixed Lifetimes**: Don't put long-lived data in the same arena as short-lived data.

**Growing Without Bounds**: In long-running processes, ensure arenas are reset periodically.

**Not Actually Short-Lived**: If most allocations need to outlive the arena, you're paying overhead for no benefit.

### Best Practices

**One Arena Per Request**: Create a fresh arena for each independent operation to ensure clean slate.

**Reset Between Batches**: When processing many similar items, reset the arena between items rather than creating new arenas.

**Separate Arenas for Lifetimes**: Use different arenas for config (persistent), request (transient), and sub-operations (very transient).

**Document Lifetime Assumptions**: Comment which arena owns which data to prevent dangling pointer bugs.

**Use defer**: Always use `defer arena.deinit()` to ensure cleanup even on errors.

**Combine with Stack Buffers**: For small operations, back the arena with a stack buffer to eliminate all heap allocations.

### Stack-Backed Arenas

For small, predictable operations, eliminate heap allocations entirely:

```zig
var buffer: [4096]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buffer);
var arena = std.heap.ArenaAllocator.init(fba.allocator());
defer arena.deinit();

// All allocations come from stack buffer (if they fit)
```

This is perfect for:
- Parsing small configuration files
- Building small JSON responses
- Temporary string formatting
- Quick computations with bounded memory

If allocations exceed the buffer, they'll fail with `OutOfMemory`, so size the buffer appropriately.

### Integration with Server Architectures

**Thread-Per-Request**: Each thread gets its own arena, freed when the thread finishes handling the request.

**Async/Event Loop**: Each async task gets an arena, freed when the task completes.

**Connection Pooling**: Reset arenas when connections are returned to the pool.

**Worker Queues**: Worker threads create arenas for each work item, resetting between items.

### Debugging Arena Issues

**Memory Leaks**: Use the arena's backing allocator to detect leaks. The testing allocator will catch blocks not freed by `deinit()`.

**Excessive Memory Usage**: Monitor arena size with custom debugging allocators. Large arenas may indicate lifetime management issues.

**Fragmentation**: If arena memory grows despite resets, check that `reset()` is being called correctly.

### Comparison to Other Strategies

**General Allocator**:
- Pro: Selective freeing, works for any lifetime
- Con: Slower, requires careful lifetime tracking

**Arena Allocator**:
- Pro: Fast, automatic cleanup, simple lifetime management
- Con: All-or-nothing freeing, can waste memory with mixed lifetimes

**Stack Allocation**:
- Pro: Fastest possible, automatic cleanup
- Con: Fixed size, limited lifetime (scope-bound)

**Pool Allocator**:
- Pro: Fast, reuses memory, works for specific object types
- Con: Fixed object size, manual lifetime management

Choose arenas when you have clear operation boundaries (requests, batches, passes) with many allocations that all share the same lifetime.

## See Also

- Recipe 18.1: Custom Allocator Implementation
- Recipe 18.4: Object Pool Management
- Recipe 18.5: Stack-Based Allocation with FixedBufferAllocator
- Recipe 0.12: Understanding Allocators

Full compilable example: `code/05-zig-paradigms/18-memory-management/recipe_18_2.zig`
