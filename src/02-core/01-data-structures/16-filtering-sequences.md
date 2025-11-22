## Problem

You want to filter elements from a collection based on some criteria, keeping only items that match a condition.

## Solution

Zig doesn't have built-in filter functions like Python or JavaScript. Instead, you create filtering functions that work with slices and ArrayLists using explicit loops. This gives you full control and makes the performance characteristics clear.

Here's a generic filter function that creates a new ArrayList:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_16.zig:basic_filter}}
    return @mod(n, 2) == 0;
}

// Usage
const numbers = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
var evens = try filter(i32, allocator, &numbers, isEven);
defer evens.deinit(allocator);
// evens.items is now [2, 4, 6, 8, 10]
```

For better performance when you don't need the original list, use in-place filtering:

```zig
pub fn filterInPlace(
    comptime T: type,
    list: *ArrayList(T),
    predicate: FilterFn(T),
) void {
    var write_idx: usize = 0;

    for (list.items) |item| {
        if (predicate(item)) {
            list.items[write_idx] = item;
            write_idx += 1;
        }
    }

    list.shrinkRetainingCapacity(write_idx);
}

// Usage
var list = ArrayList(i32){};
try list.appendSlice(allocator, &[_]i32{ 1, 2, 3, 4, 5, 6 });
filterInPlace(i32, &list, isEven);
// list now contains [2, 4, 6]
```

## Discussion

### Predicate Functions

Predicate functions take a single item and return `true` if it should be kept. You can define them as standalone functions or use anonymous structs for closure-like behavior:

```zig
// Standalone function
fn isPositive(n: i32) bool {
    return n > 0;
}

// Closure-like function with captured context
const greaterThan = struct {
    fn pred(n: i32) bool {
        return n > 5;
    }
}.pred;
```

### Memory Management

The `filter` function allocates a new ArrayList, so the caller must call `deinit()` when done. The `errdefer` ensures cleanup if an allocation fails during filtering.

For in-place filtering, no allocation occurs (besides what's already in the ArrayList), making it more efficient when you don't need the original data.

### Performance Considerations

- **filter()** - O(n) time, O(n) space. Creates a new list, original unchanged.
- **filterInPlace()** - O(n) time, O(1) extra space. Modifies the list in place, more efficient.

Both approaches use explicit loops, making it clear this is an O(n) operation. There's no hidden iteration or lazy evaluation.

### Working with Complex Types

Filtering works with any type, including structs:

```zig
const Person = struct {
    name: []const u8,
    age: u32,
};

const isAdult = struct {
    fn pred(p: Person) bool {
        return p.age >= 18;
    }
}.pred;

var adults = try filter(Person, allocator, people, isAdult);
defer adults.deinit(allocator);
```

### Idiomatic Zig

Zig emphasizes explicit control flow and no hidden allocations. Rather than method chaining like `items.filter().map().take()`, you write clear loops or compose simple functions. This makes code easier to reason about and performance characteristics obvious.

The pattern shown here - passing allocators explicitly, using `errdefer` for cleanup, and providing both allocating and in-place variants - is idiomatic Zig style.
