// Recipe 1.13: Sorting a List of Structs by a Common Field
// Target Zig Version: 0.15.2
//
// This recipe demonstrates various sorting techniques, with special attention to
// performance pitfalls when sorting by expensive-to-compute keys.
//
// KEY LESSON: When your comparison function does expensive work (allocations,
// mathematical operations, string processing), you should pre-compute the sort
// keys using the "proxy pattern" to avoid repeating that work O(n log n) times.

const std = @import("std");
const testing = std.testing;

// ============================================================================
// Test Data Structures
// ============================================================================

const Person = struct {
    name: []const u8,
    age: u32,
    salary: u32,
};

const Employee = struct {
    department: []const u8,
    name: []const u8,
    salary: u32,
};

const Student = struct {
    name: []const u8,
    grade: ?u32,
};

const Point = struct {
    x: f32,
    y: f32,

    fn distanceFromOrigin(self: Point) f32 {
        return @sqrt(self.x * self.x + self.y * self.y);
    }
};

const Company = struct {
    name: []const u8,
    ceo: struct {
        name: []const u8,
        age: u32,
    },
};

const Value = union(enum) {
    int: i32,
    float: f32,
    string: []const u8,
};

// ============================================================================
// Basic Field Sorting
// ============================================================================

// ANCHOR: basic_field_sort
fn sortByAgeAsc(people: []Person) void {
    std.mem.sort(Person, people, {}, struct {
        fn lessThan(_: void, a: Person, b: Person) bool {
            return a.age < b.age;
        }
    }.lessThan);
}

fn sortByAgeDesc(people: []Person) void {
    std.mem.sort(Person, people, {}, struct {
        fn lessThan(_: void, a: Person, b: Person) bool {
            return a.age > b.age;
        }
    }.lessThan);
}
// ANCHOR_END: basic_field_sort

// ============================================================================
// Sorting by Multiple Fields
// ============================================================================

// ANCHOR: multi_field_sort
fn sortByDepartmentThenSalary(employees: []Employee) void {
    std.mem.sort(Employee, employees, {}, struct {
        fn lessThan(_: void, a: Employee, b: Employee) bool {
            const dept_cmp = std.mem.order(u8, a.department, b.department);
            if (dept_cmp != .eq) {
                return dept_cmp == .lt;
            }
            return a.salary > b.salary;
        }
    }.lessThan);
}
// ANCHOR_END: multi_field_sort

// ============================================================================
// String Sorting
// ============================================================================

fn sortByName(people: []Person) void {
    std.mem.sort(Person, people, {}, struct {
        fn lessThan(_: void, a: Person, b: Person) bool {
            return std.mem.order(u8, a.name, b.name) == .lt;
        }
    }.lessThan);
}

// ============================================================================
// PERFORMANCE PITFALL #1: Allocating in Comparators
// ============================================================================
//
// WHY THIS IS PROBLEMATIC:
// ========================
// Sorting algorithms call the comparison function many times:
// - For n=1000 items, quicksort performs ~10,000 comparisons
// - Each comparison here allocates 2 strings, compares them, then frees them
// - Result: ~20,000 allocations instead of 1,000!
//
// TIME COMPLEXITY:
// - Naive approach: O(n log n × m) where m is average string length
// - Optimized approach: O(n×m + n log n) = O(n log n) for large n
//
// SPACE COMPLEXITY:
// - Naive: O(m) temporary per comparison (constantly allocated/freed)
// - Optimized: O(n×m) for proxy array (single allocation, freed at end)
//
// WHEN TO USE EACH:
// - Naive: Only for tiny datasets (<10 items) or one-off sorts
// - Optimized: Production code, large datasets, performance-critical paths
//
// ADDITIONAL PROBLEM - SORT INVARIANT VIOLATION:
// ===============================================
// The original implementation used `catch return false` which is DANGEROUS!
//
// If allocation fails inconsistently:
//   lessThan(a, b) might return false (allocation failed for 'a')
//   lessThan(b, a) might return true  (allocation succeeded for 'b')
//
// This violates the strict weak ordering requirement:
//   If !(a < b) AND !(b < a), then a MUST equal b
//
// When this invariant is broken, sort behavior becomes undefined and may:
// - Infinite loop
// - Corrupt data
// - Produce incorrectly sorted results
//
// THE FIX:
// Use `unreachable` to make OOM a panic, ensuring consistent behavior.
// This is acceptable because:
// 1. We're only converting ASCII names to lowercase (small allocations)
// 2. The allocator is passed in, so caller controls OOM handling
// 3. Undefined behavior from broken sort invariants is worse than a panic

