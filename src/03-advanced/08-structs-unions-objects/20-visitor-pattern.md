## Problem

You need to perform different operations on a collection of related types (like AST nodes, shapes, or file trees) without modifying those types. You want to separate algorithms from the data structures they operate on.

## Solution

Use tagged unions with an `accept` method that dispatches to visitor methods. Visitors implement specific operations, keeping the data types clean and focused.

### Basic Visitor Pattern

Define shapes and a visitor that calculates area:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_20.zig:basic_visitor}}
```

Each visitor method handles one variant of the union.

### Visitor with Context

Visitors can carry state:

```zig
const PrintVisitor = struct {
    buffer: *std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub const ResultType = void;

    pub fn visitCircle(self: PrintVisitor, circle: Circle) void {
        const msg = std.fmt.allocPrint(
            self.allocator,
            "Circle(r={d})",
            .{circle.radius}
        ) catch return;
        defer self.allocator.free(msg);
        self.buffer.appendSlice(self.allocator, msg) catch return;
    }

    pub fn visitRectangle(self: PrintVisitor, rectangle: Rectangle) void {
        const msg = std.fmt.allocPrint(
            self.allocator,
            "Rectangle(w={d},h={d})",
            .{ rectangle.width, rectangle.height }
        ) catch return;
        defer self.allocator.free(msg);
        self.buffer.appendSlice(self.allocator, msg) catch return;
    }
};
```

The visitor accumulates results in its buffer field.

### Expression Visitor (AST Traversal)

Visit and evaluate expression trees:

```zig
const Expr = union(enum) {
    number: i32,
    add: struct { left: *Expr, right: *Expr },
    mul: struct { left: *Expr, right: *Expr },
    neg: *Expr,

    pub fn accept(self: *const Expr, visitor: anytype) GetResultType(@TypeOf(visitor)) {
        return switch (self.*) {
            .number => |n| visitor.visitNumber(n),
            .add => |a| visitor.visitAdd(a.left, a.right),
            .mul => |m| visitor.visitMul(m.left, m.right),
            .neg => |n| visitor.visitNeg(n),
        };
    }
};

fn GetResultType(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .pointer => |ptr| ptr.child.ResultType,
        else => T.ResultType,
    };
}

const EvalVisitor = struct {
    pub const ResultType = i32;

    pub fn visitNumber(_: EvalVisitor, n: i32) i32 {
        return n;
    }

    pub fn visitAdd(self: EvalVisitor, left: *Expr, right: *Expr) i32 {
        return left.accept(self) + right.accept(self);
    }

    pub fn visitMul(self: EvalVisitor, left: *Expr, right: *Expr) i32 {
        return left.accept(self) * right.accept(self);
    }

    pub fn visitNeg(self: EvalVisitor, expr: *Expr) i32 {
        return -expr.accept(self);
    }
};
```

Visitors can recursively traverse tree structures.

### Collecting Visitor

Count nodes or collect information:

```zig
const NodeVisitor = struct {
    count: u32,

    pub const ResultType = void;

    pub fn visitNumber(self: *NodeVisitor, _: i32) void {
        self.count += 1;
    }

    pub fn visitAdd(self: *NodeVisitor, left: *Expr, right: *Expr) void {
        self.count += 1;
        left.accept(self);
        right.accept(self);
    }

    pub fn visitMul(self: *NodeVisitor, left: *Expr, right: *Expr) void {
        self.count += 1;
        left.accept(self);
        right.accept(self);
    }
};

// Usage
var visitor = NodeVisitor{ .count = 0 };
expression.accept(&visitor);
// visitor.count now has total node count
```

Mutable visitors accumulate state during traversal.

### Transforming Visitor

Build strings or transform structures:

```zig
const StringifyVisitor = struct {
    buffer: *std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub const ResultType = void;

    pub fn visitNumber(self: *StringifyVisitor, n: i32) void {
        const str = std.fmt.allocPrint(self.allocator, "{d}", .{n}) catch return;
        defer self.allocator.free(str);
        self.buffer.appendSlice(self.allocator, str) catch return;
    }

    pub fn visitAdd(self: *StringifyVisitor, left: *Expr, right: *Expr) void {
        self.buffer.append(self.allocator, '(') catch return;
        left.accept(self);
        self.buffer.appendSlice(self.allocator, " + ") catch return;
        right.accept(self);
        self.buffer.append(self.allocator, ')') catch return;
    }
};

