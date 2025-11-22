// Recipe 10.2: Controlling the Export of Symbols
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to control symbol visibility using the pub keyword,
// creating clean public APIs while hiding implementation details.

const std = @import("std");
const testing = std.testing;

// ANCHOR: public_vs_private
// Public vs Private declarations
const InternalCounter = struct {
    // Private field (no pub keyword)
    value: i32,

    // Public function
    pub fn init() InternalCounter {
        return .{ .value = 0 };
    }

    // Public function
    pub fn increment(self: *InternalCounter) void {
        self.value += 1;
    }

    // Public function
    pub fn getValue(self: *const InternalCounter) i32 {
        return self.value;
    }

    // Private function (no pub keyword)
    fn reset(self: *InternalCounter) void {
        self.value = 0;
    }
};

test "public vs private" {
    var counter = InternalCounter.init();
    counter.increment();

    try testing.expectEqual(@as(i32, 1), counter.getValue());

    // Can access private function within same file
    counter.reset();
    try testing.expectEqual(@as(i32, 0), counter.getValue());

    // Note: Outside this file, reset() wouldn't be accessible
}
// ANCHOR_END: public_vs_private

// ANCHOR: selective_exports
// Module with selective exports
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
// ANCHOR_END: selective_exports

// ANCHOR: api_surface
// Control API surface area with selective exports
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

    const lower = try StringUtils.toLower(allocator, "WORLD");
    defer allocator.free(lower);
    try testing.expectEqualStrings("world", lower);

    // Helper functions are private, users can't call them directly
    // StringUtils.upperCaseChar('a'); // Compile error outside this file
}
// ANCHOR_END: api_surface

// ANCHOR: namespace_exports
// Create namespace with controlled exports
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
    try testing.expect(Math.isClose(1.0, 1.00000000001)); // Within EPSILON

    const dist = Math.distance(0, 0, 3, 4);
    try testing.expectEqual(@as(f64, 5.0), dist);

    // Cannot access private members
    // const eps = Math.EPSILON; // Compile error
    // Math.square(2.0); // Compile error
}
// ANCHOR_END: namespace_exports

// ANCHOR: reexporting
// Re-export symbols from other modules with control
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
// ANCHOR_END: reexporting

// ANCHOR: versioned_api
// Create versioned API exports
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
// ANCHOR_END: versioned_api

// ANCHOR: privacy_levels
// Demonstrate different privacy levels
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
// ANCHOR_END: privacy_levels

// ANCHOR: testing_private
// Testing private implementation within the same file
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
// ANCHOR_END: testing_private

// ANCHOR: export_patterns
// Common export patterns
pub const Patterns = struct {
    // Pattern 1: Factory with private constructor
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

    // Pattern 2: Opaque handle
    pub const Handle = struct {
        const Self = @This();

        ptr: *anyopaque,

        // Prevent direct construction
        pub fn fromInt(value: usize) Handle {
            return .{ .ptr = @ptrFromInt(value) };
        }

        pub fn toInt(self: Handle) usize {
            return @intFromPtr(self.ptr);
        }
    };

    // Private helper for Widget
    var next_id: u32 = 1;

    fn generateId() u32 {
        const id = next_id;
        next_id += 1;
        return id;
    }
};

test "export patterns" {
    // Pattern 1: Factory
    const w1 = Patterns.Widget.create();
    const w2 = Patterns.Widget.create();
    try testing.expect(w1.getId() != w2.getId());

    // Cannot call private init directly (outside this file)
    // const w3 = Patterns.Widget.init(99); // Would compile in same file

    // Pattern 2: Opaque handle
    const handle = Patterns.Handle.fromInt(12345);
    try testing.expectEqual(@as(usize, 12345), handle.toInt());
}
// ANCHOR_END: export_patterns

// ANCHOR: conditional_exports
// Conditional exports based on build options
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
// ANCHOR_END: conditional_exports

// ANCHOR: documentation_exports
// Export symbols with documentation
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

test "documented exports" {
    try testing.expectEqual(@as(i32, 8), Documented.add(5, 3));
    try testing.expectEqual(@as(i32, 1000), Documented.MAX_VALUE);

    // Can still test private constants in same file
    try testing.expectEqual(@as(usize, 4096), Documented.INTERNAL_BUFFER_SIZE);
}
// ANCHOR_END: documentation_exports

// Comprehensive test
test "comprehensive export control" {
    // Public vs private
    var counter = InternalCounter.init();
    counter.increment();
    try testing.expectEqual(@as(i32, 1), counter.getValue());

    // Selective exports
    const allocator = testing.allocator;
    const upper = try StringUtils.toUpper(allocator, "test");
    defer allocator.free(upper);
    try testing.expectEqualStrings("TEST", upper);

    // Namespace exports
    try testing.expect(Math.PI > 3.0);

    // Versioned API
    try testing.expectEqual(@as(i32, 10), Latest.process(5, 2));

    // Privacy levels
    const public_obj = Library.PublicType.new(42);
    try testing.expectEqual(@as(i32, 42), public_obj.value);

    try testing.expect(true);
}
