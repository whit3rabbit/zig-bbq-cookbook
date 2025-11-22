// Recipe 18.4: Object Pool Management
// This recipe demonstrates creating object pools for efficient reuse of expensive-to-create objects,
// reducing allocation overhead and improving performance for frequently allocated/freed objects.

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

// ANCHOR: basic_pool
// Basic object pool with free list
fn Pool(comptime T: type) type {
    return struct {
        const Self = @This();
        const Node = struct {
            data: T,
            next: ?*Node,
        };

        allocator: Allocator,
        free_list: ?*Node,
        capacity: usize,
        used: usize,

        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
                .free_list = null,
                .capacity = 0,
                .used = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            while (self.free_list) |node| {
                self.free_list = node.next;
                self.allocator.destroy(node);
            }
        }

        pub fn acquire(self: *Self) !*T {
            if (self.free_list) |node| {
                self.free_list = node.next;
                self.used += 1;
                return &node.data;
            }

            const node = try self.allocator.create(Node);
            node.* = .{
                .data = undefined,
                .next = null,
            };
            self.capacity += 1;
            self.used += 1;
            return &node.data;
        }

        pub fn release(self: *Self, item: *T) void {
            const node: *Node = @alignCast(@fieldParentPtr("data", item));
            node.next = self.free_list;
            self.free_list = node;
            self.used -= 1;
        }
    };
}

test "basic object pool" {
    var pool = Pool(u32).init(testing.allocator);
    defer pool.deinit();

    // Acquire objects
    const obj1 = try pool.acquire();
    obj1.* = 42;
    const obj2 = try pool.acquire();
    obj2.* = 99;

    try testing.expectEqual(@as(usize, 2), pool.used);
    try testing.expectEqual(@as(usize, 2), pool.capacity);

    // Release and reuse
    pool.release(obj1);
    try testing.expectEqual(@as(usize, 1), pool.used);

    const obj3 = try pool.acquire();
    try testing.expectEqual(@as(usize, 2), pool.capacity); // Reused, no new allocation
    obj3.* = 123;

    pool.release(obj2);
    pool.release(obj3);
}
// ANCHOR_END: basic_pool

// ANCHOR: preallocated_pool
// Pre-allocated pool with fixed capacity
fn PreallocatedPool(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();

        objects: [capacity]T,
        available: [capacity]bool,
        count: usize,

        pub fn init() Self {
            const self = Self{
                .objects = undefined,
                .available = [_]bool{true} ** capacity,
                .count = 0,
            };
            return self;
        }

        pub fn acquire(self: *Self) ?*T {
            for (&self.available, 0..) |*avail, i| {
                if (avail.*) {
                    avail.* = false;
                    self.count += 1;
                    return &self.objects[i];
                }
            }
            return null;
        }

        pub fn release(self: *Self, item: *T) void {
            const index = (@intFromPtr(item) - @intFromPtr(&self.objects[0])) / @sizeOf(T);
            self.available[index] = true;
            self.count -= 1;
        }

        pub fn available_count(self: Self) usize {
            return capacity - self.count;
        }
    };
}

test "preallocated pool" {
    var pool = PreallocatedPool(u64, 10).init();

    // Acquire all objects
    var objects: [10]*u64 = undefined;
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        objects[i] = pool.acquire() orelse return error.PoolExhausted;
        objects[i].* = i;
    }

    try testing.expectEqual(@as(usize, 0), pool.available_count());
    try testing.expect(pool.acquire() == null); // Pool exhausted

    // Release and reuse
    pool.release(objects[5]);
    try testing.expectEqual(@as(usize, 1), pool.available_count());

    const obj = pool.acquire() orelse return error.PoolExhausted;
    obj.* = 999;
    try testing.expectEqual(@as(usize, 0), pool.available_count());

    // Clean up
    for (objects[0..5]) |o| pool.release(o);
    for (objects[6..]) |o| pool.release(o);
    pool.release(obj);
}
// ANCHOR_END: preallocated_pool

