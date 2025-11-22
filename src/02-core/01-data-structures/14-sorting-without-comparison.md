# Sorting Objects Without Native Comparison Support

## Problem

You need to sort objects that lack inherent ordering, such as complex types without comparison operators, heterogeneous collections, or types requiring external comparison logic.

## Solution

Use adapter patterns, key extraction functions, or proxy objects to enable sorting:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_14.zig:key_extraction_sort}}

    sortByPriority(&tasks);

    for (tasks) |task| {
        std.debug.print("Task {}: {s}\n", .{ task.id, task.priority });
    }
}
```

## Discussion

### Key Extraction Pattern

Transform objects into comparable keys:

```zig
const Document = struct {
    title: []const u8,
    content: []const u8,
    tags: []const []const u8,
};

// Extract sortable key
fn documentKey(doc: Document) struct { tag_count: usize, title_len: usize } {
    return .{
        .tag_count = doc.tags.len,
        .title_len = doc.title.len,
    };
}

fn sortDocuments(docs: []Document) void {
    std.mem.sort(Document, docs, {}, struct {
        fn lessThan(_: void, a: Document, b: Document) bool {
            const key_a = documentKey(a);
            const key_b = documentKey(b);

            if (key_a.tag_count != key_b.tag_count) {
                return key_a.tag_count > key_b.tag_count;
            }
            return key_a.title_len < key_b.title_len;
        }
    }.lessThan);
}
```

### Sorting with External Comparison Functions

Use function pointers for flexible comparison:

```zig
const CompareFn = *const fn (Task, Task) std.math.Order;

fn compareByPriority(a: Task, b: Task) std.math.Order {
    const key_a = priorityKey(a);
    const key_b = priorityKey(b);
    return std.math.order(key_a, key_b);
}

fn compareByCreated(a: Task, b: Task) std.math.Order {
    return std.math.order(a.created, b.created);
}

fn sortWithComparator(tasks: []Task, compareFn: CompareFn) void {
    const Context = struct {
        compare: CompareFn,

        fn lessThan(self: @This(), a: Task, b: Task) bool {
            return self.compare(a, b) == .lt;
        }
    };

    std.mem.sort(Task, tasks, Context{ .compare = compareFn }, Context.lessThan);
}
```

### Proxy Object Pattern

Wrap objects with sortable keys:

```zig
fn SortProxy(comptime T: type, comptime KeyType: type) type {
    return struct {
        item: T,
        key: KeyType,

        const Self = @This();

        fn lessThan(_: void, a: Self, b: Self) bool {
            return a.key < b.key;
        }
    };
}

fn sortWithProxy(
    comptime T: type,
    comptime KeyType: type,
    allocator: std.mem.Allocator,
    items: []T,
    keyFn: fn (T) KeyType,
) !void {
    const Proxy = SortProxy(T, KeyType);

    var proxies = try allocator.alloc(Proxy, items.len);
    defer allocator.free(proxies);

    for (items, 0..) |item, i| {
        proxies[i] = .{ .item = item, .key = keyFn(item) };
    }

    std.mem.sort(Proxy, proxies, {}, Proxy.lessThan);

    for (proxies, 0..) |proxy, i| {
        items[i] = proxy.item;
    }
}
```

### Sorting Heterogeneous Collections

Use tagged unions with comparison logic:

```zig
const Item = union(enum) {
    number: i32,
    text: []const u8,
    flag: bool,

    fn sortKey(self: Item) i32 {
        return switch (self) {
            .number => |n| n,
            .text => |s| @as(i32, @intCast(s.len)),
            .flag => |b| if (b) 1 else 0,
        };
    }

    fn compare(a: Item, b: Item) bool {
        const tag_a = @intFromEnum(a);
        const tag_b = @intFromEnum(b);

        if (tag_a != tag_b) return tag_a < tag_b;

        return a.sortKey() < b.sortKey();
    }
};

fn sortItems(items: []Item) void {
    std.mem.sort(Item, items, {}, struct {
        fn lessThan(_: void, a: Item, b: Item) bool {
            return Item.compare(a, b);
        }
    }.lessThan);
}
```

### Multi-Criteria Comparison Builder

Build complex comparators from simple ones:

```zig
fn Comparator(comptime T: type) type {
    return struct {
        const Self = @This();
        const CompareResult = enum { less, equal, greater };

        criteria: []const Criterion,

        const Criterion = struct {
            keyFn: *const fn (T) i64,
            descending: bool,
        };

        fn compare(self: Self, a: T, b: T) CompareResult {
            for (self.criteria) |criterion| {
                const key_a = criterion.keyFn(a);
                const key_b = criterion.keyFn(b);

                if (key_a != key_b) {
                    const result = if (key_a < key_b) CompareResult.less else CompareResult.greater;
                    return if (criterion.descending) switch (result) {
                        .less => .greater,
                        .greater => .less,
                        .equal => .equal,
                    } else result;
                }
            }
            return .equal;
        }

        fn lessThan(self: Self, a: T, b: T) bool {
            return self.compare(a, b) == .less;
        }
    };
}
```

### Sorting by String Representation

Use serialization for comparison:

```zig
const Config = struct {
    host: []const u8,
    port: u16,
    ssl: bool,

    fn toSortString(self: Config, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "{s}:{d}:{}", .{
            self.host,
            self.port,
            self.ssl,
        });
    }
};

