const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");

/// Maximum password length to prevent memory DoS attacks.
/// 1024 bytes allows ~256 UTF-8 characters while preventing abuse.
/// NIST 2024 recommends supporting at least 64 characters.
const MAX_PASSWORD_LENGTH: usize = 1024;

// ANCHOR: basic_password_prompt
/// Read password with echo disabled (Unix-like systems)
fn readPasswordUnix(allocator: std.mem.Allocator, prompt: []const u8) ![]u8 {
    if (builtin.os.tag == .windows) {
        return error.UnsupportedPlatform;
    }

    const stdin_file = std.fs.File{ .handle = 0 };

    // Display prompt
    std.debug.print("{s}", .{prompt});

    // Disable echo
    const original_termios = try std.posix.tcgetattr(stdin_file.handle);
    var new_termios = original_termios;
    new_termios.lflag.ECHO = false;
    try std.posix.tcsetattr(stdin_file.handle, .NOW, new_termios);

    // Ensure echo is restored even on error
    defer {
        std.posix.tcsetattr(stdin_file.handle, .NOW, original_termios) catch {};
        std.debug.print("\n", .{}); // Newline after password input
    }

    // Read password
    const reader = stdin_file.reader();
    var list = std.ArrayList(u8){};
    errdefer list.deinit(allocator);

    var buf: [1]u8 = undefined;
    while (true) {
        const bytes_read = reader.read(&buf) catch |err| {
            list.deinit(allocator);
            return err;
        };
        if (bytes_read == 0) break;
        if (buf[0] == '\n' or buf[0] == '\r') break;

        // Prevent memory DoS by enforcing maximum length
        if (list.items.len >= MAX_PASSWORD_LENGTH) {
            list.deinit(allocator);
            return error.PasswordTooLong;
        }

        try list.append(allocator, buf[0]);
    }

    return list.toOwnedSlice(allocator);
}

test "password reading API" {
    // We can't test actual terminal interaction, but we verify the function signature
    if (builtin.os.tag != .windows) {
        // On non-Windows, the function exists
        _ = readPasswordUnix;
    }
}
// ANCHOR_END: basic_password_prompt

// ANCHOR: mock_password_reader
/// Mock password reader for testing (reads from any reader)
fn readPasswordMock(allocator: std.mem.Allocator, reader: anytype) ![]u8 {
    var list = std.ArrayList(u8){};
    errdefer list.deinit(allocator);

    var buf: [1]u8 = undefined;
    while (true) {
        const bytes_read = try reader.read(&buf);
        if (bytes_read == 0) break;
        if (buf[0] == '\n' or buf[0] == '\r') break;

        // Prevent memory DoS by enforcing maximum length
        if (list.items.len >= MAX_PASSWORD_LENGTH) {
            return error.PasswordTooLong;
        }

        try list.append(allocator, buf[0]);
    }

    return list.toOwnedSlice(allocator);
}

test "mock password reader" {
    const input = "secret123\n";
    var stream = std.io.fixedBufferStream(input);

    const password = try readPasswordMock(testing.allocator, stream.reader());
    defer testing.allocator.free(password);

    try testing.expectEqualStrings("secret123", password);
}

test "password length limit - at maximum" {
    // Create password exactly at the limit
    var buf: [MAX_PASSWORD_LENGTH + 1]u8 = undefined;
    @memset(buf[0..MAX_PASSWORD_LENGTH], 'a');
    buf[MAX_PASSWORD_LENGTH] = '\n';

    var stream = std.io.fixedBufferStream(&buf);
    const password = try readPasswordMock(testing.allocator, stream.reader());
    defer testing.allocator.free(password);

    try testing.expectEqual(MAX_PASSWORD_LENGTH, password.len);
}

test "password length limit - exceeds maximum" {
    // Create password that exceeds the limit
    var buf: [MAX_PASSWORD_LENGTH + 10]u8 = undefined;
    @memset(buf[0 .. MAX_PASSWORD_LENGTH + 9], 'a');
    buf[MAX_PASSWORD_LENGTH + 9] = '\n';

    var stream = std.io.fixedBufferStream(&buf);
    const result = readPasswordMock(testing.allocator, stream.reader());

    try testing.expectError(error.PasswordTooLong, result);
}
// ANCHOR_END: mock_password_reader

