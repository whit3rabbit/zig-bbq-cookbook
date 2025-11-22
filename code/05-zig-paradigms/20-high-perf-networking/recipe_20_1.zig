// Recipe 20.1: Implementing non-blocking TCP servers with epoll/kqueue
// Target Zig Version: 0.15.2
const std = @import("std");
const testing = std.testing;
const posix = std.posix;
const net = std.net;

// ANCHOR: basic_nonblocking
const NonBlockingServer = struct {
    socket: posix.socket_t,
    address: net.Address,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, port: u16) !NonBlockingServer {
        const addr = try net.Address.parseIp("127.0.0.1", port);

        const socket = try posix.socket(
            addr.any.family,
            posix.SOCK.STREAM | posix.SOCK.NONBLOCK,
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

        return .{
            .socket = socket,
            .address = addr,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *NonBlockingServer) void {
        posix.close(self.socket);
    }
};
// ANCHOR_END: basic_nonblocking

// ANCHOR: poll_based_server
const PollServer = struct {
    server: NonBlockingServer,
    clients: std.ArrayList(posix.socket_t),
    poll_fds: std.ArrayList(posix.pollfd),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, port: u16) !PollServer {
        const server = try NonBlockingServer.init(allocator, port);
        var poll_fds = std.ArrayList(posix.pollfd){};

        try poll_fds.append(allocator, .{
            .fd = server.socket,
            .events = posix.POLL.IN,
            .revents = 0,
        });

        return .{
            .server = server,
            .clients = std.ArrayList(posix.socket_t){},
            .poll_fds = poll_fds,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *PollServer) void {
        for (self.clients.items) |client| {
            posix.close(client);
        }
        self.clients.deinit(self.allocator);
        self.poll_fds.deinit(self.allocator);
        self.server.deinit();
    }

    pub fn acceptClient(self: *PollServer) !void {
        var client_addr: net.Address = undefined;
        var addr_len: posix.socklen_t = @sizeOf(net.Address);

        const client = posix.accept(
            self.server.socket,
            &client_addr.any,
            &addr_len,
            posix.SOCK.NONBLOCK,
        ) catch |err| switch (err) {
            error.WouldBlock => return,
            else => return err,
        };

        try self.clients.append(self.allocator, client);
        try self.poll_fds.append(self.allocator, .{
            .fd = client,
            .events = posix.POLL.IN,
            .revents = 0,
        });
    }

    pub fn handleClient(self: *PollServer, index: usize) !bool {
        const client = self.clients.items[index];
        var buffer: [1024]u8 = undefined;

        const bytes_read = posix.recv(client, &buffer, 0) catch |err| switch (err) {
            error.WouldBlock => return true,
            else => return false,
        };

        if (bytes_read == 0) {
            return false;
        }

        // Note: This simple example ignores partial writes for brevity.
        // In production, send() may return fewer bytes than requested.
        // See StatefulServer.Connection.handleWrite for proper handling.
        _ = posix.send(client, buffer[0..bytes_read], 0) catch {
            return false;
        };

        return true;
    }

    pub fn removeClient(self: *PollServer, index: usize) void {
        const client = self.clients.orderedRemove(index);
        posix.close(client);
        _ = self.poll_fds.orderedRemove(index + 1);
    }

    pub fn run(self: *PollServer, iterations: usize) !void {
        var count: usize = 0;
        while (count < iterations) : (count += 1) {
            const ready = try posix.poll(self.poll_fds.items, 100);
            if (ready == 0) continue;

            if (self.poll_fds.items[0].revents & posix.POLL.IN != 0) {
                try self.acceptClient();
            }

            var i: usize = self.clients.items.len;
            while (i > 0) {
                i -= 1;
                if (self.poll_fds.items[i + 1].revents & posix.POLL.IN != 0) {
                    if (!try self.handleClient(i)) {
                        self.removeClient(i);
                    }
                }
            }
        }
    }
};
// ANCHOR_END: poll_based_server

// ANCHOR: connection_state
const ConnectionState = enum {
    reading,
    writing,
    closing,
};

const Connection = struct {
    socket: posix.socket_t,
    state: ConnectionState,
    buffer: [4096]u8,
    bytes_read: usize,
    bytes_written: usize,

    pub fn init(socket: posix.socket_t) Connection {
        return .{
            .socket = socket,
            .state = .reading,
            .buffer = undefined,
            .bytes_read = 0,
            .bytes_written = 0,
        };
    }

    pub fn handleRead(self: *Connection) !bool {
        const bytes = posix.recv(
            self.socket,
            self.buffer[self.bytes_read..],
            0,
        ) catch |err| switch (err) {
            error.WouldBlock => return true,
            else => return false,
        };

        if (bytes == 0) return false;

        self.bytes_read += bytes;
        if (self.bytes_read >= self.buffer.len or
            std.mem.indexOf(u8, self.buffer[0..self.bytes_read], "\n") != null) {
            self.state = .writing;
        }

        return true;
    }

    pub fn handleWrite(self: *Connection) !bool {
        const bytes = posix.send(
            self.socket,
            self.buffer[self.bytes_written..self.bytes_read],
            0,
        ) catch |err| switch (err) {
            error.WouldBlock => return true,
            else => return false,
        };

        self.bytes_written += bytes;
        if (self.bytes_written >= self.bytes_read) {
            self.state = .closing;
        }

        return true;
    }
};
// ANCHOR_END: connection_state

// ANCHOR: stateful_server
const StatefulServer = struct {
    server: NonBlockingServer,
    connections: std.ArrayList(Connection),
    poll_fds: std.ArrayList(posix.pollfd),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, port: u16) !StatefulServer {
        const server = try NonBlockingServer.init(allocator, port);
        var poll_fds = std.ArrayList(posix.pollfd){};

        try poll_fds.append(allocator, .{
            .fd = server.socket,
            .events = posix.POLL.IN,
            .revents = 0,
        });

        return .{
            .server = server,
            .connections = std.ArrayList(Connection){},
            .poll_fds = poll_fds,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *StatefulServer) void {
        for (self.connections.items) |conn| {
            posix.close(conn.socket);
        }
        self.connections.deinit(self.allocator);
        self.poll_fds.deinit(self.allocator);
        self.server.deinit();
    }

    pub fn acceptConnection(self: *StatefulServer) !void {
        var client_addr: net.Address = undefined;
        var addr_len: posix.socklen_t = @sizeOf(net.Address);

        const client = posix.accept(
            self.server.socket,
            &client_addr.any,
            &addr_len,
            posix.SOCK.NONBLOCK,
        ) catch |err| switch (err) {
            error.WouldBlock => return,
            else => return err,
        };

        try self.connections.append(self.allocator, Connection.init(client));
        try self.poll_fds.append(self.allocator, .{
            .fd = client,
            .events = posix.POLL.IN,
            .revents = 0,
        });
    }

    pub fn handleConnection(self: *StatefulServer, index: usize) !bool {
        var conn = &self.connections.items[index];

        switch (conn.state) {
            .reading => {
                if (!try conn.handleRead()) return false;
                if (conn.state == .writing) {
                    self.poll_fds.items[index + 1].events = posix.POLL.OUT;
                }
            },
            .writing => {
                if (!try conn.handleWrite()) return false;
                if (conn.state == .closing) {
                    return false;
                }
            },
            .closing => return false,
        }

        return true;
    }

    pub fn removeConnection(self: *StatefulServer, index: usize) void {
        const conn = self.connections.orderedRemove(index);
        posix.close(conn.socket);
        _ = self.poll_fds.orderedRemove(index + 1);
    }
};
// ANCHOR_END: stateful_server

// Tests
test "create non-blocking server" {
    const port: u16 = 9001;
    var server = try NonBlockingServer.init(testing.allocator, port);
    defer server.deinit();

    try testing.expect(server.socket >= 0);
    try testing.expectEqual(port, server.address.getPort());
}

test "poll server initialization" {
    const port: u16 = 9002;
    var poll_server = try PollServer.init(testing.allocator, port);
    defer poll_server.deinit();

    try testing.expectEqual(@as(usize, 0), poll_server.clients.items.len);
    try testing.expectEqual(@as(usize, 1), poll_server.poll_fds.items.len);
}

test "connection state transitions" {
    const conn = Connection.init(0);

    try testing.expectEqual(ConnectionState.reading, conn.state);
    try testing.expectEqual(@as(usize, 0), conn.bytes_read);
    try testing.expectEqual(@as(usize, 0), conn.bytes_written);
}

test "stateful server initialization" {
    const port: u16 = 9003;
    var server = try StatefulServer.init(testing.allocator, port);
    defer server.deinit();

    try testing.expectEqual(@as(usize, 0), server.connections.items.len);
    try testing.expectEqual(@as(usize, 1), server.poll_fds.items.len);
}

test "non-blocking accept with no clients" {
    const port: u16 = 9004;
    var server = try PollServer.init(testing.allocator, port);
    defer server.deinit();

    try server.acceptClient();
    try testing.expectEqual(@as(usize, 0), server.clients.items.len);
}

test "poll server can run event loop" {
    const port: u16 = 9005;
    var server = try PollServer.init(testing.allocator, port);
    defer server.deinit();

    try server.run(5);
    try testing.expectEqual(@as(usize, 0), server.clients.items.len);
}
