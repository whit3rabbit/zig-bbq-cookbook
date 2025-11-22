## Problem

You want to create a new dictionary (hashmap) that contains only certain entries from an existing dictionary, based on specific keys or value criteria.

## Solution

Zig provides several approaches for extracting dictionary subsets. You can filter by specific keys, by value predicates, or by examining key-value pairs together.

### Extract by Specific Keys

The most common case is extracting entries for a known set of keys:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_17.zig:extract_by_keys}}

    return result;
}

// Usage
var prices = std.StringHashMap(f32).init(allocator);
try prices.put("apple", 1.50);
try prices.put("banana", 0.75);
try prices.put("orange", 1.25);
try prices.put("grape", 2.00);

const wanted = [_][]const u8{ "apple", "orange" };
var subset = try extractStringKeys(f32, allocator, prices, &wanted);
defer subset.deinit();
// subset now contains only "apple" and "orange"
```

### Extract by Value Predicate

Filter entries based on their values:

```zig
pub fn extractStringByValue(
    comptime V: type,
    allocator: std.mem.Allocator,
    source: std.StringHashMap(V),
    predicate: *const fn (V) bool,
) !std.StringHashMap(V) {
    var result = std.StringHashMap(V).init(allocator);
    errdefer result.deinit();

    var iter = source.iterator();
    while (iter.next()) |entry| {
        if (predicate(entry.value_ptr.*)) {
            try result.put(entry.key_ptr.*, entry.value_ptr.*);
        }
    }

    return result;
}

// Usage: extract high scores
var scores = std.StringHashMap(i32).init(allocator);
try scores.put("Alice", 95);
try scores.put("Bob", 67);
try scores.put("Charlie", 88);

const isPassing = struct {
    fn pred(score: i32) bool {
        return score >= 80;
    }
}.pred;

var passing = try extractStringByValue(i32, allocator, scores, isPassing);
defer passing.deinit();
// passing contains Alice (95) and Charlie (88)
```

### Extract by Key-Value Pair

Sometimes you need to examine both key and value together:

```zig
pub fn extractStringByPair(
    comptime V: type,
    allocator: std.mem.Allocator,
    source: std.StringHashMap(V),
    predicate: *const fn ([]const u8, V) bool,
) !std.StringHashMap(V) {
    var result = std.StringHashMap(V).init(allocator);
    errdefer result.deinit();

    var iter = source.iterator();
    while (iter.next()) |entry| {
        if (predicate(entry.key_ptr.*, entry.value_ptr.*)) {
            try result.put(entry.key_ptr.*, entry.value_ptr.*);
        }
    }

    return result;
}

// Usage: items needing restock, but exclude specific items
var inventory = std.StringHashMap(i32).init(allocator);
try inventory.put("apples", 50);
try inventory.put("bananas", 5);
try inventory.put("grapes", 8);
try inventory.put("melons", 2);

const needsRestock = struct {
    fn pred(name: []const u8, count: i32) bool {
        return count < 10 and !std.mem.eql(u8, name, "melons");
    }
}.pred;

var lowStock = try extractStringByPair(i32, allocator, inventory, needsRestock);
defer lowStock.deinit();
// lowStock contains bananas (5) and grapes (8), but not melons
```

## Discussion

### String Keys vs. Integer Keys

Zig distinguishes between `StringHashMap` (for `[]const u8` keys) and `AutoHashMap` (for other types). This is because string hashing requires special handling to hash the contents rather than the pointer.

For integer or other hashable keys:

```zig
pub fn extractByKeys(
    comptime K: type,
    comptime V: type,
    allocator: std.mem.Allocator,
    source: anytype,
    keys: []const K,
) !std.AutoHashMap(K, V) {
    var result = std.AutoHashMap(K, V).init(allocator);
    errdefer result.deinit();

    for (keys) |key| {
        if (source.get(key)) |value| {
            try result.put(key, value);
        }
    }

    return result;
}
```

### Memory Management

All extraction functions allocate a new hashmap, so you must call `deinit()` on the result. The `errdefer` ensures proper cleanup if an error occurs during extraction.

If a requested key doesn't exist in the source map, it's simply skipped (no error is raised). This makes the functions robust when working with potentially missing keys.

### Performance

Extraction is O(n) where n is the number of items being extracted (or examined in the case of predicates). For large maps, consider whether you really need a new map or if iterating over the original with a predicate would suffice.

### Predicates and Closures

Since Zig doesn't have traditional closures, use anonymous structs to create predicate functions:

```zig
const min_score = 80;
const isPassing = struct {
    fn pred(score: i32) bool {
        return score >= 80; // Can't capture min_score
    }
}.pred;
```

For true closure-like behavior with captured state, you'd need to create a struct that holds the context and pass it as a parameter.

### Working with Complex Values

The extraction functions work with any value type, including structs:

```zig
const Person = struct {
    name: []const u8,
    age: u32,
    score: f32,
};

const highScorers = struct {
    fn pred(p: Person) bool {
        return p.score >= 85.0;
    }
}.pred;

var result = try extractByValue(u32, Person, allocator, people, highScorers);
```

### Why Not Method Chaining?

Unlike languages with method chaining (`.filter().map().reduce()`), Zig prefers explicit function calls. This makes allocations visible, error handling clear, and performance characteristics obvious. Each extraction creates a new map, which is explicit in the code.
