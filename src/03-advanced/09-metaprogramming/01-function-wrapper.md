## Problem

You want to add cross-cutting behavior to functions (logging, timing, caching, validation) without modifying their implementations. You need function wrappers or decorators that work at compile time with zero runtime overhead.

## Solution

Use Zig's `comptime` to create functions that take other functions as parameters and return wrapped versions. The wrapper can execute code before, after, or around the original function.

### Basic Wrapper

Create a simple logging wrapper using comptime:

```zig
{{#include ../../../code/03-advanced/09-metaprogramming/recipe_9_1.zig:basic_wrapper}}
```

The wrapper function is generated at compile time.

### Timing Wrapper

Measure execution time of any function:

```zig
fn withTiming(comptime func: anytype) fn (i32) i32 {
    return struct {
        fn wrapper(x: i32) i32 {
            const start = std.time.nanoTimestamp();
            const result = func(x);
            const end = std.time.nanoTimestamp();
            const duration = end - start;
            std.debug.print("Execution time: {d}ns\n", .{duration});
            return result;
        }
    }.wrapper;
}

fn slowFunction(x: i32) i32 {
    var sum: i32 = 0;
    var i: i32 = 0;
    while (i < x) : (i += 1) {
        sum += i;
    }
    return sum;
}

// Usage
const timed = withTiming(slowFunction);
const result = timed(100);  // Prints execution time
```

Timing is added with zero overhead when disabled.

### Error Handling Wrapper

Add error handling to functions:

```zig
fn withErrorHandling(comptime func: anytype) fn (i32) anyerror!i32 {
    return struct {
        fn wrapper(x: i32) anyerror!i32 {
            if (x < 0) {
                std.debug.print("Warning: negative input {d}\n", .{x});
            }
            return func(x);
        }
    }.wrapper;
}

fn safeDivide(x: i32) anyerror!i32 {
    if (x == 0) return error.DivisionByZero;
    return @divTrunc(100, x);
}

// Usage
const wrapped = withErrorHandling(safeDivide);
const result = try wrapped(10);  // Returns 10
```

The wrapper can validate inputs or handle errors.

### Generic Wrapper

Create wrappers that work with any function signature:

```zig
fn GenericWrapper(comptime func: anytype) type {
    const FuncInfo = @typeInfo(@TypeOf(func));
    const ReturnType = switch (FuncInfo) {
        .@"fn" => |f| f.return_type.?,
        else => @compileError("Expected function"),
    };

    return struct {
        call_count: usize = 0,

        pub fn call(self: *@This(), args: anytype) ReturnType {
            self.call_count += 1;
            return @call(.auto, func, args);
        }

        pub fn getCallCount(self: *const @This()) usize {
            return self.call_count;
        }
    };
}

fn add(a: i32, b: i32) i32 {
    return a + b;
}

// Usage
const Wrapper = GenericWrapper(add);
var wrapper = Wrapper{};
const r1 = wrapper.call(.{ 5, 3 });  // 8
const r2 = wrapper.call(.{ 10, 20 }); // 30
// wrapper.getCallCount() == 2
```

Generic wrappers adapt to any function signature using `@typeInfo`.

### Caching Wrapper

Memoize expensive function calls:

```zig
fn WithCache(comptime func: anytype) type {
    return struct {
        cache: ?i32 = null,
        cache_key: ?i32 = null,

        pub fn call(self: *@This(), x: i32) i32 {
            if (self.cache_key) |key| {
                if (key == x) {
                    return self.cache.?;
                }
            }

            const result = func(x);
            self.cache = result;
            self.cache_key = x;
            return result;
        }
    };
}

fn expensive(x: i32) i32 {
    var result: i32 = 0;
    var i: i32 = 0;
    while (i < x) : (i += 1) {
        result += i * i;
    }
    return result;
}

// Usage
const CachedFunc = WithCache(expensive);
var cached = CachedFunc{};
const r1 = cached.call(10);  // Computes
const r2 = cached.call(10);  // Returns cached value
```

Caching avoids redundant expensive computations.

### Validation Wrapper

Add input validation with compile-time bounds:

```zig
fn WithValidation(comptime func: anytype, comptime min: i32, comptime max: i32) type {
    return struct {
        pub fn call(x: i32) !i32 {
            if (x < min or x > max) {
                return error.OutOfRange;
            }
            return func(x);
        }
    };
}

fn processValue(x: i32) i32 {
    return x * x;
}

// Usage
const ValidatedFunc = WithValidation(processValue, 0, 100);
const r1 = try ValidatedFunc.call(50);   // OK: 2500
const r2 = ValidatedFunc.call(150);      // Error: OutOfRange
```

Validation bounds are checked at compile time.

### Retry Wrapper

