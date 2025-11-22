const std = @import("std");
const testing = std.testing;
const Thread = std.Thread;
const Mutex = Thread.Mutex;
const Condition = Thread.Condition;

// ANCHOR: basic_condition
const WaitNotify = struct {
    ready: bool,
    mutex: Mutex,
    condition: Condition,

    fn init() WaitNotify {
        return .{
            .ready = false,
            .mutex = .{},
            .condition = .{},
        };
    }

    fn wait(self: *WaitNotify) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (!self.ready) {
            self.condition.wait(&self.mutex);
        }
    }

    fn notify(self: *WaitNotify) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.ready = true;
        self.condition.signal();
    }
};

fn waiter(wn: *WaitNotify, result: *i32) void {
    wn.wait();
    result.* = 42;
}

fn notifier(wn: *WaitNotify) void {
    Thread.sleep(10 * std.time.ns_per_ms);
    wn.notify();
}

test "basic wait and notify" {
    var wn = WaitNotify.init();
    var result: i32 = 0;

    const wait_thread = try Thread.spawn(.{}, waiter, .{ &wn, &result });
    const notify_thread = try Thread.spawn(.{}, notifier, .{&wn});

    wait_thread.join();
    notify_thread.join();

    try testing.expectEqual(@as(i32, 42), result);
}
// ANCHOR_END: basic_condition

// ANCHOR: blocking_queue
const BlockingQueue = struct {
    buffer: []i32,
    head: usize,
    tail: usize,
    count: usize,
    mutex: Mutex,
    not_empty: Condition,
    not_full: Condition,
    capacity: usize,

    fn init(allocator: std.mem.Allocator, capacity: usize) !BlockingQueue {
        const buffer = try allocator.alloc(i32, capacity);
        return .{
            .buffer = buffer,
            .head = 0,
            .tail = 0,
            .count = 0,
            .mutex = .{},
            .not_empty = .{},
            .not_full = .{},
            .capacity = capacity,
        };
    }

    fn deinit(self: *BlockingQueue, allocator: std.mem.Allocator) void {
        allocator.free(self.buffer);
    }

    fn push(self: *BlockingQueue, item: i32) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.count >= self.capacity) {
            self.not_full.wait(&self.mutex);
        }

        self.buffer[self.tail] = item;
        self.tail = (self.tail + 1) % self.capacity;
        self.count += 1;

        self.not_empty.signal();
    }

    fn pop(self: *BlockingQueue) i32 {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.count == 0) {
            self.not_empty.wait(&self.mutex);
        }

        const item = self.buffer[self.head];
        self.head = (self.head + 1) % self.capacity;
        self.count -= 1;

        self.not_full.signal();

        return item;
    }
};

fn blockingProducer(queue: *BlockingQueue) void {
    var i: i32 = 0;
    while (i < 20) : (i += 1) {
        queue.push(i);
    }
}

fn blockingConsumer(queue: *BlockingQueue, sum: *i32) void {
    var total: i32 = 0;
    var i: i32 = 0;
    while (i < 20) : (i += 1) {
        total += queue.pop();
    }
    sum.* = total;
}

test "blocking queue with conditions" {
    var queue = try BlockingQueue.init(testing.allocator, 5);
    defer queue.deinit(testing.allocator);

    var sum: i32 = 0;

    const producer_thread = try Thread.spawn(.{}, blockingProducer, .{&queue});
    const consumer_thread = try Thread.spawn(.{}, blockingConsumer, .{ &queue, &sum });

    producer_thread.join();
    consumer_thread.join();

    // Sum of 0..19 = 190
    try testing.expectEqual(@as(i32, 190), sum);
}
// ANCHOR_END: blocking_queue

// ANCHOR: semaphore
const Semaphore = struct {
    count: usize,
    mutex: Mutex,
    condition: Condition,

    fn init(initial_count: usize) Semaphore {
        return .{
            .count = initial_count,
            .mutex = .{},
            .condition = .{},
        };
    }

    fn acquire(self: *Semaphore) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.count == 0) {
            self.condition.wait(&self.mutex);
        }

        self.count -= 1;
    }

    fn release(self: *Semaphore) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.count += 1;
        self.condition.signal();
    }
};

