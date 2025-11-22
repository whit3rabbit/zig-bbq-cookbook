# Recipe 13.12: Making a Stopwatch Timer

## Problem

You need to time operations, measure performance, or track progress in scripts.

## Solution

Create a simple stopwatch for basic timing:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_12.zig:basic_stopwatch}}
```

## Discussion

Timing is essential for performance analysis, progress tracking, and understanding how long operations take. Zig provides high-resolution timing through `std.time.nanoTimestamp()`.

### Lap Timer

Track multiple intervals with lap functionality:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_12.zig:lap_timer}}
```

Lap timers are useful for tracking multiple stages of an operation. Each lap records the time since the last lap, while `total()` gives the overall elapsed time.

### Pausable Timer

Create timers that can be paused and resumed:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_12.zig:pausable_timer}}
```

Pausable timers accurately track only active time, ignoring paused periods. This is useful when timing user interactions or operations with waiting periods.

### Countdown Timer

Implement countdown timers for deadlines:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_12.zig:countdown_timer}}
```

Countdown timers track time remaining rather than elapsed. Useful for timeouts, rate limiting, and deadline tracking.

### Format Duration

Make durations human-readable:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_12.zig:format_duration}}
```

Human-readable durations make logs and output more useful. The function automatically chooses the appropriate unit (hours, minutes, seconds, or milliseconds).

### Benchmarking

Measure average execution time:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_12.zig:benchmark}}
```

Benchmarking runs a function multiple times and calculates average execution time. More reliable than single measurements due to averaging out noise.

### Timing Statistics

Collect and analyze timing data:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_12.zig:timer_stats}}
```

Statistics help identify performance patterns. Mean shows average performance, min/max reveal outliers, and median indicates typical performance.

### Rate Calculator

Calculate operations per second:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_12.zig:rate_calculator}}
```

Rate calculators measure throughput. Useful for monitoring data processing, network transfers, or any operation where items/second matters.

### Progress Timer

Track progress with time estimates:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_12.zig:progress_timer}}
```

Progress timers estimate time remaining based on current progress. Essential for long-running operations where users need feedback.

### Best Practices

1. **Use high-resolution timers** - `std.time.nanoTimestamp()` provides nanosecond precision
2. **Account for overhead** - Timer operations themselves take time
3. **Run multiple iterations** - Average multiple runs for reliable measurements
4. **Warm up before benchmarking** - First runs may be slower due to caching
5. **Avoid optimization** - Use `std.mem.doNotOptimizeAway()` to prevent removal of benchmarked code
6. **Consider variance** - Don't rely on single measurements
7. **Use appropriate units** - Nanoseconds for microbenchmarks, seconds for long operations

### Timer Resolution

**Nanosecond precision:**
- Most systems provide nanosecond timestamps
- Actual resolution may be lower (microseconds)
- Good for measuring operations > 1μs

**Platform considerations:**
- Linux: Usually nanosecond resolution
- macOS: Nanosecond on modern systems
- Windows: Typically 100ns or better

**Measurement accuracy:**
```zig
// Too fast to measure reliably
var x = 0;
x += 1;  // Likely unmeasurable

// Measurable
var sum: usize = 0;
for (0..1000) |i| {
    sum += i;  // Accumulates enough time
}
```

### Common Timing Patterns

**Simple operation timing:**
```zig
const start = std.time.nanoTimestamp();
doExpensiveOperation();
const end = std.time.nanoTimestamp();
const duration_ns = end - start;
std.debug.print("Operation took {}ns\n", .{duration_ns});
```

**With automatic cleanup:**
```zig
const Timer = struct {
    start: i128,
    name: []const u8,

    fn init(name: []const u8) Timer {
        std.debug.print("{s} starting...\n", .{name});
        return .{
            .start = std.time.nanoTimestamp(),
            .name = name,
        };
    }

    fn deinit(self: *const Timer) void {
        const elapsed = std.time.nanoTimestamp() - self.start;
        std.debug.print("{s} took {}ns\n", .{ self.name, elapsed });
    }
};

{
    const timer = Timer.init("Database query");
    defer timer.deinit();

    // Perform query
}  // Automatically prints elapsed time
```

**Multiple checkpoints:**
```zig
var timer = Stopwatch.start();

doStage1();
const stage1_time = timer.elapsed();

doStage2();
const stage2_time = timer.elapsed() - stage1_time;

doStage3();
const stage3_time = timer.elapsed() - stage1_time - stage2_time;

