## Problem

You need to pass data between threads safely. Direct sharing with mutexes works but is error-prone. You want higher-level abstractions like queues and channels for structured communication.

## Solution

Use thread-safe queues to implement producer-consumer patterns and channels for bidirectional communication.

### Bounded Queue

A circular buffer with fixed capacity:

```zig
{{#include ../../../code/04-specialized/12-concurrency/recipe_12_5.zig:bounded_queue}}
```

The bounded queue prevents unbounded memory growth and provides backpressure when full.

## Discussion

### Producer-Consumer Pattern

Classic pattern for dividing work:

```zig
fn producer(queue: *BoundedQueue, count: i32) void {
    var i: i32 = 0;
    while (i < count) : (i += 1) {
        while (!queue.push(i)) {
            Thread.sleep(std.time.ns_per_ms); // Wait if queue full
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
            Thread.sleep(std.time.ns_per_ms); // Wait if queue empty
        }
    }

    _ = result.fetchAdd(sum, .monotonic);
}
```

Producers generate work items, consumers process them. The queue decouples production and consumption rates.

### Multiple Producer Single Consumer (MPSC)

Multiple threads sending to one receiver:

```zig
const MPSCQueue = struct {
    items: std.ArrayList(i32),
    mutex: Mutex,
    allocator: std.mem.Allocator,

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
```

Common in event processing: multiple event sources, single event loop.

**Performance Note:** This implementation uses `orderedRemove(0)` which is O(n) because it shifts all remaining elements forward in memory. For small queues or infrequent operations, this is acceptable. For high-throughput scenarios:
- Use the `RingBuffer` implementation shown below (O(1) operations, lock-free)
- Use the `BlockingQueue` from Recipe 12.6 (O(1) operations with condition variables)
- Consider `swapRemove()` if FIFO order isn't critical (O(1) but breaks ordering)

### Channels with Close Semantics

Go-style channels that can be closed:

```zig
const Channel = struct {
    buffer: []i32,
    closed: bool,
    // ... other fields

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

    fn close(self: *Channel) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.closed = true;
    }
};
```

Closing a channel signals "no more data coming". Receivers can drain remaining items then exit cleanly.

### Priority Queue

Process high-priority items first:

```zig
const PriorityQueue = struct {
    items: std.ArrayList(PriorityItem),
    mutex: Mutex,

    fn push(self: *PriorityQueue, value: i32, priority: u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const item = PriorityItem{ .value = value, .priority = priority };

        // Insert in priority order
        var insert_pos: usize = 0;
        for (self.items.items) |existing| {
            if (priority > existing.priority) break;
            insert_pos += 1;
        }

        try self.items.insert(self.allocator, insert_pos, item);
    }
};
```

Useful for task scheduling, request handling, and event processing.

### Lock-Free Ring Buffer

High-performance alternative using atomics:

```zig
const RingBuffer = struct {
    buffer: []i32,
    read_pos: std.atomic.Value(usize),
    write_pos: std.atomic.Value(usize),
    capacity: usize,

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
};
```

No locks means no contention, but requires careful memory ordering.

### Broadcast Channel

Send same value to multiple receivers:

```zig
const BroadcastChannel = struct {
    value: std.atomic.Value(i32),
    version: std.atomic.Value(u64),

    fn broadcast(self: *BroadcastChannel, value: i32) void {
        self.value.store(value, .release);
        _ = self.version.fetchAdd(1, .release);
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
```

Each receiver tracks which version they've seen. New versions indicate new values.

### Queue Pattern Selection

Choose based on requirements:

| Pattern | Use Case | Pros | Cons |
|---------|----------|------|------|
| Bounded Queue | Fixed capacity needed | Prevents memory growth | Blocks when full |
| Unbounded Queue | Variable workload | Never blocks | Can grow unbounded |
| MPSC | Multiple sources, one sink | Simple | Single receiver bottleneck |
| Channel | Structured communication | Clean shutdown | More overhead |
| Priority Queue | Urgent tasks first | Fair scheduling | Insertion cost |
| Ring Buffer | High performance | Lock-free | Fixed size, complex |

### Best Practices

1. **Bound queue sizes** - Prevents memory exhaustion
2. **Handle full/empty** - Don't busy-wait, use sleep or condition variables
3. **Signal completion** - Use channel close or sentinel values
4. **Choose right pattern** - MPSC for events, channels for pipelines
5. **Prefer simple** - Use mutex-based queues unless profiling shows contention

### Common Patterns

**Pipeline**: Chain processing stages
```zig
source -> queue1 -> worker1 -> queue2 -> worker2 -> sink
```

**Fan-out**: Distribute work to multiple workers
```zig
source -> queue -> [worker1, worker2, worker3]
```

**Fan-in**: Collect results from multiple sources
```zig
[source1, source2, source3] -> queue -> sink
```

## See Also

- Recipe 12.1: Basic threading and thread management
- Recipe 12.2: Mutexes and basic locking
- Recipe 12.6: Condition variables and signaling

Full compilable example: `code/04-specialized/12-concurrency/recipe_12_5.zig`
