# Recipe 13.5: Executing an External Command and Getting Its Output

## Problem

You need to run an external command from your Zig program and capture its output.

## Solution

Use `std.process.Child` to spawn a process and capture its output:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_5.zig:basic_exec}}
```

For more control, capture both stdout and stderr with the exit code:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_5.zig:exec_with_status}}
```

## Discussion

Executing external commands is a common task in system administration scripts and build tools.

### Providing Input

Send data to the command's stdin:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_5.zig:exec_with_input}}
```

This pattern is useful for interactive commands that read from stdin.

### Timeout Handling

Prevent commands from hanging indefinitely:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_5.zig:exec_with_timeout}}
```

**Important limitations in Zig 0.15.2:**

Implementing timeouts with child processes is complex due to stdlib constraints:

1. **Blocking I/O**: `readToEndAlloc()` blocks until the process closes its streams or sends EOF. There's no built-in non-blocking read option.

2. **Race conditions**: `std.process.Child.kill()` not only kills the process but also closes file descriptors, which can cause issues if you're trying to read from them concurrently (see [Zig issue #16820](https://github.com/ziglang/zig/issues/16820)).

3. **Platform differences**:
   - **Unix/Linux/macOS**: Works for processes that respond to SIGTERM
   - **Windows**: Cannot forcibly terminate the process due to the race condition above. The timeout flag is set, but the function waits for the process to exit naturally before returning `error.Timeout`.

The implementation above uses threading and signals (`SIGTERM` on Unix) to terminate processes that exceed the timeout. This has several limitations:
- **Windows**: Timeout detection works, but termination does not
- **Unix**: Only works for processes that respond to `SIGTERM`
- Commands producing infinite output may still hang
- Processes with custom signal handlers may not terminate

**Production alternatives (recommended):**

For production use with untrusted or potentially misbehaving commands, use the system timeout command:

**Unix/Linux/macOS:**
```bash
timeout 5s your-command
```

**Windows (PowerShell):**
```powershell
timeout /t 5 your-command
```

**Cross-platform from Zig:**
```zig
// Unix/Linux/macOS
const argv = [_][]const u8{ "timeout", "5s", "your-command" };

// Windows - use PowerShell
const argv = [_][]const u8{ "powershell", "-Command",
    "Start-Process -Wait -Timeout 5 your-command" };

const output = try executeCommand(allocator, &argv);
```

This delegates timeout handling to the OS, avoiding the Zig stdlib limitations entirely.

### Custom Environment

Run commands with modified environment variables:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_5.zig:exec_with_env}}
```

Environment customization is essential for build scripts and testing.

### Working Directory

Execute commands in a specific directory:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_5.zig:exec_in_directory}}
```

Setting the working directory avoids hardcoding paths in commands.

### Command Pipelines

Chain commands together like shell pipes:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_5.zig:exec_pipeline}}
```

Pipelines combine simple commands into complex operations.

### Streaming Output

Process command output line-by-line as it arrives:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_5.zig:exec_streaming}}
```

Streaming is essential for long-running commands where you want live feedback.

### Shell Execution

Execute shell commands with full shell features:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_5.zig:exec_shell}}
```

Shell execution enables pipes, redirections, and glob expansion, but introduces security risks.

### Safe Command Builder

Build commands safely with validation:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_5.zig:exec_safe}}
```

The builder pattern prevents command injection and makes complex invocations more readable.

### Best Practices

1. **Validate input** - Never pass unsanitized user input to shell commands
2. **Use argument arrays** - Prefer `argv` over shell strings to avoid injection
3. **Set timeouts** - Protect against hanging processes
4. **Check exit codes** - Non-zero exits indicate errors
5. **Capture stderr** - Error messages are usually on stderr
6. **Clean up processes** - Always wait for children to prevent zombies
7. **Limit output** - Set maximum buffer sizes to prevent memory exhaustion

### Security Considerations

**Command Injection:**
```zig
// DANGEROUS - user input could be malicious
const user_input = getUserInput();
const cmd = try std.fmt.allocPrint(allocator, "ls {s}", .{user_input});
// If user_input = "; rm -rf /", you have a problem!
```

**Safe Alternative:**
```zig
// SAFE - arguments are properly escaped
const argv = [_][]const u8{ "ls", user_input };
const output = try executeCommand(allocator, &argv);
```

**Never use shell execution with user input unless absolutely necessary.**

### Exit Codes

Standard Unix exit codes:
- `0` - Success
- `1` - General error
- `2` - Misuse of command
- `126` - Command cannot execute
- `127` - Command not found
- `128+N` - Killed by signal N

Always check exit codes to detect failures:

```zig
const result = try executeWithStatus(allocator, &argv);
defer result.deinit(allocator);

if (result.exit_code != 0) {
    std.debug.print("Command failed: {s}\n", .{result.stderr});
    return error.CommandFailed;
}
```

### Platform Differences

**Unix/Linux/macOS:**
- Uses `fork` + `exec`
- Signals for termination
- Rich process control

**Windows:**
- Uses `CreateProcess`
- Different signal model
- Some commands may behave differently

Test on all target platforms.

### Example Usage

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Simple command
    const argv = [_][]const u8{ "ls", "-la" };
    const output = try executeCommand(allocator, &argv);
    defer allocator.free(output);
    std.debug.print("{s}\n", .{output});

    // With status checking
    const git_argv = [_][]const u8{ "git", "status" };
    var result = try executeWithStatus(allocator, &git_argv);
    defer result.deinit(allocator);

    if (result.exit_code == 0) {
        std.debug.print("{s}\n", .{result.stdout});
    } else {
        std.debug.print("Error: {s}\n", .{result.stderr});
    }

    // Using builder
    var builder = try CommandBuilder.init(allocator, "git");
    defer builder.deinit();

    _ = try builder.arg("log");
    _ = try builder.arg("--oneline");
    _ = try builder.arg("-n");
    _ = try builder.arg("5");

    var log_result = try builder.execute();
    defer log_result.deinit(allocator);
    std.debug.print("{s}\n", .{log_result.stdout});
}
```

### Common Patterns

**Git Operations:**
```zig
const argv = [_][]const u8{ "git", "rev-parse", "--short", "HEAD" };
const commit = try executeCommand(allocator, &argv);
```

**File Processing:**
```zig
const argv = [_][]const u8{ "grep", "-r", "TODO", "src/" };
const todos = try executeCommand(allocator, &argv);
```

**System Information:**
```zig
const argv = [_][]const u8{ "uname", "-a" };
const sysinfo = try executeCommand(allocator, &argv);
```

### Error Handling

Always handle potential errors:
- `error.FileNotFound` - Command doesn't exist
- `error.AccessDenied` - No permission to execute
- `error.OutOfMemory` - Output too large
- `error.Timeout` - Command didn't complete in time

## See Also

- Recipe 13.1: Accepting script input via redirection or pipes
- Recipe 13.2: Terminating a program with an error message
- Recipe 13.6: Copying or moving files and directory trees

Full compilable example: `code/04-specialized/13-utility-scripting/recipe_13_5.zig`
