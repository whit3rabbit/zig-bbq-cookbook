# Recipe 18.4: Object Pool Management

## Problem

You frequently allocate and deallocate objects of the same type, causing overhead from repeated allocator calls. You need to reuse expensive-to-create objects like database connections or network sockets, and you want to eliminate allocation overhead for hot paths in performance-critical code.

## Solution

Object pools maintain a collection of reusable objects, dramatically reducing allocation overhead by reusing objects instead of creating new ones.

### Basic Object Pool

Create a simple pool with a free list for object reuse:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_4.zig:basic_pool}}
```

### Pre-allocated Pool

Use a fixed-capacity pool with no dynamic allocation:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_4.zig:preallocated_pool}}
```

### Thread-Safe Pool

Add mutex protection for concurrent access:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_4.zig:thread_safe_pool}}
```

### Connection Pool

Reuse expensive-to-create connections:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_4.zig:connection_pool}}
```

### Pool-Based Allocator

Create an allocator interface for pool-managed objects:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_4.zig:pool_allocator}}
```

### Performance Benefits

Object pools provide dramatic performance improvements:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_4.zig:performance_comparison}}
```

This example shows pooling being 500+x faster because:
- No allocator overhead per object
- No memory management bookkeeping
- Better cache locality
- Reduced system calls

### Lazy Initialization Pool