/// NAIVE VERSION - DO NOT USE IN PRODUCTION
/// Demonstrates the comparison pattern but has O(n log n) allocations.
/// FIXED: Now uses `unreachable` instead of `return false` to avoid
/// breaking sort invariants on allocation failure.
fn sortByNameCaseInsensitive(allocator: std.mem.Allocator, people: []Person) !void {
    const Context = struct {
        allocator: std.mem.Allocator,

        fn lessThan(self: @This(), a: Person, b: Person) bool {
            // Use unreachable instead of 'return false' to maintain sort invariants.
            // If this panics, the allocator is out of memory - which is better than
            // undefined behavior from inconsistent comparison results.
            const a_lower = std.ascii.allocLowerString(self.allocator, a.name) catch unreachable;
            defer self.allocator.free(a_lower);
            const b_lower = std.ascii.allocLowerString(self.allocator, b.name) catch unreachable;
            defer self.allocator.free(b_lower);
            return std.mem.order(u8, a_lower, b_lower) == .lt;
        }
    };

    std.mem.sort(Person, people, Context{ .allocator = allocator }, Context.lessThan);
}

/// OPTIMIZED VERSION - RECOMMENDED FOR PRODUCTION
/// Pre-computes all lowercase strings once (O(n) allocations instead of O(n log n)).
/// Also maintains stable sort order by using original index as tiebreaker.
///
/// HOW IT WORKS:
/// 1. Create "proxy" array storing index + pre-computed lowercase name
/// 2. Sort the proxy array (cheap string comparisons, no allocation)
/// 3. Use sorted proxy indices to reorder original array
///
/// PERFORMANCE GAIN:
/// For n=1000 items with average 10-char names:
/// - Naive: ~20,000 allocations (10,000 comparisons × 2 strings each)
/// - Optimized: ~1,000 allocations (one per item)
/// - Speedup: ~20x fewer allocations, much better cache locality
// ANCHOR: proxy_pattern_sort
fn sortByNameCaseInsensitiveOptimized(allocator: std.mem.Allocator, people: []Person) !void {
    if (people.len <= 1) return;

    // Proxy struct: stores original position + pre-computed sort key
    const Proxy = struct {
        index: usize,
        lower_name: []u8,
    };

    // Allocate proxy array
    var proxies = try allocator.alloc(Proxy, people.len);
    var initialized: usize = 0;

    // Cleanup: Free all lowercase strings we allocated
    defer {
        for (proxies[0..initialized]) |proxy| {
            allocator.free(proxy.lower_name);
        }
        allocator.free(proxies);
    }

    // Phase 1: Pre-compute all lowercase names (O(n) allocations)
    for (people, 0..) |person, i| {
        const lower = try std.ascii.allocLowerString(allocator, person.name);
        proxies[i] = .{ .index = i, .lower_name = lower };
        initialized += 1;
    }

    // Phase 2: Sort proxies by lowercase name (O(n log n), but no allocations)
    std.mem.sort(Proxy, proxies, {}, struct {
        fn lessThan(_: void, a: Proxy, b: Proxy) bool {
            return switch (std.mem.order(u8, a.lower_name, b.lower_name)) {
                .lt => true,
                .gt => false,
                // Equal names: use original index for stable sort
                .eq => a.index < b.index,
            };
        }
    }.lessThan);

    // Phase 3: Reorder people array based on sorted proxy indices
    var scratch = try allocator.alloc(Person, people.len);
    defer allocator.free(scratch);

    for (proxies, 0..) |proxy, i| {
        scratch[i] = people[proxy.index];
    }

    // Copy sorted data back to original array
    @memcpy(people, scratch);
}
// ANCHOR_END: proxy_pattern_sort

