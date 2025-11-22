## Problem

Mutexes can be heavyweight for simple operations like incrementing a counter. You need faster synchronization primitives that work without locks, or you want to implement lock-free data structures.

## Solution

Use `std.atomic.Value` for lock-free atomic operations. Atomic operations execute indivisibly - no other thread can observe them in a partially completed state.

### Basic Atomic Operations

```zig
{{#include ../../../code/04-specialized/12-concurrency/recipe_12_3.zig:basic_atomic}}
```

### Atomic Increment

Multiple threads can safely increment the same counter without locks:

```zig
{{#include ../../../code/04-specialized/12-concurrency/recipe_12_3.zig:atomic_increment}}
```

This is much faster than using a mutex for simple counters.

## Discussion

### Compare-and-Swap (CAS)

The fundamental building block of lock-free programming. It atomically compares a value and swaps it only if it matches:

```zig
var value = Atomic(i32).init(100);

// Try to swap 100 for 200
const result = value.cmpxchgWeak(100, 200, .monotonic, .monotonic);
if (result == null) {
    // Swap succeeded, value is now 200
} else {
    // Swap failed, result contains current value
}
```

`cmpxchgWeak` may spuriously fail on some architectures but is faster. Use `cmpxchgStrong` if you can't handle spurious failures.

### Memory Ordering

Atomic operations take memory ordering parameters that control how operations are synchronized across threads:

- **`.seq_cst`** (Sequential Consistency) - Strongest guarantee, all operations appear in some global order. Slowest.
- **`.release`** - Writes before this operation are visible to threads that `acquire` this variable
- **`.acquire`** - Reads after this operation see writes from threads that `release` this variable
- **`.monotonic`** - Just atomic access, no synchronization with other threads
- **`.acq_rel`** - Combined acquire and release for read-modify-write operations

Common patterns:
- Producer sets flag with `.release`, consumer reads with `.acquire`
- Simple counters use `.monotonic`
- When unsure, use `.seq_cst` (safe but slower)

### Lock-Free Stack

A complete lock-free data structure using CAS:

```zig
const LockFreeStack = struct {
    head: Atomic(?*Node),

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
                // CAS failed, retry
                current_head = new_head;
            } else {
                // CAS succeeded
                break;
            }
        }
    }
};
```

The loop handles contention: if another thread modifies `head` between load and CAS, retry.

### Spin Lock

Implement a simple lock using an atomic flag:

```zig
const SpinLock = struct {
    locked: Atomic(bool),

    fn lock(self: *SpinLock) void {
        while (self.locked.swap(true, .acquire)) {
            // Spin until we acquire the lock
        }
    }

    fn unlock(self: *SpinLock) void {
        self.locked.store(false, .release);
    }
};
```

Spin locks are faster than mutexes for very short critical sections but waste CPU time spinning.

### Fetch-and-Modify Operations

Atomic operations that modify and return the previous value:

```zig
var counter = Atomic(u32).init(10);

// Returns old value (10), counter becomes 15
const old_add = counter.fetchAdd(5, .monotonic);

// Returns old value (15), counter becomes 12
const old_sub = counter.fetchSub(3, .monotonic);

// Bitwise operations
var flags = Atomic(u8).init(0b0000_1111);
_ = flags.fetchAnd(0b1111_0000, .monotonic); // Clear lower bits
_ = flags.fetchOr(0b1111_0000, .monotonic);  // Set upper bits
_ = flags.fetchXor(0b1010_1010, .monotonic); // Toggle bits
```

### Atomic Pointers

Pointers can be atomic too, useful for lock-free data structures:

```zig
var data: i32 = 42;
var ptr = Atomic(?*i32).init(&data);

// Load pointer atomically
const loaded = ptr.load(.monotonic);

// Swap pointers atomically
ptr.store(&other_data, .monotonic);

// CAS on pointers
_ = ptr.cmpxchgWeak(&old_ptr, &new_ptr, .monotonic, .monotonic);
```

### Atomic Min/Max Pattern

Update a shared minimum or maximum using CAS:

```zig
fn updateMin(min_val: *Atomic(i32), value: i32) void {
    var current = min_val.load(.monotonic);
    while (value < current) {
        if (min_val.cmpxchgWeak(
            current,
            value,
            .monotonic,
            .monotonic,
        )) |new_val| {
            current = new_val; // Retry
        } else {
            break; // Success
        }
    }
}
```

### Double-Checked Locking

Optimize lazy initialization with an atomic flag:

```zig
const LazyInit = struct {
    initialized: Atomic(bool),
    mutex: Mutex,
    value: ?i32,

    fn getValue(self: *LazyInit) i32 {
        // Fast path: already initialized
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
```

Most threads hit the fast path without locking.

### When to Use Atomics

Use atomics when:
- Simple operations (counters, flags, pointers)
- Very high contention where mutex overhead matters
- Implementing lock-free data structures
- You understand memory ordering

Use mutexes when:
- Complex operations involving multiple variables
- Critical sections with conditional logic
- You're not sure about memory ordering
- Code clarity matters more than maximum performance

### Common Pitfalls

1. **Wrong memory ordering** - Can cause subtle bugs. When in doubt, use `.seq_cst`

2. **ABA problem** - Value changes from A→B→A, CAS succeeds incorrectly

   **The Problem:** In lock-free data structures using CAS on raw pointers, a dangerous race condition can occur:

   - Thread 1 reads head pointer (Node A) and head.next (Node B), then gets preempted
   - Thread 2 pops Node A, frees it, and pops Node B
   - Thread 2 allocates a new node at the same memory address as A
   - Thread 1 resumes and sees head is still address A, so CAS succeeds
   - Result: The stack is now corrupted because Node B was already removed

   **Example Scenario:**
   ```
   Initial: head -> A -> B -> C

   Thread 1: Reads head=A, reads A.next=B, prepares to CAS(A, B)
   Thread 2: Pops A (head -> B), pops B (head -> C)
   Thread 2: Allocates new node at address A (head -> A')
   Thread 1: CAS succeeds! Sets head=B (but B is stale/freed)
   Result: Corrupted stack with dangling pointer
   ```

   **Mitigation Strategies:**

   Production lock-free structures require memory reclamation:
   - **Hazard Pointers**: Threads mark pointers as "in-use" before accessing, preventing premature reclamation
   - **Epoch-Based Reclamation (EBR)**: Nodes are retired in epochs; only reclaimed after all threads have advanced
   - **Reference Counting**: Track how many threads reference each node

   **Important:** The lock-free stack example in this recipe is for educational purposes only. It does NOT implement memory reclamation and is unsafe for production use with heap-allocated nodes. For production code, use proven concurrent data structures or implement proper memory reclamation.

3. **Too much spinning** - Spin locks waste CPU on long waits
4. **Complex invariants** - Atomics can't protect complex multi-variable invariants
5. **Assuming atomicity** - Operations like `x = x + 1` are NOT atomic without explicit atomic ops

## See Also

- Recipe 12.2: Mutexes and basic locking
- Recipe 12.9: Preventing race conditions
- Recipe 12.12: Concurrent data structure patterns

Full compilable example: `code/04-specialized/12-concurrency/recipe_12_3.zig`
