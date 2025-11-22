// Recipe 0.10: Structs, Enums, and Simple Data Models
// Target Zig Version: 0.15.2
//
// This recipe covers creating custom types with structs, enums,
// and tagged unions for simple data modeling.

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_structs
// Part 1: Basic Structs
//
// Structs group related data together

test "defining and using structs" {
    const Point = struct {
        x: i32,
        y: i32,
    };

    // Create an instance
    const p1 = Point{ .x = 10, .y = 20 };

    try testing.expectEqual(@as(i32, 10), p1.x);
    try testing.expectEqual(@as(i32, 20), p1.y);

    // Mutable instance
    var p2 = Point{ .x = 5, .y = 15 };
    p2.x = 100;
    try testing.expectEqual(@as(i32, 100), p2.x);
}

test "struct with default field values" {
    const Config = struct {
        host: []const u8 = "localhost",
        port: u16 = 8080,
        debug: bool = false,
    };

    // Use defaults
    const config1 = Config{};
    try testing.expect(std.mem.eql(u8, config1.host, "localhost"));
    try testing.expectEqual(@as(u16, 8080), config1.port);
    try testing.expectEqual(false, config1.debug);

    // Override some defaults
    const config2 = Config{ .port = 3000, .debug = true };
    try testing.expect(std.mem.eql(u8, config2.host, "localhost"));
    try testing.expectEqual(@as(u16, 3000), config2.port);
    try testing.expectEqual(true, config2.debug);
}

test "struct methods" {
    const Rectangle = struct {
        width: i32,
        height: i32,

        fn area(self: @This()) i32 {
            return self.width * self.height;
        }

        fn perimeter(self: @This()) i32 {
            return 2 * (self.width + self.height);
        }

        fn scale(self: *@This(), factor: i32) void {
            self.width *= factor;
            self.height *= factor;
        }
    };

    var rect = Rectangle{ .width = 10, .height = 5 };

    try testing.expectEqual(@as(i32, 50), rect.area());
    try testing.expectEqual(@as(i32, 30), rect.perimeter());

    rect.scale(2);
    try testing.expectEqual(@as(i32, 20), rect.width);
    try testing.expectEqual(@as(i32, 10), rect.height);
}

test "constructor patterns" {
    const Person = struct {
        name: []const u8,
        age: u8,

        fn init(name: []const u8, age: u8) @This() {
            return .{
                .name = name,
                .age = age,
            };
        }

        fn describe(self: @This()) void {
            std.debug.print("{s} is {d} years old\n", .{ self.name, self.age });
        }
    };

    const person = Person.init("Alice", 30);
    try testing.expect(std.mem.eql(u8, person.name, "Alice"));
    try testing.expectEqual(@as(u8, 30), person.age);

    person.describe();
}
// ANCHOR_END: basic_structs

// ANCHOR: enums
// Part 2: Enums
//
// Enums define a set of named values

test "basic enums" {
    const Color = enum {
        red,
        green,
        blue,
    };

    const c1: Color = .red;
    const c2: Color = .green;

    try testing.expect(c1 == .red);
    try testing.expect(c2 == .green);
    try testing.expect(c1 != c2);
}

test "enums with explicit values" {
    const StatusCode = enum(u16) {
        ok = 200,
        not_found = 404,
        server_error = 500,
    };

    const code: StatusCode = .ok;

    // Convert to integer
    const value = @intFromEnum(code);
    try testing.expectEqual(@as(u16, 200), value);

    // Convert from integer
    const from_int = @as(StatusCode, @enumFromInt(404));
    try testing.expect(from_int == .not_found);
}

test "switch on enums" {
    const Direction = enum {
        north,
        south,
        east,
        west,
    };

    const dir: Direction = .north;

    const result = switch (dir) {
        .north => "Going up",
        .south => "Going down",
        .east => "Going right",
        .west => "Going left",
    };

    try testing.expect(std.mem.eql(u8, result, "Going up"));
}

test "enum methods" {
    const LogLevel = enum {
        debug,
        info,
        warning,
        err,

        fn toString(self: @This()) []const u8 {
            return switch (self) {
                .debug => "DEBUG",
                .info => "INFO",
                .warning => "WARNING",
                .err => "ERROR",
            };
        }

        fn isError(self: @This()) bool {
            return self == .err;
        }
    };

    const level: LogLevel = .warning;
    try testing.expect(std.mem.eql(u8, level.toString(), "WARNING"));
    try testing.expectEqual(false, level.isError());

    const error_level: LogLevel = .err;
    try testing.expectEqual(true, error_level.isError());
}
// ANCHOR_END: enums

// ANCHOR: tagged_unions
// Part 3: Tagged Unions - Variant Types
//
// Tagged unions let you store different types in the same variable

