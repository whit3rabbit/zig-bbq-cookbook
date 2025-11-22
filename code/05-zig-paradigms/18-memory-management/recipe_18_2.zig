// Recipe 18.2: Arena Allocator Patterns for Request Handling
// This recipe demonstrates using arena allocators for request/response lifecycles,
// batch processing, and automatic cleanup patterns.

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

// ANCHOR: basic_arena
// Basic arena allocator usage with automatic cleanup
test "basic arena allocator" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Allocate multiple items
    const slice1 = try allocator.alloc(u8, 100);
    const slice2 = try allocator.alloc(u32, 50);
    const slice3 = try allocator.alloc(u64, 25);

    // Use the allocations
    slice1[0] = 42;
    slice2[0] = 12345;
    slice3[0] = 9876543210;

    try testing.expectEqual(@as(u8, 42), slice1[0]);
    try testing.expectEqual(@as(u32, 12345), slice2[0]);
    try testing.expectEqual(@as(u64, 9876543210), slice3[0]);

    // All memory freed automatically by arena.deinit()
}
// ANCHOR_END: basic_arena

// ANCHOR: request_response
/// Request/response lifecycle with arena
const Request = struct {
    id: u32,
    path: []const u8,
    headers: std.StringHashMap([]const u8),
    body: []const u8,

    pub fn init(allocator: Allocator, id: u32, path: []const u8) !Request {
        return .{
            .id = id,
            .path = try allocator.dupe(u8, path),
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = &.{},
        };
    }

    pub fn addHeader(self: *Request, key: []const u8, value: []const u8) !void {
        const allocator = self.headers.allocator;
        const owned_key = try allocator.dupe(u8, key);
        const owned_value = try allocator.dupe(u8, value);
        try self.headers.put(owned_key, owned_value);
    }

    pub fn setBody(self: *Request, allocator: Allocator, body: []const u8) !void {
        self.body = try allocator.dupe(u8, body);
    }
};

const Response = struct {
    status: u16,
    headers: std.StringHashMap([]const u8),
    body: []const u8,

    pub fn init(allocator: Allocator, status: u16) Response {
        return .{
            .status = status,
            .headers = std.StringHashMap([]const u8).init(allocator),
            .body = &.{},
        };
    }

    pub fn addHeader(self: *Response, key: []const u8, value: []const u8) !void {
        const allocator = self.headers.allocator;
        const owned_key = try allocator.dupe(u8, key);
        const owned_value = try allocator.dupe(u8, value);
        try self.headers.put(owned_key, owned_value);
    }

    pub fn setBody(self: *Response, allocator: Allocator, body: []const u8) !void {
        self.body = try allocator.dupe(u8, body);
    }
};

fn handleRequest(allocator: Allocator, request: Request) !Response {
    var response = Response.init(allocator, 200);

    // Process request and build response
    try response.addHeader("Content-Type", "application/json");
    try response.addHeader("X-Request-ID", try std.fmt.allocPrint(allocator, "{d}", .{request.id}));

    const body = try std.fmt.allocPrint(
        allocator,
        "{{\"path\": \"{s}\", \"headers\": {d}}}",
        .{ request.path, request.headers.count() },
    );
    try response.setBody(allocator, body);

    return response;
}

test "request/response lifecycle" {
    // Each request gets its own arena
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var request = try Request.init(allocator, 123, "/api/users");
    try request.addHeader("Authorization", "Bearer token123");
    try request.addHeader("Accept", "application/json");
    try request.setBody(allocator, "{\"name\": \"Alice\"}");

    const response = try handleRequest(allocator, request);

    try testing.expectEqual(@as(u16, 200), response.status);
    try testing.expect(response.body.len > 0);

    // All allocations (request + response) freed at arena.deinit()
}
// ANCHOR_END: request_response

// ANCHOR: batch_processing
// Batch processing with arena reset
const Record = struct {
    id: u32,
    data: []const u8,
    processed: bool,
};

fn processBatch(allocator: Allocator, ids: []const u32) ![]Record {
    var records: std.ArrayList(Record) = .{};

    for (ids) |id| {
        const data = try std.fmt.allocPrint(allocator, "Record-{d}", .{id});
        try records.append(allocator, .{
            .id = id,
            .data = data,
            .processed = true,
        });
    }

    return records.toOwnedSlice(allocator);
}

