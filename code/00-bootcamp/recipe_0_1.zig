// Recipe 0.1: Understanding Zig's Philosophy
// Target Zig Version: 0.15.2
//
// This recipe demonstrates the core principles that make Zig different from
// other languages. These examples show why Zig makes the choices it does.

const std = @import("std");
const testing = std.testing;

// ANCHOR: no_hidden_allocation
// Principle 1: No Hidden Memory Allocations
//
// In Python/JavaScript/Go, this is invisible:
//   numbers = [1, 2, 3]  # Where does the memory come from?
//   numbers.append(4)     # What happens here?
//
// In Zig, you must be explicit about where memory comes from:

test "explicit memory allocation" {
    // You must provide an allocator - no magic memory
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            @panic("Memory leak detected!");
        }
    }

    const allocator = gpa.allocator();

    // Create a dynamic list - you see exactly where memory comes from
    var numbers = std.ArrayList(i32){};
    defer numbers.deinit(allocator); // You control when it's freed

    try numbers.append(allocator, 1);
    try numbers.append(allocator, 2);
    try numbers.append(allocator, 3);

    try testing.expectEqual(@as(usize, 3), numbers.items.len);
}

test "stack vs heap allocation" {
    // Fixed-size array on the stack - no allocator needed
    const stack_array = [3]i32{ 1, 2, 3 };
    // You can see it's fixed size just by looking at the type: [3]i32

    // For variable-size data, you must use an allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            @panic("Memory leak detected!");
        }
    }

    const allocator = gpa.allocator();
    const heap_array = try allocator.alloc(i32, 3);
    defer allocator.free(heap_array);

    heap_array[0] = 1;
    heap_array[1] = 2;
    heap_array[2] = 3;

    try testing.expectEqual(stack_array[0], heap_array[0]);
}
// ANCHOR_END: no_hidden_allocation

// ANCHOR: no_hidden_control_flow
// Principle 2: No Hidden Control Flow
//
// In Python/Java/C++, exceptions can jump anywhere:
//   result = parseNumber("abc")  # Might throw! You can't tell by looking
//   processResult(result)        # This might never run
//
// In Zig, errors are values and control flow is explicit:

fn parseNumber(text: []const u8) !i32 {
    // The ! in the return type tells you this can fail
    return std.fmt.parseInt(i32, text, 10);
}

test "explicit error handling" {
    // Success case - you see the error handling
    const good = try parseNumber("42");
    try testing.expectEqual(@as(i32, 42), good);

    // Error case - no hidden throws, errors are values
    const bad = parseNumber("not a number");
    try testing.expectError(error.InvalidCharacter, bad);
}

test "no operator overloading" {
    // In C++, + might do anything (operator overloading)
    // In Zig, + always means numeric addition

    const a: i32 = 5;
    const b: i32 = 10;
    const sum = a + b; // Always addition, never hidden function calls

    try testing.expectEqual(@as(i32, 15), sum);

    // For complex operations, use explicit functions
    // This makes the cost visible:
    // const result = bigNumber.add(otherBigNumber);  // You see it's a call
}
// ANCHOR_END: no_hidden_control_flow

// ANCHOR: edge_cases_matter
// Principle 3: Edge Cases Matter
//
// In many languages, edge cases cause crashes:
//   int[] array = new int[size];  // What if size is negative? Crash!
//   int x = a + b;                 // What if it overflows? Undefined!
//   Object obj = map.get(key);     // What if key doesn't exist? Null!
//
// Zig forces you to handle edge cases explicitly:

test "out of memory is an error, not a crash" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            @panic("Memory leak detected!");
        }
    }

    const allocator = gpa.allocator();

    // Allocation can fail - the ! forces you to handle it
    const array = allocator.alloc(i32, 100) catch {
        // Handle OOM explicitly
        return error.SkipZigTest; // In real code, you'd handle this
    };
    defer allocator.free(array);

    try testing.expect(array.len == 100);
}

test "integer overflow is checked in debug mode" {
    // In debug mode, overflow causes a panic (fail-fast)
    // In release mode, you choose: wrapping, saturating, or checked

    const a: i8 = 127; // Max for i8

    // This would panic in debug mode:
    // const overflow = a + 1;  // Overflow detected!

    // Make overflow behavior explicit:
    const wrapped = a +% 1; // Wrapping: 127 + 1 = -128

    // For saturating, use a conditional or saturating arithmetic
    const saturated: i8 = if (a == 127) 127 else a + 1;

    try testing.expectEqual(@as(i8, -128), wrapped);
    try testing.expectEqual(@as(i8, 127), saturated);
}

test "optionals handle absence explicitly" {
    // In Java/C++, null can cause crashes anywhere
    // In Zig, you must opt-in to nullable values with ?T

    const numbers = [_]i32{ 1, 2, 3, 4, 5 };

    // Search returns an optional - might not find it
    const found: ?i32 = for (numbers) |n| {
        if (n == 3) break n;
    } else null;

    // You must handle the null case explicitly
    const result = found orelse 0; // Provide default
    try testing.expectEqual(@as(i32, 3), result);

    const not_found: ?i32 = for (numbers) |n| {
        if (n == 99) break n;
    } else null;

    try testing.expectEqual(@as(?i32, null), not_found);
}
// ANCHOR_END: edge_cases_matter

// ANCHOR: comptime_execution
test "comptime: compilation is code execution" {
    // Principle 4: Comptime Philosophy
    //
    // Zig blurs the line between compile-time and runtime
    // Code that can run at compile-time will run at compile-time
    // This gives you metaprogramming without a separate macro language

    // This runs at compile time - zero runtime cost
    const array_size = comptime blk: {
        var size: u32 = 0;
        var i: u32 = 1;
        while (i <= 10) : (i += 1) {
            size += i;
        }
        break :blk size;
    };

    // array_size is computed at compile time
    try testing.expectEqual(@as(u32, 55), array_size);

    // You can create types at compile time
    const IntArray = [array_size]i32;
    const arr: IntArray = undefined;
    try testing.expectEqual(@as(usize, 55), arr.len);
}
// ANCHOR_END: comptime_execution

// Summary:
// 1. No hidden allocations - you see where memory comes from
// 2. No hidden control flow - no exceptions, no operator overloading
// 3. Edge cases matter - OOM, overflow, null are explicit
// 4. Comptime - compile-time execution for zero-cost abstractions
//
// This philosophy means more typing upfront, but:
// - No surprises in production
// - Performance is predictable
// - Bugs are found at compile time, not 3am in production
