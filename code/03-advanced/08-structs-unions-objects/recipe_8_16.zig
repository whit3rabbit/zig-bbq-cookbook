// Recipe 8.16: Defining More Than One Constructor in a Class
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: named_constructors
// Named constructor pattern
const Point = struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) Point {
        return Point{ .x = x, .y = y };
    }

    pub fn origin() Point {
        return Point{ .x = 0, .y = 0 };
    }

    pub fn fromPolar(radius: f32, angle: f32) Point {
        return Point{
            .x = radius * @cos(angle),
            .y = radius * @sin(angle),
        };
    }

    pub fn fromArray(arr: [2]f32) Point {
        return Point{ .x = arr[0], .y = arr[1] };
    }
};
// ANCHOR_END: named_constructors

test "named constructors" {
    const p1 = Point.init(3, 4);
    try testing.expectEqual(@as(f32, 3), p1.x);

    const p2 = Point.origin();
    try testing.expectEqual(@as(f32, 0), p2.x);

    const p3 = Point.fromPolar(5, 0);
    try testing.expectApproxEqAbs(@as(f32, 5), p3.x, 0.001);

    const arr = [_]f32{ 1, 2 };
    const p4 = Point.fromArray(arr);
    try testing.expectEqual(@as(f32, 1), p4.x);
}

// ANCHOR: default_values
// Default values with optional overrides
const Server = struct {
    host: []const u8,
    port: u16,
    timeout: u32,

    pub fn init(host: []const u8, port: u16, timeout: u32) Server {
        return Server{
            .host = host,
            .port = port,
            .timeout = timeout,
        };
    }

    pub fn withDefaults(host: []const u8) Server {
        return Server{
            .host = host,
            .port = 8080,
            .timeout = 30,
        };
    }

    pub fn localhost() Server {
        return Server{
            .host = "127.0.0.1",
            .port = 8080,
            .timeout = 30,
        };
    }
};
// ANCHOR_END: default_values

test "default values" {
    const s1 = Server.init("example.com", 443, 60);
    try testing.expectEqual(@as(u16, 443), s1.port);

    const s2 = Server.withDefaults("api.example.com");
    try testing.expectEqual(@as(u16, 8080), s2.port);
    try testing.expectEqual(@as(u32, 30), s2.timeout);

    const s3 = Server.localhost();
    try testing.expectEqualStrings("127.0.0.1", s3.host);
}

// ANCHOR: factory_methods
// Factory methods with validation
const Email = struct {
    address: []const u8,

    pub fn init(address: []const u8) !Email {
        if (std.mem.indexOf(u8, address, "@") == null) {
            return error.InvalidEmail;
        }
        return Email{ .address = address };
    }

    pub fn fromParts(local: []const u8, domain: []const u8, allocator: std.mem.Allocator) !Email {
        const address = try std.fmt.allocPrint(allocator, "{s}@{s}", .{ local, domain });
        return Email{ .address = address };
    }

    pub fn anonymous(allocator: std.mem.Allocator) !Email {
        const address = try std.fmt.allocPrint(allocator, "user{d}@example.com", .{std.crypto.random.int(u32)});
        return Email{ .address = address };
    }
};
// ANCHOR_END: factory_methods

test "factory methods" {
    const e1 = try Email.init("test@example.com");
    try testing.expectEqualStrings("test@example.com", e1.address);

    const result = Email.init("invalid");
    try testing.expectError(error.InvalidEmail, result);

    const e2 = try Email.fromParts("admin", "company.com", testing.allocator);
    defer testing.allocator.free(e2.address);
    try testing.expectEqualStrings("admin@company.com", e2.address);
}

// ANCHOR: builder_constructors
// Builder pattern with multiple initialization styles
const HttpRequest = struct {
    method: []const u8,
    url: []const u8,
    headers: ?std.StringHashMap([]const u8),
    body: ?[]const u8,

    pub fn init(method: []const u8, url: []const u8) HttpRequest {
        return HttpRequest{
            .method = method,
            .url = url,
            .headers = null,
            .body = null,
        };
    }

    pub fn get(url: []const u8) HttpRequest {
        return HttpRequest.init("GET", url);
    }

    pub fn post(url: []const u8, body: []const u8) HttpRequest {
        return HttpRequest{
            .method = "POST",
            .url = url,
            .headers = null,
            .body = body,
        };
    }

    pub fn withHeaders(self: HttpRequest, headers: std.StringHashMap([]const u8)) HttpRequest {
        var req = self;
        req.headers = headers;
        return req;
    }
};
// ANCHOR_END: builder_constructors

