## Problem

You want to control how your struct instances are printed and formatted as strings.

## Solution

Implement a `format` function for your struct that integrates with `std.fmt`:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_1.zig:basic_format}}
```

**Note:** In Zig 0.15.2, use `{f}` to call the custom `format` function, or `{any}` to use default struct representation.

## Discussion

### Basic Format Implementation

The `format` function has a simple signature taking just self and writer:

```zig
const Person = struct {
    name: []const u8,
    age: u32,

    pub fn format(self: Person, writer: anytype) !void {
        try writer.print("{s} (age {d})", .{ self.name, self.age });
    }
};

test "basic format" {
    const person = Person{ .name = "Alice", .age = 30 };

    var buf: [100]u8 = undefined;
    const result = try std.fmt.bufPrint(&buf, "{f}", .{person});

    try std.testing.expectEqualStrings("Alice (age 30)", result);
}
```

### Additional Formatting Methods

Create separate methods for different representations:

```zig
const Rectangle = struct {
    width: f32,
    height: f32,

    pub fn format(self: Rectangle, writer: anytype) !void {
        try writer.print("Rectangle({d:.2}x{d:.2})", .{ self.width, self.height });
    }

    pub fn area(self: Rectangle) f32 {
        return self.width * self.height;
    }

    pub fn perimeter(self: Rectangle) f32 {
        return 2 * (self.width + self.height);
    }
};

test "format with methods" {
    const rect = Rectangle{ .width = 10.0, .height = 5.0 };

    var buf: [100]u8 = undefined;

    const default_fmt = try std.fmt.bufPrint(&buf, "{f}", .{rect});
    try std.testing.expectEqualStrings("Rectangle(10.00x5.00)", default_fmt);

    try std.testing.expectEqual(@as(f32, 50.0), rect.area());
    try std.testing.expectEqual(@as(f32, 30.0), rect.perimeter());
}
```

### Debug vs Display Formatting

Different representations for debugging and display:

```zig
const User = struct {
    id: u64,
    username: []const u8,
    email: []const u8,

    pub fn format(
        self: User,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;

        if (std.mem.eql(u8, fmt, "debug")) {
            try writer.print("User{{ id={d}, username=\"{s}\", email=\"{s}\" }}", .{
                self.id,
                self.username,
                self.email,
            });
        } else {
            try writer.print("{s} ({s})", .{ self.username, self.email });
        }
    }
};

test "debug vs display" {
    const user = User{
        .id = 12345,
        .username = "alice",
        .email = "alice@example.com",
    };

    var buf: [200]u8 = undefined;

    const display = try std.fmt.bufPrint(&buf, "{}", .{user});
    try std.testing.expectEqualStrings("alice (alice@example.com)", display);

    const debug = try std.fmt.bufPrint(&buf, "{debug}", .{user});
    try std.testing.expectEqualStrings(
        "User{ id=12345, username=\"alice\", email=\"alice@example.com\" }",
        debug,
    );
}
```

### Nested Struct Formatting

Handle nested structures:

```zig
const Address = struct {
    street: []const u8,
    city: []const u8,

    pub fn format(
        self: Address,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s}, {s}", .{ self.street, self.city });
    }
};

const Employee = struct {
    name: []const u8,
    address: Address,

    pub fn format(
        self: Employee,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s} @ {}", .{ self.name, self.address });
    }
};

test "nested formatting" {
    const emp = Employee{
        .name = "Bob",
        .address = Address{ .street = "123 Main St", .city = "Springfield" },
    };

    var buf: [200]u8 = undefined;
    const result = try std.fmt.bufPrint(&buf, "{}", .{emp});

    try std.testing.expectEqualStrings("Bob @ 123 Main St, Springfield", result);
}
```

### Slice and Array Formatting

Format collections of items:

```zig
const Vector3 = struct {
    data: [3]f32,

    pub fn format(
        self: Vector3,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("({d:.2}, {d:.2}, {d:.2})", .{
            self.data[0],
            self.data[1],
            self.data[2],
        });
    }
};

test "array formatting" {
    const v = Vector3{ .data = .{ 1.5, 2.5, 3.5 } };

    var buf: [100]u8 = undefined;
    const result = try std.fmt.bufPrint(&buf, "{}", .{v});

    try std.testing.expectEqualStrings("(1.50, 2.50, 3.50)", result);
}
```

### Tagged Union Formatting

Format different variants:

```zig
const Shape = union(enum) {
    circle: struct { radius: f32 },
    rectangle: struct { width: f32, height: f32 },
    triangle: struct { base: f32, height: f32 },

    pub fn format(
        self: Shape,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        switch (self) {
            .circle => |c| try writer.print("Circle(r={d:.2})", .{c.radius}),
            .rectangle => |r| try writer.print("Rectangle({d:.2}x{d:.2})", .{ r.width, r.height }),
            .triangle => |t| try writer.print("Triangle(b={d:.2}, h={d:.2})", .{ t.base, t.height }),
        }
    }
};

