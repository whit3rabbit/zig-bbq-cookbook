const std = @import("std");
const testing = std.testing;

// This file demonstrates testing in the build system

// ANCHOR: test_configuration
// Test configuration
pub const TestConfig = struct {
    name: []const u8,
    source_file: []const u8,
    filters: []const []const u8,

    pub fn init(name: []const u8, source: []const u8) TestConfig {
        return .{
            .name = name,
            .source_file = source,
            .filters = &[_][]const u8{},
        };
    }

    pub fn withFilters(self: TestConfig, filters: []const []const u8) TestConfig {
        var result = self;
        result.filters = filters;
        return result;
    }

    pub fn hasFilters(self: TestConfig) bool {
        return self.filters.len > 0;
    }
};

test "test configuration" {
    const config = TestConfig.init("unit-tests", "src/lib.zig");
    try testing.expect(!config.hasFilters());
    try testing.expect(std.mem.eql(u8, config.name, "unit-tests"));

    const filters = [_][]const u8{"integration"};
    const filtered = config.withFilters(&filters);
    try testing.expect(filtered.hasFilters());
}
// ANCHOR_END: test_configuration

// ANCHOR: test_suite
// Test suite organization
pub const TestSuite = struct {
    name: []const u8,
    tests: []const TestConfig,

    pub fn init(name: []const u8, tests: []const TestConfig) TestSuite {
        return .{
            .name = name,
            .tests = tests,
        };
    }

    pub fn testCount(self: TestSuite) usize {
        return self.tests.len;
    }

    pub fn hasTest(self: TestSuite, test_name: []const u8) bool {
        for (self.tests) |t| {
            if (std.mem.eql(u8, t.name, test_name)) return true;
        }
        return false;
    }
};

test "test suite" {
    const tests = [_]TestConfig{
        TestConfig.init("unit", "test/unit.zig"),
        TestConfig.init("integration", "test/integration.zig"),
    };
    const suite = TestSuite.init("all-tests", &tests);

    try testing.expectEqual(@as(usize, 2), suite.testCount());
    try testing.expect(suite.hasTest("unit"));
    try testing.expect(!suite.hasTest("e2e"));
}
// ANCHOR_END: test_suite

// ANCHOR: test_filter
// Test filtering
pub const TestFilter = struct {
    include_patterns: []const []const u8,
    exclude_patterns: []const []const u8,

    pub fn init() TestFilter {
        return .{
            .include_patterns = &[_][]const u8{},
            .exclude_patterns = &[_][]const u8{},
        };
    }

    pub fn withIncludes(self: TestFilter, patterns: []const []const u8) TestFilter {
        var result = self;
        result.include_patterns = patterns;
        return result;
    }

    pub fn withExcludes(self: TestFilter, patterns: []const []const u8) TestFilter {
        var result = self;
        result.exclude_patterns = patterns;
        return result;
    }

    pub fn matches(self: TestFilter, test_name: []const u8) bool {
        // If includes specified, must match at least one
        if (self.include_patterns.len > 0) {
            var matched = false;
            for (self.include_patterns) |pattern| {
                if (std.mem.indexOf(u8, test_name, pattern) != null) {
                    matched = true;
                    break;
                }
            }
            if (!matched) return false;
        }

        // Must not match any exclude patterns
        for (self.exclude_patterns) |pattern| {
            if (std.mem.indexOf(u8, test_name, pattern) != null) {
                return false;
            }
        }

        return true;
    }
};

test "test filter" {
    const includes = [_][]const u8{"unit"};
    const excludes = [_][]const u8{"slow"};
    const filter = TestFilter.init().withIncludes(&includes).withExcludes(&excludes);

    try testing.expect(filter.matches("unit_test"));
    try testing.expect(!filter.matches("integration_test"));
    try testing.expect(!filter.matches("unit_slow_test"));
}
// ANCHOR_END: test_filter

// ANCHOR: coverage_config
// Test coverage configuration
pub const CoverageConfig = struct {
    enabled: bool,
    output_dir: []const u8,
    format: []const u8,

    pub fn init(enabled: bool, output: []const u8) CoverageConfig {
        return .{
            .enabled = enabled,
            .output_dir = output,
            .format = "lcov",
        };
    }

    pub fn withFormat(self: CoverageConfig, format: []const u8) CoverageConfig {
        var result = self;
        result.format = format;
        return result;
    }

    pub fn isLcov(self: CoverageConfig) bool {
        return std.mem.eql(u8, self.format, "lcov");
    }
};