test "builder constructors" {
    const req1 = HttpRequest.get("/api/users");
    try testing.expectEqualStrings("GET", req1.method);
    try testing.expectEqualStrings("/api/users", req1.url);

    const req2 = HttpRequest.post("/api/data", "payload");
    try testing.expectEqualStrings("POST", req2.method);
    try testing.expectEqualStrings("payload", req2.body.?);
}

// ANCHOR: copy_constructor
// Copy and clone constructors
const Vector = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn init(x: f32, y: f32, z: f32) Vector {
        return Vector{ .x = x, .y = y, .z = z };
    }

    pub fn copy(other: *const Vector) Vector {
        return Vector{
            .x = other.x,
            .y = other.y,
            .z = other.z,
        };
    }

    pub fn scaled(self: *const Vector, factor: f32) Vector {
        return Vector{
            .x = self.x * factor,
            .y = self.y * factor,
            .z = self.z * factor,
        };
    }

    pub fn normalized(self: *const Vector) Vector {
        const len = @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
        if (len == 0) return Vector.init(0, 0, 0);
        return Vector{
            .x = self.x / len,
            .y = self.y / len,
            .z = self.z / len,
        };
    }
};
// ANCHOR_END: copy_constructor

test "copy constructor" {
    const v1 = Vector.init(3, 4, 0);
    const v2 = Vector.copy(&v1);
    try testing.expectEqual(@as(f32, 3), v2.x);

    const v3 = v1.scaled(2);
    try testing.expectEqual(@as(f32, 6), v3.x);
    try testing.expectEqual(@as(f32, 8), v3.y);

    const v4 = v1.normalized();
    const expected_x = @as(f32, 3) / 5;
    try testing.expectApproxEqAbs(expected_x, v4.x, 0.001);
}

// ANCHOR: conditional_init
// Conditional initialization based on type
const Config = struct {
    environment: []const u8,
    debug_mode: bool,
    log_level: u8,

    pub fn production() Config {
        return Config{
            .environment = "production",
            .debug_mode = false,
            .log_level = 2,
        };
    }

    pub fn development() Config {
        return Config{
            .environment = "development",
            .debug_mode = true,
            .log_level = 5,
        };
    }

    pub fn testing() Config {
        return Config{
            .environment = "testing",
            .debug_mode = true,
            .log_level = 4,
        };
    }

    pub fn fromEnv(env: []const u8) Config {
        if (std.mem.eql(u8, env, "prod")) {
            return Config.production();
        } else if (std.mem.eql(u8, env, "dev")) {
            return Config.development();
        } else {
            return Config.testing();
        }
    }
};
// ANCHOR_END: conditional_init

test "conditional initialization" {
    const prod = Config.production();
    try testing.expect(!prod.debug_mode);
    try testing.expectEqual(@as(u8, 2), prod.log_level);

    const dev = Config.development();
    try testing.expect(dev.debug_mode);

    const config = Config.fromEnv("prod");
    try testing.expectEqualStrings("production", config.environment);
}

// ANCHOR: resource_init
// Resource initialization with different sources
const Database = struct {
    connection_string: []const u8,
    pool_size: u32,

    pub fn fromUrl(url: []const u8) Database {
        return Database{
            .connection_string = url,
            .pool_size = 10,
        };
    }

    pub fn fromConfig(host: []const u8, port: u16, db_name: []const u8, allocator: std.mem.Allocator) !Database {
        const conn_str = try std.fmt.allocPrint(allocator, "postgresql://{s}:{d}/{s}", .{ host, port, db_name });
        return Database{
            .connection_string = conn_str,
            .pool_size = 20,
        };
    }

    pub fn inmemory() Database {
        return Database{
            .connection_string = ":memory:",
            .pool_size = 1,
        };
    }
};
// ANCHOR_END: resource_init

test "resource initialization" {
    const db1 = Database.fromUrl("postgresql://localhost/mydb");
    try testing.expectEqualStrings("postgresql://localhost/mydb", db1.connection_string);
    try testing.expectEqual(@as(u32, 10), db1.pool_size);

    const db2 = try Database.fromConfig("localhost", 5432, "testdb", testing.allocator);
    defer testing.allocator.free(db2.connection_string);
    try testing.expect(std.mem.indexOf(u8, db2.connection_string, "5432") != null);

    const db3 = Database.inmemory();
    try testing.expectEqualStrings(":memory:", db3.connection_string);
}

