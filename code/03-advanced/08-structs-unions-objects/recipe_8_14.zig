// Recipe 8.14: Implementing Custom Containers
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: generic_stack
// Generic stack container
fn Stack(comptime T: type) type {
    return struct {
        items: []T,
        len: usize,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .items = &[_]T{},
                .len = 0,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            if (self.items.len > 0) {
                self.allocator.free(self.items);
            }
        }

        pub fn push(self: *Self, item: T) !void {
            if (self.len >= self.items.len) {
                const new_cap = if (self.items.len == 0) 4 else self.items.len * 2;
                const new_items = try self.allocator.realloc(self.items, new_cap);
                self.items = new_items;
            }
            self.items[self.len] = item;
            self.len += 1;
        }

        pub fn pop(self: *Self) ?T {
            if (self.len == 0) return null;
            self.len -= 1;
            return self.items[self.len];
        }

        pub fn peek(self: *const Self) ?T {
            if (self.len == 0) return null;
            return self.items[self.len - 1];
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.len == 0;
        }

        pub fn size(self: *const Self) usize {
            return self.len;
        }
    };
}
// ANCHOR_END: generic_stack

test "generic stack" {
    var stack = Stack(i32).init(testing.allocator);
    defer stack.deinit();

    try testing.expect(stack.isEmpty());

    try stack.push(10);
    try stack.push(20);
    try stack.push(30);

    try testing.expectEqual(@as(usize, 3), stack.size());
    try testing.expectEqual(@as(i32, 30), stack.peek().?);

    try testing.expectEqual(@as(i32, 30), stack.pop().?);
    try testing.expectEqual(@as(i32, 20), stack.pop().?);
    try testing.expectEqual(@as(usize, 1), stack.size());
}

// ANCHOR: circular_buffer
// Circular buffer (ring buffer)
fn CircularBuffer(comptime T: type, comptime capacity: usize) type {
    return struct {
        buffer: [capacity]T,
        read_index: usize,
        write_index: usize,
        count: usize,

        const Self = @This();

        pub fn init() Self {
            return Self{
                .buffer = undefined,
                .read_index = 0,
                .write_index = 0,
                .count = 0,
            };
        }

        pub fn write(self: *Self, item: T) !void {
            if (self.isFull()) return error.BufferFull;

            self.buffer[self.write_index] = item;
            self.write_index = (self.write_index + 1) % capacity;
            self.count += 1;
        }

        pub fn read(self: *Self) ?T {
            if (self.isEmpty()) return null;

            const item = self.buffer[self.read_index];
            self.read_index = (self.read_index + 1) % capacity;
            self.count -= 1;
            return item;
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.count == 0;
        }

        pub fn isFull(self: *const Self) bool {
            return self.count == capacity;
        }

        pub fn size(self: *const Self) usize {
            return self.count;
        }
    };
}
// ANCHOR_END: circular_buffer

test "circular buffer" {
    var buffer = CircularBuffer(u8, 4).init();

    try testing.expect(buffer.isEmpty());

    try buffer.write(1);
    try buffer.write(2);
    try buffer.write(3);

    try testing.expectEqual(@as(usize, 3), buffer.size());

    try testing.expectEqual(@as(u8, 1), buffer.read().?);
    try testing.expectEqual(@as(u8, 2), buffer.read().?);

    try buffer.write(4);
    try buffer.write(5);
    try buffer.write(6);

    try testing.expect(buffer.isFull());
    const result = buffer.write(7);
    try testing.expectError(error.BufferFull, result);
}

// ANCHOR: linked_list
// Singly linked list
fn LinkedList(comptime T: type) type {
    return struct {
        const Node = struct {
            data: T,
            next: ?*Node,
        };

        head: ?*Node,
        tail: ?*Node,
        len: usize,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .head = null,
                .tail = null,
                .len = 0,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            var current = self.head;
            while (current) |node| {
                const next = node.next;
                self.allocator.destroy(node);
                current = next;
            }
        }

        pub fn append(self: *Self, data: T) !void {
            const node = try self.allocator.create(Node);
            node.* = Node{ .data = data, .next = null };

            if (self.tail) |tail| {
                tail.next = node;
            } else {
                self.head = node;
            }

            self.tail = node;
            self.len += 1;
        }

        pub fn prepend(self: *Self, data: T) !void {
            const node = try self.allocator.create(Node);
            node.* = Node{ .data = data, .next = self.head };

            self.head = node;
            if (self.tail == null) {
                self.tail = node;
            }

            self.len += 1;
        }

        pub fn removeFirst(self: *Self) ?T {
            const head = self.head orelse return null;
            const data = head.data;

            self.head = head.next;
            if (self.head == null) {
                self.tail = null;
            }

            self.allocator.destroy(head);
            self.len -= 1;
            return data;
        }

        pub fn size(self: *const Self) usize {
            return self.len;
        }
    };
}
// ANCHOR_END: linked_list

