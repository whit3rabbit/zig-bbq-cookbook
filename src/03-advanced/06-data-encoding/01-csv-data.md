## Problem

You need to read and write CSV (Comma-Separated Values) files, handling quoted fields, commas within fields, and newlines properly.

## Solution

### CSV Writer

```zig
{{#include ../../../code/03-advanced/06-data-encoding/recipe_6_1.zig:csv_writer}}
```

### CSV Reader

```zig
{{#include ../../../code/03-advanced/06-data-encoding/recipe_6_1.zig:csv_reader}}
```

### TSV Variant

```zig
{{#include ../../../code/03-advanced/06-data-encoding/recipe_6_1.zig:tsv_variant}}
```

## Discussion

### CSV Format Basics

CSV files store tabular data in plain text:
- Fields separated by commas
- Records (rows) separated by newlines
- Fields containing commas, quotes, or newlines must be quoted
- Quotes within quoted fields are escaped by doubling them

### Writing CSV Files

Basic CSV writer implementation:

```zig
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
                if (c == '"') try self.writer.writeByte('"'); // Escape quotes
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
```

### Reading CSV Files

CSV reader with proper parsing:

```zig
pub const CsvReader = struct {
    allocator: std.mem.Allocator,
    reader: std.io.AnyReader,
    delimiter: u8 = ',',
    buffer: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator, reader: std.io.AnyReader) CsvReader {
        return .{
            .allocator = allocator,
            .reader = reader,
            .buffer = std.ArrayList(u8).init(allocator),
        };
    }

    pub fn deinit(self: *CsvReader) void {
        self.buffer.deinit();
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
                    // Check for escaped quote
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
                        // Put back the character
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
```

### Reading CSV with Headers

Parse CSV with header row:

```zig
pub fn readCsvWithHeaders(
    allocator: std.mem.Allocator,
    reader: std.io.AnyReader,
) !struct {
    headers: [][]u8,
    rows: [][][]u8,
} {
    var csv_reader = CsvReader.init(allocator, reader);
    defer csv_reader.deinit();

    // Read headers
    const headers = (try csv_reader.readRow(allocator)) orelse return error.EmptyFile;
    errdefer {
        for (headers) |h| allocator.free(h);
        allocator.free(headers);
    }

    // Read data rows
    var rows: std.ArrayList([][]u8) = .{};
    errdefer {
        for (rows.items) |row| {
            for (row) |field| allocator.free(field);
            allocator.free(row);
        }
        rows.deinit(allocator);
    }

    while (try csv_reader.readRow(allocator)) |row| {
        try rows.append(allocator, row);
    }

    return .{
        .headers = headers,
        .rows = try rows.toOwnedSlice(allocator),
    };
}
```

### Writing Structs as CSV

Convert structs to CSV rows:

```zig
pub fn writeStructs(
    comptime T: type,
    writer: std.io.AnyWriter,
    items: []const T,
    allocator: std.mem.Allocator,
) !void {
    var csv = CsvWriter.init(writer);

    // Write header from struct fields
    const fields = @typeInfo(T).Struct.fields;
    var headers: [fields.len][]const u8 = undefined;
    inline for (fields, 0..) |field, i| {
        headers[i] = field.name;
    }
    try csv.writeHeader(&headers);

    // Write rows
    for (items) |item| {
        var row: [fields.len][]u8 = undefined;
        inline for (fields, 0..) |field, i| {
            const value = @field(item, field.name);
            row[i] = try std.fmt.allocPrint(allocator, "{any}", .{value});
        }
        defer {
            inline for (&row) |r| allocator.free(r);
        }
        try csv.writeRow(&row);
    }
}
```

### Alternative Delimiter Support

Support TSV (tab-separated) and other formats:

```zig
pub fn writeTsv(writer: std.io.AnyWriter, rows: []const []const []const u8) !void {
    var csv = CsvWriter.init(writer);
    csv.delimiter = '\t';

    for (rows) |row| {
        try csv.writeRow(row);
    }
}
```

