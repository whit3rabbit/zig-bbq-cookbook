## Problem

Multiple threads frequently read shared data but rarely write it. Regular mutexes serialize all access, even reads. You want concurrent reads with exclusive writes.

## Solution

Use `std.Thread.RwLock` to allow multiple concurrent readers or one exclusive writer.

```zig
{{#include ../../../code/04-specialized/12-concurrency/recipe_12_7.zig:basic_rwlock}}
```

## Discussion

Read-write locks excel when reads outnumber writes significantly. Multiple readers can proceed concurrently, improving throughput.

### Cache Example

```zig
const Cache = struct {
    data: std.StringHashMap([]const u8),
    lock: RwLock,

    fn get(self: *Cache, key: []const u8) ?[]const u8 {
        self.lock.lockShared(); // Shared read
        defer self.lock.unlockShared();
        return self.data.get(key);
    }

    fn put(self: *Cache, key: []const u8, value: []const u8) !void {
        self.lock.lock(); // Exclusive write
        defer self.lock.unlock();
        try self.data.put(key, value);
    }
};
```

Lookups don't block each other, only updates.

### When to Use

- **Read-heavy workloads** (90%+ reads)
- **Large data structures** where reads take time
- **Caches, configuration, reference data**

### When NOT to Use

- **Write-heavy** - overhead not worth it
- **Short critical sections** - regular mutex is faster
- **Frequent small reads** - atomic operations better

## See Also

- Recipe 12.2: Mutexes and basic locking
- Recipe 12.3: Atomic operations

Full compilable example: `code/04-specialized/12-concurrency/recipe_12_7.zig`
