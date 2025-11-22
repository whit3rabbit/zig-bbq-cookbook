// Recipe 9.2: Preserving Function Metadata When Writing Decorators
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_metadata
// Preserve function signature using @typeInfo
fn PreservingWrapper(comptime func: anytype) type {
    const func_info = @typeInfo(@TypeOf(func));
    const Fn = func_info.@"fn";

    return struct {
        pub const name = @typeName(@TypeOf(func));
        pub const return_type = Fn.return_type;
        pub const params_len = Fn.params.len;

        pub fn call(args: anytype) Fn.return_type.? {
            return @call(.auto, func, args);
        }

        pub fn getName() []const u8 {
            return name;
        }
    };
}

fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic metadata" {
    const Wrapper = PreservingWrapper(add);

    const result = Wrapper.call(.{ 5, 3 });
    try testing.expectEqual(@as(i32, 8), result);
    try testing.expectEqual(@as(usize, 2), Wrapper.params_len);
}
// ANCHOR_END: basic_metadata

// ANCHOR: error_preservation
// Preserve error sets through wrappers
fn ErrorPreservingWrapper(comptime func: anytype) type {
    const func_info = @typeInfo(@TypeOf(func));
    const ReturnType = func_info.@"fn".return_type.?;

    return struct {
        pub fn call(args: anytype) ReturnType {
            // Wrapper can still handle errors
            return @call(.auto, func, args);
        }
    };
}

fn divide(a: i32, b: i32) !i32 {
    if (b == 0) return error.DivisionByZero;
    return @divTrunc(a, b);
}

test "error preservation" {
    const Wrapper = ErrorPreservingWrapper(divide);

    const r1 = try Wrapper.call(.{ 10, 2 });
    try testing.expectEqual(@as(i32, 5), r1);

    const r2 = Wrapper.call(.{ 10, 0 });
    try testing.expectError(error.DivisionByZero, r2);
}
// ANCHOR_END: error_preservation

// ANCHOR: signature_matching
// Create wrapper that exactly matches original signature
fn SignatureMatchingWrapper(comptime func: anytype) type {
    const T = @TypeOf(func);
    const func_info = @typeInfo(T).@"fn";
    const ReturnType = func_info.return_type.?;

    return struct {
        const Self = @This();

        pub const original_type = T;
        pub const return_type = ReturnType;

        call_count: usize = 0,

        pub fn wrap(self: *Self, args: anytype) ReturnType {
            self.call_count += 1;
            return @call(.auto, func, args);
        }
    };
}

fn multiply(x: i32, y: i32, z: i32) i32 {
    return x * y * z;
}

test "signature matching" {
    const Wrapper = SignatureMatchingWrapper(multiply);
    var wrapper = Wrapper{};

    const r1 = wrapper.wrap(.{ 2, 3, 4 });
    const r2 = wrapper.wrap(.{ 1, 2, 3 });

    try testing.expectEqual(@as(i32, 24), r1);
    try testing.expectEqual(@as(i32, 6), r2);
    try testing.expectEqual(@as(usize, 2), wrapper.call_count);
}
// ANCHOR_END: signature_matching

// ANCHOR: generic_metadata
// Extract and expose all function metadata
fn MetadataExtractor(comptime func: anytype) type {
    const func_info = @typeInfo(@TypeOf(func));

    if (func_info != .@"fn") {
        @compileError("Expected function type");
    }

    const fn_info = func_info.@"fn";

    return struct {
        pub const Info = struct {
            pub const is_generic = fn_info.is_generic;
            pub const is_var_args = fn_info.is_var_args;
            pub const calling_convention = fn_info.calling_convention;
            pub const param_count = fn_info.params.len;
            pub const has_return = fn_info.return_type != null;
        };

        pub fn call(args: anytype) fn_info.return_type.? {
            return @call(.auto, func, args);
        }
    };
}

fn example(a: i32, b: i32) i32 {
    return a + b;
}

