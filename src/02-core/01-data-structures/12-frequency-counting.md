# Determining Most Frequently Occurring Items

## Problem

You have a collection of items and need to count how often each item appears, find the most common items, or rank items by frequency.

## Solution

Use a HashMap to count occurrences and either scan for the global maximum or feed counts into a small priority queue when you only care about the top few items:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_12.zig:count_frequencies}}
```

## Discussion

### Basic Frequency Counting

Count occurrences of any hashable type:

```zig
fn countFrequencies(
    comptime T: type,
    allocator: std.mem.Allocator,
    items: []const T,
) !std.AutoHashMap(T, usize) {
    var freq_map = std.AutoHashMap(T, usize).init(allocator);
    errdefer freq_map.deinit();

    for (items) |item| {
        const entry = try freq_map.getOrPut(item);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
        } else {
            entry.value_ptr.* = 1;
        }
    }

    return freq_map;
}
```

### Finding the Most Common Item

Extract the item with highest frequency:

```zig
fn mostCommon(
    comptime T: type,
    freq_map: std.AutoHashMap(T, usize),
) ?struct { item: T, count: usize } {
    if (freq_map.count() == 0) return null;

    var max_item: ?T = null;
    var max_count: usize = 0;

    var it = freq_map.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.* > max_count) {
            max_count = entry.value_ptr.*;
            max_item = entry.key_ptr.*;
        }
    }

    return .{ .item = max_item.?, .count = max_count };
}
```

### Finding Top N Most Common Items

When you only care about a small `N` compared to the number of unique items `M`, sorting the entire list wastes work. Instead, keep a bounded min-heap (priority queue) of size `N`, ejecting the smallest count whenever it overflows. This keeps the complexity at `O(M log N)`:

```zig
const FreqEntry = struct {
    item: []const u8,
    count: usize,
};

fn freqEntryOrder(_: void, a: FreqEntry, b: FreqEntry) std.math.Order {
    return std.math.order(a.count, b.count);
}

fn topN(
    allocator: std.mem.Allocator,
    freq_map: std.StringHashMap(usize),
    n: usize,
) ![]FreqEntry {
    if (n == 0 or freq_map.count() == 0) return allocator.alloc(FreqEntry, 0);

    var queue = std.PriorityQueue(FreqEntry, void, freqEntryOrder).init(allocator, {});
    defer queue.deinit();

    var it = freq_map.iterator();
    while (it.next()) |entry| {
        try queue.add(.{
            .item = entry.key_ptr.*,
            .count = entry.value_ptr.*,
        });
        if (queue.count() > n) {
            _ = queue.remove(); // drop the smallest count
        }
    }

    const result_size = queue.count();
    var result = try allocator.alloc(FreqEntry, result_size);
    while (queue.count() > 0) {
        const idx = queue.count() - 1;
        result[idx] = queue.remove(); // outputs biggest counts last
    }
    return result;
}
```

### Counting with ArrayHashMap for Ordered Iteration

Use ArrayHashMap when you need predictable ordering:

```zig
fn countFrequenciesOrdered(
    allocator: std.mem.Allocator,
    words: []const []const u8,
) !std.StringArrayHashMap(usize) {
    var freq_map = std.StringArrayHashMap(usize).init(allocator);
    errdefer freq_map.deinit();

    for (words) |word| {
        const entry = try freq_map.getOrPut(word);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
        } else {
            entry.value_ptr.* = 1;
        }
    }

    return freq_map;
}
```

### Generic Top N Function

Works with any hashable type, still using the heap trick:

```zig
fn FreqResult(comptime T: type) type {
    return struct {
        item: T,
        count: usize,
    };
}

