const std = @import("std");
const testing = std.testing;

// ANCHOR: dependency_injection
const DataSource = struct {
    fetchDataFn: *const fn (allocator: std.mem.Allocator) anyerror![]const u8,

    fn fetchData(self: *const DataSource, allocator: std.mem.Allocator) ![]const u8 {
        return self.fetchDataFn(allocator);
    }
};

fn realFetchData(allocator: std.mem.Allocator) ![]const u8 {
    // In real code, this might call an API
    return allocator.dupe(u8, "real data from API");
}

fn processData(source: *const DataSource, allocator: std.mem.Allocator) ![]const u8 {
    const data = try source.fetchData(allocator);
    defer allocator.free(data);

    // Process the data
    return std.fmt.allocPrint(allocator, "Processed: {s}", .{data});
}

test "patch data source with test implementation" {
    const TestFetchData = struct {
        fn fetch(allocator: std.mem.Allocator) ![]const u8 {
            return allocator.dupe(u8, "test data");
        }
    };

    const test_source = DataSource{ .fetchDataFn = TestFetchData.fetch };
    const result = try processData(&test_source, testing.allocator);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Processed: test data", result);
}
// ANCHOR_END: dependency_injection

// ANCHOR: interface_pattern
const FileSystem = struct {
    readFileFn: *const fn (ctx: *anyopaque, path: []const u8, allocator: std.mem.Allocator) anyerror![]const u8,
    ctx: *anyopaque,

    fn readFile(self: *const FileSystem, path: []const u8, allocator: std.mem.Allocator) ![]const u8 {
        return self.readFileFn(self.ctx, path, allocator);
    }
};

const RealFileSystem = struct {
    fn readFile(ctx: *anyopaque, path: []const u8, allocator: std.mem.Allocator) ![]const u8 {
        _ = ctx;
        _ = path;
        // In real code: return std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
        return allocator.dupe(u8, "file contents");
    }

    fn init() FileSystem {
        return .{
            .readFileFn = readFile,
            .ctx = undefined,
        };
    }
};

fn loadConfig(fs: *const FileSystem, allocator: std.mem.Allocator) ![]const u8 {
    return fs.readFile("config.txt", allocator);
}

test "patch filesystem with mock implementation" {
    const MockFileSystem = struct {
        fn readFile(ctx: *anyopaque, path: []const u8, allocator: std.mem.Allocator) ![]const u8 {
            _ = ctx;
            if (std.mem.eql(u8, path, "config.txt")) {
                return allocator.dupe(u8, "mock config data");
            }
            return error.FileNotFound;
        }
    };

    const mock_fs = FileSystem{
        .readFileFn = MockFileSystem.readFile,
        .ctx = undefined,
    };

    const config = try loadConfig(&mock_fs, testing.allocator);
    defer testing.allocator.free(config);

    try testing.expectEqualStrings("mock config data", config);
}
// ANCHOR_END: interface_pattern

// ANCHOR: state_tracking
const Logger = struct {
    logFn: *const fn (ctx: *anyopaque, level: []const u8, message: []const u8) void,
    ctx: *anyopaque,

    fn log(self: *Logger, level: []const u8, message: []const u8) void {
        self.logFn(self.ctx, level, message);
    }
};

const TestLogger = struct {
    messages: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) TestLogger {
        return .{
            .messages = std.ArrayList([]const u8){},
            .allocator = allocator,
        };
    }

    fn deinit(self: *TestLogger) void {
        for (self.messages.items) |msg| {
            self.allocator.free(msg);
        }
        self.messages.deinit(self.allocator);
    }

    fn log(ctx: *anyopaque, level: []const u8, message: []const u8) void {
        const self: *TestLogger = @ptrCast(@alignCast(ctx));
        const combined = std.fmt.allocPrint(self.allocator, "[{s}] {s}", .{ level, message }) catch return;
        self.messages.append(self.allocator, combined) catch return;
    }

    fn toLogger(self: *TestLogger) Logger {
        return .{
            .logFn = log,
            .ctx = @ptrCast(self),
        };
    }
};

fn doWork(logger: *Logger) void {
    logger.log("INFO", "Starting work");
    logger.log("DEBUG", "Processing item 1");
    logger.log("DEBUG", "Processing item 2");
    logger.log("INFO", "Work complete");
}

test "track logging calls with test logger" {
    var test_logger = TestLogger.init(testing.allocator);
    defer test_logger.deinit();

    var logger = test_logger.toLogger();
    doWork(&logger);

    try testing.expectEqual(@as(usize, 4), test_logger.messages.items.len);
    try testing.expect(std.mem.indexOf(u8, test_logger.messages.items[0], "Starting work") != null);
    try testing.expect(std.mem.indexOf(u8, test_logger.messages.items[3], "Work complete") != null);
}
// ANCHOR_END: state_tracking

// ANCHOR: error_simulation
const Database = struct {
    queryFn: *const fn (ctx: *anyopaque, sql: []const u8) anyerror!i32,
    ctx: *anyopaque,

    fn query(self: *const Database, sql: []const u8) !i32 {
        return self.queryFn(self.ctx, sql);
    }
};

