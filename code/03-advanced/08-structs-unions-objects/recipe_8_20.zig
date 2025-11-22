// Recipe 8.20: Implementing the Visitor Pattern
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_visitor
// Basic visitor pattern using tagged unions
const Circle = struct { radius: f32 };
const Rectangle = struct { width: f32, height: f32 };
const Triangle = struct { base: f32, height: f32 };

const Shape = union(enum) {
    circle: Circle,
    rectangle: Rectangle,
    triangle: Triangle,

    pub fn accept(self: *const Shape, visitor: anytype) @TypeOf(visitor).ResultType {
        return switch (self.*) {
            .circle => |c| visitor.visitCircle(c),
            .rectangle => |r| visitor.visitRectangle(r),
            .triangle => |t| visitor.visitTriangle(t),
        };
    }
};

const AreaVisitor = struct {
    pub const ResultType = f32;

    pub fn visitCircle(self: AreaVisitor, circle: Circle) f32 {
        _ = self;
        return std.math.pi * circle.radius * circle.radius;
    }

    pub fn visitRectangle(self: AreaVisitor, rectangle: Rectangle) f32 {
        _ = self;
        return rectangle.width * rectangle.height;
    }

    pub fn visitTriangle(self: AreaVisitor, triangle: Triangle) f32 {
        _ = self;
        return triangle.base * triangle.height / 2.0;
    }
};

test "basic visitor" {
    const circle = Shape{ .circle = .{ .radius = 5 } };
    const rectangle = Shape{ .rectangle = .{ .width = 4, .height = 6 } };

    const visitor = AreaVisitor{};

    const circle_area = circle.accept(visitor);
    try testing.expectApproxEqAbs(@as(f32, 78.539), circle_area, 0.01);

    const rect_area = rectangle.accept(visitor);
    try testing.expectEqual(@as(f32, 24), rect_area);
}
// ANCHOR_END: basic_visitor

// ANCHOR: visitor_with_context
// Visitor with context/state
const PrintVisitor = struct {
    buffer: *std.ArrayList(u8),
    allocator: std.mem.Allocator,

    pub const ResultType = void;

    pub fn visitCircle(self: PrintVisitor, circle: Circle) void {
        const msg = std.fmt.allocPrint(self.allocator, "Circle(r={d})", .{circle.radius}) catch return;
        defer self.allocator.free(msg);
        self.buffer.appendSlice(self.allocator, msg) catch return;
    }

    pub fn visitRectangle(self: PrintVisitor, rectangle: Rectangle) void {
        const msg = std.fmt.allocPrint(self.allocator, "Rectangle(w={d},h={d})", .{ rectangle.width, rectangle.height }) catch return;
        defer self.allocator.free(msg);
        self.buffer.appendSlice(self.allocator, msg) catch return;
    }

    pub fn visitTriangle(self: PrintVisitor, triangle: Triangle) void {
        const msg = std.fmt.allocPrint(self.allocator, "Triangle(b={d},h={d})", .{ triangle.base, triangle.height }) catch return;
        defer self.allocator.free(msg);
        self.buffer.appendSlice(self.allocator, msg) catch return;
    }
};

test "visitor with context" {
    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(testing.allocator);

    const visitor = PrintVisitor{
        .buffer = &buffer,
        .allocator = testing.allocator,
    };

    const circle = Shape{ .circle = .{ .radius = 3 } };
    circle.accept(visitor);

    try testing.expect(std.mem.indexOf(u8, buffer.items, "Circle") != null);
}
// ANCHOR_END: visitor_with_context

// ANCHOR: expression_visitor
// Expression visitor (AST traversal)
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

test "expression visitor" {
    const five = Expr{ .number = 5 };
    const three = Expr{ .number = 3 };
    const add = Expr{ .add = .{ .left = @constCast(&five), .right = @constCast(&three) } };

    const visitor = EvalVisitor{};
    const result = add.accept(visitor);
    try testing.expectEqual(@as(i32, 8), result);
}
// ANCHOR_END: expression_visitor

// ANCHOR: collecting_visitor
// Visitor that collects results
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

    pub fn visitNeg(self: *NodeVisitor, expr: *Expr) void {
        self.count += 1;
        expr.accept(self);
    }
};

test "collecting visitor" {
    const five = Expr{ .number = 5 };
    const three = Expr{ .number = 3 };
    const add = Expr{ .add = .{ .left = @constCast(&five), .right = @constCast(&three) } };

    var visitor = NodeVisitor{ .count = 0 };
    add.accept(&visitor);

    try testing.expectEqual(@as(u32, 3), visitor.count); // add + 5 + 3
}
// ANCHOR_END: collecting_visitor

// ANCHOR: transforming_visitor
// Visitor that transforms the structure
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

    pub fn visitMul(self: *StringifyVisitor, left: *Expr, right: *Expr) void {
        self.buffer.append(self.allocator, '(') catch return;
        left.accept(self);
        self.buffer.appendSlice(self.allocator, " * ") catch return;
        right.accept(self);
        self.buffer.append(self.allocator, ')') catch return;
    }

    pub fn visitNeg(self: *StringifyVisitor, expr: *Expr) void {
        self.buffer.appendSlice(self.allocator, "-(") catch return;
        expr.accept(self);
        self.buffer.append(self.allocator, ')') catch return;
    }
};

