// Recipe 10.6: Reloading Modules
// Target Zig Version: 0.15.2
//
// This recipe demonstrates module import caching, state management,
// and patterns for dynamic code updates in Zig.
//
// NOTE: Unlike Python's importlib.reload(), Zig modules are compiled statically.
// This recipe shows Zig-appropriate patterns for similar concepts:
// - Import caching behavior
// - State reset patterns
// - Build system integration for code updates
// - Dynamic library loading (runtime updates)
//
// Package structure:
// recipe_10_6.zig (root test file)
// └── recipe_10_6/
//     ├── counter.zig (stateful module)
//     └── config.zig (configuration module)

const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");

// ANCHOR: import_caching
// Zig caches @import() results at compile time
const counter1 = @import("recipe_10_6/counter.zig");
const counter2 = @import("recipe_10_6/counter.zig");
// counter1 and counter2 refer to the SAME module instance
// ANCHOR_END: import_caching

const config = @import("recipe_10_6/config.zig");

// ANCHOR: imports_are_cached
test "imports are cached at compile time" {
    // Multiple imports of the same module return the same instance
    const c1 = @import("recipe_10_6/counter.zig");
    const c2 = @import("recipe_10_6/counter.zig");

    // They share the same state
    c1.reset();
    c1.increment();
    c1.increment();

    // c2 sees the same state because it's the same module
    try testing.expectEqual(@as(usize, 2), c2.getValue());
}
// ANCHOR_END: imports_are_cached

// ANCHOR: shared_module_state
test "module state is shared across imports" {
    counter1.reset();

    counter1.increment();
    try testing.expectEqual(@as(usize, 1), counter1.getValue());

    // counter2 is the same module, so sees the same state
    try testing.expectEqual(@as(usize, 1), counter2.getValue());

    counter2.increment();
    try testing.expectEqual(@as(usize, 2), counter1.getValue());
}
// ANCHOR_END: shared_module_state

// ANCHOR: reset_pattern
test "resetting module state" {
    // Modules with state should provide reset functions
    counter1.reset();
    try testing.expectEqual(@as(usize, 0), counter1.getValue());

    counter1.increment();
    counter1.increment();
    counter1.increment();
    try testing.expectEqual(@as(usize, 3), counter1.getValue());

    // Reset to initial state
    counter1.reset();
    try testing.expectEqual(@as(usize, 0), counter1.getValue());
}
// ANCHOR_END: reset_pattern

// ANCHOR: initialization_pattern
test "module initialization pattern" {
    // For modules that need setup/teardown, use explicit init/deinit
    defer config.reset(); // Clean up for next test
    config.reset(); // Reset to defaults

    config.setValue("debug_mode", true);
    try testing.expect(config.getValue("debug_mode"));

    config.setIntValue("log_level", 3);
    try testing.expectEqual(@as(i32, 3), config.getIntValue("log_level"));

    // Config will be reset by defer
    try testing.expect(config.getValue("debug_mode"));
}
// ANCHOR_END: initialization_pattern

// ANCHOR: compile_time_constants
test "compile-time constants are truly constant" {
    const version = @import("recipe_10_6/config.zig").VERSION;
    const name = @import("recipe_10_6/config.zig").APP_NAME;

    // These are compile-time constants and cannot be "reloaded"
    try testing.expectEqualStrings("1.0.0", version);
    try testing.expectEqualStrings("MyApp", name);

    // To change these, you must recompile
}
// ANCHOR_END: compile_time_constants

// ANCHOR: module_singleton_pattern
test "module singleton pattern" {
    // Each module is effectively a singleton at compile time
    const mod1 = @import("recipe_10_6/counter.zig");
    const mod2 = @import("recipe_10_6/counter.zig");

    mod1.reset();
    mod1.increment();

    // Same instance
    try testing.expectEqual(mod1.getValue(), mod2.getValue());

    // You cannot have multiple independent instances
    // (unless the module provides its own instance management)
}
// ANCHOR_END: module_singleton_pattern

// ANCHOR: instance_pattern
// To get "reloadable" behavior, use instance structs instead of module globals
const CounterInstance = struct {
    value: usize,

    pub fn init() CounterInstance {
        return .{ .value = 0 };
    }

    pub fn increment(self: *CounterInstance) void {
        self.value += 1;
    }

    pub fn getValue(self: *const CounterInstance) usize {
        return self.value;
    }

    pub fn reset(self: *CounterInstance) void {
        self.value = 0;
    }
};

