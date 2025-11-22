## Problem

You need to compare instances of your custom types for equality, sort them, use them as hash map keys, or implement custom ordering logic. Zig doesn't provide default comparison operators for structs.

## Solution

Implement comparison methods on your types: `eql()` for equality, `compare()` or `lessThan()` for ordering, and `hash()` for hash maps. Use comparison contexts with `std.mem.sort()` for flexible sorting.

### Basic Equality

Define an `eql()` method for equality comparisons:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_22.zig:basic_equality}}
```

Simple field-by-field comparison for value equality.

### Ordering Comparison

Implement `lessThan()` or `compare()` for sorting:

```zig
const Person = struct {
    name: []const u8,
    age: u32,

    pub fn lessThan(self: Person, other: Person) bool {
        // Compare by age first, then name
        if (self.age != other.age) {
            return self.age < other.age;
        }
        return std.mem.lessThan(u8, self.name, other.name);
    }

    pub fn compare(self: Person, other: Person) std.math.Order {
        if (self.age < other.age) return .lt;
        if (self.age > other.age) return .gt;
        return std.mem.order(u8, self.name, other.name);
    }
};
```

`compare()` returns `std.math.Order` (.lt, .eq, .gt) for more flexibility.

### Comparison Context for Sorting

Use comparison contexts to sort the same type different ways:

```zig
const Item = struct {
    id: u32,
    priority: i32,
    name: []const u8,

    const ByPriority = struct {
        pub fn lessThan(_: @This(), a: Item, b: Item) bool {
            return a.priority > b.priority; // Higher priority first
        }
    };

    const ByName = struct {
        pub fn lessThan(_: @This(), a: Item, b: Item) bool {
            return std.mem.lessThan(u8, a.name, b.name);
        }
    };
};

// Sort by priority
std.mem.sort(Item, items, Item.ByPriority{}, Item.ByPriority.lessThan);

// Sort by name
std.mem.sort(Item, items, Item.ByName{}, Item.ByName.lessThan);
```

Comparison contexts enable multiple sort orders without changing the type.

### Hash Function

Implement `hash()` for use in hash maps:

```zig
const Coordinate = struct {
    x: i32,
    y: i32,

    pub fn hash(self: Coordinate) u64 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(std.mem.asBytes(&self.x));
        hasher.update(std.mem.asBytes(&self.y));
        return hasher.final();
    }

    pub fn eql(self: Coordinate, other: Coordinate) bool {
        return self.x == other.x and self.y == other.y;
    }
};
```

Hash maps require both `hash()` and `eql()` methods.

### Deep Equality

Compare nested structures recursively:

```zig
const Team = struct {
    name: []const u8,
    members: []const []const u8,
    score: i32,

    pub fn eql(self: Team, other: Team) bool {
        if (self.score != other.score) return false;
        if (!std.mem.eql(u8, self.name, other.name)) return false;
        if (self.members.len != other.members.len) return false;

        for (self.members, other.members) |m1, m2| {
            if (!std.mem.eql(u8, m1, m2)) return false;
        }

        return true;
    }
};
```

Check all fields including nested arrays and slices.

### Custom Comparison Modes

Support multiple comparison strategies:

```zig
const Product = struct {
    name: []const u8,
    price: f64,
    rating: f32,

    const CompareMode = enum {
        by_price,
        by_rating,
        by_name,
    };

    pub fn compare(self: Product, other: Product, mode: CompareMode) std.math.Order {
        return switch (mode) {
            .by_price => std.math.order(self.price, other.price),
            .by_rating => std.math.order(self.rating, other.rating),
            .by_name => std.mem.order(u8, self.name, other.name),
        };
    }
};

// Compare different ways
const order = laptop.compare(phone, .by_price);
```

Enum-based modes provide flexible comparison logic.

### Approximate Equality

Compare floating point values with tolerance:

```zig
const Vector2D = struct {
    x: f64,
    y: f64,

    pub fn eql(self: Vector2D, other: Vector2D) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn approxEql(self: Vector2D, other: Vector2D, epsilon: f64) bool {
        const dx = @abs(self.x - other.x);
        const dy = @abs(self.y - other.y);
        return dx < epsilon and dy < epsilon;
    }
};

// Approximate comparison for floats
const v1 = Vector2D{ .x = 1.0, .y = 2.0 };
const v2 = Vector2D{ .x = 1.0001, .y = 2.0001 };

if (v1.approxEql(v2, 0.001)) {
    // Considered equal within tolerance
}
```

Floating point comparisons need epsilon tolerance.

### Comparable Interface

Create generic comparison utilities using comptime:

```zig
fn Comparable(comptime T: type) type {
    return struct {
        pub fn requiresCompare() void {
            if (!@hasDecl(T, "compare")) {
                @compileError("Type must have compare method");
            }
        }

        pub fn min(a: T, b: T) T {
            return if (a.compare(b) == .lt) a else b;
        }

        pub fn max(a: T, b: T) T {
            return if (a.compare(b) == .gt) a else b;
        }

        pub fn clamp(value: T, low: T, high: T) T {
            return max(low, min(value, high));
        }
    };
}

