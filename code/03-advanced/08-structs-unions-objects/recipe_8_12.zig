// Recipe 8.12: Defining an Interface or Abstract Base Class
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// Define explicit error sets for interfaces
// This provides better type safety and allows callers to handle specific errors
pub const IOError = error{
    OutOfMemory,
    EndOfStream,
    InvalidSeekPos,
    DeviceError,
    NotImplemented,
};

// ANCHOR: vtable_interface
// VTable-based interface
const Writer = struct {
    ptr: *anyopaque,
    writeFn: *const fn (ptr: *anyopaque, data: []const u8) IOError!usize,

    pub fn write(self: Writer, data: []const u8) !usize {
        return self.writeFn(self.ptr, data);
    }
};

const BufferWriter = struct {
    buffer: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) BufferWriter {
        return BufferWriter{
            .buffer = std.ArrayList(u8){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BufferWriter) void {
        self.buffer.deinit(self.allocator);
    }

    fn writeFn(ptr: *anyopaque, data: []const u8) IOError!usize {
        const self: *BufferWriter = @ptrCast(@alignCast(ptr));
        self.buffer.appendSlice(self.allocator, data) catch return error.OutOfMemory;
        return data.len;
    }

    pub fn writer(self: *BufferWriter) Writer {
        return Writer{
            .ptr = self,
            .writeFn = writeFn,
        };
    }

    pub fn getWritten(self: *const BufferWriter) []const u8 {
        return self.buffer.items;
    }
};
// ANCHOR_END: vtable_interface

test "vtable interface" {
    var buf = BufferWriter.init(testing.allocator);
    defer buf.deinit();

    const writer = buf.writer();
    const written = try writer.write("Hello, World!");

    try testing.expectEqual(@as(usize, 13), written);
    try testing.expectEqualStrings("Hello, World!", buf.getWritten());
}

// ANCHOR: tagged_union_interface
// Tagged union interface
const Shape = union(enum) {
    circle: Circle,
    rectangle: Rectangle,
    triangle: Triangle,

    const Circle = struct {
        radius: f32,

        pub fn area(self: Circle) f32 {
            return std.math.pi * self.radius * self.radius;
        }
    };

    const Rectangle = struct {
        width: f32,
        height: f32,

        pub fn area(self: Rectangle) f32 {
            return self.width * self.height;
        }
    };

    const Triangle = struct {
        base: f32,
        height: f32,

        pub fn area(self: Triangle) f32 {
            return 0.5 * self.base * self.height;
        }
    };

    pub fn area(self: Shape) f32 {
        return switch (self) {
            .circle => |c| c.area(),
            .rectangle => |r| r.area(),
            .triangle => |t| t.area(),
        };
    }

    pub fn perimeter(self: Shape) f32 {
        return switch (self) {
            .circle => |c| 2 * std.math.pi * c.radius,
            .rectangle => |r| 2 * (r.width + r.height),
            .triangle => |t| t.base + 2 * @sqrt(t.height * t.height + (t.base / 2) * (t.base / 2)),
        };
    }
};
// ANCHOR_END: tagged_union_interface

test "tagged union interface" {
    const circle = Shape{ .circle = .{ .radius = 5 } };
    const rect = Shape{ .rectangle = .{ .width = 4, .height = 6 } };

    try testing.expectApproxEqAbs(78.54, circle.area(), 0.01);
    try testing.expectEqual(@as(f32, 24), rect.area());
}

// ANCHOR: comptime_interface
// Compile-time duck typing interface
fn Drawable(comptime T: type) type {
    return struct {
        pub fn validate() void {
            if (!@hasDecl(T, "draw")) {
                @compileError("Type must have 'draw' method");
            }
            if (!@hasDecl(T, "getBounds")) {
                @compileError("Type must have 'getBounds' method");
            }
        }
    };
}

const Box = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,

    pub fn draw(self: *const Box) void {
        _ = self;
        // Drawing logic
    }

    pub fn getBounds(self: *const Box) struct { x: f32, y: f32, w: f32, h: f32 } {
        return .{ .x = self.x, .y = self.y, .w = self.width, .h = self.height };
    }
};

fn renderDrawable(drawable: anytype) void {
    const T = @TypeOf(drawable);
    Drawable(T).validate();
    drawable.draw();
}
// ANCHOR_END: comptime_interface

test "comptime interface" {
    const box = Box{ .x = 0, .y = 0, .width = 10, .height = 20 };
    renderDrawable(box);

    const bounds = box.getBounds();
    try testing.expectEqual(@as(f32, 10), bounds.w);
}

// ANCHOR: multi_vtable
// Multiple interfaces via multiple vtables
const Reader = struct {
    ptr: *anyopaque,
    readFn: *const fn (ptr: *anyopaque, buffer: []u8) IOError!usize,

    pub fn read(self: Reader, buffer: []u8) !usize {
        return self.readFn(self.ptr, buffer);
    }
};

