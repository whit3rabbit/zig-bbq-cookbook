# Your First Zig Program

## Problem

You have Zig installed and you're ready to write your first program. What's the minimal code to get something running? How do you structure a Zig program?

## Solution

Create a file called `hello.zig`:

```zig
{{#include ../../code/00-bootcamp/recipe_0_3.zig:basic_hello}}
```

Run it:
```bash
zig run hello.zig
```

You should see:
```
Hello, World!
```

That's it! You've written your first Zig program.

## Discussion

### Breaking Down the Code

Let's understand each part:

```zig
const std = @import("std");
```

This imports the standard library and binds it to the name `std`. The `@import` function is built into the compiler. You'll use `std` to access standard library features like printing, file I/O, and data structures.

```zig
pub fn main() !void {
```

This is the entry point for your program. Let's break it down:

- `pub` - Makes this function public (visible outside this file). The compiler looks for a public `main()`.
- `fn` - Declares a function
- `main` - The name of the function. This is special - it's where your program starts.
- `!void` - The return type. More on this below.

```zig
const stdout = std.io.getStdOut().writer();
```

This gets a writer for standard output. In Zig, you need to explicitly get handles to stdout/stderr/stdin. Nothing is magically available.

```zig
try stdout.print("Hello, World!\n", .{});
```

This prints to stdout. The `try` keyword means "if this fails, return the error from main()". The `.{}` is an empty tuple (we're not formatting any variables).

### Why `!void` and Not Just `void`?

The `!` in `!void` means this function returns "void or an error". This is called an error union type.

```zig
pub fn main() !void {
    // This can fail (printing might fail!)
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Hello, World!\n", .{});
}
```

Why can printing fail? What if stdout is closed? What if the disk is full (when redirecting to a file)? Zig makes you think about these cases.

The `try` keyword is shorthand for:
```zig
stdout.print("Hello, World!\n", .{}) catch |err| return err;
```

If printing fails, `try` returns the error from `main()`, and your program exits.

Here's what different return types mean:

```zig
// Can't fail
pub fn main() void {}

// Can fail (most common for real programs)
pub fn main() !void {}

// Returns exit code
pub fn main() u8 {
    return 0; // Success
}

// Can fail AND return exit code
pub fn main() !u8 {}
```

For most programs, use `!void`. It's the convention.

### Understanding Error Handling

Errors in Zig are values, not exceptions. Let's see this in action:

```zig
{{#include ../../code/00-bootcamp/recipe_0_3.zig:error_return}}
```

The `!i32` return type means "returns an i32 or an error". When you call this function, you must handle the possibility of an error.

### Exit Codes

Programs can return exit codes to the shell. By convention:
- `0` = success
- Non-zero = error (1, 2, etc.)

```zig
{{#include ../../code/00-bootcamp/recipe_0_3.zig:exit_codes}}
```

You can check the exit code in your shell:
```bash
./myprogram
echo $?  # Shows the exit code
```

### Print Formatting

The `print()` function uses format strings:

```zig
// No arguments - just a plain string
try stdout.print("Hello!\n", .{});

// With arguments - use {} placeholders
const name = "Zig";
try stdout.print("Hello, {s}!\n", .{name});

// Multiple arguments
const lang = "Zig";
const version = "0.15.2";
try stdout.print("Language: {s}, Version: {s}\n", .{ lang, version });
```

Common format specifiers:
- `{s}` - String
- `{}` - Any type (auto-detect)
- `{d}` - Decimal integer
- `{x}` - Hexadecimal
- `{b}` - Binary
- `{.2}` - Float with 2 decimal places

### Building vs Running

Zig gives you multiple ways to work with your program:

```bash
# Compile and run immediately (for development)
zig run hello.zig

# Build an executable (for distribution)
zig build-exe hello.zig
./hello

# Build with optimization
zig build-exe -O ReleaseFast hello.zig

# Cross-compile for another platform
zig build-exe -target x86_64-windows hello.zig
```

For learning and quick iteration, use `zig run`. For production, use `zig build-exe` with optimization flags.

### Debug vs Release Printing

Zig has two main ways to print:

```zig
// For stdout/stderr (production)
const stdout = std.io.getStdOut().writer();
try stdout.print("Output: {}\n", .{value});

// For debugging (simpler, but not for production)
std.debug.print("Debug: {}\n", .{value});
```

`std.debug.print()` is easier (no `try` needed, no getting a writer), but it's meant for debugging. For real output, use `stdout.print()`.

### Common Beginner Mistakes

**Forgetting `pub` on main():**
```zig
fn main() !void {  // Missing pub!
    // ...
}
```
Error: "no entry point found"

**Forgetting `try` on fallible functions:**
```zig
pub fn main() !void {
    stdout.print("Hello!\n", .{});  // Missing try!
}
```
Error: "error is ignored"

**Wrong return type:**
```zig
pub fn main() void {  // Should be !void
    try stdout.print("Hello!\n", .{});  // Can't use try if main doesn't return !
}
```
Error: "`try` in function with non-error return type"

### Testing vs Running

When you write tests, they run in a test environment:

```zig
test "hello world produces output" {
    const message = "Hello, World!\n";
    try testing.expect(message.len > 0);
}
```

Run tests with:
```bash
zig test hello.zig
```

Tests don't execute `main()`. They run the test blocks instead. This is why we have separate test functions that check the logic.

## See Also

- Recipe 0.4: Variables, Constants, and Type Inference - Working with data
- Recipe 0.11: Optionals, Errors, and Resource Cleanup - Deep dive into error handling
- Recipe 0.2: Installing Zig - Make sure Zig is set up correctly

Full compilable example: `code/00-bootcamp/recipe_0_3.zig`
