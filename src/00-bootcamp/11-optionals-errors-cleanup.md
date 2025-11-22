# Optionals, Errors, and Resource Cleanup

## Problem

You need to handle values that might be null, operations that might fail, and resources that need cleanup. How do you represent optional values? How do you handle errors without exceptions? How do you ensure cleanup code runs even when errors occur?

Coming from languages with null pointers and exceptions, Zig's approach is different but safer.

## Solution

Zig provides three powerful features for safe programming:

1. **Optionals `?T`** - Explicitly mark values that might be null
2. **Error unions `!T`** - Return errors as values, not exceptions
3. **defer/errdefer** - Automatic cleanup when scope exits

These eliminate entire classes of bugs: null pointer dereferences, unchecked exceptions, and resource leaks.

## Discussion

### Part 1: Optionals (?T)

```zig
{{#include ../../code/00-bootcamp/recipe_0_11.zig:optionals}}
```

**Coming from Java/C++:** `?T` is like `Optional<T>` or `std::optional<T>`, but built into the language. Unlike C/C++ pointers, you can't accidentally dereference null.

### Part 2: Error Unions (!T)

```zig
{{#include ../../code/00-bootcamp/recipe_0_11.zig:error_unions}}
```

**Coming from Java/Python:** Errors are return values, not exceptions. There's no try/catch blocks or stack unwinding. Error handling is explicit and visible in the code.

### Part 3: Resource Cleanup with defer and errdefer

```zig
{{#include ../../code/00-bootcamp/recipe_0_11.zig:defer_errdefer}}
```

Each `errdefer` handles cleanup for what was allocated before it. If initialization fails at any stage, all relevant cleanup runs.

### Combining Optionals and Errors

Sometimes you need both:

```zig
test "optional error unions" {
    const parseNumber = struct {
        fn call(str: []const u8) !?i32 {
            if (str.len == 0) return null;
            if (str[0] == 'x') return error.InvalidFormat;
            return 42;
        }
    }.call;

    // Success
    const result1 = try parseNumber("123");
    try testing.expectEqual(@as(?i32, 42), result1);

    // Null (not an error)
    const result2 = try parseNumber("");
    try testing.expectEqual(@as(?i32, null), result2);

    // Error
    const result3 = parseNumber("x");
    try testing.expectError(error.InvalidFormat, result3);
}
```

The type `!?T` means "either an error, or an optional T". This distinguishes:
- Success with value
- Success with no value (null)
- Failure (error)

### Practical Example

Here's a complete example combining all three features:

```zig
test "practical example: safe file operations" {
    const FileOps = struct {
        fn open(name: []const u8) !?*u32 {
            if (std.mem.eql(u8, name, "")) return null;
            if (std.mem.eql(u8, name, "bad")) return error.AccessDenied;

            const handle = try testing.allocator.create(u32);
            handle.* = 42;
            return handle;
        }

        fn close(handle: *u32, allocator: std.mem.Allocator) void {
            allocator.destroy(handle);
        }
    };

    // Successful open and close
    if (try FileOps.open("good.txt")) |handle| {
        defer FileOps.close(handle, testing.allocator);
        try testing.expectEqual(@as(u32, 42), handle.*);
    }

    // File doesn't exist (null, not error)
    const no_file = try FileOps.open("");
    try testing.expectEqual(@as(?*u32, null), no_file);

    // Access denied (error)
    const denied = FileOps.open("bad");
    try testing.expectError(error.AccessDenied, denied);
}
```

This pattern ensures:
- Resources are always cleaned up (defer)
- Errors are explicit and handled
- Null is distinct from error

### Decision Tree

**Should I use optional or error?**
- Value might not exist (but that's OK) → Use `?T`
- Operation might fail (that's an error) → Use `!T`
- Both possible → Use `!?T`

**Should I use defer or errdefer?**
- Cleanup always needed → Use `defer`
- Cleanup only on error → Use `errdefer`
- Both needed → Use both!

### Common Patterns

**Resource acquisition:**
```zig
const resource = try allocate();
defer free(resource);
```

**Error path cleanup:**
```zig
var resource = try init();
errdefer deinit(resource);
```

**Unwrapping with default:**
```zig
const value = optional orelse default_value;
const value = try_operation() catch default_value;
```

### Common Mistakes

**Forgetting defer:**
```zig
const data = try allocator.alloc(u8, 100);
// ... use data ...
// Memory leak! Need: defer allocator.free(data);
```

**Using .? on null:**
```zig
const maybe: ?i32 = null;
const value = maybe.?;  // Panic! Use if (maybe) |val| instead
```

**Not handling all error cases:**
```zig
const result = try riskyOperation();
// If riskyOperation returns error, function exits here
// Use catch if you want to handle it
```

**Wrong order of defer/errdefer:**
```zig
errdefer allocator.free(data);
const data = try allocator.alloc(u8, 100);  // Wrong! errdefer runs before allocation
```

Fix: Put errdefer after the allocation.

## See Also

- Recipe 0.12: Understanding Allocators - Why defer is crucial for memory management
- Recipe 0.7: Functions and Standard Library - Error returns with !T
- Recipe 0.13: Testing and Debugging - Testing error conditions

Full compilable example: `code/00-bootcamp/recipe_0_11.zig`
