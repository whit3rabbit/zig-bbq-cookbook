## Problem

You're familiar with dynamic languages like Python's `importlib.reload()` that reload modules at runtime. You want to update module code without restarting your program, or you need to understand how Zig handles module imports and state. You're concerned about module state being shared between different parts of your code.

## Solution

Recognize that Zig is a compiled language with static module resolution. Modules cannot be "reloaded" at runtime like Python. Instead, use Zig-appropriate patterns: understand import caching (modules are singletons at compile time), use reset functions for state management, prefer instance structs over global state, and leverage the build system for code updates.

### Understanding Import Caching

Zig caches `@import()` results at compile time:

```zig
{{#include ../../../code/03-advanced/10-modules-build-system/recipe_10_6.zig:import_caching}}
```

Multiple imports of the same module return the same instance.

### Imports Are Cached

Test that imports share the same module:

```zig
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
```

This is by design - modules are compile-time singletons.

## Discussion

### Module State is Shared

All imports of a module share the same state:

```zig
test "module state is shared across imports" {
    counter1.reset();

    counter1.increment();
    try testing.expectEqual(@as(usize, 1), counter1.getValue());

    // counter2 is the same module, so sees the same state
    try testing.expectEqual(@as(usize, 1), counter2.getValue());

    counter2.increment();
    try testing.expectEqual(@as(usize, 2), counter1.getValue());
}
```

Changes through one import affect all other imports.

### Counter Module

The counter module demonstrates global state:

```zig
// Counter module - demonstrates module state and caching
const std = @import("std");

// Module-level state (shared across all imports)
// NOTE: Global state has limitations - see recipe for alternatives
var count: usize = 0;

pub fn increment() void {
    count += 1;
}

pub fn decrement() void {
    if (count > 0) {
        count -= 1;
    }
}

pub fn getValue() usize {
    return count;
}

pub fn reset() void {
    count = 0;
}

pub fn setValue(value: usize) void {
    count = value;
}
```

Global module state is simple but has testing challenges.

### Reset Pattern

Modules with state should provide reset functions:

```zig
test "resetting module state" {
    // Modules with state should provide reset() functions
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
```

Reset functions enable clean test isolation.

### Initialization Pattern

For modules needing setup/teardown:

```zig
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
```

Use defer for automatic cleanup.

### Configuration Module

The config module demonstrates compile-time constants and runtime state:

```zig
// Configuration module
const std = @import("std");

// Compile-time constants - cannot be changed without recompiling
pub const VERSION = "1.0.0";
pub const APP_NAME = "MyApp";
pub const MAX_CONNECTIONS = 100;

// Runtime configuration state
var debug_mode: bool = false;
var log_level: i32 = 0;
var feature_x_enabled: bool = false;
var timeout_seconds: i32 = 30;

// Simple key-value storage for demonstration
var bool_config: std.StringHashMap(bool) = undefined;
var int_config: std.StringHashMap(i32) = undefined;
var initialized: bool = false;

fn ensureInit() void {
    if (!initialized) {
        bool_config = std.StringHashMap(bool).init(std.heap.page_allocator);
        int_config = std.StringHashMap(i32).init(std.heap.page_allocator);
        initialized = true;
    }
}

pub fn setValue(key: []const u8, value: bool) void {
    ensureInit();
    bool_config.put(key, value) catch return;
}

pub fn setIntValue(key: []const u8, value: i32) void {
    ensureInit();
    int_config.put(key, value) catch return;
}

pub fn getValue(key: []const u8) bool {
    ensureInit();
    return bool_config.get(key) orelse false;
}

pub fn getIntValue(key: []const u8) i32 {
    ensureInit();
    return int_config.get(key) orelse 0;
}

pub fn reset() void {
    if (initialized) {
        bool_config.clearRetainingCapacity();
        int_config.clearRetainingCapacity();
    }
    debug_mode = false;
    log_level = 0;
    feature_x_enabled = false;
    timeout_seconds = 30;
}

pub fn deinit() void {
    if (initialized) {
        bool_config.deinit();
        int_config.deinit();
        initialized = false;
    }
}
```

