## Problem

You need to work with XML data in your Zig application. You might be consuming XML APIs, reading configuration files, or generating XML documents for data interchange. You need a way to parse XML into a tree structure and serialize data structures back to XML format.

## Solution

Build an XML parser and generator using Zig's standard library. The solution includes an `XmlElement` tree structure, an `XmlWriter` for serialization, and an `XmlParser` for reading XML documents.

### Creating XML Elements

```zig
{{#include ../../../code/04-specialized/11-network-web/recipe_11_5.zig:test_element_creation}}
```

### Building Nested XML Structures

```zig
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
```

Output with pretty printing:
```xml
<people>
  <person id="1">
    <name>Alice</name>
    <age>30</age>
  </person>
</people>
```

### Parsing XML Documents

```zig
const xml = "<person name=\"Alice\">Software Engineer</person>";

var parser = XmlParser.init(testing.allocator, xml);
const element = try parser.parse();
defer {
    element.deinit();
    testing.allocator.destroy(element);
}

// Access element properties
const name_attr = element.attributes.get("name"); // "Alice"
const content = element.content; // "Software Engineer"
```

### Parsing Nested XML

```zig
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

// Navigate the tree
for (element.children.items) |child| {
    if (std.mem.eql(u8, child.name, "name")) {
        // child.content is "Alice"
    }
}
```

### XML Entity Escaping

The writer automatically escapes special characters:

```zig
const element = try XmlElement.init(testing.allocator, "data");
defer {
    element.deinit();
    testing.allocator.destroy(element);
}

try element.setContent("<tag> & \"quotes\" 'apostrophes'");

var writer = XmlWriter.init(testing.allocator, false);
const xml = try writer.writeElement(element);
defer testing.allocator.free(xml);

// Result: <data>&lt;tag&gt; &amp; &quot;quotes&quot; &apos;apostrophes&apos;</data>
```

The parser automatically unescapes entities when reading:

```zig
const xml = "<data>&lt;tag&gt; &amp; &quot;quotes&quot;</data>";

var parser = XmlParser.init(testing.allocator, xml);
const element = try parser.parse();
defer {
    element.deinit();
    testing.allocator.destroy(element);
}

// element.content is "<tag> & \"quotes\""
```

## Discussion

### XML Tree Structure

The `XmlElement` struct represents an XML node with:

- **name**: Tag name
- **attributes**: Key-value pairs using `StringArrayHashMap` for deterministic ordering
- **content**: Text content (optional)
- **children**: Child elements (for nested structures)

Elements can have either content or children, not both. This matches XML's structure where elements contain either text or other elements.

### Memory Management

The implementation uses explicit allocator passing and proper cleanup:

```zig
pub const XmlElement = struct {
    name: []const u8,
    attributes: std.StringArrayHashMap([]const u8),
    content: ?[]const u8,
    children: std.ArrayList(*XmlElement),
    allocator: std.mem.Allocator,

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
};
```

The `deinit` method:
1. Frees all strings (name, attribute keys/values, content)
2. Recursively cleans up child elements
3. Deallocates the children ArrayList

### setAttribute Memory Safety

The `setAttribute` method uses `getOrPut` to prevent memory leaks when overwriting attributes:

```zig
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
```

This ensures:
- New attributes allocate both key and value
- Overwriting attributes reuses the key and frees the old value
- Error paths properly clean up with `errdefer`

### Parser Implementation

The parser uses a simple recursive descent approach:

1. **Tag Parsing**: Identifies opening tags by `<` character
2. **Attribute Parsing**: Extracts key="value" pairs
3. **Content Parsing**: Reads text between tags
4. **Recursive Descent**: Parses nested elements recursively

Key safety features:
- Bounds checking before all array accesses
- Error return for malformed XML
- Proper cleanup with `errdefer` on parse failures

### Entity Handling

The writer escapes five basic XML entities:
- `&` → `&amp;`
- `<` → `&lt;`
- `>` → `&gt;`
- `"` → `&quot;`
- `'` → `&apos;`

The parser unescapes these same entities when reading. This handles the most common cases but doesn't support numeric character references (`&#65;`) or custom entities.

### Deterministic Attribute Ordering

The implementation uses `StringArrayHashMap` instead of `StringHashMap` to ensure attributes appear in a consistent order across writes. This is important for:
- Testing (comparing XML output)
- Version control (stable diffs)
- Debugging (predictable output)

### Self-Closing Tags

The writer optimizes empty elements with self-closing tags:

```zig
// Elements with no content and no children
<break />

// Elements with content or children
<div>Content</div>
```

### Pretty Printing

The `XmlWriter` supports optional pretty printing for human-readable output:

```zig
// Compact output
var writer = XmlWriter.init(allocator, false);

// Pretty printed with indentation
var writer = XmlWriter.init(allocator, true);
```

Pretty printing adds:
- Newlines after closing tags
- Two-space indentation per nesting level
- Whitespace between elements

### Roundtrip Validation

You can verify your XML handling with roundtrip tests:

```zig
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

// Verify roundtrip
try testing.expectEqualStrings(original.name, parsed.name);
try testing.expectEqualStrings(original.content.?, parsed.content.?);
```

### Limitations

This implementation is suitable for learning and simple use cases but has limitations for production use:

**Not Supported:**
- XML declarations (`<?xml version="1.0"?>`)
- DOCTYPE declarations
- Processing instructions
- CDATA sections (`<![CDATA[...]]>`)
- XML namespaces
- Comments (`<!-- -->`)
- Numeric character references (`&#65;`)
- Entity expansion limits (vulnerable to XML bombs)
- Streaming parsing (loads entire document into memory)
- Schema validation

**Security Considerations:**
- No maximum nesting depth (stack overflow risk)
- No entity expansion limits (denial of service risk)
- Minimal input validation (error messages lack position info)

For production use, consider:
- Adding depth limits to prevent stack overflow
- Implementing entity expansion limits
- Adding better error reporting with line/column numbers
- Supporting XML comments and CDATA
- Implementing streaming SAX-style parsing for large documents

### When to Use XML vs JSON

**Use XML when:**
- Working with legacy systems that require XML
- Need document markup (mixed content with text and elements)
- Require XML Schema validation
- Need namespace support for vocabulary mixing
- Industry standards mandate XML (SOAP, RSS, SVG)

**Use JSON when:**
- Building new web APIs
- Need lightweight data interchange
- Working with JavaScript clients
- Want simpler parsing and smaller payloads
- Don't need schema validation or namespaces

For most modern applications, JSON (Recipe 11.2) is simpler and more efficient. Use XML when it's specifically required by your use case.

## See Also

- Recipe 11.2: Working with JSON APIs - Simpler data format for modern APIs
- Recipe 11.1: Making HTTP requests - Fetch XML from web services
- Recipe 11.6: Working with REST APIs - Often uses JSON or XML

Full compilable example: `code/04-specialized/11-network-web/recipe_11_5.zig`
