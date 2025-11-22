// Recipe 10.3: Importing Package Submodules Using Relative Names
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to import submodules using relative paths,
// showing parent-to-child, child-to-parent, and sibling imports.
//
// Package structure:
// recipe_10_3.zig (root)
// ├── core.zig (parent module)
// │   ├── core/logger.zig (child module)
// │   └── core/config.zig (child module, imports sibling logger)
// ├── services.zig (parent module)
//     ├── services/database.zig (child module, imports ../core.zig)
//     └── services/api.zig (child module, imports sibling + parent)

const std = @import("std");
const testing = std.testing;

// ANCHOR: root_imports
// Root module imports top-level submodules
const core = @import("recipe_10_3/core.zig");
const services = @import("recipe_10_3/services.zig");
// ANCHOR_END: root_imports

// ANCHOR: using_imported_modules
// Use modules imported from the package
test "using imported modules" {
    const config = core.Config.init("localhost", 8080);
    try testing.expectEqualStrings("localhost", config.host);
    try testing.expectEqual(@as(u16, 8080), config.port);
}
// ANCHOR_END: using_imported_modules

// ANCHOR: sibling_imports
// Demonstrate modules that import siblings
test "sibling module imports" {
    // config.zig imports logger.zig (both in core/ directory)
    const config = core.config.Config.init("127.0.0.1", 3000);

    // Validation uses logger (sibling import)
    try testing.expect(config.validate());

    // Invalid config uses logger for error
    const bad_config = core.config.Config.init("localhost", 0);
    try testing.expect(!bad_config.validate());
}
// ANCHOR_END: sibling_imports

// ANCHOR: parent_imports
// Demonstrate child importing parent package
test "child to parent imports" {
    const config = core.Config.init("db.example.com", 5432);

    // database.zig imports ../core.zig to access Config and logger
    var db = services.database.Database.init(config);

    try db.connect();
    try testing.expect(db.connected);

    db.disconnect();
    try testing.expect(!db.connected);
}
// ANCHOR_END: parent_imports

// ANCHOR: multiple_relative_imports
// Demonstrate module with multiple relative imports
test "multiple relative imports" {
    const config = core.Config.init("api.example.com", 8080);

    // api.zig imports both database.zig (sibling) and ../core.zig (parent)
    var api = services.api.API.init(config);

    try api.start();
    try testing.expect(api.db.connected);

    api.stop();
    try testing.expect(!api.db.connected);
}
// ANCHOR_END: multiple_relative_imports

// ANCHOR: accessing_through_hierarchy
// Access modules through the import hierarchy
test "accessing through hierarchy" {
    // Can access through parent module
    const config1 = core.Config.init("host1", 1111);
    _ = config1;

    // Or through re-exported type
    const config2 = core.config.Config.init("host2", 2222);
    _ = config2;

    // Both work the same way
    try testing.expect(true);
}
// ANCHOR_END: accessing_through_hierarchy

// ANCHOR: logger_usage
// Use logger from different import paths
test "logger usage from multiple paths" {
    // Access logger through core module
    core.logger.info("Test from core.logger");

    // Access through re-export
    core.logger.debug("Test from re-export");

    // Access log function directly
    core.logger.log(.warn, "Warning message");

    try testing.expect(true);
}
// ANCHOR_END: logger_usage

// ANCHOR: reexported_types
// Use re-exported types from parent modules
test "re-exported types" {
    // Use re-exported Config type
    const config: core.Config = .{
        .host = "localhost",
        .port = 8080,
    };
    try testing.expectEqualStrings("localhost", config.host);

    // Use re-exported LogLevel enum
    const level: core.LogLevel = .info;
    try testing.expectEqual(core.LogLevel.info, level);
}
// ANCHOR_END: reexported_types

// ANCHOR: cross_package_communication
// Demonstrate communication between different package sections
test "cross-package communication" {
    // Core provides configuration
    const config = core.Config.init("myapp.local", 9000);

    // Services use core configuration
    const db = services.Database.init(config);
    const api = services.API.init(config);

    // Both services share the same config
    try testing.expectEqualStrings(db.config.host, api.db.config.host);
    try testing.expectEqual(db.config.port, api.db.config.port);
}
// ANCHOR_END: cross_package_communication

// ANCHOR: import_patterns
// Different import patterns demonstrated
const ImportPatterns = struct {
    // Pattern 1: Direct child import (parent → child)
    // In core.zig: @import("core/logger.zig")

    // Pattern 2: Sibling import (child → sibling)
    // In core/config.zig: @import("logger.zig")

    // Pattern 3: Parent import (child → parent)
    // In services/database.zig: @import("../core.zig")

    // Pattern 4: Complex relative (child → sibling + parent)
    // In services/api.zig: @import("database.zig") and @import("../core.zig")
};

test "import pattern documentation" {
    _ = ImportPatterns;
    try testing.expect(true);
}
// ANCHOR_END: import_patterns

// ANCHOR: relative_path_rules
// Demonstrate relative path rules
test "relative path rules" {
    // Rule 1: Paths are relative to the importing file
    // core.zig imports "core/logger.zig" (child in subdirectory)

    // Rule 2: Use ".." to go up one directory level
    // services/database.zig imports "../core.zig" (parent directory)

    // Rule 3: Sibling imports use just the filename
    // core/config.zig imports "logger.zig" (same directory)

    // Rule 4: Can chain ".." to go up multiple levels
    // (Not demonstrated here, but "../../module.zig" would work)

    try testing.expect(true);
}
// ANCHOR_END: relative_path_rules

// ANCHOR: package_organization_benefits
// Benefits of relative imports
test "package organization benefits" {
    // Benefit 1: Clear module relationships
    const config = core.Config.init("localhost", 8080);

    // Benefit 2: Self-contained packages
    const db = services.Database.init(config);

    // Benefit 3: Easy refactoring (move modules together)
    const api = services.API.init(config);

    // Benefit 4: No global namespace pollution
    // Each module explicitly declares its dependencies
    try testing.expectEqualStrings(config.host, db.config.host);
    try testing.expectEqualStrings(config.host, api.db.config.host);
}
// ANCHOR_END: package_organization_benefits

// ANCHOR: avoiding_circular_imports
// Avoid circular dependencies with proper layering
test "avoiding circular imports" {
    // Good: Layered architecture
    // core/ (foundation layer) - no dependencies on services/
    // services/ (application layer) - depends on core/

    // Core modules don't import services
    const config = core.Config.init("localhost", 8080);

    // Services import core (one-way dependency)
    const db = services.Database.init(config);

    // This creates a clear dependency hierarchy
    try testing.expectEqualStrings(config.host, db.config.host);
}
// ANCHOR_END: avoiding_circular_imports

// Comprehensive test
test "comprehensive relative imports" {
    // Use core modules
    const config = core.Config.init("comprehensive.test", 8080);
    try testing.expect(config.validate());

    // Use services that import core
    var db = services.Database.init(config);
    try db.connect();
    try testing.expect(db.connected);

    // Use API that imports both services and core
    var api = services.API.init(config);
    try api.start();
    try testing.expect(api.db.connected);

    // Cleanup
    api.stop();
    try testing.expect(!api.db.connected);

    try testing.expect(true);
}
