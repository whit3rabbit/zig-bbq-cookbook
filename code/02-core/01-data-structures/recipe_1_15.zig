const std = @import("std");
const testing = std.testing;

// Test structs
const Sale = struct {
    product: []const u8,
    amount: f32,
    region: []const u8,
};

const Person = struct {
    name: []const u8,
    age: u32,
};

const Priority = enum { low, medium, high };

const Task = struct {
    name: []const u8,
    priority: Priority,
};

// Composite key for multi-field grouping
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

const CompositeContext = struct {
    pub fn hash(_: @This(), key: CompositeKey) u64 {
        return key.hash();
    }
    pub fn eql(_: @This(), a: CompositeKey, b: CompositeKey) bool {
        return a.eql(b);
    }
};

// Aggregation struct
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

// Age buckets for range grouping
const AgeBucket = enum { child, teen, adult, senior };

fn ageToBucket(age: u32) AgeBucket {
    if (age < 13) return .child;
    if (age < 20) return .teen;
    if (age < 65) return .adult;
    return .senior;
}

// Basic grouping function for string keys
// ANCHOR: basic_groupby
fn groupBy(
    comptime T: type,
    comptime KeyType: type,
    allocator: std.mem.Allocator,
    items: []const T,
    keyFn: fn (T) KeyType,
) !std.StringHashMap(std.ArrayList(T)) {
    var groups = std.StringHashMap(std.ArrayList(T)).init(allocator);
    errdefer {
        var it = groups.valueIterator();
        while (it.next()) |list| list.deinit(allocator);
        groups.deinit();
    }

    for (items) |item| {
        const key = keyFn(item);
        const entry = try groups.getOrPut(key);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(T){};
        }
        try entry.value_ptr.append(allocator, item);
    }

    return groups;
}
// ANCHOR_END: basic_groupby

// Generic grouping function for non-string keys
fn groupByGeneric(
    comptime T: type,
    comptime KeyType: type,
    allocator: std.mem.Allocator,
    items: []const T,
    keyFn: fn (T) KeyType,
) !std.AutoHashMap(KeyType, std.ArrayList(T)) {
    var groups = std.AutoHashMap(KeyType, std.ArrayList(T)).init(allocator);
    errdefer {
        var it = groups.valueIterator();
        while (it.next()) |list| list.deinit(allocator);
        groups.deinit();
    }

    for (items) |item| {
        const key = keyFn(item);
        const entry = try groups.getOrPut(key);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(T){};
        }
        try entry.value_ptr.append(allocator, item);
    }

    return groups;
}

// Grouping with aggregation
// ANCHOR: groupby_aggregation
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
// ANCHOR_END: groupby_aggregation

// Grouping with ordered iteration
fn groupByOrdered(
    comptime T: type,
    allocator: std.mem.Allocator,
    items: []const T,
    keyFn: fn (T) []const u8,
) !std.StringArrayHashMap(std.ArrayList(T)) {
    var groups = std.StringArrayHashMap(std.ArrayList(T)).init(allocator);
    errdefer {
        for (groups.values()) |*list| list.deinit(allocator);
        groups.deinit();
    }

    for (items) |item| {
        const key = keyFn(item);
        const entry = try groups.getOrPut(key);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(T){};
        }
        try entry.value_ptr.append(allocator, item);
    }

    return groups;
}

