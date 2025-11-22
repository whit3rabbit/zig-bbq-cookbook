const std = @import("std");
const testing = std.testing;
const Thread = std.Thread;
const Mutex = Thread.Mutex;

// ANCHOR: bounded_queue
const BoundedQueue = struct {
    buffer: []i32,
    head: usize,
    tail: usize,
    count: usize,
    mutex: Mutex,
    capacity: usize,

    fn init(allocator: std.mem.Allocator, capacity: usize) !BoundedQueue {
        const buffer = try allocator.alloc(i32, capacity);
        return .{
            .buffer = buffer,
            .head = 0,
            .tail = 0,
            .count = 0,
            .mutex = .{},
            .capacity = capacity,
        };
    }

    fn deinit(self: *BoundedQueue, allocator: std.mem.Allocator) void {
        allocator.free(self.buffer);
    }

    fn push(self: *BoundedQueue, item: i32) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.count >= self.capacity) {
            return false; // Queue full
        }

        self.buffer[self.tail] = item;
        self.tail = (self.tail + 1) % self.capacity;
        self.count += 1;
        return true;
    }

    fn pop(self: *BoundedQueue) ?i32 {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.count == 0) {
            return null; // Queue empty
        }

        const item = self.buffer[self.head];
        self.head = (self.head + 1) % self.capacity;
        self.count -= 1;
        return item;
    }

    fn size(self: *BoundedQueue) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.count;
    }
};

test "bounded queue basic operations" {
    var queue = try BoundedQueue.init(testing.allocator, 10);
    defer queue.deinit(testing.allocator);

    try testing.expect(queue.push(1));
    try testing.expect(queue.push(2));
    try testing.expect(queue.push(3));

    try testing.expectEqual(@as(usize, 3), queue.size());
    try testing.expectEqual(@as(i32, 1), queue.pop().?);
    try testing.expectEqual(@as(i32, 2), queue.pop().?);
    try testing.expectEqual(@as(i32, 3), queue.pop().?);
    try testing.expect(queue.pop() == null);
}
// ANCHOR_END: bounded_queue

// ANCHOR: producer_consumer
fn producer(queue: *BoundedQueue, count: i32) void {
    var i: i32 = 0;
    while (i < count) : (i += 1) {
        while (!queue.push(i)) {
            Thread.sleep(std.time.ns_per_ms);
        }
    }
}

fn consumer(queue: *BoundedQueue, result: *std.atomic.Value(i32)) void {
    var sum: i32 = 0;
    var received: i32 = 0;

    while (received < 100) {
        if (queue.pop()) |value| {
            sum += value;
            received += 1;
        } else {
            Thread.sleep(std.time.ns_per_ms);
        }
    }

    _ = result.fetchAdd(@as(i32, sum), .monotonic);
}

test "producer-consumer pattern" {
    var queue = try BoundedQueue.init(testing.allocator, 20);
    defer queue.deinit(testing.allocator);

    var result = std.atomic.Value(i32).init(0);

    const producer_thread = try Thread.spawn(.{}, producer, .{ &queue, 100 });
    const consumer_thread = try Thread.spawn(.{}, consumer, .{ &queue, &result });

    producer_thread.join();
    consumer_thread.join();

    // Sum of 0..99 = 4950
    try testing.expectEqual(@as(i32, 4950), result.load(.monotonic));
}
// ANCHOR_END: producer_consumer

// ANCHOR: mpsc_queue
const MPSCQueue = struct {
    items: std.ArrayList(i32),
    mutex: Mutex,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) MPSCQueue {
        return .{
            .items = std.ArrayList(i32){},
            .mutex = .{},
            .allocator = allocator,
        };
    }

    fn deinit(self: *MPSCQueue) void {
        self.items.deinit(self.allocator);
    }

    fn send(self: *MPSCQueue, value: i32) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        try self.items.append(self.allocator, value);
    }

    fn receive(self: *MPSCQueue) ?i32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        if (self.items.items.len == 0) return null;
        return self.items.orderedRemove(0);
    }
};

fn mpscProducer(queue: *MPSCQueue, id: i32, count: i32) void {
    var i: i32 = 0;
    while (i < count) : (i += 1) {
        queue.send(id * 1000 + i) catch {};
    }
}

fn mpscConsumer(queue: *MPSCQueue, total: *std.atomic.Value(i32)) void {
    var received: usize = 0;
    while (received < 300) {
        if (queue.receive()) |_| {
            _ = total.fetchAdd(@as(i32, 1), .monotonic);
            received += 1;
        } else {
            Thread.sleep(std.time.ns_per_ms);
        }
    }
}