// ============================================================================
// PERFORMANCE PITFALL #2: Expensive Computations in Comparators
// ============================================================================
//
// WHY THIS IS PROBLEMATIC:
// ========================
// The distanceFromOrigin() function calls @sqrt(), which is expensive:
// - For n=1000 items, quicksort performs ~10,000 comparisons
// - Each comparison calls @sqrt() twice = ~20,000 sqrt operations
// - But we only have 1,000 unique points!
// - Result: Computing the same sqrt ~20x more than necessary
//
// APPLICABLE TO:
// - Any expensive computation: sqrt, sin/cos, string parsing, etc.
// - Database lookups (imagine if distance came from a DB query!)
// - Complex calculations with multiple operations
//
// WHEN TO OPTIMIZE:
// - Dataset size > 100 items
// - Computation involves expensive operations (sqrt, division, transcendentals)
// - Profiling shows comparator as hot spot
// - Real-world: Almost always use the optimized version

/// NAIVE VERSION - Computes distance O(n log n) times
/// For n=1000: ~20,000 sqrt operations
fn sortByDistance(points: []Point) void {
    std.mem.sort(Point, points, {}, struct {
        fn lessThan(_: void, a: Point, b: Point) bool {
            // Each comparison calls distanceFromOrigin() twice
            // distanceFromOrigin() calls @sqrt() - EXPENSIVE!
            return a.distanceFromOrigin() < b.distanceFromOrigin();
        }
    }.lessThan);
}

/// OPTIMIZED VERSION - Pre-computes distances once
/// For n=1000: ~1,000 sqrt operations (20x improvement!)
fn sortByDistanceOptimized(allocator: std.mem.Allocator, points: []Point) !void {
    if (points.len <= 1) return;

    const Proxy = struct {
        index: usize,
        distance: f32,
    };

    var proxies = try allocator.alloc(Proxy, points.len);
    defer allocator.free(proxies);

    // Pre-compute all distances once
    for (points, 0..) |point, i| {
        proxies[i] = .{
            .index = i,
            .distance = point.distanceFromOrigin(), // Called exactly once per point
        };
    }

    // Sort by pre-computed distance (cheap f32 comparison)
    std.mem.sort(Proxy, proxies, {}, struct {
        fn lessThan(_: void, a: Proxy, b: Proxy) bool {
            if (a.distance != b.distance) {
                return a.distance < b.distance;
            }
            return a.index < b.index; // Stable sort
        }
    }.lessThan);

    // Reorder original array
    var scratch = try allocator.alloc(Point, points.len);
    defer allocator.free(scratch);

    for (proxies, 0..) |proxy, i| {
        scratch[i] = points[proxy.index];
    }

    @memcpy(points, scratch);
}

// ============================================================================
// Generic Proxy-Based Sorting Helper
// ============================================================================
//
// USE WHEN:
// - Comparison requires allocation
// - Comparison involves expensive computation
// - You want stable sort behavior
// - Dataset is large enough to matter (>100 items typically)
//
// EXAMPLE USE CASES:
// - Case-insensitive string sorting
// - Sorting by computed properties (distance, hash, checksum)
// - Sorting by normalized/processed data
// - Sorting with database lookups or I/O

