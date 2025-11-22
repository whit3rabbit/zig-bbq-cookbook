# Testing Strategy

## Overview

Testing is built into Zig. No external frameworks, no complex setup. Just write `test` blocks alongside your code and run `zig test`. This guide establishes the testing practices used throughout the cookbook.

## Testing Philosophy

- **Every recipe includes a test block** using `std.testing`
- **Tests live alongside code** in the same file
- **All code must be compilable** with Zig v0.15.2
- **Tests ensure recipes don't break** on Zig version updates

## Basic Testing

### Writing Your First Test

```zig
{{#include ../../code/01-foundation/testing_examples.zig:basic_test}}
```

That's it! No imports of test frameworks, no decorators, no magic.

### Common Assertions

#### expectEqual
Use when you want exact equality:

```zig
{{#include ../../code/01-foundation/testing_examples.zig:common_assertions}}
```

Note: You often need `@as(Type, value)` to make types match exactly.

#### expect
Use for boolean conditions:

```zig
test "expect usage" {
    try testing.expect(add(2, 2) == 4);
    try testing.expect("hello".len > 0);
}
```

#### expectEqualStrings
Use for comparing strings:

```zig
test "expectEqualStrings usage" {
    const name = "Alice";
    try testing.expectEqualStrings("Alice", name);
}
```

#### expectError
Use to verify a function returns a specific error:

```zig
fn divide(a: i32, b: i32) !i32 {
    if (b == 0) return error.DivisionByZero;
    return @divTrunc(a, b);
}

test "expectError usage" {
    try testing.expectError(error.DivisionByZero, divide(10, 0));
}
```

#### expectEqualSlices
Use for comparing arrays and slices:

```zig
test "expectEqualSlices usage" {
    const expected = [_]i32{ 1, 2, 3 };
    const actual = [_]i32{ 1, 2, 3 };
    try testing.expectEqualSlices(i32, &expected, &actual);
}
```

## Testing with Allocators

### The Testing Allocator

`std.testing.allocator` is special: it detects memory leaks automatically.

```zig
{{#include ../../code/01-foundation/testing_examples.zig:testing_allocator}}
```

If you forget the `defer allocator.free(numbers)`, the test will fail with a memory leak error.

### Testing Functions That Allocate

```zig
fn createGreeting(allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "Hello, {s}!", .{name});
}

test "createGreeting allocates correctly" {
    const allocator = testing.allocator;

    const greeting = try createGreeting(allocator, "World");
    defer allocator.free(greeting);

    try testing.expectEqualStrings("Hello, World!", greeting);
}
// Test passes: no leaks detected
```

### Testing for Memory Leaks

The testing allocator will catch leaks automatically:

```zig
test "this test will fail - memory leak" {
    const allocator = testing.allocator;

    const data = try allocator.alloc(u8, 100);
    // Oops! Forgot to free
    _ = data;

    // Test fails: leak detected
}
```

## Test Organization

### Multiple Tests Per File

You can have as many tests as you need:

```zig
const std = @import("std");
const testing = std.testing;

fn isEven(n: i32) bool {
    return @mod(n, 2) == 0;
}

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
```

### Naming Tests

Use descriptive names that explain what you're testing:

```zig
// Good: Clear what's being tested
test "Stack.pop returns null when empty" { }
test "User.init validates email format" { }
test "Config.load uses defaults when file missing" { }

// Avoid: Too vague
test "test1" { }
test "it works" { }
test "check" { }
```

### Testing Private Functions

Tests have access to private (non-`pub`) functions in the same file:

```zig
// Private function - not exported
fn validateEmail(email: []const u8) bool {
    return std.mem.indexOf(u8, email, "@") != null;
}

test "validateEmail accepts valid emails" {
    try testing.expect(validateEmail("user@example.com"));
}

test "validateEmail rejects invalid emails" {
    try testing.expect(!validateEmail("notanemail"));
}
```

## Testing Patterns

### Setup and Teardown

Use the test function body for setup, and `defer` for teardown:

```zig
test "database operations" {
    const allocator = testing.allocator;

    // Setup
    var db = Database.init(allocator);
    defer db.deinit(); // Teardown

    // Test operations
    try db.insert("key", "value");
    const result = try db.get("key");
    try testing.expectEqualStrings("value", result);
}
```

### Testing Error Cases

Test both success and failure paths:

```zig
fn parseAge(text: []const u8) !u8 {
    const num = try std.fmt.parseInt(u8, text, 10);
    if (num > 150) return error.InvalidAge;
    return num;
}

test "parseAge success cases" {
    try testing.expectEqual(@as(u8, 25), try parseAge("25"));
    try testing.expectEqual(@as(u8, 0), try parseAge("0"));
}

test "parseAge error cases" {
    try testing.expectError(error.InvalidCharacter, parseAge("abc"));
    try testing.expectError(error.InvalidAge, parseAge("200"));
    try testing.expectError(error.InvalidCharacter, parseAge(""));
}
```

