// Recipe 11.3: WebSocket Communication
// Target Zig Version: 0.15.2
//
// Educational demonstration of WebSocket patterns in Zig.
// Shows WebSocket frame structure, handshake, and message handling patterns.
//
// Note: This demonstrates WebSocket protocol patterns without actual networking.
// For production WebSocket clients/servers, use a library like websocket.zig
//
// Key concepts:
// - WebSocket frame structure and parsing
// - Handshake protocol
// - Message fragmentation
// - Control frames (ping/pong/close)
// - Text and binary messages
// - Masking for client-to-server messages

const std = @import("std");
const testing = std.testing;

// ANCHOR: frame_header
// WebSocket frame header structure
pub const FrameHeader = struct {
    fin: bool, // Final fragment flag
    rsv1: bool = false, // Reserved bits (must be 0)
    rsv2: bool = false,
    rsv3: bool = false,
    opcode: Opcode,
    masked: bool,
    payload_length: u64,
    masking_key: ?[4]u8 = null,

    pub const Opcode = enum(u4) {
        continuation = 0x0,
        text = 0x1,
        binary = 0x2,
        close = 0x8,
        ping = 0x9,
        pong = 0xA,
        _,

        pub fn isControl(self: Opcode) bool {
            return @intFromEnum(self) >= 0x8;
        }
    };
};

test "frame header opcodes" {
    try testing.expect(FrameHeader.Opcode.ping.isControl());
    try testing.expect(FrameHeader.Opcode.pong.isControl());
    try testing.expect(FrameHeader.Opcode.close.isControl());
    try testing.expect(!FrameHeader.Opcode.text.isControl());
    try testing.expect(!FrameHeader.Opcode.binary.isControl());
}
// ANCHOR_END: frame_header

// ANCHOR: message_type
pub const MessageType = enum {
    text,
    binary,
    ping,
    pong,
    close,
};

pub const Message = struct {
    type: MessageType,
    data: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, msg_type: MessageType, data: []const u8) !Message {
        return .{
            .type = msg_type,
            .data = try allocator.dupe(u8, data),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Message) void {
        self.allocator.free(self.data);
    }
};

test "message creation" {
    var msg = try Message.init(testing.allocator, .text, "Hello WebSocket");
    defer msg.deinit();

    try testing.expectEqual(MessageType.text, msg.type);
    try testing.expectEqualStrings("Hello WebSocket", msg.data);
}
// ANCHOR_END: message_type

// ANCHOR: handshake_request
pub const HandshakeRequest = struct {
    host: []const u8,
    path: []const u8,
    key: []const u8,
    protocol: ?[]const u8 = null,

    pub fn build(self: HandshakeRequest, allocator: std.mem.Allocator) ![]u8 {
        var result = std.ArrayList(u8){};
        errdefer result.deinit(allocator);

        const writer = result.writer(allocator);

        try writer.print("GET {s} HTTP/1.1\r\n", .{self.path});
        try writer.print("Host: {s}\r\n", .{self.host});
        try writer.writeAll("Upgrade: websocket\r\n");
        try writer.writeAll("Connection: Upgrade\r\n");
        try writer.print("Sec-WebSocket-Key: {s}\r\n", .{self.key});
        try writer.writeAll("Sec-WebSocket-Version: 13\r\n");

        if (self.protocol) |proto| {
            try writer.print("Sec-WebSocket-Protocol: {s}\r\n", .{proto});
        }

        try writer.writeAll("\r\n");

        return result.toOwnedSlice(allocator);
    }
};

test "handshake request building" {
    const request = HandshakeRequest{
        .host = "example.com",
        .path = "/chat",
        .key = "dGhlIHNhbXBsZSBub25jZQ==",
    };

    const handshake = try request.build(testing.allocator);
    defer testing.allocator.free(handshake);

    try testing.expect(std.mem.indexOf(u8, handshake, "GET /chat HTTP/1.1") != null);
    try testing.expect(std.mem.indexOf(u8, handshake, "Host: example.com") != null);
    try testing.expect(std.mem.indexOf(u8, handshake, "Upgrade: websocket") != null);
}
// ANCHOR_END: handshake_request

