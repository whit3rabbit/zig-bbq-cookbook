const std = @import("std");

// ANCHOR: basic_multiple_returns
/// Simple division with quotient and remainder
pub fn divmod(a: i32, b: i32) struct { quotient: i32, remainder: i32 } {
    return .{
        .quotient = @divTrunc(a, b),
        .remainder = @mod(a, b),
    };
}

/// Named return type for division
const DivResult = struct {
    quotient: i32,
    remainder: i32,
    is_exact: bool,
};

pub fn divideWithInfo(a: i32, b: i32) DivResult {
    const quot = @divTrunc(a, b);
    const rem = @mod(a, b);

    return .{
        .quotient = quot,
        .remainder = rem,
        .is_exact = rem == 0,
    };
}
// ANCHOR_END: basic_multiple_returns

// ANCHOR: error_union_returns
/// Parse result with remaining input
const ParseResult = struct {
    value: i32,
    remaining: []const u8,
};

pub fn parseInt(input: []const u8) !ParseResult {
    if (input.len == 0) {
        return error.EmptyInput;
    }

    var i: usize = 0;
    var value: i32 = 0;
    var sign: i32 = 1;

    // Handle sign
    if (input[0] == '-') {
        sign = -1;
        i = 1;
    } else if (input[0] == '+') {
        i = 1;
    }

    // Parse digits
    if (i >= input.len or !std.ascii.isDigit(input[i])) {
        return error.InvalidFormat;
    }

    while (i < input.len and std.ascii.isDigit(input[i])) : (i += 1) {
        value = value * 10 + @as(i32, input[i] - '0');
    }

    return .{
        .value = value * sign,
        .remaining = input[i..],
    };
}
// ANCHOR_END: error_union_returns

// ANCHOR: tagged_union_returns
/// Search result with optional match
const SearchResult = struct {
    index: usize,
    value: u8,
};

pub fn findByte(haystack: []const u8, needle: u8) ?SearchResult {
    for (haystack, 0..) |byte, i| {
        if (byte == needle) {
            return .{ .index = i, .value = byte };
        }
    }
    return null;
}

/// Min and max from slice
pub fn minMax(numbers: []const i32) struct { min: i32, max: i32 } {
    var min_val = numbers[0];
    var max_val = numbers[0];

    for (numbers[1..]) |n| {
        if (n < min_val) min_val = n;
        if (n > max_val) max_val = n;
    }

    return .{ .min = min_val, .max = max_val };
}

/// Statistics calculation
const Statistics = struct {
    sum: i64,
    count: usize,
    mean: f64,
    min: i32,
    max: i32,
};

pub fn calculateStats(numbers: []const i32) Statistics {
    var sum: i64 = 0;
    var min_val = numbers[0];
    var max_val = numbers[0];

    for (numbers) |n| {
        sum += n;
        if (n < min_val) min_val = n;
        if (n > max_val) max_val = n;
    }

    const mean = @as(f64, @floatFromInt(sum)) / @as(f64, @floatFromInt(numbers.len));

    return .{
        .sum = sum,
        .count = numbers.len,
        .mean = mean,
        .min = min_val,
        .max = max_val,
    };
}

/// Tagged union for different result types
const ProcessResult = union(enum) {
    success: struct {
        value: i32,
        message: []const u8,
    },
    warning: struct {
        value: i32,
        warning: []const u8,
    },
    failure: []const u8,
};

pub fn processValue(input: i32) ProcessResult {
    if (input < 0) {
        return .{ .failure = "Negative value not allowed" };
    } else if (input > 100) {
        return .{ .warning = .{
            .value = 100,
            .warning = "Value clamped to maximum",
        } };
    } else {
        return .{ .success = .{
            .value = input,
            .message = "Processed successfully",
        } };
    }
}
// ANCHOR_END: tagged_union_returns

/// Split result with owned memory
const SplitResult = struct {
    before: []const u8,
    after: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: SplitResult) void {
        self.allocator.free(self.before);
        self.allocator.free(self.after);
    }
};

pub fn splitAndDuplicate(
    allocator: std.mem.Allocator,
    input: []const u8,
    delimiter: u8,
) !SplitResult {
    const index = std.mem.indexOfScalar(u8, input, delimiter) orelse input.len;

    const before = try allocator.dupe(u8, input[0..index]);
    errdefer allocator.free(before);

    const after = if (index < input.len)
        try allocator.dupe(u8, input[index + 1 ..])
    else
        try allocator.alloc(u8, 0);

    return .{
        .before = before,
        .after = after,
        .allocator = allocator,
    };
}

/// Compile-time type splitting
pub fn splitType(comptime T: type) struct { base: type, is_pointer: bool } {
    const info = @typeInfo(T);
    return switch (info) {
        .pointer => |ptr| .{
            .base = ptr.child,
            .is_pointer = true,
        },
        else => .{
            .base = T,
            .is_pointer = false,
        },
    };
}

/// Query result with builder pattern
const QueryResult = struct {
    rows: []const []const u8,
    count: usize,
    has_more: bool,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) QueryResult {
        return .{
            .rows = &[_][]const u8{},
            .count = 0,
            .has_more = false,
            .allocator = allocator,
        };
    }

    pub fn withRows(self: QueryResult, rows: []const []const u8) QueryResult {
        var result = self;
        result.rows = rows;
        result.count = rows.len;
        return result;
    }

    pub fn withMoreFlag(self: QueryResult, has_more: bool) QueryResult {
        var result = self;
        result.has_more = has_more;
        return result;
    }
};

/// Coordinate pair
const Point = struct {
    x: f32,
    y: f32,
};

