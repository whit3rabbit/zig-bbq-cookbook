// Recipe 10.10: Importing Modules Using a Name Given in a String
// Target Zig Version: 0.15.2
//
// This recipe demonstrates working with dynamic module selection in Zig.
// Unlike Python's importlib, Zig's @import requires compile-time known strings.
// This recipe shows patterns for achieving dynamic module selection at comptime.
//
// Key concepts:
// - Compile-time string matching
// - Module registry patterns
// - Switch-based module selection
// - Function pointer tables
// - Comptime module resolution

const std = @import("std");
const testing = std.testing;

// ANCHOR: module_simulation
// In a real project, these would be separate module files
pub const ModuleA = struct {
    pub const name = "module_a";
    pub const version = "1.0.0";

    pub fn process(value: i32) i32 {
        return value * 2;
    }
};

pub const ModuleB = struct {
    pub const name = "module_b";
    pub const version = "1.1.0";

    pub fn process(value: i32) i32 {
        return value + 10;
    }
};

pub const ModuleC = struct {
    pub const name = "module_c";
    pub const version = "2.0.0";

    pub fn process(value: i32) i32 {
        return value - 5;
    }
};
// ANCHOR_END: module_simulation

// ANCHOR: comptime_module_lookup
// Select a module at compile time based on a string
fn getModule(comptime name: []const u8) type {
    if (std.mem.eql(u8, name, "module_a")) {
        return ModuleA;
    } else if (std.mem.eql(u8, name, "module_b")) {
        return ModuleB;
    } else if (std.mem.eql(u8, name, "module_c")) {
        return ModuleC;
    } else {
        @compileError("Unknown module: " ++ name);
    }
}

test "comptime module lookup" {
    const mod = getModule("module_a");
    try testing.expectEqualStrings("module_a", mod.name);
    try testing.expectEqual(@as(i32, 20), mod.process(10));

    const mod_b = getModule("module_b");
    try testing.expectEqual(@as(i32, 20), mod_b.process(10));
}
// ANCHOR_END: comptime_module_lookup

// ANCHOR: switch_module_selection
fn selectModule(comptime name: []const u8) type {
    return switch (std.meta.stringToEnum(ModuleName, name) orelse @compileError("Invalid module")) {
        .module_a => ModuleA,
        .module_b => ModuleB,
        .module_c => ModuleC,
    };
}

const ModuleName = enum {
    module_a,
    module_b,
    module_c,
};

test "switch module selection" {
    const mod = selectModule("module_a");
    try testing.expectEqualStrings("module_a", mod.name);

    const mod_c = selectModule("module_c");
    try testing.expectEqual(@as(i32, 5), mod_c.process(10));
}
// ANCHOR_END: switch_module_selection

// ANCHOR: module_registry
const ModuleRegistry = struct {
    pub fn get(comptime name: []const u8) type {
        return inline for (registered_modules) |module| {
            if (std.mem.eql(u8, name, module.name)) {
                break module.type;
            }
        } else @compileError("Module not registered: " ++ name);
    }

    pub fn has(comptime name: []const u8) bool {
        inline for (registered_modules) |module| {
            if (std.mem.eql(u8, name, module.name)) {
                return true;
            }
        }
        return false;
    }

    pub fn list() []const ModuleEntry {
        return &registered_modules;
    }
};

const ModuleEntry = struct {
    name: []const u8,
    type: type,
};

const registered_modules = [_]ModuleEntry{
    .{ .name = "module_a", .type = ModuleA },
    .{ .name = "module_b", .type = ModuleB },
    .{ .name = "module_c", .type = ModuleC },
};

test "module registry" {
    const mod = ModuleRegistry.get("module_a");
    try testing.expectEqualStrings("module_a", mod.name);

    try testing.expect(ModuleRegistry.has("module_b"));
    try testing.expect(!ModuleRegistry.has("module_d"));

    const all_modules = ModuleRegistry.list();
    try testing.expectEqual(@as(usize, 3), all_modules.len);
}
// ANCHOR_END: module_registry

// ANCHOR: runtime_dispatch
const ModuleInterface = struct {
    process_fn: *const fn (i32) i32,
    name: []const u8,
    version: []const u8,
};

const RuntimeModuleEntry = struct {
    name: []const u8,
    interface: ModuleInterface,
};

