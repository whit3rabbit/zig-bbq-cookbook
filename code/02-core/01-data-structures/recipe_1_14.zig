const std = @import("std");
const testing = std.testing;

// Test structs
const Task = struct {
    id: u32,
    priority: []const u8,
    created: i64,
};

const Document = struct {
    title: []const u8,
    content: []const u8,
    tags: []const []const u8,
};

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

const ComplexObject = struct {
    data: []const u8,

    fn hash(self: ComplexObject) u64 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(self.data);
        return hasher.final();
    }
};

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

const OpaqueHandle = opaque {};

const Resource = struct {
    handle: ?*OpaqueHandle,
    id: u64,
    name: []const u8,
};

// Key extraction functions
// ANCHOR: key_extraction_sort
fn priorityKey(task: Task) u32 {
    if (std.mem.eql(u8, task.priority, "high")) return 0;
    if (std.mem.eql(u8, task.priority, "medium")) return 1;
    return 2;
}

fn sortByPriority(tasks: []Task) void {
    std.mem.sort(Task, tasks, {}, struct {
        fn lessThan(_: void, a: Task, b: Task) bool {
            const key_a = priorityKey(a);
            const key_b = priorityKey(b);
            if (key_a != key_b) return key_a < key_b;
            return a.created < b.created;
        }
    }.lessThan);
}
// ANCHOR_END: key_extraction_sort

// ANCHOR: composite_key_sort
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
// ANCHOR_END: composite_key_sort

// External comparison functions
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

// Proxy pattern
// ANCHOR: generic_proxy_sort
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
// ANCHOR_END: generic_proxy_sort

// Sort heterogeneous collections
fn sortItems(items: []Item) void {
    std.mem.sort(Item, items, {}, struct {
        fn lessThan(_: void, a: Item, b: Item) bool {
            return Item.compare(a, b);
        }
    }.lessThan);
}

// Multi-criteria comparator
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

// Sort by string representation
// OPTIMIZED VERSION using proxy pattern to avoid O(n log n) allocations
fn sortConfigs(allocator: std.mem.Allocator, configs: []Config) !void {
    if (configs.len <= 1) return;

    const Proxy = struct {
        index: usize,
        sort_string: []u8,
    };

    var proxies = try allocator.alloc(Proxy, configs.len);
    var initialized: usize = 0;

    defer {
        for (proxies[0..initialized]) |proxy| {
            allocator.free(proxy.sort_string);
        }
        allocator.free(proxies);
    }

    // Phase 1: Pre-compute all sort strings once (O(n) allocations)
    for (configs, 0..) |config, i| {
        const sort_str = try config.toSortString(allocator);
        proxies[i] = .{ .index = i, .sort_string = sort_str };
        initialized += 1;
    }

    // Phase 2: Sort proxies by pre-computed strings (no allocations)
    std.mem.sort(Proxy, proxies, {}, struct {
        fn lessThan(_: void, a: Proxy, b: Proxy) bool {
            return switch (std.mem.order(u8, a.sort_string, b.sort_string)) {
                .lt => true,
                .gt => false,
                .eq => a.index < b.index, // Stable sort
            };
        }
    }.lessThan);

    // Phase 3: Reorder configs array using scratch buffer
    var scratch = try allocator.alloc(Config, configs.len);
    defer allocator.free(scratch);

    for (proxies, 0..) |proxy, i| {
        scratch[i] = configs[proxy.index];
    }

    @memcpy(configs, scratch);
}

// Sort by hash
fn sortByHash(objects: []ComplexObject) void {
    std.mem.sort(ComplexObject, objects, {}, struct {
        fn lessThan(_: void, a: ComplexObject, b: ComplexObject) bool {
            return a.hash() < b.hash();
        }
    }.lessThan);
}

// Sort pointers
fn sortPointers(
    comptime T: type,
    ptrs: []*T,
    compareFn: *const fn (T, T) bool,
) void {
    const Context = struct {
        compare: *const fn (T, T) bool,

        fn lessThan(self: @This(), a: *T, b: *T) bool {
            return self.compare(a.*, b.*);
        }
    };

    std.mem.sort(*T, ptrs, Context{ .compare = compareFn }, Context.lessThan);
}

// Cached sort
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

