// Recipe 8.11: Simplifying the Initialization of Data Structures
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: default_values
// Default values pattern
const ServerConfig = struct {
    host: []const u8,
    port: u16,
    timeout_ms: u32,
    max_connections: u32,
    enable_logging: bool,

    pub fn init(host: []const u8) ServerConfig {
        return ServerConfig{
            .host = host,
            .port = 8080,
            .timeout_ms = 5000,
            .max_connections = 100,
            .enable_logging = true,
        };
    }

    pub fn withPort(self: ServerConfig, port: u16) ServerConfig {
        var config = self;
        config.port = port;
        return config;
    }

    pub fn withTimeout(self: ServerConfig, timeout_ms: u32) ServerConfig {
        var config = self;
        config.timeout_ms = timeout_ms;
        return config;
    }
};
// ANCHOR_END: default_values

test "default values" {
    var config = ServerConfig.init("localhost");
    try testing.expectEqualStrings("localhost", config.host);
    try testing.expectEqual(@as(u16, 8080), config.port);

    config = config.withPort(3000).withTimeout(10000);
    try testing.expectEqual(@as(u16, 3000), config.port);
    try testing.expectEqual(@as(u32, 10000), config.timeout_ms);
}

// ANCHOR: builder_pattern
// Builder pattern
const HttpClient = struct {
    base_url: []const u8,
    timeout_ms: u32,
    retry_count: u8,
    user_agent: []const u8,

    pub const Builder = struct {
        base_url: ?[]const u8,
        timeout_ms: u32,
        retry_count: u8,
        user_agent: []const u8,

        pub fn init() Builder {
            return Builder{
                .base_url = null,
                .timeout_ms = 30000,
                .retry_count = 3,
                .user_agent = "ZigClient/1.0",
            };
        }

        pub fn setBaseUrl(self: *Builder, url: []const u8) *Builder {
            self.base_url = url;
            return self;
        }

        pub fn setTimeout(self: *Builder, ms: u32) *Builder {
            self.timeout_ms = ms;
            return self;
        }

        pub fn setRetryCount(self: *Builder, count: u8) *Builder {
            self.retry_count = count;
            return self;
        }

        pub fn setUserAgent(self: *Builder, agent: []const u8) *Builder {
            self.user_agent = agent;
            return self;
        }

        pub fn build(self: *const Builder) !HttpClient {
            if (self.base_url == null) {
                return error.BaseUrlRequired;
            }

            return HttpClient{
                .base_url = self.base_url.?,
                .timeout_ms = self.timeout_ms,
                .retry_count = self.retry_count,
                .user_agent = self.user_agent,
            };
        }
    };
};
// ANCHOR_END: builder_pattern

test "builder pattern" {
    var builder = HttpClient.Builder.init();
    const client = try builder
        .setBaseUrl("https://api.example.com")
        .setTimeout(5000)
        .setRetryCount(5)
        .build();

    try testing.expectEqualStrings("https://api.example.com", client.base_url);
    try testing.expectEqual(@as(u32, 5000), client.timeout_ms);
    try testing.expectEqual(@as(u8, 5), client.retry_count);
}

// ANCHOR: named_constructors
// Named constructors (static factory methods)
const Connection = struct {
    host: []const u8,
    port: u16,
    encrypted: bool,

    pub fn localhost(port: u16) Connection {
        return Connection{
            .host = "127.0.0.1",
            .port = port,
            .encrypted = false,
        };
    }

    pub fn secure(host: []const u8, port: u16) Connection {
        return Connection{
            .host = host,
            .port = port,
            .encrypted = true,
        };
    }

    pub fn insecure(host: []const u8, port: u16) Connection {
        return Connection{
            .host = host,
            .port = port,
            .encrypted = false,
        };
    }

    pub fn fromUrl(url: []const u8) !Connection {
        if (std.mem.startsWith(u8, url, "https://")) {
            return Connection{
                .host = url[8..],
                .port = 443,
                .encrypted = true,
            };
        } else if (std.mem.startsWith(u8, url, "http://")) {
            return Connection{
                .host = url[7..],
                .port = 80,
                .encrypted = false,
            };
        }
        return error.InvalidUrl;
    }
};
// ANCHOR_END: named_constructors