// ANCHOR: generic_constructors
// Generic constructors with type parameters
fn Result(comptime T: type, comptime E: type) type {
    return union(enum) {
        ok: T,
        err: E,

        pub fn initOk(value: T) @This() {
            return .{ .ok = value };
        }

        pub fn initErr(err: E) @This() {
            return .{ .err = err };
        }

        pub fn fromOptional(opt: ?T, default_err: E) @This() {
            if (opt) |value| {
                return .{ .ok = value };
            } else {
                return .{ .err = default_err };
            }
        }
    };
}
// ANCHOR_END: generic_constructors

test "generic constructors" {
    const IntResult = Result(i32, []const u8);

    const r1 = IntResult.initOk(42);
    try testing.expectEqual(@as(i32, 42), r1.ok);

    const r2 = IntResult.initErr("not found");
    try testing.expectEqualStrings("not found", r2.err);

    const opt: ?i32 = null;
    const r3 = IntResult.fromOptional(opt, "empty");
    try testing.expectEqualStrings("empty", r3.err);
}

// ANCHOR: parse_constructors
// Parse constructors from strings
const Color = struct {
    r: u8,
    g: u8,
    b: u8,

    pub fn init(r: u8, g: u8, b: u8) Color {
        return Color{ .r = r, .g = g, .b = b };
    }

    pub fn fromRgb(rgb: u32) Color {
        return Color{
            .r = @intCast((rgb >> 16) & 0xFF),
            .g = @intCast((rgb >> 8) & 0xFF),
            .b = @intCast(rgb & 0xFF),
        };
    }

    pub fn black() Color {
        return Color.init(0, 0, 0);
    }

    pub fn white() Color {
        return Color.init(255, 255, 255);
    }

    pub fn red() Color {
        return Color.init(255, 0, 0);
    }

    pub fn fromGrayscale(value: u8) Color {
        return Color.init(value, value, value);
    }
};
// ANCHOR_END: parse_constructors

test "parse constructors" {
    const c1 = Color.fromRgb(0xFF5733);
    try testing.expectEqual(@as(u8, 0xFF), c1.r);
    try testing.expectEqual(@as(u8, 0x57), c1.g);
    try testing.expectEqual(@as(u8, 0x33), c1.b);

    const c2 = Color.black();
    try testing.expectEqual(@as(u8, 0), c2.r);

    const c3 = Color.fromGrayscale(128);
    try testing.expectEqual(@as(u8, 128), c3.r);
    try testing.expectEqual(@as(u8, 128), c3.g);
}

// ANCHOR: partial_init
// Partial initialization with required fields
const User = struct {
    id: u32,
    username: []const u8,
    email: ?[]const u8,
    bio: ?[]const u8,

    pub fn init(id: u32, username: []const u8) User {
        return User{
            .id = id,
            .username = username,
            .email = null,
            .bio = null,
        };
    }

    pub fn withEmail(id: u32, username: []const u8, email: []const u8) User {
        return User{
            .id = id,
            .username = username,
            .email = email,
            .bio = null,
        };
    }

    pub fn full(id: u32, username: []const u8, email: []const u8, bio: []const u8) User {
        return User{
            .id = id,
            .username = username,
            .email = email,
            .bio = bio,
        };
    }
};
// ANCHOR_END: partial_init

test "partial initialization" {
    const user1 = User.init(1, "alice");
    try testing.expectEqual(@as(u32, 1), user1.id);
    try testing.expect(user1.email == null);

    const user2 = User.withEmail(2, "bob", "bob@example.com");
    try testing.expectEqualStrings("bob@example.com", user2.email.?);
    try testing.expect(user2.bio == null);

    const user3 = User.full(3, "charlie", "charlie@example.com", "Developer");
    try testing.expectEqualStrings("Developer", user3.bio.?);
}

// Comprehensive test
test "comprehensive multiple constructors" {
    const p = Point.fromPolar(10, std.math.pi / @as(f32, 4));
    try testing.expect(p.x > 7 and p.x < 8);

    const srv = Server.localhost();
    try testing.expectEqual(@as(u16, 8080), srv.port);

    const v = Vector.init(1, 0, 0);
    const v_norm = v.normalized();
    try testing.expectApproxEqAbs(@as(f32, 1), v_norm.x, 0.001);

    const cfg = Config.fromEnv("dev");
    try testing.expect(cfg.debug_mode);

    const c = Color.white();
    try testing.expectEqual(@as(u8, 255), c.r);
}
