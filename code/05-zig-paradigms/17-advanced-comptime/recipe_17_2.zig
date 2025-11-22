// Recipe 17.2: Compile-Time String Processing and Code Generation
// This recipe demonstrates how to build DSLs and generate code from compile-time
// strings, parse format strings, and create sophisticated compile-time string
// manipulation utilities.

const std = @import("std");
const testing = std.testing;
const fmt = std.fmt;

// ANCHOR: basic_comptime_print
/// Generate strings at compile time using comptimePrint
fn makeTypeName(comptime base: []const u8, comptime id: u32) []const u8 {
    return comptime fmt.comptimePrint("{s}_{d}", .{ base, id });
}

test "basic comptime print" {
    const name1 = makeTypeName("Widget", 1);
    const name2 = makeTypeName("Widget", 2);

    try testing.expectEqualStrings("Widget_1", name1);
    try testing.expectEqualStrings("Widget_2", name2);
}
// ANCHOR_END: basic_comptime_print

// ANCHOR: string_parsing
/// Parse a simple key=value format at compile time
fn parseKeyValue(comptime input: []const u8) struct { key: []const u8, value: []const u8 } {
    comptime {
        var eq_pos: ?usize = null;
        for (input, 0..) |char, i| {
            if (char == '=') {
                eq_pos = i;
                break;
            }
        }

        if (eq_pos) |pos| {
            return .{
                .key = input[0..pos],
                .value = input[pos + 1 ..],
            };
        } else {
            @compileError("Invalid key=value format: missing '=' separator");
        }
    }
}

test "compile-time string parsing" {
    const parsed = comptime parseKeyValue("name=Alice");

    try testing.expectEqualStrings("name", parsed.key);
    try testing.expectEqualStrings("Alice", parsed.value);

    const parsed2 = comptime parseKeyValue("count=42");
    try testing.expectEqualStrings("count", parsed2.key);
    try testing.expectEqualStrings("42", parsed2.value);
}
// ANCHOR_END: string_parsing

// ANCHOR: field_name_generator
/// Generate field names based on a pattern
fn generateFieldNames(comptime prefix: []const u8, comptime count: usize) [count][]const u8 {
    comptime {
        var names: [count][]const u8 = undefined;
        for (0..count) |i| {
            names[i] = fmt.comptimePrint("{s}{d}", .{ prefix, i });
        }
        return names;
    }
}

test "field name generation" {
    const field_names = comptime generateFieldNames("field", 3);

    try testing.expectEqual(3, field_names.len);
    try testing.expectEqualStrings("field0", field_names[0]);
    try testing.expectEqualStrings("field1", field_names[1]);
    try testing.expectEqualStrings("field2", field_names[2]);
}
// ANCHOR_END: field_name_generator

// ANCHOR: sql_builder
/// Build SQL queries at compile time with basic validation
fn buildSelectQuery(
    comptime table: []const u8,
    comptime columns: []const []const u8,
    comptime where_clause: ?[]const u8,
) []const u8 {
    comptime {
        if (table.len == 0) {
            @compileError("Table name cannot be empty");
        }

        if (columns.len == 0) {
            @compileError("Must select at least one column");
        }

        // Build column list
        var col_list: []const u8 = columns[0];
        for (columns[1..]) |col| {
            col_list = col_list ++ ", " ++ col;
        }

        // Build complete query
        if (where_clause) |clause| {
            return fmt.comptimePrint("SELECT {s} FROM {s} WHERE {s}", .{ col_list, table, clause });
        } else {
            return fmt.comptimePrint("SELECT {s} FROM {s}", .{ col_list, table });
        }
    }
}

test "SQL query builder" {
    const query1 = comptime buildSelectQuery(
        "users",
        &[_][]const u8{ "id", "name", "email" },
        null,
    );
    try testing.expectEqualStrings("SELECT id, name, email FROM users", query1);

    const query2 = comptime buildSelectQuery(
        "products",
        &[_][]const u8{ "id", "price" },
        "price > 100",
    );
    try testing.expectEqualStrings("SELECT id, price FROM products WHERE price > 100", query2);
}
// ANCHOR_END: sql_builder

// ANCHOR: format_parser
/// Parse format strings at compile time and validate them
fn parseFormat(comptime format: []const u8) struct {
    placeholders: usize,
    has_precision: bool,
} {
    comptime {
        var placeholders: usize = 0;
        var has_precision = false;
        var i: usize = 0;

        while (i < format.len) : (i += 1) {
            if (format[i] == '{') {
                if (i + 1 < format.len and format[i + 1] != '{') {
                    placeholders += 1;

                    // Check for precision specifier
                    var j = i + 1;
                    while (j < format.len and format[j] != '}') : (j += 1) {
                        if (format[j] == '.') {
                            has_precision = true;
                        }
                    }

                    i = j;
                }
            }
        }

        return .{
            .placeholders = placeholders,
            .has_precision = has_precision,
        };
    }
}

