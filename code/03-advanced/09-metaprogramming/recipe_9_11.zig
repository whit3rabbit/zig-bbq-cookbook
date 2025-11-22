// Recipe 9.11: Using Comptime to Control Instance Creation
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: singleton_pattern
// Enforce singleton pattern at compile time
fn Singleton(comptime T: type) type {
    return struct {
        const Self = @This();
        var instance: ?T = null;
        var initialized: bool = false;

        pub fn getInstance() *T {
            if (!initialized) {
                instance = T{};
                initialized = true;
            }
            return &instance.?;
        }

        pub fn reset() void {
            instance = null;
            initialized = false;
        }
    };
}

const Config = struct {
    value: i32 = 42,
};

test "singleton pattern" {
    const ConfigSingleton = Singleton(Config);

    ConfigSingleton.reset();
    const cfg1 = ConfigSingleton.getInstance();
    cfg1.value = 100;

    const cfg2 = ConfigSingleton.getInstance();
    try testing.expectEqual(@as(i32, 100), cfg2.value);
    try testing.expectEqual(@intFromPtr(cfg1), @intFromPtr(cfg2));
}
// ANCHOR_END: singleton_pattern

// ANCHOR: factory_pattern
// Factory that creates different types based on comptime parameter
fn Factory(comptime kind: enum { Simple, Complex }) type {
    return switch (kind) {
        .Simple => struct {
            value: i32,

            pub fn init(v: i32) @This() {
                return .{ .value = v };
            }

            pub fn getValue(self: @This()) i32 {
                return self.value;
            }
        },
        .Complex => struct {
            value: i32,
            metadata: []const u8,

            pub fn init(v: i32, meta: []const u8) @This() {
                return .{ .value = v, .metadata = meta };
            }

            pub fn getValue(self: @This()) i32 {
                return self.value;
            }

            pub fn getMetadata(self: @This()) []const u8 {
                return self.metadata;
            }
        },
    };
}

test "factory pattern" {
    const Simple = Factory(.Simple);
    const s = Simple.init(10);
    try testing.expectEqual(@as(i32, 10), s.getValue());

    const Complex = Factory(.Complex);
    const c = Complex.init(20, "test");
    try testing.expectEqual(@as(i32, 20), c.getValue());
    try testing.expectEqualStrings("test", c.getMetadata());
}
// ANCHOR_END: factory_pattern

// ANCHOR: validated_init
// Runtime-validated initialization with compile-time type checking
fn ValidatedInit(comptime T: type) type {
    return struct {
        inner: T,

        pub fn init(value: T, comptime validator: anytype) !@This() {
            if (!validator(value)) {
                return error.InvalidValue;
            }
            return .{ .inner = value };
        }

        pub fn get(self: @This()) T {
            return self.inner;
        }
    };
}

fn isPositive(value: i32) bool {
    return value > 0;
}

fn isEven(value: i32) bool {
    return @mod(value, 2) == 0;
}

test "validated init" {
    const ValidatedInt = ValidatedInit(i32);

    const p1 = try ValidatedInt.init(10, isPositive);
    try testing.expectEqual(@as(i32, 10), p1.get());

    const p2 = ValidatedInt.init(-5, isPositive);
    try testing.expectError(error.InvalidValue, p2);

    const even = try ValidatedInt.init(8, isEven);
    try testing.expectEqual(@as(i32, 8), even.get());
}
// ANCHOR_END: validated_init

