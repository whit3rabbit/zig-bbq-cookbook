## Problem

You want to organize related decorators together, provide shared configuration or utilities, or create namespaced decorator collections. Individual standalone decorator functions can become scattered and hard to manage.

## Solution

Define decorators as methods within structs to create organized namespaces, share configuration, and group related functionality.

### Basic Struct Decorators

Organize decorators as struct methods for namespace organization:

```zig
{{#include ../../../code/03-advanced/09-metaprogramming/recipe_9_6.zig:basic_struct_decorators}}
```

Struct methods provide namespace separation and logical grouping.

### Shared Configuration

Pass configuration to decorator methods at compile time:

```zig
const ConfiguredDecorators = struct {
    const Config = struct {
        enable_logging: bool = false,
        enable_caching: bool = true,
        max_cache_size: usize = 100,
    };

    pub fn WithCache(comptime config: Config, comptime func: anytype) type {
        const enable = config.enable_caching;
        const max_size = config.max_cache_size;

        return struct {
            pub fn call(x: i32) i32 {
                if (!enable) {
                    return func(x);
                }
                // Caching logic using max_size
                return func(x);
            }

            pub fn isCacheEnabled() bool {
                return enable;
            }
        };
    }
};

// Usage
const config = ConfiguredDecorators.Config{
    .enable_caching = true,
    .max_cache_size = 50,
};

const Cached = ConfiguredDecorators.WithCache(config, double);
Cached.call(5);  // 10
Cached.isCacheEnabled();  // true
```

Compile-time configuration provides zero-overhead customization.

### Namespace Organization

Group decorators by category using separate structs:

```zig
const Validation = struct {
    pub fn Bounds(comptime func: anytype, comptime min: i32, comptime max: i32) type {
        return struct {
            pub fn call(x: i32) !i32 {
                if (x < min or x > max) {
                    return error.OutOfBounds;
                }
                return func(x);
            }
        };
    }

    pub fn NonZero(comptime func: anytype) type {
        return struct {
            pub fn call(x: i32) !i32 {
                if (x == 0) {
                    return error.ZeroNotAllowed;
                }
                return func(x);
            }
        };
    }
};

const Transformation = struct {
    pub fn Scale(comptime func: anytype, comptime factor: i32) type {
        return struct {
            pub fn call(x: i32) i32 {
                return func(x) * factor;
            }
        };
    }

    pub fn Offset(comptime func: anytype, comptime offset: i32) type {
        return struct {
            pub fn call(x: i32) i32 {
                return func(x) + offset;
            }
        };
    }
};

// Usage
const Bounded = Validation.Bounds(double, 0, 10);
const Scaled = Transformation.Scale(double, 2);

try Bounded.call(5);  // 10
try Bounded.call(15); // error.OutOfBounds

Scaled.call(5);  // 20
```

Categorization makes intent clear and improves discoverability.

### Stateful Decorators

Track state across multiple invocations:

```zig
const StatefulDecorators = struct {
    pub fn WithCounter(comptime func: anytype) type {
        return struct {
            var call_count: u32 = 0;
            var total_sum: i64 = 0;

            pub fn call(x: i32) i32 {
                call_count += 1;
                const result = func(x);
                total_sum += result;
                return result;
            }

            pub fn getCallCount() u32 {
                return call_count;
            }

            pub fn getTotalSum() i64 {
                return total_sum;
            }

            pub fn reset() void {
                call_count = 0;
                total_sum = 0;
            }
        };
    }

    pub fn WithMinMax(comptime func: anytype) type {
        return struct {
            var min_value: ?i32 = null;
            var max_value: ?i32 = null;

            pub fn call(x: i32) i32 {
                const result = func(x);

                if (min_value) |min| {
                    if (result < min) min_value = result;
                } else {
                    min_value = result;
                }

                if (max_value) |max| {
                    if (result > max) max_value = result;
                } else {
                    max_value = result;
                }

                return result;
            }

            pub fn getMin() ?i32 {
                return min_value;
            }

            pub fn getMax() ?i32 {
                return max_value;
            }

            pub fn reset() void {
                min_value = null;
                max_value = null;
            }
        };
    }
};

// Usage
const Counted = StatefulDecorators.WithCounter(double);

Counted.call(5);   // 10
Counted.call(10);  // 20

Counted.getCallCount();  // 2
Counted.getTotalSum();   // 30

const MinMaxed = StatefulDecorators.WithMinMax(double);
MinMaxed.call(5);   // 10
MinMaxed.call(10);  // 20
MinMaxed.call(2);   // 4

MinMaxed.getMin();  // 4
MinMaxed.getMax();  // 20
```

