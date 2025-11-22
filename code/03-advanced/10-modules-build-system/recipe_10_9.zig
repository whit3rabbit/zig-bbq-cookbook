// Recipe 10.9: Adding Directories to the Build Path
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to organize code across multiple directories
// and configure the build system to find modules in different locations.
//
// Key concepts:
// - Module organization across directories
// - Build.zig module configuration
// - Import paths and module resolution
// - Dependency management between modules
//
// Directory structure example:
// project/
// ├── build.zig
// ├── src/
// │   └── main.zig
// ├── lib/
// │   ├── core/
// │   │   └── core.zig
// │   └── utils/
// │       └── utils.zig
// └── vendor/
//     └── external/
//         └── external.zig

const std = @import("std");
const testing = std.testing;

// ANCHOR: module_structure
// This file demonstrates patterns for multi-directory projects.
// In a real project, these would be separate files in different directories.

// Simulating a core library module (lib/core/core.zig)
pub const CoreLib = struct {
    pub const version = "1.0.0";

    pub fn initialize() void {
        // Core initialization
    }

    pub fn shutdown() void {
        // Core shutdown
    }
};

// Simulating a utils library module (lib/utils/utils.zig)
pub const UtilsLib = struct {
    pub fn formatString(allocator: std.mem.Allocator, value: i32) ![]u8 {
        return std.fmt.allocPrint(allocator, "Value: {d}", .{value});
    }

    pub fn parseInteger(str: []const u8) !i32 {
        return std.fmt.parseInt(i32, str, 10);
    }
};

// Simulating an external vendor module (vendor/external/external.zig)
pub const ExternalLib = struct {
    pub const name = "external-lib";

    pub fn process(data: []const u8) usize {
        return data.len;
    }
};
// ANCHOR_END: module_structure

// ANCHOR: build_config_pattern
// In build.zig, modules are configured like this:
//
// const core = b.addModule("core", .{
//     .root_source_file = b.path("lib/core/core.zig"),
// });
//
// const utils = b.addModule("utils", .{
//     .root_source_file = b.path("lib/utils/utils.zig"),
//     .imports = &.{
//         .{ .name = "core", .module = core },
//     },
// });
//
// const external = b.addModule("external", .{
//     .root_source_file = b.path("vendor/external/external.zig"),
// });
//
// exe.root_module.addImport("core", core);
// exe.root_module.addImport("utils", utils);
// exe.root_module.addImport("external", external);
// ANCHOR_END: build_config_pattern

// ANCHOR: module_registry
const ModuleRegistry = struct {
    modules: std.StringHashMap(ModuleInfo),
    allocator: std.mem.Allocator,

    pub const ModuleInfo = struct {
        name: []const u8,
        path: []const u8,
        dependencies: []const []const u8,

        pub fn deinit(self: ModuleInfo, allocator: std.mem.Allocator) void {
            allocator.free(self.name);
            allocator.free(self.path);
            for (self.dependencies) |dep| {
                allocator.free(dep);
            }
            allocator.free(self.dependencies);
        }
    };

    pub fn init(allocator: std.mem.Allocator) ModuleRegistry {
        return .{
            .modules = std.StringHashMap(ModuleInfo).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ModuleRegistry) void {
        var it = self.modules.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
            self.allocator.free(entry.key_ptr.*);
        }
        self.modules.deinit();
    }

    pub fn register(
        self: *ModuleRegistry,
        name: []const u8,
        path: []const u8,
        dependencies: []const []const u8,
    ) !void {
        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);

        const owned_path = try self.allocator.dupe(u8, path);
        errdefer self.allocator.free(owned_path);

        const owned_deps = try self.allocator.alloc([]const u8, dependencies.len);
        errdefer self.allocator.free(owned_deps);

        var i: usize = 0;
        errdefer {
            for (owned_deps[0..i]) |dep| {
                self.allocator.free(dep);
            }
        }
        for (dependencies) |dep| {
            owned_deps[i] = try self.allocator.dupe(u8, dep);
            i += 1;
        }

        const info = ModuleInfo{
            .name = owned_name,
            .path = owned_path,
            .dependencies = owned_deps,
        };

        try self.modules.put(try self.allocator.dupe(u8, name), info);
    }

    pub fn get(self: *const ModuleRegistry, name: []const u8) ?ModuleInfo {
        return self.modules.get(name);
    }
};

test "module registry" {
    var registry = ModuleRegistry.init(testing.allocator);
    defer registry.deinit();

    try registry.register("core", "lib/core/core.zig", &.{});
    try registry.register("utils", "lib/utils/utils.zig", &.{"core"});

    const core = registry.get("core");
    try testing.expect(core != null);
    try testing.expectEqualStrings("lib/core/core.zig", core.?.path);

    const utils = registry.get("utils");
    try testing.expect(utils != null);
    try testing.expectEqual(@as(usize, 1), utils.?.dependencies.len);
}
// ANCHOR_END: module_registry

