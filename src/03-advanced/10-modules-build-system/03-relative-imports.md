## Problem

You need to import modules using relative paths within your package. You want siblings to import each other, child modules to access parent functionality, and a clear dependency hierarchy. You need to avoid absolute paths that make refactoring difficult.

## Solution

Use relative paths with `@import()` to reference modules based on their position in the file system. Import children with `directory/file.zig`, siblings with `file.zig`, and parents with `../file.zig`. Organize your package into logical layers to prevent circular dependencies.

### Package Structure

Create a hierarchical module organization:

```
recipe_10_3/
├── core.zig (parent module)
│   ├── core/logger.zig (utility)
│   └── core/config.zig (uses logger)
└── services.zig (parent module)
    ├── services/database.zig (uses core)
    └── services/api.zig (uses database + core)
```

### Root Imports

Import top-level modules from your main file:

```zig
{{#include ../../../code/03-advanced/10-modules-build-system/recipe_10_3.zig:root_imports}}
```

Paths are relative to your project root or build configuration.

### Using Imported Modules

Access functionality from imported modules:

```zig
test "using imported modules" {
    const config = core.Config.init("localhost", 8080);
    try testing.expectEqualStrings("localhost", config.host);
    try testing.expectEqual(@as(u16, 8080), config.port);
}
```

The `core` module exposes its types and functions.

## Discussion

### Sibling Imports

Modules in the same directory import each other using just the filename:

```zig
// In core/config.zig
const std = @import("std");

// Import sibling module using relative path
const logger = @import("logger.zig");

pub const Config = struct {
    host: []const u8,
    port: u16,

    pub fn init(host: []const u8, port: u16) Config {
        logger.info("Initializing configuration");
        return .{
            .host = host,
            .port = port,
        };
    }

    pub fn validate(self: *const Config) bool {
        if (self.port == 0) {
            logger.log(.err, "Invalid port: 0");
            return false;
        }
        logger.debug("Configuration validated");
        return true;
    }
};
```

The `config` module imports `logger` from the same directory using `@import("logger.zig")`.

Test sibling imports:

```zig
test "sibling module imports" {
    // config.zig imports logger.zig (both in core/ directory)
    const config = core.config.Config.init("127.0.0.1", 3000);

    // Validation uses logger (sibling import)
    try testing.expect(config.validate());

    // Invalid config uses logger for error
    const bad_config = core.config.Config.init("localhost", 0);
    try testing.expect(!bad_config.validate());
}
```

### Parent-to-Child Imports

Parent modules import children using directory paths:

```zig
// In core.zig
const std = @import("std");

// Import child modules from subdirectory
pub const logger = @import("core/logger.zig");
pub const config = @import("core/config.zig");

// Re-export commonly used types
pub const Config = config.Config;
pub const LogLevel = logger.Level;
```

The parent `core.zig` imports modules from the `core/` subdirectory.

### Child-to-Parent Imports

Child modules access parent packages using `../`:

```zig
// In services/database.zig
const std = @import("std");

// Import from parent package using relative path
const core = @import("../core.zig");

pub const Database = struct {
    config: core.Config,
    connected: bool,

    pub fn init(config: core.Config) Database {
        core.logger.info("Database initialized");
        return .{
            .config = config,
            .connected = false,
        };
    }

    pub fn connect(self: *Database) !void {
        if (!self.config.validate()) {
            return error.InvalidConfig;
        }
        self.connected = true;
        core.logger.info("Database connected");
    }

    pub fn disconnect(self: *Database) void {
        self.connected = false;
        core.logger.info("Database disconnected");
    }
};
```

The `database` module uses `../core.zig` to access the parent package.

Test child-to-parent imports:

```zig
test "child to parent imports" {
    const config = core.Config.init("db.example.com", 5432);

    // database.zig imports ../core.zig to access Config and logger
    var db = services.database.Database.init(config);

    try db.connect();
    try testing.expect(db.connected);

    db.disconnect();
    try testing.expect(!db.connected);
}
```

### Multiple Relative Imports

Modules can import both siblings and parents:

```zig
// In services/api.zig
const std = @import("std");

// Import sibling module
const database = @import("database.zig");

// Import from parent package
const core = @import("../core.zig");

pub const API = struct {
    db: database.Database,

    pub fn init(config: core.Config) API {
        core.logger.info("API initialized");
        return .{
            .db = database.Database.init(config),
        };
    }

    pub fn start(self: *API) !void {
        try self.db.connect();
        core.logger.info("API started");
    }

    pub fn stop(self: *API) void {
        self.db.disconnect();
        core.logger.info("API stopped");
    }
};
```

The `api` module imports both `database.zig` (sibling) and `../core.zig` (parent).

Test multiple imports:

```zig
test "multiple relative imports" {
    const config = core.Config.init("api.example.com", 8080);

    // api.zig imports both database.zig (sibling) and ../core.zig (parent)
    var api = services.api.API.init(config);

    try api.start();
    try testing.expect(api.db.connected);

    api.stop();
    try testing.expect(!api.db.connected);
}
```

### Accessing Through Hierarchy

Access modules either directly or through re-exports:

```zig
test "accessing through hierarchy" {
    // Can access through parent module
    const config1 = core.Config.init("host1", 1111);

    // Or through re-exported type
    const config2 = core.config.Config.init("host2", 2222);

    // Both work the same way
    try testing.expect(true);
}
```

Re-exports in `core.zig` provide convenient shortcuts.

### Re-Exported Types

