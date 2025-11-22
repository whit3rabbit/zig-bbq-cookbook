# Recipe 13.4: Getting the Terminal Size

## Problem

You need to determine the terminal dimensions to format output appropriately for the user's screen.

## Solution

On Unix-like systems, use the `ioctl` system call with `TIOCGWINSZ`:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_4.zig:terminal_size}}
```

For safer code, provide fallback to standard dimensions:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_4.zig:fallback_size}}
```

## Discussion

Knowing terminal dimensions allows you to format output that fits the user's screen without wrapping or truncation.

### Environment Variable Fallback

Some systems set `LINES` and `COLUMNS` environment variables:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_4.zig:environment_size}}
```

Environment variables are less reliable than `ioctl` but provide a backup method.

### Best Effort Detection

Use multiple strategies with graceful degradation:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_4.zig:adaptive_terminal}}
```

This approach tries the most reliable methods first, falling back to reasonable defaults if all detection fails.

### Responsive Text Wrapping

Wrap text to fit terminal width:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_4.zig:responsive_output}}
```

Text wrapping prevents horizontal scrolling and makes output more readable.

### Column Layout

Format data in columns that adapt to terminal width:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_4.zig:column_layout}}
```

Column layouts maximize use of screen space while maintaining readability.

### Progress Bars

Draw progress bars scaled to terminal width:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_4.zig:progress_bar}}
```

Progress bars provide visual feedback for long-running operations.

### Truncation

Truncate long lines to prevent wrapping:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_4.zig:truncate_output}}
```

Truncation keeps output compact and prevents terminal scrolling issues.

### Centering Text

Center text within terminal width:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_4.zig:center_text}}
```

Centered text creates visually appealing headers and titles.

### Best Practices

1. **Always provide fallbacks** - Not all terminals support size detection
2. **Use standard defaults** - 80x24 is a safe assumption
3. **Check for changes** - Terminal can be resized during execution
4. **Test without terminal** - Handle piped/redirected output gracefully
5. **Respect user preferences** - Don't assume terminal features
6. **Cache when possible** - Avoid excessive ioctl calls
7. **Handle edge cases** - Very small or very large terminals

### Platform Considerations

**Unix/Linux/macOS:**
- Use `ioctl` with `TIOCGWINSZ`
- Most reliable method
- Requires file descriptor to terminal

**Windows:**
- Use `GetConsoleScreenBufferInfo`
- Different API, same concept
- Works in cmd.exe and PowerShell

**Piped Output:**
- `ioctl` fails when stdout is not a terminal
- Environment variables may still work
- Fall back to standard dimensions

### Signal Handling

Terminals can be resized while your program runs. On Unix systems, this sends `SIGWINCH`:

```zig
// Pseudo-code concept
signal(SIGWINCH, handle_resize);

fn handle_resize() {
    // Re-query terminal size
    size = getTerminalSize();
    // Redraw output
}
```

For responsive applications, listen for `SIGWINCH` and update your output accordingly.

### Common Terminal Sizes

Standard sizes you might encounter:

- **80x24** - Classic VT100 standard
- **80x25** - DOS/Windows standard
- **132x24** - VT100 wide mode
- **120x30** - Common modern size
- **256x64** - Large modern terminal

Always test with small terminals (80x24) to ensure your output degrades gracefully.

### Detection Reliability

From most to least reliable:

1. **ioctl(TIOCGWINSZ)** - Direct kernel query, most accurate
2. **Environment variables** - May be stale or incorrect
3. **Fixed defaults** - Always works but may not match actual size

### Example Usage

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get terminal size
    const term_size = getTerminalSizeBestEffort(allocator);
    std.debug.print("Terminal: {}x{}\n", .{ term_size.cols, term_size.rows });

    // Wrap text to terminal width
    const text = "This is a long line that should wrap appropriately...";
    const wrapped = try wrapText(allocator, text, term_size.cols);
    defer allocator.free(wrapped);
    std.debug.print("{s}\n", .{wrapped});

    // Show progress bar
    const progress = try drawProgressBar(allocator, 42, 100, term_size.cols);
    defer allocator.free(progress);
    std.debug.print("{s}\n", .{progress});
}
```

### Use Cases

**Progress Indicators:**
- Progress bars that fill the screen
- Spinner animations in corner
- Multi-line status displays

**Data Presentation:**
- Column-aligned tables
- Wrapped paragraphs
- Truncated lists

**Interactive UIs:**
- Full-screen TUIs
- Menus and dialogs
- Split panes

## See Also

- Recipe 13.1: Accepting script input via redirection or pipes
- Recipe 13.2: Terminating a program with an error message
- Recipe 13.10: Adding logging to simple scripts

Full compilable example: `code/04-specialized/13-utility-scripting/recipe_13_4.zig`
