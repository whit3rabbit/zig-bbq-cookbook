const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_stopwatch
/// Simple stopwatch for timing operations
pub const Stopwatch = struct {
    start_time: i128,
    is_running: bool,

    pub fn start() Stopwatch {
        return .{
            .start_time = std.time.nanoTimestamp(),
            .is_running = true,
        };
    }

    pub fn elapsed(self: *const Stopwatch) i128 {
        if (!self.is_running) return 0;
        return std.time.nanoTimestamp() - self.start_time;
    }

    pub fn elapsedMs(self: *const Stopwatch) i64 {
        return @intCast(@divFloor(self.elapsed(), std.time.ns_per_ms));
    }

    pub fn elapsedSec(self: *const Stopwatch) f64 {
        return @as(f64, @floatFromInt(self.elapsed())) / @as(f64, @floatFromInt(std.time.ns_per_s));
    }

    pub fn stop(self: *Stopwatch) i128 {
        if (!self.is_running) return 0;
        const elapsed_time = std.time.nanoTimestamp() - self.start_time;
        self.is_running = false;
        return elapsed_time;
    }
};

test "basic stopwatch" {
    var sw = Stopwatch.start();
    try testing.expect(sw.is_running);

    var i: usize = 0;
    var sum: usize = 0;
    while (i < 10000) : (i += 1) {
        sum +%= i;
    }
    std.mem.doNotOptimizeAway(&sum);

    const elapsed_ns = sw.elapsed();
    try testing.expect(elapsed_ns >= 0);

    const elapsed_ms = sw.elapsedMs();
    try testing.expect(elapsed_ms >= 0);

    const stopped = sw.stop();
    try testing.expect(stopped >= 0);
    try testing.expect(!sw.is_running);
}
// ANCHOR_END: basic_stopwatch

