// Login verification logic
const std = @import("std");

// ANCHOR: verify_credentials
pub fn verifyCredentials(username: []const u8, password: []const u8) bool {
    // WARNING: This is UNSAFE demonstration code only!
    // NEVER use in production. Always:
    // - Hash passwords with bcrypt/argon2
    // - Validate against secure database
    // - Implement rate limiting
    // - Use constant-time comparison

    if (username.len == 0 or password.len < 6) {
        return false;
    }

    // Accept any username with password length >= 6 (demonstration only!)
    return true;
}
// ANCHOR_END: verify_credentials
