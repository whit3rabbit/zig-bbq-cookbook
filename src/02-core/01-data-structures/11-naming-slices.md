# Naming Slices and Indices

## Problem

You have code that accesses specific positions or ranges in a slice using numeric literals, making it hard to understand what those positions represent.

## Solution

Use named constants to give meaningful names to indices and ranges:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_11.zig:named_indices}}
    std.debug.print("Date:  {s}\n", .{date});
}
```

## Discussion

### Basic Named Indices

Replace magic numbers with descriptive constants:

```zig
const data = [_]i32{ 100, 200, 300, 400, 500 };

// Instead of: const value = data[2];
const INDEX_PRICE = 2;
const price = data[INDEX_PRICE];
```

### Named Slice Ranges

Define meaningful ranges as constants:

```zig
// CSV record: "Alice,30,Engineer,New York"
const record = "Alice,30,Engineer,New York";

const NAME_START = 0;
const NAME_END = 5;
const AGE_START = 6;
const AGE_END = 8;
const ROLE_START = 9;
const ROLE_END = 17;
const CITY_START = 18;

const name = record[NAME_START..NAME_END];
const age_str = record[AGE_START..AGE_END];
const role = record[ROLE_START..ROLE_END];
const city = record[CITY_START..];
```

### Struct-Based Field Descriptors

For more complex data layouts, use structs:

```zig
const FieldRange = struct {
    start: usize,
    end: usize,

    pub fn slice(self: FieldRange, data: []const u8) []const u8 {
        return data[self.start..self.end];
    }

    pub fn sliceTrimmed(self: FieldRange, data: []const u8) []const u8 {
        return std.mem.trim(u8, data[self.start..self.end], " ");
    }
};

const Fields = struct {
    const name = FieldRange{ .start = 0, .end = 20 };
    const address = FieldRange{ .start = 20, .end = 50 };
    const phone = FieldRange{ .start = 50, .end = 62 };
};

fn parseRecord(record: []const u8) void {
    const name = Fields.name.sliceTrimmed(record);
    const address = Fields.address.sliceTrimmed(record);
    const phone = Fields.phone.sliceTrimmed(record);

    std.debug.print("Name: {s}\n", .{name});
    std.debug.print("Address: {s}\n", .{address});
    std.debug.print("Phone: {s}\n", .{phone});
}
```

### Named Array Positions

For arrays with semantic meaning at each position:

```zig
const RGB = struct {
    const RED = 0;
    const GREEN = 1;
    const BLUE = 2;
};

fn adjustBrightness(color: *[3]u8, factor: f32) void {
    color[RGB.RED] = @intFromFloat(@as(f32, @floatFromInt(color[RGB.RED])) * factor);
    color[RGB.GREEN] = @intFromFloat(@as(f32, @floatFromInt(color[RGB.GREEN])) * factor);
    color[RGB.BLUE] = @intFromFloat(@as(f32, @floatFromInt(color[RGB.BLUE])) * factor);
}
```

### Comptime Slice Descriptors

Use comptime for zero-cost abstractions:

```zig
fn Field(comptime start: usize, comptime end: usize) type {
    return struct {
        pub inline fn get(data: []const u8) []const u8 {
            return data[start..end];
        }

        pub inline fn getTrimmed(data: []const u8) []const u8 {
            return std.mem.trim(u8, data[start..end], " ");
        }

        pub const range = .{ start, end };
        pub const length = end - start;
    };
}

const Record = struct {
    pub const Name = Field(0, 20);
    pub const Email = Field(20, 50);
    pub const Age = Field(50, 53);
};

fn processRecord(data: []const u8) void {
    const name = Record.Name.getTrimmed(data);
    const email = Record.Email.getTrimmed(data);
    const age_str = Record.Age.get(data);

    // Comptime-known field length
    comptime {
        std.debug.assert(Record.Name.length == 20);
    }
}
```

### Binary Protocol Fields

Naming fields in binary data:

```zig
const PacketHeader = struct {
    const VERSION_BYTE = 0;
    const TYPE_BYTE = 1;
    const LENGTH_START = 2;
    const LENGTH_END = 4;
    const CHECKSUM_START = 4;
    const CHECKSUM_END = 8;
    const PAYLOAD_START = 8;

    pub fn version(packet: []const u8) u8 {
        return packet[VERSION_BYTE];
    }

    pub fn packetType(packet: []const u8) u8 {
        return packet[TYPE_BYTE];
    }

    pub fn length(packet: []const u8) u16 {
        return std.mem.readInt(u16, packet[LENGTH_START..LENGTH_END][0..2], .big);
    }

    pub fn checksum(packet: []const u8) u32 {
        return std.mem.readInt(u32, packet[CHECKSUM_START..CHECKSUM_END][0..4], .big);
    }

    pub fn payload(packet: []const u8) []const u8 {
        return packet[PAYLOAD_START..];
    }
};
```

### Matrix/Grid Access

Naming positions in 2D data stored in 1D arrays:

```zig
const Grid = struct {
    data: []i32,
    width: usize,
    height: usize,

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Grid {
        return Grid{
            .data = try allocator.alloc(i32, width * height),
            .width = width,
            .height = height,
        };
    }

    pub fn deinit(self: *Grid, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }

    pub fn index(self: Grid, row: usize, col: usize) usize {
        return row * self.width + col;
    }

    pub fn get(self: Grid, row: usize, col: usize) i32 {
        return self.data[self.index(row, col)];
    }

    pub fn set(self: *Grid, row: usize, col: usize, value: i32) void {
        self.data[self.index(row, col)] = value;
    }

    pub fn row(self: Grid, row_num: usize) []i32 {
        const start = row_num * self.width;
        return self.data[start..][0..self.width];
    }
};
```

### Fixed-Width Record Parser

Parse fixed-width records with named fields:

```zig
const RecordParser = struct {
    const Field = struct {
        name: []const u8,
        start: usize,
        length: usize,

        pub fn extract(self: Field, record: []const u8) []const u8 {
            return std.mem.trim(u8, record[self.start..][0..self.length], " ");
        }
    };

    fields: []const Field,

    pub fn parse(self: RecordParser, record: []const u8, allocator: std.mem.Allocator) !std.StringHashMap([]const u8) {
        var result = std.StringHashMap([]const u8).init(allocator);
        errdefer result.deinit();

        for (self.fields) |field| {
            const value = field.extract(record);
            try result.put(field.name, value);
        }

        return result;
    }
};

