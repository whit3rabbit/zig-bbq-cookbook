## Problem

You want to enforce type constraints on functions at compile time, validating that functions have specific parameter types, return types, or other type properties. You need type-safe decorators that catch errors before runtime.

## Solution

Use `@typeInfo` to introspect function signatures and validate types at compile time with decorators. Combine type checking with `@compileError` to enforce constraints during compilation.

### Parameter Type Checking

Validate parameter types match expected types:

```zig
{{#include ../../../code/03-advanced/09-metaprogramming/recipe_9_5.zig:parameter_type_check}}
```

Type mismatches cause compile errors with helpful messages.

### Return Type Checking

Enforce specific return types:

```zig
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

// Usage
const Checked = WithReturnCheck(double, i32);  // OK
const result = Checked.call(.{5});  // 10

// This would fail at compile time:
// const Bad = WithReturnCheck(double, i64);
```

Return type validation prevents unexpected types.

### Error Set Checking

Ensure functions return error unions:

```zig
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

// Usage
const Checked = WithErrorCheck(divide, error{DivisionByZero});
const result = try Checked.call(.{ 10, 2 });  // 5
```

Enforces error handling at compile time.

### Numeric Type Constraint

Restrict to numeric types only:

```zig
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

// Usage
const Checked = NumericOnly(multiply);
const result = Checked.call(.{ 4, 5 });  // 20
```

Ensures mathematical operations on numeric types.

### Signed Integer Requirement

Require signed integer parameters:

```zig
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

// Usage
const Checked = SignedIntegersOnly(negate);
const result = Checked.call(.{5});  // -5
```

Prevents unsigned integers where signs matter.

### Pointer Parameter Check

Enforce specific parameters are pointers:

```zig
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

// Usage
const Checked = RequiresPointer(increment, 0);
var val: i32 = 10;
Checked.call(.{&val});
// val == 11
```

Validates pointer usage for mutability.

### Slice Type Enforcement

Require slice parameters with specific element types:

```zig
fn RequiresSlice(comptime func: anytype, comptime ElementType: type) type {
    const func_info = @typeInfo(@TypeOf(func));
    const params = func_info.@"fn".params;

    var found_slice = false;
    for (params) |param| {
        const param_type = param.type.?;
        const type_name = @typeName(param_type);

        // Slices start with "[]" in their type name
        if (std.mem.startsWith(u8, type_name, "[]")) {
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

// Usage
const Checked = RequiresSlice(sum, i32);
const items = [_]i32{ 1, 2, 3, 4, 5 };
const result = Checked.call(.{&items});  // 15
```

Ensures collection-based functions receive slices.

### Optional Return Type Check

Validate optional return types with specific payload:

```zig
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

// Usage
const Checked = ReturnsOptional(findFirst, usize);
const items = [_]i32{ 10, 20, 30, 40 };
const found = Checked.call(.{ &items, 30 });  // ?usize = 2
```

Enforces optional patterns for nullable results.

### Struct Field Requirement

Ensure struct parameters have required fields:

```zig
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

// Usage
const required = [_][]const u8{ "x", "y" };
const Checked = RequiresStructWithFields(distance, &required);
const p = Point{ .x = 3, .y = 4 };
const result = Checked.call(.{p});  // 7
```

Validates struct interface contracts.

### Allocator Parameter Requirement

Ensure functions take allocator as first parameter:

```zig
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

// Usage
const Checked = RequiresAllocator(allocateSlice);
const slice = try Checked.call(.{ allocator, 5 });
defer allocator.free(slice);
```

Enforces explicit allocator passing convention.

### Pure Function Check

Enforce functional purity (no mutable pointers, must return value):

```zig
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

// Usage
const Checked = PureFunction(square);
const result = Checked.call(.{7});  // 49
```

Promotes functional programming patterns.

## Discussion

Type checking decorators provide compile-time safety by validating function signatures before code runs.

### Why Type Checking Matters

**Compile-time safety**:
- Catch type errors early
- No runtime type checks needed
- Zero performance overhead
- Self-documenting constraints

**API contracts**:
- Enforce interface requirements
- Document expected types
- Prevent misuse
- Guide correct usage

**Refactoring confidence**:
- Changes caught at compile time
- Type errors impossible at runtime
- Compiler verifies correctness
- Safe large-scale changes

