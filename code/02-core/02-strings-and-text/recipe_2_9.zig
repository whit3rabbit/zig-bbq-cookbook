// Recipe 2.9: Interpolating variables in strings
// Target Zig Version: 0.15.2
//
// This recipe demonstrates string formatting and variable interpolation
// using std.fmt functions for building formatted strings.

const std = @import("std");
const testing = std.testing;
const fmt = std.fmt;
const mem = std.mem;

// ANCHOR: basic_formatting
/// Format a string with variables (allocates new string)
pub fn format(
    allocator: mem.Allocator,
    comptime format_string: []const u8,
    args: anytype,
) ![]u8 {
    return fmt.allocPrint(allocator, format_string, args);
}

/// Format into a fixed buffer (no allocation)
pub fn formatBuf(
    buffer: []u8,
    comptime format_string: []const u8,
    args: anytype,
) ![]u8 {
    return fmt.bufPrint(buffer, format_string, args);
}

/// Count format string size without allocating
pub fn formatCount(
    comptime format_string: []const u8,
    args: anytype,
) !usize {
    return fmt.count(format_string, args);
}
// ANCHOR_END: basic_formatting

test "basic string formatting" {
    const result = try format(testing.allocator, "Hello, {s}!", .{"World"});
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Hello, World!", result);
}

test "format multiple variables" {
    const name = "Alice";
    const age: u32 = 30;
    const result = try format(testing.allocator, "{s} is {d} years old", .{ name, age });
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Alice is 30 years old", result);
}

// ANCHOR: format_specifiers
test "format integers" {
    const result = try format(testing.allocator, "Number: {d}", .{42});
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Number: 42", result);
}

test "format floats" {
    const result = try format(testing.allocator, "Pi: {d:.2}", .{3.14159});
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Pi: 3.14", result);
}

test "format hexadecimal" {
    const result = try format(testing.allocator, "Hex: 0x{x}", .{255});
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Hex: 0xff", result);
}

test "format hexadecimal uppercase" {
    const result = try format(testing.allocator, "Hex: 0x{X}", .{255});
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Hex: 0xFF", result);
}

test "format octal" {
    const result = try format(testing.allocator, "Octal: {o}", .{64});
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Octal: 100", result);
}

test "format binary" {
    const result = try format(testing.allocator, "Binary: {b}", .{15});
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Binary: 1111", result);
}
// ANCHOR_END: format_specifiers

test "format boolean" {
    const result = try format(testing.allocator, "Value: {any}", .{true});
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Value: true", result);
}

test "format character" {
    const result = try format(testing.allocator, "Char: {c}", .{'A'});
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Char: A", result);
}

test "format pointer" {
    const value: u32 = 42;
    const ptr = &value;
    const result = try format(testing.allocator, "Pointer: {*}", .{ptr});
    defer testing.allocator.free(result);

    try testing.expect(result.len > 10); // Just check it formatted something
}

test "format with width" {
    const result = try format(testing.allocator, "Number: {d:5}", .{42});
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Number:    42", result);
}

test "format with zero padding" {
    const result = try format(testing.allocator, "Number: {d:0>5}", .{42});
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Number: 00042", result);
}

test "format multiple types" {
    const result = try format(
        testing.allocator,
        "String: {s}, Int: {d}, Float: {d:.1}, Hex: 0x{x}",
        .{ "test", 100, 3.14, 255 },
    );
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("String: test, Int: 100, Float: 3.1, Hex: 0xff", result);
}

test "format into buffer - no allocation" {
    var buffer: [100]u8 = undefined;
    const result = try formatBuf(&buffer, "Hello, {s}!", .{"World"});

    try testing.expectEqualStrings("Hello, World!", result);
}

test "format into buffer - exact size" {
    var buffer: [13]u8 = undefined;
    const result = try formatBuf(&buffer, "Hello, {s}!", .{"World"});

    try testing.expectEqualStrings("Hello, World!", result);
}

test "format count" {
    const size = try formatCount("Hello, {s}!", .{"World"});

    try testing.expectEqual(@as(usize, 13), size);
}

// ANCHOR: practical_formatting
test "format URL" {
    const protocol = "https";
    const domain = "example.com";
    const path = "api/users";
    const result = try format(testing.allocator, "{s}://{s}/{s}", .{ protocol, domain, path });
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("https://example.com/api/users", result);
}