// ANCHOR: path_resolution
const PathResolver = struct {
    base_paths: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) PathResolver {
        return .{
            .base_paths = std.ArrayList([]const u8){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *PathResolver) void {
        for (self.base_paths.items) |path| {
            self.allocator.free(path);
        }
        self.base_paths.deinit(self.allocator);
    }

    pub fn addPath(self: *PathResolver, path: []const u8) !void {
        const owned_path = try self.allocator.dupe(u8, path);
        try self.base_paths.append(self.allocator, owned_path);
    }

    pub fn resolve(self: *PathResolver, relative_path: []const u8) !?[]u8 {
        // Note: This is a stub implementation for demonstration.
        // Production code should check if file exists using std.fs.cwd().access()
        // before returning the path.
        for (self.base_paths.items) |base| {
            const full_path = try std.fs.path.join(
                self.allocator,
                &.{ base, relative_path },
            );
            // Always returns first path for demonstration purposes
            return full_path;
        }
        return null;
    }
};

test "path resolution" {
    var resolver = PathResolver.init(testing.allocator);
    defer resolver.deinit();

    try resolver.addPath("lib");
    try resolver.addPath("vendor");

    const resolved = try resolver.resolve("core/core.zig");
    try testing.expect(resolved != null);
    defer testing.allocator.free(resolved.?);

    try testing.expect(std.mem.endsWith(u8, resolved.?, "core/core.zig"));
}
// ANCHOR_END: path_resolution

// ANCHOR: dependency_graph
const DependencyGraph = struct {
    nodes: std.StringHashMap(Node),
    allocator: std.mem.Allocator,

    const Node = struct {
        name: []const u8,
        dependencies: std.ArrayList([]const u8),

        pub fn deinit(self: *Node, allocator: std.mem.Allocator) void {
            allocator.free(self.name);
            for (self.dependencies.items) |dep| {
                allocator.free(dep);
            }
            self.dependencies.deinit(allocator);
        }
    };

    pub fn init(allocator: std.mem.Allocator) DependencyGraph {
        return .{
            .nodes = std.StringHashMap(Node).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DependencyGraph) void {
        var it = self.nodes.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(self.allocator);
            self.allocator.free(entry.key_ptr.*);
        }
        self.nodes.deinit();
    }

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
        var visited = std.StringHashMap(bool).init(self.allocator);
        defer visited.deinit();

        var in_path = std.StringHashMap(bool).init(self.allocator);
        defer in_path.deinit();

        var it = self.nodes.iterator();
        while (it.next()) |entry| {
            if (try self.detectCycle(entry.key_ptr.*, &visited, &in_path)) {
                return true;
            }
        }

        return false;
    }

    fn detectCycle(
        self: *DependencyGraph,
        node_name: []const u8,
        visited: *std.StringHashMap(bool),
        in_path: *std.StringHashMap(bool),
    ) !bool {
        if (in_path.get(node_name)) |_| {
            return true; // Cycle detected
        }

        if (visited.get(node_name)) |_| {
            return false; // Already visited
        }

        try visited.put(node_name, true);
        try in_path.put(node_name, true);

        const node = self.nodes.get(node_name) orelse return false;
        for (node.dependencies.items) |dep| {
            if (try self.detectCycle(dep, visited, in_path)) {
                return true;
            }
        }

        _ = in_path.remove(node_name);
        return false;
    }
};

test "dependency graph" {
    var graph = DependencyGraph.init(testing.allocator);
    defer graph.deinit();

    try graph.addNode("main");
    try graph.addNode("utils");
    try graph.addNode("core");

    try graph.addDependency("main", "utils");
    try graph.addDependency("utils", "core");

    const has_cycle = try graph.hasCycle();
    try testing.expect(!has_cycle);
}

test "dependency graph cycle detection" {
    var graph = DependencyGraph.init(testing.allocator);
    defer graph.deinit();

    try graph.addNode("a");
    try graph.addNode("b");
    try graph.addNode("c");

    try graph.addDependency("a", "b");
    try graph.addDependency("b", "c");
    try graph.addDependency("c", "a"); // Creates cycle

    const has_cycle = try graph.hasCycle();
    try testing.expect(has_cycle);
}
// ANCHOR_END: dependency_graph

