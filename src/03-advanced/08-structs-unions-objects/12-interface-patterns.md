## Problem

You want to define interfaces or abstract base classes to allow different types to be used interchangeably, similar to interfaces in Java or traits in Rust. However, Zig doesn't have built-in interface syntax.

## Solution

Zig provides several approaches to interfaces: vtable-based fat pointers for runtime polymorphism, tagged unions for closed sets of types, and compile-time duck typing for static polymorphism.

### VTable-Based Interface

Use fat pointers containing a vtable for runtime polymorphism:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_12.zig:vtable_interface}}
        return Writer{
            .ptr = self,
            .writeFn = writeFn,
        };
    }
};
```

This pattern is similar to Go interfaces and allows different implementations to be used through the same interface.

### Tagged Union Interface

Use tagged unions when you know all implementing types at compile time:

```zig
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
```

Tagged unions provide zero-overhead polymorphism with compile-time type safety.

### Compile-Time Duck Typing

Validate interface requirements at compile time using `@hasDecl`:

```zig
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
```

The compiler ensures the type has required methods before allowing compilation.

### Multiple Interfaces

Combine multiple interfaces using separate vtables:

```zig
const Reader = struct {
    ptr: *anyopaque,
    readFn: *const fn (ptr: *anyopaque, buffer: []u8) anyerror!usize,

    pub fn read(self: Reader, buffer: []u8) !usize {
        return self.readFn(self.ptr, buffer);
    }
};

const Seeker = struct {
    ptr: *anyopaque,
    seekFn: *const fn (ptr: *anyopaque, pos: u64) anyerror!void,

    pub fn seek(self: Seeker, pos: u64) !void {
        return self.seekFn(self.ptr, pos);
    }
};

const MemoryFile = struct {
    data: []const u8,
    position: usize,

    // Implement both Reader and Seeker
    pub fn reader(self: *MemoryFile) Reader {
        return Reader{ .ptr = self, .readFn = readFn };
    }

    pub fn seeker(self: *MemoryFile) Seeker {
        return Seeker{ .ptr = self, .seekFn = seekFn };
    }
};
```

Types can implement multiple interfaces independently.

### Static Dispatch with Comptime

Achieve zero-cost abstraction using comptime parameters:

```zig
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
```

The concrete type is known at compile time, allowing full inlining and optimization.

### Anytype Interface (Most Flexible)

Use `anytype` for maximum flexibility:

```zig
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
```

This pattern adapts behavior based on what methods the type provides.

### Interface Composition

Combine multiple interfaces into a single type:

```zig
const Closeable = struct {
    ptr: *anyopaque,
    closeFn: *const fn (ptr: *anyopaque) anyerror!void,

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
```

Compose complex interfaces from simpler building blocks.

## Discussion

Zig's approach to interfaces emphasizes explicitness and zero-cost abstractions.

### Choosing an Interface Pattern

**VTable (fat pointer)** - Runtime polymorphism needed
- Use when: Type not known at compile time
- Examples: Plugin systems, heterogeneous collections
- Cost: One pointer indirection per call

**Tagged union** - Closed set of known types
- Use when: All types known at compile time
- Examples: AST nodes, state machines, parsers
- Cost: Switch statement (often optimized to jump table)

**Comptime duck typing** - Static polymorphism
- Use when: Generic algorithms with compile-time types
- Examples: Containers, algorithms, utilities
- Cost: Zero—fully inlined

**Anytype** - Maximum flexibility
- Use when: Many different types, each handled differently
- Examples: Logging, serialization, testing utilities
- Cost: Code bloat if many types (separate copy per type)

### Performance Characteristics

**VTable dispatch:**
- Runtime cost: One indirection
- Memory: 2 pointers (ptr + vtable)
- Monomorphization: No code duplication

**Tagged union:**
- Runtime cost: Tag check + branch
- Memory: Tag + largest variant
- Monomorphization: No code duplication

**Comptime/anytype:**
- Runtime cost: Zero (inlined)
- Memory: No overhead
- Monomorphization: Separate function per type

### Common Patterns

**Standard library pattern**: Most stdlib types use the vtable pattern
- `std.io.Reader`, `std.io.Writer`
- Fat pointers with function pointers

**Application pattern**: Use tagged unions for domain types
- Closed set of variants (commands, events, states)
- Exhaustive switch ensures all cases handled

**Library pattern**: Use comptime for generic code
- Containers (ArrayList, HashMap)
- Algorithms (sorting, searching)

### Best Practices

1. **Prefer comptime when possible** - Zero runtime cost
2. **Use tagged unions for closed sets** - Type-safe and fast
3. **VTables for true runtime polymorphism** - When types unknown at compile time
4. **Document interface requirements** - Use `@compileError` with clear messages
5. **Test with multiple implementations** - Ensure interface is truly generic

### Error Handling

Interface methods can return error unions:

```zig
const Fallible = struct {
    ptr: *anyopaque,
    executeFn: *const fn (ptr: *anyopaque) anyerror!void,

    pub fn execute(self: Fallible) !void {
        return self.executeFn(self.ptr);
    }
};
```

Callers must handle errors with `try` or `catch`.

## See Also

- Recipe 8.7: Calling a Method on a Parent Class
- Recipe 8.13: Implementing a Data Model or Type System
- Recipe 8.14: Implementing Custom Containers
- Recipe 9.11: Using comptime to Control Instance Creation

Full compilable example: `code/03-advanced/08-structs-unions-objects/recipe_8_12.zig`
