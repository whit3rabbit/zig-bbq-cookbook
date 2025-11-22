// User validation logic
// This file contains all validation functions for users

const std = @import("std");
const types = @import("user_types.zig");

// ANCHOR: validate_user
pub fn validateUser(user: *const types.User) bool {
    if (user.id == 0) return false;
    if (!validateUsername(user.username)) return false;
    if (!validateEmail(user.email)) return false;
    if (!validateAge(user.age)) return false;
    return true;
}
// ANCHOR_END: validate_user

// ANCHOR: validate_username
pub fn validateUsername(username: []const u8) bool {
    if (username.len < 3) return false;
    if (username.len > 32) return false;

    // Username must contain only alphanumeric and underscores
    for (username) |c| {
        const valid = (c >= 'a' and c <= 'z') or
            (c >= 'A' and c <= 'Z') or
            (c >= '0' and c <= '9') or
            c == '_';
        if (!valid) return false;
    }

    return true;
}
// ANCHOR_END: validate_username

// ANCHOR: validate_email
pub fn validateEmail(email: []const u8) bool {
    if (email.len < 5) return false;

    // Simple email validation: must contain @ and . after @
    var has_at = false;
    var at_index: usize = 0;

    for (email, 0..) |c, i| {
        if (c == '@') {
            if (has_at) return false; // Multiple @ symbols
            if (i == 0) return false; // @ at start
            has_at = true;
            at_index = i;
        }
    }

    if (!has_at) return false;
    if (at_index == email.len - 1) return false; // @ at end

    // Check for . after @
    const domain = email[at_index + 1 ..];
    var has_dot = false;
    for (domain) |c| {
        if (c == '.') {
            has_dot = true;
            break;
        }
    }

    return has_dot;
}
// ANCHOR_END: validate_email

// ANCHOR: validate_age
pub fn validateAge(age: u8) bool {
    return age >= 18 and age <= 120;
}
// ANCHOR_END: validate_age
