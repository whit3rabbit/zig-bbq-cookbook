## Problem

You need to parse simple XML data to extract elements, attributes, and text content.

## Solution

### Find Element

```zig
{{#include ../../../code/03-advanced/06-data-encoding/recipe_6_3.zig:find_element}}
```

### Parse Attributes

```zig
{{#include ../../../code/03-advanced/06-data-encoding/recipe_6_3.zig:parse_attributes}}
```

### Find All Elements

```zig
{{#include ../../../code/03-advanced/06-data-encoding/recipe_6_3.zig:find_all_elements}}
```

## Discussion

### Basic XML Parsing

Zig doesn't have built-in XML support, so we build parsers manually:

```zig
pub fn parseSimpleElement(
    allocator: std.mem.Allocator,
    xml: []const u8,
    tag: []const u8,
) !?XmlElement {
    const content = findElement(xml, tag) orelse return null;

    var element = XmlElement{
        .name = tag,
        .attributes = std.StringHashMap([]const u8).init(allocator),
        .text = content,
        .allocator = allocator,
    };

    return element;
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
```

### Extracting Attributes

Parse XML attributes from element tags:

```zig
pub fn parseAttributes(
    allocator: std.mem.Allocator,
    tag_content: []const u8,
) !std.StringHashMap([]const u8) {
    var attrs = std.StringHashMap([]const u8).init(allocator);
    errdefer attrs.deinit();

    var iter = std.mem.tokenizeAny(u8, tag_content, " \t\n\r");
    // Skip element name
    _ = iter.next();

    while (iter.next()) |attr| {
        const eq_pos = std.mem.indexOf(u8, attr, "=") orelse continue;
        const key = std.mem.trim(u8, attr[0..eq_pos], " \t");
        var value = std.mem.trim(u8, attr[eq_pos + 1 ..], " \t");

        // Remove quotes
        if (value.len >= 2 and value[0] == '"' and value[value.len - 1] == '"') {
            value = value[1 .. value.len - 1];
        }

        try attrs.put(key, value);
    }

    return attrs;
}

test "parse attributes" {
    const tag = "user id=\"123\" name=\"Alice\"";

    var attrs = try parseAttributes(std.testing.allocator, tag);
    defer attrs.deinit();

    try std.testing.expectEqualStrings("123", attrs.get("id").?);
    try std.testing.expectEqualStrings("Alice", attrs.get("name").?);
}
```

### Finding All Elements

Extract multiple elements with the same tag:

```zig
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
        const tag_end = std.mem.indexOfPos(u8, xml, start, ">") orelse break;
        const end = std.mem.indexOfPos(u8, xml, tag_end, close_tag) orelse break;

        const content = xml[tag_end + 1 .. end];
        try results.append(allocator, content);

        pos = end + close_tag.len;
    }

    return try results.toOwnedSlice(allocator);
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
    try std.testing.expectEqualStrings("Alice", users[0]);
    try std.testing.expectEqualStrings("Bob", users[1]);
    try std.testing.expectEqualStrings("Charlie", users[2]);
}
```

### Nested Elements

Handle nested XML structures:

```zig
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
    try std.testing.expectEqualStrings("Alice", std.mem.trim(u8, name, " \n\r\t"));

    const address = findElement(xml, "address").?;
    const city = findElement(address, "city").?;
    try std.testing.expectEqualStrings("New York", std.mem.trim(u8, city, " \n\r\t"));
}
```

### Escaping Special Characters

Handle XML entities:

```zig
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

test "unescape xml" {
    const escaped = "Hello &lt;world&gt; &amp; &quot;friends&quot;";

    const unescaped = try unescapeXml(std.testing.allocator, escaped);
    defer std.testing.allocator.free(unescaped);

    try std.testing.expectEqualStrings("Hello <world> & \"friends\"", unescaped);
}
```

### Validating XML

Basic XML validation:

```zig
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

test "validate xml" {
    try std.testing.expect(isWellFormed("<root><child>text</child></root>"));
    try std.testing.expect(!isWellFormed("<root><child>text</root>"));
    try std.testing.expect(!isWellFormed("<root><child>text</child>"));
}
```

### Reading XML from Files

Load and parse XML files:

