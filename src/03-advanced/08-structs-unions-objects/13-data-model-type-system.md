## Problem

You need to create a data model with validation rules, type constraints, relationships, and serialization—similar to ORMs or schema validation libraries in other languages.

## Solution

Use Zig's type system to enforce constraints at compile time and runtime, combining validation, typed wrappers, and builder patterns to create robust data models.

### Basic Field Validation

Start with simple validation in the init method:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_13.zig:basic_validation}}
```

This ensures invalid users can never be created.

### Typed Fields with Validation

Wrap primitive types in validation-enforcing structs:

```zig
const Email = struct {
    value: []const u8,

    pub fn init(value: []const u8) !Email {
        if (value.len == 0) return error.EmptyEmail;
        if (std.mem.indexOf(u8, value, "@") == null) return error.InvalidFormat;
        if (std.mem.indexOf(u8, value, ".") == null) return error.InvalidFormat;
        return Email{ .value = value };
    }

    pub fn getValue(self: *const Email) []const u8 {
        return self.value;
    }
};

const Username = struct {
    value: []const u8,

    pub fn init(value: []const u8) !Username {
        if (value.len < 3) return error.TooShort;
        if (value.len > 20) return error.TooLong;
        for (value) |c| {
            if (!std.ascii.isAlphanumeric(c) and c != '_') {
                return error.InvalidCharacter;
            }
        }
        return Username{ .value = value };
    }
};

const ValidatedUser = struct {
    username: Username,
    email: Email,

    pub fn init(username: []const u8, email: []const u8) !ValidatedUser {
        return ValidatedUser{
            .username = try Username.init(username),
            .email = try Email.init(email),
        };
    }
};
```

The type system enforces that only valid usernames and emails exist.

### Enum-Based State Constraints

Use enums to enforce valid state transitions:

```zig
const Status = enum {
    draft,
    published,
    archived,

    pub fn canTransitionTo(self: Status, target: Status) bool {
        return switch (self) {
            .draft => target == .published or target == .archived,
            .published => target == .archived,
            .archived => false,
        };
    }
};

const Document = struct {
    title: []const u8,
    content: []const u8,
    status: Status,

    pub fn init(title: []const u8, content: []const u8) Document {
        return Document{
            .title = title,
            .content = content,
            .status = .draft,
        };
    }

    pub fn changeStatus(self: *Document, new_status: Status) !void {
        if (!self.status.canTransitionTo(new_status)) {
            return error.InvalidTransition;
        }
        self.status = new_status;
    }
};
```

Invalid state transitions return errors at runtime.

### Schema Validation with Comptime

Enforce schema requirements at compile time:

```zig
fn validateSchema(comptime T: type) void {
    const info = @typeInfo(T);
    if (info != .@"struct") {
        @compileError("Schema validation only works on structs");
    }

    // Ensure required fields exist
    var has_id = false;
    inline for (info.@"struct".fields) |field| {
        if (std.mem.eql(u8, field.name, "id")) {
            has_id = true;
            if (field.type != u32) {
                @compileError("id field must be u32");
            }
        }
    }

    if (!has_id) {
        @compileError("Schema must have 'id' field");
    }
}

