# Keeping Dictionaries in Order

## Problem

You need a dictionary that maintains the order in which keys were inserted, making iteration predictable and allowing index-based access.

## Solution

Use `ArrayHashMap` or `StringArrayHashMap` instead of `AutoHashMap`. These variants store entries in an array, preserving insertion order:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_7.zig:basic_ordered_map}}
```

## Discussion

### ArrayHashMap vs AutoHashMap

**ArrayHashMap**:
- Maintains insertion order
- Allows index-based access (`.keys()[i]`, `.values()[i]`)
- Slightly slower for lookups
- Better cache locality
- Deterministic iteration

**AutoHashMap**:
- Faster lookups
- No order guarantees
- Cannot access by index
- Better for pure key-value lookups

### String Keys

For string keys, always use `StringArrayHashMap` which handles string comparison correctly:

```zig
var settings = std.StringArrayHashMap(i32).init(allocator);
defer settings.deinit();

try settings.put("width", 1920);
try settings.put("height", 1080);
try settings.put("fps", 60);
```

### Index-Based Access

ArrayHashMap allows direct access by index:

```zig
// Get first key-value pair
const first_key = config.keys()[0];
const first_value = config.values()[0];

// Iterate with indices
for (config.keys(), config.values(), 0..) |key, value, i| {
    std.debug.print("{d}. {s} = {s}\n", .{ i, key, value });
}
```

### Common Operations

```zig
// Put overwrites existing keys
try map.put("key", 100);
try map.put("key", 200); // Now "key" -> 200

// Check existence
const has_key = map.contains("key");

// Get with default
const value = map.get("key") orelse 0;

// Remove by key
_ = map.remove("key");

// Clear all entries
map.clearRetainingCapacity(); // Keeps allocated memory
// OR
map.clearAndFree(); // Frees memory
```

### Iteration Patterns

ArrayHashMap provides multiple ways to iterate:

```zig
// Iterate keys and values separately
for (map.keys(), map.values()) |key, value| {
    std.debug.print("{}: {}\n", .{ key, value });
}

// Iterate with indices
for (map.keys(), 0..) |key, i| {
    const value = map.values()[i];
    std.debug.print("{d}. {} = {}\n", .{ i, key, value });
}

// Using iterator (more flexible)
var it = map.iterator();
while (it.next()) |entry| {
    std.debug.print("{} -> {}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
}
```

### Mutable Iteration

Modify values during iteration:

```zig
// Double all values
for (map.values()) |*value| {
    value.* *= 2;
}

// Or using iterator
var it = map.iterator();
while (it.next()) |entry| {
    entry.value_ptr.* += 10;
}
```

### Capacity Management

```zig
// Pre-allocate for known size
try map.ensureTotalCapacity(100);

// Check capacity
const cap = map.capacity();
const len = map.count();
```

### When to Use Ordered Maps

**Use ArrayHashMap when**:
- You need predictable iteration order
- You're serializing to JSON/TOML/YAML
- You want to access entries by index
- You need to display items in insertion order
- You're building configuration systems

**Use AutoHashMap when**:
- Pure key-value lookups (no iteration)
- Maximum lookup performance is critical
- Order doesn't matter
- Working with large datasets

### Example: Configuration Manager

```zig
const Config = struct {
    settings: std.StringArrayHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Config {
        return .{
            .settings = std.StringArrayHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn set(self: *Config, key: []const u8, value: []const u8) !void {
        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);

        // Free old value if key exists
        if (self.settings.get(key)) |old_value| {
            self.allocator.free(old_value);
        }

        try self.settings.put(key, owned_value);
    }

    pub fn get(self: *Config, key: []const u8) ?[]const u8 {
        return self.settings.get(key);
    }

    pub fn deinit(self: *Config) void {
        // Free all values
        for (self.settings.values()) |value| {
            self.allocator.free(value);
        }
        self.settings.deinit();
    }
};
```

### Performance Considerations

- ArrayHashMap is slightly slower for lookups (still O(1) average)
- Better cache locality often compensates for extra indirection
- Index-based access is O(1)
- Insertion and deletion maintain order (may require memory moves)

## See Also

- Recipe 1.6: Mapping Keys to Multiple Values
- Recipe 1.8: Calculating with Dictionaries
- Recipe 1.9: Finding Commonalities in Sets

Full compilable example: `code/02-core/01-data-structures/recipe_1_7.zig`
