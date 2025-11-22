// Error Handling Patterns
// Target Zig Version: 0.15.2
//
// This file demonstrates all error handling patterns covered in the foundation guide.
// Run: zig test code/01-foundation/error_handling.zig

const std = @import("std");
const testing = std.testing;

// ==============================================================================
// Basic Error Sets
// ==============================================================================

// ANCHOR: error_sets
const FileError = error{
    FileNotFound,
    PermissionDenied,
    DiskFull,
};

const DatabaseError = error{
    ConnectionFailed,
    QueryTimeout,
    InvalidQuery,
    RecordNotFound,
};

const ValidationError = error{
    InvalidEmail,
    PasswordTooShort,
    UsernameTaken,
};
// ANCHOR_END: error_sets

test "error sets - basic error return" {
    const result = divide(10, 2);
    try testing.expectEqual(@as(i32, 5), try result);

    const error_result = divide(10, 0);
    try testing.expectError(error.DivisionByZero, error_result);
}

// ANCHOR: divide_function
fn divide(a: i32, b: i32) !i32 {
    if (b == 0) return error.DivisionByZero;
    return @divTrunc(a, b);
}
// ANCHOR_END: divide_function

// ==============================================================================
// Error Propagation with `try`
// ==============================================================================

// ANCHOR: try_propagation
fn validateAge(age: i32) !void {
    if (age < 0) return error.InvalidAge;
    if (age > 150) return error.InvalidAge;
}

fn validateName(name: []const u8) !void {
    if (name.len == 0) return error.EmptyName;
    if (name.len > 100) return error.NameTooLong;
}

fn validatePerson(name: []const u8, age: i32) !void {
    // try propagates errors from these functions
    try validateName(name);
    try validateAge(age);
}
// ANCHOR_END: try_propagation

test "error propagation - try keyword" {
    // Valid person
    try validatePerson("Alice", 30);

    // Invalid name
    try testing.expectError(error.EmptyName, validatePerson("", 30));

    // Invalid age
    try testing.expectError(error.InvalidAge, validatePerson("Bob", -5));
}

// ==============================================================================
// Error Handling with `catch`
// ==============================================================================

// ANCHOR: catch_handling
fn getUserNameOrDefault(user_id: u32) []const u8 {
    return lookupUserName(user_id) catch "Guest";
}

fn lookupUserName(user_id: u32) ![]const u8 {
    if (user_id == 0) return error.InvalidUserId;
    if (user_id == 1) return "Alice";
    if (user_id == 2) return "Bob";
    return error.UserNotFound;
}
// ANCHOR_END: catch_handling

test "error handling - catch with fallback" {
    try testing.expectEqualStrings("Alice", getUserNameOrDefault(1));
    try testing.expectEqualStrings("Bob", getUserNameOrDefault(2));
    try testing.expectEqualStrings("Guest", getUserNameOrDefault(999));
}

// ==============================================================================
// Conditional Error Handling with `if`
// ==============================================================================

// ANCHOR: if_expression
const Config = struct {
    port: u16,
    host: []const u8,

    fn default() Config {
        return .{
            .port = 8080,
            .host = "localhost",
        };
    }
};

fn loadConfigFromFile(path: []const u8) !Config {
    _ = path;
    return error.FileNotFound;
}

fn loadConfig(path: []const u8) !Config {
    if (loadConfigFromFile(path)) |config| {
        // Success path
        return config;
    } else |err| switch (err) {
        error.FileNotFound => {
            // Use default config when file doesn't exist
            return Config.default();
        },
        else => return err,
    }
}
// ANCHOR_END: if_expression

test "conditional error handling - if expression" {
    const config = try loadConfig("config.json");
    try testing.expectEqual(@as(u16, 8080), config.port);
    try testing.expectEqualStrings("localhost", config.host);
}

// ==============================================================================
// Error Cleanup with `errdefer`
// ==============================================================================

// ANCHOR: errdefer_cleanup
const User = struct {
    name: []u8,
    id: u32,
};

// NOTE: Global mutable state like this is used here only for demonstration.
// In real code, avoid globals - they make testing harder and aren't thread-safe.
// Instead, pass state explicitly (e.g., as a Counter struct parameter).
var next_user_id: u32 = 1;

fn generateUserId(should_fail: bool) !u32 {
    if (should_fail) return error.IdGenerationFailed;
    const id = next_user_id;
    next_user_id += 1;
    return id;
}

fn createUser(allocator: std.mem.Allocator, name: []const u8, should_fail: bool) !User {
    // Allocate memory for name
    const owned_name = try allocator.dupe(u8, name);
    // If anything below returns an error, clean up the name
    errdefer allocator.free(owned_name);

    // This might fail
    const id = try generateUserId(should_fail);

    // Success! The errdefer won't run
    return User{
        .name = owned_name,
        .id = id,
    };
}
// ANCHOR_END: errdefer_cleanup