// ANCHOR: handshake_response
pub const HandshakeResponse = struct {
    status_code: u16,
    accept_key: ?[]const u8 = null,
    protocol: ?[]const u8 = null,

    pub fn isValid(self: HandshakeResponse) bool {
        return self.status_code == 101 and self.accept_key != null;
    }

    pub fn parse(allocator: std.mem.Allocator, response: []const u8) !HandshakeResponse {
        _ = allocator;

        var result = HandshakeResponse{
            .status_code = 0,
        };

        var lines = std.mem.splitScalar(u8, response, '\n');

        // Parse status line
        if (lines.next()) |status_line| {
            if (std.mem.indexOf(u8, status_line, "101")) |_| {
                result.status_code = 101;
            }
        }

        // Parse headers
        while (lines.next()) |line| {
            if (std.mem.trim(u8, line, &std.ascii.whitespace).len == 0) break;

            if (std.mem.indexOf(u8, line, "Sec-WebSocket-Accept:")) |_| {
                const colon_idx = std.mem.indexOf(u8, line, ":") orelse continue;
                const value = std.mem.trim(u8, line[colon_idx + 1 ..], &std.ascii.whitespace);
                result.accept_key = value;
            }
        }

        return result;
    }
};

test "handshake response parsing" {
    const response =
        \\HTTP/1.1 101 Switching Protocols
        \\Upgrade: websocket
        \\Connection: Upgrade
        \\Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
        \\
        \\
    ;

    const parsed = try HandshakeResponse.parse(testing.allocator, response);

    try testing.expectEqual(@as(u16, 101), parsed.status_code);
    try testing.expect(parsed.isValid());
    try testing.expect(parsed.accept_key != null);
}
// ANCHOR_END: handshake_response

// ANCHOR: frame_builder
pub const FrameBuilder = struct {
    allocator: std.mem.Allocator,
    buffer: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) FrameBuilder {
        return .{
            .allocator = allocator,
            .buffer = std.ArrayList(u8){},
        };
    }

    pub fn deinit(self: *FrameBuilder) void {
        self.buffer.deinit(self.allocator);
    }

    pub fn text(self: *FrameBuilder, message: []const u8) !void {
        try self.writeFrame(.text, true, message);
    }

    pub fn binary(self: *FrameBuilder, data: []const u8) !void {
        try self.writeFrame(.binary, true, data);
    }

    pub fn ping(self: *FrameBuilder, data: []const u8) !void {
        try self.writeFrame(.ping, true, data);
    }

    pub fn pong(self: *FrameBuilder, data: []const u8) !void {
        try self.writeFrame(.pong, true, data);
    }

    pub fn close(self: *FrameBuilder, code: u16, reason: []const u8) !void {
        var close_data = std.ArrayList(u8){};
        defer close_data.deinit(self.allocator);

        // Close frame payload: 2-byte status code + reason (big-endian)
        var code_bytes: [2]u8 = undefined;
        std.mem.writeInt(u16, &code_bytes, code, .big);
        try close_data.appendSlice(self.allocator, &code_bytes);
        try close_data.appendSlice(self.allocator, reason);

        try self.writeFrame(.close, true, close_data.items);
    }

    fn writeFrame(
        self: *FrameBuilder,
        opcode: FrameHeader.Opcode,
        fin: bool,
        payload: []const u8,
    ) !void {
        // First byte: FIN + RSV + Opcode
        var byte1: u8 = @intFromEnum(opcode);
        if (fin) byte1 |= 0x80;

        try self.buffer.append(self.allocator, byte1);

        // Second byte: MASK + Payload length
        const payload_len = payload.len;
        var byte2: u8 = 0; // No masking for server-to-client

        if (payload_len < 126) {
            byte2 |= @as(u8, @intCast(payload_len));
            try self.buffer.append(self.allocator, byte2);
        } else if (payload_len <= 0xFFFF) {
            byte2 |= 126;
            try self.buffer.append(self.allocator, byte2);
            var len_bytes: [2]u8 = undefined;
            std.mem.writeInt(u16, &len_bytes, @intCast(payload_len), .big);
            try self.buffer.appendSlice(self.allocator, &len_bytes);
        } else {
            byte2 |= 127;
            try self.buffer.append(self.allocator, byte2);
            // Write 64-bit length in network byte order (big-endian)
            var len_bytes: [8]u8 = undefined;
            std.mem.writeInt(u64, &len_bytes, @intCast(payload_len), .big);
            try self.buffer.appendSlice(self.allocator, &len_bytes);
        }

        // Payload data
        try self.buffer.appendSlice(self.allocator, payload);
    }

    pub fn build(self: FrameBuilder) []const u8 {
        return self.buffer.items;
    }
};