test "linked list" {
    var list = LinkedList(i32).init(testing.allocator);
    defer list.deinit();

    try list.append(10);
    try list.append(20);
    try list.prepend(5);

    try testing.expectEqual(@as(usize, 3), list.size());

    try testing.expectEqual(@as(i32, 5), list.removeFirst().?);
    try testing.expectEqual(@as(i32, 10), list.removeFirst().?);
    try testing.expectEqual(@as(usize, 1), list.size());
}

// ANCHOR: priority_queue
// Min-heap based priority queue
fn PriorityQueue(comptime T: type) type {
    return struct {
        items: std.ArrayList(T),

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            _ = allocator;
            return Self{
                .items = std.ArrayList(T){},
            };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.items.deinit(allocator);
        }

        pub fn insert(self: *Self, allocator: std.mem.Allocator, value: T) !void {
            try self.items.append(allocator, value);
            self.bubbleUp(self.items.items.len - 1);
        }

        pub fn extractMin(self: *Self) ?T {
            if (self.items.items.len == 0) return null;

            const min = self.items.items[0];

            if (self.items.items.len > 1) {
                const last_idx = self.items.items.len - 1;
                self.items.items[0] = self.items.items[last_idx];
                _ = self.items.pop();
                self.bubbleDown(0);
            } else {
                _ = self.items.pop();
            }

            return min;
        }

        pub fn peek(self: *const Self) ?T {
            if (self.items.items.len == 0) return null;
            return self.items.items[0];
        }

        pub fn size(self: *const Self) usize {
            return self.items.items.len;
        }

        fn bubbleUp(self: *Self, index: usize) void {
            if (index == 0) return;

            const parent_index = (index - 1) / 2;
            if (self.items.items[index] < self.items.items[parent_index]) {
                const temp = self.items.items[index];
                self.items.items[index] = self.items.items[parent_index];
                self.items.items[parent_index] = temp;
                self.bubbleUp(parent_index);
            }
        }

        fn bubbleDown(self: *Self, index: usize) void {
            const left = 2 * index + 1;
            const right = 2 * index + 2;
            var smallest = index;

            if (left < self.items.items.len and self.items.items[left] < self.items.items[smallest]) {
                smallest = left;
            }

            if (right < self.items.items.len and self.items.items[right] < self.items.items[smallest]) {
                smallest = right;
            }

            if (smallest != index) {
                const temp = self.items.items[index];
                self.items.items[index] = self.items.items[smallest];
                self.items.items[smallest] = temp;
                self.bubbleDown(smallest);
            }
        }
    };
}
// ANCHOR_END: priority_queue

test "priority queue" {
    var pq = PriorityQueue(i32).init(testing.allocator);
    defer pq.deinit(testing.allocator);

    try pq.insert(testing.allocator, 30);
    try pq.insert(testing.allocator, 10);
    try pq.insert(testing.allocator, 20);
    try pq.insert(testing.allocator, 5);

    try testing.expectEqual(@as(i32, 5), pq.peek().?);
    try testing.expectEqual(@as(i32, 5), pq.extractMin().?);
    try testing.expectEqual(@as(i32, 10), pq.extractMin().?);
    try testing.expectEqual(@as(i32, 20), pq.extractMin().?);
    try testing.expectEqual(@as(usize, 1), pq.size());
}

// ANCHOR: bounded_queue
// Bounded queue with fixed capacity
fn BoundedQueue(comptime T: type, comptime max_size: usize) type {
    return struct {
        buffer: [max_size]T,
        head: usize,
        tail: usize,
        count: usize,

        const Self = @This();

        pub fn init() Self {
            return Self{
                .buffer = undefined,
                .head = 0,
                .tail = 0,
                .count = 0,
            };
        }

        pub fn enqueue(self: *Self, item: T) !void {
            if (self.count >= max_size) return error.QueueFull;

            self.buffer[self.tail] = item;
            self.tail = (self.tail + 1) % max_size;
            self.count += 1;
        }

        pub fn dequeue(self: *Self) ?T {
            if (self.count == 0) return null;

            const item = self.buffer[self.head];
            self.head = (self.head + 1) % max_size;
            self.count -= 1;
            return item;
        }

        pub fn peek(self: *const Self) ?T {
            if (self.count == 0) return null;
            return self.buffer[self.head];
        }

        pub fn size(self: *const Self) usize {
            return self.count;
        }

        pub fn isFull(self: *const Self) bool {
            return self.count >= max_size;
        }
    };
}
// ANCHOR_END: bounded_queue

test "bounded queue" {
    var queue = BoundedQueue([]const u8, 3).init();

    try queue.enqueue("first");
    try queue.enqueue("second");
    try queue.enqueue("third");

    try testing.expect(queue.isFull());

    try testing.expectEqualStrings("first", queue.dequeue().?);
    try testing.expectEqualStrings("second", queue.peek().?);
    try testing.expectEqual(@as(usize, 2), queue.size());
}

