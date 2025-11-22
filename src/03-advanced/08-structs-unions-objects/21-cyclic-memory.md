## Problem

You need to build circular linked lists, graphs with bidirectional edges, or parent-child references that form cycles. Traditional reference counting or manual cleanup can leak memory or cause use-after-free bugs when cycles prevent normal cleanup.

## Solution

Zig provides several safe patterns for cyclic structures: arena allocators for bulk cleanup, weak references through convention, explicit cycle breaking, reference counting, owned vs borrowed pointer distinction, and index-based references.

### Arena Allocator for Cycles

Use arena allocators to free entire cyclic structures at once:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_21.zig:arena_allocator}}
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
```

The arena frees all nodes regardless of cycles.

### Weak References

Simulate weak references using optionals that don't own memory:

```zig
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
```

Parent pointer doesn't own - only children are freed by the parent.

### Explicit Cycle Breaking

Break cycles before cleanup to avoid leaks:

```zig
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

// Usage
const node1 = try GraphNode.init(allocator, 1);
const node2 = try GraphNode.init(allocator, 2);
try node1.connect(node2);

// Break cycles before cleanup
node1.breakCycles();
node2.breakCycles();
node1.deinit();
node2.deinit();
```

Manual cycle breaking gives explicit control over cleanup order.

### Reference Counting

Implement shared ownership with reference counting:

```zig
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
```

Reference counting handles shared ownership automatically.

### Owned vs Borrowed Pointers

Distinguish owned pointers from borrowed ones through naming:

```zig
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
```

Clear ownership semantics prevent double-free bugs.

### Index-Based References

Avoid pointer cycles entirely by using indices:

```zig
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
```

Indices can't dangle and cleanup is trivial.

### Generational Indices

Detect dangling references with generation counters:

```zig
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
```

Old indices return null instead of accessing wrong data.

## Discussion

Managing cyclic data structures safely requires choosing the right ownership strategy.

### Why Cycles Are Challenging

**Pointer cycles prevent normal cleanup**:
```zig
// A points to B, B points to A
nodeA.next = nodeB;
nodeB.next = nodeA;
// Who frees whom?
```

**Reference counting fails with cycles**:
- A holds reference to B (count = 1)
- B holds reference to A (count = 1)
- Both counts never reach zero
- Memory leaks

**Manual cleanup is error-prone**:
- Double-free if both nodes try to free each other
- Use-after-free if order is wrong
- Easy to miss cleanup paths

### Pattern Selection Guide

**Use arena allocators when**:
- The entire structure has the same lifetime
- You can free everything at once
- Performance matters (fastest allocation)
- Graph algorithms that build then discard

**Use weak references when**:
- Clear parent-child relationship exists
- One direction owns, the other borrows
- Trees, DOM-like structures
- Ownership is hierarchical

**Use explicit cycle breaking when**:
- You need precise control over cleanup
- Cycles are sparse or well-defined
- You can identify all cycle points
- Debugging memory issues

**Use reference counting when**:
- Shared ownership is genuinely needed
- No cycles or cycles are rare
- Objects have independent lifetimes
- Thread-safety is required (with atomic counts)

**Use index-based references when**:
- All objects live in a pool/array
- You want zero-overhead references
- Random access is common
- Serialization is important

**Use generational indices when**:
- Objects are frequently created/destroyed
- Detecting stale references is critical
- Game entity systems
- Memory safety is paramount

### Arena Allocator Advantages

**Bulk deallocation**:
```zig
arena.deinit(); // Frees everything regardless of cycles
```

**Fast allocation**:
- No individual free tracking
- Bump allocator underneath
- Cache-friendly memory layout

**Simple usage**:
```zig
var list = CircularList.init(parent_allocator);
defer list.deinit(); // All nodes freed here
```

**Limitations**:
- Can't free individual nodes
- Memory grows until deinit
- Not suitable for long-lived structures with changing size

### Weak References Convention

**Document ownership**:
```zig
parent: ?*TreeNode, // Weak: borrowed, not owned
children: ArrayList(*TreeNode), // Strong: owned
```

**Cleanup follows ownership**:
```zig
pub fn deinit(self: *TreeNode, allocator: std.mem.Allocator) void {
    // Free owned children
    for (self.children.items) |child| {
        child.deinit(allocator);
    }
    // Don't touch parent - we don't own it
    self.children.deinit(allocator);
    allocator.destroy(self);
}
```

**Convention is compiler-enforced through usage**:
- Only access weak references while owner is alive
- Never free weak references
- Document clearly

### Reference Counting Pitfalls

**Not thread-safe by default**:
```zig
pub fn retain(self: *RefCounted) void {
    self.ref_count += 1; // Race condition!
}
```

Make thread-safe with atomics:
```zig
ref_count: std.atomic.Value(usize),

