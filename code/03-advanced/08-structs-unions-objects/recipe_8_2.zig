const std = @import("std");

// ANCHOR: format_wrappers
/// Person with optional title
const Person = struct {
    name: []const u8,
    age: u32,
    title: ?[]const u8,

    pub fn format(self: Person, writer: anytype) !void {
        if (self.title) |t| {
            try writer.print("{s} {s}, age {d}", .{ t, self.name, self.age });
        } else {
            try writer.print("{s}, age {d}", .{ self.name, self.age });
        }
    }

    pub fn formatter(self: Person, comptime fmt_type: FormatType) PersonFormatter {
        return PersonFormatter{ .person = self, .fmt_type = fmt_type };
    }
};

const FormatType = enum { short, long, formal };

const PersonFormatter = struct {
    person: Person,
    fmt_type: FormatType,

    pub fn format(self: PersonFormatter, writer: anytype) !void {
        switch (self.fmt_type) {
            .short => try writer.print("{s}", .{self.person.name}),
            .long => try writer.print("{s} ({d} years old)", .{
                self.person.name,
                self.person.age,
            }),
            .formal => {
                if (self.person.title) |t| {
                    try writer.print("{s} {s}", .{ t, self.person.name });
                } else {
                    try writer.print("{s}", .{self.person.name});
                }
            },
        }
    }
};
// ANCHOR_END: format_wrappers

// ANCHOR: string_builder
/// String builder
const StringBuilder = struct {
    parts: std.ArrayList([]const u8),
    owned: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) StringBuilder {
        return .{
            .parts = std.ArrayList([]const u8){},
            .owned = std.ArrayList([]const u8){},
            .allocator = allocator,
        };
    }

    pub fn add(self: *StringBuilder, part: []const u8) !void {
        try self.parts.append(self.allocator, part);
    }

    pub fn addFmt(self: *StringBuilder, comptime fmt: []const u8, args: anytype) !void {
        const str = try std.fmt.allocPrint(self.allocator, fmt, args);
        try self.parts.append(self.allocator, str);
        try self.owned.append(self.allocator, str);
    }

    pub fn build(self: *StringBuilder) ![]const u8 {
        return try std.mem.join(self.allocator, "", self.parts.items);
    }

    pub fn deinit(self: *StringBuilder) void {
        for (self.owned.items) |part| {
            self.allocator.free(part);
        }
        self.parts.deinit(self.allocator);
        self.owned.deinit(self.allocator);
    }
};
// ANCHOR_END: string_builder

// ANCHOR: conditional_format
/// Article with status
const Status = enum { draft, published, archived };

const Article = struct {
    title: []const u8,
    author: []const u8,
    status: Status,
    views: usize,

    pub fn format(self: Article, writer: anytype) !void {
        try writer.print("\"{s}\" by {s} [", .{ self.title, self.author });

        switch (self.status) {
            .draft => try writer.writeAll("DRAFT"),
            .published => try writer.print("PUBLISHED, {d} views", .{self.views}),
            .archived => try writer.writeAll("ARCHIVED"),
        }

        try writer.writeAll("]");
    }
};
// ANCHOR_END: conditional_format

// ANCHOR: padded_formatter
/// Padded formatter
const PaddedFormatter = struct {
    value: []const u8,
    width: usize,
    align_left: bool,

    pub fn format(self: PaddedFormatter, writer: anytype) !void {
        const value_len = self.value.len;

        if (value_len >= self.width) {
            try writer.writeAll(self.value);
            return;
        }

        const padding = self.width - value_len;

        if (self.align_left) {
            try writer.writeAll(self.value);
            var i: usize = 0;
            while (i < padding) : (i += 1) {
                try writer.writeByte(' ');
            }
        } else {
            var i: usize = 0;
            while (i < padding) : (i += 1) {
                try writer.writeByte(' ');
            }
            try writer.writeAll(self.value);
        }
    }
};

fn padLeft(value: []const u8, width: usize) PaddedFormatter {
    return .{ .value = value, .width = width, .align_left = false };
}

fn padRight(value: []const u8, width: usize) PaddedFormatter {
    return .{ .value = value, .width = width, .align_left = true };
}
// ANCHOR_END: padded_formatter

