const std = @import("std");

/// Serial port wrapper
pub const SerialPort = struct {
    file: std.fs.File,

    pub fn open(path: []const u8, baud_rate: u32) !SerialPort {
        const builtin = @import("builtin");
        if (builtin.os.tag == .windows) {
            return error.NotSupported;
        }

        const file = try std.fs.cwd().openFile(path, .{ .mode = .read_write });
        errdefer file.close();

        try configurePort(file, baud_rate);

        return SerialPort{ .file = file };
    }

    pub fn close(self: *SerialPort) void {
        self.file.close();
    }

    pub fn write(self: *SerialPort, data: []const u8) !void {
        return self.file.writeAll(data);
    }

    pub fn read(self: *SerialPort, buffer: []u8) !usize {
        return self.file.read(buffer);
    }
};

/// Configure serial port with termios
fn configurePort(file: std.fs.File, baud_rate: u32) !void {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return error.NotSupported;
    }

    var termios = try std.posix.tcgetattr(file.handle);

    // Set baud rate
    const speed = baudToSpeed(baud_rate);
    termios.ispeed = speed;
    termios.ospeed = speed;

    // 8N1 mode (8 data bits, no parity, 1 stop bit)
    termios.cflag &= ~@as(u32, @intCast(std.posix.PARENB)); // No parity
    termios.cflag &= ~@as(u32, @intCast(std.posix.CSTOPB)); // 1 stop bit
    termios.cflag &= ~@as(u32, @intCast(std.posix.CSIZE));
    termios.cflag |= @as(u32, @intCast(std.posix.CS8)); // 8 data bits

    // Enable receiver, ignore modem control lines
    termios.cflag |= @as(u32, @intCast(std.posix.CREAD | std.posix.CLOCAL));

    // Raw mode (no canonical processing)
    termios.lflag &= ~@as(u32, @intCast(std.posix.ICANON | std.posix.ECHO | std.posix.ECHOE | std.posix.ISIG));

    // Disable software flow control
    termios.iflag &= ~@as(u32, @intCast(std.posix.IXON | std.posix.IXOFF | std.posix.IXANY));

    // Raw output (no post-processing)
    termios.oflag &= ~@as(u32, @intCast(std.posix.OPOST));

    // Set read timeout (1 second)
    termios.cc[std.posix.V.TIME] = 10; // Deciseconds
    termios.cc[std.posix.V.MIN] = 0;

    try std.posix.tcsetattr(file.handle, .FLUSH, termios);
}

/// Convert baud rate to termios speed constant
fn baudToSpeed(baud_rate: u32) std.posix.speed_t {
    // On Unix-like systems, speed_t can be an enum (macOS/BSD) or integer (Linux)
    // Use @enumFromInt to handle both cases
    return @enumFromInt(baud_rate);
}

/// Parity options
pub const Parity = enum {
    none,
    even,
    odd,
};

/// Set parity
pub fn setParity(file: std.fs.File, parity: Parity) !void {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return error.NotSupported;
    }

    var termios = try std.posix.tcgetattr(file.handle);

    switch (parity) {
        .none => {
            termios.cflag &= ~@as(u32, @intCast(std.posix.PARENB));
        },
        .even => {
            termios.cflag |= @as(u32, @intCast(std.posix.PARENB));
            termios.cflag &= ~@as(u32, @intCast(std.posix.PARODD));
        },
        .odd => {
            termios.cflag |= @as(u32, @intCast(std.posix.PARENB | std.posix.PARODD));
        },
    }

    try std.posix.tcsetattr(file.handle, .NOW, termios);
}

/// Set stop bits (1 or 2)
pub fn setStopBits(file: std.fs.File, stop_bits: u8) !void {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return error.NotSupported;
    }

    if (stop_bits != 1 and stop_bits != 2) {
        return error.InvalidStopBits;
    }

    var termios = try std.posix.tcgetattr(file.handle);

    if (stop_bits == 1) {
        termios.cflag &= ~@as(u32, @intCast(std.posix.CSTOPB));
    } else {
        termios.cflag |= @as(u32, @intCast(std.posix.CSTOPB));
    }

    try std.posix.tcsetattr(file.handle, .NOW, termios);
}

/// Set data bits (5, 6, 7, or 8)
pub fn setDataBits(file: std.fs.File, data_bits: u8) !void {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return error.NotSupported;
    }

    var termios = try std.posix.tcgetattr(file.handle);

    termios.cflag &= ~@as(u32, @intCast(std.posix.CSIZE));

    const bits = switch (data_bits) {
        5 => std.posix.CS5,
        6 => std.posix.CS6,
        7 => std.posix.CS7,
        8 => std.posix.CS8,
        else => return error.InvalidDataBits,
    };

    termios.cflag |= @as(u32, @intCast(bits));

    try std.posix.tcsetattr(file.handle, .NOW, termios);
}

/// Set baud rate
pub fn setBaudRate(file: std.fs.File, baud_rate: u32) !void {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return error.NotSupported;
    }

    var termios = try std.posix.tcgetattr(file.handle);

    const speed = baudToSpeed(baud_rate);
    termios.ispeed = speed;
    termios.ospeed = speed;

    try std.posix.tcsetattr(file.handle, .NOW, termios);
}

