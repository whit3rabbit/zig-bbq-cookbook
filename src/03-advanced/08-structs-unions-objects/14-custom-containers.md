## Problem

You need to implement custom containers or data structures with generic types, similar to ArrayList or HashMap in the standard library.

## Solution

Use Zig's comptime type parameters to create generic containers with zero runtime overhead. Each container is specialized at compile time for the types it holds.

### Generic Stack

Create a dynamic stack that grows as needed:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_14.zig:generic_stack}}

        pub fn pop(self: *Self) ?T {
            if (self.len == 0) return null;
            self.len -= 1;
            return self.items[self.len];
        }
    };
}
```

The function returns a struct type, creating a new specialized stack for each type parameter.

### Circular Buffer

Fixed-capacity ring buffer with compile-time size:

```zig
fn CircularBuffer(comptime T: type, comptime capacity: usize) type {
    return struct {
        buffer: [capacity]T,
        read_index: usize,
        write_index: usize,
        count: usize,

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
    };
}
```

The buffer wraps around when full, overwriting old data efficiently.

### Linked List

Singly linked list with dynamic nodes:

```zig
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
    };
}
```

Linked lists provide O(1) insertion and removal at both ends.

### Priority Queue

Min-heap based priority queue:

```zig
fn PriorityQueue(comptime T: type) type {
    return struct {
        items: std.ArrayList(T),

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

        fn bubbleUp(self: *Self, index: usize) void {
            if (index == 0) return;

            const parent_index = (index - 1) / 2;
            if (self.items.items[index] < self.items.items[parent_index]) {
                // Swap and recurse
            }
        }
    };
}
```

Always extracts the minimum element efficiently.

### Iterator Pattern

Custom containers can provide iterators:

```zig
const IntRange = struct {
    start: i32,
    end: i32,

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
```

Iterators allow sequential access without exposing internal structure.

## Discussion

Zig's generic containers are fundamentally different from templates in C++ or generics in Java.

### Compile-Time Specialization

Every generic container creates a unique type at compile time:

```zig
const IntStack = Stack(i32);    // Distinct type
const StrStack = Stack([]u8);   // Different distinct type
```

This allows:
- Full type checking at compile time
- Zero runtime overhead
- Optimizations specific to each type
- No boxing or runtime type information

### Container Design Patterns

**Return struct from function**: Generic containers are functions that return types

```zig
fn MyContainer(comptime T: type) type {
    return struct {
        // Container implementation
    };
}
```

**Comptime parameters**: Accept both types and values

```zig
fn FixedArray(comptime T: type, comptime size: usize) type {
    return struct {
        data: [size]T,
    };
}
```

**Inner types**: Define helper types within the container

```zig
fn List(comptime T: type) type {
    return struct {
        const Node = struct { data: T, next: ?*Node };
        // Use Node internally
    };
}
```

### Memory Management

Containers must handle allocation explicitly:

- **Init pattern**: Accept allocator in init
- **Deinit cleanup**: Free all allocated memory
- **Allocator storage**: Store allocator for later use
- **Error handling**: Return allocation errors to caller

Example memory-safe pattern:

```zig
var list = LinkedList(i32).init(allocator);
defer list.deinit();  // Ensures cleanup

try list.append(42);  // Propagate allocation errors
```

### Performance Considerations

**Stack**:
- Push/pop: O(1) amortized with doubling strategy
- Memory: Contiguous, cache-friendly
- Use for: LIFO access patterns

**Circular Buffer**:
- Write/read: O(1) always
- Memory: Fixed, no allocations
- Use for: Bounded queues, ring buffers

**Linked List**:
- Insert/remove ends: O(1)
- Memory: Scattered, pointer overhead
- Use for: Frequent insertion/deletion

**Priority Queue**:
- Insert: O(log n)
- Extract min: O(log n)
- Memory: Contiguous array
- Use for: Always need minimum element

### Type Constraints

Containers can require specific capabilities:

```zig
fn SortedList(comptime T: type) type {
    // Verify type supports comparison at compile time
    const dummy: T = undefined;
    _ = dummy < dummy;  // Compile error if < not supported

    return struct {
        // Implementation
    };
}
```

The compiler enforces type requirements automatically.

## See Also

- Recipe 8.13: Implementing a Data Model or Type System
- Recipe 8.15: Delegating Attribute Access
- Recipe 9.11: Using comptime to Control Instance Creation
- Recipe 9.16: Defining Structs Programmatically

Full compilable example: `code/03-advanced/08-structs-unions-objects/recipe_8_14.zig`
