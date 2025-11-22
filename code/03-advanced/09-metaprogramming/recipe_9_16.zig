// Recipe 9.16: Defining Structs Programmatically
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to create struct types at compile time using @Type.
// All struct generation happens during compilation with zero runtime overhead.

const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");

// ANCHOR: basic_struct_creation
// Create a simple struct type programmatically
fn createSimpleStruct() type {
    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &[_]std.builtin.Type.StructField{
                .{
                    .name = "x",
                    .type = i32,
                    .default_value_ptr = null,
                    .is_comptime = false,
                    .alignment = @alignOf(i32),
                },
                .{
                    .name = "y",
                    .type = i32,
                    .default_value_ptr = null,
                    .is_comptime = false,
                    .alignment = @alignOf(i32),
                },
            },
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

test "basic struct creation" {
    const Point = createSimpleStruct();
    const p = Point{ .x = 10, .y = 20 };

    try testing.expectEqual(@as(i32, 10), p.x);
    try testing.expectEqual(@as(i32, 20), p.y);
}
// ANCHOR_END: basic_struct_creation

// ANCHOR: add_fields
// Generate a struct with a variable number of fields
fn createFieldsStruct(comptime count: usize, comptime T: type) type {
    var fields: [count]std.builtin.Type.StructField = undefined;

    for (0..count) |i| {
        const name = std.fmt.comptimePrint("field_{d}", .{i});
        fields[i] = .{
            .name = name,
            .type = T,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(T),
        };
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &fields,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

test "add fields" {
    const ThreeInts = createFieldsStruct(3, i32);
    const data = ThreeInts{
        .field_0 = 1,
        .field_1 = 2,
        .field_2 = 3,
    };

    try testing.expectEqual(@as(i32, 1), data.field_0);
    try testing.expectEqual(@as(i32, 2), data.field_1);
    try testing.expectEqual(@as(i32, 3), data.field_2);
}
// ANCHOR_END: add_fields

// ANCHOR: struct_from_tuples
// Create a struct from a tuple of name-type pairs
fn structFromPairs(comptime pairs: anytype) type {
    const fields_tuple = @typeInfo(@TypeOf(pairs)).@"struct".fields;
    var fields: [fields_tuple.len]std.builtin.Type.StructField = undefined;

    inline for (fields_tuple, 0..) |field, i| {
        const pair = @field(pairs, field.name);
        fields[i] = .{
            .name = pair[0],
            .type = pair[1],
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(pair[1]),
        };
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &fields,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

test "struct from tuples" {
    const Person = structFromPairs(.{
        .{ "name", []const u8 },
        .{ "age", u32 },
        .{ "active", bool },
    });

    const person = Person{
        .name = "Alice",
        .age = 30,
        .active = true,
    };

    try testing.expectEqualStrings("Alice", person.name);
    try testing.expectEqual(@as(u32, 30), person.age);
    try testing.expect(person.active);
}
// ANCHOR_END: struct_from_tuples

// ANCHOR: merge_structs
// Merge two struct types into one
// Note: Produces compile error if both structs have fields with the same name
fn mergeStructs(comptime A: type, comptime B: type) type {
    const a_fields = @typeInfo(A).@"struct".fields;
    const b_fields = @typeInfo(B).@"struct".fields;

    // Check for name collisions
    inline for (a_fields) |a_field| {
        inline for (b_fields) |b_field| {
            if (std.mem.eql(u8, a_field.name, b_field.name)) {
                @compileError("Cannot merge structs: field '" ++ a_field.name ++ "' exists in both types");
            }
        }
    }

    var merged: [a_fields.len + b_fields.len]std.builtin.Type.StructField = undefined;

    inline for (a_fields, 0..) |field, i| {
        merged[i] = field;
    }

    inline for (b_fields, 0..) |field, i| {
        merged[a_fields.len + i] = field;
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &merged,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

test "merge structs" {
    const Position = struct { x: i32, y: i32 };
    const Velocity = struct { dx: f32, dy: f32 };

    const Entity = mergeStructs(Position, Velocity);

    const entity = Entity{
        .x = 10,
        .y = 20,
        .dx = 1.5,
        .dy = 2.5,
    };

    try testing.expectEqual(@as(i32, 10), entity.x);
    try testing.expectEqual(@as(i32, 20), entity.y);
    try testing.expectEqual(@as(f32, 1.5), entity.dx);
    try testing.expectEqual(@as(f32, 2.5), entity.dy);
}
// ANCHOR_END: merge_structs

// ANCHOR: filter_fields
// Create a new struct with only fields matching a predicate
fn filterFields(comptime T: type, comptime predicate: fn (std.builtin.Type.StructField) bool) type {
    const fields = @typeInfo(T).@"struct".fields;

    comptime var count: usize = 0;
    inline for (fields) |field| {
        if (predicate(field)) {
            count += 1;
        }
    }

    var filtered: [count]std.builtin.Type.StructField = undefined;
    comptime var index: usize = 0;
    inline for (fields) |field| {
        if (predicate(field)) {
            filtered[index] = field;
            index += 1;
        }
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &filtered,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

fn isIntegerField(field: std.builtin.Type.StructField) bool {
    return @typeInfo(field.type) == .int or @typeInfo(field.type) == .comptime_int;
}

test "filter fields" {
    const Mixed = struct {
        id: u64,
        name: []const u8,
        count: i32,
        active: bool,
    };

    const IntegersOnly = filterFields(Mixed, isIntegerField);

    const data = IntegersOnly{
        .id = 1,
        .count = 42,
    };

    try testing.expectEqual(@as(u64, 1), data.id);
    try testing.expectEqual(@as(i32, 42), data.count);
}
// ANCHOR_END: filter_fields

// ANCHOR: add_prefix
// Add a prefix to all field names
fn prefixFields(comptime T: type, comptime prefix: []const u8) type {
    const fields = @typeInfo(T).@"struct".fields;
    var prefixed: [fields.len]std.builtin.Type.StructField = undefined;

    inline for (fields, 0..) |field, i| {
        prefixed[i] = .{
            .name = prefix ++ field.name,
            .type = field.type,
            .default_value_ptr = null,
            .is_comptime = field.is_comptime,
            .alignment = field.alignment,
        };
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &prefixed,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

test "add prefix" {
    const Original = struct {
        name: []const u8,
        value: i32,
    };

    const Prefixed = prefixFields(Original, "my_");

    const data = Prefixed{
        .my_name = "test",
        .my_value = 42,
    };

    try testing.expectEqualStrings("test", data.my_name);
    try testing.expectEqual(@as(i32, 42), data.my_value);
}
// ANCHOR_END: add_prefix

// ANCHOR: optional_wrapper
// Wrap all fields in Optional
fn makeFieldsOptional(comptime T: type) type {
    const fields = @typeInfo(T).@"struct".fields;
    var optional_fields: [fields.len]std.builtin.Type.StructField = undefined;

    inline for (fields, 0..) |field, i| {
        optional_fields[i] = .{
            .name = field.name,
            .type = ?field.type,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(?field.type),
        };
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &optional_fields,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

test "optional wrapper" {
    const Required = struct {
        name: []const u8,
        age: u32,
    };

    const Optional = makeFieldsOptional(Required);

    const partial = Optional{
        .name = "Alice",
        .age = null,
    };

    try testing.expectEqualStrings("Alice", partial.name.?);
    try testing.expectEqual(@as(?u32, null), partial.age);
}
// ANCHOR_END: optional_wrapper

// ANCHOR: select_fields
// Create a struct with only specific fields
// Note: Produces compile error if any field_name doesn't exist in T
fn selectFields(comptime T: type, comptime field_names: []const []const u8) type {
    const all_fields = @typeInfo(T).@"struct".fields;
    var selected: [field_names.len]std.builtin.Type.StructField = undefined;

    inline for (field_names, 0..) |name, i| {
        var found = false;
        inline for (all_fields) |field| {
            if (std.mem.eql(u8, field.name, name)) {
                selected[i] = field;
                found = true;
                break;
            }
        }
        if (!found) {
            @compileError("Field '" ++ name ++ "' not found in type " ++ @typeName(T));
        }
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &selected,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

test "select fields" {
    const Full = struct {
        id: u64,
        name: []const u8,
        email: []const u8,
        age: u32,
        active: bool,
    };

    const Partial = selectFields(Full, &[_][]const u8{ "id", "name", "active" });

    const data = Partial{
        .id = 1,
        .name = "Alice",
        .active = true,
    };

    try testing.expectEqual(@as(u64, 1), data.id);
    try testing.expectEqualStrings("Alice", data.name);
    try testing.expect(data.active);
}
// ANCHOR_END: select_fields

// Comprehensive test
test "comprehensive struct generation" {
    // Basic creation
    const Basic = createSimpleStruct();
    const b = Basic{ .x = 1, .y = 2 };
    try testing.expectEqual(@as(i32, 1), b.x);

    // Variable fields
    const Multi = createFieldsStruct(2, u32);
    const m = Multi{ .field_0 = 10, .field_1 = 20 };
    try testing.expectEqual(@as(u32, 10), m.field_0);

    // From tuples
    const FromTuples = structFromPairs(.{
        .{ "a", i32 },
        .{ "b", bool },
    });
    const ft = FromTuples{ .a = 5, .b = true };
    try testing.expectEqual(@as(i32, 5), ft.a);

    // Merged structs
    const A = struct { x: i32 };
    const B = struct { y: i32 };
    const Merged = mergeStructs(A, B);
    const merged = Merged{ .x = 1, .y = 2 };
    try testing.expectEqual(@as(i32, 1), merged.x);

    // Prefixed fields
    const Orig = struct { val: i32 };
    const Pre = prefixFields(Orig, "p_");
    const pre = Pre{ .p_val = 99 };
    try testing.expectEqual(@as(i32, 99), pre.p_val);

    // Optional fields
    const Req = struct { x: i32 };
    const Opt = makeFieldsOptional(Req);
    const opt = Opt{ .x = null };
    try testing.expectEqual(@as(?i32, null), opt.x);

    try testing.expect(true);
}
