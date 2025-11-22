const std = @import("std");
const testing = std.testing;

// ANCHOR: simd_optimization
fn sumScalar(data: []const f32) f32 {
    var sum: f32 = 0;
    for (data) |value| {
        sum += value;
    }
    return sum;
}

fn sumVectorized(data: []const f32) f32 {
    const Vector = @Vector(4, f32);
    var sum_vec: Vector = @splat(0.0);

    const len_aligned = data.len - (data.len % 4);
    var i: usize = 0;
    while (i < len_aligned) : (i += 4) {
        const vec: Vector = data[i..][0..4].*;
        sum_vec += vec;
    }

    var sum: f32 = @reduce(.Add, sum_vec);
    while (i < data.len) : (i += 1) {
        sum += data[i];
    }

    return sum;
}

test "SIMD vectorization" {
    const data = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0 };
    try testing.expectApproxEqAbs(sumScalar(&data), sumVectorized(&data), 0.001);
}
// ANCHOR_END: simd_optimization

// ANCHOR: cache_friendly
const Point2D = struct {
    x: f32,
    y: f32,
};

// Array of Structs (AoS) - less cache friendly
fn processAoS(points: []Point2D) f32 {
    var sum_x: f32 = 0;
    for (points) |point| {
        sum_x += point.x;
    }
    return sum_x;
}

// Struct of Arrays (SoA) - more cache friendly
const Points2D_SoA = struct {
    x: []f32,
    y: []f32,
};

fn processSoA(points: Points2D_SoA) f32 {
    var sum_x: f32 = 0;
    for (points.x) |x| {
        sum_x += x;
    }
    return sum_x;
}

test "cache-friendly data layout" {
    var aos = [_]Point2D{
        .{ .x = 1.0, .y = 2.0 },
        .{ .x = 3.0, .y = 4.0 },
    };

    var x_data = [_]f32{ 1.0, 3.0 };
    var y_data = [_]f32{ 2.0, 4.0 };
    const soa = Points2D_SoA{ .x = &x_data, .y = &y_data };

    try testing.expectApproxEqAbs(processAoS(&aos), processSoA(soa), 0.001);
}
// ANCHOR_END: cache_friendly

// ANCHOR: loop_unrolling
fn sumLoopNormal(data: []const i32) i64 {
    var sum: i64 = 0;
    for (data) |value| {
        sum += value;
    }
    return sum;
}

fn sumLoopUnrolled(data: []const i32) i64 {
    var sum: i64 = 0;
    const len = data.len;
    var i: usize = 0;

    // Process 4 elements at a time
    while (i + 4 <= len) : (i += 4) {
        sum += data[i];
        sum += data[i + 1];
        sum += data[i + 2];
        sum += data[i + 3];
    }

    // Handle remaining elements
    while (i < len) : (i += 1) {
        sum += data[i];
    }

    return sum;
}

test "loop unrolling" {
    const data = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    try testing.expectEqual(sumLoopNormal(&data), sumLoopUnrolled(&data));
}
// ANCHOR_END: loop_unrolling

// ANCHOR: inline_functions
inline fn fastMultiply(a: i32, b: i32) i32 {
    return a * b;
}

fn computeWithInline(data: []const i32) i64 {
    var sum: i64 = 0;
    for (data) |value| {
        sum += fastMultiply(value, 2);
    }
    return sum;
}

test "inline functions" {
    const data = [_]i32{ 1, 2, 3, 4, 5 };
    try testing.expectEqual(@as(i64, 30), computeWithInline(&data));
}
// ANCHOR_END: inline_functions

// ANCHOR: branch_prediction
fn branchUnpredictable(data: []const i32) i64 {
    var sum: i64 = 0;
    for (data) |value| {
        if (value > 50) {
            sum += value * 2;
        } else {
            sum += value;
        }
    }
    return sum;
}

fn branchlessPredictable(data: []const i32) i64 {
    var sum: i64 = 0;
    for (data) |value| {
        const multiplier: i32 = if (value > 50) 2 else 1;
        sum += value * multiplier;
    }
    return sum;
}

test "branch prediction" {
    const data = [_]i32{ 10, 20, 60, 70, 30 };
    try testing.expectEqual(branchUnpredictable(&data), branchlessPredictable(&data));
}
// ANCHOR_END: branch_prediction

// ANCHOR: memory_pooling
const ObjectPool = struct {
    objects: []?Object,
    free_list: std.ArrayList(usize),
    allocator: std.mem.Allocator,

    const Object = struct {
        data: [64]u8,
    };

    fn init(allocator: std.mem.Allocator, capacity: usize) !ObjectPool {
        const objects = try allocator.alloc(?Object, capacity);
        @memset(objects, null);

        var free_list = std.ArrayList(usize){};
        try free_list.ensureTotalCapacity(allocator, capacity);
        for (0..capacity) |i| {
            try free_list.append(allocator, capacity - 1 - i);
        }

        return .{
            .objects = objects,
            .free_list = free_list,
            .allocator = allocator,
        };
    }

    fn deinit(self: *ObjectPool) void {
        self.allocator.free(self.objects);
        self.free_list.deinit(self.allocator);
    }

    fn acquire(self: *ObjectPool) !*Object {
        if (self.free_list.items.len == 0) return error.PoolExhausted;
        const index = self.free_list.items[self.free_list.items.len - 1];
        _ = self.free_list.pop();
        self.objects[index] = Object{ .data = undefined };
        return &self.objects[index].?;
    }

    fn release(self: *ObjectPool, obj: *Object) !void {
        const index = (@intFromPtr(obj) - @intFromPtr(self.objects.ptr)) / @sizeOf(?Object);
        self.objects[index] = null;
        try self.free_list.append(self.allocator, index);
    }
};

