## Problem

You need to protect shared mutable data from race conditions when multiple threads access it concurrently. Without synchronization, concurrent reads and writes can corrupt data and cause unpredictable behavior.

## Solution

Use `std.Thread.Mutex` to create critical sections where only one thread can execute at a time.

### Basic Mutex Usage

```zig
{{#include ../../../code/04-specialized/12-concurrency/recipe_12_2.zig:basic_mutex}}
```

### Defer for Automatic Unlock

Always use `defer` to ensure the mutex is unlocked, even if an error occurs:

```zig
{{#include ../../../code/04-specialized/12-concurrency/recipe_12_2.zig:defer_unlock}}
```

### Protecting Shared Data

Embed the mutex with the data it protects:

```zig
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
```

This pattern ensures the mutex is always held when accessing `balance`, preventing race conditions.

## Discussion

### Critical Sections

A critical section is code that must execute atomically with respect to other threads. Keep critical sections as short as possible to minimize contention:

```zig
const SharedBuffer = struct {
    data: [100]u8,
    write_index: usize,
    mutex: Mutex,

    fn append(self: *SharedBuffer, value: u8) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Critical section: only one thread at a time
        if (self.write_index >= self.data.len) {
            return false;
        }

        self.data[self.write_index] = value;
        self.write_index += 1;
        return true;
    }
};
```

### Atomic Multi-Object Operations

When an operation involves multiple objects, you must lock all of them to ensure atomicity:

```zig
fn transfer(from: *BankAccount, to: *BankAccount, amount: i64) !void {
    from.mutex.lock();
    defer from.mutex.unlock();

    to.mutex.lock();
    defer to.mutex.unlock();

    if (from.balance < amount) {
        return error.InsufficientFunds;
    }

    from.balance -= amount;
    to.balance += amount;
}
```

However, this approach can deadlock if two threads try to transfer in opposite directions simultaneously.

### Preventing Deadlock with Lock Ordering

Always acquire locks in a consistent order. One approach is to order by memory address:

```zig
fn safeConcurrentTransfer(
    account1: *BankAccount,
    account2: *BankAccount,
    amount: i64,
) !void {
    // Lock accounts in consistent order based on memory address
    const first = if (@intFromPtr(account1) < @intFromPtr(account2))
        account1 else account2;
    const second = if (@intFromPtr(account1) < @intFromPtr(account2))
        account2 else account1;

    first.mutex.lock();
    defer first.mutex.unlock();

    second.mutex.lock();
    defer second.mutex.unlock();

    if (account1.balance < amount) {
        return error.InsufficientFunds;
    }

    account1.balance -= amount;
    account2.balance += amount;
}
```

This guarantees threads always lock in the same order, preventing circular wait conditions.

### Avoiding Nested Locking

Don't call a locked method from another locked method of the same object - this causes deadlock:

```zig
// WRONG: This deadlocks!
fn incrementBy(self: *Counter, amount: i32) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    var i: i32 = 0;
    while (i < amount) : (i += 1) {
        self.increment(); // increment() tries to lock again!
    }
}

// RIGHT: Duplicate logic or use internal unlocked methods
fn incrementBy(self: *Counter, amount: i32) void {
    self.mutex.lock();
    defer self.mutex.unlock();
    self.value += amount;
}
```

### Granular Locking

Instead of one global lock, use multiple locks to reduce contention. A concurrent hash map can lock individual buckets:

```zig
const ConcurrentHashMap = struct {
    buckets: [16]Bucket,
    allocator: Allocator,

    const Bucket = struct {
        items: std.ArrayList(Entry),
        mutex: Mutex,
    };

    fn put(self: *ConcurrentHashMap, key: u32, value: i32) !void {
        const bucket_index = key % self.buckets.len;
        var bucket = &self.buckets[bucket_index];

        bucket.mutex.lock();
        defer bucket.mutex.unlock();

        // Only this bucket is locked, not the entire map
        try bucket.items.append(self.allocator, .{ .key = key, .value = value });
    }
};
```

Different buckets can be accessed concurrently, improving throughput.

### Mutex Initialization

Mutexes use default initialization with empty braces:

```zig
// Standalone mutex
var mutex = Mutex{};

// Embedded in struct with default field syntax
const Data = struct {
    value: i32,
    lock: Mutex = .{},
};
```

### Scoped Access Pattern

Encapsulate locking logic to prevent forgetting to acquire the mutex:

```zig
const SafeCounter = struct {
    value: i32,
    mutex: Mutex,

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
```

Users of `SafeCounter` can't accidentally access `value` without holding the lock.

### Performance Considerations

Mutex contention slows down concurrent programs. To minimize contention:

1. Keep critical sections short
2. Use granular locking (multiple locks)
3. Prefer lock-free algorithms when appropriate (see Recipe 12.3 on atomics)
4. Avoid holding locks during I/O operations

### Common Mistakes

1. **Forgetting to unlock** - Always use `defer mutex.unlock()`
2. **Locking too much** - Don't hold locks during slow operations
3. **Inconsistent lock ordering** - Always lock in the same order
4. **Reading without locking** - Even reads need synchronization
5. **Nested locking** - Don't call locked methods from locked methods

## See Also

- Recipe 12.1: Basic threading and thread management
- Recipe 12.3: Atomic operations
- Recipe 12.7: Read-write locks
- Recipe 12.9: Preventing race conditions

Full compilable example: `code/04-specialized/12-concurrency/recipe_12_2.zig`
