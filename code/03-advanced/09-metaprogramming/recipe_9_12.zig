// Recipe 9.12: Capturing Struct Attribute Definition Order
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: get_field_order
// Extract field names in definition order
fn getFieldNames(comptime T: type) []const []const u8 {
    const fields = @typeInfo(T).@"struct".fields;
    comptime var names: [fields.len][]const u8 = undefined;
    inline for (fields, 0..) |field, i| {
        names[i] = field.name;
    }
    const final = names;
    return &final;
}

const Person = struct {
    name: []const u8,
    age: u32,
    email: []const u8,
};

test "get field order" {
    const names = getFieldNames(Person);
    try testing.expectEqual(@as(usize, 3), names.len);
    try testing.expectEqualStrings("name", names[0]);
    try testing.expectEqualStrings("age", names[1]);
    try testing.expectEqualStrings("email", names[2]);
}
// ANCHOR_END: get_field_order

// ANCHOR: field_positions
// Get position of specific field
fn getFieldPosition(comptime T: type, comptime field_name: []const u8) ?usize {
    const fields = @typeInfo(T).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        if (std.mem.eql(u8, field.name, field_name)) {
            return i;
        }
    }
    return null;
}

fn fieldCount(comptime T: type) usize {
    return @typeInfo(T).@"struct".fields.len;
}

test "field positions" {
    try testing.expectEqual(@as(?usize, 0), getFieldPosition(Person, "name"));
    try testing.expectEqual(@as(?usize, 1), getFieldPosition(Person, "age"));
    try testing.expectEqual(@as(?usize, 2), getFieldPosition(Person, "email"));
    try testing.expectEqual(@as(?usize, null), getFieldPosition(Person, "invalid"));
    try testing.expectEqual(@as(usize, 3), fieldCount(Person));
}
// ANCHOR_END: field_positions

// ANCHOR: ordered_iteration
// Iterate fields in definition order
fn printFieldOrder(comptime T: type) void {
    const fields = @typeInfo(T).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        _ = i;
        _ = field;
        // In real code: std.debug.print("Field {}: {s}\n", .{ i, field.name });
    }
}

fn forEachField(comptime T: type, comptime func: anytype) void {
    const fields = @typeInfo(T).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        func(i, field.name);
    }
}

var field_visit_count: usize = 0;

fn visitField(index: usize, name: []const u8) void {
    _ = index;
    _ = name;
    field_visit_count += 1;
}

test "ordered iteration" {
    printFieldOrder(Person);
    field_visit_count = 0;
    forEachField(Person, visitField);
    try testing.expectEqual(@as(usize, 3), field_visit_count);
}
// ANCHOR_END: ordered_iteration

// ANCHOR: preserve_order
// Create new struct preserving field order
fn WithPrefix(comptime T: type, comptime prefix: []const u8) type {
    _ = prefix;
    // Fields are automatically in the same order
    return struct {
        const Original = T;
        original: T,

        pub fn init(original: T) @This() {
            return .{ .original = original };
        }

        pub fn getFieldCount() usize {
            return @typeInfo(T).@"struct".fields.len;
        }

        pub fn getFieldName(comptime index: usize) []const u8 {
            const fields = @typeInfo(T).@"struct".fields;
            if (index >= fields.len) {
                @compileError("Field index out of bounds");
            }
            return fields[index].name;
        }
    };
}

test "preserve order" {
    const PrefixedPerson = WithPrefix(Person, "user_");
    const p = PrefixedPerson.init(.{ .name = "Alice", .age = 30, .email = "alice@example.com" });
    try testing.expectEqualStrings("Alice", p.original.name);
    try testing.expectEqual(@as(usize, 3), PrefixedPerson.getFieldCount());
    try testing.expectEqualStrings("name", PrefixedPerson.getFieldName(0));
    try testing.expectEqualStrings("age", PrefixedPerson.getFieldName(1));
}
// ANCHOR_END: preserve_order

// ANCHOR: field_metadata
// Attach metadata to fields based on order
fn isFirstField(comptime T: type, comptime name: []const u8) bool {
    const fields = @typeInfo(T).@"struct".fields;
    if (fields.len == 0) return false;
    return std.mem.eql(u8, fields[0].name, name);
}

fn isLastField(comptime T: type, comptime name: []const u8) bool {
    const fields = @typeInfo(T).@"struct".fields;
    if (fields.len == 0) return false;
    return std.mem.eql(u8, fields[fields.len - 1].name, name);
}

fn getFieldTypeAtIndex(comptime T: type, comptime index: usize) type {
    const fields = @typeInfo(T).@"struct".fields;
    if (index >= fields.len) {
        @compileError("Field index out of bounds");
    }
    return fields[index].type;
}

