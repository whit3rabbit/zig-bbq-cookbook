// Recipe 9.3: Unwrapping a Decorator
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_unwrapping
// Wrapper that exposes the original function
fn Unwrappable(comptime func: anytype) type {
    const func_info = @typeInfo(@TypeOf(func));
    const ReturnType = func_info.@"fn".return_type.?;

    return struct {
        pub const original = func;
        pub const wrapped_type = @TypeOf(func);

        pub fn call(args: anytype) ReturnType {
            return @call(.auto, func, args);
        }

        pub fn unwrap() @TypeOf(func) {
            return func;
        }
    };
}

fn double(x: i32) i32 {
    return x * 2;
}

test "basic unwrapping" {
    const Wrapped = Unwrappable(double);

    const result1 = Wrapped.call(.{5});
    try testing.expectEqual(@as(i32, 10), result1);

    // Access original function
    const orig = Wrapped.unwrap();
    const result2 = orig(5);
    try testing.expectEqual(@as(i32, 10), result2);

    // Direct access to original
    const result3 = Wrapped.original(5);
    try testing.expectEqual(@as(i32, 10), result3);
}
// ANCHOR_END: basic_unwrapping

// ANCHOR: layered_unwrapping
// Multiple wrapper layers that can be peeled off
fn Layer1(comptime func: anytype) type {
    return struct {
        pub const inner = func;
        pub const layer_name = "Layer1";

        pub fn call(x: i32) i32 {
            const result = func(x);
            return result + 1;
        }

        pub fn unwrap() @TypeOf(func) {
            return func;
        }
    };
}

fn Layer2(comptime func: anytype) type {
    return struct {
        pub const inner = func;
        pub const layer_name = "Layer2";

        pub fn call(x: i32) i32 {
            const result = func(x);
            return result * 2;
        }

        pub fn unwrap() @TypeOf(func) {
            return func;
        }
    };
}

fn base(x: i32) i32 {
    return x;
}

test "layered unwrapping" {
    const L1 = Layer1(base);
    const L2 = Layer2(L1.call);

    // Through both layers: (x + 1) * 2
    const result = L2.call(5);
    try testing.expectEqual(@as(i32, 12), result);

    // Unwrap one layer
    const unwrapped_once = L2.unwrap();
    const result2 = unwrapped_once(5);
    try testing.expectEqual(@as(i32, 6), result2);

    // Access inner layer
    const inner = L1.unwrap();
    const result3 = inner(5);
    try testing.expectEqual(@as(i32, 5), result3);
}
// ANCHOR_END: layered_unwrapping

// ANCHOR: metadata_preservation
// Unwrapping preserves original metadata
fn MetadataWrapper(comptime func: anytype) type {
    const func_info = @typeInfo(@TypeOf(func));
    const ReturnType = func_info.@"fn".return_type.?;

    return struct {
        pub const original_function = func;
        pub const original_name = @typeName(@TypeOf(func));
        pub const param_count = func_info.@"fn".params.len;

        pub fn call(args: anytype) ReturnType {
            return @call(.auto, func, args);
        }

        pub fn getOriginal() @TypeOf(func) {
            return func;
        }

        pub fn getMetadata() []const u8 {
            return original_name;
        }
    };
}

fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "metadata preservation" {
    const Wrapped = MetadataWrapper(add);

    try testing.expectEqual(@as(usize, 2), Wrapped.param_count);

    const orig = Wrapped.getOriginal();
    const result = orig(3, 7);
    try testing.expectEqual(@as(i32, 10), result);
}
// ANCHOR_END: metadata_preservation

// ANCHOR: conditional_unwrapping
// Conditionally unwrap based on type
fn ConditionalUnwrap(comptime T: type) type {
    const type_info = @typeInfo(T);
    const has_unwrap = switch (type_info) {
        .@"struct", .@"enum", .@"union", .@"opaque" => @hasDecl(T, "unwrap"),
        else => false,
    };

    if (has_unwrap) {
        return struct {
            pub fn get() @TypeOf(T.unwrap()) {
                return T.unwrap();
            }

            pub fn isWrapped() bool {
                return true;
            }
        };
    } else {
        return struct {
            pub fn get() void {
                // Can't return the type if it's not wrapped
            }

            pub fn isWrapped() bool {
                return false;
            }
        };
    }
}

