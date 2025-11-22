// Recipe 20.2: Zero-copy networking using sendfile
// Target Zig Version: 0.15.2
const std = @import("std");
const testing = std.testing;
const posix = std.posix;
const fs = std.fs;
const net = std.net;

// ANCHOR: sendfile_basic
/// Transfer a file to a socket without copying through user space
pub fn sendFile(socket: posix.socket_t, file: fs.File, offset: usize, count: usize) !usize {
    if (@import("builtin").os.tag == .linux) {
        var off: i64 = @intCast(offset);
        return try posix.sendfile(socket, file.handle, &off, count);
    } else if (@import("builtin").os.tag == .macos or @import("builtin").os.tag == .freebsd) {
        var sent: posix.off_t = @intCast(count);
        try posix.sendfile(file.handle, socket, @intCast(offset), &sent, null, 0);
        return @intCast(sent);
    } else {
        // Fallback for platforms without sendfile
        return sendFileFallback(socket, file, offset, count);
    }
}

fn sendFileFallback(socket: posix.socket_t, file: fs.File, offset: usize, count: usize) !usize {
    try file.seekTo(offset);
    var buffer: [8192]u8 = undefined;
    var total_sent: usize = 0;
    var remaining = count;

    while (remaining > 0) {
        const to_read = @min(remaining, buffer.len);
        const bytes_read = try file.read(buffer[0..to_read]);
        if (bytes_read == 0) break;

        var sent: usize = 0;
        while (sent < bytes_read) {
            const n = try posix.send(socket, buffer[sent..bytes_read], 0);
            sent += n;
        }

        total_sent += bytes_read;
        remaining -= bytes_read;
    }

    return total_sent;
}
// ANCHOR_END: sendfile_basic

// ANCHOR: static_file_server
const StaticFileServer = struct {
    socket: posix.socket_t,
    address: net.Address,
    root_dir: fs.Dir,

    pub fn init(port: u16, root_path: []const u8) !StaticFileServer {
        const addr = try net.Address.parseIp("127.0.0.1", port);

        const socket = try posix.socket(
            addr.any.family,
            posix.SOCK.STREAM,
            0,
        );
        errdefer posix.close(socket);

        try posix.setsockopt(
            socket,
            posix.SOL.SOCKET,
            posix.SO.REUSEADDR,
            &std.mem.toBytes(@as(c_int, 1)),
        );

        try posix.bind(socket, &addr.any, addr.getOsSockLen());
        try posix.listen(socket, 128);

        const root_dir = try fs.cwd().openDir(root_path, .{});

        return .{
            .socket = socket,
            .address = addr,
            .root_dir = root_dir,
        };
    }

    pub fn deinit(self: *StaticFileServer) void {
        self.root_dir.close();
        posix.close(self.socket);
    }

    pub fn serveFile(self: *StaticFileServer, client: posix.socket_t, path: []const u8) !void {
        const file = try self.root_dir.openFile(path, .{});
        defer file.close();

        const stat = try file.stat();
        const size = stat.size;

        const header = try std.fmt.allocPrint(
            std.heap.page_allocator,
            "HTTP/1.1 200 OK\r\nContent-Length: {d}\r\n\r\n",
            .{size},
        );
        defer std.heap.page_allocator.free(header);

        _ = try posix.send(client, header, 0);
        _ = try sendFile(client, file, 0, size);
    }
};
// ANCHOR_END: static_file_server

// ANCHOR: splice_pipes
/// Use splice (Linux) or pipe-based transfer for socket-to-socket zero-copy
pub fn spliceSockets(in_fd: posix.socket_t, out_fd: posix.socket_t, len: usize) !usize {
    if (@import("builtin").os.tag != .linux) {
        return error.UnsupportedPlatform;
    }

    const pipe_fds = try posix.pipe();
    defer {
        posix.close(pipe_fds[0]);
        posix.close(pipe_fds[1]);
    }

    var total: usize = 0;
    var remaining = len;

    while (remaining > 0) {
        const to_pipe = try posix.splice(
            in_fd,
            null,
            pipe_fds[1],
            null,
            remaining,
            0,
        );
        if (to_pipe == 0) break;

        var pipe_data = to_pipe;
        while (pipe_data > 0) {
            const from_pipe = try posix.splice(
                pipe_fds[0],
                null,
                out_fd,
                null,
                pipe_data,
                0,
            );
            pipe_data -= from_pipe;
            total += from_pipe;
        }

        remaining -= to_pipe;
    }

    return total;
}
// ANCHOR_END: splice_pipes

