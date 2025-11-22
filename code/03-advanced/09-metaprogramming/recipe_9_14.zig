// Recipe 9.14: Enforcing an Argument Signature on Tuple Arguments
// Target Zig Version: 0.15.2
//
// Performance Note: All validation in this recipe happens at compile-time.
// There is ZERO runtime cost for these checks. Invalid code will not compile,
// and valid code runs at full speed with no overhead.

const std = @import("std");
const testing = std.testing;

// ANCHOR: validate_types
// Validate that all tuple arguments match a specific type
fn validateAllTypes(comptime T: type, args: anytype) void {
    const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
    inline for (fields) |field| {
        if (field.type != T) {
            @compileError("All arguments must be of the specified type");
        }
    }
}

fn sumInts(args: anytype) i32 {
    comptime validateAllTypes(i32, args);

    var total: i32 = 0;
    const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
    inline for (fields) |field| {
        total += @field(args, field.name);
    }
    return total;
}

test "validate types" {
    const r1 = sumInts(.{ @as(i32, 1), @as(i32, 2), @as(i32, 3) });
    try testing.expectEqual(@as(i32, 6), r1);

    const r2 = sumInts(.{@as(i32, 10)});
    try testing.expectEqual(@as(i32, 10), r2);

    // This would fail at compile time:
    // const r3 = sumInts(.{ @as(i32, 1), 2.5, @as(i32, 3) });
}
// ANCHOR_END: validate_types

// ANCHOR: min_max_args
// Enforce minimum and maximum argument counts
fn requireArgCount(comptime min: usize, comptime max: usize, args: anytype) void {
    const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
    if (fields.len < min) {
        @compileError("Too few arguments");
    }
    if (fields.len > max) {
        @compileError("Too many arguments");
    }
}

fn average(args: anytype) f64 {
    comptime requireArgCount(1, 10, args);
    // Note: This function assumes integer arguments. For mixed numeric types,
    // see the multiplyAll function which explicitly validates numeric types.

    var total: f64 = 0;
    const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
    inline for (fields) |field| {
        const value = @field(args, field.name);
        total += @as(f64, @floatFromInt(value));
    }
    return total / @as(f64, @floatFromInt(fields.len));
}

test "min max args" {
    const r1 = average(.{10});
    try testing.expectEqual(@as(f64, 10.0), r1);

    const r2 = average(.{ 10, 20, 30 });
    try testing.expectEqual(@as(f64, 20.0), r2);

    // These would fail at compile time:
    // const r3 = average(.{}); // Too few
    // const r4 = average(.{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }); // Too many
}
// ANCHOR_END: min_max_args

// ANCHOR: typed_signature
// Enforce a specific signature pattern
fn enforceSignature(comptime Signature: type, args: anytype) void {
    const sig_fields = @typeInfo(Signature).@"struct".fields;
    const arg_fields = @typeInfo(@TypeOf(args)).@"struct".fields;

    if (sig_fields.len != arg_fields.len) {
        @compileError("Argument count mismatch");
    }

    inline for (sig_fields, 0..) |sig_field, i| {
        if (arg_fields[i].type != sig_field.type) {
            @compileError("Argument type mismatch");
        }
    }
}

fn processTyped(args: anytype) i32 {
    const Signature = struct { i32, []const u8, bool };
    comptime enforceSignature(Signature, args);

    const num = args[0];
    const str = args[1];
    const flag = args[2];

    if (flag) {
        return num + @as(i32, @intCast(str.len));
    }
    return num;
}

test "typed signature" {
    const str1: []const u8 = "hello";
    const str2: []const u8 = "test";

    const r1 = processTyped(.{ @as(i32, 10), str1, true });
    try testing.expectEqual(@as(i32, 15), r1);

    const r2 = processTyped(.{ @as(i32, 20), str2, false });
    try testing.expectEqual(@as(i32, 20), r2);

    // This would fail at compile time:
    // const r3 = processTyped(.{ @as(i32, 10), str1 }); // Wrong count
    // const r4 = processTyped(.{ 10, 20, true }); // Wrong types
}
// ANCHOR_END: typed_signature

// ANCHOR: homogeneous_tuple
// Ensure all arguments are the same type
fn HomogeneousArgs(comptime T: type) type {
    return struct {
        pub fn call(args: anytype) T {
            const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
            if (fields.len == 0) {
                @compileError("At least one argument required");
            }

            inline for (fields) |field| {
                if (field.type != T) {
                    @compileError("All arguments must be of the same type");
                }
            }

            return @field(args, fields[0].name);
        }
    };
}

fn firstInt(args: anytype) i32 {
    return HomogeneousArgs(i32).call(args);
}