### Streaming Large CSV Files

Process CSV files without loading entire file into memory:

```zig
pub fn processLargeCsv(
    allocator: std.mem.Allocator,
    path: []const u8,
    processor: *const fn ([][]const u8) anyerror!void,
) !void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var reader_buffer: [8192]u8 = undefined;
    var file_reader = file.reader(&reader_buffer);

    var csv_reader = CsvReader.init(allocator, file_reader.any());
    defer csv_reader.deinit();

    while (try csv_reader.readRow(allocator)) |row| {
        defer {
            for (row) |field| allocator.free(field);
            allocator.free(row);
        }
        try processor(row);
    }
}
```

### Error Handling

Handle malformed CSV:

```zig
pub const CsvError = error{
    UnterminatedQuote,
    InvalidFormat,
    EmptyFile,
};

pub fn validateCsvRow(row: []const []const u8, expected_fields: usize) !void {
    if (row.len != expected_fields) {
        return error.InvalidFormat;
    }
}
```

### CSV Escaping Rules

The CSV escaping rules:
1. Fields containing delimiter, quote, or newline must be quoted
2. Quotes inside quoted fields are doubled (`""`)
3. Leading/trailing whitespace preserved in quoted fields
4. Empty fields represented as empty string

Examples:
```
Normal field          -> Normal field
Field, with comma     -> "Field, with comma"
Field with "quotes"   -> "Field with ""quotes"""
Field with
newline               -> "Field with
newline"
```

### Performance Tips

**Writing:**
- Use buffered writer for better performance
- Pre-allocate row arrays when possible
- Batch writes when generating many rows

**Reading:**
- Use buffered reader
- Process rows as you read (streaming)
- Reuse allocations where possible

**Memory:**
```zig
// Good: Process row by row
while (try csv.readRow(allocator)) |row| {
    defer {
        for (row) |field| allocator.free(field);
        allocator.free(row);
    }
    try processRow(row);
}

// Bad: Load entire file into memory
const all_rows = try readAllRows(allocator, reader);
defer freeAllRows(allocator, all_rows);
```

### Common Patterns

**Reading into structs:**
```zig
const Person = struct {
    name: []const u8,
    age: u32,
    city: []const u8,
};

pub fn parsePerson(row: []const []const u8) !Person {
    if (row.len != 3) return error.InvalidFormat;

    return .{
        .name = row[0],
        .age = try std.fmt.parseInt(u32, row[1], 10),
        .city = row[2],
    };
}
```

**Writing from database query results:**
```zig
pub fn exportQueryToCsv(
    query_results: []const QueryRow,
    writer: std.io.AnyWriter,
) !void {
    var csv = CsvWriter.init(writer);

    for (query_results) |result| {
        const row = [_][]const u8{
            result.column1,
            result.column2,
            result.column3,
        };
        try csv.writeRow(&row);
    }
}
```

### Unicode and Encoding

CSV files typically use UTF-8:
```zig
// Zig strings are UTF-8 by default, so this just works
try csv.writeRow(&.{ "Name", "Nom", "名前" });
```

For other encodings, you'd need to convert:
```zig
// Hypothetical: Convert from Latin-1 to UTF-8
const utf8_field = try convertLatin1ToUtf8(allocator, latin1_field);
defer allocator.free(utf8_field);
try csv.writeField(utf8_field);
```

### Related Formats

**TSV (Tab-Separated Values):**
- Same as CSV but uses tabs
- Less ambiguous (tabs rarely appear in data)
- Just set `delimiter = '\t'`

**RFC 4180 Compliance:**
- Standard CSV format specification
- Our implementation follows RFC 4180
- Handle CRLF vs LF line endings
- Optional header row

### Related Functions

- `std.mem.tokenizeAny()` - Simple field splitting
- `std.fmt.allocPrint()` - Format values as strings
- `std.io.AnyWriter` - Generic writer interface
- `std.io.AnyReader` - Generic reader interface
- `std.ArrayList` - Dynamic arrays
