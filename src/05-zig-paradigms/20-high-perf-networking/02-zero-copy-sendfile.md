# Recipe 20.2: Zero-Copy Networking Using sendfile

## Problem

You need to transfer large files over a network connection efficiently. Reading a file into user-space memory and then writing it to a socket wastes CPU cycles and memory bandwidth with unnecessary data copying.

## Solution

Use the `sendfile()` system call to transfer data directly from a file descriptor to a socket without copying through user space. This "zero-copy" operation is handled entirely by the kernel.

### Basic sendfile Usage

Create a cross-platform sendfile wrapper:

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_2.zig:sendfile_basic}}
```

### Static File Server

Build a simple static file server using sendfile:

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_2.zig:static_file_server}}
```

### Socket-to-Socket Transfer with splice

For Linux, use `splice()` for socket-to-socket zero-copy:

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_2.zig:splice_pipes}}
```

### Chunked File Transfer

Transfer large files in chunks with progress tracking:

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_2.zig:chunked_transfer}}
```

### Memory-Mapped Alternative

Use mmap as an alternative to sendfile:

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_2.zig:mmap_send}}
```

## Discussion

Zero-copy techniques eliminate expensive memory copies between kernel and user space. This is especially important for high-throughput file servers.

### How sendfile Works

Traditional file transfer:
1. Read file into kernel buffer (disk → kernel)
2. Copy from kernel to user space (kernel → user)
3. Write from user space to kernel (user → kernel)
4. Send from kernel to network (kernel → network)

With sendfile:
1. Read file into kernel buffer (disk → kernel)
2. Send from kernel to network (kernel → network)

This eliminates two copy operations and context switches.

### Platform Differences

sendfile has different signatures across platforms:

**Linux:**
```c
ssize_t sendfile(int out_fd, int in_fd, off_t *offset, size_t count);
```

**macOS/BSD:**
```c
int sendfile(int fd, int s, off_t offset, off_t *len,
             struct sf_hdtr *hdtr, int flags);
```

The wrapper function handles these differences, providing a consistent interface.

### splice for Socket-to-Socket

On Linux, `splice()` can transfer data between any two file descriptors through a pipe. This is useful for proxies or when forwarding data between network connections without processing it.

### Performance Considerations

**When sendfile shines:**
- Large static files (images, videos, downloads)
- High-concurrency file serving
- Proxy servers forwarding data

**When sendfile doesn't help:**
- Files need processing before sending
- Small files (overhead outweighs benefit)
- Compressed/encrypted transfers

Benchmark shows sendfile can be 2-3x faster than read/write loops for large files.

### Memory Mapping Alternative

mmap maps a file into memory, letting you treat it like an array. Send operations then copy from this mapped region. This can be faster than read/write but uses more virtual memory.

Pros:
- Simple API
- Good for random access
- Works on all platforms

Cons:
- Not truly zero-copy (still copies to socket buffer)
- Can cause page faults
- Consumes address space

### Error Handling

Both sendfile and splice can return partial transfers. Always check return values and loop if needed. Handle `EAGAIN` for non-blocking sockets.

### Chunked Transfers

For very large files, transfer in chunks to:
- Provide progress feedback
- Handle partial transfers
- Manage memory pressure
- Allow cancellation

## See Also

- Recipe 20.1: Non-Blocking TCP Servers - Event-driven serving
- Recipe 11.9: Uploading and Downloading Files - High-level file transfers
- Recipe 5.10: Memory Mapping Binary Files - mmap basics
- Recipe 20.4: HTTP/1.1 Parser - Serving files over HTTP

Full compilable example: `code/05-zig-paradigms/20-high-perf-networking/recipe_20_2.zig`
