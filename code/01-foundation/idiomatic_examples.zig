// Idiomatic Zig Examples
// Target Zig Version: 0.15.2
//
// This file demonstrates all the idiomatic patterns covered in the foundation guide.
// Run: zig test code/01-foundation/idiomatic_examples.zig

const std = @import("std");
const testing = std.testing;

// ==============================================================================
// Naming Conventions Example
// ==============================================================================

// ANCHOR: user_account
// Type: PascalCase
pub const UserAccount = struct {
    // Fields: camelCase
    username: []const u8,
    createdAt: i64,

    // Function: camelCase, allocator first
    pub fn init(allocator: std.mem.Allocator, username: []const u8) !UserAccount {
        const owned_name = try allocator.dupe(u8, username);
        errdefer allocator.free(owned_name);

        return UserAccount{
            .username = owned_name,
            .createdAt = std.time.timestamp(),
        };
    }

    pub fn deinit(self: *UserAccount, allocator: std.mem.Allocator) void {
        allocator.free(self.username);
    }
};
// ANCHOR_END: user_account

test "naming conventions - UserAccount" {
    const allocator = testing.allocator;

    var account = try UserAccount.init(allocator, "alice");
    defer account.deinit(allocator);

    try testing.expectEqualStrings("alice", account.username);
}

// ==============================================================================
// Generic Data Structure using comptime
// ==============================================================================

// ANCHOR: generic_stack
fn Stack(comptime T: type) type {
    return struct {
        items: std.ArrayList(T),
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .items = std.ArrayList(T){},
                .allocator = allocator,
            };
        }

        pub fn push(self: *Self, item: T) !void {
            try self.items.append(self.allocator, item);
        }

        pub fn pop(self: *Self) ?T {
            if (self.items.items.len == 0) return null;
            return self.items.pop();
        }

        pub fn deinit(self: *Self) void {
            self.items.deinit(self.allocator);
        }
    };
}
// ANCHOR_END: generic_stack

test "generic Stack with comptime" {
    const allocator = testing.allocator;

    // Create a stack of integers
    var int_stack = Stack(i32).init(allocator);
    defer int_stack.deinit();

    try int_stack.push(1);
    try int_stack.push(2);
    try int_stack.push(3);

    try testing.expectEqual(@as(?i32, 3), int_stack.pop());
    try testing.expectEqual(@as(?i32, 2), int_stack.pop());
    try testing.expectEqual(@as(?i32, 1), int_stack.pop());
    try testing.expectEqual(@as(?i32, null), int_stack.pop());
}

// ==============================================================================
// Error Handling Patterns
// ==============================================================================

// ANCHOR: divide_function
pub fn divide(a: f64, b: f64) !f64 {
    if (b == 0.0) return error.DivisionByZero;
    return a / b;
}
// ANCHOR_END: divide_function

test "error handling - divide" {
    // Success case
    const result = try divide(10.0, 2.0);
    try testing.expectEqual(5.0, result);

    // Error case
    try testing.expectError(error.DivisionByZero, divide(10.0, 0.0));
}

// ANCHOR: max_function
// Generic max function using comptime
fn max(comptime T: type, a: T, b: T) T {
    return if (a > b) a else b;
}
// ANCHOR_END: max_function

test "comptime generic function - max" {
    try testing.expectEqual(@as(i32, 10), max(i32, 5, 10));
    try testing.expectEqual(@as(f64, 3.14), max(f64, 2.71, 3.14));
    try testing.expectEqual(@as(u8, 255), max(u8, 100, 255));
}

// ==============================================================================
// Allocator Patterns with defer/errdefer
// ==============================================================================

// ANCHOR: create_message
pub fn createMessage(allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    // Allocate memory - might fail with error.OutOfMemory
    const message = try std.fmt.allocPrint(allocator, "Hello, {s}!", .{name});
    // Caller is responsible for freeing the returned slice
    return message;
}
// ANCHOR_END: create_message

test "allocator pattern - createMessage" {
    const allocator = testing.allocator;

    const message = try createMessage(allocator, "World");
    defer allocator.free(message);

    try testing.expectEqualStrings("Hello, World!", message);
}

// ==============================================================================
// Init/Deinit Pattern
// ==============================================================================