test "instance pattern for independent state" {
    // Create independent instances instead of using module globals
    var counter_a = CounterInstance.init();
    var counter_b = CounterInstance.init();

    counter_a.increment();
    counter_a.increment();
    try testing.expectEqual(@as(usize, 2), counter_a.getValue());

    counter_b.increment();
    try testing.expectEqual(@as(usize, 1), counter_b.getValue());

    // Independent state
    try testing.expectEqual(@as(usize, 2), counter_a.getValue());
}
// ANCHOR_END: instance_pattern

// ANCHOR: avoiding_global_state
test "avoiding global state for testability" {
    // Global module state makes testing difficult
    // Because imports are cached, tests can interfere with each other

    counter1.reset(); // Must reset before each test

    counter1.increment();
    try testing.expectEqual(@as(usize, 1), counter1.getValue());

    // If we forget to reset, the next test might fail
}
// ANCHOR_END: avoiding_global_state

// ANCHOR: scoped_reset
test "scoped state management" {
    // Better pattern: Use defer for cleanup
    counter1.reset(); // Reset at start for clean state
    defer counter1.reset(); // Always reset after test

    counter1.increment();
    counter1.increment();
    counter1.increment();

    try testing.expectEqual(@as(usize, 3), counter1.getValue());

    // reset() will be called on test exit
}
// ANCHOR_END: scoped_reset

// ANCHOR: configuration_reload
test "configuration changes" {
    defer config.reset();

    // Simulate "reloading" configuration by resetting and setting new values
    config.reset();
    config.setValue("feature_x", true);
    config.setIntValue("timeout", 30);

    try testing.expect(config.getValue("feature_x"));
    try testing.expectEqual(@as(i32, 30), config.getIntValue("timeout"));

    // "Reload" with different values
    config.reset();
    config.setValue("feature_x", false);
    config.setIntValue("timeout", 60);

    try testing.expect(!config.getValue("feature_x"));
    try testing.expectEqual(@as(i32, 60), config.getIntValue("timeout"));
}
// ANCHOR_END: configuration_reload

// ANCHOR: build_system_pattern
test "understanding compile-time vs runtime" {
    // At compile time:
    // - @import() resolves modules
    // - Module structure is fixed
    // - Const values are embedded
    //
    // At runtime:
    // - Module state can change
    // - Functions can be called
    // - Variables can be modified
    //
    // To "reload" code, you must recompile

    const module_version = config.VERSION;
    try testing.expectEqualStrings("1.0.0", module_version);

    // Runtime state can change
    config.setIntValue("runtime_value", 42);
    try testing.expectEqual(@as(i32, 42), config.getIntValue("runtime_value"));
}
// ANCHOR_END: build_system_pattern

// ANCHOR: best_practices
test "best practices for module state" {
    // 1. Prefer stateless modules when possible
    // 2. If state is needed, provide reset() function
    // 3. Use explicit init/deinit for resources
    // 4. Consider instance pattern instead of globals
    // 5. Use defer for cleanup in tests

    defer counter1.reset();

    counter1.increment();
    try testing.expect(counter1.getValue() > 0);
}
// ANCHOR_END: best_practices

// Comprehensive test
test "comprehensive module caching and state management" {
    // Reset all module state
    counter1.reset();
    config.reset();

    // Demonstrate import caching
    const c1 = @import("recipe_10_6/counter.zig");
    const c2 = @import("recipe_10_6/counter.zig");

    c1.increment();
    c1.increment();

    // Same module instance
    try testing.expectEqual(@as(usize, 2), c2.getValue());

    // Configuration changes
    config.setValue("test_mode", true);
    config.setIntValue("value", 123);

    try testing.expect(config.getValue("test_mode"));
    try testing.expectEqual(@as(i32, 123), config.getIntValue("value"));

    // Instance pattern for independence
    var instance1 = CounterInstance.init();
    var instance2 = CounterInstance.init();

    instance1.increment();
    instance1.increment();
    instance1.increment();

    try testing.expectEqual(@as(usize, 3), instance1.getValue());
    try testing.expectEqual(@as(usize, 0), instance2.getValue());

    // Cleanup
    counter1.reset();
    config.reset();
}

// ANCHOR: cleanup_resources
test "cleanup module resources" {
    // For modules that allocate resources, call deinit when done
    // This test should run last to clean up the config module
    defer config.deinit();

    config.setValue("final_test", true);
    try testing.expect(config.getValue("final_test"));

    // deinit() will be called, freeing HashMaps
}
// ANCHOR_END: cleanup_resources
