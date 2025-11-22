const std = @import("std");
const testing = std.testing;
const Thread = std.Thread;
const Atomic = std.atomic.Value;

// ANCHOR: basic_atomic
test "basic atomic operations" {
    var counter = Atomic(i32).init(0);

    // Atomic store
    counter.store(42, .monotonic);

    // Atomic load
    const value = counter.load(.monotonic);
    try testing.expectEqual(@as(i32, 42), value);
}
// ANCHOR_END: basic_atomic

// ANCHOR: atomic_increment
test "atomic increment from multiple threads" {
    var counter = Atomic(u32).init(0);
    var threads: [10]Thread = undefined;

    for (&threads) |*thread| {
        thread.* = try Thread.spawn(.{}, atomicIncrementWorker, .{&counter});
    }

    for (threads) |thread| {
        thread.join();
    }

    // Each thread increments 1000 times
    try testing.expectEqual(@as(u32, 10000), counter.load(.monotonic));
}

fn atomicIncrementWorker(counter: *Atomic(u32)) void {
    var i: u32 = 0;
    while (i < 1000) : (i += 1) {
        _ = counter.fetchAdd(@as(u32, 1), .monotonic);
    }
}
// ANCHOR_END: atomic_increment

// ANCHOR: compare_and_swap
test "compare and swap" {
    var value = Atomic(i32).init(100);

    // Try to swap 100 for 200
    const result1 = value.cmpxchgWeak(100, 200, .monotonic, .monotonic);
    try testing.expect(result1 == null); // Swap succeeded

    // Try to swap 100 for 300 (will fail, value is now 200)
    const result2 = value.cmpxchgWeak(100, 300, .monotonic, .monotonic);
    try testing.expect(result2 != null); // Swap failed
    try testing.expectEqual(@as(i32, 200), result2.?);

    try testing.expectEqual(@as(i32, 200), value.load(.monotonic));
}
// ANCHOR_END: compare_and_swap

// ANCHOR: memory_ordering
test "memory ordering examples" {
    var flag = Atomic(bool).init(false);
    const data: i32 = 0;

    // Sequential consistency (strongest, slowest)
    flag.store(true, .seq_cst);

    // Acquire-release semantics (common for synchronization)
    flag.store(true, .release); // Ensure all previous writes are visible
    const value = flag.load(.acquire); // Ensure subsequent reads see previous writes
    _ = value;

    // Monotonic (no synchronization, just atomic access)
    flag.store(true, .monotonic);

    // Unordered is not available in Zig for safety

    try testing.expect(data == 0);
}
// ANCHOR_END: memory_ordering

// ANCHOR: lock_free_stack
const LockFreeStack = struct {
    head: Atomic(?*Node),

    const Node = struct {
        value: i32,
        next: ?*Node,
    };

    fn init() LockFreeStack {
        return .{
            .head = Atomic(?*Node).init(null),
        };
    }

    fn push(self: *LockFreeStack, node: *Node) void {
        var current_head = self.head.load(.monotonic);

        while (true) {
            node.next = current_head;

            // Try to swing head to new node
            if (self.head.cmpxchgWeak(
                current_head,
                node,
                .release,
                .monotonic,
            )) |new_head| {
                // CAS failed, try again
                current_head = new_head;
            } else {
                // CAS succeeded
                break;
            }
        }
    }

    fn pop(self: *LockFreeStack) ?*Node {
        var current_head = self.head.load(.monotonic);

        while (current_head) |head| {
            const next = head.next;

            // Try to swing head to next node
            if (self.head.cmpxchgWeak(
                current_head,
                next,
                .acquire,
                .monotonic,
            )) |new_head| {
                // CAS failed, try again
                current_head = new_head;
            } else {
                // CAS succeeded
                return head;
            }
        }

        return null;
    }
};

test "lock-free stack" {
    var stack = LockFreeStack.init();

    var node1 = LockFreeStack.Node{ .value = 1, .next = null };
    var node2 = LockFreeStack.Node{ .value = 2, .next = null };
    var node3 = LockFreeStack.Node{ .value = 3, .next = null };

    stack.push(&node1);
    stack.push(&node2);
    stack.push(&node3);

    try testing.expectEqual(@as(i32, 3), stack.pop().?.value);
    try testing.expectEqual(@as(i32, 2), stack.pop().?.value);
    try testing.expectEqual(@as(i32, 1), stack.pop().?.value);
    try testing.expect(stack.pop() == null);
}
// ANCHOR_END: lock_free_stack

// ANCHOR: atomic_flag
const SpinLock = struct {
    locked: Atomic(bool),

    fn init() SpinLock {
        return .{
            .locked = Atomic(bool).init(false),
        };
    }

    fn lock(self: *SpinLock) void {
        while (self.locked.swap(true, .acquire)) {
            // Yield to other threads to reduce CPU waste
            Thread.yield() catch {};
        }
    }

    fn unlock(self: *SpinLock) void {
        self.locked.store(false, .release);
    }

    fn tryLock(self: *SpinLock) bool {
        return !self.locked.swap(true, .acquire);
    }
};

test "spin lock with atomic flag" {
    var spin_lock = SpinLock.init();
    var counter: i32 = 0;

    spin_lock.lock();
    counter += 1;
    spin_lock.unlock();

    try testing.expectEqual(@as(i32, 1), counter);

    // Test try lock
    try testing.expect(spin_lock.tryLock());
    counter += 1;
    spin_lock.unlock();

    try testing.expectEqual(@as(i32, 2), counter);
}
// ANCHOR_END: atomic_flag

