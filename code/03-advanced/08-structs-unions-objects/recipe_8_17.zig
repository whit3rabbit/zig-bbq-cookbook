// Recipe 8.17: Creating an Instance Without Invoking Init
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: direct_literal
// Direct struct literal initialization
const Point = struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) Point {
        return Point{ .x = x, .y = y };
    }
};

test "direct literal initialization" {
    // Create without calling init
    const p1 = Point{ .x = 3, .y = 4 };
    try testing.expectEqual(@as(f32, 3), p1.x);

    // Using init for comparison
    const p2 = Point.init(3, 4);
    try testing.expectEqual(@as(f32, 3), p2.x);

    // Both are equivalent
    try testing.expectEqual(p1.x, p2.x);
    try testing.expectEqual(p1.y, p2.y);
}
// ANCHOR_END: direct_literal

// ANCHOR: undefined_init
// Undefined initialization for performance
const Buffer = struct {
    data: [1024]u8,
    len: usize,

    pub fn init() Buffer {
        return Buffer{
            .data = undefined,
            .len = 0,
        };
    }

    pub fn uninitialized() Buffer {
        var buf: Buffer = undefined;
        buf.len = 0;
        return buf;
    }

    pub fn write(self: *Buffer, bytes: []const u8) void {
        const space = self.data.len - self.len;
        const to_write = @min(bytes.len, space);
        @memcpy(self.data[self.len..][0..to_write], bytes[0..to_write]);
        self.len += to_write;
    }
};

test "undefined initialization" {
    var buf1 = Buffer.init();
    buf1.write("test");
    try testing.expectEqual(@as(usize, 4), buf1.len);

    var buf2 = Buffer.uninitialized();
    buf2.write("data");
    try testing.expectEqual(@as(usize, 4), buf2.len);
}
// ANCHOR_END: undefined_init

// ANCHOR: zero_init
// Zero initialization
const Counters = struct {
    success: u32,
    failure: u32,
    pending: u32,

    pub fn init() Counters {
        return Counters{
            .success = 0,
            .failure = 0,
            .pending = 0,
        };
    }

    pub fn zero() Counters {
        return std.mem.zeroes(Counters);
    }
};

test "zero initialization" {
    const c1 = Counters.init();
    try testing.expectEqual(@as(u32, 0), c1.success);

    const c2 = Counters.zero();
    try testing.expectEqual(@as(u32, 0), c2.success);
    try testing.expectEqual(@as(u32, 0), c2.failure);
    try testing.expectEqual(@as(u32, 0), c2.pending);
}
// ANCHOR_END: zero_init

// ANCHOR: from_bytes
// Deserialize from bytes
const Header = struct {
    magic: u32,
    version: u16,
    flags: u16,

    pub fn fromBytes(bytes: []const u8) !Header {
        if (bytes.len < @sizeOf(Header)) return error.TooSmall;

        return Header{
            .magic = std.mem.readInt(u32, bytes[0..4], .little),
            .version = std.mem.readInt(u16, bytes[4..6], .little),
            .flags = std.mem.readInt(u16, bytes[6..8], .little),
        };
    }

    pub fn fromBytesUnsafe(bytes: *const [@sizeOf(Header)]u8) *const Header {
        return @ptrCast(@alignCast(bytes));
    }
};

test "from bytes" {
    const bytes = [_]u8{ 0x12, 0x34, 0x56, 0x78, 0x01, 0x00, 0x02, 0x00 };

    const header = try Header.fromBytes(&bytes);
    try testing.expectEqual(@as(u32, 0x78563412), header.magic);
    try testing.expectEqual(@as(u16, 0x0001), header.version);
}
// ANCHOR_END: from_bytes

// ANCHOR: pool_pattern
// Object pool pattern (reuse without init)
const PooledObject = struct {
    id: u32,
    data: [64]u8,
    in_use: bool,

    pub fn reset(self: *PooledObject) void {
        self.in_use = false;
        @memset(&self.data, 0);
    }

    pub fn acquire(self: *PooledObject, id: u32) void {
        self.id = id;
        self.in_use = true;
    }
};

const ObjectPool = struct {
    objects: [10]PooledObject,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ObjectPool {
        var pool = ObjectPool{
            .objects = undefined,
            .allocator = allocator,
        };

        for (&pool.objects, 0..) |*obj, i| {
            obj.* = PooledObject{
                .id = @intCast(i),
                .data = undefined,
                .in_use = false,
            };
        }

        return pool;
    }

    pub fn acquire(self: *ObjectPool) ?*PooledObject {
        for (&self.objects) |*obj| {
            if (!obj.in_use) {
                obj.in_use = true;
                return obj;
            }
        }
        return null;
    }

    pub fn release(self: *ObjectPool, obj: *PooledObject) void {
        _ = self;
        obj.reset();
    }
};

test "pool pattern" {
    var pool = ObjectPool.init(testing.allocator);

    const obj1 = pool.acquire().?;
    obj1.acquire(100);
    try testing.expectEqual(@as(u32, 100), obj1.id);
    try testing.expect(obj1.in_use);

    pool.release(obj1);
    try testing.expect(!obj1.in_use);

    const obj2 = pool.acquire().?;
    try testing.expect(obj2.in_use);
}
// ANCHOR_END: pool_pattern

// ANCHOR: comptime_instance
// Comptime instance creation
const Config = struct {
    max_connections: u32,
    timeout_ms: u32,
    buffer_size: usize,

    pub fn default() Config {
        return Config{
            .max_connections = 100,
            .timeout_ms = 5000,
            .buffer_size = 4096,
        };
    }
};

