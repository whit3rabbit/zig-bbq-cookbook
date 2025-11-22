// Recipe 3.12: Basic time conversions
// Target Zig Version: 0.15.2
//
// This recipe demonstrates working with time using std.time.
// Zig keeps it simple: durations are u64 nanoseconds, and the standard library
// provides constants for conversions. No wrapper types needed.

// ANCHOR: time_constants
const std = @import("std");
const testing = std.testing;
const time = std.time;
// ANCHOR_END: time_constants

// ANCHOR: stopwatch
// Stopwatch timer for measuring elapsed time using monotonic clock
// (not affected by system clock changes like NTP adjustments)
pub const Stopwatch = struct {
    timer: time.Timer,

    pub fn start() !Stopwatch {
        return Stopwatch{
            .timer = try time.Timer.start(),
        };
    }

    pub fn read(self: *Stopwatch) u64 {
        return self.timer.read();
    }

    pub fn lap(self: *Stopwatch) u64 {
        return self.timer.lap();
    }

    pub fn reset(self: *Stopwatch) void {
        self.timer.reset();
    }
};
// ANCHOR_END: stopwatch

// ANCHOR: duration_formatting
// Format duration as human-readable string
pub fn formatDuration(allocator: std.mem.Allocator, duration_ns: u64) ![]u8 {
    if (duration_ns < time.ns_per_us) {
        return std.fmt.allocPrint(allocator, "{}ns", .{duration_ns});
    } else if (duration_ns < time.ns_per_ms) {
        const us = duration_ns / time.ns_per_us;
        return std.fmt.allocPrint(allocator, "{}µs", .{us});
    } else if (duration_ns < time.ns_per_s) {
        const ms = duration_ns / time.ns_per_ms;
        return std.fmt.allocPrint(allocator, "{}ms", .{ms});
    } else if (duration_ns < time.ns_per_min) {
        const s = @as(f64, @floatFromInt(duration_ns)) / @as(f64, time.ns_per_s);
        return std.fmt.allocPrint(allocator, "{d:.2}s", .{s});
    } else if (duration_ns < time.ns_per_hour) {
        const min = duration_ns / time.ns_per_min;
        const sec = (duration_ns % time.ns_per_min) / time.ns_per_s;
        return std.fmt.allocPrint(allocator, "{}m{}s", .{ min, sec });
    } else {
        const hours = duration_ns / time.ns_per_hour;
        const min = (duration_ns % time.ns_per_hour) / time.ns_per_min;
        return std.fmt.allocPrint(allocator, "{}h{}m", .{ hours, min });
    }
}
// ANCHOR_END: duration_formatting

// ============================================================================
// TESTS: Demonstrating idiomatic std.time usage
// ============================================================================

test "time constants are available in std.time" {
    // Zig provides these constants for time conversions
    try testing.expectEqual(@as(i64, 1000), time.ns_per_us);
    try testing.expectEqual(@as(i64, 1_000_000), time.ns_per_ms);
    try testing.expectEqual(@as(i64, 1_000_000_000), time.ns_per_s);
    try testing.expectEqual(@as(i64, 60_000_000_000), time.ns_per_min);
    try testing.expectEqual(@as(i64, 3_600_000_000_000), time.ns_per_hour);
    try testing.expectEqual(@as(i64, 86_400_000_000_000), time.ns_per_day);
}

test "creating durations from time units" {
    // Just multiply by the constant - simple and clear
    const two_seconds = 2 * time.ns_per_s;
    const five_millis = 5 * time.ns_per_ms;
    const one_hour = 1 * time.ns_per_hour;

    try testing.expectEqual(@as(u64, 2_000_000_000), two_seconds);
    try testing.expectEqual(@as(u64, 5_000_000), five_millis);
    try testing.expectEqual(@as(u64, 3_600_000_000_000), one_hour);
}

test "converting durations to different units" {
    const duration = 2 * time.ns_per_s; // 2 seconds in nanoseconds

    // Convert back to other units with division
    const as_ns = duration;
    const as_us = duration / time.ns_per_us;
    const as_ms = duration / time.ns_per_ms;
    const as_s = duration / time.ns_per_s;

    try testing.expectEqual(@as(u64, 2_000_000_000), as_ns);
    try testing.expectEqual(@as(u64, 2_000_000), as_us);
    try testing.expectEqual(@as(u64, 2_000), as_ms);
    try testing.expectEqual(@as(u64, 2), as_s);
}

test "converting durations to float seconds" {
    const duration = 1500 * time.ns_per_ms; // 1.5 seconds

    const seconds = @as(f64, @floatFromInt(duration)) / @as(f64, time.ns_per_s);
    try testing.expectApproxEqAbs(@as(f64, 1.5), seconds, 0.0001);
}

test "duration arithmetic" {
    const d1 = 1 * time.ns_per_s;
    const d2 = 2 * time.ns_per_s;

    // Addition
    const sum = d1 + d2;
    try testing.expectEqual(@as(u64, 3), sum / time.ns_per_s);

    // Subtraction
    const diff = d2 - d1;
    try testing.expectEqual(@as(u64, 1), diff / time.ns_per_s);

    // Multiplication
    const doubled = d1 * 2;
    try testing.expectEqual(@as(u64, 2), doubled / time.ns_per_s);

    // Division
    const halved = d2 / 2;
    try testing.expectEqual(@as(u64, 1), halved / time.ns_per_s);
}

