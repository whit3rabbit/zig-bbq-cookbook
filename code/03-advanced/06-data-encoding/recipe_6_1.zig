const std = @import("std");

// ANCHOR: csv_writer
/// CSV Writer
pub const CsvWriter = struct {
    writer: std.io.AnyWriter,
    delimiter: u8 = ',',

    pub fn init(writer: std.io.AnyWriter) CsvWriter {
        return .{ .writer = writer };
    }

    pub fn writeRow(self: *CsvWriter, fields: []const []const u8) !void {
        for (fields, 0..) |field, i| {
            if (i > 0) try self.writer.writeByte(self.delimiter);
            try self.writeField(field);
        }
        try self.writer.writeByte('\n');
    }

    fn writeField(self: *CsvWriter, field: []const u8) !void {
        const needs_quotes = blk: {
            for (field) |c| {
                if (c == self.delimiter or c == '"' or c == '\n' or c == '\r') {
                    break :blk true;
                }
            }
            break :blk false;
        };

        if (needs_quotes) {
            try self.writer.writeByte('"');
            for (field) |c| {
                if (c == '"') try self.writer.writeByte('"');
                try self.writer.writeByte(c);
            }
            try self.writer.writeByte('"');
        } else {
            try self.writer.writeAll(field);
        }
    }

    pub fn writeHeader(self: *CsvWriter, headers: []const []const u8) !void {
        try self.writeRow(headers);
    }
};
// ANCHOR_END: csv_writer

// ANCHOR: csv_reader
/// CSV Reader
pub const CsvReader = struct {
    allocator: std.mem.Allocator,
    reader: std.io.AnyReader,
    delimiter: u8 = ',',
    buffer: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator, reader: std.io.AnyReader) CsvReader {
        return .{
            .allocator = allocator,
            .reader = reader,
            .buffer = .{},
        };
    }

    pub fn deinit(self: *CsvReader) void {
        self.buffer.deinit(self.allocator);
    }

    pub fn readRow(self: *CsvReader, allocator: std.mem.Allocator) !?[][]u8 {
        var fields: std.ArrayList([]u8) = .{};
        errdefer {
            for (fields.items) |field| allocator.free(field);
            fields.deinit(allocator);
        }

        var in_quotes = false;
        var field_start: usize = 0;
        self.buffer.clearRetainingCapacity();

        while (true) {
            const byte = self.reader.readByte() catch |err| switch (err) {
                error.EndOfStream => {
                    if (self.buffer.items.len > 0 or fields.items.len > 0) {
                        const field = try allocator.dupe(u8, self.buffer.items[field_start..]);
                        try fields.append(allocator, field);
                        return try fields.toOwnedSlice(allocator);
                    }
                    return null;
                },
                else => return err,
            };

            if (in_quotes) {
                if (byte == '"') {
                    const next = self.reader.readByte() catch |err| switch (err) {
                        error.EndOfStream => {
                            in_quotes = false;
                            continue;
                        },
                        else => return err,
                    };

                    if (next == '"') {
                        try self.buffer.append(self.allocator, '"');
                    } else {
                        in_quotes = false;
                        if (next == self.delimiter) {
                            const field = try allocator.dupe(u8, self.buffer.items[field_start..]);
                            try fields.append(allocator, field);
                            self.buffer.clearRetainingCapacity();
                            field_start = 0;
                        } else if (next == '\n') {
                            const field = try allocator.dupe(u8, self.buffer.items[field_start..]);
                            try fields.append(allocator, field);
                            return try fields.toOwnedSlice(allocator);
                        } else if (next != '\r') {
                            try self.buffer.append(self.allocator, next);
                        }
                    }
                } else {
                    try self.buffer.append(self.allocator, byte);
                }
            } else {
                if (byte == '"' and self.buffer.items.len == field_start) {
                    in_quotes = true;
                } else if (byte == self.delimiter) {
                    const field = try allocator.dupe(u8, self.buffer.items[field_start..]);
                    try fields.append(allocator, field);
                    self.buffer.clearRetainingCapacity();
                    field_start = 0;
                } else if (byte == '\n') {
                    const field = try allocator.dupe(u8, self.buffer.items[field_start..]);
                    try fields.append(allocator, field);
                    return try fields.toOwnedSlice(allocator);
                } else if (byte != '\r') {
                    try self.buffer.append(self.allocator, byte);
                }
            }
        }
    }
};
// ANCHOR_END: csv_reader

// ANCHOR: tsv_variant
/// Write TSV (tab-separated values)
pub fn writeTsv(writer: std.io.AnyWriter, rows: []const []const []const u8) !void {
    var csv = CsvWriter.init(writer);
    csv.delimiter = '\t';

    for (rows) |row| {
        try csv.writeRow(row);
    }
}
// ANCHOR_END: tsv_variant