std.debug.print("Stage 1: {}ns\n", .{stage1_time});
std.debug.print("Stage 2: {}ns\n", .{stage2_time});
std.debug.print("Stage 3: {}ns\n", .{stage3_time});
```

### Performance Considerations

**Timer overhead:**
- Each `nanoTimestamp()` call has cost
- Typically a few hundred nanoseconds
- Negligible for operations > 1μs
- Significant for tight loops

**Optimization:**
```zig
// Bad: Timer in loop
for (items) |item| {
    const start = std.time.nanoTimestamp();
    process(item);
    const end = std.time.nanoTimestamp();
    total_time += end - start;  // Overhead per iteration
}

// Good: Timer around loop
const start = std.time.nanoTimestamp();
for (items) |item| {
    process(item);
}
const end = std.time.nanoTimestamp();
const total_time = end - start;  // Single measurement
```

**Preventing optimization:**
```zig
fn benchmarkFunction() void {
    var result: u64 = 0;
    for (0..1000) |i| {
        result += expensiveCalculation(i);
    }
    // Compiler might optimize away if unused
    std.mem.doNotOptimizeAway(&result);
}
```

### Example Usage

Complete timing example:

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Time a complete operation
    var sw = Stopwatch.start();

    // Process data with lap times
    var lap_timer = LapTimer.start(allocator);
    defer lap_timer.deinit();

    try loadData();
    const load_time = try lap_timer.lap();

    try processData();
    const process_time = try lap_timer.lap();

    try saveResults();
    const save_time = try lap_timer.lap();

    // Format and display results
    const total_time = lap_timer.total();
    const total_str = try formatDuration(allocator, total_time);
    defer allocator.free(total_str);

    std.debug.print("Total: {s}\n", .{total_str});

    const load_str = try formatDuration(allocator, load_time);
    defer allocator.free(load_str);
    std.debug.print("  Load: {s}\n", .{load_str});

    const process_str = try formatDuration(allocator, process_time);
    defer allocator.free(process_str);
    std.debug.print("  Process: {s}\n", .{process_str});

    const save_str = try formatDuration(allocator, save_time);
    defer allocator.free(save_str);
    std.debug.print("  Save: {s}\n", .{save_str});
}
```

### Progress Monitoring

Track long operations:

```zig
pub fn processLargeDataset(items: []Item) !void {
    var progress = ProgressTimer.start(items.len);

    for (items, 0..) |item, i| {
        try processItem(item);
        progress.update(i + 1);

        // Print progress every 100 items
        if (@mod(i + 1, 100) == 0) {
            const progress_str = try progress.formatProgress(allocator);
            defer allocator.free(progress_str);
            std.debug.print("\r{s}", .{progress_str});
        }
    }

    std.debug.print("\n", .{});
}
```

### Timeout Implementation

Use timers for timeouts:

```zig
fn operationWithTimeout(timeout_ms: i64) !void {
    var countdown = CountdownTimer.start(timeout_ms);

    while (!countdown.isExpired()) {
        if (try checkOperation()) {
            return;  // Success
        }

        // Small delay to avoid spinning
        std.time.sleep(10 * std.time.ns_per_ms);
    }

    return error.Timeout;
}
```

### Profiling Tips

**Identify bottlenecks:**
```zig
var stats = TimerStats.init(allocator);
defer stats.deinit();

for (0..1000) |_| {
    const start = std.time.nanoTimestamp();
    suspiciousFunction();
    const end = std.time.nanoTimestamp();
    try stats.record(end - start);
}

const avg = stats.mean();
const min_time = stats.min();
const max_time = stats.max();
const median_time = try stats.median();

std.debug.print("Avg: {}ns, Min: {}ns, Max: {}ns, Median: {}ns\n", .{
    avg,
    min_time,
    max_time,
    median_time,
});
```

**Compare implementations:**
```zig
const impl1_time = benchmark(implementation1, .{data}, 1000);
const impl2_time = benchmark(implementation2, .{data}, 1000);

if (impl1_time < impl2_time) {
    const speedup = @as(f64, @floatFromInt(impl2_time)) / @as(f64, @floatFromInt(impl1_time));
    std.debug.print("Implementation 1 is {d:.2}x faster\n", .{speedup});
} else {
    const speedup = @as(f64, @floatFromInt(impl1_time)) / @as(f64, @floatFromInt(impl2_time));
    std.debug.print("Implementation 2 is {d:.2}x faster\n", .{speedup});
}
```

## See Also

- Recipe 13.10: Adding logging to simple scripts
- Recipe 14.13: Profiling and timing your program
- Recipe 14.14: Making your programs run faster

Full compilable example: `code/04-specialized/13-utility-scripting/recipe_13_12.zig`
