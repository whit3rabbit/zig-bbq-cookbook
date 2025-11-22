# Recipe 14.14: Making your programs run faster

## Problem

You need to optimize your program's performance. You want to apply proven optimization techniques without sacrificing code clarity or introducing bugs.

## Solution

Profile first, then apply targeted optimizations. Use SIMD vectorization for data-parallel operations:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_14.zig:simd_optimization}}
```

## Discussion

Performance optimization requires understanding both your code and the hardware it runs on. Always profile before optimizing to ensure you're improving the actual bottlenecks.

### Cache-Friendly Data Layouts

Structure data for better cache utilization:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_14.zig:cache_friendly}}
```

Struct of Arrays (SoA) layout improves cache hit rates when accessing a single field across many elements.

### Loop Unrolling

Reduce loop overhead by processing multiple elements per iteration:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_14.zig:loop_unrolling}}
```

Unrolling trades code size for fewer branch instructions and better instruction pipelining.

### Inline Functions

Eliminate function call overhead for small, frequently-called functions:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_14.zig:inline_functions}}
```

The `inline` keyword suggests the compiler expand function calls at the call site.

### Branch Prediction

Write code that's friendly to CPU branch predictors:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_14.zig:branch_prediction}}
```

Predictable branches (same outcome repeatedly) perform better than random branches.

### Memory Pooling

Reduce allocation overhead with object pools:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_14.zig:memory_pooling}}
```

Pools pre-allocate objects, eliminating per-object allocation costs.

### Reduce Allocations

Reuse buffers instead of repeatedly allocating:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_14.zig:reduce_allocations}}
```

Single allocation and reuse is much faster than many small allocations.

### Comptime Optimization

Use compile-time parameters to eliminate runtime branches:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_14.zig:const_parameters}}
```

Comptime parameters let the compiler optimize away entire code paths.

### Avoid Bounds Checks

Use iterators instead of indexing when possible:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_14.zig:avoid_bounds_checks}}
```

Iterator-based loops are clearer and avoid redundant bounds checks.

### Efficient String Building

Pre-allocate capacity for string operations:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_14.zig:string_building}}
```

Pre-allocation prevents repeated reallocation as the string grows.

### Packed Structs

Reduce memory usage with packed struct layouts:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_14.zig:packed_structs}}
```

Packed structs eliminate padding, reducing memory footprint.

### Best Practices

1. **Profile first**: Measure before optimizing
2. **Optimize bottlenecks**: Focus on hot paths (80/20 rule)
3. **Measure improvements**: Verify optimizations actually help
4. **Maintain clarity**: Don't sacrifice readability for marginal gains
5. **Use release builds**: Only optimize release builds
6. **Test thoroughly**: Ensure optimizations don't break correctness
7. **Document trade-offs**: Explain why complex optimizations are needed

### Optimization Workflow

**Step 1: Profile**
```bash
# Build with optimization and profiling symbols
zig build-exe -Doptimize=ReleaseFast -Ddebug-symbols=true main.zig

# Profile with perf (Linux) or Instruments (macOS)
perf record ./main
perf report
```

**Step 2: Identify Hotspots**
Find functions consuming the most CPU time.

**Step 3: Optimize Hot Paths**
Apply optimizations to functions that matter.

**Step 4: Verify Improvement**
Re-profile to confirm the optimization helped.

### Optimization Techniques by Category

**CPU-Bound:**
- SIMD vectorization
- Loop unrolling
- Inline functions
- Comptime specialization
- Better algorithms

**Memory-Bound:**
- Cache-friendly layouts (SoA)
- Memory pooling
- Reduce allocations
- Packed structs
- Alignment optimization

**I/O-Bound:**
- Buffering
- Batch operations
- Async I/O
- Memory-mapped files
- Read-ahead caching

### Common Performance Pitfalls

**Pitfall 1: Premature Optimization**
```zig
// Wrong - optimizing without profiling
fn compute(x: i32) i32 {
    // Complex "optimized" code that may not help
    return x * @as(i32, @intCast(@as(u32, @bitCast(x))));
}

