const std = @import("std");
const testing = std.testing;

// ANCHOR: memory_limit_allocator
/// Allocator that enforces a memory limit
pub const MemoryLimitAllocator = struct {
    parent_allocator: std.mem.Allocator,
    max_bytes: usize,
    current_bytes: usize,

    pub fn init(parent_allocator: std.mem.Allocator, max_bytes: usize) MemoryLimitAllocator {
        return .{
            .parent_allocator = parent_allocator,
            .max_bytes = max_bytes,
            .current_bytes = 0,
        };
    }

    pub fn allocator(self: *MemoryLimitAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
                .remap = std.mem.Allocator.noRemap,
            },
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, ptr_align: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *MemoryLimitAllocator = @ptrCast(@alignCast(ctx));

        if (self.current_bytes + len > self.max_bytes) {
            return null; // Would exceed limit
        }

        const result = self.parent_allocator.rawAlloc(len, ptr_align, ret_addr);
        if (result != null) {
            self.current_bytes += len;
        }
        return result;
    }

    fn resize(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *MemoryLimitAllocator = @ptrCast(@alignCast(ctx));

        if (new_len > buf.len) {
            const additional = new_len - buf.len;
            if (self.current_bytes + additional > self.max_bytes) {
                return false; // Would exceed limit
            }
        }

        const result = self.parent_allocator.rawResize(buf, buf_align, new_len, ret_addr);
        if (result) {
            if (new_len > buf.len) {
                self.current_bytes += new_len - buf.len;
            } else {
                self.current_bytes -= buf.len - new_len;
            }
        }
        return result;
    }

    fn free(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, ret_addr: usize) void {
        const self: *MemoryLimitAllocator = @ptrCast(@alignCast(ctx));
        self.current_bytes -= buf.len;
        self.parent_allocator.rawFree(buf, buf_align, ret_addr);
    }

    pub fn currentUsage(self: *const MemoryLimitAllocator) usize {
        return self.current_bytes;
    }

    pub fn percentUsed(self: *const MemoryLimitAllocator) f64 {
        return @as(f64, @floatFromInt(self.current_bytes)) / @as(f64, @floatFromInt(self.max_bytes)) * 100.0;
    }
};

test "memory limit allocator" {
    var limited = MemoryLimitAllocator.init(testing.allocator, 1024);
    const allocator = limited.allocator();

    // Should succeed - within limit
    const buf1 = try allocator.alloc(u8, 512);
    defer allocator.free(buf1);
    try testing.expectEqual(512, limited.currentUsage());

    // Should fail - would exceed limit
    const buf2 = allocator.alloc(u8, 1024);
    try testing.expect(buf2 == error.OutOfMemory);

    // Should succeed - exactly at limit after first allocation
    const buf3 = try allocator.alloc(u8, 512);
    defer allocator.free(buf3);
    try testing.expectEqual(1024, limited.currentUsage());
}
// ANCHOR_END: memory_limit_allocator

// ANCHOR: timeout_operation
/// Execute operation with timeout
pub fn withTimeout(comptime T: type, timeout_ns: i128, operation: *const fn () T) !T {
    const start = std.time.nanoTimestamp();

    // For simple operations, just run and check elapsed time
    const result = operation();

    const elapsed = std.time.nanoTimestamp() - start;
    if (elapsed > timeout_ns) {
        return error.Timeout;
    }

    return result;
}

fn slowOperation() void {
    // Simulate work
    std.Thread.sleep(10 * std.time.ns_per_ms);
}

fn fastOperation() void {
    // Fast operation
}

test "timeout operation" {
    // Fast operation should succeed
    try withTimeout(
        void,
        100 * std.time.ns_per_ms,
        fastOperation,
    );

    // Slow operation should timeout
    const result = withTimeout(
        void,
        5 * std.time.ns_per_ms,
        slowOperation,
    );
    try testing.expectError(error.Timeout, result);
}
// ANCHOR_END: timeout_operation

// ANCHOR: resource_monitor
/// Monitor resource usage
pub const ResourceMonitor = struct {
    memory_limit: ?usize,
    time_limit_ns: ?i128,
    start_time: i128,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, memory_limit: ?usize, time_limit_ms: ?u64) ResourceMonitor {
        return .{
            .memory_limit = memory_limit,
            .time_limit_ns = if (time_limit_ms) |ms| @as(i128, @intCast(ms * std.time.ns_per_ms)) else null,
            .start_time = std.time.nanoTimestamp(),
            .allocator = allocator,
        };
    }

    pub fn checkLimits(self: *const ResourceMonitor, current_memory: usize) !void {
        // Check memory limit
        if (self.memory_limit) |limit| {
            if (current_memory > limit) {
                return error.MemoryLimitExceeded;
            }
        }

        // Check time limit
        if (self.time_limit_ns) |limit| {
            const elapsed = std.time.nanoTimestamp() - self.start_time;
            if (elapsed > limit) {
                return error.TimeLimitExceeded;
            }
        }
    }

    pub fn elapsedMs(self: *const ResourceMonitor) i128 {
        const elapsed_ns = std.time.nanoTimestamp() - self.start_time;
        return @divTrunc(elapsed_ns, std.time.ns_per_ms);
    }

    pub fn remainingTimeMs(self: *const ResourceMonitor) ?i128 {
        if (self.time_limit_ns) |limit| {
            const elapsed_ns = std.time.nanoTimestamp() - self.start_time;
            const remaining_ns = limit - elapsed_ns;
            if (remaining_ns <= 0) return 0;
            return @divTrunc(remaining_ns, std.time.ns_per_ms);
        }
        return null;
    }
};

