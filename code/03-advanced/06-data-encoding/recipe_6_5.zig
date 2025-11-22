const std = @import("std");

// ANCHOR: dict_to_xml
/// Convert hash map to XML
pub fn dictToXml(
    allocator: std.mem.Allocator,
    map: std.StringHashMap([]const u8),
    root_name: []const u8,
) ![]u8 {
    var xml = std.ArrayList(u8){};
    errdefer xml.deinit(allocator);

    // Write opening tag
    try xml.appendSlice(allocator, "<");
    try xml.appendSlice(allocator, root_name);
    try xml.appendSlice(allocator, ">\n");

    // Write entries
    var iter = map.iterator();
    while (iter.next()) |entry| {
        try xml.appendSlice(allocator, "  <");
        try xml.appendSlice(allocator, entry.key_ptr.*);
        try xml.appendSlice(allocator, ">");

        // Escape value to prevent XML injection
        const escaped_value = try escapeXml(allocator, entry.value_ptr.*);
        defer allocator.free(escaped_value);
        try xml.appendSlice(allocator, escaped_value);

        try xml.appendSlice(allocator, "</");
        try xml.appendSlice(allocator, entry.key_ptr.*);
        try xml.appendSlice(allocator, ">\n");
    }

    // Write closing tag
    try xml.appendSlice(allocator, "</");
    try xml.appendSlice(allocator, root_name);
    try xml.appendSlice(allocator, ">\n");

    return xml.toOwnedSlice(allocator);
}
// ANCHOR_END: dict_to_xml

// ANCHOR: struct_to_xml
/// Convert struct to XML using reflection
pub fn structToXml(
    allocator: std.mem.Allocator,
    comptime T: type,
    value: T,
    root_name: []const u8,
) ![]u8 {
    var xml = std.ArrayList(u8){};
    errdefer xml.deinit(allocator);

    try xml.appendSlice(allocator, "<");
    try xml.appendSlice(allocator, root_name);
    try xml.appendSlice(allocator, ">\n");

    const info = @typeInfo(T);
    switch (info) {
        .@"struct" => |struct_info| {
            inline for (struct_info.fields) |field| {
                try xml.appendSlice(allocator, "  <");
                try xml.appendSlice(allocator, field.name);
                try xml.appendSlice(allocator, ">");

                const field_value = @field(value, field.name);
                const FieldType = @TypeOf(field_value);
                const field_str = if (FieldType == []const u8 or FieldType == []u8)
                    try std.fmt.allocPrint(allocator, "{s}", .{field_value})
                else
                    try std.fmt.allocPrint(allocator, "{any}", .{field_value});
                defer allocator.free(field_str);

                // Escape field value to prevent XML injection
                const escaped_field = try escapeXml(allocator, field_str);
                defer allocator.free(escaped_field);
                try xml.appendSlice(allocator, escaped_field);

                try xml.appendSlice(allocator, "</");
                try xml.appendSlice(allocator, field.name);
                try xml.appendSlice(allocator, ">\n");
            }
        },
        else => return error.UnsupportedType,
    }

    try xml.appendSlice(allocator, "</");
    try xml.appendSlice(allocator, root_name);
    try xml.appendSlice(allocator, ">\n");

    return xml.toOwnedSlice(allocator);
}
// ANCHOR_END: struct_to_xml

/// Convert array to XML
pub fn arrayToXml(
    allocator: std.mem.Allocator,
    comptime T: type,
    items: []const T,
    root_name: []const u8,
    item_name: []const u8,
) ![]u8 {
    var xml = std.ArrayList(u8){};
    errdefer xml.deinit(allocator);

    try xml.appendSlice(allocator, "<");
    try xml.appendSlice(allocator, root_name);
    try xml.appendSlice(allocator, ">\n");

    for (items) |item| {
        try xml.appendSlice(allocator, "  <");
        try xml.appendSlice(allocator, item_name);
        try xml.appendSlice(allocator, ">");

        const item_str = try std.fmt.allocPrint(allocator, "{any}", .{item});
        defer allocator.free(item_str);

        // Escape item value to prevent XML injection
        const escaped_item = try escapeXml(allocator, item_str);
        defer allocator.free(escaped_item);
        try xml.appendSlice(allocator, escaped_item);

        try xml.appendSlice(allocator, "</");
        try xml.appendSlice(allocator, item_name);
        try xml.appendSlice(allocator, ">\n");
    }

    try xml.appendSlice(allocator, "</");
    try xml.appendSlice(allocator, root_name);
    try xml.appendSlice(allocator, ">\n");

    return xml.toOwnedSlice(allocator);
}

