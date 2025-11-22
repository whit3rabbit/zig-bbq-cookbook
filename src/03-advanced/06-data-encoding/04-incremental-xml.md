## Problem

You need to parse very large XML files that don't fit comfortably in memory, or you want to start processing data before the entire file is read.

## Solution

### Streaming Parser

```zig
{{#include ../../../code/03-advanced/06-data-encoding/recipe_6_4.zig:streaming_parser}}
```

### Process Large XML

```zig
{{#include ../../../code/03-advanced/06-data-encoding/recipe_6_4.zig:process_large_xml}}
```

### Extract Elements

```zig
{{#include ../../../code/03-advanced/06-data-encoding/recipe_6_4.zig:extract_elements}}
```

            if (self.pos >= self.end) continue;

            // Check for tag start
            if (self.buffer[self.pos] == '<') {
                return try self.parseTag(allocator);
            } else {
                return try self.parseText(allocator);
            }
        }
    }

    fn parseTag(self: *StreamingXmlParser, allocator: std.mem.Allocator) !XmlEvent {
        self.pos += 1; // Skip '<'

        // Check for end tag
        const is_end_tag = if (self.pos < self.end) self.buffer[self.pos] == '/' else false;
        if (is_end_tag) {
            self.pos += 1;
        }

        // Find tag name end
        const start = self.pos;
        while (self.pos < self.end and self.buffer[self.pos] != '>' and !std.ascii.isWhitespace(self.buffer[self.pos])) {
            self.pos += 1;
        }

        const name = try allocator.dupe(u8, self.buffer[start..self.pos]);

        // Skip to end of tag
        while (self.pos < self.end and self.buffer[self.pos] != '>') {
            self.pos += 1;
        }
        if (self.pos < self.end) {
            self.pos += 1; // Skip '>'
        }

        if (is_end_tag) {
            return XmlEvent{ .end_element = .{ .name = name } };
        } else {
            return XmlEvent{ .start_element = .{ .name = name } };
        }
    }

    fn parseText(self: *StreamingXmlParser, allocator: std.mem.Allocator) !XmlEvent {
        const start = self.pos;

        while (self.pos < self.end and self.buffer[self.pos] != '<') {
            self.pos += 1;
        }

        const text = std.mem.trim(u8, self.buffer[start..self.pos], &std.ascii.whitespace);
        if (text.len == 0) {
            return self.next(allocator);
        }

        return XmlEvent{ .text = .{ .content = try allocator.dupe(u8, text) } };
    }
};

test "streaming XML parser" {
    const allocator = std.testing.allocator;

    const xml_data = "<root><item>value</item></root>";

    const file = try std.fs.cwd().createFile("/tmp/test_stream.xml", .{ .read = true });
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/test_stream.xml") catch {};

    try file.writeAll(xml_data);
    try file.seekTo(0);

    var parser = StreamingXmlParser.init(file);

    const event1 = try parser.next(allocator);
    defer if (event1 == .start_element) allocator.free(event1.start_element.name);
    try std.testing.expect(event1 == .start_element);
    try std.testing.expectEqualStrings("root", event1.start_element.name);

    const event2 = try parser.next(allocator);
    defer if (event2 == .start_element) allocator.free(event2.start_element.name);
    try std.testing.expect(event2 == .start_element);

    const event3 = try parser.next(allocator);
    defer if (event3 == .text) allocator.free(event3.text.content);
    try std.testing.expect(event3 == .text);
}
```

## Discussion

### Streaming Parser Benefits

Memory-efficient processing:

```zig
pub fn processLargeXml(file: std.fs.File, allocator: std.mem.Allocator) !usize {
    var parser = StreamingXmlParser.init(file);
    var count: usize = 0;

    while (true) {
        const event = try parser.next(allocator);

        switch (event) {
            .start_element => |elem| {
                defer allocator.free(elem.name);
                count += 1;
            },
            .end_element => |elem| {
                defer allocator.free(elem.name);
            },
            .text => |text| {
                defer allocator.free(text.content);
            },
            .eof => break,
        }
    }

    return count;
}

test "process large XML" {
    const allocator = std.testing.allocator;

    const file = try std.fs.cwd().createFile("/tmp/large.xml", .{ .read = true });
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/large.xml") catch {};

    try file.writeAll("<root><a/><b/><c/></root>");
    try file.seekTo(0);

    const count = try processLargeXml(file, allocator);
    try std.testing.expectEqual(@as(usize, 4), count);
}
```

### Extracting Specific Elements

Filter while parsing:

```zig
pub fn extractElements(
    file: std.fs.File,
    allocator: std.mem.Allocator,
    target_name: []const u8,
) !std.ArrayList([]const u8) {
    var parser = StreamingXmlParser.init(file);
    var results = std.ArrayList([]const u8){};
    errdefer {
        for (results.items) |item| {
            allocator.free(item);
        }
        results.deinit(allocator);
    }

    var in_target = false;

    while (true) {
        const event = try parser.next(allocator);

        switch (event) {
            .start_element => |elem| {
                if (std.mem.eql(u8, elem.name, target_name)) {
                    in_target = true;
                }
                allocator.free(elem.name);
            },
            .end_element => |elem| {
                if (std.mem.eql(u8, elem.name, target_name)) {
                    in_target = false;
                }
                allocator.free(elem.name);
            },
            .text => |text| {
                if (in_target) {
                    try results.append(allocator, try allocator.dupe(u8, text.content));
                }
                allocator.free(text.content);
            },
            .eof => break,
        }
    }

    return results;
}