```zig
pub fn parseXmlFile(
    allocator: std.mem.Allocator,
    path: []const u8,
) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const xml_content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    return xml_content;
}

test "read xml file" {
    const xml_content = "<test>content</test>";

    // Create temporary file
    const tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    var tmp_file = try tmp_dir.dir.createFile("test.xml", .{});
    defer tmp_file.close();

    try tmp_file.writeAll(xml_content);

    // Read it back
    const path = try std.fs.path.join(
        std.testing.allocator,
        &.{ "zig-cache", "tmp", tmp_dir.sub_path[0..], "test.xml" },
    );
    defer std.testing.allocator.free(path);

    const content = try parseXmlFile(std.testing.allocator, path);
    defer std.testing.allocator.free(content);

    try std.testing.expectEqualStrings(xml_content, content);
}
```

### Using C Libraries (libxml2)

For complex XML parsing, link with libxml2:

```zig
// In build.zig:
// exe.linkSystemLibrary("xml2");
// exe.addIncludePath(.{ .path = "/usr/include/libxml2" });

const c = @cImport({
    @cInclude("libxml/parser.h");
    @cInclude("libxml/tree.h");
});

pub fn parseXmlWithLibxml2(xml: [*:0]const u8) ?*c.xmlDoc {
    const doc = c.xmlReadMemory(
        xml,
        @intCast(std.mem.len(xml)),
        null,
        null,
        0,
    );
    return doc;
}
```

### Performance Considerations

**Manual Parsing:**
- Fast for simple, known XML structures
- Low memory overhead
- No external dependencies
- Limited validation

**Using libxml2:**
- Full XML specification support
- Better error handling
- Heavier dependency
- More complex to integrate

**Best Practices:**
```zig
// Good: Parse once, reuse results
const elements = try findAllElements(allocator, xml, "item");
defer allocator.free(elements);
for (elements) |elem| {
    try processElement(elem);
}

// Bad: Repeated parsing
for (0..count) |i| {
    const elem = findElement(xml, "item"); // Inefficient!
}
```

### Error Handling

Handle malformed XML gracefully:

```zig
pub const XmlError = error{
    MalformedXml,
    UnexpectedEndOfInput,
    InvalidTag,
};

pub fn parseElementSafe(xml: []const u8, tag: []const u8) XmlError![]const u8 {
    const content = findElement(xml, tag) orelse return error.InvalidTag;

    if (!isWellFormed(xml)) {
        return error.MalformedXml;
    }

    return content;
}

test "error handling" {
    const bad_xml = "<root><unclosed>";

    const result = parseElementSafe(bad_xml, "root");
    try std.testing.expectError(error.MalformedXml, result);
}
```

### Common Patterns

**Configuration files:**
```zig
pub fn loadConfig(allocator: std.mem.Allocator, path: []const u8) !Config {
    const xml = try parseXmlFile(allocator, path);
    defer allocator.free(xml);

    const host = findElement(xml, "host") orelse return error.MissingHost;
    const port = findElement(xml, "port") orelse return error.MissingPort;

    return Config{
        .host = try allocator.dupe(u8, host),
        .port = try std.fmt.parseInt(u16, port, 10),
    };
}
```

**Data extraction:**
```zig
pub fn extractData(allocator: std.mem.Allocator, xml: []const u8) ![]Data {
    const items = try findAllElements(allocator, xml, "item");
    defer allocator.free(items);

    var results: std.ArrayList(Data) = .{};
    errdefer results.deinit(allocator);

    for (items) |item| {
        const name = findElement(item, "name") orelse continue;
        const value = findElement(item, "value") orelse continue;

        try results.append(allocator, Data{
            .name = try allocator.dupe(u8, name),
            .value = try std.fmt.parseInt(i32, value, 10),
        });
    }

    return try results.toOwnedSlice(allocator);
}
```

### Limitations

This simple parser handles basic XML but doesn't support:
- CDATA sections
- Processing instructions
- Namespaces
- DTD validation
- Complex entity references

For production XML parsing, consider using libxml2 or a Zig XML library.

### Related Functions

- `std.mem.indexOf()` - Find substrings
- `std.mem.tokenizeAny()` - Split strings
- `std.mem.trim()` - Remove whitespace
- `std.StringHashMap` - Store attributes
- `std.ArrayList` - Dynamic arrays
- `std.fs.File.readToEndAlloc()` - Read files
