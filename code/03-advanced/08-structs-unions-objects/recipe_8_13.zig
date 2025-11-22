// Recipe 8.13: Implementing a Data Model or Type System
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_validation
// Basic field validation
const User = struct {
    username: []const u8,
    email: []const u8,
    age: u8,

    pub fn validate(self: *const User) !void {
        if (self.username.len == 0 or self.username.len > 50) {
            return error.InvalidUsername;
        }
        if (std.mem.indexOf(u8, self.email, "@") == null) {
            return error.InvalidEmail;
        }
        if (self.age < 13 or self.age > 150) {
            return error.InvalidAge;
        }
    }

    pub fn init(username: []const u8, email: []const u8, age: u8) !User {
        const user = User{
            .username = username,
            .email = email,
            .age = age,
        };
        try user.validate();
        return user;
    }
};
// ANCHOR_END: basic_validation

test "basic validation" {
    const valid_user = try User.init("alice", "alice@example.com", 25);
    try testing.expectEqualStrings("alice", valid_user.username);

    const invalid_username = User.init("", "test@test.com", 25);
    try testing.expectError(error.InvalidUsername, invalid_username);

    const invalid_email = User.init("bob", "invalid", 25);
    try testing.expectError(error.InvalidEmail, invalid_email);
}

// ANCHOR: typed_fields
// Typed fields with validation
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

    pub fn getValue(self: *const Username) []const u8 {
        return self.value;
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
// ANCHOR_END: typed_fields

test "typed fields" {
    const user = try ValidatedUser.init("alice_123", "alice@example.com");
    try testing.expectEqualStrings("alice_123", user.username.getValue());
    try testing.expectEqualStrings("alice@example.com", user.email.getValue());

    const bad_username = ValidatedUser.init("ab", "test@test.com");
    try testing.expectError(error.TooShort, bad_username);

    const bad_email = ValidatedUser.init("alice", "invalid");
    try testing.expectError(error.InvalidFormat, bad_email);
}

// ANCHOR: enum_constraints
// Enum-based constraints
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
// ANCHOR_END: enum_constraints

test "enum constraints" {
    var doc = Document.init("My Doc", "Content");
    try testing.expectEqual(Status.draft, doc.status);

    try doc.changeStatus(.published);
    try testing.expectEqual(Status.published, doc.status);

    const result = doc.changeStatus(.draft);
    try testing.expectError(error.InvalidTransition, result);
}

// ANCHOR: relationship_model
// Relationships between models
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

const Comment = struct {
    id: u32,
    post_id: u32,
    author_id: u32,
    text: []const u8,
};
// ANCHOR_END: relationship_model

test "relationship model" {
    const authors = [_]Author{
        .{ .id = 1, .name = "Alice" },
        .{ .id = 2, .name = "Bob" },
    };

    const post = Post{
        .id = 100,
        .title = "Hello World",
        .author_id = 1,
        .content = "First post!",
    };

    const author = post.getAuthor(&authors);
    try testing.expect(author != null);
    try testing.expectEqualStrings("Alice", author.?.name);
}

// ANCHOR: schema_validation
// Schema validation with comptime
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
// ANCHOR_END: schema_validation

test "schema validation" {
    const product = Product{
        .id = 1,
        .name = "Widget",
        .price = 19.99,
    };

    try testing.expectEqual(@as(u32, 1), product.id);
}

// ANCHOR: builder_with_validation
// Builder pattern with progressive validation
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

        pub fn setLastName(self: *Builder, name: []const u8) !*Builder {
            if (name.len == 0) return error.EmptyLastName;
            self.last_name = name;
            return self;
        }

        pub fn setEmail(self: *Builder, email: []const u8) !*Builder {
            if (std.mem.indexOf(u8, email, "@") == null) {
                return error.InvalidEmail;
            }
            self.email = email;
            return self;
        }

        pub fn setAge(self: *Builder, age: u8) !*Builder {
            if (age < 18) return error.TooYoung;
            self.age = age;
            return self;
        }

        pub fn build(self: *const Builder) !Person {
            if (self.first_name == null) return error.MissingFirstName;
            if (self.last_name == null) return error.MissingLastName;
            if (self.email == null) return error.MissingEmail;
            if (self.age == null) return error.MissingAge;

            return Person{
                .first_name = self.first_name.?,
                .last_name = self.last_name.?,
                .email = self.email.?,
                .age = self.age.?,
            };
        }
    };
};
// ANCHOR_END: builder_with_validation

