## Problem

You want to make it easier to create instances of structs with many fields, optional parameters, validation rules, or complex initialization logic.

## Solution

Zig provides several patterns for simplifying initialization: default values, builder patterns, named constructors, configuration structs, and fluent interfaces.

### Default Values with Method Chaining

Provide sensible defaults and allow selective overrides:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_11.zig:default_values}}
```

Users start with good defaults and chain modifications as needed.

### Builder Pattern

Use a dedicated builder struct for complex initialization with validation:

```zig
const HttpClient = struct {
    base_url: []const u8,
    timeout_ms: u32,
    retry_count: u8,
    user_agent: []const u8,

    pub const Builder = struct {
        base_url: ?[]const u8,
        timeout_ms: u32,
        retry_count: u8,
        user_agent: []const u8,

        pub fn init() Builder {
            return Builder{
                .base_url = null,
                .timeout_ms = 30000,
                .retry_count = 3,
                .user_agent = "ZigClient/1.0",
            };
        }

        pub fn setBaseUrl(self: *Builder, url: []const u8) *Builder {
            self.base_url = url;
            return self;
        }

        pub fn setTimeout(self: *Builder, ms: u32) *Builder {
            self.timeout_ms = ms;
            return self;
        }

        pub fn build(self: *const Builder) !HttpClient {
            if (self.base_url == null) {
                return error.BaseUrlRequired;
            }

            return HttpClient{
                .base_url = self.base_url.?,
                .timeout_ms = self.timeout_ms,
                .retry_count = self.retry_count,
                .user_agent = self.user_agent,
            };
        }
    };
};
```

The builder validates required fields before constructing the final object.

### Named Constructors

Provide multiple initialization methods with descriptive names:

```zig
const Connection = struct {
    host: []const u8,
    port: u16,
    encrypted: bool,

    pub fn localhost(port: u16) Connection {
        return Connection{
            .host = "127.0.0.1",
            .port = port,
            .encrypted = false,
        };
    }

    pub fn secure(host: []const u8, port: u16) Connection {
        return Connection{
            .host = host,
            .port = port,
            .encrypted = true,
        };
    }

    pub fn fromUrl(url: []const u8) !Connection {
        if (std.mem.startsWith(u8, url, "https://")) {
            return Connection{
                .host = url[8..],
                .port = 443,
                .encrypted = true,
            };
        } else if (std.mem.startsWith(u8, url, "http://")) {
            return Connection{
                .host = url[7..],
                .port = 80,
                .encrypted = false,
            };
        }
        return error.InvalidUrl;
    }
};
```

Named constructors clarify intent: `Connection.localhost(8080)` vs. `Connection.secure("api.example.com", 443)`.

### Partial Initialization with Options

Separate required and optional parameters:

```zig
const UserProfile = struct {
    username: []const u8,
    email: []const u8,
    bio: ?[]const u8,
    avatar_url: ?[]const u8,
    verified: bool,

    pub const Options = struct {
        bio: ?[]const u8 = null,
        avatar_url: ?[]const u8 = null,
        verified: bool = false,
    };

    pub fn init(username: []const u8, email: []const u8, options: Options) UserProfile {
        return UserProfile{
            .username = username,
            .email = email,
            .bio = options.bio,
            .avatar_url = options.avatar_url,
            .verified = options.verified,
        };
    }
};
```

Use anonymous struct literal syntax for clean call sites:

```zig
const user = UserProfile.init("alice", "alice@example.com", .{
    .bio = "Developer",
    .verified = true,
});
```

### Copy Constructor Pattern

Create new instances based on existing ones:

```zig
const Point = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn copy(self: *const Point) Point {
        return Point{
            .x = self.x,
            .y = self.y,
            .z = self.z,
        };
    }

    pub fn copyWith(self: *const Point, x: ?f32, y: ?f32, z: ?f32) Point {
        return Point{
            .x = x orelse self.x,
            .y = y orelse self.y,
            .z = z orelse self.z,
        };
    }

    pub fn scaled(self: *const Point, factor: f32) Point {
        return Point{
            .x = self.x * factor,
            .y = self.y * factor,
            .z = self.z * factor,
        };
    }
};
```

Transformative constructors derive new values from existing instances.

### Validated Initialization

Enforce invariants at construction time:

```zig
const Email = struct {
    address: []const u8,

    pub fn init(address: []const u8) !Email {
        if (address.len == 0) return error.EmptyEmail;
        if (std.mem.indexOf(u8, address, "@") == null) return error.InvalidEmail;

        return Email{ .address = address };
    }
};

