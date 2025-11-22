const std = @import("std");
const testing = std.testing;
const Thread = std.Thread;
const Mutex = Thread.Mutex;

// ANCHOR: basic_mutex
test "basic mutex usage" {
    var mutex = Mutex{};
    var counter: i32 = 0;

    mutex.lock();
    counter += 1;
    mutex.unlock();

    try testing.expectEqual(@as(i32, 1), counter);
}
// ANCHOR_END: basic_mutex

// ANCHOR: defer_unlock
test "defer for automatic unlock" {
    var mutex = Mutex{};
    var value: i32 = 0;

    {
        mutex.lock();
        defer mutex.unlock();
        value = 42;
        // mutex automatically unlocks when scope exits
    }

    try testing.expectEqual(@as(i32, 42), value);
}
// ANCHOR_END: defer_unlock

// ANCHOR: protecting_shared_data
const BankAccount = struct {
    balance: i64,
    mutex: Mutex,

    fn init(initial_balance: i64) BankAccount {
        return .{
            .balance = initial_balance,
            .mutex = .{},
        };
    }

    fn deposit(self: *BankAccount, amount: i64) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.balance += amount;
    }

    fn withdraw(self: *BankAccount, amount: i64) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.balance >= amount) {
            self.balance -= amount;
            return true;
        }
        return false;
    }

    fn getBalance(self: *BankAccount) i64 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.balance;
    }
};

test "protecting shared data with mutex" {
    var account = BankAccount.init(1000);

    var threads: [10]Thread = undefined;

    // Spawn threads that deposit money
    for (&threads) |*thread| {
        thread.* = try Thread.spawn(.{}, depositWorker, .{&account});
    }

    for (threads) |thread| {
        thread.join();
    }

    try testing.expectEqual(@as(i64, 1100), account.getBalance());
}

fn depositWorker(account: *BankAccount) void {
    account.deposit(10);
}
// ANCHOR_END: protecting_shared_data

// ANCHOR: multiple_operations
const TransferError = error{InsufficientFunds};

fn transfer(from: *BankAccount, to: *BankAccount, amount: i64) TransferError!void {
    // Lock both accounts to ensure atomic transfer
    from.mutex.lock();
    defer from.mutex.unlock();

    to.mutex.lock();
    defer to.mutex.unlock();

    if (from.balance < amount) {
        return TransferError.InsufficientFunds;
    }

    from.balance -= amount;
    to.balance += amount;
}

test "atomic transfer between accounts" {
    var account1 = BankAccount.init(1000);
    var account2 = BankAccount.init(500);

    try transfer(&account1, &account2, 300);

    try testing.expectEqual(@as(i64, 700), account1.getBalance());
    try testing.expectEqual(@as(i64, 800), account2.getBalance());
}
// ANCHOR_END: multiple_operations

// ANCHOR: critical_section
const SharedBuffer = struct {
    data: [100]u8,
    write_index: usize,
    mutex: Mutex,

    fn init() SharedBuffer {
        return .{
            .data = [_]u8{0} ** 100,
            .write_index = 0,
            .mutex = .{},
        };
    }

    fn append(self: *SharedBuffer, value: u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Critical section: only one thread can execute this at a time
        if (self.write_index >= self.data.len) {
            return false;
        }

        self.data[self.write_index] = value;
        self.write_index += 1;
        return true;
    }

    fn size(self: *SharedBuffer) usize {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.write_index;
    }
};

test "critical section protection" {
    var buffer = SharedBuffer.init();

    var threads: [10]Thread = undefined;
    for (&threads, 0..) |*thread, i| {
        thread.* = try Thread.spawn(.{}, appendWorker, .{ &buffer, @as(u8, @intCast(i)) });
    }

    for (threads) |thread| {
        thread.join();
    }

    try testing.expectEqual(@as(usize, 10), buffer.size());
}

fn appendWorker(buffer: *SharedBuffer, value: u8) void {
    _ = buffer.append(value);
}
// ANCHOR_END: critical_section

// ANCHOR: nested_locking_safe
const NestedCounter = struct {
    value: i32,
    mutex: Mutex,

    fn init() NestedCounter {
        return .{
            .value = 0,
            .mutex = .{},
        };
    }

    fn increment(self: *NestedCounter) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.value += 1;
    }

    fn incrementBy(self: *NestedCounter, amount: i32) void {
        // Don't call increment() here - it would try to lock again (deadlock)
        // Instead, duplicate the logic or restructure
        self.mutex.lock();
        defer self.mutex.unlock();
        self.value += amount;
    }

    fn safeIncrementBy(self: *NestedCounter, amount: i32) void {
        // Safe pattern: internal method without lock
        var i: i32 = 0;
        while (i < amount) : (i += 1) {
            self.increment();
        }
    }
};

test "avoiding nested locking" {
    var counter = NestedCounter.init();
    counter.incrementBy(5);
    try testing.expectEqual(@as(i32, 5), counter.value);
}
// ANCHOR_END: nested_locking_safe