test "transforming visitor" {
    const five = Expr{ .number = 5 };
    const three = Expr{ .number = 3 };
    const add = Expr{ .add = .{ .left = @constCast(&five), .right = @constCast(&three) } };

    var buffer = std.ArrayList(u8){};
    defer buffer.deinit(testing.allocator);

    var visitor = StringifyVisitor{
        .buffer = &buffer,
        .allocator = testing.allocator,
    };

    add.accept(&visitor);
    try testing.expectEqualStrings("(5 + 3)", buffer.items);
}
// ANCHOR_END: transforming_visitor

// ANCHOR: fallible_visitor
// Visitor with error handling
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

    pub fn visitTriangle(_: ValidationVisitor, triangle: Triangle) !bool {
        if (triangle.base <= 0 or triangle.height <= 0) {
            return error.InvalidDimensions;
        }
        return true;
    }
};

test "fallible visitor" {
    const valid_circle = Shape{ .circle = .{ .radius = 5 } };
    const invalid_circle = Shape{ .circle = .{ .radius = -1 } };

    const visitor = ValidationVisitor{};

    const valid = try valid_circle.accept(visitor);
    try testing.expect(valid);

    const result = invalid_circle.accept(visitor);
    try testing.expectError(error.InvalidRadius, result);
}
// ANCHOR_END: fallible_visitor

// ANCHOR: generic_visitor
// Generic visitor using comptime
fn Visitor(comptime T: type) type {
    return struct {
        pub const ResultType = T;

        visitFn: *const fn (item: anytype) T,

        pub fn visit(self: @This(), item: anytype) T {
            return self.visitFn(item);
        }
    };
}

test "generic visitor" {
    const IntVisitor = Visitor(i32);

    const visitor = IntVisitor{
        .visitFn = struct {
            fn visit(item: anytype) i32 {
                return item;
            }
        }.visit,
    };

    const result = visitor.visit(42);
    try testing.expectEqual(@as(i32, 42), result);
}
// ANCHOR_END: generic_visitor

// ANCHOR: multi_visitor
// Multiple visitor dispatch
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

test "multi visitor" {
    const file1 = FileNode{ .file = .{ .name = "a.txt", .size = 100 } };
    const file2 = FileNode{ .file = .{ .name = "b.txt", .size = 200 } };
    const children = [_]FileNode{ file1, file2 };
    const dir = FileNode{ .directory = .{ .name = "docs", .children = children[0..] } };

    const visitor = SizeVisitor{};
    const total = dir.accept(visitor);
    try testing.expectEqual(@as(u64, 300), total);
}
// ANCHOR_END: multi_visitor

// ANCHOR: stateful_visitor
// Stateful visitor that maintains state across visits
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

test "stateful visitor" {
    const file1 = FileNode{ .file = .{ .name = "a.txt", .size = 100 } };
    const file2 = FileNode{ .file = .{ .name = "b.txt", .size = 200 } };
    const children = [_]FileNode{ file1, file2 };
    const dir = FileNode{ .directory = .{ .name = "docs", .children = children[0..] } };

    var visitor = DepthVisitor{ .depth = 0, .max_depth = 0 };
    dir.accept(&visitor);

    try testing.expectEqual(@as(u32, 1), visitor.max_depth);
}
// ANCHOR_END: stateful_visitor

// ANCHOR: filter_visitor
// Visitor with filtering
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

test "filter visitor" {
    const file1 = FileNode{ .file = .{ .name = "a.txt", .size = 100 } };
    const file2 = FileNode{ .file = .{ .name = "b.md", .size = 200 } };
    const file3 = FileNode{ .file = .{ .name = "c.txt", .size = 150 } };
    const children = [_]FileNode{ file1, file2, file3 };
    const dir = FileNode{ .directory = .{ .name = "docs", .children = children[0..] } };

    var matches = std.ArrayList([]const u8){};
    defer matches.deinit(testing.allocator);

    var visitor = FilterVisitor{
        .matches = &matches,
        .allocator = testing.allocator,
        .extension = ".txt",
    };

    dir.accept(&visitor);
    try testing.expectEqual(@as(usize, 2), matches.items.len);
}
// ANCHOR_END: filter_visitor

// Comprehensive test
test "comprehensive visitor patterns" {
    // Basic visitor
    const circle = Shape{ .circle = .{ .radius = 2 } };
    const area_visitor = AreaVisitor{};
    const area = circle.accept(area_visitor);
    try testing.expect(area > 12 and area < 13);

    // Expression visitor
    const num = Expr{ .number = 10 };
    const eval_visitor = EvalVisitor{};
    const value = num.accept(eval_visitor);
    try testing.expectEqual(@as(i32, 10), value);

    // Validation visitor
    const valid_rect = Shape{ .rectangle = .{ .width = 5, .height = 3 } };
    const validation_visitor = ValidationVisitor{};
    const is_valid = try valid_rect.accept(validation_visitor);
    try testing.expect(is_valid);

    // File tree visitor
    const file = FileNode{ .file = .{ .name = "test.txt", .size = 500 } };
    const size_visitor = SizeVisitor{};
    const size = file.accept(size_visitor);
    try testing.expectEqual(@as(u64, 500), size);
}