test "named constructors" {
    const local = Connection.localhost(8080);
    try testing.expectEqualStrings("127.0.0.1", local.host);
    try testing.expectEqual(@as(u16, 8080), local.port);
    try testing.expectEqual(false, local.encrypted);

    const secure = Connection.secure("example.com", 443);
    try testing.expect(secure.encrypted);

    const from_url = try Connection.fromUrl("https://api.example.com");
    try testing.expect(from_url.encrypted);
    try testing.expectEqual(@as(u16, 443), from_url.port);
}

// ANCHOR: partial_initialization
// Partial initialization with required/optional fields
const UserProfile = struct {
    username: []const u8,
    email: []const u8,
    bio: ?[]const u8,
    avatar_url: ?[]const u8,
    verified: bool,

    pub const Options = struct {
        bio: ?[]const u8 = null,
        avatar_url: ?[]const u8 = null,
        verified: bool = false,
    };

    pub fn init(username: []const u8, email: []const u8, options: Options) UserProfile {
        return UserProfile{
            .username = username,
            .email = email,
            .bio = options.bio,
            .avatar_url = options.avatar_url,
            .verified = options.verified,
        };
    }
};
// ANCHOR_END: partial_initialization

test "partial initialization" {
    const user1 = UserProfile.init("alice", "alice@example.com", .{});
    try testing.expectEqualStrings("alice", user1.username);
    try testing.expect(user1.bio == null);
    try testing.expectEqual(false, user1.verified);

    const user2 = UserProfile.init("bob", "bob@example.com", .{
        .bio = "Software developer",
        .verified = true,
    });
    try testing.expectEqualStrings("Software developer", user2.bio.?);
    try testing.expect(user2.verified);
}

// ANCHOR: copy_constructor
// Copy constructor pattern
const Point = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn init(x: f32, y: f32, z: f32) Point {
        return Point{ .x = x, .y = y, .z = z };
    }

    pub fn copy(self: *const Point) Point {
        return Point{
            .x = self.x,
            .y = self.y,
            .z = self.z,
        };
    }

    pub fn copyWith(self: *const Point, x: ?f32, y: ?f32, z: ?f32) Point {
        return Point{
            .x = x orelse self.x,
            .y = y orelse self.y,
            .z = z orelse self.z,
        };
    }

    pub fn scaled(self: *const Point, factor: f32) Point {
        return Point{
            .x = self.x * factor,
            .y = self.y * factor,
            .z = self.z * factor,
        };
    }
};
// ANCHOR_END: copy_constructor

test "copy constructor" {
    const p1 = Point.init(1, 2, 3);
    const p2 = p1.copy();
    try testing.expectEqual(p1.x, p2.x);

    const p3 = p1.copyWith(10, null, null);
    try testing.expectEqual(@as(f32, 10), p3.x);
    try testing.expectEqual(@as(f32, 2), p3.y);

    const p4 = p1.scaled(2);
    try testing.expectEqual(@as(f32, 2), p4.x);
    try testing.expectEqual(@as(f32, 4), p4.y);
}

// ANCHOR: validated_initialization
// Validated initialization
const Email = struct {
    address: []const u8,

    pub fn init(address: []const u8) !Email {
        if (address.len == 0) return error.EmptyEmail;
        if (std.mem.indexOf(u8, address, "@") == null) return error.InvalidEmail;

        return Email{ .address = address };
    }

    pub fn getAddress(self: *const Email) []const u8 {
        return self.address;
    }
};