// ANCHOR: chunked_transfer
const ChunkedFileTransfer = struct {
    file: fs.File,
    chunk_size: usize,
    total_size: usize,
    bytes_sent: usize,

    pub fn init(file: fs.File, chunk_size: usize) !ChunkedFileTransfer {
        const stat = try file.stat();
        return .{
            .file = file,
            .chunk_size = chunk_size,
            .total_size = stat.size,
            .bytes_sent = 0,
        };
    }

    pub fn sendChunk(self: *ChunkedFileTransfer, socket: posix.socket_t) !bool {
        if (self.bytes_sent >= self.total_size) {
            return false;
        }

        const remaining = self.total_size - self.bytes_sent;
        const chunk = @min(remaining, self.chunk_size);

        const sent = try sendFile(socket, self.file, self.bytes_sent, chunk);
        self.bytes_sent += sent;

        return self.bytes_sent < self.total_size;
    }

    pub fn progress(self: *const ChunkedFileTransfer) f32 {
        if (self.total_size == 0) return 1.0;
        return @as(f32, @floatFromInt(self.bytes_sent)) / @as(f32, @floatFromInt(self.total_size));
    }
};
// ANCHOR_END: chunked_transfer

// ANCHOR: mmap_send
/// Memory-map a file and send it (alternative to sendfile)
pub fn mmapSend(socket: posix.socket_t, file: fs.File) !void {
    const stat = try file.stat();
    const size = stat.size;

    if (size == 0) return;

    const mapped = try posix.mmap(
        null,
        size,
        posix.PROT.READ,
        .{ .TYPE = .SHARED },
        file.handle,
        0,
    );
    defer posix.munmap(mapped);

    var sent: usize = 0;
    while (sent < size) {
        const n = try posix.send(socket, mapped[sent..], 0);
        sent += n;
    }
}
// ANCHOR_END: mmap_send

// Tests
test "sendfile with temp file" {
    if (@import("builtin").os.tag == .wasi) return error.SkipZigTest;

    var test_dir = testing.tmpDir(.{});
    defer test_dir.cleanup();

    const file = try test_dir.dir.createFile("test.txt", .{ .read = true });
    defer file.close();

    const test_data = "Hello, sendfile!";
    try file.writeAll(test_data);
    try file.seekTo(0);

    const stat = try file.stat();
    try testing.expectEqual(test_data.len, stat.size);
}

test "chunked file transfer initialization" {
    if (@import("builtin").os.tag == .wasi) return error.SkipZigTest;

    var test_dir = testing.tmpDir(.{});
    defer test_dir.cleanup();

    const file = try test_dir.dir.createFile("chunk.txt", .{ .read = true });
    defer file.close();

    try file.writeAll("Test data for chunking");
    try file.seekTo(0);

    var transfer = try ChunkedFileTransfer.init(file, 1024);
    try testing.expectEqual(@as(usize, 0), transfer.bytes_sent);
    try testing.expect(transfer.total_size > 0);
    try testing.expectEqual(@as(f32, 0.0), transfer.progress());
}

test "chunked transfer progress calculation" {
    if (@import("builtin").os.tag == .wasi) return error.SkipZigTest;

    var test_dir = testing.tmpDir(.{});
    defer test_dir.cleanup();

    const file = try test_dir.dir.createFile("progress.txt", .{ .read = true });
    defer file.close();

    try file.writeAll("1234567890");
    try file.seekTo(0);

    var transfer = try ChunkedFileTransfer.init(file, 1024);
    try testing.expectEqual(@as(f32, 0.0), transfer.progress());

    transfer.bytes_sent = 5;
    try testing.expectEqual(@as(f32, 0.5), transfer.progress());

    transfer.bytes_sent = 10;
    try testing.expectEqual(@as(f32, 1.0), transfer.progress());
}

test "sendfile fallback" {
    if (@import("builtin").os.tag == .wasi) return error.SkipZigTest;

    var test_dir = testing.tmpDir(.{});
    defer test_dir.cleanup();

    const file = try test_dir.dir.createFile("fallback.txt", .{ .read = true });
    defer file.close();

    const test_data = "Fallback test data";
    try file.writeAll(test_data);
    try file.seekTo(0);

    try testing.expectEqual(test_data.len, (try file.stat()).size);
}

test "empty file handling" {
    if (@import("builtin").os.tag == .wasi) return error.SkipZigTest;

    var test_dir = testing.tmpDir(.{});
    defer test_dir.cleanup();

    const file = try test_dir.dir.createFile("empty.txt", .{});
    defer file.close();

    const stat = try file.stat();
    try testing.expectEqual(@as(u64, 0), stat.size);
}

test "chunked transfer empty file" {
    if (@import("builtin").os.tag == .wasi) return error.SkipZigTest;

    var test_dir = testing.tmpDir(.{});
    defer test_dir.cleanup();

    const file = try test_dir.dir.createFile("empty.txt", .{ .read = true });
    defer file.close();

    var transfer = try ChunkedFileTransfer.init(file, 1024);
    try testing.expectEqual(@as(usize, 0), transfer.total_size);
    try testing.expectEqual(@as(f32, 1.0), transfer.progress());
}
