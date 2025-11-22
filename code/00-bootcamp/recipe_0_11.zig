// Recipe 0.11: Optionals, Errors, and Resource Cleanup (EXPANDED)
// Target Zig Version: 0.15.2
//
// This recipe covers optionals (?T), error unions (!T), and resource cleanup
// with defer and errdefer.

const std = @import("std");
const testing = std.testing;

// ANCHOR: optionals
// Part 1: Optionals (?T)
//
// Optionals represent values that might be null

test "basic optionals" {
    // ?T means "optional T" - can be a value or null
    var maybe_num: ?i32 = 42;
    try testing.expect(maybe_num != null);

    // Set to null
    maybe_num = null;
    try testing.expect(maybe_num == null);

    // Create optional with value
    const some_value: ?i32 = 100;
    try testing.expect(some_value != null);
}

test "unwrapping optionals with if" {
    const maybe_value: ?i32 = 42;

    // Unwrap with if - safe way to access the value
    if (maybe_value) |value| {
        try testing.expectEqual(@as(i32, 42), value);
    } else {
        try testing.expect(false); // Won't run
    }

    // Null case
    const no_value: ?i32 = null;
    if (no_value) |_| {
        try testing.expect(false); // Won't run
    } else {
        try testing.expect(true); // This runs
    }
}

test "unwrapping with orelse" {
    const maybe_value: ?i32 = 42;

    // Use orelse to provide a default
    const value1 = maybe_value orelse 0;
    try testing.expectEqual(@as(i32, 42), value1);

    const no_value: ?i32 = null;
    const value2 = no_value orelse 100;
    try testing.expectEqual(@as(i32, 100), value2);
}

test "optional pointers" {
    var x: i32 = 42;
    var ptr: ?*i32 = &x;

    // Unwrap optional pointer
    if (ptr) |p| {
        try testing.expectEqual(@as(i32, 42), p.*);
    }

    ptr = null;
    try testing.expect(ptr == null);
}

fn findInArray(arr: []const i32, target: i32) ?usize {
    for (arr, 0..) |val, i| {
        if (val == target) return i;
    }
    return null;
}

test "functions returning optionals" {
    const numbers = [_]i32{ 10, 20, 30, 40, 50 };

    const index1 = findInArray(&numbers, 30);
    try testing.expect(index1 != null);
    try testing.expectEqual(@as(usize, 2), index1.?);

    const index2 = findInArray(&numbers, 99);
    try testing.expect(index2 == null);
}
// ANCHOR_END: optionals

// ANCHOR: error_unions
// Part 2: Error Unions (!T)
//
// Error unions represent operations that can fail

test "basic error unions" {
    // !T means "error union T" - can be a value or an error
    const success: anyerror!i32 = 42;
    const failure: anyerror!i32 = error.Failed;

    // Check for errors
    if (success) |val| {
        try testing.expectEqual(@as(i32, 42), val);
    } else |_| {
        try testing.expect(false);
    }

    if (failure) |_| {
        try testing.expect(false);
    } else |err| {
        try testing.expectEqual(error.Failed, err);
    }
}

const MathError = error{
    DivisionByZero,
    Overflow,
};

fn divide(a: i32, b: i32) MathError!i32 {
    if (b == 0) return error.DivisionByZero;
    if (a == std.math.minInt(i32) and b == -1) return error.Overflow;
    return @divTrunc(a, b);
}

test "custom error sets" {
    const result1 = try divide(10, 2);
    try testing.expectEqual(@as(i32, 5), result1);

    const result2 = divide(10, 0);
    try testing.expectError(error.DivisionByZero, result2);

    const result3 = divide(std.math.minInt(i32), -1);
    try testing.expectError(error.Overflow, result3);
}

test "propagating errors with try" {
    const safeDivide = struct {
        fn call(a: i32, b: i32) MathError!i32 {
            // try propagates the error up
            const result = try divide(a, b);
            return result * 2;
        }
    }.call;

    const result1 = try safeDivide(10, 2);
    try testing.expectEqual(@as(i32, 10), result1);

    const result2 = safeDivide(10, 0);
    try testing.expectError(error.DivisionByZero, result2);
}

test "handling errors with catch" {
    const divideOrZero = struct {
        fn call(a: i32, b: i32) i32 {
            return divide(a, b) catch 0;
        }
    }.call;

    const result1 = divideOrZero(10, 2);
    try testing.expectEqual(@as(i32, 5), result1);

    const result2 = divideOrZero(10, 0);
    try testing.expectEqual(@as(i32, 0), result2);
}

test "catch with error value" {
    const handleError = struct {
        fn call(a: i32, b: i32) i32 {
            return divide(a, b) catch |err| {
                std.debug.print("Error occurred: {}\n", .{err});
                return -1;
            };
        }
    }.call;

    const result = handleError(10, 0);
    try testing.expectEqual(@as(i32, -1), result);
}
// ANCHOR_END: error_unions

// ANCHOR: defer_errdefer
// Part 3: Resource Cleanup with defer and errdefer
//
// defer runs when scope exits, errdefer runs only on error

test "basic defer" {
    var counter: i32 = 0;

    {
        defer counter += 1;
        try testing.expectEqual(@as(i32, 0), counter);
    } // defer runs here

    try testing.expectEqual(@as(i32, 1), counter);
}

test "multiple defers run in reverse order" {
    var counter: i32 = 0;

    {
        defer counter += 1; // Runs third (last)
        defer counter += 10; // Runs second
        defer counter += 100; // Runs first

        try testing.expectEqual(@as(i32, 0), counter);
    } // defers run in reverse order: 100, then 10, then 1

    try testing.expectEqual(@as(i32, 111), counter);
}

