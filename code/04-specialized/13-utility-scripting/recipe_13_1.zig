const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_stdin_read
/// Read all input from stdin into a buffer
fn readStdin(allocator: std.mem.Allocator) ![]u8 {
    const stdin = std.fs.File.stdin();
    const max_size = 10 * 1024 * 1024; // 10MB max
    return try stdin.readToEndAlloc(allocator, max_size);
}

test "read from stdin mock" {
    const input = "Hello from stdin\n";
    var stream = std.io.fixedBufferStream(input);

    const reader = stream.reader();
    const max_size = 1024;
    const result = try reader.readAllAlloc(testing.allocator, max_size);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Hello from stdin\n", result);
}
// ANCHOR_END: basic_stdin_read

// ANCHOR: line_by_line
/// Process stdin line by line with fixed buffer
/// NOTE: Returns error.StreamTooLong if a line exceeds 4096 bytes
/// For production use with unknown input, prefer processLinesRobust
fn processLines(reader: anytype, writer: anytype) !void {
    var line_buffer: [4096]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&line_buffer, '\n')) |line| {
        try writer.print("Processed: {s}\n", .{line});
    }
}

test "process lines from input" {
    const input = "Line 1\nLine 2\nLine 3\n";
    var in_stream = std.io.fixedBufferStream(input);

    var out_buffer: [1024]u8 = undefined;
    var out_stream = std.io.fixedBufferStream(&out_buffer);

    try processLines(
        in_stream.reader(),
        out_stream.writer()
    );

    const expected = "Processed: Line 1\nProcessed: Line 2\nProcessed: Line 3\n";
    try testing.expectEqualStrings(expected, out_stream.getWritten());
}
// ANCHOR_END: line_by_line

// ANCHOR: is_terminal
/// Check if file descriptor is a terminal or pipe/file
/// Prefer using std.fs.File.isTty() for better portability abstraction
fn isTty(file: std.fs.File) bool {
    return file.isTty();
}

test "detect terminal vs pipe" {
    // This test demonstrates the API; actual behavior depends on runtime
    // We can't test the actual result as it depends on how tests are run
    // but we ensure the function compiles and can be called
    const stdin = std.fs.File.stdin();
    _ = isTty(stdin);
    // Can also call directly: stdin.isTty()
}
// ANCHOR_END: is_terminal

// ANCHOR: conditional_behavior
/// Read input with different behavior for terminal vs pipe
fn readInput(allocator: std.mem.Allocator, file: std.fs.File) ![]u8 {
    const reader = file.reader();

    if (isTty(file)) {
        // Interactive mode: read line by line
        const stdout_file = std.fs.File{ .handle = 1 }; // stdout
        const stdout = stdout_file.writer();
        try stdout.print("Enter input (Ctrl+D to finish):\n", .{});

        var list = std.ArrayList(u8){};
        errdefer list.deinit(allocator);

        var line_buffer: [4096]u8 = undefined;
        while (try reader.readUntilDelimiterOrEof(&line_buffer, '\n')) |line| {
            try list.appendSlice(allocator, line);
            try list.append(allocator, '\n');
        }

        return list.toOwnedSlice(allocator);
    } else {
        // Piped/redirected mode: read all at once
        const max_size = 10 * 1024 * 1024;
        return try reader.readAllAlloc(allocator, max_size);
    }
}

test "read input interactive mode simulation" {
    const input = "Line 1\nLine 2\n";
    var stream = std.io.fixedBufferStream(input);

    var list = std.ArrayList(u8){};
    defer list.deinit(testing.allocator);

    const reader = stream.reader();
    var line_buffer: [4096]u8 = undefined;
    while (try reader.readUntilDelimiterOrEof(&line_buffer, '\n')) |line| {
        try list.appendSlice(testing.allocator, line);
        try list.append(testing.allocator, '\n');
    }

    try testing.expectEqualStrings("Line 1\nLine 2\n", list.items);
}
// ANCHOR_END: conditional_behavior

