# Testing and Debugging Fundamentals

## Problem

You need to verify your code works correctly and debug issues when they arise. How do you write tests in Zig? What testing functions are available? How do you print debug output? How do you investigate bugs?

## Solution

Zig has testing built into the language:

1. **test blocks** - First-class test support with the `test` keyword
2. **std.testing** - Rich assertion library for verification
3. **std.debug** - Debugging utilities and formatted printing
4. **std.log** - Structured logging for production code

Run tests with `zig test filename.zig`. All tests run automatically, with automatic memory leak detection.

## Discussion

### Part 1: Basic Testing with std.testing

```zig
{{#include ../../code/00-bootcamp/recipe_0_13.zig:basic_testing}}
```

Never use exact equality for floats - use epsilon comparisons or `expectApproxEqAbs`.

### Part 2: Advanced Testing Patterns

```zig
{{#include ../../code/00-bootcamp/recipe_0_13.zig:advanced_testing}}
```

Test edge cases and multiple inputs to ensure correctness.

### Part 3: Debugging Techniques

```zig
{{#include ../../code/00-bootcamp/recipe_0_13.zig:debugging}}
```

### Test Organization

**Tests Near Code:**

```zig
test "test organization" {
    const MyStruct = struct {
        value: i32,

        fn init(val: i32) @This() {
            return .{ .value = val };
        }

        fn double(self: @This()) i32 {
            return self.value * 2;
        }

        // Tests can be inside structs too
        test "MyStruct.double" {
            const s = init(21);
            try testing.expectEqual(@as(i32, 42), s.double());
        }
    };

    const s = MyStruct.init(10);
    try testing.expectEqual(@as(i32, 20), s.double());
}
```

Tests can be:
- At file level
- Inside structs (near the code they test)
- In separate test files

### Common std.testing Functions

- `expect(condition)` - Assert boolean condition
- `expectEqual(expected, actual)` - Assert values are equal
- `expectError(error, result)` - Assert specific error returned
- `expectEqualSlices(T, expected, actual)` - Assert slices are equal
- `expectApproxEqAbs(expected, actual, epsilon)` - Float comparison
- `expectEqualStrings(expected, actual)` - String comparison

### Running Tests

```bash
# Run all tests in a file
zig test file.zig

# Run tests with specific build mode
zig test -O ReleaseSafe file.zig

# Run tests for entire project
zig build test
```

### Best Practices

**Write tests as you code:**
```zig
fn processData(data: []const u8) !void {
    // Implementation
}

test "processData with empty input" {
    try processData("");
}

test "processData with valid input" {
    try processData("test");
}
```

**Use testing.allocator:**
```zig
test "always use testing allocator" {
    var list = std.ArrayList(i32){};
    defer list.deinit(testing.allocator); // Automatic leak detection
    // ...
}
```

**Test edge cases:**
```zig
test "edge cases matter" {
    try testing.expectEqual(0, fibonacci(0)); // Zero
    try testing.expectEqual(1, fibonacci(1)); // One
    try testing.expectEqual(55, fibonacci(10)); // Larger value
}
```

### Common Mistakes

**Comparing strings with ==:**
```zig
const str1 = "hello";
const str2 = "hello";
try testing.expect(str1 == str2);  // Wrong - compares pointers!
try testing.expect(std.mem.eql(u8, str1, str2));  // Correct
```

**Forgetting defer with allocator:**
```zig
var list = std.ArrayList(i32){};
try list.append(testing.allocator, 1);
// Missing: defer list.deinit(testing.allocator);
// Test will fail with memory leak!
```

**Using exact equality for floats:**
```zig
const f: f32 = 0.1 + 0.2;
try testing.expectEqual(0.3, f);  // May fail due to precision!
try testing.expectApproxEqAbs(0.3, f, 0.0001);  // Correct
```

## See Also

- Recipe 0.12: Understanding Allocators - testing.allocator and leak detection
- Recipe 0.11: Optionals, Errors, and Resource Cleanup - Testing error conditions
- Recipe 0.14: Projects, Modules, and Dependencies - Running tests with zig build

Full compilable example: `code/00-bootcamp/recipe_0_13.zig`
