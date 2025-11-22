# Sorting a List of Structs by a Common Field

## Problem

You have a collection of structs and need to sort them by one or more fields, or with custom comparison logic.

## Solution

Use `std.mem.sort` with a custom comparator:

```zig
{{#include ../../../code/02-core/01-data-structures/recipe_1_13.zig:basic_field_sort}}
```

## Discussion

### Basic Field Sorting

Sort by a single field with ascending or descending order:

```zig
const Person = struct {
    name: []const u8,
    age: u32,
};

// Sort by age ascending
fn sortByAgeAsc(people: []Person) void {
    std.mem.sort(Person, people, {}, struct {
        fn lessThan(_: void, a: Person, b: Person) bool {
            return a.age < b.age;
        }
    }.lessThan);
}

// Sort by age descending
fn sortByAgeDesc(people: []Person) void {
    std.mem.sort(Person, people, {}, struct {
        fn lessThan(_: void, a: Person, b: Person) bool {
            return a.age > b.age;
        }
    }.lessThan);
}
```

### Using std.sort Helper Functions

Zig provides built-in helpers for common sorting:

```zig
// Sort integers ascending
var numbers = [_]i32{ 5, 2, 8, 1, 9 };
std.mem.sort(i32, &numbers, {}, comptime std.sort.asc(i32));

// Sort integers descending
std.mem.sort(i32, &numbers, {}, comptime std.sort.desc(i32));
```

### Sorting by Multiple Fields

Sort with primary and secondary criteria:

```zig
const Employee = struct {
    department: []const u8,
    name: []const u8,
    salary: u32,
};

fn sortByDepartmentThenSalary(employees: []Employee) void {
    std.mem.sort(Employee, employees, {}, struct {
        fn lessThan(_: void, a: Employee, b: Employee) bool {
            // First by department
            const dept_cmp = std.mem.order(u8, a.department, b.department);
            if (dept_cmp != .eq) {
                return dept_cmp == .lt;
            }
            // Then by salary descending
            return a.salary > b.salary;
        }
    }.lessThan);
}
```

### Sorting Strings Lexicographically

Sort structs containing strings:

```zig
fn sortByName(people: []Person) void {
    std.mem.sort(Person, people, {}, struct {
        fn lessThan(_: void, a: Person, b: Person) bool {
            return std.mem.order(u8, a.name, b.name) == .lt;
        }
    }.lessThan);
}

// Case-insensitive string sorting
fn sortByNameCaseInsensitive(allocator: std.mem.Allocator, people: []Person) !void {
    const Context = struct {
        allocator: std.mem.Allocator,

        fn lessThan(self: @This(), a: Person, b: Person) bool {
            const a_lower = std.ascii.allocLowerString(self.allocator, a.name) catch return false;
            defer self.allocator.free(a_lower);
            const b_lower = std.ascii.allocLowerString(self.allocator, b.name) catch return false;
            defer self.allocator.free(b_lower);
            return std.mem.order(u8, a_lower, b_lower) == .lt;
        }
    };

    std.mem.sort(Person, people, Context{ .allocator = allocator }, Context.lessThan);
}

While this approach keeps the demo focused on comparator mechanics, it is intentionally naïve from a performance perspective: each comparison allocates two lowercase copies of the names, so a full `sort` ends up creating `O(n log n)` temporary allocations. For large slices that can dominate runtime and allocator pressure. A production-ready version would precompute the lowercase (or otherwise normalized) key once per element—e.g. build a temporary proxy slice that stores `{ person, lower_name }`, sort that slice, then write the sorted `person` values back. This keeps allocation count linear in the number of items instead of the number of comparator invocations.

Here is the proxy-based version from the recipe:

```zig
fn sortByNameCaseInsensitiveOptimized(allocator: std.mem.Allocator, people: []Person) !void {
    if (people.len <= 1) return;

    const Proxy = struct {
        index: usize,
        lower_name: []u8,
    };

    var proxies = try allocator.alloc(Proxy, people.len);
    var initialized: usize = 0;
    defer {
        for (proxies[0..initialized]) |proxy| {
            allocator.free(proxy.lower_name);
        }
        allocator.free(proxies);
    }

    for (people, 0..) |person, i| {
        const lower = try std.ascii.allocLowerString(allocator, person.name);
        proxies[i] = .{ .index = i, .lower_name = lower };
        initialized += 1;
    }

    std.mem.sort(Proxy, proxies, {}, struct {
        fn lessThan(_: void, a: Proxy, b: Proxy) bool {
            return switch (std.mem.order(u8, a.lower_name, b.lower_name)) {
                .lt => true,
                .gt => false,
                .eq => a.index < b.index,
            };
        }
    }.lessThan);

    var scratch = try allocator.alloc(Person, people.len);
    defer allocator.free(scratch);

    for (proxies, 0..) |proxy, i| {
        scratch[i] = people[proxy.index];
    }

    for (scratch, 0..) |value, i| {
        people[i] = value;
    }
}
```

Because each lowercase copy is produced once per element (not once per comparison), the allocator traffic drops to `O(n)` and cache locality improves. The proxy also records the original index, so equal lowercase names keep their input ordering even though `std.mem.sort` itself is unstable. Use this version whenever you expect large datasets or the allocator cost is a concern; keep the simpler comparator-only helper for concise examples or tiny slices.
```