Separate compile-time constants from runtime state.

### Compile-Time Constants

Compile-time constants cannot change without recompilation:

```zig
test "compile-time constants are truly constant" {
    const version = @import("recipe_10_6/config.zig").VERSION;
    const name = @import("recipe_10_6/config.zig").APP_NAME;

    // These are compile-time constants and cannot be "reloaded"
    try testing.expectEqualStrings("1.0.0", version);
    try testing.expectEqualStrings("MyApp", name);

    // To change these, you must recompile
}
```

Use `pub const` for truly constant values.

### Module Singleton Pattern

Each module is a compile-time singleton:

```zig
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
```

Modules are singletons - you can't have multiple independent instances.

### Instance Pattern

To get independent state, use instance structs:

```zig
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
```

Instance structs allow multiple independent state containers.

### Avoiding Global State

Global state complicates testing:

```zig
test "avoiding global state for testability" {
    // Global module state makes testing difficult
    // Because imports are cached, tests can interfere with each other

    counter1.reset(); // Must reset before each test

    counter1.increment();
    try testing.expectEqual(@as(usize, 1), counter1.getValue());

    // If we forget to reset, the next test might fail
}
```

Tests must carefully manage shared state.

### Scoped State Management

Use defer for reliable cleanup:

```zig
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
```

Defer ensures cleanup even if the test fails.

### Configuration Changes

"Reloading" means resetting and applying new values:

```zig
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
```

Runtime state can change, but requires explicit reset and reconfiguration.

### Compile-Time vs Runtime

Understand the distinction:

```zig
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
```

Compile-time code is baked in; runtime state is mutable.

### Best Practices

Follow these patterns for module state:

```zig
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
```

These patterns prevent state pollution and testing issues.

### Cleanup Resources

Modules that allocate should provide deinit:

```zig
test "cleanup module resources" {
    // For modules that allocate resources, call deinit when done
    // This test should run last to clean up the config module
    defer config.deinit();

    config.setValue("final_test", true);
    try testing.expect(config.getValue("final_test"));

    // deinit() will be called, freeing HashMaps
}
```

Proper cleanup prevents memory leaks.

### When to Use Global State

Global module state is appropriate when:

**Single Instance:** Only one instance makes sense (logger, allocator registry)
**Constant Data:** Tables, lookup maps that never change
**Process-Wide Config:** Settings that apply to entire program

Avoid global state when:

**Testing:** State pollution between tests
**Concurrency:** Thread safety becomes complex
**Flexibility:** Users might want multiple instances
**Isolation:** Components should be independent

### Instance Pattern Benefits

The instance pattern offers advantages:

**Testability:**
- Each test creates fresh instances
- No state pollution
- Parallel test execution possible

**Flexibility:**
- Multiple independent instances
- Different configurations per instance
- Easy to pass around

**Clarity:**
- Explicit state ownership
- Clear initialization/cleanup
- Type-safe state access

### Zig vs Dynamic Languages

Comparison with Python's `reload()`:

**Python:**
```python
import mymodule
# Modify mymodule.py
importlib.reload(mymodule)  # Reload at runtime
```

**Zig Equivalent:**
```zig
// Modify module source
// Run: zig build
// Restart program with new code
```

Zig requires recompilation for code changes.

### Development Workflow

For interactive development:

**Watch Mode:**
```bash
# Use file watcher to trigger rebuild
while inotifywait -r src/; do
    zig build && ./zig-out/bin/myapp
done
```

**Build System Integration:**
```bash
# Some build tools support watch mode
zig build --watch  # (proposed feature)
```

**Dynamic Libraries:**
```zig
// For runtime updates, use dynamic loading
const lib = try std.DynLib.open("plugin.so");
defer lib.close();

const loadFn = lib.lookup(*const fn() void, "pluginInit") orelse return error.SymbolNotFound;
loadFn();
```

Shared libraries enable runtime code updates.

### Thread Safety Considerations

Global state and concurrency:

```zig
// WARNING: Module-level state is NOT thread-safe
var counter: usize = 0;  // Data race if accessed from multiple threads

pub fn increment() void {
    counter += 1;  // Race condition!
}
```

