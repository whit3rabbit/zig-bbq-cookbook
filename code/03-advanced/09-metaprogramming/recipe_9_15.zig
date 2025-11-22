// Recipe 9.15: Enforcing Coding Conventions in Structs
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to use compile-time validation to enforce
// naming conventions, field requirements, and structural patterns in structs.

const std = @import("std");
const testing = std.testing;

// ANCHOR: snake_case_validation
// Enforce snake_case naming convention for fields
fn isSnakeCase(name: []const u8) bool {
    if (name.len == 0) return false;

    // Must start with lowercase letter
    if (name[0] < 'a' or name[0] > 'z') return false;

    for (name) |c| {
        const valid = (c >= 'a' and c <= 'z') or (c >= '0' and c <= '9') or c == '_';
        if (!valid) return false;
    }

    return true;
}

fn enforceSnakeCase(comptime T: type) void {
    const fields = @typeInfo(T).@"struct".fields;
    inline for (fields) |field| {
        if (!isSnakeCase(field.name)) {
            @compileError("Field '" ++ field.name ++ "' must use snake_case naming");
        }
    }
}

const ValidSnakeCase = struct {
    user_name: []const u8,
    age_in_years: u32,
    is_active: bool,
};

test "snake case validation" {
    comptime enforceSnakeCase(ValidSnakeCase);

    const user = ValidSnakeCase{
        .user_name = "alice",
        .age_in_years = 30,
        .is_active = true,
    };
    try testing.expectEqualStrings("alice", user.user_name);

    // This would fail at compile time:
    // const InvalidCamelCase = struct { userName: []const u8 };
    // comptime enforceSnakeCase(InvalidCamelCase);
}
// ANCHOR_END: snake_case_validation

// ANCHOR: required_fields
// Enforce that specific fields must be present
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

    // This would fail at compile time:
    // const IncompleteUser = struct { id: u64, name: []const u8 };
    // comptime requireFields(IncompleteUser, &required);
}
// ANCHOR_END: required_fields

// ANCHOR: forbidden_names
// Forbid specific field names
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

    // This would fail at compile time:
    // const UnsafeConfig = struct { password: []const u8 };
    // comptime forbidFields(UnsafeConfig, &forbidden);
}
// ANCHOR_END: forbidden_names

// ANCHOR: field_count_constraints
// Enforce minimum and maximum field counts
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

    // This would fail at compile time:
    // const TooFew = struct { x: f64 };
    // comptime requireFieldCount(TooFew, 2, 4);
}
// ANCHOR_END: field_count_constraints

// ANCHOR: type_requirements
// Enforce that all fields of a certain name have a specific type
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

    // This would fail at compile time:
    // const WrongType = struct { id: i32 };
    // comptime requireFieldType(WrongType, "id", u64);
}
// ANCHOR_END: type_requirements

// ANCHOR: prefix_convention
// Enforce field name prefixes
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

    // This would fail at compile time:
    // const NoPrefixData = struct { public_field: u64 };
    // comptime requirePrefix(NoPrefixData, "_");
}
// ANCHOR_END: prefix_convention

// ANCHOR: no_optional_fields
// Forbid optional fields
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

    // This would fail at compile time:
    // const OptionalData = struct { name: ?[]const u8 };
    // comptime forbidOptionalFields(OptionalData);
}
// ANCHOR_END: no_optional_fields

// ANCHOR: require_id_field
// Require an 'id' field of integer type
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

    // This would fail at compile time:
    // const NoId = struct { name: []const u8 };
    // comptime requireIdField(NoId);
}
// ANCHOR_END: require_id_field

// ANCHOR: field_order_validation
// Validate that 'id' field comes first
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

    // This would fail at compile time:
    // const WrongOrder = struct { name: []const u8, id: u64 };
    // comptime requireIdFirst(WrongOrder);
}
// ANCHOR_END: field_order_validation

// ANCHOR: combined_validation
// Combine multiple validators for comprehensive enforcement
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
// ANCHOR_END: combined_validation

// ANCHOR: camel_case_validation
// Enforce camelCase naming convention
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

    // This would fail at compile time:
    // const InvalidSnake = struct { first_name: []const u8 };
    // comptime enforceCamelCase(InvalidSnake);
}
// ANCHOR_END: camel_case_validation

// ANCHOR: no_pointer_fields
// Forbid single-item pointer fields for safety
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

    // This would fail at compile time:
    // const UnsafeData = struct { ptr: *u8 };
    // comptime forbidSinglePointerFields(UnsafeData);
}
// ANCHOR_END: no_pointer_fields

// ANCHOR: suffix_convention
// Require fields to end with a specific suffix
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

    // This would fail at compile time:
    // const NoSuffix = struct { total: u64 };
    // comptime requireSuffix(NoSuffix, "_count");
}
// ANCHOR_END: suffix_convention

// Comprehensive test
test "comprehensive convention enforcement" {
    // Snake case convention
    comptime enforceSnakeCase(ValidSnakeCase);

    // Required fields present
    const required_user_fields = [_][]const u8{ "id", "name", "email" };
    comptime requireFields(User, &required_user_fields);

    // No forbidden fields
    const forbidden_config_fields = [_][]const u8{ "password", "secret" };
    comptime forbidFields(SafeConfig, &forbidden_config_fields);

    // Field count in range
    comptime requireFieldCount(Point3D, 2, 4);

    // Specific type enforcement
    comptime requireFieldType(Entity, "id", u64);

    // Prefix convention
    comptime requirePrefix(PrivateData, "_");

    // No optionals
    comptime forbidOptionalFields(RequiredFields);

    // ID field required
    comptime requireIdField(Product);

    // ID must be first
    comptime requireIdFirst(Record);

    // Camel case convention
    comptime enforceCamelCase(CamelCaseData);

    // No single-item pointers
    comptime forbidSinglePointerFields(SafeData);

    // Suffix convention
    comptime requireSuffix(MetricsData, "_count");

    try testing.expect(true);
}
