const std = @import("std");
const testing = std.testing;

// ANCHOR: simple_config
/// Simple key-value configuration
pub const SimpleConfig = struct {
    map: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) SimpleConfig {
        return .{
            .map = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SimpleConfig) void {
        var iter = self.map.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.map.deinit();
    }

    pub fn loadFromFile(allocator: std.mem.Allocator, path: []const u8) !SimpleConfig {
        var config = SimpleConfig.init(allocator);
        errdefer config.deinit();

        const content = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
        defer allocator.free(content);

        var lines = std.mem.tokenizeScalar(u8, content, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0 or trimmed[0] == '#') continue;

            if (std.mem.indexOf(u8, trimmed, "=")) |eq_pos| {
                const key = std.mem.trim(u8, trimmed[0..eq_pos], " \t");
                const value = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t");

                const key_copy = try allocator.dupe(u8, key);
                errdefer allocator.free(key_copy);
                const value_copy = try allocator.dupe(u8, value);

                try config.map.put(key_copy, value_copy);
            }
        }

        return config;
    }

    pub fn get(self: *const SimpleConfig, key: []const u8) ?[]const u8 {
        return self.map.get(key);
    }

    pub fn getRequired(self: *const SimpleConfig, key: []const u8) ![]const u8 {
        return self.map.get(key) orelse error.MissingConfigKey;
    }
};

test "simple config parsing" {
    const config_content =
        \\# This is a comment
        \\name = MyApp
        \\version = 1.0.0
        \\debug = true
        \\
        \\# Another comment
        \\port = 8080
    ;

    const tmp_path = "zig-cache/test_config.txt";
    {
        const file = try std.fs.cwd().createFile(tmp_path, .{});
        defer file.close();
        try file.writeAll(config_content);
    }
    defer std.fs.cwd().deleteFile(tmp_path) catch {};

    var config = try SimpleConfig.loadFromFile(testing.allocator, tmp_path);
    defer config.deinit();

    try testing.expectEqualStrings("MyApp", config.get("name").?);
    try testing.expectEqualStrings("1.0.0", config.get("version").?);
    try testing.expectEqualStrings("8080", config.get("port").?);
    try testing.expect(config.get("nonexistent") == null);
}
// ANCHOR_END: simple_config

// ANCHOR: ini_config
/// INI-style configuration with sections
pub const IniConfig = struct {
    sections: std.StringHashMap(std.StringHashMap([]const u8)),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) IniConfig {
        return .{
            .sections = std.StringHashMap(std.StringHashMap([]const u8)).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *IniConfig) void {
        var sections_iter = self.sections.iterator();
        while (sections_iter.next()) |section_entry| {
            self.allocator.free(section_entry.key_ptr.*);
            var kv_iter = section_entry.value_ptr.iterator();
            while (kv_iter.next()) |kv_entry| {
                self.allocator.free(kv_entry.key_ptr.*);
                self.allocator.free(kv_entry.value_ptr.*);
            }
            section_entry.value_ptr.deinit();
        }
        self.sections.deinit();
    }

    pub fn loadFromFile(allocator: std.mem.Allocator, path: []const u8) !IniConfig {
        var config = IniConfig.init(allocator);
        errdefer config.deinit();

        const content = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
        defer allocator.free(content);

        var current_section: ?[]const u8 = null;
        var lines = std.mem.tokenizeScalar(u8, content, '\n');

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len == 0 or trimmed[0] == ';' or trimmed[0] == '#') continue;

            // Check for section header
            if (trimmed[0] == '[' and trimmed[trimmed.len - 1] == ']') {
                const section_name = trimmed[1 .. trimmed.len - 1];
                const section_copy = try allocator.dupe(u8, section_name);
                const section_map = std.StringHashMap([]const u8).init(allocator);
                try config.sections.put(section_copy, section_map);
                current_section = section_copy;
            } else if (std.mem.indexOf(u8, trimmed, "=")) |eq_pos| {
                const key = std.mem.trim(u8, trimmed[0..eq_pos], " \t");
                const value = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t");

                if (current_section) |section| {
                    var section_map = config.sections.getPtr(section).?;
                    const key_copy = try allocator.dupe(u8, key);
                    errdefer allocator.free(key_copy);
                    const value_copy = try allocator.dupe(u8, value);
                    try section_map.put(key_copy, value_copy);
                }
            }
        }

        return config;
    }

    pub fn get(self: *const IniConfig, section: []const u8, key: []const u8) ?[]const u8 {
        const section_map = self.sections.get(section) orelse return null;
        return section_map.get(key);
    }
};

test "ini config parsing" {
    const ini_content =
        \\[database]
        \\host = localhost
        \\port = 5432
        \\
        \\[server]
        \\host = 0.0.0.0
        \\port = 8080
    ;

    const tmp_path = "zig-cache/test_config.ini";
    {
        const file = try std.fs.cwd().createFile(tmp_path, .{});
        defer file.close();
        try file.writeAll(ini_content);
    }
    defer std.fs.cwd().deleteFile(tmp_path) catch {};

    var config = try IniConfig.loadFromFile(testing.allocator, tmp_path);
    defer config.deinit();

    try testing.expectEqualStrings("localhost", config.get("database", "host").?);
    try testing.expectEqualStrings("5432", config.get("database", "port").?);
    try testing.expectEqualStrings("8080", config.get("server", "port").?);
}
// ANCHOR_END: ini_config

