## Problem

You need to write a function with keyword-only arguments to make the API clearer and prevent argument order mistakes.

## Solution

### Basic Config

```zig
{{#include ../../../code/03-advanced/07-functions/recipe_7_2.zig:basic_config}}
```

### Required Optional

```zig
{{#include ../../../code/03-advanced/07-functions/recipe_7_2.zig:required_optional}}
```

### Builder Pattern

```zig
{{#include ../../../code/03-advanced/07-functions/recipe_7_2.zig:builder_pattern}}
```

## Discussion

### Required and Optional Parameters

Mix required and optional fields (see code examples above).
    std.debug.print("Opening {s} in mode {s}\n", .{
        options.path,
        @tagName(options.mode),
    });
    std.debug.print("Buffer: {} bytes, Create: {}\n", .{
        options.buffer_size,
        options.create_if_missing,
    });

    // Placeholder - in real code, would open the file
    return error.NotImplemented;
}

test "required and optional parameters" {
    const allocator = std.testing.allocator;

    // Required parameter must be provided
    _ = openFile(allocator, .{ .path = "/tmp/test.txt" }) catch {};

    // Can override defaults
    _ = openFile(allocator, .{
        .path = "/tmp/data.bin",
        .mode = .read_write,
        .buffer_size = 8192,
    }) catch {};
}
```

### Builder Pattern

Create fluent interfaces with method chaining:

```zig
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
```

### Validation in Configuration

Validate configuration at construction:

```zig
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

pub fn startServer(config: ServerConfig) !void {
    try config.validate();
    std.debug.print("Starting server on port {}\n", .{config.port});
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
```

### Nested Configuration

Handle complex configuration hierarchies:

```zig
const DatabaseConfig = struct {
    host: []const u8 = "localhost",
    port: u16 = 5432,
    username: []const u8,
    password: []const u8,
};

const CacheConfig = struct {
    enabled: bool = true,
    ttl_seconds: u32 = 300,
    max_size_mb: u32 = 100,
};

const AppConfig = struct {
    database: DatabaseConfig,
    cache: CacheConfig = .{},
    log_level: enum { debug, info, warn, err } = .info,
};

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
```

### Compile-Time Configuration

Use comptime for zero-cost configuration:

```zig
pub fn Logger(comptime config: struct {
    level: enum { debug, info, warn, err } = .info,
    with_timestamp: bool = true,
    with_color: bool = false,
}) type {
    return struct {
        const Self = @This();

        pub fn log(comptime level: @TypeOf(config.level), message: []const u8) void {
            // Compile-time check - no runtime overhead
            const level_value = @intFromEnum(level);
            const config_level_value = @intFromEnum(config.level);

            if (level_value < config_level_value) {
                return; // Log filtered out at compile time
            }

            if (config.with_timestamp) {
                std.debug.print("[timestamp] ", .{});
            }

            if (config.with_color) {
                std.debug.print("\x1b[32m", .{}); // Green color
            }

            std.debug.print("[{s}] {s}", .{ @tagName(level), message });

            if (config.with_color) {
                std.debug.print("\x1b[0m", .{}); // Reset color
            }

            std.debug.print("\n", .{});
        }
    };
}

test "compile-time configuration" {
    const DebugLogger = Logger(.{ .level = .debug, .with_timestamp = false });
    const ProdLogger = Logger(.{ .level = .warn, .with_color = true });

    DebugLogger.log(.debug, "This appears");
    DebugLogger.log(.info, "This also appears");

    ProdLogger.log(.debug, "This is filtered out at compile time");
    ProdLogger.log(.err, "This appears");
}
```

### Mutually Exclusive Options

Enforce constraints at the type level:

```zig
const OutputFormat = union(enum) {
    file: struct {
        path: []const u8,
        append: bool = false,
    },
    stdout: void,
    stderr: void,
};

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

test "mutually exclusive options" {
    try writeOutput(.{ .file = .{ .path = "/tmp/out.txt" } }, "Hello");
    try writeOutput(.stdout, "World");
    try writeOutput(.stderr, "Error!");
}
```

### Best Practices

**Struct Configuration:**
```zig
// Good: Clear parameter names, self-documenting
try connect(.{ .host = "example.com", .port = 443, .use_ssl = true });

// Bad: Positional parameters are unclear
// try connect("example.com", 443, true); // What does 'true' mean?
```

**Default Values:**
- Provide sensible defaults for optional parameters
- Make required parameters explicit (no default value)
- Document what defaults mean

**Validation:**
```zig
const Config = struct {
    value: u32,

    pub fn init(value: u32) !Config {
        if (value > 100) return error.ValueTooLarge;
        return .{ .value = value };
    }
};

// Use init for validation
const config = try Config.init(50);
```

**Naming:**
- Use clear, descriptive struct names (`ConnectionConfig`, not `Options`)
- Use descriptive field names (`timeout_ms`, not just `timeout`)
- Follow naming conventions from `std` library

### Related Functions

- Struct initialization syntax `.{}`
- Default field values in struct definitions
- `@typeInfo()` for struct reflection
- `@tagName()` for enum to string
- Tagged unions for mutually exclusive options
- Comptime struct parameters for zero-cost abstractions
