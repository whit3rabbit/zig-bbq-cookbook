## Problem

You need to ensure resources are properly cleaned up when they go out of scope, similar to Python's context managers or C++'s RAII pattern.

## Solution

Use `defer` and `errdefer` statements to guarantee cleanup, and implement `init`/`deinit` patterns:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_3.zig:basic_defer}}
```

## Discussion

### Understanding defer

The `defer` statement schedules code to run when leaving the current scope:

```zig
const Database = struct {
    connection: i32,

    pub fn init() !Database {
        return Database{ .connection = 42 };
    }

    pub fn deinit(self: *Database) void {
        std.debug.print("Closing connection {d}\n", .{self.connection});
        self.connection = 0;
    }

    pub fn query(self: *Database, sql: []const u8) !void {
        _ = sql;
        std.debug.print("Executing on connection {d}\n", .{self.connection});
    }
};

test "defer execution order" {
    var db = try Database.init();
    defer db.deinit();

    try db.query("SELECT * FROM users");
    // deinit() called here automatically
}
```

### Using errdefer for Error Cleanup

The `errdefer` statement only runs if the function returns with an error:

```zig
const Resource = struct {
    data: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, size: usize) !Resource {
        const data = try allocator.alloc(u8, size);
        errdefer allocator.free(data);

        // If this fails, data is freed automatically
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

test "errdefer on failure" {
    const allocator = std.testing.allocator;

    // This succeeds
    var res1 = try Resource.init(allocator, 100);
    defer res1.deinit();

    // This fails but doesn't leak because of errdefer
    const res2 = Resource.init(allocator, 2000);
    try std.testing.expectError(error.TooLarge, res2);
}
```

### Multiple Resource Management

Handle multiple resources with proper cleanup order:

```zig
const Connection = struct {
    socket: i32,
    buffer: []u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Connection {
        const socket = 123; // Simulate opening socket
        errdefer {
            // Close socket if subsequent allocations fail
            std.debug.print("Closing socket on error\n", .{});
        }

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
        std.debug.print("Closing socket {d}\n", .{self.socket});
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
```

### Nested Defer Scopes

Defers execute in reverse order (LIFO):

```zig
test "defer execution order" {
    var count: u32 = 0;

    {
        defer count += 1; // Executes third
        defer count += 10; // Executes second
        defer count += 100; // Executes first

        try std.testing.expectEqual(@as(u32, 0), count);
    }

    // Order: 100 + 10 + 1 = 111
    try std.testing.expectEqual(@as(u32, 111), count);
}
```

### Scope-Based Resource Management

Create scoped wrappers for temporary resources:

```zig
const TempDir = struct {
    path: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !TempDir {
        const path = try std.fmt.allocPrint(allocator, "/tmp/{s}", .{name});
        errdefer allocator.free(path);

        // Simulate directory creation
        std.debug.print("Creating directory: {s}\n", .{path});

        return TempDir{
            .path = path,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TempDir) void {
        std.debug.print("Removing directory: {s}\n", .{self.path});
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
```

### Lock Guard Pattern

Implement automatic lock management:

```zig
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

        // Critical section - mutex is locked
        // ...
    }
    // mutex is automatically unlocked here
}
```

### Transaction-Style Operations

Implement rollback on error:

```zig
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
            std.debug.print("Rolling back transaction\n", .{});
            self.value.* = 0;
        }
    }

    pub fn execute(self: *Transaction, new_value: i32) !void {
        _ = self;
        if (new_value < 0) {
            return error.InvalidValue;
        }
        self.value.* = new_value;
    }
};

test "transaction rollback" {
    var value: i32 = 100;

    // Successful transaction
    {
        var txn = Transaction.init(&value);
        defer txn.deinit();

        try txn.execute(200);
        txn.commit();
    }
    try std.testing.expectEqual(@as(i32, 200), value);

    // Failed transaction - rolls back
    {
        var txn = Transaction.init(&value);
        defer txn.deinit();

        const result = txn.execute(-50);
        try std.testing.expectError(error.InvalidValue, result);
        // No commit called - deinit() rolls back
    }
    try std.testing.expectEqual(@as(i32, 0), value);
}
```

### Arena Allocator Pattern

Use arena for temporary allocations:

```zig
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

test "arena allocator cleanup" {
    var parser = Parser.init(std.testing.allocator);
    defer parser.deinit();

    const str1 = try parser.parseString("hello");
    const str2 = try parser.parseString("world");

    try std.testing.expectEqualStrings("hello", str1);
    try std.testing.expectEqualStrings("world", str2);

    // All allocations freed in deinit()
}
```

### Builder Pattern with Cleanup

Ensure resources are freed even if build fails:

```zig
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
```

### Best Practices

**Always Pair init/deinit:**
```zig
// Good: Clear lifecycle
var resource = try Resource.init(allocator);
defer resource.deinit();
```

**Use errdefer for Partial Cleanup:**
```zig
pub fn init(allocator: std.mem.Allocator) !MyStruct {
    const buffer = try allocator.alloc(u8, 1024);
    errdefer allocator.free(buffer);

    const more = try allocator.alloc(u8, 512);
    errdefer allocator.free(more);

    return MyStruct{ .buffer = buffer, .more = more };
}
```

**Defer Order Matters:**
```zig
// Defers execute in reverse order (LIFO)
var a = try initA();
defer a.deinit(); // Called last

var b = try initB();
defer b.deinit(); // Called first
```

**Document Ownership:**
```zig
/// Caller owns returned memory and must call deinit()
pub fn create(allocator: std.mem.Allocator) !*MyStruct {
    // ...
}
```

### Related Patterns

- Recipe 7.11: Inlining callback functions
- Recipe 8.19: Implementing state machines
- Chapter 18: Explicit Memory Management Patterns
