# Recipe 14.5: Skipping or anticipating test failures

## Problem

You need to skip tests under certain conditions or document expected failures. You want to handle platform-specific tests, known bugs, incomplete features, and resource-dependent tests.

## Solution

Return `error.SkipZigTest` to skip a test conditionally:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_5.zig:conditional_skip}}
```

## Discussion

Zig doesn't have built-in test skip annotations, but returning `error.SkipZigTest` achieves the same result. This keeps tests in your codebase while preventing them from running under specific conditions.

### Expected Failures

Document known failures by testing that they fail as expected:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_5.zig:expected_failure}}
```

This pattern is better than skipping because it verifies the failure still occurs. If the bug gets fixed, the test will fail, prompting you to update it.

### Version-Dependent Tests

Skip tests that require specific Zig versions:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_5.zig:version_dependent}}
```

This is useful when testing new language features or maintaining compatibility across versions.

### Feature Flags

Use compile-time constants to enable/disable test groups:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_5.zig:feature_flag}}
```

Feature flags let you control which tests run without commenting them out.

### Environment-Based Skipping

Skip tests based on environment variables:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_5.zig:environment_based}}
```

This is useful for CI/CD environments where certain tests shouldn't run.

### Slow Tests

Mark slow tests so they can be skipped during development:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_5.zig:slow_test}}
```

Run slow tests with a flag: `const run_slow_tests = true;` before running tests.

### Resource Availability

Skip tests when required resources aren't available:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_5.zig:resource_check}}
```

This prevents test failures due to missing test data or external dependencies.

### Documenting Known Issues

Link tests to known issues while expecting the failure:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_5.zig:known_issue}}
```

This documents the bug in the test itself and ensures it's still present.

### Platform-Specific Tests

Write tests that behave differently on each platform:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_5.zig:platform_specific}}
```

This allows platform-specific behavior to be tested appropriately.

### Handling Flaky Tests

Retry flaky tests before failing:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_5.zig:flaky_test}}
```

While flaky tests should be fixed, retries can help in the interim for tests involving timing or external resources.

### Compile-Time Skip Lists

Skip tests by name at compile time:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_5.zig:comptime_skip}}
```

This provides a centralized place to disable problematic tests.

### Graceful Degradation

Skip tests that depend on external services:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_5.zig:graceful_degradation}}
```

Set `NO_NETWORK=1` to skip network tests in offline environments.

### Architecture-Specific Tests

Skip tests on unsupported architectures:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_5.zig:architecture_specific}}
```

This ensures tests only run on architectures they support.

### CPU Capability Checks

Skip tests that require specific CPU features:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_5.zig:capability_check}}
```

This prevents tests from failing on older CPUs.

### Test Categories

Organize tests into categories that can be run selectively:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_5.zig:test_categories}}
```

Run specific categories with environment variables:
```bash
TEST_CATEGORY=unit zig test
TEST_CATEGORY=integration zig test
TEST_CATEGORY=all zig test
```

### Best Practices

1. **Prefer expected failures over skips**: Use `expectError` for known bugs
2. **Document why tests skip**: Add comments explaining skip conditions
3. **Make skips temporary**: Track skipped tests and fix the underlying issues
4. **Use feature flags**: Group related skips under feature flags
5. **Test the skip logic**: Ensure skip conditions work as expected
6. **Avoid permanent skips**: Every skip should have a plan to remove it
7. **Link to issues**: Reference bug tracker issues in skip comments

### Skip Patterns

**Pattern 1: Conditional Compilation**
```zig
test "example" {
    if (comptime !featureEnabled()) {
        return error.SkipZigTest;
    }
    // ...
}
```

**Pattern 2: Environment Detection**
```zig
fn shouldSkip() bool {
    return std.process.getEnvVarOwned(allocator, "SKIP_TEST") catch null != null;
}
```

**Pattern 3: Resource Validation**
```zig
test "example" {
    validateResources() catch return error.SkipZigTest;
    // ...
}
```

### Common Gotchas

**Skipping too liberally**: Don't skip tests just because they're inconvenient. Fix the underlying issues instead.

**Not documenting skips**: Always explain why a test is skipped:

```zig
test "skip example" {
    // TODO(#123): Skip until database mock is implemented
    if (!hasDatabaseMock()) {
        return error.SkipZigTest;
    }
}
```

**Forgetting to remove skips**: Track skipped tests and revisit them regularly. Use grep to find all skips:

```bash
grep -r "SkipZigTest" src/
```

**Platform detection errors**: Test your skip conditions on all target platforms.

### CI/CD Integration

Organize tests for continuous integration:

```zig
const in_ci = std.process.getEnvVarOwned(allocator, "CI") catch null != null;

test "interactive test" {
    if (in_ci) {
        // Skip tests requiring human interaction in CI
        return error.SkipZigTest;
    }
}
```

This lets you run full test suites locally while keeping CI fast and focused.

## See Also

- Recipe 14.3: Testing for exceptional conditions in unit tests
- Recipe 14.4: Logging test output to a file
- Recipe 0.13: Testing and Debugging Fundamentals
- Recipe 1.3: Testing Strategy

Full compilable example: `code/04-specialized/14-testing-debugging/recipe_14_5.zig`
