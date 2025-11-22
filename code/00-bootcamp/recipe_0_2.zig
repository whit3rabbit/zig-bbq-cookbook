// Recipe 0.2: Installing Zig and Verifying Your Toolchain
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to verify your Zig installation and use
// basic toolchain commands. These examples assume Zig is already installed.
//
// Installation options:
//   - Package managers (easiest): brew, apt, pacman, winget, scoop, etc.
//   - Manual download from https://ziglang.org/download/
//   - See: https://github.com/ziglang/zig/wiki/Install-Zig-from-a-Package-Manager

const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");

// ANCHOR: verify_version
// Verifying Zig Installation
//
// After installing Zig, you should verify it's working correctly.
// This test confirms that the standard library is available and working.

test "verify standard library is available" {
    // If this test runs, Zig is installed and working
    const message = "Zig toolchain is working!";
    try testing.expect(message.len > 0);
}

test "check Zig version info" {
    // You can access version information through builtin
    const version = builtin.zig_version;

    // Verify we're using a reasonable version (not ancient)
    try testing.expect(version.major >= 0);
    try testing.expect(version.minor >= 11); // At least 0.11+

    // The version is available at compile time
    if (version.major == 0 and version.minor == 15) {
        // We're on 0.15.x
        try testing.expect(true);
    }
}
// ANCHOR_END: verify_version

// ANCHOR: environment_info
// Understanding Your Zig Environment
//
// Zig provides information about the target environment through `builtin`.
// This is useful for cross-compilation and platform-specific code.

test "examine build environment" {
    // What platform are we building for?
    const os_tag = builtin.os.tag;
    const arch = builtin.cpu.arch;

    // Common OS tags: .macos, .linux, .windows
    switch (os_tag) {
        .macos, .linux, .windows => {
            // Major platforms
            try testing.expect(true);
        },
        else => {
            // Zig supports many platforms!
            try testing.expect(true);
        },
    }

    // Common architectures: .x86_64, .aarch64, .x86, .arm
    switch (arch) {
        .x86_64, .aarch64 => {
            // Modern 64-bit architectures
            try testing.expect(true);
        },
        else => {
            // Other architectures supported
            try testing.expect(true);
        },
    }
}
// ANCHOR_END: environment_info

// ANCHOR: build_modes
test "check optimization mode" {
    // Zig has different build modes
    const mode = builtin.mode;

    // Modes: .Debug, .ReleaseSafe, .ReleaseFast, .ReleaseSmall
    switch (mode) {
        .Debug => {
            // This is the default for `zig test`
            // Includes safety checks, slower but safer
            try testing.expect(true);
        },
        .ReleaseSafe => {
            // Safety checks enabled, but optimized
            try testing.expect(true);
        },
        .ReleaseFast => {
            // Maximum speed, some safety checks disabled
            try testing.expect(true);
        },
        .ReleaseSmall => {
            // Optimized for binary size
            try testing.expect(true);
        },
    }
}
// ANCHOR_END: build_modes

// ANCHOR: format_check
// Code Formatting with `zig fmt`
//
// Zig has a built-in code formatter. This test verifies that code
// follows standard formatting conventions.

test "demonstrate zig fmt expectations" {
    // Zig fmt expects:
    // - 4-space indentation
    // - Opening braces on same line
    // - Trailing commas in multi-line lists
    // - Consistent spacing

    const array = [_]i32{
        1,
        2,
        3, // Trailing comma expected
    };

    try testing.expectEqual(@as(usize, 3), array.len);

    // Function calls with multiple arguments
    const result = add(
        10,
        20, // Trailing comma
    );

    try testing.expectEqual(@as(i32, 30), result);
}

fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "zig fmt handles various constructs" {
    // Structs with multiple fields
    const Point = struct {
        x: i32,
        y: i32,
    };

    const p = Point{
        .x = 10,
        .y = 20, // Trailing comma
    };

    try testing.expectEqual(@as(i32, 10), p.x);
    try testing.expectEqual(@as(i32, 20), p.y);

    // String concatenation across lines is clear
    const long_string = "This is a long string that might " ++
        "be split across multiple lines " ++
        "for readability";

    try testing.expect(long_string.len > 0);
}
// ANCHOR_END: format_check

// Additional Notes:
//
// Common zig commands you should know:
//   zig version          - Show Zig version
//   zig env              - Show environment settings
//   zig fmt file.zig     - Format a file
//   zig fmt .            - Format all files in current directory
//   zig run file.zig     - Compile and run a program
//   zig build-exe file.zig - Compile to executable
//   zig test file.zig    - Run tests
//   zig build            - Run build.zig script
//
// Installation verification checklist:
//   1. Run `zig version` - should show version number
//   2. Run `zig env` - should show paths and settings
//   3. Run `zig fmt --check file.zig` - should check formatting
//   4. Run `zig test file.zig` - should run tests (like this file!)
