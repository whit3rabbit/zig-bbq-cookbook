const std = @import("std");
const testing = std.testing;

// ANCHOR: xml_element
pub const XmlElement = struct {
    name: []const u8,
    attributes: std.StringArrayHashMap([]const u8),
    content: ?[]const u8,
    children: std.ArrayList(*XmlElement),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !*XmlElement {
        const elem = try allocator.create(XmlElement);
        elem.* = .{
            .name = try allocator.dupe(u8, name),
            .attributes = std.StringArrayHashMap([]const u8).init(allocator),
            .content = null,
            .children = std.ArrayList(*XmlElement){},
            .allocator = allocator,
        };
        return elem;
    }

    pub fn deinit(self: *XmlElement) void {
        self.allocator.free(self.name);

        var it = self.attributes.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.attributes.deinit();

        if (self.content) |content| {
            self.allocator.free(content);
        }

        for (self.children.items) |child| {
            child.deinit();
            self.allocator.destroy(child);
        }
        self.children.deinit(self.allocator);
    }

    pub fn setAttribute(self: *XmlElement, key: []const u8, value: []const u8) !void {
        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);

        const result = try self.attributes.getOrPut(key);
        if (result.found_existing) {
            // Free old value when overwriting
            self.allocator.free(result.value_ptr.*);
            result.value_ptr.* = owned_value;
        } else {
            const owned_key = try self.allocator.dupe(u8, key);
            errdefer self.allocator.free(owned_key);
            result.key_ptr.* = owned_key;
            result.value_ptr.* = owned_value;
        }
    }

    pub fn setContent(self: *XmlElement, content: []const u8) !void {
        if (self.content) |old_content| {
            self.allocator.free(old_content);
        }
        self.content = try self.allocator.dupe(u8, content);
    }

    pub fn appendChild(self: *XmlElement, child: *XmlElement) !void {
        try self.children.append(self.allocator, child);
    }
};
// ANCHOR_END: xml_element

// ANCHOR: xml_writer
pub const XmlWriter = struct {
    allocator: std.mem.Allocator,
    indent_level: usize,
    pretty_print: bool,

    pub fn init(allocator: std.mem.Allocator, pretty_print: bool) XmlWriter {
        return .{
            .allocator = allocator,
            .indent_level = 0,
            .pretty_print = pretty_print,
        };
    }

    pub fn writeElement(self: *XmlWriter, element: *const XmlElement) ![]const u8 {
        var buffer = std.ArrayList(u8){};
        defer buffer.deinit(self.allocator);

        try self.writeElementInternal(&buffer, element);
        return buffer.toOwnedSlice(self.allocator);
    }

    fn writeElementInternal(self: *XmlWriter, buffer: *std.ArrayList(u8), element: *const XmlElement) !void {
        // Opening tag with indentation
        if (self.pretty_print) {
            for (0..self.indent_level) |_| {
                try buffer.appendSlice(self.allocator, "  ");
            }
        }

        try buffer.appendSlice(self.allocator, "<");
        try buffer.appendSlice(self.allocator, element.name);

        // Attributes
        var it = element.attributes.iterator();
        while (it.next()) |entry| {
            try buffer.appendSlice(self.allocator, " ");
            try buffer.appendSlice(self.allocator, entry.key_ptr.*);
            try buffer.appendSlice(self.allocator, "=\"");
            try self.writeEscaped(buffer, entry.value_ptr.*);
            try buffer.appendSlice(self.allocator, "\"");
        }

        // Self-closing tag if no content and no children
        if (element.content == null and element.children.items.len == 0) {
            try buffer.appendSlice(self.allocator, " />");
            if (self.pretty_print) try buffer.appendSlice(self.allocator, "\n");
            return;
        }

        try buffer.appendSlice(self.allocator, ">");

        // Content or children
        if (element.content) |content| {
            try self.writeEscaped(buffer, content);
        } else if (element.children.items.len > 0) {
            if (self.pretty_print) try buffer.appendSlice(self.allocator, "\n");

            self.indent_level += 1;
            for (element.children.items) |child| {
                try self.writeElementInternal(buffer, child);
            }
            self.indent_level -= 1;

            if (self.pretty_print) {
                for (0..self.indent_level) |_| {
                    try buffer.appendSlice(self.allocator, "  ");
                }
            }
        }

        // Closing tag
        try buffer.appendSlice(self.allocator, "</");
        try buffer.appendSlice(self.allocator, element.name);
        try buffer.appendSlice(self.allocator, ">");
        if (self.pretty_print) try buffer.appendSlice(self.allocator, "\n");
    }

    fn writeEscaped(self: *XmlWriter, buffer: *std.ArrayList(u8), text: []const u8) !void {
        for (text) |c| {
            switch (c) {
                '&' => try buffer.appendSlice(self.allocator, "&amp;"),
                '<' => try buffer.appendSlice(self.allocator, "&lt;"),
                '>' => try buffer.appendSlice(self.allocator, "&gt;"),
                '"' => try buffer.appendSlice(self.allocator, "&quot;"),
                '\'' => try buffer.appendSlice(self.allocator, "&apos;"),
                else => try buffer.append(self.allocator, c),
            }
        }
    }
};
// ANCHOR_END: xml_writer

