# Recipe 20.6: Creating Raw Sockets (Reading Raw Ethernet Frames)

## Problem

You need to capture or send packets at the lowest network level, below IP. This is useful for network monitoring tools, packet sniffers, custom protocol implementation, or security analysis.

## Solution

Use raw sockets with `AF.PACKET` to read and write raw Ethernet frames. This gives complete access to network traffic but requires elevated privileges.

### Raw Socket Creation

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_6.zig:raw_socket}}
```

### Packet Capture

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_6.zig:packet_capture}}
```

### Ethernet Sniffer

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_6.zig:ethernet_sniffer}}
```

## Discussion

Raw sockets provide the lowest-level network access, capturing packets before the kernel processes them.

### Privileges Required

Raw sockets require elevated privileges:
- **Linux**: CAP_NET_RAW capability or root
- **macOS**: root
- **Windows**: Administrator

Run with sudo:
```bash
sudo ./packet_sniffer
```

### Socket Types

**AF.PACKET** (Linux):
- Access to link layer
- See all packets on interface
- Can send custom frames

**PF.PACKET** (also Linux):
- Synonym for AF.PACKET
- Same functionality

**Protocol 0x0003** (ETH_P_ALL):
- Captures all Ethernet protocols
- IPv4, IPv6, ARP, etc.

### Packet Filter

Raw sockets capture ALL traffic, which can be overwhelming. Filter by:
- EtherType (IPv4, IPv6, ARP)
- Source/Destination MAC
- VLAN tags
- Custom logic

Common EtherTypes:
- `0x0800`: IPv4
- `0x0806`: ARP
- `0x86DD`: IPv6
- `0x8100`: VLAN-tagged frame

### Promiscuous Mode

By default, sockets only see:
- Broadcast packets
- Multicast packets registered to
- Packets destined for this host

Enable promiscuous mode to see ALL packets on the network:
```zig
// Note: Requires additional socket options
// Implementation is platform-specific
```

### Performance Considerations

**High volume:**
- Network cards process millions of packets/second
- Buffer packets to avoid drops
- Use multiple threads for processing
- Consider kernel bypass (DPDK, AF_XDP)

**Memory:**
- Each packet needs a buffer
- Allocate ring buffer for efficiency
- Reuse buffers to avoid allocation

### Use Cases

**Network Monitoring:**
```zig
while (true) {
    var buffer: [2048]u8 = undefined;
    const size = try sniffer.sniff(&buffer);
    if (size) |s| {
        analyzePacket(buffer[0..s]);
    }
}
```

**Protocol Analysis:**
```zig
// Capture only ARP packets
var arp_sniffer = try EthernetSniffer.init(0x0806);
const packet = try arp_sniffer.sniff(&buffer);
parseARPPacket(packet);
```

**Custom Protocol:**
```zig
// Implement custom L2 protocol
const MY_ETHERTYPE: u16 = 0x88B5;
var sniffer = try EthernetSniffer.init(MY_ETHERTYPE);
```

### Security Implications

Raw sockets are powerful and dangerous:
- Can capture sensitive data (passwords, keys)
- Can spoof source addresses
- Can DOS with malformed packets
- Breach confidentiality

**Ethical use only:**
- Own networks/devices
- Authorized penetration testing
- Network administration
- Security research with permission

### Platform Differences

**Linux (AF.PACKET):**
- Most flexible
- Excellent performance
- Well-documented

**BSD/macOS (BPF):**
- Use Berkeley Packet Filter
- Different API
- `/dev/bpf` devices

**Windows (Npcap/WinPcap):**
- Requires driver installation
- Different API
- More restricted

### Alternatives to Raw Sockets

**libpcap/tcpdump:**
- Cross-platform packet capture
- Higher-level API
- BPF filter language
- Industry standard

**AF_XDP (Linux):**
- Kernel bypass
- Extreme performance
- Complex setup

**DPDK:**
- Data Plane Development Kit
- User-space drivers
- Used in routers/firewalls

## See Also

- Recipe 20.3: Parsing Raw Packets - Interpreting captured data
- Recipe 20.1: Non-Blocking TCP Servers - Higher-level network programming
- Recipe 20.5: Using UDP Multicast - Layer 3 multicast

Full compilable example: `code/05-zig-paradigms/20-high-perf-networking/recipe_20_6.zig`
