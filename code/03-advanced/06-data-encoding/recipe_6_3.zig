const std = @import("std");

// XML Element structure
pub const XmlElement = struct {
    name: []const u8,
    attributes: std.StringHashMap([]const u8),
    text: ?[]const u8 = null,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *XmlElement) void {
        self.attributes.deinit();
    }
};

// XML Node for nested structures
pub const XmlNode = struct {
    name: []const u8,
    text: ?[]const u8 = null,
    children: []XmlNode = &.{},
    attributes: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn deinit(self: *XmlNode) void {
        for (self.children) |*child| {
            child.deinit();
        }
        self.allocator.free(self.children);
        self.attributes.deinit();
    }
};

// ANCHOR: find_element
/// Find a single XML element by tag name
/// NOTE: This is a naive implementation for simple, well-formed XML.
/// For robust parsing with proper handling of edge cases, attributes,
/// and complex XML structures, see recipe_6_4.zig (StreamingXmlParser).
pub fn findElement(xml: []const u8, tag: []const u8) ?[]const u8 {
    const open_tag = std.fmt.allocPrint(
        std.heap.page_allocator,
        "<{s}",
        .{tag},
    ) catch return null;
    defer std.heap.page_allocator.free(open_tag);

    const close_tag = std.fmt.allocPrint(
        std.heap.page_allocator,
        "</{s}>",
        .{tag},
    ) catch return null;
    defer std.heap.page_allocator.free(close_tag);

    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, xml, pos, open_tag)) |start| {
        // Verify this is an exact tag match, not a prefix
        // e.g., searching for <user should not match <username>
        const char_after_tag = start + open_tag.len;
        if (char_after_tag < xml.len) {
            const next_char = xml[char_after_tag];
            // Check for valid tag boundaries: '>', ' ', '\t', '\n', '\r', '/'
            if (next_char == '>' or next_char == ' ' or next_char == '\t' or
                next_char == '\n' or next_char == '\r' or next_char == '/')
            {
                // This is a valid tag match
                const tag_end = std.mem.indexOfPos(u8, xml, start, ">") orelse return null;
                const end = std.mem.indexOfPos(u8, xml, tag_end, close_tag) orelse return null;
                return xml[tag_end + 1 .. end];
            }
        }
        // Not a valid match, continue searching
        pos = start + open_tag.len;
    }

    return null;
}
// ANCHOR_END: find_element

/// Parse a simple XML element
pub fn parseSimpleElement(
    allocator: std.mem.Allocator,
    xml: []const u8,
    tag: []const u8,
) !?XmlElement {
    const content = findElement(xml, tag) orelse return null;

    const element = XmlElement{
        .name = tag,
        .attributes = std.StringHashMap([]const u8).init(allocator),
        .text = content,
        .allocator = allocator,
    };

    return element;
}

// ANCHOR: parse_attributes
/// Parse attributes from an XML tag
pub fn parseAttributes(
    allocator: std.mem.Allocator,
    tag_content: []const u8,
) !std.StringHashMap([]const u8) {
    var attrs = std.StringHashMap([]const u8).init(allocator);
    errdefer attrs.deinit();

    // First, remove the element name
    const first_space = std.mem.indexOfAny(u8, tag_content, " \t\n\r") orelse return attrs;
    const attrs_part = std.mem.trim(u8, tag_content[first_space..], " \t\n\r");

    var i: usize = 0;
    while (i < attrs_part.len) {
        // Skip whitespace
        while (i < attrs_part.len and (attrs_part[i] == ' ' or attrs_part[i] == '\t' or attrs_part[i] == '\n' or attrs_part[i] == '\r')) {
            i += 1;
        }
        if (i >= attrs_part.len) break;

        // Find key
        const key_start = i;
        while (i < attrs_part.len and attrs_part[i] != '=' and attrs_part[i] != ' ' and attrs_part[i] != '\t') {
            i += 1;
        }
        const key = std.mem.trim(u8, attrs_part[key_start..i], " \t");

        // Skip whitespace and =
        while (i < attrs_part.len and (attrs_part[i] == ' ' or attrs_part[i] == '\t' or attrs_part[i] == '=')) {
            i += 1;
        }
        if (i >= attrs_part.len) break;

        // Find value
        var value: []const u8 = undefined;
        if (attrs_part[i] == '"') {
            // Quoted value
            i += 1;
            const value_start = i;
            while (i < attrs_part.len and attrs_part[i] != '"') {
                i += 1;
            }
            value = attrs_part[value_start..i];
            if (i < attrs_part.len) i += 1; // Skip closing quote
        } else {
            // Unquoted value
            const value_start = i;
            while (i < attrs_part.len and attrs_part[i] != ' ' and attrs_part[i] != '\t') {
                i += 1;
            }
            value = attrs_part[value_start..i];
        }

        try attrs.put(key, value);
    }

    return attrs;
}
// ANCHOR_END: parse_attributes

