## Problem

You want to define functions with default argument values, but Zig doesn't have traditional default arguments like Python.

## Solution

Use configuration structs with default field values:

```zig
{{#include ../../../code/03-advanced/07-functions/recipe_7_5.zig:basic_defaults}}
```

## Discussion

### Single Optional Parameter

For functions with one optional parameter, use optionals directly:

```zig
pub fn greet(name: ?[]const u8) void {
    const actual_name = name orelse "World";
    std.debug.print("Hello, {s}!\n", .{actual_name});
}

test "optional parameter" {
    greet(null); // Uses default
    greet("Alice"); // Uses provided value
}
```

### Mixed Required and Optional Parameters

Combine required fields (no default) with optional ones:

```zig
const EmailOptions = struct {
    to: []const u8, // Required
    subject: []const u8, // Required
    from: []const u8 = "noreply@example.com", // Optional
    cc: ?[]const u8 = null, // Optional
    priority: enum { low, normal, high } = .normal, // Optional
};

pub fn sendEmail(options: EmailOptions) !void {
    std.debug.print("From: {s}\n", .{options.from});
    std.debug.print("To: {s}\n", .{options.to});
    std.debug.print("Subject: {s}\n", .{options.subject});

    if (options.cc) |cc| {
        std.debug.print("CC: {s}\n", .{cc});
    }

    std.debug.print("Priority: {s}\n", .{@tagName(options.priority)});
}

test "mixed required and optional" {
    // Required fields must be provided
    try sendEmail(.{
        .to = "user@example.com",
        .subject = "Test Email",
    });

    // Can override defaults
    try sendEmail(.{
        .to = "admin@example.com",
        .subject = "Important",
        .from = "boss@example.com",
        .cc = "team@example.com",
        .priority = .high,
    });
}
```

### Default Arguments for Generic Functions

Use comptime parameters with defaults:

```zig
pub fn ArrayList(comptime T: type) type {
    return ArrayListAligned(T, null);
}

pub fn ArrayListAligned(comptime T: type, comptime alignment: ?u29) type {
    return struct {
        items: if (alignment) |a| []align(a) T else []T,
        capacity: usize,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) @This() {
            return .{
                .items = &[_]T{},
                .capacity = 0,
                .allocator = allocator,
            };
        }
    };
}

test "generic with defaults" {
    const allocator = std.testing.allocator;

    // Use default alignment
    var list1 = ArrayList(i32).init(allocator);
    _ = list1;

    // Specify custom alignment
    var list2 = ArrayListAligned(i32, 16).init(allocator);
    _ = list2;
}
```

### Default Function Behavior

Pass function pointers as optional parameters:

```zig
const CompareFn = fn (a: i32, b: i32) bool;

fn defaultCompare(a: i32, b: i32) bool {
    return a < b;
}

pub fn sortWith(items: []i32, compare_fn: ?CompareFn) void {
    const cmp = compare_fn orelse defaultCompare;

    // Simple bubble sort for demonstration
    for (items, 0..) |_, i| {
        for (items[0 .. items.len - i - 1], 0..) |_, j| {
            if (!cmp(items[j], items[j + 1])) {
                const temp = items[j];
                items[j] = items[j + 1];
                items[j + 1] = temp;
            }
        }
    }
}

test "default function behavior" {
    var numbers = [_]i32{ 5, 2, 8, 1, 9 };

    // Use default comparison
    sortWith(&numbers, null);
    try std.testing.expectEqual(@as(i32, 1), numbers[0]);

    // Use custom comparison (descending)
    const descending = struct {
        fn cmp(a: i32, b: i32) bool {
            return a > b;
        }
    }.cmp;

    sortWith(&numbers, descending);
    try std.testing.expectEqual(@as(i32, 9), numbers[0]);
}
```

### Default Allocator Pattern

Common pattern for functions needing memory allocation:

```zig
pub fn processData(
    data: []const u8,
    allocator: ?std.mem.Allocator,
) ![]u8 {
    const alloc = allocator orelse std.heap.page_allocator;

    var result = try alloc.alloc(u8, data.len);
    errdefer alloc.free(result);

    // Process data
    for (data, 0..) |byte, i| {
        result[i] = std.ascii.toUpper(byte);
    }

    return result;
}

test "default allocator" {
    const data = "hello";

    // Use default allocator
    const result1 = try processData(data, null);
    defer std.heap.page_allocator.free(result1);
    try std.testing.expectEqualStrings("HELLO", result1);

    // Use specific allocator
    const result2 = try processData(data, std.testing.allocator);
    defer std.testing.allocator.free(result2);
    try std.testing.expectEqualStrings("HELLO", result2);
}
```

### Builder Pattern with Defaults

Incremental configuration with sensible defaults:

```zig
const HttpRequest = struct {
    url: []const u8,
    method: []const u8 = "GET",
    headers: std.StringHashMap([]const u8),
    timeout_ms: u32 = 30000,
    follow_redirects: bool = true,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, url: []const u8) HttpRequest {
        return .{
            .url = url,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn setMethod(self: *HttpRequest, method: []const u8) *HttpRequest {
        self.method = method;
        return self;
    }

    pub fn setTimeout(self: *HttpRequest, ms: u32) *HttpRequest {
        self.timeout_ms = ms;
        return self;
    }

    pub fn addHeader(self: *HttpRequest, key: []const u8, value: []const u8) !*HttpRequest {
        try self.headers.put(key, value);
        return self;
    }

    pub fn deinit(self: *HttpRequest) void {
        self.headers.deinit();
    }
};

test "builder with defaults" {
    const allocator = std.testing.allocator;

    var request = HttpRequest.init(allocator, "https://example.com");
    defer request.deinit();

    _ = request.setMethod("POST")
        .setTimeout(5000);

    try std.testing.expectEqualStrings("POST", request.method);
    try std.testing.expectEqual(@as(u32, 5000), request.timeout_ms);
    try std.testing.expect(request.follow_redirects); // Still default
}
```

### Default Values for Buffers

Pre-allocate buffers with sensible defaults:

```zig
const BufferOptions = struct {
    initial_capacity: usize = 4096,
    max_size: ?usize = null,
    clear_on_free: bool = false,
};

pub fn Buffer(comptime options: BufferOptions) type {
    return struct {
        data: []u8,
        len: usize,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) !Self {
            return .{
                .data = try allocator.alloc(u8, options.initial_capacity),
                .len = 0,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            if (options.clear_on_free) {
                @memset(self.data, 0);
            }
            self.allocator.free(self.data);
        }

        pub fn append(self: *Self, byte: u8) !void {
            if (options.max_size) |max| {
                if (self.len >= max) {
                    return error.BufferFull;
                }
            }

            if (self.len >= self.data.len) {
                const new_cap = self.data.len * 2;
                const new_data = try self.allocator.realloc(self.data, new_cap);
                self.data = new_data;
            }

            self.data[self.len] = byte;
            self.len += 1;
        }
    };
}

test "buffer with defaults" {
    const allocator = std.testing.allocator;

    // Default buffer
    var buf1 = try Buffer(.{}).init(allocator);
    defer buf1.deinit();

    try buf1.append('A');
    try std.testing.expectEqual(@as(usize, 1), buf1.len);

    // Custom buffer with size limit
    var buf2 = try Buffer(.{ .max_size = 10 }).init(allocator);
    defer buf2.deinit();

    for (0..10) |_| {
        try buf2.append('X');
    }

    try std.testing.expectError(error.BufferFull, buf2.append('Y'));
}
```

### Compile-Time Default Computation

Compute defaults at compile time:

```zig
pub fn Matrix(comptime rows: usize, comptime cols: usize, comptime default_value: f32) type {
    return struct {
        data: [rows][cols]f32,

        pub fn init() @This() {
            var result: @This() = undefined;
            for (&result.data) |*row| {
                for (row) |*cell| {
                    cell.* = default_value;
                }
            }
            return result;
        }

        pub fn get(self: @This(), row: usize, col: usize) f32 {
            return self.data[row][col];
        }
    };
}

test "compile-time defaults" {
    const Mat3x3 = Matrix(3, 3, 0.0);
    const matrix = Mat3x3.init();

    try std.testing.expectEqual(@as(f32, 0.0), matrix.get(0, 0));
    try std.testing.expectEqual(@as(f32, 0.0), matrix.get(2, 2));
}
```

### Default Error Handling Strategy

Provide default error handling:

```zig
const ErrorHandler = fn (err: anyerror) void;

fn defaultErrorHandler(err: anyerror) void {
    std.debug.print("Error occurred: {}\n", .{err});
}

pub fn executeWithHandler(
    operation: fn () anyerror!void,
    handler: ?ErrorHandler,
) void {
    const error_handler = handler orelse defaultErrorHandler;

    operation() catch |err| {
        error_handler(err);
    };
}

test "default error handler" {
    const failingOp = struct {
        fn run() anyerror!void {
            return error.SomethingWrong;
        }
    }.run;

    // Use default handler
    executeWithHandler(failingOp, null);

    // Use custom handler
    const customHandler = struct {
        fn handle(err: anyerror) void {
            _ = err;
            // Custom handling
        }
    }.handle;

    executeWithHandler(failingOp, customHandler);
}
```

### Best Practices

**Struct-Based Defaults:**
```zig
// Good: Clear defaults, named parameters
const Options = struct {
    size: usize = 100,
    enabled: bool = true,
};
fn process(options: Options) void {}

// Bad: Unclear what default values are
fn process(size: ?usize, enabled: ?bool) void {
    const s = size orelse 100;
    const e = enabled orelse true;
}
```

**Required vs Optional:**
- Make truly required parameters fields without defaults
- Use default values for optional parameters with sensible defaults
- Use `?T` for parameters that can be legitimately null

**Documentation:**
```zig
/// Opens a file with the specified options.
///
/// Default values:
/// - mode: .read_only
/// - buffer_size: 4096
/// - create_if_missing: false
const OpenOptions = struct {
    path: []const u8, // Required
    mode: std.fs.File.OpenMode = .read_only,
    buffer_size: usize = 4096,
    create_if_missing: bool = false,
};
```

**Type Safety:**
- Use enums for options with fixed choices
- Use distinct types for different kinds of parameters
- Leverage compile-time checks to validate configurations

### Related Functions

- Struct initialization syntax `.{}`
- Optional types `?T` and `orelse`
- Default struct field values
- `@hasField()` to check for optional configuration
- Comptime parameters for compile-time defaults
- Builder pattern for incremental configuration