// ANCHOR: lap_timer
/// Timer with lap functionality
pub const LapTimer = struct {
    start_time: i128,
    last_lap: i128,
    laps: std.ArrayList(i128),
    allocator: std.mem.Allocator,

    pub fn start(allocator: std.mem.Allocator) LapTimer {
        const now = std.time.nanoTimestamp();
        return .{
            .start_time = now,
            .last_lap = now,
            .laps = std.ArrayList(i128){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LapTimer) void {
        self.laps.deinit(self.allocator);
    }

    pub fn lap(self: *LapTimer) !i128 {
        const now = std.time.nanoTimestamp();
        const lap_time = now - self.last_lap;
        try self.laps.append(self.allocator, lap_time);
        self.last_lap = now;
        return lap_time;
    }

    pub fn total(self: *const LapTimer) i128 {
        return std.time.nanoTimestamp() - self.start_time;
    }

    pub fn getLaps(self: *const LapTimer) []const i128 {
        return self.laps.items;
    }
};

test "lap timer" {
    var timer = LapTimer.start(testing.allocator);
    defer timer.deinit();

    var i: usize = 0;
    var sum: usize = 0;
    while (i < 1000) : (i += 1) {
        sum +%= i;
    }
    std.mem.doNotOptimizeAway(&sum);

    const lap1 = try timer.lap();
    try testing.expect(lap1 >= 0);

    const lap2 = try timer.lap();
    try testing.expect(lap2 >= 0);

    const laps = timer.getLaps();
    try testing.expectEqual(2, laps.len);

    const total_time = timer.total();
    try testing.expect(total_time >= 0);
}
// ANCHOR_END: lap_timer

// ANCHOR: pausable_timer
/// Timer that can be paused and resumed
pub const PausableTimer = struct {
    start_time: i128,
    pause_time: i128,
    total_paused: i128,
    is_paused: bool,
    is_running: bool,

    pub fn start() PausableTimer {
        return .{
            .start_time = std.time.nanoTimestamp(),
            .pause_time = 0,
            .total_paused = 0,
            .is_paused = false,
            .is_running = true,
        };
    }

    pub fn pause(self: *PausableTimer) void {
        if (!self.is_running or self.is_paused) return;
        self.pause_time = std.time.nanoTimestamp();
        self.is_paused = true;
    }

    pub fn unpause(self: *PausableTimer) void {
        if (!self.is_running or !self.is_paused) return;
        const now = std.time.nanoTimestamp();
        self.total_paused += now - self.pause_time;
        self.is_paused = false;
    }

    pub fn elapsed(self: *const PausableTimer) i128 {
        if (!self.is_running) return 0;

        const now = std.time.nanoTimestamp();
        const total = now - self.start_time;

        if (self.is_paused) {
            const current_pause = now - self.pause_time;
            return total - self.total_paused - current_pause;
        }

        return total - self.total_paused;
    }

    pub fn stop(self: *PausableTimer) i128 {
        if (!self.is_running) return 0;
        const elapsed_time = self.elapsed();
        self.is_running = false;
        return elapsed_time;
    }
};

test "pausable timer" {
    var timer = PausableTimer.start();

    var i: usize = 0;
    var sum: usize = 0;
    while (i < 1000) : (i += 1) {
        sum +%= i;
    }
    std.mem.doNotOptimizeAway(&sum);

    const elapsed1 = timer.elapsed();
    try testing.expect(elapsed1 >= 0);

    timer.pause();
    try testing.expect(timer.is_paused);

    timer.unpause();
    try testing.expect(!timer.is_paused);

    const final_elapsed = timer.stop();
    try testing.expect(final_elapsed >= 0);
}
// ANCHOR_END: pausable_timer

// ANCHOR: countdown_timer
/// Countdown timer
pub const CountdownTimer = struct {
    start_time: i128,
    duration_ns: i128,

    pub fn start(duration_ms: i64) CountdownTimer {
        return .{
            .start_time = std.time.nanoTimestamp(),
            .duration_ns = @as(i128, duration_ms) * std.time.ns_per_ms,
        };
    }

    pub fn remaining(self: *const CountdownTimer) i128 {
        const elapsed = std.time.nanoTimestamp() - self.start_time;
        const remaining_ns = self.duration_ns - elapsed;
        return if (remaining_ns > 0) remaining_ns else 0;
    }

    pub fn remainingMs(self: *const CountdownTimer) i64 {
        return @intCast(@divFloor(self.remaining(), std.time.ns_per_ms));
    }

    pub fn isExpired(self: *const CountdownTimer) bool {
        return self.remaining() == 0;
    }

    pub fn progress(self: *const CountdownTimer) f64 {
        const elapsed = std.time.nanoTimestamp() - self.start_time;
        const prog = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(self.duration_ns));
        return if (prog > 1.0) 1.0 else prog;
    }
};

test "countdown timer" {
    var timer = CountdownTimer.start(100);

    try testing.expect(!timer.isExpired());

    const remaining = timer.remainingMs();
    try testing.expect(remaining > 0 and remaining <= 100);

    const prog = timer.progress();
    try testing.expect(prog >= 0.0 and prog <= 1.0);
}
// ANCHOR_END: countdown_timer

// ANCHOR: format_duration
/// Format duration for human-readable output
pub fn formatDuration(allocator: std.mem.Allocator, ns: i128) ![]u8 {
    const ms = @divFloor(ns, std.time.ns_per_ms);
    const sec = @divFloor(ms, 1000);
    const min = @divFloor(sec, 60);
    const hour = @divFloor(min, 60);

    if (hour > 0) {
        return try std.fmt.allocPrint(allocator, "{d}h {d}m {d}s", .{
            hour,
            @mod(min, 60),
            @mod(sec, 60),
        });
    } else if (min > 0) {
        return try std.fmt.allocPrint(allocator, "{d}m {d}s", .{
            min,
            @mod(sec, 60),
        });
    } else if (sec > 0) {
        const frac = @mod(ms, 1000);
        if (frac >= 100) {
            return try std.fmt.allocPrint(allocator, "{d}.{d}s", .{ sec, frac });
        } else if (frac >= 10) {
            return try std.fmt.allocPrint(allocator, "{d}.0{d}s", .{ sec, frac });
        } else {
            return try std.fmt.allocPrint(allocator, "{d}.00{d}s", .{ sec, frac });
        }
    } else {
        return try std.fmt.allocPrint(allocator, "{d}ms", .{ms});
    }
}

test "format duration" {
    const hour_ns = 3661 * std.time.ns_per_s;
    const hour_str = try formatDuration(testing.allocator, hour_ns);
    defer testing.allocator.free(hour_str);
    try testing.expect(std.mem.indexOf(u8, hour_str, "1h") != null);

    const min_ns = 125 * std.time.ns_per_s;
    const min_str = try formatDuration(testing.allocator, min_ns);
    defer testing.allocator.free(min_str);
    try testing.expect(std.mem.indexOf(u8, min_str, "2m") != null);

    const sec_ns = 5 * std.time.ns_per_s + 500 * std.time.ns_per_ms;
    const sec_str = try formatDuration(testing.allocator, sec_ns);
    defer testing.allocator.free(sec_str);
    try testing.expectEqualStrings("5.500s", sec_str);

    const ms_ns = 42 * std.time.ns_per_ms;
    const ms_str = try formatDuration(testing.allocator, ms_ns);
    defer testing.allocator.free(ms_str);
    try testing.expect(std.mem.indexOf(u8, ms_str, "42ms") != null);
}
// ANCHOR_END: format_duration

// ANCHOR: benchmark
/// Benchmark a function
pub fn benchmark(
    comptime func: anytype,
    args: anytype,
    iterations: usize,
) i128 {
    const start = std.time.nanoTimestamp();

    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        const result = @call(.auto, func, args);
        std.mem.doNotOptimizeAway(&result);
    }

    const end = std.time.nanoTimestamp();
    return @divFloor(end - start, @as(i128, @intCast(iterations)));
}

