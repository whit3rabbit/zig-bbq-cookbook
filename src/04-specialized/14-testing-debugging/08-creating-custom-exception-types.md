# Recipe 14.8: Creating custom exception types

## Problem

You need to define custom error types specific to your domain or application. You want to create meaningful, type-safe errors that make your code more maintainable and easier to debug.

## Solution

Define custom error sets using the `error` keyword:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_8.zig:basic_error_set}}
```

## Discussion

Zig's error sets are compile-time types that provide type-safe error handling without runtime overhead. Custom error sets make your code self-documenting and help catch error handling bugs at compile time.

### Composing Error Sets

Combine multiple error sets using the `||` operator:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_8.zig:composing_errors}}
```

Error set composition creates a union of all errors from both sets, enabling functions to return errors from multiple domains.

### Inferred Error Sets

Let Zig infer error sets automatically:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_8.zig:inferred_errors}}
```

The `!` operator without a specific error set means Zig will infer which errors the function can return. This is convenient but makes the error contract less explicit.

### Hierarchical Error Organization

Structure errors in a hierarchy for large applications:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_8.zig:hierarchical_errors}}
```

Hierarchical organization lets you handle errors at different levels of abstraction.

### Domain-Specific Errors

Group errors by business domain:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_8.zig:domain_errors}}
```

Domain-specific error sets make it clear which part of your system failed.

### Error Context and Metadata

Combine errors with additional context:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_8.zig:error_context}}
```

Wrapping errors in a struct preserves error information plus additional debugging context like line numbers and messages.

### Converting Between Error Sets

Transform errors from one domain to another:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_8.zig:error_conversion}}
```

Error conversion is useful when crossing abstraction boundaries.

### Namespacing Error Sets

Use structs to namespace related error sets:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_8.zig:error_namespacing}}
```

Namespacing prevents name collisions when different subsystems use similar error names like `NotFound`.

### Documenting Error Sets

Add documentation to your error sets:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_8.zig:error_documentation}}
```

Doc comments on error sets and individual errors improve code maintainability.

### Generic Error Handling

Use comptime to work with any error set:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_8.zig:generic_errors}}
```

Generic error handling enables reusable code that works with different error sets.

### Best Practices

1. **Be specific**: Create meaningful error names that describe what went wrong
2. **Use composition**: Combine error sets with `||` rather than creating large monolithic sets
3. **Namespace carefully**: Use structs to organize errors by subsystem
4. **Document errors**: Add doc comments explaining when errors occur
5. **Prefer explicit**: Use specific error sets instead of inferred `!` for public APIs
6. **Group by domain**: Organize errors by business domain, not implementation detail
7. **Convert at boundaries**: Transform errors when crossing abstraction layers

### Error Set Design Patterns

**Pattern 1: Layer-Based Organization**
```zig
const DataError = error{NotFound, InvalidFormat};
const NetworkError = error{Timeout, Refused};
const ApplicationError = DataError || NetworkError;
```

**Pattern 2: Fine-Grained Control**
```zig
const ReadError = error{FileNotFound, AccessDenied};
const WriteError = error{DiskFull, ReadOnly};
const IoError = ReadError || WriteError;
```

**Pattern 3: Context Enrichment**
```zig
const ErrorWithContext = struct {
    err: MyError,
    file: []const u8,
    line: usize,
};
```

### Common Gotchas

**Overly broad error sets**: Don't create catch-all error sets:

```zig
// Wrong - too generic
const AppError = error{Error, Failed, Bad};

// Right - specific and meaningful
const ValidationError = error{InvalidEmail, InvalidPhone};
const DatabaseError = error{ConnectionFailed, QueryTimeout};
```

**Not using composition**: Avoid duplicating errors across sets:

```zig
// Wrong - duplicated NotFound
const FileError = error{NotFound, AccessDenied};
const DbError = error{NotFound, QueryFailed};

// Right - compose from shared errors
const ResourceError = error{NotFound};
const FileError = ResourceError || error{AccessDenied};
const DbError = ResourceError || error{QueryFailed};
```

**Ignoring error documentation**: Always document complex error conditions:

```zig
// Wrong - no context
const Error = error{Failed};

// Right - explains when it occurs
/// Returned when database connection pool is exhausted
/// after MAX_RETRIES attempts with exponential backoff
const Error = error{ConnectionPoolExhausted};
```

### Error Set Size and Performance

Error sets have zero runtime cost:
- Errors are represented as `u16` values at runtime
- Error set membership is checked at compile time
- No memory allocation or overhead
- Perfect for performance-critical code

### Comparison with Other Languages

**Zig vs. Exceptions:**
- Zig errors are explicit in function signatures
- No hidden control flow or stack unwinding
- Compile-time verification of error handling
- Zero runtime overhead

**Zig vs. Result Types:**
- Similar to Rust's `Result<T, E>`
- But integrated into the language with `!` syntax
- Error sets are first-class types
- Automatic error set inference available

### Integration with Standard Library

Standard library functions use error sets extensively:

```zig
// std.fs uses IoError
pub const OpenError = error{
    FileNotFound,
    IsDir,
    AccessDenied,
    // ... many more
};

// Compose with your own errors
const MyFileError = std.fs.File.OpenError || error{ConfigInvalid};
```

## See Also

- Recipe 14.6: Handling multiple exceptions at once
- Recipe 14.7: Catching all exceptions
- Recipe 14.9: Raising an exception in response to another exception
- Recipe 1.2: Error Handling Patterns
- Recipe 0.11: Optionals, Errors, and Resource Cleanup

Full compilable example: `code/04-specialized/14-testing-debugging/recipe_14_8.zig`