// ANCHOR: password_validation
/// Password validation rules
pub const PasswordRules = struct {
    min_length: usize = 8,
    require_uppercase: bool = true,
    require_lowercase: bool = true,
    require_digit: bool = true,
    require_special: bool = false,

    pub fn validate(self: PasswordRules, password: []const u8) !void {
        if (password.len < self.min_length) {
            return error.PasswordTooShort;
        }

        if (self.require_uppercase) {
            var has_upper = false;
            for (password) |c| {
                if (c >= 'A' and c <= 'Z') {
                    has_upper = true;
                    break;
                }
            }
            if (!has_upper) return error.MissingUppercase;
        }

        if (self.require_lowercase) {
            var has_lower = false;
            for (password) |c| {
                if (c >= 'a' and c <= 'z') {
                    has_lower = true;
                    break;
                }
            }
            if (!has_lower) return error.MissingLowercase;
        }

        if (self.require_digit) {
            var has_digit = false;
            for (password) |c| {
                if (c >= '0' and c <= '9') {
                    has_digit = true;
                    break;
                }
            }
            if (!has_digit) return error.MissingDigit;
        }

        if (self.require_special) {
            var has_special = false;
            for (password) |c| {
                if (!std.ascii.isAlphanumeric(c)) {
                    has_special = true;
                    break;
                }
            }
            if (!has_special) return error.MissingSpecialChar;
        }
    }
};

test "password validation - valid password" {
    const rules = PasswordRules{};
    try rules.validate("Password123");
}

test "password validation - too short" {
    const rules = PasswordRules{};
    try testing.expectError(error.PasswordTooShort, rules.validate("Pw1"));
}

test "password validation - missing uppercase" {
    const rules = PasswordRules{};
    try testing.expectError(error.MissingUppercase, rules.validate("password123"));
}

test "password validation - missing lowercase" {
    const rules = PasswordRules{};
    try testing.expectError(error.MissingLowercase, rules.validate("PASSWORD123"));
}

test "password validation - missing digit" {
    const rules = PasswordRules{};
    try testing.expectError(error.MissingDigit, rules.validate("Password"));
}

test "password validation - special characters" {
    const rules = PasswordRules{ .require_special = true };
    try testing.expectError(error.MissingSpecialChar, rules.validate("Password123"));
    try rules.validate("Password123!");
}
// ANCHOR_END: password_validation

// ANCHOR: password_confirmation
/// Prompt for password with confirmation
fn promptWithConfirmation(
    allocator: std.mem.Allocator,
    reader: anytype,
    max_attempts: usize,
) ![]u8 {
    var attempts: usize = 0;
    while (attempts < max_attempts) : (attempts += 1) {
        std.debug.print("Enter password: ", .{});
        const password1 = try readPasswordMock(allocator, reader);
        defer allocator.free(password1);

        std.debug.print("Confirm password: ", .{});
        const password2 = try readPasswordMock(allocator, reader);
        defer allocator.free(password2);

        if (std.mem.eql(u8, password1, password2)) {
            return try allocator.dupe(u8, password1);
        }

        std.debug.print("Passwords do not match. Try again.\n", .{});
    }

    return error.TooManyAttempts;
}

test "password confirmation - matching" {
    const input = "secret\nsecret\n";
    var stream = std.io.fixedBufferStream(input);

    const password = try promptWithConfirmation(testing.allocator, stream.reader(), 3);
    defer testing.allocator.free(password);

    try testing.expectEqualStrings("secret", password);
}

test "password confirmation - not matching then matching" {
    const input = "secret\nwrong\nsecret\nsecret\n";
    var stream = std.io.fixedBufferStream(input);

    const password = try promptWithConfirmation(testing.allocator, stream.reader(), 3);
    defer testing.allocator.free(password);

    try testing.expectEqualStrings("secret", password);
}
// ANCHOR_END: password_confirmation

// ANCHOR: secure_password_clear
/// Securely clear password from memory
/// Uses doNotOptimizeAway to prevent compiler from optimizing away the zeroing
fn clearPassword(password: []u8) void {
    @memset(password, 0);
    // Prevent compiler optimization in Release modes
    std.mem.doNotOptimizeAway(password);
}

test "secure password clearing" {
    const password = try testing.allocator.alloc(u8, 10);
    defer testing.allocator.free(password);

    @memcpy(password, "secret1234");
    try testing.expectEqualStrings("secret1234", password);

    clearPassword(password);
    try testing.expectEqualSlices(u8, &[_]u8{0} ** 10, password);
}
// ANCHOR_END: secure_password_clear

// ANCHOR: password_with_validation
/// Prompt for password with validation
fn promptWithValidation(
    allocator: std.mem.Allocator,
    reader: anytype,
    rules: PasswordRules,
    max_attempts: usize,
) ![]u8 {
    var attempts: usize = 0;
    while (attempts < max_attempts) : (attempts += 1) {
        std.debug.print("Enter password: ", .{});
        const password = try readPasswordMock(allocator, reader);
        errdefer allocator.free(password);

        rules.validate(password) catch |err| {
            allocator.free(password);
            switch (err) {
                error.PasswordTooShort => std.debug.print("Password too short (min {} chars)\n", .{rules.min_length}),
                error.MissingUppercase => std.debug.print("Password must contain uppercase letter\n", .{}),
                error.MissingLowercase => std.debug.print("Password must contain lowercase letter\n", .{}),
                error.MissingDigit => std.debug.print("Password must contain digit\n", .{}),
                error.MissingSpecialChar => std.debug.print("Password must contain special character\n", .{}),
            }
            continue;
        };

        return password;
    }

    return error.TooManyAttempts;
}