test "generic metadata" {
    const Meta = MetadataExtractor(example);

    try testing.expect(!Meta.Info.is_generic);
    try testing.expect(!Meta.Info.is_var_args);
    try testing.expectEqual(@as(usize, 2), Meta.Info.param_count);
    try testing.expect(Meta.Info.has_return);

    const result = Meta.call(.{ 10, 20 });
    try testing.expectEqual(@as(i32, 30), result);
}
// ANCHOR_END: generic_metadata

// ANCHOR: documentation_wrapper
// Wrapper that adds documentation metadata
fn DocumentedWrapper(
    comptime func: anytype,
    comptime doc: []const u8,
) type {
    const func_info = @typeInfo(@TypeOf(func));
    const ReturnType = func_info.@"fn".return_type.?;

    return struct {
        pub const documentation = doc;
        pub const wrapped_function = func;

        pub fn call(args: anytype) ReturnType {
            return @call(.auto, func, args);
        }

        pub fn getDoc() []const u8 {
            return documentation;
        }
    };
}

fn square(x: i32) i32 {
    return x * x;
}

test "documentation wrapper" {
    const Wrapped = DocumentedWrapper(square, "Computes the square of x");

    const result = Wrapped.call(.{5});
    try testing.expectEqual(@as(i32, 25), result);

    const doc = Wrapped.getDoc();
    try testing.expectEqualStrings("Computes the square of x", doc);
}
// ANCHOR_END: documentation_wrapper

// ANCHOR: optional_preservation
// Preserve optional return types
fn OptionalPreservingWrapper(comptime func: anytype) type {
    const func_info = @typeInfo(@TypeOf(func));
    const ReturnType = func_info.@"fn".return_type.?;

    return struct {
        pub fn call(args: anytype) ReturnType {
            const result = @call(.auto, func, args);
            return result;
        }
    };
}

fn findValue(arr: []const i32, target: i32) ?usize {
    for (arr, 0..) |val, i| {
        if (val == target) return i;
    }
    return null;
}

test "optional preservation" {
    const Wrapper = OptionalPreservingWrapper(findValue);

    const arr = [_]i32{ 1, 2, 3, 4, 5 };

    const r1 = Wrapper.call(.{ &arr, 3 });
    try testing.expectEqual(@as(?usize, 2), r1);

    const r2 = Wrapper.call(.{ &arr, 10 });
    try testing.expectEqual(@as(?usize, null), r2);
}
// ANCHOR_END: optional_preservation

// ANCHOR: allocator_wrapper
// Preserve allocator-taking functions
fn AllocatorWrapper(comptime func: anytype) type {
    const func_info = @typeInfo(@TypeOf(func));
    const ReturnType = func_info.@"fn".return_type.?;

    return struct {
        allocations: usize = 0,

        pub fn call(self: *@This(), allocator: std.mem.Allocator, args: anytype) ReturnType {
            self.allocations += 1;
            const full_args = .{allocator} ++ args;
            return @call(.auto, func, full_args);
        }

        pub fn getAllocationCount(self: *const @This()) usize {
            return self.allocations;
        }
    };
}

fn allocateArray(allocator: std.mem.Allocator, size: usize) ![]i32 {
    return try allocator.alloc(i32, size);
}

test "allocator wrapper" {
    const Wrapper = AllocatorWrapper(allocateArray);
    var wrapper = Wrapper{};

    const arr1 = try wrapper.call(testing.allocator, .{5});
    defer testing.allocator.free(arr1);

    const arr2 = try wrapper.call(testing.allocator, .{3});
    defer testing.allocator.free(arr2);

    try testing.expectEqual(@as(usize, 5), arr1.len);
    try testing.expectEqual(@as(usize, 3), arr2.len);
    try testing.expectEqual(@as(usize, 2), wrapper.getAllocationCount());
}
// ANCHOR_END: allocator_wrapper

// ANCHOR: multi_return_wrapper
// Handle functions with complex return types
fn ComplexReturnWrapper(comptime func: anytype) type {
    const func_info = @typeInfo(@TypeOf(func));
    const ReturnType = func_info.@"fn".return_type.?;

    return struct {
        pub const return_type = ReturnType;

        pub fn call(args: anytype) ReturnType {
            return @call(.auto, func, args);
        }

        pub fn getReturnTypeName() []const u8 {
            return @typeName(ReturnType);
        }
    };
}

