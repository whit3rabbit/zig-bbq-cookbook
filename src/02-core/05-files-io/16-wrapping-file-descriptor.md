## Problem

You have a raw file descriptor from C code, a network socket, or system call, and want to use it with Zig's file operations.

## Solution

### Wrap File Descriptor

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_16.zig:wrap_fd}}
```

### IPC Descriptors

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_16.zig:ipc_descriptors}}
```

### Ownership Tracking

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_16.zig:ownership_tracking}}
```

## Discussion

### Understanding File Descriptors

File descriptors are small integers representing open files:

```zig
pub fn getFd(file: std.fs.File) std.posix.fd_t {
    return file.handle;
}

pub fn isValidFd(fd: std.posix.fd_t) bool {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return fd != std.os.windows.INVALID_HANDLE_VALUE;
    } else {
        return fd >= 0;
    }
}

test "check file descriptor validity" {
    const file = try std.fs.cwd().createFile("/tmp/test_fd.txt", .{});
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/test_fd.txt") catch {};

    const fd = getFd(file);
    try std.testing.expect(isValidFd(fd));
}
```

### Standard File Descriptors

Wrap stdin, stdout, stderr:

```zig
pub fn getStdin() std.fs.File {
    return std.io.getStdIn();
}

pub fn getStdout() std.fs.File {
    return std.io.getStdOut();
}

pub fn getStderr() std.fs.File {
    return std.io.getStdErr();
}

pub fn wrapStdFd(fd_num: u8) !std.fs.File {
    return switch (fd_num) {
        0 => getStdin(),
        1 => getStdout(),
        2 => getStderr(),
        else => error.InvalidStdFd,
    };
}

test "wrap standard file descriptors" {
    const stdin = getStdin();
    const stdout = getStdout();
    const stderr = getStderr();

    // Verify they're valid
    try std.testing.expect(isValidFd(stdin.handle));
    try std.testing.expect(isValidFd(stdout.handle));
    try std.testing.expect(isValidFd(stderr.handle));
}
```

### Duplicating File Descriptors

Create independent copies:

```zig
pub fn duplicateFd(file: std.fs.File) !std.fs.File {
    const new_fd = try std.posix.dup(file.handle);
    return std.fs.File{ .handle = new_fd };
}

test "duplicate file descriptor" {
    const file = try std.fs.cwd().createFile("/tmp/test_dup.txt", .{});
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/test_dup.txt") catch {};

    // Write to original
    try file.writeAll("Original");

    // Duplicate
    const dup = try duplicateFd(file);
    defer dup.close();

    // Write to duplicate
    try dup.writeAll(" Duplicate");

    // Both refer to same file
    try file.seekTo(0);
    var buffer: [100]u8 = undefined;
    const n = try file.read(&buffer);

    try std.testing.expect(std.mem.indexOf(u8, buffer[0..n], "Original Duplicate") != null);
}
```

### Setting File Descriptor Flags

Control FD behavior:

```zig
pub fn setNonBlocking(file: std.fs.File) !void {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        // Windows non-blocking I/O is different
        return error.NotSupported;
    }

    const flags = try std.posix.fcntl(file.handle, std.posix.F.GETFL, 0);
    _ = try std.posix.fcntl(file.handle, std.posix.F.SETFL, flags | @as(u32, std.posix.O.NONBLOCK));
}

pub fn setCloseOnExec(file: std.fs.File) !void {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return error.NotSupported;
    }

    const flags = try std.posix.fcntl(file.handle, std.posix.F.GETFD, 0);
    _ = try std.posix.fcntl(file.handle, std.posix.F.SETFD, flags | @as(u32, std.posix.FD_CLOEXEC));
}
```

### From Network Socket

Wrap socket as file:

```zig
pub fn wrapSocket(socket: std.posix.socket_t) std.fs.File {
    return std.fs.File{ .handle = socket };
}

