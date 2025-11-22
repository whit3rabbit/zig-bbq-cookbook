## Problem

You need to build strings that include variable values - formatting numbers, combining text with data, or creating dynamic messages with proper formatting.

## Solution

Use Zig's `std.fmt` functions for type-safe string formatting:

### Basic String Formatting

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_9.zig:basic_formatting}}
```

### Format Specifiers

```zig
{{#include ../../../code/02-core/02-strings-and-text/recipe_2_9.zig:format_specifiers}}
```

## Discussion

### Format Functions

Zig's `std.fmt` provides three main formatting functions:

**`allocPrint`** - Allocates and returns formatted string:
```zig
const result = try fmt.allocPrint(allocator, "Value: {d}", .{42});
defer allocator.free(result);
```

**`bufPrint`** - Formats into existing buffer (no allocation):
```zig
var buf: [100]u8 = undefined;
const result = try fmt.bufPrint(&buf, "Value: {d}", .{42});
// result is slice of buf
```

**`count`** - Returns size needed (no allocation, no output):
```zig
const size = try fmt.count("Value: {d}", .{42});
// size is 9
```

### Format Specifier Details

**Width and Padding:**
```zig
// Minimum width of 5
fmt.allocPrint(allocator, "{d:5}", .{42})  // "   42"

// Zero padding
fmt.allocPrint(allocator, "{d:0>5}", .{42})  // "00042"

// Left align with padding
fmt.allocPrint(allocator, "{d:<5}", .{42})  // "42   "
```

**Precision for Floats:**
```zig
// 2 decimal places
fmt.allocPrint(allocator, "{d:.2}", .{3.14159})  // "3.14"

// 4 decimal places
fmt.allocPrint(allocator, "{d:.4}", .{3.14159})  // "3.1416"
```

**Combining Width and Precision:**
```zig
// Width 8, precision 2
fmt.allocPrint(allocator, "{d:8.2}", .{3.14})  // "    3.14"
```

### Practical Examples

**Format URLs:**
```zig
const protocol = "https";
const domain = "example.com";
const path = "api/users";
const url = try fmt.allocPrint(
    allocator,
    "{s}://{s}/{s}",
    .{ protocol, domain, path }
);
defer allocator.free(url);
// url is "https://example.com/api/users"
```

**Format File Paths:**
```zig
const dir = "/home/user";
const file = "document.txt";
const path = try fmt.allocPrint(allocator, "{s}/{s}", .{ dir, file });
defer allocator.free(path);
// path is "/home/user/document.txt"
```

**Format Log Messages:**
```zig
const level = "INFO";
const message = "Server started";
const port: u16 = 8080;
const log = try fmt.allocPrint(
    allocator,
    "[{s}] {s} on port {d}",
    .{ level, message, port }
);
defer allocator.free(log);
// log is "[INFO] Server started on port 8080"
```

**Format Currency:**
```zig
const amount: f64 = 1234.56;
const price = try fmt.allocPrint(allocator, "Price: ${d:.2}", .{amount});
defer allocator.free(price);
// price is "Price: $1234.56"
```

**Format Percentages:**
```zig
const value: f32 = 0.856;
const percent = value * 100.0;
const display = try fmt.allocPrint(allocator, "Progress: {d:.1}%", .{percent});
defer allocator.free(display);
// display is "Progress: 85.6%"
```

**Format Dates:**
```zig
const year: u32 = 2024;
const month: u32 = 3;
const day: u32 = 15;
const date = try fmt.allocPrint(
    allocator,
    "{d:0>4}-{d:0>2}-{d:0>2}",
    .{ year, month, day }
);
defer allocator.free(date);
// date is "2024-03-15"
```

**Format Times:**
```zig
const hour: u32 = 9;
const minute: u32 = 5;
const second: u32 = 3;
const time = try fmt.allocPrint(
    allocator,
    "{d:0>2}:{d:0>2}:{d:0>2}",
    .{ hour, minute, second }
);
defer allocator.free(time);
// time is "09:05:03"
```

**Format SQL Queries:**
```zig
const table = "users";
const id: u32 = 123;
const query = try fmt.allocPrint(
    allocator,
    "SELECT * FROM {s} WHERE id = {d}",
    .{ table, id }
);
defer allocator.free(query);
// query is "SELECT * FROM users WHERE id = 123"
```

**Format Error Messages:**
```zig
const filename = "data.txt";
const line: u32 = 42;
const column: u32 = 15;
const error_msg = try fmt.allocPrint(
    allocator,
    "Error in {s} at line {d}, column {d}",
    .{ filename, line, column }
);
defer allocator.free(error_msg);
// error_msg is "Error in data.txt at line 42, column 15"
```

**Format Byte Sizes:**
```zig
const bytes: u64 = 1536;
const kb = @as(f64, @floatFromInt(bytes)) / 1024.0;
const size = try fmt.allocPrint(allocator, "{d:.2} KB", .{kb});
defer allocator.free(size);
// size is "1.50 KB"
```

### Format Complex Types

**Arrays and Slices:**
```zig
const numbers = [_]u32{ 1, 2, 3, 4, 5 };
const result = try fmt.allocPrint(allocator, "Numbers: {any}", .{numbers});
defer allocator.free(result);
// result is "Numbers: { 1, 2, 3, 4, 5 }"
```

**Structs:**
```zig
const Point = struct {
    x: i32,
    y: i32,
};

const point = Point{ .x = 10, .y = 20 };
const result = try fmt.allocPrint(allocator, "Point: {any}", .{point});
defer allocator.free(result);
// result is "Point: main.Point{ .x = 10, .y = 20 }"
```

### Escaping Braces

To include literal braces, double them:

```zig
// Use {{ and }} for literal braces
const json = try fmt.allocPrint(
    allocator,
    "{{\"name\": \"{s}\", \"age\": {d}}}",
    .{ "Alice", 30 }
);
defer allocator.free(json);
// json is "{\"name\": \"Alice\", \"age\": 30}"
```

### Type Safety

Zig's formatting is compile-time type-checked:

```zig
// This compiles
fmt.allocPrint(allocator, "{d}", .{42})  // OK

// This would be a compile error
// fmt.allocPrint(allocator, "{d}", .{"string"})  // ERROR: wrong type
```

The format string and arguments are validated at compile time, preventing runtime format errors.

### Performance

**allocPrint allocates** - must free result:
```zig
const result = try fmt.allocPrint(allocator, "...", .{args});
defer allocator.free(result);
```

**bufPrint is faster** - no allocation:
```zig
var buf: [100]u8 = undefined;
const result = try fmt.bufPrint(&buf, "...", .{args});
// No need to free, result is slice of buf
```

**Pre-calculate size for exact allocation:**
```zig
const size = try fmt.count("Value: {d}", .{42});
var buf = try allocator.alloc(u8, size);
defer allocator.free(buf);
_ = try fmt.bufPrint(buf, "Value: {d}", .{42});
```

### Memory Management

All `allocPrint` results must be freed:

```zig
const result = try fmt.allocPrint(allocator, "...", .{args});
defer allocator.free(result);  // Must free

// bufPrint doesn't allocate
var buf: [100]u8 = undefined;
const result = try fmt.bufPrint(&buf, "...", .{args});
// No free needed
```

### UTF-8 Support

Formatting is UTF-8 safe:

```zig
// UTF-8 in format string
const msg = try fmt.allocPrint(allocator, "Hello 世界 {d}", .{42});
defer allocator.free(msg);
// msg is "Hello 世界 42"

// UTF-8 in arguments
const text = "世界";
const msg = try fmt.allocPrint(allocator, "Hello {s}", .{text});
defer allocator.free(msg);
// msg is "Hello 世界"
```

### Debugging

The `{any}` specifier prints debug representation:

```zig
const data = .{ .name = "test", .value = 42 };
const debug = try fmt.allocPrint(allocator, "Data: {any}", .{data});
defer allocator.free(debug);
// Prints full structure
```

### Security

Format strings are compile-time validated:
- No format string vulnerabilities
- Type mismatches are compile errors
- Buffer overflows prevented

```zig
// Safe - buffer size checked
var buf: [10]u8 = undefined;
// Returns error if doesn't fit
const result = fmt.bufPrint(&buf, "...", .{args});
```

### When to Use Each Function

**Use `allocPrint` when:**
- Unknown output size
- Dynamic formatting
- One-time formatting
- Convenience matters

**Use `bufPrint` when:**
- Performance critical
- Known maximum size
- Avoiding allocations
- Stack buffers preferred

**Use `count` when:**
- Need exact size first
- Pre-allocating buffers
- Validating format
- Size calculations

### Comparison with Other Languages

**Unlike C's printf:**
- Type-safe at compile time
- No format string vulnerabilities
- Explicit allocator
- UTF-8 safe by default

**Unlike Python's f-strings:**
- Compile-time checking
- Explicit memory management
- No implicit conversions
- Manual float formatting

**Like Rust's format!:**
- Compile-time validation
- Type-safe formatting
- Explicit allocator
- Similar specifier syntax

This comprehensive formatting system provides type-safe, efficient string interpolation for all Zig programming needs.
