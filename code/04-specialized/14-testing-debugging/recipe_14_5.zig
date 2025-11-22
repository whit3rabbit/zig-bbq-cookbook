const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");

// ANCHOR: conditional_skip
test "skip on specific platform" {
    if (builtin.os.tag == .windows) {
        // Skip this test on Windows
        return error.SkipZigTest;
    }

    // Test runs on non-Windows platforms
    try testing.expectEqual(@as(i32, 42), 42);
}

test "skip based on build mode" {
    if (builtin.mode == .ReleaseFast) {
        // Skip in release mode
        return error.SkipZigTest;
    }

    // Only runs in debug mode
    try testing.expectEqual(@as(i32, 10), 10);
}
// ANCHOR_END: conditional_skip

// ANCHOR: expected_failure
const ExperimentalFeature = struct {
    fn compute(value: i32) !i32 {
        // Known to fail for negative values
        if (value < 0) return error.NotImplemented;
        return value * 2;
    }
};

test "expect known failure" {
    const result = ExperimentalFeature.compute(-5);

    // We expect this to fail with NotImplemented
    try testing.expectError(error.NotImplemented, result);
}

test "works for positive values" {
    const result = try ExperimentalFeature.compute(5);
    try testing.expectEqual(@as(i32, 10), result);
}
// ANCHOR_END: expected_failure

// ANCHOR: version_dependent
const MIN_ZIG_VERSION = std.SemanticVersion{ .major = 0, .minor = 13, .patch = 0 };

fn requiresMinVersion() !void {
    if (builtin.zig_version.order(MIN_ZIG_VERSION) == .lt) {
        return error.SkipZigTest;
    }
}

test "skip if zig version too old" {
    try requiresMinVersion();

    // This test only runs on Zig 0.13.0 or newer
    try testing.expectEqual(@as(i32, 1), 1);
}
// ANCHOR_END: version_dependent

// ANCHOR: feature_flag
const enable_experimental_tests = false;

test "experimental feature test" {
    if (!enable_experimental_tests) {
        return error.SkipZigTest;
    }

    // Experimental test code
    try testing.expectEqual(@as(i32, 100), 100);
}
// ANCHOR_END: feature_flag

// ANCHOR: environment_based
fn isCI() bool {
    const allocator = testing.allocator;
    const ci = std.process.getEnvVarOwned(allocator, "CI") catch return false;
    defer allocator.free(ci);
    return std.mem.eql(u8, ci, "true");
}

test "skip in CI environment" {
    if (isCI()) {
        return error.SkipZigTest;
    }

    // Only runs locally
    try testing.expectEqual(@as(i32, 5), 5);
}
// ANCHOR_END: environment_based

// ANCHOR: slow_test
const run_slow_tests = false;

test "slow performance test" {
    if (!run_slow_tests) {
        return error.SkipZigTest;
    }

    // Slow test that's normally skipped
    var sum: u64 = 0;
    var i: u64 = 0;
    while (i < 10_000_000) : (i += 1) {
        sum +%= i;
    }
    try testing.expect(sum > 0);
}
// ANCHOR_END: slow_test

// ANCHOR: resource_check
fn hasRequiredResource() bool {
    // Check if required file exists
    std.fs.cwd().access("test-resource.txt", .{}) catch return false;
    return true;
}

test "skip if resource missing" {
    if (!hasRequiredResource()) {
        return error.SkipZigTest;
    }

    // Test requires test-resource.txt
    try testing.expectEqual(@as(i32, 1), 1);
}
// ANCHOR_END: resource_check

// ANCHOR: known_issue
test "known failing test - issue #123" {
    // Document known issues
    const result = brokenFunction();

    // Expect the known failure
    try testing.expectError(error.KnownBug, result);
}

fn brokenFunction() !void {
    // This function has a known bug tracked in issue #123
    return error.KnownBug;
}
// ANCHOR_END: known_issue

// ANCHOR: platform_specific
test "platform-specific behavior" {
    switch (builtin.os.tag) {
        .linux => {
            // Linux-specific test
            try testing.expectEqual(@as(i32, 1), 1);
        },
        .macos => {
            // macOS-specific test
            try testing.expectEqual(@as(i32, 2), 2);
        },
        .windows => {
            // Windows-specific test
            try testing.expectEqual(@as(i32, 3), 3);
        },
        else => {
            // Skip on other platforms
            return error.SkipZigTest;
        },
    }
}
// ANCHOR_END: platform_specific

