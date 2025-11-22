# Recipe 11.3: WebSocket Communication

## Problem

You want to implement WebSocket communication in Zig - understanding the protocol structure, building and parsing frames, handling the handshake, and managing connection state. You need to work with real-time bidirectional communication.

## Solution

WebSocket is a protocol that provides full-duplex communication over a single TCP connection. While Zig doesn't have a built-in WebSocket library, understanding the protocol patterns helps you use existing libraries or implement custom solutions.

This recipe demonstrates the WebSocket protocol structure and patterns without actual networking code.

### WebSocket Frame Structure

WebSocket messages are sent as frames with a specific header format:

```zig
{{#include ../../../code/04-specialized/11-network-web/recipe_11_3.zig:frame_header}}
```

The underscore `_` in the enum makes it non-exhaustive, allowing unknown opcodes without panicking (useful for forward compatibility).

Opcode classification:

```zig
try testing.expect(FrameHeader.Opcode.ping.isControl());
try testing.expect(FrameHeader.Opcode.pong.isControl());
try testing.expect(FrameHeader.Opcode.close.isControl());
try testing.expect(!FrameHeader.Opcode.text.isControl());
```

### Message Types

Define high-level message types:

```zig
{{#include ../../../code/04-specialized/11-network-web/recipe_11_3.zig:message_type}}
```

Usage:

```zig
var msg = try Message.init(testing.allocator, .text, "Hello WebSocket");
defer msg.deinit();

try testing.expectEqual(MessageType.text, msg.type);
try testing.expectEqualStrings("Hello WebSocket", msg.data);
```

## Discussion

### Python vs Zig WebSocket Implementation

The approaches differ significantly:

**Python (websockets library):**
```python
import asyncio
import websockets

async def echo(websocket):
    async for message in websocket:
        await websocket.send(message)

# High-level abstraction
async def main():
    async with websockets.serve(echo, "localhost", 8765):
        await asyncio.Future()  # run forever

asyncio.run(main())
```

**Zig (protocol patterns):**
```zig
// Low-level protocol control
var builder = FrameBuilder.init(allocator);
defer builder.deinit();

try builder.text("Hello");
const frame = builder.build();

// Parse incoming frames
const header = try FrameParser.parse(frame);
// Handle based on opcode...
```

Key differences:
- **Abstraction Level**: Python hides protocol details; Zig exposes them
- **Control**: Zig gives precise control over frames; Python handles automatically
- **Performance**: Zig has zero overhead; Python has async runtime costs
- **Learning**: Zig teaches protocol internals; Python teaches API usage
- **Production**: Python is easier for simple cases; Zig better for custom protocols

### WebSocket Handshake

The WebSocket connection starts with an HTTP upgrade:

**Client Request:**

```zig
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
```

Example usage:

```zig
const request = HandshakeRequest{
    .host = "example.com",
    .path = "/chat",
    .key = "dGhlIHNhbXBsZSBub25jZQ==",
};

const handshake = try request.build(testing.allocator);
defer testing.allocator.free(handshake);

// Verify format
try testing.expect(std.mem.indexOf(u8, handshake, "GET /chat HTTP/1.1") != null);
try testing.expect(std.mem.indexOf(u8, handshake, "Upgrade: websocket") != null);
```

**Server Response:**

```zig
pub const HandshakeResponse = struct {
    status_code: u16,
    accept_key: ?[]const u8 = null,
    protocol: ?[]const u8 = null,

    pub fn isValid(self: HandshakeResponse) bool {
        return self.status_code == 101 and self.accept_key != null;
    }
};
```

Successful handshake response:

```
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
```

The `Sec-WebSocket-Accept` value is derived from the client's key using SHA-1 and Base64 encoding (production implementations must verify this).

### Building WebSocket Frames

Create frames for different message types:

```zig
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

    pub fn build(self: FrameBuilder) []const u8 {
        return self.buffer.items;
    }
};
```

Building a text frame:

