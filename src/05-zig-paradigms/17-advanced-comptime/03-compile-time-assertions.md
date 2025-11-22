# Recipe 17.3: Compile-Time Assertion and Contract Validation

## Problem

You need to enforce constraints on types, validate struct layouts, check API contracts, and ensure invariants are maintained across your codebase. You want these checks to happen at compile time so invalid code never makes it to production.

## Solution

Zig's `@compileError` builtin combined with compile-time type introspection allows you to create sophisticated assertions that validate code at compile time with zero runtime overhead.

### Basic Compile-Time Assertions

Create simple assertions with custom error messages:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_3.zig:basic_assertions}}
```

### Type Relationship Assertions

Validate relationships between types:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_3.zig:type_relationships}}
```

### Struct Field Validation

Check struct shapes and field types:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_3.zig:struct_field_validation}}
```

### Interface Validation

Ensure types implement required methods (duck typing):

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_3.zig:interface_validation}}
```

### Alignment and Layout Assertions

Validate memory layout characteristics:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_3.zig:alignment_assertions}}
```

### Range and Size Validation

Check compile-time constants fall within valid ranges:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_3.zig:range_validation}}
```

### Build Configuration Assertions

Validate build settings and target platforms:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_3.zig:build_configuration}}
```

### Design by Contract

Enforce preconditions and postconditions:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_3.zig:contract_validation}}
```

### Custom Validators

Build reusable validation helpers:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_3.zig:custom_validators}}
```

## Discussion

Compile-time assertions transform potential runtime bugs into compilation errors, giving you immediate feedback when constraints are violated.

### How @compileError Works

The `@compileError` builtin stops compilation with a custom message. When placed inside a comptime block or function:

- Execution stops immediately when reached
- The provided message is displayed as a compilation error
- No code is generated for invalid branches
- Works seamlessly with conditional logic

Use `std.fmt.comptimePrint` to create detailed error messages that include type names, values, and context.

### Assertion Strategies

**Type Validation**: Use `@typeInfo()` to inspect type characteristics and reject invalid types before generating code.

**Struct Introspection**: Check field names and types using the `.@"struct"` tag. Iterate fields with `inline for` to validate structure.

**Method Checking**: Use `@hasDecl()` to verify types implement required functions, enabling duck typing with compile-time guarantees.

**Size and Alignment**: Assert memory layout requirements with `@sizeOf()` and `@alignOf()` to prevent ABI mismatches or platform issues.

### Best Practices

**Informative Messages**: Include as much context as possible in error messages. Show what was expected vs. what was found, along with type names and values.

**Fail Early**: Place assertions at the entry points of generic functions and type constructors. Catch invalid usage immediately.

**Composable Validators**: Build small, focused assertion functions that can be combined. Create libraries of validators for common patterns.

**Return Bool for Testing**: Functions that would use `@compileError` should return bool for testability, then wrap them in assertion helpers.

**Document Contracts**: Use assertions as executable documentation. They clearly state what your code requires and guarantees.

### Common Use Cases

**Generic Constraints**: Ensure type parameters meet requirements (numeric, pointer, specific size, etc.).

**Platform Validation**: Check target architecture, OS, or build mode matches code requirements.

**ABI Guarantees**: Verify struct layouts match external API requirements for C interop or network protocols.

**API Evolution**: Ensure code changes don't violate backward compatibility contracts.

**Configuration Validation**: Catch invalid build options or feature combinations at compile time.

### Performance Characteristics

All assertions happen at compile time:

- Zero runtime overhead (no checks in final binary)
- No branches or conditional code generated
- Fast compile-time validation (analyzed once)
- Invalid code paths are pruned completely

### Integration with Testing

Combine compile-time assertions with runtime tests:

- Use assertions in generic functions to validate parameters
- Test successful cases with runtime tests
- Document failed cases with commented-out examples
- Use comptime blocks in tests to verify assertions fire correctly

The struct field validation example shows this pattern: runtime tests verify the validation functions work, while comptime blocks demonstrate how to use them for compile-time enforcement.

### Error Message Quality

Good error messages are crucial:

```zig
// Bad: Generic error
@compileError("Invalid type");

// Good: Specific context
@compileError(std.fmt.comptimePrint(
    "Type {s} has {d} fields, expected at least {d}",
    .{ @typeName(T), actual, minimum }
));
```

Include:
- What was checked
- What was expected
- What was actually found
- Type names for clarity
- Suggestions for fixing if possible

## See Also

- Recipe 17.1: Type-Level Pattern Matching
- Recipe 17.2: Compile-Time String Processing
- Recipe 17.4: Generic Data Structure Generation
- Recipe 9.5: Enforcing type checking on a function using a decorator

Full compilable example: `code/05-zig-paradigms/17-advanced-comptime/recipe_17_3.zig`
