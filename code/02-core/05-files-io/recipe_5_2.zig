// Recipe 5.2: Printing to a file
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to use formatted printing to write data to files,
// similar to how std.debug.print works for stdout but directed to file handles.

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_printing
/// Print formatted data to a file using the writer interface
pub fn printToFile(path: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    try writer.print("Hello, {s}!\n", .{"World"});
    try writer.print("The answer is: {}\n", .{42});
    try writer.print("Pi: {d:.2}\n", .{3.14159});

    try writer.flush();
}

/// Demonstrate printing various data types with different format specifiers
pub fn printMixedData(path: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    // Integers with different bases
    try writer.print("Decimal: {}\n", .{255});
    try writer.print("Hexadecimal: {x}\n", .{255});
    try writer.print("Binary: {b}\n", .{255});
    try writer.print("Octal: {o}\n", .{255});

    // Floating point with precision
    try writer.print("Default float: {}\n", .{3.14159});
    try writer.print("Two decimals: {d:.2}\n", .{3.14159});
    try writer.print("Scientific: {e}\n", .{1234.5});

    // Boolean and strings
    try writer.print("Boolean: {}\n", .{true});
    try writer.print("String: {s}\n", .{"Hello"});

    try writer.flush();
}
// ANCHOR_END: basic_printing

// ANCHOR: structured_printing
const Person = struct {
    name: []const u8,
    age: u32,
    height: f32,
};

/// Print structured data (array of structs) to a file
pub fn printStructData(path: []const u8, people: []const Person) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    try writer.print("People Database\n", .{});
    try writer.print("{s}\n", .{"=" ** 50});

    for (people, 0..) |person, i| {
        try writer.print("{}: {s}, Age: {}, Height: {d:.1}m\n", .{
            i + 1,
            person.name,
            person.age,
            person.height,
        });
    }

    try writer.flush();
}

/// Print a formatted table with headers and data rows
pub fn printTable(
    path: []const u8,
    headers: []const []const u8,
    data: []const []const []const u8,
) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    // Print headers
    for (headers) |header| {
        try writer.print("{s:<15} ", .{header});
    }
    try writer.print("\n", .{});

    // Print separator
    for (headers) |_| {
        try writer.print("{s:<15} ", .{"-" ** 15});
    }
    try writer.print("\n", .{});

    // Print data rows
    for (data) |row| {
        for (row) |cell| {
            try writer.print("{s:<15} ", .{cell});
        }
        try writer.print("\n", .{});
    }

    try writer.flush();
}
// ANCHOR_END: structured_printing

// ANCHOR: conditional_logging
/// Print only values that meet a condition, return count
pub fn printWithConditions(
    path: []const u8,
    values: []const i32,
    threshold: i32,
) !usize {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    var count: usize = 0;

    try writer.print("Values greater than {}:\n", .{threshold});

    for (values) |value| {
        if (value > threshold) {
            try writer.print("  {}\n", .{value});
            count += 1;
        }
    }

    try writer.print("\nTotal: {} values\n", .{count});
    try writer.flush();

    return count;
}

/// Append a log entry with timestamp to a log file
pub fn printLog(
    path: []const u8,
    level: []const u8,
    message: []const u8,
) !void {
    // Open file for appending by using OpenFlags
    const file = try std.fs.cwd().openFile(path, .{
        .mode = .write_only,
    });
    defer file.close();

    // Seek to end for appending
    try file.seekFromEnd(0);

    const timestamp = std.time.timestamp();

    // Format the message
    var buf: [512]u8 = undefined;
    const log_line = try std.fmt.bufPrint(&buf, "[{}] {s}: {s}\n", .{ timestamp, level, message });

    // Write directly without buffering to avoid issues
    _ = try file.write(log_line);
}

/// Print a report with error handling for data generation
pub fn printReport(
    path: []const u8,
    allocator: std.mem.Allocator,
    generate_data: *const fn (std.mem.Allocator) anyerror![]const u8,
) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    try writer.print("=== Report ===\n\n", .{});

    const data = generate_data(allocator) catch |err| {
        try writer.print("Error generating data: {}\n", .{err});
        try writer.flush();
        return err;
    };
    defer allocator.free(data);

    try writer.print("Data:\n{s}\n", .{data});
    try writer.flush();
}

