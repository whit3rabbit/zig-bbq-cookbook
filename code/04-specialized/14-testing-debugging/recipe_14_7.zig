const std = @import("std");
const testing = std.testing;

// ANCHOR: anyerror_catch
fn riskyOperation(value: i32) !i32 {
    if (value < 0) return error.NegativeValue;
    if (value == 0) return error.ZeroValue;
    if (value > 100) return error.TooLarge;
    return value * 2;
}

fn safeOperation(value: i32) i32 {
    return riskyOperation(value) catch |err| {
        std.debug.print("Caught error: {s}\n", .{@errorName(err)});
        return 0; // Default value
    };
}

test "catch all errors with anyerror" {
    try testing.expectEqual(@as(i32, 0), safeOperation(-5));
    try testing.expectEqual(@as(i32, 0), safeOperation(0));
    try testing.expectEqual(@as(i32, 0), safeOperation(200));
    try testing.expectEqual(@as(i32, 20), safeOperation(10));
}
// ANCHOR_END: anyerror_catch

// ANCHOR: catch_and_log
fn processWithLogging(value: i32, logger: anytype) i32 {
    return riskyOperation(value) catch |err| {
        logger.log("Operation failed: {s}", .{@errorName(err)});
        return -1;
    };
}

const TestLogger = struct {
    message: ?[]const u8 = null,

    fn log(self: *TestLogger, comptime fmt: []const u8, args: anytype) void {
        _ = fmt;
        _ = args;
        self.message = "Error logged";
    }
};

test "catch all errors and log them" {
    var logger = TestLogger{};
    const result = processWithLogging(-5, &logger);

    try testing.expectEqual(@as(i32, -1), result);
    try testing.expect(logger.message != null);
}
// ANCHOR_END: catch_and_log

// ANCHOR: error_name_inspection
fn handleAnyError(err: anyerror) []const u8 {
    const name = @errorName(err);

    // Check error name for special handling
    if (std.mem.startsWith(u8, name, "File")) {
        return "File system error";
    } else if (std.mem.startsWith(u8, name, "Network")) {
        return "Network error";
    } else if (std.mem.startsWith(u8, name, "Parse")) {
        return "Parsing error";
    }

    return "Unknown error";
}

test "inspect error names" {
    try testing.expectEqualStrings("File system error", handleAnyError(error.FileNotFound));
    try testing.expectEqualStrings("Network error", handleAnyError(error.NetworkTimeout));
    try testing.expectEqualStrings("Parsing error", handleAnyError(error.ParseError));
    try testing.expectEqualStrings("Unknown error", handleAnyError(error.GenericError));
}
// ANCHOR_END: error_name_inspection

// ANCHOR: global_error_handler
const ErrorHandler = struct {
    error_count: usize = 0,
    last_error: ?anyerror = null,

    fn handle(self: *ErrorHandler, err: anyerror) void {
        self.error_count += 1;
        self.last_error = err;
        std.debug.print("Error #{d}: {s}\n", .{ self.error_count, @errorName(err) });
    }

    fn reset(self: *ErrorHandler) void {
        self.error_count = 0;
        self.last_error = null;
    }
};

fn operationWithHandler(value: i32, handler: *ErrorHandler) !i32 {
    return riskyOperation(value) catch |err| {
        handler.handle(err);
        return error.HandledError;
    };
}

test "use global error handler" {
    var handler = ErrorHandler{};

    _ = operationWithHandler(-5, &handler) catch {};
    try testing.expectEqual(@as(usize, 1), handler.error_count);
    try testing.expectEqual(error.NegativeValue, handler.last_error.?);

    _ = operationWithHandler(200, &handler) catch {};
    try testing.expectEqual(@as(usize, 2), handler.error_count);
}
// ANCHOR_END: global_error_handler

// ANCHOR: try_or_default
fn tryOrDefault(comptime T: type, operation: anytype, default: T) T {
    return operation catch default;
}

test "try operation or return default" {
    const result1 = tryOrDefault(i32, riskyOperation(10), 0);
    try testing.expectEqual(@as(i32, 20), result1);

    const result2 = tryOrDefault(i32, riskyOperation(-5), 999);
    try testing.expectEqual(@as(i32, 999), result2);
}
// ANCHOR_END: try_or_default

// ANCHOR: panic_on_error
fn mustSucceed(value: i32) i32 {
    return riskyOperation(value) catch |err| {
        std.debug.panic("Operation must not fail: {s}", .{@errorName(err)});
    };
}

test "operations that must succeed" {
    // Only test valid cases since panic would terminate
    try testing.expectEqual(@as(i32, 20), mustSucceed(10));
    try testing.expectEqual(@as(i32, 100), mustSucceed(50));
}
// ANCHOR_END: panic_on_error

// ANCHOR: catch_all_pattern
fn robustOperation(value: i32) !struct { result: i32, had_error: bool } {
    if (riskyOperation(value)) |val| {
        return .{ .result = val, .had_error = false };
    } else |err| {
        std.debug.print("Recovered from error: {s}\n", .{@errorName(err)});
        return .{ .result = 0, .had_error = true };
    }
}

test "catch all with explicit result type" {
    const success = try robustOperation(10);
    try testing.expectEqual(@as(i32, 20), success.result);
    try testing.expect(!success.had_error);

    const failure = try robustOperation(-5);
    try testing.expectEqual(@as(i32, 0), failure.result);
    try testing.expect(failure.had_error);
}
// ANCHOR_END: catch_all_pattern

