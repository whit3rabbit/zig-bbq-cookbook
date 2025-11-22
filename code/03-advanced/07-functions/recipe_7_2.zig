const std = @import("std");

// ANCHOR: basic_config
/// Connection configuration with defaults
const ConnectionConfig = struct {
    host: []const u8 = "localhost",
    port: u16 = 8080,
    timeout_ms: u32 = 5000,
    use_ssl: bool = false,
};

/// Connect with configuration
pub fn connect(config: ConnectionConfig) !void {
    std.debug.print("Connecting to {s}:{d}\n", .{ config.host, config.port });
    std.debug.print("SSL: {}, Timeout: {}ms\n", .{ config.use_ssl, config.timeout_ms });
}
// ANCHOR_END: basic_config

// ANCHOR: required_optional
/// File options with required and optional fields
const FileOptions = struct {
    path: []const u8, // Required
    mode: std.fs.File.OpenMode = .read_only,
    buffer_size: usize = 4096,
    create_if_missing: bool = false,
};

/// Open file with options
pub fn openFile(allocator: std.mem.Allocator, options: FileOptions) !void {
    _ = allocator;
    std.debug.print("Opening {s} in mode {s}\n", .{
        options.path,
        @tagName(options.mode),
    });
    std.debug.print("Buffer: {} bytes, Create: {}\n", .{
        options.buffer_size,
        options.create_if_missing,
    });
}
// ANCHOR_END: required_optional

// ANCHOR: builder_pattern
/// Query builder with fluent interface
const QueryBuilder = struct {
    allocator: std.mem.Allocator,
    table: ?[]const u8 = null,
    where_clause: ?[]const u8 = null,
    limit: ?usize = null,
    offset: ?usize = null,

    pub fn init(allocator: std.mem.Allocator) QueryBuilder {
        return .{ .allocator = allocator };
    }

    pub fn from(self: QueryBuilder, table_name: []const u8) QueryBuilder {
        var result = self;
        result.table = table_name;
        return result;
    }

    pub fn where(self: QueryBuilder, clause: []const u8) QueryBuilder {
        var result = self;
        result.where_clause = clause;
        return result;
    }

    pub fn limitTo(self: QueryBuilder, n: usize) QueryBuilder {
        var result = self;
        result.limit = n;
        return result;
    }

    pub fn offsetBy(self: QueryBuilder, n: usize) QueryBuilder {
        var result = self;
        result.offset = n;
        return result;
    }

    pub fn build(self: QueryBuilder) ![]const u8 {
        var list = std.ArrayList(u8){};
        errdefer list.deinit(self.allocator);

        try list.appendSlice(self.allocator, "SELECT * FROM ");
        try list.appendSlice(self.allocator, self.table orelse "unknown");

        if (self.where_clause) |clause| {
            try list.appendSlice(self.allocator, " WHERE ");
            try list.appendSlice(self.allocator, clause);
        }

        if (self.limit) |lim| {
            const limit_str = try std.fmt.allocPrint(self.allocator, " LIMIT {}", .{lim});
            defer self.allocator.free(limit_str);
            try list.appendSlice(self.allocator, limit_str);
        }

        if (self.offset) |off| {
            const offset_str = try std.fmt.allocPrint(self.allocator, " OFFSET {}", .{off});
            defer self.allocator.free(offset_str);
            try list.appendSlice(self.allocator, offset_str);
        }

        return list.toOwnedSlice(self.allocator);
    }
};
// ANCHOR_END: builder_pattern

/// Server configuration with validation
const ServerConfig = struct {
    port: u16,
    max_connections: u32 = 100,
    thread_pool_size: u32 = 4,

    pub fn validate(self: ServerConfig) !void {
        if (self.port < 1024) {
            return error.PrivilegedPort;
        }
        if (self.max_connections == 0) {
            return error.InvalidMaxConnections;
        }
        if (self.thread_pool_size == 0 or self.thread_pool_size > 1000) {
            return error.InvalidThreadPoolSize;
        }
    }
};

/// Start server with validation
pub fn startServer(config: ServerConfig) !void {
    try config.validate();
    std.debug.print("Starting server on port {}\n", .{config.port});
}

/// Database configuration
const DatabaseConfig = struct {
    host: []const u8 = "localhost",
    port: u16 = 5432,
    username: []const u8,
    password: []const u8,
};

/// Cache configuration
const CacheConfig = struct {
    enabled: bool = true,
    ttl_seconds: u32 = 300,
    max_size_mb: u32 = 100,
};

/// Application configuration with nested configs
const AppConfig = struct {
    database: DatabaseConfig,
    cache: CacheConfig = .{},
    log_level: enum { debug, info, warn, err } = .info,
};

/// Initialize application with nested config
pub fn initializeApp(config: AppConfig) !void {
    std.debug.print("DB: {s}@{s}:{}\n", .{
        config.database.username,
        config.database.host,
        config.database.port,
    });
    std.debug.print("Cache: {}, TTL: {}s\n", .{
        config.cache.enabled,
        config.cache.ttl_seconds,
    });
    std.debug.print("Log level: {s}\n", .{@tagName(config.log_level)});
}