// Count-only grouping for string keys
fn groupCount(
    allocator: std.mem.Allocator,
    items: anytype,
    keyFn: anytype,
) !std.StringHashMap(usize) {
    var counts = std.StringHashMap(usize).init(allocator);
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

// Generic grouping with custom aggregation for string keys
// ANCHOR: custom_aggregation
fn StringGroupedBy(comptime T: type, comptime ValueType: type) type {
    return struct {
        map: std.StringHashMap(ValueType),
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .map = std.StringHashMap(ValueType).init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        pub fn aggregate(
            self: *Self,
            items: []const T,
            keyFn: fn (T) []const u8,
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

        pub fn get(self: Self, key: []const u8) ?ValueType {
            return self.map.get(key);
        }

        pub fn iterator(self: *Self) std.StringHashMap(ValueType).Iterator {
            return self.map.iterator();
        }
    };
}
// ANCHOR_END: custom_aggregation

// Nested grouping
fn groupByNested(
    allocator: std.mem.Allocator,
    sales: []const Sale,
) !std.StringHashMap(std.StringHashMap(std.ArrayList(Sale))) {
    var outer = std.StringHashMap(std.StringHashMap(std.ArrayList(Sale))).init(allocator);
    errdefer {
        var outer_it = outer.valueIterator();
        while (outer_it.next()) |inner_map| {
            var inner_it = inner_map.valueIterator();
            while (inner_it.next()) |list| list.deinit(allocator);
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
            inner_entry.value_ptr.* = std.ArrayList(Sale){};
        }
        try inner_entry.value_ptr.append(allocator, sale);
    }

    return outer;
}

// Group and transform
fn groupAndTransform(
    comptime T: type,
    comptime ValueType: type,
    allocator: std.mem.Allocator,
    items: []const T,
    keyFn: fn (T) []const u8,
    transformFn: fn (T) ValueType,
) !std.StringHashMap(std.ArrayList(ValueType)) {
    var groups = std.StringHashMap(std.ArrayList(ValueType)).init(allocator);
    errdefer {
        var it = groups.valueIterator();
        while (it.next()) |list| list.deinit(allocator);
        groups.deinit();
    }

    for (items) |item| {
        const key = keyFn(item);
        const value = transformFn(item);
        const entry = try groups.getOrPut(key);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(ValueType){};
        }
        try entry.value_ptr.append(allocator, value);
    }

    return groups;
}

// Group with filtering
fn groupByWhere(
    comptime T: type,
    allocator: std.mem.Allocator,
    items: []const T,
    keyFn: fn (T) []const u8,
    filterFn: fn (T) bool,
) !std.StringHashMap(std.ArrayList(T)) {
    var groups = std.StringHashMap(std.ArrayList(T)).init(allocator);
    errdefer {
        var it = groups.valueIterator();
        while (it.next()) |list| list.deinit(allocator);
        groups.deinit();
    }

    for (items) |item| {
        if (!filterFn(item)) continue;

        const key = keyFn(item);
        const entry = try groups.getOrPut(key);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(T){};
        }
        try entry.value_ptr.append(allocator, item);
    }

    return groups;
}

// Flatten grouped data
fn flatten(
    comptime T: type,
    allocator: std.mem.Allocator,
    groups: std.StringHashMap(std.ArrayList(T)),
) ![]T {
    var total: usize = 0;
    var it = groups.valueIterator();
    while (it.next()) |list| {
        total += list.items.len;
    }

    const result = try allocator.alloc(T, total);
    var index: usize = 0;

    it = groups.valueIterator();
    while (it.next()) |list| {
        @memcpy(result[index .. index + list.items.len], list.items);
        index += list.items.len;
    }

    return result;
}

// Key functions
fn getProduct(sale: Sale) []const u8 {
    return sale.product;
}

fn getRegion(sale: Sale) []const u8 {
    return sale.region;
}

fn getPriority(task: Task) Priority {
    return task.priority;
}

fn getAgeBucket(person: Person) AgeBucket {
    return ageToBucket(person.age);
}

fn getCompositeKey(sale: Sale) CompositeKey {
    return .{ .region = sale.region, .product = sale.product };
}

// Tests
test "basic grouping by product" {
    const sales = [_]Sale{
        .{ .product = "Widget", .amount = 100, .region = "North" },
        .{ .product = "Gadget", .amount = 150, .region = "South" },
        .{ .product = "Widget", .amount = 200, .region = "North" },
        .{ .product = "Gadget", .amount = 120, .region = "North" },
    };

    var groups = try groupBy(Sale, []const u8, testing.allocator, &sales, getProduct);
    defer {
        var it = groups.valueIterator();
        while (it.next()) |list| list.deinit(testing.allocator);
        groups.deinit();
    }

    try testing.expectEqual(@as(usize, 2), groups.count());

    const widgets = groups.get("Widget").?;
    try testing.expectEqual(@as(usize, 2), widgets.items.len);

    const gadgets = groups.get("Gadget").?;
    try testing.expectEqual(@as(usize, 2), gadgets.items.len);
}

