## Problem

You need decorators with instance state, configuration, or multiple methods. You want decorators that can be configured at runtime, maintain mutable state across calls, or provide additional APIs beyond simple wrapping.

## Solution

Define decorators as struct types that wrap functionality, maintaining their own state and configuration as struct fields.

### Basic Decorator Struct

Create a decorator as a struct that wraps a function type:

```zig
{{#include ../../../code/03-advanced/09-metaprogramming/recipe_9_7.zig:basic_decorator_struct}}
```

The decorator is an instance with mutable state.

### Stateful Decorator

Track statistics across multiple calls:

```zig
fn CountingDecorator(comptime Func: type) type {
    return struct {
        const Self = @This();
        func: Func,
        call_count: u32 = 0,
        total_sum: i64 = 0,

        pub fn init(func: Func) Self {
            return .{ .func = func };
        }

        pub fn call(self: *Self, x: i32) i32 {
            self.call_count += 1;
            const result = self.func.call(x);
            self.total_sum += result;
            return result;
        }

        pub fn getCallCount(self: Self) u32 {
            return self.call_count;
        }

        pub fn getTotalSum(self: Self) i64 {
            return self.total_sum;
        }

        pub fn reset(self: *Self) void {
            self.call_count = 0;
            self.total_sum = 0;
        }
    };
}

// Usage
const simple = SimpleFunc{};
var counter = CountingDecorator(SimpleFunc).init(simple);

counter.call(5);         // 10
counter.call(10);        // 20

counter.getCallCount();  // 2
counter.getTotalSum();   // 30

counter.reset();
counter.getCallCount();  // 0
```

State persists across calls and can be reset.

### Configured Decorator

Pass configuration at initialization:

```zig
fn ValidatingDecorator(comptime Func: type, comptime Config: type) type {
    return struct {
        const Self = @This();
        func: Func,
        config: Config,

        pub fn init(func: Func, config: Config) Self {
            return .{ .func = func, .config = config };
        }

        pub fn call(self: *Self, x: i32) !i32 {
            if (x < self.config.min or x > self.config.max) {
                return error.OutOfBounds;
            }
            return self.func.call(x);
        }
    };
}

const BoundsConfig = struct {
    min: i32,
    max: i32,
};

// Usage
const simple = SimpleFunc{};
const config = BoundsConfig{ .min = 0, .max = 10 };
var validator = ValidatingDecorator(SimpleFunc, BoundsConfig).init(simple, config);

try validator.call(5);   // 10
try validator.call(15);  // error.OutOfBounds
```

Configuration stored in struct fields.

### Caching Decorator

Maintain cache state within the decorator:

```zig
fn CachingDecorator(comptime Func: type) type {
    return struct {
        const Self = @This();
        const CacheEntry = struct {
            input: i32,
            output: i32,
        };

        func: Func,
        cache: ?CacheEntry = null,

        pub fn init(func: Func) Self {
            return .{ .func = func };
        }

        pub fn call(self: *Self, x: i32) i32 {
            if (self.cache) |entry| {
                if (entry.input == x) {
                    return entry.output;
                }
            }

            const result = self.func.call(x);
            self.cache = CacheEntry{ .input = x, .output = result };
            return result;
        }

        pub fn clearCache(self: *Self) void {
            self.cache = null;
        }

        pub fn isCached(self: Self, x: i32) bool {
            if (self.cache) |entry| {
                return entry.input == x;
            }
            return false;
        }
    };
}

// Usage
const simple = SimpleFunc{};
var cached = CachingDecorator(SimpleFunc).init(simple);

cached.call(5);      // Calculates, caches
cached.call(5);      // Returns cached
cached.isCached(5);  // true

cached.clearCache();
cached.isCached(5);  // false
```

Cache managed as instance state.

### Composable Decorators

Chain decorator structs together:

```zig
fn LoggingDecorator(comptime Func: type) type {
    return struct {
        const Self = @This();
        func: Func,
        log_count: u32 = 0,

        pub fn init(func: Func) Self {
            return .{ .func = func };
        }

        pub fn call(self: *Self, x: i32) @TypeOf(self.func.call(0)) {
            self.log_count += 1;
            return self.func.call(x);
        }

        pub fn getLogCount(self: Self) u32 {
            return self.log_count;
        }
    };
}

fn ScalingDecorator(comptime Func: type, comptime factor: i32) type {
    return struct {
        const Self = @This();
        func: Func,

        pub fn init(func: Func) Self {
            return .{ .func = func };
        }

        pub fn call(self: *Self, x: i32) @TypeOf(self.func.call(0)) {
            return self.func.call(x) * factor;
        }
    };
}

// Usage - compose decorators
const simple = SimpleFunc{};
const logged = LoggingDecorator(SimpleFunc).init(simple);
var scaled = ScalingDecorator(LoggingDecorator(SimpleFunc), 3).init(logged);

scaled.call(5);  // (5 * 2) * 3 = 30
```

