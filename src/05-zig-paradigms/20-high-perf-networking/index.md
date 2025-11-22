# Chapter 20: High-Performance & Low-Level Networking

Build high-performance network applications with Zig's safe low-level access.

## Topics

- Implementing non-blocking TCP servers with `std.os.poll` (or `epoll`/`kqueue`)
- Zero-copy networking using `sendfile` via Zig syscall wrappers
- Parsing raw packets (using `packed struct` for network protocols)
- Implementing a basic HTTP/1.1 parser from scratch (using `std.mem` state machines)
- Using UDP multicast
- Creating raw sockets (reading raw ethernet frames)

See TODO.md for complete recipe list (6 recipes planned).