State persists across calls, enabling tracking and analytics.

### Decorator Factory

Create decorators dynamically based on type:

```zig
const DecoratorFactory = struct {
    pub fn create(comptime decorator_type: enum { timing, logging, caching }) type {
        return switch (decorator_type) {
            .timing => struct {
                pub fn wrap(comptime func: anytype) type {
                    return struct {
                        pub fn call(x: i32) i32 {
                            // Timing logic
                            return func(x);
                        }
                    };
                }
            },
            .logging => struct {
                pub fn wrap(comptime func: anytype) type {
                    return struct {
                        var count: u32 = 0;

                        pub fn call(x: i32) i32 {
                            count += 1;
                            return func(x);
                        }

                        pub fn getCount() u32 {
                            return count;
                        }
                    };
                }
            },
            .caching => struct {
                pub fn wrap(comptime func: anytype) type {
                    return struct {
                        pub fn call(x: i32) i32 {
                            // Caching logic
                            return func(x);
                        }
                    };
                }
            },
        };
    }
};

// Usage
const LoggingDecorator = DecoratorFactory.create(.logging);
const Logged = LoggingDecorator.wrap(double);

Logged.call(5);       // 10
Logged.getCount();    // 1
```

Factory pattern provides compile-time decorator selection.

### Chaining Struct Decorators

Chain multiple decorators from the same namespace:

```zig
const ChainableDecorators = struct {
    pub fn Validate(comptime func: anytype) type {
        return struct {
            pub fn call(x: i32) !i32 {
                if (x < 0) {
                    return error.NegativeNotAllowed;
                }
                return func(x);
            }
        };
    }

    pub fn Double(comptime func: anytype) type {
        return struct {
            pub fn call(x: i32) @TypeOf(func(0)) {
                return func(x * 2);
            }
        };
    }

    pub fn AddTen(comptime func: anytype) type {
        return struct {
            pub fn call(x: i32) @TypeOf(func(0)) {
                return func(x + 10);
            }
        };
    }
};

fn identity(x: i32) i32 {
    return x;
}

// Usage - chain decorators
const Step1 = ChainableDecorators.Validate(identity);
const Step2 = ChainableDecorators.Double(Step1.call);
const Step3 = ChainableDecorators.AddTen(Step2.call);

try Step3.call(5);  // (5 + 10) * 2 = 30
```

Chaining builds complex behavior from simple components.

### Shared Utilities

Share helper functions across decorators:

```zig
const UtilityDecorators = struct {
    fn logMessage(comptime msg: []const u8, value: i32) void {
        _ = value;
        _ = msg;
        // In real code: std.debug.print("{s}: {d}\n", .{ msg, value });
    }

    pub fn WithPreLog(comptime func: anytype) type {
        return struct {
            pub fn call(x: i32) i32 {
                logMessage("Before", x);
                return func(x);
            }
        };
    }

    pub fn WithPostLog(comptime func: anytype) type {
        return struct {
            pub fn call(x: i32) i32 {
                const result = func(x);
                logMessage("After", result);
                return result;
            }
        };
    }
};

// Usage
const PreLogged = UtilityDecorators.WithPreLog(double);
const PostLogged = UtilityDecorators.WithPostLog(double);
```

Shared utilities reduce code duplication.

### Generic Decorator Struct

Create type-parameterized decorator collections:

```zig
fn DecoratorSet(comptime T: type) type {
    return struct {
        pub fn WithDefault(comptime func: anytype, comptime default: T) type {
            return struct {
                pub fn call(x: ?T) T {
                    const val = x orelse default;
                    return func(val);
                }
            };
        }

        pub fn WithValidation(comptime func: anytype, comptime validator: anytype) type {
            return struct {
                pub fn call(x: T) !T {
                    if (!validator(x)) {
                        return error.ValidationFailed;
                    }
                    return func(x);
                }
            };
        }
    };
}

fn isPositive(x: i32) bool {
    return x > 0;
}

// Usage
const I32Decorators = DecoratorSet(i32);

const WithDefault = I32Decorators.WithDefault(double, 10);
WithDefault.call(5);     // 10
WithDefault.call(null);  // 20 (uses default)

const Validated = I32Decorators.WithValidation(double, isPositive);
try Validated.call(5);   // 10
try Validated.call(-5);  // error.ValidationFailed
```