// ANCHOR: json_config
/// JSON configuration (returns parsed result that must be freed)
pub fn loadJsonConfig(allocator: std.mem.Allocator, comptime T: type, path: []const u8) !std.json.Parsed(T) {
    const content = try std.fs.cwd().readFileAlloc(allocator, path, 1024 * 1024);
    defer allocator.free(content);

    return try std.json.parseFromSlice(T, allocator, content, .{});
}

const AppConfig = struct {
    name: []const u8,
    version: []const u8,
    port: u16,
    debug: bool,
};

test "json config parsing" {
    const json_content =
        \\{
        \\  "name": "MyApp",
        \\  "version": "1.0.0",
        \\  "port": 8080,
        \\  "debug": true
        \\}
    ;

    const tmp_path = "zig-cache/test_config.json";
    {
        const file = try std.fs.cwd().createFile(tmp_path, .{});
        defer file.close();
        try file.writeAll(json_content);
    }
    defer std.fs.cwd().deleteFile(tmp_path) catch {};

    var parsed = try loadJsonConfig(testing.allocator, AppConfig, tmp_path);
    defer parsed.deinit();

    // Values are valid while parsed is alive
    try testing.expectEqual(8080, parsed.value.port);
    try testing.expectEqual(true, parsed.value.debug);
    try testing.expect(parsed.value.name.len > 0);
    try testing.expect(parsed.value.version.len > 0);
}
// ANCHOR_END: json_config

// ANCHOR: env_override
/// Configuration with environment variable overrides
pub const ConfigWithEnv = struct {
    base: SimpleConfig,

    pub fn init(allocator: std.mem.Allocator) ConfigWithEnv {
        return .{ .base = SimpleConfig.init(allocator) };
    }

    pub fn deinit(self: *ConfigWithEnv) void {
        self.base.deinit();
    }

    pub fn get(self: *const ConfigWithEnv, key: []const u8) !?[]const u8 {
        // Try environment variable first (convert to uppercase)
        var env_key_buf: [256]u8 = undefined;
        const env_key = try std.fmt.bufPrint(&env_key_buf, "APP_{s}", .{key});

        // Convert to uppercase
        for (env_key, 0..) |c, i| {
            env_key_buf[i] = std.ascii.toUpper(c);
        }

        if (std.process.getEnvVarOwned(self.base.allocator, env_key_buf[0..env_key.len])) |env_value| {
            return env_value;
        } else |_| {}

        // Fall back to config file
        return self.base.get(key);
    }
};

test "config with env override" {
    var config = ConfigWithEnv.init(testing.allocator);
    defer config.deinit();

    const key_copy = try testing.allocator.dupe(u8, "port");
    const value_copy = try testing.allocator.dupe(u8, "3000");
    try config.base.map.put(key_copy, value_copy);

    // Note: We can't reliably test env vars in tests, but we demonstrate the API
    // The get function may return an owned string from env var, so we need to handle that
    _ = try config.get("port");
    // In real usage, if you know it might be from env, you should free it
}
// ANCHOR_END: env_override

// ANCHOR: typed_config
/// Type-safe configuration accessors
pub const TypedConfig = struct {
    base: SimpleConfig,

    pub fn init(allocator: std.mem.Allocator) TypedConfig {
        return .{ .base = SimpleConfig.init(allocator) };
    }

    pub fn deinit(self: *TypedConfig) void {
        self.base.deinit();
    }

    pub fn getString(self: *const TypedConfig, key: []const u8) ![]const u8 {
        return self.base.getRequired(key);
    }

    pub fn getInt(self: *const TypedConfig, key: []const u8) !i64 {
        const value = try self.base.getRequired(key);
        return try std.fmt.parseInt(i64, value, 10);
    }

    pub fn getBool(self: *const TypedConfig, key: []const u8) !bool {
        const value = try self.base.getRequired(key);
        if (std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "1")) {
            return true;
        } else if (std.mem.eql(u8, value, "false") or std.mem.eql(u8, value, "0")) {
            return false;
        }
        return error.InvalidBoolValue;
    }

    pub fn getFloat(self: *const TypedConfig, key: []const u8) !f64 {
        const value = try self.base.getRequired(key);
        return try std.fmt.parseFloat(f64, value);
    }
};

test "typed config accessors" {
    var config = TypedConfig.init(testing.allocator);
    defer config.deinit();

    try config.base.map.put(try testing.allocator.dupe(u8, "name"), try testing.allocator.dupe(u8, "test"));
    try config.base.map.put(try testing.allocator.dupe(u8, "port"), try testing.allocator.dupe(u8, "8080"));
    try config.base.map.put(try testing.allocator.dupe(u8, "debug"), try testing.allocator.dupe(u8, "true"));
    try config.base.map.put(try testing.allocator.dupe(u8, "rate"), try testing.allocator.dupe(u8, "0.5"));

    try testing.expectEqualStrings("test", try config.getString("name"));
    try testing.expectEqual(8080, try config.getInt("port"));
    try testing.expectEqual(true, try config.getBool("debug"));
    try testing.expectEqual(0.5, try config.getFloat("rate"));
}
// ANCHOR_END: typed_config

