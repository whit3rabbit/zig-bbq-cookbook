# Recipe 10.9: Adding Directories to the Build Path

## Problem

You need to organize a large Zig project across multiple directories (like `lib/`, `vendor/`, `src/`) and configure the build system to locate and link modules from these different locations.

## Solution

Zig's build system uses `build.zig` to define modules from different directories and establish their relationships. Unlike languages with implicit path resolution, Zig requires explicit module declaration and dependency management.

### Project Structure

A typical multi-directory project looks like this:

```
project/
├── build.zig
├── src/
│   └── main.zig
├── lib/
│   ├── core/
│   │   └── core.zig
│   └── utils/
│       └── utils.zig
└── vendor/
    └── external/
        └── external.zig
```

### Basic build.zig Configuration

Here's how to configure modules from different directories:

```zig
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Define core module from lib directory
    const core = b.addModule("core", .{
        .root_source_file = b.path("lib/core/core.zig"),
    });

    // Define utils module with dependency on core
    const utils = b.addModule("utils", .{
        .root_source_file = b.path("lib/utils/utils.zig"),
        .imports = &.{
            .{ .name = "core", .module = core },
        },
    });

    // Define external vendor module
    const external = b.addModule("external", .{
        .root_source_file = b.path("vendor/external/external.zig"),
    });

    // Create executable
    const exe = b.addExecutable(.{
        .name = "myapp",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add module imports to executable
    exe.root_module.addImport("core", core);
    exe.root_module.addImport("utils", utils);
    exe.root_module.addImport("external", external);

    b.installArtifact(exe);
}
```

In `src/main.zig`, you can then import these modules:

```zig
const std = @import("std");
const core = @import("core");
const utils = @import("utils");
const external = @import("external");

pub fn main() !void {
    core.initialize();
    // Use modules...
}
```

## Discussion

### Python vs Zig Module Systems

The approaches differ significantly:

**Python:**
```python
# Implicit path-based imports
import lib.core.core
from lib.utils import formatString
import vendor.external

# Or modify sys.path
import sys
sys.path.append('vendor')
import external
```

**Zig:**
```zig
// Explicit module declaration in build.zig required
const core = @import("core");  // Maps to module defined in build.zig
const utils = @import("utils"); // Not a file path!

// build.zig controls all module resolution
```

Key differences:
- **Explicit vs Implicit**: Zig requires build.zig configuration; Python uses file paths directly
- **Dependency Management**: Zig declares dependencies explicitly; Python resolves at import time
- **Compile-Time Safety**: Zig catches missing modules at build time; Python fails at runtime
- **No Search Paths**: Zig doesn't search directories; all modules must be declared

### Module Registry Pattern

For complex projects, you might implement a module registry to track available modules:

```zig
{{#include ../../../code/03-advanced/10-modules-build-system/recipe_10_9.zig:module_registry}}
```

This helps when generating build configurations or validating module dependencies.

### Path Resolution

When working with multiple directories, path resolution becomes important:

```zig
const PathResolver = struct {
    base_paths: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn addPath(self: *PathResolver, path: []const u8) !void {
        const owned_path = try self.allocator.dupe(u8, path);
        try self.base_paths.append(self.allocator, owned_path);
    }

    pub fn resolve(self: *PathResolver, relative_path: []const u8) !?[]u8 {
        for (self.base_paths.items) |base| {
            const full_path = try std.fs.path.join(
                self.allocator,
                &.{ base, relative_path },
            );
            // Check if file exists
            std.fs.cwd().access(full_path, .{}) catch {
                self.allocator.free(full_path);
                continue;
            };
            return full_path;
        }
        return null;
    }
};
```

This pattern searches multiple base directories for a file, similar to how compilers search include paths.

### Dependency Graphs

Complex projects benefit from dependency graph analysis to detect cycles and ensure correct build order:

