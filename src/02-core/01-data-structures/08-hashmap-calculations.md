# Calculating with Dictionaries

## Problem

You need to perform calculations on dictionary values like finding minimums, maximums, sums, or filtering entries based on conditions.

## Solution

Iterate over the map's values or entries and apply calculations. Zig's for loops make this straightforward:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_8.zig:min_max_values}}
```

## Discussion

### Finding Min/Max Values

Find the minimum or maximum value in a map:

```zig
fn findMax(comptime T: type, map: std.AutoHashMap([]const u8, T)) ?T {
    if (map.count() == 0) return null;

    var max_value = map.values()[0];
    for (map.values()[1..]) |value| {
        if (value > max_value) {
            max_value = value;
        }
    }
    return max_value;
}

// Or find the key with max value
fn findKeyWithMaxValue(map: std.AutoHashMap([]const u8, i32)) ?[]const u8 {
    if (map.count() == 0) return null;

    var max_key = map.keys()[0];
    var max_value = map.values()[0];

    for (map.keys()[1..], map.values()[1..]) |key, value| {
        if (value > max_value) {
            max_key = key;
            max_value = value;
        }
    }
    return max_key;
}
```

### Summing and Averaging

Calculate totals and averages:

```zig
fn sum(map: std.AutoHashMap([]const u8, f64)) f64 {
    var total: f64 = 0.0;
    for (map.values()) |value| {
        total += value;
    }
    return total;
}

fn average(map: std.AutoHashMap([]const u8, f64)) f64 {
    if (map.count() == 0) return 0.0;
    return sum(map) / @as(f64, @floatFromInt(map.count()));
}
```

### Filtering Maps

Create a new map with entries matching a condition:

```zig
fn filterByValue(
    allocator: std.mem.Allocator,
    map: std.AutoHashMap([]const u8, i32),
    min_value: i32,
) !std.AutoHashMap([]const u8, i32) {
    var result = std.AutoHashMap([]const u8, i32).init(allocator);
    errdefer result.deinit();

    var it = map.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.* >= min_value) {
            try result.put(entry.key_ptr.*, entry.value_ptr.*);
        }
    }
    return result;
}
```

### Transforming Values

Apply a function to all values:

```zig
fn multiplyValues(map: *std.AutoHashMap([]const u8, i32), multiplier: i32) void {
    for (map.values()) |*value| {
        value.* *= multiplier;
    }
}

// Or create a new map with transformed values
fn mapValues(
    allocator: std.mem.Allocator,
    map: std.AutoHashMap([]const u8, i32),
    comptime transform: fn(i32) i32,
) !std.AutoHashMap([]const u8, i32) {
    var result = std.AutoHashMap([]const u8, i32).init(allocator);
    errdefer result.deinit();

    var it = map.iterator();
    while (it.next()) |entry| {
        try result.put(entry.key_ptr.*, transform(entry.value_ptr.*));
    }
    return result;
}
```

### Counting Occurrences

Build frequency maps:

```zig
fn countOccurrences(
    allocator: std.mem.Allocator,
    items: []const []const u8,
) !std.StringHashMap(usize) {
    var counts = std.StringHashMap(usize).init(allocator);
    errdefer counts.deinit();

    for (items) |item| {
        const entry = try counts.getOrPut(item);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
        } else {
            entry.value_ptr.* = 1;
        }
    }
    return counts;
}
```

### Merging Maps

Combine two maps with a merge strategy:

```zig
// Simple merge - second map overwrites first
fn merge(
    allocator: std.mem.Allocator,
    map1: std.AutoHashMap([]const u8, i32),
    map2: std.AutoHashMap([]const u8, i32),
) !std.AutoHashMap([]const u8, i32) {
    var result = try map1.clone();
    errdefer result.deinit();

    var it = map2.iterator();
    while (it.next()) |entry| {
        try result.put(entry.key_ptr.*, entry.value_ptr.*);
    }
    return result;
}

// Merge with custom combining function
fn mergeWith(
    allocator: std.mem.Allocator,
    map1: std.AutoHashMap([]const u8, i32),
    map2: std.AutoHashMap([]const u8, i32),
    comptime combine: fn(i32, i32) i32,
) !std.AutoHashMap([]const u8, i32) {
    var result = try map1.clone();
    errdefer result.deinit();

    var it = map2.iterator();
    while (it.next()) |entry| {
        if (result.getPtr(entry.key_ptr.*)) |existing| {
            existing.* = combine(existing.*, entry.value_ptr.*);
        } else {
            try result.put(entry.key_ptr.*, entry.value_ptr.*);
        }
    }
    return result;
}
```

### Inverting Maps

Swap keys and values:

```zig
fn invert(
    allocator: std.mem.Allocator,
    map: std.AutoHashMap([]const u8, i32),
) !std.AutoHashMap(i32, []const u8) {
    var result = std.AutoHashMap(i32, []const u8).init(allocator);
    errdefer result.deinit();

    var it = map.iterator();
    while (it.next()) |entry| {
        try result.put(entry.value_ptr.*, entry.key_ptr.*);
    }
    return result;
}
```

### Grouping by Value

Create a multimap grouped by a property:

```zig
fn groupBy(
    allocator: std.mem.Allocator,
    items: []const i32,
    comptime keyFn: fn(i32) []const u8,
) !std.StringHashMap(std.ArrayList(i32)) {
    var groups = std.StringHashMap(std.ArrayList(i32)).init(allocator);
    errdefer {
        var it = groups.valueIterator();
        while (it.next()) |list| {
            list.deinit();
        }
        groups.deinit();
    }

    for (items) |item| {
        const key = keyFn(item);
        const entry = try groups.getOrPut(key);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(i32).init(allocator);
        }
        try entry.value_ptr.append(item);
    }
    return groups;
}
```

### Top N Items

Find the N items with largest values:

```zig
const Entry = struct {
    key: []const u8,
    value: i32,
};

fn topN(
    allocator: std.mem.Allocator,
    map: std.AutoHashMap([]const u8, i32),
    n: usize,
) ![]Entry {
    // Collect all entries
    var entries = try allocator.alloc(Entry, map.count());
    errdefer allocator.free(entries);

    var i: usize = 0;
    var it = map.iterator();
    while (it.next()) |entry| : (i += 1) {
        entries[i] = .{
            .key = entry.key_ptr.*,
            .value = entry.value_ptr.*,
        };
    }

    // Sort by value descending
    std.mem.sort(Entry, entries, {}, struct {
        fn lessThan(_: void, a: Entry, b: Entry) bool {
            return a.value > b.value;
        }
    }.lessThan);

    // Return top N
    const count = @min(n, entries.len);
    return entries[0..count];
}
```

### Common Patterns

```zig
// Check if all values meet a condition
fn allValues(map: std.AutoHashMap([]const u8, i32), min: i32) bool {
    for (map.values()) |value| {
        if (value < min) return false;
    }
    return true;
}

// Check if any value meets a condition
fn anyValue(map: std.AutoHashMap([]const u8, i32), target: i32) bool {
    for (map.values()) |value| {
        if (value == target) return true;
    }
    return false;
}

// Count values matching condition
fn countWhere(map: std.AutoHashMap([]const u8, i32), min: i32) usize {
    var count: usize = 0;
    for (map.values()) |value| {
        if (value >= min) count += 1;
    }
    return count;
}
```

## See Also

- Recipe 1.6: Mapping Keys to Multiple Values
- Recipe 1.7: Keeping Dictionaries in Order
- Recipe 1.4: Finding Largest/Smallest N Items

Full compilable example: `code/02-core/01-data-structures/recipe_1_8.zig`