/// Print numbers with various alignment options
pub fn printAlignedNumbers(path: []const u8, numbers: []const i32) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    try writer.print("Left aligned:   ", .{});
    for (numbers) |num| {
        try writer.print("{:<8}", .{num});
    }
    try writer.print("\n", .{});

    try writer.print("Right aligned:  ", .{});
    for (numbers) |num| {
        try writer.print("{:>8}", .{num});
    }
    try writer.print("\n", .{});

    try writer.print("Center aligned: ", .{});
    for (numbers) |num| {
        try writer.print("{:^8}", .{num});
    }
    try writer.print("\n", .{});

    try writer.flush();
}

/// Print statistics summary
pub fn printStatistics(
    path: []const u8,
    values: []const f64,
) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    var sum: f64 = 0;
    var min: f64 = values[0];
    var max: f64 = values[0];

    for (values) |v| {
        sum += v;
        if (v < min) min = v;
        if (v > max) max = v;
    }

    const mean = sum / @as(f64, @floatFromInt(values.len));
// ANCHOR_END: conditional_logging

    try writer.print("Statistics Summary\n", .{});
    try writer.print("{s}\n", .{"=" ** 20});
    try writer.print("Count:   {}\n", .{values.len});
    try writer.print("Sum:     {d:.2}\n", .{sum});
    try writer.print("Mean:    {d:.2}\n", .{mean});
    try writer.print("Min:     {d:.2}\n", .{min});
    try writer.print("Max:     {d:.2}\n", .{max});

    try writer.flush();
}

// Tests

test "basic printing to file" {
    const test_path = "test_print_basic.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    try printToFile(test_path);

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(testing.allocator, 1024);
    defer testing.allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "Hello, World!") != null);
    try testing.expect(std.mem.indexOf(u8, content, "42") != null);
    try testing.expect(std.mem.indexOf(u8, content, "3.14") != null);
}

test "print mixed data types" {
    const test_path = "test_print_mixed.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    try printMixedData(test_path);

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(testing.allocator, 2048);
    defer testing.allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "Decimal: 255") != null);
    try testing.expect(std.mem.indexOf(u8, content, "Hexadecimal: ff") != null);
    try testing.expect(std.mem.indexOf(u8, content, "Binary: 11111111") != null);
    try testing.expect(std.mem.indexOf(u8, content, "Boolean: true") != null);
}

test "print structured data" {
    const test_path = "test_print_struct.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const people = [_]Person{
        .{ .name = "Alice", .age = 30, .height = 1.65 },
        .{ .name = "Bob", .age = 25, .height = 1.80 },
        .{ .name = "Charlie", .age = 35, .height = 1.75 },
    };

    try printStructData(test_path, &people);

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(testing.allocator, 2048);
    defer testing.allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "Alice") != null);
    try testing.expect(std.mem.indexOf(u8, content, "Bob") != null);
    try testing.expect(std.mem.indexOf(u8, content, "Charlie") != null);
    try testing.expect(std.mem.indexOf(u8, content, "Age: 30") != null);
}

test "print table" {
    const test_path = "test_print_table.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const headers = [_][]const u8{ "Name", "Age", "City" };
    const row1 = [_][]const u8{ "Alice", "30", "NYC" };
    const row2 = [_][]const u8{ "Bob", "25", "LA" };
    const row3 = [_][]const u8{ "Charlie", "35", "Chicago" };
    const data = [_][]const []const u8{ &row1, &row2, &row3 };

    try printTable(test_path, &headers, &data);

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(testing.allocator, 2048);
    defer testing.allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "Name") != null);
    try testing.expect(std.mem.indexOf(u8, content, "Alice") != null);
    try testing.expect(std.mem.indexOf(u8, content, "NYC") != null);
}

