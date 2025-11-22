## Problem

You have properties that are expensive to compute—file loading, complex calculations, or external API calls—and you want to defer computation until the value is actually needed, then cache the result for subsequent accesses.

## Solution

Use optional fields to cache computed values. Check if the cache is populated before computing, and invalidate the cache when dependencies change.

### Basic Lazy Evaluation

Use an optional to track whether a value has been computed:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_10.zig:basic_lazy_optional}}
```

The computation only runs once, on first access.

### Lazy Initialization with Allocator

For values that require memory allocation:

```zig
const LazyString = struct {
    allocator: std.mem.Allocator,
    cached: ?[]u8,
    generator_called: u32,

    pub fn init(allocator: std.mem.Allocator) LazyString {
        return LazyString{
            .allocator = allocator,
            .cached = null,
            .generator_called = 0,
        };
    }

    pub fn deinit(self: *LazyString) void {
        if (self.cached) |data| {
            self.allocator.free(data);
        }
    }

    pub fn getValue(self: *LazyString) ![]const u8 {
        if (self.cached) |data| {
            return data;
        }

        // Expensive generation
        self.generator_called += 1;
        const generated = try std.fmt.allocPrint(
            self.allocator,
            "Generated value #{d}",
            .{self.generator_called},
        );
        self.cached = generated;
        return generated;
    }

    pub fn reset(self: *LazyString) void {
        if (self.cached) |data| {
            self.allocator.free(data);
            self.cached = null;
        }
    }
};
```

Remember to free the cached value in `deinit()`.

### Cached Computed Properties

Cache multiple dependent properties and invalidate all when data changes:

```zig
const Rectangle = struct {
    width: f32,
    height: f32,
    cached_area: ?f32,
    cached_perimeter: ?f32,

    pub fn init(width: f32, height: f32) Rectangle {
        return Rectangle{
            .width = width,
            .height = height,
            .cached_area = null,
            .cached_perimeter = null,
        };
    }

    pub fn getArea(self: *Rectangle) f32 {
        if (self.cached_area) |area| {
            return area;
        }

        const area = self.width * self.height;
        self.cached_area = area;
        return area;
    }

    pub fn setWidth(self: *Rectangle, width: f32) void {
        self.width = width;
        self.invalidateCache();
    }

    fn invalidateCache(self: *Rectangle) void {
        self.cached_area = null;
        self.cached_perimeter = null;
    }
};
```

Setters invalidate all cached properties that depend on the changed data.

### Memoization Pattern

Cache results of recursive or repeated function calls:

```zig
const Fibonacci = struct {
    cache: [100]?u64,

    pub fn init() Fibonacci {
        return Fibonacci{
            .cache = [_]?u64{null} ** 100,
        };
    }

    pub fn compute(self: *Fibonacci, n: usize) u64 {
        if (n < 2) return n;

        if (n < self.cache.len) {
            if (self.cache[n]) |cached| {
                return cached;
            }
        }

        const result = self.compute(n - 1) + self.compute(n - 2);

        if (n < self.cache.len) {
            self.cache[n] = result;
        }

        return result;
    }
};
```

Dramatically improves performance for recursive algorithms.

### Time-Based Cache Invalidation

Automatically expire cached values after a timeout:

```zig
const TimedCache = struct {
    value: ?[]const u8,
    computed_at: i64,
    ttl_seconds: i64,

    pub fn init(ttl_seconds: i64) TimedCache {
        return TimedCache{
            .value = null,
            .computed_at = 0,
            .ttl_seconds = ttl_seconds,
        };
    }

    pub fn getValue(self: *TimedCache, current_time: i64) []const u8 {
        if (self.value) |cached| {
            if (current_time - self.computed_at < self.ttl_seconds) {
                return cached;
            }
        }

        // Generate new value
        const generated = "fresh value";
        self.value = generated;
        self.computed_at = current_time;
        return generated;
    }

    pub fn isValid(self: *const TimedCache, current_time: i64) bool {
        if (self.value == null) return false;
        return current_time - self.computed_at < self.ttl_seconds;
    }
};
```

Useful for API responses, configuration files, or other time-sensitive data.

### Dependency Lazy Properties

Chain lazy properties where one depends on another:

```zig
const DataModel = struct {
    raw_data: []const i32,
    filtered: ?[]i32,
    sorted: ?[]i32,
    allocator: std.mem.Allocator,

    pub fn getSorted(self: *DataModel) ![]const i32 {
        if (self.sorted) |cached| {
            return cached;
        }

        // Depends on filtered data
        const filtered = try self.getFiltered();
        const sorted = try self.allocator.dupe(i32, filtered);
        std.mem.sort(i32, sorted, {}, comptime std.sort.asc(i32));

        self.sorted = sorted;
        return sorted;
    }

    pub fn invalidate(self: *DataModel) void {
        if (self.filtered) |f| {
            self.allocator.free(f);
            self.filtered = null;
        }
        if (self.sorted) |s| {
            self.allocator.free(s);
            self.sorted = null;
        }
    }
};
```

Invalidating upstream dependencies automatically invalidates downstream ones.

### Generic Lazy Wrapper

Create a reusable lazy wrapper for any type:

```zig
fn Lazy(comptime T: type) type {
    return struct {
        value: ?T,
        generator: *const fn () T,

        const Self = @This();

        pub fn init(generator: *const fn () T) Self {
            return Self{
                .value = null,
                .generator = generator,
            };
        }

        pub fn get(self: *Self) T {
            if (self.value) |cached| {
                return cached;
            }

            const computed = self.generator();
            self.value = computed;
            return computed;
        }

        pub fn invalidate(self: *Self) void {
            self.value = null;
        }

        pub fn isComputed(self: *const Self) bool {
            return self.value != null;
        }
    };
}
```

This pattern works for any type that doesn't require allocation.

### Lazy Evaluation with Errors

Handle errors in lazy computations:

```zig
const FallibleLazy = struct {
    value: ?i32,
    last_error: ?anyerror,

    pub fn getValue(self: *FallibleLazy, input: i32) !i32 {
        if (self.value) |cached| {
            return cached;
        }

        const result = self.compute(input) catch |err| {
            self.last_error = err;
            return err;
        };

        self.value = result;
        self.last_error = null;
        return result;
    }

    fn compute(self: *FallibleLazy, input: i32) !i32 {
        _ = self;
        if (input < 0) return error.NegativeInput;
        return input * 2;
    }
};
```

Track the last error for debugging while still caching successful results.

## Discussion

Lazy evaluation is a powerful optimization technique that trades memory (cache storage) for CPU time (avoiding repeated computation).

### When to Use Lazy Properties

Use lazy evaluation when:

- **Computation is expensive** - Complex algorithms, file I/O, network requests
- **Value might not be needed** - Optional features or conditional code paths
- **Value used multiple times** - Repeated access to the same computed result
- **Initialization order matters** - Break circular dependencies

Don't use lazy evaluation for:

- Simple computations (addition, multiplication)
- Values always needed immediately
- Single-use values
- When memory is more constrained than CPU

### Performance Characteristics

**Space**: O(1) overhead per lazy property (one optional field)
**Time**: First access pays full computation cost, subsequent accesses are O(1)
**Thread safety**: Not thread-safe by default (requires synchronization for concurrent access)

### Common Patterns

1. **Cache invalidation**: Clear cache when dependencies change
2. **Expiration**: Use timestamps for time-based invalidation
3. **Memoization**: Cache function results by input parameters
4. **Lazy loading**: Defer file/network loading until needed
5. **Computed properties**: Calculate derived values only when accessed

### Memory Management

For allocated lazy values:

- Store `allocator` as a field
- Free cached value in `deinit()`
- Free old value before computing new one in `reset()`
- Consider using `errdefer` to clean up on errors

### Thread Safety

The patterns shown are not thread-safe. For concurrent access:

- Use a `std.Thread.Mutex` to protect the cache
- Consider atomic operations for simple types
- Or use read-write locks for better read performance

## See Also

- Recipe 8.6: Creating Managed Attributes
- Recipe 8.8: Extending a Property in a Subclass
- Recipe 9.11: Using comptime to Control Instance Creation
- Recipe 18.1: Memory Pool Patterns (Phase 5)

Full compilable example: `code/03-advanced/08-structs-unions-objects/recipe_8_10.zig`
