// Recipe 20.3: Parsing raw packets with packed structs
// Target Zig Version: 0.15.2
const std = @import("std");
const testing = std.testing;
const mem = std.mem;

// ANCHOR: ip_header
/// IPv4 header using extern struct for C-compatible layout
const IPv4Header = extern struct {
    version_ihl: u8, // version (4 bits) + IHL (4 bits)
    dscp_ecn: u8, // DSCP (6 bits) + ECN (2 bits)
    total_length: u16,
    identification: u16,
    flags_fragment: u16, // flags (3 bits) + fragment offset (13 bits)
    ttl: u8,
    protocol: u8,
    checksum: u16,
    source_addr: u32,
    dest_addr: u32,

    pub fn version(self: *const IPv4Header) u4 {
        return @truncate(self.version_ihl >> 4);
    }

    pub fn ihl(self: *const IPv4Header) u4 {
        return @truncate(self.version_ihl & 0x0F);
    }

    pub fn headerLength(self: *const IPv4Header) usize {
        return @as(usize, self.ihl()) * 4;
    }

    pub fn fromBytes(bytes: []const u8) !IPv4Header {
        if (bytes.len < @sizeOf(IPv4Header)) {
            return error.PacketTooSmall;
        }
        const header: *const IPv4Header = @ptrCast(@alignCast(bytes.ptr));
        return header.*;
    }

    pub fn toNetworkOrder(self: *IPv4Header) void {
        self.total_length = mem.nativeToBig(u16, self.total_length);
        self.identification = mem.nativeToBig(u16, self.identification);
        self.flags_fragment = mem.nativeToBig(u16, self.flags_fragment);
        self.checksum = mem.nativeToBig(u16, self.checksum);
        self.source_addr = mem.nativeToBig(u32, self.source_addr);
        self.dest_addr = mem.nativeToBig(u32, self.dest_addr);
    }

    pub fn fromNetworkOrder(self: *IPv4Header) void {
        self.total_length = mem.bigToNative(u16, self.total_length);
        self.identification = mem.bigToNative(u16, self.identification);
        self.flags_fragment = mem.bigToNative(u16, self.flags_fragment);
        self.checksum = mem.bigToNative(u16, self.checksum);
        self.source_addr = mem.bigToNative(u32, self.source_addr);
        self.dest_addr = mem.bigToNative(u32, self.dest_addr);
    }
};
// ANCHOR_END: ip_header

// ANCHOR: tcp_header
const TCPHeader = extern struct {
    source_port: u16,
    dest_port: u16,
    seq_num: u32,
    ack_num: u32,
    data_offset_flags: u16, // data offset (4 bits) + reserved (3 bits) + flags (9 bits)
    window_size: u16,
    checksum: u16,
    urgent_pointer: u16,

    pub fn dataOffset(self: *const TCPHeader) u4 {
        const offset_flags = mem.bigToNative(u16, self.data_offset_flags);
        return @truncate(offset_flags >> 12);
    }

    pub fn headerLength(self: *const TCPHeader) usize {
        return @as(usize, self.dataOffset()) * 4;
    }

    pub fn flags(self: *const TCPHeader) TCPFlags {
        const offset_flags = mem.bigToNative(u16, self.data_offset_flags);
        return @bitCast(@as(u9, @truncate(offset_flags & 0x1FF)));
    }

    pub fn fromBytes(bytes: []const u8) !TCPHeader {
        if (bytes.len < @sizeOf(TCPHeader)) {
            return error.PacketTooSmall;
        }
        const header: *const TCPHeader = @ptrCast(@alignCast(bytes.ptr));
        return header.*;
    }
};

// TCP flags in RFC 793 order (LSB to MSB):
// FIN=0x01, SYN=0x02, RST=0x04, PSH=0x08, ACK=0x10, URG=0x20, ECE=0x40, CWR=0x80, NS=0x100
const TCPFlags = packed struct {
    fin: bool, // Bit 0 (0x01)
    syn: bool, // Bit 1 (0x02)
    rst: bool, // Bit 2 (0x04)
    psh: bool, // Bit 3 (0x08)
    ack: bool, // Bit 4 (0x10)
    urg: bool, // Bit 5 (0x20)
    ece: bool, // Bit 6 (0x40)
    cwr: bool, // Bit 7 (0x80)
    ns: bool, // Bit 8 (0x100)
};
// ANCHOR_END: tcp_header

