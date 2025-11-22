// Recipe 8.15: Delegating Attribute Access
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_delegation
// Basic method delegation
const Engine = struct {
    power: u32,
    running: bool,

    pub fn init(power: u32) Engine {
        return Engine{
            .power = power,
            .running = false,
        };
    }

    pub fn start(self: *Engine) void {
        self.running = true;
    }

    pub fn stop(self: *Engine) void {
        self.running = false;
    }

    pub fn isRunning(self: *const Engine) bool {
        return self.running;
    }

    pub fn getPower(self: *const Engine) u32 {
        return self.power;
    }
};

const Car = struct {
    engine: Engine,
    model: []const u8,

    pub fn init(model: []const u8, engine_power: u32) Car {
        return Car{
            .engine = Engine.init(engine_power),
            .model = model,
        };
    }

    // Delegate to engine
    pub fn start(self: *Car) void {
        self.engine.start();
    }

    pub fn stop(self: *Car) void {
        self.engine.stop();
    }

    pub fn isRunning(self: *const Car) bool {
        return self.engine.isRunning();
    }

    pub fn getEnginePower(self: *const Car) u32 {
        return self.engine.getPower();
    }
};
// ANCHOR_END: basic_delegation

test "basic delegation" {
    var car = Car.init("Sedan", 150);

    try testing.expect(!car.isRunning());

    car.start();
    try testing.expect(car.isRunning());
    try testing.expectEqual(@as(u32, 150), car.getEnginePower());

    car.stop();
    try testing.expect(!car.isRunning());
}

// ANCHOR: transparent_proxy
// Transparent proxy pattern
const DataStore = struct {
    data: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) DataStore {
        return DataStore{
            .data = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *DataStore) void {
        self.data.deinit();
    }

    pub fn get(self: *const DataStore, key: []const u8) ?[]const u8 {
        return self.data.get(key);
    }

    pub fn put(self: *DataStore, key: []const u8, value: []const u8) !void {
        try self.data.put(key, value);
    }

    pub fn remove(self: *DataStore, key: []const u8) bool {
        return self.data.remove(key);
    }
};

const CachedDataStore = struct {
    store: DataStore,
    cache_hits: u32,
    cache_misses: u32,

    pub fn init(allocator: std.mem.Allocator) CachedDataStore {
        return CachedDataStore{
            .store = DataStore.init(allocator),
            .cache_hits = 0,
            .cache_misses = 0,
        };
    }

    pub fn deinit(self: *CachedDataStore) void {
        self.store.deinit();
    }

    pub fn get(self: *CachedDataStore, key: []const u8) ?[]const u8 {
        const result = self.store.get(key);
        if (result != null) {
            self.cache_hits += 1;
        } else {
            self.cache_misses += 1;
        }
        return result;
    }

    pub fn put(self: *CachedDataStore, key: []const u8, value: []const u8) !void {
        try self.store.put(key, value);
    }

    pub fn remove(self: *CachedDataStore, key: []const u8) bool {
        return self.store.remove(key);
    }

    pub fn getCacheStats(self: *const CachedDataStore) struct { hits: u32, misses: u32 } {
        return .{ .hits = self.cache_hits, .misses = self.cache_misses };
    }
};
// ANCHOR_END: transparent_proxy

test "transparent proxy" {
    var cached = CachedDataStore.init(testing.allocator);
    defer cached.deinit();

    try cached.put("key1", "value1");

    _ = cached.get("key1");
    _ = cached.get("key1");
    _ = cached.get("missing");

    const stats = cached.getCacheStats();
    try testing.expectEqual(@as(u32, 2), stats.hits);
    try testing.expectEqual(@as(u32, 1), stats.misses);
}

// ANCHOR: property_forwarding
// Property forwarding pattern
const Dimensions = struct {
    width: f32,
    height: f32,
    depth: f32,

    pub fn init(width: f32, height: f32, depth: f32) Dimensions {
        return Dimensions{
            .width = width,
            .height = height,
            .depth = depth,
        };
    }

    pub fn getVolume(self: *const Dimensions) f32 {
        return self.width * self.height * self.depth;
    }

    pub fn getSurfaceArea(self: *const Dimensions) f32 {
        return 2 * (self.width * self.height + self.width * self.depth + self.height * self.depth);
    }
};

