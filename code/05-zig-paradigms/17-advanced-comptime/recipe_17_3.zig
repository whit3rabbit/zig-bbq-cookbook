// Recipe 17.3: Compile-Time Assertion and Contract Validation
// This recipe demonstrates how to create sophisticated compile-time assertions
// that validate type relationships, struct layouts, and API contracts with
// clear error messages.

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_assertions
/// Basic compile-time assertion with custom error message
fn assertComptime(comptime condition: bool, comptime message: []const u8) void {
    if (!condition) {
        @compileError(message);
    }
}

/// Assert that a type is numeric
fn assertNumeric(comptime T: type) void {
    const info = @typeInfo(T);
    switch (info) {
        .int, .comptime_int, .float, .comptime_float => {},
        else => @compileError("Type " ++ @typeName(T) ++ " is not numeric"),
    }
}

/// Assert that a type has a specific size
fn assertSize(comptime T: type, comptime expected_size: usize) void {
    const actual_size = @sizeOf(T);
    if (actual_size != expected_size) {
        @compileError(std.fmt.comptimePrint(
            "Type {s} has size {d}, expected {d}",
            .{ @typeName(T), actual_size, expected_size },
        ));
    }
}

test "basic compile-time assertions" {
    // These assertions pass
    assertNumeric(i32);
    assertNumeric(f64);
    assertSize(u32, 4);
    assertSize(u64, 8);

    // Uncomment to see compile errors:
    // assertNumeric(bool);  // Error: Type bool is not numeric
    // assertSize(u32, 8);   // Error: Type u32 has size 4, expected 8
}
// ANCHOR_END: basic_assertions

// ANCHOR: type_relationships
/// Assert that two types are the same
fn assertSameType(comptime T: type, comptime U: type) void {
    if (T != U) {
        @compileError(std.fmt.comptimePrint(
            "Type mismatch: {s} != {s}",
            .{ @typeName(T), @typeName(U) },
        ));
    }
}

/// Assert that T can be coerced to U
fn assertCoercible(comptime T: type, comptime U: type) void {
    const dummy: T = undefined;
    _ = @as(U, dummy);
}

/// Assert that a type is a pointer
fn assertPointer(comptime T: type) void {
    const info = @typeInfo(T);
    switch (info) {
        .pointer => {},
        else => @compileError("Type " ++ @typeName(T) ++ " is not a pointer"),
    }
}

test "type relationship assertions" {
    assertSameType(i32, i32);
    assertPointer(*u8);
    assertPointer(*const u32);

    // These would fail at compile time:
    // assertSameType(i32, u32);
    // assertPointer(u8);
}
// ANCHOR_END: type_relationships

// ANCHOR: struct_field_validation
/// Check if a struct has a specific field (returns bool for use in tests)
fn hasField(comptime T: type, comptime field_name: []const u8) bool {
    const info = @typeInfo(T);
    switch (info) {
        .@"struct" => |struct_info| {
            inline for (struct_info.fields) |field| {
                if (std.mem.eql(u8, field.name, field_name)) {
                    return true;
                }
            }
            return false;
        },
        else => return false,
    }
}

/// Get field type if it exists (returns ?type for use in tests)
fn getFieldType(comptime T: type, comptime field_name: []const u8) ?type {
    const info = @typeInfo(T);
    switch (info) {
        .@"struct" => |struct_info| {
            inline for (struct_info.fields) |field| {
                if (std.mem.eql(u8, field.name, field_name)) {
                    return field.type;
                }
            }
            return null;
        },
        else => return null,
    }
}

const TestStruct = struct {
    id: u32,
    name: []const u8,
    value: f64,
};