test "multiple producer single consumer" {
    var queue = MPSCQueue.init(testing.allocator);
    defer queue.deinit();

    var total = std.atomic.Value(i32).init(0);

    var producers: [3]Thread = undefined;
    for (&producers, 0..) |*thread, i| {
        thread.* = try Thread.spawn(.{}, mpscProducer, .{ &queue, @as(i32, @intCast(i)), 100 });
    }

    const consumer_thread = try Thread.spawn(.{}, mpscConsumer, .{ &queue, &total });

    for (producers) |thread| {
        thread.join();
    }
    consumer_thread.join();

    try testing.expectEqual(@as(i32, 300), total.load(.monotonic));
}
// ANCHOR_END: mpsc_queue

// ANCHOR: channel
const Channel = struct {
    buffer: []i32,
    head: usize,
    tail: usize,
    count: usize,
    mutex: Mutex,
    capacity: usize,
    closed: bool,

    fn init(allocator: std.mem.Allocator, capacity: usize) !Channel {
        const buffer = try allocator.alloc(i32, capacity);
        return .{
            .buffer = buffer,
            .head = 0,
            .tail = 0,
            .count = 0,
            .mutex = .{},
            .capacity = capacity,
            .closed = false,
        };
    }

    fn deinit(self: *Channel, allocator: std.mem.Allocator) void {
        allocator.free(self.buffer);
    }

    fn send(self: *Channel, item: i32) !void {
        while (true) {
            self.mutex.lock();
            if (self.closed) {
                self.mutex.unlock();
                return error.ChannelClosed;
            }

            if (self.count < self.capacity) {
                self.buffer[self.tail] = item;
                self.tail = (self.tail + 1) % self.capacity;
                self.count += 1;
                self.mutex.unlock();
                return;
            }

            self.mutex.unlock();
            Thread.sleep(std.time.ns_per_ms);
        }
    }

    fn receive(self: *Channel) ?i32 {
        while (true) {
            self.mutex.lock();

            if (self.count > 0) {
                const item = self.buffer[self.head];
                self.head = (self.head + 1) % self.capacity;
                self.count -= 1;
                self.mutex.unlock();
                return item;
            }

            if (self.closed) {
                self.mutex.unlock();
                return null;
            }

            self.mutex.unlock();
            Thread.sleep(std.time.ns_per_ms);
        }
    }

    fn close(self: *Channel) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.closed = true;
    }
};

fn channelSender(ch: *Channel) void {
    var i: i32 = 0;
    while (i < 50) : (i += 1) {
        ch.send(i) catch break;
    }
    ch.close();
}

fn channelReceiver(ch: *Channel, sum: *std.atomic.Value(i32)) void {
    var total: i32 = 0;
    while (ch.receive()) |value| {
        total += value;
    }
    _ = sum.fetchAdd(@as(i32, total), .monotonic);
}

test "channel send and receive" {
    var channel = try Channel.init(testing.allocator, 10);
    defer channel.deinit(testing.allocator);

    var sum = std.atomic.Value(i32).init(0);

    const sender = try Thread.spawn(.{}, channelSender, .{&channel});
    const receiver = try Thread.spawn(.{}, channelReceiver, .{ &channel, &sum });

    sender.join();
    receiver.join();

    // Sum of 0..49 = 1225
    try testing.expectEqual(@as(i32, 1225), sum.load(.monotonic));
}
// ANCHOR_END: channel

// ANCHOR: priority_queue
const PriorityItem = struct {
    value: i32,
    priority: u8,
};

const PriorityQueue = struct {
    items: std.ArrayList(PriorityItem),
    mutex: Mutex,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) PriorityQueue {
        return .{
            .items = std.ArrayList(PriorityItem){},
            .mutex = .{},
            .allocator = allocator,
        };
    }

    fn deinit(self: *PriorityQueue) void {
        self.items.deinit(self.allocator);
    }

    fn push(self: *PriorityQueue, value: i32, priority: u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const item = PriorityItem{ .value = value, .priority = priority };

        // Insert in priority order (higher priority first)
        var insert_pos: usize = 0;
        for (self.items.items) |existing| {
            if (priority > existing.priority) break;
            insert_pos += 1;
        }

        try self.items.insert(self.allocator, insert_pos, item);
    }

    fn pop(self: *PriorityQueue) ?PriorityItem {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.items.items.len == 0) return null;
        return self.items.orderedRemove(0);
    }
};