// ANCHOR: stream_processing
/// Process input as a stream without loading all into memory
fn streamProcess(reader: anytype, writer: anytype) !usize {
    var line_count: usize = 0;
    var line_buffer: [4096]u8 = undefined;

    while (try reader.readUntilDelimiterOrEof(&line_buffer, '\n')) |line| {
        line_count += 1;
        // Process the line (e.g., transform, filter, analyze)
        if (line.len > 0) {
            try writer.print("{d}: {s}\n", .{line_count, line});
        }
    }

    return line_count;
}

test "stream processing" {
    const input = "First\nSecond\nThird\n";
    var in_stream = std.io.fixedBufferStream(input);

    var out_buffer: [1024]u8 = undefined;
    var out_stream = std.io.fixedBufferStream(&out_buffer);

    const count = try streamProcess(in_stream.reader(), out_stream.writer());

    try testing.expectEqual(3, count);
    const expected = "1: First\n2: Second\n3: Third\n";
    try testing.expectEqualStrings(expected, out_stream.getWritten());
}
// ANCHOR_END: stream_processing

// ANCHOR: binary_input
/// Read binary input from stdin
fn readBinaryInput(allocator: std.mem.Allocator) ![]u8 {
    const stdin = std.fs.File.stdin();
    const reader = stdin.reader();

    var list = std.ArrayList(u8){};
    errdefer list.deinit(allocator);

    var buffer: [4096]u8 = undefined;
    while (true) {
        const bytes_read = try reader.read(&buffer);
        if (bytes_read == 0) break;
        try list.appendSlice(allocator, buffer[0..bytes_read]);
    }

    return list.toOwnedSlice(allocator);
}

test "read binary input" {
    const binary_data = [_]u8{0x00, 0x01, 0x02, 0xFF, 0xFE, 0xFD};
    var stream = std.io.fixedBufferStream(&binary_data);

    var list = std.ArrayList(u8){};
    defer list.deinit(testing.allocator);

    var buffer: [4]u8 = undefined;
    const reader = stream.reader();

    while (true) {
        const bytes_read = try reader.read(&buffer);
        if (bytes_read == 0) break;
        try list.appendSlice(testing.allocator, buffer[0..bytes_read]);
    }

    try testing.expectEqualSlices(u8, &binary_data, list.items);
}
// ANCHOR_END: binary_input

// ANCHOR: buffered_reading
/// Read with custom buffer size for performance
fn bufferedRead(allocator: std.mem.Allocator, reader: anytype, buffer_size: usize) ![]u8 {
    var list = std.ArrayList(u8){};
    errdefer list.deinit(allocator);

    const buffer = try allocator.alloc(u8, buffer_size);
    defer allocator.free(buffer);

    while (true) {
        const bytes_read = try reader.read(buffer);
        if (bytes_read == 0) break;
        try list.appendSlice(allocator, buffer[0..bytes_read]);
    }

    return list.toOwnedSlice(allocator);
}

test "buffered reading with custom buffer" {
    const input = "A" ** 1000;
    var stream = std.io.fixedBufferStream(input);

    const result = try bufferedRead(testing.allocator, stream.reader(), 128);
    defer testing.allocator.free(result);

    try testing.expectEqual(1000, result.len);
    try testing.expectEqual('A', result[0]);
    try testing.expectEqual('A', result[999]);
}
// ANCHOR_END: buffered_reading

// ANCHOR: line_filtering
/// Filter lines based on predicate
fn filterLines(
    reader: anytype,
    writer: anytype,
    predicate: *const fn([]const u8) bool
) !usize {
    var filtered_count: usize = 0;
    var line_buffer: [4096]u8 = undefined;

    while (try reader.readUntilDelimiterOrEof(&line_buffer, '\n')) |line| {
        if (predicate(line)) {
            try writer.print("{s}\n", .{line});
            filtered_count += 1;
        }
    }

    return filtered_count;
}

fn isNotEmpty(line: []const u8) bool {
    return line.len > 0;
}

