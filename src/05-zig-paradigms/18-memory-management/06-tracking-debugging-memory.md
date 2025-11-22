# Recipe 18.6: Tracking and Debugging Memory Usage

## Problem

You need to detect memory leaks, track allocation patterns, profile memory usage, or debug memory corruption issues. You want to understand where allocations occur, how much memory is used, and whether all allocations are properly freed.

## Solution

Zig provides several tools and patterns for tracking and debugging memory, from the built-in testing allocator to custom allocator wrappers that log, validate, and profile allocations.

### Testing Allocator for Leak Detection

Use the testing allocator to automatically detect memory leaks:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_6.zig:testing_allocator}}
```

### Logging Allocator

Wrap an allocator to log all allocations and frees:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_6.zig:logging_allocator}}
```

### Tracking Allocator

Track all active allocations with detailed information:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_6.zig:tracking_allocator}}
```

### Validating Allocator

Detect buffer overruns with canary values:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_6.zig:validating_allocator}}
```

### Memory Profiler

Profile allocation patterns by size:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_6.zig:memory_profiler}}
```

## Discussion

Memory tracking and debugging tools help identify leaks, corruption, and inefficient allocation patterns, ensuring robust and efficient memory management.

### The Testing Allocator

Zig's `std.testing.allocator` is a wrapper that:

1. Tracks all allocations with metadata
2. Detects memory leaks at test end
3. Catches double-frees
4. Reports leaked allocations with stack traces

It's the primary tool for ensuring tests don't leak memory.

**Always use `testing.allocator` in tests, never `std.heap.page_allocator` or other allocators.**

### Allocator Wrapper Pattern

All debugging allocators follow the wrapper pattern:

```zig
const DebugAllocator = struct {
    parent: Allocator,
    // ... debug state

    pub fn allocator(self: *Self) Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    fn alloc(...) ?[*]u8 {
        // Debug logic here
        return self.parent.rawAlloc(...);
    }
};
```

This allows composing multiple debugging layers.

### Logging for Debugging

The logging allocator prints every allocation and free:

**Benefits**:
- See allocation order and patterns
- Identify unexpected allocations
- Track allocation call sites
- Debug allocation/free mismatches

**Drawbacks**:
- Very verbose output
- Slows execution significantly
- Not suitable for production

Use logging allocators during development to understand memory behavior.

### Tracking Active Allocations

The tracking allocator maintains a list of all active allocations:

**Features**:
- Stores size, address, and return address
- Tracks total and peak allocated memory
- Can report leaks with call sites
- Enables memory usage profiling

**Overhead**:
- Extra allocation per tracked allocation (metadata)
- Linear search on free (can be optimized with hash map)
- Memory for tracking list

Use tracking allocators to diagnose leaks and understand memory usage patterns.

### Canary Detection

Validating allocators use "canary" values to detect buffer overruns:

```zig
[CANARY][User Data][CANARY]
```

**How It Works**:
1. Allocate extra space before and after user data
2. Write known canary values (e.g., `0xDEADBEEF`)
3. On free, check if canaries are still intact
4. Panic if canaries were overwritten

This catches buffer overflows that write past allocation boundaries.

**Limitations**:
- Only detects overruns at free time
- Doesn't catch reads past boundaries
- Adds memory overhead (2 * canary size per allocation)

### Memory Profiling

Memory profilers track allocation patterns:

**Allocation Size Distribution**: How many allocations of each size?
**Allocation Frequency**: Which sizes are allocated most often?
**Temporal Patterns**: When do allocations occur?

This data helps:
- Identify opportunities for pooling
- Right-size pre-allocated buffers
- Detect unexpected allocation patterns
- Optimize hot allocation paths

### Composing Debug Allocators

Stack multiple wrappers for combined functionality:

```zig
var tracking = TrackingAllocator.init(testing.allocator);
defer tracking.deinit();

var validating = ValidatingAllocator.init(tracking.allocator());
const allocator = validating.allocator();

