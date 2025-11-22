// Recipe 1.18: Mapping names to sequence elements
// Target Zig Version: 0.15.2
//
// This recipe demonstrates different approaches to naming and accessing
// elements in sequences: structs, tuples, and enums. Each has different
// trade-offs for different use cases.

const std = @import("std");
const testing = std.testing;

// APPROACH 1: Structs - Best for records with named fields
// Pros: Named fields, type safety, documentation, compiler errors for typos
// Cons: More verbose than tuples

// ANCHOR: named_structs
const Point2D = struct {
    x: f32,
    y: f32,

    pub fn distance(self: Point2D) f32 {
        return @sqrt(self.x * self.x + self.y * self.y);
    }
};

const Person = struct {
    name: []const u8,
    age: u32,
    email: []const u8,

    pub fn isAdult(self: Person) bool {
        return self.age >= 18;
    }
};
// ANCHOR_END: named_structs

// APPROACH 2: Anonymous Tuples - Best for temporary data
// Pros: Lightweight, no type declaration needed
// Cons: Positional access only, no named fields, less readable

// ANCHOR: anonymous_tuples
fn calculateStats(numbers: []const i32) struct { min: i32, max: i32, avg: f32 } {
    if (numbers.len == 0) return .{ .min = 0, .max = 0, .avg = 0 };

    var min = numbers[0];
    var max = numbers[0];
    var sum: i64 = 0;

    for (numbers) |n| {
        if (n < min) min = n;
        if (n > max) max = n;
        sum += n;
    }

    const avg = @as(f32, @floatFromInt(sum)) / @as(f32, @floatFromInt(numbers.len));
    return .{ .min = min, .max = max, .avg = avg };
}
// ANCHOR_END: anonymous_tuples

// APPROACH 3: Tagged Unions (Enums) - Best for variants
// Pros: Type-safe variants, exhaustive switching
// Cons: Only one active variant at a time

// ANCHOR: tagged_unions
const Shape = union(enum) {
    circle: struct { radius: f32 },
    rectangle: struct { width: f32, height: f32 },
    triangle: struct { base: f32, height: f32 },

    pub fn area(self: Shape) f32 {
        return switch (self) {
            .circle => |c| std.math.pi * c.radius * c.radius,
            .rectangle => |r| r.width * r.height,
            .triangle => |t| 0.5 * t.base * t.height,
        };
    }
};
// ANCHOR_END: tagged_unions

// APPROACH 4: Const-based naming for slices
// Pros: Zero runtime cost, works with existing arrays
// Cons: Still positional access, indices must be correct

const CSV_NAME = 0;
const CSV_AGE = 1;
const CSV_EMAIL = 2;

fn parseCSVRow(row: []const []const u8) ?Person {
    if (row.len < 3) return null;

    const age = std.fmt.parseInt(u32, row[CSV_AGE], 10) catch return null;

    return Person{
        .name = row[CSV_NAME],
        .age = age,
        .email = row[CSV_EMAIL],
    };
}

// APPROACH 5: Enum-indexed arrays - Type-safe indexing
// Pros: Prevents invalid indices, clear intent
// Cons: Requires enum definition

const ColorChannel = enum {
    red,
    green,
    blue,
    alpha,
};

const Color = struct {
    channels: [4]u8,

    pub fn get(self: Color, channel: ColorChannel) u8 {
        return self.channels[@intFromEnum(channel)];
    }

    pub fn set(self: *Color, channel: ColorChannel, value: u8) void {
        self.channels[@intFromEnum(channel)] = value;
    }
};

test "structs with named fields" {
    const p = Point2D{ .x = 3.0, .y = 4.0 };

    try testing.expectEqual(@as(f32, 3.0), p.x);
    try testing.expectEqual(@as(f32, 4.0), p.y);
    try testing.expectApproxEqAbs(@as(f32, 5.0), p.distance(), 0.001);
}

test "structs with methods" {
    const alice = Person{
        .name = "Alice",
        .age = 30,
        .email = "alice@example.com",
    };

    const bob = Person{
        .name = "Bob",
        .age = 16,
        .email = "bob@example.com",
    };

    try testing.expect(alice.isAdult());
    try testing.expect(!bob.isAdult());
    try testing.expectEqualStrings("Alice", alice.name);
}

