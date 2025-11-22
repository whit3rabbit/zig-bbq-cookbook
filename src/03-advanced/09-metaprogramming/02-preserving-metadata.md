## Problem

When wrapping functions with decorators, you need to preserve the original function's metadata: return types, error sets, parameter information, and other compile-time properties. Losing metadata breaks type safety and makes wrapped functions harder to use.

## Solution

Use Zig's `@typeInfo` builtin to extract function metadata at compile time, then build wrappers that preserve all type information including signatures, error sets, optional types, and documentation.

### Basic Metadata Extraction

Extract and expose function metadata using `@typeInfo`:

```zig
{{#include ../../../code/03-advanced/09-metaprogramming/recipe_9_2.zig:basic_metadata}}
```

All function metadata is available at compile time.

### Error Set Preservation

Preserve error return types through wrappers:

```zig
fn ErrorPreservingWrapper(comptime func: anytype) type {
    const func_info = @typeInfo(@TypeOf(func));
    const ReturnType = func_info.@"fn".return_type.?;

    return struct {
        pub fn call(args: anytype) ReturnType {
            return @call(.auto, func, args);
        }
    };
}

fn divide(a: i32, b: i32) !i32 {
    if (b == 0) return error.DivisionByZero;
    return @divTrunc(a, b);
}

// Usage
const Wrapper = ErrorPreservingWrapper(divide);
const result = try Wrapper.call(.{ 10, 2 });  // Must use try
const err = Wrapper.call(.{ 10, 0 });  // Returns error.DivisionByZero
```

Error sets flow through wrappers naturally.

### Signature Matching

Create wrappers that exactly match the original function signature:

```zig
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

// Usage
const Wrapper = SignatureMatchingWrapper(multiply);
var wrapper = Wrapper{};
const result = wrapper.wrap(.{ 2, 3, 4 });  // 24
```

The wrapper exposes the original function type.

### Complete Metadata Extraction

Extract all available function properties:

```zig
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

// Usage
const Meta = MetadataExtractor(example);
// Meta.Info.param_count
// Meta.Info.is_generic
// Meta.Info.calling_convention
```

All function metadata is accessible as compile-time constants.

### Documentation Wrapper

Add documentation metadata to wrapped functions:

```zig
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

// Usage
const Wrapped = DocumentedWrapper(square, "Computes the square of x");
const result = Wrapped.call(.{5});  // 25
const doc = Wrapped.getDoc();  // "Computes the square of x"
```

Metadata can include custom documentation strings.

### Optional Type Preservation

Preserve optional return types correctly:

```zig
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

// Usage
const Wrapper = OptionalPreservingWrapper(findValue);
const arr = [_]i32{ 1, 2, 3, 4, 5 };

const found = Wrapper.call(.{ &arr, 3 });  // ?usize
if (found) |index| {
    // Use index
}
```

Optional types remain optional through wrapping.

### Allocator Function Wrapper

Handle functions that take allocators as first parameter:

```zig
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

// Usage
const Wrapper = AllocatorWrapper(allocateArray);
var wrapper = Wrapper{};
const arr = try wrapper.call(allocator, .{5});
defer allocator.free(arr);
// wrapper.getAllocationCount() == 1
```

Allocator-taking functions require special handling.

### Complex Return Types

Handle functions returning structs, tuples, or unions:

```zig
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

// Usage
const Wrapper = ComplexReturnWrapper(divmod);
const result = Wrapper.call(.{ 17, 5 });
// result.quotient == 3
// result.remainder == 2
```

Complex types are preserved through metadata extraction.

### Type-Safe Wrappers

Enforce expected return types at compile time:

```zig
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

// Usage
const Wrapper = TypeSafeWrapper(increment, i32);  // OK
// const BadWrapper = TypeSafeWrapper(increment, i64);  // Compile error
```

Type mismatches are caught at compile time.

### Void Return Functions

Handle functions that don't return values:

```zig
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

// Usage
const Wrapper = VoidReturnWrapper(voidFunc);
var wrapper = Wrapper{};
wrapper.call(.{42});
// side_effect == 42
// wrapper.call_count == 1
```

Void functions require conditional return handling.

## Discussion

Preserving metadata ensures wrapped functions behave identically to originals from the type system's perspective.

### Why Metadata Preservation Matters

**Type safety**:
- Callers know exact return types
- Error sets are explicit
- Optionals remain optional
- Compiler catches misuse

**Tooling support**:
- IDE autocomplete works
- Type inspection functions
- Documentation generation
- Compiler error messages

**Composability**:
- Wrappers can be stacked
- Each layer preserves metadata
- No information loss
- Full type inference

### Using @typeInfo

**Extract function information**:
```zig
const func_info = @typeInfo(@TypeOf(func));
```

**Access function properties**:
```zig
const fn_info = func_info.@"fn";
const return_type = fn_info.return_type;
const params = fn_info.params;
const is_generic = fn_info.is_generic;
```