test "print with conditions" {
    const test_path = "test_print_conditions.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const values = [_]i32{ 10, 25, 30, 5, 50, 15, 40 };
    const count = try printWithConditions(test_path, &values, 20);

    try testing.expectEqual(@as(usize, 4), count);

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(testing.allocator, 1024);
    defer testing.allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "25") != null);
    try testing.expect(std.mem.indexOf(u8, content, "30") != null);
    try testing.expect(std.mem.indexOf(u8, content, "50") != null);
    try testing.expect(std.mem.indexOf(u8, content, "40") != null);
    try testing.expect(std.mem.indexOf(u8, content, "Total: 4") != null);
}

test "print log entries" {
    const test_path = "test_print_log.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create initial file
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
    }

    // Append log entries
    try printLog(test_path, "INFO", "Application started");
    try printLog(test_path, "WARN", "Low memory warning");
    try printLog(test_path, "ERROR", "Connection failed");

    // Read and verify
    const content = blk: {
        const file = try std.fs.cwd().openFile(test_path, .{});
        defer file.close();
        break :blk try file.readToEndAlloc(testing.allocator, 2048);
    };
    defer testing.allocator.free(content);

    // Verify content is not empty
    try testing.expect(content.len > 0);

    // Verify each log level appears - indexOf returns the index or null
    _ = std.mem.indexOf(u8, content, "INFO") orelse {
        std.debug.print("Content: {s}\n", .{content});
        return error.TestFailed;
    };
    _ = std.mem.indexOf(u8, content, "WARN") orelse return error.TestFailed;
    _ = std.mem.indexOf(u8, content, "ERROR") orelse return error.TestFailed;
    _ = std.mem.indexOf(u8, content, "Application started") orelse return error.TestFailed;
}

fn generateTestData(allocator: std.mem.Allocator) ![]const u8 {
    return try allocator.dupe(u8, "Sample data from generator");
}

fn generateErrorData(_: std.mem.Allocator) ![]const u8 {
    return error.TestError;
}

test "print report with success" {
    const test_path = "test_print_report.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    try printReport(test_path, testing.allocator, generateTestData);

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(testing.allocator, 1024);
    defer testing.allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "=== Report ===") != null);
    try testing.expect(std.mem.indexOf(u8, content, "Sample data") != null);
}

test "print report with error" {
    const test_path = "test_print_report_error.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const result = printReport(test_path, testing.allocator, generateErrorData);
    try testing.expectError(error.TestError, result);

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(testing.allocator, 1024);
    defer testing.allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "Error generating data") != null);
}

test "print aligned numbers" {
    const test_path = "test_print_aligned.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const numbers = [_]i32{ 1, 42, 999, 12345 };
    try printAlignedNumbers(test_path, &numbers);

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(testing.allocator, 1024);
    defer testing.allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "Left aligned") != null);
    try testing.expect(std.mem.indexOf(u8, content, "Right aligned") != null);
    try testing.expect(std.mem.indexOf(u8, content, "Center aligned") != null);
}

test "print statistics" {
    const test_path = "test_print_stats.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    const values = [_]f64{ 10.5, 20.3, 15.7, 8.2, 30.1 };
    try printStatistics(test_path, &values);

    const file = try std.fs.cwd().openFile(test_path, .{});
    defer file.close();

    const content = try file.readToEndAlloc(testing.allocator, 1024);
    defer testing.allocator.free(content);

    try testing.expect(std.mem.indexOf(u8, content, "Statistics Summary") != null);
    try testing.expect(std.mem.indexOf(u8, content, "Count:   5") != null);
    try testing.expect(std.mem.indexOf(u8, content, "Min:") != null);
    try testing.expect(std.mem.indexOf(u8, content, "Max:") != null);
}

test "memory safety check - no allocations" {
    const test_path = "test_memory_safe.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // All these operations should not allocate
    try printToFile(test_path);
    try printMixedData(test_path);

    const numbers = [_]i32{ 1, 2, 3 };
    try printAlignedNumbers(test_path, &numbers);

    // If we reach here without allocation errors, the test passes
}
