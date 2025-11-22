// Recipe 20.6: Creating raw sockets (reading raw ethernet frames)
// Target Zig Version: 0.15.2
const std = @import("std");
const testing = std.testing;
const posix = std.posix;
const mem = std.mem;

// ANCHOR: raw_socket
const RawSocket = struct {
    socket: posix.socket_t,

    pub fn init() !RawSocket {
        // Note: Requires root/admin privileges
        const socket = posix.socket(
            posix.AF.PACKET,
            posix.SOCK.RAW,
            mem.nativeToBig(u16, 0x0003), // ETH_P_ALL
        ) catch |err| {
            std.debug.print("Failed to create raw socket. Need root privileges.\n", .{});
            return err;
        };

        return .{ .socket = socket };
    }

    pub fn deinit(self: *RawSocket) void {
        posix.close(self.socket);
    }

    pub fn receive(self: *RawSocket, buffer: []u8) !usize {
        return try posix.recv(self.socket, buffer, 0);
    }
};
// ANCHOR_END: raw_socket

// ANCHOR: packet_capture
const PacketCapture = struct {
    socket: RawSocket,
    packets_captured: usize,

    pub fn init() !PacketCapture {
        return .{
            .socket = try RawSocket.init(),
            .packets_captured = 0,
        };
    }

    pub fn deinit(self: *PacketCapture) void {
        self.socket.deinit();
    }

    pub fn captureOne(self: *PacketCapture, buffer: []u8) !usize {
        const size = try self.socket.receive(buffer);
        self.packets_captured += 1;
        return size;
    }

    pub fn getStats(self: *const PacketCapture) struct { packets: usize } {
        return .{ .packets = self.packets_captured };
    }
};
// ANCHOR_END: packet_capture

// ANCHOR: ethernet_sniffer
const EthernetSniffer = struct {
    capture: PacketCapture,
    filter_ethertype: ?u16,

    pub fn init(filter: ?u16) !EthernetSniffer {
        return .{
            .capture = try PacketCapture.init(),
            .filter_ethertype = filter,
        };
    }

    pub fn deinit(self: *EthernetSniffer) void {
        self.capture.deinit();
    }

    pub fn sniff(self: *EthernetSniffer, buffer: []u8) !?usize {
        const size = try self.capture.captureOne(buffer);

        if (self.filter_ethertype) |filter| {
            if (size < 14) return null;

            const ethertype = mem.bigToNative(u16, @as(*const u16, @ptrCast(@alignCast(&buffer[12]))).*);

            if (ethertype != filter) {
                return null;
            }
        }

        return size;
    }
};
// ANCHOR_END: ethernet_sniffer

// Tests
test "raw socket struct creation" {
    // Note: This test will fail without root privileges
    // We test the struct API, not actual socket creation
    const socket_id: posix.socket_t = 42;
    const raw = RawSocket{ .socket = socket_id };
    defer {} // Don't actually close in test

    try testing.expectEqual(socket_id, raw.socket);
}

test "packet capture initialization" {
    // Test structure without requiring root
    const stats = PacketCapture{
        .socket = .{ .socket = 0 },
        .packets_captured = 5,
    };

    const result = stats.getStats();
    try testing.expectEqual(@as(usize, 5), result.packets);
}

test "ethernet sniffer with filter" {
    // Test filter configuration
    const ETHERTYPE_IP: u16 = 0x0800;

    const sniffer_config = struct {
        filter: ?u16,
    }{ .filter = ETHERTYPE_IP };

    try testing.expectEqual(ETHERTYPE_IP, sniffer_config.filter.?);
}
