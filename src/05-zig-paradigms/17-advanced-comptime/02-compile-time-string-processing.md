# Recipe 17.2: Compile-Time String Processing and Code Generation

## Problem

You want to build domain-specific languages (DSLs), generate code from strings, validate identifiers, or process configuration at compile time. You need powerful string manipulation that happens during compilation without any runtime overhead.

## Solution

Zig provides `std.fmt.comptimePrint` for generating strings at compile time, along with the `++` operator for concatenation and standard string operations that work in comptime contexts.

### Basic Compile-Time Printing

Generate formatted strings at compile time:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_2.zig:basic_comptime_print}}
```

### Parsing Key-Value Pairs

Parse simple formats at compile time with validation:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_2.zig:string_parsing}}
```

### Generating Field Names

Create systematic naming patterns:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_2.zig:field_name_generator}}
```

### Building SQL Queries

Construct SQL at compile time with validation:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_2.zig:sql_builder}}
```

### Parsing Format Strings

Analyze format strings to extract metadata:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_2.zig:format_parser}}
```

### Generating Enums from Strings

Create enum types from string lists at compile time:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_2.zig:enum_from_strings}}
```

### Identifier Validation

Validate Zig identifiers at compile time:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_2.zig:identifier_validation}}
```

### String Concatenation and Joining

Build complex strings from parts:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_2.zig:string_concatenation}}
```

### Code Generator

Generate method names following naming conventions:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_2.zig:code_generator}}
```

## Discussion

Compile-time string processing is essential for metaprogramming, letting you build tools that generate code, validate input, and create DSLs without any runtime cost.

### How comptimePrint Works

`std.fmt.comptimePrint` is like `std.fmt.allocPrint` but works at compile time. It returns a compile-time string literal that gets embedded in your binary:

- No allocator needed (memory is compile-time only)
- Supports all standard format specifiers (`{s}`, `{d}`, `{x}`, etc.)
- The result is a `[]const u8` known at compile time
- Can be used anywhere a compile-time string is required

### String Operations at Comptime

Most string operations work at compile time if wrapped in a `comptime` block:

**Concatenation**: Use `++` to join strings. This creates a new compile-time string without allocation.

**Indexing and Slicing**: Access individual characters or substrings with `string[index]` or `string[start..end]`.

**Comparison**: Use `std.mem.eql(u8, a, b)` to compare strings.

**Searching**: Loop through characters to find patterns, delimiters, or specific content.

### Building DSLs

Domain-specific languages become practical when you can parse and validate them at compile time:

**SQL Builders**: Catch table name typos or missing columns before compilation completes.

**Config Validation**: Parse configuration formats and reject invalid syntax immediately.

**API Generation**: Generate function names, struct fields, or entire interfaces from specifications.

### Type Generation

Combine string processing with `@Type()` to create types programmatically. The `makeEnum` example shows how to:

1. Process string lists at compile time
2. Build type metadata (field names, values)
3. Construct a complete type with `@Type()`
4. Use the generated type like any hand-written code

This is powerful for code generation from external specifications, configuration files, or data schemas.

### Validation and Error Reporting

Use `@compileError()` to provide clear feedback when strings don't meet requirements:

- Check for empty strings, invalid characters, or malformed syntax
- Build helpful error messages using string concatenation
- Fail fast at compile time rather than runtime

The `isValidIdentifier` and `requireValidIdentifier` functions show this pattern: validate input and provide actionable errors.

### Performance Characteristics

All string processing happens at compile time, so:

- Zero runtime overhead (no string parsing at program startup)
- Generated code is as fast as hand-written code
- Binary size includes only the final strings, not processing logic
- Compilation may take longer for complex string operations

### Practical Applications

**Serialization Formats**: Generate JSON, XML, or binary protocol encoders/decoders from schemas.

**Resource Embedding**: Process file paths, concatenate includes, or generate lookup tables.

**Code Generation**: Create boilerplate, implement getters/setters, or build test fixtures.

**Configuration**: Parse build-time configuration and generate optimized code for each setting.

**Validation**: Enforce naming conventions, check identifier validity, or validate format strings.

## See Also

- Recipe 17.1: Type-Level Pattern Matching
- Recipe 17.4: Generic Data Structure Generation
- Recipe 17.6: Build-Time Resource Embedding
- Recipe 9.16: Defining structs programmatically

Full compilable example: `code/05-zig-paradigms/17-advanced-comptime/recipe_17_2.zig`
