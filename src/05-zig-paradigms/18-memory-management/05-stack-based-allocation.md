# Recipe 18.5: Stack-Based Allocation with FixedBufferAllocator

## Problem

You need predictable, ultra-fast allocations for temporary data, want to eliminate heap overhead entirely, or need to guarantee memory usage bounds. You're working in embedded systems, real-time applications, or performance-critical hot paths where heap allocations are too slow or unpredictable.

## Solution

Zig's `std.heap.FixedBufferAllocator` provides allocator functionality backed by stack-allocated buffers, eliminating all heap overhead and providing predictable, bounded memory usage.

### Basic Fixed Buffer Allocator

Allocate from a stack buffer instead of the heap:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_5.zig:basic_fixed_buffer}}
```

### Handling Buffer Overflow

Detect when the buffer is exhausted:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_5.zig:buffer_overflow}}
```

### Resetting the Buffer

Reuse the buffer for multiple operations:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_5.zig:buffer_reset}}
```

### Thread-Local Buffers

Use thread-local storage for zero-allocation per-thread buffers:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_5.zig:thread_local_buffer}}
```

### Nested Fixed Buffers

Create hierarchical buffer allocation with function-scoped buffers:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_5.zig:nested_fixed_buffers}}
```

### String Building

Build formatted strings without heap allocations:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_5.zig:string_building}}
```

### Performance Benefits

Stack allocation is dramatically faster than heap allocation:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_5.zig:performance_comparison}}
```

This example shows 400+x speedup because:
- No system calls (malloc/free)
- No allocator bookkeeping
- Optimal cache locality
- Zero fragmentation

### Request Handler Pattern

Handle requests entirely from stack buffers:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_5.zig:request_handler}}
```

### Fallback Allocator

Try stack first, fall back to heap if needed:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_5.zig:fallback_allocator}}
```

### Scoped Buffer Pattern

Process data entirely from stack buffers:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_5.zig:scoped_buffer}}
```

## Discussion

Stack-based allocation provides the ultimate performance for temporary allocations by using stack memory directly, bypassing the heap allocator entirely.

### How FixedBufferAllocator Works

The fixed buffer allocator implements bump allocation from a fixed slice:

1. **Initialization**: Receives a slice (usually stack-allocated array)
2. **Allocation**: Increments offset pointer (bump allocation)
3. **Deallocation**: No-op (memory not reclaimed individually)
4. **Reset**: Resets offset to zero, reusing entire buffer

It's essentially an arena allocator backed by a fixed buffer instead of dynamic heap blocks.

### When to Use Stack Buffers

**Perfect For:**
- Temporary string formatting
- Request/response processing
- Parsing and validation
- Small computations with bounded memory
- Real-time systems requiring deterministic allocation
- Embedded systems with limited heap
- Hot paths needing maximum performance

**Avoid When:**
- Allocation size exceeds stack limits
- Data must outlive function scope
- Size is unbounded or highly variable
- Multiple threads need separate buffers

### Stack Size Limitations

Stack sizes are limited by the OS:

**Linux**: Typically 8 MB per thread
**macOS**: 8 MB main thread, 512 KB other threads
**Windows**: 1 MB default, configurable
**Embedded**: Often 4-64 KB

Large buffers (> 1 MB) risk stack overflow. Keep stack buffers small (<100 KB) or use heap-backed arenas for large temporary allocations.

### Buffer Size Selection

Choose buffer sizes based on usage patterns:

**Small (256-1024 bytes)**: String formatting, small temp data
**Medium (4-16 KB)**: Request handling, parsing
**Large (64-256 KB)**: Batch processing, large temp buffers

Profile actual usage with `fba.end_index` to right-size buffers.

### Thread-Local Pattern

Thread-local buffers eliminate per-call allocation:

```zig
threadlocal var buffer: [4096]u8 = undefined;

fn process(data: []const u8) ![]u8 {
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();
    // Use allocator
}
```

Benefits:
- Zero allocations per call
- Thread-safe (each thread has own buffer)
- Fast (stack-local memory)

Drawbacks:
- Concurrent calls on same thread conflict
- Memory used even when thread idle
- Not suitable for recursive functions

### Nested Buffer Pattern

Function-scoped buffers enable hierarchical allocation:

```zig
fn outer() !void {
    var outer_buffer: [2048]u8 = undefined;
    var outer_fba = std.heap.FixedBufferAllocator.init(&outer_buffer);

    fn inner() !void {
        var inner_buffer: [512]u8 = undefined;
        var inner_fba = std.heap.FixedBufferAllocator.init(&inner_buffer);
        // Use inner buffer for temp data
    }

    try inner();
    // inner buffer automatically freed
}
```

Each scope gets its own buffer, automatically cleaned up on return.

### Handling Buffer Exhaustion

When a fixed buffer runs out, `alloc()` returns `error.OutOfMemory`:

