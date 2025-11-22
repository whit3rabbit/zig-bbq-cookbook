// Recipe 8.9: Creating a New Kind of Class or Instance Attribute
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: field_introspection
// Field introspection using @typeInfo
const Person = struct {
    name: []const u8,
    age: u32,
    email: []const u8,

    pub fn fieldCount() usize {
        const info = @typeInfo(Person);
        return info.@"struct".fields.len;
    }

    pub fn hasField(comptime field_name: []const u8) bool {
        const info = @typeInfo(Person);
        inline for (info.@"struct".fields) |field| {
            if (std.mem.eql(u8, field.name, field_name)) {
                return true;
            }
        }
        return false;
    }

    pub fn fieldNames() [fieldCount()][]const u8 {
        const info = @typeInfo(Person);
        var names: [info.@"struct".fields.len][]const u8 = undefined;
        inline for (info.@"struct".fields, 0..) |field, i| {
            names[i] = field.name;
        }
        return names;
    }
};
// ANCHOR_END: field_introspection

test "field introspection" {
    try testing.expectEqual(@as(usize, 3), Person.fieldCount());
    try testing.expect(Person.hasField("name"));
    try testing.expect(Person.hasField("age"));
    try testing.expect(!Person.hasField("phone"));

    const names = Person.fieldNames();
    try testing.expectEqualStrings("name", names[0]);
    try testing.expectEqualStrings("age", names[1]);
    try testing.expectEqualStrings("email", names[2]);
}

// ANCHOR: tagged_fields
// Custom tags via parallel struct
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
// ANCHOR_END: tagged_fields

test "tagged fields" {
    const user = User{
        .username = "john_doe",
        .email = "john@example.com",
        .age = 25,
    };

    try user.validate();

    const username_tag = User.getFieldTag("username");
    try testing.expect(username_tag.required);
    try testing.expectEqual(@as(usize, 50), username_tag.max_length.?);
}

// ANCHOR: generic_attribute_system
// Generic attribute system
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
// ANCHOR_END: generic_attribute_system

test "generic attribute system" {
    var validated = ValidatedString.init("hello", .{
        .max_length = 10,
        .pattern = "[a-z]+",
    });

    try testing.expectEqualStrings("hello", validated.getValue());
    try testing.expectEqual(@as(usize, 10), validated.getMetadata().max_length);

    validated.setValue("world");
    try testing.expectEqualStrings("world", validated.getValue());
}

// ANCHOR: field_annotations
// Field annotations pattern
const FieldAnnotation = struct {
    description: []const u8,
    deprecated: bool,
    since_version: []const u8,
};

fn Annotated(comptime T: type) type {
    return struct {
        const annotations = blk: {
            var result: [@typeInfo(T).@"struct".fields.len]FieldAnnotation = undefined;
            for (@typeInfo(T).@"struct".fields, 0..) |_, i| {
                result[i] = .{
                    .description = "",
                    .deprecated = false,
                    .since_version = "1.0",
                };
            }
            break :blk result;
        };

        pub fn getFieldAnnotation(comptime field_name: []const u8) ?FieldAnnotation {
            const info = @typeInfo(T);
            inline for (info.@"struct".fields, 0..) |field, i| {
                if (std.mem.eql(u8, field.name, field_name)) {
                    return annotations[i];
                }
            }
            return null;
        }

        pub fn listFields(allocator: std.mem.Allocator) ![][]const u8 {
            const info = @typeInfo(T);
            var list = std.ArrayList([]const u8){};

            inline for (info.@"struct".fields) |field| {
                try list.append(allocator, field.name);
            }

            return list.toOwnedSlice(allocator);
        }
    };
}

const Config = struct {
    host: []const u8,
    port: u16,
    timeout: u32,
};

const AnnotatedConfig = Annotated(Config);
// ANCHOR_END: field_annotations

test "field annotations" {
    const annotation = AnnotatedConfig.getFieldAnnotation("host");
    try testing.expect(annotation != null);
    try testing.expectEqualStrings("1.0", annotation.?.since_version);

    const fields = try AnnotatedConfig.listFields(testing.allocator);
    defer testing.allocator.free(fields);
    try testing.expectEqual(@as(usize, 3), fields.len);
}

// ANCHOR: comptime_field_validation
// Compile-time field validation
fn ValidatedStruct(comptime T: type, comptime validator: fn (type) bool) type {
    if (!validator(T)) {
        @compileError("Type validation failed");
    }
    return T;
}

fn hasRequiredFields(comptime T: type) bool {
    const info = @typeInfo(T);
    if (info != .@"struct") return false;

    var has_id = false;
    var has_name = false;

    inline for (info.@"struct".fields) |field| {
        if (std.mem.eql(u8, field.name, "id")) has_id = true;
        if (std.mem.eql(u8, field.name, "name")) has_name = true;
    }

    return has_id and has_name;
}

const ValidEntity = ValidatedStruct(struct {
    id: u32,
    name: []const u8,
}, hasRequiredFields);
// ANCHOR_END: comptime_field_validation

test "comptime field validation" {
    const entity = ValidEntity{
        .id = 1,
        .name = "Test",
    };

    try testing.expectEqual(@as(u32, 1), entity.id);
    try testing.expectEqualStrings("Test", entity.name);
}