Generic structs create reusable decorator families.

### Decorator Registry

Conditionally enable decorators based on compile-time registry:

```zig
const DecoratorRegistry = struct {
    const Entry = struct {
        name: []const u8,
        enabled: bool,
    };

    fn isEnabled(comptime entries: []const Entry, comptime name: []const u8) bool {
        inline for (entries) |entry| {
            if (std.mem.eql(u8, entry.name, name)) {
                return entry.enabled;
            }
        }
        return false;
    }

    pub fn Conditional(comptime entries: []const Entry, comptime name: []const u8, comptime func: anytype) type {
        const enabled = comptime isEnabled(entries, name);

        return struct {
            pub fn call(x: i32) i32 {
                if (enabled) {
                    return func(x) * 2;
                }
                return func(x);
            }
        };
    }
};

// Usage
const entries = [_]DecoratorRegistry.Entry{
    .{ .name = "timing", .enabled = true },
    .{ .name = "logging", .enabled = false },
};

const TimingWrapped = DecoratorRegistry.Conditional(&entries, "timing", double);
const LoggingWrapped = DecoratorRegistry.Conditional(&entries, "logging", double);

TimingWrapped.call(5);   // 20 (enabled: (5*2)*2)
LoggingWrapped.call(5);  // 10 (disabled: 5*2)
```

Registry pattern enables conditional compilation of decorators.

## Discussion

Organizing decorators within structs provides structure, sharing, and namespace management for metaprogramming code.

### Why Struct-Based Decorators

**Organization**:
- Logical grouping of related decorators
- Namespace separation prevents name collisions
- Clear categorization by purpose
- Easier discovery and documentation

**Sharing**:
- Common configuration across decorators
- Shared utility functions
- Consistent interfaces
- Reduced code duplication

**Flexibility**:
- Mix standalone and struct-based decorators
- Nest decorator structs for hierarchy
- Create decorator families with generics
- Enable/disable via compile-time flags

### Design Patterns

**Namespace pattern**:
```zig
const Category = struct {
    pub fn Decorator1(...) type { ... }
    pub fn Decorator2(...) type { ... }
};
```

Group by category (Validation, Transformation, etc).

**Configuration pattern**:
```zig
const Decorators = struct {
    pub fn WithConfig(comptime config: Config, ...) type { ... }
};
```

Share configuration across decorator instances.

**Factory pattern**:
```zig
const Factory = struct {
    pub fn create(comptime kind: enum { ... }) type {
        return switch (kind) { ... };
    }
};
```

Select decorator type at compile time.

**Generic pattern**:
```zig
fn DecoratorFamily(comptime T: type) type {
    return struct {
        pub fn Decorator1(...) type { ... }
        pub fn Decorator2(...) type { ... }
    };
}
```

Create type-parameterized decorator collections.

**Registry pattern**:
```zig
const Registry = struct {
    pub fn Conditional(comptime entries: []const Entry, ...) type { ... }
};
```

Enable/disable decorators based on compile-time registry.

### Struct Organization Strategies

**By purpose**:
```zig
const Validation = struct { ... };
const Logging = struct { ... };
const Performance = struct { ... };
```

**By domain**:
```zig
const HttpDecorators = struct { ... };
const DatabaseDecorators = struct { ... };
const CacheDecorators = struct { ... };
```

**By complexity**:
```zig
const SimpleDecorators = struct { ... };
const AdvancedDecorators = struct { ... };
const ExperimentalDecorators = struct { ... };
```

**By lifecycle**:
```zig
const PreProcessing = struct { ... };
const CoreLogic = struct { ... };
const PostProcessing = struct { ... };
```

### State Management

**Module-level state**:
```zig
pub fn Decorator(...) type {
    return struct {
        var state: StateType = init_value;
        // ...
    };
}
```

State persists across all uses of this decorator instance.

**Resettable state**:
```zig
pub fn reset() void {
    state = initial_value;
}
```

Allow clearing state between test runs or phases.

**Thread safety**:

Zig's comptime evaluation is single-threaded. Runtime state requires explicit synchronization:
```zig
var state: std.atomic.Value(u32) = .{ .value = 0 };
```

Use atomics for thread-safe state.

### Compile-Time Requirements

**All decorator parameters must be comptime**:
```zig
pub fn Decorator(comptime config: Config, comptime func: anytype) type
```

Can't use runtime values when returning types.

**Configuration resolution**:
```zig
pub fn Decorator(comptime config: Config, ...) type {
    const enabled = config.enabled;  // Resolved at compile time
    // Use 'enabled' in decorator logic
}
```

Extract configuration values before using in decorator.

**Registry lookups**:
```zig
const enabled = comptime isEnabled(entries, name);
```

All registry access must be comptime.

### Testing Strategies

**Test individual decorators**:
```zig
test "validation decorator" {
    const Bounded = Validation.Bounds(func, 0, 10);
    try testing.expectEqual(expected, try Bounded.call(5));
}
```

**Test decorator combinations**:
```zig
test "chained decorators" {
    const Step1 = Decorators.First(func);
    const Step2 = Decorators.Second(Step1.call);
    // Test chain behavior
}
```

**Test stateful decorators**:
```zig
test "stateful tracking" {
    const Tracked = Decorators.WithCounter(func);
    _ = Tracked.call(5);
    try testing.expectEqual(1, Tracked.getCallCount());
    Tracked.reset();
    try testing.expectEqual(0, Tracked.getCallCount());
}
```

**Test configuration variants**:
```zig
test "different configs" {
    const config1 = Config{ .enabled = true };
    const config2 = Config{ .enabled = false };

    const Dec1 = Decorators.WithConfig(config1, func);
    const Dec2 = Decorators.WithConfig(config2, func);
    // Test different behaviors
}
```

### Documentation Practices

**Document struct purpose**:
```zig
/// Validation decorators that enforce runtime constraints
const Validation = struct { ... };
```

**Document individual decorators**:
```zig
/// Enforces bounds checking on function input
/// Returns error.OutOfBounds if x < min or x > max
pub fn Bounds(comptime func: anytype, comptime min: i32, comptime max: i32) type
```

**Document configuration**:
```zig
/// Configuration for caching decorators
const Config = struct {
    /// Enable/disable caching (default: true)
    enable_caching: bool = true,
    /// Maximum cache entries (default: 100)
    max_cache_size: usize = 100,
};
```

**Provide usage examples**:
```zig
/// Example usage:
///   const Bounded = Validation.Bounds(myFunc, 0, 100);
///   const result = try Bounded.call(50);
```

### Performance Characteristics

**Zero runtime overhead**:
- All decorator selection at compile time
- No vtables or dynamic dispatch
- Fully inlined by optimizer
- Same performance as hand-written code

**Compile time impact**:
- More complex structures increase compile time
- Registry lookups add minimal overhead
- Generic instantiation multiplies compile work
- Worth it for maintainability

**Binary size**:
- Each configuration creates separate instance
- May increase code size with many variants
- Compiler deduplicates identical code
- Use judiciously in size-constrained environments

### Common Patterns

**Validation suite**:
```zig
const Validate = struct {
    pub fn Bounds(...) type { ... }
    pub fn NonNull(...) type { ... }
    pub fn Range(...) type { ... }
    pub fn Pattern(...) type { ... }
};
```

**Transformation pipeline**:
```zig
const Transform = struct {
    pub fn Map(...) type { ... }
    pub fn Filter(...) type { ... }
    pub fn Reduce(...) type { ... }
};
```

**Instrumentation**:
```zig
const Instrument = struct {
    pub fn Timing(...) type { ... }
    pub fn Logging(...) type { ... }
    pub fn Profiling(...) type { ... }
};
```

**Resource management**:
```zig
const Resource = struct {
    pub fn WithLock(...) type { ... }
    pub fn WithRetry(...) type { ... }
    pub fn WithTimeout(...) type { ... }
};
```

## See Also

- Recipe 9.1: Putting a Wrapper Around a Function
- Recipe 9.2: Preserving Function Metadata When Writing Decorators
- Recipe 9.4: Defining a Decorator That Takes Arguments
- Recipe 9.7: Defining Decorators as Structs

Full compilable example: `code/03-advanced/09-metaprogramming/recipe_9_6.zig`
