// Recipe 8.7: Calling a Method on a Parent Class
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_composition
// Basic composition
const Logger = struct {
    prefix: []const u8,

    pub fn init(prefix: []const u8) Logger {
        return Logger{ .prefix = prefix };
    }

    pub fn log(self: *const Logger, message: []const u8) void {
        _ = self;
        _ = message;
        // In reality: std.debug.print("[{s}] {s}\n", .{ self.prefix, message });
    }

    pub fn info(self: *const Logger, message: []const u8) void {
        self.log(message);
    }
};

const Application = struct {
    logger: Logger,
    name: []const u8,

    pub fn init(name: []const u8) Application {
        return Application{
            .logger = Logger.init("APP"),
            .name = name,
        };
    }

    pub fn start(self: *const Application) void {
        self.logger.info("Application starting");
    }

    pub fn stop(self: *const Application) void {
        self.logger.info("Application stopping");
    }
};
// ANCHOR_END: basic_composition

test "basic composition" {
    const app = Application.init("MyApp");
    app.start();
    app.stop();
}

// ANCHOR: embedded_struct
// Embedded struct pattern
const Animal = struct {
    name: []const u8,
    age: u8,

    pub fn init(name: []const u8, age: u8) Animal {
        return Animal{ .name = name, .age = age };
    }

    pub fn getName(self: *const Animal) []const u8 {
        return self.name;
    }

    pub fn getAge(self: *const Animal) u8 {
        return self.age;
    }

    pub fn speak(self: *const Animal) []const u8 {
        _ = self;
        return "Some sound";
    }
};

const Dog = struct {
    animal: Animal,
    breed: []const u8,

    pub fn init(name: []const u8, age: u8, breed: []const u8) Dog {
        return Dog{
            .animal = Animal.init(name, age),
            .breed = breed,
        };
    }

    // Delegate to embedded Animal
    pub fn getName(self: *const Dog) []const u8 {
        return self.animal.getName();
    }

    pub fn getAge(self: *const Dog) u8 {
        return self.animal.getAge();
    }

    // Override with Dog-specific behavior
    pub fn speak(self: *const Dog) []const u8 {
        _ = self;
        return "Woof!";
    }

    pub fn getBreed(self: *const Dog) []const u8 {
        return self.breed;
    }
};
// ANCHOR_END: embedded_struct

test "embedded struct" {
    const dog = Dog.init("Buddy", 5, "Golden Retriever");

    try testing.expectEqualStrings("Buddy", dog.getName());
    try testing.expectEqual(@as(u8, 5), dog.getAge());
    try testing.expectEqualStrings("Woof!", dog.speak());
    try testing.expectEqualStrings("Golden Retriever", dog.getBreed());
}

// ANCHOR: explicit_delegation
// Explicit delegation helper
const Counter = struct {
    count: i32,

    pub fn init() Counter {
        return Counter{ .count = 0 };
    }

    pub fn increment(self: *Counter) void {
        self.count += 1;
    }

    pub fn decrement(self: *Counter) void {
        self.count -= 1;
    }

    pub fn getValue(self: *const Counter) i32 {
        return self.count;
    }

    pub fn reset(self: *Counter) void {
        self.count = 0;
    }
};

const BoundedCounter = struct {
    counter: Counter,
    max_value: i32,

    pub fn init(max_value: i32) BoundedCounter {
        return BoundedCounter{
            .counter = Counter.init(),
            .max_value = max_value,
        };
    }

    // Delegate to parent, but with bounds checking
    pub fn increment(self: *BoundedCounter) void {
        if (self.counter.getValue() < self.max_value) {
            self.counter.increment();
        }
    }

    pub fn decrement(self: *BoundedCounter) void {
        if (self.counter.getValue() > 0) {
            self.counter.decrement();
        }
    }

    // Simple delegation
    pub fn getValue(self: *const BoundedCounter) i32 {
        return self.counter.getValue();
    }

    pub fn reset(self: *BoundedCounter) void {
        self.counter.reset();
    }
};
// ANCHOR_END: explicit_delegation

test "explicit delegation" {
    var bounded = BoundedCounter.init(5);

    bounded.increment();
    bounded.increment();
    try testing.expectEqual(@as(i32, 2), bounded.getValue());

    // Try to exceed max
    bounded.increment();
    bounded.increment();
    bounded.increment();
    bounded.increment();
    try testing.expectEqual(@as(i32, 5), bounded.getValue());

    bounded.decrement();
    try testing.expectEqual(@as(i32, 4), bounded.getValue());
}

// ANCHOR: multiple_composition
// Multiple composition (like multiple inheritance)
const Drawable = struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) Drawable {
        return Drawable{ .x = x, .y = y };
    }

    pub fn draw(self: *const Drawable) void {
        _ = self;
        // Drawing logic
    }

    pub fn moveTo(self: *Drawable, x: f32, y: f32) void {
        self.x = x;
        self.y = y;
    }
};