pub fn retain(self: *RefCounted) void {
    _ = self.ref_count.fetchAdd(1, .monotonic);
}
```

**Cycles still leak**:
- Reference counting alone can't handle cycles
- Combine with weak references
- Or use cycle detection algorithms

### Index-Based Benefits

**No pointer invalidation**:
- Array can grow, indices remain valid
- Easy to serialize (just save indices)
- No alignment or padding concerns

**Cache-friendly**:
```zig
// All nodes in contiguous array
for (pool.nodes.items) |node| {
    // Fast iteration, good cache locality
}
```

**Simple debugging**:
- Print indices to track references
- Easy to visualize in debugger
- No pointer arithmetic

### Generational Index Safety

**Catch use-after-free**:
```zig
const idx = pool.allocate(allocator, 42);
pool.free(allocator, idx);
// Later...
const value = pool.get(idx); // Returns null, not garbage
```

**Generation increments on free**:
- Old index has generation N
- Entry now has generation N+1
- Lookup fails: generations don't match

**Small overhead**:
- Extra u32 per entry
- Single integer comparison on access
- Worth it for safety

### Performance Comparison

**Arena allocator**:
- Allocation: O(1), fastest
- Deallocation: O(1), frees all at once
- Memory: Can't free individually, may waste

**Reference counting**:
- Allocation: O(1)
- Deallocation: O(1) per release
- Memory: Exact, but cycles leak

**Index-based**:
- Allocation: O(1) amortized (array growth)
- Deallocation: O(1)
- Memory: Exact with generational tracking

### Common Use Cases

**Graphs and networks**:
- Social networks: index-based (user IDs)
- Game entity graphs: generational indices
- Compiler ASTs: arena allocator

**Trees**:
- Parent-child: weak references
- File systems: weak parent pointers
- Scene graphs: reference counting or arena

**Circular buffers**:
- Ring buffers: index arithmetic
- LRU caches: doubly-linked with arena
- Event logs: circular array

**Game entities**:
- Entity component systems: generational indices
- Particle systems: arena allocators
- Physics constraints: index-based graph

### Design Guidelines

**Document ownership clearly**:
```zig
// Clear ownership semantics
owned_data: []u8,        // This struct owns and will free
borrowed_ref: *const T,  // Borrowed, don't free
weak_parent: ?*Node,     // Weak reference
```

**Prefer simpler patterns**:
1. Arena if lifetime allows
2. Weak references if hierarchical
3. Index-based for pools
4. Reference counting as last resort

**Test with allocator tracking**:
```zig
test "no memory leaks" {
    const allocator = std.testing.allocator;
    // allocator will detect leaks
}
```

**Consider serialization needs**:
- Pointers don't serialize
- Indices serialize trivially
- Generational indices need care (serialize generation too)

## See Also

- Recipe 8.18: Extending Classes with Mixins
- Recipe 8.19: Implementing Stateful Objects or State Machines
- Recipe 8.20: Implementing the Visitor Pattern
- Recipe 0.12: Understanding Allocators

Full compilable example: `code/03-advanced/08-structs-unions-objects/recipe_8_21.zig`