// ANCHOR: udp_header
const UDPHeader = packed struct {
    source_port: u16,
    dest_port: u16,
    length: u16,
    checksum: u16,

    pub fn fromBytes(bytes: []const u8) !UDPHeader {
        if (bytes.len < @sizeOf(UDPHeader)) {
            return error.PacketTooSmall;
        }
        const header: *const UDPHeader = @ptrCast(@alignCast(bytes.ptr));
        return header.*;
    }

    pub fn payloadLength(self: *const UDPHeader) u16 {
        const len = mem.bigToNative(u16, self.length);
        return len - @sizeOf(UDPHeader);
    }
};
// ANCHOR_END: udp_header

// ANCHOR: ethernet_frame
const EthernetFrame = extern struct {
    dest_mac0: u8,
    dest_mac1: u8,
    dest_mac2: u8,
    dest_mac3: u8,
    dest_mac4: u8,
    dest_mac5: u8,
    source_mac0: u8,
    source_mac1: u8,
    source_mac2: u8,
    source_mac3: u8,
    source_mac4: u8,
    source_mac5: u8,
    ethertype: u16,

    pub const ETHERTYPE_IP = 0x0800;
    pub const ETHERTYPE_ARP = 0x0806;
    pub const ETHERTYPE_IPV6 = 0x86DD;

    pub fn fromBytes(bytes: []const u8) !EthernetFrame {
        if (bytes.len < @sizeOf(EthernetFrame)) {
            return error.FrameTooSmall;
        }
        const frame: *const EthernetFrame = @ptrCast(@alignCast(bytes.ptr));
        return frame.*;
    }

    pub fn getEthertype(self: *const EthernetFrame) u16 {
        return mem.bigToNative(u16, self.ethertype);
    }

    pub fn getDestMAC(self: *const EthernetFrame) [6]u8 {
        return [_]u8{
            self.dest_mac0,
            self.dest_mac1,
            self.dest_mac2,
            self.dest_mac3,
            self.dest_mac4,
            self.dest_mac5,
        };
    }

    pub fn getSourceMAC(self: *const EthernetFrame) [6]u8 {
        return [_]u8{
            self.source_mac0,
            self.source_mac1,
            self.source_mac2,
            self.source_mac3,
            self.source_mac4,
            self.source_mac5,
        };
    }
};
// ANCHOR_END: ethernet_frame

// ANCHOR: packet_parser
const PacketParser = struct {
    pub fn parseIPv4(packet: []const u8) !struct {
        header: IPv4Header,
        payload: []const u8,
    } {
        var header = try IPv4Header.fromBytes(packet);
        header.fromNetworkOrder();

        const header_len = header.headerLength();
        if (packet.len < header_len) {
            return error.PacketTruncated;
        }

        return .{
            .header = header,
            .payload = packet[header_len..],
        };
    }

    pub fn parseTCP(packet: []const u8) !struct {
        header: TCPHeader,
        payload: []const u8,
    } {
        const header = try TCPHeader.fromBytes(packet);
        const header_len = header.headerLength();

        if (packet.len < header_len) {
            return error.PacketTruncated;
        }

        return .{
            .header = header,
            .payload = packet[header_len..],
        };
    }

    pub fn parseUDP(packet: []const u8) !struct {
        header: UDPHeader,
        payload: []const u8,
    } {
        const header = try UDPHeader.fromBytes(packet);

        if (packet.len < @sizeOf(UDPHeader)) {
            return error.PacketTruncated;
        }

        return .{
            .header = header,
            .payload = packet[@sizeOf(UDPHeader)..],
        };
    }
};
// ANCHOR_END: packet_parser

// ANCHOR: packet_builder
const PacketBuilder = struct {
    pub fn buildIPv4Header(
        protocol: u8,
        source: u32,
        dest: u32,
        payload_len: u16,
    ) IPv4Header {
        var header = IPv4Header{
            .version_ihl = (4 << 4) | 5, // IPv4, 5 words (20 bytes)
            .dscp_ecn = 0,
            .total_length = @sizeOf(IPv4Header) + payload_len,
            .identification = 0,
            .flags_fragment = 0,
            .ttl = 64,
            .protocol = protocol,
            .checksum = 0,
            .source_addr = source,
            .dest_addr = dest,
        };
        header.toNetworkOrder();
        return header;
    }

    pub fn buildUDPHeader(
        source_port: u16,
        dest_port: u16,
        payload_len: u16,
    ) UDPHeader {
        return UDPHeader{
            .source_port = mem.nativeToBig(u16, source_port),
            .dest_port = mem.nativeToBig(u16, dest_port),
            .length = mem.nativeToBig(u16, @sizeOf(UDPHeader) + payload_len),
            .checksum = 0,
        };
    }
};
// ANCHOR_END: packet_builder

// Tests
test "IPv4 header size" {
    try testing.expectEqual(@as(usize, 20), @sizeOf(IPv4Header));
}