fn startsWithHash(line: []const u8) bool {
    return line.len > 0 and line[0] == '#';
}

test "filter non-empty lines" {
    const input = "Line 1\n\nLine 3\n\nLine 5\n";
    var in_stream = std.io.fixedBufferStream(input);

    var out_buffer: [1024]u8 = undefined;
    var out_stream = std.io.fixedBufferStream(&out_buffer);

    const count = try filterLines(
        in_stream.reader(),
        out_stream.writer(),
        &isNotEmpty
    );

    try testing.expectEqual(3, count);
}

test "filter lines starting with hash" {
    const input = "# Comment\nNormal\n# Another\nLine\n";
    var in_stream = std.io.fixedBufferStream(input);

    var out_buffer: [1024]u8 = undefined;
    var out_stream = std.io.fixedBufferStream(&out_buffer);

    const count = try filterLines(
        in_stream.reader(),
        out_stream.writer(),
        &startsWithHash
    );

    try testing.expectEqual(2, count);
    const expected = "# Comment\n# Another\n";
    try testing.expectEqualStrings(expected, out_stream.getWritten());
}
// ANCHOR_END: line_filtering

// ANCHOR: word_counting
/// Count words in input stream
/// NOTE: Uses fixed 4096-byte buffer per line
fn countWords(reader: anytype) !usize {
    var word_count: usize = 0;
    var line_buffer: [4096]u8 = undefined;

    while (try reader.readUntilDelimiterOrEof(&line_buffer, '\n')) |line| {
        var iter = std.mem.tokenizeAny(u8, line, " \t");
        while (iter.next()) |_| {
            word_count += 1;
        }
    }

    return word_count;
}

test "count words in input" {
    const input = "The quick brown fox\njumps over\nthe lazy dog\n";
    var stream = std.io.fixedBufferStream(input);

    const count = try countWords(stream.reader());
    try testing.expectEqual(9, count);
}
// ANCHOR_END: word_counting

// ANCHOR: robust_line_processing
/// Process lines robustly with dynamic allocation
/// Handles lines of arbitrary length without fixed buffer limitations
fn processLinesRobust(allocator: std.mem.Allocator, reader: anytype, writer: anytype) !usize {
    var line_count: usize = 0;
    const max_line_size = 1024 * 1024; // 1MB per line max

    while (true) {
        const line = reader.readUntilDelimiterOrEofAlloc(
            allocator,
            '\n',
            max_line_size,
        ) catch |err| switch (err) {
            error.StreamTooLong => {
                // Line exceeds max_line_size, skip to next line
                try writer.print("Warning: Line too long, skipping\n", .{});
                continue;
            },
            else => return err,
        } orelse break;
        defer allocator.free(line);

        line_count += 1;
        try writer.print("{d}: {s}\n", .{ line_count, line });
    }

    return line_count;
}

test "robust line processing - normal lines" {
    const input = "Short line\nAnother short line\nThird line\n";
    var in_stream = std.io.fixedBufferStream(input);

    var out_buffer: [1024]u8 = undefined;
    var out_stream = std.io.fixedBufferStream(&out_buffer);

    const count = try processLinesRobust(
        testing.allocator,
        in_stream.reader(),
        out_stream.writer(),
    );

    try testing.expectEqual(3, count);
}

test "robust line processing - very long line" {
    // Create a line with 10000 characters
    var buf: [10100]u8 = undefined;
    @memset(buf[0..10000], 'A');
    buf[10000] = '\n';
    @memcpy(buf[10001..10014], "Normal line\n\x00");

    var stream = std.io.fixedBufferStream(buf[0..10013]);

    var out_buffer: [20000]u8 = undefined;
    var out_stream = std.io.fixedBufferStream(&out_buffer);

    const count = try processLinesRobust(
        testing.allocator,
        stream.reader(),
        out_stream.writer(),
    );

    try testing.expectEqual(2, count);
    // Both lines processed successfully
}
// ANCHOR_END: robust_line_processing

