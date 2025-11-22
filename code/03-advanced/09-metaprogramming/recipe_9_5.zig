// Recipe 9.5: Enforcing Type Checking on a Function Using a Decorator
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: parameter_type_check
// Enforce parameter types at compile time
fn WithParameterCheck(comptime func: anytype, comptime ExpectedParams: []const type) type {
    const func_info = @typeInfo(@TypeOf(func));
    const params = func_info.@"fn".params;

    if (params.len != ExpectedParams.len) {
        @compileError("Parameter count mismatch");
    }

    inline for (params, ExpectedParams, 0..) |param, expected, i| {
        if (param.type.? != expected) {
            @compileError(std.fmt.comptimePrint(
                "Parameter {d} type mismatch: expected {s}, got {s}",
                .{ i, @typeName(expected), @typeName(param.type.?) },
            ));
        }
    }

    return struct {
        pub fn call(args: anytype) func_info.@"fn".return_type.? {
            return @call(.auto, func, args);
        }
    };
}

fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "parameter type check" {
    const expected = [_]type{ i32, i32 };
    const Checked = WithParameterCheck(add, &expected);

    const result = Checked.call(.{ 5, 3 });
    try testing.expectEqual(@as(i32, 8), result);

    // This would fail at compile time:
    // const bad_params = [_]type{ i64, i32 };
    // const Bad = WithParameterCheck(add, &bad_params);
}
// ANCHOR_END: parameter_type_check

// ANCHOR: return_type_check
// Enforce return type at compile time
fn WithReturnCheck(comptime func: anytype, comptime ExpectedReturn: type) type {
    const func_info = @typeInfo(@TypeOf(func));
    const ActualReturn = func_info.@"fn".return_type.?;

    if (ActualReturn != ExpectedReturn) {
        @compileError(std.fmt.comptimePrint(
            "Return type mismatch: expected {s}, got {s}",
            .{ @typeName(ExpectedReturn), @typeName(ActualReturn) },
        ));
    }

    return struct {
        pub fn call(args: anytype) ExpectedReturn {
            return @call(.auto, func, args);
        }
    };
}

fn double(x: i32) i32 {
    return x * 2;
}

test "return type check" {
    const Checked = WithReturnCheck(double, i32);
    const result = Checked.call(.{5});
    try testing.expectEqual(@as(i32, 10), result);

    // This would fail at compile time:
    // const Bad = WithReturnCheck(double, i64);
}
// ANCHOR_END: return_type_check

// ANCHOR: error_set_check
// Enforce error set requirements
fn WithErrorCheck(comptime func: anytype, comptime RequiredErrors: type) type {
    _ = RequiredErrors; // For future enhancement
    const func_info = @typeInfo(@TypeOf(func));
    const return_info = @typeInfo(func_info.@"fn".return_type.?);

    if (return_info != .error_union) {
        @compileError("Function must return an error union");
    }

    return struct {
        pub fn call(args: anytype) func_info.@"fn".return_type.? {
            return @call(.auto, func, args);
        }
    };
}

fn divide(a: i32, b: i32) !i32 {
    if (b == 0) return error.DivisionByZero;
    return @divTrunc(a, b);
}

test "error set check" {
    const Checked = WithErrorCheck(divide, error{DivisionByZero});

    const r1 = try Checked.call(.{ 10, 2 });
    try testing.expectEqual(@as(i32, 5), r1);

    const r2 = Checked.call(.{ 10, 0 });
    try testing.expectError(error.DivisionByZero, r2);
}
// ANCHOR_END: error_set_check

// ANCHOR: numeric_constraint
// Constrain to numeric types only
fn NumericOnly(comptime func: anytype) type {
    const func_info = @typeInfo(@TypeOf(func));
    const return_type = func_info.@"fn".return_type.?;
    const return_info = @typeInfo(return_type);

    if (return_info != .int and return_info != .float) {
        @compileError("Function must return numeric type");
    }

    for (func_info.@"fn".params) |param| {
        const param_info = @typeInfo(param.type.?);
        if (param_info != .int and param_info != .float) {
            @compileError("All parameters must be numeric");
        }
    }

    return struct {
        pub fn call(args: anytype) return_type {
            return @call(.auto, func, args);
        }
    };
}

fn multiply(x: i32, y: i32) i32 {
    return x * y;
}

test "numeric constraint" {
    const Checked = NumericOnly(multiply);
    const result = Checked.call(.{ 4, 5 });
    try testing.expectEqual(@as(i32, 20), result);
}
// ANCHOR_END: numeric_constraint

