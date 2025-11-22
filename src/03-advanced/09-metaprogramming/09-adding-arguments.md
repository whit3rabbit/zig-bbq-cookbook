## Problem

You want to simplify function calls by injecting common arguments like allocators, configuration objects, loggers, or contexts. You need to avoid repetitive parameter passing while maintaining type safety and zero runtime overhead.

## Solution

Create decorators that prepend, append, or inject arguments into wrapped functions at compile time using tuple concatenation.

### Inject Allocator

Automatically provide an allocator to functions:

```zig
{{#include ../../../code/03-advanced/09-metaprogramming/recipe_9_9.zig:inject_allocator}}
```

Allocator injected automatically, callers don't pass it.

### Inject Context

Provide configuration or context objects:

```zig
fn WithContext(comptime func: anytype, comptime Context: type, comptime context: Context) type {
    return struct {
        const Self = @This();

        pub fn call(args: anytype) @TypeOf(@call(.auto, func, .{context} ++ args)) {
            return @call(.auto, func, .{context} ++ args);
        }
    };
}

const Config = struct {
    multiplier: i32,
    offset: i32,
};

fn transform(config: Config, x: i32) i32 {
    return (x * config.multiplier) + config.offset;
}

// Usage
const config = Config{ .multiplier = 2, .offset = 5 };
const Configured = WithContext(transform, Config, config);

Configured.call(.{10});  // 25: (10 * 2) + 5
```

Configuration injected at compile time.

### Prepend Arguments

Add arguments at the beginning:

```zig
fn PrependArgs(comptime func: anytype, comptime prepend: anytype) type {
    return struct {
        const Self = @This();

        pub fn call(args: anytype) @TypeOf(@call(.auto, func, prepend ++ args)) {
            return @call(.auto, func, prepend ++ args);
        }
    };
}

fn multiply(a: i32, b: i32) i32 {
    return a * b;
}

// Usage
const TimesTwo = PrependArgs(multiply, .{2});

TimesTwo.call(.{5});  // 10: 2 * 5
```

Partial application of first arguments.

### Append Arguments

Add arguments at the end:

```zig
fn AppendArgs(comptime func: anytype, comptime append: anytype) type {
    return struct {
        const Self = @This();

        pub fn call(args: anytype) @TypeOf(@call(.auto, func, args ++ append)) {
            return @call(.auto, func, args ++ append);
        }
    };
}

fn divide(a: i32, b: i32) i32 {
    return @divTrunc(a, b);
}

// Usage
const DivideByTwo = AppendArgs(divide, .{2});

DivideByTwo.call(.{10});  // 5: 10 / 2
```

Partial application of last arguments.

### Inject Default Arguments

Provide default values for trailing parameters:

```zig
fn WithDefaults(comptime func: anytype, comptime defaults: anytype) type {
    return struct {
        const Self = @This();

        pub fn call(provided: anytype) @TypeOf(@call(.auto, func, provided ++ defaults)) {
            return @call(.auto, func, provided ++ defaults);
        }
    };
}

fn configuredAdd(x: i32, multiplier: i32, offset: i32) i32 {
    return (x * multiplier) + offset;
}

// Usage
const DefaultConfig = WithDefaults(configuredAdd, .{ 3, 10 });

DefaultConfig.call(.{5});  // 25: (5 * 3) + 10
```

Defaults applied automatically.

### Inject Logger

Provide logging infrastructure:

```zig
fn WithLogger(comptime func: anytype) type {
    return struct {
        const Self = @This();
        const Logger = struct {
            log_count: *u32,

            pub fn log(self: Logger, comptime fmt: []const u8, args: anytype) void {
                _ = fmt;
                _ = args;
                self.log_count.* += 1;
            }
        };

        log_count: u32 = 0,

        pub fn call(self: *Self, args: anytype) @TypeOf(@call(.auto, func, .{Logger{ .log_count = &self.log_count }} ++ args)) {
            const logger = Logger{ .log_count = &self.log_count };
            return @call(.auto, func, .{logger} ++ args);
        }

        pub fn getLogCount(self: Self) u32 {
            return self.log_count;
        }
    };
}

fn processWithLog(logger: anytype, x: i32) i32 {
    logger.log("Processing {d}", .{x});
    return x * 2;
}

// Usage
var decorated = WithLogger(processWithLog){};

decorated.call(.{5});       // 10
decorated.getLogCount();    // 1
```

Logger injected with state tracking.