Each decorator wraps the previous one.

### Allocator-Based Decorator

Use allocators for dynamic storage:

```zig
fn HistoryDecorator(comptime Func: type) type {
    return struct {
        const Self = @This();
        func: Func,
        allocator: std.mem.Allocator,
        history: std.ArrayList(i32),

        pub fn init(allocator: std.mem.Allocator, func: Func) Self {
            return .{
                .func = func,
                .allocator = allocator,
                .history = .{ .items = &.{}, .capacity = 0 },
            };
        }

        pub fn deinit(self: *Self) void {
            self.history.deinit(self.allocator);
        }

        pub fn call(self: *Self, x: i32) !i32 {
            const result = self.func.call(x);
            try self.history.append(self.allocator, result);
            return result;
        }

        pub fn getHistory(self: Self) []const i32 {
            return self.history.items;
        }

        pub fn clearHistory(self: *Self) void {
            self.history.clearRetainingCapacity();
        }
    };
}

// Usage
const simple = SimpleFunc{};
var history = HistoryDecorator(SimpleFunc).init(allocator, simple);
defer history.deinit();

try history.call(5);   // Appends 10
try history.call(10);  // Appends 20

const hist = history.getHistory();  // [10, 20]
```

Decorators can manage allocated resources.

### Error Handling Decorator

Implement retry logic with error handling:

```zig
fn RetryDecorator(comptime Func: type, comptime max_attempts: u32) type {
    return struct {
        const Self = @This();
        func: Func,
        attempts: u32 = 0,

        pub fn init(func: Func) Self {
            return .{ .func = func };
        }

        pub fn call(self: *Self, x: i32) !i32 {
            var last_error: ?anyerror = null;
            var attempt: u32 = 0;

            while (attempt < max_attempts) : (attempt += 1) {
                self.attempts += 1;
                const result = self.func.call(x) catch |err| {
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

        pub fn getAttempts(self: Self) u32 {
            return self.attempts;
        }
    };
}

// Usage
var retry = RetryDecorator(FallibleFunc, 5).init(fallible);

const result = try retry.call(10);
retry.getAttempts();  // Number of attempts made
```

Retry attempts tracked in decorator state.

### Builder Pattern

Fluent API for decorator construction:

```zig
fn DecoratorBuilder(comptime Func: type) type {
    return struct {
        const Self = @This();

        func: Func,
        enable_logging: bool = false,
        enable_caching: bool = false,
        scale_factor: i32 = 1,

        pub fn init(func: Func) Self {
            return .{ .func = func };
        }

        pub fn withLogging(self: Self) Self {
            var new = self;
            new.enable_logging = true;
            return new;
        }

        pub fn withCaching(self: Self) Self {
            var new = self;
            new.enable_caching = true;
            return new;
        }

        pub fn withScale(self: Self, factor: i32) Self {
            var new = self;
            new.scale_factor = factor;
            return new;
        }

        pub fn build(self: Self) Built(Func) {
            return Built(Func){
                .func = self.func,
                .enable_logging = self.enable_logging,
                .enable_caching = self.enable_caching,
                .scale_factor = self.scale_factor,
            };
        }
    };
}

// Usage
const simple = SimpleFunc{};
var decorated = DecoratorBuilder(SimpleFunc).init(simple)
    .withLogging()
    .withScale(3)
    .build();

decorated.call(5);  // 30
```

Builder provides fluent configuration API.

### Conditional Decorator

Enable/disable behavior at runtime:

```zig
fn ConditionalDecorator(comptime Func: type) type {
    return struct {
        const Self = @This();

        func: Func,
        enabled: bool,
        multiplier: i32,

        pub fn init(func: Func, enabled: bool, multiplier: i32) Self {
            return .{
                .func = func,
                .enabled = enabled,
                .multiplier = multiplier,
            };
        }

        pub fn call(self: *Self, x: i32) i32 {
            const base = self.func.call(x);
            if (self.enabled) {
                return base * self.multiplier;
            }
            return base;
        }

        pub fn enable(self: *Self) void {
            self.enabled = true;
        }

        pub fn disable(self: *Self) void {
            self.enabled = false;
        }
    };
}

// Usage
var conditional = ConditionalDecorator(SimpleFunc).init(simple, true, 3);

conditional.call(5);  // 30 (enabled)

conditional.disable();
conditional.call(5);  // 10 (disabled)
```

