# Finding Commonalities in Sets

## Problem

You need to find common elements between collections, perform set operations like union and intersection, or check if one set is a subset of another.

## Solution

Zig doesn't have a dedicated Set type, but HashMap with void values works perfectly as a set:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_9.zig:basic_set}}
```

## Discussion

### Creating Sets

Use `HashMap` or `StringHashMap` with `void` values:

```zig
// Integer set
var numbers = std.AutoHashMap(i32, void).init(allocator);
defer numbers.deinit();

try numbers.put(1, {});
try numbers.put(2, {});
try numbers.put(3, {});

// String set
var words = std.StringHashMap(void).init(allocator);
defer words.deinit();

try words.put("hello", {});
try words.put("world", {});
```

### Union (A ∪ B)

Combine two sets into one containing all elements from both:

```zig
fn unionSets(
    allocator: std.mem.Allocator,
    set1: std.AutoHashMap(i32, void),
    set2: std.AutoHashMap(i32, void),
) !std.AutoHashMap(i32, void) {
    var result = std.AutoHashMap(i32, void).init(allocator);
    errdefer result.deinit();

    // Add all elements from set1
    var it1 = set1.keyIterator();
    while (it1.next()) |key| {
        try result.put(key.*, {});
    }

    // Add all elements from set2
    var it2 = set2.keyIterator();
    while (it2.next()) |key| {
        try result.put(key.*, {});
    }

    return result;
}
```

### Intersection (A ∩ B)

Find elements common to both sets:

```zig
fn intersectionSets(
    allocator: std.mem.Allocator,
    set1: std.AutoHashMap(i32, void),
    set2: std.AutoHashMap(i32, void),
) !std.AutoHashMap(i32, void) {
    var result = std.AutoHashMap(i32, void).init(allocator);
    errdefer result.deinit();

    // Add elements that exist in both sets
    var it = set1.keyIterator();
    while (it.next()) |key| {
        if (set2.contains(key.*)) {
            try result.put(key.*, {});
        }
    }

    return result;
}
```

### Difference (A - B)

Find elements in the first set but not the second:

```zig
fn differenceSets(
    allocator: std.mem.Allocator,
    set1: std.AutoHashMap(i32, void),
    set2: std.AutoHashMap(i32, void),
) !std.AutoHashMap(i32, void) {
    var result = std.AutoHashMap(i32, void).init(allocator);
    errdefer result.deinit();

    // Add elements from set1 that aren't in set2
    var it = set1.keyIterator();
    while (it.next()) |key| {
        if (!set2.contains(key.*)) {
            try result.put(key.*, {});
        }
    }

    return result;
}
```

### Symmetric Difference (A △ B)

Find elements in either set but not in both:

```zig
fn symmetricDifference(
    allocator: std.mem.Allocator,
    set1: std.AutoHashMap(i32, void),
    set2: std.AutoHashMap(i32, void),
) !std.AutoHashMap(i32, void) {
    var result = std.AutoHashMap(i32, void).init(allocator);
    errdefer result.deinit();

    // Add elements from set1 not in set2
    var it1 = set1.keyIterator();
    while (it1.next()) |key| {
        if (!set2.contains(key.*)) {
            try result.put(key.*, {});
        }
    }

    // Add elements from set2 not in set1
    var it2 = set2.keyIterator();
    while (it2.next()) |key| {
        if (!set1.contains(key.*)) {
            try result.put(key.*, {});
        }
    }

    return result;
}
```

### Subset and Superset Checks

Check if one set is contained in another:

```zig
// Check if set1 is a subset of set2 (set1 ⊆ set2)
fn isSubset(
    set1: std.AutoHashMap(i32, void),
    set2: std.AutoHashMap(i32, void),
) bool {
    var it = set1.keyIterator();
    while (it.next()) |key| {
        if (!set2.contains(key.*)) {
            return false;
        }
    }
    return true;
}

// Check if set1 is a superset of set2 (set1 ⊇ set2)
fn isSuperset(
    set1: std.AutoHashMap(i32, void),
    set2: std.AutoHashMap(i32, void),
) bool {
    return isSubset(set2, set1);
}

// Check if sets are disjoint (no common elements)
fn isDisjoint(
    set1: std.AutoHashMap(i32, void),
    set2: std.AutoHashMap(i32, void),
) bool {
    var it = set1.keyIterator();
    while (it.next()) |key| {
        if (set2.contains(key.*)) {
            return false;
        }
    }
    return true;
}
```

### Building Sets from Slices

Create sets from existing data:

```zig
fn fromSlice(
    allocator: std.mem.Allocator,
    items: []const i32,
) !std.AutoHashMap(i32, void) {
    var set = std.AutoHashMap(i32, void).init(allocator);
    errdefer set.deinit();

    for (items) |item| {
        try set.put(item, {});
    }

    return set;
}
```

### Converting Sets to Slices

Extract elements as an array:

```zig
fn toSlice(
    allocator: std.mem.Allocator,
    set: std.AutoHashMap(i32, void),
) ![]i32 {
    var result = try allocator.alloc(i32, set.count());
    errdefer allocator.free(result);

    var i: usize = 0;
    var it = set.keyIterator();
    while (it.next()) |key| : (i += 1) {
        result[i] = key.*;
    }

    return result;
}
```

### Practical Example: Finding Common Words

```zig
fn findCommonWords(
    allocator: std.mem.Allocator,
    text1: []const []const u8,
    text2: []const []const u8,
) !std.StringHashMap(void) {
    // Build sets from both texts
    var words1 = std.StringHashMap(void).init(allocator);
    defer words1.deinit();

    for (text1) |word| {
        try words1.put(word, {});
    }

    // Find intersection
    var common = std.StringHashMap(void).init(allocator);
    errdefer common.deinit();

    for (text2) |word| {
        if (words1.contains(word)) {
            try common.put(word, {});
        }
    }

    return common;
}
```

### Performance Considerations

- Set operations are O(n) where n is the size of the sets
- Membership checking is O(1) average case
- Union and intersection create new sets; consider in-place operations for large sets
- For ordered iteration, use `AutoArrayHashMap` instead

### Common Patterns

```zig
// Check if sets are equal
fn areEqual(set1: std.AutoHashMap(i32, void), set2: std.AutoHashMap(i32, void)) bool {
    if (set1.count() != set2.count()) return false;
    return isSubset(set1, set2);
}

// Count common elements
fn countCommon(set1: std.AutoHashMap(i32, void), set2: std.AutoHashMap(i32, void)) usize {
    var count: usize = 0;
    var it = set1.keyIterator();
    while (it.next()) |key| {
        if (set2.contains(key.*)) count += 1;
    }
    return count;
}

// Remove elements in-place
fn removeAll(set: *std.AutoHashMap(i32, void), to_remove: std.AutoHashMap(i32, void)) void {
    var it = to_remove.keyIterator();
    while (it.next()) |key| {
        _ = set.remove(key.*);
    }
}
```

## See Also

- Recipe 1.5: Priority Queues and Heaps
- Recipe 1.7: Keeping Dictionaries in Order
- Recipe 1.8: Calculating with Dictionaries

Full compilable example: `code/02-core/01-data-structures/recipe_1_9.zig`