fn plain(x: i32) i32 {
    return x * 3;
}

test "conditional unwrapping" {
    const Wrapped = Unwrappable(plain);
    const UnwrapHelper = ConditionalUnwrap(Wrapped);

    try testing.expect(UnwrapHelper.isWrapped());

    const PlainHelper = ConditionalUnwrap(@TypeOf(plain));
    try testing.expect(!PlainHelper.isWrapped());
}
// ANCHOR_END: conditional_unwrapping

// ANCHOR: state_unwrapping
// Unwrap stateful wrappers
fn StatefulWrapper(comptime func: anytype) type {
    const func_info = @typeInfo(@TypeOf(func));
    const ReturnType = func_info.@"fn".return_type.?;

    return struct {
        const Self = @This();

        pub const wrapped = func;
        call_count: usize = 0,

        pub fn call(self: *Self, args: anytype) ReturnType {
            self.call_count += 1;
            return @call(.auto, func, args);
        }

        pub fn getWrapped() @TypeOf(func) {
            return func;
        }

        pub fn getCallCount(self: *const Self) usize {
            return self.call_count;
        }
    };
}

fn increment(x: i32) i32 {
    return x + 1;
}

test "state unwrapping" {
    const Wrapper = StatefulWrapper(increment);
    var wrapper = Wrapper{};

    _ = wrapper.call(.{5});
    _ = wrapper.call(.{10});

    try testing.expectEqual(@as(usize, 2), wrapper.getCallCount());

    // Get original function without state
    const orig = Wrapper.getWrapped();
    const result = orig(5);
    try testing.expectEqual(@as(i32, 6), result);
}
// ANCHOR_END: state_unwrapping

// ANCHOR: recursive_unwrapping
// Unwrap all layers to get to the original
fn DeepUnwrap(comptime T: type) type {
    const type_info = @typeInfo(T);
    const can_check_decls = switch (type_info) {
        .@"struct", .@"enum", .@"union", .@"opaque" => true,
        else => false,
    };

    if (can_check_decls) {
        if (@hasDecl(T, "inner")) {
            // Has another layer
            const InnerType = @TypeOf(T.inner);
            return DeepUnwrap(InnerType);
        } else if (@hasDecl(T, "original")) {
            // This is the original
            return @TypeOf(T.original);
        }
    }

    return T;
}

fn original(x: i32) i32 {
    return x;
}

test "recursive unwrapping" {
    const L1 = Layer1(original);
    const L2 = Layer2(L1.call);

    // Get the deeply nested type
    const DeepType = DeepUnwrap(L2);

    // Verify it's the original function type
    try testing.expectEqual(@TypeOf(L1.unwrap()), DeepType);
}
// ANCHOR_END: recursive_unwrapping

// ANCHOR: runtime_unwrapping
// Runtime unwrapping with dynamic dispatch
const FuncWrapper = struct {
    const Self = @This();

    call_fn: *const fn (i32) i32,
    original_fn: *const fn (i32) i32,

    pub fn init(func: *const fn (i32) i32) Self {
        return Self{
            .call_fn = func,
            .original_fn = func,
        };
    }

    pub fn call(self: *const Self, x: i32) i32 {
        return self.call_fn(x);
    }

    pub fn unwrap(self: *const Self) *const fn (i32) i32 {
        return self.original_fn;
    }
};

fn triple(x: i32) i32 {
    return x * 3;
}

test "runtime unwrapping" {
    const wrapper = FuncWrapper.init(&triple);

    const result1 = wrapper.call(5);
    try testing.expectEqual(@as(i32, 15), result1);

    const orig = wrapper.unwrap();
    const result2 = orig(5);
    try testing.expectEqual(@as(i32, 15), result2);
}
// ANCHOR_END: runtime_unwrapping

