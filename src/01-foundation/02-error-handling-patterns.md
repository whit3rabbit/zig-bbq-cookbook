# Error Handling Patterns

## Overview

Zig treats errors as values, not exceptions. This means no hidden control flow, no try-catch blocks that jump around your code. Instead, you handle errors explicitly and visibly.

## The Basics: Error Union Types

When a function can fail, its return type is an error union: `!T` means "either an error or a value of type T".

```zig
// This function returns either an error or a u32
fn parseNumber(text: []const u8) !u32 {
    if (text.len == 0) return error.EmptyString;
    // ... parsing logic ...
    return 42;
}
```

## Error Sets

Define what errors your function can return using an error set:

```zig
{{#include ../../code/01-foundation/error_handling.zig:error_sets}}
```

### Inferred Error Sets

Let Zig infer the error set with `!`:

```zig
{{#include ../../code/01-foundation/error_handling.zig:divide_function}}
```

## The Three Ways to Handle Errors

### 1. Propagate with `try`

Use `try` when you want to pass errors up to your caller. If the expression returns an error, `try` immediately returns that error from your function.

```zig
fn readUserConfig(path: []const u8) !Config {
    // If openFile returns an error, this function immediately returns that error
    const file = try openFile(path);
    defer file.close();

    // If readContents returns an error, same thing happens
    const contents = try file.readContents();

    return parseConfig(contents);
}
```

Think of `try` as "do this, or bail out with the error".

### 2. Handle with `catch`

Use `catch` when you want to handle the error or provide a fallback value:

```zig
fn getUserName(user_id: u32) []const u8 {
    // If lookup fails, use "Guest" as the fallback
    const name = lookupUser(user_id) catch "Guest";
    return name;
}

fn processFile(path: []const u8) void {
    const file = openFile(path) catch |err| {
        std.debug.print("Failed to open {s}: {}\n", .{path, err});
        return;
    };
    defer file.close();
    // ... process file ...
}
```

### 3. Branch with `if`

Use `if` when you want to handle success and errors differently:

```zig
fn attemptUpgrade() void {
    if (performUpgrade()) |result| {
        // Success path - result is the unwrapped value
        std.debug.print("Upgraded to version {}\n", .{result.version});
    } else |err| {
        // Error path - err is the error
        std.debug.print("Upgrade failed: {}\n", .{err});
    }
}
```

You can also handle specific errors:

```zig
{{#include ../../code/01-foundation/error_handling.zig:if_expression}}
```

## Cleanup with `errdefer`

Use `errdefer` to clean up resources only when returning an error. This prevents leaks on error paths.

```zig
fn createUser(allocator: std.mem.Allocator, name: []const u8) !User {
    // Allocate memory for the user
    const user = try allocator.create(User);
    // If anything below returns an error, clean up the user
    errdefer allocator.destroy(user);

    // Duplicate the name string
    user.name = try allocator.dupe(u8, name);
    // If anything below returns an error, clean up the name
    errdefer allocator.free(user.name);

    // This might fail
    user.id = try generateUserId();

    // Success! The errdefers won't run
    return user.*;
}
```

Compare with `defer`, which always runs:

```zig
fn processData(allocator: std.mem.Allocator) !void {
    const buffer = try allocator.alloc(u8, 1024);
    defer allocator.free(buffer); // Always runs when function exits

    const temp = try allocator.alloc(u8, 512);
    errdefer allocator.free(temp); // Only runs if we return an error after this point

    try processBuffer(buffer, temp);

    // Success path - we free temp here
    allocator.free(temp);
}
```

## Custom Error Sets

Define your own error sets for your domain:

```zig
{{#include ../../code/01-foundation/error_handling.zig:combined_errors}}
```

## Error Return Traces

In Debug and ReleaseSafe modes, Zig tracks where errors originate and propagate through your code:

```zig
fn level3() !void {
    return error.SomethingWrong;
}

fn level2() !void {
    try level3(); // Error propagates through here
}

fn level1() !void {
    try level2(); // And through here
}

pub fn main() !void {
    level1() catch |err| {
        std.debug.print("Error: {}\n", .{err});
        // The error return trace shows the path the error took
        return err;
    };
}
```

## Handling Multiple Errors

Use `switch` to handle different errors differently:

```zig
fn robustFileRead(path: []const u8) ![]const u8 {
    return readFile(path) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Creating new file at {s}\n", .{path});
            return try createDefaultFile(path);
        },
        error.PermissionDenied => {
            std.debug.print("Permission denied, trying temp directory\n", .{});
            return try readFile("/tmp/fallback.txt");
        },
        error.OutOfMemory => {
            // Can't recover from OOM
            return err;
        },
        else => {
            std.debug.print("Unexpected error: {}\n", .{err});
            return err;
        },
    };
}
```

## When to Use What

### Use `try` when:
- You want to propagate errors to the caller
- The caller is better positioned to handle the error
- You're writing library code

### Use `catch` when:
- You have a sensible fallback value
- You want to log the error and continue
- You're at the top level and need to handle all errors

### Use `if` when:
- You need different logic for success vs. error
- You want to handle specific errors differently
- The error case is not exceptional (like "not found" in a lookup)

### Use `errdefer` when:
- You allocate resources that need cleanup on error
- You're building up a complex object step by step
- You want to prevent resource leaks

## Common Patterns

### Optional Conversion

Convert errors to optionals when the error itself doesn't matter:

```zig
fn findUser(id: u32) ?User {
    // Discard the specific error, just return null on any error
    return lookupUser(id) catch null;
}
```

### Unwrap or Panic

Use `catch unreachable` when you know an error is impossible:

```zig
fn getFirst(items: []const i32) i32 {
    if (items.len == 0) unreachable; // Caller must ensure items.len > 0
    return items[0];
}

// Or be explicit about the contract
fn parseValidatedNumber(text: []const u8) u32 {
    // This text was already validated, so parsing can't fail
    return parseNumber(text) catch unreachable;
}
```

### Error Logging

Wrap errors with context:

```zig
fn processFile(path: []const u8) !void {
    const file = openFile(path) catch |err| {
        std.log.err("Failed to open {s}: {}", .{path, err});
        return err;
    };
    defer file.close();

    processContents(file) catch |err| {
        std.log.err("Failed to process {s}: {}", .{path, err});
        return err;
    };
}
```

## Quick Reference

- Return type `!T` means "error or value"
- `try expr` propagates errors up the call stack
- `expr catch value` provides a fallback value
- `expr catch |err| { ... }` runs code on error
- `if (expr) |val| {} else |err| {}` branches on success/error
- `defer` runs on all exit paths
- `errdefer` runs only on error exit paths
- `error.Name` creates error values
- `switch (err)` handles different errors

See the full compilable example at `code/01-foundation/error_handling.zig`
