## Problem

You have multiple hashmaps (dictionaries) and need to combine them into a single map, with control over how to handle key conflicts.

## Solution

Zig provides several strategies for combining hashmaps, from simple overwriting to custom conflict resolution.

### Basic Merge with Overwrite

The simplest approach: later maps win on conflicts:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_20.zig:merge_overwrite}}
```

### Merge with Intersection

Keep only keys that exist in both maps:

```zig
pub fn mergeIntersection(
    comptime K: type,
    comptime V: type,
    allocator: std.mem.Allocator,
    map1: std.AutoHashMap(K, V),
    map2: std.AutoHashMap(K, V),
) !std.AutoHashMap(K, V) {
    var result = std.AutoHashMap(K, V).init(allocator);
    errdefer result.deinit();

    var iter1 = map1.iterator();
    while (iter1.next()) |entry| {
        // Only add if key exists in both maps
        if (map2.contains(entry.key_ptr.*)) {
            try result.put(entry.key_ptr.*, entry.value_ptr.*);
        }
    }

    return result;
}
```

### Merge with Custom Conflict Resolution

For full control over how conflicts are resolved:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_20.zig:merge_with_resolver}}
```

### Merge Many Maps at Once

Combine more than two maps efficiently:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_20.zig:merge_many}}
```

### Chained Iterator (No Allocation)

If you don't need a merged map but just want to iterate over all entries:

```zig
pub fn ChainedIterator(comptime K: type, comptime V: type) type {
    return struct {
        maps: []const std.AutoHashMap(K, V),
        current_map: usize = 0,
        current_iter: ?std.AutoHashMap(K, V).Iterator = null,

        const Self = @This();

        pub fn init(maps: []const std.AutoHashMap(K, V)) Self {
            var self = Self{ .maps = maps };
            if (maps.len > 0) {
                self.current_iter = maps[0].iterator();
            }
            return self;
        }

        pub fn next(self: *Self) ?struct { key: K, value: V } {
            while (self.current_map < self.maps.len) {
                if (self.current_iter) |*iter| {
                    if (iter.next()) |entry| {
                        return .{
                            .key = entry.key_ptr.*,
                            .value = entry.value_ptr.*,
                        };
                    }
                }

                // Move to next map
                self.current_map += 1;
                if (self.current_map < self.maps.len) {
                    self.current_iter = self.maps[self.current_map].iterator();
                }
            }

            return null;
        }
    };
}

// Usage
const maps = [_]std.AutoHashMap(u32, i32){ map1, map2, map3 };
var iter = ChainedIterator(u32, i32).init(&maps);

while (iter.next()) |entry| {
    // Process entry.key and entry.value
}
```

## Discussion

### Conflict Resolution Strategies

Different scenarios call for different conflict handling:

**Last Wins (Overwrite):**
- Use when later data should replace earlier data
- Configuration precedence (user config overrides defaults)
- Updates and patches

**Sum/Combine:**
```zig
const sumValues = struct {
    fn f(a: i32, b: i32) i32 {
        return a + b;
    }
}.f;
```
- Merging inventory from multiple warehouses
- Aggregating statistics
- Combining counts

**Max/Min:**
```zig
const maxValue = struct {
    fn f(a: i32, b: i32) i32 {
        return @max(a, b);
    }
}.f;
```
- Taking highest priority
- Latest timestamp wins
- Maximum stock levels

**First Wins:**
```zig
// Simply reverse the order of maps
var merged = try mergeOverwrite(K, V, allocator, map2, map1);
```

### Memory Management

All merge functions allocate a new hashmap. Remember to call `deinit()`:

```zig
var merged = try mergeWith(K, V, allocator, map1, map2, resolveFn);
defer merged.deinit();
```

The `errdefer` in merge functions ensures cleanup if allocation fails partway through.

### Working with Complex Values

Merge functions work with any value type, including structs:

```zig
const Item = struct {
    quantity: i32,
    price: f32,
};

// Merge by summing quantities
const sumQuantities = struct {
    fn f(a: Item, b: Item) Item {
        return .{
            .quantity = a.quantity + b.quantity,
            .price = a.price, // Keep first price
        };
    }
}.f;

var merged = try mergeWith(u32, Item, allocator, warehouse1, warehouse2, sumQuantities);
```

### Performance Considerations

**Merging Maps:**
- O(n + m) time where n and m are map sizes
- O(n + m) space for result
- Each entry is copied

**Chained Iterator:**
- O(1) space (no allocation)
- Lazy evaluation
- Duplicates if keys overlap in multiple maps
- Use when you don't need a permanent merged map

### When to Use Each Approach

**Use `mergeOverwrite`** when you simply need all entries with later values winning.

**Use `mergeIntersection`** when you only want entries present in all maps.

**Use `mergeWith`** when you need custom logic for handling conflicts (sum, max, min, etc.).

**Use `mergeMany`** when combining more than two maps at once.

**Use `ChainedIterator`** when you just need to iterate without creating a new map.

### Comparison with Other Languages

Unlike Python's `{**dict1, **dict2}` or JavaScript's `{...obj1, ...obj2}`, Zig requires explicit allocation and error handling. This makes the cost visible and ensures you handle out-of-memory conditions.

The functional approach also allows for type-safe, compile-time-verified conflict resolution strategies.

### Alternative: In-Place Merge

If you can modify one of the original maps:

```zig
// Merge map2 into map1 (modifies map1)
var iter = map2.iterator();
while (iter.next()) |entry| {
    try map1.put(entry.key_ptr.*, entry.value_ptr.*);
}
```

This is more efficient but destructive - use when you no longer need the original map1.