// Transforms: (5 + 3) into string "(5 + 3)"
```

Visitors can transform data structures into other representations.

### Fallible Visitor

Visitors can return errors:

```zig
const ValidationVisitor = struct {
    pub const ResultType = anyerror!bool;

    pub fn visitCircle(_: ValidationVisitor, circle: Circle) !bool {
        if (circle.radius <= 0) return error.InvalidRadius;
        return true;
    }

    pub fn visitRectangle(_: ValidationVisitor, rectangle: Rectangle) !bool {
        if (rectangle.width <= 0 or rectangle.height <= 0) {
            return error.InvalidDimensions;
        }
        return true;
    }
};

// Usage
const visitor = ValidationVisitor{};
const valid = try shape.accept(visitor);
```

Error handling integrates naturally with the visitor pattern.

### File Tree Visitor

Visit hierarchical structures:

```zig
const File = struct { name: []const u8, size: u64 };
const Directory = struct { name: []const u8, children: []const FileNode };

const FileNode = union(enum) {
    file: File,
    directory: Directory,

    pub fn accept(self: *const FileNode, visitor: anytype) GetResultType(@TypeOf(visitor)) {
        return switch (self.*) {
            .file => |f| visitor.visitFile(f),
            .directory => |d| visitor.visitDirectory(d),
        };
    }
};

const SizeVisitor = struct {
    pub const ResultType = u64;

    pub fn visitFile(_: SizeVisitor, file: File) u64 {
        return file.size;
    }

    pub fn visitDirectory(self: SizeVisitor, dir: Directory) u64 {
        var total: u64 = 0;
        for (dir.children) |*child| {
            total += child.accept(self);
        }
        return total;
    }
};
```

Recursive visitors handle tree structures naturally.

### Stateful Visitor

Track depth, path, or other traversal state:

```zig
const DepthVisitor = struct {
    depth: u32,
    max_depth: u32,

    pub const ResultType = void;

    pub fn visitFile(self: *DepthVisitor, _: File) void {
        if (self.depth > self.max_depth) {
            self.max_depth = self.depth;
        }
    }

    pub fn visitDirectory(self: *DepthVisitor, dir: Directory) void {
        if (self.depth > self.max_depth) {
            self.max_depth = self.depth;
        }

        self.depth += 1;
        for (dir.children) |*child| {
            child.accept(self);
        }
        self.depth -= 1;
    }
};
```

State tracks context during traversal.

### Filter Visitor

Collect items matching criteria:

```zig
const FilterVisitor = struct {
    matches: *std.ArrayList([]const u8),
    allocator: std.mem.Allocator,
    extension: []const u8,

    pub const ResultType = void;

    pub fn visitFile(self: *FilterVisitor, file: File) void {
        if (std.mem.endsWith(u8, file.name, self.extension)) {
            self.matches.append(self.allocator, file.name) catch return;
        }
    }

    pub fn visitDirectory(self: *FilterVisitor, dir: Directory) void {
        for (dir.children) |*child| {
            child.accept(self);
        }
    }
};