test "field metadata" {
    try testing.expect(isFirstField(Person, "name"));
    try testing.expect(!isFirstField(Person, "age"));
    try testing.expect(isLastField(Person, "email"));
    try testing.expect(!isLastField(Person, "name"));

    try testing.expect(getFieldTypeAtIndex(Person, 0) == []const u8);
    try testing.expect(getFieldTypeAtIndex(Person, 1) == u32);
    try testing.expect(getFieldTypeAtIndex(Person, 2) == []const u8);
}
// ANCHOR_END: field_metadata

// ANCHOR: ordered_serialization
// Serialize fields in definition order
fn OrderedSerializer(comptime T: type) type {
    return struct {
        const Self = @This();

        pub fn serializeFieldNames(allocator: std.mem.Allocator) ![]const u8 {
            const fields = @typeInfo(T).@"struct".fields;

            // Calculate total length needed
            comptime var total_len: usize = 0;
            inline for (fields, 0..) |field, i| {
                total_len += field.name.len;
                if (i < fields.len - 1) {
                    total_len += 1; // for comma
                }
            }

            // Allocate buffer
            const buffer = try allocator.alloc(u8, total_len);
            errdefer allocator.free(buffer);

            // Fill buffer
            var pos: usize = 0;
            inline for (fields, 0..) |field, i| {
                @memcpy(buffer[pos..][0..field.name.len], field.name);
                pos += field.name.len;
                if (i < fields.len - 1) {
                    buffer[pos] = ',';
                    pos += 1;
                }
            }

            return buffer;
        }

        pub fn getFieldCount() usize {
            return @typeInfo(T).@"struct".fields.len;
        }
    };
}

test "ordered serialization" {
    const Serializer = OrderedSerializer(Person);
    const result = try Serializer.serializeFieldNames(testing.allocator);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("name,age,email", result);
    try testing.expectEqual(@as(usize, 3), Serializer.getFieldCount());
}
// ANCHOR_END: ordered_serialization

// ANCHOR: validate_order
// Validate field order matches expected
fn validateFieldOrder(comptime T: type, comptime expected: []const []const u8) bool {
    const fields = @typeInfo(T).@"struct".fields;
    if (fields.len != expected.len) return false;

    inline for (fields, 0..) |field, i| {
        if (!std.mem.eql(u8, field.name, expected[i])) {
            return false;
        }
    }
    return true;
}

test "validate order" {
    const expected = [_][]const u8{ "name", "age", "email" };
    comptime {
        if (!validateFieldOrder(Person, &expected)) {
            @compileError("Field order validation failed");
        }
    }
    try testing.expect(validateFieldOrder(Person, &expected));

    const wrong = [_][]const u8{ "age", "name", "email" };
    try testing.expect(!validateFieldOrder(Person, &wrong));
}
// ANCHOR_END: validate_order

// ANCHOR: field_pairs
// Generate adjacent field pairs
fn getFieldPair(comptime T: type, comptime index: usize) struct { []const u8, []const u8 } {
    const fields = @typeInfo(T).@"struct".fields;
    const pair_count = if (fields.len < 2) 0 else fields.len - 1;
    if (index >= pair_count) {
        @compileError("Pair index out of bounds");
    }
    return .{ fields[index].name, fields[index + 1].name };
}

fn getFieldPairCount(comptime T: type) usize {
    const field_count = @typeInfo(T).@"struct".fields.len;
    if (field_count < 2) return 0;
    return field_count - 1;
}

test "field pairs" {
    try testing.expectEqual(@as(usize, 2), getFieldPairCount(Person));

    const pair1 = getFieldPair(Person, 0);
    try testing.expectEqualStrings("name", pair1[0]);
    try testing.expectEqualStrings("age", pair1[1]);

    const pair2 = getFieldPair(Person, 1);
    try testing.expectEqualStrings("age", pair2[0]);
    try testing.expectEqualStrings("email", pair2[1]);
}
// ANCHOR_END: field_pairs

// ANCHOR: field_range
// Get fields in a range
fn getFieldRange(comptime T: type, comptime start: usize, comptime end: usize) []const []const u8 {
    const fields = @typeInfo(T).@"struct".fields;
    if (start > end or end > fields.len) {
        @compileError("Invalid field range");
    }

    comptime var result: [end - start][]const u8 = undefined;
    inline for (start..end, 0..) |i, j| {
        result[j] = fields[i].name;
    }
    const final = result;
    return &final;
}

test "field range" {
    const range = getFieldRange(Person, 0, 2);
    try testing.expectEqual(@as(usize, 2), range.len);
    try testing.expectEqualStrings("name", range[0]);
    try testing.expectEqualStrings("age", range[1]);

    const single = getFieldRange(Person, 1, 2);
    try testing.expectEqual(@as(usize, 1), single.len);
    try testing.expectEqualStrings("age", single[0]);
}
// ANCHOR_END: field_range