test "format file path" {
    const dir = "/home/user";
    const file = "document.txt";
    const result = try format(testing.allocator, "{s}/{s}", .{ dir, file });
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("/home/user/document.txt", result);
}

test "format SQL query" {
    const table = "users";
    const id: u32 = 123;
    const result = try format(testing.allocator, "SELECT * FROM {s} WHERE id = {d}", .{ table, id });
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("SELECT * FROM users WHERE id = 123", result);
}

test "format log message" {
    const level = "INFO";
    const message = "Server started";
    const port: u16 = 8080;
    const result = try format(testing.allocator, "[{s}] {s} on port {d}", .{ level, message, port });
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("[INFO] Server started on port 8080", result);
}

test "format JSON-like string" {
    const name = "Alice";
    const age: u32 = 30;
    const result = try format(testing.allocator, "{{\"name\": \"{s}\", \"age\": {d}}}", .{ name, age });
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("{\"name\": \"Alice\", \"age\": 30}", result);
}
// ANCHOR_END: practical_formatting

test "format temperature" {
    const celsius: f32 = 23.5;
    const result = try format(testing.allocator, "Temperature: {d:.1}°C", .{celsius});
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Temperature: 23.5°C", result);
}

test "format currency" {
    const amount: f64 = 1234.56;
    const result = try format(testing.allocator, "Price: ${d:.2}", .{amount});
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Price: $1234.56", result);
}

test "format percentage" {
    const value: f32 = 0.856;
    const percent = value * 100.0;
    const result = try format(testing.allocator, "Progress: {d:.1}%", .{percent});
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Progress: 85.6%", result);
}

test "format date components" {
    const year: u32 = 2024;
    const month: u32 = 3;
    const day: u32 = 15;
    const result = try format(testing.allocator, "{d:0>4}-{d:0>2}-{d:0>2}", .{ year, month, day });
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("2024-03-15", result);
}

test "format time components" {
    const hour: u32 = 9;
    const minute: u32 = 5;
    const second: u32 = 3;
    const result = try format(testing.allocator, "{d:0>2}:{d:0>2}:{d:0>2}", .{ hour, minute, second });
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("09:05:03", result);
}

test "format array slice" {
    const numbers = [_]u32{ 1, 2, 3, 4, 5 };
    const result = try format(testing.allocator, "Numbers: {any}", .{numbers});
    defer testing.allocator.free(result);

    try testing.expect(mem.indexOf(u8, result, "1") != null);
    try testing.expect(mem.indexOf(u8, result, "5") != null);
}

test "format struct" {
    const Point = struct {
        x: i32,
        y: i32,
    };

    const point = Point{ .x = 10, .y = 20 };
    const result = try format(testing.allocator, "Point: {any}", .{point});
    defer testing.allocator.free(result);

    try testing.expect(mem.indexOf(u8, result, "10") != null);
    try testing.expect(mem.indexOf(u8, result, "20") != null);
}

test "format error message" {
    const filename = "data.txt";
    const line: u32 = 42;
    const column: u32 = 15;
    const result = try format(
        testing.allocator,
        "Error in {s} at line {d}, column {d}",
        .{ filename, line, column },
    );
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Error in data.txt at line 42, column 15", result);
}

test "format byte size" {
    const bytes: u64 = 1536;
    const kb = @as(f64, @floatFromInt(bytes)) / 1024.0;
    const result = try format(testing.allocator, "{d:.2} KB", .{kb});
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("1.50 KB", result);
}

test "memory safety - formatting" {
    const result = try format(testing.allocator, "test {d}", .{123});
    defer testing.allocator.free(result);

    // testing.allocator will detect leaks
    try testing.expect(result.len > 0);
}

test "UTF-8 in format string" {
    const result = try format(testing.allocator, "Hello 世界 {d}", .{42});
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Hello 世界 42", result);
}

test "UTF-8 in arguments" {
    const text = "世界";
    const result = try format(testing.allocator, "Hello {s}", .{text});
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Hello 世界", result);
}

test "empty format string" {
    const result = try format(testing.allocator, "", .{});
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("", result);
}

test "format with no arguments" {
    const result = try format(testing.allocator, "Static text", .{});
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Static text", result);
}

test "security - format large numbers" {
    const big: u64 = 18446744073709551615; // max u64
    const result = try format(testing.allocator, "Big: {d}", .{big});
    defer testing.allocator.free(result);

    try testing.expect(result.len > 0);
}
