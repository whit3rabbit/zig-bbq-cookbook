## Problem

You need to control which symbols are visible to users of your module. You want to create a clean public API, hide implementation details, prevent misuse of internal functions, and maintain flexibility to refactor private code without breaking users.

## Solution

Use the `pub` keyword to mark declarations as public. Anything without `pub` is private to the file/module. Design your API surface carefully by exposing only what users need and keeping implementation details private.

### Public vs Private Declarations

Public declarations use `pub`, private ones don't:

```zig
{{#include ../../../code/03-advanced/10-modules-build-system/recipe_10_2.zig:public_vs_private}}
```

Within the same file, all declarations are accessible. In importing modules, only `pub` declarations are visible.

## Discussion

### Selective Exports

Export only the types and functions users need:

```zig
const Database = struct {
    // Public type for users
    pub const Connection = struct {
        handle: *ConnectionImpl,

        pub fn query(self: *Connection, sql: []const u8) !void {
            return self.handle.execute(sql);
        }
    };

    // Private implementation (not exported)
    const ConnectionImpl = struct {
        connected: bool,

        fn execute(self: *ConnectionImpl, sql: []const u8) !void {
            if (!self.connected) {
                return error.NotConnected;
            }
            // Simulated query execution
            _ = sql;
        }
    };

    // Public factory function
    pub fn connect() !Connection {
        var impl = ConnectionImpl{ .connected = true };
        // NOTE: For demonstration only - in production, ConnectionImpl
        // would be heap-allocated with allocator.create()
        return Connection{ .handle = &impl };
    }
};

test "selective exports" {
    var conn = try Database.connect();

    // Can use public Connection type
    try conn.query("SELECT * FROM users");

    // Cannot access ConnectionImpl - it's private to Database
    // const impl: Database.ConnectionImpl = undefined; // Compile error
}
```

Users see `Connection` but `ConnectionImpl` remains private.

### Controlling API Surface

Keep helper functions private:

```zig
const StringUtils = struct {
    // Public API
    pub fn toUpper(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        const result = try allocator.alloc(u8, input.len);
        for (input, 0..) |c, i| {
            result[i] = upperCaseChar(c);
        }
        return result;
    }

    pub fn toLower(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        const result = try allocator.alloc(u8, input.len);
        for (input, 0..) |c, i| {
            result[i] = lowerCaseChar(c);
        }
        return result;
    }

    // Private helper functions (implementation details)
    fn upperCaseChar(c: u8) u8 {
        if (c >= 'a' and c <= 'z') {
            return c - 32;
        }
        return c;
    }

    fn lowerCaseChar(c: u8) u8 {
        if (c >= 'A' and c <= 'Z') {
            return c + 32;
        }
        return c;
    }
};

test "API surface control" {
    const allocator = testing.allocator;

    const upper = try StringUtils.toUpper(allocator, "hello");
    defer allocator.free(upper);
    try testing.expectEqualStrings("HELLO", upper);

    // Helper functions are private, users can't call them directly
    // StringUtils.upperCaseChar('a'); // Compile error outside this file
}
```

Users call `toUpper()` and `toLower()` without seeing implementation details.

### Namespace Exports

Create namespaces with public and private members:

```zig
pub const Math = struct {
    // Public constants
    pub const PI: f64 = 3.14159265358979323846;
    pub const E: f64 = 2.71828182845904523536;

    // Private constant (implementation detail)
    const EPSILON: f64 = 1e-10;

    // Public functions
    pub fn abs(x: f64) f64 {
        return if (x < 0) -x else x;
    }

    pub fn isClose(a: f64, b: f64) bool {
        return abs(a - b) < EPSILON;
    }

    // Private helper
    fn square(x: f64) f64 {
        return x * x;
    }

    // Public function using private helper
    pub fn distance(x1: f64, y1: f64, x2: f64, y2: f64) f64 {
        const dx = x2 - x1;
        const dy = y2 - y1;
        return @sqrt(square(dx) + square(dy));
    }
};

test "namespace exports" {
    try testing.expect(Math.PI > 3.14);
    try testing.expect(Math.E > 2.71);

    try testing.expectEqual(@as(f64, 5.0), Math.abs(-5.0));
    try testing.expect(Math.isClose(1.0, 1.00000000001));

    const dist = Math.distance(0, 0, 3, 4);
    try testing.expectEqual(@as(f64, 5.0), dist);

    // Cannot access private members
    // const eps = Math.EPSILON; // Compile error
    // Math.square(2.0); // Compile error
}
```

Public functions can use private helpers internally.

### Selective Re-Exporting

Re-export only some symbols from internal modules:

