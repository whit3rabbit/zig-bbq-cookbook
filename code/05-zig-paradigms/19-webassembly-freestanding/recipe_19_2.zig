const std = @import("std");
const testing = std.testing;

// Custom panic handler required for freestanding targets
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = msg;
    _ = error_return_trace;
    _ = ret_addr;
    while (true) {}
}

// ANCHOR: point_struct
// Point structure stored in WASM linear memory
const Point = struct {
    x: f64,
    y: f64,
};
// ANCHOR_END: point_struct

// ANCHOR: global_state
// Global state (simple use case - be careful with this pattern)
var counter: i32 = 0;
var last_calculation: f64 = 0.0;
// ANCHOR_END: global_state

// ANCHOR: counter_functions
// Counter manipulation
export fn incrementCounter() i32 {
    counter += 1;
    return counter;
}

export fn getCounter() i32 {
    return counter;
}

export fn resetCounter() void {
    counter = 0;
}
// ANCHOR_END: counter_functions

// ANCHOR: divide_with_remainder
// Return multiple values via pointer parameters
export fn divideWithRemainder(dividend: i32, divisor: i32, remainder_ptr: *i32) i32 {
    const quotient = @divTrunc(dividend, divisor);
    const remainder = @rem(dividend, divisor);
    remainder_ptr.* = remainder;
    return quotient;
}
// ANCHOR_END: divide_with_remainder

// ANCHOR: distance_calculation
// Calculate distance and store result
export fn calculateDistance(x1: f64, y1: f64, x2: f64, y2: f64) f64 {
    const dx = x2 - x1;
    const dy = y2 - y1;
    const distance = @sqrt(dx * dx + dy * dy);
    last_calculation = distance;
    return distance;
}

export fn getLastCalculation() f64 {
    return last_calculation;
}
// ANCHOR_END: distance_calculation

// ANCHOR: point_operations
// Allocate a point in WASM memory and return its address
export fn createPoint(x: f64, y: f64) *Point {
    // In a real application, you'd use a proper allocator
    // For this example, we use a static buffer
    const static = struct {
        var points_buffer: [100]Point = undefined;
        var next_index: usize = 0;
    };

    if (static.next_index >= static.points_buffer.len) {
        // Out of space - in real code, handle this better
        static.next_index = 0;
    }

    static.points_buffer[static.next_index] = Point{ .x = x, .y = y };
    const result = &static.points_buffer[static.next_index];
    static.next_index += 1;

    return result;
}

// Get point coordinates
export fn getPointX(point: *const Point) f64 {
    return point.x;
}

export fn getPointY(point: *const Point) f64 {
    return point.y;
}

// Calculate distance between two points
export fn pointDistance(p1: *const Point, p2: *const Point) f64 {
    const dx = p2.x - p1.x;
    const dy = p2.y - p1.y;
    return @sqrt(dx * dx + dy * dy);
}
// ANCHOR_END: point_operations

// ANCHOR: range_check
// Return bool (becomes i32 in WASM: 0 or 1)
export fn isInRange(value: f64, min: f64, max: f64) bool {
    return value >= min and value <= max;
}
// ANCHOR_END: range_check

// ANCHOR: clamp_function
// Clamp a value between min and max
export fn clamp(value: f64, min: f64, max: f64) f64 {
    if (value < min) return min;
    if (value > max) return max;
    return value;
}
// ANCHOR_END: clamp_function

// ANCHOR: factorial
// Factorial with iteration
export fn factorial(n: i32) i32 {
    if (n < 0) return 0;
    if (n <= 1) return 1;

    var result: i32 = 1;
    var i: i32 = 2;
    while (i <= n) : (i += 1) {
        result *= i;
    }

    return result;
}
// ANCHOR_END: factorial

// Tests

// ANCHOR: test_counter
test "counter functions" {
    counter = 0; // Reset for test
    try testing.expectEqual(@as(i32, 0), getCounter());
    try testing.expectEqual(@as(i32, 1), incrementCounter());
    try testing.expectEqual(@as(i32, 2), incrementCounter());
    try testing.expectEqual(@as(i32, 2), getCounter());
    resetCounter();
    try testing.expectEqual(@as(i32, 0), getCounter());
}
// ANCHOR_END: test_counter

// ANCHOR: test_divide_remainder
test "divide with remainder" {
    var remainder: i32 = undefined;
    const quotient = divideWithRemainder(17, 5, &remainder);
    try testing.expectEqual(@as(i32, 3), quotient);
    try testing.expectEqual(@as(i32, 2), remainder);

    const quotient2 = divideWithRemainder(20, 4, &remainder);
    try testing.expectEqual(@as(i32, 5), quotient2);
    try testing.expectEqual(@as(i32, 0), remainder);
}
// ANCHOR_END: test_divide_remainder

// ANCHOR: test_distance
test "distance calculation" {
    const dist = calculateDistance(0, 0, 3, 4);
    try testing.expectApproxEqAbs(@as(f64, 5.0), dist, 0.001);
    try testing.expectApproxEqAbs(@as(f64, 5.0), getLastCalculation(), 0.001);

    const dist2 = calculateDistance(1, 1, 4, 5);
    try testing.expectApproxEqAbs(@as(f64, 5.0), dist2, 0.001);
}
// ANCHOR_END: test_distance

// ANCHOR: test_points
test "point operations" {
    const p1 = createPoint(0, 0);
    const p2 = createPoint(3, 4);

    try testing.expectEqual(@as(f64, 0), getPointX(p1));
    try testing.expectEqual(@as(f64, 0), getPointY(p1));
    try testing.expectEqual(@as(f64, 3), getPointX(p2));
    try testing.expectEqual(@as(f64, 4), getPointY(p2));

    const dist = pointDistance(p1, p2);
    try testing.expectApproxEqAbs(@as(f64, 5.0), dist, 0.001);
}
// ANCHOR_END: test_points

// ANCHOR: test_range
test "range check" {
    try testing.expect(isInRange(5, 0, 10));
    try testing.expect(isInRange(0, 0, 10));
    try testing.expect(isInRange(10, 0, 10));
    try testing.expect(!isInRange(-1, 0, 10));
    try testing.expect(!isInRange(11, 0, 10));
}
// ANCHOR_END: test_range

// ANCHOR: test_clamp
test "clamp function" {
    try testing.expectEqual(@as(f64, 5), clamp(5, 0, 10));
    try testing.expectEqual(@as(f64, 0), clamp(-5, 0, 10));
    try testing.expectEqual(@as(f64, 10), clamp(15, 0, 10));
    try testing.expectEqual(@as(f64, 7.5), clamp(7.5, 0, 10));
}
// ANCHOR_END: test_clamp

// ANCHOR: test_factorial
test "factorial" {
    try testing.expectEqual(@as(i32, 1), factorial(0));
    try testing.expectEqual(@as(i32, 1), factorial(1));
    try testing.expectEqual(@as(i32, 2), factorial(2));
    try testing.expectEqual(@as(i32, 6), factorial(3));
    try testing.expectEqual(@as(i32, 24), factorial(4));
    try testing.expectEqual(@as(i32, 120), factorial(5));
    try testing.expectEqual(@as(i32, 0), factorial(-1));
}
// ANCHOR_END: test_factorial