/// Compile-time logger configuration
pub fn Logger(comptime config: struct {
    level: enum { debug, info, warn, err } = .info,
    with_timestamp: bool = true,
    with_color: bool = false,
}) type {
    return struct {
        const Self = @This();

        pub fn log(comptime level: @TypeOf(config.level), message: []const u8) void {
            const level_value = @intFromEnum(level);
            const config_level_value = @intFromEnum(config.level);

            if (level_value < config_level_value) {
                return;
            }

            if (config.with_timestamp) {
                std.debug.print("[timestamp] ", .{});
            }

            if (config.with_color) {
                std.debug.print("\x1b[32m", .{});
            }

            std.debug.print("[{s}] {s}", .{ @tagName(level), message });

            if (config.with_color) {
                std.debug.print("\x1b[0m", .{});
            }

            std.debug.print("\n", .{});
        }
    };
}

/// Output format with mutually exclusive options
const OutputFormat = union(enum) {
    file: struct {
        path: []const u8,
        append: bool = false,
    },
    stdout: void,
    stderr: void,
};

/// Write output to different destinations
pub fn writeOutput(format: OutputFormat, data: []const u8) !void {
    switch (format) {
        .file => |file_config| {
            std.debug.print("Writing to file: {s} (append: {})\n", .{
                file_config.path,
                file_config.append,
            });
            std.debug.print("Data: {s}\n", .{data});
        },
        .stdout => {
            std.debug.print("Writing to stdout: {s}\n", .{data});
        },
        .stderr => {
            std.debug.print("Writing to stderr: {s}\n", .{data});
        },
    }
}

// Tests

test "keyword arguments" {
    // All defaults
    try connect(.{});

    // Override specific fields
    try connect(.{ .host = "example.com", .port = 443, .use_ssl = true });

    // Named parameters make intent clear
    try connect(.{
        .host = "api.example.com",
        .use_ssl = true,
    });
}

test "required and optional parameters" {
    const allocator = std.testing.allocator;

    // Required parameter must be provided
    try openFile(allocator, .{ .path = "/tmp/test.txt" });

    // Can override defaults
    try openFile(allocator, .{
        .path = "/tmp/data.bin",
        .mode = .read_write,
        .buffer_size = 8192,
    });
}

test "builder pattern" {
    const allocator = std.testing.allocator;

    const query = try QueryBuilder.init(allocator)
        .from("users")
        .where("age > 21")
        .limitTo(10)
        .offsetBy(20)
        .build();
    defer allocator.free(query);

    try std.testing.expect(std.mem.indexOf(u8, query, "users") != null);
    try std.testing.expect(std.mem.indexOf(u8, query, "LIMIT 10") != null);
}

test "configuration validation" {
    // Valid config
    try startServer(.{ .port = 8080 });

    // Invalid configs
    try std.testing.expectError(error.PrivilegedPort, startServer(.{ .port = 80 }));
    try std.testing.expectError(
        error.InvalidMaxConnections,
        startServer(.{ .port = 8080, .max_connections = 0 }),
    );
}

test "nested configuration" {
    try initializeApp(.{
        .database = .{
            .username = "admin",
            .password = "secret",
        },
    });

    try initializeApp(.{
        .database = .{
            .host = "db.example.com",
            .username = "user",
            .password = "pass",
        },
        .cache = .{
            .enabled = false,
        },
        .log_level = .debug,
    });
}

test "compile-time configuration" {
    const DebugLogger = Logger(.{ .level = .debug, .with_timestamp = false });
    const ProdLogger = Logger(.{ .level = .warn, .with_color = true });

    DebugLogger.log(.debug, "This appears");
    DebugLogger.log(.info, "This also appears");

    ProdLogger.log(.debug, "This is filtered out at compile time");
    ProdLogger.log(.err, "This appears");
}

test "mutually exclusive options" {
    try writeOutput(.{ .file = .{ .path = "/tmp/out.txt" } }, "Hello");
    try writeOutput(.stdout, "World");
    try writeOutput(.stderr, "Error!");
}

test "default values" {
    const config: ConnectionConfig = .{};
    try std.testing.expectEqualStrings("localhost", config.host);
    try std.testing.expectEqual(@as(u16, 8080), config.port);
    try std.testing.expectEqual(@as(u32, 5000), config.timeout_ms);
    try std.testing.expectEqual(false, config.use_ssl);
}

test "partial override" {
    const config: ConnectionConfig = .{ .port = 9000 };
    try std.testing.expectEqualStrings("localhost", config.host);
    try std.testing.expectEqual(@as(u16, 9000), config.port);
}

test "query builder no where clause" {
    const allocator = std.testing.allocator;

    const query = try QueryBuilder.init(allocator)
        .from("products")
        .build();
    defer allocator.free(query);

    try std.testing.expectEqualStrings("SELECT * FROM products", query);
}

test "query builder with limit only" {
    const allocator = std.testing.allocator;

    const query = try QueryBuilder.init(allocator)
        .from("items")
        .limitTo(5)
        .build();
    defer allocator.free(query);

    try std.testing.expect(std.mem.indexOf(u8, query, "LIMIT 5") != null);
}

test "validation passes with good values" {
    const config = ServerConfig{
        .port = 8080,
        .max_connections = 50,
        .thread_pool_size = 8,
    };
    try config.validate();
}

test "validation fails with thread pool too large" {
    const config = ServerConfig{
        .port = 8080,
        .thread_pool_size = 2000,
    };
    try std.testing.expectError(error.InvalidThreadPoolSize, config.validate());
}

test "nested config with all defaults" {
    try initializeApp(.{
        .database = .{
            .username = "user",
            .password = "pass",
        },
    });
}

test "output format file with append" {
    try writeOutput(.{
        .file = .{
            .path = "/tmp/log.txt",
            .append = true,
        },
    }, "Log entry");
}