test "basic tagged unions" {
    const Value = union(enum) {
        int: i32,
        float: f32,
        boolean: bool,
    };

    // Create different variants
    const v1 = Value{ .int = 42 };
    const v2 = Value{ .float = 3.14 };
    const v3 = Value{ .boolean = true };

    // Access with switch
    switch (v1) {
        .int => |val| try testing.expectEqual(@as(i32, 42), val),
        .float => unreachable,
        .boolean => unreachable,
    }

    switch (v2) {
        .int => unreachable,
        .float => |val| try testing.expect(@abs(val - 3.14) < 0.01),
        .boolean => unreachable,
    }

    switch (v3) {
        .int => unreachable,
        .float => unreachable,
        .boolean => |val| try testing.expectEqual(true, val),
    }
}

test "tagged union with methods" {
    const Shape = union(enum) {
        circle: struct { radius: f32 },
        rectangle: struct { width: f32, height: f32 },
        triangle: struct { base: f32, height: f32 },

        fn area(self: @This()) f32 {
            return switch (self) {
                .circle => |c| std.math.pi * c.radius * c.radius,
                .rectangle => |r| r.width * r.height,
                .triangle => |t| 0.5 * t.base * t.height,
            };
        }
    };

    const circle = Shape{ .circle = .{ .radius = 5.0 } };
    const rect = Shape{ .rectangle = .{ .width = 10.0, .height = 5.0 } };
    const tri = Shape{ .triangle = .{ .base = 8.0, .height = 6.0 } };

    try testing.expect(@abs(circle.area() - 78.54) < 0.1);
    try testing.expect(@abs(rect.area() - 50.0) < 0.01);
    try testing.expect(@abs(tri.area() - 24.0) < 0.01);
}

test "tagged union pattern matching" {
    const Result = union(enum) {
        ok: i32,
        err: []const u8,

        fn isOk(self: @This()) bool {
            return switch (self) {
                .ok => true,
                .err => false,
            };
        }

        fn unwrap(self: @This()) !i32 {
            return switch (self) {
                .ok => |val| val,
                .err => |msg| {
                    std.debug.print("Error: {s}\n", .{msg});
                    return error.Failed;
                },
            };
        }
    };

    const success = Result{ .ok = 42 };
    try testing.expectEqual(true, success.isOk());
    const value = try success.unwrap();
    try testing.expectEqual(@as(i32, 42), value);

    const failure = Result{ .err = "Something went wrong" };
    try testing.expectEqual(false, failure.isOk());
    const err = failure.unwrap();
    try testing.expectError(error.Failed, err);
}
// ANCHOR_END: tagged_unions

// Public vs Private

test "public vs private members" {
    const Counter = struct {
        // Private field (default)
        count: i32 = 0,

        // Public function
        pub fn increment(self: *@This()) void {
            self.count += 1;
        }

        pub fn get(self: @This()) i32 {
            return self.count;
        }

        // Private function
        fn reset(self: *@This()) void {
            self.count = 0;
        }

        pub fn resetPublic(self: *@This()) void {
            self.reset();
        }
    };

    var counter = Counter{};
    counter.increment();
    try testing.expectEqual(@as(i32, 1), counter.get());

    counter.resetPublic();
    try testing.expectEqual(@as(i32, 0), counter.get());
}

// Nested structs

test "nested structs" {
    const Company = struct {
        const Employee = struct {
            name: []const u8,
            salary: u32,
        };

        name: []const u8,
        employees: []const Employee,

        fn totalSalary(self: @This()) u32 {
            var total: u32 = 0;
            for (self.employees) |emp| {
                total += emp.salary;
            }
            return total;
        }
    };

    const employees = [_]Company.Employee{
        .{ .name = "Alice", .salary = 50000 },
        .{ .name = "Bob", .salary = 60000 },
    };

    const company = Company{
        .name = "Acme Corp",
        .employees = &employees,
    };

    try testing.expectEqual(@as(u32, 110000), company.totalSalary());
}

// Complete example

test "putting it all together" {
    const User = struct {
        const Role = enum {
            admin,
            moderator,
            user,

            fn canDelete(self: @This()) bool {
                return switch (self) {
                    .admin, .moderator => true,
                    .user => false,
                };
            }
        };

        id: u32,
        name: []const u8,
        role: Role,

        fn init(id: u32, name: []const u8, role: Role) @This() {
            return .{
                .id = id,
                .name = name,
                .role = role,
            };
        }

        fn describe(self: @This()) void {
            const role_str = switch (self.role) {
                .admin => "Admin",
                .moderator => "Moderator",
                .user => "User",
            };
            std.debug.print("User #{d}: {s} ({s})\n", .{ self.id, self.name, role_str });
        }
    };

    const admin = User.init(1, "Alice", .admin);
    const user = User.init(2, "Bob", .user);

    try testing.expectEqual(true, admin.role.canDelete());
    try testing.expectEqual(false, user.role.canDelete());

    admin.describe();
    user.describe();
}

// Summary:
// - Structs group related data with optional default values
// - Methods use `self: @This()` or `self: *@This()` for modification
// - Enums define a set of named constants
// - Tagged unions (union(enum)) store different types
// - Use switch to handle tagged union variants
// - `pub` makes members visible outside the file
// - Nested types keep related definitions together
