// Testing Strategy Examples
// Target Zig Version: 0.15.2
//
// This file demonstrates all testing patterns covered in the foundation guide.
// Run: zig test code/01-foundation/testing_examples.zig

const std = @import("std");
const testing = std.testing;

// ==============================================================================
// Basic Functions to Test
// ==============================================================================

// ANCHOR: basic_functions
fn add(a: i32, b: i32) i32 {
    return a + b;
}

fn isEven(n: i32) bool {
    return @mod(n, 2) == 0;
}

fn divide(a: i32, b: i32) !i32 {
    if (b == 0) return error.DivisionByZero;
    return @divTrunc(a, b);
}
// ANCHOR_END: basic_functions

// ==============================================================================
// Basic Testing
// ==============================================================================

// ANCHOR: basic_test
test "add function works correctly" {
    const result = add(2, 3);
    try testing.expectEqual(@as(i32, 5), result);
}
// ANCHOR_END: basic_test

// ANCHOR: common_assertions
test "expectEqual usage" {
    try testing.expectEqual(@as(i32, 42), add(40, 2));
    try testing.expectEqual(@as(usize, 3), "foo".len);
}

test "expect usage" {
    try testing.expect(add(2, 2) == 4);
    try testing.expect("hello".len > 0);
}

test "expectEqualStrings usage" {
    const name = "Alice";
    try testing.expectEqualStrings("Alice", name);
}

test "expectError usage" {
    try testing.expectError(error.DivisionByZero, divide(10, 0));
}

test "expectEqualSlices usage" {
    const expected = [_]i32{ 1, 2, 3 };
    const actual = [_]i32{ 1, 2, 3 };
    try testing.expectEqualSlices(i32, &expected, &actual);
}
// ANCHOR_END: common_assertions

// ==============================================================================
// Testing with Allocators
// ==============================================================================

// ANCHOR: testing_allocator
test "no memory leaks" {
    const allocator = testing.allocator;

    const numbers = try allocator.alloc(i32, 10);
    defer allocator.free(numbers); // Must free or test fails

    numbers[0] = 42;
    try testing.expectEqual(@as(i32, 42), numbers[0]);
}

fn createGreeting(allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "Hello, {s}!", .{name});
}

test "createGreeting allocates correctly" {
    const allocator = testing.allocator;

    const greeting = try createGreeting(allocator, "World");
    defer allocator.free(greeting);

    try testing.expectEqualStrings("Hello, World!", greeting);
}
// ANCHOR_END: testing_allocator

// ==============================================================================
// Multiple Tests Per File
// ==============================================================================

// ANCHOR: multiple_tests
test "isEven with even number" {
    try testing.expect(isEven(4));
}

test "isEven with odd number" {
    try testing.expect(!isEven(5));
}

test "isEven with zero" {
    try testing.expect(isEven(0));
}

test "isEven with negative numbers" {
    try testing.expect(isEven(-2));
    try testing.expect(!isEven(-3));
}
// ANCHOR_END: multiple_tests

// ==============================================================================
// Testing Private Functions
// ==============================================================================

// ANCHOR: private_functions
fn validateEmail(email: []const u8) bool {
    return std.mem.indexOf(u8, email, "@") != null;
}

test "validateEmail accepts valid emails" {
    try testing.expect(validateEmail("user@example.com"));
    try testing.expect(validateEmail("test@test.org"));
}

test "validateEmail rejects invalid emails" {
    try testing.expect(!validateEmail("notanemail"));
    try testing.expect(!validateEmail("missing.at"));
}
// ANCHOR_END: private_functions

// ==============================================================================
// Testing Error Cases
// ==============================================================================

// ANCHOR: error_testing
fn parseAge(text: []const u8) !u8 {
    const num = try std.fmt.parseInt(u8, text, 10);
    if (num > 150) return error.InvalidAge;
    return num;
}

test "parseAge success cases" {
    try testing.expectEqual(@as(u8, 25), try parseAge("25"));
    try testing.expectEqual(@as(u8, 0), try parseAge("0"));
    try testing.expectEqual(@as(u8, 100), try parseAge("100"));
}

test "parseAge error cases" {
    try testing.expectError(error.InvalidCharacter, parseAge("abc"));
    try testing.expectError(error.InvalidAge, parseAge("200"));
    try testing.expectError(error.Overflow, parseAge("999"));
}
// ANCHOR_END: error_testing

// ==============================================================================
// Testing Struct Methods
// ==============================================================================

// ANCHOR: struct_testing
const Counter = struct {
    value: i32,

    pub fn init() Counter {
        return .{ .value = 0 };
    }

    pub fn increment(self: *Counter) void {
        self.value += 1;
    }

    pub fn decrement(self: *Counter) void {
        self.value -= 1;
    }

    pub fn reset(self: *Counter) void {
        self.value = 0;
    }

    pub fn getValue(self: Counter) i32 {
        return self.value;
    }
};

test "Counter.init starts at zero" {
    const counter = Counter.init();
    try testing.expectEqual(@as(i32, 0), counter.value);
}

test "Counter.increment increases value" {
    var counter = Counter.init();
    counter.increment();
    try testing.expectEqual(@as(i32, 1), counter.getValue());
    counter.increment();
    try testing.expectEqual(@as(i32, 2), counter.getValue());
}

test "Counter.decrement decreases value" {
    var counter = Counter.init();
    counter.decrement();
    try testing.expectEqual(@as(i32, -1), counter.getValue());
}

