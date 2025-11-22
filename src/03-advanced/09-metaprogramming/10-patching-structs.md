## Problem

You need to add common functionality to existing structs without modifying their definitions. You want reusable patterns for adding timestamps, IDs, validation, versioning, or other cross-cutting concerns to multiple struct types.

## Solution

Use compile-time functions that take a type and return a new type with enhanced capabilities. These "decorator" functions wrap the original struct and add fields, methods, or both.

### Adding Fields to Structs

The simplest pattern wraps a struct and adds new fields:

```zig
{{#include ../../../code/03-advanced/09-metaprogramming/recipe_9_10.zig:add_field}}
```

The original struct is stored in an `inner` field, keeping it separate from the added functionality.

### Adding Methods to Structs

You can also add new methods while preserving the original struct:

```zig
// Add logging methods to any struct
fn WithLogging(comptime T: type) type {
    return struct {
        inner: T,
        log_count: u32 = 0,

        pub fn init(inner: T) @This() {
            return .{ .inner = inner };
        }

        pub fn log(self: *@This(), comptime message: []const u8) void {
            _ = message;
            self.log_count += 1;
        }

        pub fn getLogCount(self: @This()) u32 {
            return self.log_count;
        }

        pub fn getInner(self: @This()) T {
            return self.inner;
        }
    };
}

test "add methods" {
    const LoggedPerson = WithLogging(Person);
    var lp = LoggedPerson.init(.{ .name = "Bob", .age = 25 });

    lp.log("Created person");
    lp.log("Updated person");

    try testing.expectEqual(@as(u32, 2), lp.getLogCount());
}
```

### Wrapping with Validation

Decorators can add runtime behavior like validation:

```zig
// Wrap struct with validation state
fn WithValidation(comptime T: type) type {
    return struct {
        inner: T,
        is_valid: bool = true,

        pub fn init(inner: T) @This() {
            return .{ .inner = inner };
        }

        pub fn validate(self: *@This()) bool {
            // Simplified validation
            self.is_valid = true;
            return self.is_valid;
        }

        pub fn invalidate(self: *@This()) void {
            self.is_valid = false;
        }

        pub fn getInner(self: @This()) ?T {
            if (!self.is_valid) return null;
            return self.inner;
        }
    };
}

test "wrap struct" {
    const ValidatedPerson = WithValidation(Person);
    var vp = ValidatedPerson.init(.{ .name = "Charlie", .age = 35 });

    try testing.expect(vp.validate());

    const person1 = vp.getInner();
    try testing.expect(person1 != null);

    vp.invalidate();
    const person2 = vp.getInner();
    try testing.expect(person2 == null);
}
```

## Discussion

### The Wrapper Pattern

All these decorators follow the same basic pattern:

1. Accept a type as a `comptime` parameter
2. Return a new struct type
3. Store the original type in an `inner` field
4. Add new fields and methods
5. Provide a `getInner()` method to access the wrapped value

This pattern is zero-cost at runtime because everything happens at compile time. The Zig compiler generates specialized code for each type you wrap.

### Common Decorator Patterns

**Adding Unique Identifiers:**

```zig
fn WithID(comptime T: type) type {
    return struct {
        id: u64,
        inner: T,

        pub fn init(id: u64, inner: T) @This() {
            return .{ .id = id, .inner = inner };
        }

        pub fn getID(self: @This()) u64 {
            return self.id;
        }

        pub fn getInner(self: @This()) T {
            return self.inner;
        }
    };
}

test "add id field" {
    const PersonWithID = WithID(Person);
    const p = PersonWithID.init(42, .{ .name = "Diana", .age = 28 });

    try testing.expectEqual(@as(u64, 42), p.getID());
    try testing.expectEqualStrings("Diana", p.getInner().name);
}
```

**Version Tracking:**