const Clickable = struct {
    enabled: bool,

    pub fn init() Clickable {
        return Clickable{ .enabled = true };
    }

    pub fn onClick(self: *const Clickable) void {
        _ = self;
        // Click handling logic
    }

    pub fn setEnabled(self: *Clickable, enabled: bool) void {
        self.enabled = enabled;
    }
};

const Button = struct {
    drawable: Drawable,
    clickable: Clickable,
    label: []const u8,

    pub fn init(x: f32, y: f32, label: []const u8) Button {
        return Button{
            .drawable = Drawable.init(x, y),
            .clickable = Clickable.init(),
            .label = label,
        };
    }

    // Delegate to Drawable
    pub fn draw(self: *const Button) void {
        self.drawable.draw();
    }

    pub fn moveTo(self: *Button, x: f32, y: f32) void {
        self.drawable.moveTo(x, y);
    }

    // Delegate to Clickable
    pub fn onClick(self: *const Button) void {
        if (self.clickable.enabled) {
            self.clickable.onClick();
        }
    }

    pub fn setEnabled(self: *Button, enabled: bool) void {
        self.clickable.setEnabled(enabled);
    }
};
// ANCHOR_END: multiple_composition

test "multiple composition" {
    var button = Button.init(10, 20, "Click Me");

    button.draw();
    button.onClick();

    button.moveTo(30, 40);
    try testing.expectEqual(@as(f32, 30), button.drawable.x);

    button.setEnabled(false);
    try testing.expectEqual(false, button.clickable.enabled);
}

// ANCHOR: extending_parent_method
// Extending parent method behavior
const FileWriter = struct {
    path: []const u8,
    write_count: u32,

    pub fn init(path: []const u8) FileWriter {
        return FileWriter{
            .path = path,
            .write_count = 0,
        };
    }

    pub fn write(self: *FileWriter, data: []const u8) !void {
        _ = data;
        self.write_count += 1;
        // Actual file writing would go here
    }

    pub fn getWriteCount(self: *const FileWriter) u32 {
        return self.write_count;
    }
};

const BufferedFileWriter = struct {
    writer: FileWriter,
    buffer: [1024]u8,
    buffer_len: usize,

    pub fn init(path: []const u8) BufferedFileWriter {
        return BufferedFileWriter{
            .writer = FileWriter.init(path),
            .buffer = undefined,
            .buffer_len = 0,
        };
    }

    pub fn write(self: *BufferedFileWriter, data: []const u8) !void {
        // Add to buffer
        for (data) |byte| {
            self.buffer[self.buffer_len] = byte;
            self.buffer_len += 1;

            // Flush if buffer full
            if (self.buffer_len >= self.buffer.len) {
                try self.flush();
            }
        }
    }

    pub fn flush(self: *BufferedFileWriter) !void {
        if (self.buffer_len > 0) {
            // Call parent write method
            try self.writer.write(self.buffer[0..self.buffer_len]);
            self.buffer_len = 0;
        }
    }

    pub fn getWriteCount(self: *const BufferedFileWriter) u32 {
        return self.writer.getWriteCount();
    }
};
// ANCHOR_END: extending_parent_method

test "extending parent method" {
    var buffered = BufferedFileWriter.init("/tmp/test.txt");

    try buffered.write("Hello");
    try buffered.write(", World!");

    // Haven't flushed yet
    try testing.expectEqual(@as(u32, 0), buffered.getWriteCount());

    try buffered.flush();
    try testing.expectEqual(@as(u32, 1), buffered.getWriteCount());
}

// ANCHOR: accessing_parent_state
// Accessing and modifying parent state
const Vehicle = struct {
    speed: f32,
    fuel: f32,

    pub fn init(fuel: f32) Vehicle {
        return Vehicle{
            .speed = 0,
            .fuel = fuel,
        };
    }

    pub fn accelerate(self: *Vehicle, amount: f32) !void {
        if (self.fuel <= 0) return error.NoFuel;
        self.speed += amount;
        self.fuel -= amount * 0.1;
    }

    pub fn brake(self: *Vehicle) void {
        self.speed = 0;
    }

    pub fn getSpeed(self: *const Vehicle) f32 {
        return self.speed;
    }

    pub fn getFuel(self: *const Vehicle) f32 {
        return self.fuel;
    }
};

const Car = struct {
    vehicle: Vehicle,
    turbo_enabled: bool,

    pub fn init(fuel: f32) Car {
        return Car{
            .vehicle = Vehicle.init(fuel),
            .turbo_enabled = false,
        };
    }

    pub fn accelerate(self: *Car, amount: f32) !void {
        const multiplier: f32 = if (self.turbo_enabled) 2.0 else 1.0;
        try self.vehicle.accelerate(amount * multiplier);
    }

    pub fn brake(self: *Car) void {
        self.vehicle.brake();
    }

    pub fn enableTurbo(self: *Car) void {
        self.turbo_enabled = true;
    }

    pub fn getSpeed(self: *const Car) f32 {
        return self.vehicle.getSpeed();
    }

    pub fn getFuel(self: *const Car) f32 {
        return self.vehicle.getFuel();
    }
};
// ANCHOR_END: accessing_parent_state

