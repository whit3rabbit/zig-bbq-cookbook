// Authentication feature module
const std = @import("std");
const login = @import("auth/login.zig");

// ANCHOR: auth_types
pub const User = struct {
    id: u32,
    username: []const u8,
};
// ANCHOR_END: auth_types

// ANCHOR: auth_state
// Simple in-memory auth state (for demonstration)
// WARNING: Global state is NOT thread-safe and for demonstration only.
// Production code should use explicit context structs passed to functions.
//
// Production alternative pattern:
//   const AuthContext = struct {
//       current_user: ?User = null,
//       mutex: std.Thread.Mutex = .{},
//       pub fn authenticate(self: *AuthContext, username: []const u8, password: []const u8) bool { ... }
//   };
// Then pass *AuthContext to functions instead of using global state.
var current_user: ?User = null;
var logged_in: bool = false;
// ANCHOR_END: auth_state

// ANCHOR: authenticate
pub fn authenticate(username: []const u8, password: []const u8) bool {
    // Use login module for authentication logic
    const result = login.verifyCredentials(username, password);

    if (result) {
        current_user = User{
            .id = 1,
            .username = username,
        };
        logged_in = true;
    }

    return result;
}
// ANCHOR_END: authenticate

// ANCHOR: logout
pub fn logout() void {
    current_user = null;
    logged_in = false;
}
// ANCHOR_END: logout

// ANCHOR: is_logged_in
pub fn isLoggedIn() bool {
    return logged_in;
}
// ANCHOR_END: is_logged_in

// ANCHOR: get_current_user
pub fn getCurrentUser() User {
    return current_user orelse User{ .id = 0, .username = "guest" };
}
// ANCHOR_END: get_current_user
