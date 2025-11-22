## Problem

You want to create a version of a function with some arguments pre-filled, similar to Python's `functools.partial`.

## Solution

Use structs to capture pre-filled arguments:

```zig
{{#include ../../../code/03-advanced/07-functions/recipe_7_8.zig:basic_partial}}
```

## Discussion

### Generic Partial Application

Create a generic partial applicator:

```zig
pub fn Partial2(
    comptime Func: type,
    comptime arg1_val: anytype,
) type {
    return struct {
        pub fn call(arg2: anytype) @TypeOf(Func(arg1_val, arg2)) {
            return Func(arg1_val, arg2);
        }
    };
}

fn add(a: i32, b: i32) i32 {
    return a + b;
}

fn multiply(a: i32, b: i32) i32 {
    return a * b;
}

test "generic partial" {
    const add5 = Partial2(@TypeOf(add), 5);
    const times10 = Partial2(@TypeOf(multiply), 10);

    try std.testing.expectEqual(@as(i32, 15), add5.call(10));
    try std.testing.expectEqual(@as(i32, 50), times10.call(5));
}
```

### Runtime Partial Application

Capture arguments at runtime:

```zig
pub fn PartialAdd(comptime T: type) type {
    return struct {
        value: T,

        pub fn init(value: T) @This() {
            return .{ .value = value };
        }

        pub fn call(self: @This(), other: T) T {
            return self.value + other;
        }
    };
}

test "runtime partial" {
    const add5 = PartialAdd(i32).init(5);
    const add10 = PartialAdd(i32).init(10);

    try std.testing.expectEqual(@as(i32, 15), add5.call(10));
    try std.testing.expectEqual(@as(i32, 25), add10.call(15));
}
```

### Currying Pattern

Transform multi-argument function into nested single-argument functions:

```zig
pub fn curry3(
    comptime F: type,
) type {
    return struct {
        pub fn call(a: anytype) type {
            return struct {
                pub fn call2(b: anytype) type {
                    return struct {
                        pub fn call3(c: anytype) @TypeOf(F(a, b, c)) {
                            return F(a, b, c);
                        }
                    };
                }
            };
        }
    };
}

fn add3(a: i32, b: i32, c: i32) i32 {
    return a + b + c;
}

test "currying" {
    const curried = curry3(@TypeOf(add3));

    const step1 = curried.call(1);
    const step2 = step1.call2(2);
    const result = step2.call3(3);

    try std.testing.expectEqual(@as(i32, 6), result);
}
```

### Partial with String Formatting

Pre-fill format strings:

```zig
pub fn PartialFormat(comptime fmt: []const u8) type {
    return struct {
        pub fn call(
            allocator: std.mem.Allocator,
            args: anytype,
        ) ![]u8 {
            return try std.fmt.allocPrint(allocator, fmt, args);
        }
    };
}

test "partial format" {
    const allocator = std.testing.allocator;

    const format_name = PartialFormat("Hello, {s}!");
    const result = try format_name.call(allocator, .{"World"});
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello, World!", result);
}
```

### Partial Application for Comparison

Pre-fill comparison thresholds:

```zig
pub fn GreaterThan(comptime T: type) type {
    return struct {
        threshold: T,

        pub fn init(threshold: T) @This() {
            return .{ .threshold = threshold };
        }

        pub fn check(self: @This(), value: T) bool {
            return value > self.threshold;
        }
    };
}

pub fn filter(
    allocator: std.mem.Allocator,
    items: []const i32,
    predicate: anytype,
) ![]i32 {
    var result = std.ArrayList(i32){};
    errdefer result.deinit(allocator);

    for (items) |item| {
        if (predicate.check(item)) {
            try result.append(allocator, item);
        }
    }

    return try result.toOwnedSlice(allocator);
}

test "partial comparison" {
    const allocator = std.testing.allocator;
    const numbers = [_]i32{ 1, 5, 10, 15, 20 };

    const gt10 = GreaterThan(i32).init(10);
    const filtered = try filter(allocator, &numbers, gt10);
    defer allocator.free(filtered);

    try std.testing.expectEqual(@as(usize, 2), filtered.len);
    try std.testing.expectEqual(@as(i32, 15), filtered[0]);
}
```

### Partial with Error Handling

Pre-fill error handling strategy:

```zig
pub fn PartialTry(comptime ErrorSet: type, comptime T: type) type {
    return struct {
        fallback: T,

        pub fn init(fallback: T) @This() {
            return .{ .fallback = fallback };
        }

        pub fn call(self: @This(), result: ErrorSet!T) T {
            return result catch self.fallback;
        }
    };
}

fn mayFail(value: i32) !i32 {
    if (value < 0) return error.Negative;
    return value * 2;
}

test "partial error handling" {
    const safe_double = PartialTry(error{Negative}, i32).init(0);

    try std.testing.expectEqual(@as(i32, 10), safe_double.call(mayFail(5)));
    try std.testing.expectEqual(@as(i32, 0), safe_double.call(mayFail(-5)));
}
```

### Bind First Arguments

Bind multiple leading arguments:

```zig
pub fn BindFirst2(comptime T1: type, comptime T2: type) type {
    return struct {
        arg1: T1,
        arg2: T2,

        pub fn init(arg1: T1, arg2: T2) @This() {
            return .{ .arg1 = arg1, .arg2 = arg2 };
        }

        pub fn call(
            self: @This(),
            func: anytype,
            arg3: anytype,
        ) @TypeOf(func(self.arg1, self.arg2, arg3)) {
            return func(self.arg1, self.arg2, arg3);
        }
    };
}

fn format3(prefix: []const u8, middle: []const u8, suffix: []const u8) []const u8 {
    _ = prefix;
    _ = middle;
    return suffix; // Simplified
}

test "bind first arguments" {
    const bound = BindFirst2([]const u8, []const u8).init("Hello", "beautiful");

    const result = bound.call(format3, "World");
    try std.testing.expectEqualStrings("World", result);
}
```

