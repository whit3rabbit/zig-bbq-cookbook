// User data structures and types
// This file contains all user-related data structures

const std = @import("std");

// ANCHOR: user_struct
pub const User = struct {
    id: u32,
    username: []const u8,
    email: []const u8,
    age: u8,
};
// ANCHOR_END: user_struct

// ANCHOR: user_errors
pub const UserError = error{
    InvalidUser,
    UserNotFound,
    DuplicateUser,
};
// ANCHOR_END: user_errors