Runtime control over decorator behavior.

### Method Chaining

Create fluent APIs with method chaining:

```zig
fn ChainableDecorator(comptime Func: type) type {
    return struct {
        const Self = @This();

        func: Func,
        offset: i32 = 0,
        multiplier: i32 = 1,
        invert: bool = false,

        pub fn init(func: Func) Self {
            return .{ .func = func };
        }

        pub fn addOffset(self: *Self, offset: i32) *Self {
            self.offset = offset;
            return self;
        }

        pub fn setMultiplier(self: *Self, multiplier: i32) *Self {
            self.multiplier = multiplier;
            return self;
        }

        pub fn setInvert(self: *Self, invert: bool) *Self {
            self.invert = invert;
            return self;
        }

        pub fn call(self: *Self, x: i32) i32 {
            var result = self.func.call(x);
            result = result + self.offset;
            result = result * self.multiplier;
            if (self.invert) {
                result = -result;
            }
            return result;
        }
    };
}

// Usage
var chainable = ChainableDecorator(SimpleFunc).init(simple);

_ = chainable.addOffset(5).setMultiplier(2);

chainable.call(5);  // ((5*2) + 5) * 2 = 30
```

Methods return `*Self` for chaining.

## Discussion

Decorator structs combine compile-time type generation with runtime instance state for flexible, powerful metaprogramming.

### When to Use Decorator Structs

**Use decorator structs when:**
- Need mutable state across calls
- Require runtime configuration
- Want multiple methods beyond call()
- Managing resources (allocators, files)
- Implementing stateful patterns (caching, counting)
- Building complex chained behaviors

**Use function decorators when:**
- Stateless transformations
- Pure compile-time decisions
- Simple wrapping without state
- Zero-overhead abstractions

### Struct vs Function Decorators

**Struct decorators**:
```zig
fn Decorator(comptime Func: type) type {
    return struct {
        func: Func,
        state: StateType,
        // Instance methods
    };
}
```

Instance-based, mutable state, resource management.

**Function decorators**:
```zig
fn Decorator(comptime func: anytype) type {
    return struct {
        pub fn call(args: anytype) ReturnType {
            // Stateless wrapper
        }
    };
}
```

Stateless, compile-time only, simpler.

### State Management

**Mutable state**:
```zig
return struct {
    var state: u32 = 0;  // Shared across all instances

    pub fn call(self: *Self, ...) {
        state += 1;  // Modified by all instances
    }
};
```

vs

```zig
return struct {
    state: u32 = 0,  // Per-instance

    pub fn call(self: *Self, ...) {
        self.state += 1;  // Modified per instance
    }
};
```

Choose based on sharing requirements.

**Reset capabilities**:
```zig
pub fn reset(self: *Self) void {
    self.state = initial_value;
}
```

Allow clearing state for reuse or testing.

**Thread safety**:

Struct fields are not inherently thread-safe:
```zig
state: std.atomic.Value(u32),  // For concurrent access
```

Use atomics for thread-safe state.

### Resource Management

**RAII pattern**:
```zig
pub fn init(allocator: Allocator, ...) Self {
    return .{ .resource = acquire(), ... };
}

pub fn deinit(self: *Self) void {
    release(self.resource);
}
```

Always provide `deinit` for cleanup.

**Usage with defer**:
```zig
var decorator = Decorator.init(allocator, func);
defer decorator.deinit();
```

Ensures cleanup even on error paths.

**Error handling in init**:
```zig
pub fn init(allocator: Allocator, ...) !Self {
    const resource = try acquire();
    errdefer release(resource);
    return .{ .resource = resource, ... };
}
```

Use `errdefer` for partial cleanup.

### Builder Pattern Benefits

**Fluent API**:
```zig
decorator
    .withLogging()
    .withCaching()
    .withScale(2)
    .build()
```

Readable, self-documenting configuration.

**Immutable builder**:
```zig
pub fn withOption(self: Self, value: T) Self {
    var new = self;
    new.option = value;
    return new;
}
```

Each method returns new instance.

**Validation at build**:
```zig
pub fn build(self: Self) !Decorated {
    if (self.min >= self.max) {
        return error.InvalidConfig;
    }
    return Decorated{ ... };
}
```

