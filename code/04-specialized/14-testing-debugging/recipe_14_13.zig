const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_timing
fn measureFunction() !void {
    const start = std.time.nanoTimestamp();

    // Simulate work
    std.Thread.sleep(1 * std.time.ns_per_ms);

    const end = std.time.nanoTimestamp();
    const elapsed = end - start;

    std.debug.print("Function took {d} nanoseconds ({d:.2} ms)\n", .{
        elapsed,
        @as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms,
    });
}

test "basic timing measurement" {
    try measureFunction();
}
// ANCHOR_END: basic_timing

// ANCHOR: timer_utility
const Timer = struct {
    start_time: i128,
    name: []const u8,

    fn start(name: []const u8) Timer {
        return .{
            .start_time = std.time.nanoTimestamp(),
            .name = name,
        };
    }

    fn stop(self: *const Timer) i128 {
        const elapsed = std.time.nanoTimestamp() - self.start_time;
        std.debug.print("[{s}] Elapsed: {d} ns ({d:.2} ms)\n", .{
            self.name,
            elapsed,
            @as(f64, @floatFromInt(elapsed)) / std.time.ns_per_ms,
        });
        return elapsed;
    }

    fn lap(self: *Timer, label: []const u8) i128 {
        const elapsed = std.time.nanoTimestamp() - self.start_time;
        std.debug.print("[{s}] {s}: {d} ns\n", .{ self.name, label, elapsed });
        self.start_time = std.time.nanoTimestamp(); // Reset for next lap
        return elapsed;
    }
};

test "timer utility" {
    var timer = Timer.start("MyOperation");
    std.Thread.sleep(2 * std.time.ns_per_ms);
    _ = timer.stop();
}
// ANCHOR_END: timer_utility

// ANCHOR: benchmark_comparison
fn algorithmA(n: usize) usize {
    var sum: usize = 0;
    for (0..n) |i| {
        sum += i;
    }
    return sum;
}

fn algorithmB(n: usize) usize {
    return (n * (n - 1)) / 2;
}

fn benchmarkAlgorithms(n: usize) !void {
    const start_a = std.time.nanoTimestamp();
    const result_a = algorithmA(n);
    const time_a = std.time.nanoTimestamp() - start_a;

    const start_b = std.time.nanoTimestamp();
    const result_b = algorithmB(n);
    const time_b = std.time.nanoTimestamp() - start_b;

    std.debug.print("Algorithm A: {d} ns, result: {d}\n", .{ time_a, result_a });
    std.debug.print("Algorithm B: {d} ns, result: {d}\n", .{ time_b, result_b });
    std.debug.print("Speedup: {d:.2}x\n", .{@as(f64, @floatFromInt(time_a)) / @as(f64, @floatFromInt(time_b))});
}

test "benchmark algorithm comparison" {
    try benchmarkAlgorithms(100000);
}
// ANCHOR_END: benchmark_comparison

// ANCHOR: profiling_sections
fn complexOperation() !void {
    var timer = Timer.start("ComplexOp");

    // Section 1
    std.Thread.sleep(1 * std.time.ns_per_ms);
    _ = timer.lap("Section 1: Setup");

    // Section 2
    std.Thread.sleep(3 * std.time.ns_per_ms);
    _ = timer.lap("Section 2: Processing");

    // Section 3
    std.Thread.sleep(1 * std.time.ns_per_ms);
    _ = timer.lap("Section 3: Cleanup");
}

test "profile code sections" {
    try complexOperation();
}
// ANCHOR_END: profiling_sections

// ANCHOR: memory_profiling
const MemoryStats = struct {
    allocations: usize,
    deallocations: usize,
    bytes_allocated: usize,
    bytes_freed: usize,

    fn init() MemoryStats {
        return .{
            .allocations = 0,
            .deallocations = 0,
            .bytes_allocated = 0,
            .bytes_freed = 0,
        };
    }

    fn report(self: MemoryStats) void {
        std.debug.print("Memory Stats:\n", .{});
        std.debug.print("  Allocations: {d}\n", .{self.allocations});
        std.debug.print("  Deallocations: {d}\n", .{self.deallocations});
        std.debug.print("  Bytes allocated: {d}\n", .{self.bytes_allocated});
        std.debug.print("  Bytes freed: {d}\n", .{self.bytes_freed});
        std.debug.print("  Net memory: {d}\n", .{self.bytes_allocated - self.bytes_freed});
    }
};

fn memoryIntensiveOperation(allocator: std.mem.Allocator) !void {
    var stats = MemoryStats.init();

    const buffer1 = try allocator.alloc(u8, 1024);
    stats.allocations += 1;
    stats.bytes_allocated += 1024;

    const buffer2 = try allocator.alloc(u8, 2048);
    stats.allocations += 1;
    stats.bytes_allocated += 2048;

    allocator.free(buffer1);
    stats.deallocations += 1;
    stats.bytes_freed += 1024;

    allocator.free(buffer2);
    stats.deallocations += 1;
    stats.bytes_freed += 2048;

    stats.report();
}

test "memory profiling" {
    try memoryIntensiveOperation(testing.allocator);
}
// ANCHOR_END: memory_profiling

// ANCHOR: iteration_benchmark
fn benchmarkIterations(iterations: usize) !void {
    var sum: usize = 0;
    const start = std.time.nanoTimestamp();

    for (0..iterations) |i| {
        sum +%= i;
    }

    const elapsed = std.time.nanoTimestamp() - start;
    const per_iter = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(iterations));

    std.debug.print("Iterations: {d}\n", .{iterations});
    std.debug.print("Total time: {d} ns\n", .{elapsed});
    std.debug.print("Per iteration: {d:.2} ns\n", .{per_iter});
    std.debug.print("Throughput: {d:.2} M ops/sec\n", .{
        @as(f64, @floatFromInt(iterations)) / @as(f64, @floatFromInt(elapsed)) * 1000.0,
    });
}