/// Generic proxy-based sorting for expensive comparison keys.
/// Computes the sort key once per item, then sorts efficiently.
///
/// KeyType: The type of the pre-computed sort key (e.g., []u8, f32, u64)
/// keyFn: Function that extracts/computes the key from an item
/// compareFn: Comparison function for keys
///
/// Memory: Allocates O(n) temporary space for proxies and scratch buffer
/// Time: O(n×K + n log n) where K is the cost of keyFn
pub fn sortByKey(
    comptime T: type,
    comptime KeyType: type,
    allocator: std.mem.Allocator,
    items: []T,
    keyFn: *const fn (T) KeyType,
    compareFn: *const fn (void, KeyType, KeyType) bool,
) !void {
    if (items.len <= 1) return;

    const Proxy = struct {
        index: usize,
        key: KeyType,
    };

    var proxies = try allocator.alloc(Proxy, items.len);
    defer allocator.free(proxies);

    // Pre-compute all keys
    for (items, 0..) |item, i| {
        proxies[i] = .{
            .index = i,
            .key = keyFn(item),
        };
    }

    // Sort by key with stable tiebreaking
    const Context = struct {
        cmp: *const fn (void, KeyType, KeyType) bool,

        fn lessThan(ctx: @This(), a: Proxy, b: Proxy) bool {
            const a_less_b = ctx.cmp({}, a.key, b.key);
            if (a_less_b) return true;
            const b_less_a = ctx.cmp({}, b.key, a.key);
            if (b_less_a) return false;
            return a.index < b.index; // Stable
        }
    };

    std.mem.sort(Proxy, proxies, Context{ .cmp = compareFn }, Context.lessThan);

    // Reorder using scratch buffer
    var scratch = try allocator.alloc(T, items.len);
    defer allocator.free(scratch);

    for (proxies, 0..) |proxy, i| {
        scratch[i] = items[proxy.index];
    }

    @memcpy(items, scratch);
}

// ============================================================================
// Stable Sort Implementation
// ============================================================================

const IndexedPerson = struct {
    person: Person,
    original_index: usize,
};

fn stableSort(people: []Person, allocator: std.mem.Allocator) !void {
    var indexed = try allocator.alloc(IndexedPerson, people.len);
    defer allocator.free(indexed);

    for (people, 0..) |person, i| {
        indexed[i] = .{ .person = person, .original_index = i };
    }

    std.mem.sort(IndexedPerson, indexed, {}, struct {
        fn lessThan(_: void, a: IndexedPerson, b: IndexedPerson) bool {
            if (a.person.age != b.person.age) {
                return a.person.age < b.person.age;
            }
            return a.original_index < b.original_index;
        }
    }.lessThan);

    for (indexed, 0..) |item, i| {
        people[i] = item.person;
    }
}

// ============================================================================
// Additional Sorting Utilities
// ============================================================================

fn Reverse(comptime T: type, comptime lessThan: fn (void, T, T) bool) type {
    return struct {
        fn compare(_: void, a: T, b: T) bool {
            return lessThan({}, b, a);
        }
    };
}

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

fn sortPointersByAge(people: []*Person) void {
    std.mem.sort(*Person, people, {}, struct {
        fn lessThan(_: void, a: *Person, b: *Person) bool {
            return a.age < b.age;
        }
    }.lessThan);
}

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

fn sortPartial(people: []Person, start: usize, end: usize) void {
    const slice = people[start..end];
    std.mem.sort(Person, slice, {}, struct {
        fn lessThan(_: void, a: Person, b: Person) bool {
            return a.age < b.age;
        }
    }.lessThan);
}

fn sortByGrade(students: []Student) void {
    std.mem.sort(Student, students, {}, struct {
        fn lessThan(_: void, a: Student, b: Student) bool {
            if (a.grade == null) return false;
            if (b.grade == null) return true;
            return a.grade.? < b.grade.?;
        }
    }.lessThan);
}

fn sortByTag(values: []Value) void {
    std.mem.sort(Value, values, {}, struct {
        fn lessThan(_: void, a: Value, b: Value) bool {
            return @intFromEnum(a) < @intFromEnum(b);
        }
    }.lessThan);
}

fn sortByCeoAge(companies: []Company) void {
    std.mem.sort(Company, companies, {}, struct {
        fn lessThan(_: void, a: Company, b: Company) bool {
            return a.ceo.age < b.ceo.age;
        }
    }.lessThan);
}

