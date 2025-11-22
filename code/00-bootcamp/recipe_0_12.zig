// Recipe 0.12: Understanding Allocators (CRITICAL)
// Target Zig Version: 0.15.2
//
// This is critical for beginners from garbage-collected languages.
// Zig requires explicit memory allocation - no hidden allocations.

const std = @import("std");
const testing = std.testing;

// ANCHOR: why_allocators
// Part 1: Why Zig Needs Allocators
//
// Unlike Python/Java/JavaScript, Zig has NO default allocator
// You must explicitly choose where memory comes from

test "no default allocator" {
    // This would NOT compile in Zig:
    // var list = std.ArrayList(i32).init();  // error: missing allocator parameter

    // You MUST provide an allocator:
    var list = std.ArrayList(i32){};
    defer list.deinit(testing.allocator);

    try list.append(testing.allocator, 1);
    try list.append(testing.allocator, 2);

    try testing.expectEqual(@as(usize, 2), list.items.len);
}

test "allocator interface" {
    // std.mem.Allocator is an interface
    // All allocators implement the same interface:
    // - alloc(T, n) - allocate n items of type T
    // - free(memory) - free memory
    // - create(T) - allocate one T
    // - destroy(T) - free one T

    const allocator = testing.allocator;

    // Allocate a slice of 10 integers
    const numbers = try allocator.alloc(i32, 10);
    defer allocator.free(numbers);

    numbers[0] = 42;
    try testing.expectEqual(@as(i32, 42), numbers[0]);
    try testing.expectEqual(@as(usize, 10), numbers.len);

    // Allocate a single struct
    const Point = struct {
        x: i32,
        y: i32,
    };

    const point = try allocator.create(Point);
    defer allocator.destroy(point);

    point.* = .{ .x = 10, .y = 20 };
    try testing.expectEqual(@as(i32, 10), point.x);
}
// ANCHOR_END: why_allocators

// ANCHOR: allocator_types
// Part 2: Common Allocator Types
//
// Zig provides several allocators for different use cases

test "FixedBufferAllocator - stack memory" {
    // Fixed buffer - uses stack memory, no malloc
    var buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    // Allocate from the fixed buffer
    const numbers = try allocator.alloc(i32, 10);
    // No free needed - buffer is on stack

    numbers[0] = 100;
    try testing.expectEqual(@as(i32, 100), numbers[0]);

    // If you run out of buffer space, alloc returns error.OutOfMemory
    const result = allocator.alloc(i32, 1000);
    try testing.expectError(error.OutOfMemory, result);
}

test "GeneralPurposeAllocator - safe malloc" {
    // GPA is like malloc but with leak detection
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            @panic("Memory leak detected!");
        }
    }

    const allocator = gpa.allocator();

    // Allocate on heap
    const numbers = try allocator.alloc(i32, 100);
    defer allocator.free(numbers);

    numbers[50] = 42;
    try testing.expectEqual(@as(i32, 42), numbers[50]);

    // GPA checks for leaks when deinit() is called
}

test "ArenaAllocator - batch cleanup" {
    // Arena allocates many items, frees all at once
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit(); // Frees ALL allocations

    const allocator = arena.allocator();

    // Allocate many things
    const slice1 = try allocator.alloc(i32, 10);
    const slice2 = try allocator.alloc(i32, 20);
    const slice3 = try allocator.alloc(i32, 30);

    // No individual free calls needed!
    slice1[0] = 1;
    slice2[0] = 2;
    slice3[0] = 3;

    try testing.expectEqual(@as(i32, 1), slice1[0]);
    try testing.expectEqual(@as(i32, 2), slice2[0]);
    try testing.expectEqual(@as(i32, 3), slice3[0]);

    // arena.deinit() frees everything at once
}

test "testing.allocator - for tests" {
    // testing.allocator is a GPA configured for testing
    // It detects memory leaks automatically

    const allocator = testing.allocator;

    const numbers = try allocator.alloc(i32, 50);
    defer allocator.free(numbers);

    // If you forget the defer, test will fail with leak detection
    numbers[0] = 99;
    try testing.expectEqual(@as(i32, 99), numbers[0]);
}
// ANCHOR_END: allocator_types

// ANCHOR: allocator_patterns
// Part 3: Common Allocator Patterns
//
// How to use allocators in real code

test "passing allocators to functions" {
    // Convention: allocator is first parameter
    const createList = struct {
        fn call(allocator: std.mem.Allocator, size: usize) ![]i32 {
            const list = try allocator.alloc(i32, size);
            for (list, 0..) |*item, i| {
                item.* = @intCast(i);
            }
            return list;
        }
    }.call;

    const list = try createList(testing.allocator, 5);
    defer testing.allocator.free(list);

    try testing.expectEqual(@as(i32, 0), list[0]);
    try testing.expectEqual(@as(i32, 4), list[4]);
}

