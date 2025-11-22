# Recipe 13.13: Putting Limits on Memory and CPU Usage

## Problem

You need to restrict a program's resource usage to prevent runaway memory consumption or excessive CPU time.

## Solution

Create custom allocators that enforce memory limits:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_13.zig:memory_limit_allocator}}
```

## Discussion

Resource limits prevent programs from consuming excessive system resources. This is crucial for sandboxing, quotas, and preventing denial-of-service scenarios.

### Memory Limiting

The `MemoryLimitAllocator` wraps any allocator and tracks memory usage:

**Features:**
- Tracks current memory usage
- Rejects allocations that exceed limit
- Updates usage on resize/free
- Reports percentage used

**Usage:**
```zig
var limited = MemoryLimitAllocator.init(parent_allocator, 1024 * 1024); // 1 MB limit
const allocator = limited.allocator();

const data = try allocator.alloc(u8, 512 * 1024);
defer allocator.free(data);

std.debug.print("Using: {d}%\n", .{limited.percentUsed()});
```

### Timeout Operations

Execute operations with time limits:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_13.zig:timeout_operation}}
```

Timeouts ensure operations complete within acceptable time frames.

### Resource Monitoring

Track both memory and time limits together:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_13.zig:resource_monitor}}
```

Resource monitors check multiple limits at once.

### Limited Worker Pattern

Combine memory and time limits for worker processes:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_13.zig:limited_worker}}
```

This pattern is useful for:
- Worker pools
- Request handlers
- Batch processing
- Plugin systems

### Allocation Tracking

Track allocation statistics for profiling:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_13.zig:allocation_tracker}}
```

Allocation tracking helps identify:
- Memory leaks
- Excessive allocations
- Peak memory usage
- Allocation patterns

### Rate Limiting

Limit operation frequency:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_13.zig:rate_limiter}}
```

Rate limiting prevents:
- API abuse
- Resource exhaustion
- DoS attacks
- Excessive logging

### CPU Time Limiting

Track CPU time usage:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_13.zig:cpu_time_limiter}}
```

CPU time limiters ensure fair scheduling and prevent infinite loops.

## Best Practices

1. **Set reasonable limits** - Too strict causes failures, too loose defeats purpose
2. **Track current usage** - Monitor to detect approaching limits
3. **Fail gracefully** - Return errors instead of crashing
4. **Log limit violations** - Track when and why limits are hit
5. **Make limits configurable** - Different environments need different limits
6. **Test with limits** - Ensure code handles limit errors correctly
7. **Consider overhead** - Allocators have metadata overhead

### Setting Memory Limits

**Application limits:**
```zig
const MEMORY_LIMIT = if (builtin.mode == .Debug)
    100 * 1024 * 1024  // 100 MB for debug
else
    50 * 1024 * 1024;  // 50 MB for release
```

**Per-request limits:**
```zig
const REQUEST_MEMORY_LIMIT = 10 * 1024 * 1024;  // 10 MB per request
```

**Accounting for overhead:**
- Allocators add metadata (typically 8-16 bytes per allocation)
- Alignment padding can increase actual usage
- Internal structures (hash maps, arrays) have overhead
- Set limits 10-20% higher than expected usage

### Timeout Patterns

**Network requests:**
```zig
const timeout_ms = 30000;  // 30 seconds
const limiter = CPUTimeLimiter.init(timeout_ms);

while (true) {
    try limiter.checkLimit();

    const response = try makeRequest();
    if (response.complete) break;

    std.Thread.sleep(100 * std.time.ns_per_ms);
}
```

**User operations:**
```zig
const timeout_ms = 5000;  // 5 seconds for user action
const limiter = CPUTimeLimiter.init(timeout_ms);

while (!operation_complete) {
    try limiter.checkLimit();
    try processStep();
}
```

**Long-running tasks:**
```zig
const timeout_ms = 3600000;  // 1 hour
const limiter = CPUTimeLimiter.init(timeout_ms);

for (items) |item| {
    try limiter.checkLimit();
    try processItem(item);

    if (limiter.remainingMs() < 60000) {  // < 1 minute left
        std.log.warn("Approaching time limit", .{});
    }
}
```

### Combining Limits

**Complete resource control:**
```zig
pub const ResourceLimits = struct {
    memory: MemoryLimitAllocator,
    time: CPUTimeLimiter,
    rate: RateLimiter,

    pub fn init(
        parent_allocator: std.mem.Allocator,
        memory_limit: usize,
        time_limit_ms: u64,
        rate_limit: usize,
    ) !ResourceLimits {
        return .{
            .memory = MemoryLimitAllocator.init(parent_allocator, memory_limit),
            .time = CPUTimeLimiter.init(time_limit_ms),
            .rate = RateLimiter.init(parent_allocator, rate_limit, 1000),
        };
    }

    pub fn checkAll(self: *ResourceLimits) !void {
        try self.time.checkLimit();

        if (!try self.rate.tryAcquire()) {
            return error.RateLimitExceeded;
        }
    }

    pub fn deinit(self: *ResourceLimits) void {
        self.rate.deinit();
    }
};
```

### Error Handling

**Graceful degradation:**
```zig
fn processWithLimits(allocator: std.mem.Allocator, data: []const u8) !void {
    var limited = MemoryLimitAllocator.init(allocator, 10 * 1024 * 1024);
    const limited_allocator = limited.allocator();

    const buffer = limited_allocator.alloc(u8, data.len * 2) catch |err| {
        if (err == error.OutOfMemory) {
            // Fall back to slower in-place processing
            return processInPlace(data);
        }
        return err;
    };
    defer limited_allocator.free(buffer);

    try processFast(buffer, data);
}
```

**User feedback:**
```zig
fn handleRequest(request: Request) !void {
    var limiter = ResourceMonitor.init(allocator, 1024 * 1024, 5000);

    limiter.checkLimits(current_memory) catch |err| switch (err) {
        error.MemoryLimitExceeded => {
            std.log.err("Request exceeded memory limit ({d}% used)", .{
                limiter.memory_limit.?.percentUsed()
            });
            return error.RequestTooLarge;
        },
        error.TimeLimitExceeded => {
            std.log.err("Request timeout after {d}ms", .{limiter.elapsedMs()});
            return error.RequestTimeout;
        },
        else => return err,
    };
}
```

### Platform-Specific Limits

Zig doesn't provide direct OS-level resource limit APIs. Use system calls for production:

**Unix (setrlimit):**
```zig
const c = @cImport({
    @cInclude("sys/resource.h");
});