const Product = struct {
    id: u32,
    name: []const u8,
    price: f64,

    comptime {
        validateSchema(@This());
    }
};
```

Schemas are validated at compile time—invalid schemas won't compile.

### Builder Pattern with Progressive Validation

Validate each field as it's set:

```zig
const Person = struct {
    first_name: []const u8,
    last_name: []const u8,
    email: []const u8,
    age: u8,

    pub const Builder = struct {
        first_name: ?[]const u8 = null,
        last_name: ?[]const u8 = null,
        email: ?[]const u8 = null,
        age: ?u8 = null,

        pub fn setFirstName(self: *Builder, name: []const u8) !*Builder {
            if (name.len == 0) return error.EmptyFirstName;
            self.first_name = name;
            return self;
        }

        pub fn setEmail(self: *Builder, email: []const u8) !*Builder {
            if (std.mem.indexOf(u8, email, "@") == null) {
                return error.InvalidEmail;
            }
            self.email = email;
            return self;
        }

        pub fn build(self: *const Builder) !Person {
            if (self.first_name == null) return error.MissingFirstName;
            if (self.last_name == null) return error.MissingLastName;
            // ... check other required fields

            return Person{
                .first_name = self.first_name.?,
                .last_name = self.last_name.?,
                .email = self.email.?,
                .age = self.age.?,
            };
        }
    };
};
```

Errors surface immediately when invalid data is provided.

### Polymorphic Data Model

Use tagged unions for flexible value types:

```zig
const Value = union(enum) {
    string: []const u8,
    number: f64,
    boolean: bool,
    null_value,

    pub fn asString(self: Value) ![]const u8 {
        return switch (self) {
            .string => |s| s,
            else => error.TypeMismatch,
        };
    }

    pub fn asNumber(self: Value) !f64 {
        return switch (self) {
            .number => |n| n,
            else => error.TypeMismatch,
        };
    }
};

const Record = struct {
    fields: std.StringHashMap(Value),

    pub fn set(self: *Record, key: []const u8, value: Value) !void {
        try self.fields.put(key, value);
    }

    pub fn get(self: *const Record, key: []const u8) ?Value {
        return self.fields.get(key);
    }
};
```

Records can store heterogeneous typed values safely.

### Relationship Models

Model relationships between entities:

```zig
const Author = struct {
    id: u32,
    name: []const u8,
};

const Post = struct {
    id: u32,
    title: []const u8,
    author_id: u32,
    content: []const u8,

    pub fn getAuthor(self: *const Post, authors: []const Author) ?Author {
        for (authors) |author| {
            if (author.id == self.author_id) {
                return author;
            }
        }
        return null;
    }
};
```

Foreign keys link entities, with helper methods for navigation.

## Discussion

Zig's type system and comptime features enable powerful data modeling without runtime overhead.

### Design Patterns

**Newtype pattern**: Wrap primitives in structs for type safety
- Example: `Email`, `Username`, `Price`
- Prevents mixing incompatible values

**Builder pattern**: Progressive validation with clear error messages
- Example: Complex forms, API request builders
- Better UX than constructor with 20 parameters

**Tagged unions**: Type-safe polymorphism
- Example: JSON values, AST nodes, events
- Compile-time exhaustiveness checking

**Composition over inheritance**: Embed common fields
- Example: `BaseEntity` for id/timestamps
- No vtable overhead, explicit delegation

### Validation Strategy

**Compile-time validation**:
- Schema structure (`validateSchema`)
- Field types and names
- Zero runtime cost

**Construction-time validation**:
- Field constraints in `init()`
- Invalid objects can't be created
- Fail fast principle

**Mutation-time validation**:
- Validation in setters
- State transition checking
- Prevents invalid state changes

**Lazy validation**:
- Separate `validate()` method
- Check before serialization/persistence
- Allows building incrementally

### Performance Considerations

All patterns shown have minimal overhead:
- Typed fields compile to raw values
- Validation happens once at construction
- No reflection or dynamic dispatch
- Enums compile to integers with switch statements

### Error Handling

Data model errors should be specific:

```zig
pub fn init(...) !User {
    if (invalid) return error.InvalidEmail;  // Not generic error.Invalid
}
```

Specific errors help callers provide better feedback to users.

## See Also

- Recipe 8.11: Simplifying the Initialization of Data Structures
- Recipe 8.12: Defining an Interface or Abstract Base Class
- Recipe 8.14: Implementing Custom Containers
- Recipe 9.16: Defining Structs Programmatically

Full compilable example: `code/03-advanced/08-structs-unions-objects/recipe_8_13.zig`