// ANCHOR: find_all_elements
/// Find all elements with a given tag
/// NOTE: This is a naive implementation for simple, well-formed XML.
/// For robust parsing, see recipe_6_4.zig (StreamingXmlParser).
pub fn findAllElements(
    allocator: std.mem.Allocator,
    xml: []const u8,
    tag: []const u8,
) ![][]const u8 {
    var results: std.ArrayList([]const u8) = .{};
    errdefer results.deinit(allocator);

    const open_tag = try std.fmt.allocPrint(allocator, "<{s}", .{tag});
    defer allocator.free(open_tag);

    const close_tag = try std.fmt.allocPrint(allocator, "</{s}>", .{tag});
    defer allocator.free(close_tag);

    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, xml, pos, open_tag)) |start| {
        // Verify this is an exact tag match, not a prefix
        // e.g., searching for <user should not match <username>
        const char_after_tag = start + open_tag.len;
        if (char_after_tag < xml.len) {
            const next_char = xml[char_after_tag];
            // Check for valid tag boundaries: '>', ' ', '\t', '\n', '\r', '/'
            if (next_char == '>' or next_char == ' ' or next_char == '\t' or
                next_char == '\n' or next_char == '\r' or next_char == '/')
            {
                // This is a valid tag match
                const tag_end = std.mem.indexOfPos(u8, xml, start, ">") orelse break;
                const end = std.mem.indexOfPos(u8, xml, tag_end, close_tag) orelse break;

                const content = xml[tag_end + 1 .. end];
                try results.append(allocator, content);

                pos = end + close_tag.len;
                continue;
            }
        }
        // Not a valid match, continue searching
        pos = start + open_tag.len;
    }

    return try results.toOwnedSlice(allocator);
}
// ANCHOR_END: find_all_elements

/// Unescape XML entities
pub fn unescapeXml(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    var result: std.ArrayList(u8) = .{};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < text.len) {
        if (text[i] == '&') {
            if (std.mem.startsWith(u8, text[i..], "&lt;")) {
                try result.append(allocator, '<');
                i += 4;
            } else if (std.mem.startsWith(u8, text[i..], "&gt;")) {
                try result.append(allocator, '>');
                i += 4;
            } else if (std.mem.startsWith(u8, text[i..], "&amp;")) {
                try result.append(allocator, '&');
                i += 5;
            } else if (std.mem.startsWith(u8, text[i..], "&quot;")) {
                try result.append(allocator, '"');
                i += 6;
            } else if (std.mem.startsWith(u8, text[i..], "&apos;")) {
                try result.append(allocator, '\'');
                i += 6;
            } else {
                try result.append(allocator, text[i]);
                i += 1;
            }
        } else {
            try result.append(allocator, text[i]);
            i += 1;
        }
    }

    return try result.toOwnedSlice(allocator);
}

/// Check if XML is well-formed
pub fn isWellFormed(xml: []const u8) bool {
    var depth: i32 = 0;
    var i: usize = 0;

    while (i < xml.len) {
        if (xml[i] == '<') {
            if (i + 1 < xml.len and xml[i + 1] == '/') {
                // Closing tag
                depth -= 1;
                if (depth < 0) return false;
            } else if (i + 1 < xml.len and xml[i + 1] != '!' and xml[i + 1] != '?') {
                // Opening tag (skip comments and declarations)
                depth += 1;
            }
        }
        i += 1;
    }

    return depth == 0;
}

