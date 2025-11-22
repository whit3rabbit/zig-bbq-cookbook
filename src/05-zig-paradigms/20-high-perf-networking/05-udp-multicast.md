# Recipe 20.5: Using UDP Multicast

## Problem

You need to send data to multiple receivers simultaneously without maintaining individual connections to each one. Traditional unicast requires sending the same data separately to each recipient, wasting bandwidth.

## Solution

Use UDP multicast to send a single packet that's delivered to all members of a multicast group. This is efficient for scenarios like live streaming, distributed systems, or service discovery.

### Multicast Sender

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_5.zig:multicast_sender}}
```

### Multicast Receiver

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_5.zig:multicast_receiver}}
```

### Multicast Configuration

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_5.zig:multicast_config}}
```

## Discussion

Multicast is a one-to-many communication method where a single packet reaches multiple destinations.

### Multicast Addresses

IPv4 multicast uses addresses in the range `224.0.0.0` to `239.255.255.255`:

- **224.0.0.0 - 224.0.0.255**: Reserved (local network control)
- **224.0.1.0 - 238.255.255.255**: Globally scoped
- **239.0.0.0 - 239.255.255.255**: Administratively scoped (local)

For local testing, use addresses like `239.0.0.1`.

### How Multicast Works

1. **Sender**: Creates a UDP socket and sends to multicast address
2. **Receiver**: Joins the multicast group to receive packets
3. **Network**: Routers replicate packets to all group members

This is more efficient than sending individual copies.

### TTL (Time To Live)

TTL limits how far multicast packets travel:
- **1**: Local network only (default)
- **32**: Within site
- **64**: Within region
- **128**: Within continent
- **255**: Global

Set TTL based on your needs to avoid unnecessary network traffic.

### Multicast Loopback

By default, multicast packets loop back to the sender. Disable if you don't want to receive your own messages:

```zig
config.loop = false;
```

### Platform Considerations

Joining multicast groups requires platform-specific structures:
- **Linux**: Uses `ip_mreqn`
- **BSD/macOS**: Uses `ip_mreq`
- **Windows**: Uses `ip_mreq`

The code shows the basic UDP setup; actual group joining requires C interop with platform-specific headers.

### Common Use Cases

**Service Discovery:**
```zig
// Announce service on 239.255.255.250:1900
var sender = try MulticastSender.init("239.255.255.250", 1900);
try sender.send("SERVICE:MyApp:192.168.1.100:8080");
```

**Live Data Feeds:**
```zig
// Stock quotes to all subscribers
while (true) {
    const quote = getLatestQuote();
    try sender.send(quote);
    std.time.sleep(1 * std.time.ns_per_s);
}
```

**Distributed Logging:**
```zig
// Log to all monitoring systems
try sender.send("ERROR: Database connection failed");
```

### Security Considerations

Multicast has security implications:
- Anyone on the network can join your group
- No built-in authentication
- Packets can be sniffed
- Easy to cause DoS by flooding

**Best practices:**
- Use administratively scoped addresses (239.x.x.x)
- Encrypt sensitive data
- Rate limit sending
- Validate received data

### Reliability

UDP multicast is unreliable:
- Packets may be lost
- No delivery guarantees
- No ordering guarantees
- Receivers may miss messages

For reliability, add:
- Sequence numbers
- Acknowledgments (via unicast)
- Retransmission logic
- Forward error correction

## See Also

- Recipe 20.1: Non-Blocking TCP Servers - Event-driven network programming
- Recipe 11.1: Making HTTP Requests - Unicast communication
- Recipe 20.6: Creating Raw Sockets - Lower-level network access

Full compilable example: `code/05-zig-paradigms/20-high-perf-networking/recipe_20_5.zig`