// ANCHOR: signed_integer_check
// Require signed integer types
fn SignedIntegersOnly(comptime func: anytype) type {
    const func_info = @typeInfo(@TypeOf(func));

    for (func_info.@"fn".params) |param| {
        const param_info = @typeInfo(param.type.?);
        if (param_info != .int) {
            @compileError("All parameters must be integers");
        }
        if (param_info.int.signedness != .signed) {
            @compileError("All integer parameters must be signed");
        }
    }

    return struct {
        pub fn call(args: anytype) func_info.@"fn".return_type.? {
            return @call(.auto, func, args);
        }
    };
}

fn negate(x: i32) i32 {
    return -x;
}

test "signed integer check" {
    const Checked = SignedIntegersOnly(negate);
    const result = Checked.call(.{5});
    try testing.expectEqual(@as(i32, -5), result);
}
// ANCHOR_END: signed_integer_check

// ANCHOR: pointer_check
// Enforce pointer parameter types
fn RequiresPointer(comptime func: anytype, comptime index: usize) type {
    const func_info = @typeInfo(@TypeOf(func));
    const params = func_info.@"fn".params;

    if (index >= params.len) {
        @compileError("Parameter index out of range");
    }

    const param_info = @typeInfo(params[index].type.?);
    if (param_info != .pointer) {
        @compileError(std.fmt.comptimePrint(
            "Parameter {d} must be a pointer",
            .{index},
        ));
    }

    return struct {
        pub fn call(args: anytype) func_info.@"fn".return_type.? {
            return @call(.auto, func, args);
        }
    };
}

fn increment(x: *i32) void {
    x.* += 1;
}

test "pointer check" {
    const Checked = RequiresPointer(increment, 0);

    var val: i32 = 10;
    Checked.call(.{&val});
    try testing.expectEqual(@as(i32, 11), val);
}
// ANCHOR_END: pointer_check

// ANCHOR: slice_check
// Enforce slice types
fn RequiresSlice(comptime func: anytype, comptime ElementType: type) type {
    const func_info = @typeInfo(@TypeOf(func));
    const params = func_info.@"fn".params;

    var found_slice = false;
    for (params) |param| {
        // Check if this is a slice by seeing if it matches []const T or []T pattern
        const param_type = param.type.?;
        const type_name = @typeName(param_type);

        // Slices start with "[]" in their type name
        if (std.mem.startsWith(u8, type_name, "[]")) {
            // Check if element type matches
            const param_info = @typeInfo(param_type);
            if (param_info == .pointer) {
                if (param_info.pointer.child == ElementType) {
                    found_slice = true;
                    break;
                }
            }
        }
    }

    if (!found_slice) {
        @compileError(std.fmt.comptimePrint(
            "Function must have a slice parameter of type []const {s}",
            .{@typeName(ElementType)},
        ));
    }

    return struct {
        pub fn call(args: anytype) func_info.@"fn".return_type.? {
            return @call(.auto, func, args);
        }
    };
}

fn sum(items: []const i32) i32 {
    var total: i32 = 0;
    for (items) |item| {
        total += item;
    }
    return total;
}

test "slice check" {
    const Checked = RequiresSlice(sum, i32);

    const items = [_]i32{ 1, 2, 3, 4, 5 };
    const result = Checked.call(.{&items});
    try testing.expectEqual(@as(i32, 15), result);
}
// ANCHOR_END: slice_check

// ANCHOR: optional_check
// Enforce optional return types
fn ReturnsOptional(comptime func: anytype, comptime PayloadType: type) type {
    const func_info = @typeInfo(@TypeOf(func));
    const return_type = func_info.@"fn".return_type.?;
    const return_info = @typeInfo(return_type);

    if (return_info != .optional) {
        @compileError("Function must return an optional type");
    }

    if (return_info.optional.child != PayloadType) {
        @compileError(std.fmt.comptimePrint(
            "Optional payload must be {s}, not {s}",
            .{ @typeName(PayloadType), @typeName(return_info.optional.child) },
        ));
    }

    return struct {
        pub fn call(args: anytype) return_type {
            return @call(.auto, func, args);
        }
    };
}

fn findFirst(items: []const i32, target: i32) ?usize {
    for (items, 0..) |item, i| {
        if (item == target) return i;
    }
    return null;
}

test "optional check" {
    const Checked = ReturnsOptional(findFirst, usize);

    const items = [_]i32{ 10, 20, 30, 40 };
    const r1 = Checked.call(.{ &items, 30 });
    try testing.expectEqual(@as(?usize, 2), r1);

    const r2 = Checked.call(.{ &items, 99 });
    try testing.expectEqual(@as(?usize, null), r2);
}
// ANCHOR_END: optional_check