// ANCHOR: conditional_fields
// Include fields conditionally based on comptime parameters
fn ConditionalFields(comptime has_id: bool, comptime has_timestamp: bool) type {
    return struct {
        const Self = @This();

        id: if (has_id) u64 else void,
        timestamp: if (has_timestamp) u64 else void,
        value: i32,

        pub fn init(value: i32) Self {
            return .{
                .id = if (has_id) 0 else {},
                .timestamp = if (has_timestamp) 0 else {},
                .value = value,
            };
        }

        pub fn getValue(self: Self) i32 {
            return self.value;
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
    const WithBoth = ConditionalFields(true, true);
    const both = WithBoth.init(42);
    try testing.expectEqual(@as(i32, 42), both.getValue());
    try testing.expect(WithBoth.hasID());
    try testing.expect(WithBoth.hasTimestamp());

    const WithID = ConditionalFields(true, false);
    _ = WithID.init(10);
    try testing.expect(WithID.hasID());
    try testing.expect(!WithID.hasTimestamp());

    const Plain = ConditionalFields(false, false);
    _ = Plain.init(5);
    try testing.expect(!Plain.hasID());
    try testing.expect(!Plain.hasTimestamp());
}
// ANCHOR_END: conditional_fields

// ANCHOR: resource_pool
// Compile-time resource pool
fn Pool(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();
        items: [capacity]?T = [_]?T{null} ** capacity,
        count: usize = 0,

        pub fn init() Self {
            return .{};
        }

        pub fn acquire(self: *Self, value: T) !usize {
            if (self.count >= capacity) return error.PoolExhausted;

            for (self.items, 0..) |item, i| {
                if (item == null) {
                    self.items[i] = value;
                    self.count += 1;
                    return i;
                }
            }
            unreachable;
        }

        pub fn release(self: *Self, index: usize) void {
            if (index < capacity and self.items[index] != null) {
                self.items[index] = null;
                self.count -= 1;
            }
        }

        pub fn getCapacity() usize {
            return capacity;
        }

        pub fn getCount(self: Self) usize {
            return self.count;
        }
    };
}

test "resource pool" {
    const IntPool = Pool(i32, 5);
    var pool = IntPool.init();

    try testing.expectEqual(@as(usize, 5), IntPool.getCapacity());

    const idx1 = try pool.acquire(10);
    const idx2 = try pool.acquire(20);
    try testing.expectEqual(@as(usize, 2), pool.getCount());

    pool.release(idx1);
    try testing.expectEqual(@as(usize, 1), pool.getCount());

    pool.release(idx2);
    try testing.expectEqual(@as(usize, 0), pool.getCount());
}
// ANCHOR_END: resource_pool

// ANCHOR: builder_generation
// Generate builder pattern at compile time
fn Builder(comptime T: type) type {
    return struct {
        const Self = @This();
        instance: T,

        pub fn init() Self {
            return .{ .instance = std.mem.zeroes(T) };
        }

        pub fn set(self: *Self, value: T) void {
            self.instance = value;
        }

        pub fn build(self: Self) T {
            return self.instance;
        }

        pub fn getFieldCount() usize {
            return @typeInfo(T).@"struct".fields.len;
        }

        pub fn hasField(comptime name: []const u8) bool {
            const fields = @typeInfo(T).@"struct".fields;
            inline for (fields) |field| {
                if (std.mem.eql(u8, field.name, name)) {
                    return true;
                }
            }
            return false;
        }
    };
}

const Person = struct {
    name: []const u8 = "",
    age: u32 = 0,
};

test "builder generation" {
    const PersonBuilder = Builder(Person);
    var builder = PersonBuilder.init();
    builder.instance.name = "Alice";
    builder.instance.age = 30;

    const person = builder.build();
    try testing.expectEqualStrings("Alice", person.name);
    try testing.expectEqual(@as(u32, 30), person.age);

    try testing.expectEqual(@as(usize, 2), PersonBuilder.getFieldCount());
    try testing.expect(PersonBuilder.hasField("name"));
    try testing.expect(!PersonBuilder.hasField("invalid"));
}
// ANCHOR_END: builder_generation

// ANCHOR: type_registry
// Compile-time type registry
fn TypeRegistry(comptime types: []const type) type {
    return struct {
        pub fn getCount() usize {
            return types.len;
        }

        pub fn getType(comptime index: usize) type {
            if (index >= types.len) {
                @compileError("Index out of bounds");
            }
            return types[index];
        }

        pub fn hasType(comptime T: type) bool {
            inline for (types) |t| {
                if (t == T) return true;
            }
            return false;
        }

        pub fn indexOf(comptime T: type) ?usize {
            inline for (types, 0..) |t, i| {
                if (t == T) return i;
            }
            return null;
        }
    };
}

test "type registry" {
    const Registry = TypeRegistry(&[_]type{ i32, u32, f32, bool });

    try testing.expectEqual(@as(usize, 4), Registry.getCount());
    try testing.expect(Registry.getType(0) == i32);
    try testing.expect(Registry.hasType(u32));
    try testing.expect(!Registry.hasType(i64));
    try testing.expectEqual(@as(?usize, 2), Registry.indexOf(f32));
    try testing.expectEqual(@as(?usize, null), Registry.indexOf(i64));
}
// ANCHOR_END: type_registry

// ANCHOR: lazy_static
// Compile-time lazy initialization
fn LazyStatic(comptime init_fn: anytype) type {
    return struct {
        const T = @TypeOf(init_fn());
        var value: ?T = null;
        var is_initialized: bool = false;

        pub fn get() *const T {
            if (!is_initialized) {
                value = init_fn();
                is_initialized = true;
            }
            return &value.?;
        }

        pub fn reset() void {
            value = null;
            is_initialized = false;
        }
    };
}

fn createDefaultConfig() Config {
    return .{ .value = 999 };
}

test "lazy static" {
    const DefaultConfig = LazyStatic(createDefaultConfig);

    DefaultConfig.reset();
    const cfg1 = DefaultConfig.get();
    try testing.expectEqual(@as(i32, 999), cfg1.value);

    const cfg2 = DefaultConfig.get();
    try testing.expectEqual(@intFromPtr(cfg1), @intFromPtr(cfg2));
}
// ANCHOR_END: lazy_static

// ANCHOR: variant_creation
// Create variants based on comptime enum
fn Variant(comptime shape: enum { Circle, Rectangle, Triangle }) type {
    return switch (shape) {
        .Circle => struct {
            radius: f32,

            pub fn init(r: f32) @This() {
                return .{ .radius = r };
            }

            pub fn area(self: @This()) f32 {
                return 3.14159 * self.radius * self.radius;
            }
        },
        .Rectangle => struct {
            width: f32,
            height: f32,

            pub fn init(w: f32, h: f32) @This() {
                return .{ .width = w, .height = h };
            }

            pub fn area(self: @This()) f32 {
                return self.width * self.height;
            }
        },
        .Triangle => struct {
            base: f32,
            height: f32,

            pub fn init(b: f32, h: f32) @This() {
                return .{ .base = b, .height = h };
            }

            pub fn area(self: @This()) f32 {
                return 0.5 * self.base * self.height;
            }
        },
    };
}

test "variant creation" {
    const Circle = Variant(.Circle);
    const c = Circle.init(5.0);
    try testing.expect(c.area() > 78.0 and c.area() < 79.0);

    const Rectangle = Variant(.Rectangle);
    const r = Rectangle.init(4.0, 5.0);
    try testing.expectEqual(@as(f32, 20.0), r.area());

    const Triangle = Variant(.Triangle);
    const t = Triangle.init(6.0, 4.0);
    try testing.expectEqual(@as(f32, 12.0), t.area());
}
// ANCHOR_END: variant_creation

// ANCHOR: capability_injection
// Inject capabilities based on comptime flags
fn WithCapabilities(comptime T: type, comptime capabilities: struct {
    serializable: bool = false,
    comparable: bool = false,
    cloneable: bool = false,
}) type {
    return struct {
        const Self = @This();
        inner: T,

        pub fn init(inner: T) Self {
            return .{ .inner = inner };
        }

        pub fn get(self: Self) T {
            return self.inner;
        }

        pub fn serialize(self: Self) []const u8 {
            if (!capabilities.serializable) {
                @compileError("Serialization not enabled");
            }
            _ = self;
            return "serialized";
        }

        pub fn equals(self: Self, other: Self) bool {
            if (!capabilities.comparable) {
                @compileError("Comparison not enabled");
            }
            _ = self;
            _ = other;
            return false;
        }

        pub fn clone(self: Self) Self {
            if (!capabilities.cloneable) {
                @compileError("Cloning not enabled");
            }
            return .{ .inner = self.inner };
        }

        pub fn hasSerializable() bool {
            return capabilities.serializable;
        }

        pub fn hasComparable() bool {
            return capabilities.comparable;
        }

        pub fn hasCloneable() bool {
            return capabilities.cloneable;
        }
    };
}

test "capability injection" {
    const AllCapabilities = WithCapabilities(i32, .{
        .serializable = true,
        .comparable = true,
        .cloneable = true,
    });

    try testing.expect(AllCapabilities.hasSerializable());
    try testing.expect(AllCapabilities.hasComparable());
    try testing.expect(AllCapabilities.hasCloneable());

    const v1 = AllCapabilities.init(42);
    try testing.expectEqualStrings("serialized", v1.serialize());
    try testing.expect(!v1.equals(v1));
    const v2 = v1.clone();
    try testing.expectEqual(@as(i32, 42), v2.get());

    const OnlySerializable = WithCapabilities(i32, .{ .serializable = true });
    const s = OnlySerializable.init(10);
    try testing.expectEqualStrings("serialized", s.serialize());
    try testing.expect(OnlySerializable.hasSerializable());
    try testing.expect(!OnlySerializable.hasCloneable());
    // s.clone() would fail at compile time with appropriate error
}
// ANCHOR_END: capability_injection

// ANCHOR: constrained_init
// Constrain initialization based on type properties
fn Constrained(comptime T: type, comptime constraint: fn (type) bool) type {
    if (!constraint(T)) {
        @compileError("Type does not meet constraint");
    }

    return struct {
        value: T,

        pub fn init(v: T) @This() {
            return .{ .value = v };
        }

        pub fn get(self: @This()) T {
            return self.value;
        }
    };
}

fn isNumeric(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .int, .float => true,
        else => false,
    };
}