pub fn setMemoryLimit(bytes: usize) !void {
    var limit = c.rlimit{
        .rlim_cur = bytes,
        .rlim_max = bytes,
    };

    if (c.setrlimit(c.RLIMIT_AS, &limit) != 0) {
        return error.SetLimitFailed;
    }
}

pub fn setCPUTimeLimit(seconds: u64) !void {
    var limit = c.rlimit{
        .rlim_cur = seconds,
        .rlim_max = seconds,
    };

    if (c.setrlimit(c.RLIMIT_CPU, &limit) != 0) {
        return error.SetLimitFailed;
    }
}
```

**Windows (Job Objects):**
```zig
const windows = std.os.windows;

pub fn createLimitedJob(memory_limit: usize) !windows.HANDLE {
    const job = try windows.CreateJobObjectW(null, null);
    errdefer _ = windows.CloseHandle(job);

    var info = std.mem.zeroes(windows.JOBOBJECT_EXTENDED_LIMIT_INFORMATION);
    info.BasicLimitInformation.LimitFlags = windows.JOB_OBJECT_LIMIT_PROCESS_MEMORY;
    info.ProcessMemoryLimit = memory_limit;

    const result = windows.SetInformationJobObject(
        job,
        windows.JobObjectExtendedLimitInformation,
        &info,
        @sizeOf(@TypeOf(info))
    );

    if (result == 0) return error.SetLimitFailed;

    return job;
}
```

### Testing with Limits

**Test limit enforcement:**
```zig
test "memory limit is enforced" {
    var limited = MemoryLimitAllocator.init(testing.allocator, 100);
    const allocator = limited.allocator();

    // Should fail - exceeds limit
    const result = allocator.alloc(u8, 200);
    try testing.expectError(error.OutOfMemory, result);
}

test "time limit is enforced" {
    const limiter = CPUTimeLimiter.init(10);  // 10ms limit

    std.Thread.sleep(20 * std.time.ns_per_ms);

    const result = limiter.checkLimit();
    try testing.expectError(error.CPUTimeLimitExceeded, result);
}
```

**Test cleanup on error:**
```zig
test "resources freed on limit exceeded" {
    var limited = MemoryLimitAllocator.init(testing.allocator, 100);
    const allocator = limited.allocator();

    const buf1 = try allocator.alloc(u8, 50);
    defer allocator.free(buf1);

    // This will fail, but buf1 should still be tracked correctly
    _ = allocator.alloc(u8, 100) catch {};

    try testing.expectEqual(50, limited.currentUsage());
}
```

### Performance Considerations

**Overhead:**
- Memory tracking adds ~5-10% overhead per allocation
- Time checks are cheap (~100ns per check)
- Rate limiting has HashMap overhead

**Optimization:**
- Check limits periodically, not on every operation
- Use batch allocations to reduce tracking overhead
- Cache limit checks for hot loops
- Disable limit checking in release builds if not needed

**Hot path optimization:**
```zig
var check_counter: usize = 0;

for (items) |item| {
    try processItem(item);

    // Check limits every 100 iterations instead of every time
    check_counter += 1;
    if (check_counter >= 100) {
        try limiter.checkLimit();
        check_counter = 0;
    }
}
```

### Monitoring and Alerting

**Log usage patterns:**
```zig
pub fn logResourceUsage(monitor: *const ResourceMonitor, allocator: *const MemoryLimitAllocator) void {
    std.log.info("Resource Usage:", .{});
    std.log.info("  Memory: {d}/{d} bytes ({d:.1}%)", .{
        allocator.currentUsage(),
        allocator.max_bytes,
        allocator.percentUsed(),
    });
    std.log.info("  Time: {d}/{d}ms", .{
        monitor.elapsedMs(),
        if (monitor.time_limit_ns) |limit| @divTrunc(limit, std.time.ns_per_ms) else 0,
    });
}
```

**Metrics collection:**
```zig
pub const ResourceMetrics = struct {
    peak_memory: usize,
    avg_memory: usize,
    total_time_ms: i128,
    limit_violations: usize,

    pub fn update(self: *ResourceMetrics, allocator: *const MemoryLimitAllocator, monitor: *const ResourceMonitor) void {
        const current = allocator.currentUsage();
        if (current > self.peak_memory) {
            self.peak_memory = current;
        }

        self.avg_memory = (self.avg_memory + current) / 2;
        self.total_time_ms = monitor.elapsedMs();
    }
};
```

## See Also

- Recipe 13.10: Adding logging to simple scripts
- Recipe 13.12: Making a stopwatch timer
- Recipe 14.13: Profiling and timing your program

Full compilable example: `code/04-specialized/13-utility-scripting/recipe_13_13.zig`
