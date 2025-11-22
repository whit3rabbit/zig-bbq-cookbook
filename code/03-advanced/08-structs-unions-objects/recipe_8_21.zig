// Recipe 8.21: Managing Memory in Cyclic Data Structures
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: arena_allocator
// Use arena allocator for cyclic structures
const Node = struct {
    value: i32,
    next: ?*Node,
    prev: ?*Node,

    pub fn init(allocator: std.mem.Allocator, value: i32) !*Node {
        const node = try allocator.create(Node);
        node.* = Node{
            .value = value,
            .next = null,
            .prev = null,
        };
        return node;
    }
};

const CircularList = struct {
    arena: std.heap.ArenaAllocator,

    pub fn init(parent_allocator: std.mem.Allocator) CircularList {
        return CircularList{
            .arena = std.heap.ArenaAllocator.init(parent_allocator),
        };
    }

    pub fn deinit(self: *CircularList) void {
        // Arena frees everything at once, even with cycles
        self.arena.deinit();
    }

    pub fn createCircle(self: *CircularList, values: []const i32) !*Node {
        if (values.len == 0) return error.EmptyList;

        const allocator = self.arena.allocator();
        const first = try Node.init(allocator, values[0]);
        var current = first;

        for (values[1..]) |value| {
            const new_node = try Node.init(allocator, value);
            current.next = new_node;
            new_node.prev = current;
            current = new_node;
        }

        // Create cycle
        current.next = first;
        first.prev = current;

        return first;
    }
};

test "arena allocator" {
    var list = CircularList.init(testing.allocator);
    defer list.deinit();

    const values = [_]i32{ 1, 2, 3 };
    const head = try list.createCircle(&values);

    try testing.expectEqual(@as(i32, 1), head.value);
    try testing.expectEqual(@as(i32, 2), head.next.?.value);
    try testing.expectEqual(@as(i32, 1), head.next.?.next.?.next.?.value);
}
// ANCHOR_END: arena_allocator

// ANCHOR: weak_reference
// Simulate weak references using optionals
const TreeNode = struct {
    value: i32,
    children: std.ArrayList(*TreeNode),
    parent: ?*TreeNode, // Weak reference - not owned

    pub fn init(allocator: std.mem.Allocator, value: i32) !*TreeNode {
        const node = try allocator.create(TreeNode);
        node.* = TreeNode{
            .value = value,
            .children = std.ArrayList(*TreeNode){},
            .parent = null,
        };
        return node;
    }

    pub fn addChild(self: *TreeNode, allocator: std.mem.Allocator, child: *TreeNode) !void {
        try self.children.append(allocator, child);
        child.parent = self; // Weak reference
    }

    pub fn deinit(self: *TreeNode, allocator: std.mem.Allocator) void {
        for (self.children.items) |child| {
            child.deinit(allocator);
        }
        self.children.deinit(allocator);
        allocator.destroy(self);
    }
};

test "weak reference" {
    const root = try TreeNode.init(testing.allocator, 1);
    defer root.deinit(testing.allocator);

    const child1 = try TreeNode.init(testing.allocator, 2);
    const child2 = try TreeNode.init(testing.allocator, 3);

    try root.addChild(testing.allocator, child1);
    try root.addChild(testing.allocator, child2);

    try testing.expectEqual(@as(i32, 1), child1.parent.?.value);
    try testing.expectEqual(@as(usize, 2), root.children.items.len);
}
// ANCHOR_END: weak_reference

// ANCHOR: break_cycles
// Explicitly break cycles before cleanup
const GraphNode = struct {
    id: u32,
    neighbors: std.ArrayList(*GraphNode),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, id: u32) !*GraphNode {
        const node = try allocator.create(GraphNode);
        node.* = GraphNode{
            .id = id,
            .neighbors = std.ArrayList(*GraphNode){},
            .allocator = allocator,
        };
        return node;
    }

    pub fn connect(self: *GraphNode, other: *GraphNode) !void {
        try self.neighbors.append(self.allocator, other);
        try other.neighbors.append(other.allocator, self);
    }

    pub fn breakCycles(self: *GraphNode) void {
        self.neighbors.deinit(self.allocator);
        self.neighbors = std.ArrayList(*GraphNode){};
    }

    pub fn deinit(self: *GraphNode) void {
        self.neighbors.deinit(self.allocator);
        self.allocator.destroy(self);
    }
};

test "break cycles" {
    const node1 = try GraphNode.init(testing.allocator, 1);
    const node2 = try GraphNode.init(testing.allocator, 2);

    try node1.connect(node2);
    try testing.expectEqual(@as(usize, 1), node1.neighbors.items.len);

    // Break cycles before cleanup
    node1.breakCycles();
    node2.breakCycles();

    node1.deinit();
    node2.deinit();
}
// ANCHOR_END: break_cycles

