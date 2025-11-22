## Problem

You want to apply decorators to struct instance methods or static methods (functions within structs that don't take `self`). You need to track method calls, add validation, implement caching, or inject other behavior without modifying method implementations.

## Solution

Create decorators that accept methods as compile-time parameters and return wrapper types with state and additional functionality.

### Instance Method Decorator

Decorate methods that take a `self` parameter:

```zig
{{#include ../../../code/03-advanced/09-metaprogramming/recipe_9_8.zig:instance_method_decorator}}
```

The decorator tracks how many times the method is called.

### Static Method Decorator

Decorate static methods without `self`:

```zig
fn WithCache(comptime func: anytype) type {
    return struct {
        const Self = @This();
        const CacheEntry = struct {
            input: i32,
            output: i32,
        };

        cache: ?CacheEntry = null,

        pub fn call(self: *Self, x: i32) i32 {
            if (self.cache) |entry| {
                if (entry.input == x) {
                    return entry.output;
                }
            }

            const result = func(x);
            self.cache = CacheEntry{ .input = x, .output = result };
            return result;
        }

        pub fn isCached(self: Self, x: i32) bool {
            if (self.cache) |entry| {
                return entry.input == x;
            }
            return false;
        }
    };
}

const Math = struct {
    pub fn square(x: i32) i32 {
        return x * x;
    }
};

// Usage
var cached = WithCache(Math.square){};

cached.call(5);      // Computes 25, caches
cached.call(5);      // Returns cached 25
cached.isCached(5);  // true
```

Caching decorator for pure static methods.

### Generic Method Decorator

Handle any method signature with `anytype` and `@call`:

```zig
fn MethodDecorator(comptime func: anytype) type {
    const func_info = @typeInfo(@TypeOf(func));
    const ReturnType = func_info.@"fn".return_type.?;

    return struct {
        const Self = @This();
        invocations: u32 = 0,

        pub fn call(self: *Self, args: anytype) ReturnType {
            self.invocations += 1;
            return @call(.auto, func, args);
        }

        pub fn getInvocations(self: Self) u32 {
            return self.invocations;
        }
    };
}

const Calculator = struct {
    multiplier: i32,

    pub fn multiply(self: Calculator, x: i32) i32 {
        return x * self.multiplier;
    }
};

// Usage
const calc = Calculator{ .multiplier = 3 };
var decorated = MethodDecorator(Calculator.multiply){};

decorated.call(.{ calc, 5 });  // 15
decorated.getInvocations();     // 1
```

Works with any argument tuple.

### Bound Method Decorator

Bind an instance to a method for convenient reuse:

```zig
fn BoundMethod(comptime Instance: type, comptime method: anytype) type {
    return struct {
        const Self = @This();
        instance: *Instance,
        call_count: u32 = 0,

        pub fn init(instance: *Instance) Self {
            return .{ .instance = instance };
        }

        pub fn call(self: *Self, x: i32) i32 {
            self.call_count += 1;
            return method(self.instance, x);
        }

        pub fn getCallCount(self: Self) u32 {
            return self.call_count;
        }
    };
}

// Usage
var counter = Counter{};
var bound = BoundMethod(Counter, Counter.add).init(&counter);

bound.call(5);  // Calls counter.add(5)
bound.call(3);  // Calls counter.add(3)

counter.value;         // 8
bound.getCallCount();  // 2
```

Instance is bound at initialization.

### Validation Method Decorator

Add bounds checking to methods:

```zig
fn WithValidation(comptime method: anytype, comptime min: i32, comptime max: i32) type {
    return struct {
        const Self = @This();
        validation_errors: u32 = 0,

        pub fn call(self: *Self, instance: anytype, x: i32) !i32 {
            if (x < min or x > max) {
                self.validation_errors += 1;
                return error.OutOfBounds;
            }
            return method(instance, x);
        }

        pub fn getValidationErrors(self: Self) u32 {
            return self.validation_errors;
        }
    };
}

// Usage
var counter = Counter{};
var validated = WithValidation(Counter.add, 0, 10){};

try validated.call(&counter, 5);   // 5 (valid)
try validated.call(&counter, 15);  // error.OutOfBounds

validated.getValidationErrors();    // 1
```

Tracks validation failures.

### Timing Method Decorator

Measure method execution time:

```zig
fn WithTiming(comptime method: anytype) type {
    return struct {
        const Self = @This();
        total_time: u64 = 0,
        calls: u32 = 0,

        pub fn call(self: *Self, instance: anytype, x: i32) i32 {
            // In real code, measure actual time
            const elapsed: u64 = 100;
            self.total_time += elapsed;
            self.calls += 1;
            return method(instance, x);
        }

        pub fn getAverageTime(self: Self) u64 {
            if (self.calls == 0) return 0;
            return self.total_time / self.calls;
        }
    };
}

// Usage
var counter = Counter{};
var timed = WithTiming(Counter.add){};

timed.call(&counter, 5);
timed.call(&counter, 3);

timed.getAverageTime();  // 100 (average time per call)
```

Tracks cumulative and average timing.

### Composed Decorators

Combine multiple decorator behaviors:

```zig
fn ComposeDecorators(comptime method: anytype) type {
    return struct {
        const Self = @This();
        log_count: u32 = 0,
        time_count: u32 = 0,

        pub fn call(self: *Self, instance: anytype, x: i32) i32 {
            // Log the call
            self.log_count += 1;
            // Time the call
            self.time_count += 1;
            // Call the method
            const result = method(instance, x);
            // Apply transformation
            return result * 2;
        }

        pub fn getLogCount(self: Self) u32 {
            return self.log_count;
        }
    };
}

// Usage
var counter = Counter{};
var composed = ComposeDecorators(Counter.add){};

composed.call(&counter, 5);  // 10 (5 * 2)
composed.getLogCount();       // 1
```

Single decorator with multiple concerns.

### Method Wrapper Struct

Wrap all methods of a struct:

```zig
fn DecoratedStruct(comptime T: type) type {
    return struct {
        const Self = @This();
        inner: T,
        add_calls: u32 = 0,

        pub fn init(inner: T) Self {
            return .{ .inner = inner };
        }

        pub fn add(self: *Self, x: i32) i32 {
            self.add_calls += 1;
            return self.inner.add(x);
        }

        pub fn getAddCalls(self: Self) u32 {
            return self.add_calls;
        }
    };
}

// Usage
const counter = Counter{};
var decorated = DecoratedStruct(Counter).init(counter);

decorated.add(5);
decorated.add(3);

decorated.getAddCalls();  // 2
```

Wrapper tracks calls to specific methods.

### Conditional Method Decorator

Enable/disable decoration at compile time:

```zig
fn ConditionalMethod(comptime method: anytype, comptime enabled: bool) type {
    return struct {
        const Self = @This();
        calls_when_enabled: u32 = 0,

        pub fn call(self: *Self, instance: anytype, x: i32) i32 {
            if (enabled) {
                self.calls_when_enabled += 1;
                const result = method(instance, x);
                return result * 2;
            }
            return method(instance, x);
        }

        pub fn getCalls(self: Self) u32 {
            return self.calls_when_enabled;
        }
    };
}

// Usage
var enabled = ConditionalMethod(Counter.add, true){};
enabled.call(&counter, 5);   // 10 (enabled: doubles)

var disabled = ConditionalMethod(Counter.add, false){};
disabled.call(&counter, 5);  // 5 (disabled: pass-through)
```

Compile-time conditional decoration.

### Memoizing Method

Cache method results based on input:

```zig
fn Memoized(comptime method: anytype) type {
    return struct {
        const Self = @This();
        const Entry = struct {
            input: i32,
            output: i32,
        };

        cache: [10]?Entry = [_]?Entry{null} ** 10,
        cache_size: usize = 0,

        pub fn call(self: *Self, instance: anytype, x: i32) i32 {
            // Check cache
            for (self.cache[0..self.cache_size]) |maybe_entry| {
                if (maybe_entry) |entry| {
                    if (entry.input == x) {
                        return entry.output;
                    }
                }
            }

            // Not in cache, compute
            const result = method(instance, x);

            // Add to cache if space
            if (self.cache_size < self.cache.len) {
                self.cache[self.cache_size] = Entry{ .input = x, .output = result };
                self.cache_size += 1;
            }

            return result;
        }

        pub fn getCacheSize(self: Self) usize {
            return self.cache_size;
        }
    };
}

// Usage
var counter = Counter{};
var memoized = Memoized(Counter.add){};

memoized.call(&counter, 5);  // Computes, caches
memoized.call(&counter, 5);  // Returns cached

memoized.getCacheSize();     // 1
```

Simple memoization with fixed-size cache.

### Retry Method Decorator

Implement retry logic for fallible methods:

```zig
fn WithRetry(comptime method: anytype, comptime max_attempts: u32) type {
    return struct {
        const Self = @This();
        retry_count: u32 = 0,

        pub fn call(self: *Self, instance: anytype, x: i32) !i32 {
            var attempt: u32 = 0;
            var last_error: ?anyerror = null;

            while (attempt < max_attempts) : (attempt += 1) {
                self.retry_count += 1;
                const result = method(instance, x) catch |err| {
                    last_error = err;
                    continue;
                };
                return result;
            }

            if (last_error) |err| {
                return err;
            }
            return error.MaxRetriesExceeded;
        }

        pub fn getRetryCount(self: Self) u32 {
            return self.retry_count;
        }
    };
}

const Fallible = struct {
    attempts: u32 = 0,

    pub fn unreliable(self: *Fallible, x: i32) !i32 {
        self.attempts += 1;
        if (self.attempts < 3) {
            return error.Temporary;
        }
        return x * 2;
    }
};

// Usage
var fallible = Fallible{};
var retry = WithRetry(Fallible.unreliable, 5){};

const result = try retry.call(&fallible, 10);  // 20 (succeeds on 3rd attempt)
retry.getRetryCount();  // 3
```

Automatic retry for transient failures.

## Discussion

Method decorators provide powerful metaprogramming capabilities for adding cross-cutting concerns to struct methods.

### Instance vs Static Methods

**Instance methods**:
```zig
pub fn method(self: *Self, args...) ReturnType
```

Take `self` as first parameter, access instance state.

**Static methods**:
```zig
pub fn staticMethod(args...) ReturnType
```

No `self` parameter, pure functions within struct namespace.

**Decorator differences**:

For instance methods, decorator `call` must pass instance:
```zig
pub fn call(self: *Self, instance: anytype, x: i32) i32 {
    return method(instance, x);
}
```

For static methods, no instance needed:
```zig
pub fn call(self: *Self, x: i32) i32 {
    return func(x);
}
```

### Compile-Time Method Binding

**Methods stored as comptime parameters**:
```zig
fn Decorator(comptime method: anytype) type
```

Method is a compile-time value, not stored in decorator instance.

**Zero runtime cost**:
- No function pointer storage
- No indirection overhead
- Fully inlined by compiler
- Type-specific optimization

**Multiple decorations**:
```zig
const Logged = WithLogging(Counter.add){};
const Cached = WithCache(Counter.add){};
```

Each creates separate type.

### State Management

**Per-decorator state**:
```zig
return struct {
    call_count: u32 = 0,  // Instance state
    // ...
};
```

Each decorator instance has own state.

**Shared static state**:
```zig
return struct {
    var call_count: u32 = 0,  // Shared state
    // ...
};
```

All instances of this decorator type share state.

**Resettable state**:
```zig
pub fn reset(self: *Self) void {
    self.call_count = 0;
}
```

Allow clearing state for testing or reuse.

### Generic Method Wrapping

**Using `anytype` for arguments**:
```zig
pub fn call(self: *Self, args: anytype) ReturnType {
    return @call(.auto, func, args);
}
```

Works with any argument tuple.

**Type introspection**:
```zig
const func_info = @typeInfo(@TypeOf(func));
const ReturnType = func_info.@"fn".return_type.?;
```

Extract method metadata at compile time.

**Preserving signatures**:

Decorator's `call` should match wrapped method's signature where possible for type safety.

### Bound Methods

**Python-style bound methods**:
```zig
var bound = BoundMethod(Counter, Counter.add).init(&counter);
bound.call(5);  // No need to pass &counter
```

Instance bound at initialization, calls simplified.

**Use cases**:
- Callbacks with context
- Event handlers with state
- Simplified APIs

### Validation Patterns

**Compile-time bounds**:
```zig
fn WithValidation(comptime method: anytype, comptime min: i32, comptime max: i32)
```

Bounds known at compile time, zero overhead.

**Runtime error tracking**:
```zig
validation_errors: u32 = 0,
```

Count failures for monitoring.

**Error propagation**:
```zig
pub fn call(...) !ReturnType {
    if (invalid) return error.ValidationFailed;
    return method(...);
}
```

Caller handles validation errors.

### Caching Strategies

**Simple cache**:
```zig
cache: ?CacheEntry = null,  // Single entry
```

Useful for repeated calls with same input.

**Fixed-size cache**:
```zig
cache: [10]?Entry = [_]?Entry{null} ** 10,
cache_size: usize = 0,
```

Multiple entries, no allocation.

**Hash-based cache**:

Use `std.AutoHashMap` for larger caches (requires allocator).

**Cache invalidation**:
```zig
pub fn clearCache(self: *Self) void {
    self.cache = null;
}
```

### Composition Techniques

**Single composite decorator**:
```zig
fn ComposeDecorators(comptime method: anytype) type {
    // Multiple behaviors in one decorator
}
```

Simpler than chaining separate decorators.

**Nested decorators**:
```zig
const Logged = WithLogging(method);
const LoggedAndCached = WithCache(Logged.call);
```

Layer decorators for complex behavior.

**Trade-offs**:
- Single composite: less boilerplate, less flexible
- Nested: more flexible, more complex types

### Performance Considerations

**Compile-time overhead**:
- Each decorated method generates unique type
- Can increase compile time
- Binary size grows with instantiations

**Runtime overhead**:
- State fields add memory cost
- Decorator call checks (caching, validation) add cycles
- Usually negligible compared to method work

**Optimization**:
- Compiler inlines decorator calls in release builds
- State checks often optimized away
- Profile before optimizing

### Testing Strategies

**Test decorator behavior**:
```zig
test "decorator tracking" {
    var logged = WithLogging(Counter.add){};
    _ = logged.call(&counter, 5);
    try testing.expectEqual(1, logged.getCallCount());
}
```

**Test with different methods**:
```zig
test "decorator on various methods" {
    var logged_add = WithLogging(Counter.add){};
    var logged_mult = WithLogging(Calculator.multiply){};
    // Test both
}
```

**Test state isolation**:
```zig
test "independent instances" {
    var dec1 = WithLogging(method){};
    var dec2 = WithLogging(method){};

    dec1.call(...);
    try testing.expectEqual(1, dec1.getCallCount());
    try testing.expectEqual(0, dec2.getCallCount());
}
```

**Test edge cases**:
```zig
test "validation edge cases" {
    try testing.expectEqual(min_val, try validated.call(&inst, min_val));
    try testing.expectEqual(max_val, try validated.call(&inst, max_val));
    try testing.expectError(error.OutOfBounds, validated.call(&inst, min_val - 1));
}
```

### Common Use Cases

**Instrumentation**:
- Call counting
- Timing measurement
- Performance profiling

**Validation**:
- Bounds checking
- Type validation
- Precondition enforcement

**Caching**:
- Memoization
- Result caching
- Computation reuse

**Error handling**:
- Retry logic
- Fallback values
- Error tracking

**Access control**:
- Permission checking
- Rate limiting
- Quota enforcement

## See Also

- Recipe 9.1: Putting a Wrapper Around a Function
- Recipe 9.6: Defining Decorators as Part of a Struct
- Recipe 9.7: Defining Decorators as Structs
- Recipe 8.1: Changing the String Representation of Instances

Full compilable example: `code/03-advanced/09-metaprogramming/recipe_9_8.zig`
