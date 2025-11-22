## Problem

You need to create struct types dynamically at compile time. You want to generate structs based on configuration, merge multiple structs together, transform field names or types, filter fields by criteria, or create wrapper types without manually writing repetitive struct definitions.

## Solution

Use `@Type` to construct struct types programmatically at compile time. Zig's `@Type` builtin converts type information structures into actual types, enabling dynamic struct generation with zero runtime overhead.

### Basic Struct Creation

Create a simple struct type from scratch:

```zig
{{#include ../../../code/03-advanced/09-metaprogramming/recipe_9_16.zig:basic_struct_creation}}
```

The generated `Point` type is identical to one written manually.

### Variable Number of Fields

Generate structs with dynamic field counts:

```zig
fn createFieldsStruct(comptime count: usize, comptime T: type) type {
    var fields: [count]std.builtin.Type.StructField = undefined;

    for (0..count) |i| {
        const name = std.fmt.comptimePrint("field_{d}", .{i});
        fields[i] = .{
            .name = name,
            .type = T,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(T),
        };
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &fields,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

test "add fields" {
    const ThreeInts = createFieldsStruct(3, i32);
    const data = ThreeInts{
        .field_0 = 1,
        .field_1 = 2,
        .field_2 = 3,
    };

    try testing.expectEqual(@as(i32, 1), data.field_0);
    try testing.expectEqual(@as(i32, 2), data.field_1);
    try testing.expectEqual(@as(i32, 3), data.field_2);
}
```

This is useful for code generation based on configuration.

## Discussion

### Creating Structs from Tuples

Build structs from name-type pairs:

```zig
fn structFromPairs(comptime pairs: anytype) type {
    const fields_tuple = @typeInfo(@TypeOf(pairs)).@"struct".fields;
    var fields: [fields_tuple.len]std.builtin.Type.StructField = undefined;

    inline for (fields_tuple, 0..) |field, i| {
        const pair = @field(pairs, field.name);
        fields[i] = .{
            .name = pair[0],
            .type = pair[1],
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(pair[1]),
        };
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &fields,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

test "struct from tuples" {
    const Person = structFromPairs(.{
        .{ "name", []const u8 },
        .{ "age", u32 },
        .{ "active", bool },
    });

    const person = Person{
        .name = "Alice",
        .age = 30,
        .active = true,
    };

    try testing.expectEqualStrings("Alice", person.name);
    try testing.expectEqual(@as(u32, 30), person.age);
    try testing.expect(person.active);
}
```

This enables DSL-style struct definitions with clean syntax.

### Merging Struct Types

Combine multiple structs into one:

```zig
fn mergeStructs(comptime A: type, comptime B: type) type {
    const a_fields = @typeInfo(A).@"struct".fields;
    const b_fields = @typeInfo(B).@"struct".fields;

    // Check for name collisions
    inline for (a_fields) |a_field| {
        inline for (b_fields) |b_field| {
            if (std.mem.eql(u8, a_field.name, b_field.name)) {
                @compileError("Cannot merge structs: field '" ++ a_field.name ++ "' exists in both types");
            }
        }
    }

    var merged: [a_fields.len + b_fields.len]std.builtin.Type.StructField = undefined;

    inline for (a_fields, 0..) |field, i| {
        merged[i] = field;
    }

    inline for (b_fields, 0..) |field, i| {
        merged[a_fields.len + i] = field;
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &merged,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

test "merge structs" {
    const Position = struct { x: i32, y: i32 };
    const Velocity = struct { dx: f32, dy: f32 };

    const Entity = mergeStructs(Position, Velocity);

    const entity = Entity{
        .x = 10,
        .y = 20,
        .dx = 1.5,
        .dy = 2.5,
    };

    try testing.expectEqual(@as(i32, 10), entity.x);
    try testing.expectEqual(@as(i32, 20), entity.y);
}
```

This is useful for composition patterns and combining domain objects.

### Filtering Fields by Predicate

Select fields matching specific criteria:

```zig
fn filterFields(comptime T: type, comptime predicate: fn (std.builtin.Type.StructField) bool) type {
    const fields = @typeInfo(T).@"struct".fields;

    comptime var count: usize = 0;
    inline for (fields) |field| {
        if (predicate(field)) {
            count += 1;
        }
    }

    var filtered: [count]std.builtin.Type.StructField = undefined;
    comptime var index: usize = 0;
    inline for (fields) |field| {
        if (predicate(field)) {
            filtered[index] = field;
            index += 1;
        }
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &filtered,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

fn isIntegerField(field: std.builtin.Type.StructField) bool {
    return @typeInfo(field.type) == .int or @typeInfo(field.type) == .comptime_int;
}

test "filter fields" {
    const Mixed = struct {
        id: u64,
        name: []const u8,
        count: i32,
        active: bool,
    };

    const IntegersOnly = filterFields(Mixed, isIntegerField);

    const data = IntegersOnly{
        .id = 1,
        .count = 42,
    };

    try testing.expectEqual(@as(u64, 1), data.id);
    try testing.expectEqual(@as(i32, 42), data.count);
}
```

This enables type-based transformations and projections.

### Adding Field Name Prefixes

Transform field names systematically:

```zig
fn prefixFields(comptime T: type, comptime prefix: []const u8) type {
    const fields = @typeInfo(T).@"struct".fields;
    var prefixed: [fields.len]std.builtin.Type.StructField = undefined;

    inline for (fields, 0..) |field, i| {
        prefixed[i] = .{
            .name = prefix ++ field.name,
            .type = field.type,
            .default_value_ptr = null,
            .is_comptime = field.is_comptime,
            .alignment = field.alignment,
        };
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &prefixed,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

test "add prefix" {
    const Original = struct {
        name: []const u8,
        value: i32,
    };

    const Prefixed = prefixFields(Original, "my_");

    const data = Prefixed{
        .my_name = "test",
        .my_value = 42,
    };

    try testing.expectEqualStrings("test", data.my_name);
    try testing.expectEqual(@as(i32, 42), data.my_value);
}
```