```zig
const DependencyGraph = struct {
    nodes: std.StringHashMap(Node),
    allocator: std.mem.Allocator,

    const Node = struct {
        name: []const u8,
        dependencies: std.ArrayList([]const u8),
    };

    pub fn addNode(self: *DependencyGraph, name: []const u8) !void {
        const owned_name = try self.allocator.dupe(u8, name);
        const node = Node{
            .name = owned_name,
            .dependencies = std.ArrayList([]const u8){},
        };
        try self.nodes.put(try self.allocator.dupe(u8, name), node);
    }

    pub fn addDependency(
        self: *DependencyGraph,
        from: []const u8,
        to: []const u8,
    ) !void {
        var node = self.nodes.getPtr(from) orelse return error.NodeNotFound;
        const owned_dep = try self.allocator.dupe(u8, to);
        try node.dependencies.append(self.allocator, owned_dep);
    }

    pub fn hasCycle(self: *DependencyGraph) !bool {
        // Use DFS with visited/in-path tracking
        // Returns true if cycle detected
    }
};
```

Example usage:

```zig
var graph = DependencyGraph.init(allocator);
defer graph.deinit();

try graph.addNode("main");
try graph.addNode("utils");
try graph.addNode("core");

try graph.addDependency("main", "utils");
try graph.addDependency("utils", "core");

if (try graph.hasCycle()) {
    std.debug.print("Circular dependency detected!\n", .{});
}
```

### Module Loader Pattern

A module loader tracks what's been loaded to avoid duplicate work:

```zig
const ModuleLoader = struct {
    search_paths: std.ArrayList([]const u8),
    loaded_modules: std.StringHashMap(void),
    allocator: std.mem.Allocator,

    pub fn addSearchPath(self: *ModuleLoader, path: []const u8) !void {
        const owned = try self.allocator.dupe(u8, path);
        try self.search_paths.append(self.allocator, owned);
    }

    pub fn loadModule(self: *ModuleLoader, name: []const u8) !void {
        if (self.loaded_modules.contains(name)) {
            return; // Already loaded
        }

        const owned = try self.allocator.dupe(u8, name);
        try self.loaded_modules.put(owned, {});
    }

    pub fn isLoaded(self: *const ModuleLoader, name: []const u8) bool {
        return self.loaded_modules.contains(name);
    }
};
```

### Project Structure Helpers

Create utilities to work with standard project layouts:

```zig
const ProjectStructure = struct {
    root: []const u8,
    src_dir: []const u8,
    lib_dir: []const u8,
    vendor_dir: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, root: []const u8) !ProjectStructure {
        return .{
            .root = try allocator.dupe(u8, root),
            .src_dir = try std.fs.path.join(allocator, &.{ root, "src" }),
            .lib_dir = try std.fs.path.join(allocator, &.{ root, "lib" }),
            .vendor_dir = try std.fs.path.join(allocator, &.{ root, "vendor" }),
            .allocator = allocator,
        };
    }

    pub fn getModulePath(
        self: *ProjectStructure,
        category: []const u8,
        module: []const u8,
    ) ![]u8 {
        const base = if (std.mem.eql(u8, category, "lib"))
            self.lib_dir
        else if (std.mem.eql(u8, category, "vendor"))
            self.vendor_dir
        else
            self.src_dir;

        return std.fs.path.join(self.allocator, &.{ base, module });
    }
};
```

### Import Validation

For large teams, you might want to enforce module visibility rules:

```zig
const ImportValidator = struct {
    allowed_imports: std.StringHashMap(std.ArrayList([]const u8)),
    allocator: std.mem.Allocator,

    pub fn allowImport(
        self: *ImportValidator,
        module: []const u8,
        import: []const u8,
    ) !void {
        const gop = try self.allowed_imports.getOrPut(module);
        if (!gop.found_existing) {
            gop.key_ptr.* = try self.allocator.dupe(u8, module);
            gop.value_ptr.* = std.ArrayList([]const u8){};
        }

        const owned_import = try self.allocator.dupe(u8, import);
        try gop.value_ptr.append(self.allocator, owned_import);
    }

    pub fn canImport(
        self: *ImportValidator,
        module: []const u8,
        import: []const u8,
    ) bool {
        const imports = self.allowed_imports.get(module) orelse return false;
        for (imports.items) |allowed| {
            if (std.mem.eql(u8, allowed, import)) {
                return true;
            }
        }
        return false;
    }
};
```