/// Flow control options
pub const FlowControl = enum {
    none,
    software,
    hardware,
};

/// Set flow control
pub fn setFlowControl(file: std.fs.File, flow: FlowControl) !void {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return error.NotSupported;
    }

    var termios = try std.posix.tcgetattr(file.handle);

    switch (flow) {
        .none => {
            termios.iflag &= ~@as(u32, @intCast(std.posix.IXON | std.posix.IXOFF | std.posix.IXANY));
            termios.cflag &= ~@as(u32, @intCast(std.posix.CRTSCTS));
        },
        .software => {
            termios.iflag |= @as(u32, @intCast(std.posix.IXON | std.posix.IXOFF));
            termios.cflag &= ~@as(u32, @intCast(std.posix.CRTSCTS));
        },
        .hardware => {
            termios.iflag &= ~@as(u32, @intCast(std.posix.IXON | std.posix.IXOFF | std.posix.IXANY));
            termios.cflag |= @as(u32, @intCast(std.posix.CRTSCTS));
        },
    }

    try std.posix.tcsetattr(file.handle, .NOW, termios);
}

/// Set read timeout in deciseconds (tenths of a second)
pub fn setTimeout(file: std.fs.File, timeout_deciseconds: u8) !void {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return error.NotSupported;
    }

    var termios = try std.posix.tcgetattr(file.handle);

    termios.cc[std.posix.V.TIME] = timeout_deciseconds;
    termios.cc[std.posix.V.MIN] = 0;

    try std.posix.tcsetattr(file.handle, .NOW, termios);
}

/// Flush input buffer
pub fn flushInput(file: std.fs.File) !void {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return error.NotSupported;
    }

    try std.posix.tcflush(file.handle, .IFLUSH);
}

/// Flush output buffer
pub fn flushOutput(file: std.fs.File) !void {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return error.NotSupported;
    }

    try std.posix.tcflush(file.handle, .OFLUSH);
}

/// Flush both input and output buffers
pub fn flushBoth(file: std.fs.File) !void {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return error.NotSupported;
    }

    try std.posix.tcflush(file.handle, .IOFLUSH);
}

/// Read line until delimiter
pub fn readLine(file: std.fs.File, buffer: []u8, delimiter: u8) ![]const u8 {
    var pos: usize = 0;

    while (pos < buffer.len) {
        const n = try file.read(buffer[pos..pos + 1]);
        if (n == 0) break;

        if (buffer[pos] == delimiter) {
            return buffer[0..pos];
        }

        pos += 1;
    }

    return buffer[0..pos];
}

/// Read exact number of bytes
pub fn readExactly(file: std.fs.File, buffer: []u8) !void {
    var pos: usize = 0;

    while (pos < buffer.len) {
        const n = try file.read(buffer[pos..]);
        if (n == 0) return error.EndOfStream;
        pos += n;
    }
}

/// Write line with CRLF
pub fn writeLine(file: std.fs.File, data: []const u8) !void {
    try file.writeAll(data);
    try file.writeAll("\r\n");
}

/// Write command with CR
pub fn writeCommand(file: std.fs.File, command: []const u8) !void {
    try file.writeAll(command);
    try file.writeAll("\r");
}

/// Serial configuration struct
pub const SerialConfig = struct {
    baud_rate: u32 = 9600,
    data_bits: u8 = 8,
    stop_bits: u8 = 1,
    parity: Parity = .none,
    flow_control: FlowControl = .none,
    timeout_deciseconds: u8 = 10,
};

/// Open serial port with custom configuration
pub fn openConfigured(path: []const u8, config: SerialConfig) !SerialPort {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return error.NotSupported;
    }

    var port = try SerialPort.open(path, config.baud_rate);
    errdefer port.close();

    try setDataBits(port.file, config.data_bits);
    try setStopBits(port.file, config.stop_bits);
    try setParity(port.file, config.parity);
    try setFlowControl(port.file, config.flow_control);
    try setTimeout(port.file, config.timeout_deciseconds);

    return port;
}

/// Send AT command and read response
pub fn sendATCommand(port: *SerialPort, command: []const u8, response_buffer: []u8) ![]const u8 {
    try flushBoth(port.file);

    try writeCommand(port.file, command);

    const response = try readLine(port.file, response_buffer, '\n');

    return response;
}

/// Get common serial device paths
pub fn getCommonDevices(allocator: std.mem.Allocator) ![][]const u8 {
    var devices = std.ArrayList([]const u8){};
    errdefer {
        for (devices.items) |item| {
            allocator.free(item);
        }
        devices.deinit(allocator);
    }

    // Common USB serial adapters
    const patterns = [_][]const u8{
        "/dev/ttyUSB0",
        "/dev/ttyUSB1",
        "/dev/ttyACM0",
        "/dev/ttyACM1",
        "/dev/ttyS0",
        "/dev/ttyS1",
    };

    for (patterns) |pattern| {
        std.fs.cwd().access(pattern, .{}) catch continue;
        const device = try allocator.dupe(u8, pattern);
        try devices.append(allocator, device);
    }

    return devices.toOwnedSlice(allocator);
}