// Right - clear code first
fn compute(x: i32) i32 {
    return x * x;
}
```

**Pitfall 2: Ignoring Algorithms**
```zig
// Wrong - optimizing bad algorithm
fn sortBubble(data: []i32) void {
    // ... bubble sort with SIMD ...
}

// Right - use better algorithm
fn sortQuick(data: []i32) void {
    std.sort.heap(i32, data, {}, std.sort.asc(i32));
}
```

**Pitfall 3: Over-Optimization**
```zig
// Wrong - unreadable for 1% gain
fn process(data: []const u8) u64 {
    // 500 lines of hand-crafted assembly
}

// Right - clear code with good-enough performance
fn process(data: []const u8) u64 {
    // 10 lines of readable Zig
}
```

### SIMD Guidelines

**When to use SIMD:**
- Processing large arrays
- Mathematical computations
- Image/signal processing
- Data transformations

**When not to use SIMD:**
- Small datasets (overhead dominates)
- Branch-heavy code
- Complex control flow
- Portability concerns

### Cache Optimization

**L1 Cache** (~4 cycles):
- Keep hot data small
- Use local variables
- Minimize pointer chasing

**L2 Cache** (~12 cycles):
- Group related data
- Use SoA layouts
- Prefetch when appropriate

**L3 Cache** (~40 cycles):
- Batch operations
- Sequential access patterns
- Minimize cache pollution

### Memory Alignment

Aligned data improves SIMD and cache performance:

```zig
const AlignedData = struct {
    data: [1024]f32 align(64),
};
```

### Compiler Optimizations

Enable different optimization levels:

**-Doptimize=Debug**: No optimization (default)
**-Doptimize=ReleaseSafe**: Optimized with safety checks
**-Doptimize=ReleaseFast**: Maximum speed, minimal safety
**-Doptimize=ReleaseSmall**: Optimized for size

### Platform-Specific Optimizations

**x86_64:**
- SSE/AVX instructions
- Cache line size: 64 bytes
- Strong memory ordering

**ARM:**
- NEON SIMD
- Cache line size: varies (32-128 bytes)
- Weak memory ordering

**RISC-V:**
- Vector extensions
- Explicit prefetching
- Relaxed memory model

### Micro-Optimizations

**Bit manipulation:**
```zig
// Fast power-of-2 check
inline fn isPowerOfTwo(x: u32) bool {
    return x != 0 and (x & (x - 1)) == 0;
}
```

**Multiply by constant:**
```zig
// Compiler optimizes this to shifts/adds
const result = value * 17;
```

**Avoid division:**
```zig
// Wrong - division is slow
const avg = sum / count;

// Right - multiply by reciprocal when possible
const reciprocal = 1.0 / @as(f64, @floatFromInt(count));
const avg = sum * reciprocal;
```

### Algorithmic Complexity

Optimization can't fix bad complexity:

**O(n²) → O(n log n)**: Use better sorting
**O(n) → O(1)**: Use hash tables for lookups
**O(2ⁿ) → O(n²)**: Use dynamic programming

Always choose the right algorithm before micro-optimizing.

### Parallel Processing

Use threading for CPU-bound tasks:

```zig
var threads: [4]std.Thread = undefined;
for (&threads, 0..) |*thread, i| {
    thread.* = try std.Thread.spawn(.{}, worker, .{i});
}
for (&threads) |thread| {
    thread.join();
}
```

### Performance Testing

Prevent regressions with performance tests:

```zig
test "performance regression check" {
    const start = std.time.nanoTimestamp();
    criticalFunction();
    const elapsed = std.time.nanoTimestamp() - start;

    const max_ns = 1_000_000; // 1ms limit
    try testing.expect(elapsed < max_ns);
}
```

## See Also

- Recipe 14.13: Profiling and timing your program
- Recipe 14.12: Debugging basic program crashes
- Recipe 1.5: Build modes and safety
- Recipe 12.4: Thread pools for parallel work

Full compilable example: `code/04-specialized/14-testing-debugging/recipe_14_14.zig`
