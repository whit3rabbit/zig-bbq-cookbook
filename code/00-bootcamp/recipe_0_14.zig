// Recipe 0.14: Projects, Modules, and Dependencies
// Target Zig Version: 0.15.2
//
// This recipe covers project structure, modules, and the build system.

const std = @import("std");
const testing = std.testing;

// ANCHOR: modules
// Part 1: Modules and @import
//
// Zig uses @import to load code from other files

test "importing std library" {
    // @import("std") loads the standard library
    // It returns a struct containing all std modules

    // Access modules through the std namespace
    _ = std.ArrayList;
    _ = std.HashMap;
    _ = std.mem;
    _ = std.testing;
    _ = std.io;
}

test "module structure" {
    // Modules are just structs
    // They can contain:
    // - Functions
    // - Types (structs, enums, unions)
    // - Constants
    // - Other modules (nested)

    const MyModule = struct {
        // Public function
        pub fn greet(name: []const u8) void {
            std.debug.print("Hello, {s}!\n", .{name});
        }

        // Public type
        pub const Config = struct {
            debug: bool = false,
        };

        // Public constant
        pub const VERSION = "1.0.0";

        // Nested module
        pub const utils = struct {
            pub fn add(a: i32, b: i32) i32 {
                return a + b;
            }
        };
    };

    // Use the module
    MyModule.greet("Zig");
    const config = MyModule.Config{};
    try testing.expectEqual(false, config.debug);
    try testing.expect(std.mem.eql(u8, MyModule.VERSION, "1.0.0"));
    try testing.expectEqual(@as(i32, 5), MyModule.utils.add(2, 3));
}

test "public vs private in modules" {
    const MyModule = struct {
        // Public - visible when imported
        pub fn publicFunction() i32 {
            return 42;
        }

        // Private - only visible within this module
        fn privateHelper() i32 {
            return 10;
        }

        pub fn usesPrivate() i32 {
            return privateHelper() * 2;
        }
    };

    // Can call public functions
    try testing.expectEqual(@as(i32, 42), MyModule.publicFunction());
    try testing.expectEqual(@as(i32, 20), MyModule.usesPrivate());

    // Cannot call private functions from outside:
    // const x = MyModule.privateHelper();  // error
}
// ANCHOR_END: modules

// ANCHOR: project_structure
// Part 2: Project Structure and Organization
//
// Typical Zig project layout

test "typical project structure" {
    // A typical Zig project looks like:
    //
    // my-project/
    //   build.zig          - Build configuration
    //   build.zig.zon      - Package dependencies
    //   src/
    //     main.zig         - Entry point
    //     lib.zig          - Library root (optional)
    //     module1.zig      - Module files
    //     module2.zig
    //   tests/
    //     tests.zig        - Integration tests

    // Files are modules - use @import to load them
    // @import("./module.zig") loads a file
    // @import("module") loads from build.zig modules

    try testing.expect(true); // This test just documents structure
}

test "file organization patterns" {
    // Pattern 1: Monolithic - everything in one file
    // Good for: Small projects, prototypes

    // Pattern 2: Modular - split by functionality
    // src/
    //   parser.zig
    //   lexer.zig
    //   ast.zig
    //   main.zig

    // Pattern 3: Hierarchical - nested modules
    // src/
    //   frontend/
    //     lexer.zig
    //     parser.zig
    //   backend/
    //     codegen.zig
    //     optimizer.zig

    // Import from subdirectories:
    // const lexer = @import("frontend/lexer.zig");

    try testing.expect(true); // Documentation test
}
// ANCHOR_END: project_structure

// ANCHOR: build_system
// Part 3: Build System Basics
//
// Understanding build.zig

test "build system concepts" {
    // build.zig is a Zig program that builds your project
    // It runs at build time (before compiling your code)

    // Key concepts:
    // - Build steps: compile, test, run, install
    // - Dependencies: link libraries, add modules
    // - Options: build configurations
    // - Cross-compilation: different targets

    // Common build.zig pattern:
    // pub fn build(b: *std.Build) void {
    //     const target = b.standardTargetOptions(.{});
    //     const optimize = b.standardOptimizeOption(.{});
    //
    //     const exe = b.addExecutable(.{
    //         .name = "my-app",
    //         .root_source_file = b.path("src/main.zig"),
    //         .target = target,
    //         .optimize = optimize,
    //     });
    //
    //     b.installArtifact(exe);
    // }

    try testing.expect(true); // Documentation test
}

test "common build commands" {
    // zig init-exe          - Create executable project
    // zig init-lib          - Create library project
    // zig build             - Build the project
    // zig build run         - Build and run
    // zig build test        - Run tests
    // zig build install     - Install to zig-out/
    // zig build -Doptimize=ReleaseFast  - Release build

    try testing.expect(true); // Documentation test
}

test "dependency management" {
    // build.zig.zon - Package manifest file
    // .{
    //     .name = "my-project",
    //     .version = "0.1.0",
    //     .dependencies = .{
    //         .some_lib = .{
    //             .url = "https://github.com/user/lib/archive/v1.0.tar.gz",
    //             .hash = "1220...",
    //         },
    //     },
    // }

    // zig fetch - Download and cache dependency

    // In build.zig, add the dependency:
    // const some_lib = b.dependency("some_lib", .{});
    // exe.root_module.addImport("some_lib", some_lib.module("some_lib"));

    // In your code:
    // const some_lib = @import("some_lib");

    try testing.expect(true); // Documentation test
}
// ANCHOR_END: build_system

// Practical examples

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

// Summary:
// - @import loads modules (std library or your files)
// - Modules are structs with pub members
// - Use pub to export from modules
// - Organize code in src/ directory
// - build.zig configures your project
// - build.zig.zon manages dependencies
// - zig build compiles everything
// - zig fetch downloads dependencies
// - Split code into logical modules
// - Use hierarchical namespaces