pub fn createSocketPair() ![2]std.fs.File {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return error.NotSupported;
    }

    var fds: [2]std.posix.fd_t = undefined;
    try std.posix.socketpair(
        std.posix.AF.UNIX,
        std.posix.SOCK.STREAM,
        0,
        &fds,
    );

    return [2]std.fs.File{
        std.fs.File{ .handle = fds[0] },
        std.fs.File{ .handle = fds[1] },
    };
}

test "socket pair" {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    const pair = try createSocketPair();
    defer pair[0].close();
    defer pair[1].close();

    // Write to one end
    try pair[0].writeAll("Hello");

    // Read from other end
    var buffer: [10]u8 = undefined;
    const n = try pair[1].read(&buffer);

    try std.testing.expectEqualStrings("Hello", buffer[0..n]);
}
```

### From Pipe

Wrap pipe file descriptors:

```zig
pub fn createPipe() ![2]std.fs.File {
    var fds: [2]std.posix.fd_t = undefined;
    try std.posix.pipe(&fds);

    return [2]std.fs.File{
        std.fs.File{ .handle = fds[0] }, // Read end
        std.fs.File{ .handle = fds[1] }, // Write end
    };
}

test "pipe communication" {
    const pipe = try createPipe();
    defer pipe[0].close();
    defer pipe[1].close();

    // Write to pipe
    try pipe[1].writeAll("Pipe data");

    // Read from pipe
    var buffer: [20]u8 = undefined;
    const n = try pipe[0].read(&buffer);

    try std.testing.expectEqualStrings("Pipe data", buffer[0..n]);
}
```

### From C Code

Interop with C file descriptors:

```zig
pub fn fromCInt(c_fd: c_int) std.fs.File {
    const builtin = @import("builtin");
    const fd: std.posix.fd_t = if (builtin.os.tag == .windows)
        @ptrFromInt(@as(usize, @intCast(c_fd)))
    else
        c_fd;

    return std.fs.File{ .handle = fd };
}

pub fn toCInt(file: std.fs.File) c_int {
    const builtin = @import("builtin");
    return if (builtin.os.tag == .windows)
        @intCast(@intFromPtr(file.handle))
    else
        file.handle;
}
```

### Ownership and Closing

Control when FD is closed:

```zig
pub const OwnedFile = struct {
    file: std.fs.File,
    owned: bool,

    pub fn init(fd: std.posix.fd_t, owned: bool) OwnedFile {
        return .{
            .file = std.fs.File{ .handle = fd },
            .owned = owned,
        };
    }

    pub fn deinit(self: *OwnedFile) void {
        if (self.owned) {
            self.file.close();
        }
    }

    pub fn writer(self: *OwnedFile) std.fs.File.Writer {
        return self.file.writer();
    }

    pub fn reader(self: *OwnedFile) std.fs.File.Reader {
        return self.file.reader();
    }
};

test "owned file" {
    const file = try std.fs.cwd().createFile("/tmp/test_owned.txt", .{});
    defer std.fs.cwd().deleteFile("/tmp/test_owned.txt") catch {};

    const fd = file.handle;

    // Transfer ownership
    var owned = OwnedFile.init(fd, true);
    defer owned.deinit(); // This will close the fd

    try owned.writer().writeAll("Owned file");

    // Original file is closed by owned.deinit()
}
```

### Temporary File from FD

Create temp file from descriptor:

```zig
pub fn makeTempFromFd(fd: std.posix.fd_t) std.fs.File {
    return std.fs.File{ .handle = fd };
}

pub fn createAnonymousFile() !std.fs.File {
    const builtin = @import("builtin");
    if (builtin.os.tag == .linux) {
        // Use memfd_create on Linux
        const name = "anonymous";
        const fd = try std.posix.memfd_create(name, 0);
        return std.fs.File{ .handle = fd };
    } else {
        // Fall back to regular temp file
        const file = try std.fs.cwd().createFile("/tmp/anon_temp", .{
            .read = true,
            .truncate = true,
        });
        try std.fs.cwd().deleteFile("/tmp/anon_temp");
        return file;
    }
}