const Seeker = struct {
    ptr: *anyopaque,
    seekFn: *const fn (ptr: *anyopaque, pos: u64) IOError!void,

    pub fn seek(self: Seeker, pos: u64) !void {
        return self.seekFn(self.ptr, pos);
    }
};

const MemoryFile = struct {
    data: []const u8,
    position: usize,

    pub fn init(data: []const u8) MemoryFile {
        return MemoryFile{
            .data = data,
            .position = 0,
        };
    }

    fn readFn(ptr: *anyopaque, buffer: []u8) IOError!usize {
        const self: *MemoryFile = @ptrCast(@alignCast(ptr));
        const remaining = self.data[self.position..];
        const to_read = @min(buffer.len, remaining.len);
        @memcpy(buffer[0..to_read], remaining[0..to_read]);
        self.position += to_read;
        return to_read;
    }

    fn seekFn(ptr: *anyopaque, pos: u64) IOError!void {
        const self: *MemoryFile = @ptrCast(@alignCast(ptr));
        if (pos > self.data.len) return error.InvalidSeekPos;
        self.position = @intCast(pos);
    }

    pub fn reader(self: *MemoryFile) Reader {
        return Reader{ .ptr = self, .readFn = readFn };
    }

    pub fn seeker(self: *MemoryFile) Seeker {
        return Seeker{ .ptr = self, .seekFn = seekFn };
    }
};
// ANCHOR_END: multi_vtable

test "multiple interfaces" {
    const data = "Hello, World!";
    var file = MemoryFile.init(data);

    const reader = file.reader();
    var buffer: [5]u8 = undefined;
    const read_count = try reader.read(&buffer);
    try testing.expectEqual(@as(usize, 5), read_count);
    try testing.expectEqualStrings("Hello", &buffer);

    const seeker = file.seeker();
    try seeker.seek(7);
    const read_count2 = try reader.read(&buffer);
    try testing.expectEqual(@as(usize, 5), read_count2);
    try testing.expectEqualStrings("World", &buffer);
}

// ANCHOR: generic_interface
// Generic interface pattern
fn Serializer(comptime T: type) type {
    return struct {
        pub fn serialize(value: T, allocator: std.mem.Allocator) ![]u8 {
            _ = value;
            return try allocator.dupe(u8, "serialized");
        }

        pub fn deserialize(data: []const u8, allocator: std.mem.Allocator) !T {
            _ = data;
            _ = allocator;
            return error.NotImplemented;
        }
    };
}

const Person = struct {
    name: []const u8,
    age: u32,

    pub const Ser = Serializer(@This());
};
// ANCHOR_END: generic_interface

test "generic interface" {
    const person = Person{ .name = "Alice", .age = 30 };
    const serialized = try Person.Ser.serialize(person, testing.allocator);
    defer testing.allocator.free(serialized);

    try testing.expectEqualStrings("serialized", serialized);
}

// ANCHOR: trait_bounds
// Trait bounds using comptime
fn printValue(value: anytype) void {
    const T = @TypeOf(value);
    const info = @typeInfo(T);

    // Require the type to have a print method
    if (info == .@"struct" or info == .@"union") {
        if (!@hasDecl(T, "print")) {
            @compileError("Type must implement print() method");
        }
    }

    value.print();
}

const LogEntry = struct {
    message: []const u8,
    level: enum { info, warn, err },

    pub fn print(self: *const LogEntry) void {
        _ = self;
        // Print implementation
    }
};
// ANCHOR_END: trait_bounds

test "trait bounds" {
    const entry = LogEntry{
        .message = "Test message",
        .level = .info,
    };

    printValue(entry);
}

// ANCHOR: interface_composition
// Interface composition
const Closeable = struct {
    ptr: *anyopaque,
    closeFn: *const fn (ptr: *anyopaque) IOError!void,

    pub fn close(self: Closeable) !void {
        return self.closeFn(self.ptr);
    }
};

const ReadWriteCloseable = struct {
    reader: Reader,
    writer: Writer,
    closeable: Closeable,

    pub fn read(self: ReadWriteCloseable, buffer: []u8) !usize {
        return self.reader.read(buffer);
    }

    pub fn write(self: ReadWriteCloseable, data: []const u8) !usize {
        return self.writer.write(data);
    }

    pub fn close(self: ReadWriteCloseable) !void {
        return self.closeable.close();
    }
};

