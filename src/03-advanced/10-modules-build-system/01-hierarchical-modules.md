## Problem

You need to organize a growing codebase into logical modules with clear hierarchy. You want to group related functionality, control what's exposed publicly, provide convenient access patterns, and maintain a clean API as your project scales.

## Solution

Zig uses explicit imports with `@import()` to create module hierarchies. Structure your code in directories, create parent modules that aggregate child modules, selectively re-export functionality, and design clean public APIs through controlled exports.

### Module Structure

Create a hierarchical organization:

```
recipe_10_1.zig (root)
├── math.zig (parent module)
│   ├── math/basic.zig (basic operations)
│   └── math/advanced.zig (advanced operations)
└── utils.zig (peer module)
```

### Importing Modules

Import modules using file paths relative to the importing file:

```zig
{{#include ../../../code/03-advanced/10-modules-build-system/recipe_10_1.zig:importing_modules}}
```

The path is relative to your project structure. Child modules import their siblings or parent modules similarly.

### Accessing Nested Modules

Access functionality through the module hierarchy:

```zig
test "accessing nested modules" {
    // Access through parent module
    const sum = math.add(5, 3);
    try testing.expectEqual(@as(i32, 8), sum);

    // Access through child module directly
    const product = math.basic.multiply(4, 5);
    try testing.expectEqual(@as(i32, 20), product);

    // Access advanced math through the hierarchy
    const pow = math.advanced.power(2, 10);
    try testing.expectEqual(@as(i64, 1024), pow);
}
```

You can access functions through re-exports at the parent level or directly through child modules.

## Discussion

### Creating Child Modules

Child modules define focused functionality. Here's a basic operations module:

```zig
// basic.zig
const std = @import("std");

/// Add two numbers
pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

/// Divide two numbers (returns error on division by zero)
pub fn divide(a: i32, b: i32) !i32 {
    if (b == 0) {
        return error.DivisionByZero;
    }
    return @divTrunc(a, b);
}
```

Use `pub` to expose functions publicly. Private functions (without `pub`) are only accessible within the module.

### Parent Module Aggregation

Parent modules import and organize child modules:

```zig
// math.zig
const std = @import("std");

// Import child modules
pub const basic = @import("math/basic.zig");
pub const advanced = @import("math/advanced.zig");

// Re-export commonly used functions at this level
pub const add = basic.add;
pub const subtract = basic.subtract;
pub const multiply = basic.multiply;
pub const divide = basic.divide;
```

This provides two access patterns: `math.add(a, b)` or `math.basic.add(a, b)`.

### Re-Exported Functions

Re-exports make common operations more convenient:

```zig
test "using re-exported functions" {
    // These are re-exported at the math module level
    const a = math.add(10, 20);
    const b = math.subtract(50, 15);
    const c = math.multiply(3, 7);

    try testing.expectEqual(@as(i32, 30), a);
    try testing.expectEqual(@as(i32, 35), b);
    try testing.expectEqual(@as(i32, 21), c);

    // Division returns error union
    const d = try math.divide(100, 4);
    try testing.expectEqual(@as(i32, 25), d);
}
```

Users can choose between convenience (re-exports) and explicitness (child module access).

### Module-Level Coordination Functions

Parent modules can provide coordination functions:

```zig
// In math.zig
pub fn calculate(operation: Operation, a: i32, b: i32) !i32 {
    return switch (operation) {
        .add => basic.add(a, b),
        .subtract => basic.subtract(a, b),
        .multiply => basic.multiply(a, b),
        .divide => try basic.divide(a, b),
    };
}

pub const Operation = enum {
    add,
    subtract,
    multiply,
    divide,
};
```

This provides a unified interface across child module functionality:

```zig
test "module-level functions" {
    const result1 = try math.calculate(.add, 15, 25);
    try testing.expectEqual(@as(i32, 40), result1);

    const result2 = try math.calculate(.multiply, 6, 7);
    try testing.expectEqual(@as(i32, 42), result2);
}
```

### Advanced Operations Module

Separate complex functionality into dedicated modules:

```zig
// advanced.zig
pub fn power(a: i32, b: u32) i64 {
    if (b == 0) return 1;

    var result: i64 = 1;
    var i: u32 = 0;
    while (i < b) : (i += 1) {
        result *= a;
    }
    return result;
}

pub fn factorial(n: u32) u64 {
    if (n == 0 or n == 1) return 1;

    var result: u64 = 1;
    var i: u32 = 2;
    while (i <= n) : (i += 1) {
        result *= i;
    }
    return result;
}

pub fn isPrime(n: u32) bool {
    if (n < 2) return false;
    if (n == 2) return true;
    if (n % 2 == 0) return false;

    var i: u32 = 3;
    while (i * i <= n) : (i += 2) {
        if (n % i == 0) return false;
    }
    return true;
}
```

Access these through the parent module:

```zig
test "advanced math operations" {
    // Power function
    try testing.expectEqual(@as(i64, 8), math.advanced.power(2, 3));

    // Factorial function
    try testing.expectEqual(@as(u64, 120), math.advanced.factorial(5));

    // Prime checking
    try testing.expect(math.advanced.isPrime(7));
    try testing.expect(!math.advanced.isPrime(9));
}
```

### Peer Modules

Create peer modules at the same level for different concerns:

```zig
// utils.zig
const std = @import("std");

/// Convert integer to string
pub fn intToString(allocator: std.mem.Allocator, value: i32) ![]u8 {
    return std.fmt.allocPrint(allocator, "{d}", .{value});
}

/// Check if string is numeric
pub fn isNumeric(str: []const u8) bool {
    if (str.len == 0) return false;

    var start: usize = 0;
    if (str[0] == '-' or str[0] == '+') {
        if (str.len == 1) return false;
        start = 1;
    }

    for (str[start..]) |c| {
        if (c < '0' or c > '9') return false;
    }
    return true;
}
```

Use peer modules alongside hierarchical ones:

```zig
test "utility functions" {
    const allocator = testing.allocator;

    const str = try utils.intToString(allocator, 42);
    defer allocator.free(str);
    try testing.expectEqualStrings("42", str);

    try testing.expect(utils.isNumeric("123"));
    try testing.expect(!utils.isNumeric("abc"));
}
```

### Cross-Module Usage

Combine multiple modules in your application:

```zig
test "cross-module usage" {
    const allocator = testing.allocator;

    // Calculate using math module
    const result = try math.calculate(.add, 10, 32);

    // Convert result to string using utils module
    const str = try utils.intToString(allocator, result);
    defer allocator.free(str);

    try testing.expectEqualStrings("42", str);

    // Verify it's numeric
    try testing.expect(utils.isNumeric(str));
}
```

Modules remain independent but compose naturally.

### Hierarchical Access Patterns

Provide flexibility in how users access functionality:

```zig
test "hierarchical access patterns" {
    // Direct access through re-export
    const a = math.add(5, 3);

    // Access through child module
    const b = math.basic.add(5, 3);

    // Both should give same result
    try testing.expectEqual(a, b);

    // Can access enum through parent module
    const op: math.Operation = .add;
    const c = try math.calculate(op, 5, 3);

    try testing.expectEqual(a, c);
}
```

Different patterns suit different use cases and preferences.

### Public API Design

Design clean public APIs through selective exports:

```zig
const math_mod = math;
const utils_mod = utils;

const PublicAPI = struct {
    // Expose only selected functionality
    pub const MathOps = struct {
        pub const add = math_mod.add;
        pub const subtract = math_mod.subtract;
        pub const power = math_mod.advanced.power;
        pub const factorial = math_mod.advanced.factorial;
    };

    pub const Utils = struct {
        pub const parseInt = utils_mod.parseInt;
        pub const isNumeric = utils_mod.isNumeric;
    };
};

test "public API design" {
    // Users only see curated public API
    const sum = PublicAPI.MathOps.add(10, 20);
    try testing.expectEqual(@as(i32, 30), sum);

    const pow = PublicAPI.MathOps.power(2, 8);
    try testing.expectEqual(@as(i64, 256), pow);
}
```

This creates a stable public API while keeping implementation details private.

### Module Organization Benefits

Hierarchical organization provides several advantages:

**Namespace Separation:**
- Clear boundaries between different areas of functionality
- Prevents naming conflicts
- Makes dependencies explicit

**Selective Imports:**
- Import only what you need
- Reduces compilation dependencies
- Clearer code intent