test "grouping by region" {
    const sales = [_]Sale{
        .{ .product = "Widget", .amount = 100, .region = "North" },
        .{ .product = "Gadget", .amount = 150, .region = "South" },
        .{ .product = "Widget", .amount = 200, .region = "North" },
        .{ .product = "Gadget", .amount = 120, .region = "North" },
    };

    var groups = try groupBy(Sale, []const u8, testing.allocator, &sales, getRegion);
    defer {
        var it = groups.valueIterator();
        while (it.next()) |list| list.deinit(testing.allocator);
        groups.deinit();
    }

    try testing.expectEqual(@as(usize, 2), groups.count());

    const north = groups.get("North").?;
    try testing.expectEqual(@as(usize, 3), north.items.len);

    const south = groups.get("South").?;
    try testing.expectEqual(@as(usize, 1), south.items.len);
}

test "grouping with aggregation" {
    const sales = [_]Sale{
        .{ .product = "Widget", .amount = 100, .region = "North" },
        .{ .product = "Gadget", .amount = 150, .region = "South" },
        .{ .product = "Widget", .amount = 200, .region = "North" },
        .{ .product = "Gadget", .amount = 120, .region = "North" },
    };

    var stats = try groupWithStats(testing.allocator, &sales);
    defer stats.deinit();

    const widget_stats = stats.get("Widget").?;
    try testing.expectEqual(@as(usize, 2), widget_stats.count);
    try testing.expectEqual(@as(f32, 300), widget_stats.total);
    try testing.expectEqual(@as(f32, 150), widget_stats.average);

    const gadget_stats = stats.get("Gadget").?;
    try testing.expectEqual(@as(usize, 2), gadget_stats.count);
    try testing.expectEqual(@as(f32, 270), gadget_stats.total);
    try testing.expectEqual(@as(f32, 135), gadget_stats.average);
}

test "grouping with ordered iteration" {
    const sales = [_]Sale{
        .{ .product = "Widget", .amount = 100, .region = "North" },
        .{ .product = "Gadget", .amount = 150, .region = "South" },
        .{ .product = "Doohickey", .amount = 80, .region = "East" },
    };

    var groups = try groupByOrdered(Sale, testing.allocator, &sales, getProduct);
    defer {
        for (groups.values()) |*list| list.deinit(testing.allocator);
        groups.deinit();
    }

    try testing.expectEqual(@as(usize, 3), groups.count());

    const keys = groups.keys();
    try testing.expectEqualStrings("Widget", keys[0]);
    try testing.expectEqualStrings("Gadget", keys[1]);
    try testing.expectEqualStrings("Doohickey", keys[2]);
}

test "count-only grouping" {
    const sales = [_]Sale{
        .{ .product = "Widget", .amount = 100, .region = "North" },
        .{ .product = "Gadget", .amount = 150, .region = "South" },
        .{ .product = "Widget", .amount = 200, .region = "North" },
        .{ .product = "Gadget", .amount = 120, .region = "North" },
    };

    var counts = try groupCount(testing.allocator, &sales, getProduct);
    defer counts.deinit();

    try testing.expectEqual(@as(usize, 2), counts.get("Widget").?);
    try testing.expectEqual(@as(usize, 2), counts.get("Gadget").?);
}

test "generic grouping with custom aggregation" {
    const sales = [_]Sale{
        .{ .product = "Widget", .amount = 100, .region = "North" },
        .{ .product = "Widget", .amount = 200, .region = "North" },
    };

    var grouped = StringGroupedBy(Sale, GroupStats).init(testing.allocator);
    defer grouped.deinit();

    const initFn = struct {
        fn f(_: std.mem.Allocator) !GroupStats {
            return .{ .count = 0, .total = 0, .average = 0 };
        }
    }.f;

    const updateFn = struct {
        fn f(stats: *GroupStats, sale: Sale) !void {
            stats.add(sale.amount);
        }
    }.f;

    try grouped.aggregate(&sales, getProduct, initFn, updateFn);

    const widget_stats = grouped.get("Widget").?;
    try testing.expectEqual(@as(usize, 2), widget_stats.count);
    try testing.expectEqual(@as(f32, 300), widget_stats.total);
}