test "benchmark iterations" {
    try benchmarkIterations(1_000_000);
}
// ANCHOR_END: iteration_benchmark

// ANCHOR: warmup_benchmark
fn runBenchmarkWithWarmup(comptime func: fn () usize, warmup_runs: usize, measured_runs: usize) !void {
    // Warmup phase
    for (0..warmup_runs) |_| {
        _ = func();
    }

    // Measurement phase
    const start = std.time.nanoTimestamp();
    for (0..measured_runs) |_| {
        _ = func();
    }
    const elapsed = std.time.nanoTimestamp() - start;

    const avg = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(measured_runs));
    std.debug.print("Average per run: {d:.2} ns ({d} runs after {d} warmup)\n", .{
        avg,
        measured_runs,
        warmup_runs,
    });
}

fn benchmarkedFunction() usize {
    var sum: usize = 0;
    for (0..1000) |i| {
        sum +%= i * i;
    }
    return sum;
}

test "benchmark with warmup" {
    try runBenchmarkWithWarmup(benchmarkedFunction, 100, 1000);
}
// ANCHOR_END: warmup_benchmark

// ANCHOR: statistical_benchmark
const BenchmarkStats = struct {
    samples: []i128,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, capacity: usize) !BenchmarkStats {
        return .{
            .samples = try allocator.alloc(i128, capacity),
            .allocator = allocator,
        };
    }

    fn deinit(self: *BenchmarkStats) void {
        self.allocator.free(self.samples);
    }

    fn addSample(self: *BenchmarkStats, index: usize, value: i128) void {
        self.samples[index] = value;
    }

    fn analyze(self: *const BenchmarkStats) void {
        var min = self.samples[0];
        var max = self.samples[0];
        var sum: i128 = 0;

        for (self.samples) |sample| {
            if (sample < min) min = sample;
            if (sample > max) max = sample;
            sum += sample;
        }

        const avg = @divTrunc(sum, @as(i128, @intCast(self.samples.len)));

        std.debug.print("Benchmark Statistics:\n", .{});
        std.debug.print("  Samples: {d}\n", .{self.samples.len});
        std.debug.print("  Min: {d} ns\n", .{min});
        std.debug.print("  Max: {d} ns\n", .{max});
        std.debug.print("  Avg: {d} ns\n", .{avg});
        std.debug.print("  Range: {d} ns\n", .{max - min});
    }
};

test "statistical benchmarking" {
    const runs = 10;
    var stats = try BenchmarkStats.init(testing.allocator, runs);
    defer stats.deinit();

    for (0..runs) |i| {
        const start = std.time.nanoTimestamp();
        _ = benchmarkedFunction();
        const elapsed = std.time.nanoTimestamp() - start;
        stats.addSample(i, elapsed);
    }

    stats.analyze();
}
// ANCHOR_END: statistical_benchmark

// ANCHOR: allocation_tracking
const TrackingAllocator = struct {
    parent_allocator: std.mem.Allocator,
    allocation_count: usize,
    deallocation_count: usize,
    bytes_allocated: usize,

    fn init(parent: std.mem.Allocator) TrackingAllocator {
        return .{
            .parent_allocator = parent,
            .allocation_count = 0,
            .deallocation_count = 0,
            .bytes_allocated = 0,
        };
    }

    fn allocator(self: *TrackingAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
                .remap = remap,
            },
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, ptr_align: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        self.allocation_count += 1;
        self.bytes_allocated += len;
        return self.parent_allocator.rawAlloc(len, ptr_align, ret_addr);
    }

    fn resize(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        return self.parent_allocator.rawResize(buf, buf_align, new_len, ret_addr);
    }

    fn free(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, ret_addr: usize) void {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        self.deallocation_count += 1;
        self.parent_allocator.rawFree(buf, buf_align, ret_addr);
    }

    fn remap(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        return self.parent_allocator.rawRemap(buf, buf_align, new_len, ret_addr);
    }

    fn report(self: *const TrackingAllocator) void {
        std.debug.print("Allocation Tracking:\n", .{});
        std.debug.print("  Allocations: {d}\n", .{self.allocation_count});
        std.debug.print("  Deallocations: {d}\n", .{self.deallocation_count});
        std.debug.print("  Bytes allocated: {d}\n", .{self.bytes_allocated});
    }
};

test "allocation tracking" {
    var tracking = TrackingAllocator.init(testing.allocator);
    const allocator = tracking.allocator();

    const buffer1 = try allocator.alloc(u8, 100);
    defer allocator.free(buffer1);

    const buffer2 = try allocator.alloc(u8, 200);
    defer allocator.free(buffer2);

    tracking.report();
}
// ANCHOR_END: allocation_tracking

// ANCHOR: throughput_measurement
fn measureThroughput(data_size: usize, iterations: usize) !void {
    var sum: usize = 0;
    const start = std.time.nanoTimestamp();

    for (0..iterations) |_| {
        for (0..data_size) |i| {
            sum +%= i;
        }
    }

    const elapsed = std.time.nanoTimestamp() - start;
    const total_bytes = data_size * iterations * @sizeOf(usize);
    const throughput_mbps = @as(f64, @floatFromInt(total_bytes)) /
                            @as(f64, @floatFromInt(elapsed)) * 1000.0;

    std.debug.print("Throughput: {d:.2} MB/s\n", .{throughput_mbps});
    std.debug.print("Total data: {d} bytes in {d} ns\n", .{ total_bytes, elapsed });
}

test "throughput measurement" {
    try measureThroughput(10000, 100);
}
// ANCHOR_END: throughput_measurement
