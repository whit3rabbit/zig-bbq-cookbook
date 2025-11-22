// Recipe 18.5: Stack-Based Allocation with FixedBufferAllocator
// This recipe demonstrates using stack-allocated buffers for memory management,
// eliminating heap allocations entirely for improved performance and predictability.

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

// ANCHOR: basic_fixed_buffer
// Basic fixed buffer allocator on the stack
test "basic fixed buffer allocator" {
    var buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    // Allocate from stack buffer
    const slice1 = try allocator.alloc(u32, 10);
    slice1[0] = 42;

    const slice2 = try allocator.alloc(u64, 5);
    slice2[0] = 123456789;

    try testing.expectEqual(@as(u32, 42), slice1[0]);
    try testing.expectEqual(@as(u64, 123456789), slice2[0]);

    // All memory automatically freed when buffer goes out of scope
}
// ANCHOR_END: basic_fixed_buffer

// ANCHOR: buffer_overflow
// Handling buffer overflow
test "fixed buffer overflow" {
    var buffer: [100]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    // This fits
    const slice1 = try allocator.alloc(u8, 50);
    try testing.expectEqual(@as(usize, 50), slice1.len);

    // This also fits
    const slice2 = try allocator.alloc(u8, 40);
    try testing.expectEqual(@as(usize, 40), slice2.len);

    // This exceeds buffer capacity
    const result = allocator.alloc(u8, 20);
    try testing.expectError(error.OutOfMemory, result);
}
// ANCHOR_END: buffer_overflow

// ANCHOR: buffer_reset
// Resetting fixed buffer allocator
test "resetting fixed buffer" {
    var buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    // Use some memory
    _ = try allocator.alloc(u8, 500);
    try testing.expectEqual(@as(usize, 500), fba.end_index);

    // Reset to reuse buffer
    fba.reset();
    try testing.expectEqual(@as(usize, 0), fba.end_index);

    // Can allocate again
    const slice = try allocator.alloc(u8, 800);
    try testing.expectEqual(@as(usize, 800), slice.len);
}
// ANCHOR_END: buffer_reset

// ANCHOR: thread_local_buffer
// Thread-local stack buffer pattern
threadlocal var thread_buffer: [4096]u8 = undefined;

fn processWithThreadLocal(data: []const u8) ![]u8 {
    var fba = std.heap.FixedBufferAllocator.init(&thread_buffer);
    const allocator = fba.allocator();

    // Process data using thread-local buffer
    const result = try allocator.alloc(u8, data.len * 2);
    for (data, 0..) |byte, i| {
        result[i * 2] = byte;
        result[i * 2 + 1] = byte;
    }

    return result;
}

test "thread-local buffer" {
    const input = "Hello";
    const output = try processWithThreadLocal(input);

    try testing.expectEqual(@as(usize, 10), output.len);
    try testing.expectEqual(@as(u8, 'H'), output[0]);
    try testing.expectEqual(@as(u8, 'H'), output[1]);
}
// ANCHOR_END: thread_local_buffer

// ANCHOR: nested_fixed_buffers
// Nested fixed buffer allocators
fn parseJson(allocator: Allocator, json: []const u8) !u32 {
    // Inner function with its own stack buffer
    var buffer: [256]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const temp_allocator = fba.allocator();

    // Parse using temporary buffer
    _ = json;
    const temp = try temp_allocator.alloc(u8, 100);
    @memset(temp, 0);

    // Real result allocated from parent allocator
    _ = allocator;
    return 42;
}

test "nested fixed buffers" {
    var outer_buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&outer_buffer);
    const allocator = fba.allocator();

    const result = try parseJson(allocator, "{\"value\": 42}");
    try testing.expectEqual(@as(u32, 42), result);
}
// ANCHOR_END: nested_fixed_buffers

// ANCHOR: string_building
// String building with fixed buffer
fn buildMessage(allocator: Allocator, name: []const u8, count: u32) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "Hello, {s}! Count: {d}", .{ name, count });
}