// Sort by engagement
// OPTIMIZED VERSION using proxy pattern to avoid redundant calculations
fn sortByEngagement(allocator: std.mem.Allocator, users: []User) !void {
    if (users.len <= 1) return;

    const Proxy = struct {
        index: usize,
        score: f32,
    };

    var proxies = try allocator.alloc(Proxy, users.len);
    defer allocator.free(proxies);

    // Phase 1: Pre-compute all engagement scores once
    for (users, 0..) |user, i| {
        proxies[i] = .{
            .index = i,
            .score = user.engagementScore(),
        };
    }

    // Phase 2: Sort proxies by pre-computed scores (cheap f32 comparison)
    std.mem.sort(Proxy, proxies, {}, struct {
        fn lessThan(_: void, a: Proxy, b: Proxy) bool {
            if (a.score != b.score) {
                return a.score > b.score; // Descending order
            }
            return a.index < b.index; // Stable sort
        }
    }.lessThan);

    // Phase 3: Reorder users array using scratch buffer
    var scratch = try allocator.alloc(User, users.len);
    defer allocator.free(scratch);

    for (proxies, 0..) |proxy, i| {
        scratch[i] = users[proxy.index];
    }

    @memcpy(users, scratch);
}

// Sort adapter
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

// Sort resources
fn sortResourcesById(resources: []Resource) void {
    std.mem.sort(Resource, resources, {}, struct {
        fn lessThan(_: void, a: Resource, b: Resource) bool {
            return a.id < b.id;
        }
    }.lessThan);
}

// Tests
test "sort by priority with key extraction" {
    var tasks = [_]Task{
        .{ .id = 1, .priority = "low", .created = 100 },
        .{ .id = 2, .priority = "high", .created = 200 },
        .{ .id = 3, .priority = "medium", .created = 150 },
        .{ .id = 4, .priority = "high", .created = 180 },
    };

    sortByPriority(&tasks);

    try testing.expectEqualStrings("high", tasks[0].priority);
    try testing.expectEqual(@as(i64, 180), tasks[0].created);
    try testing.expectEqualStrings("high", tasks[1].priority);
    try testing.expectEqual(@as(i64, 200), tasks[1].created);
    try testing.expectEqualStrings("medium", tasks[2].priority);
    try testing.expectEqualStrings("low", tasks[3].priority);
}

test "sort documents by extracted key" {
    const tags1 = [_][]const u8{ "zig", "programming" };
    const tags2 = [_][]const u8{"tutorial"};
    const tags3 = [_][]const u8{ "advanced", "comptime" };

    var docs = [_]Document{
        .{ .title = "Hello", .content = "...", .tags = &tags1 },
        .{ .title = "Short", .content = "...", .tags = &tags3 },
        .{ .title = "Guide", .content = "...", .tags = &tags1 },
        .{ .title = "Tutorial", .content = "...", .tags = &tags2 },
    };

    sortDocuments(&docs);

    // First 3 have 2 tags (sorted by title length)
    try testing.expectEqual(@as(usize, 2), docs[0].tags.len);
    try testing.expectEqual(@as(usize, 2), docs[1].tags.len);
    try testing.expectEqual(@as(usize, 2), docs[2].tags.len);
    // Last one has 1 tag
    try testing.expectEqual(@as(usize, 1), docs[3].tags.len);

    // Within docs with 2 tags, sorted by title length: Guide(5), Hello(5), Short(5)
    // They're all the same length, so order depends on original order (unstable sort)
    try testing.expect(docs[0].tags.len == 2);
    try testing.expect(docs[1].tags.len == 2);
    try testing.expect(docs[2].tags.len == 2);
}

test "sort with external comparator by priority" {
    var tasks = [_]Task{
        .{ .id = 1, .priority = "low", .created = 100 },
        .{ .id = 2, .priority = "high", .created = 200 },
        .{ .id = 3, .priority = "medium", .created = 150 },
    };

    sortWithComparator(&tasks, compareByPriority);

    // Priority keys: high=0, medium=1, low=2
    try testing.expectEqualStrings("high", tasks[0].priority);
    try testing.expectEqualStrings("medium", tasks[1].priority);
    try testing.expectEqualStrings("low", tasks[2].priority);
}