// ANCHOR: error_tracking
const ErrorTracker = struct {
    errors: std.ArrayList(anyerror),
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) ErrorTracker {
        return .{
            .errors = std.ArrayList(anyerror){},
            .allocator = allocator,
        };
    }

    fn deinit(self: *ErrorTracker) void {
        self.errors.deinit(self.allocator);
    }

    fn track(self: *ErrorTracker, err: anyerror) !void {
        try self.errors.append(self.allocator, err);
    }

    fn getErrors(self: *const ErrorTracker) []const anyerror {
        return self.errors.items;
    }
};

fn trackAllErrors(values: []const i32, tracker: *ErrorTracker) !void {
    for (values) |value| {
        _ = riskyOperation(value) catch |err| {
            try tracker.track(err);
            continue;
        };
    }
}

test "track all encountered errors" {
    var tracker = ErrorTracker.init(testing.allocator);
    defer tracker.deinit();

    const values = [_]i32{ -5, 0, 10, 200, -1 };
    try trackAllErrors(&values, &tracker);

    const errors = tracker.getErrors();
    try testing.expectEqual(@as(usize, 4), errors.len);
    try testing.expectEqual(error.NegativeValue, errors[0]);
    try testing.expectEqual(error.ZeroValue, errors[1]);
}
// ANCHOR_END: error_tracking

// ANCHOR: fallback_chain
fn withFallbacks(value: i32) i32 {
    // Try primary operation
    if (riskyOperation(value)) |result| {
        return result;
    } else |err1| {
        std.debug.print("Primary failed: {s}\n", .{@errorName(err1)});

        // Try fallback with adjusted value
        const adjusted = if (value < 0) -value else value;
        if (riskyOperation(adjusted)) |result| {
            return result;
        } else |err2| {
            std.debug.print("Fallback failed: {s}\n", .{@errorName(err2)});

            // Return safe default
            return 1;
        }
    }
}

test "fallback chain on any error" {
    try testing.expectEqual(@as(i32, 20), withFallbacks(10));
    try testing.expectEqual(@as(i32, 10), withFallbacks(-5)); // -(-5) = 5, * 2 = 10
    try testing.expectEqual(@as(i32, 1), withFallbacks(0)); // Both fail, return default
}
// ANCHOR_END: fallback_chain

// ANCHOR: error_metrics
const ErrorMetrics = struct {
    total_operations: usize = 0,
    total_errors: usize = 0,
    error_types: std.StringHashMap(usize),
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) ErrorMetrics {
        return .{
            .error_types = std.StringHashMap(usize).init(allocator),
            .allocator = allocator,
        };
    }

    fn deinit(self: *ErrorMetrics) void {
        self.error_types.deinit();
    }

    fn recordOperation(self: *ErrorMetrics, result: anytype) !void {
        self.total_operations += 1;

        if (result) |_| {
            // Success
        } else |err| {
            self.total_errors += 1;
            const name = @errorName(err);
            const count = self.error_types.get(name) orelse 0;
            try self.error_types.put(name, count + 1);
        }
    }

    fn errorRate(self: *const ErrorMetrics) f64 {
        if (self.total_operations == 0) return 0;
        return @as(f64, @floatFromInt(self.total_errors)) / @as(f64, @floatFromInt(self.total_operations));
    }
};

test "collect error metrics" {
    var metrics = ErrorMetrics.init(testing.allocator);
    defer metrics.deinit();

    try metrics.recordOperation(riskyOperation(10));
    try metrics.recordOperation(riskyOperation(-5));
    try metrics.recordOperation(riskyOperation(0));
    try metrics.recordOperation(riskyOperation(20));

    try testing.expectEqual(@as(usize, 4), metrics.total_operations);
    try testing.expectEqual(@as(usize, 2), metrics.total_errors);
    try testing.expect(metrics.errorRate() > 0.4);
}
// ANCHOR_END: error_metrics

// ANCHOR: error_categorization
const ErrorCategory = enum {
    validation,
    system,
    network,
    unknown,
};

fn categorizeError(err: anyerror) ErrorCategory {
    const name = @errorName(err);

    if (std.mem.indexOf(u8, name, "Invalid") != null or
        std.mem.indexOf(u8, name, "Zero") != null or
        std.mem.indexOf(u8, name, "Negative") != null or
        std.mem.indexOf(u8, name, "TooLarge") != null)
    {
        return .validation;
    } else if (std.mem.indexOf(u8, name, "File") != null or
        std.mem.indexOf(u8, name, "Memory") != null)
    {
        return .system;
    } else if (std.mem.indexOf(u8, name, "Network") != null or
        std.mem.indexOf(u8, name, "Timeout") != null)
    {
        return .network;
    }

    return .unknown;
}

test "categorize any error" {
    try testing.expectEqual(ErrorCategory.validation, categorizeError(error.NegativeValue));
    try testing.expectEqual(ErrorCategory.validation, categorizeError(error.ZeroValue));
    try testing.expectEqual(ErrorCategory.system, categorizeError(error.FileNotFound));
    try testing.expectEqual(ErrorCategory.network, categorizeError(error.NetworkTimeout));
    try testing.expectEqual(ErrorCategory.unknown, categorizeError(error.GenericError));
}
// ANCHOR_END: error_categorization