fn topNGeneric(
    comptime T: type,
    allocator: std.mem.Allocator,
    freq_map: std.AutoHashMap(T, usize),
    n: usize,
) ![]FreqResult(T) {
    if (n == 0 or freq_map.count() == 0) return allocator.alloc(FreqResult(T), 0);

    const Ctx = struct {
        pub fn order(_: void, a: FreqResult(T), b: FreqResult(T)) std.math.Order {
            return std.math.order(a.count, b.count);
        }
    };

    var queue = std.PriorityQueue(FreqResult(T), void, Ctx.order).init(allocator, {});
    defer queue.deinit();

    var it = freq_map.iterator();
    while (it.next()) |entry| {
        try queue.add(.{
            .item = entry.key_ptr.*,
            .count = entry.value_ptr.*,
        });
        if (queue.count() > n) {
            _ = queue.remove();
        }
    }

    const result_size = queue.count();
    var result = try allocator.alloc(FreqResult(T), result_size);
    while (queue.count() > 0) {
        const idx = queue.count() - 1;
        result[idx] = queue.remove();
    }
    return result;
}
```

### Finding Items by Frequency Threshold

Get all items appearing at least N times:

```zig
fn itemsWithMinFrequency(
    comptime T: type,
    allocator: std.mem.Allocator,
    freq_map: std.AutoHashMap(T, usize),
    min_count: usize,
) ![]T {
    var result = std.ArrayList(T){};
    errdefer result.deinit(allocator);

    var it = freq_map.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.* >= min_count) {
            try result.append(allocator, entry.key_ptr.*);
        }
    }

    return result.toOwnedSlice(allocator);
}
```

### Counting Character Frequencies

Specialized for character/byte counting:

```zig
fn countCharFrequencies(
    allocator: std.mem.Allocator,
    text: []const u8,
) !std.AutoHashMap(u8, usize) {
    var freq_map = std.AutoHashMap(u8, usize).init(allocator);
    errdefer freq_map.deinit();

    for (text) |char| {
        const entry = try freq_map.getOrPut(char);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
        } else {
            entry.value_ptr.* = 1;
        }
    }

    return freq_map;
}
```

### Mode (Statistical)

Find the mode (most common value) in a dataset:

```zig
fn mode(
    comptime T: type,
    allocator: std.mem.Allocator,
    data: []const T,
) !?T {
    var freq_map = try countFrequencies(T, allocator, data);
    defer freq_map.deinit();

    if (freq_map.count() == 0) return null;

    var mode_value: ?T = null;
    var max_count: usize = 0;

    var it = freq_map.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.* > max_count) {
            max_count = entry.value_ptr.*;
            mode_value = entry.key_ptr.*;
        }
    }

    return mode_value;
}
```

### Percentile-Based Frequency

Find items in the top P percent by frequency:

```zig
fn topPercentile(
    allocator: std.mem.Allocator,
    freq_map: std.StringHashMap(usize),
    percentile: f32, // 0.0 to 1.0
) ![]FreqEntry {
    // Get total count
    var total: usize = 0;
    var it = freq_map.iterator();
    while (it.next()) |entry| {
        total += entry.value_ptr.*;
    }

    const threshold = @as(usize, @intFromFloat(@as(f32, @floatFromInt(total)) * percentile));

    // Collect entries above threshold
    var result = std.ArrayList(FreqEntry){};
    errdefer result.deinit(allocator);

    it = freq_map.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.* >= threshold) {
            try result.append(allocator, .{
                .item = entry.key_ptr.*,
                .count = entry.value_ptr.*,
            });
        }
    }

    return result.toOwnedSlice(allocator);
}
```

### Frequency Distribution

Get the distribution of frequencies:

```zig
fn frequencyDistribution(
    allocator: std.mem.Allocator,
    freq_map: std.AutoHashMap(i32, usize),
) !std.AutoHashMap(usize, usize) {
    var distribution = std.AutoHashMap(usize, usize).init(allocator);
    errdefer distribution.deinit();

    var it = freq_map.iterator();
    while (it.next()) |entry| {
        const count = entry.value_ptr.*;
        const dist_entry = try distribution.getOrPut(count);
        if (dist_entry.found_existing) {
            dist_entry.value_ptr.* += 1;
        } else {
            dist_entry.value_ptr.* = 1;
        }
    }

    return distribution;
}
```

### Practical Example: Word Frequency Analysis

Analyze text and find most common words:

```zig
fn analyzeText(
    allocator: std.mem.Allocator,
    text: []const u8,
    top_n: usize,
) ![]FreqEntry {
    // Split into words (simple whitespace split)
    var words = std.ArrayList([]const u8){};
    defer words.deinit(allocator);

    var iter = std.mem.tokenizeAny(u8, text, " \t\n\r");
    while (iter.next()) |word| {
        // Convert to lowercase for case-insensitive counting
        const lower = try std.ascii.allocLowerString(allocator, word);
        try words.append(allocator, lower);
    }
    defer {
        for (words.items) |word| {
            allocator.free(word);
        }
    }

    // Count frequencies
    var freq_map = std.StringHashMap(usize).init(allocator);
    defer freq_map.deinit();

    for (words.items) |word| {
        const entry = try freq_map.getOrPut(word);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
        } else {
            entry.value_ptr.* = 1;
        }
    }

    // Get top N
    return topN(allocator, freq_map, top_n);
}
```

### Multiset Operations

Count with multiplicity support:

```zig
const Multiset = struct {
    map: std.AutoHashMap(i32, usize),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Multiset {
        return .{
            .map = std.AutoHashMap(i32, usize).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Multiset) void {
        self.map.deinit();
    }

    pub fn add(self: *Multiset, item: i32, count: usize) !void {
        const entry = try self.map.getOrPut(item);
        if (entry.found_existing) {
            entry.value_ptr.* += count;
        } else {
            entry.value_ptr.* = count;
        }
    }

    pub fn count(self: Multiset, item: i32) usize {
        return self.map.get(item) orelse 0;
    }

    pub fn totalCount(self: Multiset) usize {
        var total: usize = 0;
        var it = self.map.valueIterator();
        while (it.next()) |count| {
            total += count.*;
        }
        return total;
    }
};
```

### Performance Considerations

- Counting is O(n) where n is the number of items
- Finding most common is O(m) where m is the number of unique items
- Sorting for top-N is O(m log m)
- Using ArrayHashMap provides insertion order but slightly slower than HashMap
- For very large datasets, consider streaming approaches

### Common Patterns

```zig
// Increment counter pattern
const entry = try map.getOrPut(key);
if (entry.found_existing) {
    entry.value_ptr.* += 1;
} else {
    entry.value_ptr.* = 1;
}

// Find maximum frequency
var max_count: usize = 0;
var it = map.valueIterator();
while (it.next()) |count| {
    max_count = @max(max_count, count.*);
}

// Filter by frequency
var filtered = std.ArrayList(T){};
var it2 = map.iterator();
while (it2.next()) |entry| {
    if (entry.value_ptr.* >= threshold) {
        try filtered.append(allocator, entry.key_ptr.*);
    }
}
```

## See Also

- Recipe 1.7: Keeping Dictionaries in Order
- Recipe 1.8: Calculating with Dictionaries
- Recipe 1.13: Sorting a List of Structs by a Common Field

Full compilable example: `code/02-core/01-data-structures/recipe_1_12.zig`
