## Problem

You want to access elements in a collection by name rather than numeric index, making code more readable and less error-prone.

## Solution

Zig offers several approaches to naming elements, each suited to different situations:

### Approach 1: Structs (Best for Named Records)

Structs provide named fields with full type safety:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_18.zig:named_structs}}
```

### Approach 2: Anonymous Struct Tuples (Best for Temporary Data)

For lightweight data or return values, use anonymous structs:

```zig
fn calculateStats(numbers: []const i32) struct { min: i32, max: i32, avg: f32 } {
    // ... calculation logic ...
    return .{ .min = min, .max = max, .avg = avg };
}

const stats = calculateStats(&numbers);
// Access: stats.min, stats.max, stats.avg
```

### Approach 3: Tagged Unions (Best for Variants)

When data can be one of several types, use tagged unions:

```zig
const Shape = union(enum) {
    circle: struct { radius: f32 },
    rectangle: struct { width: f32, height: f32 },
    triangle: struct { base: f32, height: f32 },

    pub fn area(self: Shape) f32 {
        return switch (self) {
            .circle => |c| std.math.pi * c.radius * c.radius,
            .rectangle => |r| r.width * r.height,
            .triangle => |t| 0.5 * t.base * t.height,
        };
    }
};

const circle = Shape{ .circle = .{ .radius = 5.0 } };
const area = circle.area();
```

### Approach 4: Named Constants for Indices (Best for Existing Arrays)

When working with positional data like CSV, name the indices:

```zig
const CSV_NAME = 0;
const CSV_AGE = 1;
const CSV_EMAIL = 2;

fn parseCSVRow(row: []const []const u8) ?Person {
    if (row.len < 3) return null;

    const age = std.fmt.parseInt(u32, row[CSV_AGE], 10) catch return null;

    return Person{
        .name = row[CSV_NAME],
        .age = age,
        .email = row[CSV_EMAIL],
    };
}
```

### Approach 5: Enum-Indexed Arrays (Type-Safe Indexing)

For fixed-size arrays where indices have meaning, use enum indexing:

```zig
const ColorChannel = enum {
    red,
    green,
    blue,
    alpha,
};

const Color = struct {
    channels: [4]u8,

    pub fn get(self: Color, channel: ColorChannel) u8 {
        return self.channels[@intFromEnum(channel)];
    }

    pub fn set(self: *Color, channel: ColorChannel, value: u8) void {
        self.channels[@intFromEnum(channel)] = value;
    }
};

var color = Color{ .channels = [_]u8{ 255, 128, 64, 255 } };
const red = color.get(.red);
color.set(.green, 200);
```

## Discussion

### Choosing the Right Approach

**Use Structs when:**
- You have a well-defined record type
- You want methods and associated behavior
- You need maximum readability and maintainability
- Type safety and compile-time checks are important

**Use Anonymous Struct Tuples when:**
- Returning multiple values from a function
- Working with temporary data
- You don't want to declare a full struct type
- The data structure is only used in one place

**Use Tagged Unions when:**
- Data can be one of several distinct types
- You need exhaustive matching (compiler ensures all cases handled)
- Different variants have different fields
- Replacing inheritance/polymorphism patterns

**Use Named Constants when:**
- Working with existing positional data (CSV, binary formats)
- Can't change the data structure
- Want better documentation than magic numbers
- Zero runtime cost is critical

**Use Enum-Indexed Arrays when:**
- Fixed-size array with meaningful indices
- Want type-safe indexing
- Prevent invalid indices at compile time
- Clear intent about what each position means

### Memory and Performance

Structs are value types in Zig and are copied when assigned:

```zig
const p1 = Point2D{ .x = 1.0, .y = 2.0 };
var p2 = p1; // Copied
p2.x = 5.0;  // p1 unchanged
```

For large structs, pass by pointer to avoid copying:

```zig
fn processLargeData(data: *const LargeStruct) void {
    // Work with data without copying
}
```

### Optional Fields

Structs can have optional fields using `?T`:

```zig
const OptionalPerson = struct {
    name: []const u8,
    age: u32,
    email: ?[]const u8, // Optional

    pub fn hasEmail(self: @This()) bool {
        return self.email != null;
    }
};

const person = OptionalPerson{
    .name = "Bob",
    .age = 25,
    .email = null,
};
```

### Nested Structures

Structs can contain other structs for complex data modeling:

```zig
const Address = struct {
    street: []const u8,
    city: []const u8,
    zip: []const u8,
};

const Employee = struct {
    name: []const u8,
    id: u32,
    address: Address,
};

const emp = Employee{
    .name = "Alice",
    .id = 12345,
    .address = .{
        .street = "123 Main St",
        .city = "Springfield",
        .zip = "12345",
    },
};
```

### Comparison with Other Languages

Unlike Python's `namedtuple` or JavaScript's object literals, Zig's structs are statically typed and have zero runtime overhead. There's no dictionary lookup or dynamic dispatch - field access compiles to a direct memory offset.

The explicit approach to data modeling in Zig makes code more maintainable and catches errors at compile time rather than runtime.