test "homogeneous tuple" {
    const r1 = firstInt(.{@as(i32, 42)});
    try testing.expectEqual(@as(i32, 42), r1);

    const r2 = firstInt(.{ @as(i32, 1), @as(i32, 2), @as(i32, 3), @as(i32, 4), @as(i32, 5) });
    try testing.expectEqual(@as(i32, 1), r2);

    // This would fail at compile time:
    // const r3 = firstInt(.{ @as(i32, 1), "hello", @as(i32, 3) });
}
// ANCHOR_END: homogeneous_tuple

// ANCHOR: numeric_only
// Validate numeric types only
fn isNumeric(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .int, .float, .comptime_int, .comptime_float => true,
        else => false,
    };
}

fn validateNumeric(args: anytype) void {
    const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
    inline for (fields) |field| {
        if (!isNumeric(field.type)) {
            @compileError("Only numeric types allowed");
        }
    }
}

fn multiplyAll(args: anytype) f64 {
    comptime validateNumeric(args);

    var result: f64 = 1.0;
    const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
    inline for (fields) |field| {
        const value = @field(args, field.name);
        const float_val = switch (@typeInfo(field.type)) {
            .int, .comptime_int => @as(f64, @floatFromInt(value)),
            .float, .comptime_float => @as(f64, @floatCast(value)),
            else => unreachable,
        };
        result *= float_val;
    }
    return result;
}

test "numeric only" {
    const r1 = multiplyAll(.{ 2, 3, 4 });
    try testing.expectEqual(@as(f64, 24.0), r1);

    const r2 = multiplyAll(.{ 2.5, 4.0 });
    try testing.expectEqual(@as(f64, 10.0), r2);

    const r3 = multiplyAll(.{ @as(i32, 5), @as(f32, 2.0) });
    try testing.expectEqual(@as(f64, 10.0), r3);

    // This would fail at compile time:
    // const r4 = multiplyAll(.{ 2, "hello", 4 });
}
// ANCHOR_END: numeric_only

// ANCHOR: first_type_determines
// First argument determines type for rest
fn FirstTypeDetermines(args: anytype) type {
    const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
    if (fields.len == 0) {
        @compileError("At least one argument required");
    }

    const FirstType = fields[0].type;
    inline for (fields[1..]) |field| {
        if (field.type != FirstType) {
            @compileError("All arguments must match the first argument's type");
        }
    }

    return FirstType;
}

fn maxValue(args: anytype) FirstTypeDetermines(args) {
    var max_val = args[0];

    const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
    inline for (fields[1..]) |field| {
        const value = @field(args, field.name);
        if (value > max_val) {
            max_val = value;
        }
    }

    return max_val;
}

test "first type determines" {
    const r1 = maxValue(.{ 3, 7, 2, 9, 1 });
    try testing.expectEqual(9, r1);

    const r2 = maxValue(.{ 3.5, 1.2, 7.8 });
    try testing.expect(r2 > 7.7 and r2 < 7.9);

    // This would fail at compile time:
    // const r3 = maxValue(.{ 3, 7.5, 2 }); // Mixed types
}
// ANCHOR_END: first_type_determines

// ANCHOR: alternate_types
// Validate alternating type pattern
fn validateAlternating(comptime T1: type, comptime T2: type, args: anytype) void {
    const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        const expected_type = if (i % 2 == 0) T1 else T2;
        if (field.type != expected_type) {
            @compileError("Arguments must alternate between specified types");
        }
    }
}

fn processAlternating(args: anytype) i32 {
    comptime validateAlternating(i32, []const u8, args);

    var sum: i32 = 0;
    const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
    inline for (fields, 0..) |field, i| {
        if (i % 2 == 0) {
            sum += @field(args, field.name);
        }
    }
    return sum;
}

test "alternate types" {
    const s1: []const u8 = "a";
    const s2: []const u8 = "b";
    const s3: []const u8 = "c";
    const s4: []const u8 = "test";

    const r1 = processAlternating(.{ @as(i32, 10), s1, @as(i32, 20), s2, @as(i32, 30), s3 });
    try testing.expectEqual(@as(i32, 60), r1);

    const r2 = processAlternating(.{ @as(i32, 5), s4 });
    try testing.expectEqual(@as(i32, 5), r2);

    // This would fail at compile time:
    // const r3 = processAlternating(.{ 10, 20, 30 }); // Not alternating
}
// ANCHOR_END: alternate_types

// ANCHOR: key_value_pairs
// Enforce key-value pair structure
fn validateKeyValuePairs(comptime KeyType: type, comptime ValueType: type, args: anytype) void {
    const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
    if (fields.len % 2 != 0) {
        @compileError("Arguments must be in key-value pairs");
    }

    inline for (fields, 0..) |field, i| {
        const expected_type = if (i % 2 == 0) KeyType else ValueType;
        if (field.type != expected_type) {
            @compileError("Key-value types don't match");
        }
    }
}

fn countPairs(args: anytype) usize {
    comptime validateKeyValuePairs([]const u8, i32, args);
    const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
    return fields.len / 2;
}