fn semWorker(sem: *Semaphore, counter: *std.atomic.Value(i32)) void {
    sem.acquire();
    defer sem.release();

    // Critical section
    _ = counter.fetchAdd(@as(i32, 1), .monotonic);
    Thread.sleep(5 * std.time.ns_per_ms);
}

test "semaphore limits concurrency" {
    var sem = Semaphore.init(2); // Max 2 concurrent
    var counter = std.atomic.Value(i32).init(0);

    var threads: [5]Thread = undefined;
    for (&threads) |*thread| {
        thread.* = try Thread.spawn(.{}, semWorker, .{ &sem, &counter });
    }

    for (threads) |thread| {
        thread.join();
    }

    try testing.expectEqual(@as(i32, 5), counter.load(.monotonic));
}
// ANCHOR_END: semaphore

// ANCHOR: barrier
const Barrier = struct {
    count: usize,
    waiting: usize,
    generation: usize,
    mutex: Mutex,
    condition: Condition,

    fn init(count: usize) Barrier {
        return .{
            .count = count,
            .waiting = 0,
            .generation = 0,
            .mutex = .{},
            .condition = .{},
        };
    }

    fn wait(self: *Barrier) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const gen = self.generation;
        self.waiting += 1;

        if (self.waiting >= self.count) {
            // Last thread arrives
            self.waiting = 0;
            self.generation += 1;
            self.condition.broadcast();
        } else {
            // Wait for others
            while (gen == self.generation) {
                self.condition.wait(&self.mutex);
            }
        }
    }
};

fn barrierWorker(barrier: *Barrier, id: usize, results: []usize, phase: *std.atomic.Value(usize)) void {
    // Phase 1
    results[id] = id * 2;

    barrier.wait(); // Sync point

    // Phase 2 - all threads have completed phase 1
    _ = phase.fetchAdd(@as(usize, 1), .monotonic);
}

test "barrier synchronization" {
    var barrier = Barrier.init(4);
    var results: [4]usize = undefined;
    var phase = std.atomic.Value(usize).init(0);

    var threads: [4]Thread = undefined;
    for (&threads, 0..) |*thread, i| {
        thread.* = try Thread.spawn(.{}, barrierWorker, .{ &barrier, i, &results, &phase });
    }

    for (threads) |thread| {
        thread.join();
    }

    // Verify all threads completed phase 1 before phase 2
    try testing.expectEqual(@as(usize, 4), phase.load(.monotonic));

    // Verify all phase 1 results are set
    try testing.expectEqual(@as(usize, 0), results[0]);
    try testing.expectEqual(@as(usize, 2), results[1]);
    try testing.expectEqual(@as(usize, 4), results[2]);
    try testing.expectEqual(@as(usize, 6), results[3]);
}
// ANCHOR_END: barrier

// ANCHOR: latch
const Latch = struct {
    count: std.atomic.Value(usize),
    mutex: Mutex,
    condition: Condition,

    fn init(count: usize) Latch {
        return .{
            .count = std.atomic.Value(usize).init(count),
            .mutex = .{},
            .condition = .{},
        };
    }

    fn countDown(self: *Latch) void {
        const old = self.count.fetchSub(@as(usize, 1), .release);
        if (old == 1) {
            self.mutex.lock();
            defer self.mutex.unlock();
            self.condition.broadcast();
        }
    }

    fn wait(self: *Latch) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.count.load(.acquire) > 0) {
            self.condition.wait(&self.mutex);
        }
    }
};

fn latchWorker(latch: *Latch) void {
    Thread.sleep(10 * std.time.ns_per_ms);
    latch.countDown();
}

test "latch waits for all events" {
    var latch = Latch.init(3);

    var threads: [3]Thread = undefined;
    for (&threads) |*thread| {
        thread.* = try Thread.spawn(.{}, latchWorker, .{&latch});
    }

    latch.wait(); // Block until all threads count down

    for (threads) |thread| {
        thread.join();
    }

    try testing.expectEqual(@as(usize, 0), latch.count.load(.monotonic));
}
// ANCHOR_END: latch