test "accessing parent state" {
    var car = Car.init(100);

    try car.accelerate(10);
    try testing.expectEqual(@as(f32, 10), car.getSpeed());

    car.enableTurbo();
    try car.accelerate(10);
    try testing.expectEqual(@as(f32, 30), car.getSpeed()); // 10 + (10 * 2)
}

// ANCHOR: init_with_parent
// Initializing with parent initialization
const Shape = struct {
    color: []const u8,
    id: u32,

    pub fn init(color: []const u8, id: u32) Shape {
        return Shape{
            .color = color,
            .id = id,
        };
    }

    pub fn describe(self: *const Shape) void {
        _ = self;
        // std.debug.print("Shape #{d} in {s}\n", .{ self.id, self.color });
    }
};

const Circle = struct {
    shape: Shape,
    radius: f32,

    pub fn init(color: []const u8, id: u32, radius: f32) Circle {
        return Circle{
            .shape = Shape.init(color, id),
            .radius = radius,
        };
    }

    pub fn describe(self: *const Circle) void {
        self.shape.describe();
        // Additional circle-specific description
    }

    pub fn getArea(self: *const Circle) f32 {
        return std.math.pi * self.radius * self.radius;
    }
};
// ANCHOR_END: init_with_parent

test "init with parent" {
    const circle = Circle.init("red", 1, 5.0);

    try testing.expectEqualStrings("red", circle.shape.color);
    try testing.expectEqual(@as(u32, 1), circle.shape.id);
    try testing.expectEqual(@as(f32, 5.0), circle.radius);

    const area = circle.getArea();
    try testing.expectApproxEqAbs(78.54, area, 0.01);
}

// ANCHOR: generic_wrapper
// Generic wrapper pattern
fn Wrapper(comptime T: type) type {
    return struct {
        inner: T,
        metadata: []const u8,

        const Self = @This();

        pub fn init(inner: T, metadata: []const u8) Self {
            return Self{
                .inner = inner,
                .metadata = metadata,
            };
        }

        pub fn getInner(self: *const Self) *const T {
            return &self.inner;
        }

        pub fn getInnerMut(self: *Self) *T {
            return &self.inner;
        }

        pub fn getMetadata(self: *const Self) []const u8 {
            return self.metadata;
        }
    };
}
// ANCHOR_END: generic_wrapper

test "generic wrapper" {
    var wrapped = Wrapper(i32).init(42, "important number");

    try testing.expectEqual(@as(i32, 42), wrapped.getInner().*);
    try testing.expectEqualStrings("important number", wrapped.getMetadata());

    wrapped.getInnerMut().* = 100;
    try testing.expectEqual(@as(i32, 100), wrapped.getInner().*);
}

// ANCHOR: interface_delegation
// Interface-style delegation
const Writer = struct {
    ptr: *anyopaque,
    writeFn: *const fn (ptr: *anyopaque, data: []const u8) anyerror!usize,

    pub fn write(self: Writer, data: []const u8) !usize {
        return self.writeFn(self.ptr, data);
    }
};

const StringWriter = struct {
    buffer: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) StringWriter {
        return StringWriter{
            .buffer = std.ArrayList(u8){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *StringWriter) void {
        self.buffer.deinit(self.allocator);
    }

    fn writeImpl(ptr: *anyopaque, data: []const u8) !usize {
        const self: *StringWriter = @ptrCast(@alignCast(ptr));
        try self.buffer.appendSlice(self.allocator, data);
        return data.len;
    }

    pub fn writer(self: *StringWriter) Writer {
        return Writer{
            .ptr = self,
            .writeFn = writeImpl,
        };
    }

    pub fn getString(self: *const StringWriter) []const u8 {
        return self.buffer.items;
    }
};
// ANCHOR_END: interface_delegation

test "interface delegation" {
    var string_writer = StringWriter.init(testing.allocator);
    defer string_writer.deinit();

    const writer = string_writer.writer();
    const written = try writer.write("Hello, World!");

    try testing.expectEqual(@as(usize, 13), written);
    try testing.expectEqualStrings("Hello, World!", string_writer.getString());
}

// Comprehensive test
test "comprehensive parent method calls" {
    var dog = Dog.init("Max", 3, "Labrador");
    try testing.expectEqualStrings("Max", dog.getName());

    var bounded = BoundedCounter.init(10);
    bounded.increment();
    try testing.expectEqual(@as(i32, 1), bounded.getValue());

    var button = Button.init(5, 5, "Submit");
    button.moveTo(10, 10);
    try testing.expectEqual(@as(f32, 10), button.drawable.x);

    var car = Car.init(50);
    try car.accelerate(5);
    try testing.expect(car.getSpeed() > 0);
}
