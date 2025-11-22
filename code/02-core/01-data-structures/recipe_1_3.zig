// Recipe 1.3: Ring Buffers and Keeping Last N Items
// Target Zig Version: 0.15.2
//
// Demonstrates how to use circular buffers to track the most recent N elements.
// Run: zig test code/02-core/01-data-structures/recipe_1_3.zig

const std = @import("std");
const testing = std.testing;

// ==============================================================================
// Basic Ring Buffer Implementation
// ==============================================================================

// ANCHOR: ring_buffer_impl
fn RingBuffer(comptime T: type, comptime size: usize) type {
    return struct {
        data: [size]T,
        write_index: usize,
        count: usize,

        const Self = @This();

        pub fn init() Self {
            return .{
                .data = undefined,
                .write_index = 0,
                .count = 0,
            };
        }

        pub fn push(self: *Self, item: T) void {
            self.data[self.write_index] = item;
            self.write_index = (self.write_index + 1) % size;
            if (self.count < size) {
                self.count += 1;
            }
        }

        pub fn get(self: Self, index: usize) ?T {
            if (index >= self.count) return null;
            const actual_index = if (self.count < size)
                index
            else
                (self.write_index + index) % size;
            return self.data[actual_index];
        }

        pub fn len(self: Self) usize {
            return self.count;
        }

        pub fn isFull(self: Self) bool {
            return self.count >= size;
        }
    };
}
// ANCHOR_END: ring_buffer_impl

// ANCHOR: basic_usage
test "ring buffer - basic push and get" {
    var buffer = RingBuffer(i32, 5).init();

    buffer.push(1);
    buffer.push(2);
    buffer.push(3);

    try testing.expectEqual(@as(usize, 3), buffer.len());
    try testing.expectEqual(@as(?i32, 1), buffer.get(0));
    try testing.expectEqual(@as(?i32, 2), buffer.get(1));
    try testing.expectEqual(@as(?i32, 3), buffer.get(2));
}
// ANCHOR_END: basic_usage

test "ring buffer - wraps around when full" {
    var buffer = RingBuffer(i32, 3).init();

    buffer.push(1);
    buffer.push(2);
    buffer.push(3);
    try testing.expect(buffer.isFull());

    // Now it wraps - 4 overwrites 1
    buffer.push(4);
    try testing.expectEqual(@as(?i32, 2), buffer.get(0));
    try testing.expectEqual(@as(?i32, 3), buffer.get(1));
    try testing.expectEqual(@as(?i32, 4), buffer.get(2));

    // 5 overwrites 2
    buffer.push(5);
    try testing.expectEqual(@as(?i32, 3), buffer.get(0));
    try testing.expectEqual(@as(?i32, 4), buffer.get(1));
    try testing.expectEqual(@as(?i32, 5), buffer.get(2));
}

test "ring buffer - out of bounds returns null" {
    var buffer = RingBuffer(i32, 5).init();

    buffer.push(10);
    buffer.push(20);

    try testing.expectEqual(@as(?i32, 10), buffer.get(0));
    try testing.expectEqual(@as(?i32, 20), buffer.get(1));
    try testing.expectEqual(@as(?i32, null), buffer.get(2));
    try testing.expectEqual(@as(?i32, null), buffer.get(10));
}

// ==============================================================================
// Simple Recent Items Implementation (Simple non-ordered buffer)
// ==============================================================================

const RecentItems = struct {
    items: [10]i32,
    write_index: usize,
    count: usize,

    pub fn init() RecentItems {
        return .{
            .items = [_]i32{0} ** 10,
            .write_index = 0,
            .count = 0,
        };
    }

    pub fn add(self: *RecentItems, item: i32) void {
        self.items[self.write_index] = item;
        self.write_index = (self.write_index + 1) % self.items.len;
        if (self.count < self.items.len) {
            self.count += 1;
        }
    }

    pub fn len(self: RecentItems) usize {
        return self.count;
    }
};

test "recent items - tracks count correctly" {
    var recent = RecentItems.init();

    try testing.expectEqual(@as(usize, 0), recent.len());

    recent.add(10);
    try testing.expectEqual(@as(usize, 1), recent.len());

    recent.add(20);
    recent.add(30);
    try testing.expectEqual(@as(usize, 3), recent.len());
}

test "recent items - fills to capacity" {
    var recent = RecentItems.init();

    for (0..10) |i| {
        recent.add(@as(i32, @intCast(i)));
    }

    try testing.expectEqual(@as(usize, 10), recent.len());
}

test "recent items - wraps without growing past capacity" {
    var recent = RecentItems.init();

    // Add more than capacity
    for (0..15) |i| {
        recent.add(@as(i32, @intCast(i)));
    }

    // Count should max out at 10
    try testing.expectEqual(@as(usize, 10), recent.len());
}

// ==============================================================================
// Dynamic Ring Buffer
// ==============================================================================