// ANCHOR: atomic_min_max
test "atomic minimum and maximum" {
    var min_val = Atomic(i32).init(100);
    var max_val = Atomic(i32).init(0);

    var threads: [4]Thread = undefined;
    const values = [_]i32{ 50, 150, 25, 200 };

    for (&threads, values) |*thread, val| {
        thread.* = try Thread.spawn(.{}, updateMinMax, .{ &min_val, &max_val, val });
    }

    for (threads) |thread| {
        thread.join();
    }

    try testing.expectEqual(@as(i32, 25), min_val.load(.monotonic));
    try testing.expectEqual(@as(i32, 200), max_val.load(.monotonic));
}

fn updateMinMax(min_val: *Atomic(i32), max_val: *Atomic(i32), value: i32) void {
    // Update minimum
    var current_min = min_val.load(.monotonic);
    while (value < current_min) {
        if (min_val.cmpxchgWeak(
            current_min,
            value,
            .monotonic,
            .monotonic,
        )) |new_min| {
            current_min = new_min;
        } else {
            break;
        }
    }

    // Update maximum
    var current_max = max_val.load(.monotonic);
    while (value > current_max) {
        if (max_val.cmpxchgWeak(
            current_max,
            value,
            .monotonic,
            .monotonic,
        )) |new_max| {
            current_max = new_max;
        } else {
            break;
        }
    }
}
// ANCHOR_END: atomic_min_max

// ANCHOR: fetch_operations
test "fetch and modify operations" {
    var counter = Atomic(u32).init(10);

    // Fetch and add
    const old_add = counter.fetchAdd(@as(u32, 5), .monotonic);
    try testing.expectEqual(@as(u32, 10), old_add);
    try testing.expectEqual(@as(u32, 15), counter.load(.monotonic));

    // Fetch and sub
    const old_sub = counter.fetchSub(@as(u32, 3), .monotonic);
    try testing.expectEqual(@as(u32, 15), old_sub);
    try testing.expectEqual(@as(u32, 12), counter.load(.monotonic));

    // Fetch and bitwise operations
    var flags = Atomic(u8).init(0b0000_1111);

    _ = flags.fetchAnd(@as(u8, 0b1111_0000), .monotonic);
    try testing.expectEqual(@as(u8, 0b0000_0000), flags.load(.monotonic));

    flags.store(0b0000_1111, .monotonic);
    _ = flags.fetchOr(@as(u8, 0b1111_0000), .monotonic);
    try testing.expectEqual(@as(u8, 0b1111_1111), flags.load(.monotonic));

    _ = flags.fetchXor(@as(u8, 0b1010_1010), .monotonic);
    try testing.expectEqual(@as(u8, 0b0101_0101), flags.load(.monotonic));
}
// ANCHOR_END: fetch_operations

// ANCHOR: atomic_pointer
test "atomic pointer operations" {
    var data1: i32 = 42;
    var data2: i32 = 100;

    var ptr = Atomic(?*i32).init(&data1);

    // Load pointer
    const loaded = ptr.load(.monotonic);
    try testing.expectEqual(&data1, loaded.?);
    try testing.expectEqual(@as(i32, 42), loaded.?.*);

    // Store pointer
    ptr.store(&data2, .monotonic);
    try testing.expectEqual(&data2, ptr.load(.monotonic).?);

    // Compare and swap pointers
    const result = ptr.cmpxchgWeak(&data2, &data1, .monotonic, .monotonic);
    try testing.expect(result == null); // Swap succeeded
    try testing.expectEqual(&data1, ptr.load(.monotonic).?);
}
// ANCHOR_END: atomic_pointer

// ANCHOR: wait_notify
test "atomic wait and notify" {
    var ready = Atomic(u32).init(0);
    var result: i32 = 0;

    const worker_thread = try Thread.spawn(.{}, waitWorker, .{ &ready, &result });

    // Give worker time to start waiting
    Thread.sleep(10 * std.time.ns_per_ms);

    // Do some work
    result = 42;

    // Signal worker
    ready.store(1, .release);

    worker_thread.join();

    try testing.expectEqual(@as(i32, 42), result);
}

fn waitWorker(ready: *Atomic(u32), result: *i32) void {
    // Wait for signal (simple spin)
    while (ready.load(.acquire) == 0) {
        Thread.sleep(std.time.ns_per_ms);
    }

    // Process result
    std.debug.print("Worker received: {}\n", .{result.*});
}
// ANCHOR_END: wait_notify

// ANCHOR: double_checked_locking
const LazyInit = struct {
    initialized: Atomic(bool),
    mutex: Thread.Mutex,
    value: ?i32,

    fn init() LazyInit {
        return .{
            .initialized = Atomic(bool).init(false),
            .mutex = .{},
            .value = null,
        };
    }

    fn getValue(self: *LazyInit) i32 {
        // First check without lock (fast path)
        if (self.initialized.load(.acquire)) {
            return self.value.?;
        }

        // Slow path: acquire lock and initialize
        self.mutex.lock();
        defer self.mutex.unlock();

        // Double check after acquiring lock
        if (!self.initialized.load(.monotonic)) {
            self.value = expensiveComputation();
            self.initialized.store(true, .release);
        }

        return self.value.?;
    }
};

fn expensiveComputation() i32 {
    return 42;
}

test "double-checked locking pattern" {
    var lazy = LazyInit.init();

    var threads: [4]Thread = undefined;
    var results: [4]i32 = undefined;

    for (&threads, 0..) |*thread, i| {
        thread.* = try Thread.spawn(.{}, getLazyValue, .{ &lazy, &results[i] });
    }

    for (threads) |thread| {
        thread.join();
    }

    // All threads should get the same value
    for (results) |result| {
        try testing.expectEqual(@as(i32, 42), result);
    }
}

fn getLazyValue(lazy: *LazyInit, result: *i32) void {
    result.* = lazy.getValue();
}
// ANCHOR_END: double_checked_locking
