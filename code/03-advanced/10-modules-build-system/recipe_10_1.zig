// Recipe 10.1: Making a Hierarchical Package of Modules
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to organize code into a hierarchical
// module structure with multiple levels of imports and re-exports.
//
// Module structure:
// recipe_10_1.zig (root)
// ├── math.zig (parent module)
// │   ├── math/basic.zig (child module)
// │   └── math/advanced.zig (child module)
// └── utils.zig (peer module)

const std = @import("std");
const testing = std.testing;

// ANCHOR: importing_modules
// Import top-level modules from the package
const math = @import("recipe_10_1/math.zig");
const utils = @import("recipe_10_1/utils.zig");
// ANCHOR_END: importing_modules

// ANCHOR: accessing_nested_modules
// Access functions from nested modules in different ways
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
// ANCHOR_END: accessing_nested_modules

// ANCHOR: using_reexported_functions
// Use re-exported functions from parent module
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

    // Test error case
    const err = math.divide(10, 0);
    try testing.expectError(error.DivisionByZero, err);
}
// ANCHOR_END: using_reexported_functions

// ANCHOR: module_level_functions
// Use module-level functions that coordinate child modules
test "module-level functions" {
    const result1 = try math.calculate(.add, 15, 25);
    try testing.expectEqual(@as(i32, 40), result1);

    const result2 = try math.calculate(.multiply, 6, 7);
    try testing.expectEqual(@as(i32, 42), result2);

    const result3 = try math.calculate(.subtract, 100, 42);
    try testing.expectEqual(@as(i32, 58), result3);

    const result4 = try math.calculate(.divide, 50, 5);
    try testing.expectEqual(@as(i32, 10), result4);
}
// ANCHOR_END: module_level_functions

// ANCHOR: basic_math_operations
// Test basic math operations from the basic module
test "basic math operations" {
    try testing.expectEqual(@as(i32, 7), math.basic.add(3, 4));
    try testing.expectEqual(@as(i32, 1), math.basic.subtract(5, 4));
    try testing.expectEqual(@as(i32, 12), math.basic.multiply(3, 4));
    try testing.expectEqual(@as(i32, 3), try math.basic.divide(9, 3));
}
// ANCHOR_END: basic_math_operations

// ANCHOR: advanced_math_operations
// Test advanced math operations from the advanced module
test "advanced math operations" {
    // Power function
    try testing.expectEqual(@as(i64, 8), math.advanced.power(2, 3));
    try testing.expectEqual(@as(i64, 1), math.advanced.power(5, 0));
    try testing.expectEqual(@as(i64, 125), math.advanced.power(5, 3));

    // Factorial function
    try testing.expectEqual(@as(u64, 1), math.advanced.factorial(0));
    try testing.expectEqual(@as(u64, 1), math.advanced.factorial(1));
    try testing.expectEqual(@as(u64, 120), math.advanced.factorial(5));
    try testing.expectEqual(@as(u64, 3628800), math.advanced.factorial(10));

    // Prime checking
    try testing.expect(!math.advanced.isPrime(0));
    try testing.expect(!math.advanced.isPrime(1));
    try testing.expect(math.advanced.isPrime(2));
    try testing.expect(math.advanced.isPrime(7));
    try testing.expect(!math.advanced.isPrime(9));
    try testing.expect(math.advanced.isPrime(13));
}
// ANCHOR_END: advanced_math_operations

// ANCHOR: utility_functions
// Test utility functions from utils module
test "utility functions" {
    const allocator = testing.allocator;

    // Integer to string conversion
    const str = try utils.intToString(allocator, 42);
    defer allocator.free(str);
    try testing.expectEqualStrings("42", str);

    // Numeric checking
    try testing.expect(utils.isNumeric("123"));
    try testing.expect(utils.isNumeric("-456"));
    try testing.expect(!utils.isNumeric("abc"));
    try testing.expect(!utils.isNumeric("12a3"));
    try testing.expect(!utils.isNumeric(""));

    // Integer parsing
    try testing.expectEqual(@as(i32, 123), try utils.parseInt("123"));
    try testing.expectEqual(@as(i32, -456), try utils.parseInt("-456"));

    // Clamping
    try testing.expectEqual(@as(i32, 5), utils.clamp(5, 0, 10));
    try testing.expectEqual(@as(i32, 0), utils.clamp(-5, 0, 10));
    try testing.expectEqual(@as(i32, 10), utils.clamp(15, 0, 10));
}
// ANCHOR_END: utility_functions

// ANCHOR: cross_module_usage
// Demonstrate using multiple modules together
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

    // Parse it back
    const parsed = try utils.parseInt(str);
    try testing.expectEqual(result, parsed);
}
// ANCHOR_END: cross_module_usage

// ANCHOR: hierarchical_access_patterns
// Different ways to access the same functionality
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
// ANCHOR_END: hierarchical_access_patterns

// ANCHOR: public_api_design
// Demonstrate a clean public API through selective exports
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

    try testing.expect(PublicAPI.Utils.isNumeric("123"));
}
// ANCHOR_END: public_api_design

// ANCHOR: module_organization_benefits
// Demonstrate benefits of hierarchical organization
test "module organization benefits" {
    // 1. Namespace separation
    const math_result = math.basic.add(5, 3);
    _ = math_result;

    // 2. Selective imports (only import what you need)
    const basic = math.basic;
    const advanced = math.advanced;
    _ = basic.add(1, 2);
    _ = advanced.power(2, 3);

    // 3. Consistent API structure
    _ = try math.calculate(.add, 1, 2);
    _ = try math.calculate(.divide, 10, 2);

    // 4. Clear dependencies
    const allocator = testing.allocator;
    const str = try utils.intToString(allocator, 42);
    defer allocator.free(str);

    try testing.expect(true);
}
// ANCHOR_END: module_organization_benefits

// Comprehensive test
test "comprehensive hierarchical modules" {
    const allocator = testing.allocator;

    // Use basic math
    const sum = math.add(10, 20);
    try testing.expectEqual(@as(i32, 30), sum);

    // Use advanced math
    const fact = math.advanced.factorial(5);
    try testing.expectEqual(@as(u64, 120), fact);

    // Use utils
    const str = try utils.intToString(allocator, @intCast(fact));
    defer allocator.free(str);
    try testing.expectEqualStrings("120", str);

    // Use module-level function
    const result = try math.calculate(.multiply, 6, 7);
    try testing.expectEqual(@as(i32, 42), result);

    try testing.expect(true);
}
