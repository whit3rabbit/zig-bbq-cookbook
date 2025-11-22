## Problem

Busy-waiting wastes CPU cycles. You need threads to sleep until a specific condition becomes true, then wake up efficiently when signaled.

## Solution

Use condition variables (`std.Thread.Condition`) to block threads until notified.

### Basic Wait and Notify

```zig
{{#include ../../../code/04-specialized/12-concurrency/recipe_12_6.zig:basic_condition}}
```

The waiting thread sleeps until signaled, saving CPU.

## Discussion

### Blocking Queue

Condition variables enable efficient producer-consumer:

```zig
const BlockingQueue = struct {
    not_empty: Condition,
    not_full: Condition,
    mutex: Mutex,
    // ... buffer fields

    fn push(self: *BlockingQueue, item: i32) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.count >= self.capacity) {
            self.not_full.wait(&self.mutex); // Block until space
        }

        // Add item
        self.not_empty.signal(); // Wake consumer
    }

    fn pop(self: *BlockingQueue) i32 {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.count == 0) {
            self.not_empty.wait(&self.mutex); // Block until data
        }

        // Remove item
        self.not_full.signal(); // Wake producer
        return item;
    }
};
```

No spinning, threads sleep when waiting.

### Semaphore

Count-based synchronization:

```zig
const Semaphore = struct {
    count: usize,
    mutex: Mutex,
    condition: Condition,

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
```

Limits concurrent access to resources.

### Barrier

Synchronize multiple threads at a point:

```zig
const Barrier = struct {
    count: usize,
    waiting: usize,
    generation: usize,
    mutex: Mutex,
    condition: Condition,

    fn wait(self: *Barrier) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const gen = self.generation;
        self.waiting += 1;

        if (self.waiting >= self.count) {
            // Last thread - release all
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
```

All threads wait until everyone arrives.

### Latch

Count down events, wait for completion:

```zig
const Latch = struct {
    count: std.atomic.Value(usize),
    mutex: Mutex,
    condition: Condition,

    fn countDown(self: *Latch) void {
        const old = self.count.fetchSub(1, .release);
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
```

Useful for waiting on parallel initialization.

### Signal vs Broadcast

- **`signal()`** - Wakes one waiting thread
- **`broadcast()`** - Wakes all waiting threads

```zig
fn broadcast(self: *BroadcastSignal) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    self.flag = true;
    self.condition.broadcast(); // Wake ALL waiters
}
```

Use broadcast when all waiters need to wake up.

### Event

Reusable signal:

```zig
const Event = struct {
    signaled: std.atomic.Value(bool),
    mutex: Mutex,
    condition: Condition,

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
```

Can be reset and reused.

### Timed Waits

Wait with a timeout to avoid blocking indefinitely:

```zig
const TimedWait = struct {
    ready: bool,
    mutex: Mutex,
    condition: Condition,

    fn waitFor(self: *TimedWait, timeout_ms: u64) bool {
        self.mutex.lock();
        defer self.mutex.unlock();

        const timeout_ns = timeout_ms * std.time.ns_per_ms;

        while (!self.ready) {
            // timedWait returns error.Timeout if time expires
            self.condition.timedWait(&self.mutex, timeout_ns) catch {
                return false; // Timeout occurred
            };
        }

        return true; // Condition met before timeout
    }
};
```

The `timedWait` method:
- Takes timeout in nanoseconds
- Returns `error.Timeout` if timeout expires
- Can experience spurious wakeups (use while loop)
- Atomically unlocks mutex, sleeps, and re-locks on wake

Benefits over manual sleep loops:
- More precise timing
- Efficient CPU usage (proper OS-level blocking)
- Immediate wakeup on signal (no polling delay)

### Common Patterns

**Producer-Consumer**: Use two conditions (not_empty, not_full)

**Barrier**: Synchronize phase transitions

**Semaphore**: Limit resource access

**Latch**: Wait for parallel tasks to complete

**Event**: One-shot or recurring signals

### Important Rules

1. **Always use while loop** - Never `if`, always `while (condition) { wait() }`
2. **Hold mutex** - Lock before checking condition, hold during wait
3. **Signal after change** - Update state before signaling
4. **Broadcast carefully** - Only when all waiters need to wake

### Why While Not If?

```zig
// WRONG - can miss wakeups
if (!self.ready) {
    self.condition.wait(&self.mutex);
}

// CORRECT - handles spurious wakeups
while (!self.ready) {
    self.condition.wait(&self.mutex);
}
```

Spurious wakeups can occur - the thread wakes but condition isn't met.

## See Also

- Recipe 12.2: Mutexes and basic locking
- Recipe 12.5: Thread-safe queues and channels
- Recipe 12.10: Wait groups for synchronization

Full compilable example: `code/04-specialized/12-concurrency/recipe_12_6.zig`