// ANCHOR: default_values
/// Configuration with default values
pub const ConfigWithDefaults = struct {
    config: SimpleConfig,
    defaults: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) ConfigWithDefaults {
        return .{
            .config = SimpleConfig.init(allocator),
            .defaults = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ConfigWithDefaults) void {
        self.config.deinit();
        var iter = self.defaults.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.defaults.deinit();
    }

    pub fn setDefault(self: *ConfigWithDefaults, key: []const u8, value: []const u8) !void {
        const key_copy = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(key_copy);
        const value_copy = try self.allocator.dupe(u8, value);
        try self.defaults.put(key_copy, value_copy);
    }

    pub fn get(self: *const ConfigWithDefaults, key: []const u8) []const u8 {
        if (self.config.get(key)) |value| {
            return value;
        }
        return self.defaults.get(key).?;
    }
};

test "config with defaults" {
    var config = ConfigWithDefaults.init(testing.allocator);
    defer config.deinit();

    try config.setDefault("port", "8080");
    try config.setDefault("host", "localhost");

    // Override one default
    try config.config.map.put(try testing.allocator.dupe(u8, "port"), try testing.allocator.dupe(u8, "3000"));

    try testing.expectEqualStrings("3000", config.get("port"));
    try testing.expectEqualStrings("localhost", config.get("host"));
}
// ANCHOR_END: default_values

// ANCHOR: validation
/// Configuration validation
pub const ValidationError = error{
    InvalidPort,
    InvalidHost,
    MissingRequired,
};

pub fn validateConfig(config: *const SimpleConfig) ValidationError!void {
    // Check required fields
    const port_str = config.get("port") orelse return ValidationError.MissingRequired;
    const port = std.fmt.parseInt(u16, port_str, 10) catch return ValidationError.InvalidPort;

    if (port == 0) return ValidationError.InvalidPort;

    if (config.get("host")) |host| {
        if (host.len == 0) return ValidationError.InvalidHost;
    }
}

test "config validation" {
    var config = SimpleConfig.init(testing.allocator);
    defer config.deinit();

    // Missing port
    try testing.expectError(ValidationError.MissingRequired, validateConfig(&config));

    // Invalid port
    try config.map.put(try testing.allocator.dupe(u8, "port"), try testing.allocator.dupe(u8, "0"));
    try testing.expectError(ValidationError.InvalidPort, validateConfig(&config));

    // Valid config
    var valid_config = SimpleConfig.init(testing.allocator);
    defer valid_config.deinit();
    try valid_config.map.put(try testing.allocator.dupe(u8, "port"), try testing.allocator.dupe(u8, "8080"));
    try valid_config.map.put(try testing.allocator.dupe(u8, "host"), try testing.allocator.dupe(u8, "localhost"));
    try validateConfig(&valid_config);
}
// ANCHOR_END: validation

// ANCHOR: config_merge
/// Merge multiple configuration sources
pub fn mergeConfigs(allocator: std.mem.Allocator, configs: []const SimpleConfig) !SimpleConfig {
    var merged = SimpleConfig.init(allocator);
    errdefer merged.deinit();

    for (configs) |config| {
        var iter = config.map.iterator();
        while (iter.next()) |entry| {
            const key_copy = try allocator.dupe(u8, entry.key_ptr.*);
            errdefer allocator.free(key_copy);
            const value_copy = try allocator.dupe(u8, entry.value_ptr.*);

            // Later configs override earlier ones
            if (merged.map.getPtr(key_copy)) |existing| {
                allocator.free(existing.*);
                existing.* = value_copy;
                allocator.free(key_copy);
            } else {
                try merged.map.put(key_copy, value_copy);
            }
        }
    }

    return merged;
}

test "merge configs" {
    var config1 = SimpleConfig.init(testing.allocator);
    defer config1.deinit();
    try config1.map.put(try testing.allocator.dupe(u8, "port"), try testing.allocator.dupe(u8, "8080"));
    try config1.map.put(try testing.allocator.dupe(u8, "host"), try testing.allocator.dupe(u8, "localhost"));

    var config2 = SimpleConfig.init(testing.allocator);
    defer config2.deinit();
    try config2.map.put(try testing.allocator.dupe(u8, "port"), try testing.allocator.dupe(u8, "3000"));
    try config2.map.put(try testing.allocator.dupe(u8, "debug"), try testing.allocator.dupe(u8, "true"));

    const configs = [_]SimpleConfig{ config1, config2 };
    var merged = try mergeConfigs(testing.allocator, &configs);
    defer merged.deinit();

    try testing.expectEqualStrings("3000", merged.get("port").?); // Overridden
    try testing.expectEqualStrings("localhost", merged.get("host").?);
    try testing.expectEqualStrings("true", merged.get("debug").?);
}
// ANCHOR_END: config_merge