// ============================================================================
// Tests
// ============================================================================

test "basic sort by age ascending" {
    var people = [_]Person{
        .{ .name = "Alice", .age = 30, .salary = 75000 },
        .{ .name = "Bob", .age = 25, .salary = 65000 },
        .{ .name = "Charlie", .age = 35, .salary = 85000 },
    };

    sortByAgeAsc(&people);

    try testing.expectEqual(@as(u32, 25), people[0].age);
    try testing.expectEqual(@as(u32, 30), people[1].age);
    try testing.expectEqual(@as(u32, 35), people[2].age);
}

test "basic sort by age descending" {
    var people = [_]Person{
        .{ .name = "Alice", .age = 30, .salary = 75000 },
        .{ .name = "Bob", .age = 25, .salary = 65000 },
        .{ .name = "Charlie", .age = 35, .salary = 85000 },
    };

    sortByAgeDesc(&people);

    try testing.expectEqual(@as(u32, 35), people[0].age);
    try testing.expectEqual(@as(u32, 30), people[1].age);
    try testing.expectEqual(@as(u32, 25), people[2].age);
}

test "sort integers using std.sort.asc" {
    var numbers = [_]i32{ 5, 2, 8, 1, 9 };
    std.mem.sort(i32, &numbers, {}, comptime std.sort.asc(i32));

    try testing.expectEqualSlices(i32, &[_]i32{ 1, 2, 5, 8, 9 }, &numbers);
}

test "sort integers using std.sort.desc" {
    var numbers = [_]i32{ 5, 2, 8, 1, 9 };
    std.mem.sort(i32, &numbers, {}, comptime std.sort.desc(i32));

    try testing.expectEqualSlices(i32, &[_]i32{ 9, 8, 5, 2, 1 }, &numbers);
}

test "sort by multiple fields" {
    var employees = [_]Employee{
        .{ .department = "Engineering", .name = "Alice", .salary = 85000 },
        .{ .department = "Engineering", .name = "Bob", .salary = 95000 },
        .{ .department = "Sales", .name = "Charlie", .salary = 70000 },
        .{ .department = "Sales", .name = "David", .salary = 80000 },
    };

    sortByDepartmentThenSalary(&employees);

    try testing.expectEqualStrings("Engineering", employees[0].department);
    try testing.expectEqual(@as(u32, 95000), employees[0].salary);
    try testing.expectEqualStrings("Engineering", employees[1].department);
    try testing.expectEqual(@as(u32, 85000), employees[1].salary);
    try testing.expectEqualStrings("Sales", employees[2].department);
    try testing.expectEqual(@as(u32, 80000), employees[2].salary);
}

test "sort by name lexicographically" {
    var people = [_]Person{
        .{ .name = "Charlie", .age = 35, .salary = 85000 },
        .{ .name = "Alice", .age = 30, .salary = 75000 },
        .{ .name = "Bob", .age = 25, .salary = 65000 },
    };

    sortByName(&people);

    try testing.expectEqualStrings("Alice", people[0].name);
    try testing.expectEqualStrings("Bob", people[1].name);
    try testing.expectEqualStrings("Charlie", people[2].name);
}

test "sort by name case-insensitive naive" {
    var people = [_]Person{
        .{ .name = "charlie", .age = 35, .salary = 85000 },
        .{ .name = "ALICE", .age = 30, .salary = 75000 },
        .{ .name = "Bob", .age = 25, .salary = 65000 },
    };

    try sortByNameCaseInsensitive(testing.allocator, &people);

    try testing.expectEqualStrings("ALICE", people[0].name);
    try testing.expectEqualStrings("Bob", people[1].name);
    try testing.expectEqualStrings("charlie", people[2].name);
}