const Age = struct {
    value: u8,

    pub fn init(value: u8) !Age {
        if (value > 150) return error.InvalidAge;
        return Age{ .value = value };
    }

    pub fn getValue(self: *const Age) u8 {
        return self.value;
    }
};
// ANCHOR_END: validated_initialization

test "validated initialization" {
    const email = try Email.init("user@example.com");
    try testing.expectEqualStrings("user@example.com", email.getAddress());

    const invalid_email = Email.init("invalid");
    try testing.expectError(error.InvalidEmail, invalid_email);

    const age = try Age.init(25);
    try testing.expectEqual(@as(u8, 25), age.getValue());

    const invalid_age = Age.init(200);
    try testing.expectError(error.InvalidAge, invalid_age);
}

// ANCHOR: fluent_interface
// Fluent interface for chaining
const StringBuilder = struct {
    buffer: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) StringBuilder {
        return StringBuilder{
            .buffer = std.ArrayList(u8){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *StringBuilder) void {
        self.buffer.deinit(self.allocator);
    }

    pub fn append(self: *StringBuilder, text: []const u8) !*StringBuilder {
        try self.buffer.appendSlice(self.allocator, text);
        return self;
    }

    pub fn appendChar(self: *StringBuilder, char: u8) !*StringBuilder {
        try self.buffer.append(self.allocator, char);
        return self;
    }

    pub fn clear(self: *StringBuilder) *StringBuilder {
        self.buffer.clearRetainingCapacity();
        return self;
    }

    pub fn toString(self: *const StringBuilder) []const u8 {
        return self.buffer.items;
    }
};
// ANCHOR_END: fluent_interface

test "fluent interface" {
    var sb = StringBuilder.init(testing.allocator);
    defer sb.deinit();

    _ = try (try (try (try sb.append("Hello")).append(" ")).append("World")).appendChar('!');

    try testing.expectEqualStrings("Hello World!", sb.toString());

    _ = try sb.clear().append("New");
    try testing.expectEqualStrings("New", sb.toString());
}

// ANCHOR: configuration_struct
// Configuration struct pattern
const DatabaseConfig = struct {
    connection_string: []const u8,
    pool_size: u32 = 10,
    timeout_ms: u32 = 5000,
    auto_reconnect: bool = true,
    ssl_enabled: bool = false,

    pub fn validate(self: *const DatabaseConfig) !void {
        if (self.connection_string.len == 0) {
            return error.EmptyConnectionString;
        }
        if (self.pool_size == 0) {
            return error.InvalidPoolSize;
        }
    }
};

const Database = struct {
    config: DatabaseConfig,

    pub fn init(config: DatabaseConfig) !Database {
        try config.validate();
        return Database{ .config = config };
    }
};
// ANCHOR_END: configuration_struct

test "configuration struct" {
    const config = DatabaseConfig{
        .connection_string = "postgresql://localhost/mydb",
        .pool_size = 20,
        .ssl_enabled = true,
    };

    const db = try Database.init(config);
    try testing.expectEqual(@as(u32, 20), db.config.pool_size);
    try testing.expect(db.config.ssl_enabled);
    try testing.expect(db.config.auto_reconnect);
}

// ANCHOR: from_conversion
// From conversions
const Color = struct {
    r: u8,
    g: u8,
    b: u8,

    pub fn fromHex(hex: u32) Color {
        return Color{
            .r = @truncate((hex >> 16) & 0xFF),
            .g = @truncate((hex >> 8) & 0xFF),
            .b = @truncate(hex & 0xFF),
        };
    }

    pub fn fromRgb(r: u8, g: u8, b: u8) Color {
        return Color{ .r = r, .g = g, .b = b };
    }

    pub fn fromGray(value: u8) Color {
        return Color{ .r = value, .g = value, .b = value };
    }

    pub fn toHex(self: *const Color) u32 {
        return (@as(u32, self.r) << 16) | (@as(u32, self.g) << 8) | @as(u32, self.b);
    }
};
// ANCHOR_END: from_conversion

test "from conversions" {
    const red = Color.fromHex(0xFF0000);
    try testing.expectEqual(@as(u8, 255), red.r);
    try testing.expectEqual(@as(u8, 0), red.g);

    const green = Color.fromRgb(0, 255, 0);
    try testing.expectEqual(@as(u32, 0x00FF00), green.toHex());

    const gray = Color.fromGray(128);
    try testing.expectEqual(@as(u8, 128), gray.r);
    try testing.expectEqual(@as(u8, 128), gray.g);
}

// ANCHOR: lazy_initialization_init
// Lazy initialization in init
const ResourceManager = struct {
    allocator: std.mem.Allocator,
    cache: ?std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) ResourceManager {
        return ResourceManager{
            .allocator = allocator,
            .cache = null,
        };
    }

    pub fn deinit(self: *ResourceManager) void {
        if (self.cache) |*c| {
            c.deinit();
        }
    }

    pub fn getCache(self: *ResourceManager) *std.StringHashMap([]const u8) {
        if (self.cache == null) {
            self.cache = std.StringHashMap([]const u8).init(self.allocator);
        }
        return &self.cache.?;
    }
};
// ANCHOR_END: lazy_initialization_init

