## Problem

You want to create custom attribute systems—like validators, serialization metadata, or field annotations—that attach behavior or information to struct fields, similar to decorators or attributes in other languages.

## Solution

Use Zig's comptime reflection via `@typeInfo()` and generic types to build attribute systems. You can introspect struct fields at compile time, create wrapper types with metadata, and generate code based on field characteristics.

### Field Introspection

Use `@typeInfo()` to examine struct fields at compile time:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_9.zig:field_introspection}}
```

This provides runtime access to compile-time field information.

### Custom Tags via Parallel Struct

Create metadata alongside your struct:

```zig
const FieldTags = struct {
    required: bool,
    max_length: ?usize,
    min_value: ?i32,
};

const UserSchema = struct {
    const tags = .{
        .username = FieldTags{ .required = true, .max_length = 50, .min_value = null },
        .email = FieldTags{ .required = true, .max_length = 100, .min_value = null },
        .age = FieldTags{ .required = false, .max_length = null, .min_value = 0 },
    };
};

const User = struct {
    username: []const u8,
    email: []const u8,
    age: u32,

    pub fn getFieldTag(comptime field_name: []const u8) FieldTags {
        return @field(UserSchema.tags, field_name);
    }

    pub fn validate(self: *const User) !void {
        if (self.username.len > UserSchema.tags.username.max_length.?) {
            return error.UsernameTooLong;
        }
        if (self.email.len > UserSchema.tags.email.max_length.?) {
            return error.EmailTooLong;
        }
        if (self.age < UserSchema.tags.age.min_value.?) {
            return error.AgeTooYoung;
        }
    }
};
```

Tags live in a separate schema struct but are accessed through the main type.

### Generic Attribute System

Build reusable attribute wrappers:

```zig
fn Attributed(comptime T: type, comptime Metadata: type) type {
    return struct {
        value: T,
        metadata: Metadata,

        const Self = @This();

        pub fn init(value: T, metadata: Metadata) Self {
            return Self{ .value = value, .metadata = metadata };
        }

        pub fn getValue(self: *const Self) T {
            return self.value;
        }

        pub fn getMetadata(self: *const Self) Metadata {
            return self.metadata;
        }

        pub fn setValue(self: *Self, value: T) void {
            self.value = value;
        }
    };
}

const StringMetadata = struct {
    max_length: usize,
    pattern: []const u8,
};

const ValidatedString = Attributed([]const u8, StringMetadata);
```

This pattern wraps any type with custom metadata.

### Reflection-Based Property Access

Access fields dynamically using `@field()`:

```zig
fn getField(value: anytype, comptime field_name: []const u8) @TypeOf(@field(value, field_name)) {
    return @field(value, field_name);
}

fn setField(value: anytype, comptime field_name: []const u8, new_value: anytype) void {
    @field(value, field_name) = new_value;
}

const Point = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn getByIndex(self: *const Point, index: usize) !f32 {
        return switch (index) {
            0 => self.x,
            1 => self.y,
            2 => self.z,
            else => error.IndexOutOfBounds,
        };
    }

    pub fn setByIndex(self: *Point, index: usize, value: f32) !void {
        switch (index) {
            0 => self.x = value,
            1 => self.y = value,
            2 => self.z = value,
            else => return error.IndexOutOfBounds,
        }
    }
};
```

Combine compile-time and runtime field access for flexible APIs.

### Read-Only Attribute Pattern

Wrap values to enforce immutability:

```zig
fn ReadOnly(comptime T: type) type {
    return struct {
        value: T,

        const Self = @This();

        pub fn init(value: T) Self {
            return Self{ .value = value };
        }

        pub fn get(self: *const Self) T {
            return self.value;
        }

        // No public set method - immutable after init
    };
}

const ImmutableConfig = struct {
    api_key: ReadOnly([]const u8),
    endpoint: ReadOnly([]const u8),

    pub fn init(api_key: []const u8, endpoint: []const u8) ImmutableConfig {
        return ImmutableConfig{
            .api_key = ReadOnly([]const u8).init(api_key),
            .endpoint = ReadOnly([]const u8).init(endpoint),
        };
    }
};
```

The type system enforces read-only semantics.

### Default Value Attribute

Attach default values to fields:

```zig
fn WithDefault(comptime T: type, comptime default_value: T) type {
    return struct {
        value: T,

        const Self = @This();
        const default = default_value;

        pub fn init() Self {
            return Self{ .value = default };
        }

        pub fn initWithValue(value: T) Self {
            return Self{ .value = value };
        }

        pub fn get(self: *const Self) T {
            return self.value;
        }

        pub fn set(self: *Self, value: T) void {
            self.value = value;
        }

        pub fn reset(self: *Self) void {
            self.value = default;
        }
    };
}

const Settings = struct {
    timeout: WithDefault(u32, 5000),
    retries: WithDefault(u8, 3),

    pub fn init() Settings {
        return Settings{
            .timeout = WithDefault(u32, 5000).init(),
            .retries = WithDefault(u8, 3).init(),
        };
    }
};
```

Each field carries its default value and can reset to it.

## Discussion

Zig's comptime system provides powerful metaprogramming capabilities that enable custom attribute systems without language-level attribute syntax.

### Key Techniques

1. **`@typeInfo()`** - Introspect types at compile time
2. **`@field()`** - Access fields by comptime-known names
3. **Generic wrapper types** - Add behavior through composition
4. **Parallel metadata structs** - Store field-level information separately
5. **`inline for`** - Iterate over fields at compile time

### Advantages

- **Zero runtime cost** - All attribute logic runs at compile time
- **Type safety** - Compile errors for invalid field access
- **Flexibility** - Create any attribute system you need
- **Composability** - Combine multiple attribute wrappers
- **No magic** - Explicit, visible attribute definitions

### Common Patterns

**Validation**: Use tags to define constraints, validate in methods
**Serialization**: Generate serialization code from field metadata
**Documentation**: Attach descriptions and annotations to fields
**Defaults**: Wrapper types with default values
**Immutability**: Types that only expose getters

### Limitations

- Field names must be known at compile time for `@field()`
- Cannot add fields dynamically at runtime
- Metadata must be defined alongside struct definition
- More verbose than language-level attribute syntax

### Performance

All attribute systems shown here have zero runtime overhead:
- Type introspection happens at compile time
- Generic wrappers inline into containing structs
- Metadata lookups resolve to constants

## See Also

- Recipe 8.6: Creating Managed Attributes
- Recipe 8.13: Implementing a Data Model or Type System
- Recipe 9.11: Using comptime to Control Instance Creation
- Recipe 9.16: Defining Structs Programmatically

Full compilable example: `code/03-advanced/08-structs-unions-objects/recipe_8_9.zig`
