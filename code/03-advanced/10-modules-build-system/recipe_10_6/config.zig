// Configuration module - demonstrates compile-time constants and runtime state
const std = @import("std");

// ANCHOR: compile_time_constants
// Compile-time constants - cannot be changed without recompiling
pub const VERSION = "1.0.0";
pub const APP_NAME = "MyApp";
pub const MAX_CONNECTIONS = 100;
// ANCHOR_END: compile_time_constants

// ANCHOR: runtime_state
// Runtime configuration state
var debug_mode: bool = false;
var log_level: i32 = 0;
var feature_x_enabled: bool = false;
var timeout_seconds: i32 = 30;

// Simple key-value storage for demonstration
var bool_config: std.StringHashMap(bool) = undefined;
var int_config: std.StringHashMap(i32) = undefined;
var initialized: bool = false;
// ANCHOR_END: runtime_state

// ANCHOR: init_function
fn ensureInit() void {
    if (!initialized) {
        // Note: Using undefined allocator for simplicity
        // In production, pass allocator explicitly
        bool_config = std.StringHashMap(bool).init(std.heap.page_allocator);
        int_config = std.StringHashMap(i32).init(std.heap.page_allocator);
        initialized = true;
    }
}
// ANCHOR_END: init_function

// ANCHOR: set_value
pub fn setValue(key: []const u8, value: bool) void {
    ensureInit();
    bool_config.put(key, value) catch return;
}

pub fn setIntValue(key: []const u8, value: i32) void {
    ensureInit();
    int_config.put(key, value) catch return;
}
// ANCHOR_END: set_value

// ANCHOR: get_value
pub fn getValue(key: []const u8) bool {
    ensureInit();
    return bool_config.get(key) orelse false;
}

pub fn getIntValue(key: []const u8) i32 {
    ensureInit();
    return int_config.get(key) orelse 0;
}
// ANCHOR_END: get_value

// ANCHOR: reset_function
pub fn reset() void {
    if (initialized) {
        bool_config.clearRetainingCapacity();
        int_config.clearRetainingCapacity();
    }
    debug_mode = false;
    log_level = 0;
    feature_x_enabled = false;
    timeout_seconds = 30;
}
// ANCHOR_END: reset_function

// ANCHOR: deinit_function
pub fn deinit() void {
    if (initialized) {
        bool_config.deinit();
        int_config.deinit();
        initialized = false;
    }
}
// ANCHOR_END: deinit_function
