# Recipe 10.8: Reading Datafiles Within a Package

## Problem

You need to include data files (configuration, templates, messages, binary data) with your application and access them reliably at compile-time or runtime.

## Solution

Zig provides `@embedFile` for compile-time embedding of data files directly into your binary, and standard file I/O for runtime access. Each approach has different trade-offs.

### Basic File Embedding

The simplest approach uses `@embedFile` to include file contents at compile time:

```zig
{{#include ../../../code/03-advanced/10-modules-build-system/recipe_10_8.zig:embed_file_basic}}
```

Files are embedded relative to the source file containing the `@embedFile` call.

### Parsing Embedded Configuration

You can parse embedded data at runtime:

```zig
const Config = struct {
    name: []const u8,
    version: []const u8,
    enabled: bool,

    pub fn parseFromEmbedded(allocator: std.mem.Allocator, data: []const u8) !Config {
        var lines = std.mem.tokenizeScalar(u8, data, '\n');

        var name: ?[]const u8 = null;
        var version: ?[]const u8 = null;
        var enabled: ?bool = null;

        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "name=")) {
                const value = line[5..];
                name = try allocator.dupe(u8, value);
            } else if (std.mem.startsWith(u8, line, "version=")) {
                const value = line[8..];
                version = try allocator.dupe(u8, value);
            } else if (std.mem.startsWith(u8, line, "enabled=")) {
                const value = line[8..];
                enabled = std.mem.eql(u8, value, "true");
            }
        }

        return Config{
            .name = name orelse return error.MissingName,
            .version = version orelse return error.MissingVersion,
            .enabled = enabled orelse return error.MissingEnabled,
        };
    }

    pub fn deinit(self: Config, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.version);
    }
};
```

## Discussion

### Embedded vs Runtime File Access

