// Recipe 20.5: Using UDP multicast
// Target Zig Version: 0.15.2
const std = @import("std");
const testing = std.testing;
const posix = std.posix;
const net = std.net;
const mem = std.mem;

// ANCHOR: multicast_sender
const MulticastSender = struct {
    socket: posix.socket_t,
    multicast_addr: net.Address,

    pub fn init(group: []const u8, port: u16) !MulticastSender {
        const addr = try net.Address.parseIp(group, port);

        const socket = try posix.socket(
            posix.AF.INET,
            posix.SOCK.DGRAM,
            posix.IPPROTO.UDP,
        );
        errdefer posix.close(socket);

        return .{
            .socket = socket,
            .multicast_addr = addr,
        };
    }

    pub fn deinit(self: *MulticastSender) void {
        posix.close(self.socket);
    }

    pub fn send(self: *MulticastSender, data: []const u8) !void {
        _ = try posix.sendto(
            self.socket,
            data,
            0,
            &self.multicast_addr.any,
            self.multicast_addr.getOsSockLen(),
        );
    }
};
// ANCHOR_END: multicast_sender

// ANCHOR: multicast_receiver
const MulticastReceiver = struct {
    socket: posix.socket_t,
    local_addr: net.Address,

    pub fn init(port: u16) !MulticastReceiver {
        const any_addr = try net.Address.parseIp("0.0.0.0", port);

        const socket = try posix.socket(
            posix.AF.INET,
            posix.SOCK.DGRAM,
            posix.IPPROTO.UDP,
        );
        errdefer posix.close(socket);

        try posix.setsockopt(
            socket,
            posix.SOL.SOCKET,
            posix.SO.REUSEADDR,
            &mem.toBytes(@as(c_int, 1)),
        );

        try posix.bind(socket, &any_addr.any, any_addr.getOsSockLen());

        // Note: Actual multicast group joining is platform-specific
        // and would require using C structures not directly available in Zig std.posix

        return .{
            .socket = socket,
            .local_addr = any_addr,
        };
    }

    pub fn deinit(self: *MulticastReceiver) void {
        posix.close(self.socket);
    }

    pub fn receive(self: *MulticastReceiver, buffer: []u8) !usize {
        return try posix.recv(self.socket, buffer, 0);
    }
};
// ANCHOR_END: multicast_receiver

// ANCHOR: multicast_config
const MulticastConfig = struct {
    ttl: u8 = 1,
    loop: bool = true,

    pub fn apply(self: *const MulticastConfig, socket: posix.socket_t) !void {
        // Set TTL
        try posix.setsockopt(
            socket,
            posix.IPPROTO.IP,
            posix.IP.MULTICAST_TTL,
            &mem.toBytes(@as(c_int, self.ttl)),
        );

        // Set loopback
        const loop_val: c_int = if (self.loop) 1 else 0;
        try posix.setsockopt(
            socket,
            posix.IPPROTO.IP,
            posix.IP.MULTICAST_LOOP,
            &mem.toBytes(loop_val),
        );
    }
};
// ANCHOR_END: multicast_config

// Tests
test "multicast sender creation" {
    if (@import("builtin").os.tag == .wasi) return error.SkipZigTest;

    var sender = try MulticastSender.init("239.0.0.1", 5000);
    defer sender.deinit();

    try testing.expect(sender.socket >= 0);
}

test "multicast receiver creation" {
    if (@import("builtin").os.tag == .wasi) return error.SkipZigTest;

    var receiver = try MulticastReceiver.init(5001);
    defer receiver.deinit();

    try testing.expect(receiver.socket >= 0);
}

test "multicast config" {
    const config = MulticastConfig{
        .ttl = 2,
        .loop = false,
    };

    try testing.expectEqual(@as(u8, 2), config.ttl);
    try testing.expectEqual(false, config.loop);
}
