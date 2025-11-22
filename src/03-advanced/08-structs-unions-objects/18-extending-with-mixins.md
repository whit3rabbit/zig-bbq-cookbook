## Problem

You want to add cross-cutting functionality (like logging, validation, caching, or timing) to multiple types without code duplication. Traditional inheritance doesn't fit Zig's philosophy.

## Solution

Use compile-time functions that return wrapper types. These "mixins" embed the original type and add new functionality, composing features at compile time with zero runtime overhead.

### Basic Mixin Pattern

Wrap a type to add functionality:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_18.zig:basic_mixin}}
```

The mixin wraps SimpleTask, adding logging without modifying the original type.

### Composing Multiple Mixins

Stack mixins to combine functionality:

```zig
fn WithTiming(comptime T: type) type {
    return struct {
        inner: T,
        last_duration_ns: u64,

        pub fn execute(self: *Self) void {
            const start = std.time.nanoTimestamp();
            if (@hasDecl(T, "execute")) {
                self.inner.execute();
            }
            const end = std.time.nanoTimestamp();
            self.last_duration_ns = @intCast(end - start);
        }

        pub fn getDuration(self: *const Self) u64 {
            return self.last_duration_ns;
        }
    };
}

// Stack multiple mixins
const task = SimpleTask.init();
var logged = WithLogging(SimpleTask).init(task);
var timed = WithTiming(WithLogging(SimpleTask)).init(logged);

timed.execute();
// Now both timed and logged!
```

Mixins compose naturally, each adding a layer of functionality.

### Validation Mixin

Add runtime validation to any type:

```zig
fn WithValidation(comptime T: type) type {
    return struct {
        inner: T,
        validation_errors: u32,

        pub fn setValue(self: *Self, value: i32) !void {
            if (value < 0) {
                self.validation_errors += 1;
                return error.InvalidValue;
            }
            if (@hasDecl(T, "setValue")) {
                try self.inner.setValue(value);
            }
        }

        pub fn getValidationErrors(self: *const Self) u32 {
            return self.validation_errors;
        }
    };
}
```

The validation mixin intercepts method calls to enforce constraints.

### Caching Mixin

Add memoization to expensive computations:

```zig
fn WithCache(comptime T: type, comptime CacheType: type) type {
    return struct {
        inner: T,
        cache: ?CacheType,
        cache_hits: u32,

        pub fn compute(self: *Self) CacheType {
            if (self.cache) |cached| {
                self.cache_hits += 1;
                return cached;
            }

            const result = if (@hasDecl(T, "compute"))
                self.inner.compute()
            else
                @as(CacheType, 0);

            self.cache = result;
            return result;
        }

        pub fn invalidate(self: *Self) void {
            self.cache = null;
        }

        pub fn getCacheHits(self: *const Self) u32 {
            return self.cache_hits;
        }
    };
}
```

Caching is transparently added to any type with a `compute()` method.

### Serialization Mixin

Add serialization without modifying the original type:

```zig
fn Serializable(comptime T: type) type {
    return struct {
        inner: T,

        pub fn toBytes(self: *const Self, buffer: []u8) !usize {
            if (buffer.len < @sizeOf(T)) return error.BufferTooSmall;
            const bytes = std.mem.asBytes(&self.inner);
            @memcpy(buffer[0..bytes.len], bytes);
            return bytes.len;
        }

        pub fn fromBytes(bytes: []const u8) !Self {
            if (bytes.len < @sizeOf(T)) return error.BufferTooSmall;
            var inner: T = undefined;
            const dest = std.mem.asBytes(&inner);
            @memcpy(dest, bytes[0..dest.len]);
            return Self{ .inner = inner };
        }
    };
}
```

Any type can now be serialized to/from bytes.

### Observable Mixin

Add observer pattern functionality:

```zig
fn Observable(comptime T: type) type {
    return struct {
        inner: T,
        observers: u32,

        pub fn notify(self: *Self) void {
            self.observers += 1;
        }

        pub fn modify(self: *Self, value: anytype) void {
            if (@hasDecl(T, "setValue")) {
                self.inner.setValue(value) catch {};
            }
            self.notify();
        }

        pub fn getNotificationCount(self: *const Self) u32 {
            return self.observers;
        }
    };
}
```

Track changes and notify observers automatically.

### Retry Mixin

Add automatic retry logic with backoff:

```zig
fn WithRetry(comptime T: type, comptime max_retries: u32) type {
    return struct {
        inner: T,
        retry_count: u32,

        pub fn execute(self: *Self) !void {
            var attempts: u32 = 0;
            while (attempts < max_retries) : (attempts += 1) {
                if (@hasDecl(T, "execute")) {
                    self.inner.execute() catch |err| {
                        self.retry_count += 1;
                        if (attempts == max_retries - 1) {
                            return err;
                        }
                        continue;
                    };
                    return;
                }
            }
        }

        pub fn getRetryCount(self: *const Self) u32 {
            return self.retry_count;
        }
    };
}
```

Automatically retry failed operations.

### Conditional Mixin

Use comptime to enable/disable features:

```zig
fn WithDebug(comptime T: type, comptime enable_debug: bool) type {
    if (enable_debug) {
        return struct {
            inner: T,
            debug_info: []const u8,

            pub fn execute(self: *Self) void {
                // Debug wrapper active
                if (@hasDecl(T, "execute")) {
                    self.inner.execute();
                }
            }

            pub fn getDebugInfo(self: *const Self) []const u8 {
                return self.debug_info;
            }
        };
    } else {
        return struct {
            inner: T,

            pub fn execute(self: *Self) void {
                // No debug overhead
                if (@hasDecl(T, "execute")) {
                    self.inner.execute();
                }
            }
        };
    }
}
```

Compile-time flags control which features are included.

### Thread-Safety Mixin

Add locking behavior (conceptual example):

```zig
fn ThreadSafe(comptime T: type) type {
    return struct {
        inner: T,
        lock_count: u32,

        pub fn withLock(self: *Self, comptime func: anytype) void {
            self.lock_count += 1;
            defer self.lock_count -= 1;
            func(&self.inner);
        }

        pub fn getLockCount(self: *const Self) u32 {
            return self.lock_count;
        }
    };
}

