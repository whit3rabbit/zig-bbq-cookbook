const std = @import("std");
const testing = std.testing;

// ANCHOR: error_transformation
const LowLevelError = error{
    FileNotFound,
    AccessDenied,
    DiskFull,
};

const HighLevelError = error{
    ConfigurationError,
    InitializationFailed,
    ResourceUnavailable,
};

fn readConfigFile(path: []const u8) LowLevelError![]const u8 {
    if (std.mem.eql(u8, path, "missing.conf")) {
        return error.FileNotFound;
    }
    if (std.mem.eql(u8, path, "protected.conf")) {
        return error.AccessDenied;
    }
    return "config data";
}

fn loadConfiguration(path: []const u8) HighLevelError![]const u8 {
    const config = readConfigFile(path) catch |err| {
        std.debug.print("Failed to read config: {s}\n", .{@errorName(err)});
        return error.ConfigurationError;
    };
    return config;
}

test "transform low-level errors to high-level" {
    try testing.expectError(error.ConfigurationError, loadConfiguration("missing.conf"));
    try testing.expectError(error.ConfigurationError, loadConfiguration("protected.conf"));
    try testing.expectEqualStrings("config data", try loadConfiguration("valid.conf"));
}
// ANCHOR_END: error_transformation

// ANCHOR: error_context_chain
const IoError = error{ ReadFailed, WriteFailed, SeekFailed };
const DatabaseError = error{ QueryFailed, TransactionAborted };

const ErrorChain = struct {
    original: anyerror,
    context: []const u8,
    layer: u8,

    fn fromIoError(err: IoError, context: []const u8) DatabaseError {
        std.debug.print("IO Error ({s}) -> Database Error: {s}\n", .{ @errorName(err), context });
        return error.QueryFailed;
    }

    fn fromDbError(err: DatabaseError, context: []const u8) IoError {
        std.debug.print("DB Error ({s}) -> IO Error: {s}\n", .{ @errorName(err), context });
        return error.WriteFailed;
    }
};

fn lowLevelRead(should_fail: bool) IoError!i32 {
    if (should_fail) return error.ReadFailed;
    return 42;
}

fn databaseQuery(should_fail: bool) DatabaseError!i32 {
    const value = lowLevelRead(should_fail) catch |err| {
        return ErrorChain.fromIoError(err, "Database query requires file read");
    };
    return value;
}

test "chain errors with context" {
    try testing.expectEqual(@as(i32, 42), try databaseQuery(false));
    try testing.expectError(error.QueryFailed, databaseQuery(true));
}
// ANCHOR_END: error_context_chain

// ANCHOR: wrapping_errors
const OperationError = error{
    NetworkFailure,
    ParseFailure,
    ValidationFailure,
};

const Result = struct {
    value: ?i32,
    original_error: ?anyerror,
    wrapped_error: ?OperationError,
    message: []const u8,

    fn success(value: i32) Result {
        return .{
            .value = value,
            .original_error = null,
            .wrapped_error = null,
            .message = "Success",
        };
    }

    fn failure(original: anyerror, wrapped: OperationError, message: []const u8) Result {
        return .{
            .value = null,
            .original_error = original,
            .wrapped_error = wrapped,
            .message = message,
        };
    }
};

fn parseValue(input: []const u8) !i32 {
    if (input.len == 0) return error.EmptyInput;
    if (input[0] == 'x') return error.InvalidFormat;
    return 42;
}

fn processInput(input: []const u8) OperationError!Result {
    const value = parseValue(input) catch |err| {
        const wrapped_err = error.ParseFailure;
        const msg = "Failed to parse input value";
        return Result.failure(err, wrapped_err, msg);
    };
    return Result.success(value);
}

test "wrap errors with metadata" {
    const success = try processInput("42");
    try testing.expectEqual(@as(i32, 42), success.value.?);
    try testing.expect(success.wrapped_error == null);

    const failure = try processInput("");
    try testing.expect(failure.value == null);
    try testing.expectEqual(error.ParseFailure, failure.wrapped_error.?);
    try testing.expectEqualStrings("Failed to parse input value", failure.message);
}
// ANCHOR_END: wrapping_errors

// ANCHOR: conditional_wrapping
fn openResource(name: []const u8) !void {
    if (std.mem.eql(u8, name, "locked")) return error.ResourceLocked;
    if (std.mem.eql(u8, name, "missing")) return error.ResourceNotFound;
}

fn acquireResource(name: []const u8, retry: bool) !void {
    openResource(name) catch |err| {
        // Decide whether to wrap based on error type
        if (err == error.ResourceLocked) {
            return if (retry) error.RetryableError else err;
        } else if (err == error.ResourceNotFound) {
            return error.PermanentError;
        } else {
            return err;
        }
    };
}

test "conditionally wrap errors" {
    try acquireResource("available", false);
    try testing.expectError(error.RetryableError, acquireResource("locked", true));
    try testing.expectError(error.ResourceLocked, acquireResource("locked", false));
    try testing.expectError(error.PermanentError, acquireResource("missing", false));
}
// ANCHOR_END: conditional_wrapping

// ANCHOR: error_enrichment
const EnrichedError = struct {
    category: ErrorCategory,
    original: anyerror,
    timestamp: i64,
    context: []const u8,

    fn fromError(err: anyerror, ctx: []const u8) EnrichedError {
        return .{
            .category = categorizeError(err),
            .original = err,
            .timestamp = std.time.milliTimestamp(),
            .context = ctx,
        };
    }
};