// ANCHOR: xml_parser
pub const XmlParser = struct {
    allocator: std.mem.Allocator,
    input: []const u8,
    pos: usize,

    pub fn init(allocator: std.mem.Allocator, input: []const u8) XmlParser {
        return .{
            .allocator = allocator,
            .input = input,
            .pos = 0,
        };
    }

    pub fn parse(self: *XmlParser) !*XmlElement {
        self.skipWhitespace();
        return try self.parseElement();
    }

    fn parseElement(self: *XmlParser) !*XmlElement {
        // Expect '<'
        if (self.pos >= self.input.len or self.input[self.pos] != '<') {
            return error.InvalidXml;
        }
        self.pos += 1;

        // Parse tag name
        const name_start = self.pos;
        while (self.pos < self.input.len) {
            const c = self.input[self.pos];
            if (c == ' ' or c == '/' or c == '>') break;
            self.pos += 1;
        }
        const name = self.input[name_start..self.pos];

        const element = try XmlElement.init(self.allocator, name);
        errdefer {
            element.deinit();
            self.allocator.destroy(element);
        }

        // Parse attributes
        while (self.pos < self.input.len) {
            self.skipWhitespace();

            if (self.pos >= self.input.len) return error.InvalidXml;

            if (self.input[self.pos] == '>') {
                self.pos += 1;
                break;
            }

            if (self.input[self.pos] == '/') {
                if (self.pos + 1 >= self.input.len) return error.InvalidXml;
                if (self.input[self.pos + 1] == '>') {
                    self.pos += 2;
                    return element;
                }
            }

            // Parse attribute
            const attr_name_start = self.pos;
            while (self.pos < self.input.len and self.input[self.pos] != '=') {
                self.pos += 1;
            }
            const attr_name = std.mem.trim(u8, self.input[attr_name_start..self.pos], " \t\n\r");

            self.pos += 1; // Skip '='
            self.skipWhitespace();

            if (self.pos >= self.input.len) return error.InvalidXml;
            const quote = self.input[self.pos];
            self.pos += 1;

            const attr_value_start = self.pos;
            while (self.pos < self.input.len and self.input[self.pos] != quote) {
                self.pos += 1;
            }
            const attr_value = self.input[attr_value_start..self.pos];
            self.pos += 1; // Skip closing quote

            try element.setAttribute(attr_name, attr_value);
        }

        // Parse content or children
        const content_start = self.pos;
        var has_children = false;

        while (self.pos < self.input.len) {
            if (self.input[self.pos] == '<') {
                // Check if it's a closing tag
                if (self.pos + 1 >= self.input.len) return error.InvalidXml;
                if (self.input[self.pos + 1] == '/') {
                    // Found closing tag
                    if (!has_children and self.pos > content_start) {
                        const content = self.input[content_start..self.pos];
                        const trimmed = std.mem.trim(u8, content, " \t\n\r");
                        if (trimmed.len > 0) {
                            const unescaped = try self.unescapeXml(trimmed);
                            defer self.allocator.free(unescaped);
                            try element.setContent(unescaped);
                        }
                    }

                    // Skip to end of closing tag
                    while (self.pos < self.input.len and self.input[self.pos] != '>') {
                        self.pos += 1;
                    }
                    self.pos += 1;
                    break;
                } else {
                    // Child element
                    has_children = true;
                    const child = try self.parseElement();
                    try element.appendChild(child);
                }
            } else {
                self.pos += 1;
            }
        }

        return element;
    }

    fn skipWhitespace(self: *XmlParser) void {
        while (self.pos < self.input.len and std.mem.indexOfScalar(u8, " \t\n\r", self.input[self.pos]) != null) {
            self.pos += 1;
        }
    }

    fn unescapeXml(self: *XmlParser, text: []const u8) ![]const u8 {
        var result = std.ArrayList(u8){};
        defer result.deinit(self.allocator);

        var i: usize = 0;
        while (i < text.len) {
            if (text[i] == '&') {
                if (std.mem.startsWith(u8, text[i..], "&amp;")) {
                    try result.append(self.allocator, '&');
                    i += 5;
                } else if (std.mem.startsWith(u8, text[i..], "&lt;")) {
                    try result.append(self.allocator, '<');
                    i += 4;
                } else if (std.mem.startsWith(u8, text[i..], "&gt;")) {
                    try result.append(self.allocator, '>');
                    i += 4;
                } else if (std.mem.startsWith(u8, text[i..], "&quot;")) {
                    try result.append(self.allocator, '"');
                    i += 6;
                } else if (std.mem.startsWith(u8, text[i..], "&apos;")) {
                    try result.append(self.allocator, '\'');
                    i += 6;
                } else {
                    try result.append(self.allocator, text[i]);
                    i += 1;
                }
            } else {
                try result.append(self.allocator, text[i]);
                i += 1;
            }
        }

        return result.toOwnedSlice(self.allocator);
    }
};
// ANCHOR_END: xml_parser