fn divmod(a: i32, b: i32) struct { quotient: i32, remainder: i32 } {
    return .{
        .quotient = @divTrunc(a, b),
        .remainder = @rem(a, b),
    };
}

test "multi return wrapper" {
    const Wrapper = ComplexReturnWrapper(divmod);

    const result = Wrapper.call(.{ 17, 5 });
    try testing.expectEqual(@as(i32, 3), result.quotient);
    try testing.expectEqual(@as(i32, 2), result.remainder);
}
// ANCHOR_END: multi_return_wrapper

// ANCHOR: type_safe_wrapper
// Compile-time type safety in wrappers
fn TypeSafeWrapper(comptime func: anytype, comptime ExpectedReturn: type) type {
    const func_info = @typeInfo(@TypeOf(func));
    const ActualReturn = func_info.@"fn".return_type.?;

    // Compile-time check
    if (ActualReturn != ExpectedReturn) {
        @compileError("Return type mismatch");
    }

    return struct {
        pub fn call(args: anytype) ExpectedReturn {
            return @call(.auto, func, args);
        }
    };
}

fn increment(x: i32) i32 {
    return x + 1;
}

test "type safe wrapper" {
    const Wrapper = TypeSafeWrapper(increment, i32);
    const result = Wrapper.call(.{5});
    try testing.expectEqual(@as(i32, 6), result);

    // This would fail at compile time:
    // const BadWrapper = TypeSafeWrapper(increment, i64);
}
// ANCHOR_END: type_safe_wrapper

// ANCHOR: void_return_wrapper
// Handle void return functions
fn VoidReturnWrapper(comptime func: anytype) type {
    const func_info = @typeInfo(@TypeOf(func));
    const ReturnType = func_info.@"fn".return_type;

    return struct {
        call_count: usize = 0,

        pub fn call(self: *@This(), args: anytype) if (ReturnType) |T| T else void {
            self.call_count += 1;
            if (ReturnType) |_| {
                return @call(.auto, func, args);
            } else {
                @call(.auto, func, args);
            }
        }
    };
}

var side_effect: i32 = 0;

fn voidFunc(x: i32) void {
    side_effect = x;
}

test "void return wrapper" {
    const Wrapper = VoidReturnWrapper(voidFunc);
    var wrapper = Wrapper{};

    wrapper.call(.{42});
    try testing.expectEqual(@as(i32, 42), side_effect);
    try testing.expectEqual(@as(usize, 1), wrapper.call_count);

    wrapper.call(.{100});
    try testing.expectEqual(@as(i32, 100), side_effect);
    try testing.expectEqual(@as(usize, 2), wrapper.call_count);
}
// ANCHOR_END: void_return_wrapper

// Comprehensive test
test "comprehensive metadata preservation" {
    // Test basic metadata extraction
    const Meta = MetadataExtractor(example);
    try testing.expectEqual(@as(usize, 2), Meta.Info.param_count);

    // Test error preservation
    const ErrWrapper = ErrorPreservingWrapper(divide);
    const err_result = try ErrWrapper.call(.{ 10, 2 });
    try testing.expectEqual(@as(i32, 5), err_result);

    // Test optional preservation
    const OptWrapper = OptionalPreservingWrapper(findValue);
    const arr = [_]i32{ 1, 2, 3 };
    const opt_result = OptWrapper.call(.{ &arr, 2 });
    try testing.expectEqual(@as(?usize, 1), opt_result);

    // Test documentation
    const DocWrapper = DocumentedWrapper(square, "Square function");
    try testing.expectEqualStrings("Square function", DocWrapper.getDoc());

    // Test void return
    const VoidWrapper = VoidReturnWrapper(voidFunc);
    var void_wrap = VoidWrapper{};
    void_wrap.call(.{50});
    try testing.expectEqual(@as(i32, 50), side_effect);
}