Example usage:

```zig
var validator = ImportValidator.init(allocator);
defer validator.deinit();

// Define allowed imports
try validator.allowImport("main", "core");
try validator.allowImport("main", "utils");
try validator.allowImport("utils", "core");

// Validate an import
if (!validator.canImport("main", "vendor")) {
    std.debug.print("Import not allowed!\n", .{});
}
```

## Best Practices

1. **Explicit Dependencies**: Always declare module dependencies in `.imports`
2. **Avoid Circular Dependencies**: Use dependency graphs to detect cycles early
3. **Consistent Directory Structure**: Follow conventions like `lib/`, `src/`, `vendor/`
4. **Module Naming**: Use clear, descriptive names that match their purpose
5. **Version Control**: Track `build.zig` carefully as it's critical to builds
6. **Documentation**: Comment module purposes and dependencies
7. **Lazy Loading**: Only import modules actually needed
8. **Path Safety**: Use `b.path()` for relative paths in build.zig
9. **Test Organization**: Keep test files near the code they test
10. **Vendor Isolation**: Keep third-party code separate from your modules

## Common Patterns

### Library + Binary Structure

```
project/
├── build.zig
├── src/
│   └── main.zig          # Binary entry point
└── lib/
    ├── mylib.zig         # Library root
    ├── core/
    │   └── core.zig
    └── utils/
        └── utils.zig
```

```zig
// build.zig
const lib = b.addStaticLibrary(.{
    .name = "mylib",
    .root_source_file = b.path("lib/mylib.zig"),
    .target = target,
    .optimize = optimize,
});

const exe = b.addExecutable(.{
    .name = "myapp",
    .root_source_file = b.path("src/main.zig"),
    .target = target,
    .optimize = optimize,
});

exe.linkLibrary(lib);
```

### Monorepo with Multiple Packages

```
monorepo/
├── packages/
│   ├── package-a/
│   │   ├── build.zig
│   │   └── src/
│   └── package-b/
│       ├── build.zig
│       └── src/
└── shared/
    └── common/
        └── common.zig
```

Each package's `build.zig` can reference shared modules using relative paths.

### Plugin System Structure

```
app/
├── build.zig
├── src/
│   └── main.zig
├── core/
│   └── plugin_interface.zig
└── plugins/
    ├── plugin1/
    │   └── plugin1.zig
    └── plugin2/
        └── plugin2.zig
```

The build system can dynamically discover and include plugins.

## Troubleshooting

**Module not found:**
- Check that `addModule` was called in build.zig
- Verify the `root_source_file` path is correct
- Ensure `addImport` was called on the importing module

**Circular dependency:**
- Use dependency graph analysis to find the cycle
- Refactor to extract shared code into a separate module
- Consider using dependency inversion

**Wrong module loaded:**
- Check that module names are unique
- Verify import names match `addImport` calls exactly
- Look for typos in module names

**Build path issues:**
- Use `b.path()` for all paths in build.zig
- Paths are relative to build.zig location
- Don't use absolute paths (breaks portability)

## See Also

- Recipe 10.1: Making a Hierarchical Package of Modules - Basic module organization
- Recipe 10.3: Importing Package Submodules - Using relative imports
- Recipe 10.4: Splitting a Module into Multiple Files - Breaking up large modules
- Recipe 10.11: Distributing Packages - Packaging for distribution

Full compilable example: `code/03-advanced/10-modules-build-system/recipe_10_9.zig`