// ANCHOR: thread_safe_pool
// Thread-safe object pool
fn ThreadSafePool(comptime T: type) type {
    return struct {
        const Self = @This();
        const Node = struct {
            data: T,
            next: ?*Node,
        };

        allocator: Allocator,
        free_list: ?*Node,
        mutex: std.Thread.Mutex,
        capacity: usize,
        used: usize,

        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
                .free_list = null,
                .mutex = .{},
                .capacity = 0,
                .used = 0,
            };
        }

        pub fn deinit(self: *Self) void {
            self.mutex.lock();
            defer self.mutex.unlock();

            while (self.free_list) |node| {
                self.free_list = node.next;
                self.allocator.destroy(node);
            }
        }

        pub fn acquire(self: *Self) !*T {
            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.free_list) |node| {
                self.free_list = node.next;
                self.used += 1;
                return &node.data;
            }

            const node = try self.allocator.create(Node);
            node.* = .{
                .data = undefined,
                .next = null,
            };
            self.capacity += 1;
            self.used += 1;
            return &node.data;
        }

        pub fn release(self: *Self, item: *T) void {
            self.mutex.lock();
            defer self.mutex.unlock();

            const node: *Node = @alignCast(@fieldParentPtr("data", item));
            node.next = self.free_list;
            self.free_list = node;
            self.used -= 1;
        }
    };
}

test "thread-safe pool" {
    var pool = ThreadSafePool(u32).init(testing.allocator);
    defer pool.deinit();

    const obj1 = try pool.acquire();
    obj1.* = 100;

    const obj2 = try pool.acquire();
    obj2.* = 200;

    pool.release(obj1);
    pool.release(obj2);

    const obj3 = try pool.acquire();
    try testing.expect(obj3.* == 200 or obj3.* == 100);

    pool.release(obj3);
}
// ANCHOR_END: thread_safe_pool

// ANCHOR: connection_pool
// Connection pool example
const Connection = struct {
    id: u32,
    connected: bool,

    pub fn init(id: u32) Connection {
        return .{
            .id = id,
            .connected = false,
        };
    }

    pub fn connect(self: *Connection) !void {
        self.connected = true;
    }

    pub fn disconnect(self: *Connection) void {
        self.connected = false;
    }
};