// ANCHOR: cache_struct
pub const Cache = struct {
    data: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Cache {
        return Cache{
            .data = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    /// Store a key-value pair in the cache.
    ///
    /// IMPORTANT: StringHashMap stores key REFERENCES, not copies.
    /// Keys must remain valid for the lifetime of the map.
    ///
    /// Safe key types:
    /// - String literals: try cache.put("key", "value")
    /// - Arena-allocated strings that live as long as the cache
    ///
    /// Unsafe key types (will cause dangling pointers):
    /// - Stack buffers that go out of scope
    /// - Temporary strings from functions
    /// - Previously freed memory
    ///
    /// For dynamic keys, either:
    /// 1. Use an arena allocator for all keys, OR
    /// 2. Duplicate the key and manage its lifetime separately:
    ///    const owned_key = try allocator.dupe(u8, key);
    ///    gop.key_ptr.* = owned_key; // See recipe_11_4.zig for example
    pub fn put(self: *Cache, key: []const u8, value: []const u8) !void {
        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);

        // Use getOrPut for atomic operation - prevents data loss if put() fails
        const result = try self.data.getOrPut(key);
        if (result.found_existing) {
            // Free old value only AFTER we know the map operation succeeded
            self.allocator.free(result.value_ptr.*);
        }
        // Assign new value (cannot fail)
        result.value_ptr.* = owned_value;
    }

    pub fn get(self: *Cache, key: []const u8) ?[]const u8 {
        return self.data.get(key);
    }

    pub fn deinit(self: *Cache) void {
        var it = self.data.valueIterator();
        while (it.next()) |value| {
            self.allocator.free(value.*);
        }
        self.data.deinit();
    }
};
// ANCHOR_END: cache_struct

test "init/deinit pattern - Cache" {
    const allocator = testing.allocator;

    var cache = Cache.init(allocator);
    defer cache.deinit();

    try cache.put("name", "Alice");
    try cache.put("city", "Portland");

    const name = cache.get("name");
    try testing.expect(name != null);
    try testing.expectEqualStrings("Alice", name.?);

    const missing = cache.get("missing");
    try testing.expectEqual(@as(?[]const u8, null), missing);
}

test "Cache handles key overwrites without leaking" {
    const allocator = testing.allocator;

    var cache = Cache.init(allocator);
    defer cache.deinit();

    // Put initial value
    try cache.put("name", "Alice");
    try testing.expectEqualStrings("Alice", cache.get("name").?);

    // Overwrite with new value - old value should be freed automatically
    try cache.put("name", "Bob");
    try testing.expectEqualStrings("Bob", cache.get("name").?);

    // Overwrite again
    try cache.put("name", "Charlie");
    try testing.expectEqualStrings("Charlie", cache.get("name").?);
    // If we leaked memory, testing.allocator would catch it
}

// ==============================================================================
// Slice vs Pointer Preference
// ==============================================================================

// ANCHOR: print_names_slice
fn printNamesSlice(names: []const []const u8) usize {
    var count: usize = 0;
    for (names) |name| {
        _ = name; // In real code, would print
        count += 1;
    }
    return count;
}
// ANCHOR_END: print_names_slice

test "slice preference - easier iteration" {
    const names = [_][]const u8{ "Alice", "Bob", "Charlie" };
    const count = printNamesSlice(&names);
    try testing.expectEqual(@as(usize, 3), count);
}

// ==============================================================================
// Compile-Time Configuration
// ==============================================================================

// ANCHOR: connection_pool
const Config = struct {
    max_connections: usize,
    timeout_ms: u32,
};

fn ConnectionPool(comptime config: Config) type {
    return struct {
        const max_connections = config.max_connections;
        const timeout_ms = config.timeout_ms;

        active_count: usize,

        pub fn init() @This() {
            return .{
                .active_count = 0,
            };
        }

        pub fn canAcceptConnection(self: @This()) bool {
            return self.active_count < max_connections;
        }

        pub fn getMaxConnections() usize {
            return max_connections;
        }
    };
}
// ANCHOR_END: connection_pool

test "compile-time configuration - ConnectionPool" {
    const SmallPool = ConnectionPool(.{
        .max_connections = 10,
        .timeout_ms = 5000,
    });

    const LargePool = ConnectionPool(.{
        .max_connections = 1000,
        .timeout_ms = 30000,
    });

    var small = SmallPool.init();
    try testing.expectEqual(true, small.canAcceptConnection());
    try testing.expectEqual(@as(usize, 10), SmallPool.getMaxConnections());

    var large = LargePool.init();
    try testing.expectEqual(true, large.canAcceptConnection());
    try testing.expectEqual(@as(usize, 1000), LargePool.getMaxConnections());
}

// ==============================================================================
// Defer and errdefer for Resource Management
// ==============================================================================

// ANCHOR: defer_example
const Resource = struct {
    value: i32,
    allocator: std.mem.Allocator,

    pub fn create(allocator: std.mem.Allocator, value: i32) !*Resource {
        const resource = try allocator.create(Resource);
        resource.* = .{
            .value = value,
            .allocator = allocator,
        };
        return resource;
    }

    pub fn destroy(self: *Resource) void {
        self.allocator.destroy(self);
    }
};

fn processWithDefer(allocator: std.mem.Allocator, should_fail: bool) !i32 {
    const resource = try Resource.create(allocator, 42);
    defer resource.destroy(); // Always called when function exits

    if (should_fail) {
        return error.ProcessingFailed;
    }

    return resource.value * 2;
}
// ANCHOR_END: defer_example

test "defer ensures cleanup on success" {
    const allocator = testing.allocator;
    const result = try processWithDefer(allocator, false);
    try testing.expectEqual(@as(i32, 84), result);
}

test "defer ensures cleanup on error" {
    const allocator = testing.allocator;
    try testing.expectError(error.ProcessingFailed, processWithDefer(allocator, true));
}

// ANCHOR: errdefer_example
fn processWithErrDefer(allocator: std.mem.Allocator, should_fail: bool) ![]u8 {
    const buffer = try allocator.alloc(u8, 100);
    errdefer allocator.free(buffer); // Only called if we return an error

    if (should_fail) {
        return error.ProcessingFailed;
    }

    // Success path - caller must free the buffer
    return buffer;
}
// ANCHOR_END: errdefer_example

test "errdefer cleans up on error path only" {
    const allocator = testing.allocator;

    // Success - we must free
    const buffer = try processWithErrDefer(allocator, false);
    defer allocator.free(buffer);
    try testing.expectEqual(@as(usize, 100), buffer.len);

    // Error - errdefer already freed it
    try testing.expectError(error.ProcessingFailed, processWithErrDefer(allocator, true));
}