test "lazy initialization in init" {
    var manager = ResourceManager.init(testing.allocator);
    defer manager.deinit();

    try testing.expect(manager.cache == null);

    const cache = manager.getCache();
    try testing.expect(manager.cache != null);
    try testing.expectEqual(@as(usize, 0), cache.count());
}

// ANCHOR: anonymous_struct_init
// Anonymous struct initialization
const Settings = struct {
    display: struct {
        width: u32,
        height: u32,
        fullscreen: bool,
    },
    audio: struct {
        volume: f32,
        muted: bool,
    },

    pub fn default() Settings {
        return Settings{
            .display = .{
                .width = 1920,
                .height = 1080,
                .fullscreen = false,
            },
            .audio = .{
                .volume = 0.8,
                .muted = false,
            },
        };
    }
};
// ANCHOR_END: anonymous_struct_init

test "anonymous struct init" {
    const settings = Settings.default();
    try testing.expectEqual(@as(u32, 1920), settings.display.width);
    try testing.expectEqual(@as(f32, 0.8), settings.audio.volume);
}

// ANCHOR: zero_initialization
// Zero initialization helper
fn zero(comptime T: type) T {
    var result: T = undefined;
    @memset(std.mem.asBytes(&result), 0);
    return result;
}

const Statistics = struct {
    count: u64,
    sum: f64,
    min: f64,
    max: f64,

    pub fn init() Statistics {
        return zero(Statistics);
    }

    pub fn initWithDefaults() Statistics {
        return Statistics{
            .count = 0,
            .sum = 0,
            .min = std.math.inf(f64),
            .max = -std.math.inf(f64),
        };
    }
};
// ANCHOR_END: zero_initialization

test "zero initialization" {
    const stats1 = Statistics.init();
    try testing.expectEqual(@as(u64, 0), stats1.count);
    try testing.expectEqual(@as(f64, 0), stats1.sum);

    const stats2 = Statistics.initWithDefaults();
    try testing.expect(std.math.isInf(stats2.min));
    try testing.expect(std.math.isNegativeInf(stats2.max));
}

// Comprehensive test
test "comprehensive initialization patterns" {
    var config = ServerConfig.init("0.0.0.0");
    config = config.withPort(9000);
    try testing.expectEqual(@as(u16, 9000), config.port);

    var builder = HttpClient.Builder.init();
    const client = try builder.setBaseUrl("https://test.com").build();
    try testing.expectEqualStrings("https://test.com", client.base_url);

    const conn = Connection.localhost(3000);
    try testing.expectEqual(@as(u16, 3000), conn.port);

    const user = UserProfile.init("test", "test@test.com", .{});
    try testing.expectEqualStrings("test", user.username);
}