test "anonymous file" {
    const file = try createAnonymousFile();
    defer file.close();

    try file.writeAll("Anonymous data");

    try file.seekTo(0);
    var buffer: [20]u8 = undefined;
    const n = try file.read(&buffer);

    try std.testing.expectEqualStrings("Anonymous data", buffer[0..n]);
}
```

### Error Handling

Safe wrapping with validation:

```zig
pub fn safeWrapFd(fd: std.posix.fd_t) !std.fs.File {
    if (!isValidFd(fd)) {
        return error.InvalidFileDescriptor;
    }

    // Verify it's actually open
    _ = std.posix.fcntl(fd, std.posix.F.GETFL, 0) catch {
        return error.ClosedFileDescriptor;
    };

    return std.fs.File{ .handle = fd };
}

test "safe wrap - invalid fd" {
    const result = safeWrapFd(-1);
    try std.testing.expectError(error.InvalidFileDescriptor, result);
}
```

### Redirecting Standard Streams

Replace stdin/stdout/stderr:

```zig
pub fn redirectStdout(target_file: std.fs.File) !void {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return error.NotSupported;
    }

    try std.posix.dup2(target_file.handle, std.posix.STDOUT_FILENO);
}

pub fn redirectStderr(target_file: std.fs.File) !void {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return error.NotSupported;
    }

    try std.posix.dup2(target_file.handle, std.posix.STDERR_FILENO);
}
```

### Buffered I/O

Wrap with buffering:

```zig
pub fn createBufferedFile(fd: std.posix.fd_t, allocator: std.mem.Allocator) !std.io.BufferedWriter(4096, std.fs.File.Writer) {
    const file = std.fs.File{ .handle = fd };
    return std.io.bufferedWriter(file.writer());
}
```

### Platform Differences

**Unix/Linux:**
- File descriptors are small integers (0, 1, 2, ...)
- `fcntl()` for flags and properties
- Pipes, sockets work naturally
- `dup()`, `dup2()` for duplication

**Windows:**
- HANDLEs instead of integers
- Different API (`GetHandleInformation`, etc.)
- Socket handles separate from file handles

**Cross-platform wrapper:**
```zig
pub fn wrapFdCrossPlatform(fd: std.posix.fd_t) !std.fs.File {
    const builtin = @import("builtin");

    if (builtin.os.tag == .windows) {
        // Windows-specific validation
        if (fd == std.os.windows.INVALID_HANDLE_VALUE) {
            return error.InvalidHandle;
        }
    } else {
        // Unix-like validation
        if (fd < 0) {
            return error.InvalidFileDescriptor;
        }
    }

    return std.fs.File{ .handle = fd };
}
```

### Best Practices

**Ownership:**
- Always clarify who owns the FD
- Use `defer file.close()` for owned FDs
- Don't close FDs you don't own

**Error handling:**
```zig
pub fn wrapAndUse(fd: std.posix.fd_t) !void {
    const file = try safeWrapFd(fd);
    // Don't close - we don't own it

    try file.writeAll("Data");
}
```

**Validation:**
- Check validity before wrapping
- Verify FD is open
- Handle platform differences

### Related Functions

- `std.fs.File{ .handle = fd }` - Wrap file descriptor
- `std.posix.dup()` - Duplicate file descriptor
- `std.posix.dup2()` - Duplicate to specific FD number
- `std.posix.fcntl()` - File control operations
- `std.posix.pipe()` - Create pipe
- `std.posix.socketpair()` - Create socket pair
- `std.io.getStdIn()` - Get stdin file
- `std.io.getStdOut()` - Get stdout file
- `std.io.getStdErr()` - Get stderr file
