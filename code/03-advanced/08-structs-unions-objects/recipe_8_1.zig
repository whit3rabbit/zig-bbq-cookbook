const std = @import("std");

// ANCHOR: basic_format
/// Basic point with custom formatting
const Point = struct {
    x: f32,
    y: f32,

    pub fn format(self: Point, writer: anytype) !void {
        try writer.print("Point({d:.2}, {d:.2})", .{ self.x, self.y });
    }
};
// ANCHOR_END: basic_format

/// Person with name and age
const Person = struct {
    name: []const u8,
    age: u32,

    pub fn format(self: Person, writer: anytype) !void {
        try writer.print("{s} (age {d})", .{ self.name, self.age });
    }
};

/// Rectangle with helper methods
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

// ANCHOR: multiple_formats
/// User with simple formatting
const User = struct {
    id: u64,
    username: []const u8,
    email: []const u8,

    pub fn format(self: User, writer: anytype) !void {
        try writer.print("{s} ({s})", .{ self.username, self.email });
    }

    pub fn formatDebug(self: User, writer: anytype) !void {
        try writer.print("User{{ id={d}, username=\"{s}\", email=\"{s}\" }}", .{
            self.id,
            self.username,
            self.email,
        });
    }
};
// ANCHOR_END: multiple_formats

/// Nested structures
const Address = struct {
    street: []const u8,
    city: []const u8,

    pub fn format(self: Address, writer: anytype) !void {
        try writer.print("{s}, {s}", .{ self.street, self.city });
    }
};

const Employee = struct {
    name: []const u8,
    address: Address,

    pub fn format(self: Employee, writer: anytype) !void {
        try writer.print("{s} @ {f}", .{ self.name, self.address });
    }
};

/// Vector with array formatting
const Vector3 = struct {
    data: [3]f32,

    pub fn format(self: Vector3, writer: anytype) !void {
        try writer.print("({d:.2}, {d:.2}, {d:.2})", .{
            self.data[0],
            self.data[1],
            self.data[2],
        });
    }
};

// ANCHOR: union_formatting
/// Tagged union formatting
const Shape = union(enum) {
    circle: struct { radius: f32 },
    rectangle: struct { width: f32, height: f32 },
    triangle: struct { base: f32, height: f32 },

    pub fn format(self: Shape, writer: anytype) !void {
        switch (self) {
            .circle => |c| try writer.print("Circle(r={d:.2})", .{c.radius}),
            .rectangle => |r| try writer.print("Rectangle({d:.2}x{d:.2})", .{ r.width, r.height }),
            .triangle => |t| try writer.print("Triangle(b={d:.2}, h={d:.2})", .{ t.base, t.height }),
        }
    }
};
// ANCHOR_END: union_formatting

/// Config with compact formatting
const Config = struct {
    host: []const u8,
    port: u16,
    timeout_ms: u32,

    pub fn format(self: Config, writer: anytype) !void {
        try writer.print("Config{{ host=\"{s}\", port={d}, timeout_ms={d} }}", .{
            self.host,
            self.port,
            self.timeout_ms,
        });
    }

    pub fn formatPretty(self: Config, writer: anytype) !void {
        try writer.writeAll("Config {\n");
        try writer.print("  host: \"{s}\"\n", .{self.host});
        try writer.print("  port: {d}\n", .{self.port});
        try writer.print("  timeout_ms: {d}\n", .{self.timeout_ms});
        try writer.writeAll("}");
    }
};

/// Status enum
const Status = enum { active, inactive, pending };