Automatically retry failed operations:

```zig
fn WithRetry(comptime func: anytype, comptime max_retries: u32) type {
    return struct {
        pub fn call(x: i32) !i32 {
            var attempts: u32 = 0;
            var last_error: ?anyerror = null;

            while (attempts < max_retries) : (attempts += 1) {
                const result = func(x) catch |err| {
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
    };
}

fn unreliable(x: i32) !i32 {
    // Might fail temporarily
    if (shouldFail()) {
        return error.Temporary;
    }
    return x * 2;
}

// Usage
const RetriedFunc = WithRetry(unreliable, 5);
const result = try RetriedFunc.call(10);  // Retries up to 5 times
```

Retry logic is baked in at compile time.

### Chaining Wrappers

Compose multiple wrappers together:

```zig
fn compose(comptime f: anytype, comptime g: anytype) fn (i32) i32 {
    return struct {
        fn wrapper(x: i32) i32 {
            return f(g(x));
        }
    }.wrapper;
}

fn increment(x: i32) i32 {
    return x + 1;
}

fn triple(x: i32) i32 {
    return x * 3;
}

// Usage
const composed = compose(triple, increment);
const result = composed(5);  // (5 + 1) * 3 = 18
```

Function composition creates pipelines at compile time.

### Stateful Wrapper

Maintain state across wrapper invocations:

```zig
fn WithState(comptime func: anytype) type {
    return struct {
        total_calls: usize = 0,
        total_sum: i32 = 0,

        pub fn call(self: *@This(), x: i32) i32 {
            self.total_calls += 1;
            const result = func(x);
            self.total_sum += result;
            return result;
        }

        pub fn getAverage(self: *const @This()) i32 {
            if (self.total_calls == 0) return 0;
            return @divTrunc(self.total_sum, @as(i32, @intCast(self.total_calls)));
        }
    };
}

// Usage
const StatefulFunc = WithState(identity);
var stateful = StatefulFunc{};
_ = stateful.call(10);
_ = stateful.call(20);
_ = stateful.call(30);
// stateful.getAverage() == 20
```

Wrappers can accumulate statistics or history.

### Conditional Wrapper

Enable or disable wrappers at compile time:

```zig
fn ConditionalWrapper(comptime func: anytype, comptime enable: bool) type {
    if (enable) {
        return struct {
            pub fn call(x: i32) i32 {
                std.debug.print("Enabled wrapper\n", .{});
                return func(x);
            }
        };
    } else {
        return struct {
            pub fn call(x: i32) i32 {
                return func(x);
            }
        };
    }
}

// Usage
const EnabledWrapper = ConditionalWrapper(simpleFunc, true);
const DisabledWrapper = ConditionalWrapper(simpleFunc, false);
```

Debug wrappers can be completely eliminated in release builds.

## Discussion

Function wrappers in Zig use compile-time metaprogramming to add behavior without runtime overhead.

### How Comptime Wrappers Work

**Compile-time function generation**:
```zig
fn wrapper(comptime func: anytype) fn (i32) i32 {
    return struct {
        fn inner(x: i32) i32 {
            // Wrapper logic
            return func(x);  // Call original
        }
    }.inner;
}
```

**Pattern breakdown**:
1. Accept function as `comptime` parameter
2. Return new function (or type with callable methods)
3. Wrapper calls original function
4. All resolved at compile time

**Anonymous struct trick**:
```zig
return struct {
    fn wrapper(...) ... {
        // Implementation
    }
}.wrapper;
```

Creates closure-like behavior without heap allocation.

### Wrapper Patterns

**Simple function wrapper**:
```zig
fn wrap(comptime func: anytype) fn (T) R {
    return struct {
        fn inner(arg: T) R {
            // before
            const result = func(arg);
            // after
            return result;
        }
    }.inner;
}
```

Returns function directly.

**Stateful type wrapper**:
```zig
fn Wrap(comptime func: anytype) type {
    return struct {
        state: StateType,

        pub fn call(self: *@This(), arg: T) R {
            // Use self.state
            return func(arg);
        }
    };
}
```

Returns type with state and methods.

**Generic wrapper with any signature**:
```zig
fn Wrap(comptime func: anytype) type {
    return struct {
        pub fn call(self: *@This(), args: anytype) ReturnType {
            return @call(.auto, func, args);
        }
    };
}
```

Uses `anytype` for arguments and `@call` for invocation.

### Type Introspection

**Extract function info**:
```zig
const FuncInfo = @typeInfo(@TypeOf(func));
const return_type = switch (FuncInfo) {
    .@"fn" => |f| f.return_type.?,
    else => @compileError("Not a function"),
};
```

