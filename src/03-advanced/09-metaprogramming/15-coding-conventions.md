## Problem

You want to enforce consistent coding conventions across your codebase at compile time. You need to validate that struct definitions follow naming standards, include required fields, avoid forbidden patterns, and maintain structural consistency. Manual code reviews catch these issues too late and inconsistently.

## Solution

Use `@typeInfo` to introspect struct definitions at compile time and `@compileError` to enforce conventions before code runs. Zig's compile-time execution lets you validate naming patterns, field requirements, type constraints, and structural rules with zero runtime overhead.

### Enforcing snake_case Naming

Validate that all field names follow snake_case convention:

```zig
{{#include ../../../code/03-advanced/09-metaprogramming/recipe_9_15.zig:snake_case_validation}}
```

Invalid naming patterns won't compile. This is useful for matching SQL column conventions or enforcing project style guides.

### Requiring Specific Fields

Ensure structs contain mandatory fields:

```zig
fn requireFields(comptime T: type, comptime required: []const []const u8) void {
    const fields = @typeInfo(T).@"struct".fields;

    inline for (required) |req_name| {
        var found = false;
        inline for (fields) |field| {
            if (std.mem.eql(u8, field.name, req_name)) {
                found = true;
                break;
            }
        }
        if (!found) {
            @compileError("Required field '" ++ req_name ++ "' is missing");
        }
    }
}

const User = struct {
    id: u64,
    name: []const u8,
    email: []const u8,
    created_at: i64,
};

test "required fields" {
    const required = [_][]const u8{ "id", "name", "email" };
    comptime requireFields(User, &required);

    const user = User{
        .id = 1,
        .name = "alice",
        .email = "alice@example.com",
        .created_at = 1234567890,
    };
    try testing.expectEqual(@as(u64, 1), user.id);
}
```

This pattern ensures API entities or database models always include essential fields.

## Discussion

### Forbidding Dangerous Field Names

Prevent accidentally including sensitive data:

```zig
fn forbidFields(comptime T: type, comptime forbidden: []const []const u8) void {
    const fields = @typeInfo(T).@"struct".fields;

    inline for (fields) |field| {
        inline for (forbidden) |forbidden_name| {
            if (std.mem.eql(u8, field.name, forbidden_name)) {
                @compileError("Field '" ++ field.name ++ "' is forbidden");
            }
        }
    }
}

const SafeConfig = struct {
    host: []const u8,
    port: u16,
    timeout: u32,
};

test "forbidden fields" {
    const forbidden = [_][]const u8{ "password", "secret", "private_key" };
    comptime forbidFields(SafeConfig, &forbidden);

    const config = SafeConfig{
        .host = "localhost",
        .port = 8080,
        .timeout = 30,
    };
    try testing.expectEqual(@as(u16, 8080), config.port);
}
```

This prevents sensitive data from appearing in logged or serialized structs.

### Field Count Constraints

Enforce reasonable struct sizes:

```zig
fn requireFieldCount(comptime T: type, comptime min: usize, comptime max: usize) void {
    const fields = @typeInfo(T).@"struct".fields;
    if (fields.len < min) {
        @compileError("Struct must have at least " ++ std.fmt.comptimePrint("{d}", .{min}) ++ " fields");
    }
    if (fields.len > max) {
        @compileError("Struct must have at most " ++ std.fmt.comptimePrint("{d}", .{max}) ++ " fields");
    }
}

const Point3D = struct {
    x: f64,
    y: f64,
    z: f64,
};

test "field count constraints" {
    comptime requireFieldCount(Point3D, 2, 4);

    const p = Point3D{ .x = 1.0, .y = 2.0, .z = 3.0 };
    try testing.expectEqual(@as(f64, 1.0), p.x);
}
```

This helps prevent overly complex data structures and encourages composition.

### Type Requirements

Enforce that specific fields have expected types:

```zig
fn requireFieldType(comptime T: type, comptime field_name: []const u8, comptime FieldType: type) void {
    const fields = @typeInfo(T).@"struct".fields;

    inline for (fields) |field| {
        if (std.mem.eql(u8, field.name, field_name)) {
            if (field.type != FieldType) {
                @compileError("Field '" ++ field_name ++ "' must be of type " ++ @typeName(FieldType));
            }
        }
    }
}

const Entity = struct {
    id: u64,
    name: []const u8,
    active: bool,
};

test "type requirements" {
    comptime requireFieldType(Entity, "id", u64);
    comptime requireFieldType(Entity, "active", bool);

    const entity = Entity{
        .id = 42,
        .name = "test",
        .active = true,
    };
    try testing.expectEqual(@as(u64, 42), entity.id);
}
```

This ensures critical fields maintain consistent types across related structs.

### Prefix Conventions

Enforce field name prefixes for private or internal fields:

```zig
fn requirePrefix(comptime T: type, comptime prefix: []const u8) void {
    const fields = @typeInfo(T).@"struct".fields;

    inline for (fields) |field| {
        if (!std.mem.startsWith(u8, field.name, prefix)) {
            @compileError("Field '" ++ field.name ++ "' must start with '" ++ prefix ++ "'");
        }
    }
}

const PrivateData = struct {
    _internal_id: u64,
    _hidden_flag: bool,
    _secret_value: i32,
};

test "prefix convention" {
    comptime requirePrefix(PrivateData, "_");

    const data = PrivateData{
        ._internal_id = 1,
        ._hidden_flag = true,
        ._secret_value = 42,
    };
    try testing.expectEqual(@as(u64, 1), data._internal_id);
}
```

This pattern makes internal fields visually distinct from public API.

### Forbidding Optional Fields

Prevent nullable fields for stricter data models:

```zig
fn forbidOptionalFields(comptime T: type) void {
    const fields = @typeInfo(T).@"struct".fields;

    inline for (fields) |field| {
        const type_info = @typeInfo(field.type);
        if (type_info == .optional) {
            @compileError("Field '" ++ field.name ++ "' cannot be optional");
        }
    }
}

const RequiredFields = struct {
    name: []const u8,
    age: u32,
    active: bool,
};

test "no optional fields" {
    comptime forbidOptionalFields(RequiredFields);

    const data = RequiredFields{
        .name = "test",
        .age = 25,
        .active = true,
    };
    try testing.expectEqual(@as(u32, 25), data.age);
}
```

This is useful for database models where NULL values aren't permitted.

### Requiring ID Fields

Enforce that database entities have identifier fields:

```zig
fn requireIdField(comptime T: type) void {
    const fields = @typeInfo(T).@"struct".fields;
    var found_id = false;

    inline for (fields) |field| {
        if (std.mem.eql(u8, field.name, "id")) {
            found_id = true;
            const type_info = @typeInfo(field.type);
            if (type_info != .int and type_info != .comptime_int) {
                @compileError("Field 'id' must be an integer type");
            }
        }
    }

    if (!found_id) {
        @compileError("Struct must have an 'id' field");
    }
}

const Product = struct {
    id: u64,
    name: []const u8,
    price: f64,
};

test "require id field" {
    comptime requireIdField(Product);

    const product = Product{
        .id = 100,
        .name = "Widget",
        .price = 19.99,
    };
    try testing.expectEqual(@as(u64, 100), product.id);
}
```

This ensures consistent identifier handling across data models.

### Field Ordering Requirements

Validate field definition order:

```zig
fn requireIdFirst(comptime T: type) void {
    const fields = @typeInfo(T).@"struct".fields;
    if (fields.len == 0) {
        @compileError("Struct must have at least one field");
    }

    if (!std.mem.eql(u8, fields[0].name, "id")) {
        @compileError("First field must be 'id', found '" ++ fields[0].name ++ "'");
    }
}

const Record = struct {
    id: u64,
    timestamp: i64,
    data: []const u8,
};

test "field order validation" {
    comptime requireIdFirst(Record);

    const record = Record{
        .id = 1,
        .timestamp = 1234567890,
        .data = "test",
    };
    try testing.expectEqual(@as(u64, 1), record.id);
}
```