// ANCHOR: reference_counting
// Reference counting for shared ownership
const RefCounted = struct {
    data: i32,
    ref_count: usize,

    pub fn init(allocator: std.mem.Allocator, data: i32) !*RefCounted {
        const self = try allocator.create(RefCounted);
        self.* = RefCounted{
            .data = data,
            .ref_count = 1,
        };
        return self;
    }

    pub fn retain(self: *RefCounted) void {
        self.ref_count += 1;
    }

    pub fn release(self: *RefCounted, allocator: std.mem.Allocator) void {
        self.ref_count -= 1;
        if (self.ref_count == 0) {
            allocator.destroy(self);
        }
    }
};

const SharedPtr = struct {
    ptr: ?*RefCounted,

    pub fn init(allocator: std.mem.Allocator, data: i32) !SharedPtr {
        return SharedPtr{
            .ptr = try RefCounted.init(allocator, data),
        };
    }

    pub fn clone(self: *const SharedPtr) SharedPtr {
        if (self.ptr) |p| {
            p.retain();
        }
        return SharedPtr{ .ptr = self.ptr };
    }

    pub fn deinit(self: *SharedPtr, allocator: std.mem.Allocator) void {
        if (self.ptr) |p| {
            p.release(allocator);
            self.ptr = null;
        }
    }
};

test "reference counting" {
    var ptr1 = try SharedPtr.init(testing.allocator, 42);
    defer ptr1.deinit(testing.allocator);

    var ptr2 = ptr1.clone();
    defer ptr2.deinit(testing.allocator);

    try testing.expectEqual(@as(usize, 2), ptr1.ptr.?.ref_count);
    try testing.expectEqual(@as(i32, 42), ptr2.ptr.?.data);
}
// ANCHOR_END: reference_counting

// ANCHOR: owned_pointers
// Clear ownership with owned vs borrowed pointers
const ListNode = struct {
    value: i32,
    next: ?*ListNode, // Owned
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, value: i32) !*ListNode {
        const node = try allocator.create(ListNode);
        node.* = ListNode{
            .value = value,
            .next = null,
            .allocator = allocator,
        };
        return node;
    }

    pub fn append(self: *ListNode, value: i32) !void {
        if (self.next) |next| {
            try next.append(value);
        } else {
            const new_node = try ListNode.init(self.allocator, value);
            self.next = new_node;
        }
    }

    pub fn deinit(self: *ListNode) void {
        if (self.next) |next| {
            next.deinit();
        }
        self.allocator.destroy(self);
    }
};

const ListIterator = struct {
    current: ?*ListNode, // Borrowed - doesn't own

    pub fn init(head: *ListNode) ListIterator {
        return ListIterator{ .current = head };
    }

    pub fn next(self: *ListIterator) ?i32 {
        if (self.current) |node| {
            const value = node.value;
            self.current = node.next;
            return value;
        }
        return null;
    }
};

test "owned pointers" {
    const head = try ListNode.init(testing.allocator, 1);
    defer head.deinit();

    try head.append(2);
    try head.append(3);

    var iter = ListIterator.init(head);
    try testing.expectEqual(@as(i32, 1), iter.next().?);
    try testing.expectEqual(@as(i32, 2), iter.next().?);
}
// ANCHOR_END: owned_pointers

// ANCHOR: index_based
// Use indices instead of pointers
const NodePool = struct {
    const NodeIndex = u32;

    const PoolNode = struct {
        value: i32,
        next: ?NodeIndex,
        prev: ?NodeIndex,
    };

    nodes: std.ArrayList(PoolNode),

    pub fn init(allocator: std.mem.Allocator) NodePool {
        _ = allocator;
        return NodePool{
            .nodes = std.ArrayList(PoolNode){},
        };
    }

    pub fn deinit(self: *NodePool, allocator: std.mem.Allocator) void {
        self.nodes.deinit(allocator);
    }

    pub fn create(self: *NodePool, allocator: std.mem.Allocator, value: i32) !NodeIndex {
        const index: NodeIndex = @intCast(self.nodes.items.len);
        try self.nodes.append(allocator, PoolNode{
            .value = value,
            .next = null,
            .prev = null,
        });
        return index;
    }

    pub fn connect(self: *NodePool, a: NodeIndex, b: NodeIndex) void {
        self.nodes.items[a].next = b;
        self.nodes.items[b].prev = a;
    }

    pub fn get(self: *const NodePool, index: NodeIndex) i32 {
        return self.nodes.items[index].value;
    }
};

test "index based" {
    var pool = NodePool.init(testing.allocator);
    defer pool.deinit(testing.allocator);

    const idx1 = try pool.create(testing.allocator, 10);
    const idx2 = try pool.create(testing.allocator, 20);

    pool.connect(idx1, idx2);

    try testing.expectEqual(@as(i32, 10), pool.get(idx1));
    try testing.expectEqual(@as(i32, 20), pool.get(idx2));
}
// ANCHOR_END: index_based

// ANCHOR: generation_indices
// Generation indices to detect dangling references
const GenerationalIndex = struct {
    index: u32,
    generation: u32,
};