const Score = struct {
    value: i32,

    pub fn compare(self: Score, other: Score) std.math.Order {
        return std.math.order(self.value, other.value);
    }
};

const ScoreOps = Comparable(Score);
const min_score = ScoreOps.min(s1, s2);
```

Generic utilities work with any type implementing `compare()`.

### Partial Ordering

Handle types where not all values are comparable:

```zig
const Entry = struct {
    key: ?[]const u8,
    value: i32,

    pub fn compare(self: Entry, other: Entry) ?std.math.Order {
        // Can't compare if either key is null
        const k1 = self.key orelse return null;
        const k2 = other.key orelse return null;

        const key_order = std.mem.order(u8, k1, k2);
        if (key_order != .eq) return key_order;

        return std.math.order(self.value, other.value);
    }
};

// Check if comparison succeeded
if (e1.compare(e2)) |order| {
    // Use order
} else {
    // Comparison not defined
}
```

Return optional order when comparison might not be valid.

### Multi-Field Comparison

Efficiently compare multiple fields in priority order:

```zig
const Record = struct {
    category: u8,
    priority: i32,
    timestamp: i64,
    id: u32,

    pub fn compare(self: Record, other: Record) std.math.Order {
        // Compare fields in order of importance
        if (self.category != other.category) {
            return std.math.order(self.category, other.category);
        }
        if (self.priority != other.priority) {
            return std.math.order(self.priority, other.priority);
        }
        if (self.timestamp != other.timestamp) {
            return std.math.order(self.timestamp, other.timestamp);
        }
        return std.math.order(self.id, other.id);
    }

    pub fn eql(self: Record, other: Record) bool {
        return self.category == other.category and
            self.priority == other.priority and
            self.timestamp == other.timestamp and
            self.id == other.id;
    }
};
```

Early exit on first difference for efficiency.

## Discussion

Comparison operations enable sorting, searching, and using custom types in data structures.

### Comparison Method Conventions

**Equality: `eql()`**:
```zig
pub fn eql(self: T, other: T) bool
```
- Returns true if values are equal
- Used for exact equality checks
- Required for hash maps (with `hash()`)

**Ordering: `lessThan()`**:
```zig
pub fn lessThan(self: T, other: T) bool
```
- Returns true if self < other
- Simple, intuitive interface
- Common for basic sorting

**Three-way comparison: `compare()`**:
```zig
pub fn compare(self: T, other: T) std.math.Order
```
- Returns .lt, .eq, or .gt
- More expressive than boolean
- Enables min/max/clamp utilities
- Single comparison determines all relationships

**Hashing: `hash()`**:
```zig
pub fn hash(self: T) u64
```
- Returns hash value
- Must be consistent with `eql()`
- If `a.eql(b)` then `a.hash() == b.hash()`

### Choosing Comparison Strategy

**Use `eql()` when**:
- Only need equality, not ordering
- Comparing for membership tests
- Keys in hash maps
- Simpler than full comparison

**Use `lessThan()` when**:
- Primary use is sorting
- Don't need all comparison operations
- Simpler mental model than Order enum
- Integrates with `std.mem.sort()`

**Use `compare()` when**:
- Need multiple comparison operations (min, max, clamp)
- Three-way comparison is more efficient
- Building generic comparison utilities
- Want exhaustive Order handling via switch

### Comparison Contexts

**Why use contexts**:
```zig
// Instead of multiple comparison methods
pub fn compareByPrice(...) {}
pub fn compareByName(...) {}

// Use contexts
const ByPrice = struct {
    pub fn lessThan(...) {}
};
```

**Benefits**:
- Multiple sort orders for same type
- No modification to original type
- Stateless or stateful comparisons
- Clean namespace

**Pattern**:
```zig
const MyType = struct {
    const SortContext = struct {
        reverse: bool,

        pub fn lessThan(self: @This(), a: MyType, b: MyType) bool {
            const result = a.value < b.value;
            return if (self.reverse) !result else result;
        }
    };
};