// Tests

test "write simple csv" {
    var buffer: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    var csv = CsvWriter.init(stream.writer().any());

    try csv.writeRow(&.{ "Name", "Age", "City" });
    try csv.writeRow(&.{ "Alice", "30", "New York" });
    try csv.writeRow(&.{ "Bob", "25", "San Francisco" });

    const result = stream.getWritten();
    try std.testing.expectEqualStrings(
        "Name,Age,City\nAlice,30,New York\nBob,25,San Francisco\n",
        result,
    );
}

test "write csv with quotes" {
    var buffer: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    var csv = CsvWriter.init(stream.writer().any());

    try csv.writeRow(&.{ "Name", "Description" });
    try csv.writeRow(&.{ "Item", "Contains, comma" });

    const result = stream.getWritten();
    try std.testing.expectEqualStrings(
        "Name,Description\nItem,\"Contains, comma\"\n",
        result,
    );
}

test "write csv with escaped quotes" {
    var buffer: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    var csv = CsvWriter.init(stream.writer().any());

    try csv.writeRow(&.{ "Title", "Quote" });
    try csv.writeRow(&.{ "Book", "He said \"Hello\"" });

    const result = stream.getWritten();
    try std.testing.expectEqualStrings(
        "Title,Quote\nBook,\"He said \"\"Hello\"\"\"\n",
        result,
    );
}

test "write csv with newlines" {
    var buffer: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    var csv = CsvWriter.init(stream.writer().any());

    try csv.writeRow(&.{ "Field", "Value" });
    try csv.writeRow(&.{ "Multi", "Line\nValue" });

    const result = stream.getWritten();
    try std.testing.expectEqualStrings(
        "Field,Value\nMulti,\"Line\nValue\"\n",
        result,
    );
}

test "write empty fields" {
    var buffer: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    var csv = CsvWriter.init(stream.writer().any());

    try csv.writeRow(&.{ "A", "", "C" });
    try csv.writeRow(&.{ "", "B", "" });

    const result = stream.getWritten();
    try std.testing.expectEqualStrings(
        "A,,C\n,B,\n",
        result,
    );
}

test "read simple csv" {
    const data = "Name,Age,City\nAlice,30,New York\nBob,25,San Francisco\n";
    var stream = std.io.fixedBufferStream(data);

    const allocator = std.testing.allocator;
    var csv = CsvReader.init(allocator, stream.reader().any());
    defer csv.deinit();

    // Read header
    const header = (try csv.readRow(allocator)).?;
    defer {
        for (header) |field| allocator.free(field);
        allocator.free(header);
    }

    try std.testing.expectEqual(@as(usize, 3), header.len);
    try std.testing.expectEqualStrings("Name", header[0]);
    try std.testing.expectEqualStrings("Age", header[1]);
    try std.testing.expectEqualStrings("City", header[2]);

    // Read first row
    const row1 = (try csv.readRow(allocator)).?;
    defer {
        for (row1) |field| allocator.free(field);
        allocator.free(row1);
    }

    try std.testing.expectEqual(@as(usize, 3), row1.len);
    try std.testing.expectEqualStrings("Alice", row1[0]);
    try std.testing.expectEqualStrings("30", row1[1]);
    try std.testing.expectEqualStrings("New York", row1[2]);

    // Read second row
    const row2 = (try csv.readRow(allocator)).?;
    defer {
        for (row2) |field| allocator.free(field);
        allocator.free(row2);
    }

    try std.testing.expectEqual(@as(usize, 3), row2.len);
    try std.testing.expectEqualStrings("Bob", row2[0]);
}

test "read csv with quoted fields" {
    const data = "Name,Description\nItem,\"Contains, comma\"\n";
    var stream = std.io.fixedBufferStream(data);

    const allocator = std.testing.allocator;
    var csv = CsvReader.init(allocator, stream.reader().any());
    defer csv.deinit();

    // Skip header
    const header = (try csv.readRow(allocator)).?;
    defer {
        for (header) |field| allocator.free(field);
        allocator.free(header);
    }

    const row = (try csv.readRow(allocator)).?;
    defer {
        for (row) |field| allocator.free(field);
        allocator.free(row);
    }

    try std.testing.expectEqualStrings("Item", row[0]);
    try std.testing.expectEqualStrings("Contains, comma", row[1]);
}