### Type Introspection with @typeInfo

**Function information**:
```zig
const func_info = @typeInfo(@TypeOf(func));
const fn_info = func_info.@"fn";
```

**Available properties**:
- `params` - Parameter list
- `return_type` - Return type (nullable)
- `calling_convention` - Calling convention
- `is_generic` - Generic function check
- `is_var_args` - Variadic check

**Parameter inspection**:
```zig
for (fn_info.params, 0..) |param, i| {
    const param_type = param.type.?;
    const param_info = @typeInfo(param_type);
    // Check param_info...
}
```

### Type Categories

**Primitive types**:
```zig
.int, .float, .bool, .void
```

**Composite types**:
```zig
.@"struct", .@"enum", .@"union", .@"opaque"
```

**Pointer types**:
```zig
.pointer - Check size, child, is_const
```

**Special types**:
```zig
.optional, .error_union, .error_set, .array
```

### Error Messages

**Helpful compile errors**:
```zig
@compileError(std.fmt.comptimePrint(
    "Expected {s} but got {s}",
    .{ @typeName(expected), @typeName(actual) },
));
```

**Include context**:
- Parameter index
- Expected vs actual types
- Constraint description
- Suggestion for fix

**Example output**:
```
error: Parameter 1 type mismatch: expected i32, got i64
```

### Common Patterns

**Type equality**:
```zig
if (ActualType != ExpectedType) {
    @compileError("Type mismatch");
}
```

**Type category**:
```zig
const info = @typeInfo(T);
if (info != .int) {
    @compileError("Must be integer");
}
```

**Field existence**:
```zig
if (!@hasField(T, "field_name")) {
    @compileError("Missing field");
}
```

**Signedness check**:
```zig
if (info.int.signedness != .signed) {
    @compileError("Must be signed");
}
```

### Design Guidelines

**Clear error messages**:
- Explain what's wrong
- Show expected vs actual
- Suggest how to fix
- Include context

**Specific constraints**:
- Check exactly what matters
- Don't over-constrain
- Allow flexibility where safe
- Document requirements

**Composable checks**:
```zig
const Validated =
    RequiresAllocator(
        NumericOnly(
            WithReturnCheck(func, i32)
        )
    );
```

Stack checks for comprehensive validation.

### Performance

**Zero runtime cost**:
- All checks at compile time
- No type tags
- No runtime inspection
- Pure compile-time overhead

**Compile time**:
- Type checks are fast
- Increase with complexity
- Worth it for safety
- One-time cost

**Binary size**:
- No runtime metadata
- Same as unchecked code
- Type info eliminated
- Optimal generated code

### Testing Type Checks

**Test valid cases**:
```zig
test "accepts valid types" {
    const Checked = WithReturnCheck(func, i32);
    const result = Checked.call(.{5});
    try testing.expectEqual(@as(i32, 10), result);
}
```

**Test compile errors** (in comments):
```zig
// This should fail at compile time:
// const Bad = WithReturnCheck(func, i64);
```

**Test edge cases**:
```zig
test "empty parameter list" {
    fn noParams() i32 { return 42; }
    const Checked = WithParameterCheck(noParams, &[_]type{});
    try testing.expectEqual(@as(i32, 42), Checked.call(.{}));
}
```

### Advanced Techniques

**Recursive type checking**:
```zig
fn checkNested(comptime T: type) void {
    const info = @typeInfo(T);
    if (info == .@"struct") {
        inline for (info.@"struct".fields) |field| {
            checkNested(field.type);
        }
    }
}
```

**Constraint composition**:
```zig
fn MultiConstraint(comptime func: anytype) type {
    _ = NumericOnly(func);
    _ = WithReturnCheck(func, i32);
    _ = RequiresAllocator(func);
    // All checks must pass
    return func;
}
```

**Custom type traits**:
```zig
fn isNumeric(comptime T: type) bool {
    const info = @typeInfo(T);
    return info == .int or info == .float;
}
```

## See Also

- Recipe 9.1: Putting a Wrapper Around a Function
- Recipe 9.2: Preserving Function Metadata When Writing Decorators
- Recipe 9.4: Defining a Decorator That Takes Arguments
- Recipe 9.6: Defining Decorators as Part of a Struct

Full compilable example: `code/03-advanced/09-metaprogramming/recipe_9_5.zig`