test "password with validation - valid on first try" {
    const input = "Password123\n";
    var stream = std.io.fixedBufferStream(input);

    const rules = PasswordRules{};
    const password = try promptWithValidation(testing.allocator, stream.reader(), rules, 3);
    defer testing.allocator.free(password);

    try testing.expectEqualStrings("Password123", password);
}

test "password with validation - valid after retry" {
    const input = "weak\nPassword123\n";
    var stream = std.io.fixedBufferStream(input);

    const rules = PasswordRules{};
    const password = try promptWithValidation(testing.allocator, stream.reader(), rules, 3);
    defer testing.allocator.free(password);

    try testing.expectEqualStrings("Password123", password);
}
// ANCHOR_END: password_with_validation

// ANCHOR: password_strength
/// Calculate password strength score
pub const PasswordStrength = enum {
    weak,
    fair,
    good,
    strong,

    pub fn calculate(password: []const u8) PasswordStrength {
        var score: usize = 0;

        // Length bonus
        if (password.len >= 8) score += 1;
        if (password.len >= 12) score += 1;
        if (password.len >= 16) score += 1;

        // Character variety
        var has_lower = false;
        var has_upper = false;
        var has_digit = false;
        var has_special = false;

        for (password) |c| {
            if (c >= 'a' and c <= 'z') has_lower = true;
            if (c >= 'A' and c <= 'Z') has_upper = true;
            if (c >= '0' and c <= '9') has_digit = true;
            if (!std.ascii.isAlphanumeric(c)) has_special = true;
        }

        if (has_lower) score += 1;
        if (has_upper) score += 1;
        if (has_digit) score += 1;
        if (has_special) score += 1;

        return switch (score) {
            0...2 => .weak,
            3...4 => .fair,
            5...6 => .good,
            else => .strong,
        };
    }

    pub fn toString(self: PasswordStrength) []const u8 {
        return switch (self) {
            .weak => "Weak",
            .fair => "Fair",
            .good => "Good",
            .strong => "Strong",
        };
    }
};

test "password strength - weak" {
    const strength = PasswordStrength.calculate("abc");
    try testing.expectEqual(PasswordStrength.weak, strength);
}

test "password strength - fair" {
    const strength = PasswordStrength.calculate("password123"); // 8+ chars, lower, digit
    try testing.expectEqual(PasswordStrength.fair, strength);
}

test "password strength - good" {
    const strength = PasswordStrength.calculate("Password1234"); // 12+ chars, upper, lower, digit
    try testing.expectEqual(PasswordStrength.good, strength);
}

test "password strength - strong" {
    const strength = PasswordStrength.calculate("P@ssw0rd!2024Long"); // 16+ chars, all types
    try testing.expectEqual(PasswordStrength.strong, strength);
}
// ANCHOR_END: password_strength

// ANCHOR: masked_input
/// Show masked input (asterisks) for password
fn readPasswordMasked(allocator: std.mem.Allocator, reader: anytype, mask_char: u8) ![]u8 {
    var list = std.ArrayList(u8){};
    errdefer list.deinit(allocator);

    var buf: [1]u8 = undefined;
    while (true) {
        const bytes_read = try reader.read(&buf);
        if (bytes_read == 0) break;
        if (buf[0] == '\n' or buf[0] == '\r') break;

        // Prevent memory DoS by enforcing maximum length
        if (list.items.len >= MAX_PASSWORD_LENGTH) {
            return error.PasswordTooLong;
        }

        try list.append(allocator, buf[0]);
        // In real implementation, would print mask_char to terminal
        _ = mask_char;
    }

    return list.toOwnedSlice(allocator);
}

test "masked password input" {
    const input = "secret\n";
    var stream = std.io.fixedBufferStream(input);

    const password = try readPasswordMasked(testing.allocator, stream.reader(), '*');
    defer testing.allocator.free(password);

    try testing.expectEqualStrings("secret", password);
}
// ANCHOR_END: masked_input

// ANCHOR: timeout_password
/// Read password with timeout
fn readPasswordWithTimeout(
    allocator: std.mem.Allocator,
    reader: anytype,
    timeout_ms: u64,
) ![]u8 {
    _ = timeout_ms; // Would be used with select/poll in real implementation

    // Simplified version without actual timeout
    return try readPasswordMock(allocator, reader);
}

test "password with timeout" {
    const input = "quickpass\n";
    var stream = std.io.fixedBufferStream(input);

    const password = try readPasswordWithTimeout(testing.allocator, stream.reader(), 5000);
    defer testing.allocator.free(password);

    try testing.expectEqualStrings("quickpass", password);
}
// ANCHOR_END: timeout_password