/// Read XML from file
pub fn parseXmlFile(
    allocator: std.mem.Allocator,
    path: []const u8,
) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const xml_content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    return xml_content;
}

/// XML parsing errors
pub const XmlError = error{
    MalformedXml,
    UnexpectedEndOfInput,
    InvalidTag,
};

/// Parse element with error handling
pub fn parseElementSafe(xml: []const u8, tag: []const u8) XmlError![]const u8 {
    if (!isWellFormed(xml)) {
        return error.MalformedXml;
    }

    const content = findElement(xml, tag) orelse return error.InvalidTag;

    return content;
}

// Tests

test "find xml element" {
    const xml = "<root><name>Alice</name><age>30</age></root>";

    const name = findElement(xml, "name").?;
    try std.testing.expectEqualStrings("Alice", name);

    const age = findElement(xml, "age").?;
    try std.testing.expectEqualStrings("30", age);
}

test "find element not found" {
    const xml = "<root><name>Alice</name></root>";

    const missing = findElement(xml, "missing");
    try std.testing.expect(missing == null);
}

test "parse simple element" {
    const xml = "<user>Alice</user>";

    var element = (try parseSimpleElement(
        std.testing.allocator,
        xml,
        "user",
    )).?;
    defer element.deinit();

    try std.testing.expectEqualStrings("user", element.name);
    try std.testing.expectEqualStrings("Alice", element.text.?);
}

test "parse element with no content" {
    const xml = "<root></root>";

    var element = (try parseSimpleElement(
        std.testing.allocator,
        xml,
        "root",
    )).?;
    defer element.deinit();

    try std.testing.expectEqualStrings("", element.text.?);
}

test "parse attributes" {
    const tag = "user id=\"123\" name=\"Alice\"";

    var attrs = try parseAttributes(std.testing.allocator, tag);
    defer attrs.deinit();

    try std.testing.expectEqualStrings("123", attrs.get("id").?);
    try std.testing.expectEqualStrings("Alice", attrs.get("name").?);
}

test "parse attributes with spaces" {
    const tag = "img src = \"image.png\"  alt = \"Picture\"  ";

    var attrs = try parseAttributes(std.testing.allocator, tag);
    defer attrs.deinit();

    try std.testing.expectEqualStrings("image.png", attrs.get("src").?);
    try std.testing.expectEqualStrings("Picture", attrs.get("alt").?);
}

test "parse single attribute" {
    const tag = "link href=\"/path\"";

    var attrs = try parseAttributes(std.testing.allocator, tag);
    defer attrs.deinit();

    try std.testing.expectEqualStrings("/path", attrs.get("href").?);
}

test "find all elements" {
    const xml =
        \\<users>
        \\  <user>Alice</user>
        \\  <user>Bob</user>
        \\  <user>Charlie</user>
        \\</users>
    ;

    const users = try findAllElements(std.testing.allocator, xml, "user");
    defer std.testing.allocator.free(users);

    try std.testing.expectEqual(@as(usize, 3), users.len);
    try std.testing.expect(std.mem.indexOf(u8, users[0], "Alice") != null);
    try std.testing.expect(std.mem.indexOf(u8, users[1], "Bob") != null);
    try std.testing.expect(std.mem.indexOf(u8, users[2], "Charlie") != null);
}

test "find all elements empty" {
    const xml = "<root></root>";

    const items = try findAllElements(std.testing.allocator, xml, "item");
    defer std.testing.allocator.free(items);

    try std.testing.expectEqual(@as(usize, 0), items.len);
}

test "nested elements" {
    const xml =
        \\<person>
        \\  <name>Alice</name>
        \\  <address>
        \\    <city>New York</city>
        \\    <zip>10001</zip>
        \\  </address>
        \\</person>
    ;

    const name = findElement(xml, "name").?;
    try std.testing.expect(std.mem.indexOf(u8, name, "Alice") != null);

    const address = findElement(xml, "address").?;
    const city = findElement(address, "city").?;
    try std.testing.expect(std.mem.indexOf(u8, city, "New York") != null);

    const zip = findElement(address, "zip").?;
    try std.testing.expect(std.mem.indexOf(u8, zip, "10001") != null);
}

