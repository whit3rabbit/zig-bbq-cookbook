# Grouping Records Together Based on a Field

## Problem

You need to group a collection of records by one or more fields, similar to SQL's GROUP BY or creating categories from data.

## Solution

Use a HashMap to collect items into groups by key:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_15.zig:basic_groupby}}
```

## Discussion

### Basic Grouping Function

Create a reusable grouping function:

```zig
fn groupBy(
    comptime T: type,
    comptime KeyType: type,
    allocator: std.mem.Allocator,
    items: []const T,
    keyFn: fn (T) KeyType,
) !std.AutoHashMap(KeyType, std.ArrayList(T)) {
    var groups = std.AutoHashMap(KeyType, std.ArrayList(T)).init(allocator);
    errdefer {
        var it = groups.valueIterator();
        while (it.next()) |list| list.deinit();
        groups.deinit();
    }

    for (items) |item| {
        const key = keyFn(item);
        const entry = try groups.getOrPut(key);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(T).init(allocator);
        }
        try entry.value_ptr.append(item);
    }

    return groups;
}
```

### Grouping by String Field

Group records by string fields:

```zig
fn getRegion(sale: Sale) []const u8 {
    return sale.region;
}

const groups = try groupBy(Sale, []const u8, allocator, &sales, getRegion);
defer {
    var it = groups.valueIterator();
    while (it.next()) |list| list.deinit();
    groups.deinit();
}
```

### Grouping by Multiple Fields

Use composite keys:

```zig
const CompositeKey = struct {
    region: []const u8,
    product: []const u8,

    pub fn hash(self: @This()) u64 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(self.region);
        hasher.update(self.product);
        return hasher.final();
    }

    pub fn eql(a: @This(), b: @This()) bool {
        return std.mem.eql(u8, a.region, b.region) and
            std.mem.eql(u8, a.product, b.product);
    }
};

fn getCompositeKey(sale: Sale) CompositeKey {
    return .{ .region = sale.region, .product = sale.product };
}

const Context = struct {
    pub fn hash(_: @This(), key: CompositeKey) u64 {
        return key.hash();
    }
    pub fn eql(_: @This(), a: CompositeKey, b: CompositeKey) bool {
        return a.eql(b);
    }
};

var groups = std.HashMap(
    CompositeKey,
    std.ArrayList(Sale),
    Context,
    std.hash_map.default_max_load_percentage,
).init(allocator);
defer {
    var it = groups.valueIterator();
    while (it.next()) |list| list.deinit();
    groups.deinit();
}
```

### Grouping with Aggregation

Compute statistics while grouping:

```zig
const GroupStats = struct {
    count: usize,
    total: f32,
    average: f32,

    fn add(self: *@This(), amount: f32) void {
        self.count += 1;
        self.total += amount;
        self.average = self.total / @as(f32, @floatFromInt(self.count));
    }
};