test "batch processing with arena" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Process multiple batches
    const batch1 = &[_]u32{ 1, 2, 3 };
    const records1 = try processBatch(allocator, batch1);
    try testing.expectEqual(@as(usize, 3), records1.len);
    try testing.expect(records1[0].processed);

    // Reset arena to reuse memory
    _ = arena.reset(.retain_capacity);

    const batch2 = &[_]u32{ 4, 5, 6, 7 };
    const records2 = try processBatch(allocator, batch2);
    try testing.expectEqual(@as(usize, 4), records2.len);
    try testing.expect(records2[0].processed);

    // Previous records1 is now invalid (memory reused)
}
// ANCHOR_END: batch_processing

// ANCHOR: nested_arenas
// Nested arena scopes for hierarchical data
const Tree = struct {
    value: i32,
    children: []Tree,

    pub fn create(allocator: Allocator, value: i32, child_count: usize) !Tree {
        const children = try allocator.alloc(Tree, child_count);

        for (children, 0..) |*child, i| {
            child.* = .{
                .value = value * 10 + @as(i32, @intCast(i)),
                .children = &.{},
            };
        }

        return .{
            .value = value,
            .children = children,
        };
    }

    pub fn totalNodes(self: Tree) usize {
        var count: usize = 1;
        for (self.children) |child| {
            count += child.totalNodes();
        }
        return count;
    }
};

test "nested arena scopes" {
    var parent_arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer parent_arena.deinit();

    {
        // Child arena for temporary tree construction
        var child_arena = std.heap.ArenaAllocator.init(parent_arena.allocator());
        defer child_arena.deinit();

        const tree = try Tree.create(child_arena.allocator(), 1, 3);
        try testing.expectEqual(@as(i32, 1), tree.value);
        try testing.expectEqual(@as(usize, 3), tree.children.len);
        try testing.expectEqual(@as(usize, 4), tree.totalNodes());

        // tree and all children freed by child_arena.deinit()
    }

    // Parent arena memory still available for other operations
}
// ANCHOR_END: nested_arenas

// ANCHOR: arena_vs_general
// Performance comparison: arena vs general allocator
test "arena vs general allocator performance" {
    const iterations = 100;

    // Measure general allocator
    var general_timer = try std.time.Timer.start();
    {
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            const slice = try testing.allocator.alloc(u8, 1024);
            defer testing.allocator.free(slice);
            @memset(slice, 0);
        }
    }
    const general_ns = general_timer.read();

    // Measure arena allocator
    var arena_timer = try std.time.Timer.start();
    {
        var arena = std.heap.ArenaAllocator.init(testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            const slice = try allocator.alloc(u8, 1024);
            @memset(slice, 0);
        }
    }
    const arena_ns = arena_timer.read();

    // Arena should be faster (no individual frees)
    std.debug.print("\nGeneral: {d}ns, Arena: {d}ns, Speedup: {d:.2}x\n", .{
        general_ns,
        arena_ns,
        @as(f64, @floatFromInt(general_ns)) / @as(f64, @floatFromInt(arena_ns)),
    });
}
// ANCHOR_END: arena_vs_general

// ANCHOR: scoped_arena
// Scoped arena pattern for temporary allocations
fn buildJsonResponse(allocator: Allocator, user_id: u32, username: []const u8) ![]const u8 {
    // All allocations from this function will be freed together
    var list: std.ArrayList(u8) = .{};

    try list.appendSlice(allocator, "{\"user_id\": ");
    try list.writer(allocator).print("{d}", .{user_id});
    try list.appendSlice(allocator, ", \"username\": \"");
    try list.appendSlice(allocator, username);
    try list.appendSlice(allocator, "\"}");

    return list.toOwnedSlice(allocator);
}

test "scoped arena for function" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const json1 = try buildJsonResponse(allocator, 42, "alice");
    const json2 = try buildJsonResponse(allocator, 99, "bob");

    try testing.expect(std.mem.indexOf(u8, json1, "alice") != null);
    try testing.expect(std.mem.indexOf(u8, json2, "bob") != null);

    // Both json1 and json2 freed by arena.deinit()
}
// ANCHOR_END: scoped_arena