/// Convert hash map to XML with attributes
pub fn dictToXmlWithAttrs(
    allocator: std.mem.Allocator,
    map: std.StringHashMap([]const u8),
    attrs: std.StringHashMap([]const u8),
    root_name: []const u8,
) ![]u8 {
    var xml = std.ArrayList(u8){};
    errdefer xml.deinit(allocator);

    // Opening tag with attributes
    try xml.appendSlice(allocator, "<");
    try xml.appendSlice(allocator, root_name);

    var attr_iter = attrs.iterator();
    while (attr_iter.next()) |attr| {
        try xml.appendSlice(allocator, " ");
        try xml.appendSlice(allocator, attr.key_ptr.*);
        try xml.appendSlice(allocator, "=\"");

        // Escape attribute value to prevent XML injection
        const escaped_attr = try escapeXml(allocator, attr.value_ptr.*);
        defer allocator.free(escaped_attr);
        try xml.appendSlice(allocator, escaped_attr);

        try xml.appendSlice(allocator, "\"");
    }

    try xml.appendSlice(allocator, ">\n");

    // Elements
    var iter = map.iterator();
    while (iter.next()) |entry| {
        try xml.appendSlice(allocator, "  <");
        try xml.appendSlice(allocator, entry.key_ptr.*);
        try xml.appendSlice(allocator, ">");

        // Escape element value to prevent XML injection
        const escaped_value = try escapeXml(allocator, entry.value_ptr.*);
        defer allocator.free(escaped_value);
        try xml.appendSlice(allocator, escaped_value);

        try xml.appendSlice(allocator, "</");
        try xml.appendSlice(allocator, entry.key_ptr.*);
        try xml.appendSlice(allocator, ">\n");
    }

    try xml.appendSlice(allocator, "</");
    try xml.appendSlice(allocator, root_name);
    try xml.appendSlice(allocator, ">\n");

    return xml.toOwnedSlice(allocator);
}

/// Escape XML special characters
pub fn escapeXml(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    for (text) |char| {
        switch (char) {
            '<' => try result.appendSlice(allocator, "&lt;"),
            '>' => try result.appendSlice(allocator, "&gt;"),
            '&' => try result.appendSlice(allocator, "&amp;"),
            '"' => try result.appendSlice(allocator, "&quot;"),
            '\'' => try result.appendSlice(allocator, "&apos;"),
            else => try result.append(allocator, char),
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Validate XML element name
pub fn isValidElementName(name: []const u8) bool {
    if (name.len == 0) return false;
    if (!std.ascii.isAlphabetic(name[0]) and name[0] != '_') return false;
    for (name) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '-' and c != '.') {
            return false;
        }
    }
    return true;
}

// ANCHOR: xml_writer
/// XML writer with pretty printing
pub const XmlWriter = struct {
    list: std.ArrayList(u8),
    indent_level: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) XmlWriter {
        return .{
            .list = std.ArrayList(u8){},
            .indent_level = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *XmlWriter) void {
        self.list.deinit(self.allocator);
    }

    pub fn startElement(self: *XmlWriter, name: []const u8) !void {
        try self.writeIndent();
        try self.list.appendSlice(self.allocator, "<");
        try self.list.appendSlice(self.allocator, name);
        try self.list.appendSlice(self.allocator, ">\n");
        self.indent_level += 1;
    }

    pub fn endElement(self: *XmlWriter, name: []const u8) !void {
        self.indent_level -= 1;
        try self.writeIndent();
        try self.list.appendSlice(self.allocator, "</");
        try self.list.appendSlice(self.allocator, name);
        try self.list.appendSlice(self.allocator, ">\n");
    }

    pub fn writeText(self: *XmlWriter, text: []const u8) !void {
        // Escape text to prevent XML injection
        const escaped_text = try escapeXml(self.allocator, text);
        defer self.allocator.free(escaped_text);
        try self.list.appendSlice(self.allocator, escaped_text);
    }

    pub fn toOwnedSlice(self: *XmlWriter) ![]u8 {
        return self.list.toOwnedSlice(self.allocator);
    }

    fn writeIndent(self: *XmlWriter) !void {
        var i: usize = 0;
        while (i < self.indent_level) : (i += 1) {
            try self.list.appendSlice(self.allocator, "  ");
        }
    }

    pub fn startElementWithAttrs(
        self: *XmlWriter,
        name: []const u8,
        attrs: std.StringHashMap([]const u8),
    ) !void {
        try self.writeIndent();
        try self.list.appendSlice(self.allocator, "<");
        try self.list.appendSlice(self.allocator, name);

        var iter = attrs.iterator();
        while (iter.next()) |attr| {
            try self.list.appendSlice(self.allocator, " ");
            try self.list.appendSlice(self.allocator, attr.key_ptr.*);
            try self.list.appendSlice(self.allocator, "=\"");

            // Escape attribute value to prevent XML injection
            const escaped_attr = try escapeXml(self.allocator, attr.value_ptr.*);
            defer self.allocator.free(escaped_attr);
            try self.list.appendSlice(self.allocator, escaped_attr);

            try self.list.appendSlice(self.allocator, "\"");
        }

        try self.list.appendSlice(self.allocator, ">\n");
        self.indent_level += 1;
    }

    pub fn writeElement(self: *XmlWriter, name: []const u8, text: []const u8) !void {
        try self.writeIndent();
        try self.list.appendSlice(self.allocator, "<");
        try self.list.appendSlice(self.allocator, name);
        try self.list.appendSlice(self.allocator, ">");

        // Escape text to prevent XML injection
        const escaped_text = try escapeXml(self.allocator, text);
        defer self.allocator.free(escaped_text);
        try self.list.appendSlice(self.allocator, escaped_text);

        try self.list.appendSlice(self.allocator, "</");
        try self.list.appendSlice(self.allocator, name);
        try self.list.appendSlice(self.allocator, ">\n");
    }
};
// ANCHOR_END: xml_writer

/// Add XML declaration
pub fn addXmlDeclaration(allocator: std.mem.Allocator, xml: []const u8) ![]u8 {
    const declaration = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
    return std.fmt.allocPrint(allocator, "{s}{s}", .{ declaration, xml });
}

// Tests

test "dict to XML" {
    const allocator = std.testing.allocator;

    var map = std.StringHashMap([]const u8).init(allocator);
    defer map.deinit();

    try map.put("name", "Alice");
    try map.put("age", "30");

    const xml = try dictToXml(allocator, map, "person");
    defer allocator.free(xml);

    try std.testing.expect(std.mem.indexOf(u8, xml, "<person>") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml, "<name>Alice</name>") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml, "<age>30</age>") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml, "</person>") != null);
}