test "union formatting" {
    const circle = Shape{ .circle = .{ .radius = 5.0 } };
    const rect = Shape{ .rectangle = .{ .width = 10.0, .height = 5.0 } };

    var buf: [100]u8 = undefined;

    const c_str = try std.fmt.bufPrint(&buf, "{}", .{circle});
    try std.testing.expectEqualStrings("Circle(r=5.00)", c_str);

    const r_str = try std.fmt.bufPrint(&buf, "{}", .{rect});
    try std.testing.expectEqualStrings("Rectangle(10.00x5.00)", r_str);
}
```

### Multiline Formatting

Pretty-print complex structures:

```zig
const Config = struct {
    host: []const u8,
    port: u16,
    timeout_ms: u32,

    pub fn format(
        self: Config,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = options;

        if (std.mem.eql(u8, fmt, "pretty")) {
            try writer.writeAll("Config {\n");
            try writer.print("  host: \"{s}\"\n", .{self.host});
            try writer.print("  port: {d}\n", .{self.port});
            try writer.print("  timeout_ms: {d}\n", .{self.timeout_ms});
            try writer.writeAll("}");
        } else {
            try writer.print("Config{{ host=\"{s}\", port={d}, timeout_ms={d} }}", .{
                self.host,
                self.port,
                self.timeout_ms,
            });
        }
    }
};

test "multiline formatting" {
    const cfg = Config{
        .host = "localhost",
        .port = 8080,
        .timeout_ms = 5000,
    };

    var buf: [200]u8 = undefined;

    const compact = try std.fmt.bufPrint(&buf, "{}", .{cfg});
    try std.testing.expectEqualStrings(
        "Config{ host=\"localhost\", port=8080, timeout_ms=5000 }",
        compact,
    );

    const pretty = try std.fmt.bufPrint(&buf, "{pretty}", .{cfg});
    const expected =
        \\Config {
        \\  host: "localhost"
        \\  port: 8080
        \\  timeout_ms: 5000
        \\}
    ;
    try std.testing.expectEqualStrings(expected, pretty);
}
```

### Conditional Formatting

Show different fields based on state:

```zig
const Status = enum { active, inactive, pending };

const Account = struct {
    username: []const u8,
    status: Status,
    login_count: u32,

    pub fn format(
        self: Account,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("{s} [", .{self.username});

        switch (self.status) {
            .active => try writer.writeAll("ACTIVE"),
            .inactive => try writer.writeAll("INACTIVE"),
            .pending => try writer.writeAll("PENDING"),
        }

        try writer.writeAll("]");

        if (self.status == .active) {
            try writer.print(" (logins: {d})", .{self.login_count});
        }
    }
};

test "conditional formatting" {
    const active_acc = Account{
        .username = "alice",
        .status = .active,
        .login_count = 42,
    };

    const inactive_acc = Account{
        .username = "bob",
        .status = .inactive,
        .login_count = 0,
    };

    var buf: [100]u8 = undefined;

    const active_str = try std.fmt.bufPrint(&buf, "{}", .{active_acc});
    try std.testing.expectEqualStrings("alice [ACTIVE] (logins: 42)", active_str);

    const inactive_str = try std.fmt.bufPrint(&buf, "{}", .{inactive_acc});
    try std.testing.expectEqualStrings("bob [INACTIVE]", inactive_str);
}
```

### Using Format Options

Respect width and precision:

```zig
const Temperature = struct {
    celsius: f32,

    pub fn format(
        self: Temperature,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;

        const precision = options.precision orelse 1;

        switch (precision) {
            0 => try writer.print("{d}°C", .{@as(i32, @intFromFloat(self.celsius))}),
            1 => try writer.print("{d:.1}°C", .{self.celsius}),
            else => try writer.print("{d:.2}°C", .{self.celsius}),
        }
    }
};

test "format options" {
    const temp = Temperature{ .celsius = 23.456 };

    var buf: [100]u8 = undefined;

    const default_fmt = try std.fmt.bufPrint(&buf, "{}", .{temp});
    try std.testing.expectEqualStrings("23.5°C", default_fmt);

    const precise = try std.fmt.bufPrint(&buf, "{.2}", .{temp});
    try std.testing.expectEqualStrings("23.46°C", precise);
}
```

### Best Practices

**Zig 0.15.2 Format Signature:**
```zig
// Correct signature for Zig 0.15.2
pub fn format(self: @This(), writer: anytype) !void {
    try writer.print("...", .{...});
}

// Call with {f} format specifier
const result = try std.fmt.bufPrint(&buf, "{f}", .{instance});

// Use {any} for default struct debug representation
const debug = try std.fmt.bufPrint(&buf, "{any}", .{instance});
```

**Error Handling:**
- Always return `!void` for writer errors
- Use `try` for all writer operations
- No need to catch errors - let them propagate

**Performance:**
```zig
// Good: Direct writing
try writer.writeAll("Point(");
try writer.print("{d}", .{self.x});
try writer.writeAll(")");

// Avoid: Multiple allocations
const str = try std.fmt.allocPrint(allocator, "Point({d})", .{self.x});
defer allocator.free(str);
try writer.writeAll(str);
```

**Format Specifiers:**
- Document custom format specifiers
- Use empty string `""` for default formatting
- Check with `std.mem.eql(u8, fmt, "specifier")`

**Testing:**
```zig
// Always test formatting
test "format" {
    var buf: [100]u8 = undefined;
    const result = try std.fmt.bufPrint(&buf, "{}", .{instance});
    try std.testing.expectEqualStrings("expected", result);
}
```

### Related Functions

- `std.fmt.format()` - Core formatting function
- `std.fmt.bufPrint()` - Format to fixed buffer
- `std.fmt.allocPrint()` - Format with allocation
- `std.fmt.FormatOptions` - Formatting options struct
- `std.io.Writer` - Generic writer interface