test "sort by name case-insensitive optimized" {
    var people = [_]Person{
        .{ .name = "charlie", .age = 35, .salary = 85000 },
        .{ .name = "ALICE", .age = 30, .salary = 75000 },
        .{ .name = "Bob", .age = 25, .salary = 65000 },
        .{ .name = "alice", .age = 41, .salary = 95000 },
    };

    try sortByNameCaseInsensitiveOptimized(testing.allocator, &people);

    try testing.expectEqualStrings("ALICE", people[0].name);
    try testing.expectEqualStrings("alice", people[1].name);
    try testing.expectEqualStrings("Bob", people[2].name);
    try testing.expectEqualStrings("charlie", people[3].name);
}

test "case-insensitive: naive and optimized produce same results" {
    var people_naive = [_]Person{
        .{ .name = "Zebra", .age = 10, .salary = 1 },
        .{ .name = "apple", .age = 20, .salary = 2 },
        .{ .name = "BANANA", .age = 30, .salary = 3 },
        .{ .name = "cherry", .age = 40, .salary = 4 },
    };

    var people_opt = [_]Person{
        .{ .name = "Zebra", .age = 10, .salary = 1 },
        .{ .name = "apple", .age = 20, .salary = 2 },
        .{ .name = "BANANA", .age = 30, .salary = 3 },
        .{ .name = "cherry", .age = 40, .salary = 4 },
    };

    try sortByNameCaseInsensitive(testing.allocator, &people_naive);
    try sortByNameCaseInsensitiveOptimized(testing.allocator, &people_opt);

    for (people_naive, people_opt) |naive, opt| {
        try testing.expectEqualStrings(naive.name, opt.name);
    }
}

test "stable sort maintains order of equal elements" {
    var people = [_]Person{
        .{ .name = "Alice", .age = 30, .salary = 75000 },
        .{ .name = "Bob", .age = 30, .salary = 65000 },
        .{ .name = "Charlie", .age = 25, .salary = 85000 },
        .{ .name = "David", .age = 30, .salary = 70000 },
    };

    try stableSort(&people, testing.allocator);

    try testing.expectEqualStrings("Charlie", people[0].name);
    try testing.expectEqualStrings("Alice", people[1].name);
    try testing.expectEqualStrings("Bob", people[2].name);
    try testing.expectEqualStrings("David", people[3].name);
}

test "reverse comparator" {
    const AscByAge = struct {
        fn lessThan(_: void, a: Person, b: Person) bool {
            return a.age < b.age;
        }
    };

    var people = [_]Person{
        .{ .name = "Alice", .age = 30, .salary = 75000 },
        .{ .name = "Bob", .age = 25, .salary = 65000 },
        .{ .name = "Charlie", .age = 35, .salary = 85000 },
    };

    std.mem.sort(Person, &people, {}, Reverse(Person, AscByAge.lessThan).compare);

    try testing.expectEqual(@as(u32, 35), people[0].age);
    try testing.expectEqual(@as(u32, 30), people[1].age);
    try testing.expectEqual(@as(u32, 25), people[2].age);
}

test "sort by computed distance naive" {
    var points = [_]Point{
        .{ .x = 3.0, .y = 4.0 }, // distance 5.0
        .{ .x = 1.0, .y = 1.0 }, // distance ~1.41
        .{ .x = 0.0, .y = 5.0 }, // distance 5.0
        .{ .x = 2.0, .y = 2.0 }, // distance ~2.83
    };

    sortByDistance(&points);

    const d0 = points[0].distanceFromOrigin();
    const d1 = points[1].distanceFromOrigin();
    const d2 = points[2].distanceFromOrigin();
    const d3 = points[3].distanceFromOrigin();

    try testing.expect(d0 <= d1);
    try testing.expect(d1 <= d2);
    try testing.expect(d2 <= d3);
}

test "sort by computed distance optimized" {
    var points = [_]Point{
        .{ .x = 3.0, .y = 4.0 }, // distance 5.0
        .{ .x = 1.0, .y = 1.0 }, // distance ~1.41
        .{ .x = 0.0, .y = 5.0 }, // distance 5.0
        .{ .x = 2.0, .y = 2.0 }, // distance ~2.83
    };

    try sortByDistanceOptimized(testing.allocator, &points);

    const d0 = points[0].distanceFromOrigin();
    const d1 = points[1].distanceFromOrigin();
    const d2 = points[2].distanceFromOrigin();
    const d3 = points[3].distanceFromOrigin();

    try testing.expect(d0 <= d1);
    try testing.expect(d1 <= d2);
    try testing.expect(d2 <= d3);
}