test "sort with external comparator by created" {
    var tasks = [_]Task{
        .{ .id = 1, .priority = "low", .created = 300 },
        .{ .id = 2, .priority = "high", .created = 100 },
        .{ .id = 3, .priority = "medium", .created = 200 },
    };

    sortWithComparator(&tasks, compareByCreated);

    try testing.expectEqual(@as(i64, 100), tasks[0].created);
    try testing.expectEqual(@as(i64, 200), tasks[1].created);
    try testing.expectEqual(@as(i64, 300), tasks[2].created);
}

test "sort with proxy pattern" {
    var tasks = [_]Task{
        .{ .id = 1, .priority = "low", .created = 100 },
        .{ .id = 2, .priority = "high", .created = 200 },
        .{ .id = 3, .priority = "medium", .created = 150 },
    };

    try sortWithProxy(Task, u32, testing.allocator, &tasks, priorityKey);

    try testing.expectEqualStrings("high", tasks[0].priority);
    try testing.expectEqualStrings("medium", tasks[1].priority);
    try testing.expectEqualStrings("low", tasks[2].priority);
}

test "sort heterogeneous collection" {
    var items = [_]Item{
        .{ .text = "hello" },
        .{ .number = 42 },
        .{ .flag = true },
        .{ .number = 10 },
        .{ .text = "hi" },
    };

    sortItems(&items);

    // Sorted by tag first: number(0), text(1), flag(2)
    // Then by sortKey within tag
    try testing.expect(items[0] == .number); // 10
    try testing.expect(items[1] == .number); // 42
    try testing.expect(items[2] == .text);    // "hi" (len 2)
    try testing.expect(items[3] == .text);    // "hello" (len 5)
    try testing.expect(items[4] == .flag);    // true
}

test "multi-criteria comparator" {
    const TestItem = struct {
        a: i64,
        b: i64,

        fn getA(item: @This()) i64 {
            return item.a;
        }
        fn getB(item: @This()) i64 {
            return item.b;
        }
    };

    var items = [_]TestItem{
        .{ .a = 2, .b = 3 },
        .{ .a = 1, .b = 5 },
        .{ .a = 2, .b = 1 },
    };

    const criteria = [_]Comparator(TestItem).Criterion{
        .{ .keyFn = &TestItem.getA, .descending = false },
        .{ .keyFn = &TestItem.getB, .descending = true },
    };

    const comparator = Comparator(TestItem){ .criteria = &criteria };

    std.mem.sort(TestItem, &items, comparator, Comparator(TestItem).lessThan);

    try testing.expectEqual(@as(i64, 1), items[0].a);
    try testing.expectEqual(@as(i64, 2), items[1].a);
    try testing.expectEqual(@as(i64, 3), items[1].b);
    try testing.expectEqual(@as(i64, 2), items[2].a);
    try testing.expectEqual(@as(i64, 1), items[2].b);
}

test "sort by string representation" {
    var configs = [_]Config{
        .{ .host = "localhost", .port = 8080, .ssl = false },
        .{ .host = "example.com", .port = 443, .ssl = true },
        .{ .host = "localhost", .port = 443, .ssl = true },
    };

    try sortConfigs(testing.allocator, &configs);

    // Sorted lexicographically by "host:port:ssl" string
    // "example.com:443:true" < "localhost:443:true" < "localhost:8080:false"
    try testing.expectEqualStrings("example.com", configs[0].host);
    try testing.expectEqualStrings("localhost", configs[1].host);
    try testing.expectEqual(@as(u16, 443), configs[1].port);
    try testing.expect(configs[1].ssl == true);
    try testing.expectEqualStrings("localhost", configs[2].host);
    try testing.expectEqual(@as(u16, 8080), configs[2].port);
    try testing.expect(configs[2].ssl == false);
}

test "sort by hash values" {
    var objects = [_]ComplexObject{
        .{ .data = "zebra" },
        .{ .data = "apple" },
        .{ .data = "mango" },
    };

    sortByHash(&objects);

    const h0 = objects[0].hash();
    const h1 = objects[1].hash();
    const h2 = objects[2].hash();

    try testing.expect(h0 <= h1);
    try testing.expect(h1 <= h2);
}

test "sort pointers with adapter" {
    var t1 = Task{ .id = 3, .priority = "low", .created = 100 };
    var t2 = Task{ .id = 1, .priority = "high", .created = 200 };
    var t3 = Task{ .id = 2, .priority = "medium", .created = 150 };

    var tasks = [_]*Task{ &t1, &t2, &t3 };

    sortPointers(Task, &tasks, struct {
        fn cmp(a: Task, b: Task) bool {
            return a.id < b.id;
        }
    }.cmp);

    try testing.expectEqual(@as(u32, 1), tasks[0].id);
    try testing.expectEqual(@as(u32, 2), tasks[1].id);
    try testing.expectEqual(@as(u32, 3), tasks[2].id);
}

