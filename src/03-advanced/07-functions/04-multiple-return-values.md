## Problem

You need to return multiple values from a function without creating a complex data structure.

## Solution

Use anonymous structs (tuples) for simple multiple return values:

```zig
{{#include ../../../code/03-advanced/07-functions/recipe_7_4.zig:tuple_return}}
```

## Discussion

### Named Return Types

Use named structs for clarity and reusability:

```zig
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

test "named return type" {
    const result = divideWithInfo(20, 4);
    try std.testing.expectEqual(@as(i32, 5), result.quotient);
    try std.testing.expectEqual(@as(i32, 0), result.remainder);
    try std.testing.expect(result.is_exact);
}
```

### Error Union with Multiple Values

Combine error handling with multiple return values:

```zig
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

test "error union with multiple values" {
    const result = try parseInt("123abc");
    try std.testing.expectEqual(@as(i32, 123), result.value);
    try std.testing.expectEqualStrings("abc", result.remaining);

    try std.testing.expectError(error.EmptyInput, parseInt(""));
    try std.testing.expectError(error.InvalidFormat, parseInt("abc"));
}
```

### Optional Multiple Values

Return optional results:

```zig
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

test "optional multiple values" {
    const result = findByte("hello", 'l');
    try std.testing.expect(result != null);
    try std.testing.expectEqual(@as(usize, 2), result.?.index);

    const not_found = findByte("hello", 'x');
    try std.testing.expect(not_found == null);
}
```

### Tuple-Style Returns

Use tuples for simple, unnamed returns:

```zig
pub fn minMax(numbers: []const i32) struct { min: i32, max: i32 } {
    var min_val = numbers[0];
    var max_val = numbers[0];

    for (numbers[1..]) |n| {
        if (n < min_val) min_val = n;
        if (n > max_val) max_val = n;
    }

    return .{ .min = min_val, .max = max_val };
}

test "min max tuple" {
    const numbers = [_]i32{ 5, 2, 8, 1, 9, 3 };
    const result = minMax(&numbers);

    try std.testing.expectEqual(@as(i32, 1), result.min);
    try std.testing.expectEqual(@as(i32, 9), result.max);
}
```

### Multi-Step Computation Results

Return intermediate and final results:

```zig
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

test "calculate statistics" {
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    const stats = calculateStats(&numbers);

    try std.testing.expectEqual(@as(i64, 15), stats.sum);
    try std.testing.expectEqual(@as(usize, 5), stats.count);
    try std.testing.expectEqual(@as(f64, 3.0), stats.mean);
}
```

### Tagged Union Returns

Return different types of results:

```zig
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
```

### Allocated Return Values

Return values that own their memory:

```zig
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

test "allocated return values" {
    const allocator = std.testing.allocator;

    const result = try splitAndDuplicate(allocator, "hello:world", ':');
    defer result.deinit();

    try std.testing.expectEqualStrings("hello", result.before);
    try std.testing.expectEqualStrings("world", result.after);
}
```

### Compile-Time Multiple Returns

Return multiple compile-time values:

```zig
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

test "compile-time multiple returns" {
    const result1 = comptime splitType(*i32);
    try std.testing.expect(result1.is_pointer);
    try std.testing.expect(result1.base == i32);

    const result2 = comptime splitType(i32);
    try std.testing.expect(!result2.is_pointer);
    try std.testing.expect(result2.base == i32);
}
```

### Builder Pattern for Complex Returns

Use method chaining to build complex results:

```zig
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

test "builder pattern return" {
    const allocator = std.testing.allocator;

    const rows = [_][]const u8{ "row1", "row2", "row3" };
    const result = QueryResult.init(allocator)
        .withRows(&rows)
        .withMoreFlag(true);

    try std.testing.expectEqual(@as(usize, 3), result.count);
    try std.testing.expect(result.has_more);
}
```

### Best Practices

**Return Type Selection:**
```zig
// Simple pairs: use anonymous struct
fn getCoordinates() struct { x: f32, y: f32 }

// Reused type: use named struct
const Point = struct { x: f32, y: f32 };
fn getPoint() Point

// Different result types: use tagged union
const Result = union(enum) { ok: T, err: E };
```

**Destructuring:**
```zig
// Access fields directly
const result = divmod(17, 5);
std.debug.print("{} remainder {}\n", .{ result.quotient, result.remainder });

// Or destructure
const q, const r = .{ result.quotient, result.remainder };
```

**Error Handling:**
- Combine error unions with multiple values naturally
- Use tagged unions for different success/failure paths
- Return optionals when the entire result might be missing

**Memory Management:**
```zig
// Include allocator in return type for cleanup
const Result = struct {
    data: []u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: Result) void {
        self.allocator.free(self.data);
    }
};
```

### Related Functions

- Struct initialization syntax `.{}`
- Tuple destructuring with `const a, const b = tuple`
- `@typeInfo()` for compile-time type inspection
- Tagged unions for variant returns
- Error unions `!T` for fallible operations
- Optional `?T` for potentially missing values