fn DynamicRingBuffer(comptime T: type) type {
    return struct {
        data: std.ArrayList(T),
        write_index: usize,
        capacity: usize,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator, capacity: usize) !Self {
            // Validate capacity to prevent division by zero
            if (capacity == 0) return error.InvalidCapacity;

            return .{
                .data = std.ArrayList(T){},
                .write_index = 0,
                .capacity = capacity,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.data.deinit(self.allocator);
        }

        pub fn push(self: *Self, item: T) !void {
            if (self.data.items.len < self.capacity) {
                try self.data.append(self.allocator, item);
            } else {
                self.data.items[self.write_index] = item;
            }
            self.write_index = (self.write_index + 1) % self.capacity;
        }

        pub fn items(self: Self) []const T {
            return self.data.items;
        }
    };
}

test "dynamic ring buffer - basic usage" {
    const allocator = testing.allocator;
    var buffer = try DynamicRingBuffer(i32).init(allocator, 3);
    defer buffer.deinit();

    try buffer.push(1);
    try buffer.push(2);
    try buffer.push(3);

    const buf_items = buffer.items();
    try testing.expectEqual(@as(usize, 3), buf_items.len);
    try testing.expectEqual(@as(i32, 1), buf_items[0]);
    try testing.expectEqual(@as(i32, 3), buf_items[2]);
}

test "dynamic ring buffer - wraps around" {
    const allocator = testing.allocator;
    var buffer = try DynamicRingBuffer(i32).init(allocator, 3);
    defer buffer.deinit();

    try buffer.push(1);
    try buffer.push(2);
    try buffer.push(3);
    try buffer.push(4);  // Overwrites 1

    const buf_items = buffer.items();
    try testing.expectEqual(@as(i32, 4), buf_items[0]);  // Position 0 now has 4
    try testing.expectEqual(@as(i32, 2), buf_items[1]);
    try testing.expectEqual(@as(i32, 3), buf_items[2]);
}

test "dynamic ring buffer - rejects zero capacity" {
    const allocator = testing.allocator;

    // Capacity of 0 should return an error
    const result = DynamicRingBuffer(i32).init(allocator, 0);
    try testing.expectError(error.InvalidCapacity, result);
}

// ==============================================================================
// Rolling Average Calculator
// ==============================================================================

const RollingAverage = struct {
    buffer: [10]f64,
    index: usize,
    count: usize,

    pub fn init() RollingAverage {
        return .{
            .buffer = [_]f64{0.0} ** 10,
            .index = 0,
            .count = 0,
        };
    }

    pub fn add(self: *RollingAverage, value: f64) void {
        self.buffer[self.index] = value;
        self.index = (self.index + 1) % self.buffer.len;
        if (self.count < self.buffer.len) {
            self.count += 1;
        }
    }

    pub fn average(self: RollingAverage) f64 {
        if (self.count == 0) return 0.0;

        var sum: f64 = 0.0;
        for (self.buffer[0..self.count]) |val| {
            sum += val;
        }
        return sum / @as(f64, @floatFromInt(self.count));
    }
};

test "rolling average - partial data" {
    var avg = RollingAverage.init();

    avg.add(10.0);
    avg.add(20.0);
    avg.add(30.0);

    const result = avg.average();
    try testing.expectEqual(@as(f64, 20.0), result);
}

test "rolling average - full buffer" {
    var avg = RollingAverage.init();

    // Fill with values 1.0 to 10.0
    for (1..11) |i| {
        avg.add(@as(f64, @floatFromInt(i)));
    }

    // Average of 1..10 = 55/10 = 5.5
    const result = avg.average();
    try testing.expectEqual(@as(f64, 5.5), result);
}

test "rolling average - wraps around" {
    var avg = RollingAverage.init();

    // Fill with 1..10
    for (1..11) |i| {
        avg.add(@as(f64, @floatFromInt(i)));
    }

    // Add more values - these overwrite the oldest
    avg.add(100.0);  // Overwrites 1.0
    avg.add(100.0);  // Overwrites 2.0

    // New average: (3+4+5+6+7+8+9+10+100+100) / 10 = 252/10 = 25.2
    const result = avg.average();
    try testing.expectEqual(@as(f64, 25.2), result);
}

// ==============================================================================
// Practical Example: Simple Event Counter
// ==============================================================================

// ANCHOR: event_counter
fn EventCounter(comptime size: usize) type {
    return struct {
        events: [size]i32,
        write_index: usize,
        count: usize,

        const Self = @This();

        pub fn init() Self {
            return .{
                .events = [_]i32{0} ** size,
                .write_index = 0,
                .count = 0,
            };
        }

        pub fn record(self: *Self, event_id: i32) void {
            self.events[self.write_index] = event_id;
            self.write_index = (self.write_index + 1) % size;
            if (self.count < size) {
                self.count += 1;
            }
        }

        pub fn len(self: Self) usize {
            return self.count;
        }
    };
}

test "event counter - records events" {
    var counter = EventCounter(5).init();

    counter.record(101);
    counter.record(102);
    counter.record(103);

    try testing.expectEqual(@as(usize, 3), counter.len());
}
// ANCHOR_END: event_counter

test "event counter - respects capacity" {
    var counter = EventCounter(3).init();

    counter.record(1);
    counter.record(2);
    counter.record(3);
    counter.record(4);  // Overwrites first
    counter.record(5);  // Overwrites second

    try testing.expectEqual(@as(usize, 3), counter.len());
}