**Consistent API Structure:**
- Predictable organization
- Similar operations grouped together
- Easier to discover functionality

**Clear Dependencies:**
- Explicit import statements show relationships
- No hidden dependencies
- Easy to understand data flow

**Scalability:**
- Add new modules without restructuring existing code
- Split large modules into smaller ones
- Maintain backward compatibility through re-exports

### Best Practices

Follow these guidelines for module organization:

**File Organization:**
- One module per file
- Group related modules in directories
- Mirror module hierarchy in filesystem structure

**Naming Conventions:**
- Use lowercase for module files (`math.zig`, not `Math.zig`)
- Descriptive module names (`basic.zig`, `advanced.zig`)
- Match module name to its primary purpose

**Public Interface:**
- Make only necessary items `pub`
- Group related exports in parent modules
- Provide re-exports for common operations
- Document public API with `///` comments

**Module Size:**
- Keep modules focused on single responsibility
- Split large modules into child modules
- Aim for 200-500 lines per module
- Create sub-directories when > 5 related modules

**Import Strategy:**
- Import modules, not individual functions
- Use const declarations for imports
- Avoid circular dependencies
- Keep import list at top of file

### When to Create Hierarchies

Use hierarchical modules when:

**Growing Codebase:**
- File exceeds 500 lines
- Multiple related functions
- Distinct logical groupings emerge

**Multiple Developers:**
- Clear ownership boundaries
- Parallel development needed
- Independent testing required

**Public Libraries:**
- Need version stability
- Want to hide implementation details
- Provide multiple access patterns

**Domain Complexity:**
- Multiple layers of abstraction
- Different levels of user sophistication
- Gradual feature exposure

### Common Patterns

**Feature Modules:**
```
features/
├── auth.zig (authentication)
├── db.zig (database access)
└── api.zig (API handlers)
```

**Layer Architecture:**
```
app/
├── presentation/ (UI layer)
├── business/ (logic layer)
└── data/ (persistence layer)
```

**Component-Based:**
```
components/
├── button/
│   ├── button.zig
│   └── styles.zig
└── input/
    ├── input.zig
    └── validation.zig
```

### Testing Hierarchical Modules

Test at multiple levels:

**Unit Tests** (in child modules):
```zig
// In basic.zig
test "add" {
    const testing = @import("std").testing;
    try testing.expectEqual(@as(i32, 7), add(3, 4));
}
```

**Integration Tests** (in parent modules):
```zig
// In math.zig
test "calculate all operations" {
    try testing.expectEqual(@as(i32, 7), try calculate(.add, 3, 4));
    try testing.expectEqual(@as(i32, 12), try calculate(.multiply, 3, 4));
}
```

**System Tests** (in root):
```zig
// In recipe_10_1.zig
test "comprehensive usage" {
    // Tests cross-module integration
}
```

### Documentation Generation

Zig generates documentation from module structure:

```bash
zig build-lib math.zig -femit-docs
```

This creates HTML documentation showing the hierarchy. Use `///` doc comments:

```zig
/// Add two integers.
/// Returns the sum of a and b.
pub fn add(a: i32, b: i32) i32 {
    return a + b;
}
```

### Module Initialization

Modules can have initialization code:

```zig
const std = @import("std");

// Module-level constant
const VERSION = "1.0.0";

// Comptime initialization
const lookup_table = blk: {
    var table: [256]u8 = undefined;
    for (&table, 0..) |*val, i| {
        val.* = @intCast(i);
    }
    break :blk table;
};
```

This code runs once when the module is first imported.

### Avoiding Circular Dependencies

Circular dependencies cause compilation errors:

```zig
// DON'T: Circular dependency
// a.zig imports b.zig
// b.zig imports a.zig
```

Solutions:

1. **Extract Common Code:**
   Create a third module for shared functionality

2. **Dependency Inversion:**
   Pass dependencies as parameters instead of importing

3. **Interface Definitions:**
   Define interfaces in a separate module

## See Also

- Recipe 10.2: Controlling the export of symbols
- Recipe 10.4: Splitting a module into multiple files
- Recipe 10.5: Making separate directories of code import under a common namespace

Full compilable example: `code/03-advanced/10-modules-build-system/recipe_10_1.zig`