Catch configuration errors early.

### Composition Strategies

**Nested decorators**:
```zig
const logged = LoggingDecorator(SimpleFunc).init(simple);
const cached = CachingDecorator(LoggingDecorator(SimpleFunc)).init(logged);
```

Type composition at compile time.

**Uniform interface**:
```zig
pub fn call(self: *Self, x: i32) ReturnType
```

All decorators share same call signature.

**Type erasure**:
```zig
const AnyDecorator = struct {
    ptr: *anyopaque,
    callFn: *const fn(*anyopaque, i32) i32,

    pub fn call(self: *AnyDecorator, x: i32) i32 {
        return self.callFn(self.ptr, x);
    }
};
```

Hide concrete decorator types if needed.

### Performance Considerations

**Instance overhead**:
- Each decorator instance has memory cost
- State stored in struct fields
- Multiple decorators = multiple instances
- Consider stack vs heap allocation

**Indirection cost**:
```zig
self.func.call(x)  // One level of indirection
```

Minimal, often inlined by compiler.

**Cache effects**:
- Struct fields stored contiguously
- Good cache locality for hot paths
- Large structs may hurt performance

**Optimization**:
- Compiler can inline struct methods
- Release builds optimize away overhead
- Profile before optimizing

### Testing Strategies

**Test initialization**:
```zig
test "decorator init" {
    const decorator = Decorator.init(func);
    try testing.expectEqual(expected_initial_state, decorator.state);
}
```

**Test state changes**:
```zig
test "state mutation" {
    var decorator = Decorator.init(func);
    _ = decorator.call(5);
    try testing.expectEqual(1, decorator.call_count);
}
```

**Test resource cleanup**:
```zig
test "cleanup" {
    var decorator = Decorator.init(allocator, func);
    defer decorator.deinit();
    // Use decorator
    // defer ensures cleanup
}
```

**Test error paths**:
```zig
test "error handling" {
    var decorator = Decorator.init(func);
    try testing.expectError(error.Expected, decorator.call(invalid));
}
```

**Test composition**:
```zig
test "chained decorators" {
    const d1 = Dec1.init(func);
    var d2 = Dec2.init(d1);
    try testing.expectEqual(expected, d2.call(input));
}
```

### Common Patterns

**Statistics tracking**:
```zig
call_count: u32 = 0,
total_time: u64 = 0,
min_value: ?T = null,
max_value: ?T = null,
```

**Caching**:
```zig
cache: std.AutoHashMap(Input, Output),
cache_hits: u32 = 0,
cache_misses: u32 = 0,
```

**Rate limiting**:
```zig
last_call: i64 = 0,
calls_per_second: u32,
delay_ms: u64,
```

**Validation**:
```zig
min_value: T,
max_value: T,
validation_errors: u32 = 0,
```

**Logging**:
```zig
log_level: LogLevel,
log_count: u32 = 0,
last_input: ?Input = null,
```

### Memory Layout

**Struct size**:
```zig
test "decorator size" {
    try testing.expectEqual(
        @sizeOf(WrappedFunc) + @sizeOf(State),
        @sizeOf(Decorator(WrappedFunc))
    );
}
```

**Alignment**:
```zig
return struct {
    func: Func align(8),  // Control alignment
    state: State,
};
```

**Packed structs**:
```zig
return packed struct {
    // Minimize size for flags
    enabled: bool,
    cached: bool,
    logged: bool,
};
```

### Documentation

**Document struct fields**:
```zig
/// Number of times call() has been invoked
call_count: u32 = 0,
/// Cumulative sum of all results
total_sum: i64 = 0,
```

**Document methods**:
```zig
/// Calls the wrapped function and updates statistics
/// Returns the result of the wrapped function
pub fn call(self: *Self, x: i32) i32
```

**Document initialization**:
```zig
/// Creates a new decorator instance
/// The decorator takes ownership of `func`
pub fn init(func: Func) Self
```

**Document cleanup**:
```zig
/// Releases all resources held by this decorator
/// Must be called when decorator is no longer needed
pub fn deinit(self: *Self) void
```

## See Also

- Recipe 9.1: Putting a Wrapper Around a Function
- Recipe 9.6: Defining Decorators as Part of a Struct
- Recipe 9.8: Applying Decorators to Struct and Static Methods
- Recipe 8.10: Using Lazily Computed Properties

Full compilable example: `code/03-advanced/09-metaprogramming/recipe_9_7.zig`