// ANCHOR: arena_state
// Arena with retained state pattern
const RequestProcessor = struct {
    arena: std.heap.ArenaAllocator,
    requests_processed: u32,

    pub fn init(backing_allocator: Allocator) RequestProcessor {
        return .{
            .arena = std.heap.ArenaAllocator.init(backing_allocator),
            .requests_processed = 0,
        };
    }

    pub fn deinit(self: *RequestProcessor) void {
        self.arena.deinit();
    }

    pub fn processRequest(self: *RequestProcessor, path: []const u8) ![]const u8 {
        const allocator = self.arena.allocator();
        self.requests_processed += 1;

        return try std.fmt.allocPrint(
            allocator,
            "Processed request #{d}: {s}",
            .{ self.requests_processed, path },
        );
    }

    pub fn reset(self: *RequestProcessor) void {
        _ = self.arena.reset(.retain_capacity);
        // Note: requests_processed is NOT reset
    }
};

test "arena with retained state" {
    var processor = RequestProcessor.init(testing.allocator);
    defer processor.deinit();

    const result1 = try processor.processRequest("/api/users");
    try testing.expect(std.mem.indexOf(u8, result1, "#1") != null);

    const result2 = try processor.processRequest("/api/posts");
    try testing.expect(std.mem.indexOf(u8, result2, "#2") != null);

    // Reset arena but keep counter
    processor.reset();

    const result3 = try processor.processRequest("/api/comments");
    try testing.expect(std.mem.indexOf(u8, result3, "#3") != null);

    try testing.expectEqual(@as(u32, 3), processor.requests_processed);
}
// ANCHOR_END: arena_state

// ANCHOR: multi_arena
// Multiple arenas for different lifetimes
const Server = struct {
    config_arena: std.heap.ArenaAllocator,
    request_arena: std.heap.ArenaAllocator,
    config: []const u8,

    pub fn init(backing_allocator: Allocator) Server {
        return .{
            .config_arena = std.heap.ArenaAllocator.init(backing_allocator),
            .request_arena = std.heap.ArenaAllocator.init(backing_allocator),
            .config = &.{},
        };
    }

    pub fn deinit(self: *Server) void {
        self.request_arena.deinit();
        self.config_arena.deinit();
    }

    pub fn loadConfig(self: *Server, config_data: []const u8) !void {
        const allocator = self.config_arena.allocator();
        self.config = try allocator.dupe(u8, config_data);
    }

    pub fn handleRequest(self: *Server, path: []const u8) ![]const u8 {
        const allocator = self.request_arena.allocator();
        return try std.fmt.allocPrint(
            allocator,
            "Config: {s}, Path: {s}",
            .{ self.config, path },
        );
    }

    pub fn resetRequests(self: *Server) void {
        _ = self.request_arena.reset(.retain_capacity);
    }
};

test "multiple arenas for different lifetimes" {
    var server = Server.init(testing.allocator);
    defer server.deinit();

    // Config lives for entire server lifetime
    try server.loadConfig("production");

    // Process multiple requests
    const resp1 = try server.handleRequest("/users");
    try testing.expect(std.mem.indexOf(u8, resp1, "production") != null);

    const resp2 = try server.handleRequest("/posts");
    try testing.expect(std.mem.indexOf(u8, resp2, "production") != null);

    // Reset request arena but keep config
    server.resetRequests();

    const resp3 = try server.handleRequest("/comments");
    try testing.expect(std.mem.indexOf(u8, resp3, "production") != null);
}
// ANCHOR_END: multi_arena

// ANCHOR: arena_optimization
// Arena optimization: preallocated buffer
test "arena with preallocated buffer" {
    var buffer: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);

    var arena = std.heap.ArenaAllocator.init(fba.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    // These allocations come from the stack buffer
    const slice1 = try allocator.alloc(u8, 100);
    const slice2 = try allocator.alloc(u32, 50);
    const slice3 = try allocator.alloc(u64, 25);

    slice1[0] = 1;
    slice2[0] = 2;
    slice3[0] = 3;

    try testing.expectEqual(@as(u8, 1), slice1[0]);
    try testing.expectEqual(@as(u32, 2), slice2[0]);
    try testing.expectEqual(@as(u64, 3), slice3[0]);

    // All from stack, no heap allocations
}
// ANCHOR_END: arena_optimization
