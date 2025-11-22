const std = @import("std");
const testing = std.testing;
const Thread = std.Thread;

// ANCHOR: basic_worker_pool
const WorkerPool = struct {
    threads: []Thread,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, num_workers: usize) !WorkerPool {
        const threads = try allocator.alloc(Thread, num_workers);
        return .{
            .threads = threads,
            .allocator = allocator,
        };
    }

    fn deinit(self: *WorkerPool) void {
        self.allocator.free(self.threads);
    }

    fn spawn(self: *WorkerPool, comptime func: anytype, args: anytype, index: usize) !void {
        self.threads[index] = try Thread.spawn(.{}, func, args);
    }

    fn join(self: *WorkerPool) void {
        for (self.threads) |thread| {
            thread.join();
        }
    }
};

test "basic worker pool" {
    var pool = try WorkerPool.init(testing.allocator, 4);
    defer pool.deinit();

    var counter = std.atomic.Value(u32).init(0);

    var i: usize = 0;
    while (i < 4) : (i += 1) {
        try pool.spawn(incrementWorker, .{&counter}, i);
    }

    pool.join();

    try testing.expectEqual(@as(u32, 4), counter.load(.monotonic));
}

fn incrementWorker(counter: *std.atomic.Value(u32)) void {
    _ = counter.fetchAdd(@as(u32, 1), .monotonic);
}
// ANCHOR_END: basic_worker_pool

// ANCHOR: parallel_computation
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

        threads[i] = try Thread.spawn(.{}, computeChunk, .{ data[start..end], results[start..end] });
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

test "parallel computation" {
    const data = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var results: [8]i32 = undefined;

    try parallelCompute(testing.allocator, &data, &results);

    for (data, results) |input, result| {
        try testing.expectEqual(input * input, result);
    }
}
// ANCHOR_END: parallel_computation

// ANCHOR: parallel_sum
fn parallelSum(allocator: std.mem.Allocator, data: []const i32) !i32 {
    if (data.len == 0) return 0;

    const num_workers = @min(try Thread.getCpuCount(), data.len);
    const chunk_size = (data.len + num_workers - 1) / num_workers;

    var threads = try allocator.alloc(Thread, num_workers);
    defer allocator.free(threads);

    var partial_sums = try allocator.alloc(i32, num_workers);
    defer allocator.free(partial_sums);

    @memset(partial_sums, 0);

    var spawned: usize = 0;
    for (0..num_workers) |i| {
        const start = i * chunk_size;
        if (start >= data.len) break;
        const end = @min(start + chunk_size, data.len);

        threads[i] = try Thread.spawn(.{}, sumChunk, .{ data[start..end], &partial_sums[i] });
        spawned += 1;
    }

    for (threads[0..spawned]) |thread| {
        thread.join();
    }

    var total: i32 = 0;
    for (partial_sums[0..spawned]) |sum| {
        total += sum;
    }

    return total;
}

fn sumChunk(data: []const i32, result: *i32) void {
    var sum: i32 = 0;
    for (data) |value| {
        sum += value;
    }
    result.* = sum;
}

test "parallel sum" {
    const data = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    const result = try parallelSum(testing.allocator, &data);
    try testing.expectEqual(@as(i32, 55), result);
}
// ANCHOR_END: parallel_sum

// ANCHOR: work_queue
const WorkQueue = struct {
    items: std.ArrayList(i32),
    mutex: Thread.Mutex,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) WorkQueue {
        return .{
            .items = std.ArrayList(i32){},
            .mutex = .{},
            .allocator = allocator,
        };
    }

    fn deinit(self: *WorkQueue) void {
        self.items.deinit(self.allocator);
    }

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
        _ = result.fetchAdd(@as(i32, item), .monotonic);
    }
}

test "work queue with multiple workers" {
    var queue = WorkQueue.init(testing.allocator);
    defer queue.deinit();

    // Add work items
    for (1..11) |i| {
        try queue.push(@intCast(i));
    }

    var result = std.atomic.Value(i32).init(0);
    var threads: [4]Thread = undefined;

    // Spawn workers
    for (&threads) |*thread| {
        thread.* = try Thread.spawn(.{}, queueWorker, .{ &queue, &result });
    }

    // Wait for completion
    for (threads) |thread| {
        thread.join();
    }

    try testing.expectEqual(@as(i32, 55), result.load(.monotonic));
}
// ANCHOR_END: work_queue

// ANCHOR: batch_processing
fn processBatch(data: []i32) void {
    for (data) |*item| {
        item.* *= 2;
    }
}

test "batch processing" {
    var data = try testing.allocator.alloc(i32, 1000);
    defer testing.allocator.free(data);

    // Initialize
    for (data, 0..) |*item, i| {
        item.* = @intCast(i);
    }

    // Process in parallel batches
    const num_workers = 4;
    const chunk_size = data.len / num_workers;
    var threads: [4]Thread = undefined;

    for (&threads, 0..) |*thread, i| {
        const start = i * chunk_size;
        const end = if (i == num_workers - 1) data.len else (i + 1) * chunk_size;
        thread.* = try Thread.spawn(.{}, processBatch, .{data[start..end]});
    }

    for (threads) |thread| {
        thread.join();
    }

    // Verify
    for (data, 0..) |value, i| {
        try testing.expectEqual(@as(i32, @intCast(i * 2)), value);
    }
}
// ANCHOR_END: batch_processing

// ANCHOR: optimal_worker_count
test "determining optimal worker count" {
    const cpu_count = try Thread.getCpuCount();

    // For CPU-bound tasks: use CPU count
    const cpu_bound_workers = cpu_count;

    // For I/O-bound tasks: can use more threads
    const io_bound_workers = cpu_count * 2;

    try testing.expect(cpu_bound_workers > 0);
    try testing.expect(io_bound_workers >= cpu_bound_workers);

    std.debug.print("CPU count: {}, CPU-bound workers: {}, I/O-bound workers: {}\n", .{
        cpu_count,
        cpu_bound_workers,
        io_bound_workers,
    });
}
// ANCHOR_END: optimal_worker_count