// ANCHOR: type_level_attributes
// Type-level attributes using container declarations
const Serializable = struct {
    pub const serialization_version = 1;
    pub const supports_json = true;
    pub const supports_binary = true;
};

const Document = struct {
    title: []const u8,
    content: []const u8,

    pub const version = Serializable.serialization_version;
    pub const supports_json = Serializable.supports_json;

    pub fn toJson(self: *const Document, allocator: std.mem.Allocator) ![]u8 {
        _ = self;
        return try allocator.dupe(u8, "{}");
    }

    pub fn fromJson(data: []const u8, allocator: std.mem.Allocator) !Document {
        _ = data;
        _ = allocator;
        return error.NotImplemented;
    }
};
// ANCHOR_END: type_level_attributes

test "type-level attributes" {
    const doc = Document{
        .title = "Test",
        .content = "Content",
    };

    try testing.expectEqual(@as(u32, 1), Document.version);

    const json = try doc.toJson(testing.allocator);
    defer testing.allocator.free(json);
    try testing.expectEqualStrings("{}", json);
}

// ANCHOR: reflection_property_access
// Reflection-based property access
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
// ANCHOR_END: reflection_property_access

test "reflection property access" {
    var point = Point{ .x = 1, .y = 2, .z = 3 };

    try testing.expectEqual(@as(f32, 1), getField(point, "x"));
    try testing.expectEqual(@as(f32, 2), getField(point, "y"));

    setField(&point, "x", 10);
    try testing.expectEqual(@as(f32, 10), point.x);

    try testing.expectEqual(@as(f32, 2), try point.getByIndex(1));
    try point.setByIndex(2, 30);
    try testing.expectEqual(@as(f32, 30), point.z);
}

// ANCHOR: custom_serialization_metadata
// Custom serialization based on field metadata
const SerializationMeta = struct {
    json_name: []const u8,
    omit_empty: bool,
    required: bool,
};

fn Serializer(comptime T: type) type {
    return struct {
        pub fn fieldMeta(comptime field_name: []const u8) SerializationMeta {
            // Default metadata
            return .{
                .json_name = field_name,
                .omit_empty = false,
                .required = false,
            };
        }

        pub fn serialize(value: T, allocator: std.mem.Allocator) ![]u8 {
            _ = value;
            var result = std.ArrayList(u8){};
            errdefer result.deinit(allocator);

            try result.appendSlice(allocator, "{");

            const info = @typeInfo(T);
            inline for (info.@"struct".fields, 0..) |field, i| {
                if (i > 0) try result.appendSlice(allocator, ",");

                const meta = fieldMeta(field.name);
                try result.appendSlice(allocator, "\"");
                try result.appendSlice(allocator, meta.json_name);
                try result.appendSlice(allocator, "\":null");
            }

            try result.appendSlice(allocator, "}");
            return result.toOwnedSlice(allocator);
        }
    };
}

const Product = struct {
    id: u32,
    name: []const u8,
    price: f64,

    const ProductSerializer = Serializer(@This());

    pub fn fieldMeta(comptime field_name: []const u8) SerializationMeta {
        return ProductSerializer.fieldMeta(field_name);
    }

    pub fn serialize(value: Product, allocator: std.mem.Allocator) ![]u8 {
        return ProductSerializer.serialize(value, allocator);
    }
};
// ANCHOR_END: custom_serialization_metadata

test "custom serialization metadata" {
    const product = Product{
        .id = 123,
        .name = "Widget",
        .price = 29.99,
    };

    const json = try Product.serialize(product, testing.allocator);
    defer testing.allocator.free(json);

    try testing.expect(std.mem.indexOf(u8, json, "\"id\"") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"name\"") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"price\"") != null);
}

// ANCHOR: readonly_attribute
// Read-only attribute pattern
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
// ANCHOR_END: readonly_attribute

test "readonly attribute" {
    const config = ImmutableConfig.init("secret123", "https://api.example.com");

    try testing.expectEqualStrings("secret123", config.api_key.get());
    try testing.expectEqualStrings("https://api.example.com", config.endpoint.get());
}

// ANCHOR: default_value_attribute
// Default value attribute
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
// ANCHOR_END: default_value_attribute

test "default value attribute" {
    var settings = Settings.init();

    try testing.expectEqual(@as(u32, 5000), settings.timeout.get());
    try testing.expectEqual(@as(u8, 3), settings.retries.get());

    settings.timeout.set(10000);
    try testing.expectEqual(@as(u32, 10000), settings.timeout.get());

    settings.timeout.reset();
    try testing.expectEqual(@as(u32, 5000), settings.timeout.get());
}

// Comprehensive test
test "comprehensive custom attributes" {
    try testing.expectEqual(@as(usize, 3), Person.fieldCount());

    var validated = ValidatedString.init("test", .{
        .max_length = 100,
        .pattern = ".*",
    });
    try testing.expectEqualStrings("test", validated.getValue());

    var point = Point{ .x = 5, .y = 10, .z = 15 };
    try testing.expectEqual(@as(f32, 10), try point.getByIndex(1));

    var settings = Settings.init();
    try testing.expectEqual(@as(u32, 5000), settings.timeout.get());
}
