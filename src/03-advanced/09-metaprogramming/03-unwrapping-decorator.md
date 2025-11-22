## Problem

You've wrapped functions with decorators but need to access the original unwrapped function, inspect wrapper layers, or remove decorator behavior. You want to extract the underlying function from a chain of wrappers.

## Solution

Expose the original function through the wrapper type using public constants and unwrap methods. Use `@hasDecl` to check if types support unwrapping and `@TypeOf` to extract function types from wrappers.

### Basic Unwrapping

Store and expose the original function in the wrapper:

```zig
{{#include ../../../code/03-advanced/09-metaprogramming/recipe_9_3.zig:basic_unwrapping}}
```

The original function remains accessible through multiple pathways.

### Layered Unwrapping

Peel off wrapper layers one at a time:

```zig
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

// Usage
const L1 = Layer1(base);
const L2 = Layer2(L1.call);

// Through both layers: (x + 1) * 2
const result = L2.call(5);  // 12

// Unwrap one layer
const unwrapped_once = L2.unwrap();
const result2 = unwrapped_once(5);  // 6

// Access inner layer
const inner = L1.unwrap();
const result3 = inner(5);  // 5
```

Each layer can be unwrapped independently.

### Metadata Preservation

Keep original function metadata when unwrapping:

```zig
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

// Usage
const Wrapped = MetadataWrapper(add);
// Wrapped.param_count == 2
const orig = Wrapped.getOriginal();
const result = orig(3, 7);  // 10
```

Metadata survives unwrapping operations.

### Conditional Unwrapping

Check if a type supports unwrapping before attempting it:

```zig
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

// Usage
const Wrapped = Unwrappable(plain);
const UnwrapHelper = ConditionalUnwrap(Wrapped);
// UnwrapHelper.isWrapped() == true

const PlainHelper = ConditionalUnwrap(@TypeOf(plain));
// PlainHelper.isWrapped() == false
```

Runtime checks determine if unwrapping is available.

### Stateful Wrapper Unwrapping

Extract original function from stateful wrappers:

```zig
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

// Usage
const Wrapper = StatefulWrapper(increment);
var wrapper = Wrapper{};
_ = wrapper.call(.{5});
_ = wrapper.call(.{10});
// wrapper.getCallCount() == 2

// Get original function without state
const orig = Wrapper.getWrapped();
const result = orig(5);  // 6
```

State and original function are separate concerns.

### Recursive Unwrapping

Unwrap all layers to reach the original function:

```zig
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

// Usage
const L1 = Layer1(original);
const L2 = Layer2(L1.call);

// Get the deeply nested type
const DeepType = DeepUnwrap(L2);
// DeepType is the original function type
```

Recursion peels off all wrapper layers.

### Runtime Unwrapping

Support unwrapping with runtime function pointers:

```zig
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

// Usage
const wrapper = FuncWrapper.init(&triple);
const result1 = wrapper.call(5);  // 15

const orig = wrapper.unwrap();
const result2 = orig(5);  // 15
```

Runtime wrappers track original function pointers.

### Wrapper Chain

Build and navigate wrapper chains:

```zig
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

// Usage
const W1 = ChainableWrapper(identity, "First");
const W2 = ChainableWrapper(W1.call, "Second");
const W3 = ChainableWrapper(W2.call, "Third");

// W3.getName() == "Third"
// W2.getName() == "Second"
// W1.getName() == "First"

const result = W3.call(42);  // 42
```

Named wrappers help track layer identity.

### Type-Safe Unwrapping

Enforce expected types at compile time:

```zig
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

// Usage
const Wrapped = Unwrappable(square);
const Unwrapper = TypeSafeUnwrap(Wrapped, @TypeOf(square));
const orig = Unwrapper.unwrap();
const result = orig(7);  // 49
```

Type mismatches cause compile errors.

### Partial Unwrapping

Unwrap to a specific depth in the wrapper chain:

```zig
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

// Usage
const L1 = Layer1(base);
const L2 = Layer2(L1.call);

// Unwrap to depth 0 (no unwrapping)
const Depth0 = UnwrapToDepth(L2, 0);  // L2

// Unwrap to depth 1
const Depth1 = UnwrapToDepth(L2, 1);  // L1.call type
```

Control how many layers to peel off.

## Discussion

Unwrapping decorators provides access to original functions while preserving the ability to use wrapped versions.

### Why Unwrapping Matters

**Testing**:
- Test original function directly
- Verify wrapper behavior separately
- Mock or stub wrapped functions
- Compare wrapped vs unwrapped

**Debugging**:
- Call original without wrapper overhead
- Isolate bugs to wrapper or function
- Profile performance differences
- Inspect intermediate states

**Introspection**:
- Query wrapper chain depth
- Identify active decorators
- Extract metadata
- Validate wrapper composition

**Flexibility**:
- Conditionally use wrappers
- Remove wrappers at runtime
- Reconfigure decorator chain
- Access both wrapped and unwrapped

### Unwrapping Patterns

**Public constant**:
```zig
return struct {
    pub const original = func;
};
```

Simplest approach, direct access.

**Unwrap method**:
```zig
pub fn unwrap() @TypeOf(func) {
    return func;
}
```

More explicit, follows naming convention.

**Typed constant**:
```zig
pub const wrapped_function: @TypeOf(func) = func;
```

Type annotation for clarity.

