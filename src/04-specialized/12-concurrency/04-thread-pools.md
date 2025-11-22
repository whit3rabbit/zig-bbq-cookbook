## Problem

Creating a new thread for each task is expensive. You need to reuse a fixed set of worker threads to process many tasks efficiently and avoid thread creation overhead.

## Solution

Create a worker pool that maintains a set of threads and distributes work among them.

### Basic Worker Pool

```zig
{{#include ../../../code/04-specialized/12-concurrency/recipe_12_4.zig:basic_worker_pool}}
```

Use it like this:

```zig
var pool = try WorkerPool.init(allocator, 4);
defer pool.deinit();

var counter = std.atomic.Value(u32).init(0);

for (0..4) |i| {
    try pool.spawn(worker, .{&counter}, i);
}

pool.join();
```

## Discussion

### Parallel Computation

Distribute computational work across multiple workers:

```zig
fn parallelCompute(allocator: std.mem.Allocator, data: []const i32, results: []i32) !void {
    const num_workers = try Thread.getCpuCount();
    const chunk_size = (data.len + num_workers - 1) / num_workers;

    var threads = try allocator.alloc(Thread, num_workers);
    defer allocator.free(threads);

    var spawned: usize = 0;
    for (0..num_workers) |i| {
        const start = i * chunk_size;
        if (start >= data.len) break;
        const end = @min(start + chunk_size, data.len);

        threads[i] = try Thread.spawn(.{}, computeChunk, .{
            data[start..end],
            results[start..end],
        });
        spawned += 1;
    }

    for (threads[0..spawned]) |thread| {
        thread.join();
    }
}

fn computeChunk(input: []const i32, output: []i32) void {
    for (input, output) |val, *out| {
        out.* = val * val;
    }
}
```

This pattern:
1. Divides data into chunks
2. Spawns one worker per chunk
3. Each worker processes its chunk independently
4. Waits for all workers to complete

### Parallel Sum (Reduce Pattern)

Aggregate results from multiple workers:

```zig
fn parallelSum(allocator: std.mem.Allocator, data: []const i32) !i32 {
    const num_workers = @min(try Thread.getCpuCount(), data.len);
    const chunk_size = (data.len + num_workers - 1) / num_workers;

    var threads = try allocator.alloc(Thread, num_workers);
    defer allocator.free(threads);

    var partial_sums = try allocator.alloc(i32, num_workers);
    defer allocator.free(partial_sums);

    @memset(partial_sums, 0);

    // Spawn workers
    var spawned: usize = 0;
    for (0..num_workers) |i| {
        const start = i * chunk_size;
        if (start >= data.len) break;
        const end = @min(start + chunk_size, data.len);

        threads[i] = try Thread.spawn(.{}, sumChunk, .{
            data[start..end],
            &partial_sums[i],
        });
        spawned += 1;
    }

    // Wait for workers
    for (threads[0..spawned]) |thread| {
        thread.join();
    }

    // Combine results
    var total: i32 = 0;
    for (partial_sums[0..spawned]) |sum| {
        total += sum;
    }

    return total;
}
```

### Work Queue

For dynamic task distribution, use a thread-safe queue:

```zig
const WorkQueue = struct {
    items: std.ArrayList(i32),
    mutex: Thread.Mutex,
    allocator: std.mem.Allocator,

    fn push(self: *WorkQueue, item: i32) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.items.append(self.allocator, item);
    }

    fn pop(self: *WorkQueue) ?i32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.items.items.len == 0) return null;
        return self.items.pop();
    }
};

fn queueWorker(queue: *WorkQueue, result: *std.atomic.Value(i32)) void {
    while (queue.pop()) |item| {
        _ = result.fetchAdd(item, .monotonic);
    }
}
```

Workers pull tasks from the queue until it's empty. This balances load automatically - faster workers process more tasks.

### Batch Processing

Process large datasets in parallel chunks:

```zig
fn processBatch(data: []i32) void {
    for (data) |*item| {
        item.* *= 2;
    }
}

// Divide work into batches
const num_workers = 4;
const chunk_size = data.len / num_workers;

for (0..num_workers) |i| {
    const start = i * chunk_size;
    const end = if (i == num_workers - 1) data.len else (i + 1) * chunk_size;
    threads[i] = try Thread.spawn(.{}, processBatch, .{data[start..end]});
}
```

### Optimal Worker Count

Choose thread count based on workload:

```zig
const cpu_count = try Thread.getCpuCount();

// For CPU-bound work: match CPU count
const cpu_bound_workers = cpu_count;

// For I/O-bound work: can use more threads
const io_bound_workers = cpu_count * 2;

// For memory-bound work: may want fewer threads
const memory_bound_workers = cpu_count / 2;
```

**CPU-bound**: Computation-heavy tasks benefit from one thread per core.

**I/O-bound**: Tasks waiting on I/O can use more threads since most will be blocked.

**Memory-bound**: Too many threads competing for memory bandwidth can slow down. Use fewer threads.

### Thread Pool Best Practices

1. **Reuse threads** - Create pool once, use many times
2. **Match CPU count** for CPU-bound tasks
3. **Chunk work appropriately** - Not too small (overhead), not too large (imbalance)
4. **Avoid contention** - Minimize shared state between workers
5. **Clean shutdown** - Always join all threads before exiting

### Common Patterns

**Map**: Transform each element independently
```zig
for (input, output, 0..) |in, *out, i| {
    assignToWorker(i % num_workers, .{ in, out });
}
```

**Reduce**: Aggregate partial results
```zig
var partials: []Result = allocWorkerResults(num_workers);
// Workers compute partials...
combineResults(partials);
```

**Pipeline**: Chain processing stages
```zig
stage1Queue -> Worker1 -> stage2Queue -> Worker2 -> results
```

## See Also

- Recipe 12.1: Basic threading and thread management
- Recipe 12.5: Thread-safe queues and channels
- Recipe 12.11: Parallel map and reduce operations

Full compilable example: `code/04-specialized/12-concurrency/recipe_12_4.zig`
