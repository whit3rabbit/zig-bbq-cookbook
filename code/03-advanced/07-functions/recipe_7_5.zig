const std = @import("std");

// ANCHOR: basic_defaults
/// Connection options with defaults
const ConnectionOptions = struct {
    host: []const u8 = "localhost",
    port: u16 = 8080,
    timeout_ms: u32 = 5000,
    retries: u8 = 3,
};

pub fn connect(options: ConnectionOptions) !void {
    std.debug.print("Connecting to {s}:{d}\n", .{ options.host, options.port });
    std.debug.print("Timeout: {}ms, Retries: {}\n", .{ options.timeout_ms, options.retries });
}

/// Simple optional parameter
pub fn greet(name: ?[]const u8) void {
    const actual_name = name orelse "World";
    std.debug.print("Hello, {s}!\n", .{actual_name});
}
// ANCHOR_END: basic_defaults

// ANCHOR: optional_parameters
/// Email options with required and optional fields
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
// ANCHOR_END: optional_parameters

// ANCHOR: comptime_defaults
/// Generic array list with default alignment
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

/// Sorting with optional comparison function
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

/// Process data with optional allocator
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

/// HTTP request builder with defaults
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

/// Buffer with compile-time options
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
// ANCHOR_END: comptime_defaults

/// Matrix with compile-time default value
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

/// Error handling with default handler
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

/// File options
const FileOptions = struct {
    path: []const u8, // Required
    mode: enum { read, write, append } = .read,
    buffer_size: usize = 4096,
    create_if_missing: bool = false,
};

pub fn openFile(options: FileOptions) !void {
    std.debug.print("Opening: {s}\n", .{options.path});
    std.debug.print("Mode: {s}, Buffer: {}\n", .{
        @tagName(options.mode),
        options.buffer_size,
    });
    std.debug.print("Create if missing: {}\n", .{options.create_if_missing});
}

// Tests

test "default arguments" {
    // Use all defaults
    try connect(.{});

    // Override specific fields
    try connect(.{ .host = "example.com" });

    // Override multiple fields
    try connect(.{
        .host = "api.example.com",
        .port = 443,
        .timeout_ms = 10000,
    });
}

test "optional parameter" {
    greet(null); // Uses default
    greet("Alice"); // Uses provided value
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

test "generic with defaults" {
    const allocator = std.testing.allocator;

    // Use default alignment
    const list1 = ArrayList(i32).init(allocator);
    _ = list1;

    // Specify custom alignment
    const list2 = ArrayListAligned(i32, 16).init(allocator);
    _ = list2;
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

test "compile-time defaults" {
    const Mat3x3 = Matrix(3, 3, 0.0);
    const matrix = Mat3x3.init();

    try std.testing.expectEqual(@as(f32, 0.0), matrix.get(0, 0));
    try std.testing.expectEqual(@as(f32, 0.0), matrix.get(2, 2));
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
        var error_captured: ?anyerror = null;

        fn handle(err: anyerror) void {
            error_captured = err;
        }
    }.handle;

    executeWithHandler(failingOp, customHandler);
}

test "all defaults used" {
    const opts: ConnectionOptions = .{};
    try std.testing.expectEqualStrings("localhost", opts.host);
    try std.testing.expectEqual(@as(u16, 8080), opts.port);
    try std.testing.expectEqual(@as(u32, 5000), opts.timeout_ms);
    try std.testing.expectEqual(@as(u8, 3), opts.retries);
}

test "partial override" {
    const opts: ConnectionOptions = .{ .port = 443 };
    try std.testing.expectEqualStrings("localhost", opts.host);
    try std.testing.expectEqual(@as(u16, 443), opts.port);
}

test "file options with defaults" {
    try openFile(.{ .path = "/tmp/test.txt" });

    try openFile(.{
        .path = "/tmp/data.bin",
        .mode = .write,
        .create_if_missing = true,
    });
}

test "buffer initial capacity" {
    const allocator = std.testing.allocator;

    var buf = try Buffer(.{ .initial_capacity = 16 }).init(allocator);
    defer buf.deinit();

    try std.testing.expectEqual(@as(usize, 16), buf.data.len);
}

test "matrix with non-zero default" {
    const Mat2x2 = Matrix(2, 2, 1.0);
    const matrix = Mat2x2.init();

    try std.testing.expectEqual(@as(f32, 1.0), matrix.get(0, 0));
    try std.testing.expectEqual(@as(f32, 1.0), matrix.get(1, 1));
}