This helps with namespace management and avoiding name collisions.

### Wrapping Fields in Optionals

Convert all fields to optional types:

```zig
fn makeFieldsOptional(comptime T: type) type {
    const fields = @typeInfo(T).@"struct".fields;
    var optional_fields: [fields.len]std.builtin.Type.StructField = undefined;

    inline for (fields, 0..) |field, i| {
        optional_fields[i] = .{
            .name = field.name,
            .type = ?field.type,
            .default_value_ptr = null,
            .is_comptime = false,
            .alignment = @alignOf(?field.type),
        };
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &optional_fields,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

test "optional wrapper" {
    const Required = struct {
        name: []const u8,
        age: u32,
    };

    const Optional = makeFieldsOptional(Required);

    const partial = Optional{
        .name = "Alice",
        .age = null,
    };

    try testing.expectEqualStrings("Alice", partial.name.?);
    try testing.expectEqual(@as(?u32, null), partial.age);
}
```

This is useful for builder patterns or partial updates.

### Selecting Specific Fields

Create a struct containing only named fields:

```zig
fn selectFields(comptime T: type, comptime field_names: []const []const u8) type {
    const all_fields = @typeInfo(T).@"struct".fields;
    var selected: [field_names.len]std.builtin.Type.StructField = undefined;

    inline for (field_names, 0..) |name, i| {
        var found = false;
        inline for (all_fields) |field| {
            if (std.mem.eql(u8, field.name, name)) {
                selected[i] = field;
                found = true;
                break;
            }
        }
        if (!found) {
            @compileError("Field '" ++ name ++ "' not found in type " ++ @typeName(T));
        }
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = &selected,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

test "select fields" {
    const Full = struct {
        id: u64,
        name: []const u8,
        email: []const u8,
        age: u32,
        active: bool,
    };

    const Partial = selectFields(Full, &[_][]const u8{ "id", "name", "active" });

    const data = Partial{
        .id = 1,
        .name = "Alice",
        .active = true,
    };

    try testing.expectEqual(@as(u64, 1), data.id);
    try testing.expectEqualStrings("Alice", data.name);
    try testing.expect(data.active);
}
```

This implements projection, useful for API responses or data transfer objects.

### Why This Matters

Programmatic struct creation provides several benefits:

1. **Code Generation** - Generate types from configuration files or schemas
2. **Type Transformations** - Create wrapper types without manual duplication
3. **Composition** - Build complex types from simpler components
4. **DRY Principle** - Avoid repeating similar struct definitions
5. **Compile-Time Validation** - All type errors caught before code runs
6. **Zero Runtime Cost** - All struct generation happens at compile time

### Real-World Applications

These patterns are useful for:

1. **ORM Systems** - Generate database model types from schemas
2. **API Clients** - Create request/response types from API specifications
3. **Serialization** - Generate serialization wrappers automatically
4. **Builder Patterns** - Create optional field versions for builders
5. **Type Safety** - Enforce field presence or absence at compile time
6. **Code Generators** - Build types from external data sources

### Performance Characteristics

All struct generation has zero runtime cost:

- Type construction happens during compilation
- Generated structs are identical to hand-written ones
- No runtime type information needed
- No dynamic dispatch or vtables
- Full compiler optimization applies

The only cost is compile time, which increases with complexity but remains reasonable for most use cases.

### Type System Integration

Generated structs integrate fully with Zig's type system:

- Type inference works normally
- Compiler errors reference generated types
- `@TypeOf` and `@typeInfo` work correctly
- Can be used in generic functions
- Support all struct operations (methods, fields, etc.)

### Limitations and Gotchas

Be aware of these constraints:

1. **Field Names Must Be Compile-Time Known** - Can't generate names from runtime strings
2. **No Circular References** - Generated types can't reference themselves
3. **Type Info Immutable** - Once created, types can't be modified
4. **Error Messages** - Compiler errors may reference generated code locations
5. **Collision Detection** - Check for duplicate field names manually (as shown in `mergeStructs`)

### Combining Patterns

You can chain struct transformations:

```zig
const Base = struct { id: u64, name: []const u8 };
const WithPrefix = prefixFields(Base, "db_");
const Optional = makeFieldsOptional(WithPrefix);

const config = Optional{
    .db_id = 1,
    .db_name = null,
};
```

This enables complex type transformations through composition.

### Field Structure Details

Each `StructField` requires these components:

- **name** - Field name as compile-time string
- **type** - Field type (must be a Zig type)
- **default_value_ptr** - Pointer to default value or null
- **is_comptime** - Whether field is comptime-known
- **alignment** - Field alignment (use `@alignOf(T)`)

All fields must be properly initialized to avoid undefined behavior.

### Debugging Generated Types

Use `@typeName` to inspect generated types:

```zig
const Generated = createFieldsStruct(3, i32);
std.debug.print("Type: {s}\n", .{@typeName(Generated)});
```

This helps understand what the compiler generated.

## See Also

- Recipe 9.12: Capturing struct attribute definition order
- Recipe 9.15: Enforcing coding conventions in structs
- Recipe 9.17: Initializing struct members at definition time

Full compilable example: `code/03-advanced/09-metaprogramming/recipe_9_16.zig`
