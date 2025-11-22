# Understanding Allocators

## Problem

You're coming from Python, JavaScript, or Java where memory allocation is automatic and invisible. In Zig, there's no `new` keyword, no `malloc()` function you can call directly, and no default allocator.

How do you allocate memory? What's an `Allocator` parameter? Why do ArrayList and HashMap need an allocator argument? This is uniquely Zig and must be understood before writing any real code.

## Solution

Zig requires **explicit memory allocation** - you must choose where memory comes from:

1. **No default allocator** - Functions that allocate memory take an `Allocator` parameter
2. **Allocator interface** - All allocators implement `std.mem.Allocator`
3. **Different allocators for different use cases** - Choose based on lifetime and performance needs

Common allocators:
- `FixedBufferAllocator` - Stack memory, no malloc
- `GeneralPurposeAllocator` - Safe malloc with leak detection
- `ArenaAllocator` - Batch allocate, free all at once
- `testing.allocator` - For tests, detects leaks automatically

This explicit approach eliminates hidden allocations and makes memory usage predictable.

## Discussion

### Part 1: Why Zig Needs Allocators

```zig
{{#include ../../code/00-bootcamp/recipe_0_12.zig:why_allocators}}
```

**Coming from C:** Zig's allocators are like passing a custom `malloc`/`free` implementation, but type-safe and standardized.

**Coming from Java/Python:** Every `new` or `[]` allocation you write in those languages is hidden. Zig makes it explicit so you know exactly when and where memory is allocated.

### Part 2: Common Allocator Types

```zig
{{#include ../../code/00-bootcamp/recipe_0_12.zig:allocator_types}}
```

Always use `testing.allocator` in tests - it automatically detects and reports memory leaks.

### Part 3: Common Allocator Patterns

```zig
{{#include ../../code/00-bootcamp/recipe_0_12.zig:allocator_patterns}}
```

### Handling Allocation Failures

Allocations can fail - always be prepared:

```zig
test "handling allocation failures" {
    const tryAllocate = struct {
        fn call(allocator: std.mem.Allocator, size: usize) ![]u8 {
            const data = allocator.alloc(u8, size) catch |err| {
                std.debug.print("Allocation failed: {}\n", .{err});
                return err;
            };
            return data;
        }
    }.call;

    // This will likely succeed
    const data = try tryAllocate(testing.allocator, 100);
    defer testing.allocator.free(data);

    // FixedBufferAllocator can run out of space
    var buffer: [10]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);

    const result = tryAllocate(fba.allocator(), 1000);
    try testing.expectError(error.OutOfMemory, result);
}
```

Unlike garbage-collected languages, running out of memory is a recoverable error in Zig.

### Combining with errdefer

Use `errdefer` to clean up on allocation failure:

```zig
test "allocator with errdefer" {
    const createAndInit = struct {
        fn call(allocator: std.mem.Allocator, should_fail: bool) ![]i32 {
            const data = try allocator.alloc(i32, 10);
            errdefer allocator.free(data); // Free if initialization fails

            // Initialize
            for (data, 0..) |*item, i| {
                item.* = @intCast(i);
            }

            if (should_fail) {
                return error.InitFailed; // errdefer runs
            }

            return data; // errdefer doesn't run
        }
    }.call;

    // Success case
    const data = try createAndInit(testing.allocator, false);
    defer testing.allocator.free(data);
    try testing.expectEqual(@as(i32, 5), data[5]);

    // Failure case - errdefer prevents leak
    const result = createAndInit(testing.allocator, true);
    try testing.expectError(error.InitFailed, result);
}
```

### Practical Example

Building a dynamic data structure:

```zig
test "building a dynamic data structure" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var names = std.ArrayList([]const u8){};
    defer names.deinit(allocator);

    // Add strings to list
    try names.append(allocator, "Alice");
    try names.append(allocator, "Bob");
    try names.append(allocator, "Charlie");

    // Create a copy of a string
    const name_copy = try allocator.dupe(u8, "David");
    try names.append(allocator, name_copy);

    try testing.expectEqual(@as(usize, 4), names.items.len);
    try testing.expect(std.mem.eql(u8, names.items[0], "Alice"));

    // arena.deinit() frees everything
}
```

### Decision Tree

**Which allocator should I use?**

- Writing tests? → `testing.allocator`
- Small, temporary, stack allocation? → `FixedBufferAllocator`
- Many allocations, free all at once? → `ArenaAllocator`
- General purpose, long-lived? → `GeneralPurposeAllocator`

**Should I store the allocator in my struct?**

- Struct allocates memory in `init`? → Yes, store it for `deinit`
- Struct only receives allocated memory? → No, caller handles it

### Common Patterns

**Init/deinit pattern:**
```zig
fn init(allocator: std.mem.Allocator) !@This() {
    const data = try allocator.alloc(u8, size);
    return .{ .data = data, .allocator = allocator };
}

fn deinit(self: *@This()) void {
    self.allocator.free(self.data);
}
```

**Arena for scoped lifetime:**
```zig
var arena = std.heap.ArenaAllocator.init(parent_allocator);
defer arena.deinit();
// ... use arena.allocator() ...
```

**Passing allocator through call chain:**
```zig
fn topLevel(allocator: std.mem.Allocator) !void {
    try middleLevel(allocator);
}

fn middleLevel(allocator: std.mem.Allocator) !void {
    const data = try bottomLevel(allocator);
    defer allocator.free(data);
}
```

### Common Mistakes

**Forgetting to pass allocator:**
```zig
var list = std.ArrayList(i32){};
list.append(1);  // error: no allocator provided
// Fixed:
try list.append(allocator, 1);
```

**Forgetting defer:**
```zig
const data = try allocator.alloc(u8, 100);
// Memory leak! Need: defer allocator.free(data);
```

**Using wrong allocator for deinit:**
```zig
const data = try allocator1.alloc(u8, 100);
allocator2.free(data);  // Wrong! Must use same allocator
```

**Not handling OutOfMemory:**
```zig
const data = allocator.alloc(u8, huge_size);
// Should be:
const data = try allocator.alloc(u8, huge_size);
```

## See Also

- Recipe 0.11: Optionals, Errors, and Resource Cleanup - Using defer/errdefer
- Recipe 0.6: Arrays, ArrayLists, and Slices - ArrayList needs allocators
- Recipe 0.13: Testing and Debugging - Memory leak detection

Full compilable example: `code/00-bootcamp/recipe_0_12.zig`