test "coverage config" {
    const coverage = CoverageConfig.init(true, "coverage");
    try testing.expect(coverage.enabled);
    try testing.expect(coverage.isLcov());

    const html = coverage.withFormat("html");
    try testing.expect(!html.isLcov());
}
// ANCHOR_END: coverage_config

// ANCHOR: benchmark_config
// Benchmark configuration
pub const BenchmarkConfig = struct {
    name: []const u8,
    iterations: u32,
    warmup_iterations: u32,

    pub fn init(name: []const u8, iterations: u32) BenchmarkConfig {
        return .{
            .name = name,
            .iterations = iterations,
            .warmup_iterations = iterations / 10,
        };
    }

    pub fn withWarmup(self: BenchmarkConfig, warmup: u32) BenchmarkConfig {
        var result = self;
        result.warmup_iterations = warmup;
        return result;
    }

    pub fn totalIterations(self: BenchmarkConfig) u32 {
        return self.iterations + self.warmup_iterations;
    }
};

test "benchmark config" {
    const bench = BenchmarkConfig.init("sort_benchmark", 1000);
    try testing.expectEqual(@as(u32, 100), bench.warmup_iterations);
    try testing.expectEqual(@as(u32, 1100), bench.totalIterations());

    const custom = bench.withWarmup(50);
    try testing.expectEqual(@as(u32, 1050), custom.totalIterations());
}
// ANCHOR_END: benchmark_config

// ANCHOR: test_runner_options
// Test runner options
pub const TestRunnerOptions = struct {
    verbose: bool,
    fail_fast: bool,
    parallel: bool,
    timeout_seconds: ?u32,

    pub fn init() TestRunnerOptions {
        return .{
            .verbose = false,
            .fail_fast = false,
            .parallel = true,
            .timeout_seconds = null,
        };
    }

    pub fn withVerbose(self: TestRunnerOptions) TestRunnerOptions {
        var result = self;
        result.verbose = true;
        return result;
    }

    pub fn withFailFast(self: TestRunnerOptions) TestRunnerOptions {
        var result = self;
        result.fail_fast = true;
        return result;
    }

    pub fn withTimeout(self: TestRunnerOptions, timeout: u32) TestRunnerOptions {
        var result = self;
        result.timeout_seconds = timeout;
        return result;
    }

    pub fn hasTimeout(self: TestRunnerOptions) bool {
        return self.timeout_seconds != null;
    }
};

test "test runner options" {
    const opts = TestRunnerOptions.init();
    try testing.expect(!opts.verbose);
    try testing.expect(opts.parallel);
    try testing.expect(!opts.hasTimeout());

    const verbose = opts.withVerbose().withFailFast().withTimeout(300);
    try testing.expect(verbose.verbose);
    try testing.expect(verbose.fail_fast);
    try testing.expect(verbose.hasTimeout());
}
// ANCHOR_END: test_runner_options

// ANCHOR: integration_test_config
// Integration test configuration
pub const IntegrationTestConfig = struct {
    name: []const u8,
    setup_required: bool,
    cleanup_required: bool,
    dependencies: []const []const u8,

    pub fn init(name: []const u8) IntegrationTestConfig {
        return .{
            .name = name,
            .setup_required = false,
            .cleanup_required = false,
            .dependencies = &[_][]const u8{},
        };
    }

    pub fn requiresSetup(self: IntegrationTestConfig) IntegrationTestConfig {
        var result = self;
        result.setup_required = true;
        return result;
    }

    pub fn requiresCleanup(self: IntegrationTestConfig) IntegrationTestConfig {
        var result = self;
        result.cleanup_required = true;
        return result;
    }

    pub fn withDependencies(self: IntegrationTestConfig, deps: []const []const u8) IntegrationTestConfig {
        var result = self;
        result.dependencies = deps;
        return result;
    }

    pub fn hasDependencies(self: IntegrationTestConfig) bool {
        return self.dependencies.len > 0;
    }
};

test "integration test config" {
    const config = IntegrationTestConfig.init("api-test");
    try testing.expect(!config.setup_required);
    try testing.expect(!config.hasDependencies());

    const deps = [_][]const u8{ "database", "redis" };
    const full = config.requiresSetup().requiresCleanup().withDependencies(&deps);
    try testing.expect(full.setup_required);
    try testing.expect(full.cleanup_required);
    try testing.expect(full.hasDependencies());
}
// ANCHOR_END: integration_test_config