test "constrained init" {
    const NumericInt = Constrained(i32, isNumeric);
    const n = NumericInt.init(42);
    try testing.expectEqual(@as(i32, 42), n.get());

    // This would fail at compile time:
    // const InvalidType = Constrained(bool, isNumeric);
}
// ANCHOR_END: constrained_init

// Comprehensive test
test "comprehensive comptime instance creation" {
    // Singleton
    const SingletonConfig = Singleton(Config);
    SingletonConfig.reset();
    const cfg = SingletonConfig.getInstance();
    try testing.expectEqual(@as(i32, 42), cfg.value);

    // Factory
    const SimpleFactory = Factory(.Simple);
    const simple = SimpleFactory.init(100);
    try testing.expectEqual(@as(i32, 100), simple.getValue());

    // Conditional fields
    const Minimal = ConditionalFields(false, false);
    const m = Minimal.init(15);
    try testing.expectEqual(@as(i32, 15), m.getValue());

    // Pool
    const SmallPool = Pool(i32, 3);
    var pool = SmallPool.init();
    _ = try pool.acquire(1);
    _ = try pool.acquire(2);
    try testing.expectEqual(@as(usize, 2), pool.getCount());

    // Variant
    const Rect = Variant(.Rectangle);
    const rect = Rect.init(10.0, 5.0);
    try testing.expectEqual(@as(f32, 50.0), rect.area());
}