test "duration comparisons" {
    const one_sec = 1 * time.ns_per_s;
    const two_sec = 2 * time.ns_per_s;
    const also_two_sec = 2000 * time.ns_per_ms;

    // Use standard comparison operators
    try testing.expect(one_sec < two_sec);
    try testing.expect(two_sec > one_sec);
    try testing.expect(two_sec == also_two_sec);
}

test "sleeping for a duration" {
    // Sleep expects nanoseconds (in std.Thread, not std.time)
    const sleep_time = 1 * time.ns_per_ms; // 1 millisecond
    std.Thread.sleep(sleep_time);
    // No assertion needed, just demonstrating the API
}

test "getting wall clock timestamps" {
    // Wall clock time - can be affected by system clock changes
    const ts_nanos = time.nanoTimestamp();
    const ts_millis = time.milliTimestamp();

    // Verify we're past Jan 1, 2020 (1577836800 seconds since epoch)
    const year_2020_ns: i128 = 1577836800 * time.ns_per_s;
    const year_2020_ms: i64 = 1577836800 * 1000;

    try testing.expect(ts_nanos > year_2020_ns);
    try testing.expect(ts_millis > year_2020_ms);
}

test "monotonic timing with stopwatch" {
    // Timer uses monotonic clock, not affected by system time changes
    var sw = try Stopwatch.start();

    // Do some work
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        _ = i * 2;
    }

    const elapsed = sw.read();
    try testing.expect(elapsed > 0);

    // Convert to human units
    const elapsed_us = elapsed / time.ns_per_us;
    _ = elapsed_us; // Microseconds elapsed
}

test "stopwatch lap timing" {
    var sw = try Stopwatch.start();

    // First lap
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        _ = i * 2;
    }
    const lap1 = sw.lap();

    // Second lap
    i = 0;
    while (i < 100) : (i += 1) {
        _ = i * 2;
    }
    const lap2 = sw.lap();

    try testing.expect(lap1 > 0);
    try testing.expect(lap2 > 0);
}

test "stopwatch reset" {
    var sw = try Stopwatch.start();

    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        _ = i * 2;
    }

    sw.reset();
    const elapsed = sw.read();

    // After reset, elapsed should be very small
    try testing.expect(elapsed < 1 * time.ns_per_ms);
}

test "format duration nanoseconds" {
    const duration = 500; // 500 nanoseconds
    const formatted = try formatDuration(testing.allocator, duration);
    defer testing.allocator.free(formatted);

    try testing.expect(std.mem.eql(u8, formatted, "500ns"));
}

test "format duration microseconds" {
    const duration = 250 * time.ns_per_us;
    const formatted = try formatDuration(testing.allocator, duration);
    defer testing.allocator.free(formatted);

    try testing.expect(std.mem.eql(u8, formatted, "250µs"));
}

test "format duration milliseconds" {
    const duration = 150 * time.ns_per_ms;
    const formatted = try formatDuration(testing.allocator, duration);
    defer testing.allocator.free(formatted);

    try testing.expect(std.mem.eql(u8, formatted, "150ms"));
}

test "format duration seconds" {
    const duration = 2500 * time.ns_per_ms; // 2.5 seconds
    const formatted = try formatDuration(testing.allocator, duration);
    defer testing.allocator.free(formatted);

    try testing.expect(std.mem.eql(u8, formatted, "2.50s"));
}

test "format duration minutes" {
    const duration = 125 * time.ns_per_s; // 2 minutes 5 seconds
    const formatted = try formatDuration(testing.allocator, duration);
    defer testing.allocator.free(formatted);

    try testing.expect(std.mem.eql(u8, formatted, "2m5s"));
}

test "format duration hours" {
    const duration = 150 * time.ns_per_min; // 2 hours 30 minutes
    const formatted = try formatDuration(testing.allocator, duration);
    defer testing.allocator.free(formatted);

    try testing.expect(std.mem.eql(u8, formatted, "2h30m"));
}

test "practical example: measuring code performance" {
    var sw = try Stopwatch.start();

    // Simulate some work
    var sum: u64 = 0;
    var i: usize = 0;
    while (i < 10_000) : (i += 1) {
        sum +%= i;
    }

    const elapsed = sw.read();
    const formatted = try formatDuration(testing.allocator, elapsed);
    defer testing.allocator.free(formatted);

    // Just verify we can format it
    try testing.expect(formatted.len > 0);

    // Prevent optimization from removing the loop
    try testing.expect(sum > 0);
}

test "memory safety - duration operations do not allocate" {
    // All duration math is just integer arithmetic - zero allocations
    const d1 = 10 * time.ns_per_s;
    const d2 = 5 * time.ns_per_s;

    _ = d1 + d2;
    _ = d1 - d2;
    _ = d1 * 2;
    _ = d1 / 2;
    _ = d1 < d2;
    _ = d1 / time.ns_per_s;
}

test "security note - timing comparisons are not constant-time" {
    // For cryptographic operations, use std.crypto.timing_safe_eql
    // Standard duration comparisons are NOT constant-time
    const d1 = 1 * time.ns_per_s;
    const d2 = 1 * time.ns_per_s;

    // This comparison leaks timing information
    try testing.expect(d1 == d2);

    // For timing-sensitive security operations (password comparison, etc.),
    // use dedicated constant-time comparison functions, not duration comparison
}