test "grouping by enum values" {
    const tasks = [_]Task{
        .{ .name = "Task1", .priority = .high },
        .{ .name = "Task2", .priority = .low },
        .{ .name = "Task3", .priority = .high },
        .{ .name = "Task4", .priority = .medium },
    };

    var groups = try groupByGeneric(Task, Priority, testing.allocator, &tasks, getPriority);
    defer {
        var it = groups.valueIterator();
        while (it.next()) |list| list.deinit(testing.allocator);
        groups.deinit();
    }

    try testing.expectEqual(@as(usize, 2), groups.get(.high).?.items.len);
    try testing.expectEqual(@as(usize, 1), groups.get(.low).?.items.len);
    try testing.expectEqual(@as(usize, 1), groups.get(.medium).?.items.len);
}

test "nested grouping by region and product" {
    const sales = [_]Sale{
        .{ .product = "Widget", .amount = 100, .region = "North" },
        .{ .product = "Gadget", .amount = 150, .region = "South" },
        .{ .product = "Widget", .amount = 200, .region = "North" },
        .{ .product = "Gadget", .amount = 120, .region = "North" },
    };

    var nested = try groupByNested(testing.allocator, &sales);
    defer {
        var outer_it = nested.valueIterator();
        while (outer_it.next()) |inner_map| {
            var inner_it = inner_map.valueIterator();
            while (inner_it.next()) |list| list.deinit(testing.allocator);
            inner_map.deinit();
        }
        nested.deinit();
    }

    const north = nested.get("North").?;
    try testing.expectEqual(@as(usize, 2), north.get("Widget").?.items.len);
    try testing.expectEqual(@as(usize, 1), north.get("Gadget").?.items.len);

    const south = nested.get("South").?;
    try testing.expectEqual(@as(usize, 1), south.get("Gadget").?.items.len);
}

test "group and transform" {
    const sales = [_]Sale{
        .{ .product = "Widget", .amount = 100, .region = "North" },
        .{ .product = "Widget", .amount = 200, .region = "North" },
        .{ .product = "Gadget", .amount = 150, .region = "South" },
    };

    const transformFn = struct {
        fn f(sale: Sale) f32 {
            return sale.amount;
        }
    }.f;

    var groups = try groupAndTransform(Sale, f32, testing.allocator, &sales, getProduct, transformFn);
    defer {
        var it = groups.valueIterator();
        while (it.next()) |list| list.deinit(testing.allocator);
        groups.deinit();
    }

    const widget_amounts = groups.get("Widget").?;
    try testing.expectEqual(@as(usize, 2), widget_amounts.items.len);
    try testing.expectEqual(@as(f32, 100), widget_amounts.items[0]);
    try testing.expectEqual(@as(f32, 200), widget_amounts.items[1]);
}

test "group with filtering" {
    const sales = [_]Sale{
        .{ .product = "Widget", .amount = 100, .region = "North" },
        .{ .product = "Widget", .amount = 200, .region = "South" },
        .{ .product = "Gadget", .amount = 150, .region = "North" },
        .{ .product = "Gadget", .amount = 120, .region = "South" },
    };

    const filterFn = struct {
        fn f(sale: Sale) bool {
            return sale.amount >= 150;
        }
    }.f;

    var groups = try groupByWhere(Sale, testing.allocator, &sales, getProduct, filterFn);
    defer {
        var it = groups.valueIterator();
        while (it.next()) |list| list.deinit(testing.allocator);
        groups.deinit();
    }

    const widgets = groups.get("Widget").?;
    try testing.expectEqual(@as(usize, 1), widgets.items.len);
    try testing.expectEqual(@as(f32, 200), widgets.items[0].amount);

    const gadgets = groups.get("Gadget").?;
    try testing.expectEqual(@as(usize, 1), gadgets.items.len);
    try testing.expectEqual(@as(f32, 150), gadgets.items[0].amount);
}

