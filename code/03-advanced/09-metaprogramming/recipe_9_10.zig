// Recipe 9.10: Using Decorators to Patch Struct Definitions
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: add_field
// Add fields to a struct
fn WithTimestamp(comptime T: type) type {
    return struct {
        inner: T,
        created_at: u64 = 0,
        updated_at: u64 = 0,

        pub fn init(inner: T) @This() {
            return .{
                .inner = inner,
                .created_at = 1000,
                .updated_at = 1000,
            };
        }

        pub fn update(self: *@This()) void {
            self.updated_at += 1;
        }

        pub fn getInner(self: @This()) T {
            return self.inner;
        }
    };
}

const Person = struct {
    name: []const u8,
    age: u32,
};

test "add field" {
    const TimestampedPerson = WithTimestamp(Person);
    var tp = TimestampedPerson.init(.{ .name = "Alice", .age = 30 });

    try testing.expectEqual(@as(u64, 1000), tp.created_at);
    tp.update();
    try testing.expectEqual(@as(u64, 1001), tp.updated_at);

    const person = tp.getInner();
    try testing.expectEqualStrings("Alice", person.name);
}
// ANCHOR_END: add_field

// ANCHOR: add_methods
// Add methods to a struct
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
// ANCHOR_END: add_methods

// ANCHOR: wrap_struct
// Wrap struct with validation
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
// ANCHOR_END: wrap_struct

// ANCHOR: add_id_field
// Add ID field to any struct
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
// ANCHOR_END: add_id_field

// ANCHOR: versioned_struct
// Add version tracking
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
// ANCHOR_END: versioned_struct

// ANCHOR: mixin_pattern
// Mixin pattern for adding capabilities
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
// ANCHOR_END: mixin_pattern

// ANCHOR: compose_mixins
// Compose multiple mixins
fn Compose(comptime T: type, comptime Mixins: []const type) type {
    // This is simplified - real implementation would be more complex
    _ = Mixins;
    return struct {
        inner: T,

        pub fn init(inner: T) @This() {
            return .{ .inner = inner };
        }

        pub fn getInner(self: @This()) T {
            return self.inner;
        }
    };
}

test "compose mixins" {
    const Enhanced = Compose(Person, &[_]type{ Comparable(Person), Serializable(Person) });
    const e = Enhanced.init(.{ .name = "Iris", .age = 22 });

    try testing.expectEqualStrings("Iris", e.getInner().name);
}
// ANCHOR_END: compose_mixins

// ANCHOR: add_metadata
// Add metadata to struct
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
// ANCHOR_END: add_metadata

// ANCHOR: builder_wrapper
// Add builder pattern
fn WithBuilder(comptime T: type) type {
    return struct {
        const Self = @This();
        inner: T,

        pub fn init(inner: T) Self {
            return .{ .inner = inner };
        }

        pub fn build(self: Self) T {
            return self.inner;
        }

        pub fn getInner(self: Self) T {
            return self.inner;
        }
    };
}

test "builder wrapper" {
    const PersonBuilder = WithBuilder(Person);
    const builder = PersonBuilder.init(.{ .name = "Kate", .age = 27 });

    const person = builder.build();
    try testing.expectEqualStrings("Kate", person.name);
}
// ANCHOR_END: builder_wrapper

// ANCHOR: observable_struct
// Add observer pattern
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
// ANCHOR_END: observable_struct

// ANCHOR: clone_support
// Add clone capability
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
// ANCHOR_END: clone_support

// ANCHOR: default_values
// Add default value support
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
// ANCHOR_END: default_values

// ANCHOR: lazy_initialization
// Add lazy initialization
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
// ANCHOR_END: lazy_initialization

// Comprehensive test
test "comprehensive struct patching" {
    // Add timestamp
    const TimestampedPerson = WithTimestamp(Person);
    const tp = TimestampedPerson.init(.{ .name = "Test", .age = 50 });
    try testing.expectEqual(@as(u64, 1000), tp.created_at);

    // Add ID
    const PersonWithID = WithID(Person);
    const pid = PersonWithID.init(123, .{ .name = "Test2", .age = 51 });
    try testing.expectEqual(@as(u64, 123), pid.getID());

    // Versioned
    const VersionedPerson = Versioned(Person);
    var vp = VersionedPerson.init(.{ .name = "Test3", .age = 52 });
    vp.update(.{ .name = "Test3", .age = 53 });
    try testing.expectEqual(@as(u32, 2), vp.getVersion());

    // Observable
    const ObservablePerson = Observable(Person);
    var op = ObservablePerson.init(.{ .name = "Test4", .age = 54 });
    op.set(.{ .name = "Test4", .age = 55 });
    try testing.expectEqual(@as(u32, 1), op.getChangeCount());
}