### Inject Timestamp

Provide timing information:

```zig
fn WithTimestamp(comptime func: anytype) type {
    return struct {
        const Self = @This();
        current_time: u64 = 0,

        pub fn call(self: *Self, args: anytype) @TypeOf(@call(.auto, func, .{self.current_time} ++ args)) {
            self.current_time += 1;
            return @call(.auto, func, .{self.current_time} ++ args);
        }

        pub fn getCurrentTime(self: Self) u64 {
            return self.current_time;
        }
    };
}

fn processWithTime(timestamp: u64, x: i32) i32 {
    _ = timestamp;
    return x * 2;
}

// Usage
var decorated = WithTimestamp(processWithTime){};

decorated.call(.{5});
decorated.call(.{10});

decorated.getCurrentTime();  // 2
```

Monotonic timestamp injection.

### Inject Error Handler

Provide error handling infrastructure:

```zig
fn WithErrorHandler(comptime func: anytype) type {
    return struct {
        const Self = @This();
        const ErrorHandler = struct {
            error_count: *u32,

            pub fn handleError(self: ErrorHandler, _: anyerror) void {
                self.error_count.* += 1;
            }
        };

        error_count: u32 = 0,

        pub fn call(self: *Self, args: anytype) @TypeOf(@call(.auto, func, .{ErrorHandler{ .error_count = &self.error_count }} ++ args)) {
            const handler = ErrorHandler{ .error_count = &self.error_count };
            return @call(.auto, func, .{handler} ++ args);
        }

        pub fn getErrorCount(self: Self) u32 {
            return self.error_count;
        }
    };
}

fn processWithErrorHandler(handler: anytype, x: i32) !i32 {
    if (x < 0) {
        handler.handleError(error.NegativeValue);
        return error.NegativeValue;
    }
    return x * 2;
}

// Usage
var decorated = WithErrorHandler(processWithErrorHandler){};

try decorated.call(.{5});      // 10
try decorated.call(.{-5});     // error.NegativeValue

decorated.getErrorCount();      // 1
```

Error tracking built into injected handler.

### Inject Metrics

Provide metrics collection:

```zig
fn WithMetrics(comptime func: anytype) type {
    return struct {
        const Self = @This();
        const Metrics = struct {
            calls: *u32,
            total: *i64,

            pub fn record(self: Metrics, value: i32) void {
                self.calls.* += 1;
                self.total.* += value;
            }
        };

        calls: u32 = 0,
        total: i64 = 0,

        pub fn call(self: *Self, args: anytype) @TypeOf(@call(.auto, func, .{Metrics{ .calls = &self.calls, .total = &self.total }} ++ args)) {
            const metrics = Metrics{ .calls = &self.calls, .total = &self.total };
            return @call(.auto, func, .{metrics} ++ args);
        }

        pub fn getAverage(self: Self) i64 {
            if (self.calls == 0) return 0;
            return @divTrunc(self.total, self.calls);
        }
    };
}

fn processWithMetrics(metrics: anytype, x: i32) i32 {
    const result = x * 2;
    metrics.record(result);
    return result;
}

// Usage
var decorated = WithMetrics(processWithMetrics){};

decorated.call(.{5});
decorated.call(.{10});
decorated.call(.{15});

decorated.getAverage();  // 20: (10 + 20 + 30) / 3
```

Automatic metrics collection.

### Inject Runtime Context

Provide runtime-configurable context:

```zig
fn WithRuntimeContext(comptime func: anytype, comptime Context: type) type {
    return struct {
        const Self = @This();
        context: Context,

        pub fn init(context: Context) Self {
            return .{ .context = context };
        }

        pub fn call(self: Self, args: anytype) @TypeOf(@call(.auto, func, .{self.context} ++ args)) {
            return @call(.auto, func, .{self.context} ++ args);
        }
    };
}

const RuntimeConfig = struct {
    scale: i32,
    enabled: bool,
};

fn processWithRuntimeContext(config: RuntimeConfig, x: i32) i32 {
    if (!config.enabled) return x;
    return x * config.scale;
}

// Usage
const config1 = RuntimeConfig{ .scale = 3, .enabled = true };
const decorated1 = WithRuntimeContext(processWithRuntimeContext, RuntimeConfig).init(config1);

decorated1.call(.{5});  // 15

const config2 = RuntimeConfig{ .scale = 3, .enabled = false };
const decorated2 = WithRuntimeContext(processWithRuntimeContext, RuntimeConfig).init(config2);

decorated2.call(.{5});  // 5
```