// Use with state
std.mem.sort(MyType, items, MyType.SortContext{ .reverse = true }, ...);
```

### Hash Function Implementation

**Good hash properties**:
- Deterministic: same input → same hash
- Uniform: distributes values evenly
- Fast: O(1) or O(n) for collections
- Consistent with equality

**Using Wyhash**:
```zig
pub fn hash(self: T) u64 {
    var hasher = std.hash.Wyhash.init(0);
    hasher.update(std.mem.asBytes(&self.field1));
    hasher.update(std.mem.asBytes(&self.field2));
    return hasher.final();
}
```

**For simple types**:
```zig
pub fn hash(self: T) u64 {
    return std.hash.Wyhash.hash(0, std.mem.asBytes(&self));
}
```

**Hash all fields used in `eql()`**:
- If `eql()` checks field X, `hash()` must include X
- Otherwise hash map lookups fail

### String Comparison

**Use `std.mem` utilities**:
```zig
std.mem.eql(u8, s1, s2)        // Equality
std.mem.lessThan(u8, s1, s2)   // Lexicographic <
std.mem.order(u8, s1, s2)      // Three-way order
```

**Case-insensitive**:
```zig
std.ascii.eqlIgnoreCase(s1, s2)
// No built-in case-insensitive ordering
// Implement custom if needed
```

**String slices in structs**:
```zig
pub fn eql(self: T, other: T) bool {
    return std.mem.eql(u8, self.name, other.name);
}
```

### Floating Point Comparison

**Exact equality is fragile**:
```zig
const a: f64 = 0.1 + 0.2;
const b: f64 = 0.3;
// a == b may be false due to rounding
```

**Use epsilon tolerance**:
```zig
pub fn approxEql(a: f64, b: f64, epsilon: f64) bool {
    return @abs(a - b) < epsilon;
}
```

**Choose epsilon carefully**:
- Too large: false positives
- Too small: false negatives
- Depends on magnitude and precision needs

**For ordering**:
```zig
std.math.order(a, b)  // Use exact comparison
// Ordering doesn't need epsilon
```

### Performance Considerations

**Short-circuit on first difference**:
```zig
pub fn compare(self: T, other: T) std.math.Order {
    if (self.field1 != other.field1) {
        return std.math.order(self.field1, other.field1);
    }
    // Only check field2 if field1 equal
    return std.math.order(self.field2, other.field2);
}
```

**Order fields by**:
- Likelihood of difference (most different first)
- Cheapness of comparison (cheap first)
- Logical importance

**Avoid expensive operations**:
```zig
// Bad: hash for equality
pub fn eql(self: T, other: T) bool {
    return self.hash() == other.hash(); // Too slow
}

// Good: direct field comparison
pub fn eql(self: T, other: T) bool {
    return self.id == other.id; // Fast
}
```

### Generic Comparison Utilities

**Compile-time interface checking**:
```zig
fn requireCompare(comptime T: type) void {
    if (!@hasDecl(T, "compare")) {
        @compileError("Type must have compare method");
    }
}
```

**Generic min/max**:
```zig
fn min(comptime T: type, a: T, b: T) T {
    requireCompare(T);
    return if (a.compare(b) == .lt) a else b;
}
```

**Type-safe interfaces**:
- Use `@hasDecl` to check methods exist
- Provide helpful compile errors
- No runtime overhead

### Common Patterns

**Database records**:
```zig
// Primary key comparison
pub fn eql(self: Record, other: Record) bool {
    return self.id == other.id;
}

// Multi-field sorting
pub fn compare(self: Record, other: Record) std.math.Order {
    // Category, then priority, then timestamp
}
```

**Range types**:
```zig
pub fn contains(self: Range, value: T) bool {
    return self.start.compare(value) != .gt and
           self.end.compare(value) != .lt;
}
```

**Sorted containers**:
```zig
pub fn insert(self: *SortedList, item: T) !void {
    var i: usize = 0;
    while (i < self.items.len) : (i += 1) {
        if (item.compare(self.items[i]) == .lt) break;
    }
    try self.items.insert(i, item);
}
```

### Testing Comparison Functions

**Test all orderings**:
```zig
test "comparison" {
    const a = T{ ... };
    const b = T{ ... };
    const c = T{ ... };

    // Reflexive: a == a
    try testing.expect(a.eql(a));

    // Symmetric: if a == b then b == a
    if (a.eql(b)) {
        try testing.expect(b.eql(a));
    }

    // Transitive: if a < b and b < c then a < c
    if (a.compare(b) == .lt and b.compare(c) == .lt) {
        try testing.expectEqual(std.math.Order.lt, a.compare(c));
    }
}
```

**Hash consistency**:
```zig
test "hash consistency" {
    const a = T{ ... };
    const b = T{ ... };

    if (a.eql(b)) {
        try testing.expectEqual(a.hash(), b.hash());
    }
}
```

## See Also

- Recipe 8.19: Implementing Stateful Objects or State Machines
- Recipe 8.20: Implementing the Visitor Pattern
- Recipe 2.1: Keeping the Last N Items (using comparison for priority queues)
- Recipe 7.6: Determining the Most Frequently Occurring Items in a Sequence

Full compilable example: `code/03-advanced/08-structs-unions-objects/recipe_8_22.zig`