**Type variants**:
- `.@"fn"` - Regular functions
- `.params` - Parameter list
- `.return_type` - Return type (nullable)
- `.calling_convention` - C, Inline, etc.
- `.is_generic` - Generic function
- `.is_var_args` - Variadic

### Return Type Handling

**Non-error return**:
```zig
const ReturnType = fn_info.return_type.?;
pub fn call(args: anytype) ReturnType { ... }
```

**Error union return**:
```zig
// ReturnType already includes !
pub fn call(args: anytype) ReturnType { ... }
```

**Optional return**:
```zig
// ReturnType is ?T
pub fn call(args: anytype) ReturnType { ... }
```

**Void return**:
```zig
const ReturnType = fn_info.return_type;  // null for void
pub fn call(args: anytype) if (ReturnType) |T| T else void { ... }
```

### Function Call Strategies

**Direct call with tuple**:
```zig
return @call(.auto, func, args);  // args is tuple
```

**Argument unpacking**:
```zig
const full_args = .{allocator} ++ args;
return @call(.auto, func, full_args);
```

**Conditional calling**:
```zig
if (ReturnType) |_| {
    return @call(.auto, func, args);
} else {
    @call(.auto, func, args);
}
```

### Metadata Patterns

**Expose compile-time constants**:
```zig
return struct {
    pub const param_count = fn_info.params.len;
    pub const return_type = fn_info.return_type;
    pub const original_function = func;
};
```

**Runtime metadata**:
```zig
return struct {
    call_count: usize = 0,
    last_result: ?ReturnType = null,
};
```

**Mixed compile/runtime**:
```zig
return struct {
    pub const Info = struct {
        // Compile-time data
    };

    // Runtime state
    stats: Stats,
};
```

### Error Set Preservation

**Automatic preservation**:
```zig
const ReturnType = fn_info.return_type.?;
// If ReturnType is !T, it's preserved
pub fn call(args: anytype) ReturnType {
    return @call(.auto, func, args);
}
```

**Error handling in wrapper**:
```zig
pub fn call(args: anytype) ReturnType {
    const result = @call(.auto, func, args) catch |err| {
        // Log or handle error
        return err;
    };
    return result;
}
```

**Adding wrapper errors**:
```zig
pub fn call(args: anytype) (error{WrapperError} || ReturnErrorSet)!T {
    if (invalid_input) return error.WrapperError;
    return @call(.auto, func, args);
}
```

### Parameter Introspection

**Extract parameter types**:
```zig
const params = fn_info.params;
const first_param_type = params[0].type.?;
```

**Check parameter count**:
```zig
if (fn_info.params.len != 2) {
    @compileError("Expected 2 parameters");
}
```

**Validate parameter types**:
```zig
inline for (fn_info.params, 0..) |param, i| {
    if (param.type.? != i32) {
        @compileError("All params must be i32");
    }
}
```

### Generic Function Handling

**Check if generic**:
```zig
if (fn_info.is_generic) {
    // Handle generic function
}
```

**Generic wrappers**:
```zig
fn GenericWrapper(comptime func: anytype) type {
    // Works for both generic and non-generic
    return struct {
        pub fn call(args: anytype) auto {
            return @call(.auto, func, args);
        }
    };
}
```

### Documentation Strategies

**Embed documentation**:
```zig
pub const documentation = "Function description";
pub const param_docs = [_][]const u8{
    "First parameter",
    "Second parameter",
};
```

**Generate from metadata**:
```zig
pub fn getSignature() []const u8 {
    return std.fmt.comptimePrint(
        "fn({d} params) -> {s}",
        .{ param_count, @typeName(return_type) }
    );
}
```

### Performance Implications

**Zero runtime overhead**:
- All metadata resolved at compile time
- No runtime type checks
- Fully inlined calls
- Same as hand-written code

**Compile-time cost**:
- Type introspection takes compile time
- Each wrapper instantiation generates code
- Complex metadata increases build time

**Binary size**:
- Metadata stored in type system only
- No runtime metadata structures
- Generic wrappers per instantiation

### Testing Metadata

**Verify metadata extraction**:
```zig
test "metadata extraction" {
    const Meta = MetadataExtractor(func);
    try testing.expectEqual(expected_count, Meta.Info.param_count);
    try testing.expect(Meta.Info.has_return);
}
```

**Test type preservation**:
```zig
test "type preservation" {
    const Wrapper = PreservingWrapper(func);
    try testing.expectEqual(
        @TypeOf(func(0)),
        @TypeOf(Wrapper.call(.{0}))
    );
}
```

**Test error propagation**:
```zig
test "error propagation" {
    const Wrapper = ErrorWrapper(failableFunc);
    const result = Wrapper.call(.{bad_input});
    try testing.expectError(error.Expected, result);
}
```

## See Also

- Recipe 9.1: Putting a Wrapper Around a Function
- Recipe 9.3: Unwrapping a Decorator
- Recipe 9.5: Enforcing Type Checking on a Function Using a Decorator
- Recipe 9.11: Using comptime to Control Instance Creation

Full compilable example: `code/03-advanced/09-metaprogramming/recipe_9_2.zig`