test "anonymous tuple return values" {
    const numbers = [_]i32{ 1, 5, 3, 9, 2, 7 };
    const stats = calculateStats(&numbers);

    try testing.expectEqual(@as(i32, 1), stats.min);
    try testing.expectEqual(@as(i32, 9), stats.max);
    try testing.expectApproxEqAbs(@as(f32, 4.5), stats.avg, 0.001);
}

test "anonymous tuple for temporary data" {
    // Tuples are great for function returns without declaring a struct
    const result = .{ .success = true, .value = 42, .message = "OK" };

    try testing.expect(result.success);
    try testing.expectEqual(@as(i32, 42), result.value);
    try testing.expectEqualStrings("OK", result.message);
}

test "tagged unions for variants" {
    const shapes = [_]Shape{
        .{ .circle = .{ .radius = 5.0 } },
        .{ .rectangle = .{ .width = 4.0, .height = 6.0 } },
        .{ .triangle = .{ .base = 3.0, .height = 8.0 } },
    };

    try testing.expectApproxEqAbs(@as(f32, 78.54), shapes[0].area(), 0.01);
    try testing.expectApproxEqAbs(@as(f32, 24.0), shapes[1].area(), 0.01);
    try testing.expectApproxEqAbs(@as(f32, 12.0), shapes[2].area(), 0.01);
}

test "const-based naming for array indices" {
    const row = [_][]const u8{ "Alice", "30", "alice@example.com" };

    const person = parseCSVRow(&row).?;

    try testing.expectEqualStrings("Alice", person.name);
    try testing.expectEqual(@as(u32, 30), person.age);
    try testing.expectEqualStrings("alice@example.com", person.email);
}

test "enum-indexed arrays" {
    var color = Color{
        .channels = [_]u8{ 255, 128, 64, 255 },
    };

    try testing.expectEqual(@as(u8, 255), color.get(.red));
    try testing.expectEqual(@as(u8, 128), color.get(.green));
    try testing.expectEqual(@as(u8, 64), color.get(.blue));
    try testing.expectEqual(@as(u8, 255), color.get(.alpha));

    color.set(.green, 200);
    try testing.expectEqual(@as(u8, 200), color.get(.green));
}

test "comparison of approaches - readability" {
    // Struct: Most readable, named fields
    const p1 = Person{ .name = "Alice", .age = 30, .email = "alice@example.com" };
    try testing.expectEqualStrings("Alice", p1.name);

    // Tuple: Lightweight but less clear
    const p2 = .{ "Bob", @as(u32, 25), "bob@example.com" };
    try testing.expectEqualStrings("Bob", p2[0]);

    // Anonymous struct tuple (best of both)
    const p3 = .{ .name = "Charlie", .age = @as(u32, 35), .email = "charlie@example.com" };
    try testing.expectEqualStrings("Charlie", p3.name);
}

test "nested structs for complex data" {
    const Address = struct {
        street: []const u8,
        city: []const u8,
        zip: []const u8,
    };

    const Employee = struct {
        name: []const u8,
        id: u32,
        address: Address,
    };

    const emp = Employee{
        .name = "Alice",
        .id = 12345,
        .address = .{
            .street = "123 Main St",
            .city = "Springfield",
            .zip = "12345",
        },
    };

    try testing.expectEqualStrings("Springfield", emp.address.city);
    try testing.expectEqual(@as(u32, 12345), emp.id);
}

test "optional struct fields" {
    const OptionalPerson = struct {
        name: []const u8,
        age: u32,
        email: ?[]const u8, // Optional field

        pub fn hasEmail(self: @This()) bool {
            return self.email != null;
        }
    };

    const alice = OptionalPerson{
        .name = "Alice",
        .age = 30,
        .email = "alice@example.com",
    };

    const bob = OptionalPerson{
        .name = "Bob",
        .age = 25,
        .email = null,
    };

    try testing.expect(alice.hasEmail());
    try testing.expect(!bob.hasEmail());
}

test "memory safety - struct copying" {
    // Structs are value types and are copied
    const p1 = Point2D{ .x = 1.0, .y = 2.0 };
    var p2 = p1; // Copy
    p2.x = 5.0;

    try testing.expectEqual(@as(f32, 1.0), p1.x); // p1 unchanged
    try testing.expectEqual(@as(f32, 5.0), p2.x);
}