test "frame builder text" {
    var builder = FrameBuilder.init(testing.allocator);
    defer builder.deinit();

    try builder.text("Hello");

    const frame = builder.build();

    // First byte: FIN=1, opcode=1 (text)
    try testing.expectEqual(@as(u8, 0x81), frame[0]);
    // Second byte: MASK=0, len=5
    try testing.expectEqual(@as(u8, 5), frame[1]);
    // Payload
    try testing.expectEqualStrings("Hello", frame[2..]);
}
// ANCHOR_END: frame_builder

// ANCHOR: frame_parser
pub const FrameParser = struct {
    pub fn parse(data: []const u8) !FrameHeader {
        if (data.len < 2) return error.IncompleteFrame;

        const byte1 = data[0];
        const byte2 = data[1];

        const fin = (byte1 & 0x80) != 0;
        const rsv1 = (byte1 & 0x40) != 0;
        const rsv2 = (byte1 & 0x20) != 0;
        const rsv3 = (byte1 & 0x10) != 0;
        const opcode: FrameHeader.Opcode = @enumFromInt(byte1 & 0x0F);

        const masked = (byte2 & 0x80) != 0;
        var payload_length: u64 = byte2 & 0x7F;

        var offset: usize = 2;

        if (payload_length == 126) {
            if (data.len < 4) return error.IncompleteFrame;
            // Read 16-bit length in network byte order (big-endian)
            payload_length = std.mem.readInt(u16, data[2..4][0..2], .big);
            offset = 4;
        } else if (payload_length == 127) {
            if (data.len < 10) return error.IncompleteFrame;
            // Read 64-bit length in network byte order (big-endian)
            payload_length = std.mem.readInt(u64, data[2..10][0..8], .big);
            offset = 10;
        }

        var masking_key: ?[4]u8 = null;
        if (masked) {
            if (data.len < offset + 4) return error.IncompleteFrame;
            masking_key = data[offset..][0..4].*;
        }

        return .{
            .fin = fin,
            .rsv1 = rsv1,
            .rsv2 = rsv2,
            .rsv3 = rsv3,
            .opcode = opcode,
            .masked = masked,
            .payload_length = payload_length,
            .masking_key = masking_key,
        };
    }

    pub fn unmask(payload: []u8, masking_key: [4]u8) void {
        for (payload, 0..) |*byte, i| {
            byte.* ^= masking_key[i % 4];
        }
    }
};

test "frame parser basic" {
    // Text frame: FIN=1, opcode=1, unmasked, length=5, payload="Hello"
    const frame = [_]u8{ 0x81, 0x05, 'H', 'e', 'l', 'l', 'o' };

    const header = try FrameParser.parse(&frame);

    try testing.expect(header.fin);
    try testing.expectEqual(FrameHeader.Opcode.text, header.opcode);
    try testing.expect(!header.masked);
    try testing.expectEqual(@as(u64, 5), header.payload_length);
}
// ANCHOR_END: frame_parser

// ANCHOR: connection_state
pub const ConnectionState = enum {
    connecting,
    open,
    closing,
    closed,
};

pub const WebSocketConnection = struct {
    state: ConnectionState,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) WebSocketConnection {
        return .{
            .state = .connecting,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *WebSocketConnection) void {
        _ = self;
    }

    pub fn open(self: *WebSocketConnection) void {
        self.state = .open;
    }

    pub fn close(self: *WebSocketConnection) void {
        self.state = .closing;
    }

    pub fn isOpen(self: WebSocketConnection) bool {
        return self.state == .open;
    }

    pub fn canSend(self: WebSocketConnection) bool {
        return self.state == .open or self.state == .closing;
    }
};

test "connection state" {
    var conn = WebSocketConnection.init(testing.allocator);
    defer conn.deinit();

    try testing.expectEqual(ConnectionState.connecting, conn.state);
    try testing.expect(!conn.isOpen());

    conn.open();
    try testing.expect(conn.isOpen());
    try testing.expect(conn.canSend());

    conn.close();
    try testing.expect(!conn.isOpen());
    try testing.expect(conn.canSend()); // Can still send close frame
}
// ANCHOR_END: connection_state