test "struct to XML" {
    const allocator = std.testing.allocator;

    const Person = struct {
        name: []const u8,
        age: u32,
    };

    const person = Person{
        .name = "Bob",
        .age = 25,
    };

    const xml = try structToXml(allocator, Person, person, "person");
    defer allocator.free(xml);

    try std.testing.expect(std.mem.indexOf(u8, xml, "<person>") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml, "<name>Bob</name>") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml, "<age>25</age>") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml, "</person>") != null);
}

test "array to XML" {
    const allocator = std.testing.allocator;

    const numbers = [_]u32{ 1, 2, 3, 4, 5 };

    const xml = try arrayToXml(allocator, u32, &numbers, "numbers", "number");
    defer allocator.free(xml);

    try std.testing.expect(std.mem.indexOf(u8, xml, "<numbers>") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml, "<number>1</number>") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml, "<number>5</number>") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml, "</numbers>") != null);
}

test "XML with attributes" {
    const allocator = std.testing.allocator;

    var map = std.StringHashMap([]const u8).init(allocator);
    defer map.deinit();
    try map.put("title", "Book");

    var attrs = std.StringHashMap([]const u8).init(allocator);
    defer attrs.deinit();
    try attrs.put("id", "123");
    try attrs.put("version", "1.0");

    const xml = try dictToXmlWithAttrs(allocator, map, attrs, "item");
    defer allocator.free(xml);

    try std.testing.expect(std.mem.indexOf(u8, xml, "id=\"123\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml, "version=\"1.0\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml, "<title>Book</title>") != null);
}

test "escape XML" {
    const allocator = std.testing.allocator;

    const escaped = try escapeXml(allocator, "A < B & C > D");
    defer allocator.free(escaped);

    try std.testing.expectEqualStrings("A &lt; B &amp; C &gt; D", escaped);
}

test "escape XML quotes" {
    const allocator = std.testing.allocator;

    const escaped = try escapeXml(allocator, "Say \"Hello\" & 'World'");
    defer allocator.free(escaped);

    try std.testing.expect(std.mem.indexOf(u8, escaped, "&quot;") != null);
    try std.testing.expect(std.mem.indexOf(u8, escaped, "&apos;") != null);
    try std.testing.expect(std.mem.indexOf(u8, escaped, "&amp;") != null);
}

test "valid element names" {
    try std.testing.expect(isValidElementName("root"));
    try std.testing.expect(isValidElementName("my_element"));
    try std.testing.expect(isValidElementName("element-123"));
    try std.testing.expect(isValidElementName("_private"));

    try std.testing.expect(!isValidElementName(""));
    try std.testing.expect(!isValidElementName("123start"));
    try std.testing.expect(!isValidElementName("has space"));
    try std.testing.expect(!isValidElementName("has@symbol"));
}

test "XML writer" {
    const allocator = std.testing.allocator;

    var writer = XmlWriter.init(allocator);
    defer writer.deinit();

    try writer.startElement("root");
    try writer.startElement("item");
    try writer.writeText("value");
    try writer.endElement("item");
    try writer.endElement("root");

    const xml = try writer.toOwnedSlice();
    defer allocator.free(xml);

    try std.testing.expect(std.mem.indexOf(u8, xml, "<root>") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml, "  <item>") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml, "</root>") != null);
}

