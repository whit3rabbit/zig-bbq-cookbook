# Projects, Modules, and Dependencies

## Problem

You've been writing small single-file Zig programs. Now you need to organize code across multiple files, import modules, structure a project, and manage dependencies. How does Zig's module system work? What are the standard project layouts? How do you use the build system?

## Solution

Zig provides a straightforward module and build system:

1. **Modules are just structs** - Use `pub` to export functionality
2. **@import loads modules** - Import the standard library or your own files
3. **build.zig configures projects** - Standard build script pattern
4. **build.zig.zon manages dependencies** - Package manifest file

The module system is simple: files are modules, structs are namespaces, and `pub` controls visibility.

## Discussion

### Part 1: Modules and @import

```zig
{{#include ../../code/00-bootcamp/recipe_0_14.zig:modules}}
```

### Part 2: Project Structure and Organization

```zig
{{#include ../../code/00-bootcamp/recipe_0_14.zig:project_structure}}
```

### Part 3: Build System Basics

```zig
{{#include ../../code/00-bootcamp/recipe_0_14.zig:build_system}}
```

### Practical Examples

**Example Module Pattern:**

```zig
test "example module pattern" {
    // A typical module exports a focused API
    const StringUtils = struct {
        pub fn reverse(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
            const result = try allocator.alloc(u8, s.len);
            var i: usize = 0;
            while (i < s.len) : (i += 1) {
                result[i] = s[s.len - 1 - i];
            }
            return result;
        }

        pub fn toUpper(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
            const result = try allocator.dupe(u8, s);
            for (result) |*c| {
                if (c.* >= 'a' and c.* <= 'z') {
                    c.* -= 32;
                }
            }
            return result;
        }
    };

    const reversed = try StringUtils.reverse(testing.allocator, "hello");
    defer testing.allocator.free(reversed);
    try testing.expect(std.mem.eql(u8, "olleh", reversed));

    const upper = try StringUtils.toUpper(testing.allocator, "hello");
    defer testing.allocator.free(upper);
    try testing.expect(std.mem.eql(u8, "HELLO", upper));
}
```

This module provides string utilities with clear, focused functionality.

**Multi-File Project Simulation:**

```zig
test "multi-file project simulation" {
    // Simulate what multiple files would look like

    // File: math.zig
    const Math = struct {
        pub fn add(a: i32, b: i32) i32 {
            return a + b;
        }

        pub fn multiply(a: i32, b: i32) i32 {
            return a * b;
        }
    };

    // File: utils.zig
    const Utils = struct {
        pub fn max(a: i32, b: i32) i32 {
            return if (a > b) a else b;
        }
    };

    // File: main.zig would import these:
    // const math = @import("math.zig");
    // const utils = @import("utils.zig");

    // Using them:
    const sum = Math.add(5, 3);
    const product = Math.multiply(sum, 2);
    const result = Utils.max(product, 100);

    try testing.expectEqual(@as(i32, 100), result);
}
```

**Namespace Organization:**

```zig
test "namespace organization" {
    // Good practice: organize related functionality
    const App = struct {
        pub const models = struct {
            pub const User = struct {
                id: u32,
                name: []const u8,
            };

            pub const Post = struct {
                id: u32,
                title: []const u8,
            };
        };

        pub const services = struct {
            pub fn createUser(id: u32, name: []const u8) models.User {
                return .{ .id = id, .name = name };
            }
        };
    };

    // Clean, hierarchical access:
    const user = App.services.createUser(1, "Alice");
    try testing.expectEqual(@as(u32, 1), user.id);
    try testing.expect(std.mem.eql(u8, "Alice", user.name));
}
```

Nested namespaces create clean, self-documenting code organization.

**Conditional Imports:**

```zig
test "conditional imports" {
    // Can conditionally import based on platform
    const os_module = if (@import("builtin").os.tag == .windows)
        struct {
            pub fn getPath() []const u8 {
                return "C:\\path";
            }
        }
    else
        struct {
            pub fn getPath() []const u8 {
                return "/path";
            }
        };

    const path = os_module.getPath();
    try testing.expect(path.len > 0);
}
```

Use `@import("builtin")` to conditionally select platform-specific code.

### Getting Started with Projects

**Create a new executable project:**
```bash
zig init-exe
```

This generates:
- `build.zig` - Build configuration
- `build.zig.zon` - Package manifest
- `src/main.zig` - Entry point with `pub fn main() !void`

**Create a new library project:**
```bash
zig init-lib
```

This generates:
- `build.zig` - Library build configuration
- `src/root.zig` - Library root module

**Build and run:**
```bash
zig build run
```

**Run tests:**
```bash
zig build test
```

### Common Patterns

**Init pattern for modules:**
```zig
const MyModule = struct {
    data: []const u8,

    pub fn init(data: []const u8) MyModule {
        return .{ .data = data };
    }
};
```

**Exporting library interface:**
```zig
// In src/lib.zig
pub const Parser = @import("parser.zig").Parser;
pub const Lexer = @import("lexer.zig").Lexer;
pub const version = "1.0.0";
```

**Cross-compilation:**
```bash
zig build -Dtarget=x86_64-windows
zig build -Dtarget=aarch64-linux
```

## Summary

- `@import` loads modules (std library or your files)
- Modules are structs with `pub` members
- Use `pub` to export from modules
- Organize code in `src/` directory
- `build.zig` configures your project
- `build.zig.zon` manages dependencies
- `zig build` compiles everything
- `zig fetch` downloads dependencies
- Split code into logical modules
- Use hierarchical namespaces for organization

## See Also

- Recipe 0.7: Functions and the Standard Library - Basic @import usage
- Recipe 0.10: Structs, Enums, and Simple Data Models - Creating types for modules
- Recipe 0.12: Understanding Allocators - Passing allocators through module boundaries

Full compilable example: `code/00-bootcamp/recipe_0_14.zig`