test "format string parsing" {
    const fmt1 = comptime parseFormat("Hello, {s}!");
    try testing.expectEqual(1, fmt1.placeholders);
    try testing.expect(!fmt1.has_precision);

    const fmt2 = comptime parseFormat("Value: {d:.2}");
    try testing.expectEqual(1, fmt2.placeholders);
    try testing.expect(fmt2.has_precision);

    const fmt3 = comptime parseFormat("Multiple: {s} and {d} values");
    try testing.expectEqual(2, fmt3.placeholders);
}
// ANCHOR_END: format_parser

// ANCHOR: enum_from_strings
/// Generate an enum from compile-time string list
fn makeEnum(comptime strings: []const []const u8) type {
    comptime {
        // Create enum fields
        var fields: [strings.len]std.builtin.Type.EnumField = undefined;
        for (strings, 0..) |str, i| {
            // Add sentinel terminator for field name
            const name = str ++ "";
            fields[i] = .{
                .name = name[0..str.len :0],
                .value = i,
            };
        }

        return @Type(.{
            .@"enum" = .{
                .tag_type = std.math.IntFittingRange(0, strings.len - 1),
                .fields = &fields,
                .decls = &[_]std.builtin.Type.Declaration{},
                .is_exhaustive = true,
            },
        });
    }
}

test "enum generation from strings" {
    const Color = makeEnum(&[_][]const u8{ "red", "green", "blue" });

    const red = Color.red;
    const green = Color.green;
    const blue = Color.blue;

    try testing.expectEqual(Color.red, red);
    try testing.expectEqual(Color.green, green);
    try testing.expectEqual(Color.blue, blue);
}
// ANCHOR_END: enum_from_strings

// ANCHOR: identifier_validation
/// Validate that a string is a valid Zig identifier at compile time
fn isValidIdentifier(comptime name: []const u8) bool {
    if (name.len == 0) return false;

    // First character must be letter or underscore
    const first = name[0];
    if (!std.ascii.isAlphabetic(first) and first != '_') {
        return false;
    }

    // Remaining characters must be alphanumeric or underscore
    for (name[1..]) |char| {
        if (!std.ascii.isAlphanumeric(char) and char != '_') {
            return false;
        }
    }

    return true;
}

fn requireValidIdentifier(comptime name: []const u8) void {
    if (!isValidIdentifier(name)) {
        @compileError("Invalid identifier: '" ++ name ++ "'");
    }
}

test "identifier validation" {
    try testing.expect(isValidIdentifier("hello"));
    try testing.expect(isValidIdentifier("_private"));
    try testing.expect(isValidIdentifier("value123"));
    try testing.expect(isValidIdentifier("snake_case"));

    try testing.expect(!isValidIdentifier(""));
    try testing.expect(!isValidIdentifier("123start"));
    try testing.expect(!isValidIdentifier("has-dash"));
    try testing.expect(!isValidIdentifier("has space"));
}
// ANCHOR_END: identifier_validation

// ANCHOR: string_concatenation
/// Compile-time string concatenation utilities
fn concat(comptime strings: []const []const u8) []const u8 {
    comptime {
        var result: []const u8 = "";
        for (strings) |s| {
            result = result ++ s;
        }
        return result;
    }
}

fn join(comptime strings: []const []const u8, comptime separator: []const u8) []const u8 {
    comptime {
        if (strings.len == 0) return "";
        if (strings.len == 1) return strings[0];

        var result: []const u8 = strings[0];
        for (strings[1..]) |s| {
            result = result ++ separator ++ s;
        }
        return result;
    }
}

test "compile-time string operations" {
    const hello = comptime concat(&[_][]const u8{ "Hello", ", ", "World", "!" });
    try testing.expectEqualStrings("Hello, World!", hello);

    const path = comptime join(&[_][]const u8{ "usr", "local", "bin" }, "/");
    try testing.expectEqualStrings("usr/local/bin", path);

    const csv = comptime join(&[_][]const u8{ "a", "b", "c" }, ", ");
    try testing.expectEqualStrings("a, b, c", csv);
}
// ANCHOR_END: string_concatenation

// ANCHOR: code_generator
/// Generate getter and setter method names
fn makeAccessors(comptime field_name: []const u8) struct {
    getter: []const u8,
    setter: []const u8,
} {
    comptime {
        requireValidIdentifier(field_name);

        // Capitalize first letter for getter/setter
        var capitalized: [field_name.len]u8 = undefined;
        @memcpy(&capitalized, field_name);
        if (capitalized.len > 0 and std.ascii.isLower(capitalized[0])) {
            capitalized[0] = std.ascii.toUpper(capitalized[0]);
        }

        return .{
            .getter = fmt.comptimePrint("get{s}", .{capitalized}),
            .setter = fmt.comptimePrint("set{s}", .{capitalized}),
        };
    }
}

test "accessor name generation" {
    const accessors = comptime makeAccessors("name");

    try testing.expectEqualStrings("getName", accessors.getter);
    try testing.expectEqualStrings("setName", accessors.setter);

    const accessors2 = comptime makeAccessors("value");
    try testing.expectEqualStrings("getValue", accessors2.getter);
    try testing.expectEqualStrings("setValue", accessors2.setter);
}
// ANCHOR_END: code_generator
