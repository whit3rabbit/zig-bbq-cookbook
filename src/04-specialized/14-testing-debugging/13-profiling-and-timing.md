# Recipe 14.13: Profiling and timing your program

## Problem

You need to measure your program's performance, identify bottlenecks, and optimize slow code. You want to benchmark functions, track memory allocations, and measure throughput.

## Solution

Use `std.time.nanoTimestamp()` for high-resolution timing:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_13.zig:basic_timing}}
```

## Discussion

Zig provides precise timing primitives for performance measurement. Profiling helps you understand where your program spends time and identify optimization opportunities.

### Timer Utility

Create a reusable timer for consistent measurements:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_13.zig:timer_utility}}
```

Timers make it easy to measure multiple operations consistently.

### Benchmark Algorithm Comparison

Compare different implementations:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_13.zig:benchmark_comparison}}
```

Direct comparison reveals which algorithm performs better.

### Profiling Code Sections

Measure individual sections to find bottlenecks:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_13.zig:profiling_sections}}
```

Lap timing shows where your function spends most of its time.

### Memory Profiling

Track memory usage patterns:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_13.zig:memory_profiling}}
```

Memory profiling reveals allocation patterns and potential leaks.

### Iteration Benchmarking

Measure per-iteration performance:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_13.zig:iteration_benchmark}}
```

Per-iteration timing helps assess scalability.

### Warmup and Statistical Benchmarking

Account for warmup effects and get accurate measurements:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_13.zig:warmup_benchmark}}
```

Warmup runs eliminate JIT compilation and cache effects.

### Statistical Analysis

Collect multiple samples for reliable results:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_13.zig:statistical_benchmark}}
```

Statistics reveal measurement variability and outliers.

### Allocation Tracking

Track allocations with a custom allocator:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_13.zig:allocation_tracking}}
```

Tracking allocators provide detailed memory usage insights.

### Throughput Measurement

Measure data processing rates:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_13.zig:throughput_measurement}}
```

Throughput measurements help assess I/O and processing efficiency.

### Best Practices

1. **Use release builds**: Profile with `-Doptimize=ReleaseFast` for accurate results
2. **Warm up**: Run code multiple times before measuring
3. **Multiple samples**: Take many measurements and analyze statistics
4. **Isolate code**: Benchmark specific functions, not entire programs
5. **Minimize interference**: Close other programs during benchmarking
6. **Measure consistently**: Use the same environment for comparisons
7. **Profile first, optimize second**: Don't optimize without data

### Profiling Workflow

**Step 1: Identify Slow Code**
```zig
var timer = Timer.start("Entire Program");
// ... program code ...
_ = timer.stop();
```

**Step 2: Profile Sections**
```zig
var timer = Timer.start("Operations");
_ = timer.lap("Phase 1");
_ = timer.lap("Phase 2");
_ = timer.lap("Phase 3");
```

**Step 3: Benchmark Alternatives**
```zig
// Compare different implementations
benchmarkFunction(implementationA);
benchmarkFunction(implementationB);
```

**Step 4: Optimize and Verify**
```zig
// After optimization, verify improvement
const before = measureOriginal();
const after = measureOptimized();
std.debug.print("Speedup: {d:.2}x\n", .{before / after});
```

### Timing Patterns

**Pattern 1: Simple Timing**
```zig
const start = std.time.nanoTimestamp();
operation();
const elapsed = std.time.nanoTimestamp() - start;
```

**Pattern 2: Scoped Timing**
```zig
{
    var timer = Timer.start("Operation");
    defer _ = timer.stop();
    operation();
}
```

**Pattern 3: Comparative Benchmarking**
```zig
const times_a = benchmark(funcA, iterations);
const times_b = benchmark(funcB, iterations);
if (times_a < times_b) {
    std.debug.print("A is {d:.2}x faster\n", .{times_b / times_a});
}
```

### Common Gotchas

**Debug vs Release**: Always profile release builds:

```zig
// Wrong - debug builds are much slower
// zig test code.zig

// Right - profile optimized code
// zig test code.zig -Doptimize=ReleaseFast
```

**Cold vs Warm**: Account for warmup:

```zig
// Wrong - includes cold start overhead
const time = measure(func);

// Right - warm up first
for (0..100) |_| func(); // Warmup
const time = measure(func);
```

**Single sample unreliable**: Use statistics:

```zig
// Wrong - one measurement
const time = measure(func);

// Right - multiple samples
var stats = BenchmarkStats.init(100);
for (0..100) |i| {
    stats.addSample(i, measure(func));
}
stats.analyze();
```

### Build Modes and Performance

**Debug** (`-Doptimize=Debug`):
- Slowest execution
- Full safety checks
- Easiest debugging
- Not for profiling

**ReleaseSafe** (`-Doptimize=ReleaseSafe`):
- Fast execution
- Safety checks enabled
- Good for production profiling

**ReleaseFast** (`-Doptimize=ReleaseFast`):
- Fastest execution
- No safety checks
- Best for benchmarking

**ReleaseSmall** (`-Doptimize=ReleaseSmall`):
- Optimized for size
- Useful for embedded systems

### External Profiling Tools

**Linux:**
- `perf` - CPU profiling and hardware counters
- `valgrind --tool=callgrind` - Detailed call graphs
- `flamegraph` - Visualization of profiling data

**macOS:**
- Instruments - Xcode profiling suite
- `dtrace` - System-level tracing

**Cross-platform:**
- `tracy` - Real-time profiler
- `superluminal` - Low-overhead profiler

### Using perf on Linux

```bash
# Compile with debug symbols
zig build-exe -Doptimize=ReleaseFast -Ddebug-symbols=true main.zig

# Profile
perf record ./main

# Analyze
perf report
```

### Memory Profiling Techniques

**Heap Profiling:**
```zig
var gpa = std.heap.GeneralPurposeAllocator(.{
    .enable_memory_limit = true,
}){};
const allocator = gpa.allocator();
// ... use allocator ...
const leaked = gpa.deinit();
```

**Peak Memory Usage:**
```zig
var max_memory: usize = 0;
// Track allocations and update max_memory
```

**Allocation Hot Spots:**
Use a tracking allocator to find where most allocations occur.

### Micro-Benchmarking Pitfalls

**Compiler Optimization**: Prevent dead code elimination:

```zig
// Wrong - may be optimized away
for (0..1000) |_| {
    const result = compute();
    _ = result;
}

// Right - use result to prevent elimination
var sum: usize = 0;
for (0..1000) |_| {
    sum +%= compute();
}
std.mem.doNotOptimizeAway(&sum);
```

**Measurement Overhead**: Account for timer overhead:

```zig
const overhead = measureOverhead();
const measured = measure(func);
const actual = measured - overhead;
```

### Throughput vs Latency

**Latency**: Time for single operation
```zig
const start = std.time.nanoTimestamp();
singleOperation();
const latency = std.time.nanoTimestamp() - start;
```

**Throughput**: Operations per second
```zig
const start = std.time.nanoTimestamp();
for (0..operations) |_| {
    singleOperation();
}
const elapsed = std.time.nanoTimestamp() - start;
const throughput = operations * std.time.ns_per_s / elapsed;
```

### CI/CD Integration

Track performance over time:

```zig
test "performance regression check" {
    const max_allowed_ns = 1000000; // 1ms
    const elapsed = measureCriticalPath();
    try testing.expect(elapsed < max_allowed_ns);
}
```

Fail builds if performance degrades beyond thresholds.

## See Also

- Recipe 14.14: Making your programs run faster
- Recipe 14.12: Debugging basic program crashes
- Recipe 1.5: Build modes and safety
- Recipe 0.13: Testing and Debugging Fundamentals

Full compilable example: `code/04-specialized/14-testing-debugging/recipe_14_13.zig`
