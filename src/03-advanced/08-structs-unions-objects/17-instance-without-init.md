## Problem

You want to create struct instances without calling an init function, either for performance, flexibility, or because you're working with external data formats.

## Solution

Zig allows direct struct initialization using struct literals, special initialization patterns, and compile-time techniques. Choose the right approach based on your needs.

### Direct Struct Literals

Create structs inline without any function call:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_17.zig:direct_literal}}
```

The compiler treats both the same way. Direct literals are useful when init() doesn't provide value.

### Undefined Initialization

Leave fields uninitialized when you'll overwrite them immediately:

```zig
const Buffer = struct {
    data: [1024]u8,
    len: usize,

    pub fn init() Buffer {
        return Buffer{
            .data = undefined,  // Don't waste time zeroing
            .len = 0,
        };
    }

    pub fn uninitialized() Buffer {
        var buf: Buffer = undefined;
        buf.len = 0;  // Only initialize what matters
        return buf;
    }
};
```

Using `undefined` skips initialization overhead for data you'll replace anyway.

### Zero Initialization

Initialize all fields to zero using std.mem.zeroes:

```zig
const Counters = struct {
    success: u32,
    failure: u32,
    pending: u32,

    pub fn init() Counters {
        return Counters{
            .success = 0,
            .failure = 0,
            .pending = 0,
        };
    }

    pub fn zero() Counters {
        return std.mem.zeroes(Counters);
    }
};
```

`std.mem.zeroes()` sets all bytes to zero, perfect for resetting state or initializing counters.

### Deserialize From Bytes

Create instances directly from byte arrays:

```zig
const Header = struct {
    magic: u32,
    version: u16,
    flags: u16,

    pub fn fromBytes(bytes: []const u8) !Header {
        if (bytes.len < @sizeOf(Header)) return error.TooSmall;

        return Header{
            .magic = std.mem.readInt(u32, bytes[0..4], .little),
            .version = std.mem.readInt(u16, bytes[4..6], .little),
            .flags = std.mem.readInt(u16, bytes[6..8], .little),
        };
    }

    pub fn fromBytesUnsafe(bytes: *const [@sizeOf(Header)]u8) *const Header {
        return @ptrCast(@alignCast(bytes));
    }
};
```

Parse binary formats directly into structs.

### Object Pool Pattern

Reuse instances without re-initialization:

```zig
const PooledObject = struct {
    id: u32,
    data: [64]u8,
    in_use: bool,

    pub fn reset(self: *PooledObject) void {
        self.in_use = false;
        @memset(&self.data, 0);
    }

    pub fn acquire(self: *PooledObject, id: u32) void {
        self.id = id;
        self.in_use = true;
    }
};

const ObjectPool = struct {
    objects: [10]PooledObject,

    pub fn init() ObjectPool {
        var pool = ObjectPool{
            .objects = undefined,
        };

        for (&pool.objects, 0..) |*obj, i| {
            obj.* = PooledObject{
                .id = @intCast(i),
                .data = undefined,
                .in_use = false,
            };
        }

        return pool;
    }

    pub fn acquire(self: *ObjectPool) ?*PooledObject {
        for (&self.objects) |*obj| {
            if (!obj.in_use) {
                obj.in_use = true;
                return obj;
            }
        }
        return null;
    }
};
```

Pools recycle objects, avoiding repeated initialization costs.

### Compile-Time Instances

Create instances at compile time as constants:

```zig
const Config = struct {
    max_connections: u32,
    timeout_ms: u32,
    buffer_size: usize,

    pub fn default() Config {
        return Config{
            .max_connections = 100,
            .timeout_ms = 5000,
            .buffer_size = 4096,
        };
    }
};

// Created at compile time
const global_config = Config{
    .max_connections = 50,
    .timeout_ms = 3000,
    .buffer_size = 2048,
};

const default_config = Config.default();
```

Compile-time instances have zero runtime cost.

### Placement Initialization

Initialize a struct in-place:

```zig
const Node = struct {
    value: i32,
    next: ?*Node,

    pub fn initInPlace(self: *Node, value: i32) void {
        self.* = Node{
            .value = value,
            .next = null,
        };
    }
};

// Initialize in existing storage
var storage: Node = undefined;
storage.initInPlace(42);

// Or direct assignment
var storage2: Node = undefined;
storage2 = Node{ .value = 100, .next = null };
```

Useful when working with pre-allocated memory.

### Default Struct Values

Leverage Zig's default field values:

```zig
const Settings = struct {
    name: []const u8 = "default",
    enabled: bool = true,
    count: u32 = 0,
};

// Uses all defaults
const s1: Settings = .{};

