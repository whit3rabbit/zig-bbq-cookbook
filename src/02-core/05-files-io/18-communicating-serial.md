## Problem

You need to communicate with hardware devices via serial ports (RS-232, USB-to-serial, etc.) and control parameters like baud rate, parity, and stop bits.

## Solution

### Serial Config

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_18.zig:serial_config}}
```

### Device Discovery

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_18.zig:device_discovery}}
```

### Usage Examples

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_18.zig:usage_examples}}
```

## Discussion

### Opening Serial Ports

Common serial port paths:

```zig
pub fn openSerialPort(allocator: std.mem.Allocator, device: []const u8, baud_rate: u32) !SerialPort {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return error.NotSupported;
    }

    _ = allocator;
    return SerialPort.open(device, baud_rate);
}

test "open serial port" {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    // Common paths: /dev/ttyUSB0, /dev/ttyACM0, /dev/ttyS0
    // This would require actual hardware to test
}
```

### Configuring Baud Rate

Set communication speed:

```zig
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
```

### Setting Parity

Configure parity checking:

```zig
pub const Parity = enum {
    none,
    even,
    odd,
};

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
```

### Setting Stop Bits

Configure stop bits:

```zig
pub fn setStopBits(file: std.fs.File, stop_bits: u8) !void {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return error.NotSupported;
    }

    var termios = try std.posix.tcgetattr(file.handle);

    if (stop_bits == 1) {
        termios.cflag &= ~@as(u32, @intCast(std.posix.CSTOPB));
    } else {
        termios.cflag |= @as(u32, @intCast(std.posix.CSTOPB));
    }

    try std.posix.tcsetattr(file.handle, .NOW, termios);
}
```

### Setting Data Bits

Configure data bits:

```zig
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
```

### Setting Flow Control

Configure hardware/software flow control:

```zig
pub const FlowControl = enum {
    none,
    software,
    hardware,
};

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
```

### Setting Timeouts

Control read/write timeouts:

```zig
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
```

### Flushing Buffers

Discard buffered data:

```zig
pub fn flushInput(file: std.fs.File) !void {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return error.NotSupported;
    }

    try std.posix.tcflush(file.handle, .IFLUSH);
}

pub fn flushOutput(file: std.fs.File) !void {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return error.NotSupported;
    }

    try std.posix.tcflush(file.handle, .OFLUSH);
}

pub fn flushBoth(file: std.fs.File) !void {
    const builtin = @import("builtin");
    if (builtin.os.tag == .windows) {
        return error.NotSupported;
    }

    try std.posix.tcflush(file.handle, .IOFLUSH);
}
```

### Reading Data

Read from serial port:

```zig
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

pub fn readExactly(file: std.fs.File, buffer: []u8) !void {
    var pos: usize = 0;

    while (pos < buffer.len) {
        const n = try file.read(buffer[pos..]);
        if (n == 0) return error.EndOfStream;
        pos += n;
    }
}
```

### Writing Data

Write to serial port:

```zig
pub fn writeLine(file: std.fs.File, data: []const u8) !void {
    try file.writeAll(data);
    try file.writeAll("\r\n");
}

pub fn writeCommand(file: std.fs.File, command: []const u8) !void {
    try file.writeAll(command);
    try file.writeAll("\r");
}
```

### Complete Serial Port Wrapper

Full-featured wrapper:

```zig
pub const SerialConfig = struct {
    baud_rate: u32 = 9600,
    data_bits: u8 = 8,
    stop_bits: u8 = 1,
    parity: Parity = .none,
    flow_control: FlowControl = .none,
    timeout_deciseconds: u8 = 10,
};

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
```

### AT Command Example

Communicating with modems:

```zig
pub fn sendATCommand(port: *SerialPort, command: []const u8, response_buffer: []u8) ![]const u8 {
    try flushBoth(port.file);

    try writeCommand(port.file, command);

    const response = try readLine(port.file, response_buffer, '\n');

    return response;
}
```

### Best Practices

**Configuration:**
- Always set all parameters explicitly
- Use `.FLUSH` when applying settings to clear buffers
- Verify device paths exist before opening

**Error handling:**
```zig
const port = SerialPort.open("/dev/ttyUSB0", 115200) catch |err| {
    std.log.err("Failed to open serial port: {}", .{err});
    return err;
};
defer port.close();
```

**Timeouts:**
- Set appropriate timeouts to avoid blocking forever
- `V.TIME` is in deciseconds (tenths of a second)
- `V.MIN = 0` for timeout-based reads

**Buffer management:**
- Flush buffers before important operations
- Use fixed-size buffers for embedded systems
- Handle partial reads in loops

**Platform support:**
- Unix/Linux: Full POSIX termios support
- macOS: Same as Unix/Linux
- Windows: Requires different API (not covered here)

### Related Functions

- `std.posix.tcgetattr()` - Get terminal attributes
- `std.posix.tcsetattr()` - Set terminal attributes
- `std.posix.tcflush()` - Flush terminal buffers
- `std.posix.tcdrain()` - Wait for output to drain
- `std.fs.File.read()` - Read data
- `std.fs.File.writeAll()` - Write data
- `std.fs.cwd().openFile()` - Open file/device