test "IPv4 header parsing" {
    var packet = [_]u8{
        0x45, 0x00, // version, IHL, DSCP, ECN
        0x00, 0x3c, // total length
        0x1c, 0x46, // identification
        0x40, 0x00, // flags, fragment offset
        0x40, 0x06, // TTL, protocol
        0xb1, 0xe6, // checksum
        0xc0, 0xa8, 0x00, 0x68, // source IP
        0xc0, 0xa8, 0x00, 0x01, // dest IP
    };

    var header = try IPv4Header.fromBytes(&packet);
    try testing.expectEqual(@as(u4, 4), header.version());
    try testing.expectEqual(@as(u4, 5), header.ihl());
    try testing.expectEqual(@as(usize, 20), header.headerLength());
}

test "TCP header size" {
    try testing.expectEqual(@as(usize, 20), @sizeOf(TCPHeader));
}

test "TCP flags parsing" {
    const packet = [_]u8{
        0x00, 0x50, // source port
        0x01, 0xbb, // dest port
        0x00, 0x00, 0x00, 0x00, // seq
        0x00, 0x00, 0x00, 0x00, // ack
        0x50, 0x12, // data offset + flags (SYN+ACK)
        0x20, 0x00, // window
        0x00, 0x00, // checksum
        0x00, 0x00, // urgent
    };

    const header = try TCPHeader.fromBytes(&packet);
    const tcp_flags = header.flags();
    // 0x5012: offset=5, flags=0x012 = 0b0001_0010
    // Bit 1 (SYN = 0x02) = 1, Bit 4 (ACK = 0x10) = 1
    try testing.expect(tcp_flags.syn); // SYN must be set
    try testing.expect(tcp_flags.ack); // ACK must be set
    try testing.expect(!tcp_flags.fin); // FIN must NOT be set
    try testing.expect(!tcp_flags.rst); // RST must NOT be set
    try testing.expect(!tcp_flags.psh); // PSH must NOT be set
    try testing.expect(!tcp_flags.urg); // URG must NOT be set
    try testing.expectEqual(@as(u4, 5), header.dataOffset());
}

test "UDP header size" {
    try testing.expectEqual(@as(usize, 8), @sizeOf(UDPHeader));
}

test "UDP payload length" {
    const packet = [_]u8{
        0x00, 0x35, // source port
        0x00, 0x35, // dest port
        0x00, 0x20, // length (32 bytes)
        0x00, 0x00, // checksum
    };

    const header = try UDPHeader.fromBytes(&packet);
    try testing.expectEqual(@as(u16, 24), header.payloadLength());
}

test "Ethernet frame size" {
    try testing.expectEqual(@as(usize, 14), @sizeOf(EthernetFrame));
}

test "Ethernet ethertype" {
    var frame = EthernetFrame{
        .dest_mac0 = 0xff,
        .dest_mac1 = 0xff,
        .dest_mac2 = 0xff,
        .dest_mac3 = 0xff,
        .dest_mac4 = 0xff,
        .dest_mac5 = 0xff,
        .source_mac0 = 0x00,
        .source_mac1 = 0x11,
        .source_mac2 = 0x22,
        .source_mac3 = 0x33,
        .source_mac4 = 0x44,
        .source_mac5 = 0x55,
        .ethertype = mem.nativeToBig(u16, EthernetFrame.ETHERTYPE_IP),
    };

    try testing.expectEqual(EthernetFrame.ETHERTYPE_IP, frame.getEthertype());
    const dest_mac = frame.getDestMAC();
    try testing.expectEqual(@as(u8, 0xff), dest_mac[0]);
}

test "packet parser - IPv4" {
    const packet = [_]u8{
        0x45, 0x00, 0x00, 0x3c, 0x1c, 0x46, 0x40, 0x00,
        0x40, 0x06, 0xb1, 0xe6, 0xc0, 0xa8, 0x00, 0x68,
        0xc0, 0xa8, 0x00, 0x01, // 20 byte header
        0xde, 0xad, 0xbe, 0xef, // payload
    };

    const parsed = try PacketParser.parseIPv4(&packet);
    try testing.expectEqual(@as(u4, 4), parsed.header.version());
    try testing.expectEqual(@as(usize, 4), parsed.payload.len);
}

test "packet builder - IPv4" {
    const header = PacketBuilder.buildIPv4Header(6, 0xC0A80001, 0xC0A80002, 100);
    try testing.expectEqual(@as(u4, 4), header.version());
    try testing.expectEqual(@as(u8, 6), header.protocol);
}

test "packet builder - UDP" {
    const header = PacketBuilder.buildUDPHeader(53, 53, 512);
    const payload_len = header.payloadLength();
    try testing.expectEqual(@as(u16, 512), payload_len);
}