test "struct field validation" {
    // Test field existence
    try testing.expect(hasField(TestStruct, "id"));
    try testing.expect(hasField(TestStruct, "name"));
    try testing.expect(hasField(TestStruct, "value"));
    try testing.expect(!hasField(TestStruct, "missing"));

    // Test field types
    try testing.expectEqual(u32, getFieldType(TestStruct, "id").?);
    try testing.expectEqual([]const u8, getFieldType(TestStruct, "name").?);
    try testing.expectEqual(f64, getFieldType(TestStruct, "value").?);
    try testing.expectEqual(@as(?type, null), getFieldType(TestStruct, "missing"));

    // Example of how to use in compile-time assertions:
    comptime {
        if (!hasField(TestStruct, "id")) {
            @compileError("TestStruct must have id field");
        }
        if (getFieldType(TestStruct, "id").? != u32) {
            @compileError("TestStruct.id must be u32");
        }
    }
}
// ANCHOR_END: struct_field_validation

// ANCHOR: interface_validation
/// Assert that a type implements required methods (duck typing)
fn assertHasMethod(
    comptime T: type,
    comptime method_name: []const u8,
) void {
    if (!@hasDecl(T, method_name)) {
        @compileError(std.fmt.comptimePrint(
            "Type {s} does not implement method '{s}'",
            .{ @typeName(T), method_name },
        ));
    }
}

/// Assert that a type implements multiple methods
fn assertImplements(
    comptime T: type,
    comptime methods: []const []const u8,
) void {
    inline for (methods) |method_name| {
        assertHasMethod(T, method_name);
    }
}

const Writer = struct {
    pub fn write(self: *Writer, data: []const u8) !usize {
        _ = self;
        _ = data;
        return 0;
    }

    pub fn flush(self: *Writer) !void {
        _ = self;
    }
};

test "interface validation" {
    assertHasMethod(Writer, "write");
    assertHasMethod(Writer, "flush");

    assertImplements(Writer, &[_][]const u8{ "write", "flush" });

    // Would fail:
    // assertHasMethod(Writer, "missing");
}
// ANCHOR_END: interface_validation

// ANCHOR: alignment_assertions
/// Assert that a type has specific alignment
fn assertAlignment(comptime T: type, comptime expected: usize) void {
    const actual = @alignOf(T);
    if (actual != expected) {
        @compileError(std.fmt.comptimePrint(
            "Type {s} has alignment {d}, expected {d}",
            .{ @typeName(T), actual, expected },
        ));
    }
}

/// Assert that a type is packed (no padding)
fn assertPacked(comptime T: type) void {
    const info = @typeInfo(T);
    switch (info) {
        .@"struct" => |struct_info| {
            if (struct_info.layout != .@"packed") {
                @compileError("Struct " ++ @typeName(T) ++ " is not packed");
            }
        },
        else => @compileError("Type " ++ @typeName(T) ++ " is not a struct"),
    }
}

const PackedStruct = packed struct {
    a: u8,
    b: u16,
    c: u8,
};

test "alignment assertions" {
    assertAlignment(u8, 1);
    assertAlignment(u16, 2);
    assertAlignment(u32, 4);
    assertAlignment(u64, 8);

    assertPacked(PackedStruct);
}
// ANCHOR_END: alignment_assertions

// ANCHOR: range_validation
/// Assert that a value is within a valid range
fn assertInRange(
    comptime T: type,
    comptime value: T,
    comptime min: T,
    comptime max: T,
) void {
    if (value < min or value > max) {
        @compileError(std.fmt.comptimePrint(
            "Value {d} is outside range [{d}, {d}]",
            .{ value, min, max },
        ));
    }
}

/// Assert that an array has a specific length
fn assertArrayLength(comptime T: type, comptime expected_len: usize) void {
    const info = @typeInfo(T);
    switch (info) {
        .array => |arr_info| {
            if (arr_info.len != expected_len) {
                @compileError(std.fmt.comptimePrint(
                    "Array has length {d}, expected {d}",
                    .{ arr_info.len, expected_len },
                ));
            }
        },
        else => @compileError("Type " ++ @typeName(T) ++ " is not an array"),
    }
}

test "range validation" {
    assertInRange(u32, 50, 0, 100);
    assertInRange(i32, -10, -100, 100);

    assertArrayLength([5]u8, 5);
    assertArrayLength([10]i32, 10);

    // Would fail:
    // assertInRange(u32, 150, 0, 100);
    // assertArrayLength([5]u8, 10);
}
// ANCHOR_END: range_validation