test "string building with fixed buffer" {
    var buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    const msg1 = try buildMessage(allocator, "Alice", 10);
    try testing.expect(std.mem.eql(u8, "Hello, Alice! Count: 10", msg1));

    fba.reset();

    const msg2 = try buildMessage(allocator, "Bob", 20);
    try testing.expect(std.mem.eql(u8, "Hello, Bob! Count: 20", msg2));
}
// ANCHOR_END: string_building

// ANCHOR: performance_comparison
// Performance comparison: stack vs heap
test "stack vs heap performance" {
    const iterations = 1000;

    // Heap allocation
    var heap_timer = try std.time.Timer.start();
    {
        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            const slice = try testing.allocator.alloc(u8, 100);
            @memset(slice, 0);
            testing.allocator.free(slice);
        }
    }
    const heap_ns = heap_timer.read();

    // Stack allocation
    var stack_timer = try std.time.Timer.start();
    {
        var buffer: [100 * 1000]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buffer);
        const allocator = fba.allocator();

        var i: usize = 0;
        while (i < iterations) : (i += 1) {
            const slice = try allocator.alloc(u8, 100);
            @memset(slice, 0);
        }
    }
    const stack_ns = stack_timer.read();

    std.debug.print("\nHeap: {d}ns, Stack: {d}ns, Speedup: {d:.2}x\n", .{
        heap_ns,
        stack_ns,
        @as(f64, @floatFromInt(heap_ns)) / @as(f64, @floatFromInt(stack_ns)),
    });
}
// ANCHOR_END: performance_comparison

// ANCHOR: request_handler
// Request handler pattern with stack buffer
const Request = struct {
    path: []const u8,
    headers: std.StringHashMap([]const u8),

    pub fn init(allocator: Allocator, path: []const u8) !Request {
        return .{
            .path = try allocator.dupe(u8, path),
            .headers = std.StringHashMap([]const u8).init(allocator),
        };
    }
};

fn handleRequest(path: []const u8) ![]const u8 {
    var buffer: [4096]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    var req = try Request.init(allocator, path);
    _ = try req.headers.put("Content-Type", "application/json");

    return try std.fmt.allocPrint(allocator, "{{\"path\": \"{s}\"}}", .{req.path});
}

test "request handler with stack buffer" {
    const response = try handleRequest("/api/users");
    try testing.expect(std.mem.indexOf(u8, response, "/api/users") != null);
}
// ANCHOR_END: request_handler

// ANCHOR: fallback_allocator
// Fallback allocator: try stack first, then heap
fn processWithFallback(stack_allocator: Allocator, heap_allocator: Allocator, size: usize) ![]u8 {
    // Try stack allocation first
    if (stack_allocator.alloc(u8, size)) |slice| {
        return slice;
    } else |_| {
        // Fall back to heap if stack is exhausted
        return try heap_allocator.alloc(u8, size);
    }
}

test "fallback allocator" {
    var buffer: [100]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const stack_allocator = fba.allocator();

    // Small allocation uses stack
    const small = try processWithFallback(stack_allocator, testing.allocator, 50);
    try testing.expectEqual(@as(usize, 50), small.len);

    // Large allocation uses heap
    const large = try processWithFallback(stack_allocator, testing.allocator, 200);
    defer testing.allocator.free(large);
    try testing.expectEqual(@as(usize, 200), large.len);
}
// ANCHOR_END: fallback_allocator

// ANCHOR: scoped_buffer
// Scoped buffer pattern for temporary processing
fn processDataWithStack(input: []const u8) !u32 {
    var buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    // All allocations from stack buffer
    const temp = try allocator.alloc(u8, input.len);
    @memcpy(temp, input);

    const upper = try allocator.alloc(u8, input.len);
    for (input, 0..) |c, i| {
        upper[i] = std.ascii.toUpper(c);
    }

    return @as(u32, @intCast(temp.len + upper.len));
}

test "scoped buffer pattern" {
    const result = try processDataWithStack("Hello, World!");
    try testing.expectEqual(@as(u32, 26), result);
}
// ANCHOR_END: scoped_buffer