// Override some fields, others use defaults
const s2: Settings = .{ .name = "custom", .count = 10 };
```

Default values make partial initialization ergonomic.

### Copy From Another Instance

Create copies efficiently:

```zig
const Matrix = struct {
    data: [9]f32,

    pub fn identity() Matrix {
        return Matrix{
            .data = [_]f32{
                1, 0, 0,
                0, 1, 0,
                0, 0, 1,
            },
        };
    }

    pub fn copyFrom(other: *const Matrix) Matrix {
        var m: Matrix = undefined;
        @memcpy(&m.data, &other.data);
        return m;
    }

    pub fn clone(self: *const Matrix) Matrix {
        return self.*;  // Simple copy
    }
};
```

Copying structs is a simple value copy in Zig.

### Tagged Union Initialization

Initialize unions without explicit constructors:

```zig
const Message = union(enum) {
    text: []const u8,
    number: i32,
    flag: bool,

    pub fn initText(content: []const u8) Message {
        return .{ .text = content };
    }
};

// Direct initialization
const m1: Message = .{ .text = "hello" };
const m2: Message = .{ .number = 42 };

// Or using constructors
const m3 = Message.initText("world");
```

Unions support direct initialization with the tag specified.

### Reinterpret Bytes as Struct

Convert raw bytes into struct layout:

```zig
const Packet = struct {
    type_id: u8,
    length: u16,
    payload: [5]u8,

    pub fn fromMemory(ptr: *const anyopaque) *const Packet {
        return @ptrCast(@alignCast(ptr));
    }

    pub fn fromBytes(bytes: *const [8]u8) Packet {
        return Packet{
            .type_id = bytes[0],
            .length = std.mem.readInt(u16, bytes[1..3], .little),
            .payload = bytes[3..8].*,
        };
    }
};
```

Reinterpret memory as structured data when working with binary formats.

## Discussion

Zig gives you fine control over how and when structs are initialized.

### When to Skip Init

**Performance-critical paths**: Avoid unnecessary zero-initialization
```zig
var buffer: [4096]u8 = undefined;  // Fast
var buffer: [4096]u8 = [_]u8{0} ** 4096;  // Slow
```

**Object pools**: Reuse instances without re-initializing
```zig
const obj = pool.acquire();  // Gets recycled object
obj.reset();  // Only reset what changed
```

**Working with external data**: Deserialize from bytes
```zig
const header = try Header.fromBytes(network_data);
```

**Compile-time constants**: Create at comptime for zero runtime cost
```zig
const config = Config{ .port = 8080, ... };  // Built into binary
```

### Initialization Techniques

**Undefined** (`undefined`):
- Use when you'll immediately overwrite
- Fastest option
- Dangerous if you forget to initialize

**Zero** (`std.mem.zeroes`):
- Sets all bytes to zero
- Safe default for numeric types
- Overhead for large structures

**Direct literal** (`.{ .field = value }`):
- Explicit and clear
- Compile-time checked
- Same as calling init()

**Copy** (`instance.*` or `@memcpy`):
- Simple value copy
- Fast for small structs
- Consider pointers for large structs

### Safety Considerations

**Undefined is dangerous**:
```zig
var x: i32 = undefined;
std.debug.print("{}", .{x});  // Undefined behavior!
```

Only use `undefined` when you'll initialize before reading.

**Alignment matters for reinterpretation**:
```zig
// Safe - explicit alignment
const ptr: *align(@alignOf(Header)) const u8 = data.ptr;
const header: *const Header = @ptrCast(@alignCast(ptr));

// Unsafe - might crash
const header: *const Header = @ptrCast(data.ptr);
```

Always use `@alignCast` when reinterpreting pointers.

### Performance Implications

**Compile-time initialization**: Zero runtime cost
```zig
const config = Config{ .port = 8080 };  // Embedded in binary
```

**Zero initialization**: Memset overhead
```zig
const zeroed = std.mem.zeroes(LargeStruct);  // Runtime cost
```

**Undefined initialization**: Zero cost but must initialize before use
```zig
var buffer: [1024]u8 = undefined;  // Instant
buffer[0] = 42;  // Now safe to use buffer[0]
```

**Direct struct literals**: Same as init(), often inlined
```zig
const p = Point{ .x = 1, .y = 2 };  // Typically inlined
```

### When to Use Each Pattern

Use **direct literals** when:
- Init doesn't provide value
- You want explicit field values
- Working with small structs

Use **undefined** when:
- Performance critical
- You'll immediately overwrite
- Working with large arrays

Use **std.mem.zeroes** when:
- You want a clean slate
- Struct has many fields
- Safety over performance

Use **comptime instances** when:
- Values never change
- Configuration constants
- Zero runtime cost desired

## See Also

- Recipe 8.16: Defining More Than One Constructor in a Class
- Recipe 8.11: Simplifying the Initialization of Data Structures
- Recipe 8.14: Implementing Custom Containers
- Recipe 9.11: Using comptime to Control Instance Creation

Full compilable example: `code/03-advanced/08-structs-unions-objects/recipe_8_17.zig`