// ANCHOR: table_formatter
/// Table formatter
const TableFormatter = struct {
    headers: []const []const u8,
    rows: []const []const []const u8,

    pub fn format(self: TableFormatter, writer: anytype) !void {
        // Calculate column widths
        var widths = [_]usize{0} ** 10;
        for (self.headers, 0..) |header, i| {
            widths[i] = header.len;
        }

        for (self.rows) |row| {
            for (row, 0..) |cell, i| {
                widths[i] = @max(widths[i], cell.len);
            }
        }

        // Print headers
        for (self.headers, 0..) |header, i| {
            if (i > 0) try writer.writeAll(" | ");
            try writer.writeAll(header);
            // Don't pad the last column
            if (i < self.headers.len - 1) {
                const padding = widths[i] - header.len;
                var p: usize = 0;
                while (p < padding) : (p += 1) {
                    try writer.writeByte(' ');
                }
            }
        }
        try writer.writeAll("\n");

        // Print separator
        for (self.headers, 0..) |_, i| {
            if (i > 0) try writer.writeAll("-+-");
            var d: usize = 0;
            while (d < widths[i]) : (d += 1) {
                try writer.writeByte('-');
            }
        }
        try writer.writeAll("\n");

        // Print rows
        for (self.rows) |row| {
            for (row, 0..) |cell, i| {
                if (i > 0) try writer.writeAll(" | ");
                try writer.writeAll(cell);
                // Don't pad the last column
                if (i < row.len - 1) {
                    const padding = widths[i] - cell.len;
                    var p: usize = 0;
                    while (p < padding) : (p += 1) {
                        try writer.writeByte(' ');
                    }
                }
            }
            try writer.writeAll("\n");
        }
    }
};
// ANCHOR_END: table_formatter

// ANCHOR: json_formatter
/// JSON-like formatter
const JsonLikeFormatter = struct {
    depth: usize = 0,

    pub fn formatStruct(
        self: JsonLikeFormatter,
        writer: anytype,
        name: []const u8,
        fields: []const Field,
    ) !void {
        // Write indent spaces
        var d: usize = 0;
        while (d < self.depth) : (d += 1) {
            try writer.writeAll("  ");
        }

        try writer.print("{s} {{\n", .{name});

        for (fields, 0..) |field, i| {
            // Write next indent
            var nd: usize = 0;
            while (nd < self.depth + 1) : (nd += 1) {
                try writer.writeAll("  ");
            }
            try writer.print("{s}: {s}", .{ field.name, field.value });

            if (i < fields.len - 1) {
                try writer.writeAll(",\n");
            } else {
                try writer.writeAll("\n");
            }
        }

        // Write closing indent
        d = 0;
        while (d < self.depth) : (d += 1) {
            try writer.writeAll("  ");
        }
        try writer.writeAll("}");
    }
};

const Field = struct {
    name: []const u8,
    value: []const u8,
};
// ANCHOR_END: json_formatter

// ANCHOR: color_formatter
/// Color formatter
const Color = enum {
    reset,
    red,
    green,
    yellow,
    blue,

    fn code(self: Color) []const u8 {
        return switch (self) {
            .reset => "\x1b[0m",
            .red => "\x1b[31m",
            .green => "\x1b[32m",
            .yellow => "\x1b[33m",
            .blue => "\x1b[34m",
        };
    }
};

const ColoredText = struct {
    text: []const u8,
    color: Color,

    pub fn format(self: ColoredText, writer: anytype) !void {
        try writer.writeAll(self.color.code());
        try writer.writeAll(self.text);
        try writer.writeAll(Color.reset.code());
    }
};

fn colored(text: []const u8, color: Color) ColoredText {
    return .{ .text = text, .color = color };
}
// ANCHOR_END: color_formatter

// ANCHOR: list_formatter
/// List formatter
const ListFormatter = struct {
    items: []const []const u8,
    separator: []const u8,
    prefix: []const u8,
    suffix: []const u8,

    pub fn format(self: ListFormatter, writer: anytype) !void {
        try writer.writeAll(self.prefix);

        for (self.items, 0..) |item, i| {
            try writer.writeAll(item);
            if (i < self.items.len - 1) {
                try writer.writeAll(self.separator);
            }
        }

        try writer.writeAll(self.suffix);
    }
};

fn listFmt(items: []const []const u8, separator: []const u8) ListFormatter {
    return .{
        .items = items,
        .separator = separator,
        .prefix = "",
        .suffix = "",
    };
}

fn bracketedList(items: []const []const u8, separator: []const u8) ListFormatter {
    return .{
        .items = items,
        .separator = separator,
        .prefix = "[",
        .suffix = "]",
    };
}
// ANCHOR_END: list_formatter

// Tests

test "format wrappers short" {
    const person = Person{
        .name = "Smith",
        .age = 35,
        .title = "Dr.",
    };

    var buf: [100]u8 = undefined;
    const short = try std.fmt.bufPrint(&buf, "{f}", .{person.formatter(.short)});
    try std.testing.expectEqualStrings("Smith", short);
}

test "format wrappers long" {
    const person = Person{
        .name = "Smith",
        .age = 35,
        .title = "Dr.",
    };

    var buf: [100]u8 = undefined;
    const long = try std.fmt.bufPrint(&buf, "{f}", .{person.formatter(.long)});
    try std.testing.expectEqualStrings("Smith (35 years old)", long);
}