test "struct with allocator field" {
    // Structs that allocate keep a reference to allocator
    const Buffer = struct {
        data: []u8,
        allocator: std.mem.Allocator,

        fn init(allocator: std.mem.Allocator, size: usize) !@This() {
            const data = try allocator.alloc(u8, size);
            return .{
                .data = data,
                .allocator = allocator,
            };
        }

        fn deinit(self: *@This()) void {
            self.allocator.free(self.data);
        }
    };

    var buffer = try Buffer.init(testing.allocator, 100);
    defer buffer.deinit();

    buffer.data[0] = 42;
    try testing.expectEqual(@as(u8, 42), buffer.data[0]);
}

test "arena for temporary allocations" {
    // Use arena for request-scoped lifetimes
    const processRequest = struct {
        fn call(parent_allocator: std.mem.Allocator) !i32 {
            var arena = std.heap.ArenaAllocator.init(parent_allocator);
            defer arena.deinit(); // Cleanup all at end

            const allocator = arena.allocator();

            // Allocate many temporary things
            const temp1 = try allocator.alloc(i32, 10);
            const temp2 = try allocator.alloc(i32, 20);

            // Do work...
            temp1[0] = 10;
            temp2[0] = 20;

            return temp1[0] + temp2[0];
        }
    }.call;

    const result = try processRequest(testing.allocator);
    try testing.expectEqual(@as(i32, 30), result);
    // All arena allocations freed automatically
}

test "choosing the right allocator" {
    // For small, known-size allocations - FixedBufferAllocator
    var buffer: [256]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const small_alloc = fba.allocator();

    const small_data = try small_alloc.alloc(u8, 10);
    small_data[0] = 1;
    try testing.expectEqual(@as(u8, 1), small_data[0]);

    // For temporary allocations - ArenaAllocator
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const temp_alloc = arena.allocator();

    const temp_data = try temp_alloc.alloc(i32, 100);
    temp_data[0] = 2;
    try testing.expectEqual(@as(i32, 2), temp_data[0]);

    // For general use - GeneralPurposeAllocator
    // (or testing.allocator in tests)
    const general_alloc = testing.allocator;
    const general_data = try general_alloc.alloc(f32, 50);
    defer general_alloc.free(general_data);

    general_data[0] = 3.0;
    try testing.expect(@abs(general_data[0] - 3.0) < 0.01);
}
// ANCHOR_END: allocator_patterns

// Handling out-of-memory errors

test "handling allocation failures" {
    // Allocations can fail - plan for it
    const tryAllocate = struct {
        fn call(allocator: std.mem.Allocator, size: usize) ![]u8 {
            const data = allocator.alloc(u8, size) catch |err| {
                std.debug.print("Allocation failed: {}\n", .{err});
                return err;
            };
            return data;
        }
    }.call;

    // This will likely succeed
    const data = try tryAllocate(testing.allocator, 100);
    defer testing.allocator.free(data);

    try testing.expectEqual(@as(usize, 100), data.len);

    // FixedBufferAllocator can run out of space
    var buffer: [10]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);

    const result = tryAllocate(fba.allocator(), 1000);
    try testing.expectError(error.OutOfMemory, result);
}

// Complex example

test "building a dynamic data structure" {
    // Realistic example: building a list of strings
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var names = std.ArrayList([]const u8){};
    defer names.deinit(allocator);

    // Add strings to list
    try names.append(allocator, "Alice");
    try names.append(allocator, "Bob");
    try names.append(allocator, "Charlie");

    // Create a copy of a string
    const name_copy = try allocator.dupe(u8, "David");
    try names.append(allocator, name_copy);

    try testing.expectEqual(@as(usize, 4), names.items.len);
    try testing.expect(std.mem.eql(u8, names.items[0], "Alice"));
    try testing.expect(std.mem.eql(u8, names.items[3], "David"));

    // arena.deinit() frees everything
}

test "allocator with errdefer" {
    const createAndInit = struct {
        fn call(allocator: std.mem.Allocator, should_fail: bool) ![]i32 {
            const data = try allocator.alloc(i32, 10);
            errdefer allocator.free(data); // Free if initialization fails

            // Initialize
            for (data, 0..) |*item, i| {
                item.* = @intCast(i);
            }

            if (should_fail) {
                return error.InitFailed; // errdefer runs
            }

            return data; // errdefer doesn't run
        }
    }.call;

    // Success case
    const data = try createAndInit(testing.allocator, false);
    defer testing.allocator.free(data);
    try testing.expectEqual(@as(i32, 5), data[5]);

    // Failure case - errdefer prevents leak
    const result = createAndInit(testing.allocator, true);
    try testing.expectError(error.InitFailed, result);
}

// Summary:
// - Zig has NO default allocator - you must provide one
// - std.mem.Allocator is the interface all allocators implement
// - FixedBufferAllocator: stack memory, no malloc
// - GeneralPurposeAllocator: safe malloc with leak detection
// - ArenaAllocator: batch allocate, free all at once
// - testing.allocator: for tests, detects leaks
// - Convention: allocator is first function parameter
// - Always use defer/errdefer to prevent leaks
// - Handle allocation failures with try/catch
