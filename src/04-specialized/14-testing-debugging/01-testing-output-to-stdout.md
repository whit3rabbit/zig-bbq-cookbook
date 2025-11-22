# Recipe 14.1: Testing program output sent to stdout

## Problem

You need to test functions that print to stdout, but running tests shouldn't actually print anything. You want to capture and verify the output programmatically.

## Solution

Use `std.ArrayList(u8)` as an in-memory buffer to capture output. Pass the buffer's writer to functions instead of stdout, then verify the contents:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_1.zig:basic_output}}
```

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_1.zig:testing_output}}
```

## Discussion

Testing output is crucial for CLI tools and scripts. Instead of writing directly to `std.io.getStdOut()`, design your functions to accept any writer through the `anytype` parameter. This makes them testable and more flexible.

The pattern works because:

1. **Writer abstraction**: Functions use `anytype` for the writer parameter
2. **ArrayList as buffer**: `std.ArrayList(u8)` provides an in-memory writer
3. **Direct inspection**: After the function runs, check `buffer.items` for the output

### Testing Multiple Lines

Capture complex output with multiple print statements:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_1.zig:multiple_outputs}}
```

The multiline string literal (`\\`) makes expected output easy to read and maintain.

### Pattern Matching Output

You don't always need exact string matches. Use `std.mem.indexOf` to verify specific content is present:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_1.zig:formatted_output}}
```

This approach is more resilient to minor formatting changes.

### Testing Error and Success Messages

Capture output even when functions return errors:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_1.zig:error_messages}}
```

The buffer captures output before the error is returned, allowing you to verify error messages were printed correctly.

### Verifying Structured Output

Test complex formatted output like tables:

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_1.zig:table_output}}
```

### Testing Special Output

#### JSON Output

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_1.zig:json_output}}
```

#### Progress Indicators

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_1.zig:progress_output}}
```

#### ANSI Color Codes

```zig
{{#include ../../../code/04-specialized/14-testing-debugging/recipe_14_1.zig:color_codes}}
```

### Best Practices

1. **Design for testability**: Accept writer parameters rather than hardcoding `stdout`
2. **Use exact matches for simple output**: `expectEqualStrings` for predictable output
3. **Use pattern matching for complex output**: `indexOf` when format might vary
4. **Test both success and error paths**: Verify output in all scenarios
5. **Count lines for structure**: Validate output structure without hardcoding content

### Common Gotchas

**Forgetting the allocator**: In Zig 0.15.2, `ArrayList` is unmanaged and requires passing the allocator to `deinit` and `writer`:

```zig
var buffer = std.ArrayList(u8){};
defer buffer.deinit(testing.allocator);  // Pass allocator here
const writer = buffer.writer(testing.allocator);  // And here
```

**Comparing with wrong string endings**: Remember to include newlines in expected output if your functions print them.

## See Also

- Recipe 13.1: Accepting script input via redirection or pipes
- Recipe 14.3: Testing for exceptional conditions in unit tests
- Recipe 14.4: Logging test output to a file

Full compilable example: `code/04-specialized/14-testing-debugging/recipe_14_1.zig`
