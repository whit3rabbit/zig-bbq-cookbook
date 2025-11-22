const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_output
fn greet(writer: anytype, name: []const u8) !void {
    try writer.print("Hello, {s}!\n", .{name});
}
// ANCHOR_END: basic_output

// ANCHOR: testing_output
test "capture and verify stdout output" {
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(testing.allocator);

    const writer = buffer.writer(testing.allocator);
    try greet(writer, "World");

    try testing.expectEqualStrings("Hello, World!\n", buffer.items);
}
// ANCHOR_END: testing_output

// ANCHOR: multiple_outputs
fn printReport(writer: anytype, items: usize, total: f64) !void {
    try writer.print("Items processed: {d}\n", .{items});
    try writer.print("Total value: ${d:.2}\n", .{total});
    try writer.writeAll("Status: Complete\n");
}

test "capture multiple output lines" {
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(testing.allocator);

    try printReport(buffer.writer(testing.allocator), 42, 123.45);

    const expected =
        \\Items processed: 42
        \\Total value: $123.45
        \\Status: Complete
        \\
    ;
    try testing.expectEqualStrings(expected, buffer.items);
}
// ANCHOR_END: multiple_outputs

// ANCHOR: formatted_output
fn formatData(writer: anytype, data: []const u8) !void {
    try writer.print("[INFO] Processing: {s}\n", .{data});
    try writer.print("[INFO] Length: {d} bytes\n", .{data.len});
}

test "verify formatted output" {
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(testing.allocator);

    try formatData(buffer.writer(testing.allocator), "test data");

    try testing.expect(std.mem.indexOf(u8, buffer.items, "[INFO]") != null);
    try testing.expect(std.mem.indexOf(u8, buffer.items, "test data") != null);
    try testing.expect(std.mem.indexOf(u8, buffer.items, "9 bytes") != null);
}
// ANCHOR_END: formatted_output

// ANCHOR: table_output
fn printTable(writer: anytype) !void {
    try writer.writeAll("Name       | Age | City\n");
    try writer.writeAll("-----------+-----+----------\n");
    try writer.writeAll("Alice      |  30 | Seattle\n");
    try writer.writeAll("Bob        |  25 | Portland\n");
}

test "capture table output" {
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(testing.allocator);

    try printTable(buffer.writer(testing.allocator));

    // Verify table structure
    try testing.expect(std.mem.indexOf(u8, buffer.items, "Name") != null);
    try testing.expect(std.mem.indexOf(u8, buffer.items, "Alice") != null);
    try testing.expect(std.mem.indexOf(u8, buffer.items, "Bob") != null);

    // Count lines
    var line_count: usize = 0;
    for (buffer.items) |char| {
        if (char == '\n') line_count += 1;
    }
    try testing.expectEqual(4, line_count);
}
// ANCHOR_END: table_output

// ANCHOR: error_messages
fn processWithLogging(writer: anytype, value: i32) !void {
    if (value < 0) {
        try writer.print("ERROR: Invalid value {d}\n", .{value});
        return error.InvalidValue;
    }
    try writer.print("SUCCESS: Processed {d}\n", .{value});
}

test "capture error messages" {
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(testing.allocator);

    const result = processWithLogging(buffer.writer(testing.allocator), -5);
    try testing.expectError(error.InvalidValue, result);
    try testing.expect(std.mem.indexOf(u8, buffer.items, "ERROR") != null);
    try testing.expect(std.mem.indexOf(u8, buffer.items, "-5") != null);
}

test "capture success messages" {
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(testing.allocator);

    try processWithLogging(buffer.writer(testing.allocator), 42);
    try testing.expect(std.mem.indexOf(u8, buffer.items, "SUCCESS") != null);
    try testing.expect(std.mem.indexOf(u8, buffer.items, "42") != null);
}
// ANCHOR_END: error_messages

// ANCHOR: json_output
fn printJSON(writer: anytype, name: []const u8, age: u8) !void {
    try writer.writeAll("{\n");
    try writer.print("  \"name\": \"{s}\",\n", .{name});
    try writer.print("  \"age\": {d}\n", .{age});
    try writer.writeAll("}\n");
}

test "verify JSON output structure" {
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(testing.allocator);

    try printJSON(buffer.writer(testing.allocator), "Alice", 30);

    // Verify JSON structure
    try testing.expect(std.mem.indexOf(u8, buffer.items, "{") != null);
    try testing.expect(std.mem.indexOf(u8, buffer.items, "}") != null);
    try testing.expect(std.mem.indexOf(u8, buffer.items, "\"name\"") != null);
    try testing.expect(std.mem.indexOf(u8, buffer.items, "\"Alice\"") != null);
    try testing.expect(std.mem.indexOf(u8, buffer.items, "\"age\"") != null);
    try testing.expect(std.mem.indexOf(u8, buffer.items, "30") != null);
}
// ANCHOR_END: json_output

// ANCHOR: progress_output
fn printProgress(writer: anytype, current: usize, total: usize) !void {
    const percent = @as(f64, @floatFromInt(current)) / @as(f64, @floatFromInt(total)) * 100.0;
    try writer.print("Progress: {d}/{d} ({d:.1}%)\n", .{ current, total, percent });
}

test "verify progress output" {
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(testing.allocator);

    try printProgress(buffer.writer(testing.allocator), 25, 100);

    try testing.expect(std.mem.indexOf(u8, buffer.items, "25/100") != null);
    try testing.expect(std.mem.indexOf(u8, buffer.items, "25.0%") != null);
}
// ANCHOR_END: progress_output

// ANCHOR: color_codes
fn printColoredOutput(writer: anytype) !void {
    const red = "\x1b[31m";
    const green = "\x1b[32m";
    const reset = "\x1b[0m";

    try writer.print("{s}Error{s}: Something went wrong\n", .{ red, reset });
    try writer.print("{s}Success{s}: Operation completed\n", .{ green, reset });
}

test "verify ANSI color codes in output" {
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(testing.allocator);

    try printColoredOutput(buffer.writer(testing.allocator));

    // Verify ANSI codes are present
    try testing.expect(std.mem.indexOf(u8, buffer.items, "\x1b[31m") != null);
    try testing.expect(std.mem.indexOf(u8, buffer.items, "\x1b[32m") != null);
    try testing.expect(std.mem.indexOf(u8, buffer.items, "\x1b[0m") != null);
}
// ANCHOR_END: color_codes
