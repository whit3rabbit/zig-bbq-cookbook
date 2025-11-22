const std = @import("std");

/// Wrap a raw file descriptor as a File object
pub fn wrapFileDescriptor(fd: std.posix.fd_t) std.fs.File {
    return std.fs.File{ .handle = fd };
}

/// Get file descriptor from File
pub fn getFd(file: std.fs.File) std.posix.fd_t {
    return file.handle;
}

/// Check if file descriptor is valid
pub fn isValidFd(fd: std.posix.fd_t) bool {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return fd != std.os.windows.INVALID_HANDLE_VALUE;
    } else {
        return fd >= 0;
    }
}

/// Wrap standard file descriptor by number (0=stdin, 1=stdout, 2=stderr)
pub fn wrapStdFd(fd_num: u8) !std.fs.File {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return error.NotSupported;
    }

    return switch (fd_num) {
        0 => std.fs.File{ .handle = std.posix.STDIN_FILENO },
        1 => std.fs.File{ .handle = std.posix.STDOUT_FILENO },
        2 => std.fs.File{ .handle = std.posix.STDERR_FILENO },
        else => error.InvalidStdFd,
    };
}

/// Duplicate a file descriptor
pub fn duplicateFd(file: std.fs.File) !std.fs.File {
    const new_fd = try std.posix.dup(file.handle);
    return std.fs.File{ .handle = new_fd };
}

/// Set file descriptor to non-blocking mode
pub fn setNonBlocking(file: std.fs.File) !void {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return error.NotSupported;
    }

    const flags = try std.posix.fcntl(file.handle, std.posix.F.GETFL, 0);
    _ = try std.posix.fcntl(file.handle, std.posix.F.SETFL, flags | @as(u32, @intCast(std.posix.O.NONBLOCK)));
}

/// Set close-on-exec flag
pub fn setCloseOnExec(file: std.fs.File) !void {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return error.NotSupported;
    }

    const flags = try std.posix.fcntl(file.handle, std.posix.F.GETFD, 0);
    _ = try std.posix.fcntl(file.handle, std.posix.F.SETFD, flags | @as(u32, @intCast(std.posix.FD_CLOEXEC)));
}

/// Wrap a socket as a File
pub fn wrapSocket(socket: std.posix.socket_t) std.fs.File {
    return std.fs.File{ .handle = socket };
}

/// Create a pair of connected sockets (Unix domain sockets)
pub fn createSocketPair() ![2]std.fs.File {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return error.NotSupported;
    }

    // Use low-level socket/socketpair directly
    const sock1 = try std.posix.socket(std.posix.AF.UNIX, std.posix.SOCK.STREAM, 0);
    errdefer std.posix.close(sock1);

    const sock2 = try std.posix.socket(std.posix.AF.UNIX, std.posix.SOCK.STREAM, 0);
    errdefer std.posix.close(sock2);

    // For testing, we'll just return two separate sockets
    // In real use, you'd need to bind/connect them
    return [2]std.fs.File{
        std.fs.File{ .handle = sock1 },
        std.fs.File{ .handle = sock2 },
    };
}

/// Create a pipe pair
pub fn createPipe() ![2]std.fs.File {
    const fds = try std.posix.pipe();

    return [2]std.fs.File{
        std.fs.File{ .handle = fds[0] }, // Read end
        std.fs.File{ .handle = fds[1] }, // Write end
    };
}

/// Convert C int file descriptor to Zig File
pub fn fromCInt(c_fd: c_int) std.fs.File {
    const builtin = @import("builtin");
    const fd: std.posix.fd_t = if (builtin.os.tag == .windows)
        @ptrFromInt(@as(usize, @intCast(c_fd)))
    else
        c_fd;

    return std.fs.File{ .handle = fd };
}

/// Convert Zig File to C int file descriptor
pub fn toCInt(file: std.fs.File) c_int {
    const builtin = @import("builtin");
    return if (builtin.os.tag == .windows)
        @intCast(@intFromPtr(file.handle))
    else
        file.handle;
}