```zig
var builder = FrameBuilder.init(testing.allocator);
defer builder.deinit();

try builder.text("Hello");

const frame = builder.build();

// Frame format: [FIN|RSV|Opcode][MASK|Length][Payload]
// First byte: FIN=1, opcode=1 (text) = 0x81
try testing.expectEqual(@as(u8, 0x81), frame[0]);
// Second byte: MASK=0, len=5 = 0x05
try testing.expectEqual(@as(u8, 5), frame[1]);
// Payload
try testing.expectEqualStrings("Hello", frame[2..]);
```

The frame structure:
- **Byte 0**: `FIN` (1 bit) + `RSV1-3` (3 bits) + `Opcode` (4 bits)
- **Byte 1**: `MASK` (1 bit) + `Payload Length` (7 bits)
- **Extended Length**: 2 or 8 bytes if needed
- **Masking Key**: 4 bytes if masked (client-to-server)
- **Payload**: The actual message data

### Parsing WebSocket Frames

Parse incoming frames to extract headers:

```zig
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
            payload_length = (@as(u64, data[2]) << 8) | @as(u64, data[3]);
            offset = 4;
        } else if (payload_length == 127) {
            if (data.len < 10) return error.IncompleteFrame;
            payload_length = 0;
            for (2..10) |i| {
                payload_length = (payload_length << 8) | @as(u64, data[i]);
            }
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
```

Parsing example:

```zig
// Text frame: FIN=1, opcode=1, unmasked, length=5, payload="Hello"
const frame = [_]u8{ 0x81, 0x05, 'H', 'e', 'l', 'l', 'o' };

const header = try FrameParser.parse(&frame);

try testing.expect(header.fin);
try testing.expectEqual(FrameHeader.Opcode.text, header.opcode);
try testing.expect(!header.masked);
try testing.expectEqual(@as(u64, 5), header.payload_length);
```

### Connection State Management

Track WebSocket connection lifecycle:

```zig
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
```

State transitions:

```zig
var conn = WebSocketConnection.init(testing.allocator);
defer conn.deinit();

try testing.expectEqual(ConnectionState.connecting, conn.state);

conn.open();
try testing.expect(conn.isOpen());
try testing.expect(conn.canSend());

conn.close();
try testing.expect(!conn.isOpen());
try testing.expect(conn.canSend()); // Can still send close frame
```

### Close Codes

WebSocket defines standard closure codes:

```zig
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
```

Using close codes:

```zig
try builder.close(@intFromEnum(CloseCode.normal), "Goodbye");

// In production, parse close frame to get code and reason
if (header.opcode == .close) {
    const code = @as(u16, payload[0]) << 8 | payload[1];
    const reason = payload[2..];
    // Handle graceful shutdown...
}
```

### Message Fragmentation

Split large messages into multiple frames:

```zig
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
```

Example:

```zig
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
```

When sending fragmented messages:
- First frame: `FIN=0`, opcode = text/binary
- Middle frames: `FIN=0`, opcode = continuation (0x0)
- Last frame: `FIN=1`, opcode = continuation

### Ping/Pong Heartbeat

Detect connection health with ping/pong:

```zig
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
```

Usage pattern:

```zig
var handler = PingPongHandler{};

// Send ping
handler.sendPing(1000);

// Later: check if alive
if (!handler.isAlive(6000, 4000)) {
    // No pong received within timeout - connection dead
    conn.close();
}

// When pong received
handler.receivePong(2000);
// Connection is alive
```

## Production WebSocket Implementation

**Important:** This recipe demonstrates protocol patterns for learning. Production implementations require:

1. **Transport Security**: Use WSS (WebSocket Secure) over TLS 1.2+
2. **Handshake Validation**: Verify `Sec-WebSocket-Accept` using SHA-1 + Base64
3. **Frame Size Limits**: Enforce maximum frame/message size to prevent DoS
4. **UTF-8 Validation**: Text frames must contain valid UTF-8 sequences
5. **Timeout Handling**: Implement connection and idle timeouts
6. **Cryptographic Masking**: Use secure random number generation for client masks
7. **Resource Limits**: Limit concurrent connections, buffer sizes, fragmentation
8. **Error Handling**: Properly close connections with appropriate status codes