const GenerationalPool = struct {
    const Entry = struct {
        value: i32,
        generation: u32,
        is_alive: bool,
    };

    entries: std.ArrayList(Entry),
    free_list: std.ArrayList(u32),

    pub fn init(allocator: std.mem.Allocator) GenerationalPool {
        _ = allocator;
        return GenerationalPool{
            .entries = std.ArrayList(Entry){},
            .free_list = std.ArrayList(u32){},
        };
    }

    pub fn deinit(self: *GenerationalPool, allocator: std.mem.Allocator) void {
        self.entries.deinit(allocator);
        self.free_list.deinit(allocator);
    }

    pub fn allocate(self: *GenerationalPool, allocator: std.mem.Allocator, value: i32) !GenerationalIndex {
        if (self.free_list.items.len > 0) {
            const index = self.free_list.pop().?;
            const entry = &self.entries.items[index];
            entry.value = value;
            entry.is_alive = true;
            return GenerationalIndex{
                .index = index,
                .generation = entry.generation,
            };
        } else {
            const index: u32 = @intCast(self.entries.items.len);
            try self.entries.append(allocator, Entry{
                .value = value,
                .generation = 0,
                .is_alive = true,
            });
            return GenerationalIndex{
                .index = index,
                .generation = 0,
            };
        }
    }

    pub fn free(self: *GenerationalPool, allocator: std.mem.Allocator, idx: GenerationalIndex) !void {
        const entry = &self.entries.items[idx.index];
        if (entry.generation == idx.generation and entry.is_alive) {
            entry.is_alive = false;
            entry.generation += 1;
            try self.free_list.append(allocator, idx.index);
        }
    }

    pub fn get(self: *const GenerationalPool, idx: GenerationalIndex) ?i32 {
        const entry = self.entries.items[idx.index];
        if (entry.generation == idx.generation and entry.is_alive) {
            return entry.value;
        }
        return null;
    }
};

test "generation indices" {
    var pool = GenerationalPool.init(testing.allocator);
    defer pool.deinit(testing.allocator);

    const idx1 = try pool.allocate(testing.allocator, 100);
    try testing.expectEqual(@as(i32, 100), pool.get(idx1).?);

    try pool.free(testing.allocator, idx1);
    try testing.expect(pool.get(idx1) == null);

    const idx2 = try pool.allocate(testing.allocator, 200);
    try testing.expectEqual(@as(i32, 200), pool.get(idx2).?);
}
// ANCHOR_END: generation_indices

// ANCHOR: doubly_linked_arena
// Doubly-linked list with arena allocator
const DoublyLinkedList = struct {
    const DNode = struct {
        value: i32,
        next: ?*DNode,
        prev: ?*DNode,
    };

    arena: std.heap.ArenaAllocator,
    head: ?*DNode,
    tail: ?*DNode,

    pub fn init(parent_allocator: std.mem.Allocator) DoublyLinkedList {
        return DoublyLinkedList{
            .arena = std.heap.ArenaAllocator.init(parent_allocator),
            .head = null,
            .tail = null,
        };
    }

    pub fn deinit(self: *DoublyLinkedList) void {
        self.arena.deinit();
    }

    pub fn append(self: *DoublyLinkedList, value: i32) !void {
        const allocator = self.arena.allocator();
        const node = try allocator.create(DNode);
        node.* = DNode{
            .value = value,
            .next = null,
            .prev = self.tail,
        };

        if (self.tail) |tail| {
            tail.next = node;
        } else {
            self.head = node;
        }
        self.tail = node;
    }

    pub fn makeCircular(self: *DoublyLinkedList) void {
        if (self.head) |head| {
            if (self.tail) |tail| {
                tail.next = head;
                head.prev = tail;
            }
        }
    }
};

test "doubly linked arena" {
    var list = DoublyLinkedList.init(testing.allocator);
    defer list.deinit();

    try list.append(1);
    try list.append(2);
    try list.append(3);

    list.makeCircular();

    try testing.expectEqual(@as(i32, 1), list.head.?.value);
    try testing.expectEqual(@as(i32, 1), list.tail.?.next.?.value);
}
// ANCHOR_END: doubly_linked_arena

// Comprehensive test
test "comprehensive cyclic memory management" {
    // Arena for cycles
    var circular = CircularList.init(testing.allocator);
    defer circular.deinit();

    const vals = [_]i32{ 5, 10, 15 };
    const head = try circular.createCircle(&vals);
    try testing.expectEqual(@as(i32, 5), head.value);

    // Weak references
    const tree_root = try TreeNode.init(testing.allocator, 100);
    defer tree_root.deinit(testing.allocator);

    const tree_child = try TreeNode.init(testing.allocator, 200);
    try tree_root.addChild(testing.allocator, tree_child);
    try testing.expectEqual(@as(i32, 100), tree_child.parent.?.value);

    // Index-based
    var pool = NodePool.init(testing.allocator);
    defer pool.deinit(testing.allocator);

    const idx = try pool.create(testing.allocator, 42);
    try testing.expectEqual(@as(i32, 42), pool.get(idx));
}