// ANCHOR: flaky_test
const max_retries = 3;

fn flakyOperation(attempt: usize) !i32 {
    // Simulates a flaky operation that sometimes fails
    if (attempt < 2) {
        return error.TransientFailure;
    }
    return 42;
}

test "retry flaky operation" {
    var attempt: usize = 0;
    const result = while (attempt < max_retries) : (attempt += 1) {
        if (flakyOperation(attempt)) |value| {
            break value;
        } else |err| {
            if (attempt == max_retries - 1) {
                return err;
            }
            continue;
        }
    } else unreachable;

    try testing.expectEqual(@as(i32, 42), result);
}
// ANCHOR_END: flaky_test

// ANCHOR: comptime_skip
fn shouldRunTest(comptime test_name: []const u8) bool {
    // Skip specific tests at compile time
    const skip_list = &[_][]const u8{
        "broken_test",
        "disabled_test",
    };

    inline for (skip_list) |skip_name| {
        if (std.mem.eql(u8, test_name, skip_name)) {
            return false;
        }
    }
    return true;
}

test "conditionally run based on name" {
    if (!shouldRunTest("this_test")) {
        return error.SkipZigTest;
    }

    try testing.expectEqual(@as(i32, 1), 1);
}
// ANCHOR_END: comptime_skip

// ANCHOR: graceful_degradation
const NetworkTest = struct {
    fn requiresNetwork() !void {
        // Try to detect network availability
        const allocator = testing.allocator;
        const no_network = std.process.getEnvVarOwned(allocator, "NO_NETWORK") catch null;
        if (no_network) |val| {
            defer allocator.free(val);
            if (std.mem.eql(u8, val, "1")) {
                return error.SkipZigTest;
            }
        }
    }
};

test "network-dependent test" {
    try NetworkTest.requiresNetwork();

    // Network test code here
    try testing.expectEqual(@as(i32, 1), 1);
}
// ANCHOR_END: graceful_degradation

// ANCHOR: architecture_specific
test "skip on 32-bit architectures" {
    if (@sizeOf(usize) < 8) {
        // Skip on 32-bit systems
        return error.SkipZigTest;
    }

    // Test requires 64-bit architecture
    const large_number: u64 = 0xFFFFFFFFFFFFFFFF;
    try testing.expect(large_number > 0);
}
// ANCHOR_END: architecture_specific

// ANCHOR: capability_check
fn hasSSE2() bool {
    // Check for CPU features
    return std.Target.x86.featureSetHas(builtin.cpu.features, .sse2);
}

test "skip without SSE2" {
    if (builtin.cpu.arch != .x86_64) {
        return error.SkipZigTest;
    }

    if (!hasSSE2()) {
        return error.SkipZigTest;
    }

    // SSE2-specific test
    try testing.expectEqual(@as(i32, 1), 1);
}
// ANCHOR_END: capability_check

// ANCHOR: test_categories
const TestCategory = enum {
    unit,
    integration,
    performance,
    flaky,
};

fn shouldRunCategory(category: TestCategory) bool {
    const allocator = testing.allocator;
    const test_category = std.process.getEnvVarOwned(allocator, "TEST_CATEGORY") catch return true;
    defer allocator.free(test_category);

    return switch (category) {
        .unit => std.mem.eql(u8, test_category, "unit") or std.mem.eql(u8, test_category, "all"),
        .integration => std.mem.eql(u8, test_category, "integration") or std.mem.eql(u8, test_category, "all"),
        .performance => std.mem.eql(u8, test_category, "performance") or std.mem.eql(u8, test_category, "all"),
        .flaky => std.mem.eql(u8, test_category, "flaky"),
    };
}

test "unit test category" {
    if (!shouldRunCategory(.unit)) {
        return error.SkipZigTest;
    }

    try testing.expectEqual(@as(i32, 1), 1);
}

test "integration test category" {
    if (!shouldRunCategory(.integration)) {
        return error.SkipZigTest;
    }

    try testing.expectEqual(@as(i32, 2), 2);
}
// ANCHOR_END: test_categories