// ANCHOR: set_container
// Simple hash set
fn Set(comptime T: type) type {
    return struct {
        map: std.AutoHashMap(T, void),

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .map = std.AutoHashMap(T, void).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.map.deinit();
        }

        pub fn add(self: *Self, item: T) !void {
            try self.map.put(item, {});
        }

        pub fn remove(self: *Self, item: T) bool {
            return self.map.remove(item);
        }

        pub fn contains(self: *const Self, item: T) bool {
            return self.map.contains(item);
        }

        pub fn size(self: *const Self) usize {
            return self.map.count();
        }

        pub fn clear(self: *Self) void {
            self.map.clearRetainingCapacity();
        }
    };
}
// ANCHOR_END: set_container

test "set container" {
    var set = Set(i32).init(testing.allocator);
    defer set.deinit();

    try set.add(10);
    try set.add(20);
    try set.add(10); // Duplicate

    try testing.expectEqual(@as(usize, 2), set.size());
    try testing.expect(set.contains(10));
    try testing.expect(!set.contains(30));

    try testing.expect(set.remove(10));
    try testing.expect(!set.contains(10));
    try testing.expectEqual(@as(usize, 1), set.size());
}

// ANCHOR: doubly_linked_list
// Doubly linked list for bidirectional iteration
fn DoublyLinkedList(comptime T: type) type {
    return struct {
        const Node = struct {
            data: T,
            prev: ?*Node,
            next: ?*Node,
        };

        head: ?*Node,
        tail: ?*Node,
        len: usize,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{
                .head = null,
                .tail = null,
                .len = 0,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            var current = self.head;
            while (current) |node| {
                const next = node.next;
                self.allocator.destroy(node);
                current = next;
            }
        }

        pub fn append(self: *Self, data: T) !void {
            const node = try self.allocator.create(Node);
            node.* = Node{ .data = data, .prev = self.tail, .next = null };

            if (self.tail) |tail| {
                tail.next = node;
            } else {
                self.head = node;
            }

            self.tail = node;
            self.len += 1;
        }

        pub fn removeLast(self: *Self) ?T {
            const tail = self.tail orelse return null;
            const data = tail.data;

            if (tail.prev) |prev| {
                prev.next = null;
                self.tail = prev;
            } else {
                self.head = null;
                self.tail = null;
            }

            self.allocator.destroy(tail);
            self.len -= 1;
            return data;
        }

        pub fn size(self: *const Self) usize {
            return self.len;
        }
    };
}
// ANCHOR_END: doubly_linked_list

test "doubly linked list" {
    var list = DoublyLinkedList(i32).init(testing.allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    try list.append(3);

    try testing.expectEqual(@as(usize, 3), list.size());
    try testing.expectEqual(@as(i32, 3), list.removeLast().?);
    try testing.expectEqual(@as(i32, 2), list.removeLast().?);
    try testing.expectEqual(@as(usize, 1), list.size());
}

// ANCHOR: iterator_pattern
// Container with iterator
const IntRange = struct {
    start: i32,
    end: i32,

    pub fn init(start: i32, end: i32) IntRange {
        return IntRange{ .start = start, .end = end };
    }

    pub const Iterator = struct {
        current: i32,
        end: i32,

        pub fn next(self: *Iterator) ?i32 {
            if (self.current >= self.end) return null;
            const value = self.current;
            self.current += 1;
            return value;
        }
    };

    pub fn iterator(self: *const IntRange) Iterator {
        return Iterator{
            .current = self.start,
            .end = self.end,
        };
    }
};
// ANCHOR_END: iterator_pattern

test "iterator pattern" {
    const range = IntRange.init(0, 5);
    var iter = range.iterator();

    try testing.expectEqual(@as(i32, 0), iter.next().?);
    try testing.expectEqual(@as(i32, 1), iter.next().?);
    try testing.expectEqual(@as(i32, 2), iter.next().?);
    try testing.expectEqual(@as(i32, 3), iter.next().?);
    try testing.expectEqual(@as(i32, 4), iter.next().?);
    try testing.expect(iter.next() == null);
}

// Comprehensive test
test "comprehensive custom containers" {
    var stack = Stack(i32).init(testing.allocator);
    defer stack.deinit();
    try stack.push(42);
    try testing.expectEqual(@as(i32, 42), stack.pop().?);

    var buffer = CircularBuffer(u8, 8).init();
    try buffer.write(100);
    try testing.expectEqual(@as(u8, 100), buffer.read().?);

    var list = LinkedList(i32).init(testing.allocator);
    defer list.deinit();
    try list.append(10);
    try testing.expectEqual(@as(usize, 1), list.size());

    var set = Set(i32).init(testing.allocator);
    defer set.deinit();
    try set.add(5);
    try testing.expect(set.contains(5));
}