test "deeply nested elements" {
    const xml =
        \\<root>
        \\  <level1>
        \\    <level2>
        \\      <level3>Deep</level3>
        \\    </level2>
        \\  </level1>
        \\</root>
    ;

    const level1 = findElement(xml, "level1").?;
    const level2 = findElement(level1, "level2").?;
    const level3 = findElement(level2, "level3").?;
    try std.testing.expect(std.mem.indexOf(u8, level3, "Deep") != null);
}

test "unescape xml" {
    const escaped = "Hello &lt;world&gt; &amp; &quot;friends&quot;";

    const unescaped = try unescapeXml(std.testing.allocator, escaped);
    defer std.testing.allocator.free(unescaped);

    try std.testing.expectEqualStrings("Hello <world> & \"friends\"", unescaped);
}

test "unescape xml with apostrophe" {
    const escaped = "It&apos;s working";

    const unescaped = try unescapeXml(std.testing.allocator, escaped);
    defer std.testing.allocator.free(unescaped);

    try std.testing.expectEqualStrings("It's working", unescaped);
}

test "unescape xml no entities" {
    const text = "Plain text";

    const result = try unescapeXml(std.testing.allocator, text);
    defer std.testing.allocator.free(result);

    try std.testing.expectEqualStrings("Plain text", result);
}

test "validate xml well formed" {
    try std.testing.expect(isWellFormed("<root><child>text</child></root>"));
    try std.testing.expect(isWellFormed("<a><b><c></c></b></a>"));
    try std.testing.expect(isWellFormed("<empty></empty>"));
}

test "validate xml malformed" {
    try std.testing.expect(!isWellFormed("<root><child>text</root>"));
    try std.testing.expect(!isWellFormed("<root><child>text</child>"));
    try std.testing.expect(!isWellFormed("</root>"));
    try std.testing.expect(!isWellFormed("<root></child></root>"));
}

test "validate xml with comments" {
    const xml = "<!-- Comment --><root>text</root>";
    try std.testing.expect(isWellFormed(xml));
}

test "validate xml with declaration" {
    const xml = "<?xml version=\"1.0\"?><root>text</root>";
    try std.testing.expect(isWellFormed(xml));
}

test "read xml file" {
    const xml_content = "<test>content</test>";

    // Create temporary file
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    var tmp_file = try tmp_dir.dir.createFile("test.xml", .{});
    try tmp_file.writeAll(xml_content);
    tmp_file.close();

    // Read it back using the tmp_dir
    const file = try tmp_dir.dir.openFile("test.xml", .{});
    defer file.close();

    const content = try file.readToEndAlloc(std.testing.allocator, 10 * 1024 * 1024);
    defer std.testing.allocator.free(content);

    try std.testing.expectEqualStrings(xml_content, content);
}

test "read xml file not found" {
    const result = parseXmlFile(std.testing.allocator, "nonexistent.xml");
    try std.testing.expectError(error.FileNotFound, result);
}

test "error handling invalid tag" {
    const bad_xml = "<root><child>text</child></root>";

    const result = parseElementSafe(bad_xml, "missing");
    try std.testing.expectError(error.InvalidTag, result);
}

test "error handling malformed xml" {
    const bad_xml = "<root><unclosed>";

    const result = parseElementSafe(bad_xml, "root");
    try std.testing.expectError(error.MalformedXml, result);
}

test "parse element safe success" {
    const xml = "<root><child>text</child></root>";

    const result = try parseElementSafe(xml, "child");
    try std.testing.expectEqualStrings("text", result);
}

test "xml with whitespace" {
    const xml =
        \\  <root>
        \\    <name>  Alice  </name>
        \\  </root>
    ;

    const name = findElement(xml, "name").?;
    const trimmed = std.mem.trim(u8, name, " \n\r\t");
    try std.testing.expectEqualStrings("Alice", trimmed);
}

