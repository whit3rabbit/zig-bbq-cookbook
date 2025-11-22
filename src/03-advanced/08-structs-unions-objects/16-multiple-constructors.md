## Problem

You want to create a struct with multiple ways to initialize it, similar to constructor overloading in other languages. Zig doesn't have traditional constructors, but you need different initialization patterns.

## Solution

Use named static methods as constructors. Each method returns an instance of the struct, providing different initialization patterns based on the use case.

### Named Constructors

Create multiple initialization methods with descriptive names:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_16.zig:named_constructors}}
```

Each method provides a clear, self-documenting way to create a Point:
- `init()` for basic x,y coordinates
- `origin()` for the (0,0) point
- `fromPolar()` for polar coordinates
- `fromArray()` for array conversion

### Default Values

Provide convenience constructors with sensible defaults:

```zig
const Server = struct {
    host: []const u8,
    port: u16,
    timeout: u32,

    pub fn init(host: []const u8, port: u16, timeout: u32) Server {
        return Server{
            .host = host,
            .port = port,
            .timeout = timeout,
        };
    }

    pub fn withDefaults(host: []const u8) Server {
        return Server{
            .host = host,
            .port = 8080,
            .timeout = 30,
        };
    }

    pub fn localhost() Server {
        return Server{
            .host = "127.0.0.1",
            .port = 8080,
            .timeout = 30,
        };
    }
};
```

Users can choose between full control and convenient defaults.

### Factory Methods with Validation

Return error unions for constructors that can fail:

```zig
const Email = struct {
    address: []const u8,

    pub fn init(address: []const u8) !Email {
        if (std.mem.indexOf(u8, address, "@") == null) {
            return error.InvalidEmail;
        }
        return Email{ .address = address };
    }

    pub fn fromParts(local: []const u8, domain: []const u8, allocator: std.mem.Allocator) !Email {
        const address = try std.fmt.allocPrint(allocator, "{s}@{s}", .{ local, domain });
        return Email{ .address = address };
    }

    pub fn anonymous(allocator: std.mem.Allocator) !Email {
        const address = try std.fmt.allocPrint(
            allocator,
            "user{d}@example.com",
            .{std.crypto.random.int(u32)}
        );
        return Email{ .address = address };
    }
};
```

Factory methods can validate input and return errors when initialization fails.

### Builder-Style Constructors

Create convenience methods for common use cases:

```zig
const HttpRequest = struct {
    method: []const u8,
    url: []const u8,
    headers: ?std.StringHashMap([]const u8),
    body: ?[]const u8,

    pub fn init(method: []const u8, url: []const u8) HttpRequest {
        return HttpRequest{
            .method = method,
            .url = url,
            .headers = null,
            .body = null,
        };
    }

    pub fn get(url: []const u8) HttpRequest {
        return HttpRequest.init("GET", url);
    }

    pub fn post(url: []const u8, body: []const u8) HttpRequest {
        return HttpRequest{
            .method = "POST",
            .url = url,
            .headers = null,
            .body = body,
        };
    }
};
```

Specialized constructors make common operations more ergonomic.

### Copy Constructors

Create instances from existing instances:

```zig
const Vector = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn init(x: f32, y: f32, z: f32) Vector {
        return Vector{ .x = x, .y = y, .z = z };
    }

    pub fn copy(other: *const Vector) Vector {
        return Vector{
            .x = other.x,
            .y = other.y,
            .z = other.z,
        };
    }

    pub fn scaled(self: *const Vector, factor: f32) Vector {
        return Vector{
            .x = self.x * factor,
            .y = self.y * factor,
            .z = self.z * factor,
        };
    }

    pub fn normalized(self: *const Vector) Vector {
        const len = @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
        if (len == 0) return Vector.init(0, 0, 0);
        return Vector{
            .x = self.x / len,
            .y = self.y / len,
            .z = self.z / len,
        };
    }
};
```

Transformation methods return new instances without modifying the original.

### Conditional Initialization

Create instances based on environment or configuration:

```zig
const Config = struct {
    environment: []const u8,
    debug_mode: bool,
    log_level: u8,

    pub fn production() Config {
        return Config{
            .environment = "production",
            .debug_mode = false,
            .log_level = 2,
        };
    }

    pub fn development() Config {
        return Config{
            .environment = "development",
            .debug_mode = true,
            .log_level = 5,
        };
    }

    pub fn fromEnv(env: []const u8) Config {
        if (std.mem.eql(u8, env, "prod")) {
            return Config.production();
        } else if (std.mem.eql(u8, env, "dev")) {
            return Config.development();
        } else {
            return Config.testing();
        }
    }
};
```

Environment-specific constructors encapsulate configuration logic.

### Parse Constructors

Create instances from different representations:

```zig
const Color = struct {
    r: u8,
    g: u8,
    b: u8,

    pub fn init(r: u8, g: u8, b: u8) Color {
        return Color{ .r = r, .g = g, .b = b };
    }

    pub fn fromRgb(rgb: u32) Color {
        return Color{
            .r = @intCast((rgb >> 16) & 0xFF),
            .g = @intCast((rgb >> 8) & 0xFF),
            .b = @intCast(rgb & 0xFF),
        };
    }

    pub fn black() Color {
        return Color.init(0, 0, 0);
    }

    pub fn white() Color {
        return Color.init(255, 255, 255);
    }

    pub fn fromGrayscale(value: u8) Color {
        return Color.init(value, value, value);
    }
};
```

Parse different formats into your struct representation.

### Generic Constructors

Use comptime for type-generic construction:

```zig
fn Result(comptime T: type, comptime E: type) type {
    return union(enum) {
        ok: T,
        err: E,

        pub fn initOk(value: T) @This() {
            return .{ .ok = value };
        }

        pub fn initErr(err: E) @This() {
            return .{ .err = err };
        }

        pub fn fromOptional(opt: ?T, default_err: E) @This() {
            if (opt) |value| {
                return .{ .ok = value };
            } else {
                return .{ .err = default_err };
            }
        }
    };
}
```

Generic types can have multiple constructors for different scenarios.

## Discussion

Zig doesn't have constructor overloading, but named methods provide a clearer, more flexible alternative.

### Why Named Constructors

**Clarity**: Method names document intent
```zig
Point.origin()           // Clear: creates origin point
Point.fromPolar(5, 0)    // Clear: converts from polar
```

**Flexibility**: Different return types or error handling per constructor
```zig
pub fn init(...) Point           // Never fails
pub fn fromString(...) !Point    // Can fail with error
```

**Self-documenting**: No ambiguity about what each constructor does
```zig
Config.production()    // Obviously production config
Config.development()   // Obviously development config
```

### Constructor Patterns

**Basic pattern**: Direct initialization
```zig
pub fn init(params) Type {
    return Type{ .field = param };
}
```

**With defaults**: Common configurations
```zig
pub fn withDefaults(required_params) Type {
    return Type{
        .required = required_params,
        .optional = default_value,
    };
}
```

**Factory pattern**: Validation and transformation
```zig
pub fn fromX(x_data) !Type {
    if (!valid(x_data)) return error.Invalid;
    return Type{ .field = transform(x_data) };
}
```

**Named instances**: Common constants
```zig
pub fn origin() Type {
    return Type{ .x = 0, .y = 0 };
}
```

### Design Guidelines

**Naming conventions**:
- `init()` for basic construction
- `from*()` for conversion constructors
- Named constants for well-known instances
- `with*()` for variant constructors

**Error handling**:
- Return `Type` if never fails
- Return `!Type` if validation needed
- Return `?Type` for optional construction

**Allocator usage**:
- Pass allocator as first parameter when needed
- Store allocator in struct if lifetime matches struct
- Document memory ownership clearly

### Performance

All constructors are regular functions that get inlined:

```zig
const p = Point.origin();  // Inlined to: Point{ .x = 0, .y = 0 }
```

No runtime overhead compared to direct initialization. The compiler optimizes away the function call.

### Comparison with Other Languages

**C++**: Constructor overloading
```cpp
Point(float x, float y);           // Zig: init(x, y)
Point();                            // Zig: origin()
static Point fromPolar(r, theta);  // Zig: fromPolar(r, theta)
```

**Java**: Multiple constructors
```java
Point(float x, float y) { ... }    // Zig: init(x, y)
Point() { this(0, 0); }             // Zig: origin()
```

**Rust**: Impl blocks with multiple methods
```rust
impl Point {
    fn new(x, y) -> Point { ... }   // Zig: init(x, y)
    fn origin() -> Point { ... }    // Zig: origin()
}
```

Zig's approach is most similar to Rust, but simpler because Zig structs are just namespaces.

## See Also

- Recipe 8.11: Simplifying the Initialization of Data Structures
- Recipe 8.17: Creating an Instance Without Invoking Init
- Recipe 8.13: Implementing a Data Model or Type System
- Recipe 9.11: Using comptime to Control Instance Creation

Full compilable example: `code/03-advanced/08-structs-unions-objects/recipe_8_16.zig`
