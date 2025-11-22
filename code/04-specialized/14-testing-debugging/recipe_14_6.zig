const std = @import("std");
const testing = std.testing;

// ANCHOR: error_union
const FileError = error{ NotFound, PermissionDenied, TooLarge };
const NetworkError = error{ Timeout, ConnectionRefused, HostUnreachable };
const AllErrors = FileError || NetworkError;

fn complexOperation(mode: u8) AllErrors!void {
    switch (mode) {
        1 => return error.NotFound,
        2 => return error.Timeout,
        3 => return error.PermissionDenied,
        else => {},
    }
}

test "handle multiple error types" {
    if (complexOperation(1)) |_| {
        try testing.expect(false);
    } else |err| {
        switch (err) {
            error.NotFound, error.PermissionDenied, error.TooLarge => {
                // Handle file errors
                try testing.expect(true);
            },
            error.Timeout, error.ConnectionRefused, error.HostUnreachable => {
                // Handle network errors
                try testing.expect(false);
            },
        }
    }
}
// ANCHOR_END: error_union

// ANCHOR: switch_errors
fn processData(data: []const u8) !void {
    if (data.len == 0) return error.EmptyData;
    if (data.len > 1000) return error.DataTooLarge;
    if (data[0] == 0) return error.InvalidFormat;
}

test "handle each error differently" {
    const cases = [_]struct {
        data: []const u8,
        expected_error: ?anyerror,
    }{
        .{ .data = "", .expected_error = error.EmptyData },
        .{ .data = &[_]u8{0} ** 1001, .expected_error = error.DataTooLarge },
        .{ .data = &[_]u8{0}, .expected_error = error.InvalidFormat },
        .{ .data = "valid", .expected_error = null },
    };

    for (cases) |case| {
        if (case.expected_error) |expected| {
            try testing.expectError(expected, processData(case.data));
        } else {
            try processData(case.data);
        }
    }
}
// ANCHOR_END: switch_errors

// ANCHOR: error_context
const Operation = struct {
    const Error = error{ InvalidInput, ProcessingFailed, OutputError };

    fn execute(input: i32) Error!i32 {
        if (input < 0) return error.InvalidInput;
        if (input > 100) return error.ProcessingFailed;
        return input * 2;
    }

    fn handleError(err: Error) []const u8 {
        return switch (err) {
            error.InvalidInput => "Input validation failed",
            error.ProcessingFailed => "Processing exceeded limits",
            error.OutputError => "Failed to produce output",
        };
    }
};

test "provide context for each error" {
    const result = Operation.execute(-5);
    if (result) |_| {
        try testing.expect(false);
    } else |err| {
        const message = Operation.handleError(err);
        try testing.expectEqualStrings("Input validation failed", message);
    }
}
// ANCHOR_END: error_context

// ANCHOR: cascading_errors
fn readConfig(path: []const u8) ![]const u8 {
    if (path.len == 0) return error.InvalidPath;
    if (std.mem.eql(u8, path, "missing.conf")) return error.FileNotFound;
    return "config data";
}

fn parseConfig(data: []const u8) !i32 {
    if (data.len == 0) return error.EmptyConfig;
    return 42;
}

fn loadConfiguration(path: []const u8) !i32 {
    const data = readConfig(path) catch |err| {
        switch (err) {
            error.InvalidPath => {
                // Try default path
                return parseConfig("default config");
            },
            error.FileNotFound => {
                // Create default config
                return 0;
            },
            else => return err,
        }
    };

    return parseConfig(data);
}

test "cascade through multiple error handlers" {
    try testing.expectEqual(@as(i32, 0), try loadConfiguration("missing.conf"));
    try testing.expectEqual(@as(i32, 42), try loadConfiguration("valid.conf"));
    try testing.expectEqual(@as(i32, 42), try loadConfiguration(""));
}
// ANCHOR_END: cascading_errors

// ANCHOR: error_recovery
const RecoveryStrategy = enum { retry, fallback, abort };

fn unreliableOperation(attempt: usize) !i32 {
    if (attempt < 3) return error.Transient;
    return 42;
}

fn handleWithStrategy(err: anyerror, strategy: RecoveryStrategy) !i32 {
    return switch (strategy) {
        .retry => blk: {
            // Retry logic - ignore the original error
            std.debug.print("Retrying after error: {s}\n", .{@errorName(err)});
            var attempt: usize = 0;
            while (attempt < 5) : (attempt += 1) {
                if (unreliableOperation(attempt)) |val| {
                    break :blk val;
                } else |e| {
                    if (e != error.Transient) return e;
                }
            }
            return error.MaxRetriesExceeded;
        },
        .fallback => 0, // Return default value
        .abort => err,
    };
}

test "apply different recovery strategies" {
    try testing.expectEqual(@as(i32, 42), try handleWithStrategy(error.Transient, .retry));
    try testing.expectEqual(@as(i32, 0), try handleWithStrategy(error.Permanent, .fallback));
    try testing.expectError(error.Permanent, handleWithStrategy(error.Permanent, .abort));
}
// ANCHOR_END: error_recovery

// ANCHOR: grouped_handling
const IOError = error{ ReadError, WriteError, SeekError };
const ValidationError = error{ InvalidFormat, OutOfRange, MissingField };
const RuntimeError = error{ OutOfMemory, Overflow, Timeout };

