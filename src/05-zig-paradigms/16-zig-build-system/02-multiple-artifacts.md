# Recipe 16.2: Multiple Executables and Libraries

## Problem

You need to build multiple executables and libraries in a single project, with some executables depending on the libraries.

## Solution

Configure multiple artifacts in your `build.zig`:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_2/build.zig:multiple_artifacts}}
```

Build everything:

```bash
zig build                    # Build all artifacts
zig build run-app1           # Run first application
zig build run-app2           # Run second application
```

## Discussion

### Building Static Libraries

Static libraries are linked at compile time:

```zig
const lib = b.addStaticLibrary(.{
    .name = "mylib",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }),
});
b.installArtifact(lib);
```

Output: `zig-out/lib/libmylib.a` (Linux/macOS) or `mylib.lib` (Windows)

### Building Shared Libraries

Shared libraries are loaded at runtime:

```zig
const shared_lib = b.addSharedLibrary(.{
    .name = "shared",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/shared.zig"),
        .target = target,
        .optimize = optimize,
    }),
    .version = .{ .major = 1, .minor = 0, .patch = 0 },
});
b.installArtifact(shared_lib);
```

Output: `libshared.so.1.0.0` (Linux), `libshared.1.0.0.dylib` (macOS), or `shared.dll` (Windows)

### Linking Against Libraries

Executables can link against your libraries:

```zig
const exe = b.addExecutable(.{
    .name = "app",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/app.zig"),
        .target = target,
        .optimize = optimize,
    }),
});
exe.root_module.linkLibrary(lib);  // Link against library
b.installArtifact(exe);
```

In your source code, import the library:

```zig
const mylib = @import("mylib");

pub fn main() !void {
    const result = mylib.add(10, 20);
    std.debug.print("Result: {d}\n", .{result});
}
```

### Multiple Executables

Build several executables from different source files:

```zig
const exe1 = b.addExecutable(.{
    .name = "app1",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/app1.zig"),
        .target = target,
        .optimize = optimize,
    }),
});

const exe2 = b.addExecutable(.{
    .name = "app2",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/app2.zig"),
        .target = target,
        .optimize = optimize,
    }),
});

b.installArtifact(exe1);
b.installArtifact(exe2);
```

### Custom Run Steps

Create named run steps for each executable:

```zig
const run_app1 = b.addRunArtifact(exe1);
const run_app1_step = b.step("run-app1", "Run application 1");
run_app1_step.dependOn(&run_app1.step);

const run_app2 = b.addRunArtifact(exe2);
const run_app2_step = b.step("run-app2", "Run application 2");
run_app2_step.dependOn(&run_app2.step);
```

Usage:

```bash
zig build run-app1
zig build run-app2
```

### Library Versioning

Specify semantic versioning for shared libraries:

```zig
.version = .{ .major = 1, .minor = 2, .patch = 3 }
```

This creates proper symlinks on Unix systems:
- `libmylib.so.1.2.3` (actual file)
- `libmylib.so.1` → `libmylib.so.1.2.3`
- `libmylib.so` → `libmylib.so.1`

### Organizing Multi-Artifact Projects

```
myproject/
├── build.zig
├── src/
│   ├── lib.zig          # Static library
│   ├── shared.zig       # Shared library
│   ├── app1.zig         # First executable
│   └── app2.zig         # Second executable
└── zig-out/
    ├── bin/
    │   ├── app1
    │   └── app2
    └── lib/
        ├── libmylib.a
        └── libshared.so
```

### Library Source Code

A library typically exports public functions:

```zig
// src/lib.zig
const std = @import("std");

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

pub fn multiply(a: i32, b: i32) i32 {
    return a * b;
}

test "library functions" {
    const testing = std.testing;
    try testing.expectEqual(@as(i32, 5), add(2, 3));
}
```

### Executable Using Library

```zig
// src/app.zig
const std = @import("std");
const mylib = @import("mylib");

pub fn main() !void {
    const result = mylib.add(10, 20);
    std.debug.print("10 + 20 = {d}\n", .{result});
}
```

### Static vs Dynamic Linking

**Static Linking:**
- Library code embedded in executable
- Larger executable size
- No runtime dependencies
- Single file to distribute

**Dynamic Linking:**
- Smaller executable size
- Shared library must be present at runtime
- Multiple programs can share one library
- Library can be updated independently

### Installing to Custom Directories

Install artifacts to specific locations:

```zig
const lib_install = b.addInstallArtifact(lib, .{
    .dest_dir = .{ .override = .{ .custom = "mylibs" } },
});
```

### Building Object Files

Sometimes you need just object files:

```zig
const obj = b.addObject(.{
    .name = "myobj",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/obj.zig"),
        .target = target,
        .optimize = optimize,
    }),
});
b.installArtifact(obj);
```

### Conditional Artifact Building

Build different artifacts based on configuration:

```zig
const build_server = b.option(bool, "server", "Build server") orelse true;
const build_client = b.option(bool, "client", "Build client") orelse true;

if (build_server) {
    const server = b.addExecutable(.{
        .name = "server",
        // ...
    });
    b.installArtifact(server);
}

if (build_client) {
    const client = b.addExecutable(.{
        .name = "client",
        // ...
    });
    b.installArtifact(client);
}
```

Usage:

```bash
zig build -Dserver=true -Dclient=false   # Build only server
zig build -Dserver=false -Dclient=true   # Build only client
```

### Best Practices

1. **Organize by artifact type** - Keep executables, libraries separate
2. **Use meaningful names** - Clear artifact and step names
3. **Version shared libraries** - Always specify versions
4. **Create run steps** - One for each executable
5. **Document dependencies** - Comment which exe uses which lib
6. **Test libraries** - Include tests in library source files

## See Also

- Recipe 16.1: Basic build.zig Setup
- Recipe 16.3: Managing Dependencies
- Recipe 16.4: Custom Build Steps

Full example: `code/05-zig-paradigms/16-zig-build-system/recipe_16_2/`
