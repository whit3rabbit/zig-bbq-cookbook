## Problem

You need to run code in parallel using multiple threads, pass data between threads safely, and coordinate their execution.

## Solution

Zig provides `std.Thread` for creating and managing threads. Here's how to spawn a basic thread:

```zig
{{#include ../../../code/04-specialized/12-concurrency/recipe_12_1.zig:basic_thread}}
```

### Passing Arguments to Threads

Threads can accept parameters through their function arguments:

```zig
{{#include ../../../code/04-specialized/12-concurrency/recipe_12_1.zig:thread_with_args}}
```

### Managing Multiple Threads

Create and coordinate multiple threads using arrays:

```zig
{{#include ../../../code/04-specialized/12-concurrency/recipe_12_1.zig:multiple_threads}}
```

### Sharing State Between Threads

When threads need to share mutable state, protect it with a mutex:

```zig
const Counter = struct {
    value: usize,
    mutex: Thread.Mutex,

    fn init() Counter {
        return .{
            .value = 0,
            .mutex = .{},
        };
    }

    fn increment(self: *Counter) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.value += 1;
    }
};

var counter = Counter.init();
var threads: [4]Thread = undefined;

for (&threads) |*thread| {
    thread.* = try Thread.spawn(.{}, incrementCounter, .{&counter});
}

for (threads) |thread| {
    thread.join();
}
```

## Discussion

### Thread Lifecycle

Zig requires explicit thread management. Every spawned thread must be joined - there's no detach operation. This prevents resource leaks and ensures you handle thread completion properly.

The `join()` method blocks until the thread completes its work. Plan your thread coordination carefully to avoid unnecessary waiting.

### Thread Configuration

Customize thread behavior with `Thread.SpawnConfig`:

```zig
const config = Thread.SpawnConfig{
    .stack_size = 1024 * 1024, // 1 MB stack
};

const thread = try Thread.spawn(config, simpleWorker, .{});
thread.join();
```

### Timing and Sleep

Use `Thread.sleep()` to pause execution. Time is specified in nanoseconds:

```zig
fn sleepWorker(ms: u64) void {
    Thread.sleep(ms * time.ns_per_ms);
}
```

### Error Handling in Threads

Thread functions can't directly return errors through `join()`. Instead, communicate errors through shared state:

```zig
var result: ?WorkerError = null;
const thread = try Thread.spawn(.{}, errorWorker, .{&result});
thread.join();

fn errorWorker(result: *?WorkerError) void {
    result.* = WorkerError.TaskFailed;
}
```

### Returning Results from Threads

Use a simple channel pattern to communicate results:

```zig
const ResultChannel = struct {
    result: ?i32,
    mutex: Thread.Mutex,
    ready: bool,

    fn send(self: *ResultChannel, value: i32) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.result = value;
        self.ready = true;
    }

    fn receive(self: *ResultChannel) ?i32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.ready) return self.result;
        return null;
    }
};
```

### Thread Identification

Get the current thread's ID for debugging or logging:

```zig
const thread_id = Thread.getCurrentId();
```

### CPU Count Detection

Determine optimal thread pool size based on available CPUs:

```zig
const cpu_count = try Thread.getCpuCount();
// Common pattern: create worker threads = CPU count
```

### Practical Example: Parallel Sum

Here's a complete example of parallel computation:

```zig
fn parallelSum(data: []const i32, num_threads: usize) !i64 {
    const chunk_size = (data.len + num_threads - 1) / num_threads;
    const threads = try allocator.alloc(Thread, num_threads);
    defer allocator.free(threads);

    var partial_sums = try allocator.alloc(i64, num_threads);
    defer allocator.free(partial_sums);

    for (threads, 0..) |*thread, i| {
        const start = i * chunk_size;
        const end = @min(start + chunk_size, data.len);
        if (start >= data.len) {
            partial_sums[i] = 0;
            continue;
        }
        thread.* = try Thread.spawn(.{}, sumChunk, .{ data[start..end], &partial_sums[i] });
    }

    for (threads, 0..) |thread, i| {
        if (i * chunk_size < data.len) {
            thread.join();
        }
    }

    var total: i64 = 0;
    for (partial_sums) |sum| total += sum;
    return total;
}

fn sumChunk(data: []const i32, result: *i64) void {
    var sum: i64 = 0;
    for (data) |value| sum += value;
    result.* = sum;
}
```

### Key Takeaways

1. Always join threads - Zig has no detach operation
2. Protect shared state with mutexes
3. Use channels or shared state to communicate results
4. Configure stack size when needed for deep recursion
5. Match thread count to CPU count for compute-bound tasks
6. Remember that thread creation has overhead - don't spawn thousands of threads

## See Also

- Recipe 12.2: Mutexes and basic locking
- Recipe 12.4: Thread pools for parallel work
- Recipe 12.5: Thread-safe queues and channels

Full compilable example: `code/04-specialized/12-concurrency/recipe_12_1.zig`