Field ordering can matter for binary serialization or memory layout optimization.

### Combining Multiple Validators

Create comprehensive validation by composing validators:

```zig
fn ValidatedStruct(comptime T: type) type {
    // Enforce all conventions
    comptime enforceSnakeCase(T);
    comptime requireIdField(T);
    comptime requireIdFirst(T);
    comptime forbidOptionalFields(T);
    comptime requireFieldCount(T, 2, 10);

    return T;
}

const ValidatedUser = ValidatedStruct(struct {
    id: u64,
    user_name: []const u8,
    email_address: []const u8,
    is_active: bool,
});

test "combined validation" {
    const user = ValidatedUser{
        .id = 1,
        .user_name = "alice",
        .email_address = "alice@example.com",
        .is_active = true,
    };
    try testing.expectEqual(@as(u64, 1), user.id);
    try testing.expectEqualStrings("alice", user.user_name);
}
```

This pattern lets you create domain-specific validators for different parts of your system.

### camelCase Convention

Support alternative naming conventions:

```zig
fn isCamelCase(name: []const u8) bool {
    if (name.len == 0) return false;

    // Must start with lowercase letter
    if (name[0] < 'a' or name[0] > 'z') return false;

    for (name) |c| {
        const valid = (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9');
        if (!valid) return false;
    }

    return true;
}

fn enforceCamelCase(comptime T: type) void {
    const fields = @typeInfo(T).@"struct".fields;
    inline for (fields) |field| {
        if (!isCamelCase(field.name)) {
            @compileError("Field '" ++ field.name ++ "' must use camelCase naming");
        }
    }
}

const CamelCaseData = struct {
    firstName: []const u8,
    lastName: []const u8,
    emailAddress: []const u8,
};

test "camel case validation" {
    comptime enforceCamelCase(CamelCaseData);

    const data = CamelCaseData{
        .firstName = "Bob",
        .lastName = "Smith",
        .emailAddress = "bob@example.com",
    };
    try testing.expectEqualStrings("Bob", data.firstName);
}
```

Different naming conventions suit different contexts (APIs, databases, legacy systems).

### Forbidding Single-Item Pointers

Prevent unsafe pointer usage:

```zig
fn forbidSinglePointerFields(comptime T: type) void {
    const fields = @typeInfo(T).@"struct".fields;

    inline for (fields) |field| {
        const type_info = @typeInfo(field.type);
        if (type_info == .pointer) {
            // Forbid single-item pointers (size == .one)
            // Allow many-item pointers and C pointers (slices)
            if (type_info.pointer.size == .one) {
                @compileError("Field '" ++ field.name ++ "' cannot be a single-item pointer (use slices or values instead)");
            }
        }
    }
}

const SafeData = struct {
    values: []const u8,  // Slice is OK
    count: usize,
};

test "no single pointer fields" {
    comptime forbidSinglePointerFields(SafeData);

    const data = SafeData{
        .values = "test",
        .count = 4,
    };
    try testing.expectEqual(@as(usize, 4), data.count);
}
```

This encourages safer memory handling with slices instead of raw pointers.

### Suffix Conventions

Require consistent field name suffixes:

```zig
fn requireSuffix(comptime T: type, comptime suffix: []const u8) void {
    const fields = @typeInfo(T).@"struct".fields;

    inline for (fields) |field| {
        if (!std.mem.endsWith(u8, field.name, suffix)) {
            @compileError("Field '" ++ field.name ++ "' must end with '" ++ suffix ++ "'");
        }
    }
}

const MetricsData = struct {
    request_count: u64,
    error_count: u64,
    success_count: u64,
};

test "suffix convention" {
    comptime requireSuffix(MetricsData, "_count");

    const metrics = MetricsData{
        .request_count = 100,
        .error_count = 5,
        .success_count = 95,
    };
    try testing.expectEqual(@as(u64, 100), metrics.request_count);
}
```

