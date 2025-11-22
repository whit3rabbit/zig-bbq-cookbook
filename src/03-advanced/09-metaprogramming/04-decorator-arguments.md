## Problem

You need decorators that behave differently based on configuration. You want to parameterize wrappers with values, types, callbacks, or options that control how they modify functions.

## Solution

Pass additional comptime parameters to decorator functions before the wrapped function. These parameters become part of the generated type and can control wrapper behavior, provide defaults, or configure validation.

### Basic Parameterized Decorator

Create decorators that take simple value parameters:

```zig
{{#include ../../../code/03-advanced/09-metaprogramming/recipe_9_4.zig:basic_parameterized}}
```

The multiplier parameter customizes each wrapper instance.

### Validation Decorator

Use parameters to configure validation bounds:

```zig
fn WithBounds(comptime func: anytype, comptime min: i32, comptime max: i32) type {
    return struct {
        pub fn call(x: i32) !i32 {
            if (x < min or x > max) {
                return error.OutOfBounds;
            }
            return func(x);
        }

        pub fn getMin() i32 {
            return min;
        }

        pub fn getMax() i32 {
            return max;
        }
    };
}

fn square(x: i32) i32 {
    return x * x;
}

// Usage
const BoundedSquare = WithBounds(square, 0, 10);
const result = try BoundedSquare.call(5);  // 25
const err = BoundedSquare.call(15);  // error.OutOfBounds
```

Bounds are enforced at runtime, configured at compile time.

### Retry Decorator

Configure retry behavior with parameters:

```zig
fn WithRetry(comptime func: anytype, comptime max_attempts: u32, comptime delay_ms: u64) type {
    return struct {
        pub fn call(x: i32) !i32 {
            var attempts: u32 = 0;
            var last_error: ?anyerror = null;

            while (attempts < max_attempts) : (attempts += 1) {
                const result = func(x) catch |err| {
                    last_error = err;
                    // In real code, would sleep for delay_ms milliseconds
                    continue;
                };
                return result;
            }

            if (last_error) |err| {
                return err;
            }
            return error.MaxRetriesExceeded;
        }

        pub fn getMaxAttempts() u32 {
            return max_attempts;
        }

        pub fn getDelay() u64 {
            return delay_ms;
        }
    };
}

// Usage
const Retried = WithRetry(unreliable, 5, 100);
const result = try Retried.call(10);
// Retried.getMaxAttempts() == 5
// Retried.getDelay() == 100
```

Retry configuration is baked into the type.

### String Parameter Decorator

Use string parameters for formatting:

```zig
fn WithPrefixSuffix(comptime func: anytype, comptime prefix: []const u8, comptime suffix: []const u8) type {
    return struct {
        pub fn call(allocator: std.mem.Allocator, x: i32) ![]u8 {
            const result = try func(allocator, x);
            defer allocator.free(result);

            const full = try std.fmt.allocPrint(
                allocator,
                "{s}{s}{s}",
                .{ prefix, result, suffix },
            );
            return full;
        }
    };
}

fn formatNumber(allocator: std.mem.Allocator, x: i32) ![]u8 {
    return try std.fmt.allocPrint(allocator, "{d}", .{x});
}

// Usage
const Bracketed = WithPrefixSuffix(formatNumber, "[", "]");
const result = try Bracketed.call(allocator, 42);
defer allocator.free(result);
// result == "[42]"
```

String literals become compile-time constants.

### Type Parameter Decorator

Accept type parameters for generic behavior:

```zig
fn WithDefault(comptime func: anytype, comptime T: type, comptime default: T) type {
    const func_info = @typeInfo(@TypeOf(func));
    const ReturnType = func_info.@"fn".return_type.?;

    return struct {
        pub fn call(x: ?T) ReturnType {
            const val = x orelse default;
            return func(val);
        }

        pub fn getDefault() T {
            return default;
        }
    };
}

fn double(x: i32) i32 {
    return x * 2;
}

// Usage
const DoubleWithDefault = WithDefault(double, i32, 10);
DoubleWithDefault.call(5);     // 10
DoubleWithDefault.call(null);  // 20 (uses default)
```

Type and default value customize wrapper behavior.

### Callback Parameter Decorator

Pass functions as decorator arguments:

```zig
fn WithCallbacks(
    comptime func: anytype,
    comptime before: anytype,
    comptime after: anytype,
) type {
    return struct {
        pub fn call(x: i32) i32 {
            before(x);
            const result = func(x);
            after(result);
            return result;
        }
    };
}

fn logBefore(x: i32) void {
    std.debug.print("Before: {d}\n", .{x});
}

fn logAfter(x: i32) void {
    std.debug.print("After: {d}\n", .{x});
}

// Usage
const Instrumented = WithCallbacks(triple, logBefore, logAfter);
const result = Instrumented.call(5);  // Logs before and after
```

Callbacks customize behavior without modifying the decorator.