// ANCHOR: struct_field_check
// Enforce struct parameter with specific fields
fn RequiresStructWithFields(comptime func: anytype, comptime required_fields: []const []const u8) type {
    const func_info = @typeInfo(@TypeOf(func));
    const params = func_info.@"fn".params;

    if (params.len == 0) {
        @compileError("Function must have at least one parameter");
    }

    const first_param = params[0].type.?;
    const param_info = @typeInfo(first_param);

    if (param_info != .@"struct") {
        @compileError("First parameter must be a struct");
    }

    inline for (required_fields) |field_name| {
        if (!@hasField(first_param, field_name)) {
            @compileError(std.fmt.comptimePrint(
                "Struct must have field: {s}",
                .{field_name},
            ));
        }
    }

    return struct {
        pub fn call(args: anytype) func_info.@"fn".return_type.? {
            return @call(.auto, func, args);
        }
    };
}

const Point = struct {
    x: i32,
    y: i32,
};

fn distance(p: Point) i32 {
    return p.x + p.y;
}

test "struct field check" {
    const required = [_][]const u8{ "x", "y" };
    const Checked = RequiresStructWithFields(distance, &required);

    const p = Point{ .x = 3, .y = 4 };
    const result = Checked.call(.{p});
    try testing.expectEqual(@as(i32, 7), result);
}
// ANCHOR_END: struct_field_check

// ANCHOR: allocator_check
// Ensure function takes allocator as first parameter
fn RequiresAllocator(comptime func: anytype) type {
    const func_info = @typeInfo(@TypeOf(func));
    const params = func_info.@"fn".params;

    if (params.len == 0) {
        @compileError("Function must have at least one parameter");
    }

    const first_param = params[0].type.?;
    if (first_param != std.mem.Allocator) {
        @compileError(std.fmt.comptimePrint(
            "First parameter must be std.mem.Allocator, got {s}",
            .{@typeName(first_param)},
        ));
    }

    return struct {
        pub fn call(args: anytype) func_info.@"fn".return_type.? {
            return @call(.auto, func, args);
        }
    };
}

fn allocateSlice(allocator: std.mem.Allocator, size: usize) ![]i32 {
    return try allocator.alloc(i32, size);
}

test "allocator check" {
    const Checked = RequiresAllocator(allocateSlice);

    const slice = try Checked.call(.{ testing.allocator, 5 });
    defer testing.allocator.free(slice);

    try testing.expectEqual(@as(usize, 5), slice.len);
}
// ANCHOR_END: allocator_check

// ANCHOR: pure_function_check
// Enforce that function has no side effects (no void parameters/returns)
fn PureFunction(comptime func: anytype) type {
    const func_info = @typeInfo(@TypeOf(func));

    if (func_info.@"fn".return_type == null) {
        @compileError("Pure function must return a value");
    }

    for (func_info.@"fn".params) |param| {
        const param_type = param.type.?;
        const param_info = @typeInfo(param_type);

        if (param_info == .pointer) {
            // Allow const pointers and slices (read-only access)
            const is_slice = std.mem.startsWith(u8, @typeName(param_type), "[]");
            if (param_info.pointer.is_const == false and !is_slice) {
                @compileError("Pure function cannot have mutable pointer parameters");
            }
        }
    }

    return struct {
        pub fn call(args: anytype) func_info.@"fn".return_type.? {
            return @call(.auto, func, args);
        }
    };
}

fn square(x: i32) i32 {
    return x * x;
}

test "pure function check" {
    const Checked = PureFunction(square);
    const result = Checked.call(.{7});
    try testing.expectEqual(@as(i32, 49), result);
}
// ANCHOR_END: pure_function_check

// Comprehensive test
test "comprehensive type checking" {
    // Parameter type checking
    const param_types = [_]type{ i32, i32 };
    const CheckedAdd = WithParameterCheck(add, &param_types);
    try testing.expectEqual(@as(i32, 8), CheckedAdd.call(.{ 5, 3 }));

    // Return type checking
    const CheckedDouble = WithReturnCheck(double, i32);
    try testing.expectEqual(@as(i32, 10), CheckedDouble.call(.{5}));

    // Error set checking
    const CheckedDivide = WithErrorCheck(divide, error{DivisionByZero});
    try testing.expectEqual(@as(i32, 5), try CheckedDivide.call(.{ 10, 2 }));

    // Numeric constraint
    const CheckedMultiply = NumericOnly(multiply);
    try testing.expectEqual(@as(i32, 20), CheckedMultiply.call(.{ 4, 5 }));

    // Pure function
    const CheckedSquare = PureFunction(square);
    try testing.expectEqual(@as(i32, 49), CheckedSquare.call(.{7}));
}