test "builder with validation" {
    var builder = Person.Builder{};

    _ = try builder.setFirstName("John");
    _ = try builder.setLastName("Doe");
    _ = try builder.setEmail("john@example.com");
    _ = try builder.setAge(30);
    const person = try builder.build();

    try testing.expectEqualStrings("John", person.first_name);
    try testing.expectEqual(@as(u8, 30), person.age);

    var bad_builder = Person.Builder{};
    _ = try bad_builder.setFirstName("Jane");
    const result = bad_builder.build();
    try testing.expectError(error.MissingLastName, result);
}

// ANCHOR: polymorphic_data
// Polymorphic data model
const Value = union(enum) {
    string: []const u8,
    number: f64,
    boolean: bool,
    null_value,

    pub fn typeStr(self: Value) []const u8 {
        return switch (self) {
            .string => "string",
            .number => "number",
            .boolean => "boolean",
            .null_value => "null",
        };
    }

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

    pub fn init(allocator: std.mem.Allocator) Record {
        return Record{
            .fields = std.StringHashMap(Value).init(allocator),
        };
    }

    pub fn deinit(self: *Record) void {
        self.fields.deinit();
    }

    pub fn set(self: *Record, key: []const u8, value: Value) !void {
        try self.fields.put(key, value);
    }

    pub fn get(self: *const Record, key: []const u8) ?Value {
        return self.fields.get(key);
    }
};
// ANCHOR_END: polymorphic_data

test "polymorphic data" {
    var record = Record.init(testing.allocator);
    defer record.deinit();

    try record.set("name", .{ .string = "Alice" });
    try record.set("age", .{ .number = 30 });
    try record.set("active", .{ .boolean = true });

    const name = record.get("name");
    try testing.expect(name != null);
    try testing.expectEqualStrings("Alice", try name.?.asString());

    const age = record.get("age");
    try testing.expectEqual(@as(f64, 30), try age.?.asNumber());
}

// ANCHOR: inheritance_alternative
// Inheritance alternative via composition
const BaseEntity = struct {
    id: u32,
    created_at: i64,
    updated_at: i64,

    pub fn init(id: u32, timestamp: i64) BaseEntity {
        return BaseEntity{
            .id = id,
            .created_at = timestamp,
            .updated_at = timestamp,
        };
    }

    pub fn touch(self: *BaseEntity, timestamp: i64) void {
        self.updated_at = timestamp;
    }
};

const Article = struct {
    base: BaseEntity,
    title: []const u8,
    body: []const u8,

    pub fn init(id: u32, title: []const u8, body: []const u8, timestamp: i64) Article {
        return Article{
            .base = BaseEntity.init(id, timestamp),
            .title = title,
            .body = body,
        };
    }

    pub fn getId(self: *const Article) u32 {
        return self.base.id;
    }

    pub fn update(self: *Article, body: []const u8, timestamp: i64) void {
        self.body = body;
        self.base.touch(timestamp);
    }
};
// ANCHOR_END: inheritance_alternative

test "inheritance alternative" {
    var article = Article.init(1, "Title", "Original body", 1000);
    try testing.expectEqual(@as(u32, 1), article.getId());
    try testing.expectEqual(@as(i64, 1000), article.base.created_at);

    article.update("Updated body", 2000);
    try testing.expectEqualStrings("Updated body", article.body);
    try testing.expectEqual(@as(i64, 2000), article.base.updated_at);
}

// ANCHOR: serialization_metadata
// Serialization with metadata
const FieldMeta = struct {
    json_name: []const u8,
    required: bool,
    default_value: ?[]const u8,
};