test "errdefer cleans up on error" {
    const allocator = testing.allocator;

    // Success case - no leak
    const user1 = try createUser(allocator, "Alice", false);
    defer allocator.free(user1.name);
    try testing.expectEqualStrings("Alice", user1.name);

    // Error case - errdefer should clean up the name allocation
    try testing.expectError(error.IdGenerationFailed, createUser(allocator, "Bob", true));
    // If errdefer didn't work, this would leak memory and the test allocator would catch it
}

// ==============================================================================
// Combining Error Sets
// ==============================================================================

// ANCHOR: combined_errors
const Account = struct {
    email: []const u8,
    id: u32,
};

// Mock database insert
fn dbInsertUser(email: []const u8, password: []const u8) DatabaseError!Account {
    _ = password;
    if (email.len == 0) return error.InvalidQuery;
    return Account{ .email = email, .id = 1 };
}

fn createAccount(email: []const u8, password: []const u8) (DatabaseError || ValidationError)!Account {
    if (email.len == 0) return error.InvalidEmail;
    if (password.len < 8) return error.PasswordTooShort;

    // This can return DatabaseError
    return try dbInsertUser(email, password);
}
// ANCHOR_END: combined_errors

test "combined error sets" {
    // Success
    const account = try createAccount("alice@example.com", "password123");
    try testing.expectEqualStrings("alice@example.com", account.email);

    // ValidationError
    try testing.expectError(error.InvalidEmail, createAccount("", "password123"));
    try testing.expectError(error.PasswordTooShort, createAccount("alice@example.com", "short"));
}

// ==============================================================================
// Error to Optional Conversion
// ==============================================================================

// ANCHOR: error_to_optional
fn findUser(id: u32) ?User {
    // Discard the specific error, just return null on any error
    return lookupUser(id) catch null;
}

fn lookupUser(id: u32) !User {
    if (id == 1) return User{ .name = &[_]u8{}, .id = 1 };
    return error.UserNotFound;
}
// ANCHOR_END: error_to_optional

test "error to optional conversion" {
    const user1 = findUser(1);
    try testing.expect(user1 != null);
    try testing.expectEqual(@as(u32, 1), user1.?.id);

    const user2 = findUser(999);
    try testing.expectEqual(@as(?User, null), user2);
}

// ==============================================================================
// Multiple Error Handling Strategies
// ==============================================================================

// ANCHOR: switch_errors
fn processNumber(text: []const u8, fallback: i32) i32 {
    return parseNumber(text) catch |err| switch (err) {
        error.EmptyString => 0,
        error.InvalidCharacter => fallback,
    };
}

fn parseNumber(text: []const u8) !i32 {
    if (text.len == 0) return error.EmptyString;
    if (text[0] < '0' or text[0] > '9') return error.InvalidCharacter;
    // Simplified parsing
    return @as(i32, text[0] - '0');
}
// ANCHOR_END: switch_errors

test "switch on error" {
    try testing.expectEqual(@as(i32, 5), processNumber("5", 100));
    try testing.expectEqual(@as(i32, 0), processNumber("", 100));
    try testing.expectEqual(@as(i32, 100), processNumber("abc", 100));
}

// ==============================================================================
// defer vs errdefer
// ==============================================================================

// ANCHOR: defer_vs_errdefer
fn processWithBothDefers(allocator: std.mem.Allocator, should_fail: bool) ![]u8 {
    const buffer = try allocator.alloc(u8, 100);
    defer allocator.free(buffer); // This always runs and frees buffer

    const temp = try allocator.alloc(u8, 50);
    errdefer allocator.free(temp); // Only runs on error

    if (should_fail) {
        return error.ProcessingFailed;
    }

    // Success - caller owns temp, buffer will be freed by defer
    return temp;
}
// ANCHOR_END: defer_vs_errdefer

test "defer vs errdefer" {
    const allocator = testing.allocator;

    // Success - we get temp back, errdefer didn't run
    const result = try processWithBothDefers(allocator, false);
    defer allocator.free(result);
    try testing.expectEqual(@as(usize, 50), result.len);

    // Error - errdefer ran and cleaned up temp
    try testing.expectError(error.ProcessingFailed, processWithBothDefers(allocator, true));
}

// ==============================================================================
// Error Return Traces
// ==============================================================================

// ANCHOR: error_traces
fn level3(should_fail: bool) !void {
    if (should_fail) return error.SomethingWrong;
}

fn level2(should_fail: bool) !void {
    try level3(should_fail);
}

fn level1(should_fail: bool) !void {
    try level2(should_fail);
}
// ANCHOR_END: error_traces

test "error return trace propagation" {
    // Success
    try level1(false);

    // Error - the error propagates through all three levels
    try testing.expectError(error.SomethingWrong, level1(true));
}

// ==============================================================================
// Inferred Error Sets
// ==============================================================================

// ANCHOR: inferred_errors
// Zig infers this can return error{OutOfBounds, Negative}
fn checkValue(val: i32) !void {
    if (val < 0) return error.Negative;
    if (val > 100) return error.OutOfBounds;
}
// ANCHOR_END: inferred_errors

test "inferred error sets" {
    try checkValue(50);
    try testing.expectError(error.Negative, checkValue(-1));
    try testing.expectError(error.OutOfBounds, checkValue(101));
}