fn groupWithStats(
    allocator: std.mem.Allocator,
    sales: []const Sale,
) !std.StringHashMap(GroupStats) {
    var stats = std.StringHashMap(GroupStats).init(allocator);
    errdefer stats.deinit();

    for (sales) |sale| {
        const entry = try stats.getOrPut(sale.product);
        if (!entry.found_existing) {
            entry.value_ptr.* = .{ .count = 0, .total = 0, .average = 0 };
        }
        entry.value_ptr.add(sale.amount);
    }

    return stats;
}
```

### Grouping with ArrayHashMap for Ordered Groups

Preserve insertion order:

```zig
fn groupByOrdered(
    comptime T: type,
    allocator: std.mem.Allocator,
    items: []const T,
    keyFn: fn (T) []const u8,
) !std.StringArrayHashMap(std.ArrayList(T)) {
    var groups = std.StringArrayHashMap(std.ArrayList(T)).init(allocator);
    errdefer {
        for (groups.values()) |*list| list.deinit();
        groups.deinit();
    }

    for (items) |item| {
        const key = keyFn(item);
        const entry = try groups.getOrPut(key);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(T).init(allocator);
        }
        try entry.value_ptr.append(item);
    }

    return groups;
}
```

### Grouping with Count Only

Save memory when you only need counts:

```zig
fn groupCount(
    comptime KeyType: type,
    allocator: std.mem.Allocator,
    items: anytype,
    keyFn: anytype,
) !std.AutoHashMap(KeyType, usize) {
    var counts = std.AutoHashMap(KeyType, usize).init(allocator);
    errdefer counts.deinit();

    for (items) |item| {
        const key = keyFn(item);
        const entry = try counts.getOrPut(key);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
        } else {
            entry.value_ptr.* = 1;
        }
    }

    return counts;
}
```

### Generic Grouping with Custom Aggregation

Flexible aggregation pattern:

```zig
fn GroupedBy(comptime T: type, comptime KeyType: type, comptime ValueType: type) type {
    return struct {
        map: std.AutoHashMap(KeyType, ValueType),
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .map = std.AutoHashMap(KeyType, ValueType).init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        pub fn aggregate(
            self: *Self,
            items: []const T,
            keyFn: fn (T) KeyType,
            initFn: fn (std.mem.Allocator) anyerror!ValueType,
            updateFn: fn (*ValueType, T) anyerror!void,
        ) !void {
            for (items) |item| {
                const key = keyFn(item);
                const entry = try self.map.getOrPut(key);
                if (!entry.found_existing) {
                    entry.value_ptr.* = try initFn(self.allocator);
                }
                try updateFn(entry.value_ptr, item);
            }
        }

        pub fn get(self: Self, key: KeyType) ?ValueType {
            return self.map.get(key);
        }

        pub fn iterator(self: *Self) std.AutoHashMap(KeyType, ValueType).Iterator {
            return self.map.iterator();
        }
    };
}
```

### Grouping by Enum Values

Use enums as group keys:

```zig
const Priority = enum { low, medium, high };

const Task = struct {
    name: []const u8,
    priority: Priority,
};

fn getPriority(task: Task) Priority {
    return task.priority;
}

