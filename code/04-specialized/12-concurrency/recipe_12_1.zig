const std = @import("std");
const testing = std.testing;
const Thread = std.Thread;
const time = std.time;

// ANCHOR: basic_thread
test "spawn a basic thread" {
    const thread = try Thread.spawn(.{}, simpleWorker, .{});
    thread.join();
}

fn simpleWorker() void {
    // Thread does some work
    std.debug.print("Thread running\n", .{});
}
// ANCHOR_END: basic_thread

// ANCHOR: thread_with_args
test "spawn thread with arguments" {
    const message = "Hello from thread";
    const thread = try Thread.spawn(.{}, workerWithArgs, .{message});
    thread.join();
}

fn workerWithArgs(msg: []const u8) void {
    std.debug.print("{s}\n", .{msg});
}
// ANCHOR_END: thread_with_args

// ANCHOR: multiple_threads
test "spawn multiple threads" {
    var threads: [4]Thread = undefined;

    for (&threads, 0..) |*thread, i| {
        thread.* = try Thread.spawn(.{}, workerWithId, .{i});
    }

    for (threads) |thread| {
        thread.join();
    }
}

fn workerWithId(id: usize) void {
    std.debug.print("Thread {} running\n", .{id});
}
// ANCHOR_END: multiple_threads

// ANCHOR: shared_counter
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

test "threads with shared state" {
    var counter = Counter.init();
    var threads: [4]Thread = undefined;

    for (&threads) |*thread| {
        thread.* = try Thread.spawn(.{}, incrementCounter, .{&counter});
    }

    for (threads) |thread| {
        thread.join();
    }

    try testing.expectEqual(@as(usize, 4), counter.value);
}

fn incrementCounter(counter: *Counter) void {
    counter.increment();
}
// ANCHOR_END: shared_counter

// ANCHOR: thread_sleep
test "thread sleep and timing" {
    const start = time.milliTimestamp();

    const thread = try Thread.spawn(.{}, sleepWorker, .{100});
    thread.join();

    const elapsed = time.milliTimestamp() - start;
    try testing.expect(elapsed >= 100);
}

fn sleepWorker(ms: u64) void {
    Thread.sleep(ms * time.ns_per_ms);
}
// ANCHOR_END: thread_sleep

// ANCHOR: thread_config
test "thread with stack size configuration" {
    const config = Thread.SpawnConfig{
        .stack_size = 1024 * 1024, // 1 MB stack
    };

    const thread = try Thread.spawn(config, simpleWorker, .{});
    thread.join();
}
// ANCHOR_END: thread_config

// ANCHOR: thread_error_handling
const WorkerError = error{
    TaskFailed,
    InvalidInput,
};

test "handling errors in threads" {
    // Threads that return errors need special handling
    // The thread function itself can't return errors through join()
    // Instead, use shared state to communicate errors

    var result: ?WorkerError = null;
    const thread = try Thread.spawn(.{}, errorWorker, .{&result});
    thread.join();

    try testing.expectEqual(WorkerError.TaskFailed, result.?);
}

fn errorWorker(result: *?WorkerError) void {
    // Simulate an error condition
    result.* = WorkerError.TaskFailed;
}
// ANCHOR_END: thread_error_handling

// ANCHOR: thread_result_channel
const ResultChannel = struct {
    result: ?i32,
    mutex: Thread.Mutex,
    ready: bool,

    fn init() ResultChannel {
        return .{
            .result = null,
            .mutex = .{},
            .ready = false,
        };
    }

    fn send(self: *ResultChannel, value: i32) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.result = value;
        self.ready = true;
    }

    fn receive(self: *ResultChannel) ?i32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.ready) {
            return self.result;
        }
        return null;
    }
};

test "thread result via channel" {
    var channel = ResultChannel.init();

    const thread = try Thread.spawn(.{}, computeWorker, .{&channel});

    // Wait for result
    while (channel.receive() == null) {
        Thread.sleep(time.ns_per_ms);
    }

    thread.join();

    try testing.expectEqual(@as(i32, 42), channel.result.?);
}

fn computeWorker(channel: *ResultChannel) void {
    Thread.sleep(10 * time.ns_per_ms);
    channel.send(42);
}
// ANCHOR_END: thread_result_channel

// ANCHOR: thread_current_id
test "get current thread ID" {
    const main_id = Thread.getCurrentId();

    var thread_id: Thread.Id = undefined;
    const thread = try Thread.spawn(.{}, getThreadId, .{&thread_id});
    thread.join();

    // IDs should be different
    try testing.expect(main_id != thread_id);
}

fn getThreadId(id: *Thread.Id) void {
    id.* = Thread.getCurrentId();
}
// ANCHOR_END: thread_current_id

// ANCHOR: cpu_count
test "detect CPU count for thread pool sizing" {
    const cpu_count = try Thread.getCpuCount();
    try testing.expect(cpu_count > 0);

    // Common pattern: create worker threads = CPU count
    std.debug.print("CPU count: {}\n", .{cpu_count});
}
// ANCHOR_END: cpu_count

// ANCHOR: thread_detach
test "understanding thread lifecycle" {
    // In Zig, you must explicitly join threads
    // There's no detach - all threads must be joined
    // This prevents resource leaks

    const thread = try Thread.spawn(.{}, simpleWorker, .{});

    // Must call join() or thread handle leaks
    thread.join();
}
// ANCHOR_END: thread_detach

// ANCHOR: practical_parallel_sum
fn parallelSum(data: []const i32, num_threads: usize) !i64 {
    if (data.len == 0) return 0;
    if (num_threads == 1) {
        var sum: i64 = 0;
        for (data) |value| sum += value;
        return sum;
    }

    const chunk_size = (data.len + num_threads - 1) / num_threads;
    const threads = try std.testing.allocator.alloc(Thread, num_threads);
    defer std.testing.allocator.free(threads);

    var partial_sums = try std.testing.allocator.alloc(i64, num_threads);
    defer std.testing.allocator.free(partial_sums);

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

test "parallel sum computation" {
    const data = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    const result = try parallelSum(&data, 4);
    try testing.expectEqual(@as(i64, 55), result);
}
// ANCHOR_END: practical_parallel_sum
