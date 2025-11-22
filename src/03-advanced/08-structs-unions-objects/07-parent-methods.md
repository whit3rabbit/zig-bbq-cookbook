## Problem

You want to reuse functionality from one struct in another, similar to how object-oriented languages use inheritance and calling parent class methods. However, Zig doesn't have traditional class inheritance.

## Solution

Zig uses composition over inheritance. Embed structs within other structs and delegate method calls to access parent functionality. This gives you the benefits of code reuse without the complexity of inheritance hierarchies.

### Basic Composition

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_7.zig:basic_composition}}

    pub fn stop(self: *const Application) void {
        self.logger.info("Application stopping");
    }
};
```

The `Application` struct contains a `Logger` and calls its methods directly.

### Embedded Struct Pattern

Create a parent-child relationship through embedding:

```zig
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
```

`Dog` embeds `Animal` and delegates some methods while providing its own implementation of others.

### Explicit Delegation with Enhanced Behavior

Wrap parent methods to add validation or extra logic:

```zig
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
```

`BoundedCounter` enhances `Counter` by adding boundary checks before delegating.

### Multiple Composition

Combine multiple structs to get features from several sources:

```zig
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
```

`Button` combines drawable and clickable functionality through multiple embedded structs.

### Extending Parent Method Behavior

Call parent methods and add additional processing:

```zig
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
```

`BufferedFileWriter` adds buffering logic before calling the parent's `write()` method.

### Accessing and Modifying Parent State

Child structs can read and modify parent state through the embedded struct:

```zig
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
```

`Car` modifies how acceleration works by applying a turbo multiplier before calling the parent method.

### Generic Wrapper Pattern

Create reusable wrappers using `comptime`:

```zig
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
```

This wrapper works with any type and provides access to the wrapped value.

## Discussion

Zig's composition approach offers several advantages over traditional inheritance:

1. **Explicit relationships** - You can see exactly which methods delegate to which embedded structs
2. **No diamond problem** - Multiple composition doesn't create ambiguous method resolution
3. **Flexible organization** - Restructure relationships without changing interfaces
4. **Clear ownership** - Each struct owns its embedded structs
5. **Better performance** - No vtable lookups or dynamic dispatch overhead

### Composition vs. Inheritance

In object-oriented languages, you might write:

```
class Dog extends Animal {
    speak() { return "Woof!"; }
}
```

In Zig, you compose explicitly:

```zig
const Dog = struct {
    animal: Animal,  // Embed parent
    // ... delegate methods ...
};
```

The Zig approach requires more typing but makes dependencies and relationships visible.

### When to Delegate

Delegate method calls when you want to:

- **Reuse logic** - Don't duplicate parent functionality
- **Add validation** - Wrap parent methods with checks
- **Extend behavior** - Call parent then do additional work
- **Maintain compatibility** - Keep same interface as parent

For new functionality unique to the child struct, implement methods directly without delegation.

### Performance

Composition in Zig has minimal overhead:

- Embedded structs are laid out inline (no pointers or allocations)
- Method calls compile to direct function calls (no dynamic dispatch)
- The compiler can inline delegated methods
- No runtime type checking or vtable lookups

This makes composition as fast as using the structs directly.

### Pattern: Delegation Macros

For structs with many delegated methods, consider using `comptime` to generate delegation code automatically. This reduces boilerplate while maintaining explicitness.

## See Also

- Recipe 8.5: Encapsulating Names in a Struct
- Recipe 8.8: Extending a Property in a Subclass
- Recipe 8.12: Defining an Interface
- Recipe 8.18: Extending Classes with Mixins

Full compilable example: `code/03-advanced/08-structs-unions-objects/recipe_8_7.zig`