test "xml with mixed content" {
    const xml = "<p>Hello <b>world</b>!</p>";

    const p = findElement(xml, "p").?;
    try std.testing.expect(std.mem.indexOf(u8, p, "Hello") != null);
    try std.testing.expect(std.mem.indexOf(u8, p, "world") != null);

    const b = findElement(p, "b").?;
    try std.testing.expectEqualStrings("world", b);
}

test "xml self-closing tags" {
    const xml = "<root><item/><item/></root>";

    // Self-closing tags won't be found by our simple parser
    // This test documents the limitation
    const items = try findAllElements(std.testing.allocator, xml, "item");
    defer std.testing.allocator.free(items);

    // Our simple parser doesn't handle self-closing tags
    try std.testing.expectEqual(@as(usize, 0), items.len);
}

test "xml with numbers" {
    const xml = "<data><count>42</count><price>19.99</price></data>";

    const count_str = findElement(xml, "count").?;
    const count = try std.fmt.parseInt(i32, count_str, 10);
    try std.testing.expectEqual(@as(i32, 42), count);

    const price_str = findElement(xml, "price").?;
    const price = try std.fmt.parseFloat(f32, price_str);
    try std.testing.expectApproxEqRel(@as(f32, 19.99), price, 0.01);
}

test "xml empty string" {
    const xml = "";

    const result = findElement(xml, "root");
    try std.testing.expect(result == null);
}

test "xml single element" {
    const xml = "<root>value</root>";

    const root = findElement(xml, "root").?;
    try std.testing.expectEqualStrings("value", root);
}

test "xml unicode content" {
    const xml = "<message>こんにちは世界</message>";

    const message = findElement(xml, "message").?;
    try std.testing.expectEqualStrings("こんにちは世界", message);
}

test "xml boolean values" {
    const xml = "<config><enabled>true</enabled><debug>false</debug></config>";

    const enabled_str = findElement(xml, "enabled").?;
    const enabled = std.mem.eql(u8, enabled_str, "true");
    try std.testing.expect(enabled);

    const debug_str = findElement(xml, "debug").?;
    const debug = std.mem.eql(u8, debug_str, "true");
    try std.testing.expect(!debug);
}

test "tag name prefix matching bug fix" {
    // This test verifies that searching for <user> doesn't match <username>
    const xml =
        \\<root>
        \\  <user>Alice</user>
        \\  <username>alice123</username>
        \\  <user_id>42</user_id>
        \\  <user>Bob</user>
        \\</root>
    ;

    // Should only find <user> tags, not <username> or <user_id>
    const users = try findAllElements(std.testing.allocator, xml, "user");
    defer std.testing.allocator.free(users);

    try std.testing.expectEqual(@as(usize, 2), users.len);
    try std.testing.expect(std.mem.indexOf(u8, users[0], "Alice") != null);
    try std.testing.expect(std.mem.indexOf(u8, users[1], "Bob") != null);

    // Verify username tag exists separately
    const username = findElement(xml, "username").?;
    try std.testing.expect(std.mem.indexOf(u8, username, "alice123") != null);

    // Verify user_id tag exists separately
    const user_id = findElement(xml, "user_id").?;
    try std.testing.expect(std.mem.indexOf(u8, user_id, "42") != null);
}

test "exact tag match with attributes" {
    // Test that tags with attributes are correctly identified
    const xml =
        \\<root>
        \\  <item id="1">First</item>
        \\  <itemized>Not an item tag</itemized>
        \\  <item id="2">Second</item>
        \\</root>
    ;

    const items = try findAllElements(std.testing.allocator, xml, "item");
    defer std.testing.allocator.free(items);

    // Should find 2 <item> tags, not <itemized>
    try std.testing.expectEqual(@as(usize, 2), items.len);
    try std.testing.expect(std.mem.indexOf(u8, items[0], "First") != null);
    try std.testing.expect(std.mem.indexOf(u8, items[1], "Second") != null);

    // Verify itemized tag is separate
    const itemized = findElement(xml, "itemized").?;
    try std.testing.expect(std.mem.indexOf(u8, itemized, "Not an item tag") != null);
}