// Usage
const employee_fields = [_]RecordParser.Field{
    .{ .name = "id", .start = 0, .length = 6 },
    .{ .name = "name", .start = 6, .length = 30 },
    .{ .name = "department", .start = 36, .length = 20 },
    .{ .name = "salary", .start = 56, .length = 10 },
};

const parser = RecordParser{ .fields = &employee_fields };
```

### Enum-Based Indexing

Use enums for type-safe array indexing:

```zig
const Stat = enum(usize) {
    health = 0,
    mana = 1,
    stamina = 2,
    strength = 3,

    pub fn get(self: Stat, stats: []const i32) i32 {
        return stats[@intFromEnum(self)];
    }

    pub fn set(self: Stat, stats: []i32, value: i32) void {
        stats[@intFromEnum(self)] = value;
    }
};

fn updateCharacter(stats: []i32) void {
    // Much clearer than stats[0], stats[1], etc.
    Stat.health.set(stats, Stat.health.get(stats) + 10);
    Stat.mana.set(stats, Stat.mana.get(stats) - 5);
}
```

### Re-slicing with Named Offsets

Create sub-slices with meaningful names:

```zig
const HttpRequest = struct {
    raw: []const u8,

    pub fn method(self: HttpRequest) ?[]const u8 {
        const space_pos = std.mem.indexOfScalar(u8, self.raw, ' ') orelse return null;
        return self.raw[0..space_pos];
    }

    pub fn path(self: HttpRequest) ?[]const u8 {
        const first_space = std.mem.indexOfScalar(u8, self.raw, ' ') orelse return null;
        const remaining = self.raw[first_space + 1..];
        const second_space = std.mem.indexOfScalar(u8, remaining, ' ') orelse return null;
        return remaining[0..second_space];
    }

    pub fn version(self: HttpRequest) ?[]const u8 {
        const first_space = std.mem.indexOfScalar(u8, self.raw, ' ') orelse return null;
        const remaining = self.raw[first_space + 1..];
        const second_space = std.mem.indexOfScalar(u8, remaining, ' ') orelse return null;
        const after_path = remaining[second_space + 1..];
        const newline = std.mem.indexOfScalar(u8, after_path, '\n') orelse return null;
        return std.mem.trim(u8, after_path[0..newline], "\r");
    }
};
```

### Performance Considerations

Named indices and slices have zero runtime cost:
- Constants are resolved at compile time
- Inline functions are inlined by the compiler
- No extra allocations or indirection

### Best Practices

1. **Use ALL_CAPS** for constant indices
2. **Use descriptive names** that explain what the data represents
3. **Group related constants** in structs or namespaces
4. **Prefer comptime** when possible for zero-cost abstractions
5. **Document the data format** if working with fixed-width records
6. **Use enums** for finite sets of named positions
7. **Add assertions** to validate data layout assumptions

### Common Patterns

```zig
// CSV column indices
const CSV = struct {
    const NAME = 0;
    const AGE = 1;
    const EMAIL = 2;
    const PHONE = 3;
};

// Time components in array
const Time = struct {
    const HOUR = 0;
    const MINUTE = 1;
    const SECOND = 2;
};

// RGB color components
const Color = struct {
    const R = 0;
    const G = 1;
    const B = 2;
    const A = 3;
};

// Fixed-format positions
const Position = struct {
    const HEADER_START = 0;
    const HEADER_END = 32;
    const BODY_START = 32;
};
```

## See Also

- Recipe 1.2: Working with Arbitrary-Length Iterables
- Recipe 2.11: Combining and Concatenating Strings
- Recipe 5.8: Iterating Over Fixed-Sized Records

Full compilable example: `code/02-core/01-data-structures/recipe_1_11.zig`