**Compile-Time Embedding (`@embedFile`):**
- Files become part of the binary
- No runtime file I/O needed
- Guaranteed availability (can't be missing)
- Increases binary size
- Changes require recompilation
- Perfect for templates, default configs, small assets

**Runtime File Access:**
- Files stay separate from binary
- Smaller binary size
- Can be updated without recompilation
- Requires file system access
- Files might be missing (need error handling)
- Better for large data, user configs

### Python Comparison

Zig's approach differs significantly from Python's resource handling:

**Python:**
```python
# Using importlib.resources (Python 3.9+)
from importlib.resources import files
import my_package

config = files(my_package).joinpath("data/config.txt").read_text()
```

**Zig:**
```zig
// Compile-time embedding
const config = @embedFile("data/config.txt");

// Or runtime loading
const file = try std.fs.cwd().openFile("data/config.txt", .{});
defer file.close();
const config = try file.readToEndAlloc(allocator, max_size);
defer allocator.free(config);
```

Python's approach is runtime-based and relies on the package structure. Zig offers both compile-time (zero runtime cost) and runtime options.

### Template Substitution Pattern

A common pattern is using embedded templates with variable substitution:

```zig
const Template = struct {
    content: []const u8,

    pub fn init(embedded_data: []const u8) Template {
        return .{ .content = embedded_data };
    }

    pub fn render(
        self: Template,
        allocator: std.mem.Allocator,
        vars: std.StringHashMap([]const u8),
    ) ![]u8 {
        var result = std.ArrayList(u8){};
        errdefer result.deinit(allocator);

        var i: usize = 0;
        while (i < self.content.len) {
            if (i + 1 < self.content.len and
                self.content[i] == '{' and
                self.content[i + 1] == '{') {

                const end = std.mem.indexOfPos(u8, self.content, i + 2, "}}") orelse {
                    return error.UnclosedTemplate;
                };

                const var_name = self.content[i + 2 .. end];
                const value = vars.get(var_name) orelse return error.MissingVariable;
                try result.appendSlice(allocator, value);

                i = end + 2;
            } else {
                try result.append(allocator, self.content[i]);
                i += 1;
            }
        }

        return result.toOwnedSlice(allocator);
    }
};
```

Use it like this:

```zig
const template_content = "Hello {{name}}, version {{version}}!";
const tmpl = Template.init(template_content);

var vars = std.StringHashMap([]const u8).init(allocator);
defer vars.deinit();

try vars.put("name", "World");
try vars.put("version", "1.0");

const rendered = try tmpl.render(allocator, vars);
defer allocator.free(rendered);
// Result: "Hello World, version 1.0!"
```

### Resource Loader Pattern

For flexibility, create a resource loader that supports both approaches:

```zig
const ResourceLoader = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ResourceLoader {
        return .{ .allocator = allocator };
    }

    pub fn loadEmbedded(comptime name: []const u8) []const u8 {
        return @embedFile(name);
    }

    pub fn loadRuntime(self: ResourceLoader, path: []const u8) ![]u8 {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const stat = try file.stat();
        const contents = try file.readToEndAlloc(self.allocator, stat.size);
        return contents;
    }
};
```

### Organizing Multiple Resources

Group related resources using a struct:

```zig
const Resources = struct {
    pub const config = @embedFile("data/sample_config.txt");
    pub const template = @embedFile("data/sample_template.txt");
    pub const messages = @embedFile("data/sample_messages.txt");
};
```

Or use an enum for type-safe access:

```zig
const ResourceType = enum {
    config,
    template,
    messages,

    pub fn getData(self: ResourceType) []const u8 {
        return switch (self) {
            .config => Resources.config,
            .template => Resources.template,
            .messages => Resources.messages,
        };
    }

    pub fn getPath(self: ResourceType) []const u8 {
        return switch (self) {
            .config => "data/sample_config.txt",
            .template => "data/sample_template.txt",
            .messages => "data/sample_messages.txt",
        };
    }
};
```

### Resource Manager with Caching

For more complex applications, implement a resource manager:

```zig
const ResourceManager = struct {
    allocator: std.mem.Allocator,
    cache: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) ResourceManager {
        return .{
            .allocator = allocator,
            .cache = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *ResourceManager) void {
        var it = self.cache.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.cache.deinit();
    }

    pub fn load(self: *ResourceManager, name: []const u8, data: []const u8) !void {
        // Check if key exists and free old data
        if (self.cache.getPtr(name)) |old_value| {
            self.allocator.free(old_value.*);
            const owned_data = try self.allocator.dupe(u8, data);
            old_value.* = owned_data;
        } else {
            const owned_name = try self.allocator.dupe(u8, name);
            const owned_data = try self.allocator.dupe(u8, data);

            self.cache.put(owned_name, owned_data) catch |err| {
                self.allocator.free(owned_name);
                self.allocator.free(owned_data);
                return err;
            };
        }
    }

    pub fn get(self: *ResourceManager, name: []const u8) ?[]const u8 {
        return self.cache.get(name);
    }
};
```

This manager:
- Caches loaded resources
- Handles duplicate keys properly (frees old data)
- Provides error safety with proper cleanup
- Allows updating resources at runtime

### Binary Data Handling

For binary files, use structured access:

```zig
const BinaryResource = struct {
    data: []const u8,

    pub fn init(embedded: []const u8) BinaryResource {
        return .{ .data = embedded };
    }

    pub fn asBytes(self: BinaryResource) []const u8 {
        return self.data;
    }

    pub fn readU32(self: BinaryResource, offset: usize) !u32 {
        if (offset + 4 > self.data.len) {
            return error.OutOfBounds;
        }
        return std.mem.readInt(u32, self.data[offset..][0..4], .little);
    }

    pub fn readString(self: BinaryResource, offset: usize, len: usize) ![]const u8 {
        if (offset + len > self.data.len) {
            return error.OutOfBounds;
        }
        return self.data[offset .. offset + len];
    }
};
```

### Build-Time Information

Combine embedded resources with build metadata:

```zig
pub const build_info = struct {
    pub const version = "1.0.0";
    pub const commit = "abc123def";
    pub const build_date = "2025-01-15";

    pub const embedded_resources = true;
    pub const resource_count = 3;
};
```

This information can be populated by build.zig using the options system.

## Best Practices

1. **Use `@embedFile` for small, static resources** - Templates, default configs, help text
2. **Use runtime loading for large or dynamic data** - User configs, databases, large assets
3. **Always provide error handling** for runtime file access
4. **Cache frequently accessed resources** to avoid repeated I/O
5. **Use relative paths** from the source file for portability
6. **Consider binary size** when embedding many files
7. **Document embedded resources** so users know what's included
8. **Test with missing files** to ensure graceful degradation
9. **Use const for embedded data** since it's read-only
10. **Provide fallback values** for optional configuration files

## Build System Integration

In `build.zig`, you can control resource embedding:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "myapp",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // The data/ directory should be relative to source files
    // No special build configuration needed for @embedFile

    b.installArtifact(exe);
}
```

For runtime file access, consider installing data files:

```zig
// Install data files alongside executable
const install_data = b.addInstallDirectory(.{
    .source_dir = b.path("data"),
    .install_dir = .{ .custom = "share" },
    .install_subdir = "myapp/data",
});

exe.step.dependOn(&install_data.step);
```

## Common Pitfalls

1. **Wrong relative paths** - Paths in `@embedFile` are relative to the source file, not the build root
2. **Missing defer** - Always free runtime-loaded resources
3. **Binary size bloat** - Embedding large files increases executable size significantly
4. **Forgetting error cases** - Runtime file access can fail; handle `FileNotFound` gracefully
5. **Memory leaks in resource managers** - Always free both keys and values in hashmaps
6. **Mutable embedded data** - `@embedFile` returns `[]const u8`; don't try to modify it

## See Also

- Recipe 10.7: Making a Directory or Zip File Runnable - Entry points and packaging
- Recipe 10.9: Adding Directories to the Build Path - Organizing larger projects
- Recipe 10.11: Distributing Packages - Including resources in distributed packages

Full compilable example: `code/03-advanced/10-modules-build-system/recipe_10_8.zig`
