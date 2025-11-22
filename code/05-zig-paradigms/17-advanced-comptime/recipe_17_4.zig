// Recipe 17.4: Generic Data Structure Generation
// This recipe demonstrates how to build type-safe container types that adapt
// to payload types at compile time, creating zero-overhead generic data structures.

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

// ANCHOR: basic_generic_list
/// Simple generic dynamic array
fn List(comptime T: type) type {
    return struct {
        items: []T,
        capacity: usize,
        allocator: Allocator,

        const Self = @This();

        pub fn init(allocator: Allocator) Self {
            return .{
                .items = &[_]T{},
                .capacity = 0,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            if (self.capacity > 0) {
                self.allocator.free(self.items.ptr[0..self.capacity]);
            }
        }

        pub fn append(self: *Self, item: T) !void {
            if (self.items.len >= self.capacity) {
                try self.grow();
            }
            self.items.ptr[self.items.len] = item;
            self.items.len += 1;
        }

        fn grow(self: *Self) !void {
            const new_capacity = if (self.capacity == 0) 4 else self.capacity * 2;
            const new_memory = try self.allocator.alloc(T, new_capacity);

            if (self.items.len > 0) {
                @memcpy(new_memory[0..self.items.len], self.items);
            }

            if (self.capacity > 0) {
                self.allocator.free(self.items.ptr[0..self.capacity]);
            }

            self.items = new_memory[0..self.items.len];
            self.capacity = new_capacity;
        }
    };
}

test "basic generic list" {
    var int_list = List(i32).init(testing.allocator);
    defer int_list.deinit();

    try int_list.append(1);
    try int_list.append(2);
    try int_list.append(3);

    try testing.expectEqual(3, int_list.items.len);
    try testing.expectEqual(@as(i32, 1), int_list.items[0]);
    try testing.expectEqual(@as(i32, 2), int_list.items[1]);
    try testing.expectEqual(@as(i32, 3), int_list.items[2]);
}
// ANCHOR_END: basic_generic_list

// ANCHOR: type_aware_optimization
/// Generic stack with type-specific optimizations
fn Stack(comptime T: type) type {
    const is_small = @sizeOf(T) <= @sizeOf(usize);
    const inline_capacity = if (is_small) 16 else 4;

    return struct {
        items: [inline_capacity]T,
        len: usize,

        const Self = @This();

        pub fn init() Self {
            return .{
                .items = undefined,
                .len = 0,
            };
        }

        pub fn push(self: *Self, value: T) !void {
            if (self.len >= inline_capacity) {
                return error.StackFull;
            }
            self.items[self.len] = value;
            self.len += 1;
        }

        pub fn pop(self: *Self) ?T {
            if (self.len == 0) return null;
            self.len -= 1;
            return self.items[self.len];
        }

        pub fn peek(self: *const Self) ?T {
            if (self.len == 0) return null;
            return self.items[self.len - 1];
        }
    };
}

test "type-aware stack optimization" {
    var small_stack = Stack(u8).init();
    try small_stack.push(1);
    try small_stack.push(2);
    try testing.expectEqual(@as(?u8, 2), small_stack.peek());
    try testing.expectEqual(@as(?u8, 2), small_stack.pop());
    try testing.expectEqual(@as(?u8, 1), small_stack.pop());
    try testing.expectEqual(@as(?u8, null), small_stack.pop());

    var large_stack = Stack([100]u8).init();
    try large_stack.push([_]u8{0} ** 100);
    try testing.expect(large_stack.pop() != null);
}
// ANCHOR_END: type_aware_optimization

// ANCHOR: result_type
/// Generic Result type for error handling
fn Result(comptime T: type, comptime E: type) type {
    return union(enum) {
        ok: T,
        err: E,

        const Self = @This();

        pub fn isOk(self: Self) bool {
            return self == .ok;
        }

        pub fn isErr(self: Self) bool {
            return self == .err;
        }

        pub fn unwrap(self: Self) T {
            return switch (self) {
                .ok => |value| value,
                .err => @panic("Called unwrap on error value"),
            };
        }

        pub fn unwrapOr(self: Self, default: T) T {
            return switch (self) {
                .ok => |value| value,
                .err => default,
            };
        }

        pub fn unwrapErr(self: Self) E {
            return switch (self) {
                .err => |e| e,
                .ok => @panic("Called unwrapErr on ok value"),
            };
        }
    };
}

test "generic result type" {
    const IntResult = Result(i32, []const u8);

    const success = IntResult{ .ok = 42 };
    try testing.expect(success.isOk());
    try testing.expectEqual(@as(i32, 42), success.unwrap());

    const failure = IntResult{ .err = "something went wrong" };
    try testing.expect(failure.isErr());
    try testing.expectEqualStrings("something went wrong", failure.unwrapErr());
    try testing.expectEqual(@as(i32, -1), failure.unwrapOr(-1));
}
// ANCHOR_END: result_type

// ANCHOR: pair_tuple
/// Generic pair/tuple type
fn Pair(comptime A: type, comptime B: type) type {
    return struct {
        first: A,
        second: B,

        const Self = @This();

        pub fn init(a: A, b: B) Self {
            return .{ .first = a, .second = b };
        }

        pub fn swap(self: Self) Pair(B, A) {
            return .{ .first = self.second, .second = self.first };
        }
    };
}

test "generic pair" {
    const p1 = Pair(i32, []const u8).init(42, "hello");
    try testing.expectEqual(@as(i32, 42), p1.first);
    try testing.expectEqualStrings("hello", p1.second);

    const p2 = p1.swap();
    try testing.expectEqualStrings("hello", p2.first);
    try testing.expectEqual(@as(i32, 42), p2.second);
}
// ANCHOR_END: pair_tuple

// ANCHOR: optional_wrapper
/// Enhanced optional with additional methods
fn Maybe(comptime T: type) type {
    return struct {
        value: ?T,

        const Self = @This();

        pub fn some(v: T) Self {
            return .{ .value = v };
        }

        pub fn none() Self {
            return .{ .value = null };
        }

        pub fn isSome(self: Self) bool {
            return self.value != null;
        }

        pub fn isNone(self: Self) bool {
            return self.value == null;
        }

        pub fn unwrap(self: Self) T {
            return self.value orelse @panic("Called unwrap on none");
        }

        pub fn unwrapOr(self: Self, default: T) T {
            return self.value orelse default;
        }

        pub fn map(self: Self, comptime U: type, f: fn (T) U) Maybe(U) {
            if (self.value) |v| {
                return Maybe(U).some(f(v));
            }
            return Maybe(U).none();
        }
    };
}

fn double(x: i32) i32 {
    return x * 2;
}

test "enhanced optional" {
    const m1 = Maybe(i32).some(21);
    try testing.expect(m1.isSome());
    try testing.expectEqual(@as(i32, 21), m1.unwrap());

    const m2 = m1.map(i32, double);
    try testing.expectEqual(@as(i32, 42), m2.unwrap());

    const m3 = Maybe(i32).none();
    try testing.expect(m3.isNone());
    try testing.expectEqual(@as(i32, -1), m3.unwrapOr(-1));
}
// ANCHOR_END: optional_wrapper

// ANCHOR: tree_node
/// Generic binary tree node
fn TreeNode(comptime T: type) type {
    return struct {
        value: T,
        left: ?*Self,
        right: ?*Self,
        allocator: Allocator,

        const Self = @This();

        pub fn init(allocator: Allocator, value: T) !*Self {
            const node = try allocator.create(Self);
            node.* = .{
                .value = value,
                .left = null,
                .right = null,
                .allocator = allocator,
            };
            return node;
        }

        pub fn deinit(self: *Self) void {
            if (self.left) |left| {
                left.deinit();
                self.allocator.destroy(left);
            }
            if (self.right) |right| {
                right.deinit();
                self.allocator.destroy(right);
            }
        }

        pub fn insert(self: *Self, value: T) !void {
            if (value < self.value) {
                if (self.left) |left| {
                    try left.insert(value);
                } else {
                    self.left = try Self.init(self.allocator, value);
                }
            } else {
                if (self.right) |right| {
                    try right.insert(value);
                } else {
                    self.right = try Self.init(self.allocator, value);
                }
            }
        }
    };
}

test "generic tree node" {
    var root = try TreeNode(i32).init(testing.allocator, 50);
    defer {
        root.deinit();
        testing.allocator.destroy(root);
    }

    try root.insert(30);
    try root.insert(70);
    try root.insert(20);
    try root.insert(40);

    try testing.expectEqual(@as(i32, 50), root.value);
    try testing.expectEqual(@as(i32, 30), root.left.?.value);
    try testing.expectEqual(@as(i32, 70), root.right.?.value);
}
// ANCHOR_END: tree_node

// ANCHOR: circular_buffer
/// Fixed-size circular buffer
fn CircularBuffer(comptime T: type, comptime size: usize) type {
    if (size == 0) {
        @compileError("CircularBuffer size must be greater than 0");
    }

    return struct {
        buffer: [size]T,
        read_pos: usize,
        write_pos: usize,
        count: usize,

        const Self = @This();

        pub fn init() Self {
            return .{
                .buffer = undefined,
                .read_pos = 0,
                .write_pos = 0,
                .count = 0,
            };
        }

        pub fn write(self: *Self, value: T) bool {
            if (self.count >= size) {
                return false; // Buffer full
            }

            self.buffer[self.write_pos] = value;
            self.write_pos = (self.write_pos + 1) % size;
            self.count += 1;
            return true;
        }

        pub fn read(self: *Self) ?T {
            if (self.count == 0) {
                return null;
            }

            const value = self.buffer[self.read_pos];
            self.read_pos = (self.read_pos + 1) % size;
            self.count -= 1;
            return value;
        }

        pub fn isFull(self: Self) bool {
            return self.count >= size;
        }

        pub fn isEmpty(self: Self) bool {
            return self.count == 0;
        }
    };
}

test "circular buffer" {
    var buf = CircularBuffer(u32, 4).init();

    try testing.expect(buf.write(1));
    try testing.expect(buf.write(2));
    try testing.expect(buf.write(3));
    try testing.expect(buf.write(4));
    try testing.expect(buf.isFull());
    try testing.expect(!buf.write(5)); // Should fail, buffer full

    try testing.expectEqual(@as(?u32, 1), buf.read());
    try testing.expectEqual(@as(?u32, 2), buf.read());
    try testing.expect(!buf.isFull());

    try testing.expect(buf.write(5));
    try testing.expect(buf.write(6));

    try testing.expectEqual(@as(?u32, 3), buf.read());
    try testing.expectEqual(@as(?u32, 4), buf.read());
    try testing.expectEqual(@as(?u32, 5), buf.read());
    try testing.expectEqual(@as(?u32, 6), buf.read());
    try testing.expect(buf.isEmpty());
}
// ANCHOR_END: circular_buffer

// ANCHOR: tagged_union
/// Generate tagged union from type list
fn TaggedUnion(comptime types: []const type) type {
    // First create the enum tag type
    var enum_fields: [types.len]std.builtin.Type.EnumField = undefined;
    for (0..types.len) |i| {
        const name = std.fmt.comptimePrint("variant{d}", .{i});
        const name_z = name ++ "";
        enum_fields[i] = .{
            .name = name_z[0..name.len :0],
            .value = i,
        };
    }

    const TagEnum = @Type(.{
        .@"enum" = .{
            .tag_type = std.math.IntFittingRange(0, types.len - 1),
            .fields = &enum_fields,
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_exhaustive = true,
        },
    });

    // Now create the union fields
    var union_fields: [types.len]std.builtin.Type.UnionField = undefined;
    for (types, 0..) |T, i| {
        const name = std.fmt.comptimePrint("variant{d}", .{i});
        const name_z = name ++ "";
        union_fields[i] = .{
            .name = name_z[0..name.len :0],
            .type = T,
            .alignment = @alignOf(T),
        };
    }

    return @Type(.{
        .@"union" = .{
            .layout = .auto,
            .tag_type = TagEnum,
            .fields = &union_fields,
            .decls = &[_]std.builtin.Type.Declaration{},
        },
    });
}

test "tagged union generation" {
    const MyUnion = TaggedUnion(&[_]type{ i32, f64, []const u8 });

    var value: MyUnion = .{ .variant0 = 42 };
    try testing.expectEqual(@as(i32, 42), value.variant0);

    value = .{ .variant1 = 3.14 };
    try testing.expectEqual(@as(f64, 3.14), value.variant1);

    value = .{ .variant2 = "hello" };
    try testing.expectEqualStrings("hello", value.variant2);
}
// ANCHOR_END: tagged_union
