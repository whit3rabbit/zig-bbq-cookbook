const std = @import("std");

/// XML event types for streaming parser
pub const XmlEvent = union(enum) {
    start_element: struct {
        name: []const u8,
    },
    end_element: struct {
        name: []const u8,
    },
    text: struct {
        content: []const u8,
    },
    eof,
};

// ANCHOR: streaming_parser
/// Streaming XML parser for processing large files
pub const StreamingXmlParser = struct {
    file: std.fs.File,
    buffer: [4096]u8,
    pos: usize,
    end: usize,

    pub fn init(file: std.fs.File) StreamingXmlParser {
        return .{
            .file = file,
            .buffer = undefined,
            .pos = 0,
            .end = 0,
        };
    }

    pub fn next(self: *StreamingXmlParser, allocator: std.mem.Allocator) !XmlEvent {
        while (true) {
            // Refill buffer if needed
            if (self.pos >= self.end) {
                self.end = try self.file.read(&self.buffer);
                self.pos = 0;
                if (self.end == 0) {
                    return XmlEvent.eof;
                }
            }

            // Skip whitespace
            while (self.pos < self.end and std.ascii.isWhitespace(self.buffer[self.pos])) {
                self.pos += 1;
            }

            if (self.pos >= self.end) continue;

            // Check for tag start
            if (self.buffer[self.pos] == '<') {
                return try self.parseTag(allocator);
            } else {
                if (try self.parseText(allocator)) |event| {
                    return event;
                }
                // Empty text, continue to next event
                continue;
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
        while (self.pos < self.end and self.buffer[self.pos] != '>' and self.buffer[self.pos] != '/' and !std.ascii.isWhitespace(self.buffer[self.pos])) {
            self.pos += 1;
        }

        const name = try allocator.dupe(u8, self.buffer[start..self.pos]);

        // Check for self-closing tag
        var is_self_closing = false;
        while (self.pos < self.end and self.buffer[self.pos] != '>') {
            if (self.buffer[self.pos] == '/') {
                is_self_closing = true;
            }
            self.pos += 1;
        }
        if (self.pos < self.end) {
            self.pos += 1; // Skip '>'
        }

        if (is_end_tag) {
            return XmlEvent{ .end_element = .{ .name = name } };
        } else {
            // For self-closing tags, we only return start_element
            // The caller needs to handle this specially if needed
            return XmlEvent{ .start_element = .{ .name = name } };
        }
    }

    fn parseText(self: *StreamingXmlParser, allocator: std.mem.Allocator) error{OutOfMemory}!?XmlEvent {
        const start = self.pos;

        while (self.pos < self.end and self.buffer[self.pos] != '<') {
            self.pos += 1;
        }

        // NOTE: This implementation trims whitespace for simplicity, which is appropriate
        // for data-centric XML (like config files). For document-oriented XML with mixed
        // content (e.g., "<b>Bold</b> <i>text</i>"), whitespace can be significant.
        // In production, consider making whitespace handling configurable based on your use case.
        const text = std.mem.trim(u8, self.buffer[start..self.pos], &std.ascii.whitespace);
        if (text.len == 0) {
            return null; // Skip empty text, caller will continue parsing
        }

        return XmlEvent{ .text = .{ .content = try allocator.dupe(u8, text) } };
    }
};
// ANCHOR_END: streaming_parser

// ANCHOR: process_large_xml
/// Process large XML file counting elements
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
// ANCHOR_END: process_large_xml

// ANCHOR: extract_elements
/// Extract text content from specific elements
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
// ANCHOR_END: extract_elements

/// Count occurrences of specific element
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

/// Generic buffered streaming parser
pub fn StreamingXmlParserBuffered(comptime buffer_size: usize) type {
    return struct {
        const Self = @This();

        file: std.fs.File,
        buffer: [buffer_size]u8,
        pos: usize,
        end: usize,

        pub fn init(file: std.fs.File) Self {
            return .{
                .file = file,
                .buffer = undefined,
                .pos = 0,
                .end = 0,
            };
        }

        pub fn next(self: *Self, allocator: std.mem.Allocator) !XmlEvent {
            while (true) {
                // Refill buffer if needed
                if (self.pos >= self.end) {
                    self.end = try self.file.read(&self.buffer);
                    self.pos = 0;
                    if (self.end == 0) {
                        return XmlEvent.eof;
                    }
                }

                // Skip whitespace
                while (self.pos < self.end and std.ascii.isWhitespace(self.buffer[self.pos])) {
                    self.pos += 1;
                }

                if (self.pos >= self.end) continue;

                // Check for tag start
                if (self.buffer[self.pos] == '<') {
                    return try self.parseTag(allocator);
                } else {
                    if (try self.parseText(allocator)) |event| {
                        return event;
                    }
                    // Empty text, continue to next event
                    continue;
                }
            }
        }

        fn parseTag(self: *Self, allocator: std.mem.Allocator) !XmlEvent {
            self.pos += 1; // Skip '<'

            // Check for end tag
            const is_end_tag = if (self.pos < self.end) self.buffer[self.pos] == '/' else false;
            if (is_end_tag) {
                self.pos += 1;
            }

            // Find tag name end
            const start = self.pos;
            while (self.pos < self.end and self.buffer[self.pos] != '>' and self.buffer[self.pos] != '/' and !std.ascii.isWhitespace(self.buffer[self.pos])) {
                self.pos += 1;
            }

            const name = try allocator.dupe(u8, self.buffer[start..self.pos]);

            // Check for self-closing tag
            var is_self_closing = false;
            while (self.pos < self.end and self.buffer[self.pos] != '>') {
                if (self.buffer[self.pos] == '/') {
                    is_self_closing = true;
                }
                self.pos += 1;
            }
            if (self.pos < self.end) {
                self.pos += 1; // Skip '>'
            }

            if (is_end_tag) {
                return XmlEvent{ .end_element = .{ .name = name } };
            } else {
                // For self-closing tags, we only return start_element
                // The caller needs to handle this specially if needed
                return XmlEvent{ .start_element = .{ .name = name } };
            }
        }

        fn parseText(self: *Self, allocator: std.mem.Allocator) error{OutOfMemory}!?XmlEvent {
            const start = self.pos;

            while (self.pos < self.end and self.buffer[self.pos] != '<') {
                self.pos += 1;
            }

            // NOTE: This implementation trims whitespace for simplicity, which is appropriate
            // for data-centric XML (like config files). For document-oriented XML with mixed
            // content (e.g., "<b>Bold</b> <i>text</i>"), whitespace can be significant.
            // In production, consider making whitespace handling configurable based on your use case.
            const text = std.mem.trim(u8, self.buffer[start..self.pos], &std.ascii.whitespace);
            if (text.len == 0) {
                return null; // Skip empty text, caller will continue parsing
            }

            return XmlEvent{ .text = .{ .content = try allocator.dupe(u8, text) } };
        }
    };
}

/// Process XML in chunks
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

/// Safe XML processing with error handling
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

// Tests

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
    try std.testing.expectEqualStrings("A", results.items[0]);
    try std.testing.expectEqualStrings("C", results.items[1]);
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

test "buffered parser" {
    const Parser = StreamingXmlParserBuffered(8192);
    const file = try std.fs.cwd().createFile("/tmp/buffered.xml", .{ .read = true });
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/buffered.xml") catch {};

    try file.writeAll("<root><item/></root>");
    try file.seekTo(0);

    var parser = Parser.init(file);
    const allocator = std.testing.allocator;

    const event = try parser.next(allocator);
    defer if (event == .start_element) allocator.free(event.start_element.name);

    try std.testing.expect(event == .start_element);
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

test "empty XML" {
    const allocator = std.testing.allocator;

    const file = try std.fs.cwd().createFile("/tmp/empty.xml", .{ .read = true });
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/empty.xml") catch {};

    try file.writeAll("");
    try file.seekTo(0);

    var parser = StreamingXmlParser.init(file);
    const event = try parser.next(allocator);

    try std.testing.expect(event == .eof);
}

test "nested elements" {
    const allocator = std.testing.allocator;

    const file = try std.fs.cwd().createFile("/tmp/nested.xml", .{ .read = true });
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/nested.xml") catch {};

    try file.writeAll("<root><parent><child>text</child></parent></root>");
    try file.seekTo(0);

    var parser = StreamingXmlParser.init(file);

    // root start
    const e1 = try parser.next(allocator);
    defer if (e1 == .start_element) allocator.free(e1.start_element.name);
    try std.testing.expect(e1 == .start_element);

    // parent start
    const e2 = try parser.next(allocator);
    defer if (e2 == .start_element) allocator.free(e2.start_element.name);
    try std.testing.expect(e2 == .start_element);

    // child start
    const e3 = try parser.next(allocator);
    defer if (e3 == .start_element) allocator.free(e3.start_element.name);
    try std.testing.expect(e3 == .start_element);
}

test "self-closing tags" {
    const allocator = std.testing.allocator;

    const file = try std.fs.cwd().createFile("/tmp/selfclose.xml", .{ .read = true });
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/selfclose.xml") catch {};

    try file.writeAll("<root><item/></root>");
    try file.seekTo(0);

    const count = try processLargeXml(file, allocator);
    try std.testing.expectEqual(@as(usize, 2), count);
}

test "XML with attributes" {
    const allocator = std.testing.allocator;

    const file = try std.fs.cwd().createFile("/tmp/attrs.xml", .{ .read = true });
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/attrs.xml") catch {};

    try file.writeAll("<root><item id=\"1\">text</item></root>");
    try file.seekTo(0);

    var parser = StreamingXmlParser.init(file);

    const e1 = try parser.next(allocator);
    defer if (e1 == .start_element) allocator.free(e1.start_element.name);

    const e2 = try parser.next(allocator);
    defer if (e2 == .start_element) allocator.free(e2.start_element.name);
    try std.testing.expectEqualStrings("item", e2.start_element.name);
}

test "safe process XML" {
    const allocator = std.testing.allocator;

    const file = try std.fs.cwd().createFile("/tmp/safe.xml", .{ .read = true });
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/safe.xml") catch {};

    try file.writeAll("<root><item/></root>");
    try file.seekTo(0);

    try safeProcessXml(file, allocator);
}