**Panic**: For bugs (buffer sized wrong)
**Fallback**: Try heap allocation
**Increase Size**: Profile and resize buffer
**Split Work**: Process in smaller chunks

Always handle exhaustion explicitly - don't assume buffers are large enough.

### Reset Pattern

Resetting allows buffer reuse across iterations:

```zig
var buffer: [4096]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buffer);

for (items) |item| {
    fba.reset();
    const allocator = fba.allocator();
    try processItem(allocator, item);
    // All memory freed by reset
}
```

This eliminates allocations for all iterations after the first.

### Performance Characteristics

**Allocation**:
- O(1) bump allocation (just offset increment)
- Typically 100-1000x faster than malloc
- Zero system calls
- Inline-friendly (no function calls)

**Deallocation**:
- O(1) no-op (free does nothing)
- Reset is O(1) (just offset = 0)

**Memory**:
- Zero per-allocation overhead
- All memory from stack (very cache-friendly)
- Wastes end of buffer space

**Limitations**:
- No individual free (all-or-nothing)
- Fixed maximum size
- Can't grow beyond initial buffer

### Common Pitfalls

**Stack Overflow**: Large buffers can overflow the stack. Keep under 100 KB for safety.

**Dangling Pointers**: Pointers into a fixed buffer become invalid when the buffer goes out of scope or is reset.

**Thread Unsafety**: Shared fixed buffers need synchronization if accessed from multiple threads.

**Size Estimation**: Under-sizing causes OutOfMemory, over-sizing wastes stack space.

### Best Practices

**Size Conservatively**: Use smallest buffer that handles typical cases, with fallback for larger.

**Profile Usage**: Check `fba.end_index` to see actual peak usage.

**Function-Scoped**: Keep buffers function-scoped for automatic cleanup.

**Document Limits**: Comment maximum allocation size supported by buffer.

**Handle Exhaustion**: Always handle `error.OutOfMemory` gracefully.

**Avoid Recursion**: Recursive functions with fixed buffers quickly exhaust stack.

### Fallback Strategy

Combine fixed buffers with heap fallback:

```zig
const data = stack_allocator.alloc(T, size) catch
    try heap_allocator.alloc(T, size);
defer {
    if (data.ptr >= &stack_buffer[0] and data.ptr < &stack_buffer[stack_buffer.len]) {
        // Stack allocation, no free needed
    } else {
        heap_allocator.free(data);
    }
}
```

This optimizes common cases while handling uncommon large allocations.

### Integration Patterns

**With Arena**: Back an arena with a fixed buffer for temporary work:

```zig
var buffer: [4096]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buffer);
var arena = std.heap.ArenaAllocator.init(fba.allocator());
defer arena.deinit();
```

This combines arena convenience with stack performance.

**With Pools**: Use fixed buffer for pool metadata:

```zig
var buffer: [4096]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buffer);
var pool = Pool(T).init(fba.allocator());
```

### Debugging Stack Issues

**Buffer Too Small**: Monitor `fba.end_index`, increase size if near capacity.

**Stack Overflow**: Reduce buffer size or move to heap.

**Corruption**: Ensure no buffer overruns, validate sizes.

**Performance**: Profile to confirm stack allocation is actually faster (not always true for tiny allocations).

### Platform Considerations

**Stack Limits Vary**: Test on target platform, don't assume stack size.

**Thread Stacks Differ**: Main thread often has larger stack than spawned threads.

**Embedded Systems**: Stack is extremely limited (4-64 KB total). Use tiny buffers.

**WebAssembly**: Linear memory model, different characteristics.

### Real-World Use Cases

**Web Servers**: Request buffers, JSON formatting, query parsing
**Parsers**: Token buffers, AST node temporary storage
**Compilers**: Symbol table lookups, error message formatting
**Games**: Frame-scoped allocations, temporary calculations
**Embedded**: Sensor data processing, protocol parsing
**CLI Tools**: Argument processing, output formatting

### Comparison to Other Strategies

**Heap Allocation**:
- Pro: Unlimited size, flexible lifetime
- Con: 100-1000x slower, unpredictable latency

**Stack Allocation**:
- Pro: Fastest possible, zero overhead, deterministic
- Con: Size limited, scope-bound lifetime

**Arena Allocation**:
- Pro: Batch cleanup, flexible size
- Con: Heap-backed, some overhead

**Static Allocation**:
- Pro: Zero runtime allocation
- Con: Fixed at compile time, wastes memory

Choose fixed buffers when you need maximum performance for temporary, bounded allocations.

## See Also

- Recipe 18.2: Arena Allocator Patterns
- Recipe 18.1: Custom Allocator Implementation
- Recipe 0.12: Understanding Allocators

Full compilable example: `code/05-zig-paradigms/18-memory-management/recipe_18_5.zig`