test "distance sort: naive and optimized produce same results" {
    var points_naive = [_]Point{
        .{ .x = 5.0, .y = 5.0 },
        .{ .x = 1.0, .y = 1.0 },
        .{ .x = 3.0, .y = 4.0 },
        .{ .x = 2.0, .y = 2.0 },
    };

    var points_opt = [_]Point{
        .{ .x = 5.0, .y = 5.0 },
        .{ .x = 1.0, .y = 1.0 },
        .{ .x = 3.0, .y = 4.0 },
        .{ .x = 2.0, .y = 2.0 },
    };

    sortByDistance(&points_naive);
    try sortByDistanceOptimized(testing.allocator, &points_opt);

    for (points_naive, points_opt) |naive, opt| {
        try testing.expectEqual(naive.x, opt.x);
        try testing.expectEqual(naive.y, opt.y);
    }
}

test "generic sortByKey with distance" {
    const Helper = struct {
        fn extractDistance(point: Point) f32 {
            return point.distanceFromOrigin();
        }

        fn compareF32(_: void, a: f32, b: f32) bool {
            return a < b;
        }
    };

    var points = [_]Point{
        .{ .x = 3.0, .y = 4.0 },
        .{ .x = 1.0, .y = 1.0 },
        .{ .x = 2.0, .y = 2.0 },
    };

    try sortByKey(Point, f32, testing.allocator, &points, &Helper.extractDistance, &Helper.compareF32);

    const d0 = points[0].distanceFromOrigin();
    const d1 = points[1].distanceFromOrigin();
    const d2 = points[2].distanceFromOrigin();

    try testing.expect(d0 <= d1);
    try testing.expect(d1 <= d2);
}

test "generic field comparator" {
    var people = [_]Person{
        .{ .name = "Alice", .age = 30, .salary = 75000 },
        .{ .name = "Bob", .age = 25, .salary = 65000 },
        .{ .name = "Charlie", .age = 35, .salary = 85000 },
    };

    std.mem.sort(Person, &people, {}, FieldComparator(Person, "age", true).lessThan);

    try testing.expectEqual(@as(u32, 25), people[0].age);
    try testing.expectEqual(@as(u32, 30), people[1].age);
    try testing.expectEqual(@as(u32, 35), people[2].age);
}

test "generic field comparator descending" {
    var people = [_]Person{
        .{ .name = "Alice", .age = 30, .salary = 75000 },
        .{ .name = "Bob", .age = 25, .salary = 65000 },
        .{ .name = "Charlie", .age = 35, .salary = 85000 },
    };

    std.mem.sort(Person, &people, {}, FieldComparator(Person, "salary", false).lessThan);

    try testing.expectEqual(@as(u32, 85000), people[0].salary);
    try testing.expectEqual(@as(u32, 75000), people[1].salary);
    try testing.expectEqual(@as(u32, 65000), people[2].salary);
}

test "sort pointers to structs" {
    var alice = Person{ .name = "Alice", .age = 30, .salary = 75000 };
    var bob = Person{ .name = "Bob", .age = 25, .salary = 65000 };
    var charlie = Person{ .name = "Charlie", .age = 35, .salary = 85000 };

    var people = [_]*Person{ &charlie, &alice, &bob };

    sortPointersByAge(&people);

    try testing.expectEqual(@as(u32, 25), people[0].age);
    try testing.expectEqual(@as(u32, 30), people[1].age);
    try testing.expectEqual(@as(u32, 35), people[2].age);
}