const Box = struct {
    dimensions: Dimensions,
    material: []const u8,

    pub fn init(width: f32, height: f32, depth: f32, material: []const u8) Box {
        return Box{
            .dimensions = Dimensions.init(width, height, depth),
            .material = material,
        };
    }

    // Forward dimension properties
    pub fn getWidth(self: *const Box) f32 {
        return self.dimensions.width;
    }

    pub fn getHeight(self: *const Box) f32 {
        return self.dimensions.height;
    }

    pub fn getDepth(self: *const Box) f32 {
        return self.dimensions.depth;
    }

    pub fn getVolume(self: *const Box) f32 {
        return self.dimensions.getVolume();
    }

    pub fn getSurfaceArea(self: *const Box) f32 {
        return self.dimensions.getSurfaceArea();
    }
};
// ANCHOR_END: property_forwarding

test "property forwarding" {
    const box = Box.init(2, 3, 4, "cardboard");

    try testing.expectEqual(@as(f32, 2), box.getWidth());
    try testing.expectEqual(@as(f32, 3), box.getHeight());
    try testing.expectEqual(@as(f32, 24), box.getVolume());
}

// ANCHOR: selective_delegation
// Selective method delegation
const FileSystem = struct {
    pub fn read(path: []const u8) ![]const u8 {
        _ = path;
        return "file contents";
    }

    pub fn write(path: []const u8, data: []const u8) !void {
        _ = path;
        _ = data;
    }

    pub fn delete(path: []const u8) !void {
        _ = path;
    }
};

const ReadOnlyFileSystem = struct {
    // Only expose read operation
    pub fn read(path: []const u8) ![]const u8 {
        return FileSystem.read(path);
    }

    // write and delete are not exposed
};
// ANCHOR_END: selective_delegation

test "selective delegation" {
    const contents = try ReadOnlyFileSystem.read("/test/file.txt");
    try testing.expectEqualStrings("file contents", contents);
}

// ANCHOR: logging_wrapper
// Logging wrapper with delegation
const Database = struct {
    connection_count: u32,

    pub fn init() Database {
        return Database{ .connection_count = 0 };
    }

    pub fn query(self: *Database, sql: []const u8) !void {
        _ = sql;
        self.connection_count += 1;
    }

    pub fn execute(self: *Database, sql: []const u8) !void {
        _ = sql;
        self.connection_count += 1;
    }
};

