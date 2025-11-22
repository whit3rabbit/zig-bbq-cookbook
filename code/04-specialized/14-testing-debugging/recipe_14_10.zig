const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_reraise
fn lowLevelOperation(value: i32) !i32 {
    if (value < 0) return error.InvalidValue;
    if (value == 0) return error.ZeroValue;
    return value * 2;
}

fn middleLayer(value: i32) !i32 {
    // Reraise error without modification
    return try lowLevelOperation(value);
}

fn topLayer(value: i32) !i32 {
    // Reraise error without modification
    return try middleLayer(value);
}

test "basic error reraising with try" {
    try testing.expectError(error.InvalidValue, topLayer(-1));
    try testing.expectError(error.ZeroValue, topLayer(0));
    try testing.expectEqual(@as(i32, 20), try topLayer(10));
}
// ANCHOR_END: basic_reraise

// ANCHOR: conditional_reraise
fn performOperation(value: i32) !i32 {
    if (value < 0) return error.Negative;
    if (value == 0) return error.Zero;
    if (value > 100) return error.TooLarge;
    return value;
}

fn handleWithLogging(value: i32) !i32 {
    return performOperation(value) catch |err| {
        // Log error but reraise it
        std.debug.print("Error occurred: {s}\n", .{@errorName(err)});
        return err;
    };
}

test "conditionally reraise after logging" {
    try testing.expectError(error.Negative, handleWithLogging(-5));
    try testing.expectError(error.Zero, handleWithLogging(0));
    try testing.expectEqual(@as(i32, 50), try handleWithLogging(50));
}
// ANCHOR_END: conditional_reraise

// ANCHOR: reraise_with_cleanup
const Resource = struct {
    allocated: bool,

    fn init() Resource {
        return .{ .allocated = true };
    }

    fn deinit(self: *Resource) void {
        self.allocated = false;
    }
};

fn operationWithCleanup(fail: bool) !i32 {
    var resource = Resource.init();
    defer resource.deinit();

    if (fail) return error.OperationFailed;
    return 42;
}

fn wrapperWithCleanup(fail: bool) !i32 {
    // Error is automatically reraised after defer cleanup
    return try operationWithCleanup(fail);
}

test "reraise with cleanup" {
    try testing.expectEqual(@as(i32, 42), try wrapperWithCleanup(false));
    try testing.expectError(error.OperationFailed, wrapperWithCleanup(true));
}
// ANCHOR_END: reraise_with_cleanup

// ANCHOR: selective_reraise
fn mayFail(value: i32) !i32 {
    if (value == 1) return error.Recoverable;
    if (value == 2) return error.Critical;
    if (value == 3) return error.Warning;
    return value;
}

fn selectiveHandler(value: i32) !i32 {
    return mayFail(value) catch |err| {
        // Reraise some errors, handle others
        switch (err) {
            error.Recoverable => {
                std.debug.print("Recovered from error\n", .{});
                return 0; // Handle this one
            },
            error.Warning => {
                std.debug.print("Warning: {s}\n", .{@errorName(err)});
                return 0; // Handle this one too
            },
            error.Critical => {
                std.debug.print("Critical error, reraising\n", .{});
                return err; // Reraise
            },
        }
    };
}

test "selectively reraise errors" {
    try testing.expectEqual(@as(i32, 0), try selectiveHandler(1)); // Handled
    try testing.expectError(error.Critical, selectiveHandler(2)); // Reraised
    try testing.expectEqual(@as(i32, 0), try selectiveHandler(3)); // Handled
    try testing.expectEqual(@as(i32, 99), try selectiveHandler(99)); // Success
}
// ANCHOR_END: selective_reraise

// ANCHOR: reraise_with_context
const OperationContext = struct {
    name: []const u8,
    attempt: usize,

    fn execute(self: *OperationContext, value: i32) !i32 {
        self.attempt += 1;
        if (value < 0) {
            std.debug.print("[{s}] Attempt {d}: Error\n", .{ self.name, self.attempt });
            return error.Failed;
        }
        return value;
    }
};

fn executeWithContext(value: i32) !i32 {
    var ctx = OperationContext{ .name = "MyOperation", .attempt = 0 };

    // Try operation, reraise if it fails
    const result = ctx.execute(value) catch |err| {
        std.debug.print("Reraising error from {s}\n", .{ctx.name});
        return err;
    };

    return result;
}

test "reraise with context tracking" {
    try testing.expectEqual(@as(i32, 42), try executeWithContext(42));
    try testing.expectError(error.Failed, executeWithContext(-1));
}
// ANCHOR_END: reraise_with_context