// ANCHOR: lock_ordering
// Always lock mutexes in the same order to avoid deadlock
fn safeConcurrentTransfer(
    account1: *BankAccount,
    account2: *BankAccount,
    amount: i64,
) TransferError!void {
    // Lock accounts in consistent order based on memory address
    const first = if (@intFromPtr(account1) < @intFromPtr(account2)) account1 else account2;
    const second = if (@intFromPtr(account1) < @intFromPtr(account2)) account2 else account1;

    first.mutex.lock();
    defer first.mutex.unlock();

    second.mutex.lock();
    defer second.mutex.unlock();

    if (account1.balance < amount) {
        return TransferError.InsufficientFunds;
    }

    account1.balance -= amount;
    account2.balance += amount;
}

test "lock ordering prevents deadlock" {
    var account1 = BankAccount.init(1000);
    var account2 = BankAccount.init(500);

    try safeConcurrentTransfer(&account1, &account2, 100);
    try safeConcurrentTransfer(&account2, &account1, 50);

    try testing.expectEqual(@as(i64, 950), account1.balance);
    try testing.expectEqual(@as(i64, 550), account2.balance);
}
// ANCHOR_END: lock_ordering

// ANCHOR: granular_locking
const ConcurrentHashMap = struct {
    buckets: [16]Bucket,
    allocator: std.mem.Allocator,

    const Bucket = struct {
        items: std.ArrayList(Entry),
        mutex: Mutex,
    };

    const Entry = struct {
        key: u32,
        value: i32,
    };

    fn init(allocator: std.mem.Allocator) ConcurrentHashMap {
        var map: ConcurrentHashMap = .{
            .buckets = undefined,
            .allocator = allocator,
        };
        for (&map.buckets) |*bucket| {
            bucket.* = .{
                .items = std.ArrayList(Entry){},
                .mutex = .{},
            };
        }
        return map;
    }

    fn deinit(self: *ConcurrentHashMap) void {
        for (&self.buckets) |*bucket| {
            bucket.items.deinit(self.allocator);
        }
    }

    fn put(self: *ConcurrentHashMap, key: u32, value: i32) !void {
        const bucket_index = key % self.buckets.len;
        var bucket = &self.buckets[bucket_index];

        bucket.mutex.lock();
        defer bucket.mutex.unlock();

        // Check if key exists
        for (bucket.items.items) |*entry| {
            if (entry.key == key) {
                entry.value = value;
                return;
            }
        }

        // Add new entry
        try bucket.items.append(self.allocator, .{ .key = key, .value = value });
    }

    fn get(self: *ConcurrentHashMap, key: u32) ?i32 {
        const bucket_index = key % self.buckets.len;
        var bucket = &self.buckets[bucket_index];

        bucket.mutex.lock();
        defer bucket.mutex.unlock();

        for (bucket.items.items) |entry| {
            if (entry.key == key) {
                return entry.value;
            }
        }
        return null;
    }
};

test "granular locking with multiple mutexes" {
    var map = ConcurrentHashMap.init(testing.allocator);
    defer map.deinit();

    try map.put(1, 100);
    try map.put(17, 200); // Same bucket as 1 (1 % 16 == 17 % 16)

    try testing.expectEqual(@as(i32, 100), map.get(1).?);
    try testing.expectEqual(@as(i32, 200), map.get(17).?);
}
// ANCHOR_END: granular_locking

// ANCHOR: mutex_initialization
test "mutex initialization patterns" {
    // Default initialization
    var mutex1 = Mutex{};
    mutex1.lock();
    mutex1.unlock();

    // Struct with embedded mutex
    const Data = struct {
        value: i32,
        lock: Mutex = .{},
    };

    var data = Data{ .value = 42 };
    data.lock.lock();
    defer data.lock.unlock();
    try testing.expectEqual(@as(i32, 42), data.value);
}
// ANCHOR_END: mutex_initialization

// ANCHOR: scoped_access
const SafeCounter = struct {
    value: i32,
    mutex: Mutex,

    fn init() SafeCounter {
        return .{
            .value = 0,
            .mutex = .{},
        };
    }

    fn add(self: *SafeCounter, amount: i32) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.value += amount;
    }

    fn get(self: *SafeCounter) i32 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.value;
    }
};

test "scoped mutex access" {
    var counter = SafeCounter.init();
    counter.add(10);

    const result = counter.get();
    try testing.expectEqual(@as(i32, 10), result);
}
// ANCHOR_END: scoped_access

// ANCHOR: benchmarking_contention
test "mutex contention stress test" {
    var counter = SafeCounter.init();
    var threads: [100]Thread = undefined;

    const start = std.time.milliTimestamp();

    for (&threads) |*thread| {
        thread.* = try Thread.spawn(.{}, stressWorker, .{&counter});
    }

    for (threads) |thread| {
        thread.join();
    }

    const elapsed = std.time.milliTimestamp() - start;

    // Each thread increments 100 times
    try testing.expectEqual(@as(i32, 10000), counter.value);

    std.debug.print("Mutex contention test: {} threads, {}ms\n", .{ threads.len, elapsed });
}

fn stressWorker(counter: *SafeCounter) void {
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        counter.add(1);
    }
}
// ANCHOR_END: benchmarking_contention