fn exampleFunction(n: usize) usize {
    var sum: usize = 0;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        sum += i;
    }
    return sum;
}

test "benchmark function" {
    const avg_time = benchmark(exampleFunction, .{100}, 1000);
    try testing.expect(avg_time > 0);
}
// ANCHOR_END: benchmark

// ANCHOR: timer_stats
/// Collect timing statistics
pub const TimerStats = struct {
    samples: std.ArrayList(i128),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) TimerStats {
        return .{
            .samples = std.ArrayList(i128){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TimerStats) void {
        self.samples.deinit(self.allocator);
    }

    pub fn record(self: *TimerStats, duration: i128) !void {
        try self.samples.append(self.allocator, duration);
    }

    pub fn mean(self: *const TimerStats) i128 {
        if (self.samples.items.len == 0) return 0;

        var sum: i128 = 0;
        for (self.samples.items) |sample| {
            sum += sample;
        }
        return @divFloor(sum, @as(i128, @intCast(self.samples.items.len)));
    }

    pub fn min(self: *const TimerStats) i128 {
        if (self.samples.items.len == 0) return 0;

        var minimum = self.samples.items[0];
        for (self.samples.items[1..]) |sample| {
            if (sample < minimum) minimum = sample;
        }
        return minimum;
    }

    pub fn max(self: *const TimerStats) i128 {
        if (self.samples.items.len == 0) return 0;

        var maximum = self.samples.items[0];
        for (self.samples.items[1..]) |sample| {
            if (sample > maximum) maximum = sample;
        }
        return maximum;
    }

    pub fn median(self: *TimerStats) !i128 {
        if (self.samples.items.len == 0) return 0;

        const items = try self.allocator.dupe(i128, self.samples.items);
        defer self.allocator.free(items);

        std.mem.sort(i128, items, {}, comptime std.sort.asc(i128));

        const mid = items.len / 2;
        if (items.len % 2 == 0) {
            return @divFloor(items[mid - 1] + items[mid], 2);
        } else {
            return items[mid];
        }
    }
};

test "timer statistics" {
    var stats = TimerStats.init(testing.allocator);
    defer stats.deinit();

    try stats.record(100);
    try stats.record(200);
    try stats.record(150);
    try stats.record(300);

    try testing.expectEqual(@as(i128, 187), stats.mean());
    try testing.expectEqual(@as(i128, 100), stats.min());
    try testing.expectEqual(@as(i128, 300), stats.max());
    try testing.expectEqual(@as(i128, 175), try stats.median());
}
// ANCHOR_END: timer_stats

// ANCHOR: rate_calculator
/// Calculate operations per second
pub const RateCalculator = struct {
    start_time: i128,
    count: u64,

    pub fn start() RateCalculator {
        return .{
            .start_time = std.time.nanoTimestamp(),
            .count = 0,
        };
    }

    pub fn increment(self: *RateCalculator) void {
        self.count += 1;
    }

    pub fn incrementBy(self: *RateCalculator, n: u64) void {
        self.count += n;
    }

    pub fn rate(self: *const RateCalculator) f64 {
        const elapsed_ns = std.time.nanoTimestamp() - self.start_time;
        if (elapsed_ns == 0) return 0.0;

        const elapsed_sec = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(std.time.ns_per_s));
        return @as(f64, @floatFromInt(self.count)) / elapsed_sec;
    }

    pub fn formatRate(self: *const RateCalculator, allocator: std.mem.Allocator) ![]u8 {
        const ops_per_sec = self.rate();

        if (ops_per_sec >= 1_000_000) {
            return try std.fmt.allocPrint(allocator, "{d:.2} M ops/sec", .{ops_per_sec / 1_000_000});
        } else if (ops_per_sec >= 1_000) {
            return try std.fmt.allocPrint(allocator, "{d:.2} K ops/sec", .{ops_per_sec / 1_000});
        } else {
            return try std.fmt.allocPrint(allocator, "{d:.2} ops/sec", .{ops_per_sec});
        }
    }
};

