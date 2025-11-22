# Recipe 16.7: Testing in the Build System

## Problem

You need to organize and run different types of tests (unit, integration, benchmarks) as part of your build process, with the ability to run subsets of tests and configure test behavior.

## Solution

Use Zig's build system to create multiple test targets with different configurations:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_7/build.zig:testing_setup}}
```

## Discussion

Zig's build system integrates testing directly, making it easy to organize and run tests at different levels of granularity.

### Test Configuration

Configure tests programmatically:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_7.zig:test_configuration}}
```

Test configuration lets you:
- Name test suites
- Specify source files
- Apply filters to run specific tests
- Set test-specific build options

### Test Suites

Organize tests into logical suites:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_7.zig:test_suite}}
```

Test suites help organize:
- Unit tests (fast, isolated function tests)
- Integration tests (component interaction tests)
- End-to-end tests (full system tests)
- Performance tests (benchmarks)

### Test Filtering

Run specific tests using filters:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_7.zig:test_filter}}
```

Filters are powerful for:
- Running fast tests during development
- Skipping slow integration tests
- Running only specific test categories
- CI/CD selective test execution

### Coverage Configuration

Track test coverage:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_7.zig:coverage_config}}
```

Coverage helps identify:
- Untested code paths
- Dead code
- Missing edge case tests
- Areas needing more testing

### Benchmark Configuration

Configure performance benchmarks:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_7.zig:benchmark_config}}
```

Benchmarks measure:
- Function execution time
- Algorithm efficiency
- Memory allocation patterns
- Throughput and latency

### Test Runner Options

Customize test execution:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_7.zig:test_runner_options}}
```

Runner options control:
- Verbose output for debugging
- Fail-fast behavior (stop on first failure)
- Parallel test execution
- Test timeouts

### Integration Test Configuration

Set up integration tests properly:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_7.zig:integration_test_config}}
```

Integration tests often need:
- Database setup/teardown
- External service mocking
- Test data fixtures
- Environment configuration

## Running Tests

Run tests from the command line:

```bash
# Run all tests
zig build test

# Run specific test suite
zig build test-unit
zig build test-integration

# Run filtered tests
zig build test-fast

# Run benchmarks
zig build bench

# Check if code compiles without running tests
zig build check

# Run tests with verbose output
zig build test --summary all

# Run a specific test by name filter
zig build test -- --test-filter "fast"
```

## Test Organization

Organize tests by type:

```
project/
├── build.zig
├── src/
│   ├── lib.zig           # Source code with inline unit tests
│   └── main.zig
└── test/
    ├── integration.zig   # Integration tests
    ├── benchmark.zig     # Performance tests
    └── e2e.zig          # End-to-end tests
```

**Inline Unit Tests**: Put unit tests directly in source files using `test` blocks. These test individual functions in isolation.

**Separate Integration Tests**: Put integration tests in dedicated test files. These test how components work together.

**Benchmark Tests**: Create separate benchmark files with performance-critical tests.

## Writing Tests

**Unit Tests**:
```zig
const std = @import("std");
const testing = std.testing;

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "add positive numbers" {
    try testing.expectEqual(@as(i32, 5), add(2, 3));
}

test "add negative numbers" {
    try testing.expectEqual(@as(i32, -5), add(-2, -3));
}

test "fast: add zero" {
    try testing.expectEqual(@as(i32, 5), add(5, 0));
}
```

**Integration Tests**:
```zig
const std = @import("std");
const testing = std.testing;

test "integration: full workflow" {
    // Setup
    var allocator = testing.allocator;
    const db = try Database.init(allocator);
    defer db.deinit();

    // Execute
    try db.insert("key", "value");
    const result = try db.get("key");

    // Verify
    try testing.expectEqualStrings("value", result);
}
```

**Benchmark Tests**:
```zig
const std = @import("std");
const testing = std.testing;

test "benchmark: sorting performance" {
    var data = [_]i32{5, 2, 8, 1, 9};

    const start = std.time.nanoTimestamp();
    std.sort.heap(i32, &data, {}, comptime std.sort.asc(i32));
    const end = std.time.nanoTimestamp();

    const duration = end - start;
    std.debug.print("Sort took {d}ns\n", .{duration});

    try testing.expect(duration < 1_000_000); // Less than 1ms
}
```

## Test Assertions

Zig provides comprehensive assertion functions:

```zig
const testing = std.testing;

test "assertions" {
    // Equality
    try testing.expectEqual(@as(i32, 42), 42);
    try testing.expectEqualStrings("hello", "hello");
    try testing.expectEqualSlices(u8, &[_]u8{1, 2, 3}, &[_]u8{1, 2, 3});

    // Errors
    try testing.expectError(error.OutOfMemory, failingFunction());

    // Booleans
    try testing.expect(true);

    // Approximate equality (floats)
    try testing.expectApproxEqAbs(3.14, 3.14159, 0.01);
}
```

## Best Practices

**Write Tests First**: Use test-driven development. Write tests before implementing features.

**Test Edge Cases**: Don't just test the happy path. Test boundary conditions, error cases, and invalid inputs.

**Keep Tests Fast**: Unit tests should run in milliseconds. Move slow tests to integration suites.

**Use Descriptive Names**: Name tests clearly: `test "add returns sum of two positive integers"` not `test "test1"`.

**One Assert Per Test**: Each test should verify one specific behavior. Multiple tests are better than complex tests.

**Use Test Filters**: Tag tests for easy filtering: `test "fast: quick operation"`, `test "slow: database operation"`.

**Isolate Tests**: Each test should be independent. Don't rely on test execution order.

**Clean Up Resources**: Use `defer` to clean up allocations and resources.

## Continuous Integration

Example CI configuration:

```bash
# Run all tests
zig build test

# Run fast tests only for quick feedback
zig build test-fast

# Run full suite including slow tests
zig build test-unit
zig build test-integration

# Check code compiles for all targets
zig build check -Dtarget=x86_64-linux
zig build check -Dtarget=x86_64-windows
zig build check -Dtarget=aarch64-macos
```

## Debugging Test Failures

**Verbose Output**:
```bash
zig build test --summary all
```

**Run Specific Test**:
```bash
zig build test -- --test-filter "failing_test"
```

**Debug Mode**:
```bash
zig build test -Doptimize=Debug
```

**GDB/LLDB**:
```bash
# Build tests
zig build test -Doptimize=Debug

# Run with debugger
lldb ./zig-cache/o/*/test
```

## See Also

- Recipe 16.1: Basic build.zig setup
- Recipe 16.4: Custom build steps
- Recipe 16.6: Build options and configurations
- Recipe 14.1: Testing program output
- Recipe 14.3: Testing exceptional conditions

Full compilable example: `code/05-zig-paradigms/16-zig-build-system/recipe_16_7.zig`