```zig
fn Versioned(comptime T: type) type {
    return struct {
        inner: T,
        version: u32 = 1,

        pub fn init(inner: T) @This() {
            return .{ .inner = inner };
        }

        pub fn update(self: *@This(), new_inner: T) void {
            self.inner = new_inner;
            self.version += 1;
        }

        pub fn getVersion(self: @This()) u32 {
            return self.version;
        }

        pub fn getInner(self: @This()) T {
            return self.inner;
        }
    };
}

test "versioned struct" {
    const VersionedPerson = Versioned(Person);
    var vp = VersionedPerson.init(.{ .name = "Eve", .age = 30 });

    try testing.expectEqual(@as(u32, 1), vp.getVersion());

    vp.update(.{ .name = "Eve", .age = 31 });
    try testing.expectEqual(@as(u32, 2), vp.getVersion());
    try testing.expectEqual(@as(u32, 31), vp.getInner().age);
}
```

### Mixin Pattern

Mixins add capabilities without inheritance:

```zig
fn Comparable(comptime T: type) type {
    return struct {
        inner: T,

        pub fn init(inner: T) @This() {
            return .{ .inner = inner };
        }

        pub fn equals(self: @This(), other: @This()) bool {
            // Simplified comparison
            _ = self;
            _ = other;
            return false; // Would compare fields
        }

        pub fn getInner(self: @This()) T {
            return self.inner;
        }
    };
}

fn Serializable(comptime T: type) type {
    return struct {
        inner: T,

        pub fn init(inner: T) @This() {
            return .{ .inner = inner };
        }

        pub fn serialize(self: @This()) []const u8 {
            _ = self;
            return "serialized"; // Simplified
        }

        pub fn getInner(self: @This()) T {
            return self.inner;
        }
    };
}

test "mixin pattern" {
    const ComparablePerson = Comparable(Person);
    const cp1 = ComparablePerson.init(.{ .name = "Frank", .age = 40 });
    const cp2 = ComparablePerson.init(.{ .name = "Grace", .age = 45 });

    try testing.expect(!cp1.equals(cp2));

    const SerializablePerson = Serializable(Person);
    const sp = SerializablePerson.init(.{ .name = "Henry", .age = 50 });

    try testing.expectEqualStrings("serialized", sp.serialize());
}
```

### Adding Metadata

You can attach compile-time metadata to structs:

```zig
fn WithMetadata(comptime T: type, comptime metadata: anytype) type {
    return struct {
        pub const meta = metadata;
        inner: T,

        pub fn init(inner: T) @This() {
            return .{ .inner = inner };
        }

        pub fn getMetadata() @TypeOf(metadata) {
            return meta;
        }

        pub fn getInner(self: @This()) T {
            return self.inner;
        }
    };
}

const Metadata = struct {
    table_name: []const u8,
    primary_key: []const u8,
};

test "add metadata" {
    const meta = Metadata{ .table_name = "people", .primary_key = "id" };
    const MetaPerson = WithMetadata(Person, meta);

    const mp = MetaPerson.init(.{ .name = "Jack", .age = 33 });

    try testing.expectEqualStrings("people", MetaPerson.getMetadata().table_name);
    try testing.expectEqualStrings("Jack", mp.getInner().name);
}
```

The metadata is stored as a compile-time constant, accessible via the type itself rather than instances.

### Observable Pattern

Track changes to wrapped values:

```zig
fn Observable(comptime T: type) type {
    return struct {
        inner: T,
        change_count: u32 = 0,

        pub fn init(inner: T) @This() {
            return .{ .inner = inner };
        }

        pub fn set(self: *@This(), new_value: T) void {
            self.inner = new_value;
            self.change_count += 1;
        }

        pub fn get(self: @This()) T {
            return self.inner;
        }

        pub fn getChangeCount(self: @This()) u32 {
            return self.change_count;
        }
    };
}

test "observable struct" {
    const ObservablePerson = Observable(Person);
    var op = ObservablePerson.init(.{ .name = "Leo", .age = 29 });

    try testing.expectEqual(@as(u32, 0), op.getChangeCount());

    op.set(.{ .name = "Leo", .age = 30 });
    try testing.expectEqual(@as(u32, 1), op.getChangeCount());
}
```