const ConnectionPool = struct {
    const Self = @This();
    pool: Pool(Connection),
    next_id: u32,

    pub fn init(allocator: Allocator) Self {
        return .{
            .pool = Pool(Connection).init(allocator),
            .next_id = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        self.pool.deinit();
    }

    pub fn acquire(self: *Self) !*Connection {
        const conn = try self.pool.acquire();
        if (!conn.connected) {
            conn.* = Connection.init(self.next_id);
            self.next_id += 1;
            try conn.connect();
        }
        return conn;
    }

    pub fn release(self: *Self, conn: *Connection) void {
        // Don't disconnect - keep connection open for reuse
        self.pool.release(conn);
    }
};

test "connection pool" {
    var pool = ConnectionPool.init(testing.allocator);
    defer pool.deinit();

    // Acquire connections
    const conn1 = try pool.acquire();
    try testing.expectEqual(@as(u32, 0), conn1.id);
    try testing.expect(conn1.connected);

    const conn2 = try pool.acquire();
    try testing.expectEqual(@as(u32, 1), conn2.id);

    // Release and reuse
    pool.release(conn1);
    const conn3 = try pool.acquire();
    try testing.expectEqual(@as(u32, 0), conn3.id); // Reused conn1
    try testing.expect(conn3.connected); // Still connected

    pool.release(conn2);
    pool.release(conn3);
}
// ANCHOR_END: connection_pool

// ANCHOR: pool_allocator
// Pool-based allocator for fixed-size allocations
fn PoolAllocator(comptime T: type) type {
    return struct {
        const Self = @This();
        pool: Pool(T),

        pub fn init(backing_allocator: Allocator) Self {
            return .{
                .pool = Pool(T).init(backing_allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.pool.deinit();
        }

        pub fn create(self: *Self) !*T {
            return try self.pool.acquire();
        }

        pub fn destroy(self: *Self, item: *T) void {
            self.pool.release(item);
        }
    };
}

test "pool allocator" {
    var pool_alloc = PoolAllocator(u64).init(testing.allocator);
    defer pool_alloc.deinit();

    // Allocate and free
    const obj1 = try pool_alloc.create();
    obj1.* = 42;

    const obj2 = try pool_alloc.create();
    obj2.* = 99;

    pool_alloc.destroy(obj1);

    const obj3 = try pool_alloc.create();
    obj3.* = 123;

    try testing.expectEqual(@as(usize, 2), pool_alloc.pool.capacity);

    pool_alloc.destroy(obj2);
    pool_alloc.destroy(obj3);
}
// ANCHOR_END: pool_allocator

// ANCHOR: performance_comparison
// Performance comparison: pool vs allocator
test "pool vs allocator performance" {
    const iterations = 1000;

    // Test regular allocator
    var alloc_timer = try std.time.Timer.start();
    {
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            const obj = try testing.allocator.create(u64);
            obj.* = i;
            testing.allocator.destroy(obj);
        }
    }
    const alloc_ns = alloc_timer.read();

    // Test pool
    var pool_timer = try std.time.Timer.start();
    {
        var pool = Pool(u64).init(testing.allocator);
        defer pool.deinit();

        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            const obj = try pool.acquire();
            obj.* = i;
            pool.release(obj);
        }
    }
    const pool_ns = pool_timer.read();

    std.debug.print("\nAllocator: {d}ns, Pool: {d}ns, Speedup: {d:.2}x\n", .{
        alloc_ns,
        pool_ns,
        @as(f64, @floatFromInt(alloc_ns)) / @as(f64, @floatFromInt(pool_ns)),
    });

    // Pool should be faster
    try testing.expect(pool_ns < alloc_ns);
}
// ANCHOR_END: performance_comparison

// ANCHOR: lazy_pool
// Pool with lazy initialization
fn LazyPool(comptime T: type, comptime init_fn: fn () T) type {
    return struct {
        const Self = @This();
        const Node = struct {
            data: T,
            initialized: bool,
            next: ?*Node,
        };

        allocator: Allocator,
        free_list: ?*Node,

        pub fn init(allocator: Allocator) Self {
            return .{
                .allocator = allocator,
                .free_list = null,
            };
        }

        pub fn deinit(self: *Self) void {
            while (self.free_list) |node| {
                self.free_list = node.next;
                self.allocator.destroy(node);
            }
        }

        pub fn acquire(self: *Self) !*T {
            if (self.free_list) |node| {
                self.free_list = node.next;
                return &node.data;
            }

            const node = try self.allocator.create(Node);
            node.* = .{
                .data = init_fn(),
                .initialized = true,
                .next = null,
            };
            return &node.data;
        }

        pub fn release(self: *Self, item: *T) void {
            const node: *Node = @alignCast(@fieldParentPtr("data", item));
            node.next = self.free_list;
            self.free_list = node;
        }
    };
}

fn initCounter() u32 {
    return 0;
}

test "lazy pool initialization" {
    var pool = LazyPool(u32, initCounter).init(testing.allocator);
    defer pool.deinit();

    const obj1 = try pool.acquire();
    try testing.expectEqual(@as(u32, 0), obj1.*);
    obj1.* = 42;

    pool.release(obj1);

    const obj2 = try pool.acquire();
    try testing.expectEqual(@as(u32, 42), obj2.*); // Preserves previous value

    pool.release(obj2);
}
// ANCHOR_END: lazy_pool