fn allocateResource(allocator: std.mem.Allocator) ![]u8 {
    const data = try allocator.alloc(u8, 100);
    errdefer allocator.free(data); // Only runs if error occurs after this point

    // Simulate initialization that might fail
    if (data.len < 50) return error.TooSmall; // Won't happen, but demonstrates errdefer

    return data;
}

test "defer for resource cleanup" {
    const data = try allocateResource(testing.allocator);
    defer testing.allocator.free(data);

    // Use data
    try testing.expectEqual(@as(usize, 100), data.len);
}

fn createList(allocator: std.mem.Allocator, fail: bool) !std.ArrayList(i32) {
    var list = std.ArrayList(i32){};
    errdefer list.deinit(allocator); // Clean up if initialization fails

    try list.append(allocator, 1);
    try list.append(allocator, 2);

    if (fail) {
        return error.InitFailed; // errdefer will run
    }

    return list; // errdefer won't run
}

test "errdefer for error cleanup" {
    // Success case - errdefer doesn't run
    var list1 = try createList(testing.allocator, false);
    defer list1.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 2), list1.items.len);

    // Error case - errdefer runs and cleans up
    const result = createList(testing.allocator, true);
    try testing.expectError(error.InitFailed, result);
    // If errdefer didn't run, we'd have a memory leak
}

test "defer vs errdefer" {
    var regular_cleanup = false;
    var error_cleanup = false;

    const testFunc = struct {
        fn call(should_fail: bool, reg: *bool, err_clean: *bool) !void {
            defer reg.* = true; // Always runs
            errdefer err_clean.* = true; // Only runs on error

            if (should_fail) {
                return error.Failed;
            }
        }
    }.call;

    // Success case
    try testFunc(false, &regular_cleanup, &error_cleanup);
    try testing.expectEqual(true, regular_cleanup);
    try testing.expectEqual(false, error_cleanup);

    // Reset
    regular_cleanup = false;
    error_cleanup = false;

    // Error case
    const result = testFunc(true, &regular_cleanup, &error_cleanup);
    try testing.expectError(error.Failed, result);
    try testing.expectEqual(true, regular_cleanup); // defer ran
    try testing.expectEqual(true, error_cleanup); // errdefer also ran
}

fn initializeResource(allocator: std.mem.Allocator, stage: u8) !*std.ArrayList(i32) {
    const list = try allocator.create(std.ArrayList(i32));
    errdefer allocator.destroy(list);

    list.* = std.ArrayList(i32){};
    errdefer list.deinit(allocator);

    try list.append(allocator, 1);

    if (stage == 1) return error.StageFailed;

    try list.append(allocator, 2);

    if (stage == 2) return error.StageFailed;

    return list;
}

test "multiple errdefers for staged cleanup" {
    // Success
    const resource = try initializeResource(testing.allocator, 0);
    defer {
        resource.deinit(testing.allocator);
        testing.allocator.destroy(resource);
    }
    try testing.expectEqual(@as(usize, 2), resource.items.len);

    // Fail at stage 1 - both errdefers run
    const result1 = initializeResource(testing.allocator, 1);
    try testing.expectError(error.StageFailed, result1);

    // Fail at stage 2 - both errdefers run
    const result2 = initializeResource(testing.allocator, 2);
    try testing.expectError(error.StageFailed, result2);
}
// ANCHOR_END: defer_errdefer

// Combining optionals and errors

test "optional error unions" {
    const parseNumber = struct {
        fn call(str: []const u8) !?i32 {
            if (str.len == 0) return null;
            if (str[0] == 'x') return error.InvalidFormat;
            return 42;
        }
    }.call;

    // Success
    const result1 = try parseNumber("123");
    try testing.expectEqual(@as(?i32, 42), result1);

    // Null (not an error)
    const result2 = try parseNumber("");
    try testing.expectEqual(@as(?i32, null), result2);

    // Error
    const result3 = parseNumber("x");
    try testing.expectError(error.InvalidFormat, result3);
}

test "practical example: safe file operations" {
    // Simulate file operations with error handling
    const FileOps = struct {
        fn open(name: []const u8) !?*u32 {
            if (std.mem.eql(u8, name, "")) return null;
            if (std.mem.eql(u8, name, "bad")) return error.AccessDenied;

            const handle = try testing.allocator.create(u32);
            handle.* = 42;
            return handle;
        }

        fn close(handle: *u32, allocator: std.mem.Allocator) void {
            allocator.destroy(handle);
        }
    };

    // Successful open and close
    if (try FileOps.open("good.txt")) |handle| {
        defer FileOps.close(handle, testing.allocator);
        try testing.expectEqual(@as(u32, 42), handle.*);
    }

    // File doesn't exist (null, not error)
    const no_file = try FileOps.open("");
    try testing.expectEqual(@as(?*u32, null), no_file);

    // Access denied (error)
    const denied = FileOps.open("bad");
    try testing.expectError(error.AccessDenied, denied);
}

// Summary:
// - ?T: optional values (can be null)
// - !T: error unions (can be error or value)
// - Use if (val) |v| to unwrap optionals
// - Use if (val) |v| else |err| to unwrap errors
// - Use orelse for optional defaults
// - Use catch for error defaults
// - defer: always runs when scope exits
// - errdefer: only runs when scope exits due to error
// - Use errdefer for resource cleanup in error paths
