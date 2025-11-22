## Problem

You need to control the rate of requests or operations to prevent resource exhaustion, ensure fair usage, and protect your services from abuse or overload.

## Solution

Zig provides excellent support for concurrent programming with atomics and mutexes. This recipe demonstrates four rate limiting patterns: token bucket, sliding window, concurrent request limiting, and request throttling.

### Token Bucket Algorithm

The token bucket is a classic rate limiting algorithm that refills tokens at a steady rate:

```zig
{{#include ../../../code/04-specialized/11-network-web/recipe_11_10.zig:token_bucket}}
```

### Sliding Window Rate Limiting

Sliding windows track exact request timestamps for precise rate limiting:

```zig
pub const SlidingWindow = struct {
    window_size_ms: i64,
    max_requests: usize,
    requests: std.ArrayList(i64),
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator, window_size_ms: i64, max_requests: usize) SlidingWindow {
        return .{
            .window_size_ms = window_size_ms,
            .max_requests = max_requests,
            .requests = std.ArrayList(i64){},
            .allocator = allocator,
            .mutex = .{},
        };
    }

    pub fn deinit(self: *SlidingWindow) void {
        self.requests.deinit(self.allocator);
    }

    pub fn tryRequest(self: *SlidingWindow) !bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.milliTimestamp();
        try self.cleanOldRequests(now);

        if (self.requests.items.len < self.max_requests) {
            try self.requests.append(self.allocator, now);
            return true;
        }
        return false;
    }

    fn cleanOldRequests(self: *SlidingWindow, now: i64) !void {
        const cutoff = now - self.window_size_ms;
        var i: usize = 0;
        while (i < self.requests.items.len) {
            if (self.requests.items[i] < cutoff) {
                _ = self.requests.orderedRemove(i);
            } else {
                i += 1;
            }
        }
    }
};
```

### Rate Limiter with HTTP Headers

Wrapper around token bucket that provides standard HTTP rate limit headers:

```zig
pub const RateLimiter = struct {
    token_bucket: TokenBucket,

    pub fn init(capacity: usize, refill_rate: f64) RateLimiter {
        return .{
            .token_bucket = TokenBucket.init(capacity, refill_rate),
        };
    }

    pub fn checkLimit(self: *RateLimiter, tokens: usize) !bool {
        return self.token_bucket.tryConsume(tokens);
    }

    pub fn waitForTokens(self: *RateLimiter, tokens: usize, timeout_ms: u64) !bool {
        const start = std.time.milliTimestamp();
        while (true) {
            if (self.token_bucket.tryConsume(tokens)) {
                return true;
            }

            const elapsed = @as(u64, @intCast(std.time.milliTimestamp() - start));
            if (elapsed >= timeout_ms) {
                return false;
            }

            std.Thread.sleep(10 * std.time.ns_per_ms);
        }
    }

    pub fn getRateLimitHeaders(self: *RateLimiter) RateLimitHeaders {
        const remaining = self.token_bucket.availableTokens();
        const reset_time = std.time.timestamp() + 60; // Reset in 1 minute

        return .{
            .limit = self.token_bucket.capacity,
            .remaining = remaining,
            .reset = reset_time,
        };
    }
};

pub const RateLimitHeaders = struct {
    limit: usize,
    remaining: usize,
    reset: i64,
};
```

### Concurrent Request Limiter

Limits the number of simultaneous in-flight requests using atomic operations:

```zig
pub const ConcurrentLimiter = struct {
    max_concurrent: usize,
    current: std.atomic.Value(usize),

    pub fn init(max_concurrent: usize) ConcurrentLimiter {
        return .{
            .max_concurrent = max_concurrent,
            .current = std.atomic.Value(usize).init(0),
        };
    }

    pub fn acquire(self: *ConcurrentLimiter) bool {
        while (true) {
            const current = self.current.load(.monotonic);
            if (current >= self.max_concurrent) {
                return false;
            }

            if (self.current.cmpxchgWeak(
                current,
                current + 1,
                .monotonic,
                .monotonic,
            ) == null) {
                return true;
            }
        }
    }

    pub fn release(self: *ConcurrentLimiter) void {
        const prev = self.current.fetchSub(1, .monotonic);
        std.debug.assert(prev > 0); // Catch double-release in debug mode
    }

    pub fn currentCount(self: *ConcurrentLimiter) usize {
        return self.current.load(.monotonic);
    }
};
```

### Request Throttler

Enforces minimum time intervals between operations:

```zig
pub const Throttler = struct {
    min_interval_ms: i64,
    last_execution: std.atomic.Value(i64),

    pub fn init(min_interval_ms: i64) Throttler {
        return .{
            .min_interval_ms = min_interval_ms,
            .last_execution = std.atomic.Value(i64).init(0),
        };
    }

    pub fn shouldExecute(self: *Throttler) bool {
        const now = std.time.milliTimestamp();
        const last = self.last_execution.load(.monotonic);
        const elapsed = now - last;

        if (elapsed >= self.min_interval_ms) {
            if (self.last_execution.cmpxchgWeak(
                last,
                now,
                .monotonic,
                .monotonic,
            ) == null) {
                return true;
            }
        }
        return false;
    }

    pub fn reset(self: *Throttler) void {
        self.last_execution.store(0, .monotonic);
    }
};
```

## Discussion

This recipe demonstrates various rate limiting strategies, each suitable for different use cases.

### Token Bucket Algorithm

The token bucket allows controlled bursts while maintaining an average rate:

**How it works:**
1. Bucket starts full with `capacity` tokens
2. Tokens refill at `refill_rate` per second
3. Each operation consumes tokens
4. Operations are rejected when no tokens available

**Advantages:**
- Allows bursts up to capacity
- Smooth long-term rate limiting
- Memory efficient (constant space)

**Best for:**
- API rate limiting
- Network bandwidth control
- Resource consumption limits

**Thread Safety:**
Token bucket uses `std.Thread.Mutex` to protect shared state. The `refill()` method calculates tokens based on elapsed time, making it safe even if called from multiple threads.

**Overflow Protection:**
The implementation includes bounds checking to prevent integer truncation:
```zig
if (tokens_float < 0 or tokens_float > @as(f64, @floatFromInt(std.math.maxInt(usize)))) {
    self.tokens = self.capacity;
    self.last_refill = now;
    return;
}
```

This guards against system clock changes or extremely high refill rates.

### Sliding Window Algorithm

Sliding windows provide exact request counting over a time period:

**How it works:**
1. Store timestamp of each request
2. Remove requests older than window size
3. Accept requests if count under limit

**Advantages:**
- Exact rate limiting (no burst tolerance)
- Fair distribution across time window
- Predictable behavior

**Disadvantages:**
- Memory grows with request rate
- O(n) cleanup per request (can be optimized)

**Best for:**
- Strict rate limits without bursts
- User quota enforcement
- Request logging with limits

**Memory Considerations:**
In production, consider adding cleanup strategies:
- Maximum stored timestamps
- Periodic background cleanup
- Alternative data structures (circular buffer)

### Concurrent Request Limiting

Limits simultaneous in-flight operations using lock-free atomics:

**How it works:**
1. Atomic counter tracks current operations
2. `acquire()` uses compare-exchange to increment
3. `release()` decrements when operation completes

**Lock-Free Design:**
```zig
while (true) {
    const current = self.current.load(.monotonic);
    if (current >= self.max_concurrent) {
        return false;
    }

    if (self.current.cmpxchgWeak(current, current + 1, .monotonic, .monotonic) == null) {
        return true;
    }
}
```

The `cmpxchgWeak` operation atomically checks if the value is still `current` and updates it to `current + 1`. If another thread modified it, the loop retries.

**Safety:**
The `release()` method includes a debug assert to catch double-release bugs:
```zig
const prev = self.current.fetchSub(1, .monotonic);
std.debug.assert(prev > 0);
```

In debug builds, this will panic if release is called without a matching acquire.

**Best for:**
- Connection pooling
- Worker thread limits
- Database connection limits
- File handle management

### Request Throttling

Enforces minimum intervals between operations:

**How it works:**
1. Stores timestamp of last execution
2. Checks elapsed time since last execution
3. Updates timestamp atomically on success

**Lock-Free Implementation:**
Uses atomic compare-exchange to prevent race conditions when multiple threads try to execute simultaneously.

**Best for:**
- Protecting slow operations
- Log rate limiting
- API call throttling
- Event debouncing

### Choosing a Strategy

**Use Token Bucket when:**
- You want to allow controlled bursts
- Average rate matters more than instantaneous rate
- You need memory-efficient rate limiting

**Use Sliding Window when:**
- You need exact rate limits
- Bursts should be prevented
- You can afford the memory overhead

**Use Concurrent Limiter when:**
- Limiting simultaneous operations
- Protecting shared resources
- Managing connection pools

**Use Throttler when:**
- Operations should not execute too frequently
- You need simple minimum interval enforcement
- Debouncing user actions

### HTTP Rate Limit Headers

The `RateLimitHeaders` struct provides standard HTTP headers:

```text
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 42
X-RateLimit-Reset: 1609459200
```

These headers inform clients about:
- Total rate limit (`limit`)
- Remaining requests (`remaining`)
- When limit resets (`reset` timestamp)

### Production Considerations

**Time Source:**
This implementation uses `std.time.timestamp()` and `std.time.milliTimestamp()` which can be affected by system clock changes. For production:
- Use monotonic clocks when available
- Handle backward time jumps gracefully
- Consider timer-based refill instead of on-demand

**Distributed Rate Limiting:**
For multi-server deployments:
- Use Redis or similar for shared state
- Implement distributed token buckets
- Consider eventual consistency trade-offs

**Monitoring:**
Track these metrics:
- Rate limit rejections
- Average token consumption
- Concurrent request peaks
- Throttle activation frequency

**Configuration:**
Make limits configurable per:
- User tier (free vs paid)
- API endpoint
- Time of day
- Geographic region

### Atomic Memory Ordering

This code uses `.monotonic` memory ordering for atomics:

```zig
const current = self.current.load(.monotonic);
```

**Monotonic ordering** guarantees:
- No reordering of monotonic operations
- Lighter weight than sequential consistency
- Sufficient for counters and simple state

For more complex scenarios, consider:
- `.acquire` / `.release` for lock-like patterns
- `.acq_rel` for read-modify-write
- `.seq_cst` when full ordering needed

### Error Handling

The sliding window's `tryRequest()` can return errors from ArrayList operations:

```zig
pub fn tryRequest(self: *SlidingWindow) !bool {
    try self.requests.append(self.allocator, now);
    return true;
}
```

Callers should handle allocation failures appropriately, perhaps by temporarily rejecting requests during OOM conditions.

## See Also

- Recipe 11.4: Building a simple HTTP server
- Recipe 11.6: Working with REST APIs

Full compilable example: `code/04-specialized/11-network-web/recipe_11_10.zig`
