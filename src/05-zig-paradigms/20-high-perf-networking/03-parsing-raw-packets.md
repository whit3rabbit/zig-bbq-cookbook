# Recipe 20.3: Parsing Raw Packets with Packed Structs

## Problem

You need to parse network packets at a low level, extracting headers and fields from raw binary data. Manual byte manipulation is error-prone and makes code hard to maintain.

## Solution

Use Zig's `extern struct` to define packet structures that map directly to network protocol layouts. extern structs guarantee C-compatible memory layout, making them perfect for binary protocols.

### IPv4 Header

Define an IPv4 header structure:

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_3.zig:ip_header}}
```

### TCP Header

Parse TCP headers with bitfield access:

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_3.zig:tcp_header}}
```

### UDP Header

UDP has a simpler header:

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_3.zig:udp_header}}
```

### Ethernet Frame

Handle link-layer frames:

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_3.zig:ethernet_frame}}
```

### Packet Parser

Combine parsers for complete packet handling:

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_3.zig:packet_parser}}
```

### Packet Builder

Build packets programmatically:

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_3.zig:packet_builder}}
```

## Discussion

Low-level packet parsing requires understanding both network protocols and memory layout. Zig makes this safe and efficient.

### extern vs packed Structs

**extern struct:**
- C-compatible layout
- Natural alignment (2-byte fields on 2-byte boundaries)
- Works for most network protocols
- Best for interfacing with C libraries

**packed struct:**
- Bit-level control
- Can create odd-sized types
- Useful for protocols with bit fields
- More complex to work with

For network protocols, extern struct is usually the right choice because network headers follow natural alignment.

### Network Byte Order

Network protocols use big-endian byte order. Always convert:
- `mem.nativeToBig()` when building packets
- `mem.bigToNative()` when parsing packets

The IPv4Header example shows both conversions in `toNetworkOrder()` and `fromNetworkOrder()`.

### Bitfield Access

Some header fields pack multiple values into single bytes:
- IPv4: version (4 bits) + IHL (4 bits)
- TCP: data offset (4 bits) + reserved (3 bits) + flags (9 bits)

Use bit shifting and masking to extract these:
```zig
pub fn version(self: *const IPv4Header) u4 {
    return @truncate(self.version_ihl >> 4);
}
```

### Safety Considerations

**Always validate input:**
- Check packet length before casting
- Verify header checksums
- Validate field values (TTL, protocol numbers, etc.)

**Alignment matters:**
- Use `@ptrCast(@alignCast(...))` when casting bytes to struct pointers
- extern struct guarantees natural alignment
- Be careful with odd-sized packets

### Protocol Examples

**IPv4 Header:** 20 bytes minimum
- Version, IHL, DSCP, ECN (4 bytes)
- Length, ID, Flags, Fragment (4 bytes)
- TTL, Protocol, Checksum (4 bytes)
- Source IP (4 bytes)
- Destination IP (4 bytes)

**TCP Header:** 20 bytes minimum
- Ports, sequence, acknowledgment (12 bytes)
- Data offset, flags, window (4 bytes)
- Checksum, urgent pointer (4 bytes)

**UDP Header:** 8 bytes fixed
- Source/dest ports (4 bytes)
- Length, checksum (4 bytes)

### Performance Tips

**Zero-copy parsing:**
- Cast directly from packet buffer to struct
- No allocation or copying needed
- Extremely fast

**Batch processing:**
- Parse many packets without allocation
- Use stack buffers for small headers
- Stream processing for high throughput

### MAC Address Handling

Packed structs can't contain arrays in Zig 0.15, so MAC addresses use individual fields. Helper methods provide array access:

```zig
pub fn getDestMAC(self: *const EthernetFrame) [6]u8 {
    return [_]u8{
        self.dest_mac0, self.dest_mac1, self.dest_mac2,
        self.dest_mac3, self.dest_mac4, self.dest_mac5,
    };
}
```

This keeps the struct layout simple while providing convenient access.

## See Also

- Recipe 20.1: Non-Blocking TCP Servers - Using parsed packets
- Recipe 20.6: Creating Raw Sockets - Capturing raw packets
- Recipe 6.9: Binary Arrays of Structures - Binary data handling
- Recipe 3.4: Searching and Matching Text Patterns - Pattern matching

Full compilable example: `code/05-zig-paradigms/20-high-perf-networking/recipe_20_3.zig`