// ANCHOR: build_configuration
/// Assert debug mode for development-only code
fn assertDebugMode() void {
    const mode = @import("builtin").mode;
    if (mode != .Debug) {
        @compileError("This code only works in Debug mode");
    }
}

/// Assert release mode for performance-critical code
fn assertReleaseMode() void {
    const mode = @import("builtin").mode;
    if (mode == .Debug) {
        @compileError("This code requires release mode optimizations");
    }
}

/// Assert specific target architecture
fn assertArch(comptime expected: std.Target.Cpu.Arch) void {
    const actual = @import("builtin").cpu.arch;
    if (actual != expected) {
        @compileError(std.fmt.comptimePrint(
            "Expected architecture {s}, found {s}",
            .{ @tagName(expected), @tagName(actual) },
        ));
    }
}

test "build configuration assertions" {
    // These depend on build settings
    const mode = @import("builtin").mode;
    _ = mode;

    // Example: assertArch would check CPU architecture
    // assertArch(.x86_64);
}
// ANCHOR_END: build_configuration

// ANCHOR: contract_validation
/// Design by contract: require preconditions
fn requireContract(comptime condition: bool, comptime message: []const u8) void {
    if (!condition) {
        @compileError("Contract violation: " ++ message);
    }
}

/// Generic function with compile-time contracts
fn divideArray(comptime T: type, comptime len: usize) type {
    // Contracts
    assertNumeric(T);
    requireContract(len > 0, "Array length must be positive");
    requireContract(len % 2 == 0, "Array length must be even");

    return struct {
        first_half: [len / 2]T,
        second_half: [len / 2]T,
    };
}

test "contract validation" {
    const Result4 = divideArray(i32, 4);
    const r4: Result4 = undefined;
    try testing.expectEqual(2, r4.first_half.len);
    try testing.expectEqual(2, r4.second_half.len);

    const Result10 = divideArray(f64, 10);
    const r10: Result10 = undefined;
    try testing.expectEqual(5, r10.first_half.len);
    try testing.expectEqual(5, r10.second_half.len);

    // Would fail at compile time:
    // const Bad1 = divideArray(bool, 4);  // Not numeric
    // const Bad2 = divideArray(i32, 0);   // Length not positive
    // const Bad3 = divideArray(i32, 5);   // Length not even
}
// ANCHOR_END: contract_validation

// ANCHOR: custom_validators
/// Composite validator for numeric types in a specific range
fn ValidatedNumeric(
    comptime T: type,
    comptime min_bits: u16,
    comptime max_bits: u16,
) type {
    assertNumeric(T);

    const info = @typeInfo(T);
    const bits = switch (info) {
        .int => |int_info| int_info.bits,
        .float => |float_info| float_info.bits,
        else => unreachable,
    };

    if (bits < min_bits or bits > max_bits) {
        @compileError(std.fmt.comptimePrint(
            "Type {s} has {d} bits, must be between {d} and {d}",
            .{ @typeName(T), bits, min_bits, max_bits },
        ));
    }

    return T;
}

/// Builder pattern for complex validation
fn ValidatedStruct(comptime T: type) type {
    // Validate it's a struct
    const info = @typeInfo(T);
    if (info != .@"struct") {
        @compileError("ValidatedStruct requires a struct type");
    }

    // Ensure struct has at least one field
    if (info.@"struct".fields.len == 0) {
        @compileError("Struct must have at least one field");
    }

    return T;
}

test "custom validators" {
    const Small = ValidatedNumeric(u8, 8, 16);
    try testing.expectEqual(u8, Small);

    const Medium = ValidatedNumeric(u32, 16, 64);
    try testing.expectEqual(u32, Medium);

    const Valid = ValidatedStruct(TestStruct);
    try testing.expectEqual(TestStruct, Valid);

    // Would fail:
    // const TooBig = ValidatedNumeric(u128, 8, 64);
    // const Empty = ValidatedStruct(struct {});
}
// ANCHOR_END: custom_validators