// Create at compile time
const global_config = Config{
    .max_connections = 50,
    .timeout_ms = 3000,
    .buffer_size = 2048,
};

const default_config = Config.default();

test "comptime instance" {
    try testing.expectEqual(@as(u32, 50), global_config.max_connections);
    try testing.expectEqual(@as(u32, 100), default_config.max_connections);

    // Can use comptime instances at runtime
    var runtime_config = global_config;
    runtime_config.max_connections = 200;
    try testing.expectEqual(@as(u32, 200), runtime_config.max_connections);
}
// ANCHOR_END: comptime_instance

// ANCHOR: placement_new
// Placement initialization (initialize in-place)
const Node = struct {
    value: i32,
    next: ?*Node,

    pub fn initInPlace(self: *Node, value: i32) void {
        self.* = Node{
            .value = value,
            .next = null,
        };
    }
};

test "placement initialization" {
    var storage: Node = undefined;
    storage.initInPlace(42);

    try testing.expectEqual(@as(i32, 42), storage.value);
    try testing.expect(storage.next == null);

    // Can also use direct assignment
    var storage2: Node = undefined;
    storage2 = Node{ .value = 100, .next = null };
    try testing.expectEqual(@as(i32, 100), storage2.value);
}
// ANCHOR_END: placement_new

// ANCHOR: default_struct
// Structs with default values
const Settings = struct {
    name: []const u8 = "default",
    enabled: bool = true,
    count: u32 = 0,

    pub fn init() Settings {
        return .{};
    }
};

test "default struct values" {
    const s1: Settings = .{};
    try testing.expectEqualStrings("default", s1.name);
    try testing.expect(s1.enabled);
    try testing.expectEqual(@as(u32, 0), s1.count);

    const s2: Settings = .{ .name = "custom", .count = 10 };
    try testing.expectEqualStrings("custom", s2.name);
    try testing.expect(s2.enabled); // Still uses default
    try testing.expectEqual(@as(u32, 10), s2.count);
}
// ANCHOR_END: default_struct

// ANCHOR: copy_from
// Copy from another instance
const Matrix = struct {
    data: [9]f32,

    pub fn identity() Matrix {
        return Matrix{
            .data = [_]f32{
                1, 0, 0,
                0, 1, 0,
                0, 0, 1,
            },
        };
    }

    pub fn copyFrom(other: *const Matrix) Matrix {
        var m: Matrix = undefined;
        @memcpy(&m.data, &other.data);
        return m;
    }

    pub fn clone(self: *const Matrix) Matrix {
        return self.*;
    }
};

test "copy from" {
    const m1 = Matrix.identity();
    const m2 = Matrix.copyFrom(&m1);

    try testing.expectEqual(m1.data[0], m2.data[0]);
    try testing.expectEqual(m1.data[4], m2.data[4]);

    const m3 = m1.clone();
    try testing.expectEqual(m1.data[0], m3.data[0]);
}
// ANCHOR_END: copy_from

// ANCHOR: tagged_union_init
// Tagged union initialization without constructor
const Message = union(enum) {
    text: []const u8,
    number: i32,
    flag: bool,

    pub fn initText(content: []const u8) Message {
        return .{ .text = content };
    }

    pub fn initNumber(value: i32) Message {
        return .{ .number = value };
    }
};

test "tagged union initialization" {
    // Direct initialization
    const m1: Message = .{ .text = "hello" };
    try testing.expectEqualStrings("hello", m1.text);

    const m2: Message = .{ .number = 42 };
    try testing.expectEqual(@as(i32, 42), m2.number);

    // Using constructors
    const m3 = Message.initText("world");
    try testing.expectEqualStrings("world", m3.text);
}
// ANCHOR_END: tagged_union_init

// ANCHOR: reinterpret
// Reinterpret bytes as struct
const Packet = struct {
    type_id: u8,
    length: u16,
    payload: [5]u8,

    pub fn fromMemory(ptr: *const anyopaque) *const Packet {
        return @ptrCast(@alignCast(ptr));
    }

    pub fn fromBytes(bytes: *const [8]u8) Packet {
        return Packet{
            .type_id = bytes[0],
            .length = std.mem.readInt(u16, bytes[1..3], .little),
            .payload = bytes[3..8].*,
        };
    }
};

test "reinterpret bytes" {
    const bytes = [_]u8{ 1, 10, 0, 'h', 'e', 'l', 'l', 'o' };
    const packet = Packet.fromBytes(&bytes);

    try testing.expectEqual(@as(u8, 1), packet.type_id);
    try testing.expectEqual(@as(u16, 10), packet.length);
    try testing.expectEqual(@as(u8, 'h'), packet.payload[0]);
}
// ANCHOR_END: reinterpret

// Comprehensive test
test "comprehensive instance creation" {
    // Direct literal
    const p: Point = .{ .x = 1, .y = 2 };
    try testing.expectEqual(@as(f32, 1), p.x);

    // Zero initialized
    const c = std.mem.zeroes(Counters);
    try testing.expectEqual(@as(u32, 0), c.success);

    // With defaults
    const s: Settings = .{ .count = 5 };
    try testing.expect(s.enabled);
    try testing.expectEqual(@as(u32, 5), s.count);

    // Tagged union
    const msg: Message = .{ .flag = true };
    try testing.expect(msg.flag);

    // Undefined then initialize
    var buf: Buffer = undefined;
    buf.len = 0;
    try testing.expectEqual(@as(usize, 0), buf.len);
}