pub fn getCoordinates() struct { x: f32, y: f32 } {
    return .{ .x = 10.0, .y = 20.0 };
}

pub fn getPoint() Point {
    return .{ .x = 10.0, .y = 20.0 };
}

/// Error union with tuple return
pub fn parseCoordinates(input: []const u8) !struct { x: i32, y: i32 } {
    var iter = std.mem.splitScalar(u8, input, ',');
    const x_str = iter.next() orelse return error.InvalidFormat;
    const y_str = iter.next() orelse return error.InvalidFormat;

    const x = try std.fmt.parseInt(i32, std.mem.trim(u8, x_str, " "), 10);
    const y = try std.fmt.parseInt(i32, std.mem.trim(u8, y_str, " "), 10);

    return .{ .x = x, .y = y };
}

/// Range with start and end
pub fn getRange(start: usize, count: usize) struct { start: usize, end: usize } {
    return .{
        .start = start,
        .end = start + count,
    };
}

// Tests

test "returning multiple values" {
    const result = divmod(17, 5);
    try std.testing.expectEqual(@as(i32, 3), result.quotient);
    try std.testing.expectEqual(@as(i32, 2), result.remainder);

    // Destructure at call site
    const q, const r = .{ result.quotient, result.remainder };
    try std.testing.expectEqual(@as(i32, 3), q);
    try std.testing.expectEqual(@as(i32, 2), r);
}

test "named return type" {
    const result = divideWithInfo(20, 4);
    try std.testing.expectEqual(@as(i32, 5), result.quotient);
    try std.testing.expectEqual(@as(i32, 0), result.remainder);
    try std.testing.expect(result.is_exact);
}

test "error union with multiple values" {
    const result = try parseInt("123abc");
    try std.testing.expectEqual(@as(i32, 123), result.value);
    try std.testing.expectEqualStrings("abc", result.remaining);

    try std.testing.expectError(error.EmptyInput, parseInt(""));
    try std.testing.expectError(error.InvalidFormat, parseInt("abc"));
}

test "optional multiple values" {
    const result = findByte("hello", 'l');
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(usize, 2), result.?.index);

    const not_found = findByte("hello", 'x');
    try std.testing.expect(not_found == null);
}

test "min max tuple" {
    const numbers = [_]i32{ 5, 2, 8, 1, 9, 3 };
    const result = minMax(&numbers);

    try std.testing.expectEqual(@as(i32, 1), result.min);
    try std.testing.expectEqual(@as(i32, 9), result.max);
}

test "calculate statistics" {
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    const stats = calculateStats(&numbers);

    try std.testing.expectEqual(@as(i64, 15), stats.sum);
    try std.testing.expectEqual(@as(usize, 5), stats.count);
    try std.testing.expectEqual(@as(f64, 3.0), stats.mean);
}

test "tagged union return" {
    const ok = processValue(50);
    try std.testing.expect(ok == .success);
    try std.testing.expectEqual(@as(i32, 50), ok.success.value);

    const warned = processValue(150);
    try std.testing.expect(warned == .warning);
    try std.testing.expectEqual(@as(i32, 100), warned.warning.value);

    const err = processValue(-10);
    try std.testing.expect(err == .failure);
}

test "allocated return values" {
    const allocator = std.testing.allocator;

    const result = try splitAndDuplicate(allocator, "hello:world", ':');
    defer result.deinit();

    try std.testing.expectEqualStrings("hello", result.before);
    try std.testing.expectEqualStrings("world", result.after);
}

test "compile-time multiple returns" {
    const result1 = comptime splitType(*i32);
    try std.testing.expect(result1.is_pointer);
    try std.testing.expect(result1.base == i32);

    const result2 = comptime splitType(i32);
    try std.testing.expect(!result2.is_pointer);
    try std.testing.expect(result2.base == i32);
}

test "builder pattern return" {
    const allocator = std.testing.allocator;

    const rows = [_][]const u8{ "row1", "row2", "row3" };
    const result = QueryResult.init(allocator)
        .withRows(&rows)
        .withMoreFlag(true);

    try std.testing.expectEqual(@as(usize, 3), result.count);
    try std.testing.expect(result.has_more);
}

test "anonymous vs named struct" {
    const anon = getCoordinates();
    const named = getPoint();

    try std.testing.expectEqual(@as(f32, 10.0), anon.x);
    try std.testing.expectEqual(@as(f32, 20.0), anon.y);
    try std.testing.expectEqual(@as(f32, 10.0), named.x);
    try std.testing.expectEqual(@as(f32, 20.0), named.y);
}

test "error union with tuple" {
    const result = try parseCoordinates("10, 20");
    try std.testing.expectEqual(@as(i32, 10), result.x);
    try std.testing.expectEqual(@as(i32, 20), result.y);

    try std.testing.expectError(error.InvalidFormat, parseCoordinates("10"));
}

test "range calculation" {
    const range = getRange(5, 10);
    try std.testing.expectEqual(@as(usize, 5), range.start);
    try std.testing.expectEqual(@as(usize, 15), range.end);
}

test "negative number parsing" {
    const result = try parseInt("-456xyz");
    try std.testing.expectEqual(@as(i32, -456), result.value);
    try std.testing.expectEqualStrings("xyz", result.remaining);
}

test "split with no delimiter" {
    const allocator = std.testing.allocator;

    const result = try splitAndDuplicate(allocator, "hello", ':');
    defer result.deinit();

    try std.testing.expectEqualStrings("hello", result.before);
    try std.testing.expectEqualStrings("", result.after);
}