const module_entries = [_]RuntimeModuleEntry{
    .{ .name = "module_a", .interface = .{
        .process_fn = &ModuleA.process,
        .name = ModuleA.name,
        .version = ModuleA.version,
    } },
    .{ .name = "module_b", .interface = .{
        .process_fn = &ModuleB.process,
        .name = ModuleB.name,
        .version = ModuleB.version,
    } },
    .{ .name = "module_c", .interface = .{
        .process_fn = &ModuleC.process,
        .name = ModuleC.name,
        .version = ModuleC.version,
    } },
};

fn getModuleRuntime(name: []const u8) ?ModuleInterface {
    for (module_entries) |entry| {
        if (std.mem.eql(u8, entry.name, name)) {
            return entry.interface;
        }
    }
    return null;
}

test "runtime module dispatch" {
    const module_name = "module_a"; // Could be runtime value
    const mod = getModuleRuntime(module_name);

    try testing.expect(mod != null);
    try testing.expectEqualStrings("module_a", mod.?.name);
    try testing.expectEqual(@as(i32, 20), mod.?.process_fn(10));

    const missing = getModuleRuntime("nonexistent");
    try testing.expect(missing == null);
}
// ANCHOR_END: runtime_dispatch

// ANCHOR: generic_module_wrapper
fn ModuleWrapper(comptime T: type) type {
    return struct {
        const Self = @This();

        pub fn getName() []const u8 {
            return T.name;
        }

        pub fn getVersion() []const u8 {
            return T.version;
        }

        pub fn process(value: i32) i32 {
            return T.process(value);
        }

        pub fn getInfo() ModuleInfo {
            return .{
                .name = T.name,
                .version = T.version,
            };
        }
    };
}

const ModuleInfo = struct {
    name: []const u8,
    version: []const u8,
};

test "generic module wrapper" {
    const wrapped = ModuleWrapper(ModuleA);

    try testing.expectEqualStrings("module_a", wrapped.getName());
    try testing.expectEqualStrings("1.0.0", wrapped.getVersion());
    try testing.expectEqual(@as(i32, 20), wrapped.process(10));
}
// ANCHOR_END: generic_module_wrapper

// ANCHOR: module_loader
const ModuleLoader = struct {
    pub fn load(comptime name: []const u8) type {
        if (ModuleRegistry.has(name)) {
            return ModuleRegistry.get(name);
        } else {
            @compileError("Failed to load module: " ++ name);
        }
    }

    pub fn loadWithFallback(comptime name: []const u8, comptime fallback: type) type {
        if (ModuleRegistry.has(name)) {
            return ModuleRegistry.get(name);
        } else {
            return fallback;
        }
    }
};

test "module loader" {
    const mod = ModuleLoader.load("module_a");
    try testing.expectEqualStrings("module_a", mod.name);

    const mod_with_fallback = ModuleLoader.loadWithFallback("nonexistent", ModuleB);
    try testing.expectEqualStrings("module_b", mod_with_fallback.name);
}
// ANCHOR_END: module_loader

// ANCHOR: conditional_import
fn conditionalModule(comptime condition: bool) type {
    if (condition) {
        return ModuleA;
    } else {
        return ModuleB;
    }
}

test "conditional module import" {
    const use_module_a = true;
    const mod = conditionalModule(use_module_a);

    try testing.expectEqualStrings("module_a", mod.name);
}
// ANCHOR_END: conditional_import

// ANCHOR: version_based_selection
fn getModuleByVersion(comptime min_version: []const u8) type {
    // Note: This is a simplified example. For production code, use
    // std.SemanticVersion for proper version parsing and comparison.
    // Currently always returns the latest version module.
    _ = min_version;

    if (std.mem.eql(u8, ModuleC.version, "2.0.0")) {
        return ModuleC;
    } else if (std.mem.eql(u8, ModuleB.version, "1.1.0")) {
        return ModuleB;
    } else {
        return ModuleA;
    }
}

test "version based selection" {
    const mod = getModuleByVersion("1.0.0");
    try testing.expectEqualStrings("2.0.0", mod.version);
}
// ANCHOR_END: version_based_selection

// ANCHOR: plugin_system
const PluginInterface = struct {
    init_fn: *const fn () void,
    process_fn: *const fn (i32) i32,
    deinit_fn: *const fn () void,
    name: []const u8,
};

const PluginRegistry = struct {
    const plugins = [_]PluginInterface{
        .{
            .init_fn = &pluginAInit,
            .process_fn = &ModuleA.process,
            .deinit_fn = &pluginADeinit,
            .name = "plugin_a",
        },
        .{
            .init_fn = &pluginBInit,
            .process_fn = &ModuleB.process,
            .deinit_fn = &pluginBDeinit,
            .name = "plugin_b",
        },
    };

    pub fn get(name: []const u8) ?PluginInterface {
        for (plugins) |plugin| {
            if (std.mem.eql(u8, plugin.name, name)) {
                return plugin;
            }
        }
        return null;
    }

    pub fn getAll() []const PluginInterface {
        return &plugins;
    }
};

