# Recipe 13.3: Prompting for a Password at Runtime

## Problem

You need to securely prompt the user for a password without displaying it on the screen.

## Solution

On Unix-like systems, use terminal control functions to disable echo:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_3.zig:basic_password_prompt}}
```

For testing or mock implementations, use a simpler reader-based approach:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_3.zig:mock_password_reader}}
```

## Discussion

Securely handling passwords requires disabling terminal echo, validating input, and properly clearing sensitive data from memory.

### Password Validation

Enforce password strength requirements:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_3.zig:password_validation}}
```

Common password rules include:
- Minimum length (typically 8-16 characters)
- Character variety (uppercase, lowercase, digits, special chars)
- No common patterns or dictionary words

### Password Confirmation

Prompt twice to ensure the user typed what they intended:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_3.zig:password_confirmation}}
```

This pattern prevents typos in password entry, especially important during account creation or password changes.

### Secure Memory Clearing

Always clear passwords from memory after use:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_3.zig:secure_password_clear}}
```

While Zig doesn't have automatic memory encryption, explicitly zeroing sensitive data reduces the window where it could be exposed through memory dumps or swap files.

### Validation with Retry

Combine validation with user-friendly retry logic:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_3.zig:password_with_validation}}
```

This gives users multiple chances to create a valid password while providing clear feedback on what's wrong.

### Password Strength Indicator

Provide feedback on password strength:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_3.zig:password_strength}}
```

Strength indicators help users understand password quality without enforcing strict requirements.

### Masked Input

Some applications show asterisks instead of hiding input completely:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_3.zig:masked_input}}
```

Masked input provides visual feedback that the user is typing without revealing the actual password.

### Timeout Handling

For security-sensitive applications, implement timeouts:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_3.zig:timeout_password}}
```

Timeouts prevent leaving password prompts open indefinitely in unattended terminals.

### Best Practices

1. **Never echo passwords** - Always disable terminal echo or use masked characters
2. **Clear from memory** - Zero out password buffers after use
3. **Validate strength** - Enforce reasonable password requirements
4. **Confirm on creation** - Ask twice when setting new passwords
5. **Give feedback** - Show clear error messages for invalid passwords
6. **Limit attempts** - Prevent brute force by limiting retry attempts
7. **Handle signals** - Restore terminal state even when interrupted
8. **Test with mocks** - Use reader-based mocks for unit testing

### Terminal Control

On Unix-like systems, password prompting uses `tcgetattr` and `tcsetattr` to control terminal behavior:

```c
// Pseudo-code concept
original_settings = tcgetattr(stdin)
new_settings = original_settings
new_settings.ECHO = false  // Disable echo
tcsetattr(stdin, new_settings)

// Read password

tcsetattr(stdin, original_settings)  // Restore
```

Always restore the terminal state, even when errors occur. Use `defer` to ensure cleanup.

### Platform Considerations

**Unix/Linux/macOS:**
- Use `termios` for terminal control
- `tcgetattr` and `tcsetattr` for echo control
- Works in any POSIX-compliant terminal

**Windows:**
- Use `SetConsoleMode` with `ENABLE_ECHO_INPUT`
- Different API but same concept
- Works in cmd.exe and PowerShell

**Testing:**
- Use mock readers for automated testing
- Don't rely on actual terminal in tests
- Test validation logic separately

### Security Considerations

1. **Memory exposure**: Passwords may briefly exist in memory
2. **Terminal logging**: Some terminals log output
3. **Screen capture**: Malware could capture screen content
4. **Keyboard loggers**: Hardware/software keyloggers bypass this protection
5. **Shoulder surfing**: Physical observation remains a risk

Password prompting protects against casual observation and terminal history, but can't defend against all attack vectors.

### Example Usage

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Read password
    const password = try readPasswordUnix(allocator, "Enter password: ");
    defer {
        clearPassword(password);
        allocator.free(password);
    }

    // Validate
    const rules = PasswordRules{};
    try rules.validate(password);

    // Use password for authentication...
    std.debug.print("Password accepted\n", .{});
}
```

## See Also

- Recipe 13.1: Accepting script input via redirection or pipes
- Recipe 13.2: Terminating a program with an error message
- Recipe 13.4: Getting the terminal size

Full compilable example: `code/04-specialized/13-utility-scripting/recipe_13_3.zig`
