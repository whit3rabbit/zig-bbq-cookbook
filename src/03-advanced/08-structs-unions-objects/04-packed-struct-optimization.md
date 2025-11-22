## Problem

You need to create thousands or millions of instances of a struct and want to minimize memory usage.

## Solution

Use `packed struct` to eliminate padding and control memory layout at the bit level:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_4.zig:basic_packed}}
```

## Discussion

### Understanding Packed Struct Alignment

Packed structs eliminate padding between fields, but the compiler may still align the overall struct to natural boundaries for performance. The actual size depends on the target architecture and field types.

```zig
test "packed struct alignment" {
    const Small = packed struct {
        a: bool,
        b: bool,
        c: bool,
    };

    // Might be 1 byte or padded to 2/4 bytes depending on alignment
    const size = @sizeOf(Small);
    try std.testing.expect(size >= 1);
}
```

### Normal vs Packed Structs

Compare memory layout of normal and packed structs:

```zig
const NormalFlags = struct {
    is_active: bool,
    is_visible: bool,
    is_enabled: bool,
    count: u8,
};

const PackedFlags = packed struct {
    is_active: bool,
    is_visible: bool,
    is_enabled: bool,
    count: u5,
};

test "normal vs packed" {
    // Normal struct has padding for alignment
    const normal_size = @sizeOf(NormalFlags);
    try std.testing.expect(normal_size >= 4);

    // Packed struct uses exact bits needed
    const packed_size = @sizeOf(PackedFlags);
    try std.testing.expectEqual(@as(usize, 1), packed_size);

    // Memory savings when creating many instances
    const num_instances = 1000000;
    const normal_memory = normal_size * num_instances;
    const packed_memory = packed_size * num_instances;

    std.debug.print(
        "Normal: {} bytes, Packed: {} bytes, Savings: {} bytes\n",
        .{ normal_memory, packed_memory, normal_memory - packed_memory },
    );
}
```

### Bit Field Packing

Pack multiple small values into minimal space:

```zig
const RGBColor = packed struct {
    red: u8,
    green: u8,
    blue: u8,

    // Takes exactly 3 bytes
};

const CompactColor = packed struct {
    red: u5,    // 0-31
    green: u6,  // 0-63
    blue: u5,   // 0-31

    // Takes exactly 2 bytes (16 bits)
};

test "color packing" {
    try std.testing.expectEqual(@as(usize, 3), @sizeOf(RGBColor));
    try std.testing.expectEqual(@as(usize, 2), @sizeOf(CompactColor));

    const color = CompactColor{
        .red = 31,
        .green = 63,
        .blue = 31,
    };

    try std.testing.expectEqual(@as(u5, 31), color.red);
    try std.testing.expectEqual(@as(u6, 63), color.green);
}
```

### Network Protocol Headers

Pack protocol headers efficiently:

```zig
const PacketHeader = packed struct {
    version: u4,        // 0-15
    packet_type: u4,    // 0-15
    flags: u8,
    length: u16,

    // Total: 4 bytes
};

test "packet header" {
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(PacketHeader));

    const header = PacketHeader{
        .version = 1,
        .packet_type = 5,
        .flags = 0x80,
        .length = 1024,
    };

    // Can cast directly to bytes for network transmission
    const bytes: *const [4]u8 = @ptrCast(&header);
    _ = bytes;
}
```

### Game Entity Flags

Optimize game entity states:

```zig
const Entity = packed struct {
    // Movement
    can_move: bool,
    can_jump: bool,
    can_fly: bool,
    can_swim: bool,

    // Combat
    is_hostile: bool,
    is_invulnerable: bool,
    can_attack: bool,
    _padding1: bool,

    // Visibility
    is_visible: bool,
    casts_shadow: bool,
    receives_shadow: bool,
    _padding2: u5,

    // Stats (fit in remaining bits)
    health_percent: u8,  // 0-255

    // Total: 3 bytes per entity
};

test "game entity" {
    try std.testing.expectEqual(@as(usize, 3), @sizeOf(Entity));

    var entity = Entity{
        .can_move = true,
        .can_jump = true,
        .can_fly = false,
        .can_swim = false,
        .is_hostile = true,
        .is_invulnerable = false,
        .can_attack = true,
        ._padding1 = false,
        .is_visible = true,
        .casts_shadow = true,
        .receives_shadow = true,
        ._padding2 = 0,
        .health_percent = 100,
    };

    try std.testing.expect(entity.can_move);
    try std.testing.expectEqual(@as(u8, 100), entity.health_percent);

    entity.health_percent = 50;
    try std.testing.expectEqual(@as(u8, 50), entity.health_percent);
}
```

### File Format Structures

Pack file format metadata:

```zig
const FileHeader = packed struct {
    magic: u32,
    version_major: u8,
    version_minor: u8,
    flags: u16,
    entry_count: u32,
    reserved: u64,

    // Total: 16 bytes
};

test "file header" {
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(FileHeader));

    const header = FileHeader{
        .magic = 0x12345678,
        .version_major = 1,
        .version_minor = 0,
        .flags = 0,
        .entry_count = 42,
        .reserved = 0,
    };

    try std.testing.expectEqual(@as(u32, 0x12345678), header.magic);
}
```

### Enum-Based Bit Packing

Use enums with explicit bit widths:

```zig
const Priority = enum(u2) {
    low = 0,
    medium = 1,
    high = 2,
    critical = 3,
};

const Status = enum(u2) {
    idle = 0,
    running = 1,
    paused = 2,
    stopped = 3,
};