// Now we have: testing.allocator -> tracking -> validating -> your code
// Leak detection, allocation tracking, AND canary detection!
```

Each layer adds its own checks and tracking.

### Debugging Memory Leaks

To find a leak:

1. **Enable Tracking**: Use tracking allocator or testing allocator
2. **Run Code**: Exercise the code path
3. **Check Report**: Look for non-freed allocations
4. **Find Source**: Use return addresses to locate allocation site
5. **Fix Leak**: Add missing `free()` or fix lifetime issue

**Common Leak Patterns**:
- Forgetting `defer allocator.free()`
- Early returns bypassing cleanup
- Exceptions/errors skipping deallocation
- Circular references in graph structures

### Debugging Corruption

To find corruption:

1. **Enable Validation**: Use validating allocator
2. **Run Until Crash**: Execute until corruption detected
3. **Examine Canaries**: Check which canary was overwritten
4. **Find Culprit**: Look for buffer writes near crash time
5. **Fix Bug**: Add bounds checking, fix off-by-one errors

**Common Corruption Patterns**:
- Off-by-one errors in loops
- Incorrect size calculations
- Pointer arithmetic errors
- String operations without null terminator

### Performance Impact

Debug allocators have performance costs:

**Logging**: 10-100x slowdown (I/O overhead)
**Tracking**: 2-5x slowdown (list management)
**Validation**: 1.1-1.5x slowdown (canary checks)
**Profiling**: 1.5-3x slowdown (hash map updates)

**Only use in debug builds**. Wrap with `if (builtin.mode == .Debug)` for zero production cost.

### Best Practices

**Use Testing Allocator**: Always in tests for automatic leak detection.

**Layered Debugging**: Combine allocators for comprehensive checking.

**Conditional Wrapping**: Enable debug allocators only in debug mode.

**Profile First**: Use profiling to understand patterns before optimizing.

**Fix Leaks Immediately**: Don't accumulate memory leak debt.

**Automate Checks**: Run tests with leak detection in CI.

### Advanced Techniques

**Stack Traces**: Store full stack trace on allocation:

```zig
const info = AllocationInfo{
    .size = len,
    .address = @intFromPtr(result),
    .stack_trace = std.debug.dumpCurrentStackTrace(),
};
```

**Allocation Tagging**: Tag allocations by subsystem:

```zig
const Tagged = struct {
    tag: []const u8,
    parent: Allocator,
};
```

**Time Tracking**: Record allocation timestamps to detect patterns.

**Heap Visualization**: Generate graphs of allocation/free patterns.

### Integration with Tools

**Valgrind**: Not needed for leak detection (use testing allocator), but useful for:
- Finding use-after-free
- Detecting uninitialized reads
- Checking cache behavior

**AddressSanitizer**: Compile with `-fsanitize=address` for additional checking:
- Buffer overflows
- Use-after-free
- Memory leaks
- Stack corruption

**Zig's Built-in Safety**: `-Doptimize=Debug` enables:
- Undefined behavior checks
- Integer overflow detection
- Bounds checking

### Common Debugging Scenarios

**Intermittent Crashes**: Often corruption. Use validating allocator.

**Memory Growth**: Likely leak. Use tracking allocator to find culprit.

**Slow Performance**: Too many allocations. Use profiling allocator.

**Test Failures**: Leak in test. Check testing allocator output.

**Production Issues**: Can't use debug allocators. Enable limited tracking.

### Production Debugging

For production memory issues:

**Metrics**: Track total allocated, allocation rate, free rate
**Sampling**: Only track 1 in N allocations for low overhead
**Aggregation**: Collect allocation size histograms
**Periodic Snapshots**: Dump allocation state periodically
**Limits**: Set hard limits, fail fast on exceeded limits

### Debugging Zig-Specific Issues

**Arena Leaks**: Forget to call `arena.deinit()`. Look for missing defers.

**Pool Leaks**: Objects acquired but not released. Track pool state.

**Circular References**: Use weak references or explicit break cycles.

**Slice Lifetime**: Slices outlive underlying allocation. Validate lifetimes.

**Allocator Mismatch**: Free with different allocator than alloc. Always match.

### Best Practices Summary

1. **Always use `testing.allocator` in tests**
2. **Defer cleanup immediately after allocation**
3. **Use `errdefer` for error path cleanup**
4. **Enable debug allocators in development**
5. **Profile before optimizing**
6. **Fix leaks as they're found**
7. **Automate leak detection in CI**
8. **Document allocation ownership**
9. **Use RAII patterns for automatic cleanup**
10. **Validate assumptions with debug allocators**

### When Not to Debug

**Working Code**: If tests pass and no issues, don't add debug overhead.

**Micro-Optimizations**: Profile first, don't guess.

**Production**: Debug allocators have too much overhead for production.

**Embedded**: Limited resources may preclude debug allocators.

## See Also

- Recipe 18.1: Custom Allocator Implementation
- Recipe 18.2: Arena Allocator Patterns
- Recipe 0.13: Testing and Debugging Fundamentals

Full compilable example: `code/05-zig-paradigms/18-memory-management/recipe_18_6.zig`