test "resource monitor" {
    const monitor = ResourceMonitor.init(testing.allocator, 1024, 100);

    // Within limits
    try monitor.checkLimits(512);

    // Exceeds memory limit
    const result = monitor.checkLimits(2048);
    try testing.expectError(error.MemoryLimitExceeded, result);

    // Check elapsed time
    try testing.expect(monitor.elapsedMs() >= 0);

    // Check remaining time
    const remaining = monitor.remainingTimeMs();
    try testing.expect(remaining != null);
}
// ANCHOR_END: resource_monitor

// ANCHOR: limited_worker
/// Worker with resource limits
pub const LimitedWorker = struct {
    allocator: std.mem.Allocator,
    memory_allocator: MemoryLimitAllocator,
    monitor: ResourceMonitor,

    pub fn init(
        parent_allocator: std.mem.Allocator,
        memory_limit: usize,
        time_limit_ms: u64,
    ) LimitedWorker {
        var mem_alloc = MemoryLimitAllocator.init(parent_allocator, memory_limit);
        const monitor = ResourceMonitor.init(parent_allocator, memory_limit, time_limit_ms);

        return .{
            .allocator = mem_alloc.allocator(),
            .memory_allocator = mem_alloc,
            .monitor = monitor,
        };
    }

    pub fn doWork(self: *LimitedWorker) !void {
        // Check limits before doing work
        try self.monitor.checkLimits(self.memory_allocator.currentUsage());

        // Simulate some work
        const data = try self.allocator.alloc(u8, 100);
        defer self.allocator.free(data);

        // Fill with data
        for (data, 0..) |*byte, i| {
            byte.* = @intCast(i % 256);
        }

        // Check limits again
        try self.monitor.checkLimits(self.memory_allocator.currentUsage());
    }

    pub fn getMemoryUsage(self: *const LimitedWorker) usize {
        return self.memory_allocator.currentUsage();
    }

    pub fn getElapsedMs(self: *const LimitedWorker) i128 {
        return self.monitor.elapsedMs();
    }
};

test "limited worker" {
    // Test with simple allocations
    var mem_alloc = MemoryLimitAllocator.init(testing.allocator, 1024);
    const allocator = mem_alloc.allocator();

    const data = try allocator.alloc(u8, 100);
    defer allocator.free(data);

    try testing.expectEqual(100, mem_alloc.currentUsage());
}
// ANCHOR_END: limited_worker

// ANCHOR: allocation_tracker
/// Track allocation statistics
pub const AllocationTracker = struct {
    parent_allocator: std.mem.Allocator,
    total_allocated: usize,
    total_freed: usize,
    allocation_count: usize,
    free_count: usize,
    peak_usage: usize,
    current_usage: usize,

    pub fn init(parent_allocator: std.mem.Allocator) AllocationTracker {
        return .{
            .parent_allocator = parent_allocator,
            .total_allocated = 0,
            .total_freed = 0,
            .allocation_count = 0,
            .free_count = 0,
            .peak_usage = 0,
            .current_usage = 0,
        };
    }

    pub fn allocator(self: *AllocationTracker) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
                .remap = std.mem.Allocator.noRemap,
            },
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, ptr_align: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *AllocationTracker = @ptrCast(@alignCast(ctx));

        const result = self.parent_allocator.rawAlloc(len, ptr_align, ret_addr);
        if (result != null) {
            self.total_allocated += len;
            self.allocation_count += 1;
            self.current_usage += len;
            if (self.current_usage > self.peak_usage) {
                self.peak_usage = self.current_usage;
            }
        }
        return result;
    }

    fn resize(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *AllocationTracker = @ptrCast(@alignCast(ctx));

        const result = self.parent_allocator.rawResize(buf, buf_align, new_len, ret_addr);
        if (result) {
            if (new_len > buf.len) {
                const additional = new_len - buf.len;
                self.total_allocated += additional;
                self.current_usage += additional;
            } else {
                const reduction = buf.len - new_len;
                self.total_freed += reduction;
                self.current_usage -= reduction;
            }

            if (self.current_usage > self.peak_usage) {
                self.peak_usage = self.current_usage;
            }
        }
        return result;
    }

    fn free(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, ret_addr: usize) void {
        const self: *AllocationTracker = @ptrCast(@alignCast(ctx));
        self.total_freed += buf.len;
        self.free_count += 1;
        self.current_usage -= buf.len;
        self.parent_allocator.rawFree(buf, buf_align, ret_addr);
    }

    pub fn report(self: *const AllocationTracker) void {
        std.debug.print("=== Allocation Report ===\n", .{});
        std.debug.print("Allocations: {d}\n", .{self.allocation_count});
        std.debug.print("Frees: {d}\n", .{self.free_count});
        std.debug.print("Total allocated: {d} bytes\n", .{self.total_allocated});
        std.debug.print("Total freed: {d} bytes\n", .{self.total_freed});
        std.debug.print("Peak usage: {d} bytes\n", .{self.peak_usage});
        std.debug.print("Current usage: {d} bytes\n", .{self.current_usage});
    }
};