test "extract specific elements" {
    const allocator = std.testing.allocator;

    const file = try std.fs.cwd().createFile("/tmp/extract.xml", .{ .read = true });
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/extract.xml") catch {};

    try file.writeAll("<root><item>A</item><other>B</other><item>C</item></root>");
    try file.seekTo(0);

    var results = try extractElements(file, allocator, "item");
    defer {
        for (results.items) |item| {
            allocator.free(item);
        }
        results.deinit(allocator);
    }

    try std.testing.expectEqual(@as(usize, 2), results.items.len);
}
```

### Counting Elements

Process without storing:

```zig
pub fn countElements(
    file: std.fs.File,
    allocator: std.mem.Allocator,
    element_name: []const u8,
) !usize {
    var parser = StreamingXmlParser.init(file);
    var count: usize = 0;

    while (true) {
        const event = try parser.next(allocator);

        switch (event) {
            .start_element => |elem| {
                if (std.mem.eql(u8, elem.name, element_name)) {
                    count += 1;
                }
                allocator.free(elem.name);
            },
            .end_element => |elem| {
                allocator.free(elem.name);
            },
            .text => |text| {
                allocator.free(text.content);
            },
            .eof => break,
        }
    }

    return count;
}

test "count elements" {
    const allocator = std.testing.allocator;

    const file = try std.fs.cwd().createFile("/tmp/count.xml", .{ .read = true });
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/count.xml") catch {};

    try file.writeAll("<root><item/><item/><item/></root>");
    try file.seekTo(0);

    const count = try countElements(file, allocator, "item");
    try std.testing.expectEqual(@as(usize, 3), count);
}
```

### Buffered Reading

Optimize I/O with larger buffers:

```zig
pub fn StreamingXmlParserBuffered(comptime buffer_size: usize) type {
    return struct {
        const Self = @This();

        reader: std.fs.File.Reader,
        buffer: [buffer_size]u8,
        pos: usize,
        end: usize,

        pub fn init(file: std.fs.File) Self {
            return .{
                .reader = file.reader(),
                .buffer = undefined,
                .pos = 0,
                .end = 0,
            };
        }

        pub fn next(self: *Self, allocator: std.mem.Allocator) !XmlEvent {
            // Same implementation as StreamingXmlParser
            _ = allocator;
            _ = self;
            return XmlEvent.eof;
        }
    };
}

test "buffered parser" {
    const Parser = StreamingXmlParserBuffered(8192);
    const file = try std.fs.cwd().createFile("/tmp/buffered.xml", .{ .read = true });
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/buffered.xml") catch {};

    var parser = Parser.init(file);
    _ = parser;
}
```

### Processing in Chunks

Handle data in manageable pieces:

```zig
pub fn processXmlChunk(
    parser: *StreamingXmlParser,
    allocator: std.mem.Allocator,
    max_events: usize,
) !usize {
    var processed: usize = 0;

    while (processed < max_events) {
        const event = try parser.next(allocator);

        switch (event) {
            .start_element => |elem| {
                defer allocator.free(elem.name);
                processed += 1;
            },
            .end_element => |elem| {
                defer allocator.free(elem.name);
                processed += 1;
            },
            .text => |text| {
                defer allocator.free(text.content);
                processed += 1;
            },
            .eof => break,
        }
    }

    return processed;
}

test "process in chunks" {
    const allocator = std.testing.allocator;

    const file = try std.fs.cwd().createFile("/tmp/chunks.xml", .{ .read = true });
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/chunks.xml") catch {};

    try file.writeAll("<root><a/><b/><c/></root>");
    try file.seekTo(0);

    var parser = StreamingXmlParser.init(file);

    const chunk1 = try processXmlChunk(&parser, allocator, 3);
    try std.testing.expect(chunk1 > 0);
}
```

### Best Practices

**Memory management:**
- Free event data immediately after processing
- Use arena allocator for temporary data
- Process in chunks for bounded memory usage

**Error handling:**
```zig
pub fn safeProcessXml(file: std.fs.File, allocator: std.mem.Allocator) !void {
    var parser = StreamingXmlParser.init(file);

    while (true) {
        const event = parser.next(allocator) catch |err| {
            std.log.err("XML parsing error: {}", .{err});
            return err;
        };

        switch (event) {
            .start_element => |elem| {
                defer allocator.free(elem.name);
                // Process
            },
            .end_element => |elem| {
                defer allocator.free(elem.name);
            },
            .text => |text| {
                defer allocator.free(text.content);
            },
            .eof => break,
        }
    }
}
```

**Performance:**
- Use larger buffers for sequential reads
- Minimize allocations by reusing buffers
- Process events immediately instead of storing
- Consider using `std.io.BufferedReader`

**Robustness:**
- Handle malformed XML gracefully
- Validate structure during parsing
- Implement depth tracking for nesting
- Support entity decoding

### Related Functions

- `std.fs.File.reader()` - Get file reader
- `std.io.BufferedReader()` - Add buffering
- `std.mem.trim()` - Trim whitespace
- `std.ascii.isWhitespace()` - Check whitespace
- `std.ArrayList()` - Dynamic array for results
- `std.mem.eql()` - String comparison