test "format wrappers formal" {
    const person = Person{
        .name = "Smith",
        .age = 35,
        .title = "Dr.",
    };

    var buf: [100]u8 = undefined;
    const formal = try std.fmt.bufPrint(&buf, "{f}", .{person.formatter(.formal)});
    try std.testing.expectEqualStrings("Dr. Smith", formal);
}

test "string builder" {
    const allocator = std.testing.allocator;

    var builder = StringBuilder.init(allocator);
    defer builder.deinit();

    try builder.add("Hello ");
    try builder.addFmt("{s}!", .{"World"});
    try builder.addFmt(" Count: {d}", .{42});

    const result = try builder.build();
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello World! Count: 42", result);
}

test "conditional formatting draft" {
    var buf: [200]u8 = undefined;

    const draft = Article{
        .title = "My Article",
        .author = "Alice",
        .status = .draft,
        .views = 0,
    };

    const result = try std.fmt.bufPrint(&buf, "{f}", .{draft});
    try std.testing.expectEqualStrings("\"My Article\" by Alice [DRAFT]", result);
}

test "conditional formatting published" {
    var buf: [200]u8 = undefined;

    const published = Article{
        .title = "Published Work",
        .author = "Bob",
        .status = .published,
        .views = 1234,
    };

    const result = try std.fmt.bufPrint(&buf, "{f}", .{published});
    try std.testing.expectEqualStrings("\"Published Work\" by Bob [PUBLISHED, 1234 views]", result);
}

test "padded formatting left" {
    var buf: [100]u8 = undefined;

    const left = try std.fmt.bufPrint(&buf, "{f}", .{padLeft("test", 10)});
    try std.testing.expectEqualStrings("      test", left);
}

test "padded formatting right" {
    var buf: [100]u8 = undefined;

    const right = try std.fmt.bufPrint(&buf, "{f}", .{padRight("test", 10)});
    try std.testing.expectEqualStrings("test      ", right);
}

test "table formatter" {
    const headers = [_][]const u8{ "Name", "Age", "City" };
    const row1 = [_][]const u8{ "Alice", "30", "NYC" };
    const row2 = [_][]const u8{ "Bob", "25", "LA" };
    const rows = [_][]const []const u8{ &row1, &row2 };

    const table = TableFormatter{
        .headers = &headers,
        .rows = &rows,
    };

    var buf: [500]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    try table.format(stream.writer());

    const expected =
        \\Name  | Age | City
        \\------+-----+-----
        \\Alice | 30  | NYC
        \\Bob   | 25  | LA
        \\
    ;

    try std.testing.expectEqualStrings(expected, stream.getWritten());
}

test "json-like formatter" {
    const fields = [_]Field{
        .{ .name = "name", .value = "\"Alice\"" },
        .{ .name = "age", .value = "30" },
        .{ .name = "active", .value = "true" },
    };

    var buf: [500]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);

    const formatter = JsonLikeFormatter{};
    try formatter.formatStruct(stream.writer(), "User", &fields);

    const expected =
        \\User {
        \\  name: "Alice",
        \\  age: 30,
        \\  active: true
        \\}
    ;

    try std.testing.expectEqualStrings(expected, stream.getWritten());
}

test "colored formatter" {
    var buf: [500]u8 = undefined;

    const result = try std.fmt.bufPrint(&buf, "{f} {f} {f}", .{
        colored("Error", .red),
        colored("Warning", .yellow),
        colored("Success", .green),
    });

    try std.testing.expect(std.mem.indexOf(u8, result, "\x1b[31m") != null);
    try std.testing.expect(std.mem.indexOf(u8, result, "Error") != null);
}

test "list formatter comma" {
    const items = [_][]const u8{ "apple", "banana", "cherry" };

    var buf: [100]u8 = undefined;

    const comma = try std.fmt.bufPrint(&buf, "{f}", .{listFmt(&items, ", ")});
    try std.testing.expectEqualStrings("apple, banana, cherry", comma);
}

test "list formatter bracketed" {
    const items = [_][]const u8{ "apple", "banana", "cherry" };

    var buf: [100]u8 = undefined;

    const bracketed = try std.fmt.bufPrint(&buf, "{f}", .{bracketedList(&items, ", ")});
    try std.testing.expectEqualStrings("[apple, banana, cherry]", bracketed);
}

test "person default format" {
    const person = Person{
        .name = "Smith",
        .age = 35,
        .title = "Dr.",
    };

    var buf: [100]u8 = undefined;
    const result = try std.fmt.bufPrint(&buf, "{f}", .{person});
    try std.testing.expectEqualStrings("Dr. Smith, age 35", result);
}

test "person without title" {
    const person = Person{
        .name = "Johnson",
        .age = 28,
        .title = null,
    };

    var buf: [100]u8 = undefined;
    const result = try std.fmt.bufPrint(&buf, "{f}", .{person});
    try std.testing.expectEqualStrings("Johnson, age 28", result);
}
