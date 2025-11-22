# Recipe 20.1: Non-Blocking TCP Servers with Poll

## Problem

You need to build a TCP server that can handle many concurrent connections without dedicating a thread to each client. Traditional blocking I/O creates scalability problems when dealing with simultaneous connections.

## Solution

Use Zig's `std.posix` module to create non-blocking sockets and poll for events across multiple file descriptors. The `poll()` system call monitors many sockets from a single thread, providing a portable foundation for event-driven servers.

### Basic Non-Blocking Server

First, create a non-blocking server socket:

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_1.zig:basic_nonblocking}}
```

The key is the `posix.SOCK.NONBLOCK` flag when creating the socket. This prevents `accept()`, `recv()`, and `send()` from blocking.

### Poll-Based Event Loop

Build a simple event loop using poll:

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_1.zig:poll_based_server}}
```

### Stateful Connections

For more complex protocols, track connection state:

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_1.zig:connection_state}}
```

Integrate with a stateful server:

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_1.zig:stateful_server}}
```

## Discussion

Non-blocking I/O is the foundation of high-performance servers. Instead of dedicating a thread per connection (which limits you to thousands of connections), you use a single thread to monitor many sockets.

### How Poll Works

The `poll()` system call takes an array of file descriptors and event masks, then blocks until one or more descriptors is ready for I/O. This is much more efficient than checking each socket individually.

**Scalability note:** `poll()` has O(n) complexity - the kernel scans all file descriptors on each call. This is fine for hundreds of connections but becomes a bottleneck with thousands. For extreme scale:
- **Linux**: Use `epoll` directly (O(1) event notification)
- **macOS/BSD**: Use `kqueue` directly (O(1) event notification)
- **Windows**: Use IOCP

This recipe uses `poll()` because it's portable and simpler to understand. The patterns (non-blocking I/O, event loops, state machines) transfer directly to epoll/kqueue when you need more performance.

### Event-Driven Architecture

The pattern follows this flow:

1. **Accept**: Listen socket becomes readable when clients connect
2. **Read**: Client socket becomes readable when data arrives
3. **Write**: Client socket becomes writable when you can send data
4. **Close**: Handle errors or client disconnections

### Error Handling

Non-blocking calls return `error.WouldBlock` when they would have blocked. This is not an error - it means "try again later." Always catch this specifically:

```zig
const bytes = posix.recv(socket, buffer, 0) catch |err| switch (err) {
    error.WouldBlock => return true,  // Not ready yet
    else => return false,             // Real error
};
```

### Performance Characteristics

**Advantages:**
- Handle thousands of connections with one thread
- Low memory overhead per connection
- Excellent CPU efficiency
- Predictable latency

**Trade-offs:**
- More complex code than blocking I/O
- Need careful state management
- Can't use traditional read/write patterns

### Platform Differences

Zig's `std.posix` provides portable socket operations:
- `posix.SOCK.NONBLOCK` works on POSIX systems
- `poll()` is available on all POSIX platforms
- Socket options use consistent naming

Note: Windows support requires different APIs (`WSAPoll` or `select`). For cross-platform servers, consider using a library or adding platform-specific code paths.

### Memory Management

Use an allocator for dynamic arrays of connections. The testing allocator helps catch leaks during development. The unmanaged ArrayList pattern (`.append(allocator, item)`) makes allocator usage explicit.

## See Also

- Recipe 11.4: Building a Simple HTTP Server - Higher-level HTTP handling
- Recipe 12.1: Basic Threading and Thread Management - Thread pools for parallel work
- Recipe 20.2: Zero-Copy Networking Using sendfile - Efficient file transfers
- Recipe 20.4: Implementing a Basic HTTP/1.1 Parser - Protocol parsing

Full compilable example: `code/05-zig-paradigms/20-high-perf-networking/recipe_20_1.zig`
