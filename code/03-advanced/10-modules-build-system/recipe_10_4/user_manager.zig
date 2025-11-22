// User Manager - Aggregator module
// This module provides a unified public API by re-exporting components

const std = @import("std");

// ANCHOR: import_components
// Import the split components
const types = @import("user_types.zig");
const validation = @import("user_validation.zig");
const storage = @import("user_storage.zig");
// ANCHOR_END: import_components

// ANCHOR: reexport_types
// Re-export types for public API
pub const User = types.User;
pub const UserError = types.UserError;
// ANCHOR_END: reexport_types

// ANCHOR: reexport_validation
// Re-export validation functions
pub const validateUser = validation.validateUser;
pub const validateUsername = validation.validateUsername;
pub const validateEmail = validation.validateEmail;
pub const validateAge = validation.validateAge;
// ANCHOR_END: reexport_validation

// ANCHOR: manager_wrapper
// Provide a convenience wrapper around storage
const Storage = storage.Storage;

pub fn init(allocator: std.mem.Allocator) !Storage {
    return Storage.init(allocator);
}

pub const deinit = Storage.deinit;
pub const addUser = Storage.addUser;
pub const findUser = Storage.findUser;
pub const removeUser = Storage.removeUser;
pub const count = Storage.count;
pub const clear = Storage.clear;
// ANCHOR_END: manager_wrapper
