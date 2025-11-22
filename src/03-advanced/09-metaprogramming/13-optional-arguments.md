## Problem

You need to create generic types or functions that accept optional parameters, allowing users to override defaults when needed while keeping simple cases simple. You want to avoid forcing users to specify every parameter while still maintaining type safety.

## Solution

Zig provides several patterns for optional arguments: structs with default field values, compile-time conditional logic, and variadic tuple handling. These approaches leverage compile-time evaluation to eliminate runtime overhead.

### Optional Configuration Struct

The simplest pattern uses a struct with default field values:

```zig
{{#include ../../../code/03-advanced/09-metaprogramming/recipe_9_13.zig:optional_config}}
```

Callers can specify only the fields they want to override, making the API both flexible and concise.

## Discussion

### Generic with Optional Type Parameters

Use struct defaults to provide optional configuration to generic types:

```zig
fn Container(comptime T: type, comptime Options: type) type {
    return struct {
        const Self = @This();
        const Opts = if (@hasDecl(Options, "capacity")) Options else struct {
            pub const capacity: usize = 10;
            pub const resizable: bool = true;
        };

        data: [Opts.capacity]T = undefined,
        len: usize = 0,

        pub fn init() Self {
            return .{};
        }

        pub fn append(self: *Self, item: T) !void {
            if (self.len >= Opts.capacity) {
                return error.CapacityExceeded;
            }
            self.data[self.len] = item;
            self.len += 1;
        }

        pub fn getCapacity() usize {
            return Opts.capacity;
        }
    };
}

test "optional type param" {
    // Use default options
    const DefaultContainer = Container(i32, struct {});
    var c1 = DefaultContainer.init();
    try c1.append(10);
    try testing.expectEqual(@as(usize, 10), DefaultContainer.getCapacity());

    // Custom options
    const CustomOptions = struct {
        pub const capacity: usize = 5;
        pub const resizable: bool = false;
    };
    const CustomContainer = Container(i32, CustomOptions);
    var c2 = CustomContainer.init();
    try testing.expectEqual(@as(usize, 5), CustomContainer.getCapacity());
}
```

The `@hasDecl` check allows detecting whether custom options were provided.

### Variadic Tuple Arguments

Process a variable number of arguments via tuples:

```zig
fn sum(args: anytype) i32 {
    const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
    var total: i32 = 0;
    inline for (fields) |field| {
        total += @field(args, field.name);
    }
    return total;
}

fn concat(allocator: std.mem.Allocator, args: anytype) ![]const u8 {
    const fields = @typeInfo(@TypeOf(args)).@"struct".fields;

    // Calculate total length
    var total_len: usize = 0;
    inline for (fields) |field| {
        const value = @field(args, field.name);
        total_len += value.len;
    }

    // Allocate and fill buffer
    const buffer = try allocator.alloc(u8, total_len);
    errdefer allocator.free(buffer);

    var pos: usize = 0;
    inline for (fields) |field| {
        const value = @field(args, field.name);
        @memcpy(buffer[pos..][0..value.len], value);
        pos += value.len;
    }

    return buffer;
}

test "variadic tuple" {
    const r1 = sum(.{1});
    try testing.expectEqual(@as(i32, 1), r1);

    const r2 = sum(.{ 1, 2, 3 });
    try testing.expectEqual(@as(i32, 6), r2);

    const s = try concat(testing.allocator, .{ "hello", " ", "world" });
    defer testing.allocator.free(s);
    try testing.expectEqualStrings("hello world", s);
}
```

The `inline for` iterates over tuple fields at compile time, making this zero-overhead.

### Optional Allocator

Conditionally include an allocator based on a compile-time flag:

```zig
fn Processor(comptime needs_allocator: bool) type {
    return struct {
        const Self = @This();
        allocator: if (needs_allocator) std.mem.Allocator else void,
        buffer: if (needs_allocator) ?[]u8 else void,

        pub fn init(allocator_arg: anytype) Self {
            if (needs_allocator) {
                return .{
                    .allocator = allocator_arg,
                    .buffer = null,
                };
            } else {
                return .{
                    .allocator = {},
                    .buffer = {},
                };
            }
        }

        pub fn process(self: *Self, value: i32) !i32 {
            if (needs_allocator) {
                if (self.buffer == null) {
                    self.buffer = try self.allocator.alloc(u8, 10);
                }
            }
            return value * 2;
        }

        pub fn deinit(self: *Self) void {
            if (needs_allocator) {
                if (self.buffer) |buf| {
                    self.allocator.free(buf);
                }
            }
        }

        pub fn needsAllocator() bool {
            return needs_allocator;
        }
    };
}

test "optional allocator" {
    const WithAlloc = Processor(true);
    var p1 = WithAlloc.init(testing.allocator);
    defer p1.deinit();
    const r1 = try p1.process(10);
    try testing.expectEqual(@as(i32, 20), r1);

    const NoAlloc = Processor(false);
    var p2 = NoAlloc.init({});
    const r2 = try p2.process(15);
    try testing.expectEqual(@as(i32, 30), r2);
}
```

