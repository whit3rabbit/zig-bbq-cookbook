# Mapping Keys to Multiple Values

## Problem

You need a dictionary-like data structure where each key can have multiple values associated with it (a multimap or one-to-many mapping).

## Solution

Use a HashMap where the values are ArrayLists. Zig doesn't have a built-in multimap, but it's straightforward to build one:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_6.zig:multimap_impl}}
```

## Discussion

### Why Use This Pattern

Multimaps are useful when you have natural one-to-many relationships:
- **Tags to items**: "red" → [apple, cherry, rose]
- **Category to products**: "electronics" → [phone, laptop, tablet]
- **Author to books**: "Alice" → [book1, book2, book3]
- **Date to events**: "2024-01-15" → [event1, event2]

### Using StringArrayHashMap

For string keys, use `StringArrayHashMap` which handles string comparison properly:

```zig
const Tags = struct {
    tags: std.StringArrayHashMap(std.ArrayList([]const u8)),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Tags {
        return .{
            .tags = std.StringArrayHashMap(std.ArrayList([]const u8)).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn addTag(self: *Tags, tag: []const u8, item: []const u8) !void {
        const entry = try self.tags.getOrPut(tag);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList([]const u8){};
        }
        try entry.value_ptr.append(self.allocator, item);
    }

    pub fn getItems(self: *Tags, tag: []const u8) ?[]const []const u8 {
        if (self.tags.get(tag)) |list| {
            return list.items;
        }
        return null;
    }

    pub fn deinit(self: *Tags) void {
        var it = self.tags.valueIterator();
        while (it.next()) |list| {
            list.deinit(self.allocator);
        }
        self.tags.deinit();
    }
};
```

### Memory Management

The key challenge is properly freeing all ArrayLists when done:

```zig
pub fn deinit(self: *Self) void {
    // Must iterate and free each ArrayList
    var it = self.map.valueIterator();
    while (it.next()) |list| {
        list.deinit(self.allocator);
    }
    // Then free the map itself
    self.map.deinit();
}
```

### Common Operations

```zig
// Add single value
try multimap.add("fruits", "apple");

// Add multiple values to same key
try multimap.add("fruits", "banana");
try multimap.add("fruits", "cherry");

// Get all values for a key
if (multimap.get("fruits")) |items| {
    for (items) |item| {
        std.debug.print("{s}\n", .{item});
    }
}

// Check if key exists
const has_fruits = multimap.get("fruits") != null;

// Count values for a key
const fruit_count = if (multimap.get("fruits")) |items| items.len else 0;
```

### Removing Values

Zig multimaps provide two removal strategies with different trade-offs:

**Fast removal (breaks order):**

```zig
pub fn remove(self: *Self, key: K, value: V) bool {
    if (self.map.getPtr(key)) |list| {
        for (list.items, 0..) |item, i| {
            if (item == value) {
                _ = list.swapRemove(i);  // O(1) removal
                return true;
            }
        }
    }
    return false;
}
```

`swapRemove` is O(1) but replaces the removed item with the last item in the list, breaking insertion order. Use this when order doesn't matter or you need maximum performance.

**Order-preserving removal:**

```zig
pub fn removeOrdered(self: *Self, key: K, value: V) bool {
    if (self.map.getPtr(key)) |list| {
        for (list.items, 0..) |item, i| {
            if (item == value) {
                _ = list.orderedRemove(i);  // O(n) removal
                return true;
            }
        }
    }
    return false;
}
```

`orderedRemove` is O(n) but preserves insertion order by shifting elements. Use this for:
- FIFO queues where order matters
- Chronological lists (events, timestamps)
- Any case where insertion order is significant

**Note:** Both operations are already O(n) for the search phase, so the performance difference is only in the constant factors of the removal itself.

To remove all values for a key:

```zig
pub fn removeKey(self: *Self, key: K) void {
    if (self.map.fetchRemove(key)) |entry| {
        var list = entry.value;
        list.deinit(self.allocator);
    }
}
```

### Alternative: Array of Tuples

For small datasets, a simple array of key-value pairs might be simpler:

```zig
const Entry = struct { key: []const u8, value: i32 };
var entries = std.ArrayList(Entry).init(allocator);

// Add
try entries.append(.{ .key = "score", .value = 100 });

// Get all values for key
for (entries.items) |entry| {
    if (std.mem.eql(u8, entry.key, "score")) {
        std.debug.print("{d}\n", .{entry.value});
    }
}
```

This is O(n) for lookups but uses less memory and is simpler for small collections.

### Iteration

Iterate over all keys and their values:

```zig
var it = multimap.map.iterator();
while (it.next()) |entry| {
    std.debug.print("Key: {}, Values: ", .{entry.key_ptr.*});
    for (entry.value_ptr.items) |value| {
        std.debug.print("{} ", .{value});
    }
    std.debug.print("\n", .{});
}
```

## See Also

- Recipe 1.7: Keeping Dictionaries in order (ArrayHashMap variants)
- Recipe 1.8: Calculating with dictionaries
- Recipe 1.15: Grouping records together based on a field

Full compilable example: `code/02-core/01-data-structures/recipe_1_6.zig`
