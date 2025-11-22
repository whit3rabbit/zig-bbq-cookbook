const std = @import("std");
const testing = std.testing;

// ANCHOR: token_bucket
pub const TokenBucket = struct {
    capacity: usize,
    tokens: usize,
    refill_rate: f64, // tokens per second
    last_refill: i64,
    mutex: std.Thread.Mutex,

    pub fn init(capacity: usize, refill_rate: f64) TokenBucket {
        return .{
            .capacity = capacity,
            .tokens = capacity,
            .refill_rate = refill_rate,
            .last_refill = std.time.timestamp(),
            .mutex = .{},
        };
    }

    pub fn tryConsume(self: *TokenBucket, tokens: usize) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.refill();

        if (self.tokens >= tokens) {
            self.tokens -= tokens;
            return true;
        }
        return false;
    }

    fn refill(self: *TokenBucket) void {
        const now = std.time.timestamp();
        const elapsed = @as(f64, @floatFromInt(now - self.last_refill));

        if (elapsed <= 0) return; // Guard against negative time or no elapsed time

        const tokens_float = elapsed * self.refill_rate;
        if (tokens_float < 0 or tokens_float > @as(f64, @floatFromInt(std.math.maxInt(usize)))) {
            // Overflow or invalid value - fill to capacity
            self.tokens = self.capacity;
            self.last_refill = now;
            return;
        }

        const tokens_to_add = @as(usize, @intFromFloat(tokens_float));
        if (tokens_to_add > 0) {
            self.tokens = @min(self.capacity, self.tokens + tokens_to_add);
            self.last_refill = now;
        }
    }

    pub fn availableTokens(self: *TokenBucket) usize {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.refill();
        return self.tokens;
    }
};
// ANCHOR_END: token_bucket

// ANCHOR: sliding_window
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

    pub fn requestCount(self: *SlidingWindow) usize {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.milliTimestamp();
        self.cleanOldRequests(now) catch return self.requests.items.len;
        return self.requests.items.len;
    }
};
// ANCHOR_END: sliding_window

// ANCHOR: rate_limiter
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
// ANCHOR_END: rate_limiter

// ANCHOR: concurrent_limiter
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
// ANCHOR_END: concurrent_limiter

// ANCHOR: throttler
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

    pub fn timeSinceLastExecution(self: *Throttler) i64 {
        const now = std.time.milliTimestamp();
        const last = self.last_execution.load(.monotonic);
        if (last == 0) return self.min_interval_ms;
        return now - last;
    }
};
// ANCHOR_END: throttler

// ANCHOR: test_token_bucket
test "token bucket basic consumption" {
    var bucket = TokenBucket.init(10, 1.0);

    try testing.expect(bucket.tryConsume(5));
    try testing.expectEqual(@as(usize, 5), bucket.availableTokens());

    try testing.expect(bucket.tryConsume(5));
    try testing.expectEqual(@as(usize, 0), bucket.availableTokens());

    try testing.expect(!bucket.tryConsume(1));
}
// ANCHOR_END: test_token_bucket

// ANCHOR: test_token_bucket_refill
test "token bucket refill" {
    var bucket = TokenBucket.init(10, 10.0); // 10 tokens per second

    try testing.expect(bucket.tryConsume(10));
    try testing.expectEqual(@as(usize, 0), bucket.availableTokens());

    // Wait for refill (simulate by adjusting last_refill)
    bucket.last_refill -= 1; // Simulate 1 second passed

    const available = bucket.availableTokens();
    try testing.expect(available > 0);
}
// ANCHOR_END: test_token_bucket_refill

// ANCHOR: test_sliding_window
test "sliding window basic" {
    var window = SlidingWindow.init(testing.allocator, 1000, 5);
    defer window.deinit();

    // Should allow 5 requests
    try testing.expect(try window.tryRequest());
    try testing.expect(try window.tryRequest());
    try testing.expect(try window.tryRequest());
    try testing.expect(try window.tryRequest());
    try testing.expect(try window.tryRequest());

    // Should reject 6th request
    try testing.expect(!try window.tryRequest());

    try testing.expectEqual(@as(usize, 5), window.requestCount());
}
// ANCHOR_END: test_sliding_window