// Find all .txt files
var matches = std.ArrayList([]const u8).init(allocator);
var visitor = FilterVisitor{
    .matches = &matches,
    .allocator = allocator,
    .extension = ".txt",
};
tree.accept(&visitor);
```

Visitors can filter and collect specific items.

## Discussion

The visitor pattern separates operations from data structures, making both easier to extend and maintain.

### How Visitors Work

**Double dispatch**: The data type and visitor type determine behavior
1. `shape.accept(visitor)` - shape knows its type
2. `visitor.visitCircle(circle)` - visitor knows the operation
3. Result combines both type and operation

**Tagged union dispatch**:
```zig
pub fn accept(self: *const Shape, visitor: anytype) ResultType {
    return switch (self.*) {  // Dispatch on shape type
        .circle => |c| visitor.visitCircle(c),  // Call visitor method
        .rectangle => |r| visitor.visitRectangle(r),
        // ...
    };
}
```

**Generic visitors**:
```zig
visitor: anytype  // Any type with appropriate visit methods
```

Zig's comptime checks that the visitor has required methods.

### Visitor Pattern Benefits

**Separation of concerns**:
- Data structures: Just hold data
- Visitors: Implement algorithms
- Easy to add new operations

**Type safety**:
- Compiler ensures all cases handled
- No missing visitor methods
- Compile-time verification

**Flexibility**:
- Multiple visitors for same data
- Different operations without changing data
- Compose visitors

### Design Guidelines

**Naming conventions**:
- `accept()` method on data structures
- `visit*()` methods on visitors
- `ResultType` constant for return type

**ResultType pattern**:
```zig
pub const ResultType = T;  // What accept() returns

pub fn visitX(self: Visitor, ...) ResultType {
    // Must return ResultType
}
```

**Visitor state**:
- Immutable visitors: Pure operations
- Mutable visitors: Collect results
- Both work with `anytype`

**Error handling**:
```zig
pub const ResultType = !T;  // Visitor can fail

pub fn visitX(...) !T {
    if (invalid) return error.Invalid;
    return result;
}
```

### Performance

**Zero overhead dispatch**: Switch compiles to jump table
- Enum tag lookup: O(1)
- Jump to handler: O(1)
- No vtable indirection

**Inline-friendly**: Small visitors inline completely
```zig
const area = shape.accept(AreaVisitor{});
// Often inlined to direct calculation
```

**Memory**: Only visitor fields
- No heap allocation
- Stack-allocated visitors
- Data structure unchanged

### Common Use Cases

**AST traversal**:
- Evaluation
- Pretty printing
- Type checking
- Code generation

**Data structure operations**:
- Serialization
- Validation
- Transformation
- Filtering

**File system operations**:
- Size calculation
- Search
- Permission checking
- Backup

**Graph algorithms**:
- DFS/BFS traversal
- Path finding
- Cycle detection
- Topological sort

### Visitor Variations

**Single-method visitor**:
```zig
pub fn process(item: anytype) void {
    // Handle all types the same way
}
```

**Multi-type visitor**:
```zig
pub fn visit(item: anytype) void {
    switch (@TypeOf(item)) {
        Shape.circle => ...,
        Shape.rectangle => ...,
    }
}
```

**Accumulating visitor**:
```zig
var results = std.ArrayList(Result).init(allocator);
var visitor = CollectVisitor{ .results = &results };
```

**Transform visitor**:
```zig
pub const ResultType = TransformedType;

pub fn visitX(...) TransformedType {
    return transform(...);
}
```

### Comparison with Alternatives

**Pattern matching** (if Zig had it):
```rust
// Rust
match shape {
    Shape::Circle(r) => std.math.pi * r * r,
    Shape::Rectangle(w, h) => w * h,
}
```

Visitor pattern:
- More verbose but more flexible
- Can add operations without modifying types
- Better for complex operations

**Method-based dispatch**:
```zig
shape.calculateArea()  // Method on Shape
```

Visitor:
- Separates concerns better
- Operations are pluggable
- Multiple implementations possible

### When to Use Visitors

Use visitors when:
- You have a stable set of data types
- You want to add many operations
- Operations don't belong on the data type
- You need to collect or transform data

Don't use visitors when:
- Data types change frequently
- Only one operation needed
- Simple mapping suffices
- Switch statements are clearer

## See Also

- Recipe 8.19: Implementing Stateful Objects or State Machines
- Recipe 8.12: Defining an Interface or Abstract Base Class
- Recipe 7.2: Using Enums for State Representation
- Recipe 9.11: Using comptime to Control Instance Creation

Full compilable example: `code/03-advanced/08-structs-unions-objects/recipe_8_20.zig`