test "memory pooling" {
    var pool = try ObjectPool.init(testing.allocator, 10);
    defer pool.deinit();

    const obj1 = try pool.acquire();
    const obj2 = try pool.acquire();

    try pool.release(obj1);
    try pool.release(obj2);
}
// ANCHOR_END: memory_pooling

// ANCHOR: reduce_allocations
fn processWithManyAllocations(allocator: std.mem.Allocator, count: usize) !void {
    for (0..count) |i| {
        const buffer = try allocator.alloc(u8, 100);
        defer allocator.free(buffer);
        // Use buffer
        buffer[0] = @intCast(i % 256);
    }
}

fn processWithSingleAllocation(allocator: std.mem.Allocator, count: usize) !void {
    const buffer = try allocator.alloc(u8, 100);
    defer allocator.free(buffer);

    for (0..count) |i| {
        // Reuse buffer
        buffer[0] = @intCast(i % 256);
    }
}

test "reduce allocations" {
    try processWithManyAllocations(testing.allocator, 10);
    try processWithSingleAllocation(testing.allocator, 10);
}
// ANCHOR_END: reduce_allocations

// ANCHOR: const_parameters
fn processData(comptime use_fast_path: bool, data: []i32) i64 {
    var sum: i64 = 0;
    if (use_fast_path) {
        // Compiler knows this branch at compile time
        for (data) |value| {
            sum += value;
        }
    } else {
        for (data) |value| {
            sum += value * value;
        }
    }
    return sum;
}

test "comptime optimization" {
    var data = [_]i32{ 1, 2, 3, 4, 5 };
    const fast = processData(true, &data);
    const slow = processData(false, &data);
    try testing.expectEqual(@as(i64, 15), fast);
    try testing.expectEqual(@as(i64, 55), slow);
}
// ANCHOR_END: const_parameters

// ANCHOR: avoid_bounds_checks
fn sumWithBoundsChecks(data: []const i32) i64 {
    var sum: i64 = 0;
    for (0..data.len) |i| {
        sum += data[i]; // Bounds checked
    }
    return sum;
}

fn sumNoBoundsChecks(data: []const i32) i64 {
    var sum: i64 = 0;
    for (data) |value| { // Iterator, no bounds check
        sum += value;
    }
    return sum;
}

test "avoid bounds checks" {
    const data = [_]i32{ 1, 2, 3, 4, 5 };
    try testing.expectEqual(sumWithBoundsChecks(&data), sumNoBoundsChecks(&data));
}
// ANCHOR_END: avoid_bounds_checks

// ANCHOR: string_building
fn buildStringNaive(allocator: std.mem.Allocator) ![]u8 {
    var result = std.ArrayList(u8){};
    for (0..100) |i| {
        const str = try std.fmt.allocPrint(allocator, "{d} ", .{i});
        defer allocator.free(str);
        try result.appendSlice(allocator, str);
    }
    return result.toOwnedSlice(allocator);
}

fn buildStringEfficient(allocator: std.mem.Allocator) ![]u8 {
    var result = std.ArrayList(u8){};
    try result.ensureTotalCapacity(allocator, 400); // Pre-allocate

    for (0..100) |i| {
        try result.writer(allocator).print("{d} ", .{i});
    }
    return result.toOwnedSlice(allocator);
}

test "efficient string building" {
    const naive = try buildStringNaive(testing.allocator);
    defer testing.allocator.free(naive);

    const efficient = try buildStringEfficient(testing.allocator);
    defer testing.allocator.free(efficient);

    try testing.expectEqualStrings(naive, efficient);
}
// ANCHOR_END: string_building

// ANCHOR: packed_structs
const UnpackedFlags = struct {
    flag1: bool,
    flag2: bool,
    flag3: bool,
    flag4: bool,
    // 4 bytes (with padding)
};

const PackedFlags = packed struct {
    flag1: bool,
    flag2: bool,
    flag3: bool,
    flag4: bool,
    // 1 byte
};

test "packed structs" {
    const unpacked = UnpackedFlags{
        .flag1 = true,
        .flag2 = false,
        .flag3 = true,
        .flag4 = false,
    };

    const packed_flags = PackedFlags{
        .flag1 = true,
        .flag2 = false,
        .flag3 = true,
        .flag4 = false,
    };

    try testing.expect(@sizeOf(UnpackedFlags) >= @sizeOf(PackedFlags));
    _ = unpacked;
    _ = packed_flags;
}
// ANCHOR_END: packed_structs