Parent modules re-export types for convenience:

```zig
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
```

Users can choose between `core.Config` (re-export) or `core.config.Config` (full path).

### Cross-Package Communication

Different package sections communicate through shared modules:

```zig
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
```

The `core` package provides shared types and utilities used by `services`.

### Relative Path Rules

Follow these rules for relative imports:

**Rule 1: Paths are relative to the importing file**
```zig
// In core.zig
@import("core/logger.zig")  // Child in subdirectory
```

**Rule 2: Use ".." to go up one directory level**
```zig
// In services/database.zig
@import("../core.zig")  // Parent directory
```

**Rule 3: Sibling imports use just the filename**
```zig
// In core/config.zig
@import("logger.zig")  // Same directory
```

**Rule 4: Can chain ".." to go up multiple levels**
```zig
@import("../../module.zig")  // Two levels up
```

### Import Pattern Summary

| Pattern | Example Path | Use Case |
|---------|-------------|----------|
| Root → Child | `@import("pkg/module.zig")` | Main imports package |
| Parent → Child | `@import("dir/file.zig")` | Aggregator imports submodules |
| Sibling → Sibling | `@import("sibling.zig")` | Same directory imports |
| Child → Parent | `@import("../parent.zig")` | Access package utilities |
| Multi-level | `@import("../../file.zig")` | Deep hierarchy navigation |

### Avoiding Circular Dependencies

Organize modules into layers to prevent circular imports:

```zig
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
```

Dependencies flow in one direction: `services` → `core`, never the reverse.

### Package Organization Benefits

Relative imports provide several advantages:

**Clear module relationships:**
- Dependencies are explicit in import statements
- Easy to see which modules depend on others
- Refactoring updates are localized

**Self-contained packages:**
- Modules can be moved as a group
- Relative paths remain valid
- No global namespace concerns

**Easy refactoring:**
- Move entire directories without updating imports
- Rename packages without breaking internal imports
- Reorganize structure with minimal changes

**No global namespace pollution:**
- Each module declares dependencies explicitly
- No hidden or implicit imports
- Clear separation of concerns

### Best Practices

**Use Layered Architecture:**
```
foundation/ (no external dependencies)
    ├── core utilities
    └── shared types
application/ (depends on foundation)
    ├── business logic
    └── services
```

**Keep Imports at Top:**
```zig
const std = @import("std");
const core = @import("../core.zig");
const sibling = @import("sibling.zig");

// Then your code
```

**Avoid Deep Hierarchies:**
- Limit nesting to 2-3 levels
- Use aggregator modules for deep trees
- Consider flattening if paths get complex

**Document Dependencies:**
```zig
// Import from core utilities layer
const logger = @import("../core/logger.zig");

// Import sibling service
const database = @import("database.zig");
```

**Group Related Modules:**
```
services/
    ├── database.zig
    ├── api.zig
    └── cache.zig
```

### Common Patterns

**Utility Layer:**
```
core/
    ├── logger.zig (logging)
    ├── config.zig (configuration)
    └── errors.zig (error types)
```

**Service Layer:**
```
services/
    ├── database.zig (imports core)
    ├── api.zig (imports database + core)
    └── worker.zig (imports core)
```

**Feature Modules:**
```
features/
    ├── auth/ (authentication)
    │   ├── auth.zig
    │   └── auth/providers.zig
    └── users/ (user management)
        ├── users.zig
        └── users/repository.zig
```

### Preventing Common Mistakes

**Don't use absolute paths when relative works:**
```zig
// Bad: hardcoded absolute path
const logger = @import("myapp/core/logger.zig");

// Good: relative path
const logger = @import("../core/logger.zig");
```

**Don't create circular dependencies:**
```zig
// Bad: A imports B, B imports A
// a.zig: const b = @import("b.zig");
// b.zig: const a = @import("a.zig"); // Circular!

// Good: Extract shared code to C
// a.zig: const c = @import("c.zig");
// b.zig: const c = @import("c.zig");
```

**Don't nest too deeply:**
```zig
// Bad: too many levels
@import("../../../../shared/utils.zig")

// Good: restructure or use aggregator
@import("../shared.zig")
```

### Working with Build System

In `build.zig`, configure module paths:

```zig
const exe = b.addExecutable(.{
    .name = "myapp",
    .root_source_file = b.path("src/main.zig"),
});

// Modules can now import relative to src/
```

The build system resolves import paths relative to the root source file.

### Testing Module Imports

Test that imports work correctly:

```zig
test "module imports compile" {
    // Simply importing tests the import path
    _ = @import("core.zig");
    _ = @import("services.zig");
}

test "module functionality" {
    // Test actual behavior
    const config = core.Config.init("test", 8080);
    try testing.expect(config.validate());
}
```

### Refactoring with Relative Imports

When restructuring code:

1. **Move related modules together** - Relative imports update automatically
2. **Keep import paths short** - Minimize `../` usage
3. **Test after moving** - Verify imports still resolve
4. **Update parent aggregators** - Adjust re-exports if needed

### Import Resolution

Zig resolves imports in this order:

1. Check for standard library (`std`)
2. Check build system packages
3. Resolve relative to importing file
4. Report error if not found

Relative paths always resolve from the current file's location.

## See Also

- Recipe 10.1: Making a hierarchical package of modules
- Recipe 10.4: Splitting a module into multiple files
- Recipe 10.5: Making separate directories of code import under a common namespace

Full compilable example: `code/03-advanced/10-modules-build-system/recipe_10_3.zig`