const Task = packed struct {
    priority: Priority,
    status: Status,
    is_async: bool,
    is_cancellable: bool,
    progress: u8,  // 0-255 percent
    _padding: u4,

    // Total: 2 bytes
};

test "task packing" {
    try std.testing.expectEqual(@as(usize, 2), @sizeOf(Task));

    const task = Task{
        .priority = .high,
        .status = .running,
        .is_async = true,
        .is_cancellable = true,
        .progress = 75,
        ._padding = 0,
    };

    try std.testing.expectEqual(Priority.high, task.priority);
    try std.testing.expectEqual(Status.running, task.status);
}
```

### Date/Time Packing

Pack date and time efficiently:

```zig
const CompactDateTime = packed struct {
    year: u12,   // 0-4095 (supports years 0-4095)
    month: u4,   // 1-12
    day: u5,     // 1-31
    hour: u5,    // 0-23
    minute: u6,  // 0-59
    second: u6,  // 0-59

    // Total: 38 bits = 5 bytes (rounded up)
};

test "datetime packing" {
    const dt = CompactDateTime{
        .year = 2024,
        .month = 11,
        .day = 13,
        .hour = 14,
        .minute = 30,
        .second = 45,
    };

    try std.testing.expectEqual(@as(u12, 2024), dt.year);
    try std.testing.expectEqual(@as(u4, 11), dt.month);
    try std.testing.expectEqual(@as(u5, 13), dt.day);
}
```

### Permission Bits

Pack Unix-style permissions:

```zig
const Permissions = packed struct {
    // Owner
    owner_read: bool,
    owner_write: bool,
    owner_execute: bool,

    // Group
    group_read: bool,
    group_write: bool,
    group_execute: bool,

    // Others
    others_read: bool,
    others_write: bool,
    others_execute: bool,

    // Special bits
    setuid: bool,
    setgid: bool,
    sticky: bool,

    _padding: u4,

    // Total: 2 bytes
};

test "permissions" {
    try std.testing.expectEqual(@as(usize, 2), @sizeOf(Permissions));

    const perms = Permissions{
        .owner_read = true,
        .owner_write = true,
        .owner_execute = true,
        .group_read = true,
        .group_write = false,
        .group_execute = true,
        .others_read = true,
        .others_write = false,
        .others_execute = false,
        .setuid = false,
        .setgid = false,
        .sticky = false,
        ._padding = 0,
    };

    try std.testing.expect(perms.owner_read);
    try std.testing.expect(!perms.group_write);
}
```

### Struct Field Ordering

Optimize normal struct layout by ordering fields:

```zig
const UnoptimizedStruct = struct {
    flag1: bool,  // 1 byte + 7 padding
    value1: u64,  // 8 bytes (aligned to 8)
    flag2: bool,  // 1 byte + 7 padding
    value2: u64,  // 8 bytes (aligned to 8)
    // Total: ~32 bytes
};

const OptimizedStruct = struct {
    value1: u64,  // 8 bytes
    value2: u64,  // 8 bytes
    flag1: bool,  // 1 byte
    flag2: bool,  // 1 byte + 6 padding
    // Total: ~24 bytes
};

test "field ordering" {
    const unopt_size = @sizeOf(UnoptimizedStruct);
    const opt_size = @sizeOf(OptimizedStruct);

    std.debug.print(
        "Unoptimized: {} bytes, Optimized: {} bytes\n",
        .{ unopt_size, opt_size },
    );

    // Optimized struct is smaller due to better field ordering
    try std.testing.expect(opt_size <= unopt_size);
}
```

### Array of Structs Optimization

Compare memory usage for arrays:

```zig
test "array memory comparison" {
    const NormalItem = struct {
        active: bool,
        id: u16,
        flags: u8,
    };

    const PackedItem = packed struct {
        active: bool,
        id: u16,
        flags: u8,
    };

    const count = 10000;

    const normal_total = @sizeOf(NormalItem) * count;
    const packed_total = @sizeOf(PackedItem) * count;

    std.debug.print(
        "Array of {}: Normal {} bytes, Packed {} bytes\n",
        .{ count, normal_total, packed_total },
    );
}
```

### Best Practices

**When to Use Packed Structs:**
- Large arrays of data structures
- Network protocol headers
- File format structures
- Embedded systems with limited memory
- Game entities with many boolean flags

**Trade-offs:**
```zig
// Packed struct cons:
// - Slower access (may require bit manipulation)
// - Cannot take address of fields
// - May not work with @alignOf expectations

// Good use case - millions of instances
const Good = packed struct {
    flags: u8,
    id: u16,
};

// Bad use case - single instance
const Bad = packed struct {
    single_flag: bool,
};
```

**Padding Management:**
```zig
// Explicitly pad to byte boundaries when needed
const Padded = packed struct {
    value1: u5,
    value2: u5,
    _padding: u6,  // Explicitly pad to 16 bits
};
```

**Testing Memory Layout:**
```zig
test "verify size" {
    const MyStruct = packed struct {
        field1: u8,
        field2: u8,
    };

    // Always verify expected size
    try std.testing.expectEqual(@as(usize, 2), @sizeOf(MyStruct));
}
```

**Type Safety:**
```zig
// Use explicit types for bit fields
const Config = packed struct {
    mode: u2,    // Better than anonymous bits
    level: u4,
    _pad: u2,
};
```

### Related Patterns

- Recipe 8.1: String representation of instances
- Recipe 8.19: Implementing state machines
- Chapter 18: Explicit Memory Management Patterns
