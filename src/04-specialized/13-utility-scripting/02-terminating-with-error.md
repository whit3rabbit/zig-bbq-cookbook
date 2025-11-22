# Recipe 13.2: Terminating a Program with an Error Message

## Problem

You need to terminate your program with a meaningful error message and appropriate exit code when something goes wrong.

## Solution

Use `std.process.exit()` to terminate with an exit code, and `std.debug.print()` to write error messages to stderr:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_2.zig:basic_exit}}
```

For error reporting:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_2.zig:error_to_stderr}}
```

## Discussion

Proper error handling in command-line tools requires both meaningful exit codes and clear error messages.

### Standard Exit Codes

Use conventional exit codes to communicate results to the shell:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_2.zig:custom_error_types}}
```

Exit code 0 means success. Non-zero codes indicate different types of failures. Common conventions:
- `1`: General error
- `2`: Misuse of shell command (bad arguments)
- `127`: Command not found
- `128+`: Signal-related exits

### Error Context

Provide rich error information with context:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_2.zig:error_with_context}}
```

This pattern bundles the error message with its exit code and provides methods to report or exit directly.

### Fatal Errors

For unrecoverable errors, use a fatal error function:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_2.zig:fatal_error}}
```

Fatal errors print to stderr and immediately exit. Use these for programming errors, missing required resources, or any condition that prevents the program from continuing.

### Usage Errors

When users provide invalid input, show the error with usage hints:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_2.zig:error_with_usage}}
```

This helps users understand what went wrong and how to use your tool correctly.

### Error Categories

Organize errors by category with consistent codes and prefixes:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_2.zig:error_categories}}
```

Categorized errors make it easier to handle different failure modes consistently:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_2.zig:categorized_error}}
```

### Builder Pattern for Rich Errors

For complex error messages, use a builder pattern:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_2.zig:error_builder}}
```

This pattern lets you construct detailed error messages with hints, suggestions, and context.

### Custom Panic Handler

For catching panics and providing custom error messages:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_2.zig:stack_trace_error}}
```

### Multiple Error Accumulation

Sometimes you want to collect all errors before exiting:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_2.zig:multi_error_accumulation}}
```

This is useful for validation tasks where you want to report all problems at once rather than failing on the first error.

### Best Practices

1. **Always write errors to stderr** - Use `std.debug.print()` which writes to stderr by default
2. **Use conventional exit codes** - Follow shell conventions for exit codes
3. **Be specific** - Include relevant details in error messages
4. **Provide context** - Tell users what went wrong and how to fix it
5. **Clean up resources** - Even when exiting with an error, use `defer` and `errdefer` for cleanup
6. **Test error paths** - Write tests that verify error handling works correctly

### Exit Code Conventions

Standard Unix exit codes:
- `0` - Success
- `1` - General error
- `2` - Misuse of shell command
- `64` - Command line usage error
- `65` - Data format error
- `66` - Cannot open input
- `67` - Addressee unknown
- `68` - Host name unknown
- `69` - Service unavailable
- `70` - Internal software error
- `71` - System error
- `72` - Critical OS file missing
- `73` - Can't create output file
- `74` - I/O error
- `75` - Temp failure
- `76` - Remote error in protocol
- `77` - Permission denied
- `78` - Configuration error
- `126` - Command cannot execute
- `127` - Command not found
- `128+N` - Fatal signal N

### Common Patterns

**Simple error and exit:**
```bash
$ ./mytool invalid_arg
Error: unknown option 'invalid_arg'
$ echo $?
2
```

**Fatal error:**
```bash
$ ./mytool
Fatal: configuration file not found
$ echo $?
1
```

**Multiple errors:**
```bash
$ ./mytool --validate config.json
Found 3 error(s):
  1. missing required field 'name'
  2. invalid port number '99999'
  3. unknown option 'foo'
$ echo $?
1
```

## See Also

- Recipe 13.1: Accepting script input via redirection or pipes
- Recipe 13.10: Adding logging to simple scripts
- Recipe 13.15: Parsing command-line options

Full compilable example: `code/04-specialized/13-utility-scripting/recipe_13_2.zig`