Defer object initialization until first use:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_4.zig:lazy_pool}}
```

## Discussion

Object pools eliminate the overhead of repeated allocation/deallocation by maintaining a collection of reusable objects, providing both performance and predictability benefits.

### How Object Pools Work

An object pool manages object lifecycles:

1. **Initialization**: Pre-allocate or lazily create objects
2. **Acquire**: Remove an object from the free list or create new
3. **Use**: Application uses the object
4. **Release**: Return object to the free list for reuse
5. **Cleanup**: Free all objects on pool destruction

Objects are never destroyed individually - they're recycled back into the pool for reuse.

### Free List Pattern

The basic pool uses a free list (linked list of available objects):

**Acquire**: Pop from free list (O(1)), or allocate if empty
**Release**: Push to free list (O(1))
**Memory**: Nodes embed the free list pointer

This provides constant-time acquire/release operations with minimal overhead.

### When to Use Object Pools

**Perfect For:**
- Frequently created/destroyed objects (particles, bullets, messages)
- Expensive-to-create objects (database connections, threads, buffers)
- Fixed-size object types
- Performance-critical hot paths
- Real-time systems requiring predictable allocation
- Embedded systems with limited memory

**Avoid When:**
- Objects have varying lifetimes
- Objects are large and rarely reused
- Memory pressure is high (pools hold memory)
- Object initialization is trivial
- Different object types are needed

### Pre-allocated vs Dynamic Pools

**Pre-allocated Pools**:
- Pro: Zero allocations after init, predictable memory usage
- Con: Fixed capacity, wastes memory if under-utilized

**Dynamic Pools**:
- Pro: Grows as needed, efficient memory use
- Con: Occasional allocations for growth, unbounded growth risk

Choose pre-allocated for real-time systems and embedded platforms. Use dynamic for general-purpose applications with variable workloads.

### Thread Safety

Thread-safe pools add mutex protection:

```zig
pub fn acquire(self: *Self) !*T {
    self.mutex.lock();
    defer self.mutex.unlock();
    // ... pool logic
}
```

This ensures correctness when multiple threads access the pool concurrently. The mutex overhead is typically much smaller than allocation overhead.

**Lock-Free Alternative**: For very high concurrency, consider lock-free pools using atomics and thread-local pools.

### Connection Pooling Pattern

Connection pools keep expensive connections alive:

```zig
pub fn acquire(self: *Self) !*Connection {
    const conn = try self.pool.acquire();
    if (!conn.connected) {
        conn.* = Connection.init(self.next_id);
        try conn.connect(); // Expensive operation
    }
    return conn;
}
```

This pattern:
- Reuses established connections
- Avoids connection setup overhead (handshakes, authentication)
- Limits concurrent connections to the pool size
- Handles connection failures gracefully

Common for database connections, HTTP clients, and network sockets.

### Object Lifecycle Management

Pools manage object lifecycles differently than allocators:

**Construction**: May happen once (pre-allocated) or lazily (dynamic)
**Initialization**: Often separate from construction (init function)
**Reset**: Objects may be reset on release to clean state
**Destruction**: Only happens on pool destruction, not individual release

Design objects for pooling by separating construction from initialization.

### The @fieldParentPtr Trick

Pools store free list pointers in the Node structure:

```zig
const Node = struct {
    data: T,
    next: ?*Node,
};
```

To get the Node from a `*T`:

```zig
const node: *Node = @alignCast(@fieldParentPtr("data", item));
```

This recovers the parent Node pointer from the data field pointer, allowing pool metadata (next pointer) to live alongside the object data.

### Pool Capacity Management

**Pre-allocated**: Fixed capacity, `acquire()` returns null when exhausted

**Dynamic**: Grows automatically, bounded only by available memory

**Hybrid**: Start with pre-allocated buffer, allocate more as needed

**High-Water Mark**: Track maximum size, warn if pool grows too large

Monitor pool usage to detect capacity issues and memory leaks.

### Performance Characteristics

**Acquire**:
- From pool: O(1) (pop free list)
- New object: O(1) allocator call (amortized)
- Typical: 50-1000x faster than allocator

**Release**:
- O(1) (push to free list)
- No allocator calls

**Memory**:
- Per-object: Object size + pointer (usually 8 bytes)
- Overhead: Minimal (~1%)

**Cache**:
- Excellent locality if objects reused quickly
- Poor locality if pool is very large

### Common Pitfalls

**Use-After-Release**: Released objects are still valid pointers but may be reused. Don't access them after release.

**Capacity Exhaustion**: Pre-allocated pools can run out. Handle null returns from `acquire()`.

**Memory Leaks**: Forgetting to release objects back to the pool. Use RAII or defer patterns.

**Thread Safety**: Accessing pool from multiple threads without synchronization causes corruption.

**Unbounded Growth**: Dynamic pools without limits can exhaust memory.

### Best Practices

**RAII Wrappers**: Create scoped wrappers that auto-release on scope exit:

```zig
const Scoped = struct {
    pool: *Pool(T),
    item: *T,

    pub fn deinit(self: Scoped) void {
        self.pool.release(self.item);
    }
};
```

**Defer Release**: Always use `defer pool.release(obj)` immediately after acquire.

**Separate Init**: Keep object construction separate from initialization. Allow reset without reallocation.

**Limit Capacity**: Set maximum pool size to prevent unbounded growth.

**Monitor Usage**: Track high-water marks, acquisition failures, and release patterns.

**Document Ownership**: Clearly document who owns pooled objects and when they should be released.

### Lazy Initialization

Lazy pools defer expensive initialization until first use:

```zig
pub fn acquire(self: *Self) !*T {
    const obj = try self.pool.acquire();
    if (!obj.initialized) {
        obj.* = init_fn();
        obj.initialized = true;
    }
    return obj;
}
```

Benefits:
- Avoid initialization cost if objects unused
- Delay expensive setup (file opens, connection establishment)
- Reduce startup time

### Pool Warming

Pre-warm pools by pre-allocating objects:

```zig
pub fn warmup(self: *Self, count: usize) !void {
    var i: usize = 0;
    while (i < count) : (i += 1) {
        const obj = try self.acquire();
        self.release(obj);
    }
}
```

This ensures objects are pre-allocated, eliminating first-use latency.

### Multi-Type Pools

For multiple types, use a struct of pools:

```zig
const Pools = struct {
    entities: Pool(Entity),
    projectiles: Pool(Projectile),
    particles: Pool(Particle),

    pub fn init(allocator: Allocator) Pools {
        return .{
            .entities = Pool(Entity).init(allocator),
            .projectiles = Pool(Projectile).init(allocator),
            .particles = Pool(Particle).init(allocator),
        };
    }
};
```

This provides centralized pool management for related types.

### Integration with Game Engines

Object pools are fundamental to game engines:

**Entities**: Reuse game objects (enemies, bullets, pickups)
**Particle Systems**: Pool thousands of particles
**Audio Sources**: Reuse sound effect instances
**UI Elements**: Recycle menu items, list entries

Game loops can reset pools each frame for maximum performance.

### Debugging Pool Issues

**Double-Release**: Releasing the same object twice corrupts the free list. Add debug checks:

```zig
if (builtin.mode == .Debug) {
    // Check if object is already in free list
}
```

**Leaks**: Objects never released. Use `pool.used` to track active objects.

**Capacity**: Pre-allocated pools returning null. Log capacity exhaustion.

**Corruption**: Free list corruption from race conditions. Ensure thread safety.

### Advanced Patterns

**Per-Thread Pools**: Each thread has its own pool, eliminating contention.

**Tiered Pools**: Small objects in one pool, large in another.

**Generation Counting**: Add generation counters to detect use-after-release.

**Intrusive Pools**: Store free list pointer inside objects themselves (no separate Node).

### Comparison to Allocators

**General Allocator**:
- Works for any size/type
- Higher overhead per allocation
- Flexible, handles any pattern

**Object Pool**:
- Fixed type and size only
- Minimal overhead (50-1000x faster)
- Requires manual release

**When to Choose**: Use pools when you have a type that's frequently allocated/freed in hot paths.

### Real-World Use Cases

**Web Servers**: Request/response objects, buffer pools, connection pools
**Databases**: Connection pools, prepared statement caches, result set buffers
**Game Engines**: Entities, particles, audio sources, render commands
**Message Queues**: Message buffers, worker threads
**Network Stacks**: Packet buffers, socket objects

## See Also

- Recipe 18.1: Custom Allocator Implementation
- Recipe 18.2: Arena Allocator Patterns
- Recipe 12.4: Thread Pools for Parallel Work
- Recipe 11.7: Handling Cookies and Sessions (connection pooling)

Full compilable example: `code/05-zig-paradigms/18-memory-management/recipe_18_4.zig`
