// Recipe 1.4: When to Pass by Pointer vs Value
// Target Zig Version: 0.15.2
//
// This recipe demonstrates when to pass arguments by value vs by pointer,
// covering performance considerations, mutability requirements, and Zig idioms.

const std = @import("std");
const testing = std.testing;

// ANCHOR: small_types_by_value
// Small types: pass by value (cheap to copy)
fn incrementByValue(x: i32) i32 {
    return x + 1;
}

fn addPoints(a: Point2D, b: Point2D) Point2D {
    return .{
        .x = a.x + b.x,
        .y = a.y + b.y,
    };
}

const Point2D = struct {
    x: f32,
    y: f32,
};

test "small types by value" {
    const result = incrementByValue(5);
    try testing.expectEqual(@as(i32, 6), result);

    const p1 = Point2D{ .x = 1.0, .y = 2.0 };
    const p2 = Point2D{ .x = 3.0, .y = 4.0 };
    const sum = addPoints(p1, p2);

    try testing.expectEqual(@as(f32, 4.0), sum.x);
    try testing.expectEqual(@as(f32, 6.0), sum.y);
}
// ANCHOR_END: small_types_by_value

// ANCHOR: mutation_by_pointer
// Mutation: pass by pointer when you need to modify
fn incrementByPointer(x: *i32) void {
    x.* += 1;
}

fn scalePoint(point: *Point2D, factor: f32) void {
    point.x *= factor;
    point.y *= factor;
}

test "mutation requires pointer" {
    var value: i32 = 5;
    incrementByPointer(&value);
    try testing.expectEqual(@as(i32, 6), value);

    var point = Point2D{ .x = 2.0, .y = 3.0 };
    scalePoint(&point, 2.0);

    try testing.expectEqual(@as(f32, 4.0), point.x);
    try testing.expectEqual(@as(f32, 6.0), point.y);
}
// ANCHOR_END: mutation_by_pointer

// ANCHOR: large_types_const_pointer
// Large types: pass by const pointer to avoid copies
const LargeStruct = struct {
    data: [1024]u8,
    metadata: [256]u8,

    pub fn init() LargeStruct {
        return .{
            .data = [_]u8{0} ** 1024,
            .metadata = [_]u8{0} ** 256,
        };
    }
};

// Inefficient: copies 1280 bytes
fn processLargeByValue(large: LargeStruct) usize {
    var sum: usize = 0;
    for (large.data) |byte| {
        sum += byte;
    }
    return sum;
}

// Efficient: passes 8-byte pointer
fn processLargeByConstPointer(large: *const LargeStruct) usize {
    var sum: usize = 0;
    for (large.data) |byte| {
        sum += byte;
    }
    return sum;
}

test "large types use const pointer" {
    const large = LargeStruct.init();

    // Both work, but const pointer is more efficient
    const result1 = processLargeByValue(large);
    const result2 = processLargeByConstPointer(&large);

    try testing.expectEqual(result1, result2);
    try testing.expectEqual(@as(usize, 0), result1);
}
// ANCHOR_END: large_types_const_pointer

// ANCHOR: const_pointer_immutability
// Const pointers prevent mutation
fn tryToModify(point: *const Point2D) f32 {
    // point.x = 10.0;  // Compile error: cannot assign to const
    return point.x + point.y;
}

fn mustModify(point: *Point2D) void {
    point.x = 10.0; // OK: mutable pointer
}

test "const pointer prevents modification" {
    var point = Point2D{ .x = 1.0, .y = 2.0 };

    const sum = tryToModify(&point);
    try testing.expectEqual(@as(f32, 3.0), sum);

    mustModify(&point);
    try testing.expectEqual(@as(f32, 10.0), point.x);
}
// ANCHOR_END: const_pointer_immutability

// ANCHOR: slices_already_pointers
// Slices are already pointers - don't double-pointer
fn sumSlice(items: []const i32) i32 {
    var total: i32 = 0;
    for (items) |item| {
        total += item;
    }
    return total;
}

// Don't do this - slice is already a reference
// fn sumSliceWrong(items: *const []const i32) i32 { ... }

test "slices are already pointers" {
    const numbers = [_]i32{ 1, 2, 3, 4, 5 };
    const total = sumSlice(&numbers);
    try testing.expectEqual(@as(i32, 15), total);
}
// ANCHOR_END: slices_already_pointers

// ANCHOR: return_by_value
// Return by value for small types and stack allocation
fn createPoint(x: f32, y: f32) Point2D {
    return .{ .x = x, .y = y };
}

fn createArray() [4]i32 {
    return .{ 1, 2, 3, 4 };
}

test "return by value for small types" {
    const point = createPoint(5.0, 10.0);
    try testing.expectEqual(@as(f32, 5.0), point.x);

    const array = createArray();
    try testing.expectEqual(@as(i32, 1), array[0]);
    try testing.expectEqual(@as(i32, 4), array[3]);
}
// ANCHOR_END: return_by_value

// ANCHOR: caller_allocated
// Caller-allocated: pass pointer to receive large result
fn fillLargeStruct(result: *LargeStruct) void {
    result.data = [_]u8{42} ** 1024;
    result.metadata = [_]u8{1} ** 256;
}

test "caller-allocated pattern" {
    var large = LargeStruct.init();
    fillLargeStruct(&large);

    try testing.expectEqual(@as(u8, 42), large.data[0]);
    try testing.expectEqual(@as(u8, 1), large.metadata[0]);
}
// ANCHOR_END: caller_allocated

