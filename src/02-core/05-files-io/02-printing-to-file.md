## Problem

You need to write formatted data to a file, similar to how `std.debug.print` works for stdout, but directed to a file instead.

## Solution

### Basic Printing

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_2.zig:basic_printing}}
```

### Structured Printing

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_2.zig:structured_printing}}
```

### Conditional Logging

```zig
{{#include ../../../code/02-core/05-files-io/recipe_5_2.zig:conditional_logging}}
```

## Original Solution

Use a file writer with the `.print()` method to format and write data directly to a file.
    try writer.print("Pointer: {*}\n", .{&writer});

    try writer.flush();
}
```

### Printing Structured Data

```zig
const Person = struct {
    name: []const u8,
    age: u32,
    height: f32,
};

pub fn printStructData(path: []const u8, people: []const Person) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    try writer.print("People Database\n", .{});
    try writer.print("{s}\n", .{"=" ** 50});

    for (people, 0..) |person, i| {
        try writer.print("{}: {s}, Age: {}, Height: {d:.1}m\n", .{
            i + 1,
            person.name,
            person.age,
            person.height,
        });
    }

    try writer.flush();
}
```

### Printing Tables with Alignment

```zig
pub fn printTable(
    path: []const u8,
    headers: []const []const u8,
    data: []const []const []const u8,
) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    // Print headers
    for (headers) |header| {
        try writer.print("{s:<15} ", .{header});
    }
    try writer.print("\n", .{});

    // Print separator
    for (headers) |_| {
        try writer.print("{s:<15} ", .{"-" ** 15});
    }
    try writer.print("\n", .{});

    // Print data rows
    for (data) |row| {
        for (row) |cell| {
            try writer.print("{s:<15} ", .{cell});
        }
        try writer.print("\n", .{});
    }

    try writer.flush();
}
```

### Conditional Printing

```zig
pub fn printWithConditions(
    path: []const u8,
    values: []const i32,
    threshold: i32,
) !usize {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    var count: usize = 0;

    try writer.print("Values greater than {}:\n", .{threshold});

    for (values) |value| {
        if (value > threshold) {
            try writer.print("  {}\n", .{value});
            count += 1;
        }
    }

    try writer.print("\nTotal: {} values\n", .{count});
    try writer.flush();

    return count;
}
```

### Logging-Style Printing with Timestamps

```zig
pub fn printLog(
    path: []const u8,
    level: []const u8,
    message: []const u8,
) !void {
    const file = try std.fs.cwd().openFile(path, .{
        .mode = .write_only,
    });
    defer file.close();

    // Seek to end for appending
    try file.seekFromEnd(0);

    const timestamp = std.time.timestamp();

    // Format the message
    var buf: [512]u8 = undefined;
    const log_line = try std.fmt.bufPrint(&buf, "[{}] {s}: {s}\n", .{ timestamp, level, message });

    // Write directly without buffering for reliable appending
    _ = try file.write(log_line);
}
```

### Printing with Error Handling

```zig
pub fn printReport(
    path: []const u8,
    allocator: std.mem.Allocator,
    generate_data: fn (std.mem.Allocator) anyerror![]const u8,
) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var write_buf: [4096]u8 = undefined;
    var file_writer = file.writer(&write_buf);
    const writer = &file_writer.interface;

    try writer.print("=== Report ===\n\n", .{});

    const data = generate_data(allocator) catch |err| {
        try writer.print("Error generating data: {}\n", .{err});
        try writer.flush();
        return err;
    };
    defer allocator.free(data);

    try writer.print("Data:\n{s}\n", .{data});
    try writer.flush();
}
```

## Discussion

### Writer Interface

The `.print()` method on writers provides type-safe formatted output similar to `std.debug.print` or `std.fmt.format`. It uses compile-time format string parsing to ensure type safety.

**Format specifiers:**
- `{}` - Default formatting for the type
- `{s}` - String (required for `[]const u8`)
- `{d}` - Decimal formatting for numbers
- `{x}` - Hexadecimal (lowercase)
- `{X}` - Hexadecimal (uppercase)
- `{b}` - Binary
- `{o}` - Octal
- `{e}` - Scientific notation
- `{c}` - Character
- `{*}` - Pointer address

**Formatting options:**
- `{d:.2}` - Precision (2 decimal places)
- `{s:<10}` - Left-align with width 10
- `{s:>10}` - Right-align with width 10
- `{s:^10}` - Center-align with width 10

### Memory Usage

The `.print()` method formats directly into the writer's buffer, avoiding intermediate allocations. This makes it very efficient for file output.

```zig
// No allocations needed
try writer.print("Value: {}\n", .{42});

// Compare to building strings:
const str = try std.fmt.allocPrint(allocator, "Value: {}\n", .{42});
defer allocator.free(str);
try writer.writeAll(str);  // Less efficient
```

### Flushing

Always remember to flush the writer when you're done:

```zig
try writer.flush();
```

Without flushing, data may remain in the buffer and not be written to disk. This is especially important for:
- Log files where immediate visibility matters
- Critical data that must be persisted
- Before closing the file (though `defer file.close()` helps here)

### Error Handling

Printing to a file can fail for several reasons:
- Disk full (`error.NoSpaceLeft`)
- File system errors (`error.InputOutput`)
- Broken pipe if file handle becomes invalid
- Permission issues

Always propagate or handle these errors appropriately:

```zig
writer.print("Data: {}\n", .{value}) catch |err| {
    std.log.err("Failed to write: {}", .{err});
    return err;
};
```

### Performance Considerations

**Buffered writing is automatic** with the new Zig 0.15.2 API. The buffer you provide to `file.writer(&buffer)` is used for batching write operations.

**Buffer size matters:**
- Smaller buffers (1KB-4KB): More frequent flushes, good for logs
- Larger buffers (8KB-64KB): Fewer syscalls, better for bulk data
- Default 4KB is good for most cases

**For maximum performance:**
```zig
var write_buf: [8192]u8 = undefined;  // Larger buffer
var file_writer = file.writer(&write_buf);
const writer = &file_writer.interface;

// Batch many print calls
for (many_items) |item| {
    try writer.print("{}\n", .{item});
}

// Single flush at the end
try writer.flush();
```

### Comparison with writeAll

**Use `.print()` when:**
- You need formatting
- Working with multiple data types
- Building output dynamically
- Creating human-readable output

**Use `.writeAll()` when:**
- You already have formatted strings
- Writing raw binary data
- Maximum performance is critical
- No formatting needed

```zig
// With formatting - use print
try writer.print("Count: {}\n", .{count});

// Pre-formatted - use writeAll
try writer.writeAll("Static string\n");
```

### Comparison with Other Languages

**Python:**
```python
with open('output.txt', 'w') as f:
    print(f"Hello, {name}!", file=f)
    print(f"Value: {value}", file=f)
```

**C:**
```c
FILE *f = fopen("output.txt", "w");
fprintf(f, "Hello, %s!\n", name);
fprintf(f, "Value: %d\n", value);
fclose(f);
```

**Zig's approach** combines type safety of format strings (compile-time checked) with explicit error handling and no hidden allocations.

## See Also

- `code/02-core/05-files-io/recipe_5_2.zig` - Full implementations and tests
- Recipe 5.1: Reading and writing text data
- Recipe 5.3: Printing with a different separator or line ending
- Recipe 3.3: Formatting numbers for output
