// Math module - aggregates basic and advanced math operations
// This is a parent module that imports and re-exports child modules

const std = @import("std");

// Import child modules
pub const basic = @import("math/basic.zig");
pub const advanced = @import("math/advanced.zig");

// Re-export commonly used functions at this level
pub const add = basic.add;
pub const subtract = basic.subtract;
pub const multiply = basic.multiply;
pub const divide = basic.divide;

// Module-level function that uses child modules
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