test "sort with context by age ascending" {
    var people = [_]Person{
        .{ .name = "Alice", .age = 30, .salary = 75000 },
        .{ .name = "Bob", .age = 25, .salary = 65000 },
        .{ .name = "Charlie", .age = 35, .salary = 85000 },
    };

    const context = SortContext{ .sort_field = .age, .ascending = true };
    std.mem.sort(Person, &people, context, SortContext.lessThan);

    try testing.expectEqual(@as(u32, 25), people[0].age);
    try testing.expectEqual(@as(u32, 30), people[1].age);
    try testing.expectEqual(@as(u32, 35), people[2].age);
}

test "sort with context by salary descending" {
    var people = [_]Person{
        .{ .name = "Alice", .age = 30, .salary = 75000 },
        .{ .name = "Bob", .age = 25, .salary = 65000 },
        .{ .name = "Charlie", .age = 35, .salary = 85000 },
    };

    const context = SortContext{ .sort_field = .salary, .ascending = false };
    std.mem.sort(Person, &people, context, SortContext.lessThan);

    try testing.expectEqual(@as(u32, 85000), people[0].salary);
    try testing.expectEqual(@as(u32, 75000), people[1].salary);
    try testing.expectEqual(@as(u32, 65000), people[2].salary);
}

test "partial sorting" {
    var people = [_]Person{
        .{ .name = "Alice", .age = 30, .salary = 75000 },
        .{ .name = "Bob", .age = 25, .salary = 65000 },
        .{ .name = "Charlie", .age = 35, .salary = 85000 },
        .{ .name = "David", .age = 28, .salary = 70000 },
    };

    sortPartial(&people, 1, 3);

    try testing.expectEqualStrings("Alice", people[0].name);
    try testing.expectEqual(@as(u32, 25), people[1].age);
    try testing.expectEqual(@as(u32, 35), people[2].age);
    try testing.expectEqualStrings("David", people[3].name);
}

test "sort by optional fields - nulls last" {
    var students = [_]Student{
        .{ .name = "Alice", .grade = 85 },
        .{ .name = "Bob", .grade = null },
        .{ .name = "Charlie", .grade = 92 },
        .{ .name = "David", .grade = null },
        .{ .name = "Eve", .grade = 78 },
    };

    sortByGrade(&students);

    try testing.expectEqual(@as(u32, 78), students[0].grade.?);
    try testing.expectEqual(@as(u32, 85), students[1].grade.?);
    try testing.expectEqual(@as(u32, 92), students[2].grade.?);
    try testing.expect(students[3].grade == null);
    try testing.expect(students[4].grade == null);
}

test "sort tagged unions by tag" {
    var values = [_]Value{
        .{ .string = "hello" },
        .{ .int = 42 },
        .{ .float = 3.14 },
        .{ .string = "world" },
        .{ .int = 7 },
    };

    sortByTag(&values);

    try testing.expect(values[0] == .int);
    try testing.expect(values[1] == .int);
    try testing.expect(values[2] == .float);
    try testing.expect(values[3] == .string);
    try testing.expect(values[4] == .string);
}

test "sort by nested field" {
    var companies = [_]Company{
        .{ .name = "TechCorp", .ceo = .{ .name = "Alice", .age = 45 } },
        .{ .name = "StartupInc", .ceo = .{ .name = "Bob", .age = 32 } },
        .{ .name = "BigCo", .ceo = .{ .name = "Charlie", .age = 58 } },
    };

    sortByCeoAge(&companies);

    try testing.expectEqual(@as(u32, 32), companies[0].ceo.age);
    try testing.expectEqual(@as(u32, 45), companies[1].ceo.age);
    try testing.expectEqual(@as(u32, 58), companies[2].ceo.age);
}

test "sort empty slice" {
    var people: [0]Person = undefined;
    sortByAgeAsc(&people);
    // Should not crash
}

test "sort single element" {
    var people = [_]Person{
        .{ .name = "Alice", .age = 30, .salary = 75000 },
    };
    sortByAgeAsc(&people);
    try testing.expectEqualStrings("Alice", people[0].name);
}