Different instances with different configurations.

### Inject Multiple Arguments

Inject several arguments at once:

```zig
fn InjectMultiple(comptime func: anytype, comptime inject: anytype) type {
    return struct {
        const Self = @This();

        pub fn call(args: anytype) @TypeOf(@call(.auto, func, inject ++ args)) {
            return @call(.auto, func, inject ++ args);
        }
    };
}

fn complexFunc(a: i32, b: i32, c: i32, d: i32) i32 {
    return a + b + c + d;
}

// Usage
const Injected = InjectMultiple(complexFunc, .{ 1, 2 });

Injected.call(.{ 3, 4 });  // 10: 1 + 2 + 3 + 4
```

Multiple arguments injected together.

### Conditional Injection

Inject arguments based on compile-time condition:

```zig
fn ConditionalInject(comptime func: anytype, comptime condition: bool, comptime inject: anytype) type {
    if (condition) {
        return struct {
            pub fn call(args: anytype) @TypeOf(@call(.auto, func, inject ++ args)) {
                return @call(.auto, func, inject ++ args);
            }
        };
    } else {
        return struct {
            pub fn call(args: anytype) @TypeOf(@call(.auto, func, args)) {
                return @call(.auto, func, args);
            }
        };
    }
}

fn add(a: i32, b: i32) i32 {
    return a + b;
}

// Usage
const WithInjection = ConditionalInject(add, true, .{10});
WithInjection.call(.{5});  // 15: 10 + 5

const WithoutInjection = ConditionalInject(add, false, .{10});
WithoutInjection.call(.{ 5, 3 });  // 8: 5 + 3
```

Compile-time conditional argument injection.

## Discussion

Argument injection decorators provide dependency injection, simplify APIs, and eliminate repetitive parameter passing.

### Tuple Concatenation

**Core mechanism**:
```zig
.{allocator} ++ args  // Prepend allocator to args tuple
args ++ .{default}    // Append default to args tuple
```

Tuples concatenated at compile time, zero runtime overhead.

**Type safety**:
```zig
@TypeOf(@call(.auto, func, prepend ++ args))
```

Return type computed from actual call signature.

**Flexibility**:
```zig
inject ++ args         // Prepend
args ++ inject         // Append
prefix ++ args ++ suffix  // Both
```

### Compile-Time vs Runtime Injection

**Compile-time injection**:
```zig
fn WithAllocator(comptime func: anytype, comptime allocator: Allocator) type
```

Allocator baked into type, no storage cost.

**Runtime injection**:
```zig
return struct {
    context: Context,  // Stored in decorator instance

    pub fn call(self: Self, args: anytype) ... {
        return @call(.auto, func, .{self.context} ++ args);
    }
};
```

Context can vary per instance.

**Trade-offs**:
- Compile-time: Zero overhead, but fixed at compile time
- Runtime: Flexible configuration, small storage cost

### Dependency Injection Patterns

**Allocator injection**:

Common in Zig APIs. Decorators eliminate repetitive passing:
```zig
// Without decorator
const slice1 = try createSlice(allocator, 5);
const slice2 = try createSlice(allocator, 10);

// With decorator
const Create = WithAllocator(createSlice, allocator);
const slice1 = try Create.call(.{5});
const slice2 = try Create.call(.{10});
```

**Configuration injection**:

Centralize configuration:
```zig
const config = Config{ .timeout = 100, .retries = 3 };
const Process = WithContext(process, Config, config);

Process.call(.{data1});
Process.call(.{data2});
```

All calls use same configuration.

**Infrastructure injection**:

Loggers, metrics, error handlers:
```zig
var logged = WithLogger(process){};
logged.call(.{x});  // Logger automatically provided
```

Infrastructure transparent to caller.

### Partial Application

**Currying in Zig**:

Decorators enable partial application:
```zig
fn add(a: i32, b: i32) i32 {
    return a + b;
}

const Add5 = PrependArgs(add, .{5});
Add5.call(.{10});  // 15
```

Bind some arguments, defer others.

**Use cases**:
- Factory functions
- Specialized processors
- Event handlers with context

### State Management

**Stateless injection**:
```zig
fn WithAllocator(...) type {
    return struct {
        pub fn call(args: anytype) ... {
            return @call(.auto, func, .{allocator} ++ args);
        }
    };
}
```