```zig
const internal = struct {
    pub fn internalFunc1() i32 {
        return 42;
    }

    pub fn internalFunc2() i32 {
        return 24;
    }

    pub fn internalFunc3() i32 {
        return 99;
    }
};

pub const PublicAPI = struct {
    // Selectively re-export only some functions
    pub const func1 = internal.internalFunc1;
    pub const func2 = internal.internalFunc2;

    // Don't export internalFunc3 - it's an implementation detail
};

test "selective re-exporting" {
    try testing.expectEqual(@as(i32, 42), PublicAPI.func1());
    try testing.expectEqual(@as(i32, 24), PublicAPI.func2());

    // func3 is not exported
    // PublicAPI.func3(); // Compile error

    // But we can still test internal functions in the same file
    try testing.expectEqual(@as(i32, 99), internal.internalFunc3());
}
```

This creates a curated public interface while keeping full functionality for internal use.

### Versioned API Exports

Maintain multiple API versions:

```zig
pub const V1 = struct {
    pub fn process(value: i32) i32 {
        return value * 2;
    }
};

pub const V2 = struct {
    pub fn process(value: i32, multiplier: i32) i32 {
        return value * multiplier;
    }

    // V2 can delegate to V1 for compatibility
    pub fn processSimple(value: i32) i32 {
        return V1.process(value);
    }
};

// Latest version alias
pub const Latest = V2;

test "versioned API" {
    try testing.expectEqual(@as(i32, 10), V1.process(5));
    try testing.expectEqual(@as(i32, 15), V2.process(5, 3));
    try testing.expectEqual(@as(i32, 10), V2.processSimple(5));
    try testing.expectEqual(@as(i32, 15), Latest.process(5, 3));
}
```

Users can choose which version to use, and `Latest` always points to the newest.

### Privacy Levels

Demonstrate different levels of encapsulation:

```zig
pub const Library = struct {
    // Level 1: Public type with fields accessible
    pub const PublicType = struct {
        value: i32, // Fields are accessible where struct is accessible

        pub fn new(val: i32) PublicType {
            return .{ .value = val };
        }
    };

    // Level 2: Public type, recommended accessor pattern
    pub const EncapsulatedType = struct {
        value: i32,

        pub fn new(val: i32) EncapsulatedType {
            return .{ .value = val };
        }

        pub fn getValue(self: *const EncapsulatedType) i32 {
            return self.value;
        }

        pub fn setValue(self: *EncapsulatedType, val: i32) void {
            self.value = val;
        }
    };

    // Level 3: Completely private (no pub)
    const PrivateType = struct {
        value: i32,
    };

    // Public function using private type
    pub fn usePrivateType() i32 {
        const p = PrivateType{ .value = 100 };
        return p.value;
    }
};

test "privacy levels" {
    // Level 1: Full access (fields accessible in same module)
    var public_var = Library.PublicType.new(10);
    public_var.value = 20;
    try testing.expectEqual(@as(i32, 20), public_var.value);

    // Level 2: Encapsulation pattern (use accessors)
    var encap = Library.EncapsulatedType.new(30);
    try testing.expectEqual(@as(i32, 30), encap.getValue());
    encap.setValue(40);
    try testing.expectEqual(@as(i32, 40), encap.getValue());

    // Level 3: Cannot access type at all from outside module
    // const priv: Library.PrivateType = undefined; // Compile error

    // But can use functions that return values from private types
    try testing.expectEqual(@as(i32, 100), Library.usePrivateType());
}
```

Choose the privacy level that matches your needs.

### Testing Private Implementation

Tests in the same file can verify private functions:

```zig
const Calculator = struct {
    // Private implementation
    fn add_internal(a: i32, b: i32) i32 {
        return a + b;
    }

    fn multiply_internal(a: i32, b: i32) i32 {
        return a * b;
    }

    // Public API
    pub fn calculate(a: i32, b: i32, op: Op) i32 {
        return switch (op) {
            .add => add_internal(a, b),
            .multiply => multiply_internal(a, b),
        };
    }

    pub const Op = enum {
        add,
        multiply,
    };
};

test "testing private implementation" {
    // Within the same file, we can test private functions
    try testing.expectEqual(@as(i32, 7), Calculator.add_internal(3, 4));
    try testing.expectEqual(@as(i32, 12), Calculator.multiply_internal(3, 4));

    // Public API still works
    try testing.expectEqual(@as(i32, 7), Calculator.calculate(3, 4, .add));
    try testing.expectEqual(@as(i32, 12), Calculator.calculate(3, 4, .multiply));
}
```

This allows thorough testing while keeping implementation details private to external users.

### Common Export Patterns

**Pattern 1: Factory with Private Constructor**

```zig
pub const Widget = struct {
    id: u32,

    // Private - users must use factory
    fn init(id: u32) Widget {
        return .{ .id = id };
    }

    // Public factory
    pub fn create() Widget {
        return init(generateId());
    }

    pub fn getId(self: *const Widget) u32 {
        return self.id;
    }
};
```

Forces users to use controlled initialization.

**Pattern 2: Opaque Handle**