fn serializeToJson(comptime T: type, value: T, allocator: std.mem.Allocator) ![]u8 {
    var result = std.ArrayList(u8){};
    errdefer result.deinit(allocator);

    try result.appendSlice(allocator, "{");

    const info = @typeInfo(T);
    inline for (info.@"struct".fields, 0..) |field, i| {
        if (i > 0) try result.appendSlice(allocator, ",");

        try result.appendSlice(allocator, "\"");
        try result.appendSlice(allocator, field.name);
        try result.appendSlice(allocator, "\":");

        const field_value = @field(value, field.name);
        const field_type = @TypeOf(field_value);

        if (field_type == []const u8) {
            try result.appendSlice(allocator, "\"");
            try result.appendSlice(allocator, field_value);
            try result.appendSlice(allocator, "\"");
        } else {
            const value_str = try std.fmt.allocPrint(allocator, "{d}", .{field_value});
            defer allocator.free(value_str);
            try result.appendSlice(allocator, value_str);
        }
    }

    try result.appendSlice(allocator, "}");
    return result.toOwnedSlice(allocator);
}

const ApiResponse = struct {
    status: u16,
    message: []const u8,
};
// ANCHOR_END: serialization_metadata

test "serialization metadata" {
    const response = ApiResponse{
        .status = 200,
        .message = "OK",
    };

    const json = try serializeToJson(ApiResponse, response, testing.allocator);
    defer testing.allocator.free(json);

    try testing.expect(std.mem.indexOf(u8, json, "\"status\":200") != null);
    try testing.expect(std.mem.indexOf(u8, json, "\"message\":\"OK\"") != null);
}

// ANCHOR: query_builder
// Query builder pattern
const QueryBuilder = struct {
    table: []const u8,
    where_clauses: std.ArrayList([]const u8),
    limit_value: ?usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, table: []const u8) QueryBuilder {
        return QueryBuilder{
            .table = table,
            .where_clauses = std.ArrayList([]const u8){},
            .limit_value = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *QueryBuilder) void {
        self.where_clauses.deinit(self.allocator);
    }

    pub fn where(self: *QueryBuilder, clause: []const u8) !*QueryBuilder {
        try self.where_clauses.append(self.allocator, clause);
        return self;
    }

    pub fn limit(self: *QueryBuilder, value: usize) *QueryBuilder {
        self.limit_value = value;
        return self;
    }

    pub fn build(self: *const QueryBuilder, allocator: std.mem.Allocator) ![]u8 {
        var result = std.ArrayList(u8){};
        errdefer result.deinit(allocator);

        try result.appendSlice(allocator, "SELECT * FROM ");
        try result.appendSlice(allocator, self.table);

        if (self.where_clauses.items.len > 0) {
            try result.appendSlice(allocator, " WHERE ");
            for (self.where_clauses.items, 0..) |clause, i| {
                if (i > 0) try result.appendSlice(allocator, " AND ");
                try result.appendSlice(allocator, clause);
            }
        }

        if (self.limit_value) |lim| {
            const limit_str = try std.fmt.allocPrint(allocator, " LIMIT {d}", .{lim});
            defer allocator.free(limit_str);
            try result.appendSlice(allocator, limit_str);
        }

        return result.toOwnedSlice(allocator);
    }
};
// ANCHOR_END: query_builder

test "query builder" {
    var query = QueryBuilder.init(testing.allocator, "users");
    defer query.deinit();

    _ = try query.where("age > 18");
    _ = try query.where("active = true");
    _ = query.limit(10);
    const sql = try query.build(testing.allocator);
    defer testing.allocator.free(sql);

    try testing.expect(std.mem.indexOf(u8, sql, "SELECT * FROM users") != null);
    try testing.expect(std.mem.indexOf(u8, sql, "WHERE age > 18 AND active = true") != null);
    try testing.expect(std.mem.indexOf(u8, sql, "LIMIT 10") != null);
}

// Comprehensive test
test "comprehensive data model" {
    const valid_user = try User.init("testuser", "test@test.com", 25);
    try valid_user.validate();

    const validated = try ValidatedUser.init("john_doe", "john@example.com");
    try testing.expectEqualStrings("john_doe", validated.username.getValue());

    var doc = Document.init("Test", "Content");
    try doc.changeStatus(.published);
    try testing.expectEqual(Status.published, doc.status);

    const product = Product{ .id = 123, .name = "Test", .price = 9.99 };
    try testing.expectEqual(@as(u32, 123), product.id);
}