// ANCHOR: broadcast_wait
const BroadcastSignal = struct {
    flag: bool,
    mutex: Mutex,
    condition: Condition,

    fn init() BroadcastSignal {
        return .{
            .flag = false,
            .mutex = .{},
            .condition = .{},
        };
    }

    fn wait(self: *BroadcastSignal) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (!self.flag) {
            self.condition.wait(&self.mutex);
        }
    }

    fn broadcast(self: *BroadcastSignal) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.flag = true;
        self.condition.broadcast(); // Wake all waiters
    }
};

fn broadcastWaiter(signal: *BroadcastSignal, counter: *std.atomic.Value(i32)) void {
    signal.wait();
    _ = counter.fetchAdd(@as(i32, 1), .monotonic);
}

test "broadcast wakes all waiters" {
    var signal = BroadcastSignal.init();
    var counter = std.atomic.Value(i32).init(0);

    var threads: [5]Thread = undefined;
    for (&threads) |*thread| {
        thread.* = try Thread.spawn(.{}, broadcastWaiter, .{ &signal, &counter });
    }

    Thread.sleep(20 * std.time.ns_per_ms);
    signal.broadcast();

    for (threads) |thread| {
        thread.join();
    }

    try testing.expectEqual(@as(i32, 5), counter.load(.monotonic));
}
// ANCHOR_END: broadcast_wait

// ANCHOR: timed_wait
const TimedWait = struct {
    ready: bool,
    mutex: Mutex,
    condition: Condition,

    fn init() TimedWait {
        return .{
            .ready = false,
            .mutex = .{},
            .condition = .{},
        };
    }

    fn waitFor(self: *TimedWait, timeout_ms: u64) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        const timeout_ns = timeout_ms * std.time.ns_per_ms;

        while (!self.ready) {
            // Use native timedWait which returns error.Timeout if time expires
            self.condition.timedWait(&self.mutex, timeout_ns) catch {
                return false; // Timeout
            };
        }

        return true;
    }

    fn signal(self: *TimedWait) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.ready = true;
        self.condition.signal();
    }
};

test "timed wait timeout" {
    var tw = TimedWait.init();

    const timed_out = !tw.waitFor(50);
    try testing.expect(timed_out);
}

test "timed wait success" {
    var tw = TimedWait.init();

    const thread = try Thread.spawn(.{}, timedSignaler, .{&tw});

    const success = tw.waitFor(100);
    try testing.expect(success);

    thread.join();
}

fn timedSignaler(tw: *TimedWait) void {
    Thread.sleep(20 * std.time.ns_per_ms);
    tw.signal();
}
// ANCHOR_END: timed_wait

// ANCHOR: event
const Event = struct {
    signaled: std.atomic.Value(bool),
    mutex: Mutex,
    condition: Condition,

    fn init() Event {
        return .{
            .signaled = std.atomic.Value(bool).init(false),
            .mutex = .{},
            .condition = .{},
        };
    }

    fn wait(self: *Event) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (!self.signaled.load(.acquire)) {
            self.condition.wait(&self.mutex);
        }
    }

    fn set(self: *Event) void {
        self.signaled.store(true, .release);

        self.mutex.lock();
        defer self.mutex.unlock();
        self.condition.broadcast();
    }

    fn reset(self: *Event) void {
        self.signaled.store(false, .release);
    }
};

fn eventWaiter(event: *Event, result: *i32) void {
    event.wait();
    result.* = 100;
}

test "event signaling" {
    var event = Event.init();
    var result: i32 = 0;

    const thread = try Thread.spawn(.{}, eventWaiter, .{ &event, &result });

    Thread.sleep(10 * std.time.ns_per_ms);
    event.set();

    thread.join();

    try testing.expectEqual(@as(i32, 100), result);
}
// ANCHOR_END: event
