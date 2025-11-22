// Recipe 9.6: Defining Decorators as Part of a Struct
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_struct_decorators
// Organize decorators as struct methods
const Decorators = struct {
    pub fn Timing(comptime func: anytype) type {
        return struct {
            pub fn call(x: i32) i32 {
                // In real code, would measure time
                const result = func(x);
                return result;
            }
        };
    }

    pub fn Logging(comptime func: anytype) type {
        return struct {
            var call_count: u32 = 0;

            pub fn call(x: i32) i32 {
                call_count += 1;
                const result = func(x);
                return result;
            }

            pub fn getCallCount() u32 {
                return call_count;
            }
        };
    }
};

fn double(x: i32) i32 {
    return x * 2;
}

test "basic struct decorators" {
    const Timed = Decorators.Timing(double);
    try testing.expectEqual(@as(i32, 10), Timed.call(5));

    const Logged = Decorators.Logging(double);
    try testing.expectEqual(@as(i32, 10), Logged.call(5));
    try testing.expectEqual(@as(u32, 1), Logged.getCallCount());
}
// ANCHOR_END: basic_struct_decorators

// ANCHOR: shared_config
// Decorators with shared configuration
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
                // Simplified caching
                _ = max_size;
                return func(x);
            }

            pub fn isCacheEnabled() bool {
                return enable;
            }
        };
    }
};

test "shared config" {
    const config = ConfiguredDecorators.Config{
        .enable_caching = true,
        .max_cache_size = 50,
    };

    const Cached = ConfiguredDecorators.WithCache(config, double);
    try testing.expectEqual(@as(i32, 10), Cached.call(5));
    try testing.expect(Cached.isCacheEnabled());
}
// ANCHOR_END: shared_config

// ANCHOR: namespace_organization
// Organize decorators by category
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

test "namespace organization" {
    const Bounded = Validation.Bounds(double, 0, 10);
    try testing.expectEqual(@as(i32, 10), try Bounded.call(5));
    try testing.expectError(error.OutOfBounds, Bounded.call(15));

    const Scaled = Transformation.Scale(double, 2);
    try testing.expectEqual(@as(i32, 20), Scaled.call(5)); // (5 * 2) * 2
}
// ANCHOR_END: namespace_organization

// ANCHOR: stateful_decorators
// Decorators with compile-time configuration and state tracking
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

test "stateful decorators" {
    const Counted = StatefulDecorators.WithCounter(double);

    _ = Counted.call(5);
    _ = Counted.call(10);

    try testing.expectEqual(@as(u32, 2), Counted.getCallCount());
    try testing.expectEqual(@as(i64, 30), Counted.getTotalSum()); // 10 + 20

    Counted.reset();
    try testing.expectEqual(@as(u32, 0), Counted.getCallCount());

    const MinMaxed = StatefulDecorators.WithMinMax(double);
    _ = MinMaxed.call(5);  // 10
    _ = MinMaxed.call(10); // 20
    _ = MinMaxed.call(2);  // 4

    try testing.expectEqual(@as(?i32, 4), MinMaxed.getMin());
    try testing.expectEqual(@as(?i32, 20), MinMaxed.getMax());

    MinMaxed.reset();
}
// ANCHOR_END: stateful_decorators

// ANCHOR: decorator_factory
// Factory pattern for decorator creation
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

test "decorator factory" {
    const LoggingDecorator = DecoratorFactory.create(.logging);
    const Logged = LoggingDecorator.wrap(double);

    try testing.expectEqual(@as(i32, 10), Logged.call(5));
    try testing.expectEqual(@as(u32, 1), Logged.getCount());
}
// ANCHOR_END: decorator_factory

// ANCHOR: chaining_struct_decorators
// Chain multiple decorators from the same struct
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

test "chaining struct decorators" {
    // Chain: AddTen -> Double -> Validate -> identity
    const Step1 = ChainableDecorators.Validate(identity);
    const Step2 = ChainableDecorators.Double(Step1.call);
    const Step3 = ChainableDecorators.AddTen(Step2.call);

    try testing.expectEqual(@as(i32, 30), try Step3.call(5)); // (5 + 10) * 2 = 30
}
// ANCHOR_END: chaining_struct_decorators