test "priority queue ordering" {
    var queue = PriorityQueue.init(testing.allocator);
    defer queue.deinit();

    try queue.push(1, 1);
    try queue.push(2, 3);
    try queue.push(3, 2);
    try queue.push(4, 3);

    const item1 = queue.pop().?;
    try testing.expectEqual(@as(u8, 3), item1.priority);

    const item2 = queue.pop().?;
    try testing.expectEqual(@as(u8, 3), item2.priority);

    const item3 = queue.pop().?;
    try testing.expectEqual(@as(u8, 2), item3.priority);

    const item4 = queue.pop().?;
    try testing.expectEqual(@as(u8, 1), item4.priority);
}
// ANCHOR_END: priority_queue

// ANCHOR: ring_buffer
const RingBuffer = struct {
    buffer: []i32,
    read_pos: std.atomic.Value(usize),
    write_pos: std.atomic.Value(usize),
    capacity: usize,

    fn init(allocator: std.mem.Allocator, capacity: usize) !RingBuffer {
        const buffer = try allocator.alloc(i32, capacity);
        return .{
            .buffer = buffer,
            .read_pos = std.atomic.Value(usize).init(0),
            .write_pos = std.atomic.Value(usize).init(0),
            .capacity = capacity,
        };
    }

    fn deinit(self: *RingBuffer, allocator: std.mem.Allocator) void {
        allocator.free(self.buffer);
    }

    fn write(self: *RingBuffer, value: i32) bool {
        const write_idx = self.write_pos.load(.monotonic);
        const read_idx = self.read_pos.load(.monotonic);
        const next_write = (write_idx + 1) % self.capacity;

        if (next_write == read_idx) {
            return false; // Buffer full
        }

        self.buffer[write_idx] = value;
        self.write_pos.store(next_write, .release);
        return true;
    }

    fn read(self: *RingBuffer) ?i32 {
        const read_idx = self.read_pos.load(.monotonic);
        const write_idx = self.write_pos.load(.acquire);

        if (read_idx == write_idx) {
            return null; // Buffer empty
        }

        const value = self.buffer[read_idx];
        self.read_pos.store((read_idx + 1) % self.capacity, .release);
        return value;
    }
};

test "lock-free ring buffer" {
    var ring = try RingBuffer.init(testing.allocator, 10);
    defer ring.deinit(testing.allocator);

    try testing.expect(ring.write(1));
    try testing.expect(ring.write(2));
    try testing.expect(ring.write(3));

    try testing.expectEqual(@as(i32, 1), ring.read().?);
    try testing.expectEqual(@as(i32, 2), ring.read().?);
    try testing.expectEqual(@as(i32, 3), ring.read().?);
    try testing.expect(ring.read() == null);
}
// ANCHOR_END: ring_buffer

// ANCHOR: broadcast_channel
const BroadcastChannel = struct {
    value: std.atomic.Value(i32),
    version: std.atomic.Value(u64),

    fn init() BroadcastChannel {
        return .{
            .value = std.atomic.Value(i32).init(0),
            .version = std.atomic.Value(u64).init(0),
        };
    }

    fn broadcast(self: *BroadcastChannel, value: i32) void {
        self.value.store(value, .release);
        _ = self.version.fetchAdd(@as(u64, 1), .release);
    }

    fn receive(self: *BroadcastChannel, last_version: *u64) ?i32 {
        const current_version = self.version.load(.acquire);
        if (current_version == last_version.*) {
            return null; // No new value
        }

        last_version.* = current_version;
        return self.value.load(.acquire);
    }
};

fn broadcaster(ch: *BroadcastChannel) void {
    var i: i32 = 1;
    while (i <= 10) : (i += 1) {
        ch.broadcast(i);
        Thread.sleep(5 * std.time.ns_per_ms);
    }
}

fn broadcastReceiver(ch: *BroadcastChannel, count: *std.atomic.Value(i32)) void {
    var last_version: u64 = 0;
    var received: i32 = 0;

    while (received < 10) {
        if (ch.receive(&last_version)) |_| {
            received += 1;
        } else {
            Thread.sleep(std.time.ns_per_ms);
        }
    }

    _ = count.fetchAdd(@as(i32, 1), .monotonic);
}

test "broadcast to multiple receivers" {
    var channel = BroadcastChannel.init();
    var count = std.atomic.Value(i32).init(0);

    const sender = try Thread.spawn(.{}, broadcaster, .{&channel});

    var receivers: [3]Thread = undefined;
    for (&receivers) |*thread| {
        thread.* = try Thread.spawn(.{}, broadcastReceiver, .{ &channel, &count });
    }

    sender.join();
    for (receivers) |thread| {
        thread.join();
    }

    try testing.expectEqual(@as(i32, 3), count.load(.monotonic));
}
// ANCHOR_END: broadcast_channel