const LoggedDatabase = struct {
    db: Database,
    query_log: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) LoggedDatabase {
        return LoggedDatabase{
            .db = Database.init(),
            .query_log = std.ArrayList([]const u8){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *LoggedDatabase) void {
        self.query_log.deinit(self.allocator);
    }

    pub fn query(self: *LoggedDatabase, sql: []const u8) !void {
        try self.query_log.append(self.allocator, sql);
        try self.db.query(sql);
    }

    pub fn execute(self: *LoggedDatabase, sql: []const u8) !void {
        try self.query_log.append(self.allocator, sql);
        try self.db.execute(sql);
    }

    pub fn getQueryLog(self: *const LoggedDatabase) []const []const u8 {
        return self.query_log.items;
    }
};
// ANCHOR_END: logging_wrapper

test "logging wrapper" {
    var logged_db = LoggedDatabase.init(testing.allocator);
    defer logged_db.deinit();

    try logged_db.query("SELECT * FROM users");
    try logged_db.execute("INSERT INTO users VALUES (1)");

    const log = logged_db.getQueryLog();
    try testing.expectEqual(@as(usize, 2), log.len);
    try testing.expectEqualStrings("SELECT * FROM users", log[0]);
}

// ANCHOR: chain_delegation
// Chain of delegation
const NetworkInterface = struct {
    bytes_sent: u64,
    bytes_received: u64,

    pub fn init() NetworkInterface {
        return NetworkInterface{
            .bytes_sent = 0,
            .bytes_received = 0,
        };
    }

    pub fn send(self: *NetworkInterface, data: []const u8) void {
        self.bytes_sent += data.len;
    }

    pub fn receive(self: *NetworkInterface, size: usize) void {
        self.bytes_received += size;
    }
};

const EncryptedNetwork = struct {
    network: NetworkInterface,

    pub fn init() EncryptedNetwork {
        return EncryptedNetwork{
            .network = NetworkInterface.init(),
        };
    }

    pub fn send(self: *EncryptedNetwork, data: []const u8) void {
        // Add encryption overhead
        self.network.send(data);
        self.network.bytes_sent += 16; // Encryption header
    }

    pub fn receive(self: *EncryptedNetwork, size: usize) void {
        self.network.receive(size);
    }

    pub fn getBytesSent(self: *const EncryptedNetwork) u64 {
        return self.network.bytes_sent;
    }
};

const CompressedEncryptedNetwork = struct {
    encrypted: EncryptedNetwork,

    pub fn init() CompressedEncryptedNetwork {
        return CompressedEncryptedNetwork{
            .encrypted = EncryptedNetwork.init(),
        };
    }

    pub fn send(self: *CompressedEncryptedNetwork, data: []const u8) void {
        // Simulate compression (50% reduction)
        const compressed_size = data.len / 2;
        const compressed_data = data[0..compressed_size];
        self.encrypted.send(compressed_data);
    }

    pub fn getBytesSent(self: *const CompressedEncryptedNetwork) u64 {
        return self.encrypted.getBytesSent();
    }
};
// ANCHOR_END: chain_delegation

test "chain delegation" {
    var network = CompressedEncryptedNetwork.init();

    const data = "Hello, World!";
    network.send(data);

    const sent = network.getBytesSent();
    try testing.expect(sent > 0);
}

// ANCHOR: dynamic_delegation
// Dynamic delegation pattern
const Writer = struct {
    ptr: *anyopaque,
    writeFn: *const fn (ptr: *anyopaque, data: []const u8) anyerror!void,

    pub fn write(self: Writer, data: []const u8) !void {
        return self.writeFn(self.ptr, data);
    }
};

const BufferWriter = struct {
    buffer: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) BufferWriter {
        return BufferWriter{
            .buffer = std.ArrayList(u8){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BufferWriter) void {
        self.buffer.deinit(self.allocator);
    }

    fn writeFn(ptr: *anyopaque, data: []const u8) !void {
        const self: *BufferWriter = @ptrCast(@alignCast(ptr));
        try self.buffer.appendSlice(self.allocator, data);
    }

    pub fn writer(self: *BufferWriter) Writer {
        return Writer{
            .ptr = self,
            .writeFn = writeFn,
        };
    }

    pub fn getContents(self: *const BufferWriter) []const u8 {
        return self.buffer.items;
    }
};

const DelegatingWriter = struct {
    writer: Writer,

    pub fn init(writer: Writer) DelegatingWriter {
        return DelegatingWriter{ .writer = writer };
    }

    pub fn writeLine(self: *DelegatingWriter, line: []const u8) !void {
        try self.writer.write(line);
        try self.writer.write("\n");
    }
};
// ANCHOR_END: dynamic_delegation

test "dynamic delegation" {
    var buf = BufferWriter.init(testing.allocator);
    defer buf.deinit();

    var delegating = DelegatingWriter.init(buf.writer());
    try delegating.writeLine("First line");
    try delegating.writeLine("Second line");

    try testing.expectEqualStrings("First line\nSecond line\n", buf.getContents());
}

// ANCHOR: mixin_delegation
// Mixin-style delegation
fn WithLogging(comptime T: type) type {
    return struct {
        inner: T,
        log_count: u32,

        const Self = @This();

        pub fn init(inner: T) Self {
            return Self{
                .inner = inner,
                .log_count = 0,
            };
        }

        pub fn call(self: *Self) void {
            self.log_count += 1;
            if (@hasDecl(T, "call")) {
                self.inner.call();
            }
        }

        pub fn getLogCount(self: *const Self) u32 {
            return self.log_count;
        }

        pub fn getInner(self: *Self) *T {
            return &self.inner;
        }
    };
}

const SimpleService = struct {
    invocations: u32,

    pub fn init() SimpleService {
        return SimpleService{ .invocations = 0 };
    }

    pub fn call(self: *SimpleService) void {
        self.invocations += 1;
    }
};
// ANCHOR_END: mixin_delegation

test "mixin delegation" {
    const service = SimpleService.init();
    var logged = WithLogging(SimpleService).init(service);

    logged.call();
    logged.call();
    logged.call();

    try testing.expectEqual(@as(u32, 3), logged.getLogCount());
    try testing.expectEqual(@as(u32, 3), logged.getInner().invocations);
}

// ANCHOR: conditional_delegation
// Conditional delegation
const Calculator = struct {
    result: f64,

    pub fn init() Calculator {
        return Calculator{ .result = 0 };
    }

    pub fn add(self: *Calculator, value: f64) void {
        self.result += value;
    }

    pub fn multiply(self: *Calculator, value: f64) void {
        self.result *= value;
    }

    pub fn getResult(self: *const Calculator) f64 {
        return self.result;
    }
};

const SafeCalculator = struct {
    calculator: Calculator,
    overflow_occurred: bool,

    pub fn init() SafeCalculator {
        return SafeCalculator{
            .calculator = Calculator.init(),
            .overflow_occurred = false,
        };
    }

    pub fn add(self: *SafeCalculator, value: f64) void {
        const new_result = self.calculator.result + value;
        if (std.math.isInf(new_result) or std.math.isNan(new_result)) {
            self.overflow_occurred = true;
        } else {
            self.calculator.add(value);
        }
    }

    pub fn multiply(self: *SafeCalculator, value: f64) void {
        const new_result = self.calculator.result * value;
        if (std.math.isInf(new_result) or std.math.isNan(new_result)) {
            self.overflow_occurred = true;
        } else {
            self.calculator.multiply(value);
        }
    }

    pub fn getResult(self: *const SafeCalculator) ?f64 {
        if (self.overflow_occurred) return null;
        return self.calculator.getResult();
    }

    pub fn hasOverflow(self: *const SafeCalculator) bool {
        return self.overflow_occurred;
    }
};
// ANCHOR_END: conditional_delegation

test "conditional delegation" {
    var calc = SafeCalculator.init();

    calc.add(10);
    calc.multiply(5);

    try testing.expectEqual(@as(f64, 50), calc.getResult().?);
    try testing.expect(!calc.hasOverflow());

    calc.multiply(std.math.inf(f64));
    try testing.expect(calc.hasOverflow());
    try testing.expect(calc.getResult() == null);
}

// ANCHOR: lazy_delegation
// Lazy delegation (delegate only when needed)
const HeavyResource = struct {
    data: []const u8,

    pub fn init() HeavyResource {
        return HeavyResource{ .data = "heavy resource data" };
    }

    pub fn getData(self: *const HeavyResource) []const u8 {
        return self.data;
    }
};

const LazyProxy = struct {
    resource: ?HeavyResource,
    initialization_count: u32,

    pub fn init() LazyProxy {
        return LazyProxy{
            .resource = null,
            .initialization_count = 0,
        };
    }

    pub fn getData(self: *LazyProxy) []const u8 {
        if (self.resource == null) {
            self.resource = HeavyResource.init();
            self.initialization_count += 1;
        }
        return self.resource.?.getData();
    }

    pub fn getInitCount(self: *const LazyProxy) u32 {
        return self.initialization_count;
    }
};
// ANCHOR_END: lazy_delegation

test "lazy delegation" {
    var proxy = LazyProxy.init();

    try testing.expectEqual(@as(u32, 0), proxy.getInitCount());

    const data1 = proxy.getData();
    try testing.expectEqualStrings("heavy resource data", data1);
    try testing.expectEqual(@as(u32, 1), proxy.getInitCount());

    const data2 = proxy.getData();
    try testing.expectEqualStrings("heavy resource data", data2);
    try testing.expectEqual(@as(u32, 1), proxy.getInitCount());
}

// Comprehensive test
test "comprehensive delegation patterns" {
    var car = Car.init("Sedan", 200);
    car.start();
    try testing.expect(car.isRunning());

    var cached = CachedDataStore.init(testing.allocator);
    defer cached.deinit();
    try cached.put("test", "value");
    _ = cached.get("test");

    const box = Box.init(1, 2, 3, "wood");
    try testing.expectEqual(@as(f32, 6), box.getVolume());

    var proxy = LazyProxy.init();
    _ = proxy.getData();
    try testing.expectEqual(@as(u32, 1), proxy.getInitCount());
}
