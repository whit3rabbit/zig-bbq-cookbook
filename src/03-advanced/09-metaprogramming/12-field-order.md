## Problem

You need to know the order in which fields are defined in a struct. You want to iterate over fields in definition order, serialize them in a specific sequence, validate field ordering, or create derived types that preserve or manipulate field order.

## Solution

Use `@typeInfo` to access struct metadata at compile time. Zig guarantees that the fields array returned by `@typeInfo(T).@"struct".fields` preserves the original definition order.

### Getting Field Names in Order

The simplest operation extracts field names as they were defined:

```zig
{{#include ../../../code/03-advanced/09-metaprogramming/recipe_9_12.zig:get_field_order}}
```

The array index corresponds directly to the field's position in the struct definition.

### Finding Field Positions

You can look up where a specific field appears:

```zig
fn getFieldPosition(comptime T: type, comptime field_name: []const u8) ?usize {
    const fields = @typeInfo(T).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        if (std.mem.eql(u8, field.name, field_name)) {
            return i;
        }
    }
    return null;
}

test "field positions" {
    try testing.expectEqual(@as(?usize, 0), getFieldPosition(Person, "name"));
    try testing.expectEqual(@as(?usize, 1), getFieldPosition(Person, "age"));
    try testing.expectEqual(@as(?usize, null), getFieldPosition(Person, "invalid"));
}
```

This returns `null` for fields that don't exist.

## Discussion

### Iterating Fields in Order

You can process fields sequentially using their definition order:

```zig
fn forEachField(comptime T: type, comptime func: anytype) void {
    const fields = @typeInfo(T).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        func(i, field.name);
    }
}

test "ordered iteration" {
    var count: usize = 0;
    forEachField(Person, struct {
        fn visit(index: usize, name: []const u8) void {
            _ = index;
            _ = name;
            count += 1;
        }
    }.visit);
    try testing.expectEqual(@as(usize, 3), count);
}
```

The `inline for` ensures each field is visited in order at compile time.

### Preserving Order in Generated Types

When creating wrapper types, field order is automatically preserved:

```zig
fn WithPrefix(comptime T: type, comptime prefix: []const u8) type {
    _ = prefix;
    return struct {
        const Original = T;
        original: T,

        pub fn init(original: T) @This() {
            return .{ .original = original };
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
    try testing.expectEqualStrings("name", PrefixedPerson.getFieldName(0));
    try testing.expectEqualStrings("age", PrefixedPerson.getFieldName(1));
}
```

The wrapper can query the original type's field order.

### Field Metadata Based on Position

Determine if a field is first, last, or at a specific position:

```zig
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

    try testing.expect(getFieldTypeAtIndex(Person, 0) == []const u8);
    try testing.expect(getFieldTypeAtIndex(Person, 1) == u32);
}
```

These functions use `@compileError` to catch invalid indices at compile time.

### Ordered Serialization

Serialize field names in definition order:

```zig
fn OrderedSerializer(comptime T: type) type {
    return struct {
        pub fn serializeFieldNames(allocator: std.mem.Allocator) ![]const u8 {
            const fields = @typeInfo(T).@"struct".fields;

            // Calculate total length at compile time
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

            // Fill buffer in field order
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
    };
}

test "ordered serialization" {
    const Serializer = OrderedSerializer(Person);
    const result = try Serializer.serializeFieldNames(testing.allocator);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("name,age,email", result);
}
```

The compile-time length calculation eliminates runtime overhead for size determination.

### Validating Field Order

Enforce that fields appear in a specific order:

```zig
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
```

The `comptime` block ensures validation happens during compilation.

### Adjacent Field Pairs

Work with consecutive field pairs:

```zig
fn getFieldPair(comptime T: type, comptime index: usize) struct { []const u8, []const u8 } {
    const fields = @typeInfo(T).@"struct".fields;
    const pair_count = if (fields.len < 2) 0 else fields.len - 1;
    if (index >= pair_count) {
        @compileError("Pair index out of bounds");
    }
    return .{ fields[index].name, fields[index + 1].name };
}

test "field pairs" {
    const pair1 = getFieldPair(Person, 0);
    try testing.expectEqualStrings("name", pair1[0]);
    try testing.expectEqualStrings("age", pair1[1]);

    const pair2 = getFieldPair(Person, 1);
    try testing.expectEqualStrings("age", pair2[0]);
    try testing.expectEqualStrings("email", pair2[1]);
}
```

This is useful for analyzing relationships between adjacent fields.

### Field Ranges

Extract a subset of fields by index range:

```zig
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
}
```

Bounds checking happens at compile time.

### Reversing Field Order

Get fields in reverse definition order:

```zig
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
    try testing.expectEqualStrings("email", reversed[0]);
    try testing.expectEqualStrings("age", reversed[1]);
    try testing.expectEqualStrings("name", reversed[2]);
}
```

This can be useful for processing fields in reverse dependency order.

### Filtering Fields by Type

Select fields matching specific criteria:

```zig
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
```

Filtered results maintain original definition order.

### Grouping Fields by Type

Identify where field types change:

```zig
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
    try testing.expect(isFieldGroupBoundary(Mixed, 0));  // Start of first group
    try testing.expect(!isFieldGroupBoundary(Mixed, 1)); // Same type as 'a'
    try testing.expect(isFieldGroupBoundary(Mixed, 2));  // Type changed
    try testing.expect(!isFieldGroupBoundary(Mixed, 3)); // Same type as 'c'
    try testing.expect(isFieldGroupBoundary(Mixed, 4));  // Type changed
}
```

This detects consecutive fields with the same type, useful for layout optimization or batch processing.

### Why Field Order Matters

Field definition order is significant for:

1. **Binary layout** - Affects memory layout and struct size due to alignment
2. **Serialization** - Determines wire format and compatibility
3. **Initialization order** - Some frameworks process fields sequentially
4. **API design** - Field order in constructors often mirrors struct order
5. **Code generation** - Generated code may depend on consistent ordering

Zig's guarantee that `@typeInfo` preserves definition order makes it reliable for these use cases.

### Performance Considerations

All the functions shown operate at compile time with zero runtime overhead:

- Field iteration uses `inline for`, unrolling at compile time
- Array allocations for field names are resolved during compilation
- Type comparisons and validations happen before code generation
- The only runtime cost is from explicit allocations like serialization buffers

This makes field order analysis essentially free in production code.

## See Also

- Recipe 9.10: Using decorators to patch struct definitions
- Recipe 9.11: Using comptime to control instance creation
- Recipe 9.13: Defining a generic that takes optional arguments

Full compilable example: `code/03-advanced/09-metaprogramming/recipe_9_12.zig`
