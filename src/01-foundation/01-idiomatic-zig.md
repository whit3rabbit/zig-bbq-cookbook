# Idiomatic Zig

## Overview

Zig has strong conventions that make code predictable and maintainable. This guide establishes the idiomatic patterns used throughout the cookbook.

## Key Principles

### 1. Explicit Over Implicit

Zig has no hidden control flow. Everything is visible and intentional.

```zig
// Good: Explicit allocation
const list = try std.ArrayList(i32).init(allocator);

// Bad: (This doesn't exist in Zig - no hidden allocations!)
// const list = ArrayList(i32).new();  // Where does memory come from?
```

### 2. Pass Allocators Explicitly

Never use global state for memory. Always pass allocators as the first parameter.

```zig
// Good: Allocator passed explicitly
pub fn init(allocator: std.mem.Allocator, capacity: usize) !MyStruct {
    return MyStruct{
        .items = try allocator.alloc(Item, capacity),
        .allocator = allocator,
    };
}

// Bad: Hidden global allocator
// var global_allocator: std.mem.Allocator = undefined;  // Don't do this!
```

### 3. Use defer and errdefer for Cleanup

These ensure cleanup happens automatically, even when errors occur.

```zig
// Good: Cleanup is guaranteed
pub fn processFile(allocator: std.mem.Allocator, path: []const u8) !void {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close(); // Always runs when function exits

    const buffer = try allocator.alloc(u8, 4096);
    errdefer allocator.free(buffer); // Only runs if an error is returned after this point

    const bytes_read = try file.readAll(buffer);
    // ... process data ...
    allocator.free(buffer);
}
```

### 4. Prefer Slices Over Pointers

Slices carry length information, making them safer and more ergonomic.

```zig
// Good: Slice includes length
fn printNames(names: []const []const u8) void {
    for (names) |name| {
        std.debug.print("{s}\n", .{name});
    }
}

// Avoid: Raw pointer requires separate length
fn printNamesOld(names: [*]const []const u8, len: usize) void {
    var i: usize = 0;
    while (i < len) : (i += 1) {
        std.debug.print("{s}\n", .{names[i]});
    }
}
```

### 5. Use comptime for Generics

Zig doesn't have templates or generics syntax. Instead, use compile-time evaluation.

```zig
// Good: Generic function using comptime
fn max(comptime T: type, a: T, b: T) T {
    return if (a > b) a else b;
}

// Usage - type is known at compile time
const result = max(i32, 5, 10);  // returns 10
```

## Naming Conventions

### Files and Modules
- Use lowercase with underscores: `string_utils.zig`
- Test files can use `_test.zig` suffix

### Functions and Variables
- Use camelCase: `calculateTotal`, `firstName`
- Constants use camelCase: `maxRetries`, `defaultTimeout`

### Types
- Use PascalCase: `ArrayList`, `HashMap`, `MyStruct`

### Example

```zig
{{#include ../../code/01-foundation/idiomatic_examples.zig:user_account}}
```

## Memory Management Patterns

### The RAII Pattern with defer

Resource Acquisition Is Initialization works beautifully with `defer`:

```zig
pub fn readConfig(allocator: std.mem.Allocator, path: []const u8) !Config {
    // Open file
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close(); // Guaranteed cleanup

    // Allocate buffer
    const contents = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(contents); // Guaranteed cleanup

    // Parse and return (might error!)
    return try parseConfig(allocator, contents);
}
```

### Init/Deinit Convention

Always pair initialization with deinitialization:

```zig
{{#include ../../code/01-foundation/idiomatic_examples.zig:cache_struct}}
```

## Error Handling Integration

### Return Errors, Don't Panic

```zig
{{#include ../../code/01-foundation/idiomatic_examples.zig:divide_function}}
```

### Combine Allocator and Error Handling

```zig
{{#include ../../code/01-foundation/idiomatic_examples.zig:create_message}}
```

## Comptime Patterns

### Generic Data Structures

```zig
{{#include ../../code/01-foundation/idiomatic_examples.zig:generic_stack}}
```

### Compile-Time Configuration

```zig
{{#include ../../code/01-foundation/idiomatic_examples.zig:connection_pool}}
```

## Quick Reference

- Allocators: Always first parameter, explicitly passed
- Cleanup: Use `defer` for guaranteed cleanup, `errdefer` for error paths
- Errors: Return them (use `!`), propagate with `try`, handle with `catch`
- Naming: camelCase for functions/variables, PascalCase for types
- Slices: Prefer `[]T` over `[*]T` whenever possible
- Generics: Use `comptime` type parameters
- No hidden behavior: No exceptions, no hidden allocations, no implicit conversions

See the full compilable example at `code/01-foundation/idiomatic_examples.zig`
