# Recipe 13.1: Accepting Script Input via Redirection or Pipes

## Problem

You need to write a utility script that can accept input from stdin, whether it's typed interactively, piped from another command, or redirected from a file.

## Solution

Zig provides `std.io.getStdIn()` to read from standard input. You can read all input at once or process it line by line:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_1.zig:basic_stdin_read}}
```

For line-by-line processing:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_1.zig:line_by_line}}
```

## Discussion

Reading from stdin in Zig is straightforward but offers several patterns depending on your needs.

### Detecting Terminal vs Pipe

Sometimes you want different behavior when input is interactive versus piped. Use `isatty()` to detect:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_1.zig:is_terminal}}
```

This lets you provide prompts in interactive mode but stay quiet when piped:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_1.zig:conditional_behavior}}
```

### Stream Processing

For large inputs, process data as a stream instead of loading everything into memory:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_1.zig:stream_processing}}
```

Stream processing is efficient because it processes one line at a time without allocating memory for the entire input.

### Binary Input

For binary data, read raw bytes instead of text lines:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_1.zig:binary_input}}
```

### Custom Buffer Sizes

For performance tuning, adjust the buffer size based on your use case:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_1.zig:buffered_reading}}
```

Larger buffers reduce system calls but use more memory. Smaller buffers are more responsive but may be slower.

### Filtering Input

Process and filter lines based on conditions:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_1.zig:line_filtering}}
```

### Common Patterns

Word counting and text analysis:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_1.zig:word_counting}}
```

### Best Practices

1. **Always pass allocators explicitly** - Never use hidden allocations
2. **Handle both modes** - Support both interactive and piped input when appropriate
3. **Process streams when possible** - Avoid loading large files entirely into memory
4. **Use appropriate buffer sizes** - Balance memory usage and performance
5. **Clean up resources** - Use `defer` and `errdefer` for proper cleanup

### Common Use Cases

**Reading a config file or pipe:**
```bash
cat config.txt | ./my-tool
# or
./my-tool < config.txt
```

**Processing command output:**
```bash
ls -la | ./my-tool
```

**Interactive input:**
```bash
./my-tool
# User types input, presses Ctrl+D when done
```

## See Also

- Recipe 13.2: Terminating a program with an error message
- Recipe 13.5: Executing an external command and getting its output
- Recipe 13.10: Adding logging to simple scripts

Full compilable example: `code/04-specialized/13-utility-scripting/recipe_13_1.zig`
