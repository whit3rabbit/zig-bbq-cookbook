# Removing Duplicates While Maintaining Order

## Problem

You have a sequence with duplicate elements and want to remove them while keeping the first occurrence of each element in its original position.

## Solution

Use a HashMap to track seen elements combined with an ArrayList to build the deduplicated result:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_10.zig:remove_duplicates}}
```

## Discussion

### How It Works

The algorithm uses two data structures:
1. A HashMap (`seen`) to track which elements we've encountered (O(1) lookup)
2. An ArrayList (`result`) to build the deduplicated sequence in order

For each element, we check if it's in the `seen` set. If not, we add it to both the set and the result list.

### Generic Function

The `removeDuplicates` function works with any type that can be hashed:

```zig
fn removeDuplicates(
    comptime T: type,
    allocator: std.mem.Allocator,
    items: []const T,
) ![]T {
    var seen = std.AutoHashMap(T, void).init(allocator);
    defer seen.deinit();

    var result = std.ArrayList(T).init(allocator);
    errdefer result.deinit();

    for (items) |item| {
        if (!seen.contains(item)) {
            try seen.put(item, {});
            try result.append(item);
        }
    }

    return result.toOwnedSlice();
}
```

### String Deduplication

For strings, use `StringHashMap` to avoid hashing issues:

```zig
fn removeDuplicateStrings(
    allocator: std.mem.Allocator,
    strings: []const []const u8,
) ![][]const u8 {
    var seen = std.StringHashMap(void).init(allocator);
    defer seen.deinit();

    var result = std.ArrayList([]const u8).init(allocator);
    errdefer result.deinit();

    for (strings) |str| {
        if (!seen.contains(str)) {
            try seen.put(str, {});
            try result.append(str);
        }
    }

    return result.toOwnedSlice();
}
```

### In-Place Deduplication

For slices where you can modify the data in place:

```zig
fn deduplicateInPlace(
    comptime T: type,
    allocator: std.mem.Allocator,
    items: []T,
) !usize {
    var seen = std.AutoHashMap(T, void).init(allocator);
    defer seen.deinit();

    var write_pos: usize = 0;
    for (items) |item| {
        if (!seen.contains(item)) {
            try seen.put(item, {});
            items[write_pos] = item;
            write_pos += 1;
        }
    }

    return write_pos; // New length
}
```

This modifies the slice in place and returns the new length. The remaining elements are undefined but can be ignored.

### Deduplication by Field

Remove duplicates based on a specific struct field:

```zig
const Person = struct {
    id: u32,
    name: []const u8,
    age: u8,
};

fn removeDuplicateIds(
    allocator: std.mem.Allocator,
    people: []const Person,
) ![]Person {
    var seen = std.AutoHashMap(u32, void).init(allocator);
    defer seen.deinit();

    var result = std.ArrayList(Person).init(allocator);
    errdefer result.deinit();

    for (people) |person| {
        if (!seen.contains(person.id)) {
            try seen.put(person.id, {});
            try result.append(person);
        }
    }

    return result.toOwnedSlice();
}
```

### Keeping Last Occurrence Instead

If you want to keep the last occurrence rather than the first:

```zig
fn keepLastOccurrence(
    comptime T: type,
    allocator: std.mem.Allocator,
    items: []const T,
) ![]T {
    var last_index = std.AutoHashMap(T, usize).init(allocator);
    defer last_index.deinit();

    // Record the last index of each element
    for (items, 0..) |item, i| {
        try last_index.put(item, i);
    }

    // Build result keeping only last occurrences in order
    var result = std.ArrayList(T).init(allocator);
    errdefer result.deinit();

    for (items, 0..) |item, i| {
        if (last_index.get(item).? == i) {
            try result.append(item);
        }
    }

    return result.toOwnedSlice();
}
```

### Custom Equality for Complex Types

For types that need custom equality:

```zig
const Point = struct {
    x: f32,
    y: f32,

    pub fn eql(self: Point, other: Point) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn hash(self: Point) u64 {
        var hasher = std.hash.Wyhash.init(0);
        std.hash.autoHash(&hasher, self.x);
        std.hash.autoHash(&hasher, self.y);
        return hasher.final();
    }
};

fn removeDuplicatePoints(
    allocator: std.mem.Allocator,
    points: []const Point,
) ![]Point {
    const Context = struct {
        pub fn hash(_: @This(), p: Point) u64 {
            return p.hash();
        }
        pub fn eql(_: @This(), a: Point, b: Point) bool {
            return a.eql(b);
        }
    };

    var seen = std.HashMap(Point, void, Context, std.hash_map.default_max_load_percentage).init(allocator);
    defer seen.deinit();

    var result = std.ArrayList(Point).init(allocator);
    errdefer result.deinit();

    for (points) |point| {
        if (!seen.contains(point)) {
            try seen.put(point, {});
            try result.append(point);
        }
    }

    return result.toOwnedSlice();
}
```

### Performance Characteristics

- Time complexity: O(n) average case, O(n²) worst case (hash collisions)
- Space complexity: O(n) for the HashMap and result ArrayList
- Memory efficient: only stores unique elements in result
- Preserves order: maintains the sequence of first occurrences

### Practical Example: Cleaning User Input

```zig
fn cleanTagList(
    allocator: std.mem.Allocator,
    tags: []const []const u8,
) ![][]const u8 {
    var seen = std.StringHashMap(void).init(allocator);
    defer seen.deinit();

    var result = std.ArrayList([]const u8).init(allocator);
    errdefer result.deinit();

    for (tags) |tag| {
        // Skip empty tags
        if (tag.len == 0) continue;

        // Normalize to lowercase for comparison
        const lower = try std.ascii.allocLowerString(allocator, tag);
        defer allocator.free(lower);

        if (!seen.contains(lower)) {
            try seen.put(try allocator.dupe(u8, lower), {});
            try result.append(try allocator.dupe(u8, lower));
        }
    }

    return result.toOwnedSlice();
}
```

### When Order Doesn't Matter

If you don't care about order, you can just convert to a set and back:

```zig
fn removeDuplicatesUnordered(
    comptime T: type,
    allocator: std.mem.Allocator,
    items: []const T,
) ![]T {
    var set = std.AutoHashMap(T, void).init(allocator);
    defer set.deinit();

    for (items) |item| {
        try set.put(item, {});
    }

    var result = try allocator.alloc(T, set.count());
    errdefer allocator.free(result);

    var i: usize = 0;
    var it = set.keyIterator();
    while (it.next()) |key| : (i += 1) {
        result[i] = key.*;
    }

    return result;
}
```

## See Also

- Recipe 1.9: Finding Commonalities in Sets
- Recipe 1.7: Keeping Dictionaries in Order
- Recipe 1.11: Naming Slices

Full compilable example: `code/02-core/01-data-structures/recipe_1_10.zig`
