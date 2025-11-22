## Problem

You want to control instance creation at compile time, enforcing patterns like singletons, factories, or resource pools. You need to generate different types based on compile-time parameters, validate initialization, or include/exclude fields conditionally.

## Solution

Use `comptime` parameters and compile-time evaluation to generate types with specific instance creation behavior. Zig's compile-time execution allows you to make decisions about type structure and initialization before the program runs.

### Singleton Pattern

Enforce single-instance behavior at compile time:

```zig
{{#include ../../../code/03-advanced/09-metaprogramming/recipe_9_11.zig:singleton_pattern}}
```

The singleton is generated at compile time, with static storage for the single instance.

### Factory Pattern

Create different types based on compile-time enum values:

```zig
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
```

Each factory variant generates a completely different type with its own structure and methods.

## Discussion

### Runtime Validation with Compile-Time Types

While you can't validate runtime values at compile time, you can create types that enforce validation:

```zig
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
```

The validator is a compile-time parameter, allowing different validation logic for each usage.

### Conditional Fields

Include or exclude fields based on compile-time flags:

```zig
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

    const Plain = ConditionalFields(false, false);
    _ = Plain.init(5);
    try testing.expect(!Plain.hasID());
    try testing.expect(!Plain.hasTimestamp());
}
```

Fields with type `void` occupy no space, making this truly zero-cost.

### Resource Pools

Create fixed-size resource pools at compile time:

```zig
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
}
```

The array size is determined at compile time, with no runtime allocation.

### Builder Pattern Generation

Generate builders that introspect the target type:

```zig
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

    try testing.expectEqual(@as(usize, 2), PersonBuilder.getFieldCount());
    try testing.expect(PersonBuilder.hasField("name"));
    try testing.expect(!PersonBuilder.hasField("invalid"));
}
```

The builder uses `@typeInfo` to inspect fields at compile time.

### Type Registry

Create compile-time type collections:

```zig
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
}
```

All type lookups happen at compile time with no runtime cost.

### Lazy Static Initialization

Initialize static values lazily:

```zig
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
```

The initialization function runs at most once, on first access.

### Variant Types

Generate different struct types based on an enum:

```zig
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
}
```

Each variant is a completely different type with its own fields and implementations.

### Capability Injection

Selectively add methods based on compile-time flags:

```zig
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

        pub fn clone(self: Self) Self {
            if (!capabilities.cloneable) {
                @compileError("Cloning not enabled");
            }
            return .{ .inner = self.inner };
        }

        pub fn hasSerializable() bool {
            return capabilities.serializable;
        }
    };
}

test "capability injection" {
    const AllCapabilities = WithCapabilities(i32, .{
        .serializable = true,
        .comparable = true,
        .cloneable = true,
    });

    const v1 = AllCapabilities.init(42);
    try testing.expectEqualStrings("serialized", v1.serialize());
    const v2 = v1.clone();
    try testing.expectEqual(@as(i32, 42), v2.get());
}
```

Calling a disabled capability produces a compile error.

### Type Constraints

Enforce constraints on the types that can be used:

```zig
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
```

The constraint function runs at compile time, rejecting invalid types before code generation.

### When to Use These Patterns

Compile-time instance creation control is valuable when you need to:

1. **Enforce design patterns** like singletons or factories at the type level
2. **Generate type variants** based on compile-time parameters
3. **Optimize for specific use cases** by including only needed fields
4. **Create domain-specific types** with compile-time validation
5. **Build type-safe APIs** that prevent misuse at compile time

The key advantage is that all decisions happen during compilation, resulting in zero runtime overhead compared to hand-written alternatives.

## See Also

- Recipe 9.10: Using decorators to patch struct definitions
- Recipe 9.13: Defining a generic that takes optional arguments
- Recipe 9.15: Enforcing coding conventions in structs

Full compilable example: `code/03-advanced/09-metaprogramming/recipe_9_11.zig`
