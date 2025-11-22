# Recipe 10.10: Importing Modules Using a Name Given in a String

## Problem

You want to import or select a module dynamically based on a string value, similar to Python's `importlib.import_module()`. However, Zig's `@import` only accepts compile-time known string literals.

## Solution

While Zig doesn't support true runtime dynamic imports (by design), you can achieve similar functionality using compile-time module selection patterns. The key is distinguishing between compile-time module resolution and runtime module dispatch.

### Compile-Time Module Lookup

For string values known at compile time, use conditional logic:

```zig
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

// Usage
const mod = getModule("module_a");
const result = mod.process(10);
```

### Switch-Based Selection with Enums

For cleaner code, use enums with `std.meta.stringToEnum`:

```zig
const ModuleName = enum {
    module_a,
    module_b,
    module_c,
};

fn selectModule(comptime name: []const u8) type {
    return switch (std.meta.stringToEnum(ModuleName, name) orelse
                   @compileError("Invalid module")) {
        .module_a => ModuleA,
        .module_b => ModuleB,
        .module_c => ModuleC,
    };
}

// Usage
const mod = selectModule("module_b");
```

### Module Registry Pattern

For more sophisticated module management:

```zig
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
```

Usage:

```zig
// Check if module exists
if (ModuleRegistry.has("module_b")) {
    const mod = ModuleRegistry.get("module_b");
    // Use module...
}

// List all registered modules
const all_modules = ModuleRegistry.list();
```

## Discussion

### Why Zig Doesn't Have Dynamic Imports

Zig's philosophy prioritizes:
- **No hidden control flow**: All imports are visible at compile time
- **Performance**: No runtime module loading overhead
- **Safety**: Missing modules are compile errors, not runtime failures
- **Simplicity**: No need for complex module loading systems

This makes Zig programs more predictable and easier to analyze.

### Python vs Zig Comparison

**Python (Runtime Dynamic):**
```python
import importlib

# Runtime module loading
module_name = "module_a"  # Could come from config file
mod = importlib.import_module(module_name)
result = mod.process(10)

# Can load modules not known at compile time
user_input = input("Which module? ")
mod = importlib.import_module(user_input)
```

**Zig (Compile-Time Selection):**
```zig
// Compile-time module selection
const module_name = "module_a"; // Must be comptime known
const mod = getModule(module_name);
const result = mod.process(10);

// Cannot use runtime values for @import
// var user_input = getUserInput();
// const mod = @import(user_input); // ERROR!
```

The fundamental difference: Python loads modules at runtime; Zig resolves all modules at compile time.

### Runtime Dispatch Alternative

If you need runtime selection (e.g., loading different implementations based on config), use function pointer tables:

```zig
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
};

fn getModuleRuntime(name: []const u8) ?ModuleInterface {
    for (module_entries) |entry| {
        if (std.mem.eql(u8, entry.name, name)) {
            return entry.interface;
        }
    }
    return null;
}
```

Usage:

```zig
// Can use runtime value
var config = try loadConfig();
const module_name = config.preferred_module;

if (getModuleRuntime(module_name)) |mod| {
    const result = mod.process_fn(10);
    std.debug.print("Module: {s}, Result: {d}\n", .{ mod.name, result });
}
```

This provides runtime flexibility while maintaining compile-time safety (all possible modules are known at compile time).

### Generic Module Wrapper

Create a unified interface for different module types:

```zig
fn ModuleWrapper(comptime T: type) type {
    return struct {
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

// Usage
const wrapped = ModuleWrapper(ModuleA);
const name = wrapped.getName();
const result = wrapped.process(10);
```

### Module Loader with Fallback

Provide graceful fallback for missing modules:

```zig
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

// Usage
const mod = ModuleLoader.loadWithFallback("optional_module", DefaultModule);
```

### Plugin System Pattern

For plugin architectures:

```zig
{{#include ../../../code/03-advanced/10-modules-build-system/recipe_10_10.zig:plugin_system}}
```

Usage:

```zig
// Load plugin by name at runtime
if (PluginRegistry.get("plugin_a")) |plugin| {
    plugin.init_fn();
    const result = plugin.process_fn(10);
    plugin.deinit_fn();
}

// Iterate all plugins
for (PluginRegistry.getAll()) |plugin| {
    std.debug.print("Plugin: {s}\n", .{plugin.name});
}
```