// ANCHOR: reraise_chain
fn level1Operation(value: i32) !i32 {
    if (value == 1) return error.L1Error;
    return value;
}

fn level2Operation(value: i32) !i32 {
    // Reraise L1 error
    return level1Operation(value) catch |err| {
        std.debug.print("Level 2 reraising: {s}\n", .{@errorName(err)});
        return err;
    };
}

fn level3Operation(value: i32) !i32 {
    // Reraise from level 2
    return level2Operation(value) catch |err| {
        std.debug.print("Level 3 reraising: {s}\n", .{@errorName(err)});
        return err;
    };
}

test "error reraising chain" {
    try testing.expectEqual(@as(i32, 42), try level3Operation(42));
    try testing.expectError(error.L1Error, level3Operation(1));
}
// ANCHOR_END: reraise_chain

// ANCHOR: errdefer_reraise
fn allocateAndProcess(allocator: std.mem.Allocator, fail: bool) ![]u8 {
    const buffer = try allocator.alloc(u8, 100);
    errdefer allocator.free(buffer);

    if (fail) {
        // errdefer will run, then error is reraised
        return error.ProcessingFailed;
    }

    return buffer;
}

fn wrapAllocate(allocator: std.mem.Allocator, fail: bool) ![]u8 {
    // Error from allocateAndProcess is automatically reraised
    return try allocateAndProcess(allocator, fail);
}

test "reraise with errdefer cleanup" {
    const buffer = try wrapAllocate(testing.allocator, false);
    defer testing.allocator.free(buffer);

    try testing.expectEqual(@as(usize, 100), buffer.len);
    try testing.expectError(error.ProcessingFailed, wrapAllocate(testing.allocator, true));
}
// ANCHOR_END: errdefer_reraise

// ANCHOR: reraise_or_default
fn operationWithDefault(value: i32, default: i32) i32 {
    return performOperation(value) catch |err| {
        // For some errors, reraise; for others, return default
        switch (err) {
            error.Negative, error.Zero => return default,
            error.TooLarge => {
                std.debug.print("Value too large, using default\n", .{});
                return default;
            },
        }
    };
}

test "reraise or return default" {
    try testing.expectEqual(@as(i32, 50), operationWithDefault(50, 0));
    try testing.expectEqual(@as(i32, 0), operationWithDefault(-1, 0));
    try testing.expectEqual(@as(i32, 99), operationWithDefault(0, 99));
}
// ANCHOR_END: reraise_or_default

// ANCHOR: transparent_reraise
fn operation1(value: i32) !i32 {
    if (value == 1) return error.Op1Failed;
    return value * 2;
}

fn operation2(value: i32) !i32 {
    if (value == 2) return error.Op2Failed;
    return value * 3;
}

fn compositeOperation(value: i32) !i32 {
    // Transparently reraise errors from both operations
    const result1 = try operation1(value);
    const result2 = try operation2(value);
    return result1 + result2;
}

test "transparently reraise from multiple operations" {
    try testing.expectError(error.Op1Failed, compositeOperation(1));
    try testing.expectError(error.Op2Failed, compositeOperation(2));
    try testing.expectEqual(@as(i32, 25), try compositeOperation(5)); // (5*2) + (5*3) = 25
}
// ANCHOR_END: transparent_reraise

// ANCHOR: reraise_with_metric
const ErrorMetrics = struct {
    reraise_count: usize = 0,
    handled_count: usize = 0,

    fn recordReraise(self: *ErrorMetrics, err: anyerror) void {
        self.reraise_count += 1;
        std.debug.print("Reraising #{d}: {s}\n", .{ self.reraise_count, @errorName(err) });
    }

    fn recordHandled(self: *ErrorMetrics, err: anyerror) void {
        self.handled_count += 1;
        std.debug.print("Handled #{d}: {s}\n", .{ self.handled_count, @errorName(err) });
    }
};

fn operationWithMetrics(value: i32, metrics: *ErrorMetrics) !i32 {
    return performOperation(value) catch |err| {
        if (err == error.Negative) {
            metrics.recordHandled(err);
            return 0;
        } else {
            metrics.recordReraise(err);
            return err;
        }
    };
}

test "track reraise metrics" {
    var metrics = ErrorMetrics{};

    _ = try operationWithMetrics(50, &metrics);
    _ = try operationWithMetrics(-1, &metrics);
    _ = operationWithMetrics(0, &metrics) catch {};

    try testing.expectEqual(@as(usize, 1), metrics.reraise_count);
    try testing.expectEqual(@as(usize, 1), metrics.handled_count);
}
// ANCHOR_END: reraise_with_metric