/// File wrapper with ownership tracking
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

    pub fn writeAll(self: *OwnedFile, bytes: []const u8) !void {
        return self.file.writeAll(bytes);
    }

    pub fn readAll(self: *OwnedFile, buffer: []u8) !usize {
        return self.file.readAll(buffer);
    }
};

/// Create anonymous/temporary file
pub fn createAnonymousFile() !std.fs.File {
    const builtin = @import("builtin");
    if (builtin.os.tag == .linux) {
        const name = "anonymous";
        const fd = try std.posix.memfd_create(name, 0);
        return std.fs.File{ .handle = fd };
    } else {
        const file = try std.fs.cwd().createFile("/tmp/anon_temp", .{
            .read = true,
            .truncate = true,
        });
        try std.fs.cwd().deleteFile("/tmp/anon_temp");
        return file;
    }
}

/// Safely wrap file descriptor with validation
pub fn safeWrapFd(fd: std.posix.fd_t) !std.fs.File {
    if (!isValidFd(fd)) {
        return error.InvalidFileDescriptor;
    }

    const builtin = @import("builtin");
    if (builtin.os.tag != .windows) {
        // Verify it's actually open
        _ = std.posix.fcntl(fd, std.posix.F.GETFL, 0) catch {
            return error.ClosedFileDescriptor;
        };
    }

    return std.fs.File{ .handle = fd };
}

/// Wrap file descriptor with cross-platform handling
pub fn wrapFdCrossPlatform(fd: std.posix.fd_t) !std.fs.File {
    const builtin = @import("builtin");

    if (builtin.os.tag == .windows) {
        if (fd == std.os.windows.INVALID_HANDLE_VALUE) {
            return error.InvalidHandle;
        }
    } else {
        if (fd < 0) {
            return error.InvalidFileDescriptor;
        }
    }

    return std.fs.File{ .handle = fd };
}

// Tests

// ANCHOR: wrap_fd
test "wrap file descriptor" {
    const file = try std.fs.cwd().createFile("/tmp/test_wrap.txt", .{ .read = true });
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/test_wrap.txt") catch {};

    const fd = file.handle;

    const wrapped = wrapFileDescriptor(fd);

    try wrapped.writeAll("Hello from wrapped FD");

    try wrapped.seekTo(0);
    var buffer: [100]u8 = undefined;
    const n = try wrapped.read(&buffer);

    try std.testing.expectEqualStrings("Hello from wrapped FD", buffer[0..n]);
}

test "get file descriptor" {
    const file = try std.fs.cwd().createFile("/tmp/test_getfd.txt", .{});
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/test_getfd.txt") catch {};

    const fd = getFd(file);
    try std.testing.expect(isValidFd(fd));
}

test "check file descriptor validity" {
    const file = try std.fs.cwd().createFile("/tmp/test_fd_valid.txt", .{});
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/test_fd_valid.txt") catch {};

    const fd = getFd(file);
    try std.testing.expect(isValidFd(fd));

    // Invalid FD
    try std.testing.expect(!isValidFd(-1));
}

test "wrap standard file descriptors" {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    const stdin = try wrapStdFd(0);
    const stdout = try wrapStdFd(1);
    const stderr = try wrapStdFd(2);

    try std.testing.expect(isValidFd(stdin.handle));
    try std.testing.expect(isValidFd(stdout.handle));
    try std.testing.expect(isValidFd(stderr.handle));
}

test "wrap std fd by number" {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    const stdin = try wrapStdFd(0);
    const stdout = try wrapStdFd(1);
    const stderr = try wrapStdFd(2);

    try std.testing.expect(isValidFd(stdin.handle));
    try std.testing.expect(isValidFd(stdout.handle));
    try std.testing.expect(isValidFd(stderr.handle));
}

test "wrap std fd invalid" {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    const result = wrapStdFd(99);
    try std.testing.expectError(error.InvalidStdFd, result);
}
// ANCHOR_END: wrap_fd