### Feature Flags Pattern

Enable/disable modules based on compile-time configuration:

```zig
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

// Usage (typically configured in build.zig)
const features = Features{
    .enable_module_a = false,
    .enable_module_b = true,
    .enable_module_c = false,
};

const mod = getEnabledModule(features);
```

### Environment-Based Selection

Choose modules based on build environment:

```zig
fn getModuleForEnvironment(comptime env: []const u8) type {
    if (std.mem.eql(u8, env, "development")) {
        return DevelopmentModule;
    } else if (std.mem.eql(u8, env, "staging")) {
        return StagingModule;
    } else if (std.mem.eql(u8, env, "production")) {
        return ProductionModule;
    } else {
        @compileError("Unknown environment: " ++ env);
    }
}

// In build.zig, pass environment as build option
const env = b.option([]const u8, "env", "Build environment") orelse "development";
const mod = getModuleForEnvironment(env);
```

### Module Aliases

Create friendly names for modules:

```zig
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

// Usage
const mod = ModuleAlias.resolve("primary");
```

## Best Practices

1. **Use Compile-Time When Possible**: Prefer `comptime` selection for better performance and error detection
2. **Runtime Dispatch for True Dynamics**: Use function pointers when module choice genuinely depends on runtime data
3. **Clear Error Messages**: Use `@compileError` with descriptive messages for invalid modules
4. **Document Module Contracts**: Ensure all modules in a registry follow the same interface
5. **Consider Table Size**: Runtime dispatch tables have O(n) lookup; use enums/switches for small sets
6. **Version Management**: Include version information in module interfaces
7. **Plugin Discovery**: For plugin systems, consider comptime discovery patterns
8. **Feature Flags**: Use comptime flags to enable/disable entire modules
9. **Type Safety**: Ensure runtime dispatch maintains type safety through interfaces
10. **Testing**: Test all code paths for each possible module selection

## Performance Considerations

**Compile-Time Selection:**
- Zero runtime overhead
- All module calls can be inlined
- Dead code elimination removes unused modules
- Optimal for known configurations

**Runtime Dispatch:**
- Small overhead from table lookup
- Function pointer indirection (typically 1-2 CPU cycles)
- No inlining across dispatch boundary
- Necessary for truly dynamic selection

**Hybrid Approach:**
Use compile-time selection for the 90% case, runtime dispatch for the 10% that truly needs it:

```zig
const mod = if (comptime std.mem.eql(u8, config.module, "default")) {
    DefaultModule;  // Compile-time selection for common case
} else {
    getModuleRuntime(config.module); // Runtime for rare case
};
```

## Common Patterns

**Config-Driven Module Selection:**
```zig
const Config = struct {
    database: []const u8 = "postgres",
    cache: []const u8 = "redis",
    logging: []const u8 = "syslog",
};

fn getDatabaseModule(comptime config: Config) type {
    return ModuleRegistry.get(config.database);
}
```

**Conditional Compilation:**
```zig
const mod = if (@import("builtin").os.tag == .windows)
    WindowsModule
else if (@import("builtin").os.tag == .linux)
    LinuxModule
else
    PosixModule;
```

**Module Composition:**
```zig
fn ComposeModules(comptime A: type, comptime B: type) type {
    return struct {
        pub fn process(value: i32) i32 {
            return B.process(A.process(value));
        }
    };
}

const composed = ComposeModules(ModuleA, ModuleB);
```

## Troubleshooting

**"Module name must be comptime known":**
- Zig requires module names at compile time
- Use runtime dispatch with function pointers instead

**"Module not found at compile time":**
- Check module registry includes the module
- Verify module name spelling is correct
- Ensure module is imported in the file

**"Type mismatch in module interface":**
- All modules in a registry must match the interface
- Verify function signatures match exactly
- Check return types and parameter types

## See Also

- Recipe 10.1: Making a Hierarchical Package of Modules - Basic module organization
- Recipe 10.7: Making a Directory or Zip File Runnable - Entry points
- Recipe 9.11: Using Comptime to Control Instance Creation - Comptime patterns
- Recipe 9.13: Defining a Generic that Takes Optional Arguments - Generic patterns

Full compilable example: `code/03-advanced/10-modules-build-system/recipe_10_10.zig`