**Inner reference**:
```zig
pub const inner = func;  // For nested wrappers
```

Indicates another layer exists.

### Checking for Unwrap Support

**Use @hasDecl safely**:
```zig
const type_info = @typeInfo(T);
const can_check = switch (type_info) {
    .@"struct", .@"enum", .@"union", .@"opaque" => true,
    else => false,
};

if (can_check and @hasDecl(T, "unwrap")) {
    // Can unwrap
}
```

`@hasDecl` only works on aggregate types.

**Compile-time check**:
```zig
if (!@hasDecl(Wrapper, "unwrap")) {
    @compileError("Wrapper must support unwrapping");
}
```

Enforce unwrapping support at compile time.

**Runtime check**:
```zig
pub fn isUnwrappable(comptime T: type) bool {
    const info = @typeInfo(T);
    return switch (info) {
        .@"struct" => @hasDecl(T, "unwrap"),
        else => false,
    };
}
```

### Layer Navigation

**Direct unwrap**:
```zig
const orig = Wrapper.unwrap();  // One layer
```

**Chain unwrap**:
```zig
const layer1 = Layer3.unwrap();
const layer2 = layer1.unwrap();
const orig = layer2.unwrap();
```

**Recursive unwrap**:
```zig
const DeepType = DeepUnwrap(MultiLayerWrapper);
```

**Depth-controlled**:
```zig
const PartialType = UnwrapToDepth(Wrapper, 2);
```

### Metadata Extraction

**Function type**:
```zig
pub const wrapped_type = @TypeOf(func);
```

**Function name**:
```zig
pub const original_name = @typeName(@TypeOf(func));
```

**Parameter count**:
```zig
pub const param_count = @typeInfo(@TypeOf(func)).@"fn".params.len;
```

**Return type**:
```zig
pub const return_type = @typeInfo(@TypeOf(func)).@"fn".return_type.?;
```

### State vs Function Separation

**Stateful wrapper**:
```zig
return struct {
    pub const wrapped = func;  // Function
    state: State,              // Wrapper state

    pub fn call(self: *Self, ...) ... {
        self.state.update();
        return func(...);
    }
};
```

Original function has no state.

**State-free access**:
```zig
const orig = Wrapper.wrapped;
// Call without wrapper state
const result = orig(args);
```

### Performance Considerations

**Compile-time unwrapping**:
- Zero runtime cost
- Function inlined
- Type-safe extraction
- Optimized away

**Runtime unwrapping**:
- Function pointer overhead
- Indirect call
- Not inlined
- Dynamic dispatch

**Unwrap caching**:
```zig
const cached_orig = Wrapper.unwrap();
// Reuse cached_orig multiple times
```

Avoid repeated unwrapping.

### Design Guidelines

**Always provide unwrap**:
- Makes wrappers transparent
- Enables testing
- Supports debugging
- Shows intent

**Naming consistency**:
- `unwrap()` - Method that returns function
- `original` - Direct const access
- `inner` - Next layer reference
- `wrapped` - Alternate naming

**Document unwrapping**:
```zig
/// Returns the original unwrapped function.
/// Use this for testing or when wrapper behavior isn't needed.
pub fn unwrap() @TypeOf(func) {
    return func;
}
```

**Type safety**:
```zig
// Ensure unwrap returns correct type
pub fn unwrap() @TypeOf(func) {
    return func;  // Type-checked
}
```

### Common Use Cases

**Unit testing**:
```zig
test "original function" {
    const orig = Wrapper.unwrap();
    const result = orig(input);
    try testing.expectEqual(expected, result);
}
```

**Performance profiling**:
```zig
const orig = Wrapper.unwrap();
const start = timer.read();
_ = orig(args);
const unwrapped_time = timer.read() - start;

const wrapped_result = Wrapper.call(args);
const wrapped_time = timer.read() - start - unwrapped_time;
```

**Conditional decoration**:
```zig
const func = if (enable_wrapper)
    Wrapper.call
else
    Wrapper.unwrap();
```

**Wrapper analysis**:
```zig
fn countLayers(comptime T: type) usize {
    if (@hasDecl(T, "inner")) {
        return 1 + countLayers(@TypeOf(T.inner));
    }
    return 0;
}
```

### Testing Unwrapping

**Test basic unwrap**:
```zig
test "unwrap returns original" {
    const Wrapped = Unwrappable(func);
    const orig = Wrapped.unwrap();
    try testing.expectEqual(@TypeOf(func), @TypeOf(orig));
}
```

**Test layer unwrapping**:
```zig
test "layer by layer" {
    const L1 = Layer1(base);
    const L2 = Layer2(L1.call);

    const unwrapped = L2.unwrap();
    try testing.expectEqual(L1.call, unwrapped);
}
```

**Test metadata preservation**:
```zig
test "metadata survives unwrapping" {
    const Wrapped = MetadataWrapper(func);
    const orig = Wrapped.unwrap();
    // Verify orig has same properties as func
}
```

## See Also

- Recipe 9.1: Putting a Wrapper Around a Function
- Recipe 9.2: Preserving Function Metadata When Writing Decorators
- Recipe 9.4: Defining a Decorator That Takes Arguments
- Recipe 9.11: Using comptime to Control Instance Creation

Full compilable example: `code/03-advanced/09-metaprogramming/recipe_9_3.zig`