### Partial Application Builder

Chain partial applications:

```zig
pub fn FunctionBuilder(comptime Ret: type) type {
    return struct {
        const Self = @This();

        pub fn arg(comptime T: type, value: T) type {
            return struct {
                captured: T,

                pub fn init() @This() {
                    return .{ .captured = value };
                }

                pub fn apply(self: @This(), func: fn (T) Ret) Ret {
                    return func(self.captured);
                }
            };
        }
    };
}

test "function builder" {
    const double = struct {
        fn f(x: i32) i32 {
            return x * 2;
        }
    }.f;

    const Builder = FunctionBuilder(i32);
    const partial = Builder.arg(i32, 5).init();

    try std.testing.expectEqual(@as(i32, 10), partial.apply(double));
}
```

### Method Partial Application

Bind object methods:

```zig
pub fn Calculator() type {
    return struct {
        base: i32,

        const Self = @This();

        pub fn init(base: i32) Self {
            return .{ .base = base };
        }

        pub fn add(self: Self, value: i32) i32 {
            return self.base + value;
        }

        pub fn multiply(self: Self, value: i32) i32 {
            return self.base * value;
        }

        pub fn partialAdd(self: Self) type {
            return struct {
                calc: Self,

                pub fn init() @This() {
                    return .{ .calc = self };
                }

                pub fn call(this: @This(), value: i32) i32 {
                    return this.calc.add(value);
                }
            };
        }
    };
}

test "method partial" {
    const calc = Calculator().init(10);

    const AddTo10 = calc.partialAdd().init();
    try std.testing.expectEqual(@as(i32, 15), AddTo10.call(5));
}
```

### Reverse Partial Application

Bind last argument instead of first:

```zig
pub fn PartialLast(comptime T: type) type {
    return struct {
        last_arg: T,

        pub fn init(last_arg: T) @This() {
            return .{ .last_arg = last_arg };
        }

        pub fn call(
            self: @This(),
            func: anytype,
            first_arg: anytype,
        ) @TypeOf(func(first_arg, self.last_arg)) {
            return func(first_arg, self.last_arg);
        }
    };
}

fn subtract(a: i32, b: i32) i32 {
    return a - b;
}

test "reverse partial" {
    const subtract5 = PartialLast(i32).init(5);

    try std.testing.expectEqual(@as(i32, 5), subtract5.call(subtract, 10));
    try std.testing.expectEqual(@as(i32, 15), subtract5.call(subtract, 20));
}
```

### Partial with Allocator

Pre-fill allocator for functions:

```zig
pub fn WithAllocator(allocator: std.mem.Allocator) type {
    return struct {
        pub fn duplicate(text: []const u8) ![]u8 {
            return try allocator.dupe(u8, text);
        }

        pub fn format(comptime fmt: []const u8, args: anytype) ![]u8 {
            return try std.fmt.allocPrint(allocator, fmt, args);
        }
    };
}

test "partial allocator" {
    const allocator = std.testing.allocator;
    const Mem = WithAllocator(allocator);

    const dup = try Mem.duplicate("hello");
    defer allocator.free(dup);
    try std.testing.expectEqualStrings("hello", dup);

    const formatted = try Mem.format("Value: {}", .{42});
    defer allocator.free(formatted);
    try std.testing.expectEqualStrings("Value: 42", formatted);
}
```

### Partial Application Combinator

Combine multiple partial applications:

```zig
pub fn Compose(comptime F: type, comptime G: type) type {
    return struct {
        pub fn call(x: anytype) @TypeOf(F(G(x))) {
            return F(G(x));
        }
    };
}

fn double(x: i32) i32 {
    return x * 2;
}

fn addTen(x: i32) i32 {
    return x + 10;
}

test "composition" {
    const doubleAndAdd = Compose(@TypeOf(addTen), @TypeOf(double));

    // (5 * 2) + 10 = 20
    try std.testing.expectEqual(@as(i32, 20), doubleAndAdd.call(5));
}
```

### Best Practices

**Choosing Between Comptime and Runtime:**
```zig
// Good: Comptime when values known at compile time
pub fn makeAdder(comptime n: i32) type {
    return struct {
        pub fn call(x: i32) i32 {
            return x + n;
        }
    };
}

// Good: Runtime when values known only at runtime
pub fn Adder() type {
    return struct {
        n: i32,

        pub fn init(n: i32) @This() {
            return .{ .n = n };
        }

        pub fn call(self: @This(), x: i32) i32 {
            return x + self.n;
        }
    };
}
```

**Type Safety:**
- Use comptime parameters for maximum type safety
- Leverage Zig's type system to catch errors early
- Document expected function signatures

**Performance:**
- Comptime partial application has zero runtime overhead
- Runtime partial application is just struct field access
- No hidden allocations or indirection

**API Design:**
```zig
// Good: Clear, self-documenting
const add5 = PartialAdd(i32).init(5);
result = add5.call(10);

// Less clear: Generic but harder to understand
const partial = Partial(add, 5);
result = partial.call(10);
```

### Related Functions

- `comptime` for compile-time partial application
- `@TypeOf()` for type inference
- Function pointers for flexible partial application
- Struct initialization for capturing arguments
- `anytype` for generic partial application