const DualBuffer = struct {
    read_buffer: []const u8,
    write_buffer: std.ArrayList(u8),
    read_pos: usize,
    allocator: std.mem.Allocator,
    closed: bool,

    pub fn init(allocator: std.mem.Allocator, read_data: []const u8) DualBuffer {
        return DualBuffer{
            .read_buffer = read_data,
            .write_buffer = std.ArrayList(u8){},
            .read_pos = 0,
            .allocator = allocator,
            .closed = false,
        };
    }

    pub fn deinit(self: *DualBuffer) void {
        self.write_buffer.deinit(self.allocator);
    }

    fn readFn(ptr: *anyopaque, buffer: []u8) IOError!usize {
        const self: *DualBuffer = @ptrCast(@alignCast(ptr));
        const remaining = self.read_buffer[self.read_pos..];
        const to_read = @min(buffer.len, remaining.len);
        @memcpy(buffer[0..to_read], remaining[0..to_read]);
        self.read_pos += to_read;
        return to_read;
    }

    fn writeFn(ptr: *anyopaque, data: []const u8) IOError!usize {
        const self: *DualBuffer = @ptrCast(@alignCast(ptr));
        self.write_buffer.appendSlice(self.allocator, data) catch return error.OutOfMemory;
        return data.len;
    }

    fn closeFn(ptr: *anyopaque) IOError!void {
        const self: *DualBuffer = @ptrCast(@alignCast(ptr));
        self.closed = true;
    }

    pub fn readWriteCloseable(self: *DualBuffer) ReadWriteCloseable {
        return ReadWriteCloseable{
            .reader = Reader{ .ptr = self, .readFn = readFn },
            .writer = Writer{ .ptr = self, .writeFn = writeFn },
            .closeable = Closeable{ .ptr = self, .closeFn = closeFn },
        };
    }
};
// ANCHOR_END: interface_composition

test "interface composition" {
    var dual = DualBuffer.init(testing.allocator, "input data");
    defer dual.deinit();

    const rwc = dual.readWriteCloseable();

    var buffer: [5]u8 = undefined;
    _ = try rwc.read(&buffer);
    try testing.expectEqualStrings("input", &buffer);

    _ = try rwc.write("output");
    try testing.expectEqualStrings("output", dual.write_buffer.items);

    try rwc.close();
    try testing.expect(dual.closed);
}

// ANCHOR: static_dispatch
// Static dispatch with comptime
fn process(comptime T: type, processor: T, data: []const u8) !void {
    // Verify interface at compile time
    if (!@hasDecl(T, "process")) {
        @compileError("Type must have process method");
    }

    try processor.process(data);
}

const UppercaseProcessor = struct {
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub fn process(self: UppercaseProcessor, data: []const u8) !void {
        for (data) |c| {
            try self.output.append(self.allocator, std.ascii.toUpper(c));
        }
    }
};

const LowercaseProcessor = struct {
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub fn process(self: LowercaseProcessor, data: []const u8) !void {
        for (data) |c| {
            try self.output.append(self.allocator, std.ascii.toLower(c));
        }
    }
};
// ANCHOR_END: static_dispatch

test "static dispatch" {
    var upper_output = std.ArrayList(u8){};
    defer upper_output.deinit(testing.allocator);

    const upper = UppercaseProcessor{ .output = &upper_output, .allocator = testing.allocator };
    try process(UppercaseProcessor, upper, "hello");
    try testing.expectEqualStrings("HELLO", upper_output.items);

    var lower_output = std.ArrayList(u8){};
    defer lower_output.deinit(testing.allocator);

    const lower = LowercaseProcessor{ .output = &lower_output, .allocator = testing.allocator };
    try process(LowercaseProcessor, lower, "WORLD");
    try testing.expectEqualStrings("world", lower_output.items);
}

// ANCHOR: anytype_interface
// Anytype interface (most flexible)
fn compare(a: anytype, b: anytype) !bool {
    const T = @TypeOf(a);
    if (@TypeOf(b) != T) {
        @compileError("Both arguments must be the same type");
    }

    // Check if type has equals method
    const info = @typeInfo(T);
    const has_equals = switch (info) {
        .@"struct", .@"union", .@"enum" => @hasDecl(T, "equals"),
        else => false,
    };

    if (has_equals) {
        return a.equals(b);
    }

    // Fall back to builtin equality
    return a == b;
}

const CustomNumber = struct {
    value: i32,

    pub fn equals(self: CustomNumber, other: CustomNumber) bool {
        return self.value == other.value;
    }
};
// ANCHOR_END: anytype_interface

test "anytype interface" {
    const n1 = CustomNumber{ .value = 42 };
    const n2 = CustomNumber{ .value = 42 };
    const n3 = CustomNumber{ .value = 99 };

    try testing.expect(try compare(n1, n2));
    try testing.expect(!try compare(n1, n3));

    try testing.expect(try compare(@as(i32, 5), @as(i32, 5)));
}

// Comprehensive test
test "comprehensive interface patterns" {
    var buf = BufferWriter.init(testing.allocator);
    defer buf.deinit();
    _ = try buf.writer().write("test");
    try testing.expectEqualStrings("test", buf.getWritten());

    const circle = Shape{ .circle = .{ .radius = 3 } };
    const area = circle.area();
    try testing.expectApproxEqAbs(28.27, area, 0.01);

    const box = Box{ .x = 0, .y = 0, .width = 5, .height = 5 };
    renderDrawable(box);
}