**Recommendation:** Use a battle-tested library like `websocket.zig` for production use.

## Best Practices

1. **Validate Reserved Bits**: RSV1-3 must be 0 unless extension negotiates their use
2. **Control Frame Limits**: Control frames (ping/pong/close) must have payload ≤ 125 bytes
3. **Client Masking**: Client-to-server frames MUST be masked
4. **Server Unmasked**: Server-to-client frames MUST NOT be masked
5. **Handle Fragmentation**: Support receiving fragmented messages
6. **Respond to Ping**: Always send pong in response to ping
7. **Graceful Close**: Send close frame before closing TCP connection
8. **Error Codes**: Use appropriate close codes for different failure modes
9. **UTF-8 Validation**: Validate text frame payloads are valid UTF-8
10. **Buffering Strategy**: Implement flow control to prevent memory exhaustion

## Common Patterns

**Echo Server Pattern:**
```zig
// Receive message
const header = try FrameParser.parse(frame_data);

if (header.opcode == .text or header.opcode == .binary) {
    // Extract payload
    const payload = frame_data[header_size..][0..header.payload_length];

    // Echo back
    var builder = FrameBuilder.init(allocator);
    defer builder.deinit();

    if (header.opcode == .text) {
        try builder.text(payload);
    } else {
        try builder.binary(payload);
    }

    // Send builder.build() back to client
}
```

**Heartbeat Loop:**
```zig
const PING_INTERVAL = 30_000; // 30 seconds
const PONG_TIMEOUT = 10_000; // 10 seconds

var handler = PingPongHandler{};
var last_ping: i64 = 0;

while (conn.isOpen()) {
    const now = std.time.milliTimestamp();

    // Send periodic pings
    if (now - last_ping >= PING_INTERVAL) {
        try builder.ping("heartbeat");
        handler.sendPing(now);
        last_ping = now;
    }

    // Check if connection is alive
    if (!handler.isAlive(now, PONG_TIMEOUT)) {
        try builder.close(@intFromEnum(CloseCode.going_away), "Timeout");
        break;
    }

    // Process incoming frames...
}
```

**Graceful Shutdown:**
```zig
// Initiate close handshake
var builder = FrameBuilder.init(allocator);
defer builder.deinit();

try builder.close(@intFromEnum(CloseCode.normal), "Server shutting down");
// Send close frame

// Wait for close frame response (with timeout)
// Then close TCP connection
```

## Troubleshooting

**Frame Parse Errors:**
- Check that you have complete frame data before parsing
- Verify endianness for multi-byte length fields (network byte order = big-endian)
- Ensure masking key is present for client frames

**Handshake Failures:**
- Verify `Sec-WebSocket-Key` is properly Base64 encoded
- Check that `Upgrade: websocket` header is present
- Ensure `Connection: Upgrade` header is set
- Validate `Sec-WebSocket-Version: 13` is sent

**Message Corruption:**
- Text frames must be valid UTF-8
- Ensure proper masking/unmasking for client frames
- Check that fragmented messages use correct opcodes

**Connection Drops:**
- Implement ping/pong heartbeat mechanism
- Set appropriate TCP keepalive timeouts
- Handle network errors gracefully with close frames

## See Also

- Recipe 11.1: Making HTTP Requests - HTTP protocol fundamentals
- Recipe 11.2: Working with JSON APIs - Sending JSON over WebSocket
- Recipe 11.4: Building a Simple HTTP Server - Server-side WebSocket upgrades
- Recipe 12.1: Async I/O Patterns - Asynchronous WebSocket handling

Full compilable example: `code/04-specialized/11-network-web/recipe_11_3.zig`