### Conditional Decorator

Use boolean flags to enable/disable features:

```zig
fn Conditional(comptime func: anytype, comptime enabled: bool) type {
    if (enabled) {
        return struct {
            pub fn call(x: i32) i32 {
                const result = func(x);
                return result * 2; // Apply transformation
            }

            pub fn isEnabled() bool {
                return true;
            }
        };
    } else {
        return struct {
            pub fn call(x: i32) i32 {
                return func(x); // Pass through
            }

            pub fn isEnabled() bool {
                return false;
            }
        };
    }
}

// Usage
const Enabled = Conditional(add10, true);
const Disabled = Conditional(add10, false);

Enabled.call(5);   // 30 (transformed)
Disabled.call(5);  // 15 (pass-through)
```

Compile-time conditionals eliminate dead code.

### Threshold Decorator

Combine enum and value parameters:

```zig
fn WithThreshold(comptime func: anytype, comptime threshold: i32, comptime action: enum { clamp, error_on_exceed }) type {
    return struct {
        pub fn call(x: i32) !i32 {
            if (x > threshold) {
                switch (action) {
                    .clamp => {
                        const result = func(threshold);
                        return result;
                    },
                    .error_on_exceed => {
                        return error.ThresholdExceeded;
                    },
                }
            }
            return func(x);
        }

        pub fn getThreshold() i32 {
            return threshold;
        }
    };
}

// Usage
const Clamped = WithThreshold(double, 10, .clamp);
const ErrorBased = WithThreshold(double, 10, .error_on_exceed);

Clamped.call(15);      // 20 (clamped to 10, then doubled)
ErrorBased.call(15);   // error.ThresholdExceeded
```

Enum parameters provide type-safe configuration options.

### Multiple Parameter Decorator

Use struct parameters for complex configuration:

```zig
fn WithConfig(
    comptime func: anytype,
    comptime config: struct {
        multiplier: i32,
        offset: i32,
        invert: bool,
    },
) type {
    return struct {
        pub fn call(x: i32) i32 {
            var result = func(x);
            result = result * config.multiplier;
            result = result + config.offset;
            if (config.invert) {
                result = -result;
            }
            return result;
        }

        pub fn getConfig() @TypeOf(config) {
            return config;
        }
    };
}

// Usage
const Configured = WithConfig(identity, .{
    .multiplier = 2,
    .offset = 5,
    .invert = false,
});

Configured.call(5);  // (5 * 2) + 5 = 15
```

Struct parameters group related configuration.

### Array Parameter Decorator

Use arrays for list-based configuration:

```zig
fn WithAllowList(comptime func: anytype, comptime allowed: []const i32) type {
    return struct {
        pub fn call(x: i32) !i32 {
            for (allowed) |val| {
                if (x == val) {
                    return func(x);
                }
            }
            return error.NotAllowed;
        }

        pub fn getAllowed() []const i32 {
            return allowed;
        }
    };
}

// Usage
const allowed_values = [_]i32{ 1, 5, 10, 15 };
const Restricted = WithAllowList(double, &allowed_values);

Restricted.call(5);   // 10 (allowed)
Restricted.call(7);   // error.NotAllowed
```

Arrays define allow/deny lists at compile time.

## Discussion

Parameterized decorators enable flexible, reusable metaprogramming patterns with compile-time configuration.

### Why Parameterized Decorators

**Reusability**:
- One decorator, many configurations
- No code duplication
- Shared behavior, different parameters
- Type-safe variation

**Compile-time safety**:
- Parameters validated at compile time
- Type errors caught early
- No runtime configuration overhead
- Optimized per-instantiation

**Flexibility**:
- Mix and match parameters
- Compose decorators with different configs
- Build decorator libraries
- Application-specific customization

### Parameter Types

**Value parameters**:
```zig
comptime multiplier: i32
comptime threshold: f64
comptime max_retries: u32
```

Simple constants used in wrapper logic.

**Type parameters**:
```zig
comptime T: type
comptime ErrorSet: type
comptime ReturnType: type
```

Generic wrappers adapting to types.

**String parameters**:
```zig
comptime prefix: []const u8
comptime format: []const u8
comptime name: []const u8
```

Compile-time string constants.

**Function parameters**:
```zig
comptime callback: anytype
comptime validator: anytype
comptime transform: anytype
```

Higher-order decoration with function parameters.

**Enum parameters**:
```zig
comptime mode: enum { strict, lenient }
comptime action: enum { clamp, error, wrap }
```

Type-safe configuration options.

**Struct parameters**:
```zig
comptime config: struct {
    field1: T1,
    field2: T2,
}
```

Grouped configuration for complex cases.

**Array parameters**:
```zig
comptime allowed: []const T
comptime defaults: []const T
```

Lists of values at compile time.

### Parameter Naming