test "flatten grouped data" {
    const sales = [_]Sale{
        .{ .product = "Widget", .amount = 100, .region = "North" },
        .{ .product = "Gadget", .amount = 150, .region = "South" },
        .{ .product = "Widget", .amount = 200, .region = "North" },
    };

    var groups = try groupBy(Sale, []const u8, testing.allocator, &sales, getProduct);
    defer {
        var it = groups.valueIterator();
        while (it.next()) |list| list.deinit(testing.allocator);
        groups.deinit();
    }

    const flattened = try flatten(Sale, testing.allocator, groups);
    defer testing.allocator.free(flattened);

    try testing.expectEqual(@as(usize, 3), flattened.len);
}

test "grouping by range buckets" {
    const people = [_]Person{
        .{ .name = "Alice", .age = 10 },
        .{ .name = "Bob", .age = 15 },
        .{ .name = "Charlie", .age = 30 },
        .{ .name = "David", .age = 70 },
    };

    var groups = try groupByGeneric(Person, AgeBucket, testing.allocator, &people, getAgeBucket);
    defer {
        var it = groups.valueIterator();
        while (it.next()) |list| list.deinit(testing.allocator);
        groups.deinit();
    }

    try testing.expectEqual(@as(usize, 1), groups.get(.child).?.items.len);
    try testing.expectEqual(@as(usize, 1), groups.get(.teen).?.items.len);
    try testing.expectEqual(@as(usize, 1), groups.get(.adult).?.items.len);
    try testing.expectEqual(@as(usize, 1), groups.get(.senior).?.items.len);
}

test "grouping by composite key" {
    const sales = [_]Sale{
        .{ .product = "Widget", .amount = 100, .region = "North" },
        .{ .product = "Widget", .amount = 150, .region = "South" },
        .{ .product = "Gadget", .amount = 200, .region = "North" },
        .{ .product = "Widget", .amount = 120, .region = "North" },
    };

    var groups = std.HashMap(
        CompositeKey,
        std.ArrayList(Sale),
        CompositeContext,
        std.hash_map.default_max_load_percentage,
    ).init(testing.allocator);
    defer {
        var it = groups.valueIterator();
        while (it.next()) |list| list.deinit(testing.allocator);
        groups.deinit();
    }

    for (sales) |sale| {
        const key = getCompositeKey(sale);
        const entry = try groups.getOrPut(key);
        if (!entry.found_existing) {
            entry.value_ptr.* = std.ArrayList(Sale){};
        }
        try entry.value_ptr.append(testing.allocator, sale);
    }

    const north_widget = groups.get(.{ .region = "North", .product = "Widget" }).?;
    try testing.expectEqual(@as(usize, 2), north_widget.items.len);

    const south_widget = groups.get(.{ .region = "South", .product = "Widget" }).?;
    try testing.expectEqual(@as(usize, 1), south_widget.items.len);
}

test "grouping empty slice" {
    const sales: []const Sale = &[_]Sale{};

    var groups = try groupBy(Sale, []const u8, testing.allocator, sales, getProduct);
    defer {
        var it = groups.valueIterator();
        while (it.next()) |list| list.deinit(testing.allocator);
        groups.deinit();
    }

    try testing.expectEqual(@as(usize, 0), groups.count());
}

test "grouping single item" {
    const sales = [_]Sale{
        .{ .product = "Widget", .amount = 100, .region = "North" },
    };

    var groups = try groupBy(Sale, []const u8, testing.allocator, &sales, getProduct);
    defer {
        var it = groups.valueIterator();
        while (it.next()) |list| list.deinit(testing.allocator);
        groups.deinit();
    }

    try testing.expectEqual(@as(usize, 1), groups.count());
    try testing.expectEqual(@as(usize, 1), groups.get("Widget").?.items.len);
}