// ANCHOR: close_codes
pub const CloseCode = enum(u16) {
    normal = 1000,
    going_away = 1001,
    protocol_error = 1002,
    unsupported_data = 1003,
    invalid_frame = 1007,
    policy_violation = 1008,
    message_too_big = 1009,
    internal_error = 1011,

    pub fn toString(self: CloseCode) []const u8 {
        return switch (self) {
            .normal => "Normal Closure",
            .going_away => "Going Away",
            .protocol_error => "Protocol Error",
            .unsupported_data => "Unsupported Data",
            .invalid_frame => "Invalid Frame Payload Data",
            .policy_violation => "Policy Violation",
            .message_too_big => "Message Too Big",
            .internal_error => "Internal Server Error",
        };
    }
};

test "close codes" {
    try testing.expectEqual(@as(u16, 1000), @intFromEnum(CloseCode.normal));
    try testing.expectEqualStrings("Normal Closure", CloseCode.normal.toString());
    try testing.expectEqualStrings("Protocol Error", CloseCode.protocol_error.toString());
}
// ANCHOR_END: close_codes

// ANCHOR: message_fragmenter
pub const MessageFragmenter = struct {
    max_frame_size: usize,

    pub fn init(max_frame_size: usize) MessageFragmenter {
        return .{ .max_frame_size = max_frame_size };
    }

    pub fn fragment(
        self: MessageFragmenter,
        allocator: std.mem.Allocator,
        data: []const u8,
    ) !std.ArrayList([]const u8) {
        var fragments = std.ArrayList([]const u8){};
        errdefer {
            for (fragments.items) |frag| {
                allocator.free(frag);
            }
            fragments.deinit(allocator);
        }

        var offset: usize = 0;
        while (offset < data.len) {
            const remaining = data.len - offset;
            const chunk_size = @min(remaining, self.max_frame_size);
            const chunk = try allocator.dupe(u8, data[offset..][0..chunk_size]);
            try fragments.append(allocator, chunk);
            offset += chunk_size;
        }

        return fragments;
    }
};

test "message fragmentation" {
    const fragmenter = MessageFragmenter.init(5);
    const data = "Hello World!";

    var fragments = try fragmenter.fragment(testing.allocator, data);
    defer {
        for (fragments.items) |frag| {
            testing.allocator.free(frag);
        }
        fragments.deinit(testing.allocator);
    }

    try testing.expectEqual(@as(usize, 3), fragments.items.len);
    try testing.expectEqualStrings("Hello", fragments.items[0]);
    try testing.expectEqualStrings(" Worl", fragments.items[1]);
    try testing.expectEqualStrings("d!", fragments.items[2]);
}
// ANCHOR_END: message_fragmenter

// ANCHOR: ping_pong
pub const PingPongHandler = struct {
    last_ping_time: i64 = 0,
    last_pong_time: i64 = 0,

    pub fn sendPing(self: *PingPongHandler, current_time: i64) void {
        self.last_ping_time = current_time;
    }

    pub fn receivePong(self: *PingPongHandler, current_time: i64) void {
        self.last_pong_time = current_time;
    }

    pub fn isAlive(self: PingPongHandler, current_time: i64, timeout_ms: i64) bool {
        if (self.last_ping_time == 0) return true;
        const elapsed = current_time - self.last_ping_time;
        return self.last_pong_time >= self.last_ping_time or elapsed < timeout_ms;
    }
};

test "ping pong handler" {
    var handler = PingPongHandler{};

    handler.sendPing(1000);
    try testing.expect(!handler.isAlive(6000, 4000)); // Timeout

    handler.receivePong(2000);
    try testing.expect(handler.isAlive(6000, 4000)); // Received pong
}
// ANCHOR_END: ping_pong

// Comprehensive test
test "comprehensive websocket patterns" {
    // Build a text frame
    var builder = FrameBuilder.init(testing.allocator);
    defer builder.deinit();

    try builder.text("Test");
    const frame = builder.build();

    // Parse the frame
    const header = try FrameParser.parse(frame);
    try testing.expect(header.fin);
    try testing.expectEqual(FrameHeader.Opcode.text, header.opcode);

    // Connection state management
    var conn = WebSocketConnection.init(testing.allocator);
    defer conn.deinit();

    conn.open();
    try testing.expect(conn.canSend());

    // Close with code
    try builder.close(@intFromEnum(CloseCode.normal), "Goodbye");
    try testing.expect(builder.build().len > 0);
}