// Tests

// ANCHOR: serial_config
test "baud rate conversion" {
    const speed_9600: std.posix.speed_t = @enumFromInt(9600);
    const speed_115200: std.posix.speed_t = @enumFromInt(115200);
    const speed_57600: std.posix.speed_t = @enumFromInt(57600);

    try std.testing.expectEqual(speed_9600, baudToSpeed(9600));
    try std.testing.expectEqual(speed_115200, baudToSpeed(115200));
    try std.testing.expectEqual(speed_57600, baudToSpeed(57600));
}

test "serial config defaults" {
    const config = SerialConfig{};

    try std.testing.expectEqual(@as(u32, 9600), config.baud_rate);
    try std.testing.expectEqual(@as(u8, 8), config.data_bits);
    try std.testing.expectEqual(@as(u8, 1), config.stop_bits);
    try std.testing.expectEqual(Parity.none, config.parity);
    try std.testing.expectEqual(FlowControl.none, config.flow_control);
    try std.testing.expectEqual(@as(u8, 10), config.timeout_deciseconds);
}

test "serial config custom" {
    const config = SerialConfig{
        .baud_rate = 115200,
        .data_bits = 7,
        .stop_bits = 2,
        .parity = .even,
        .flow_control = .hardware,
        .timeout_deciseconds = 20,
    };

    try std.testing.expectEqual(@as(u32, 115200), config.baud_rate);
    try std.testing.expectEqual(@as(u8, 7), config.data_bits);
    try std.testing.expectEqual(@as(u8, 2), config.stop_bits);
    try std.testing.expectEqual(Parity.even, config.parity);
    try std.testing.expectEqual(FlowControl.hardware, config.flow_control);
    try std.testing.expectEqual(@as(u8, 20), config.timeout_deciseconds);
}

test "parity enum" {
    const none = Parity.none;
    const even = Parity.even;
    const odd = Parity.odd;

    try std.testing.expect(none != even);
    try std.testing.expect(even != odd);
    try std.testing.expect(odd != none);
}

test "flow control enum" {
    const none = FlowControl.none;
    const software = FlowControl.software;
    const hardware = FlowControl.hardware;

    try std.testing.expect(none != software);
    try std.testing.expect(software != hardware);
    try std.testing.expect(hardware != none);
}
// ANCHOR_END: serial_config

// ANCHOR: device_discovery
test "get common devices" {
    const allocator = std.testing.allocator;

    const devices = try getCommonDevices(allocator);
    defer {
        for (devices) |device| {
            allocator.free(device);
        }
        allocator.free(devices);
    }

    // Just verify we can call it
    // Actual devices depend on hardware
}

test "windows not supported" {
    const builtin = @import("builtin");
    if (builtin.os.tag != .windows) return error.SkipZigTest;

    const result = SerialPort.open("/dev/ttyUSB0", 9600);
    try std.testing.expectError(error.NotSupported, result);
}
// ANCHOR_END: device_discovery

// The following tests require actual serial hardware

// ANCHOR: usage_examples
test "serial port API" {
    // This test documents the API without requiring hardware
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    // Example usage (would fail without hardware):
    // var port = try SerialPort.open("/dev/ttyUSB0", 115200);
    // defer port.close();
    //
    // try port.write("Hello\r\n");
    //
    // var buffer: [100]u8 = undefined;
    // const n = try port.read(&buffer);
}

test "configured open API" {
    // This test documents the configured API without requiring hardware
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    // Example usage (would fail without hardware):
    // const config = SerialConfig{
    //     .baud_rate = 115200,
    //     .parity = .even,
    //     .flow_control = .hardware,
    // };
    //
    // var port = try openConfigured("/dev/ttyUSB0", config);
    // defer port.close();
}

test "read line simulation" {
    // Simulate reading with a fixed buffer
    var buffer: [100]u8 = undefined;
    @memcpy(buffer[0.."Hello\n".len], "Hello\n");

    // In real use, this would read from a file
    // const line = try readLine(file, &buffer, '\n');
}

test "write commands simulation" {
    // Documents the write command API
    // In real use:
    // try writeCommand(file, "AT");
    // try writeLine(file, "Hello World");
}

test "AT command simulation" {
    // Documents AT command pattern
    // In real use with modem:
    // var response_buffer: [256]u8 = undefined;
    // const response = try sendATCommand(&port, "AT", &response_buffer);
    // Expected response: "OK"
}

test "buffer flush simulation" {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    // Documents flush API
    // In real use:
    // try flushInput(file);
    // try flushOutput(file);
    // try flushBoth(file);
}

test "timeout configuration" {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    // Documents timeout API
    // In real use:
    // try setTimeout(file, 20); // 2 seconds
}

test "parameter configuration" {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    // Documents parameter setting API
    // In real use:
    // try setBaudRate(file, 115200);
    // try setDataBits(file, 8);
    // try setStopBits(file, 1);
    // try setParity(file, .none);
    // try setFlowControl(file, .none);
}
// ANCHOR_END: usage_examples
