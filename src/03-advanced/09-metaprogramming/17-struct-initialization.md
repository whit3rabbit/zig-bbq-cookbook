## Problem

You need to initialize struct members with sensible defaults, provide flexible initialization options, or create instances with different preset configurations. You want to avoid repetitive initialization code, support partial initialization, and provide clean APIs for struct creation.

## Solution

Zig offers multiple approaches for struct initialization: default field values, init functions, builder patterns, factory methods, and compile-time defaults. Each pattern suits different use cases and complexity levels.

### Default Field Values

The simplest approach assigns default values directly in the struct definition:

```zig
{{#include ../../../code/03-advanced/09-metaprogramming/recipe_9_17.zig:default_values}}
```

Creating an instance with `Config{}` uses all defaults. This works well for simple configuration structs.

### Partial Initialization

Override specific defaults while keeping others:

```zig
test "partial initialization" {
    const config = Config{
        .port = 3000,
    };

    try testing.expectEqualStrings("localhost", config.host);
    try testing.expectEqual(@as(u16, 3000), config.port);
    try testing.expectEqual(@as(u32, 30), config.timeout);
}
```

Only the port changes; other fields use their defaults.

## Discussion

### Init Functions

For structs without defaults, provide named initialization functions:

```zig
const Point = struct {
    x: f32,
    y: f32,

    pub fn init() Point {
        return .{
            .x = 0.0,
            .y = 0.0,
        };
    }

    pub fn initAt(x: f32, y: f32) Point {
        return .{
            .x = x,
            .y = y,
        };
    }
};

test "init function" {
    const origin = Point.init();
    try testing.expectEqual(@as(f32, 0.0), origin.x);
    try testing.expectEqual(@as(f32, 0.0), origin.y);

    const point = Point.initAt(10.0, 20.0);
    try testing.expectEqual(@as(f32, 10.0), point.x);
    try testing.expectEqual(@as(f32, 20.0), point.y);
}
```

This pattern provides semantic names for different initialization scenarios.

### Compile-Time Default Generation

Generate defaults programmatically using reflection:

```zig
fn createDefaults(comptime T: type) T {
    var result: T = undefined;
    const fields = @typeInfo(T).@"struct".fields;

    inline for (fields) |field| {
        const default_val = switch (@typeInfo(field.type)) {
            .int => @as(field.type, 0),
            .float => @as(field.type, 0.0),
            .bool => false,
            .pointer => |ptr| switch (ptr.size) {
                .one => @compileError("Cannot create default for single-item pointer"),
                .many, .c => @compileError("Cannot create default for many-item pointer"),
                .slice => @as(field.type, &[_]u8{}),
            },
            else => @compileError("Unsupported type for default value"),
        };
        @field(result, field.name) = default_val;
    }

    return result;
}

test "comptime defaults" {
    const Data = struct {
        count: i32,
        value: f64,
        active: bool,
    };

    const defaults = comptime createDefaults(Data);

    try testing.expectEqual(@as(i32, 0), defaults.count);
    try testing.expectEqual(@as(f64, 0.0), defaults.value);
    try testing.expect(!defaults.active);
}
```

This demonstrates compile-time introspection to generate zero values for any compatible struct.

### Builder Pattern

Implement fluent initialization with method chaining:

```zig
const ServerConfig = struct {
    host: []const u8 = "localhost",
    port: u16 = 8080,
    max_connections: u32 = 100,
    timeout_seconds: u32 = 30,
    enable_logging: bool = true,

    pub fn builder() ServerConfig {
        return .{};
    }

    pub fn withHost(self: ServerConfig, host: []const u8) ServerConfig {
        var result = self;
        result.host = host;
        return result;
    }

    pub fn withPort(self: ServerConfig, port: u16) ServerConfig {
        var result = self;
        result.port = port;
        return result;
    }

    pub fn withMaxConnections(self: ServerConfig, max: u32) ServerConfig {
        var result = self;
        result.max_connections = max;
        return result;
    }
};

test "builder pattern" {
    const config = ServerConfig.builder()
        .withHost("example.com")
        .withPort(9000)
        .withMaxConnections(500);

    try testing.expectEqualStrings("example.com", config.host);
    try testing.expectEqual(@as(u16, 9000), config.port);
    try testing.expectEqual(@as(u32, 500), config.max_connections);
    try testing.expectEqual(@as(u32, 30), config.timeout_seconds);
    try testing.expect(config.enable_logging);
}
```

The builder pattern works well for complex configurations with many optional fields.

### Computed Defaults

Use factory methods to compute related values:

```zig
const Rectangle = struct {
    width: f32,
    height: f32,

    pub fn init(width: f32, height: f32) Rectangle {
        return .{
            .width = width,
            .height = height,
        };
    }

    pub fn square(side: f32) Rectangle {
        return .{
            .width = side,
            .height = side,
        };
    }

    pub fn area(self: Rectangle) f32 {
        return self.width * self.height;
    }
};

test "computed defaults" {
    const rect = Rectangle.init(10.0, 5.0);
    try testing.expectEqual(@as(f32, 50.0), rect.area());

    const sq = Rectangle.square(7.0);
    try testing.expectEqual(@as(f32, 49.0), sq.area());
}
```

The `square` factory method computes both dimensions from a single parameter.

### Optional Fields

Use null defaults for optional configuration:

```zig
const User = struct {
    id: u64,
    name: []const u8,
    email: ?[]const u8 = null,
    phone: ?[]const u8 = null,

    pub fn init(id: u64, name: []const u8) User {
        return .{
            .id = id,
            .name = name,
        };
    }

    pub fn withEmail(self: User, email: []const u8) User {
        var result = self;
        result.email = email;
        return result;
    }
};

test "optional fields" {
    const user1 = User.init(1, "Alice");
    try testing.expectEqual(@as(u64, 1), user1.id);
    try testing.expectEqualStrings("Alice", user1.name);
    try testing.expectEqual(@as(?[]const u8, null), user1.email);

    const user2 = user1.withEmail("alice@example.com");
    try testing.expectEqualStrings("alice@example.com", user2.email.?);
}
```

Optional fields with null defaults support incremental configuration.

### Enum-Based Configuration

Use enums to create named configuration profiles:

```zig
const LogLevel = enum {
    debug,
    info,
    warn,
    err,
};

const Logger = struct {
    level: LogLevel = .info,
    timestamp: bool = true,
    color: bool = false,

    pub fn init() Logger {
        return .{};
    }

    pub fn debug() Logger {
        return .{ .level = .debug };
    }

    pub fn production() Logger {
        return .{
            .level = .warn,
            .timestamp = true,
            .color = false,
        };
    }
};

test "enum defaults" {
    const default_logger = Logger.init();
    try testing.expectEqual(LogLevel.info, default_logger.level);
    try testing.expect(default_logger.timestamp);
    try testing.expect(!default_logger.color);

    const debug_logger = Logger.debug();
    try testing.expectEqual(LogLevel.debug, debug_logger.level);

    const prod_logger = Logger.production();
    try testing.expectEqual(LogLevel.warn, prod_logger.level);
}
```

Named factory methods provide semantic initialization for different environments.

### Array Defaults

Initialize array fields with repetition syntax:

```zig
const Matrix3x3 = struct {
    data: [9]f32 = [_]f32{0.0} ** 9,

    pub fn identity() Matrix3x3 {
        return .{
            .data = [_]f32{
                1.0, 0.0, 0.0,
                0.0, 1.0, 0.0,
                0.0, 0.0, 1.0,
            },
        };
    }

    pub fn get(self: Matrix3x3, row: usize, col: usize) f32 {
        return self.data[row * 3 + col];
    }
};

test "array defaults" {
    const zero_matrix = Matrix3x3{};
    try testing.expectEqual(@as(f32, 0.0), zero_matrix.get(0, 0));
    try testing.expectEqual(@as(f32, 0.0), zero_matrix.get(1, 1));

    const identity = Matrix3x3.identity();
    try testing.expectEqual(@as(f32, 1.0), identity.get(0, 0));
    try testing.expectEqual(@as(f32, 1.0), identity.get(1, 1));
    try testing.expectEqual(@as(f32, 1.0), identity.get(2, 2));
    try testing.expectEqual(@as(f32, 0.0), identity.get(0, 1));
}
```

The `** 9` syntax repeats the value 9 times to fill the array.

### Nested Defaults

Struct defaults cascade to nested structs:

```zig
const Address = struct {
    street: []const u8 = "",
    city: []const u8 = "",
    country: []const u8 = "USA",
};

const Person = struct {
    name: []const u8,
    age: u32 = 0,
    address: Address = .{},

    pub fn init(name: []const u8) Person {
        return .{
            .name = name,
        };
    }
};

test "nested defaults" {
    const person = Person.init("Bob");

    try testing.expectEqualStrings("Bob", person.name);
    try testing.expectEqual(@as(u32, 0), person.age);
    try testing.expectEqualStrings("", person.address.street);
    try testing.expectEqualStrings("USA", person.address.country);
}
```

The `address: Address = .{}` syntax creates a nested struct using its defaults.

### Compile-Time Struct Initialization