### Clone Support

Add cloning capability to any type:

```zig
fn Cloneable(comptime T: type) type {
    return struct {
        inner: T,

        pub fn init(inner: T) @This() {
            return .{ .inner = inner };
        }

        pub fn clone(self: @This()) @This() {
            return .{ .inner = self.inner };
        }

        pub fn getInner(self: @This()) T {
            return self.inner;
        }
    };
}

test "clone support" {
    const CloneablePerson = Cloneable(Person);
    const cp = CloneablePerson.init(.{ .name = "Mary", .age = 32 });

    const cloned = cp.clone();
    try testing.expectEqualStrings("Mary", cloned.getInner().name);
    try testing.expectEqual(@as(u32, 32), cloned.getInner().age);
}
```

This works for types that can be copied by value. For heap-allocated data, you'd need to pass an allocator and implement deep cloning.

### Default Values

Provide default initialization:

```zig
fn WithDefaults(comptime T: type, comptime defaults: T) type {
    return struct {
        inner: T,

        pub fn init() @This() {
            return .{ .inner = defaults };
        }

        pub fn initWith(inner: T) @This() {
            return .{ .inner = inner };
        }

        pub fn getInner(self: @This()) T {
            return self.inner;
        }
    };
}

test "default values" {
    const default_person = Person{ .name = "Default", .age = 0 };
    const DefaultPerson = WithDefaults(Person, default_person);

    const dp1 = DefaultPerson.init();
    try testing.expectEqualStrings("Default", dp1.getInner().name);

    const dp2 = DefaultPerson.initWith(.{ .name = "Nancy", .age = 24 });
    try testing.expectEqualStrings("Nancy", dp2.getInner().name);
}
```

### Lazy Initialization

Defer expensive initialization until first use:

```zig
fn Lazy(comptime T: type) type {
    return struct {
        value: ?T = null,
        initialized: bool = false,

        pub fn init() @This() {
            return .{};
        }

        pub fn get(self: *@This(), comptime init_fn: anytype) T {
            if (!self.initialized) {
                self.value = init_fn();
                self.initialized = true;
            }
            return self.value.?;
        }

        pub fn isInitialized(self: @This()) bool {
            return self.initialized;
        }
    };
}

fn createPerson() Person {
    return .{ .name = "Lazy", .age = 99 };
}

test "lazy initialization" {
    var lazy = Lazy(Person).init();

    try testing.expect(!lazy.isInitialized());

    const person = lazy.get(createPerson);
    try testing.expect(lazy.isInitialized());
    try testing.expectEqualStrings("Lazy", person.name);
}
```

The initialization function is called only once, on the first `get()` call.

### When to Use Struct Patching

These patterns shine when you need to:

1. **Add cross-cutting concerns** like logging, metrics, or validation to many types
2. **Avoid code duplication** by extracting common patterns
3. **Maintain separation of concerns** between core logic and auxiliary features
4. **Support progressive enhancement** of simple types
5. **Create composable abstractions** without inheritance

The compile-time nature means there's no runtime overhead compared to writing the enhanced struct directly.

### Limitations

**Type Identity:**
The wrapped type is distinct from the original. `WithTimestamp(Person)` and `Person` are different types.

**Field Access:**
You can't directly access inner fields without calling `getInner()` first. This can be verbose but maintains clear boundaries.

**Multiple Wrapping:**
Wrapping the same type with multiple decorators creates nesting:

```zig
const Enhanced = WithTimestamp(WithID(Person));
```

Each wrapper adds another level of indirection. For complex compositions, consider creating a dedicated struct instead.

## See Also

- Recipe 9.1: Putting a wrapper around a function
- Recipe 9.6: Defining decorators as part of a struct
- Recipe 9.7: Defining decorators as structs
- Recipe 9.18: Extending classes with mixins (if available)

Full compilable example: `code/03-advanced/09-metaprogramming/recipe_9_10.zig`