test "XML writer with attributes" {
    const allocator = std.testing.allocator;

    var writer = XmlWriter.init(allocator);
    defer writer.deinit();

    var attrs = std.StringHashMap([]const u8).init(allocator);
    defer attrs.deinit();
    try attrs.put("id", "42");

    try writer.startElementWithAttrs("item", attrs);
    try writer.writeText("content");
    try writer.endElement("item");

    const xml = try writer.toOwnedSlice();
    defer allocator.free(xml);

    try std.testing.expect(std.mem.indexOf(u8, xml, "id=\"42\"") != null);
}

test "XML writer write element" {
    const allocator = std.testing.allocator;

    var writer = XmlWriter.init(allocator);
    defer writer.deinit();

    try writer.startElement("root");
    try writer.writeElement("name", "Alice");
    try writer.writeElement("age", "30");
    try writer.endElement("root");

    const xml = try writer.toOwnedSlice();
    defer allocator.free(xml);

    try std.testing.expect(std.mem.indexOf(u8, xml, "<name>Alice</name>") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml, "<age>30</age>") != null);
}

test "empty dict to XML" {
    const allocator = std.testing.allocator;

    var map = std.StringHashMap([]const u8).init(allocator);
    defer map.deinit();

    const xml = try dictToXml(allocator, map, "empty");
    defer allocator.free(xml);

    try std.testing.expect(std.mem.indexOf(u8, xml, "<empty>") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml, "</empty>") != null);
}

test "empty array to XML" {
    const allocator = std.testing.allocator;

    const numbers: []const u32 = &.{};

    const xml = try arrayToXml(allocator, u32, numbers, "numbers", "number");
    defer allocator.free(xml);

    try std.testing.expect(std.mem.indexOf(u8, xml, "<numbers>") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml, "</numbers>") != null);
}

test "struct with bool to XML" {
    const allocator = std.testing.allocator;

    const Config = struct {
        enabled: bool,
        count: i32,
    };

    const config = Config{
        .enabled = true,
        .count = -5,
    };

    const xml = try structToXml(allocator, Config, config, "config");
    defer allocator.free(xml);

    try std.testing.expect(std.mem.indexOf(u8, xml, "<enabled>true</enabled>") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml, "<count>-5</count>") != null);
}

test "add XML declaration" {
    const allocator = std.testing.allocator;

    const simple_xml = "<root/>";
    const with_declaration = try addXmlDeclaration(allocator, simple_xml);
    defer allocator.free(with_declaration);

    try std.testing.expect(std.mem.startsWith(u8, with_declaration, "<?xml version=\"1.0\""));
    try std.testing.expect(std.mem.indexOf(u8, with_declaration, "<root/>") != null);
}

test "escape empty string" {
    const allocator = std.testing.allocator;

    const escaped = try escapeXml(allocator, "");
    defer allocator.free(escaped);

    try std.testing.expectEqualStrings("", escaped);
}

test "escape no special chars" {
    const allocator = std.testing.allocator;

    const escaped = try escapeXml(allocator, "Normal text 123");
    defer allocator.free(escaped);

    try std.testing.expectEqualStrings("Normal text 123", escaped);
}

test "prevent XML injection in dict" {
    const allocator = std.testing.allocator;

    var map = std.StringHashMap([]const u8).init(allocator);
    defer map.deinit();

    // Attempt XML injection via malicious value
    try map.put("name", "</name><admin>true</admin><name>");

    const xml = try dictToXml(allocator, map, "user");
    defer allocator.free(xml);

    // Verify malicious tags are escaped and not executable
    try std.testing.expect(std.mem.indexOf(u8, xml, "&lt;/name&gt;") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml, "&lt;admin&gt;") != null);
    // Ensure raw tags are NOT present
    try std.testing.expect(std.mem.indexOf(u8, xml, "<admin>") == null);
}

test "prevent XML injection in attributes" {
    const allocator = std.testing.allocator;

    var map = std.StringHashMap([]const u8).init(allocator);
    defer map.deinit();
    try map.put("title", "Book");

    var attrs = std.StringHashMap([]const u8).init(allocator);
    defer attrs.deinit();
    // Attempt injection via attribute value
    try attrs.put("id", "\"><script>alert('xss')</script><x y=\"");

    const xml = try dictToXmlWithAttrs(allocator, map, attrs, "item");
    defer allocator.free(xml);

    // Verify malicious content is escaped
    try std.testing.expect(std.mem.indexOf(u8, xml, "&quot;&gt;&lt;script&gt;") != null);
    // Ensure raw script tag is NOT present
    try std.testing.expect(std.mem.indexOf(u8, xml, "<script>") == null);
}