/// Account with conditional formatting
const Account = struct {
    username: []const u8,
    status: Status,
    login_count: u32,

    pub fn format(self: Account, writer: anytype) !void {
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

/// Temperature with simple formatting
const Temperature = struct {
    celsius: f32,

    pub fn format(self: Temperature, writer: anytype) !void {
        try writer.print("{d:.1}°C", .{self.celsius});
    }

    pub fn formatPrecise(self: Temperature, writer: anytype) !void {
        try writer.print("{d:.2}°C", .{self.celsius});
    }
};

// Tests

test "custom string representation" {
    const p = Point{ .x = 3.14, .y = 2.71 };

    var buf: [100]u8 = undefined;
    const result = try std.fmt.bufPrint(&buf, "{f}", .{p});

    try std.testing.expectEqualStrings("Point(3.14, 2.71)", result);
}

test "basic format" {
    const person = Person{ .name = "Alice", .age = 30 };

    var buf: [100]u8 = undefined;
    const result = try std.fmt.bufPrint(&buf, "{f}", .{person});

    try std.testing.expectEqualStrings("Alice (age 30)", result);
}

test "format rectangle default" {
    const rect = Rectangle{ .width = 10.0, .height = 5.0 };

    var buf: [100]u8 = undefined;
    const default_fmt = try std.fmt.bufPrint(&buf, "{f}", .{rect});
    try std.testing.expectEqualStrings("Rectangle(10.00x5.00)", default_fmt);
}

test "rectangle area method" {
    const rect = Rectangle{ .width = 10.0, .height = 5.0 };
    try std.testing.expectEqual(@as(f32, 50.0), rect.area());
}

test "rectangle perimeter method" {
    const rect = Rectangle{ .width = 10.0, .height = 5.0 };
    try std.testing.expectEqual(@as(f32, 30.0), rect.perimeter());
}

test "user display format" {
    const user = User{
        .id = 12345,
        .username = "alice",
        .email = "alice@example.com",
    };

    var buf: [200]u8 = undefined;

    const display = try std.fmt.bufPrint(&buf, "{f}", .{user});
    try std.testing.expectEqualStrings("alice (alice@example.com)", display);
}

test "user debug format" {
    const user = User{
        .id = 12345,
        .username = "alice",
        .email = "alice@example.com",
    };

    var buf: [200]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try user.formatDebug(stream.writer());

    try std.testing.expectEqualStrings(
        "User{ id=12345, username=\"alice\", email=\"alice@example.com\" }",
        stream.getWritten(),
    );
}

test "nested formatting" {
    const emp = Employee{
        .name = "Bob",
        .address = Address{ .street = "123 Main St", .city = "Springfield" },
    };

    var buf: [200]u8 = undefined;
    const result = try std.fmt.bufPrint(&buf, "{f}", .{emp});

    try std.testing.expectEqualStrings("Bob @ 123 Main St, Springfield", result);
}

test "array formatting" {
    const v = Vector3{ .data = .{ 1.5, 2.5, 3.5 } };

    var buf: [100]u8 = undefined;
    const result = try std.fmt.bufPrint(&buf, "{f}", .{v});

    try std.testing.expectEqualStrings("(1.50, 2.50, 3.50)", result);
}

test "union formatting circle" {
    const circle = Shape{ .circle = .{ .radius = 5.0 } };

    var buf: [100]u8 = undefined;
    const c_str = try std.fmt.bufPrint(&buf, "{f}", .{circle});
    try std.testing.expectEqualStrings("Circle(r=5.00)", c_str);
}

test "union formatting rectangle" {
    const rect = Shape{ .rectangle = .{ .width = 10.0, .height = 5.0 } };

    var buf: [100]u8 = undefined;
    const r_str = try std.fmt.bufPrint(&buf, "{f}", .{rect});
    try std.testing.expectEqualStrings("Rectangle(10.00x5.00)", r_str);
}

test "config compact formatting" {
    const cfg = Config{
        .host = "localhost",
        .port = 8080,
        .timeout_ms = 5000,
    };

    var buf: [200]u8 = undefined;
    const compact = try std.fmt.bufPrint(&buf, "{f}", .{cfg});
    try std.testing.expectEqualStrings(
        "Config{ host=\"localhost\", port=8080, timeout_ms=5000 }",
        compact,
    );
}

test "config pretty formatting" {
    const cfg = Config{
        .host = "localhost",
        .port = 8080,
        .timeout_ms = 5000,
    };

    var buf: [200]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try cfg.formatPretty(stream.writer());

    const expected =
        \\Config {
        \\  host: "localhost"
        \\  port: 8080
        \\  timeout_ms: 5000
        \\}
    ;
    try std.testing.expectEqualStrings(expected, stream.getWritten());
}

test "conditional formatting active" {
    const active_acc = Account{
        .username = "alice",
        .status = .active,
        .login_count = 42,
    };

    var buf: [100]u8 = undefined;
    const active_str = try std.fmt.bufPrint(&buf, "{f}", .{active_acc});
    try std.testing.expectEqualStrings("alice [ACTIVE] (logins: 42)", active_str);
}

test "conditional formatting inactive" {
    const inactive_acc = Account{
        .username = "bob",
        .status = .inactive,
        .login_count = 0,
    };

    var buf: [100]u8 = undefined;
    const inactive_str = try std.fmt.bufPrint(&buf, "{f}", .{inactive_acc});
    try std.testing.expectEqualStrings("bob [INACTIVE]", inactive_str);
}

test "temperature default formatting" {
    const temp = Temperature{ .celsius = 23.456 };

    var buf: [100]u8 = undefined;
    const default_fmt = try std.fmt.bufPrint(&buf, "{f}", .{temp});
    try std.testing.expectEqualStrings("23.5°C", default_fmt);
}

test "temperature precise formatting" {
    const temp = Temperature{ .celsius = 23.456 };

    var buf: [100]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try temp.formatPrecise(stream.writer());
    try std.testing.expectEqualStrings("23.46°C", stream.getWritten());
}