test "key value pairs" {
    const k1: []const u8 = "age";
    const k2: []const u8 = "score";
    const k3: []const u8 = "count";

    const r1 = countPairs(.{ k1, @as(i32, 30), k2, @as(i32, 100) });
    try testing.expectEqual(@as(usize, 2), r1);

    const r2 = countPairs(.{ k3, @as(i32, 42) });
    try testing.expectEqual(@as(usize, 1), r2);

    // These would fail at compile time:
    // const r3 = countPairs(.{ k1, @as(i32, 30), k2 }); // Odd count
    // const r4 = countPairs(.{ k1, k2 }); // Wrong value type
}
// ANCHOR_END: key_value_pairs

// ANCHOR: min_one_max_rest
// First argument required, rest optional
fn requireFirstArg(comptime FirstType: type, args: anytype) void {
    const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
    if (fields.len == 0) {
        @compileError("At least one argument required");
    }
    if (fields[0].type != FirstType) {
        @compileError("First argument must be of specified type");
    }
}

fn formatMessage(args: anytype) []const u8 {
    comptime requireFirstArg([]const u8, args);
    return args[0];
}

test "min one max rest" {
    const msg1: []const u8 = "hello";
    const msg2: []const u8 = "message";

    const r1 = formatMessage(.{msg1});
    try testing.expectEqualStrings("hello", r1);

    const r2 = formatMessage(.{ msg2, 42, true });
    try testing.expectEqualStrings("message", r2);

    // These would fail at compile time:
    // const r3 = formatMessage(.{}); // No arguments
    // const r4 = formatMessage(.{ 42, msg1 }); // Wrong first type
}
// ANCHOR_END: min_one_max_rest

// ANCHOR: type_predicate
// Use predicate function to validate types
fn TypePredicate(comptime predicate: fn (type) bool) type {
    return struct {
        pub fn validate(args: anytype) void {
            const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
            inline for (fields) |field| {
                if (!predicate(field.type)) {
                    @compileError("Argument type fails predicate");
                }
            }
        }
    };
}

fn isInteger(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .int, .comptime_int => true,
        else => false,
    };
}

fn sumIntegers(args: anytype) i64 {
    comptime TypePredicate(isInteger).validate(args);

    var total: i64 = 0;
    const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
    inline for (fields) |field| {
        total += @as(i64, @field(args, field.name));
    }
    return total;
}

test "type predicate" {
    const r1 = sumIntegers(.{ @as(i32, 10), @as(i8, 20), @as(u16, 30) });
    try testing.expectEqual(@as(i64, 60), r1);

    // This would fail at compile time:
    // const r2 = sumIntegers(.{ 10, 2.5, 30 }); // Contains float
}
// ANCHOR_END: type_predicate

// ANCHOR: count_constraint
// Validate exact argument count
fn requireExactCount(comptime count: usize, args: anytype) void {
    const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
    if (fields.len != count) {
        @compileError("Exact argument count required");
    }
}

fn triple(args: anytype) struct { i32, i32, i32 } {
    comptime requireExactCount(3, args);
    comptime validateAllTypes(i32, args);

    return .{ args[0], args[1], args[2] };
}

test "count constraint" {
    const result = triple(.{ @as(i32, 1), @as(i32, 2), @as(i32, 3) });
    try testing.expectEqual(@as(i32, 1), result[0]);
    try testing.expectEqual(@as(i32, 2), result[1]);
    try testing.expectEqual(@as(i32, 3), result[2]);

    // These would fail at compile time:
    // const r2 = triple(.{ @as(i32, 1), @as(i32, 2) }); // Too few
    // const r3 = triple(.{ @as(i32, 1), @as(i32, 2), @as(i32, 3), @as(i32, 4) }); // Too many
}
// ANCHOR_END: count_constraint

// Comprehensive test
test "comprehensive signature validation" {
    // Type validation
    const sum_result = sumInts(.{ @as(i32, 1), @as(i32, 2), @as(i32, 3), @as(i32, 4), @as(i32, 5) });
    try testing.expectEqual(@as(i32, 15), sum_result);

    // Count validation
    const avg_result = average(.{ 10, 20, 30 });
    try testing.expectEqual(@as(f64, 20.0), avg_result);

    // Signature enforcement
    const world: []const u8 = "world";
    const proc_result = processTyped(.{ @as(i32, 5), world, false });
    try testing.expectEqual(@as(i32, 5), proc_result);

    // Numeric validation
    const mult_result = multiplyAll(.{ 2, 3, 4 });
    try testing.expectEqual(@as(f64, 24.0), mult_result);

    // Max value
    const max_result = maxValue(.{ 5, 9, 3, 7 });
    try testing.expectEqual(9, max_result);

    // Key-value pairs
    const ka: []const u8 = "a";
    const kb: []const u8 = "b";
    const pair_count = countPairs(.{ ka, @as(i32, 1), kb, @as(i32, 2) });
    try testing.expectEqual(@as(usize, 2), pair_count);
}