// ANCHOR: reverse_order
// Get fields in reverse order
fn reverseFieldOrder(comptime T: type) []const []const u8 {
    const fields = @typeInfo(T).@"struct".fields;
    comptime var reversed: [fields.len][]const u8 = undefined;

    inline for (fields, 0..) |field, i| {
        reversed[fields.len - 1 - i] = field.name;
    }
    const final = reversed;
    return &final;
}

test "reverse order" {
    const reversed = reverseFieldOrder(Person);
    try testing.expectEqual(@as(usize, 3), reversed.len);
    try testing.expectEqualStrings("email", reversed[0]);
    try testing.expectEqualStrings("age", reversed[1]);
    try testing.expectEqualStrings("name", reversed[2]);
}
// ANCHOR_END: reverse_order

// ANCHOR: field_filter
// Filter fields by type
fn getStringFields(comptime T: type) []const []const u8 {
    const fields = @typeInfo(T).@"struct".fields;

    comptime var count: usize = 0;
    inline for (fields) |field| {
        if (field.type == []const u8) {
            count += 1;
        }
    }

    comptime var result: [count][]const u8 = undefined;
    comptime var index: usize = 0;
    inline for (fields) |field| {
        if (field.type == []const u8) {
            result[index] = field.name;
            index += 1;
        }
    }

    const final = result;
    return &final;
}

fn getNumericFields(comptime T: type) []const []const u8 {
    const fields = @typeInfo(T).@"struct".fields;

    comptime var count: usize = 0;
    inline for (fields) |field| {
        const is_numeric = switch (@typeInfo(field.type)) {
            .int, .float => true,
            else => false,
        };
        if (is_numeric) {
            count += 1;
        }
    }

    comptime var result: [count][]const u8 = undefined;
    comptime var index: usize = 0;
    inline for (fields) |field| {
        const is_numeric = switch (@typeInfo(field.type)) {
            .int, .float => true,
            else => false,
        };
        if (is_numeric) {
            result[index] = field.name;
            index += 1;
        }
    }

    const final = result;
    return &final;
}

test "field filter" {
    const string_fields = getStringFields(Person);
    try testing.expectEqual(@as(usize, 2), string_fields.len);
    try testing.expectEqualStrings("name", string_fields[0]);
    try testing.expectEqualStrings("email", string_fields[1]);

    const numeric_fields = getNumericFields(Person);
    try testing.expectEqual(@as(usize, 1), numeric_fields.len);
    try testing.expectEqualStrings("age", numeric_fields[0]);
}
// ANCHOR_END: field_filter

// ANCHOR: field_grouping
// Group consecutive fields by type
fn countFieldGroups(comptime T: type) usize {
    const fields = @typeInfo(T).@"struct".fields;
    if (fields.len == 0) return 0;

    comptime var groups: usize = 1;
    comptime var prev_type = fields[0].type;

    inline for (fields[1..]) |field| {
        if (field.type != prev_type) {
            groups += 1;
            prev_type = field.type;
        }
    }

    return groups;
}

fn isFieldGroupBoundary(comptime T: type, comptime index: usize) bool {
    const fields = @typeInfo(T).@"struct".fields;
    if (index == 0 or index >= fields.len) return true;
    return fields[index].type != fields[index - 1].type;
}

const Mixed = struct {
    a: i32,
    b: i32,
    c: []const u8,
    d: []const u8,
    e: bool,
};

test "field grouping" {
    try testing.expectEqual(@as(usize, 3), countFieldGroups(Mixed));
    try testing.expect(isFieldGroupBoundary(Mixed, 0)); // Start
    try testing.expect(!isFieldGroupBoundary(Mixed, 1)); // Same as a
    try testing.expect(isFieldGroupBoundary(Mixed, 2)); // Different from b
    try testing.expect(!isFieldGroupBoundary(Mixed, 3)); // Same as c
    try testing.expect(isFieldGroupBoundary(Mixed, 4)); // Different from d
}
// ANCHOR_END: field_grouping

// Comprehensive test
test "comprehensive field order operations" {
    // Get field names
    const names = getFieldNames(Person);
    try testing.expectEqual(@as(usize, 3), names.len);

    // Field positions
    try testing.expectEqual(@as(?usize, 1), getFieldPosition(Person, "age"));

    // Metadata
    try testing.expect(isFirstField(Person, "name"));
    try testing.expect(isLastField(Person, "email"));

    // Serialization
    const Serializer = OrderedSerializer(Person);
    const serialized = try Serializer.serializeFieldNames(testing.allocator);
    defer testing.allocator.free(serialized);
    try testing.expectEqualStrings("name,age,email", serialized);

    // Validation
    const expected = [_][]const u8{ "name", "age", "email" };
    try testing.expect(validateFieldOrder(Person, &expected));

    // Reverse order
    const reversed = reverseFieldOrder(Person);
    try testing.expectEqualStrings("email", reversed[0]);

    // Filtering
    const strings = getStringFields(Person);
    try testing.expectEqual(@as(usize, 2), strings.len);
}