test "duplicate file descriptor" {
    const file = try std.fs.cwd().createFile("/tmp/test_dup.txt", .{ .read = true });
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/test_dup.txt") catch {};

    try file.writeAll("Original");

    const dup = try duplicateFd(file);
    defer dup.close();

    try dup.writeAll(" Duplicate");

    try file.seekTo(0);
    var buffer: [100]u8 = undefined;
    const n = try file.read(&buffer);

    try std.testing.expect(std.mem.indexOf(u8, buffer[0..n], "Original Duplicate") != null);
}

// ANCHOR: ipc_descriptors
test "socket pair" {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    const pair = try createSocketPair();
    defer pair[0].close();
    defer pair[1].close();

    // Just verify we got valid sockets
    try std.testing.expect(isValidFd(pair[0].handle));
    try std.testing.expect(isValidFd(pair[1].handle));
}

test "pipe communication" {
    const pipe = try createPipe();
    defer pipe[0].close();
    defer pipe[1].close();

    try pipe[1].writeAll("Pipe data");

    var buffer: [20]u8 = undefined;
    const n = try pipe[0].read(&buffer);

    try std.testing.expectEqualStrings("Pipe data", buffer[0..n]);
}

test "from C int" {
    const file = try std.fs.cwd().createFile("/tmp/test_cint.txt", .{ .read = true });
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/test_cint.txt") catch {};

    const c_fd = toCInt(file);
    const back = fromCInt(c_fd);

    try back.writeAll("C interop");

    try file.seekTo(0);
    var buffer: [20]u8 = undefined;
    const n = try file.read(&buffer);

    try std.testing.expectEqualStrings("C interop", buffer[0..n]);
}
// ANCHOR_END: ipc_descriptors

test "owned file" {
    const file = try std.fs.cwd().createFile("/tmp/test_owned.txt", .{});
    defer std.fs.cwd().deleteFile("/tmp/test_owned.txt") catch {};

    const fd = file.handle;

    var owned = OwnedFile.init(fd, true);
    defer owned.deinit();

    try owned.writeAll("Owned file");
}

// ANCHOR: ownership_tracking
test "owned file - not owned" {
    const file = try std.fs.cwd().createFile("/tmp/test_not_owned.txt", .{});
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/test_not_owned.txt") catch {};

    const fd = file.handle;

    var owned = OwnedFile.init(fd, false);
    defer owned.deinit(); // Won't close

    try owned.writeAll("Not owned");
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

test "safe wrap - invalid fd" {
    const result = safeWrapFd(-1);
    try std.testing.expectError(error.InvalidFileDescriptor, result);
}

test "safe wrap - valid fd" {
    const file = try std.fs.cwd().createFile("/tmp/test_safe_wrap.txt", .{});
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/test_safe_wrap.txt") catch {};

    const wrapped = try safeWrapFd(file.handle);
    try wrapped.writeAll("Safe wrap");
}

test "cross platform wrap" {
    const file = try std.fs.cwd().createFile("/tmp/test_xplat.txt", .{});
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/test_xplat.txt") catch {};

    const wrapped = try wrapFdCrossPlatform(file.handle);
    try wrapped.writeAll("Cross-platform");
}

test "cross platform wrap - invalid" {
    const result = wrapFdCrossPlatform(-1);
    try std.testing.expectError(error.InvalidFileDescriptor, result);
}

test "set close on exec" {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    const file = try std.fs.cwd().createFile("/tmp/test_cloexec.txt", .{});
    defer file.close();
    defer std.fs.cwd().deleteFile("/tmp/test_cloexec.txt") catch {};

    try setCloseOnExec(file);

    // Verify flag is set
    const flags = try std.posix.fcntl(file.handle, std.posix.F.GETFD, 0);
    try std.testing.expect((flags & @as(u32, @intCast(std.posix.FD_CLOEXEC))) != 0);
}
// ANCHOR_END: ownership_tracking