test "read csv with escaped quotes" {
    const data = "Title,Quote\nBook,\"He said \"\"Hello\"\"\"\n";
    var stream = std.io.fixedBufferStream(data);

    const allocator = std.testing.allocator;
    var csv = CsvReader.init(allocator, stream.reader().any());
    defer csv.deinit();

    // Skip header
    const header = (try csv.readRow(allocator)).?;
    defer {
        for (header) |field| allocator.free(field);
        allocator.free(header);
    }

    const row = (try csv.readRow(allocator)).?;
    defer {
        for (row) |field| allocator.free(field);
        allocator.free(row);
    }

    try std.testing.expectEqualStrings("Book", row[0]);
    try std.testing.expectEqualStrings("He said \"Hello\"", row[1]);
}

test "read csv with newlines in quotes" {
    const data = "Field,Value\nMulti,\"Line\nValue\"\n";
    var stream = std.io.fixedBufferStream(data);

    const allocator = std.testing.allocator;
    var csv = CsvReader.init(allocator, stream.reader().any());
    defer csv.deinit();

    // Skip header
    const header = (try csv.readRow(allocator)).?;
    defer {
        for (header) |field| allocator.free(field);
        allocator.free(header);
    }

    const row = (try csv.readRow(allocator)).?;
    defer {
        for (row) |field| allocator.free(field);
        allocator.free(row);
    }

    try std.testing.expectEqualStrings("Multi", row[0]);
    try std.testing.expectEqualStrings("Line\nValue", row[1]);
}

test "read empty csv" {
    const data = "";
    var stream = std.io.fixedBufferStream(data);

    const allocator = std.testing.allocator;
    var csv = CsvReader.init(allocator, stream.reader().any());
    defer csv.deinit();

    const row = try csv.readRow(allocator);
    try std.testing.expect(row == null);
}

test "read csv with empty fields" {
    const data = "A,,C\n,B,\n";
    var stream = std.io.fixedBufferStream(data);

    const allocator = std.testing.allocator;
    var csv = CsvReader.init(allocator, stream.reader().any());
    defer csv.deinit();

    const row1 = (try csv.readRow(allocator)).?;
    defer {
        for (row1) |field| allocator.free(field);
        allocator.free(row1);
    }

    try std.testing.expectEqual(@as(usize, 3), row1.len);
    try std.testing.expectEqualStrings("A", row1[0]);
    try std.testing.expectEqualStrings("", row1[1]);
    try std.testing.expectEqualStrings("C", row1[2]);
}

test "write tsv" {
    var buffer: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    const rows = [_][]const []const u8{
        &.{ "Name", "Age" },
        &.{ "Alice", "30" },
    };

    try writeTsv(stream.writer().any(), &rows);

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("Name\tAge\nAlice\t30\n", result);
}

test "roundtrip csv" {
    const allocator = std.testing.allocator;

    // Write CSV
    var write_buffer: [1024]u8 = undefined;
    var write_stream = std.io.fixedBufferStream(&write_buffer);

    var writer = CsvWriter.init(write_stream.writer().any());
    try writer.writeRow(&.{ "Name", "Value" });
    try writer.writeRow(&.{ "Test", "Data" });

    const written = write_stream.getWritten();

    // Read CSV back
    var read_stream = std.io.fixedBufferStream(written);
    var reader = CsvReader.init(allocator, read_stream.reader().any());
    defer reader.deinit();

    const row1 = (try reader.readRow(allocator)).?;
    defer {
        for (row1) |field| allocator.free(field);
        allocator.free(row1);
    }

    const row2 = (try reader.readRow(allocator)).?;
    defer {
        for (row2) |field| allocator.free(field);
        allocator.free(row2);
    }

    try std.testing.expectEqualStrings("Name", row1[0]);
    try std.testing.expectEqualStrings("Test", row2[0]);
}

test "single field csv" {
    var buffer: [128]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    var csv = CsvWriter.init(stream.writer().any());
    try csv.writeRow(&.{"Single"});

    const result = stream.getWritten();
    try std.testing.expectEqualStrings("Single\n", result);
}

test "read single field csv" {
    const data = "Single\n";
    var stream = std.io.fixedBufferStream(data);

    const allocator = std.testing.allocator;
    var csv = CsvReader.init(allocator, stream.reader().any());
    defer csv.deinit();

    const row = (try csv.readRow(allocator)).?;
    defer {
        for (row) |field| allocator.free(field);
        allocator.free(row);
    }

    try std.testing.expectEqual(@as(usize, 1), row.len);
    try std.testing.expectEqualStrings("Single", row[0]);
}

test "csv with unicode" {
    var buffer: [1024]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buffer);

    var csv = CsvWriter.init(stream.writer().any());
    try csv.writeRow(&.{ "Name", "Nom", "名前" });
    try csv.writeRow(&.{ "Hello", "Bonjour", "こんにちは" });

    const result = stream.getWritten();
    try std.testing.expect(std.mem.indexOf(u8, result, "名前") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "こんにちは") != null);
}