// ANCHOR: performance_comparison
// Demonstrate performance difference with benchmarking approach
const BenchmarkData = struct {
    values: [100]f32,

    pub fn init() BenchmarkData {
        var result = BenchmarkData{ .values = undefined };
        for (&result.values, 0..) |*val, i| {
            val.* = @floatFromInt(i);
        }
        return result;
    }
};

fn processByValue(data: BenchmarkData) f32 {
    var sum: f32 = 0.0;
    for (data.values) |val| {
        sum += val;
    }
    return sum;
}

fn processByPointer(data: *const BenchmarkData) f32 {
    var sum: f32 = 0.0;
    for (data.values) |val| {
        sum += val;
    }
    return sum;
}

test "performance comparison" {
    const data = BenchmarkData.init();

    const result1 = processByValue(data);
    const result2 = processByPointer(&data);

    try testing.expectEqual(result1, result2);
}
// ANCHOR_END: performance_comparison

// ANCHOR: struct_methods_self
// Struct methods: self convention
const Counter = struct {
    value: i32,

    pub fn init() Counter {
        return .{ .value = 0 };
    }

    // Method that reads: const pointer
    pub fn getValue(self: *const Counter) i32 {
        return self.value;
    }

    // Method that mutates: mutable pointer
    pub fn increment(self: *Counter) void {
        self.value += 1;
    }

    // Method that consumes: by value
    pub fn consume(self: Counter) i32 {
        return self.value;
    }
};

test "struct method self conventions" {
    var counter = Counter.init();

    try testing.expectEqual(@as(i32, 0), counter.getValue());

    counter.increment();
    try testing.expectEqual(@as(i32, 1), counter.getValue());

    const final = counter.consume();
    try testing.expectEqual(@as(i32, 1), final);
}
// ANCHOR_END: struct_methods_self

// ANCHOR: optional_pointers
// Optional pointers for optional references
fn findMax(items: []const i32) ?*const i32 {
    if (items.len == 0) return null;

    var max_idx: usize = 0;
    for (items[1..], 1..) |val, i| {
        if (val > items[max_idx]) {
            max_idx = i;
        }
    }
    return &items[max_idx];
}

test "optional pointers" {
    const numbers = [_]i32{ 3, 7, 2, 9, 1 };
    const max = findMax(&numbers);

    try testing.expect(max != null);
    try testing.expectEqual(@as(i32, 9), max.?.*);

    const empty: []const i32 = &.{};
    const no_max = findMax(empty);
    try testing.expect(no_max == null);
}
// ANCHOR_END: optional_pointers

// ANCHOR: pointer_size_awareness
// Size awareness: primitives vs structs
test "pointer size is always constant" {
    // Pointers are always 8 bytes on 64-bit (regardless of what they point to)
    try testing.expectEqual(@as(usize, 8), @sizeOf(*i32));
    try testing.expectEqual(@as(usize, 8), @sizeOf(*LargeStruct));
    try testing.expectEqual(@as(usize, 8), @sizeOf(*Point2D));

    // Values vary in size
    try testing.expectEqual(@as(usize, 4), @sizeOf(i32));
    try testing.expectEqual(@as(usize, 1280), @sizeOf(LargeStruct));
    try testing.expectEqual(@as(usize, 8), @sizeOf(Point2D));
}
// ANCHOR_END: pointer_size_awareness

// ANCHOR: multi_return_values
// Multiple return values: use struct, not pointer out-params
const DivResult = struct {
    quotient: i32,
    remainder: i32,
};

fn divmod(a: i32, b: i32) DivResult {
    return .{
        .quotient = @divTrunc(a, b),
        .remainder = @rem(a, b),
    };
}

test "multi return with struct" {
    const result = divmod(17, 5);

    try testing.expectEqual(@as(i32, 3), result.quotient);
    try testing.expectEqual(@as(i32, 2), result.remainder);
}
// ANCHOR_END: multi_return_values

// ANCHOR: aliasing_concerns
// Be aware of pointer aliasing
fn addToEach(a: *i32, b: *i32, value: i32) void {
    a.* += value;
    b.* += value;
}

test "pointer aliasing" {
    var x: i32 = 10;
    var y: i32 = 20;

    // Different pointers: works as expected
    addToEach(&x, &y, 5);
    try testing.expectEqual(@as(i32, 15), x);
    try testing.expectEqual(@as(i32, 25), y);

    // Same pointer: adds twice (aliasing)
    var z: i32 = 10;
    addToEach(&z, &z, 5);
    try testing.expectEqual(@as(i32, 20), z); // 10 + 5 + 5
}
// ANCHOR_END: aliasing_concerns

// Comprehensive test
test "comprehensive pointer vs value patterns" {
    // Small types by value
    const inc_result = incrementByValue(10);
    try testing.expectEqual(@as(i32, 11), inc_result);

    // Mutation by pointer
    var mut_value: i32 = 5;
    incrementByPointer(&mut_value);
    try testing.expectEqual(@as(i32, 6), mut_value);

    // Large types by const pointer
    const large = LargeStruct.init();
    _ = processLargeByConstPointer(&large);

    // Slices already pointers
    const nums = [_]i32{ 1, 2, 3 };
    _ = sumSlice(&nums);

    // Struct methods
    var counter = Counter.init();
    counter.increment();
    try testing.expectEqual(@as(i32, 1), counter.getValue());

    // Multiple returns
    const div_result = divmod(10, 3);
    try testing.expectEqual(@as(i32, 3), div_result.quotient);

    try testing.expect(true);
}
