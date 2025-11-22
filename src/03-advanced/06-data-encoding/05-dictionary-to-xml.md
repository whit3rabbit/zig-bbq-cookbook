## Problem

You need to convert Zig data structures (hash maps, structs, arrays) into XML format for configuration files, APIs, or data exchange.

## Solution

### Dict to XML

```zig
{{#include ../../../code/03-advanced/06-data-encoding/recipe_6_5.zig:dict_to_xml}}
```

### Struct to XML

```zig
{{#include ../../../code/03-advanced/06-data-encoding/recipe_6_5.zig:struct_to_xml}}
```

### XML Writer

```zig
{{#include ../../../code/03-advanced/06-data-encoding/recipe_6_5.zig:xml_writer}}
```
    defer allocator.free(xml);

    try std.testing.expect(std.mem.indexOf(u8, xml, "<person>") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml, "<name>Alice</name>") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml, "</person>") != null);
}
```

## Discussion

### Struct to XML

Convert structs to XML:

```zig
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
    inline for (info.Struct.fields) |field| {
        try xml.appendSlice(allocator, "  <");
        try xml.appendSlice(allocator, field.name);
        try xml.appendSlice(allocator, ">");

        const field_value = @field(value, field.name);
        const field_str = try std.fmt.allocPrint(allocator, "{any}", .{field_value});
        defer allocator.free(field_str);
        try xml.appendSlice(allocator, field_str);

        try xml.appendSlice(allocator, "</");
        try xml.appendSlice(allocator, field.name);
        try xml.appendSlice(allocator, ">\n");
    }

    try xml.appendSlice(allocator, "</");
    try xml.appendSlice(allocator, root_name);
    try xml.appendSlice(allocator, ">\n");

    return xml.toOwnedSlice(allocator);
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
}
```

### Array to XML

Convert arrays to XML:

```zig
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
        try xml.appendSlice(allocator, item_str);

        try xml.appendSlice(allocator, "</");
        try xml.appendSlice(allocator, item_name);
        try xml.appendSlice(allocator, ">\n");
    }

    try xml.appendSlice(allocator, "</");
    try xml.appendSlice(allocator, root_name);
    try xml.appendSlice(allocator, ">\n");

    return xml.toOwnedSlice(allocator);
}

test "array to XML" {
    const allocator = std.testing.allocator;

    const numbers = [_]u32{ 1, 2, 3, 4, 5 };

    const xml = try arrayToXml(allocator, u32, &numbers, "numbers", "number");
    defer allocator.free(xml);

    try std.testing.expect(std.mem.indexOf(u8, xml, "<numbers>") != null);
    try std.testing.expect(std.mem.indexOf(u8, xml, "<number>1</number>") != null);
}
```

### XML with Attributes

Add attributes to elements:

```zig
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
        try xml.appendSlice(allocator, attr.value_ptr.*);
        try xml.appendSlice(allocator, "\"");
    }

    try xml.appendSlice(allocator, ">\n");

    // Elements
    var iter = map.iterator();
    while (iter.next()) |entry| {
        try xml.appendSlice(allocator, "  <");
        try xml.appendSlice(allocator, entry.key_ptr.*);
        try xml.appendSlice(allocator, ">");
        try xml.appendSlice(allocator, entry.value_ptr.*);
        try xml.appendSlice(allocator, "</");
        try xml.appendSlice(allocator, entry.key_ptr.*);
        try xml.appendSlice(allocator, ">\n");
    }

    try xml.appendSlice(allocator, "</");
    try xml.appendSlice(allocator, root_name);
    try xml.appendSlice(allocator, ">\n");

    return xml.toOwnedSlice(allocator);
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
}
```

### Escaping XML Special Characters

Handle special characters:

```zig
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

test "escape XML" {
    const allocator = std.testing.allocator;

    const escaped = try escapeXml(allocator, "A < B & C > D");
    defer allocator.free(escaped);

    try std.testing.expectEqualStrings("A &lt; B &amp; C &gt; D", escaped);
}
```

### Nested Structures

Handle nested maps:

```zig
pub fn nestedDictToXml(
    allocator: std.mem.Allocator,
    map: std.StringHashMap(std.StringHashMap([]const u8)),
    root_name: []const u8,
) ![]u8 {
    var xml = std.ArrayList(u8){};
    errdefer xml.deinit(allocator);

    try xml.appendSlice(allocator, "<");
    try xml.appendSlice(allocator, root_name);
    try xml.appendSlice(allocator, ">\n");

    var iter = map.iterator();
    while (iter.next()) |entry| {
        try xml.appendSlice(allocator, "  <");
        try xml.appendSlice(allocator, entry.key_ptr.*);
        try xml.appendSlice(allocator, ">\n");

        var inner_iter = entry.value_ptr.iterator();
        while (inner_iter.next()) |inner| {
            try xml.appendSlice(allocator, "    <");
            try xml.appendSlice(allocator, inner.key_ptr.*);
            try xml.appendSlice(allocator, ">");
            try xml.appendSlice(allocator, inner.value_ptr.*);
            try xml.appendSlice(allocator, "</");
            try xml.appendSlice(allocator, inner.key_ptr.*);
            try xml.appendSlice(allocator, ">\n");
        }

        try xml.appendSlice(allocator, "  </");
        try xml.appendSlice(allocator, entry.key_ptr.*);
        try xml.appendSlice(allocator, ">\n");
    }

    try xml.appendSlice(allocator, "</");
    try xml.appendSlice(allocator, root_name);
    try xml.appendSlice(allocator, ">\n");

    return xml.toOwnedSlice(allocator);
}
```

### Pretty Printing

Format with indentation:

```zig
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
        try self.list.appendSlice(self.allocator, text);
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
};

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

    try std.testing.expect(std.mem.indexOf(u8, xml, "  <item>") != null);
}
```

### Best Practices

**Escaping:**
- Always escape special characters: `<`, `>`, `&`, `"`, `'`
- Use escaping for both element content and attribute values
- Consider CDATA sections for large text blocks

**Structure:**
```zig
// Use consistent naming
const xml = try dictToXml(allocator, map, "root");

// Validate element names (no spaces, start with letter)
fn isValidElementName(name: []const u8) bool {
    if (name.len == 0) return false;
    if (!std.ascii.isAlphabetic(name[0])) return false;
    for (name) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_' and c != '-') {
            return false;
        }
    }
    return true;
}
```

**Memory:**
- Use arena allocator for temporary XML generation
- Write directly to file for large documents
- Consider streaming for very large outputs

**Formatting:**
- Add XML declaration: `<?xml version="1.0" encoding="UTF-8"?>`
- Use consistent indentation
- Consider minified output for network transfer

### Related Functions

- `std.ArrayList()` - Dynamic string building
- `std.StringHashMap()` - Key-value storage
- `std.fmt.allocPrint()` - Format values
- `@typeInfo()` - Struct reflection
- `std.mem.indexOf()` - String search
- `std.ascii.isAlphanumeric()` - Character validation