// ANCHOR: test_sliding_window_cleanup
test "sliding window cleanup old requests" {
    var window = SlidingWindow.init(testing.allocator, 100, 3);
    defer window.deinit();

    try testing.expect(try window.tryRequest());
    try testing.expect(try window.tryRequest());
    try testing.expect(try window.tryRequest());
    try testing.expect(!try window.tryRequest());

    // Simulate time passing
    std.Thread.sleep(150 * std.time.ns_per_ms);

    // Old requests should be cleaned up
    try testing.expect(try window.tryRequest());
}
// ANCHOR_END: test_sliding_window_cleanup

// ANCHOR: test_rate_limiter
test "rate limiter check limit" {
    var limiter = RateLimiter.init(10, 1.0);

    try testing.expect(try limiter.checkLimit(5));
    try testing.expect(try limiter.checkLimit(5));
    try testing.expect(!try limiter.checkLimit(1));
}
// ANCHOR_END: test_rate_limiter

// ANCHOR: test_rate_limiter_headers
test "rate limiter headers" {
    var limiter = RateLimiter.init(100, 10.0);

    _ = try limiter.checkLimit(30);

    const headers = limiter.getRateLimitHeaders();
    try testing.expectEqual(@as(usize, 100), headers.limit);
    try testing.expect(headers.remaining <= 70);
    try testing.expect(headers.reset > std.time.timestamp());
}
// ANCHOR_END: test_rate_limiter_headers

// ANCHOR: test_rate_limiter_wait
test "rate limiter wait for tokens" {
    var limiter = RateLimiter.init(5, 0.1); // Very slow refill

    try testing.expect(try limiter.checkLimit(5));

    // Should timeout since refill rate is very slow
    try testing.expect(!try limiter.waitForTokens(1, 50));
}
// ANCHOR_END: test_rate_limiter_wait

// ANCHOR: test_concurrent_limiter
test "concurrent limiter basic" {
    var limiter = ConcurrentLimiter.init(3);

    try testing.expect(limiter.acquire());
    try testing.expectEqual(@as(usize, 1), limiter.currentCount());

    try testing.expect(limiter.acquire());
    try testing.expectEqual(@as(usize, 2), limiter.currentCount());

    try testing.expect(limiter.acquire());
    try testing.expectEqual(@as(usize, 3), limiter.currentCount());

    try testing.expect(!limiter.acquire());
    try testing.expectEqual(@as(usize, 3), limiter.currentCount());
}
// ANCHOR_END: test_concurrent_limiter

// ANCHOR: test_concurrent_limiter_release
test "concurrent limiter release" {
    var limiter = ConcurrentLimiter.init(2);

    try testing.expect(limiter.acquire());
    try testing.expect(limiter.acquire());
    try testing.expect(!limiter.acquire());

    limiter.release();
    try testing.expectEqual(@as(usize, 1), limiter.currentCount());

    try testing.expect(limiter.acquire());
    try testing.expectEqual(@as(usize, 2), limiter.currentCount());
}
// ANCHOR_END: test_concurrent_limiter_release

// ANCHOR: test_throttler
test "throttler basic" {
    var throttler = Throttler.init(100);

    try testing.expect(throttler.shouldExecute());
    try testing.expect(!throttler.shouldExecute());

    std.Thread.sleep(150 * std.time.ns_per_ms);

    try testing.expect(throttler.shouldExecute());
}
// ANCHOR_END: test_throttler

// ANCHOR: test_throttler_reset
test "throttler reset" {
    var throttler = Throttler.init(1000);

    try testing.expect(throttler.shouldExecute());
    try testing.expect(!throttler.shouldExecute());

    throttler.reset();

    try testing.expect(throttler.shouldExecute());
}
// ANCHOR_END: test_throttler_reset

// ANCHOR: test_throttler_time_since
test "throttler time since last execution" {
    var throttler = Throttler.init(100);

    const initial_time = throttler.timeSinceLastExecution();
    try testing.expectEqual(@as(i64, 100), initial_time);

    try testing.expect(throttler.shouldExecute());

    std.Thread.sleep(50 * std.time.ns_per_ms);

    const elapsed = throttler.timeSinceLastExecution();
    try testing.expect(elapsed >= 50);
    try testing.expect(elapsed < 100);
}
// ANCHOR_END: test_throttler_time_since