fn getUserCount(db: *const Database) !i32 {
    return db.query("SELECT COUNT(*) FROM users");
}

test "simulate database errors" {
    const ErrorDB = struct {
        fn query(ctx: *anyopaque, sql: []const u8) !i32 {
            _ = ctx;
            _ = sql;
            return error.ConnectionRefused;
        }
    };

    const error_db = Database{
        .queryFn = ErrorDB.query,
        .ctx = undefined,
    };

    const result = getUserCount(&error_db);
    try testing.expectError(error.ConnectionRefused, result);
}

test "simulate successful database query" {
    const SuccessDB = struct {
        fn query(ctx: *anyopaque, sql: []const u8) !i32 {
            _ = ctx;
            _ = sql;
            return 42;
        }
    };

    const success_db = Database{
        .queryFn = SuccessDB.query,
        .ctx = undefined,
    };

    const count = try getUserCount(&success_db);
    try testing.expectEqual(@as(i32, 42), count);
}
// ANCHOR_END: error_simulation

// ANCHOR: comptime_switching
fn HttpClient(comptime test_mode: bool) type {
    return struct {
        const Self = @This();

        fn get(self: Self, url: []const u8, allocator: std.mem.Allocator) ![]const u8 {
            _ = self;
            if (test_mode) {
                // Test implementation
                if (std.mem.eql(u8, url, "https://api.example.com/data")) {
                    return allocator.dupe(u8, "{\"status\":\"ok\"}");
                }
                return error.NotFound;
            } else {
                // Real implementation would make actual HTTP request
                // In production, url would be used here
                const response = try std.fmt.allocPrint(allocator, "real response from {s}", .{url});
                return response;
            }
        }
    };
}

fn fetchData(client: anytype, allocator: std.mem.Allocator) ![]const u8 {
    return client.get("https://api.example.com/data", allocator);
}

test "use comptime test mode" {
    const TestClient = HttpClient(true);
    const client = TestClient{};

    const data = try fetchData(client, testing.allocator);
    defer testing.allocator.free(data);

    try testing.expectEqualStrings("{\"status\":\"ok\"}", data);
}
// ANCHOR_END: comptime_switching

// ANCHOR: call_counting
const Counter = struct {
    count: usize = 0,

    fn increment(self: *Counter) void {
        self.count += 1;
    }
};

const ApiClient = struct {
    requestFn: *const fn (ctx: *anyopaque, endpoint: []const u8) anyerror!void,
    ctx: *anyopaque,
    counter: *Counter,

    fn request(self: *ApiClient, endpoint: []const u8) !void {
        self.counter.increment();
        return self.requestFn(self.ctx, endpoint);
    }
};

fn syncData(client: *ApiClient) !void {
    try client.request("/api/users");
    try client.request("/api/posts");
    try client.request("/api/comments");
}

test "count API calls" {
    const MockApi = struct {
        fn request(ctx: *anyopaque, endpoint: []const u8) !void {
            _ = ctx;
            _ = endpoint;
            // Do nothing, just count
        }
    };

    var counter = Counter{};
    var client = ApiClient{
        .requestFn = MockApi.request,
        .ctx = undefined,
        .counter = &counter,
    };

    try syncData(&client);
    try testing.expectEqual(@as(usize, 3), counter.count);
}
// ANCHOR_END: call_counting

// ANCHOR: return_sequence
const ValueProvider = struct {
    values: []const i32,
    index: usize = 0,

    fn next(self: *ValueProvider) ?i32 {
        if (self.index >= self.values.len) return null;
        const value = self.values[self.index];
        self.index += 1;
        return value;
    }
};

const Sensor = struct {
    readFn: *const fn (ctx: *anyopaque) anyerror!i32,
    ctx: *anyopaque,

    fn read(self: *Sensor) !i32 {
        return self.readFn(self.ctx);
    }
};

fn collectReadings(sensor: *Sensor, count: usize, allocator: std.mem.Allocator) ![]i32 {
    var readings = try std.ArrayList(i32).initCapacity(allocator, count);
    errdefer readings.deinit(allocator);

    var i: usize = 0;
    while (i < count) : (i += 1) {
        const value = try sensor.read();
        try readings.append(allocator, value);
    }

    return readings.toOwnedSlice(allocator);
}

test "return sequence of values" {
    const test_values = [_]i32{ 10, 20, 30, 40 };
    var provider = ValueProvider{ .values = &test_values };

    const MockSensor = struct {
        fn read(ctx: *anyopaque) !i32 {
            const self: *ValueProvider = @ptrCast(@alignCast(ctx));
            return self.next() orelse error.NoMoreData;
        }
    };

    var sensor = Sensor{
        .readFn = MockSensor.read,
        .ctx = @ptrCast(&provider),
    };

    const readings = try collectReadings(&sensor, 4, testing.allocator);
    defer testing.allocator.free(readings);

    try testing.expectEqual(@as(usize, 4), readings.len);
    try testing.expectEqual(@as(i32, 10), readings[0]);
    try testing.expectEqual(@as(i32, 40), readings[3]);
}
// ANCHOR_END: return_sequence