test "cached sort with expensive key function" {
    var tasks = [_]Task{
        .{ .id = 1, .priority = "low", .created = 100 },
        .{ .id = 2, .priority = "high", .created = 200 },
        .{ .id = 3, .priority = "medium", .created = 150 },
    };

    const sorter = CachedSort(Task, u32);
    try sorter.sort(testing.allocator, &tasks, priorityKey);

    try testing.expectEqualStrings("high", tasks[0].priority);
    try testing.expectEqualStrings("medium", tasks[1].priority);
    try testing.expectEqualStrings("low", tasks[2].priority);
}

test "sort by engagement score" {
    var users = [_]User{
        .{ .name = "Alice", .posts = 10, .likes = 100, .followers = 50 },
        .{ .name = "Bob", .posts = 5, .likes = 200, .followers = 100 },
        .{ .name = "Charlie", .posts = 20, .likes = 50, .followers = 30 },
    };

    try sortByEngagement(testing.allocator, &users);

    const score0 = users[0].engagementScore();
    const score1 = users[1].engagementScore();
    const score2 = users[2].engagementScore();

    try testing.expect(score0 >= score1);
    try testing.expect(score1 >= score2);
}

test "sort adapter with sortBy" {
    var tasks = [_]Task{
        .{ .id = 3, .priority = "low", .created = 100 },
        .{ .id = 1, .priority = "high", .created = 200 },
        .{ .id = 2, .priority = "medium", .created = 150 },
    };

    const adapter = SortAdapter(Task);
    adapter.sortBy(&tasks, {}, struct {
        fn cmp(_: void, a: Task, b: Task) bool {
            return a.id < b.id;
        }
    }.cmp);

    try testing.expectEqual(@as(u32, 1), tasks[0].id);
    try testing.expectEqual(@as(u32, 2), tasks[1].id);
    try testing.expectEqual(@as(u32, 3), tasks[2].id);
}

test "sort adapter with sortByKey" {
    var tasks = [_]Task{
        .{ .id = 1, .priority = "low", .created = 100 },
        .{ .id = 2, .priority = "high", .created = 200 },
        .{ .id = 3, .priority = "medium", .created = 150 },
    };

    const adapter = SortAdapter(Task);
    try adapter.sortByKey(u32, testing.allocator, &tasks, priorityKey);

    try testing.expectEqualStrings("high", tasks[0].priority);
    try testing.expectEqualStrings("medium", tasks[1].priority);
    try testing.expectEqualStrings("low", tasks[2].priority);
}

test "sort adapter with sortByField" {
    var tasks = [_]Task{
        .{ .id = 3, .priority = "low", .created = 300 },
        .{ .id = 1, .priority = "high", .created = 100 },
        .{ .id = 2, .priority = "medium", .created = 200 },
    };

    const adapter = SortAdapter(Task);
    adapter.sortByField("created", &tasks);

    try testing.expectEqual(@as(i64, 100), tasks[0].created);
    try testing.expectEqual(@as(i64, 200), tasks[1].created);
    try testing.expectEqual(@as(i64, 300), tasks[2].created);
}

test "sort opaque resources by id" {
    var resources = [_]Resource{
        .{ .handle = null, .id = 300, .name = "resource3" },
        .{ .handle = null, .id = 100, .name = "resource1" },
        .{ .handle = null, .id = 200, .name = "resource2" },
    };

    sortResourcesById(&resources);

    try testing.expectEqual(@as(u64, 100), resources[0].id);
    try testing.expectEqual(@as(u64, 200), resources[1].id);
    try testing.expectEqual(@as(u64, 300), resources[2].id);
}

test "sort empty slice without comparison" {
    var tasks: [0]Task = undefined;
    sortByPriority(&tasks);
}

test "sort single element without comparison" {
    var tasks = [_]Task{
        .{ .id = 1, .priority = "high", .created = 100 },
    };
    sortByPriority(&tasks);
    try testing.expectEqual(@as(u32, 1), tasks[0].id);
}