fn pluginAInit() void {}
fn pluginADeinit() void {}
fn pluginBInit() void {}
fn pluginBDeinit() void {}

test "plugin system" {
    const plugin = PluginRegistry.get("plugin_a");
    try testing.expect(plugin != null);

    plugin.?.init_fn();
    const result = plugin.?.process_fn(10);
    try testing.expectEqual(@as(i32, 20), result);
    plugin.?.deinit_fn();

    const all = PluginRegistry.getAll();
    try testing.expectEqual(@as(usize, 2), all.len);
}
// ANCHOR_END: plugin_system

// ANCHOR: feature_flags
const Features = struct {
    enable_module_a: bool = true,
    enable_module_b: bool = false,
    enable_module_c: bool = true,
};

fn getEnabledModule(comptime features: Features) type {
    if (features.enable_module_a) {
        return ModuleA;
    } else if (features.enable_module_b) {
        return ModuleB;
    } else if (features.enable_module_c) {
        return ModuleC;
    } else {
        @compileError("No module enabled");
    }
}

test "feature flag selection" {
    const features = Features{
        .enable_module_a = false,
        .enable_module_b = true,
        .enable_module_c = false,
    };

    const mod = getEnabledModule(features);
    try testing.expectEqualStrings("module_b", mod.name);
}
// ANCHOR_END: feature_flags

// ANCHOR: lazy_module_loading
// Note: This demonstrates the lazy loading pattern conceptually.
// Since everything is comptime, there's no runtime performance benefit.
// For actual runtime lazy loading, use optionals with runtime checks.
const LazyModule = struct {
    loaded: bool = false,
    module_type: type,

    pub fn get(comptime self: *LazyModule) type {
        if (!self.loaded) {
            self.loaded = true;
        }
        return self.module_type;
    }
};

test "lazy module loading" {
    comptime var lazy = LazyModule{ .module_type = ModuleA };
    try testing.expect(!lazy.loaded);

    const mod = lazy.get();
    try testing.expect(lazy.loaded);
    try testing.expectEqualStrings("module_a", mod.name);
}
// ANCHOR_END: lazy_module_loading

// ANCHOR: module_alias
const ModuleAlias = struct {
    pub const Primary = ModuleA;
    pub const Secondary = ModuleB;
    pub const Fallback = ModuleC;

    pub fn resolve(comptime alias: []const u8) type {
        if (std.mem.eql(u8, alias, "primary")) {
            return Primary;
        } else if (std.mem.eql(u8, alias, "secondary")) {
            return Secondary;
        } else if (std.mem.eql(u8, alias, "fallback")) {
            return Fallback;
        } else {
            @compileError("Unknown alias: " ++ alias);
        }
    }
};

test "module aliases" {
    const mod = ModuleAlias.resolve("primary");
    try testing.expectEqualStrings("module_a", mod.name);

    const fallback = ModuleAlias.resolve("fallback");
    try testing.expectEqualStrings("module_c", fallback.name);
}
// ANCHOR_END: module_alias

// ANCHOR: environment_based
fn getModuleForEnvironment(comptime env: []const u8) type {
    if (std.mem.eql(u8, env, "development")) {
        return ModuleA;
    } else if (std.mem.eql(u8, env, "staging")) {
        return ModuleB;
    } else if (std.mem.eql(u8, env, "production")) {
        return ModuleC;
    } else {
        @compileError("Unknown environment: " ++ env);
    }
}

test "environment based selection" {
    const mod = getModuleForEnvironment("production");
    try testing.expectEqualStrings("module_c", mod.name);
}
// ANCHOR_END: environment_based

// Comprehensive test
test "comprehensive module selection patterns" {
    // Comptime lookup
    const mod_a = getModule("module_a");
    try testing.expectEqual(@as(i32, 20), mod_a.process(10));

    // Switch selection
    const mod_b = selectModule("module_b");
    try testing.expectEqual(@as(i32, 20), mod_b.process(10));

    // Registry
    try testing.expect(ModuleRegistry.has("module_c"));

    // Runtime dispatch
    const runtime_mod = getModuleRuntime("module_a");
    try testing.expect(runtime_mod != null);

    // Plugin system
    const plugin = PluginRegistry.get("plugin_a");
    try testing.expect(plugin != null);
}