fn sortConfigs(allocator: std.mem.Allocator, configs: []Config) !void {
    const Context = struct {
        allocator: std.mem.Allocator,

        fn lessThan(self: @This(), a: Config, b: Config) bool {
            const str_a = a.toSortString(self.allocator) catch return false;
            defer self.allocator.free(str_a);
            const str_b = b.toSortString(self.allocator) catch return false;
            defer self.allocator.free(str_b);

            return std.mem.order(u8, str_a, str_b) == .lt;
        }
    };

    std.mem.sort(Config, configs, Context{ .allocator = allocator }, Context.lessThan);
}
```

### Sorting by Hash Values

Use hashing for deterministic ordering:

```zig
const ComplexObject = struct {
    data: []const u8,
    metadata: std.StringHashMap([]const u8),

    fn hash(self: ComplexObject) u64 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(self.data);

        var it = self.metadata.iterator();
        while (it.next()) |entry| {
            hasher.update(entry.key_ptr.*);
            hasher.update(entry.value_ptr.*);
        }

        return hasher.final();
    }
};

fn sortByHash(objects: []ComplexObject) void {
    std.mem.sort(ComplexObject, objects, {}, struct {
        fn lessThan(_: void, a: ComplexObject, b: ComplexObject) bool {
            return a.hash() < b.hash();
        }
    }.lessThan);
}
```

### Adapter Pattern for Pointer Types

Sort pointers using dereferenced comparison:

```zig
fn sortPointers(
    comptime T: type,
    ptrs: []*T,
    compareFn: fn (T, T) bool,
) void {
    const Context = struct {
        compare: fn (T, T) bool,

        fn lessThan(self: @This(), a: *T, b: *T) bool {
            return self.compare(a.*, b.*);
        }
    };

    std.mem.sort(*T, ptrs, Context{ .compare = compareFn }, Context.lessThan);
}
```

### Sorting with Cached Keys

Pre-compute expensive keys for performance:

```zig
fn CachedSort(comptime T: type, comptime KeyType: type) type {
    return struct {
        const Entry = struct {
            item: T,
            key: KeyType,
        };

        pub fn sort(
            allocator: std.mem.Allocator,
            items: []T,
            keyFn: fn (T) KeyType,
        ) !void {
            var entries = try allocator.alloc(Entry, items.len);
            defer allocator.free(entries);

            for (items, 0..) |item, i| {
                entries[i] = .{ .item = item, .key = keyFn(item) };
            }

            std.mem.sort(Entry, entries, {}, struct {
                fn lessThan(_: void, a: Entry, b: Entry) bool {
                    return a.key < b.key;
                }
            }.lessThan);

            for (entries, 0..) |entry, i| {
                items[i] = entry.item;
            }
        }
    };
}
```

### Sorting with Custom Metrics

Define application-specific comparison logic:

```zig
const User = struct {
    name: []const u8,
    posts: usize,
    likes: usize,
    followers: usize,

    fn engagementScore(self: User) f32 {
        const posts_f: f32 = @floatFromInt(self.posts);
        const likes_f: f32 = @floatFromInt(self.likes);
        const followers_f: f32 = @floatFromInt(self.followers);

        return (posts_f * 0.3) + (likes_f * 0.5) + (followers_f * 0.2);
    }
};

fn sortByEngagement(users: []User) void {
    std.mem.sort(User, users, {}, struct {
        fn lessThan(_: void, a: User, b: User) bool {
            return a.engagementScore() > b.engagementScore();
        }
    }.lessThan);
}
```

### Generic Sort Adapter

Create reusable sorting infrastructure:

```zig
fn SortAdapter(comptime T: type) type {
    return struct {
        pub fn sortBy(
            items: []T,
            context: anytype,
            compareFn: fn (@TypeOf(context), T, T) bool,
        ) void {
            std.mem.sort(T, items, context, compareFn);
        }

        pub fn sortByKey(
            comptime KeyType: type,
            allocator: std.mem.Allocator,
            items: []T,
            keyFn: fn (T) KeyType,
        ) !void {
            const sorter = CachedSort(T, KeyType);
            try sorter.sort(allocator, items, keyFn);
        }

        pub fn sortByField(
            comptime field: []const u8,
            items: []T,
        ) void {
            std.mem.sort(T, items, {}, struct {
                fn lessThan(_: void, a: T, b: T) bool {
                    return @field(a, field) < @field(b, field);
                }
            }.lessThan);
        }
    };
}
```

### Sorting Opaque Types

Handle types with hidden internals:

```zig
const OpaqueHandle = opaque {};

const Resource = struct {
    handle: *OpaqueHandle,
    id: u64,
    name: []const u8,
};

fn sortResourcesById(resources: []Resource) void {
    std.mem.sort(Resource, resources, {}, struct {
        fn lessThan(_: void, a: Resource, b: Resource) bool {
            return a.id < b.id;
        }
    }.lessThan);
}
```

### Performance Considerations

- Pre-compute expensive keys using cached sort pattern
- Avoid allocations in comparison functions when possible
- Use proxy objects for multiple sorts with same key function
- Consider hash-based ordering for consistency without semantic meaning
- For very large datasets, consider external sorting approaches

### Common Patterns

```zig
// Pattern 1: Key extraction
fn keyFn(item: T) KeyType { return item.computeKey(); }

// Pattern 2: Proxy with cached key
const Proxy = struct { item: T, key: KeyType };

// Pattern 3: Multiple comparison functions
fn compare(a: T, b: T) std.math.Order { ... }

// Pattern 4: Tagged union sorting
fn compare(a: Union, b: Union) bool {
    if (@intFromEnum(a) != @intFromEnum(b)) return @intFromEnum(a) < @intFromEnum(b);
    // Compare by value within same tag
}
```

## See Also

- Recipe 1.13: Sorting a List of Structs by a Common Field
- Recipe 1.4: Finding Largest/Smallest N Items
- Recipe 8.12: Implementing Interfaces

Full compilable example: `code/02-core/01-data-structures/recipe_1_14.zig`