Suffix conventions make field purposes immediately clear.

### Why This Matters

Compile-time convention enforcement provides several benefits:

1. **Consistency** - Automated enforcement across entire codebase
2. **Early Detection** - Violations caught during compilation, not code review
3. **Zero Runtime Cost** - All validation happens at compile time
4. **Self-Documenting** - Validators encode team conventions explicitly
5. **Refactoring Safety** - Convention violations prevented during changes
6. **Onboarding** - New team members learn conventions from compiler errors

### Real-World Applications

These validation patterns are useful for:

1. **Database ORM** - Enforce entity structure (required IDs, snake_case columns)
2. **API Serialization** - Validate JSON-compatible field names (camelCase)
3. **Security** - Prevent sensitive fields in logged structs
4. **Code Generation** - Ensure generated structs meet requirements
5. **Plugin Systems** - Validate plugin interface implementations
6. **Legacy Integration** - Enforce compatibility with existing systems

### Performance Characteristics

All validation has zero runtime cost:

- Type checking happens during compilation
- Invalid code is rejected before code generation
- Valid code runs at full speed with no overhead
- No dynamic dispatch or runtime type information needed

The only cost is compile time, which increases slightly with more validators. However, this is typically negligible compared to the time saved catching errors early.

### Building Domain-Specific Validators

You can create specialized validators for different system components:

```zig
// Database entity validator
fn DatabaseEntity(comptime T: type) type {
    comptime {
        enforceSnakeCase(T);           // SQL column naming
        requireIdField(T);              // Primary key required
        requireIdFirst(T);              // Conventional field order
        forbidSinglePointerFields(T);   // No dangling references
    }
    return T;
}

// API response validator
fn ApiResponse(comptime T: type) type {
    comptime {
        enforceCamelCase(T);            // JSON naming convention
        forbidOptionalFields(T);        // All fields must be present
        requireFieldCount(T, 1, 20);    // Reasonable payload size
    }
    return T;
}

// Internal state validator
fn InternalState(comptime T: type) type {
    comptime {
        requirePrefix(T, "_");          // Private field convention
        forbidFields(T, &[_][]const u8{"password", "secret"});  // No secrets in state
    }
    return T;
}
```

These specialized validators encode architectural decisions and maintain consistency across layers.

### String Validation Patterns

When validating field names, work with compile-time string operations:

```zig
// Check character ranges directly
if (name[0] < 'a' or name[0] > 'z') return false;

// Use std.mem functions for patterns
if (!std.mem.startsWith(u8, field.name, "_")) { }
if (!std.mem.endsWith(u8, field.name, "_count")) { }
if (!std.mem.eql(u8, field.name, "id")) { }

// Iterate characters for custom validation
for (name) |c| {
    const valid = (c >= 'a' and c <= 'z') or c == '_';
    if (!valid) return false;
}
```

All string operations work at compile time with zero runtime overhead.

### Type Introspection Techniques

Access different aspects of type information:

```zig
const fields = @typeInfo(T).@"struct".fields;

for (fields) |field| {
    const name = field.name;              // Field name ([]const u8)
    const field_type = field.type;        // Field type (type)
    const type_info = @typeInfo(field_type);  // Type category

    // Check type categories
    if (type_info == .optional) { }
    if (type_info == .pointer) { }
    if (type_info == .int) { }

    // Access pointer details
    if (type_info == .pointer) {
        const size = type_info.pointer.size;  // .one, .many, .c
    }
}
```

The `@typeInfo` builtin provides complete type metadata at compile time.

## See Also

- Recipe 9.12: Capturing struct attribute definition order
- Recipe 9.14: Enforcing an argument signature on tuple arguments
- Recipe 9.16: Defining structs programmatically

Full compilable example: `code/03-advanced/09-metaprogramming/recipe_9_15.zig`
