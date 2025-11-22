// Recipe 9.13: Defining a Generic That Takes Optional Arguments
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: optional_type_param
// Generic with optional type parameter using struct defaults
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
                // Note: Actual resizing would require an allocator parameter.
                // The 'resizable' option is kept for demonstration purposes.
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
    try c2.append(20);
    try testing.expectEqual(@as(usize, 5), CustomContainer.getCapacity());
}
// ANCHOR_END: optional_type_param

// ANCHOR: optional_config
// Function with optional configuration struct
fn process(value: i32, config: struct {
    multiplier: i32 = 2,
    offset: i32 = 0,
    enabled: bool = true,
}) i32 {
    if (!config.enabled) return value;
    return (value * config.multiplier) + config.offset;
}

test "optional config" {
    // All defaults
    const r1 = process(10, .{});
    try testing.expectEqual(@as(i32, 20), r1);

    // Partial override
    const r2 = process(10, .{ .multiplier = 3 });
    try testing.expectEqual(@as(i32, 30), r2);

    // Full override
    const r3 = process(10, .{ .multiplier = 5, .offset = 10, .enabled = true });
    try testing.expectEqual(@as(i32, 60), r3);

    // Disabled
    const r4 = process(10, .{ .enabled = false });
    try testing.expectEqual(@as(i32, 10), r4);
}
// ANCHOR_END: optional_config

// ANCHOR: variadic_tuple
// Process variable number of arguments via tuple
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

    // Allocate buffer
    const buffer = try allocator.alloc(u8, total_len);
    errdefer allocator.free(buffer);

    // Copy strings
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

    const r3 = sum(.{ 10, 20, 30, 40 });
    try testing.expectEqual(@as(i32, 100), r3);

    const s1 = try concat(testing.allocator, .{"hello"});
    defer testing.allocator.free(s1);
    try testing.expectEqualStrings("hello", s1);

    const s2 = try concat(testing.allocator, .{ "hello", " ", "world" });
    defer testing.allocator.free(s2);
    try testing.expectEqualStrings("hello world", s2);
}
// ANCHOR_END: variadic_tuple

// ANCHOR: optional_allocator
// Generic with optional allocator
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
                return value * 2;
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
    try testing.expect(WithAlloc.needsAllocator());

    const NoAlloc = Processor(false);
    var p2 = NoAlloc.init({});
    defer p2.deinit();
    const r2 = try p2.process(15);
    try testing.expectEqual(@as(i32, 30), r2);
    try testing.expect(!NoAlloc.needsAllocator());
}
// ANCHOR_END: optional_allocator

// ANCHOR: builder_pattern
// Builder with optional fields
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
// ANCHOR_END: builder_pattern

// ANCHOR: conditional_fields
// Type with conditionally included fields
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
    try testing.expectEqual(@as(u64, 456), r1.timestamp);
    try testing.expect(Full.hasID());
    try testing.expect(Full.hasTimestamp());

    const Minimal = Record(false, false);
    const r2 = Minimal.init("data", .{});
    try testing.expectEqualStrings("data", r2.data);
    try testing.expect(!Minimal.hasID());
    try testing.expect(!Minimal.hasTimestamp());
}
// ANCHOR_END: conditional_fields

// ANCHOR: default_args
// Generic function with default type arguments
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
    const arr1 = createArray(i32, 3, 0);
    try testing.expectEqual(@as(usize, 3), arr1.len);
    try testing.expectEqual(@as(i32, 0), arr1[0]);

    const arr2 = createArrayOpt(i32, .{});
    try testing.expectEqual(@as(usize, 5), arr2.len);

    const arr3 = createArrayOpt(i32, .{ .size = 3, .default_value = 10 });
    try testing.expectEqual(@as(usize, 3), arr3.len);
    try testing.expectEqual(@as(i32, 10), arr3[0]);
}
// ANCHOR_END: default_args

// ANCHOR: optional_callback
// Generic with optional callback
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
// ANCHOR_END: optional_callback

// ANCHOR: optional_error_type
// Generic with optional error type
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

    const op2 = Fallible.init(-5);
    const r2 = op2.execute();
    try testing.expectError(error.OperationFailed, r2);

    const Infallible = Operation(false);
    const op3 = Infallible.init(-5);
    const r3 = op3.execute();
    try testing.expectEqual(@as(i32, -10), r3);
}
// ANCHOR_END: optional_error_type

// ANCHOR: optional_constraints
// Generic with optional type constraints
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
    try testing.expect(NoConstraints.validate(0));
    try testing.expect(NoConstraints.validate(-100));

    const MinOnly = Validator(i32, .{ .min_value = 10 });
    try testing.expect(MinOnly.validate(10));
    try testing.expect(MinOnly.validate(100));
    try testing.expect(!MinOnly.validate(5));

    const Range = Validator(i32, .{ .min_value = 0, .max_value = 100 });
    try testing.expect(Range.validate(50));
    try testing.expect(!Range.validate(-1));
    try testing.expect(!Range.validate(101));

    const NoZero = Validator(i32, .{ .allow_zero = false });
    try testing.expect(!NoZero.validate(0));
    try testing.expect(NoZero.validate(1));
}
// ANCHOR_END: optional_constraints

// ANCHOR: optional_wrapper
// Generic wrapper with optional features
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

        pub fn hasLogging() bool {
            return features.logging;
        }

        pub fn hasValidation() bool {
            return features.validation;
        }

        pub fn hasCaching() bool {
            return features.caching;
        }
    };
}

test "optional wrapper" {
    const AllFeatures = Wrapper(i32, .{ .logging = true, .validation = true, .caching = true });
    var w1 = AllFeatures.init(42);
    try testing.expectEqual(@as(i32, 42), w1.get());
    try testing.expectEqual(@as(u32, 1), w1.log_count);
    try testing.expect(AllFeatures.hasLogging());
    try testing.expect(AllFeatures.hasValidation());
    try testing.expect(AllFeatures.hasCaching());

    const NoFeatures = Wrapper(i32, .{});
    var w2 = NoFeatures.init(10);
    try testing.expectEqual(@as(i32, 10), w2.get());
    try testing.expect(!NoFeatures.hasLogging());
}
// ANCHOR_END: optional_wrapper

// Comprehensive test
test "comprehensive optional arguments" {
    // Optional config
    const r1 = process(5, .{ .multiplier = 4 });
    try testing.expectEqual(@as(i32, 20), r1);

    // Variadic
    const r2 = sum(.{ 1, 2, 3, 4, 5 });
    try testing.expectEqual(@as(i32, 15), r2);

    // Builder
    var builder = Builder(Config).init();
    const config = builder.set("value", 100).build();
    try testing.expectEqual(@as(i32, 100), config.value);

    // Optional allocator
    const NoAlloc = Processor(false);
    var proc = NoAlloc.init({});
    defer proc.deinit();
    const r3 = try proc.process(7);
    try testing.expectEqual(@as(i32, 14), r3);

    // Optional constraints
    const RangeValidator = Validator(i32, .{ .min_value = 1, .max_value = 10 });
    try testing.expect(RangeValidator.validate(5));
    try testing.expect(!RangeValidator.validate(11));
}
