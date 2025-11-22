## Problem

You want to create functions that accept variable numbers of arguments (variadic functions) while enforcing specific type constraints, count requirements, or structural patterns at compile time. You need to validate tuple arguments to ensure type safety, prevent misuse, and provide clear compiler errors when arguments don't match expected patterns.

## Solution

Use `@typeInfo` to introspect tuple arguments at compile time and `@compileError` to enforce validation rules. Zig's compile-time execution allows you to validate argument types, counts, and patterns with zero runtime overhead.

### Validating All Types Match

The simplest validation ensures all tuple arguments have the same type:

```zig
{{#include ../../../code/03-advanced/09-metaprogramming/recipe_9_14.zig:validate_types}}
```

The validation happens entirely at compile time. Code with invalid argument types will not compile.

### Enforcing Argument Count Constraints

Require a minimum and maximum number of arguments:

```zig
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
```

## Discussion

### Enforcing Exact Type Signatures

You can validate that arguments match a specific type pattern:

```zig
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
}
```

This creates a compile-time contract for the exact argument types and count.

### Homogeneous Tuple Validation

Create a reusable generic validator for homogeneous tuples:

```zig
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

    const r2 = firstInt(.{ @as(i32, 1), @as(i32, 2), @as(i32, 3) });
    try testing.expectEqual(@as(i32, 1), r2);
}
```

This pattern bundles the validation logic into a reusable type generator.

### Validating Type Categories

Check that all arguments belong to a category of types:

```zig
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
}
```

This accepts any numeric type, handling both integers and floats correctly.

### First Argument Determines Type

Use the first argument's type to validate the rest:

```zig
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
}
```

The return type is determined by the first argument, allowing type-safe operations on any comparable type.

### Alternating Type Patterns

Enforce that arguments alternate between two types:

```zig
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

    const r1 = processAlternating(.{ @as(i32, 10), s1, @as(i32, 20), s2, @as(i32, 30), s3 });
    try testing.expectEqual(@as(i32, 60), r1);
}
```

This is useful for functions that process pairs of related values.

### Key-Value Pair Validation

Enforce that arguments come in key-value pairs:

```zig
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

    const r1 = countPairs(.{ k1, @as(i32, 30), k2, @as(i32, 100) });
    try testing.expectEqual(@as(usize, 2), r1);
}
```

This pattern is useful for building DSLs or configuration functions.

### Required First Argument

Validate that the first argument is a specific type, with any remaining arguments optional:

```zig
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
}
```

This allows flexible trailing arguments while ensuring a required argument is present.

### Type Predicate Validation

Use a predicate function to validate types:

```zig
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
}
```

This approach allows reusable type validators based on arbitrary conditions.

### Exact Count Constraint

Require an exact number of arguments:

```zig
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
}
```

This is useful for functions that need a specific number of arguments.

### Combining Validators

You can combine multiple validators for comprehensive validation:

```zig
fn processData(args: anytype) i32 {
    comptime requireArgCount(2, 5, args);
    comptime validateNumeric(args);

    var sum: i32 = 0;
    const fields = @typeInfo(@TypeOf(args)).@"struct".fields;
    inline for (fields) |field| {
        sum += @as(i32, @field(args, field.name));
    }
    return sum;
}
```

Validators compose naturally since they all operate at compile time.

### Why This Matters

Compile-time argument validation provides several benefits:

1. **Zero runtime cost** - All validation happens during compilation
2. **Type safety** - Invalid code won't compile, catching errors early
3. **Clear error messages** - `@compileError` provides helpful feedback
4. **No exceptions** - Type errors are caught before code runs
5. **Self-documenting** - Validation code serves as documentation
6. **Composition** - Validators can be combined and reused

### Performance Characteristics

All validation in this recipe has zero runtime overhead:

- Type checking happens during compilation
- Invalid code is rejected before code generation
- Valid code runs at full speed with no extra checks
- No dynamic dispatch or runtime type information needed

The only runtime cost is from the actual function logic, never from validation.

### String Literal Type Inference

Note the use of explicit type annotations for string literals in tests:

```zig
const str: []const u8 = "hello";
const r = processTyped(.{ @as(i32, 10), str, true });
```

String literals infer as `*const [N:0]u8` (null-terminated pointer arrays), not `[]const u8` (slices). When type-checking signatures, you need explicit slice types. This is an important detail when working with string arguments in validated tuples.

### Real-World Applications

These patterns are useful for:

1. **DSL construction** - Creating type-safe mini-languages
2. **Builder APIs** - Validating builder method calls
3. **Configuration functions** - Type-safe configuration
4. **Testing utilities** - Flexible test assertions
5. **Generic algorithms** - Type-safe variadic algorithms
6. **Data processing** - Validated data transformations

## See Also

- Recipe 9.11: Using comptime to control instance creation
- Recipe 9.12: Capturing struct attribute definition order
- Recipe 9.13: Defining a generic that takes optional arguments

Full compilable example: `code/03-advanced/09-metaprogramming/recipe_9_14.zig`