// ANCHOR: wrapper_chain
// Chain of wrappers with full unwrap path
fn ChainableWrapper(comptime func: anytype, comptime name: []const u8) type {
    return struct {
        pub const wrapped_function = func;
        pub const wrapper_name = name;

        pub fn call(x: i32) i32 {
            return func(x);
        }

        pub fn unwrap() @TypeOf(func) {
            return func;
        }

        pub fn getName() []const u8 {
            return name;
        }
    };
}

fn identity(x: i32) i32 {
    return x;
}

test "wrapper chain" {
    const W1 = ChainableWrapper(identity, "First");
    const W2 = ChainableWrapper(W1.call, "Second");
    const W3 = ChainableWrapper(W2.call, "Third");

    try testing.expectEqualStrings("Third", W3.getName());
    try testing.expectEqualStrings("Second", W2.getName());
    try testing.expectEqualStrings("First", W1.getName());

    const result = W3.call(42);
    try testing.expectEqual(@as(i32, 42), result);
}
// ANCHOR_END: wrapper_chain

// ANCHOR: type_safe_unwrap
// Type-safe unwrapping with compile-time checks
fn TypeSafeUnwrap(comptime Wrapper: type, comptime ExpectedType: type) type {
    return struct {
        pub fn unwrap() ExpectedType {
            if (!@hasDecl(Wrapper, "unwrap")) {
                @compileError("Type does not support unwrapping");
            }

            const unwrapped = Wrapper.unwrap();
            const ActualType = @TypeOf(unwrapped);

            if (ActualType != ExpectedType) {
                @compileError("Unwrapped type does not match expected type");
            }

            return unwrapped;
        }
    };
}

fn square(x: i32) i32 {
    return x * x;
}

test "type safe unwrap" {
    const Wrapped = Unwrappable(square);
    const Unwrapper = TypeSafeUnwrap(Wrapped, @TypeOf(square));

    const orig = Unwrapper.unwrap();
    const result = orig(7);
    try testing.expectEqual(@as(i32, 49), result);
}
// ANCHOR_END: type_safe_unwrap

// ANCHOR: partial_unwrapping
// Unwrap to a specific layer depth
fn UnwrapToDepth(comptime T: type, comptime depth: usize) type {
    if (depth == 0) {
        return T;
    } else {
        if (@hasDecl(T, "inner")) {
            const InnerType = @TypeOf(T.inner);
            return UnwrapToDepth(InnerType, depth - 1);
        } else {
            return T;
        }
    }
}

test "partial unwrapping" {
    const L1 = Layer1(base);
    const L2 = Layer2(L1.call);

    // Unwrap to depth 0 (no unwrapping)
    const Depth0 = UnwrapToDepth(L2, 0);
    try testing.expectEqual(L2, Depth0);

    // Unwrap to depth 1
    const Depth1 = UnwrapToDepth(L2, 1);
    try testing.expectEqual(@TypeOf(L1.call), Depth1);
}
// ANCHOR_END: partial_unwrapping

// Comprehensive test
test "comprehensive unwrapping" {
    // Test basic unwrapping
    const W1 = Unwrappable(double);
    const orig1 = W1.unwrap();
    try testing.expectEqual(@as(i32, 10), orig1(5));

    // Test layered unwrapping
    const L1 = Layer1(base);
    const L2 = Layer2(L1.call);
    try testing.expectEqual(@as(i32, 12), L2.call(5));

    // Test stateful unwrapping
    const SW = StatefulWrapper(increment);
    var sw = SW{};
    _ = sw.call(.{1});
    const orig2 = SW.getWrapped();
    try testing.expectEqual(@as(i32, 6), orig2(5));

    // Test conditional unwrapping
    const CU = ConditionalUnwrap(W1);
    try testing.expect(CU.isWrapped());

    // Test wrapper chain
    const C1 = ChainableWrapper(identity, "A");
    const C2 = ChainableWrapper(C1.call, "B");
    try testing.expectEqualStrings("B", C2.getName());
}