**Check function properties**:
```zig
if (FuncInfo.@"fn".is_generic) {
    // Handle generic functions
}
if (FuncInfo.@"fn".return_type == null) {
    // Void return
}
```

Use `@typeInfo` to adapt to function signatures.

### Performance Characteristics

**Zero runtime overhead**:
- All wrapper logic compiled away
- Inlined like hand-written code
- No function pointer indirection
- No heap allocations

**Compile-time cost**:
- More complex wrappers increase compile time
- Each wrapper instantiation generates code
- Trade compile time for runtime performance

**Code size**:
- Generic wrappers instantiated per function
- Can increase binary size
- Mitigated by compiler optimizations

### Design Guidelines

**When to use wrappers**:
- Cross-cutting concerns (logging, timing, caching)
- Aspect-oriented behavior
- Policy enforcement
- Testing and debugging hooks

**Naming conventions**:
```zig
fn withLogging(...)     // Returns function
fn WithCache(...)       // Returns type
fn Validated(...)       // Adjective describing wrapper
```

**Keep wrappers simple**:
- Single responsibility
- Minimal state
- Clear semantics
- Composable

**Document behavior**:
```zig
/// Wraps a function to add retry logic with exponential backoff.
/// Returns a new type with a `call` method that retries up to max_retries times.
fn WithRetry(comptime func: anytype, comptime max_retries: u32) type
```

### Common Wrapper Use Cases

**Instrumentation**:
- Logging function calls
- Measuring execution time
- Counting invocations
- Profiling hot paths

**Resilience**:
- Retry logic
- Fallback values
- Error recovery
- Circuit breakers

**Optimization**:
- Result caching/memoization
- Lazy evaluation
- Batch processing
- Resource pooling

**Validation**:
- Input bounds checking
- Precondition enforcement
- Type constraints
- Authorization checks

### Wrapper Composition

**Sequential composition**:
```zig
const f = withLogging(withTiming(withCache(original)));
```

Wrappers applied inside-out.

**Functional composition**:
```zig
fn pipe(comptime f: anytype, comptime g: anytype) ... {
    return compose(g, f);  // g(f(x))
}
```

Create composition utilities.

**Conditional stacking**:
```zig
const func = if (debug)
    withLogging(withTiming(original))
else
    original;
```

Enable wrappers based on conditions.

### Limitations and Gotchas

**Type signatures must match**:
- Wrapper return type must match wrapped function
- Or use `anytype` for flexibility
- Can't change fundamental signature

**State requires type wrappers**:
```zig
// Can't maintain state with function wrapper
fn wrap(...) fn (...) {...}  // Stateless

// Need type wrapper for state
fn Wrap(...) type {...}      // Stateful
```

**Comptime function parameter**:
```zig
// Must be comptime
fn wrap(comptime func: anytype) ... {
    // func is known at compile time
}
```

Not for runtime function pointers.

**Generic wrappers need care**:
```zig
// Works for specific signature
fn wrap(comptime func: fn (i32) i32) fn (i32) i32

// Generic requires type introspection
fn Wrap(comptime func: anytype) type {
    // Use @typeInfo and @call
}
```

### Testing Wrappers

**Test wrapper behavior**:
```zig
test "wrapper adds logging" {
    var output = std.ArrayList(u8).init(allocator);
    defer output.deinit();

    const wrapped = withLogging(double);
    _ = wrapped(5);

    // Verify logging occurred
    try testing.expect(output.items.len > 0);
}
```

**Test state accumulation**:
```zig
test "wrapper tracks calls" {
    const Wrapper = GenericWrapper(add);
    var wrapper = Wrapper{};

    _ = wrapper.call(.{1, 2});
    _ = wrapper.call(.{3, 4});

    try testing.expectEqual(@as(usize, 2), wrapper.getCallCount());
}
```

**Test composition**:
```zig
test "wrappers compose" {
    const f = compose(triple, increment);
    const result = f(5);
    try testing.expectEqual(@as(i32, 18), result);
}
```

### Comparison with Other Languages

**Python decorators**:
```python
@with_logging
def double(x):
    return x * 2
```

Zig equivalent:
```zig
const double_wrapped = withLogging(double);
```

**Rust**:
```rust
// No direct equivalent, use macros or traits
```

**C++ templates**:
```cpp
template<typename F>
auto withLogging(F func) {
    return [func](auto x) {
        // wrapper logic
        return func(x);
    };
}
```

Zig's approach is simpler and more explicit.

## See Also

- Recipe 9.2: Preserving Function Metadata When Writing Decorators
- Recipe 9.4: Defining a Decorator That Takes Arguments
- Recipe 9.11: Using comptime to Control Instance Creation
- Recipe 8.18: Extending Classes with Mixins

Full compilable example: `code/03-advanced/09-metaprogramming/recipe_9_1.zig`
