// Recipe 9.17: Initializing Struct Members at Definition Time
// Target Zig Version: 0.15.2
//
// This recipe demonstrates compile-time struct initialization patterns,
// default values, and automatic field population.
//
// Important: Default field values should only be used when fields are
// truly independent. For complex types with interdependent fields,
// prefer named default constants or factory methods.

const std = @import("std");
const testing = std.testing;

// ANCHOR: default_values
// Simple struct with default field values
const Config = struct {
    host: []const u8 = "localhost",
    port: u16 = 8080,
    timeout: u32 = 30,
};

test "default values" {
    const config = Config{};

    try testing.expectEqualStrings("localhost", config.host);
    try testing.expectEqual(@as(u16, 8080), config.port);
    try testing.expectEqual(@as(u32, 30), config.timeout);
}
// ANCHOR_END: default_values

// ANCHOR: partial_init
// Override some defaults while keeping others
test "partial initialization" {
    const config = Config{
        .port = 3000,
    };

    try testing.expectEqualStrings("localhost", config.host);
    try testing.expectEqual(@as(u16, 3000), config.port);
    try testing.expectEqual(@as(u32, 30), config.timeout);
}
// ANCHOR_END: partial_init

// ANCHOR: init_function
// Custom initialization function with defaults
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
// ANCHOR_END: init_function

// ANCHOR: comptime_defaults
// Generate default values at compile time
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
// ANCHOR_END: comptime_defaults

// ANCHOR: builder_pattern
// Builder pattern with incremental initialization
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
// ANCHOR_END: builder_pattern

// ANCHOR: computed_defaults
// Defaults computed from other values
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
// ANCHOR_END: computed_defaults

// ANCHOR: optional_fields
// Optional fields with null defaults
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
// ANCHOR_END: optional_fields

// ANCHOR: enum_defaults
// Enum-based configuration with defaults
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
// ANCHOR_END: enum_defaults

// ANCHOR: array_defaults
// Arrays with default values
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
// ANCHOR_END: array_defaults

// ANCHOR: nested_defaults
// Nested structs with cascading defaults
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
// ANCHOR_END: nested_defaults

// ANCHOR: comptime_init
// Compile-time struct initialization
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
// ANCHOR_END: comptime_init

// ANCHOR: factory_pattern
// Factory methods for different initialization scenarios
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
// ANCHOR_END: factory_pattern

// Comprehensive test
test "comprehensive initialization patterns" {
    // Default values
    const cfg = Config{};
    try testing.expectEqual(@as(u16, 8080), cfg.port);

    // Init function
    const pt = Point.init();
    try testing.expectEqual(@as(f32, 0.0), pt.x);

    // Builder pattern
    const srv = ServerConfig.builder().withPort(5000);
    try testing.expectEqual(@as(u16, 5000), srv.port);

    // Optional fields
    const usr = User.init(1, "Test");
    try testing.expectEqual(@as(?[]const u8, null), usr.email);

    // Enum defaults
    const log = Logger.init();
    try testing.expectEqual(LogLevel.info, log.level);

    // Array defaults
    const mat = Matrix3x3{};
    try testing.expectEqual(@as(f32, 0.0), mat.get(0, 0));

    // Nested defaults
    const pers = Person.init("Alice");
    try testing.expectEqualStrings("USA", pers.address.country);

    // Factory pattern
    const conn = Connection.local();
    try testing.expectEqualStrings("localhost", conn.host);

    try testing.expect(true);
}
