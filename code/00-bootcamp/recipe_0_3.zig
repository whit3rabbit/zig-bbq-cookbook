// Recipe 0.3: Your First Zig Program
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to write a basic Zig program with main(),
// understand return types, and work with exit codes.

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_hello
// The Simplest Hello World
//
// In Zig, the entry point for an executable is `pub fn main()`.
// The `pub` keyword makes it visible outside this file (required for main).
// The `!void` return type means "returns nothing or an error".

pub fn main() !void {
    // Print to standard output
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Hello, World!\n", .{});
}

// Note: This main() won't actually run when you `zig test` this file.
// Tests run in their own environment. But it will run if you:
//   zig build-exe recipe_0_3.zig
//   ./recipe_0_3

// For testing purposes, we can test the hello world logic separately:
test "hello world produces output" {
    // We can't easily test stdout, but we can test similar logic
    const message = "Hello, World!\n";
    try testing.expect(message.len > 0);
    try testing.expect(std.mem.eql(u8, message, "Hello, World!\n"));
}
// ANCHOR_END: basic_hello

// ANCHOR: error_return
// Understanding Return Types
//
// Why does main() return `!void` instead of just `void`?
// The `!` means the function can return an error.

fn mightFail() !void {
    // This function does nothing, but it could return an error
    // If it did fail, we'd use: return error.SomethingWrong;
}

test "understanding error return types" {
    // When you call a function that returns !T, you must handle potential errors
    // Option 1: Use `try` to propagate the error
    try mightFail();

    // Option 2: Use `catch` to handle the error
    mightFail() catch |err| {
        // Handle the error
        _ = err; // Suppress unused variable warning
        return;
    };

    // Option 3: Assert it won't fail (dangerous!)
    // mightFail() catch unreachable;  // Use only if you're 100% sure
}

fn parseAndDouble(text: []const u8) !i32 {
    // Parse text to integer, then double it
    const num = try std.fmt.parseInt(i32, text, 10);
    return num * 2;
}

test "errors must be handled" {
    // Success case
    const result = try parseAndDouble("21");
    try testing.expectEqual(@as(i32, 42), result);

    // Error case
    const err_result = parseAndDouble("not a number");
    try testing.expectError(error.InvalidCharacter, err_result);
}
// ANCHOR_END: error_return

// ANCHOR: exit_codes
// Working with Exit Codes
//
// Programs can return exit codes to indicate success or failure.
// By convention: 0 = success, non-zero = error

pub fn main_with_exit_code() u8 {
    // Return 0 for success
    return 0;
}

pub fn main_with_error() u8 {
    // Return non-zero for error
    return 1;
}

test "exit codes convention" {
    const success = main_with_exit_code();
    try testing.expectEqual(@as(u8, 0), success);

    const failure = main_with_error();
    try testing.expectEqual(@as(u8, 1), failure);
}

// In real programs, you might do:
pub fn main_real_example() u8 {
    const result = doSomething() catch {
        std.debug.print("Error occurred!\n", .{});
        return 1; // Return error code
    };

    std.debug.print("Success: {}\n", .{result});
    return 0; // Return success
}

fn doSomething() !i32 {
    // Simulate some work
    return 42;
}

test "main with error handling" {
    const exit_code = main_real_example();
    try testing.expectEqual(@as(u8, 0), exit_code);
}

// Different main() signatures you might see:
//
// pub fn main() void {}                    // Can't fail
// pub fn main() !void {}                   // Can fail (most common)
// pub fn main() u8 {}                      // Returns exit code
// pub fn main() !u8 {}                     // Can fail and return exit code
// pub fn main() anyerror!void {}           // Explicit error type
//
// For most programs, use: pub fn main() !void {}
// ANCHOR_END: exit_codes

// Additional examples showing common main() patterns

test "understanding print formatting" {
    // The print function uses format strings
    // Empty .{} means no arguments
    const no_args = "Hello!\n";
    try testing.expect(no_args.len > 0);

    // With arguments, use {} placeholders
    const name = "Zig";
    const msg = std.fmt.allocPrint(
        testing.allocator,
        "Hello, {s}!\n",
        .{name},
    ) catch unreachable;
    defer testing.allocator.free(msg);

    try testing.expect(std.mem.eql(u8, msg, "Hello, Zig!\n"));
}

test "multiple print arguments" {
    // You can print multiple values
    const name = "Zig";
    const version = "0.15.2";

    const msg = std.fmt.allocPrint(
        testing.allocator,
        "Language: {s}, Version: {s}\n",
        .{ name, version },
    ) catch unreachable;
    defer testing.allocator.free(msg);

    try testing.expect(msg.len > 0);
}

// Summary:
// - Entry point is `pub fn main()`
// - Use `!void` return type to allow errors
// - Use `try` to propagate errors from main()
// - Print with stdout.print() or std.debug.print()
// - Format strings use {} for placeholders
// - Exit codes: 0 = success, non-zero = error