// ANCHOR: shared_utilities
// Decorators with shared utility functions
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

test "shared utilities" {
    const PreLogged = UtilityDecorators.WithPreLog(double);
    const PostLogged = UtilityDecorators.WithPostLog(double);

    try testing.expectEqual(@as(i32, 10), PreLogged.call(5));
    try testing.expectEqual(@as(i32, 10), PostLogged.call(5));
}
// ANCHOR_END: shared_utilities

// ANCHOR: generic_decorator_struct
// Generic decorator struct with type parameters
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

test "generic decorator struct" {
    const I32Decorators = DecoratorSet(i32);

    const WithDefault = I32Decorators.WithDefault(double, 10);
    try testing.expectEqual(@as(i32, 10), WithDefault.call(5));
    try testing.expectEqual(@as(i32, 20), WithDefault.call(null));

    const Validated = I32Decorators.WithValidation(double, isPositive);
    try testing.expectEqual(@as(i32, 10), try Validated.call(5));
    try testing.expectError(error.ValidationFailed, Validated.call(-5));
}
// ANCHOR_END: generic_decorator_struct

// ANCHOR: mixin_decorators
// Decorator mixin pattern
const LoggingMixin = struct {
    pub fn addLogging(comptime T: type) type {
        return struct {
            base: T,

            pub fn call(self: @This(), x: i32) i32 {
                // Log before
                const result = self.base.call(x);
                // Log after
                return result;
            }
        };
    }
};

const CachingMixin = struct {
    pub fn addCaching(comptime T: type) type {
        return struct {
            base: T,
            var cached: ?i32 = null;

            pub fn call(self: @This(), x: i32) i32 {
                if (cached) |c| {
                    if (x == 0) return c; // Simplified cache check
                }
                const result = self.base.call(x);
                cached = result;
                return result;
            }
        };
    }
};

const BaseWrapper = struct {
    pub fn call(_: @This(), x: i32) i32 {
        return x * 3;
    }
};

test "mixin decorators" {
    const Logged = LoggingMixin.addLogging(BaseWrapper);
    const logged = Logged{ .base = .{} };
    try testing.expectEqual(@as(i32, 15), logged.call(5));

    const Cached = CachingMixin.addCaching(BaseWrapper);
    const cached = Cached{ .base = .{} };
    try testing.expectEqual(@as(i32, 15), cached.call(5));
}
// ANCHOR_END: mixin_decorators

// ANCHOR: decorator_registry
// Decorator registry pattern
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

test "decorator registry" {
    const entries = [_]DecoratorRegistry.Entry{
        .{ .name = "timing", .enabled = true },
        .{ .name = "logging", .enabled = false },
    };

    const TimingWrapped = DecoratorRegistry.Conditional(&entries, "timing", double);
    const LoggingWrapped = DecoratorRegistry.Conditional(&entries, "logging", double);

    try testing.expectEqual(@as(i32, 20), TimingWrapped.call(5)); // Enabled: (5*2)*2
    try testing.expectEqual(@as(i32, 10), LoggingWrapped.call(5)); // Disabled: 5*2
}
// ANCHOR_END: decorator_registry

// Comprehensive test
test "comprehensive struct decorators" {
    // Basic struct decorators
    const Logged = Decorators.Logging(double);
    try testing.expectEqual(@as(i32, 10), Logged.call(5));

    // Namespace organization
    const Bounded = Validation.Bounds(double, 0, 100);
    try testing.expectEqual(@as(i32, 10), try Bounded.call(5));

    // Factory pattern
    const Factory = DecoratorFactory.create(.logging);
    const FactoryWrapped = Factory.wrap(double);
    try testing.expectEqual(@as(i32, 10), FactoryWrapped.call(5));

    // Generic decorator set
    const I32Decs = DecoratorSet(i32);
    const WithDef = I32Decs.WithDefault(double, 10);
    try testing.expectEqual(@as(i32, 20), WithDef.call(null));
}