// ANCHOR: test_element_creation
test "create basic XML element" {
    const element = try XmlElement.init(testing.allocator, "person");
    defer {
        element.deinit();
        testing.allocator.destroy(element);
    }

    try testing.expectEqualStrings("person", element.name);
    try testing.expectEqual(@as(usize, 0), element.children.items.len);
    try testing.expectEqual(@as(?[]const u8, null), element.content);
}
// ANCHOR_END: test_element_creation

// ANCHOR: test_element_attributes
test "element with attributes" {
    const element = try XmlElement.init(testing.allocator, "person");
    defer {
        element.deinit();
        testing.allocator.destroy(element);
    }

    try element.setAttribute("name", "Alice");
    try element.setAttribute("age", "30");

    const name = element.attributes.get("name");
    try testing.expect(name != null);
    try testing.expectEqualStrings("Alice", name.?);

    const age = element.attributes.get("age");
    try testing.expect(age != null);
    try testing.expectEqualStrings("30", age.?);
}
// ANCHOR_END: test_element_attributes

// ANCHOR: test_element_content
test "element with content" {
    const element = try XmlElement.init(testing.allocator, "message");
    defer {
        element.deinit();
        testing.allocator.destroy(element);
    }

    try element.setContent("Hello, World!");

    try testing.expect(element.content != null);
    try testing.expectEqualStrings("Hello, World!", element.content.?);
}
// ANCHOR_END: test_element_content

// ANCHOR: test_nested_elements
test "nested XML elements" {
    const root = try XmlElement.init(testing.allocator, "root");
    defer {
        root.deinit();
        testing.allocator.destroy(root);
    }

    const child1 = try XmlElement.init(testing.allocator, "child");
    try child1.setContent("First child");
    try root.appendChild(child1);

    const child2 = try XmlElement.init(testing.allocator, "child");
    try child2.setContent("Second child");
    try root.appendChild(child2);

    try testing.expectEqual(@as(usize, 2), root.children.items.len);
    try testing.expectEqualStrings("First child", root.children.items[0].content.?);
    try testing.expectEqualStrings("Second child", root.children.items[1].content.?);
}
// ANCHOR_END: test_nested_elements

// ANCHOR: test_write_simple
test "write simple XML element" {
    const element = try XmlElement.init(testing.allocator, "person");
    defer {
        element.deinit();
        testing.allocator.destroy(element);
    }

    try element.setAttribute("name", "Alice");
    try element.setContent("Software Engineer");

    var writer = XmlWriter.init(testing.allocator, false);
    const xml = try writer.writeElement(element);
    defer testing.allocator.free(xml);

    try testing.expectEqualStrings("<person name=\"Alice\">Software Engineer</person>", xml);
}
// ANCHOR_END: test_write_simple

// ANCHOR: test_write_nested
test "write nested XML elements" {
    const root = try XmlElement.init(testing.allocator, "people");
    defer {
        root.deinit();
        testing.allocator.destroy(root);
    }

    const person = try XmlElement.init(testing.allocator, "person");
    try person.setAttribute("id", "1");

    const name = try XmlElement.init(testing.allocator, "name");
    try name.setContent("Alice");
    try person.appendChild(name);

    const age = try XmlElement.init(testing.allocator, "age");
    try age.setContent("30");
    try person.appendChild(age);

    try root.appendChild(person);

    var writer = XmlWriter.init(testing.allocator, true);
    const xml = try writer.writeElement(root);
    defer testing.allocator.free(xml);

    const expected =
        \\<people>
        \\  <person id="1">
        \\    <name>Alice</name>
        \\    <age>30</age>
        \\  </person>
        \\</people>
        \\
    ;
    try testing.expectEqualStrings(expected, xml);
}
// ANCHOR_END: test_write_nested