test "rate calculator" {
    var calc = RateCalculator.start();

    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        calc.increment();
    }

    const ops_rate = calc.rate();
    try testing.expect(ops_rate > 0);

    const formatted = try calc.formatRate(testing.allocator);
    defer testing.allocator.free(formatted);
    try testing.expect(formatted.len > 0);
}
// ANCHOR_END: rate_calculator

// ANCHOR: progress_timer
/// Timer with progress tracking
pub const ProgressTimer = struct {
    start_time: i128,
    total_items: usize,
    completed_items: usize,

    pub fn start(total: usize) ProgressTimer {
        return .{
            .start_time = std.time.nanoTimestamp(),
            .total_items = total,
            .completed_items = 0,
        };
    }

    pub fn update(self: *ProgressTimer, completed: usize) void {
        self.completed_items = completed;
    }

    pub fn increment(self: *ProgressTimer) void {
        self.completed_items += 1;
    }

    pub fn percentComplete(self: *const ProgressTimer) f64 {
        if (self.total_items == 0) return 0.0;
        return @as(f64, @floatFromInt(self.completed_items)) / @as(f64, @floatFromInt(self.total_items)) * 100.0;
    }

    pub fn estimatedTimeRemaining(self: *const ProgressTimer) i128 {
        if (self.completed_items == 0) return 0;

        const elapsed = std.time.nanoTimestamp() - self.start_time;
        const rate = @as(f64, @floatFromInt(elapsed)) / @as(f64, @floatFromInt(self.completed_items));
        const remaining_items = self.total_items - self.completed_items;

        return @intFromFloat(rate * @as(f64, @floatFromInt(remaining_items)));
    }

    pub fn formatProgress(self: *const ProgressTimer, allocator: std.mem.Allocator) ![]u8 {
        const percent = self.percentComplete();
        const remaining_ns = self.estimatedTimeRemaining();
        const remaining_str = try formatDuration(allocator, remaining_ns);
        defer allocator.free(remaining_str);

        return try std.fmt.allocPrint(allocator, "{d}/{d} ({d:.1}%) - ETA: {s}", .{
            self.completed_items,
            self.total_items,
            percent,
            remaining_str,
        });
    }
};

test "progress timer" {
    var timer = ProgressTimer.start(100);

    timer.update(25);
    try testing.expectEqual(@as(f64, 25.0), timer.percentComplete());

    timer.increment();
    try testing.expectEqual(@as(usize, 26), timer.completed_items);

    const formatted = try timer.formatProgress(testing.allocator);
    defer testing.allocator.free(formatted);
    try testing.expect(std.mem.indexOf(u8, formatted, "26/100") != null);
}
// ANCHOR_END: progress_timer