No state, pure compile-time.

**Stateful injection**:
```zig
fn WithLogger(...) type {
    return struct {
        log_count: u32 = 0,  // State

        pub fn call(self: *Self, args: anytype) ... {
            const logger = Logger{ .log_count = &self.log_count };
            return @call(.auto, func, .{logger} ++ args);
        }
    };
}
```

Decorator maintains state, shared with injected object.

### Injected Object Design

**Simple values**:
```zig
.{allocator} ++ args
.{config} ++ args
```

Directly inject POD types.

**Complex objects**:
```zig
const Logger = struct {
    count: *u32,
    pub fn log(self: Logger, ...) void { ... }
};

const logger = Logger{ .count = &self.log_count };
.{logger} ++ args
```

Inject structs with methods, maintain references to decorator state.

**Interface pattern**:

Injected objects can be `anytype`, allowing duck typing:
```zig
fn process(logger: anytype, x: i32) i32 {
    logger.log("Processing", .{});  // Any type with log() works
    return x * 2;
}
```

### Performance Characteristics

**Zero-cost abstraction**:
- Tuple concatenation at compile time
- No runtime allocation
- Fully inlined
- Same performance as manual passing

**Binary size**:
- Each injected configuration creates new type
- Can increase code size
- Usually negligible

**Compile time**:
- Argument injection is fast
- Complex injected types increase compile time slightly

### Testing Strategies

**Test with different injections**:
```zig
test "with test allocator" {
    const Create = WithAllocator(createSlice, testing.allocator);
    const slice = try Create.call(.{5});
    defer testing.allocator.free(slice);
}

test "with failing allocator" {
    const Create = WithAllocator(createSlice, testing.failing_allocator);
    try testing.expectError(error.OutOfMemory, Create.call(.{5}));
}
```

**Test state tracking**:
```zig
test "logger counts calls" {
    var logged = WithLogger(process){};
    _ = logged.call(.{5});
    _ = logged.call(.{10});
    try testing.expectEqual(2, logged.getLogCount());
}
```

**Test runtime configuration**:
```zig
test "different contexts" {
    const ctx1 = Config{ .enabled = true };
    const dec1 = WithRuntimeContext(process, Config).init(ctx1);

    const ctx2 = Config{ .enabled = false };
    const dec2 = WithRuntimeContext(process, Config).init(ctx2);

    // Test different behaviors
}
```

### Common Use Cases

**Allocator passing**:

Eliminate repetitive allocator arguments:
```zig
const WithAlloc = WithAllocator(func, allocator);
```

**Configuration management**:

Centralize configuration:
```zig
const Configured = WithContext(func, Config, config);
```

**Observability**:

Inject logging, metrics, tracing:
```zig
var logged = WithLogger(func){};
var metriced = WithMetrics(func){};
```

**Error handling**:

Inject error handlers, recovery logic:
```zig
var handled = WithErrorHandler(func){};
```

**Testing**:

Inject test doubles, mocks:
```zig
const WithMock = WithContext(func, MockDB, mock_db);
```

### Design Patterns

**Builder with injection**:
```zig
const builder = FunctionBuilder.init(func)
    .withAllocator(alloc)
    .withLogger()
    .build();
```

**Factory with defaults**:
```zig
fn createProcessor(config: Config) ProcessorType {
    return WithDefaults(rawProcessor, .{ config.default1, config.default2 });
}
```

**Adapter pattern**:
```zig
// Adapt function expecting (allocator, x, y) to take just (x, y)
const Adapted = WithAllocator(func, allocator);
```

### Limitations

**Cannot remove arguments**:

Only prepend/append, not remove or reorder:
```zig
// Can't turn fn(a, b, c) into fn(a, c)
```

**Type must match**:

Injected arguments must match function signature:
```zig
fn process(allocator: Allocator, x: i32) !T
const Dec = WithAllocator(process, allocator);  // OK
const Bad = WithAllocator(process, 42);  // Type error: expects Allocator
```

**Fixed arity**:

Can't make variadic functions:
```zig
// Can't inject different number of args based on runtime condition
```

## See Also

- Recipe 9.1: Putting a Wrapper Around a Function
- Recipe 9.4: Defining a Decorator That Takes Arguments
- Recipe 9.7: Defining Decorators as Structs
- Recipe 0.12: Understanding Allocators

Full compilable example: `code/03-advanced/09-metaprogramming/recipe_9_9.zig`
