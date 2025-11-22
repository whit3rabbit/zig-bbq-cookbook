// Recipe 8.3: Making Objects Support the Context-Management Protocol
// Target Zig Version: 0.15.2

const std = @import("std");

// ANCHOR: basic_defer
// Basic defer pattern
const File = struct {
    handle: std.fs.File,
    path: []const u8,

    pub fn init(path: []const u8) !File {
        const file = try std.fs.cwd().createFile(path, .{});
        return File{
            .handle = file,
            .path = path,
        };
    }

    pub fn deinit(self: *File) void {
        self.handle.close();
    }

    pub fn write(self: *File, data: []const u8) !void {
        try self.handle.writeAll(data);
    }
};
// ANCHOR_END: basic_defer

test "basic defer pattern" {
    const test_file = "test_defer.txt";
    defer std.fs.cwd().deleteFile(test_file) catch {};

    var file = try File.init(test_file);
    defer file.deinit();

    try file.write("Hello, World!");
}

// Database with defer
const Database = struct {
    connection: i32,

    pub fn init() !Database {
        return Database{ .connection = 42 };
    }

    pub fn deinit(self: *Database) void {
        self.connection = 0;
    }

    pub fn query(self: *Database, sql: []const u8) !void {
        _ = sql;
        _ = self;
    }
};

test "defer execution order" {
    var db = try Database.init();
    defer db.deinit();

    try db.query("SELECT * FROM users");
}

// ANCHOR: errdefer_cleanup
// errdefer for error cleanup
const Resource = struct {
    data: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, size: usize) !Resource {
        const data = try allocator.alloc(u8, size);
        errdefer allocator.free(data);

        if (size > 1000) {
            return error.TooLarge;
        }

        return Resource{
            .data = data,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Resource) void {
        self.allocator.free(self.data);
    }
};
// ANCHOR_END: errdefer_cleanup

test "errdefer on failure" {
    const allocator = std.testing.allocator;

    var res1 = try Resource.init(allocator, 100);
    defer res1.deinit();

    const res2 = Resource.init(allocator, 2000);
    try std.testing.expectError(error.TooLarge, res2);
}