For thread-safe code:

```zig
const std = @import("std");

var counter_mutex: std.Thread.Mutex = .{};
var counter: usize = 0;

pub fn increment() void {
    counter_mutex.lock();
    defer counter_mutex.unlock();
    counter += 1;
}
```

Or use atomic operations:

```zig
var counter = std.atomic.Value(usize).init(0);

pub fn increment() void {
    _ = counter.fetchAdd(1, .monotonic);
}
```

Prefer instance pattern for better thread safety.

### Configuration Files

For runtime configuration updates:

```zig
const Config = struct {
    debug_mode: bool,
    log_level: i32,

    pub fn loadFromFile(allocator: std.mem.Allocator, path: []const u8) !Config {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        // Parse configuration file
        // Return Config instance
    }
};

test "reload config from file" {
    const allocator = std.testing.allocator;

    var config = try Config.loadFromFile(allocator, "config.json");

    // Modify config.json externally

    // "Reload" by reading file again
    config = try Config.loadFromFile(allocator, "config.json");
}
```

External files provide runtime configurability.

### Comptime vs Var

Understand the difference:

```zig
// Compile-time: Baked into binary
pub const VERSION = "1.0.0";
comptime var build_number = 0;  // Computed at compile time

// Runtime: Can change during execution
var connection_count: usize = 0;
var is_ready: bool = false;
```

Use `const` for unchanging values, `var` for mutable state.

### Hot Reload Patterns

For development, consider:

**Separate Data from Code:**
```zig
// config.json - can be edited while running
{
    "timeout": 30,
    "retries": 3
}

// Code reads config periodically
const config = try readConfig("config.json");
```

**Plugin Architecture:**
```zig
// Load plugins as shared libraries
const plugin = try std.DynLib.open("feature.so");
const init_fn = plugin.lookup(*const fn() void, "init") orelse return error.Missing;
init_fn();

// Can reload by closing and reopening
plugin.close();
const new_plugin = try std.DynLib.open("feature.so");
```

**Asset Reloading:**
```zig
// Watch for file changes
while (true) {
    const mtime = try getModificationTime("assets/textures.png");
    if (mtime != last_mtime) {
        texture = try loadTexture("assets/textures.png");
        last_mtime = mtime;
    }
    std.time.sleep(1 * std.time.ns_per_s);
}
```

These patterns enable development workflows without full restarts.

### Memory Management

Module state should be cleaned up:

```zig
// Bad: Leaks memory
var list: std.ArrayList(u8) = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    list = std.ArrayList(u8).init(allocator);
}

// Good: Provides cleanup
pub fn deinit() void {
    list.deinit();
}
```

Always provide deinit for allocated resources.

### Testing Isolation

Ensure tests don't interfere:

```zig
test "isolated test 1" {
    counter.reset();
    defer counter.reset();

    counter.increment();
    try testing.expectEqual(@as(usize, 1), counter.getValue());
}

test "isolated test 2" {
    counter.reset();
    defer counter.reset();

    // Starts fresh even if previous test forgot to reset
    try testing.expectEqual(@as(usize, 0), counter.getValue());
}
```

Reset at start and cleanup with defer.

### Summary

Key takeaways for module "reloading" in Zig:

1. **Imports are cached** - Each module is a compile-time singleton
2. **No runtime reload** - Code changes require recompilation
3. **Global state shared** - All imports see the same state
4. **Use reset functions** - Enable clean test isolation
5. **Prefer instances** - Better than global state for flexibility
6. **Use defer** - Ensures cleanup even on errors
7. **Separate concerns** - Compile-time constants vs runtime state
8. **Provide deinit** - Clean up allocated resources
9. **Consider concurrency** - Global state isn't thread-safe
10. **Use configuration files** - For runtime-changeable settings

## See Also

- Recipe 10.1: Making a hierarchical package of modules
- Recipe 10.4: Splitting a module into multiple files
- Recipe 10.5: Making separate directories of code import under a common namespace

Full compilable example: `code/03-advanced/10-modules-build-system/recipe_10_6.zig`