### Stable vs Unstable Sort

`std.mem.sort` is not stable (equal elements may not maintain their original order). For stable sorting:

```zig
// Add index to maintain stability
const IndexedPerson = struct {
    person: Person,
    original_index: usize,
};

fn stableSort(people: []Person, allocator: std.mem.Allocator) !void {
    // Create indexed array
    var indexed = try allocator.alloc(IndexedPerson, people.len);
    defer allocator.free(indexed);

    for (people, 0..) |person, i| {
        indexed[i] = .{ .person = person, .original_index = i };
    }

    // Sort by field, using index as tiebreaker
    std.mem.sort(IndexedPerson, indexed, {}, struct {
        fn lessThan(_: void, a: IndexedPerson, b: IndexedPerson) bool {
            if (a.person.age != b.person.age) {
                return a.person.age < b.person.age;
            }
            return a.original_index < b.original_index;
        }
    }.lessThan);

    // Copy back
    for (indexed, 0..) |item, i| {
        people[i] = item.person;
    }
}
```

### Reverse Comparator

Create a reverse comparator wrapper:

```zig
fn Reverse(comptime T: type, comptime lessThan: fn (void, T, T) bool) type {
    return struct {
        fn compare(_: void, a: T, b: T) bool {
            return lessThan({}, b, a);
        }
    };
}

// Usage
const AscByAge = struct {
    fn lessThan(_: void, a: Person, b: Person) bool {
        return a.age < b.age;
    }
};

// Sort descending by wrapping
std.mem.sort(Person, &people, {}, Reverse(Person, AscByAge.lessThan).compare);
```

### Sorting by Computed Values

Sort based on calculated properties:

```zig
const Point = struct {
    x: f32,
    y: f32,

    fn distanceFromOrigin(self: Point) f32 {
        return @sqrt(self.x * self.x + self.y * self.y);
    }
};

fn sortByDistance(points: []Point) void {
    std.mem.sort(Point, points, {}, struct {
        fn lessThan(_: void, a: Point, b: Point) bool {
            return a.distanceFromOrigin() < b.distanceFromOrigin();
        }
    }.lessThan);
}
```

### Generic Comparator Builder

Create reusable comparators:

```zig
fn FieldComparator(
    comptime T: type,
    comptime field: []const u8,
    comptime ascending: bool,
) type {
    return struct {
        fn lessThan(_: void, a: T, b: T) bool {
            const a_val = @field(a, field);
            const b_val = @field(b, field);
            if (ascending) {
                return a_val < b_val;
            } else {
                return a_val > b_val;
            }
        }
    };
}

// Usage
std.mem.sort(Person, &people, {}, FieldComparator(Person, "age", true).lessThan);
```

### Sorting Slices of Pointers

Sort when you have pointers to structs:

```zig
fn sortPointersByAge(people: []*Person) void {
    std.mem.sort(*Person, people, {}, struct {
        fn lessThan(_: void, a: *Person, b: *Person) bool {
            return a.age < b.age;
        }
    }.lessThan);
}
```