// ANCHOR: test_write_self_closing
test "write self-closing XML element" {
    const element = try XmlElement.init(testing.allocator, "break");
    defer {
        element.deinit();
        testing.allocator.destroy(element);
    }

    var writer = XmlWriter.init(testing.allocator, false);
    const xml = try writer.writeElement(element);
    defer testing.allocator.free(xml);

    try testing.expectEqualStrings("<break />", xml);
}
// ANCHOR_END: test_write_self_closing

// ANCHOR: test_write_escaping
test "XML entity escaping" {
    const element = try XmlElement.init(testing.allocator, "data");
    defer {
        element.deinit();
        testing.allocator.destroy(element);
    }

    try element.setContent("<tag> & \"quotes\" 'apostrophes'");

    var writer = XmlWriter.init(testing.allocator, false);
    const xml = try writer.writeElement(element);
    defer testing.allocator.free(xml);

    try testing.expectEqualStrings("<data>&lt;tag&gt; &amp; &quot;quotes&quot; &apos;apostrophes&apos;</data>", xml);
}
// ANCHOR_END: test_write_escaping

// ANCHOR: test_parse_simple
test "parse simple XML" {
    const xml = "<person name=\"Alice\">Software Engineer</person>";

    var parser = XmlParser.init(testing.allocator, xml);
    const element = try parser.parse();
    defer {
        element.deinit();
        testing.allocator.destroy(element);
    }

    try testing.expectEqualStrings("person", element.name);
    try testing.expect(element.content != null);
    try testing.expectEqualStrings("Software Engineer", element.content.?);

    const name = element.attributes.get("name");
    try testing.expect(name != null);
    try testing.expectEqualStrings("Alice", name.?);
}
// ANCHOR_END: test_parse_simple

// ANCHOR: test_parse_nested
test "parse nested XML" {
    const xml =
        \\<person id="1">
        \\  <name>Alice</name>
        \\  <age>30</age>
        \\</person>
    ;

    var parser = XmlParser.init(testing.allocator, xml);
    const element = try parser.parse();
    defer {
        element.deinit();
        testing.allocator.destroy(element);
    }

    try testing.expectEqualStrings("person", element.name);
    try testing.expectEqual(@as(usize, 2), element.children.items.len);

    try testing.expectEqualStrings("name", element.children.items[0].name);
    try testing.expectEqualStrings("Alice", element.children.items[0].content.?);

    try testing.expectEqualStrings("age", element.children.items[1].name);
    try testing.expectEqualStrings("30", element.children.items[1].content.?);
}
// ANCHOR_END: test_parse_nested

// ANCHOR: test_parse_self_closing
test "parse self-closing element" {
    const xml = "<break />";

    var parser = XmlParser.init(testing.allocator, xml);
    const element = try parser.parse();
    defer {
        element.deinit();
        testing.allocator.destroy(element);
    }

    try testing.expectEqualStrings("break", element.name);
    try testing.expectEqual(@as(?[]const u8, null), element.content);
    try testing.expectEqual(@as(usize, 0), element.children.items.len);
}
// ANCHOR_END: test_parse_self_closing

// ANCHOR: test_roundtrip
test "XML roundtrip (write then parse)" {
    // Create element
    const original = try XmlElement.init(testing.allocator, "person");
    defer {
        original.deinit();
        testing.allocator.destroy(original);
    }

    try original.setAttribute("id", "123");
    try original.setContent("Test Person");

    // Write to XML
    var writer = XmlWriter.init(testing.allocator, false);
    const xml = try writer.writeElement(original);
    defer testing.allocator.free(xml);

    // Parse back
    var parser = XmlParser.init(testing.allocator, xml);
    const parsed = try parser.parse();
    defer {
        parsed.deinit();
        testing.allocator.destroy(parsed);
    }

    // Verify
    try testing.expectEqualStrings(original.name, parsed.name);
    try testing.expectEqualStrings(original.content.?, parsed.content.?);

    const id = parsed.attributes.get("id");
    try testing.expect(id != null);
    try testing.expectEqualStrings("123", id.?);
}
// ANCHOR_END: test_roundtrip

// ANCHOR: test_parse_unescape
test "parse XML with escaped entities" {
    const xml = "<data>&lt;tag&gt; &amp; &quot;quotes&quot;</data>";

    var parser = XmlParser.init(testing.allocator, xml);
    const element = try parser.parse();
    defer {
        element.deinit();
        testing.allocator.destroy(element);
    }

    try testing.expectEqualStrings("<tag> & \"quotes\"", element.content.?);
}
// ANCHOR_END: test_parse_unescape