Fields with type `void` occupy no space, making the non-allocator version truly zero-cost.

### Builder Pattern

Implement fluent builders with optional field setting:

```zig
fn Builder(comptime T: type) type {
    return struct {
        const Self = @This();
        instance: T,

        pub fn init() Self {
            return .{ .instance = std.mem.zeroes(T) };
        }

        pub fn set(self: *Self, comptime field_name: []const u8, value: anytype) *Self {
            @field(self.instance, field_name) = value;
            return self;
        }

        pub fn build(self: Self) T {
            return self.instance;
        }
    };
}

const Config = struct {
    name: []const u8 = "",
    value: i32 = 0,
    enabled: bool = false,
};

test "builder pattern" {
    var builder = Builder(Config).init();
    const config = builder
        .set("name", "test")
        .set("value", 42)
        .build();

    try testing.expectEqualStrings("test", config.name);
    try testing.expectEqual(@as(i32, 42), config.value);
    try testing.expect(!config.enabled); // Uses default
}
```

The builder returns `*Self` to enable method chaining. Fields not explicitly set retain their default values.

### Conditional Fields

Include fields only when needed:

```zig
fn Record(comptime has_id: bool, comptime has_timestamp: bool) type {
    return struct {
        const Self = @This();

        id: if (has_id) u64 else void = if (has_id) 0 else {},
        timestamp: if (has_timestamp) u64 else void = if (has_timestamp) 0 else {},
        data: []const u8,

        pub fn init(data: []const u8, opts: anytype) Self {
            var result: Self = undefined;
            result.data = data;

            if (has_id) {
                if (@hasField(@TypeOf(opts), "id")) {
                    result.id = opts.id;
                } else {
                    result.id = 0;
                }
            } else {
                result.id = {};
            }

            if (has_timestamp) {
                if (@hasField(@TypeOf(opts), "timestamp")) {
                    result.timestamp = opts.timestamp;
                } else {
                    result.timestamp = 0;
                }
            } else {
                result.timestamp = {};
            }

            return result;
        }

        pub fn hasID() bool {
            return has_id;
        }

        pub fn hasTimestamp() bool {
            return has_timestamp;
        }
    };
}

test "conditional fields" {
    const Full = Record(true, true);
    const r1 = Full.init("data", .{ .id = 123, .timestamp = 456 });
    try testing.expectEqual(@as(u64, 123), r1.id);

    const Minimal = Record(false, false);
    const r2 = Minimal.init("data", .{});
    try testing.expectEqualStrings("data", r2.data);
    try testing.expect(!Minimal.hasID());
}
```

This creates completely different struct layouts based on compile-time parameters.

### Default Type Arguments

Provide defaults for type-level parameters:

```zig
fn createArray(comptime T: type, comptime size: usize, comptime default_value: T) [size]T {
    var arr: [size]T = undefined;
    for (&arr) |*item| {
        item.* = default_value;
    }
    return arr;
}

fn createArrayOpt(comptime T: type, comptime opts: struct {
    size: usize = 5,
    default_value: T = 0,
}) [opts.size]T {
    var arr: [opts.size]T = undefined;
    for (&arr) |*item| {
        item.* = opts.default_value;
    }
    return arr;
}

test "default args" {
    const arr1 = createArrayOpt(i32, .{});
    try testing.expectEqual(@as(usize, 5), arr1.len);

    const arr2 = createArrayOpt(i32, .{ .size = 3, .default_value = 10 });
    try testing.expectEqual(@as(usize, 3), arr2.len);
    try testing.expectEqual(@as(i32, 10), arr2[0]);
}
```

The struct parameter allows named defaults while maintaining type safety.

### Optional Callback

Conditionally include callback functionality:

```zig
fn Transform(comptime has_callback: bool) type {
    return struct {
        const Self = @This();
        const Callback = if (has_callback) *const fn (i32) i32 else void;

        callback: Callback,
        multiplier: i32,

        pub fn init(multiplier: i32, callback: anytype) Self {
            if (has_callback) {
                return .{
                    .callback = callback,
                    .multiplier = multiplier,
                };
            } else {
                return .{
                    .callback = {},
                    .multiplier = multiplier,
                };
            }
        }

        pub fn process(self: Self, value: i32) i32 {
            const result = value * self.multiplier;
            if (has_callback) {
                return self.callback(result);
            }
            return result;
        }
    };
}

fn addTen(x: i32) i32 {
    return x + 10;
}

test "optional callback" {
    const WithCallback = Transform(true);
    const t1 = WithCallback.init(2, addTen);
    const r1 = t1.process(5);
    try testing.expectEqual(@as(i32, 20), r1); // (5 * 2) + 10

    const NoCallback = Transform(false);
    const t2 = NoCallback.init(3, {});
    const r2 = t2.process(5);
    try testing.expectEqual(@as(i32, 15), r2); // 5 * 3
}
```

The callback type is `void` when not needed, eliminating storage overhead.

### Optional Error Type

Choose between fallible and infallible operations:

```zig
fn Operation(comptime can_fail: bool) type {
    return struct {
        const Self = @This();
        const Error = if (can_fail) error{OperationFailed} else void;
        const Result = if (can_fail) Error!i32 else i32;

        value: i32,

        pub fn init(value: i32) Self {
            return .{ .value = value };
        }

        pub fn execute(self: Self) Result {
            if (can_fail) {
                if (self.value < 0) {
                    return error.OperationFailed;
                }
                return self.value * 2;
            }
            return self.value * 2;
        }
    };
}

test "optional error type" {
    const Fallible = Operation(true);
    const op1 = Fallible.init(10);
    const r1 = try op1.execute();
    try testing.expectEqual(@as(i32, 20), r1);

    const Infallible = Operation(false);
    const op3 = Infallible.init(-5);
    const r3 = op3.execute();
    try testing.expectEqual(@as(i32, -10), r3); // No error checking needed
}
```

Infallible operations return plain `i32`, avoiding the overhead of error handling.

### Optional Constraints

Validate values against optional bounds:

```zig
fn Validator(comptime T: type, comptime opts: struct {
    min_value: ?T = null,
    max_value: ?T = null,
    allow_zero: bool = true,
}) type {
    return struct {
        pub fn validate(value: T) bool {
            if (opts.min_value) |min| {
                if (value < min) return false;
            }
            if (opts.max_value) |max| {
                if (value > max) return false;
            }
            if (!opts.allow_zero and value == 0) {
                return false;
            }
            return true;
        }
    };
}

test "optional constraints" {
    const NoConstraints = Validator(i32, .{});
    try testing.expect(NoConstraints.validate(100));

    const Range = Validator(i32, .{ .min_value = 0, .max_value = 100 });
    try testing.expect(Range.validate(50));
    try testing.expect(!Range.validate(101));

    const NoZero = Validator(i32, .{ .allow_zero = false });
    try testing.expect(!NoZero.validate(0));
}
```

Optional values use `?T` to indicate constraints that may or may not be present.

### Feature Flags

Enable or disable features at compile time:

```zig
fn Wrapper(comptime T: type, comptime features: struct {
    logging: bool = false,
    validation: bool = false,
    caching: bool = false,
}) type {
    return struct {
        const Self = @This();
        value: T,
        log_count: if (features.logging) u32 else void = if (features.logging) 0 else {},
        is_valid: if (features.validation) bool else void = if (features.validation) true else {},
        cached: if (features.caching) ?T else void = if (features.caching) null else {},

        pub fn init(value: T) Self {
            var result: Self = undefined;
            result.value = value;
            if (features.logging) result.log_count = 0;
            if (features.validation) result.is_valid = true;
            if (features.caching) result.cached = null;
            return result;
        }

        pub fn get(self: *Self) T {
            if (features.logging) {
                self.log_count += 1;
            }
            if (features.caching) {
                if (self.cached) |cached| {
                    return cached;
                }
                self.cached = self.value;
            }
            return self.value;
        }
    };
}

test "optional wrapper" {
    const AllFeatures = Wrapper(i32, .{ .logging = true, .caching = true });
    var w1 = AllFeatures.init(42);
    try testing.expectEqual(@as(i32, 42), w1.get());
    try testing.expectEqual(@as(u32, 1), w1.log_count);

    const NoFeatures = Wrapper(i32, .{});
    var w2 = NoFeatures.init(10);
    try testing.expectEqual(@as(i32, 10), w2.get());
}
```

Disabled features compile away entirely, including their fields and logic.

### When to Use Optional Arguments

These patterns are valuable when:

1. **Sensible defaults exist** - Most users can use defaults, but some need customization
2. **Configuration grows over time** - New options can be added without breaking existing code
3. **Zero-cost abstractions matter** - Unused features should impose no runtime cost
4. **Type safety is critical** - Compile-time validation prevents configuration errors
5. **API evolution is important** - Optional parameters allow backward-compatible changes

### Design Considerations

**Struct Parameters vs Multiple Functions:**
Using struct parameters with defaults is more maintainable than creating multiple function variants:

```zig
// Good: Single function with optional config
fn process(value: i32, config: struct { multiplier: i32 = 2 }) i32

// Avoid: Multiple functions for each combination
fn process(value: i32) i32
fn processWithMultiplier(value: i32, multiplier: i32) i32
```

**Compile-Time vs Runtime Optionality:**
- Use `comptime` parameters when the choice affects type structure or can be resolved at compile time
- Use `?T` (optional types) when the choice must be made at runtime
- Prefer compile-time when possible for better optimization

**Named vs Positional Parameters:**
Struct parameters provide named arguments, improving readability:

```zig
// Clear what each value means
const r = process(10, .{ .multiplier = 3, .offset = 5 });

// Unclear without looking at function signature
const r = process(10, 3, 5);
```

The pattern trades a small amount of syntax for significant gains in maintainability.

## See Also

- Recipe 9.11: Using comptime to control instance creation
- Recipe 9.14: Enforcing an argument signature on tuple arguments
- Recipe 9.15: Enforcing coding conventions in structs

Full compilable example: `code/03-advanced/09-metaprogramming/recipe_9_13.zig`