```zig
pub const Handle = struct {
    ptr: *anyopaque,

    pub fn fromInt(value: usize) Handle {
        return .{ .ptr = @ptrFromInt(value) };
    }

    pub fn toInt(self: Handle) usize {
        return @intFromPtr(self.ptr);
    }
};
```

Hides internal representation completely.

### Conditional Exports

Export symbols conditionally based on build configuration:

```zig
const build_options = struct {
    // In production, this would be: @import("build_options")
    // configured via: exe.addOptions(options) in build.zig
    const enable_debug = true;
};

pub const Debug = if (build_options.enable_debug) struct {
    pub fn log(msg: []const u8) void {
        std.debug.print("[DEBUG] {s}\n", .{msg});
    }

    pub fn assert(condition: bool) void {
        std.debug.assert(condition);
    }
} else struct {
    // Empty struct when debug is disabled
};

test "conditional exports" {
    if (build_options.enable_debug) {
        Debug.log("Test message");
        Debug.assert(true);
    }
    try testing.expect(true);
}
```

This allows different APIs for different build configurations.

### Documentation Exports

Document public APIs with `///` comments:

```zig
pub const Documented = struct {
    /// A documented public function
    /// that shows how to use doc comments.
    ///
    /// Example:
    /// ```
    /// const result = Documented.add(5, 3);
    /// ```
    pub fn add(a: i32, b: i32) i32 {
        return addImpl(a, b);
    }

    // Private implementation (no doc comment needed)
    fn addImpl(a: i32, b: i32) i32 {
        return a + b;
    }

    /// Maximum supported value
    pub const MAX_VALUE: i32 = 1000;

    // Private constant (no doc comment)
    const INTERNAL_BUFFER_SIZE: usize = 4096;
};
```

Only public declarations need documentation comments.

### Best Practices

**Start with Everything Private:**
- Make declarations private by default
- Add `pub` only when needed
- This prevents accidental API exposure

**Group Related Exports:**
- Use structs as namespaces
- Keep related functions together
- Provide clear module boundaries

**Use Accessor Patterns:**
- Provide getters/setters for encapsulated types
- Validate inputs in setters
- Keep fields private when validation is needed

**Version Your APIs:**
- Export versioned namespaces (V1, V2, etc.)
- Provide `Latest` alias for current version
- Maintain backward compatibility when possible

**Document Public APIs:**
- Use `///` for all public functions
- Include examples in doc comments
- Explain error conditions

**Test Private Code:**
- Write tests in the same file
- Verify implementation details
- Keep integration tests in separate files

### Design Considerations

**When to Make Something Public:**
- Users need to call/access it
- Part of the stable API contract
- Designed for external use

**When to Keep Something Private:**
- Implementation detail
- May change in future versions
- Internal helper function
- Validation or sanitization logic

**Privacy and Performance:**
- Privacy is compile-time only (zero runtime cost)
- Private functions inline just like public ones
- No performance penalty for encapsulation

### Common Patterns Summary

| Pattern | Use Case | Example |
|---------|----------|---------|
| Public struct with private fields | Encapsulation | `pub const Type = struct { value: i32, ... }` |
| Private helper functions | Implementation details | `fn helper() void { ... }` |
| Factory pattern | Controlled initialization | `pub fn create() T { ... }` |
| Opaque handle | Complete abstraction | `pub const Handle = struct { ptr: *anyopaque }` |
| Namespace | Grouping related functions | `pub const Math = struct { ... }` |
| Re-exporting | API facade | `pub const api = internal.func;` |
| Versioned exports | API stability | `pub const V1 = struct { ... }` |
| Conditional exports | Build-specific APIs | `pub const Debug = if (enable) ...` |

### Avoiding Common Mistakes

**Don't expose internals accidentally:**
```zig
// Bad: exposes implementation
pub const Config = struct {
    pub internal_state: i32, // Users can modify this!
};

// Good: encapsulated
pub const Config = struct {
    internal_state: i32,

    pub fn getState(self: *const Config) i32 {
        return self.internal_state;
    }
};
```

**Don't make everything public:**
```zig
// Bad: too much exposure
pub fn publicFunc() void {
    pub fn helperA() void { ... } // Compile error anyway
    pub fn helperB() void { ... } // Compile error anyway
}

// Good: only what's needed
pub fn publicFunc() void {
    helperA();
    helperB();
}

fn helperA() void { ... }
fn helperB() void { ... }
```

**Don't forget to document public APIs:**
```zig
// Bad: no documentation
pub fn process(data: []const u8) !void { ... }

// Good: documented
/// Process the input data.
/// Returns error.InvalidData if data is malformed.
pub fn process(data: []const u8) !void { ... }
```

## See Also

- Recipe 10.1: Making a hierarchical package of modules
- Recipe 10.4: Splitting a module into multiple files
- Recipe 8.12: Defining an interface

Full compilable example: `code/03-advanced/10-modules-build-system/recipe_10_2.zig`