const groups = try groupBy(Task, Priority, allocator, &tasks, getPriority);
```

### Nested Grouping

Group by multiple levels:

```zig
fn groupByNested(
    allocator: std.mem.Allocator,
    sales: []const Sale,
) !std.StringHashMap(std.StringHashMap(std.ArrayList(Sale))) {
    var outer = std.StringHashMap(std.StringHashMap(std.ArrayList(Sale))).init(allocator);
    errdefer {
        var outer_it = outer.valueIterator();
        while (outer_it.next()) |inner_map| {
            var inner_it = inner_map.valueIterator();
            while (inner_it.next()) |list| list.deinit();
            inner_map.deinit();
        }
        outer.deinit();
    }

    for (sales) |sale| {
        const outer_entry = try outer.getOrPut(sale.region);
        if (!outer_entry.found_existing) {
            outer_entry.value_ptr.* = std.StringHashMap(std.ArrayList(Sale)).init(allocator);
        }

        const inner_entry = try outer_entry.value_ptr.getOrPut(sale.product);
        if (!inner_entry.found_existing) {
            inner_entry.value_ptr.* = std.ArrayList(Sale).init(allocator);
        }
        try inner_entry.value_ptr.append(sale);
    }

    return outer;
}
```

### Grouping with Transform

Transform items while grouping:

```zig
fn groupAndTransform(
    comptime T: type,
    comptime KeyType: type,
    comptime ValueType: type,
    allocator: std.mem.Allocator,
    items: []const T,
    keyFn: fn (T) KeyType,
    transformFn: fn (T) ValueType,
) !std.AutoHashMap(KeyType, std.ArrayList(ValueType)) {
    var groups = std.AutoHashMap(KeyType, std.ArrayList(ValueType)).init(allocator);
    errdefer {
        var it = groups.valueIterator();
        while (it.next()) |list| list.deinit();
        groups.deinit();
    }

    for (items) |item| {
        const key = keyFn(item);
        const value = transformFn(item);
        const entry = try groups.getOrPut(key);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(ValueType).init(allocator);
        }
        try entry.value_ptr.append(value);
    }

    return groups;
}
```

### Grouping Slices Efficiently

Pre-allocate when group sizes are known:

```zig
fn groupWithPrealloc(
    comptime T: type,
    comptime KeyType: type,
    allocator: std.mem.Allocator,
    items: []const T,
    keyFn: fn (T) KeyType,
    expected_groups: usize,
) !std.AutoHashMap(KeyType, std.ArrayList(T)) {
    var groups = std.AutoHashMap(KeyType, std.ArrayList(T)).init(allocator);
    try groups.ensureTotalCapacity(@as(u32, @intCast(expected_groups)));

    errdefer {
        var it = groups.valueIterator();
        while (it.next()) |list| list.deinit();
        groups.deinit();
    }

    for (items) |item| {
        const key = keyFn(item);
        const entry = try groups.getOrPut(key);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(T).init(allocator);
        }
        try entry.value_ptr.append(item);
    }

    return groups;
}
```

### Grouping with Filtering

Group only items matching a predicate:

```zig
fn groupByWhere(
    comptime T: type,
    comptime KeyType: type,
    allocator: std.mem.Allocator,
    items: []const T,
    keyFn: fn (T) KeyType,
    filterFn: fn (T) bool,
) !std.AutoHashMap(KeyType, std.ArrayList(T)) {
    var groups = std.AutoHashMap(KeyType, std.ArrayList(T)).init(allocator);
    errdefer {
        var it = groups.valueIterator();
        while (it.next()) |list| list.deinit();
        groups.deinit();
    }

    for (items) |item| {
        if (!filterFn(item)) continue;

        const key = keyFn(item);
        const entry = try groups.getOrPut(key);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(T).init(allocator);
        }
        try entry.value_ptr.append(item);
    }

    return groups;
}
```

### Flattening Grouped Data

Convert groups back to flat list:

```zig
fn flatten(
    comptime T: type,
    comptime KeyType: type,
    allocator: std.mem.Allocator,
    groups: std.AutoHashMap(KeyType, std.ArrayList(T)),
) ![]T {
    var total: usize = 0;
    var it = groups.valueIterator();
    while (it.next()) |list| {
        total += list.items.len;
    }

    var result = try allocator.alloc(T, total);
    var index: usize = 0;

    it = groups.valueIterator();
    while (it.next()) |list| {
        @memcpy(result[index .. index + list.items.len], list.items);
        index += list.items.len;
    }

    return result;
}
```

### Grouping by Range Buckets

Group numeric values into ranges:

```zig
const AgeBucket = enum { child, teen, adult, senior };

fn ageToBucket(age: u32) AgeBucket {
    if (age < 13) return .child;
    if (age < 20) return .teen;
    if (age < 65) return .adult;
    return .senior;
}

const Person = struct {
    name: []const u8,
    age: u32,
};

fn getAgeBucket(person: Person) AgeBucket {
    return ageToBucket(person.age);
}

const groups = try groupBy(Person, AgeBucket, allocator, &people, getAgeBucket);
```

### Performance Considerations

- Use `AutoHashMap` for general keys, `StringHashMap` for string keys
- Pre-allocate HashMap capacity if group count is known
- Use `ArrayHashMap` when insertion order matters
- Consider count-only grouping to save memory
- For large datasets, consider streaming approaches
- Clean up with proper defer/errdefer patterns

### Common Patterns

```zig
// Pattern 1: Basic grouping
const groups = try groupBy(T, KeyType, allocator, items, keyFn);
defer {
    var it = groups.valueIterator();
    while (it.next()) |list| list.deinit();
    groups.deinit();
}

// Pattern 2: Aggregation
const entry = try stats.getOrPut(key);
if (!entry.found_existing) {
    entry.value_ptr.* = initial_value;
}
entry.value_ptr.update(item);

// Pattern 3: Composite key
const key = .{ .field1 = item.field1, .field2 = item.field2 };

// Pattern 4: Count only
const entry = try counts.getOrPut(key);
entry.value_ptr.* = if (entry.found_existing) entry.value_ptr.* + 1 else 1;
```

## See Also

- Recipe 1.6: Mapping Keys to Multiple Values
- Recipe 1.12: Determining Most Frequently Occurring Items
- Recipe 1.8: Calculating with Dictionaries

Full compilable example: `code/02-core/01-data-structures/recipe_1_15.zig`
