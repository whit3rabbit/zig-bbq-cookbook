const std = @import("std");
const testing = std.testing;

// This file demonstrates dependency management concepts

// ANCHOR: dependency_info
// Dependency information structure
pub const DependencyInfo = struct {
    name: []const u8,
    version: []const u8,
    url: []const u8,
    hash: []const u8,

    pub fn init(name: []const u8, version: []const u8, url: []const u8, hash: []const u8) DependencyInfo {
        return .{
            .name = name,
            .version = version,
            .url = url,
            .hash = hash,
        };
    }

    pub fn isValid(self: DependencyInfo) bool {
        return self.name.len > 0 and self.hash.len == 68; // SHA256 hash length with prefix
    }
};

test "dependency info" {
    const dep = DependencyInfo.init(
        "mylib",
        "1.0.0",
        "https://example.com/mylib.tar.gz",
        "12200000000000000000000000000000000000000000000000000000000000000000",
    );
    try testing.expect(dep.isValid());
    try testing.expect(std.mem.eql(u8, dep.name, "mylib"));
}
// ANCHOR_END: dependency_info

// ANCHOR: version_constraint
// Version constraint handling
pub const VersionConstraint = struct {
    minimum: []const u8,
    maximum: ?[]const u8,

    pub fn init(minimum: []const u8, maximum: ?[]const u8) VersionConstraint {
        return .{
            .minimum = minimum,
            .maximum = maximum,
        };
    }

    pub fn hasMaximum(self: VersionConstraint) bool {
        return self.maximum != null;
    }
};

test "version constraints" {
    const constraint = VersionConstraint.init("1.0.0", "2.0.0");
    try testing.expect(constraint.hasMaximum());
    try testing.expect(std.mem.eql(u8, constraint.minimum, "1.0.0"));
}
// ANCHOR_END: version_constraint

// ANCHOR: module_import
// Module import configuration
pub const ModuleImport = struct {
    name: []const u8,
    dependency_name: []const u8,

    pub fn init(name: []const u8, dependency_name: []const u8) ModuleImport {
        return .{
            .name = name,
            .dependency_name = dependency_name,
        };
    }

    pub fn matches(self: ModuleImport, dep_name: []const u8) bool {
        return std.mem.eql(u8, self.dependency_name, dep_name);
    }
};

test "module imports" {
    const import = ModuleImport.init("mylib", "my-dependency");
    try testing.expect(import.matches("my-dependency"));
    try testing.expect(!import.matches("other-dependency"));
}
// ANCHOR_END: module_import

// ANCHOR: dependency_graph
// Simple dependency graph representation
pub const DependencyNode = struct {
    name: []const u8,
    dependencies: []const []const u8,

    pub fn init(name: []const u8, dependencies: []const []const u8) DependencyNode {
        return .{
            .name = name,
            .dependencies = dependencies,
        };
    }

    pub fn dependsOn(self: DependencyNode, dep_name: []const u8) bool {
        for (self.dependencies) |dep| {
            if (std.mem.eql(u8, dep, dep_name)) return true;
        }
        return false;
    }

    pub fn dependencyCount(self: DependencyNode) usize {
        return self.dependencies.len;
    }
};

test "dependency graph" {
    const deps = [_][]const u8{ "dep1", "dep2", "dep3" };
    const node = DependencyNode.init("myproject", &deps);

    try testing.expectEqual(@as(usize, 3), node.dependencyCount());
    try testing.expect(node.dependsOn("dep1"));
    try testing.expect(!node.dependsOn("dep4"));
}
// ANCHOR_END: dependency_graph

// ANCHOR: local_dependency
// Local dependency (path-based)
pub const LocalDependency = struct {
    name: []const u8,
    path: []const u8,

    pub fn init(name: []const u8, path: []const u8) LocalDependency {
        return .{
            .name = name,
            .path = path,
        };
    }

    pub fn isRelative(self: LocalDependency) bool {
        return !std.fs.path.isAbsolute(self.path);
    }
};

test "local dependencies" {
    const dep = LocalDependency.init("mylib", "../mylib");
    try testing.expect(dep.isRelative());

    const abs_dep = LocalDependency.init("other", "/usr/local/lib/other");
    try testing.expect(!abs_dep.isRelative());
}
// ANCHOR_END: local_dependency

// ANCHOR: dependency_options
// Options passed to dependencies
pub const DependencyOptions = struct {
    optimize: std.builtin.OptimizeMode,
    target: ?[]const u8,
    features: []const []const u8,

    pub fn init(optimize: std.builtin.OptimizeMode) DependencyOptions {
        return .{
            .optimize = optimize,
            .target = null,
            .features = &[_][]const u8{},
        };
    }

    pub fn hasFeatures(self: DependencyOptions) bool {
        return self.features.len > 0;
    }

    pub fn hasTarget(self: DependencyOptions) bool {
        return self.target != null;
    }
};

test "dependency options" {
    const options = DependencyOptions.init(.ReleaseFast);
    try testing.expectEqual(std.builtin.OptimizeMode.ReleaseFast, options.optimize);
    try testing.expect(!options.hasFeatures());
    try testing.expect(!options.hasTarget());
}
// ANCHOR_END: dependency_options

// ANCHOR: hash_verification
// Hash verification for dependencies
pub const DependencyHash = struct {
    algorithm: []const u8,
    value: []const u8,

    pub fn init(algorithm: []const u8, value: []const u8) DependencyHash {
        return .{
            .algorithm = algorithm,
            .value = value,
        };
    }

    pub fn isSHA256(self: DependencyHash) bool {
        return std.mem.eql(u8, self.algorithm, "sha256");
    }

    pub fn isValid(self: DependencyHash) bool {
        if (self.isSHA256()) {
            // SHA256 hash with "1220" prefix is 68 characters
            return self.value.len == 68;
        }
        return false;
    }
};

test "hash verification" {
    const hash = DependencyHash.init("sha256", "12200000000000000000000000000000000000000000000000000000000000000000");
    try testing.expect(hash.isSHA256());
    try testing.expect(hash.isValid());
}
// ANCHOR_END: hash_verification

// ANCHOR: transitive_dependencies
// Managing transitive dependencies
pub const DependencyTree = struct {
    root: []const u8,
    direct: []const []const u8,
    transitive: []const []const u8,

    pub fn init(root: []const u8, direct: []const []const u8, transitive: []const []const u8) DependencyTree {
        return .{
            .root = root,
            .direct = direct,
            .transitive = transitive,
        };
    }

    pub fn totalDependencies(self: DependencyTree) usize {
        return self.direct.len + self.transitive.len;
    }

    pub fn isDirect(self: DependencyTree, name: []const u8) bool {
        for (self.direct) |dep| {
            if (std.mem.eql(u8, dep, name)) return true;
        }
        return false;
    }
};

test "transitive dependencies" {
    const direct = [_][]const u8{ "dep1", "dep2" };
    const transitive = [_][]const u8{ "dep3", "dep4", "dep5" };
    const tree = DependencyTree.init("myproject", &direct, &transitive);

    try testing.expectEqual(@as(usize, 5), tree.totalDependencies());
    try testing.expect(tree.isDirect("dep1"));
    try testing.expect(!tree.isDirect("dep3"));
}
// ANCHOR_END: transitive_dependencies