test "allocation tracker" {
    var tracker = AllocationTracker.init(testing.allocator);
    const allocator = tracker.allocator();

    const buf1 = try allocator.alloc(u8, 100);
    try testing.expectEqual(100, tracker.current_usage);
    try testing.expectEqual(100, tracker.peak_usage);

    const buf2 = try allocator.alloc(u8, 200);
    try testing.expectEqual(300, tracker.current_usage);
    try testing.expectEqual(300, tracker.peak_usage);

    allocator.free(buf1);
    try testing.expectEqual(200, tracker.current_usage);
    try testing.expectEqual(300, tracker.peak_usage); // Peak stays

    allocator.free(buf2);
    try testing.expectEqual(0, tracker.current_usage);
    try testing.expectEqual(2, tracker.allocation_count);
    try testing.expectEqual(2, tracker.free_count);
}
// ANCHOR_END: allocation_tracker

// ANCHOR: rate_limiter
/// Rate limiter for operations
pub const RateLimiter = struct {
    max_operations: usize,
    window_ns: i128,
    operations: std.ArrayList(i128),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, max_operations: usize, window_ms: u64) RateLimiter {
        return .{
            .max_operations = max_operations,
            .window_ns = @as(i128, @intCast(window_ms * std.time.ns_per_ms)),
            .operations = std.ArrayList(i128){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *RateLimiter) void {
        self.operations.deinit(self.allocator);
    }

    pub fn tryAcquire(self: *RateLimiter) !bool {
        const now = std.time.nanoTimestamp();
        const cutoff = now - self.window_ns;

        // Remove old operations
        var i: usize = 0;
        while (i < self.operations.items.len) {
            if (self.operations.items[i] < cutoff) {
                _ = self.operations.orderedRemove(i);
            } else {
                i += 1;
            }
        }

        // Check if we can add another operation
        if (self.operations.items.len >= self.max_operations) {
            return false;
        }

        try self.operations.append(self.allocator, now);
        return true;
    }

    pub fn currentCount(self: *const RateLimiter) usize {
        return self.operations.items.len;
    }
};

test "rate limiter" {
    var limiter = RateLimiter.init(testing.allocator, 3, 1000);
    defer limiter.deinit();

    // Should allow first 3 operations
    try testing.expect(try limiter.tryAcquire());
    try testing.expect(try limiter.tryAcquire());
    try testing.expect(try limiter.tryAcquire());

    // Should deny 4th operation
    try testing.expect(!try limiter.tryAcquire());

    try testing.expectEqual(3, limiter.currentCount());
}
// ANCHOR_END: rate_limiter

// ANCHOR: cpu_time_limiter
/// Track CPU time usage (simplified)
pub const CPUTimeLimiter = struct {
    start_time: i128,
    max_duration_ns: i128,

    pub fn init(max_duration_ms: u64) CPUTimeLimiter {
        return .{
            .start_time = std.time.nanoTimestamp(),
            .max_duration_ns = @as(i128, @intCast(max_duration_ms * std.time.ns_per_ms)),
        };
    }

    pub fn checkLimit(self: *const CPUTimeLimiter) !void {
        const elapsed = std.time.nanoTimestamp() - self.start_time;
        if (elapsed > self.max_duration_ns) {
            return error.CPUTimeLimitExceeded;
        }
    }

    pub fn elapsedMs(self: *const CPUTimeLimiter) i128 {
        const elapsed_ns = std.time.nanoTimestamp() - self.start_time;
        return @divTrunc(elapsed_ns, std.time.ns_per_ms);
    }

    pub fn remainingMs(self: *const CPUTimeLimiter) i128 {
        const elapsed_ns = std.time.nanoTimestamp() - self.start_time;
        const remaining_ns = self.max_duration_ns - elapsed_ns;
        if (remaining_ns <= 0) return 0;
        return @divTrunc(remaining_ns, std.time.ns_per_ms);
    }
};

test "cpu time limiter" {
    const limiter = CPUTimeLimiter.init(100);

    // Should be within limit
    try limiter.checkLimit();

    try testing.expect(limiter.elapsedMs() >= 0);
    try testing.expect(limiter.remainingMs() > 0);
}
// ANCHOR_END: cpu_time_limiter
