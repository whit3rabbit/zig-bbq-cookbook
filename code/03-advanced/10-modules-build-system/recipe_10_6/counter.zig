// Counter module - demonstrates module state and caching
const std = @import("std");

// ANCHOR: module_state
// Module-level state (shared across all imports)
// NOTE: Global state has limitations - see recipe for alternatives
var count: usize = 0;
// ANCHOR_END: module_state

// ANCHOR: state_functions
pub fn increment() void {
    count += 1;
}

pub fn decrement() void {
    if (count > 0) {
        count -= 1;
    }
}

pub fn getValue() usize {
    return count;
}

pub fn reset() void {
    count = 0;
}
// ANCHOR_END: state_functions

// ANCHOR: setValue_function
pub fn setValue(value: usize) void {
    count = value;
}
// ANCHOR_END: setValue_function