test "Counter.reset returns to zero" {
    var counter = Counter.init();
    counter.increment();
    counter.increment();
    counter.reset();
    try testing.expectEqual(@as(i32, 0), counter.getValue());
}
// ANCHOR_END: struct_testing

// ==============================================================================
// Testing with Setup and Teardown
// ==============================================================================

// ANCHOR: setup_teardown
const StringBuffer = struct {
    data: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) StringBuffer {
        return .{
            .data = std.ArrayList(u8){},
            .allocator = allocator,
        };
    }

    pub fn append(self: *StringBuffer, text: []const u8) !void {
        try self.data.appendSlice(self.allocator, text);
    }

    pub fn get(self: StringBuffer) []const u8 {
        return self.data.items;
    }

    pub fn deinit(self: *StringBuffer) void {
        self.data.deinit(self.allocator);
    }
};

test "StringBuffer operations" {
    const allocator = testing.allocator;

    // Setup
    var buffer = StringBuffer.init(allocator);
    defer buffer.deinit(); // Teardown

    // Test operations
    try buffer.append("Hello");
    try testing.expectEqualStrings("Hello", buffer.get());

    try buffer.append(" World");
    try testing.expectEqualStrings("Hello World", buffer.get());
}
// ANCHOR_END: setup_teardown

// ==============================================================================
// Testing with Temporary Data
// ==============================================================================

test "copying temporary data" {
    const allocator = testing.allocator;

    // Create test data
    const test_data = "Hello, Test!";

    // Use the test data
    const copy = try allocator.dupe(u8, test_data);
    defer allocator.free(copy);

    try testing.expectEqualStrings(test_data, copy);
    try testing.expectEqual(test_data.len, copy.len);
}

// ==============================================================================
// Helper Functions for Testing
// ==============================================================================

// ANCHOR: helper_functions
fn expectNear(expected: f64, actual: f64, tolerance: f64) !void {
    const diff = @abs(expected - actual);
    try testing.expect(diff < tolerance);
}

fn approxSqrt(x: f64) f64 {
    // Simple Newton's method approximation
    if (x == 0.0) return 0.0;

    var guess: f64 = x / 2.0;
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        guess = (guess + x / guess) / 2.0;
    }
    return guess;
}

test "sqrt approximation with helper" {
    try expectNear(2.0, approxSqrt(4.0), 0.001);
    try expectNear(3.0, approxSqrt(9.0), 0.001);
    try expectNear(10.0, approxSqrt(100.0), 0.001);
}
// ANCHOR_END: helper_functions

// ==============================================================================
// Testing Edge Cases
// ==============================================================================

// ANCHOR: edge_cases
fn findFirst(items: []const i32, target: i32) ?usize {
    for (items, 0..) |item, i| {
        if (item == target) return i;
    }
    return null;
}

test "findFirst edge cases" {
    // Empty slice
    const empty: []const i32 = &[_]i32{};
    try testing.expectEqual(@as(?usize, null), findFirst(empty, 5));

    // Single element - found
    const single = [_]i32{5};
    try testing.expectEqual(@as(?usize, 0), findFirst(&single, 5));

    // Single element - not found
    try testing.expectEqual(@as(?usize, null), findFirst(&single, 10));

    // Multiple elements - found at start
    const multi = [_]i32{ 1, 2, 3, 4, 5 };
    try testing.expectEqual(@as(?usize, 0), findFirst(&multi, 1));

    // Multiple elements - found at end
    try testing.expectEqual(@as(?usize, 4), findFirst(&multi, 5));

    // Multiple elements - found in middle
    try testing.expectEqual(@as(?usize, 2), findFirst(&multi, 3));

    // Multiple elements - not found
    try testing.expectEqual(@as(?usize, null), findFirst(&multi, 99));
}
// ANCHOR_END: edge_cases

// ==============================================================================
// Testing with ArrayList
// ==============================================================================

// ANCHOR: arraylist_testing
test "ArrayList append and pop" {
    const allocator = testing.allocator;

    var list = std.ArrayList(i32){};
    defer list.deinit(allocator);

    // Test append
    try list.append(allocator, 42);
    try testing.expectEqual(@as(usize, 1), list.items.len);
    try testing.expectEqual(@as(i32, 42), list.items[0]);

    // Test pop
    const item = list.pop();
    try testing.expectEqual(@as(i32, 42), item);
    try testing.expectEqual(@as(usize, 0), list.items.len);
}

test "ArrayList multiple operations" {
    const allocator = testing.allocator;

    var list = std.ArrayList([]const u8){};
    defer list.deinit(allocator);

    try list.append(allocator, "first");
    try list.append(allocator, "second");
    try list.append(allocator, "third");

    try testing.expectEqual(@as(usize, 3), list.items.len);
    try testing.expectEqualStrings("first", list.items[0]);
    try testing.expectEqualStrings("second", list.items[1]);
    try testing.expectEqualStrings("third", list.items[2]);
}
// ANCHOR_END: arraylist_testing

// ==============================================================================
// Testing Best Practices Examples
// ==============================================================================

// Test one thing per test
test "divide returns correct quotient" {
    const result = try divide(10, 2);
    try testing.expectEqual(@as(i32, 5), result);
}

test "divide returns error on division by zero" {
    try testing.expectError(error.DivisionByZero, divide(10, 0));
}

test "divide handles negative numbers" {
    try testing.expectEqual(@as(i32, -5), try divide(-10, 2));
    try testing.expectEqual(@as(i32, -5), try divide(10, -2));
    try testing.expectEqual(@as(i32, 5), try divide(-10, -2));
}