fn handleIOErrors(err: anyerror) void {
    std.debug.print("IO Error: {s}\n", .{@errorName(err)});
}

fn handleValidationErrors(err: anyerror) void {
    std.debug.print("Validation Error: {s}\n", .{@errorName(err)});
}

fn handleRuntimeErrors(err: anyerror) void {
    std.debug.print("Runtime Error: {s}\n", .{@errorName(err)});
}

fn operation(mode: u8) (IOError || ValidationError || RuntimeError)!void {
    switch (mode) {
        1 => return error.ReadError,
        2 => return error.InvalidFormat,
        3 => return error.OutOfMemory,
        else => {},
    }
}

test "group and handle related errors" {
    const result = operation(1);

    if (result) |_| {
        try testing.expect(true);
    } else |err| {
        switch (err) {
            error.ReadError, error.WriteError, error.SeekError => {
                handleIOErrors(err);
            },
            error.InvalidFormat, error.OutOfRange, error.MissingField => {
                handleValidationErrors(err);
            },
            error.OutOfMemory, error.Overflow, error.Timeout => {
                handleRuntimeErrors(err);
            },
        }
    }
}
// ANCHOR_END: grouped_handling

// ANCHOR: error_aggregation
const ErrorAggregator = struct {
    errors: std.ArrayList(anyerror),
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) ErrorAggregator {
        return .{
            .errors = std.ArrayList(anyerror){},
            .allocator = allocator,
        };
    }

    fn deinit(self: *ErrorAggregator) void {
        self.errors.deinit(self.allocator);
    }

    fn addError(self: *ErrorAggregator, err: anyerror) !void {
        try self.errors.append(self.allocator, err);
    }

    fn hasErrors(self: *const ErrorAggregator) bool {
        return self.errors.items.len > 0;
    }

    fn getErrors(self: *const ErrorAggregator) []const anyerror {
        return self.errors.items;
    }
};

test "aggregate multiple errors" {
    var aggregator = ErrorAggregator.init(testing.allocator);
    defer aggregator.deinit();

    try aggregator.addError(error.FirstError);
    try aggregator.addError(error.SecondError);
    try aggregator.addError(error.ThirdError);

    try testing.expect(aggregator.hasErrors());
    try testing.expectEqual(@as(usize, 3), aggregator.getErrors().len);
}
// ANCHOR_END: error_aggregation

// ANCHOR: error_chain
const ErrorChain = struct {
    current: anyerror,
    cause: ?*const ErrorChain = null,

    fn wrap(err: anyerror, cause: ?*const ErrorChain) ErrorChain {
        return .{
            .current = err,
            .cause = cause,
        };
    }

    fn rootCause(self: *const ErrorChain) anyerror {
        var chain = self;
        while (chain.cause) |cause| {
            chain = cause;
        }
        return chain.current;
    }
};

test "chain errors to preserve context" {
    const root = ErrorChain.wrap(error.DatabaseError, null);
    const mid = ErrorChain.wrap(error.ConnectionError, &root);
    const top = ErrorChain.wrap(error.ServiceError, &mid);

    try testing.expectEqual(error.DatabaseError, top.rootCause());
    try testing.expectEqual(error.ServiceError, top.current);
}
// ANCHOR_END: error_chain

// ANCHOR: error_priority
fn handleByPriority(err: anyerror) !void {
    // Handle errors by priority
    const critical = [_]anyerror{ error.OutOfMemory, error.StackOverflow };
    const important = [_]anyerror{ error.FileNotFound, error.PermissionDenied };

    for (critical) |critical_err| {
        if (err == critical_err) {
            // Critical error - abort immediately
            return err;
        }
    }

    for (important) |important_err| {
        if (err == important_err) {
            // Important error - log and continue
            return;
        }
    }

    // Other errors - ignore
}

test "prioritize error handling" {
    try testing.expectError(error.OutOfMemory, handleByPriority(error.OutOfMemory));
    try handleByPriority(error.FileNotFound);
    try handleByPriority(error.UnknownError);
}
// ANCHOR_END: error_priority

// ANCHOR: parallel_errors
const ParallelResult = struct {
    success_count: usize = 0,
    errors: std.ArrayList(anyerror),

    fn init() ParallelResult {
        return .{
            .errors = std.ArrayList(anyerror){},
        };
    }

    fn deinit(self: *ParallelResult, allocator: std.mem.Allocator) void {
        self.errors.deinit(allocator);
    }

    fn recordSuccess(self: *ParallelResult) void {
        self.success_count += 1;
    }

    fn recordError(self: *ParallelResult, allocator: std.mem.Allocator, err: anyerror) !void {
        try self.errors.append(allocator, err);
    }
};

fn parallelOperations(allocator: std.mem.Allocator) !ParallelResult {
    var result = ParallelResult.init();

    // Simulate parallel operations
    const operations = [_]?anyerror{ null, error.Op1Failed, null, error.Op2Failed };

    for (operations) |maybe_err| {
        if (maybe_err) |err| {
            try result.recordError(allocator, err);
        } else {
            result.recordSuccess();
        }
    }

    return result;
}

test "collect errors from parallel operations" {
    var result = try parallelOperations(testing.allocator);
    defer result.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 2), result.success_count);
    try testing.expectEqual(@as(usize, 2), result.errors.items.len);
}
// ANCHOR_END: parallel_errors