**Descriptive names**:
```zig
fn WithBounds(... comptime min: i32, comptime max: i32)
fn WithRetry(... comptime max_attempts: u32, comptime delay_ms: u64)
```

Make parameter purpose obvious.

**Config struct pattern**:
```zig
fn Decorator(comptime func: anytype, comptime config: Config) type
```

Group related parameters.

**Consistent ordering**:
1. Function being wrapped
2. Primary parameters
3. Secondary/optional parameters
4. Callback functions

### Accessing Parameters

**Public const**:
```zig
return struct {
    pub const multiplier_value = multiplier;
    pub const threshold_value = threshold;
};
```

Expose parameters as constants.

**Getter methods**:
```zig
pub fn getMultiplier() i32 {
    return multiplier;
}
```

More explicit than constants.

**Both approaches**:
```zig
pub const max_attempts = max_attempts_param;

pub fn getMaxAttempts() u32 {
    return max_attempts;
}
```

Provide both for flexibility.

### Conditional Compilation

**Feature flags**:
```zig
fn WithFeature(comptime func: anytype, comptime enable_feature: bool) type {
    if (enable_feature) {
        // Feature enabled code
    } else {
        // Feature disabled code
    }
}
```

**Build mode checks**:
```zig
const debug = @import("builtin").mode == .Debug;
const Decorated = WithLogging(func, debug);
```

**Platform-specific**:
```zig
const is_windows = @import("builtin").os.tag == .windows;
const Wrapped = PlatformSpecific(func, is_windows);
```

### Design Patterns

**Builder pattern**:
```zig
const Builder = struct {
    multiplier: i32 = 1,
    offset: i32 = 0,

    pub fn build(self: Builder, comptime func: anytype) type {
        return WithConfig(func, .{
            .multiplier = self.multiplier,
            .offset = self.offset,
        });
    }
};
```

**Default parameters**:
```zig
fn WithOptionalRetry(
    comptime func: anytype,
    comptime max_attempts: u32,
    comptime delay_ms: ?u64,
) type {
    const delay = delay_ms orelse 100; // Default
    return WithRetry(func, max_attempts, delay);
}
```

**Parameter validation**:
```zig
fn WithValidatedBounds(..., comptime min: i32, comptime max: i32) type {
    if (min >= max) {
        @compileError("min must be less than max");
    }
    // ...
}
```

### Common Configurations

**Validation**:
- Min/max bounds
- Allow/deny lists
- Type constraints
- Format validation

**Timing**:
- Retry delays
- Timeout durations
- Rate limits
- Debounce intervals

**Transformation**:
- Multipliers/scalars
- Offsets/additions
- Format strings
- Conversion functions

**Behavior**:
- Debug vs release
- Strict vs lenient
- Synchronous vs async
- Cached vs uncached

### Performance

**Zero runtime overhead**:
- All parameters resolved at compile time
- No runtime configuration structures
- No dynamic dispatch
- Fully inlined

**Code size**:
- Each parameter combination generates separate type
- Can increase binary size
- Mitigated by compiler optimization
- Trade-off: flexibility vs size

**Compile time**:
- More parameters = longer compile
- Complex conditionals increase time
- Worth it for runtime performance
- Use judiciously

### Testing Parameterized Decorators

**Test different configurations**:
```zig
test "various multipliers" {
    const Times2 = WithMultiplier(func, 2);
    const Times10 = WithMultiplier(func, 10);

    try testing.expectEqual(10, Times2.call(5));
    try testing.expectEqual(50, Times10.call(5));
}
```

**Test parameter access**:
```zig
test "parameter accessors" {
    const Decorated = WithBounds(func, 0, 100);

    try testing.expectEqual(0, Decorated.getMin());
    try testing.expectEqual(100, Decorated.getMax());
}
```

**Test edge cases**:
```zig
test "boundary conditions" {
    const Bounded = WithBounds(func, 5, 10);

    try testing.expectEqual(25, try Bounded.call(5));  // Min
    try testing.expectEqual(100, try Bounded.call(10)); // Max
    try testing.expectError(error.OutOfBounds, Bounded.call(4));  // Below
    try testing.expectError(error.OutOfBounds, Bounded.call(11)); // Above
}
```

### Error Handling

**Invalid parameters**:
```zig
if (max_attempts == 0) {
    @compileError("max_attempts must be > 0");
}
```

**Type mismatches**:
```zig
if (@TypeOf(default) != T) {
    @compileError("default value type must match T");
}
```

**Range validation**:
```zig
if (threshold < 0 or threshold > 100) {
    @compileError("threshold must be 0-100");
}
```

## See Also

- Recipe 9.1: Putting a Wrapper Around a Function
- Recipe 9.2: Preserving Function Metadata When Writing Decorators
- Recipe 9.3: Unwrapping a Decorator
- Recipe 9.5: Enforcing Type Checking on a Function Using a Decorator

Full compilable example: `code/03-advanced/09-metaprogramming/recipe_9_4.zig`