const ErrorCategory = enum {
    transient,
    permanent,
    unknown,
};

fn categorizeError(err: anyerror) ErrorCategory {
    const name = @errorName(err);
    if (std.mem.indexOf(u8, name, "Timeout") != null or
        std.mem.indexOf(u8, name, "Busy") != null)
    {
        return .transient;
    } else if (std.mem.indexOf(u8, name, "NotFound") != null or
        std.mem.indexOf(u8, name, "Invalid") != null)
    {
        return .permanent;
    }
    return .unknown;
}

fn performOperation(should_fail: bool) !i32 {
    if (should_fail) return error.Timeout;
    return 100;
}

fn wrappedOperation(should_fail: bool) !i32 {
    return performOperation(should_fail) catch |err| {
        const enriched = EnrichedError.fromError(err, "Operation context");
        std.debug.print("Enriched error: category={s}, error={s}\n", .{
            @tagName(enriched.category),
            @errorName(enriched.original),
        });

        return switch (enriched.category) {
            .transient => error.ShouldRetry,
            .permanent => error.ShouldAbort,
            .unknown => err,
        };
    };
}

test "enrich errors with metadata" {
    try testing.expectEqual(@as(i32, 100), try wrappedOperation(false));
    try testing.expectError(error.ShouldRetry, wrappedOperation(true));
}
// ANCHOR_END: error_enrichment

// ANCHOR: multi_layer_wrapping
const Layer1Error = error{ L1Failed };
const Layer2Error = error{ L2Failed };
const Layer3Error = error{ L3Failed };

fn layer1Operation(fail: bool) Layer1Error!i32 {
    if (fail) return error.L1Failed;
    return 1;
}

fn layer2Operation(fail: bool) Layer2Error!i32 {
    const result = layer1Operation(fail) catch |err| {
        std.debug.print("Layer 2 caught: {s}\n", .{@errorName(err)});
        return error.L2Failed;
    };
    return result * 2;
}

fn layer3Operation(fail: bool) Layer3Error!i32 {
    const result = layer2Operation(fail) catch |err| {
        std.debug.print("Layer 3 caught: {s}\n", .{@errorName(err)});
        return error.L3Failed;
    };
    return result * 3;
}

test "multi-layer error wrapping" {
    try testing.expectEqual(@as(i32, 6), try layer3Operation(false));
    try testing.expectError(error.L3Failed, layer3Operation(true));
}
// ANCHOR_END: multi_layer_wrapping

// ANCHOR: error_recovery_chain
const RecoveryStrategy = enum {
    retry,
    fallback,
    abort,
};

fn determineStrategy(err: anyerror) RecoveryStrategy {
    const name = @errorName(err);
    if (std.mem.indexOf(u8, name, "Timeout") != null) {
        return .retry;
    } else if (std.mem.indexOf(u8, name, "NotFound") != null) {
        return .fallback;
    }
    return .abort;
}

fn fetchData(source: u8) !i32 {
    switch (source) {
        0 => return error.Timeout,
        1 => return error.NotFound,
        2 => return error.FatalError,
        else => return 42,
    }
}

fn smartFetch(source: u8, default: i32) !i32 {
    return fetchData(source) catch |err| {
        const strategy = determineStrategy(err);
        std.debug.print("Error: {s}, Strategy: {s}\n", .{ @errorName(err), @tagName(strategy) });

        return switch (strategy) {
            .retry => error.ShouldRetry,
            .fallback => default,
            .abort => error.OperationAborted,
        };
    };
}

test "error recovery with strategy chain" {
    try testing.expectEqual(@as(i32, 42), try smartFetch(99, 0));
    try testing.expectError(error.ShouldRetry, smartFetch(0, 0));
    try testing.expectEqual(@as(i32, -1), try smartFetch(1, -1));
    try testing.expectError(error.OperationAborted, smartFetch(2, 0));
}
// ANCHOR_END: error_recovery_chain

// ANCHOR: error_stack_tracking
const ErrorStack = struct {
    errors: [10]?anyerror,
    contexts: [10][]const u8,
    count: usize,

    fn init() ErrorStack {
        return .{
            .errors = [_]?anyerror{null} ** 10,
            .contexts = [_][]const u8{""} ** 10,
            .count = 0,
        };
    }

    fn push(self: *ErrorStack, err: anyerror, context: []const u8) void {
        if (self.count < self.errors.len) {
            self.errors[self.count] = err;
            self.contexts[self.count] = context;
            self.count += 1;
        }
    }

    fn getStack(self: *const ErrorStack) []const ?anyerror {
        return self.errors[0..self.count];
    }
};

fn operation1(fail: bool, stack: *ErrorStack) !void {
    if (fail) {
        const err = error.Op1Failed;
        stack.push(err, "Operation 1");
        return err;
    }
}

fn operation2(fail: bool, stack: *ErrorStack) !void {
    operation1(fail, stack) catch {
        const wrapped = error.Op2Failed;
        stack.push(wrapped, "Operation 2 wrapping Op1");
        return wrapped;
    };
}

test "track error stack" {
    var stack = ErrorStack.init();
    operation2(true, &stack) catch {};

    try testing.expectEqual(@as(usize, 2), stack.count);
    try testing.expectEqual(error.Op1Failed, stack.errors[0].?);
    try testing.expectEqual(error.Op2Failed, stack.errors[1].?);
}
// ANCHOR_END: error_stack_tracking
