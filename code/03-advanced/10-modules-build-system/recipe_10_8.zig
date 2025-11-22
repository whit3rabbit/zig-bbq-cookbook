// Recipe 10.8: Reading Datafiles Within a Package
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to access data files packaged with your code.
// Unlike Python's importlib.resources or pkg_resources, Zig provides compile-time
// embedding via @embedFile and runtime file access.
//
// Key concepts:
// - Using @embedFile for compile-time data embedding
// - Runtime file access relative to executable
// - Build system integration for data files
// - Handling different deployment scenarios
//
// Package structure:
// recipe_10_8/
// ├── build.zig
// ├── src/
// │   └── main.zig
// └── data/
//     ├── config.json
//     ├── template.txt
//     └── messages.txt

const std = @import("std");
const testing = std.testing;

// ANCHOR: embed_file_basic
// Embed a file at compile time - contents become part of the binary
pub const config_data = @embedFile("data/sample_config.txt");
pub const template_data = @embedFile("data/sample_template.txt");

test "embed file basic usage" {
    // Embedded file is a null-terminated string constant
    try testing.expect(config_data.len > 0);
    try testing.expect(template_data.len > 0);
}
// ANCHOR_END: embed_file_basic

// ANCHOR: embed_file_parsing
const Config = struct {
    name: []const u8,
    version: []const u8,
    enabled: bool,

    pub fn parseFromEmbedded(allocator: std.mem.Allocator, data: []const u8) !Config {
        // Simple parser for demonstration
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

test "parse embedded config" {
    const sample_config =
        \\name=MyApp
        \\version=1.0.0
        \\enabled=true
    ;

    const config = try Config.parseFromEmbedded(testing.allocator, sample_config);
    defer config.deinit(testing.allocator);

    try testing.expectEqualStrings("MyApp", config.name);
    try testing.expectEqualStrings("1.0.0", config.version);
    try testing.expect(config.enabled);
}
// ANCHOR_END: embed_file_parsing

// ANCHOR: template_substitution
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
            if (i + 1 < self.content.len and self.content[i] == '{' and self.content[i + 1] == '{') {
                // Find closing }}
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

test "template substitution" {
    const template_content = "Hello {{name}}, version {{version}}!";
    const tmpl = Template.init(template_content);

    var vars = std.StringHashMap([]const u8).init(testing.allocator);
    defer vars.deinit();

    try vars.put("name", "World");
    try vars.put("version", "1.0");

    const rendered = try tmpl.render(testing.allocator, vars);
    defer testing.allocator.free(rendered);

    try testing.expectEqualStrings("Hello World, version 1.0!", rendered);
}
// ANCHOR_END: template_substitution

// ANCHOR: resource_loader
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

test "resource loader embedded" {
    const data = ResourceLoader.loadEmbedded("data/sample_config.txt");
    try testing.expect(data.len > 0);
}
// ANCHOR_END: resource_loader

// ANCHOR: multi_resource_pattern
const Resources = struct {
    pub const config = @embedFile("data/sample_config.txt");
    pub const template = @embedFile("data/sample_template.txt");
    pub const messages = @embedFile("data/sample_messages.txt");
};

test "multi resource pattern" {
    try testing.expect(Resources.config.len > 0);
    try testing.expect(Resources.template.len > 0);
    try testing.expect(Resources.messages.len > 0);
}
// ANCHOR_END: multi_resource_pattern

// ANCHOR: resource_enum
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

test "resource enum" {
    const config_data_enum = ResourceType.config.getData();
    try testing.expect(config_data_enum.len > 0);
    try testing.expectEqualStrings("data/sample_config.txt", ResourceType.config.getPath());
}
// ANCHOR_END: resource_enum

// ANCHOR: lazy_resource_loading
const LazyResource = struct {
    data: ?[]const u8,
    embedded: []const u8,

    pub fn init(comptime embedded_data: []const u8) LazyResource {
        return .{
            .data = null,
            .embedded = embedded_data,
        };
    }

    pub fn get(self: *LazyResource) []const u8 {
        if (self.data) |d| {
            return d;
        }
        self.data = self.embedded;
        return self.embedded;
    }
};

test "lazy resource loading" {
    var resource = LazyResource.init("embedded content");

    try testing.expect(resource.data == null);

    const data1 = resource.get();
    try testing.expectEqualStrings("embedded content", data1);
    try testing.expect(resource.data != null);

    const data2 = resource.get();
    try testing.expectEqualStrings("embedded content", data2);
}
// ANCHOR_END: lazy_resource_loading

// ANCHOR: versioned_resources
const VersionedResources = struct {
    pub fn getConfigV1() []const u8 {
        return @embedFile("data/sample_config.txt");
    }

    pub fn getConfigV2() []const u8 {
        return @embedFile("data/sample_template.txt");
    }

    pub fn getConfigV3() []const u8 {
        return @embedFile("data/sample_messages.txt");
    }
};

test "versioned resources" {
    const v1_config = VersionedResources.getConfigV1();
    const v2_config = VersionedResources.getConfigV2();
    const v3_config = VersionedResources.getConfigV3();

    try testing.expect(v1_config.len > 0);
    try testing.expect(v2_config.len > 0);
    try testing.expect(v3_config.len > 0);
}
// ANCHOR_END: versioned_resources

// ANCHOR: resource_manager
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

test "resource manager" {
    var manager = ResourceManager.init(testing.allocator);
    defer manager.deinit();

    try manager.load("config", "config_data");
    try manager.load("template", "template_data");

    const config = manager.get("config");
    try testing.expect(config != null);
    try testing.expectEqualStrings("config_data", config.?);

    const missing = manager.get("missing");
    try testing.expect(missing == null);

    // Test updating existing resource (replaces old value)
    try manager.load("config", "updated_config_data");
    const updated = manager.get("config");
    try testing.expect(updated != null);
    try testing.expectEqualStrings("updated_config_data", updated.?);
}
// ANCHOR_END: resource_manager

// ANCHOR: binary_data_handling
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

test "binary data handling" {
    const binary_data = "\x01\x02\x03\x04Hello";
    const resource = BinaryResource.init(binary_data);

    const value = try resource.readU32(0);
    try testing.expectEqual(@as(u32, 0x04030201), value);

    const str = try resource.readString(4, 5);
    try testing.expectEqualStrings("Hello", str);

    const out_of_bounds = resource.readU32(100);
    try testing.expectError(error.OutOfBounds, out_of_bounds);
}
// ANCHOR_END: binary_data_handling

// ANCHOR: build_info_pattern
pub const build_info = struct {
    pub const version = "1.0.0";
    pub const commit = "abc123def";
    pub const build_date = "2025-01-15";

    // These would typically come from build.zig via options
    pub const embedded_resources = true;
    pub const resource_count = 3;
};

test "build info pattern" {
    try testing.expectEqualStrings("1.0.0", build_info.version);
    try testing.expect(build_info.embedded_resources);
    try testing.expectEqual(@as(usize, 3), build_info.resource_count);
}
// ANCHOR_END: build_info_pattern

// Comprehensive test
test "comprehensive data file handling" {
    // Embedded resources
    try testing.expect(Resources.config.len > 0);

    // Resource manager
    var manager = ResourceManager.init(testing.allocator);
    defer manager.deinit();
    try manager.load("test", "data");
    try testing.expect(manager.get("test") != null);

    // Template rendering
    const tmpl = Template.init("{{key}}");
    var vars = std.StringHashMap([]const u8).init(testing.allocator);
    defer vars.deinit();
    try vars.put("key", "value");
    const rendered = try tmpl.render(testing.allocator, vars);
    defer testing.allocator.free(rendered);
    try testing.expectEqualStrings("value", rendered);
}