Create structs with compile-time constant fields:

```zig
fn createComptimeStruct(comptime name: []const u8, comptime value: i32) type {
    return struct {
        const config_name = name;
        const config_value = value;
        data: i32 = value,

        pub fn init() @This() {
            return .{};
        }
    };
}

test "comptime initialization" {
    const MyStruct = createComptimeStruct("test", 42);

    try testing.expectEqualStrings("test", MyStruct.config_name);
    try testing.expectEqual(@as(i32, 42), MyStruct.config_value);

    const instance = MyStruct.init();
    try testing.expectEqual(@as(i32, 42), instance.data);
}
```

This pattern generates struct types with embedded constants at compile time.

### Factory Pattern

Provide preset configurations through named factory methods:

```zig
const Connection = struct {
    host: []const u8,
    port: u16,
    secure: bool,
    timeout: u32,

    pub fn local() Connection {
        return .{
            .host = "localhost",
            .port = 8080,
            .secure = false,
            .timeout = 30,
        };
    }

    pub fn secureConnection(host: []const u8, port: u16) Connection {
        return .{
            .host = host,
            .port = port,
            .secure = true,
            .timeout = 60,
        };
    }

    pub fn custom(host: []const u8, port: u16, timeout: u32) Connection {
        return .{
            .host = host,
            .port = port,
            .secure = false,
            .timeout = timeout,
        };
    }
};

test "factory pattern" {
    const local = Connection.local();
    try testing.expectEqualStrings("localhost", local.host);
    try testing.expect(!local.secure);

    const secure_conn = Connection.secureConnection("example.com", 443);
    try testing.expectEqualStrings("example.com", secure_conn.host);
    try testing.expectEqual(@as(u16, 443), secure_conn.port);
    try testing.expect(secure_conn.secure);

    const custom = Connection.custom("api.example.com", 9000, 120);
    try testing.expectEqual(@as(u32, 120), custom.timeout);
}
```

Factory methods provide semantic initialization for common scenarios while maintaining flexibility.

### When to Use Each Pattern

Choose the right pattern for your use case:

**Default Values:**
- Simple configuration structs
- Independent fields with no interdependencies
- Fields rarely need customization
- Example: `Config{ .port = 3000 }`

**Init Functions:**
- Structs with required parameters
- Complex initialization logic
- Field validation needed
- Example: `Point.init()`, `Point.initAt(x, y)`

**Builder Pattern:**
- Many optional configuration fields
- Step-by-step construction preferred
- Fluent API desired
- Example: `ServerConfig.builder().withHost("x").withPort(80)`

**Factory Methods:**
- Multiple preset configurations
- Semantic initialization needed
- Common use cases deserve named methods
- Example: `Logger.production()`, `Connection.local()`

**Compile-Time Defaults:**
- Generic default generation needed
- Type-based initialization
- Metaprogramming applications
- Example: `createDefaults(MyStruct)`

### Important Considerations

Default field values should only be used when fields are truly independent. For structs with interdependent fields, prefer factory methods or computed properties:

```zig
// Don't do this - fields can become inconsistent:
const BadRectangle = struct {
    width: f32 = 10.0,
    height: f32 = 5.0,
    area: f32 = 50.0,  // Can diverge from width * height
};

// Do this instead - compute dependent values:
const GoodRectangle = struct {
    width: f32,
    height: f32,

    pub fn area(self: GoodRectangle) f32 {
        return self.width * self.height;
    }
};
```

### Performance Characteristics

All initialization patterns have zero runtime overhead:

- Default values are compile-time constants
- Builder pattern copies are optimized away
- Factory methods inline completely
- No virtual dispatch or dynamic allocation
- Struct layout identical to manual initialization

The compiler generates the same machine code regardless of which pattern you use.

### Memory Management

These patterns work naturally with Zig's explicit allocation:

- Stack allocation: `const config = Config{};`
- Heap allocation: `const config = try allocator.create(Config);`
- Builder pattern works identically for both

No hidden allocations occur in any of these patterns.

### Combining Patterns

Mix and match patterns as needed:

```zig
const config = ServerConfig.builder()  // Builder pattern
    .withHost("example.com")
    .withPort(9000);

const logger = Logger.production();  // Factory method

const person = Person.init("Alice");  // Init function

const partial = Config{ .port = 3000 };  // Partial defaults
```

Each pattern complements the others for different use cases.

## See Also

- Recipe 9.11: Using comptime to control instance creation
- Recipe 9.16: Defining structs programmatically
- Recipe 8.11: Simplifying the initialization of data structures

Full compilable example: `code/03-advanced/09-metaprogramming/recipe_9_17.zig`