// ANCHOR: module_loader
const ModuleLoader = struct {
    search_paths: std.ArrayList([]const u8),
    loaded_modules: std.StringHashMap(void),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ModuleLoader {
        return .{
            .search_paths = std.ArrayList([]const u8){},
            .loaded_modules = std.StringHashMap(void).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ModuleLoader) void {
        for (self.search_paths.items) |path| {
            self.allocator.free(path);
        }
        self.search_paths.deinit(self.allocator);

        var it = self.loaded_modules.keyIterator();
        while (it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.loaded_modules.deinit();
    }

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

test "module loader" {
    var loader = ModuleLoader.init(testing.allocator);
    defer loader.deinit();

    try loader.addSearchPath("lib");
    try loader.addSearchPath("vendor");

    try loader.loadModule("core");
    try testing.expect(loader.isLoaded("core"));
    try testing.expect(!loader.isLoaded("utils"));

    try loader.loadModule("utils");
    try testing.expect(loader.isLoaded("utils"));
}
// ANCHOR_END: module_loader

// ANCHOR: project_structure
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

    pub fn deinit(self: *ProjectStructure) void {
        self.allocator.free(self.root);
        self.allocator.free(self.src_dir);
        self.allocator.free(self.lib_dir);
        self.allocator.free(self.vendor_dir);
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

        return std.fs.path.join(
            self.allocator,
            &.{ base, module },
        );
    }
};

test "project structure" {
    var structure = try ProjectStructure.init(testing.allocator, "/project");
    defer structure.deinit();

    const lib_path = try structure.getModulePath("lib", "core.zig");
    defer testing.allocator.free(lib_path);

    try testing.expect(std.mem.endsWith(u8, lib_path, "lib/core.zig"));
}
// ANCHOR_END: project_structure

// ANCHOR: import_validator
const ImportValidator = struct {
    allowed_imports: std.StringHashMap(std.ArrayList([]const u8)),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ImportValidator {
        return .{
            .allowed_imports = std.StringHashMap(std.ArrayList([]const u8)).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ImportValidator) void {
        var it = self.allowed_imports.iterator();
        while (it.next()) |entry| {
            for (entry.value_ptr.items) |item| {
                self.allocator.free(item);
            }
            entry.value_ptr.deinit(self.allocator);
            self.allocator.free(entry.key_ptr.*);
        }
        self.allowed_imports.deinit();
    }

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

test "import validator" {
    var validator = ImportValidator.init(testing.allocator);
    defer validator.deinit();

    try validator.allowImport("main", "core");
    try validator.allowImport("main", "utils");
    try validator.allowImport("utils", "core");

    try testing.expect(validator.canImport("main", "core"));
    try testing.expect(validator.canImport("main", "utils"));
    try testing.expect(!validator.canImport("main", "vendor"));
    try testing.expect(validator.canImport("utils", "core"));
}
// ANCHOR_END: import_validator

// ANCHOR: build_example
// Example build.zig structure for multi-directory projects:
//
// pub fn build(b: *std.Build) void {
//     const target = b.standardTargetOptions(.{});
//     const optimize = b.standardOptimizeOption(.{});
//
//     // Define modules from different directories
//     const core = b.addModule("core", .{
//         .root_source_file = b.path("lib/core/core.zig"),
//     });
//
//     const utils = b.addModule("utils", .{
//         .root_source_file = b.path("lib/utils/utils.zig"),
//         .imports = &.{
//             .{ .name = "core", .module = core },
//         },
//     });
//
//     const external = b.addModule("external", .{
//         .root_source_file = b.path("vendor/external/external.zig"),
//     });
//
//     // Create executable
//     const exe = b.addExecutable(.{
//         .name = "myapp",
//         .root_source_file = b.path("src/main.zig"),
//         .target = target,
//         .optimize = optimize,
//     });
//
//     // Add module imports to executable
//     exe.root_module.addImport("core", core);
//     exe.root_module.addImport("utils", utils);
//     exe.root_module.addImport("external", external);
//
//     b.installArtifact(exe);
// }
// ANCHOR_END: build_example

// Comprehensive test
test "comprehensive build path management" {
    // Module registry
    var registry = ModuleRegistry.init(testing.allocator);
    defer registry.deinit();
    try registry.register("core", "lib/core/core.zig", &.{});

    // Path resolution
    var resolver = PathResolver.init(testing.allocator);
    defer resolver.deinit();
    try resolver.addPath("lib");

    // Dependency graph
    var graph = DependencyGraph.init(testing.allocator);
    defer graph.deinit();
    try graph.addNode("main");
    try graph.addNode("core");
    try graph.addDependency("main", "core");
    try testing.expect(!try graph.hasCycle());

    // Module loader
    var loader = ModuleLoader.init(testing.allocator);
    defer loader.deinit();
    try loader.loadModule("core");
    try testing.expect(loader.isLoaded("core"));
}