// Usage
var safe = ThreadSafe(Counter).init(counter);
safe.withLock(struct {
    fn call(c: *Counter) void {
        c.value = 100;
    }
}.call);
```

Encapsulate synchronization logic in a reusable mixin.

## Discussion

Mixins provide compile-time composition without runtime overhead.

### How Mixins Work

**Compile-time type generation**:
```zig
fn Mixin(comptime T: type) type {  // Takes a type
    return struct {                 // Returns a new type
        inner: T,                   // Embeds original
        // ... additional fields and methods
    };
}
```

**Zero runtime cost**:
- All mixin logic runs at compile time
- Generated types are concrete structs
- No vtables, no dynamic dispatch
- Same as hand-written code

**Type inference**:
```zig
const Logged = WithLogging(Task);  // New type created
var x = Logged.init(...);          // Type: WithLogging(Task)
```

### Mixin Patterns

**Wrapper pattern**: Embed and extend
```zig
return struct {
    inner: T,
    extra_field: u32,
    pub fn method(self: *Self) void {
        self.inner.originalMethod();  // Delegate
        // ... extra behavior
    }
};
```

**Conditional compilation**: Feature flags
```zig
if (enable_feature) {
    return struct { /* with feature */ };
} else {
    return struct { /* without feature */ };
}
```

**Method forwarding**: Delegate to inner
```zig
pub fn getInner(self: *Self) *T {
    return &self.inner;
}
```

**Capability checking**: Use @hasDecl
```zig
if (@hasDecl(T, "method")) {
    self.inner.method();
}
```

### Design Guidelines

**Naming conventions**:
- `With*` for adding functionality (`WithLogging`, `WithCache`)
- Descriptive names showing what's added
- Use `inner` for the wrapped type

**Interface requirements**:
- Document required methods in comments
- Use `@hasDecl` to check capabilities
- Provide sensible defaults when methods missing

**Composability**:
- Mixins should stack without conflicts
- Each mixin should be independent
- Access inner type with `getInner()`

**Performance**:
- Avoid unnecessary indirection
- Inline small methods
- Use comptime to eliminate dead code

### Advantages Over Inheritance

**Explicit composition**:
```zig
// Clear what functionality is added
var logged = WithLogging(Task).init(task);
var validated = WithValidation(WithLogging(Task)).init(...);
```

**No fragile base class problem**:
- Changes to inner type don't break mixins
- Mixins are independent
- Compile-time errors for incompatibilities

**Flexible**:
- Mix and match as needed
- Different combinations for different uses
- No single inheritance limitation

**Type-safe**:
- All checked at compile time
- No runtime surprises
- Clear error messages

### Common Use Cases

**Cross-cutting concerns**:
- Logging
- Metrics/monitoring
- Validation
- Caching
- Error handling
- Authentication/authorization

**Aspect-oriented programming**:
- Timing measurements
- Resource tracking
- Transaction management
- Retry logic

**Protocol adaptation**:
- Serialization
- Formatting
- Type conversion
- Interface matching

### Performance Characteristics

**Compile-time overhead**: Type generation happens at compile time
- Longer compile times with many mixins
- No runtime impact

**Runtime overhead**: Zero
- Inlined like hand-written code
- No function pointers
- No vtable lookups

**Memory overhead**: Only added fields
```zig
WithLogging(T):
  sizeof(T) + sizeof(u32)  // log_count field

WithCache(T, i32):
  sizeof(T) + sizeof(?i32) + sizeof(u32)  // cache + hits
```

### Comparison with Other Languages

**Rust traits**:
```rust
impl Loggable for Task { ... }  // Zig: WithLogging(Task)
```

**Python decorators**:
```python
@with_logging                   // Zig: WithLogging(Task)
def task(): ...
```

**C++ CRTP (Curiously Recurring Template Pattern)**:
```cpp
template<typename T>
class Logging : public T { ... }  // Zig: WithLogging(T)
```

Zig's approach is simpler and more explicit than these alternatives.

## See Also

- Recipe 8.15: Delegating Attribute Access
- Recipe 8.12: Defining an Interface or Abstract Base Class
- Recipe 9.11: Using comptime to Control Instance Creation
- Recipe 9.16: Defining Structs Programmatically

Full compilable example: `code/03-advanced/08-structs-unions-objects/recipe_8_18.zig`