### Testing with Temporary Data

```zig
test "file operations" {
    const allocator = testing.allocator;

    // Create test data
    const test_data = "Hello, Test!";

    // Use the test data
    const copy = try allocator.dupe(u8, test_data);
    defer allocator.free(copy);

    try testing.expectEqualStrings(test_data, copy);
}
```

### Testing Struct Methods

```zig
const Counter = struct {
    value: i32,

    pub fn init() Counter {
        return .{ .value = 0 };
    }

    pub fn increment(self: *Counter) void {
        self.value += 1;
    }

    pub fn reset(self: *Counter) void {
        self.value = 0;
    }
};

test "Counter.init starts at zero" {
    const counter = Counter.init();
    try testing.expectEqual(@as(i32, 0), counter.value);
}

test "Counter.increment increases value" {
    var counter = Counter.init();
    counter.increment();
    try testing.expectEqual(@as(i32, 1), counter.value);
    counter.increment();
    try testing.expectEqual(@as(i32, 2), counter.value);
}

test "Counter.reset returns to zero" {
    var counter = Counter.init();
    counter.increment();
    counter.increment();
    counter.reset();
    try testing.expectEqual(@as(i32, 0), counter.value);
}
```

## Running Tests

### Run All Tests in a File

```bash
zig test my_code.zig
```

### Run All Tests in a Directory

```bash
# Run all .zig files
zig test code/**/*.zig
```

### Run Tests with More Information

```bash
# Show summary of test runs
zig test my_code.zig --summary all
```

### Run Tests in Different Modes

```bash
# Debug mode (default) - includes safety checks
zig test my_code.zig

# ReleaseSafe - optimized but keeps safety checks
zig test my_code.zig -O ReleaseSafe

# ReleaseFast - maximum speed, no safety checks
zig test my_code.zig -O ReleaseFast
```

## Testing Best Practices

### 1. Test One Thing Per Test

```zig
// Good: Each test focuses on one behavior
test "ArrayList.append adds item to end" {
    var list = std.ArrayList(i32).init(testing.allocator);
    defer list.deinit(testing.allocator);
    try list.append(testing.allocator, 42);
    try testing.expectEqual(@as(usize, 1), list.items.len);
    try testing.expectEqual(@as(i32, 42), list.items[0]);
}

test "ArrayList.pop removes last item" {
    var list = std.ArrayList(i32).init(testing.allocator);
    defer list.deinit(testing.allocator);
    try list.append(testing.allocator, 42);
    const item = list.pop();
    try testing.expectEqual(@as(i32, 42), item);
    try testing.expectEqual(@as(usize, 0), list.items.len);
}
```

### 2. Always Use the Testing Allocator

```zig
// Good: Will catch leaks
test "with testing allocator" {
    const allocator = testing.allocator;
    const data = try allocator.alloc(u8, 10);
    defer allocator.free(data);
    // ...
}

// Avoid: Won't detect leaks
test "with page allocator" {
    const allocator = std.heap.page_allocator;
    const data = try allocator.alloc(u8, 10);
    // Leaks go undetected!
}
```

### 3. Test Edge Cases

```zig
test "String.split handles edge cases" {
    // Empty string
    try testSplit("", ',', &[_][]const u8{});

    // Single delimiter
    try testSplit(",", ',', &[_][]const u8{ "", "" });

    // No delimiters
    try testSplit("hello", ',', &[_][]const u8{"hello"});

    // Multiple delimiters
    try testSplit("a,b,c", ',', &[_][]const u8{ "a", "b", "c" });
}
```

### 4. Use Helper Functions

```zig
fn expectNear(expected: f64, actual: f64, tolerance: f64) !void {
    const diff = @abs(expected - actual);
    try testing.expect(diff < tolerance);
}

test "sqrt approximation" {
    try expectNear(2.0, approxSqrt(4.0), 0.01);
    try expectNear(3.0, approxSqrt(9.0), 0.01);
}
```

## Quick Reference

### Common Assertions
- `try testing.expect(condition)` - Boolean condition
- `try testing.expectEqual(expected, actual)` - Exact equality
- `try testing.expectEqualStrings(expected, actual)` - String comparison
- `try testing.expectEqualSlices(T, expected, actual)` - Slice comparison
- `try testing.expectError(expected_error, result)` - Error checking

### Running Tests
- `zig test file.zig` - Run tests in a file
- `zig test file.zig --summary all` - Show detailed summary
- `zig test file.zig -O ReleaseSafe` - Run optimized with safety checks

### Memory Testing
- Always use `testing.allocator` in tests
- Use `defer allocator.free()` to prevent leaks
- Tests fail automatically on memory leaks

See the full compilable example at `code/01-foundation/testing_examples.zig`