### Sorting with Context

Use context for parameterized comparisons:

```zig
const SortContext = struct {
    sort_field: enum { name, age, salary },
    ascending: bool,

    fn lessThan(self: @This(), a: Person, b: Person) bool {
        const result = switch (self.sort_field) {
            .name => std.mem.order(u8, a.name, b.name) == .lt,
            .age => a.age < b.age,
            .salary => a.salary < b.salary,
        };
        return if (self.ascending) result else !result;
    }
};

// Usage
const context = SortContext{ .sort_field = .salary, .ascending = false };
std.mem.sort(Person, &people, context, SortContext.lessThan);
```

### Partial Sorting

Sort only part of an array:

```zig
fn sortPartial(people: []Person, start: usize, end: usize) void {
    const slice = people[start..end];
    std.mem.sort(Person, slice, {}, struct {
        fn lessThan(_: void, a: Person, b: Person) bool {
            return a.age < b.age;
        }
    }.lessThan);
}
```

### Sorting by Optional Fields

Handle optional struct fields:

```zig
const Student = struct {
    name: []const u8,
    grade: ?u32,
};

fn sortByGrade(students: []Student) void {
    std.mem.sort(Student, students, {}, struct {
        fn lessThan(_: void, a: Student, b: Student) bool {
            // null values sort to the end
            if (a.grade == null) return false;
            if (b.grade == null) return true;
            return a.grade.? < b.grade.?;
        }
    }.lessThan);
}
```

### Sorting Tagged Unions

Sort by union tag or value:

```zig
const Value = union(enum) {
    int: i32,
    float: f32,
    string: []const u8,
};

fn sortByTag(values: []Value) void {
    std.mem.sort(Value, values, {}, struct {
        fn lessThan(_: void, a: Value, b: Value) bool {
            return @intFromEnum(a) < @intFromEnum(b);
        }
    }.lessThan);
}
```

### Performance Considerations

- Sorting is O(n log n) average case
- Avoid allocations in comparator functions
- Use `comptime` for simple comparators
- For small arrays (<20 items), insertion sort may be faster
- Consider caching computed values if comparison is expensive

### Custom Sort Algorithms

Implement custom sorting when needed:

```zig
// Insertion sort for small arrays
fn insertionSort(comptime T: type, items: []T, context: anytype, lessThan: anytype) void {
    var i: usize = 1;
    while (i < items.len) : (i += 1) {
        const key = items[i];
        var j = i;
        while (j > 0 and lessThan(context, key, items[j - 1])) : (j -= 1) {
            items[j] = items[j - 1];
        }
        items[j] = key;
    }
}
```

### Sorting Complex Nested Structures

Sort based on nested field access:

```zig
const Company = struct {
    name: []const u8,
    ceo: struct {
        name: []const u8,
        age: u32,
    },
};

fn sortByCeoAge(companies: []Company) void {
    std.mem.sort(Company, companies, {}, struct {
        fn lessThan(_: void, a: Company, b: Company) bool {
            return a.ceo.age < b.ceo.age;
        }
    }.lessThan);
}
```

### Common Patterns

```zig
// Pattern 1: Simple field sort
std.mem.sort(T, slice, {}, struct {
    fn lessThan(_: void, a: T, b: T) bool {
        return a.field < b.field;
    }
}.lessThan);

// Pattern 2: Multi-field sort with std.mem.order
const order = std.mem.order(u8, a.string_field, b.string_field);
if (order != .eq) return order == .lt;
return a.number_field < b.number_field;

// Pattern 3: Reverse sort
return a.field > b.field;  // Note: > instead of <

// Pattern 4: Null handling
if (a.optional == null) return false;
if (b.optional == null) return true;
return a.optional.? < b.optional.?;
```

## See Also

- Recipe 1.4: Finding Largest/Smallest N Items
- Recipe 1.12: Determining Most Frequently Occurring Items
- Recipe 1.14: Sorting Objects Without Native Comparison Support

Full compilable example: `code/02-core/01-data-structures/recipe_1_13.zig`