const Age = struct {
    value: u8,

    pub fn init(value: u8) !Age {
        if (value > 150) return error.InvalidAge;
        return Age{ .value = value };
    }
};
```

Invalid values can't be constructed—validation happens early.

### Configuration Struct Pattern

Use struct default values for cleaner initialization:

```zig
const DatabaseConfig = struct {
    connection_string: []const u8,
    pool_size: u32 = 10,
    timeout_ms: u32 = 5000,
    auto_reconnect: bool = true,
    ssl_enabled: bool = false,

    pub fn validate(self: *const DatabaseConfig) !void {
        if (self.connection_string.len == 0) {
            return error.EmptyConnectionString;
        }
        if (self.pool_size == 0) {
            return error.InvalidPoolSize;
        }
    }
};

const Database = struct {
    config: DatabaseConfig,

    pub fn init(config: DatabaseConfig) !Database {
        try config.validate();
        return Database{ .config = config };
    }
};
```

Users only specify non-default values:

```zig
const db = try Database.init(.{
    .connection_string = "postgresql://localhost/mydb",
    .pool_size = 20,
    .ssl_enabled = true,
});
```

### From Conversions

Provide type conversions from common formats:

```zig
const Color = struct {
    r: u8,
    g: u8,
    b: u8,

    pub fn fromHex(hex: u32) Color {
        return Color{
            .r = @truncate((hex >> 16) & 0xFF),
            .g = @truncate((hex >> 8) & 0xFF),
            .b = @truncate(hex & 0xFF),
        };
    }

    pub fn fromRgb(r: u8, g: u8, b: u8) Color {
        return Color{ .r = r, .g = g, .b = b };
    }

    pub fn fromGray(value: u8) Color {
        return Color{ .r = value, .g = value, .b = value };
    }
};
```

Multiple `from*` methods support different input formats.

## Discussion

Good initialization patterns make structs easier to use and harder to misuse.

### Choosing a Pattern

**Default values** - When most fields have sensible defaults
- Example: Configuration objects, UI widgets

**Builder pattern** - When validation is complex or fields are interdependent
- Example: HTTP clients, database connections

**Named constructors** - When different use cases need different initialization
- Example: Connections (localhost vs remote), Colors (RGB vs hex)

**Options struct** - When many optional parameters exist
- Example: User profiles, search filters

**Validated init** - When invariants must hold
- Example: Email addresses, age ranges, positive numbers

### Performance Considerations

All patterns shown have zero runtime overhead:
- Method chaining creates stack values
- Builder pattern compiles to direct initialization
- Named constructors inline to struct literals
- No heap allocation unless explicitly required

### Error Handling

Use error unions (`!Type`) for fallible initialization:

```zig
pub fn init(...) !MyStruct {
    if (invalid) return error.InvalidInput;
    return MyStruct{ ... };
}
```

This forces callers to handle errors with `try` or `catch`.

### Testing Tips

Test initialization patterns thoroughly:

```zig
test "builder requires base URL" {
    var builder = HttpClient.Builder.init();
    const result = builder.build();
    try testing.expectError(error.BaseUrlRequired, result);
}

test "email validates format" {
    const result = Email.init("invalid");
    try testing.expectError(error.InvalidEmail, result);
}
```

## See Also

- Recipe 8.6: Creating Managed Attributes
- Recipe 8.16: Defining More Than One Constructor
- Recipe 8.17: Creating an Instance Without Invoking Init
- Recipe 9.11: Using comptime to Control Instance Creation

Full compilable example: `code/03-advanced/08-structs-unions-objects/recipe_8_11.zig`