// Multiple resource management
const Connection = struct {
    socket: i32,
    buffer: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Connection {
        const socket = 123;

        const buffer = try allocator.alloc(u8, 1024);
        errdefer allocator.free(buffer);

        return Connection{
            .socket = socket,
            .buffer = buffer,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Connection) void {
        self.allocator.free(self.buffer);
    }

    pub fn send(self: *Connection, data: []const u8) !void {
        @memcpy(self.buffer[0..data.len], data);
    }
};

test "multiple resource cleanup" {
    const allocator = std.testing.allocator;

    var conn = try Connection.init(allocator);
    defer conn.deinit();

    try conn.send("Hello");
}

// Nested defer scopes
test "defer execution order LIFO" {
    var count: u32 = 0;

    {
        defer count += 1;
        defer count += 10;
        defer count += 100;

        try std.testing.expectEqual(@as(u32, 0), count);
    }

    try std.testing.expectEqual(@as(u32, 111), count);
}

// Scoped resource management
const TempDir = struct {
    path: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !TempDir {
        const path = try std.fmt.allocPrint(allocator, "/tmp/{s}", .{name});
        errdefer allocator.free(path);

        return TempDir{
            .path = path,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TempDir) void {
        self.allocator.free(self.path);
    }

    pub fn getPath(self: *const TempDir) []const u8 {
        return self.path;
    }
};

test "scoped resource" {
    const allocator = std.testing.allocator;

    var tmpdir = try TempDir.init(allocator, "test123");
    defer tmpdir.deinit();

    const path = tmpdir.getPath();
    try std.testing.expect(std.mem.indexOf(u8, path, "test123") != null);
}

// Lock guard pattern
const LockGuard = struct {
    mutex: *std.Thread.Mutex,

    pub fn init(mutex: *std.Thread.Mutex) LockGuard {
        mutex.lock();
        return LockGuard{ .mutex = mutex };
    }

    pub fn deinit(self: *LockGuard) void {
        self.mutex.unlock();
    }
};

test "lock guard" {
    var mutex = std.Thread.Mutex{};

    {
        var guard = LockGuard.init(&mutex);
        defer guard.deinit();
    }
}

// Transaction-style operations
const Transaction = struct {
    committed: bool,
    value: *i32,

    pub fn init(value: *i32) Transaction {
        return Transaction{
            .committed = false,
            .value = value,
        };
    }

    pub fn commit(self: *Transaction) void {
        self.committed = true;
    }

    pub fn deinit(self: *Transaction) void {
        if (!self.committed) {
            self.value.* = 0;
        }
    }

    pub fn execute(self: *Transaction, new_value: i32) !void {
        if (new_value < 0) {
            return error.InvalidValue;
        }
        self.value.* = new_value;
    }
};

test "transaction rollback" {
    var value: i32 = 100;

    {
        var txn = Transaction.init(&value);
        defer txn.deinit();

        try txn.execute(200);
        txn.commit();
    }
    try std.testing.expectEqual(@as(i32, 200), value);

    {
        var txn = Transaction.init(&value);
        defer txn.deinit();

        const result = txn.execute(-50);
        try std.testing.expectError(error.InvalidValue, result);
    }
    try std.testing.expectEqual(@as(i32, 0), value);
}

// ANCHOR: arena_pattern
// Arena allocator pattern
const Parser = struct {
    arena: std.heap.ArenaAllocator,

    pub fn init(backing_allocator: std.mem.Allocator) Parser {
        return Parser{
            .arena = std.heap.ArenaAllocator.init(backing_allocator),
        };
    }

    pub fn deinit(self: *Parser) void {
        self.arena.deinit();
    }

    pub fn parseString(self: *Parser, input: []const u8) ![]u8 {
        const allocator = self.arena.allocator();
        const result = try allocator.alloc(u8, input.len);
        @memcpy(result, input);
        return result;
    }
};
// ANCHOR_END: arena_pattern

test "arena allocator cleanup" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();

    const str1 = try parser.parseString("hello");
    const str2 = try parser.parseString("world");

    try std.testing.expectEqualStrings("hello", str1);
    try std.testing.expectEqualStrings("world", str2);
}

// Builder pattern with cleanup
const Builder = struct {
    items: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Builder {
        return Builder{
            .items = std.ArrayList([]const u8){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Builder) void {
        for (self.items.items) |item| {
            self.allocator.free(item);
        }
        self.items.deinit(self.allocator);
    }

    pub fn add(self: *Builder, item: []const u8) !void {
        const copy = try self.allocator.dupe(u8, item);
        errdefer self.allocator.free(copy);

        try self.items.append(self.allocator, copy);
    }

    pub fn build(self: *Builder) ![][]const u8 {
        return try self.items.toOwnedSlice(self.allocator);
    }
};

test "builder with cleanup" {
    var builder = Builder.init(std.testing.allocator);
    defer builder.deinit();

    try builder.add("first");
    try builder.add("second");

    const result = try builder.build();
    defer {
        for (result) |item| {
            std.testing.allocator.free(item);
        }
        std.testing.allocator.free(result);
    }

    try std.testing.expectEqual(@as(usize, 2), result.len);
}

// Comprehensive test
test "comprehensive context management" {
    const allocator = std.testing.allocator;

    var outer_resource = try Resource.init(allocator, 100);
    defer outer_resource.deinit();

    var conn = try Connection.init(allocator);
    defer conn.deinit();

    try conn.send("test data");

    var tmpdir = try TempDir.init(allocator, "comprehensive_test");
    defer tmpdir.deinit();

    try std.testing.expect(tmpdir.getPath().len > 0);
}
