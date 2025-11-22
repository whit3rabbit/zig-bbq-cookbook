const std = @import("std");
const testing = std.testing;
const Thread = std.Thread;
const Mutex = Thread.Mutex;
const RwLock = Thread.RwLock;

// ANCHOR: basic_rwlock
const SharedData = struct {
    value: i32,
    lock: RwLock,

    fn init() SharedData {
        return .{
            .value = 0,
            .lock = .{},
        };
    }

    fn read(self: *SharedData) i32 {
        self.lock.lockShared();
        defer self.lock.unlockShared();
        return self.value;
    }

    fn write(self: *SharedData, value: i32) void {
        self.lock.lock();
        defer self.lock.unlock();
        self.value = value;
    }
};

test "read-write lock basic usage" {
    var data = SharedData.init();

    data.write(42);
    const value = data.read();

    try testing.expectEqual(@as(i32, 42), value);
}
// ANCHOR_END: basic_rwlock

// ANCHOR: concurrent_readers
fn reader(data: *SharedData, sum: *std.atomic.Value(i32)) void {
    var total: i32 = 0;
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        total += data.read();
        Thread.sleep(std.time.ns_per_ms);
    }
    _ = sum.fetchAdd(@as(i32, total), .monotonic);
}

fn writer(data: *SharedData) void {
    var i: i32 = 1;
    while (i <= 10) : (i += 1) {
        data.write(i);
        Thread.sleep(10 * std.time.ns_per_ms);
    }
}

test "multiple concurrent readers" {
    var data = SharedData.init();
    data.write(5);

    var sum = std.atomic.Value(i32).init(0);

    var readers: [4]Thread = undefined;
    for (&readers) |*thread| {
        thread.* = try Thread.spawn(.{}, reader, .{ &data, &sum });
    }

    const writer_thread = try Thread.spawn(.{}, writer, .{&data});

    for (readers) |thread| {
        thread.join();
    }
    writer_thread.join();

    // Readers can proceed concurrently
    try testing.expect(sum.load(.monotonic) > 0);
}
// ANCHOR_END: concurrent_readers

// ANCHOR: cache_example
const Cache = struct {
    data: std.StringHashMap([]const u8),
    lock: RwLock,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) Cache {
        return .{
            .data = std.StringHashMap([]const u8).init(allocator),
            .lock = .{},
            .allocator = allocator,
        };
    }

    fn deinit(self: *Cache) void {
        self.data.deinit();
    }

    fn get(self: *Cache, key: []const u8) ?[]const u8 {
        self.lock.lockShared();
        defer self.lock.unlockShared();
        return self.data.get(key);
    }

    fn put(self: *Cache, key: []const u8, value: []const u8) !void {
        self.lock.lock();
        defer self.lock.unlock();
        try self.data.put(key, value);
    }
};

test "cache with read-write lock" {
    var cache = Cache.init(testing.allocator);
    defer cache.deinit();

    try cache.put("key1", "value1");
    try cache.put("key2", "value2");

    const value1 = cache.get("key1");
    try testing.expect(value1 != null);
    try testing.expectEqualStrings("value1", value1.?);
}
// ANCHOR_END: cache_example

// ANCHOR: read_write_patterns
const Counter = struct {
    value: i32,
    lock: RwLock,

    fn init() Counter {
        return .{
            .value = 0,
            .lock = .{},
        };
    }

    fn increment(self: *Counter) void {
        self.lock.lock();
        defer self.lock.unlock();
        self.value += 1;
    }

    fn decrement(self: *Counter) void {
        self.lock.lock();
        defer self.lock.unlock();
        self.value -= 1;
    }

    fn get(self: *Counter) i32 {
        self.lock.lockShared();
        defer self.lock.unlockShared();
        return self.value;
    }
};

fn incrementWorker(counter: *Counter) void {
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        counter.increment();
    }
}

fn readWorker(counter: *Counter, samples: *std.atomic.Value(i32)) void {
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const value = counter.get();
        if (value > 0) {
            _ = samples.fetchAdd(@as(i32, 1), .monotonic);
        }
        Thread.sleep(std.time.ns_per_ms / 10);
    }
}

test "read-write patterns" {
    var counter = Counter.init();
    var samples = std.atomic.Value(i32).init(0);

    var writers: [2]Thread = undefined;
    var readers: [4]Thread = undefined;

    for (&writers) |*thread| {
        thread.* = try Thread.spawn(.{}, incrementWorker, .{&counter});
    }

    for (&readers) |*thread| {
        thread.* = try Thread.spawn(.{}, readWorker, .{ &counter, &samples });
    }

    for (writers) |thread| {
        thread.join();
    }
    for (readers) |thread| {
        thread.join();
    }

    try testing.expectEqual(@as(i32, 200), counter.get());
}
// ANCHOR_END: read_write_patterns
