const std = @import("std");
const testing = std.testing;

//ANCHOR: c_library_import
// Import C standard library functions
const c = @cImport({
    @cInclude("stdlib.h");
    @cInclude("string.h");
    @cInclude("math.h");
    @cInclude("stdio.h");
});
// ANCHOR_END: c_library_import

// ANCHOR: basic_wrapper
// Wrapper for C malloc/free with Zig types
pub const CMemory = struct {
    pub fn alloc(size: usize) ?[*]u8 {
        const ptr = c.malloc(size);
        return @ptrCast(ptr);
    }

    pub fn free(ptr: ?[*]u8) void {
        c.free(ptr);
    }

    pub fn realloc(ptr: ?[*]u8, new_size: usize) ?[*]u8 {
        const new_ptr = c.realloc(ptr, new_size);
        return @ptrCast(new_ptr);
    }
};

test "wrapping C memory functions" {
    const ptr = CMemory.alloc(100);
    try testing.expect(ptr != null);

    if (ptr) |p| {
        p[0] = 42;
        try testing.expectEqual(@as(u8, 42), p[0]);

        const new_ptr = CMemory.realloc(p, 200);
        try testing.expect(new_ptr != null);

        if (new_ptr) |np| {
            try testing.expectEqual(@as(u8, 42), np[0]);
            CMemory.free(np);
        }
    }
}
// ANCHOR_END: basic_wrapper

// ANCHOR: error_handling_wrapper
// Wrap C functions with Zig error handling
pub const MathError = error{
    InvalidInput,
    DomainError,
    RangeError,
};

pub const SafeMath = struct {
    pub fn sqrt(x: f64) MathError!f64 {
        if (x < 0) return error.DomainError;
        return c.sqrt(x);
    }

    pub fn log(x: f64) MathError!f64 {
        if (x <= 0) return error.DomainError;
        return c.log(x);
    }

    pub fn pow(base: f64, exp: f64) MathError!f64 {
        const result = c.pow(base, exp);
        if (std.math.isNan(result)) return error.DomainError;
        if (std.math.isInf(result)) return error.RangeError;
        return result;
    }
};

test "error handling wrapper" {
    const result1 = try SafeMath.sqrt(16.0);
    try testing.expectApproxEqAbs(4.0, result1, 0.001);

    const result2 = SafeMath.sqrt(-1.0);
    try testing.expectError(error.DomainError, result2);

    const result3 = try SafeMath.log(std.math.e);
    try testing.expectApproxEqAbs(1.0, result3, 0.001);
}
// ANCHOR_END: error_handling_wrapper

// ANCHOR: string_wrapper
// Wrap C string functions with Zig slices
pub const CString = struct {
    pub fn length(str: [*:0]const u8) usize {
        return c.strlen(str);
    }

    pub fn compare(s1: [*:0]const u8, s2: [*:0]const u8) i32 {
        return c.strcmp(s1, s2);
    }

    pub fn copy(dest: [*]u8, src: [*:0]const u8, max_len: usize) [*]u8 {
        _ = c.strncpy(dest, src, max_len);
        return dest;
    }

    pub fn duplicate(allocator: std.mem.Allocator, str: [*:0]const u8) ![]u8 {
        const len = length(str);
        const buf = try allocator.alloc(u8, len);
        @memcpy(buf, str[0..len]);
        return buf;
    }
};

test "C string wrapper" {
    const str1 = "hello";
    const str2 = "world";

    const len = CString.length(str1.ptr);
    try testing.expectEqual(@as(usize, 5), len);

    var buffer: [20]u8 = undefined;
    _ = CString.copy(&buffer, str1.ptr, buffer.len);

    const allocator = testing.allocator;
    const dup = try CString.duplicate(allocator, str2.ptr);
    defer allocator.free(dup);
    try testing.expect(std.mem.eql(u8, dup, "world"));
}
// ANCHOR_END: string_wrapper

// ANCHOR: resource_wrapper
// RAII-style wrapper for C resources
pub const CFile = struct {
    handle: ?*c.FILE,

    pub fn open(path: [*:0]const u8, mode: [*:0]const u8) !CFile {
        const handle = c.fopen(path, mode);
        if (handle == null) return error.OpenFailed;
        return CFile{ .handle = handle };
    }

    pub fn close(self: *CFile) void {
        if (self.handle) |h| {
            _ = c.fclose(h);
            self.handle = null;
        }
    }

    pub fn write(self: *CFile, data: []const u8) !usize {
        const h = self.handle orelse return error.FileClosed;
        const written = c.fwrite(data.ptr, 1, data.len, h);
        if (written < data.len) return error.WriteFailed;
        return written;
    }

    pub fn read(self: *CFile, buffer: []u8) !usize {
        const h = self.handle orelse return error.FileClosed;
        const bytes_read = c.fread(buffer.ptr, 1, buffer.len, h);
        return bytes_read;
    }
};

test "RAII C file wrapper" {
    // Test file operations (in-memory for testing)
    const filename = "/tmp/test_zig_c_wrapper.txt";
    var file = try CFile.open(filename, "w");
    defer file.close();

    const data = "Hello from Zig!";
    _ = try file.write(data);
}
// ANCHOR_END: resource_wrapper

// ANCHOR: type_safe_wrapper
// Type-safe wrapper for C functions
pub const Allocator = struct {
    pub fn create(comptime T: type) !*T {
        const ptr = c.malloc(@sizeOf(T));
        if (ptr == null) return error.OutOfMemory;
        return @ptrCast(@alignCast(ptr.?));
    }

    pub fn destroy(comptime T: type, ptr: *T) void {
        c.free(ptr);
    }

    pub fn createArray(comptime T: type, count: usize) ![]T {
        const ptr = c.malloc(@sizeOf(T) * count);
        if (ptr == null) return error.OutOfMemory;
        const typed_ptr: [*]T = @ptrCast(@alignCast(ptr.?));
        return typed_ptr[0..count];
    }

    pub fn destroyArray(comptime T: type, slice: []T) void {
        c.free(slice.ptr);
    }
};

test "type-safe allocator wrapper" {
    const Point = struct { x: i32, y: i32 };

    const point = try Allocator.create(Point);
    point.* = .{ .x = 10, .y = 20 };
    try testing.expectEqual(@as(i32, 10), point.x);
    Allocator.destroy(Point, point);

    const points = try Allocator.createArray(Point, 3);
    points[0] = .{ .x = 1, .y = 2 };
    points[1] = .{ .x = 3, .y = 4 };
    points[2] = .{ .x = 5, .y = 6 };
    try testing.expectEqual(@as(i32, 3), points[1].x);
    Allocator.destroyArray(Point, points);
}
// ANCHOR_END: type_safe_wrapper

// ANCHOR: callback_wrapper
// Wrapper for C callbacks
pub const Comparator = struct {
    pub const CompareFunc = *const fn (a: ?*const anyopaque, b: ?*const anyopaque) callconv(.c) c_int;

    pub fn qsort(comptime T: type, slice: []T, compare_fn: CompareFunc) void {
        c.qsort(slice.ptr, slice.len, @sizeOf(T), compare_fn);
    }
};

fn compareInts(a: ?*const anyopaque, b: ?*const anyopaque) callconv(.c) c_int {
    const ia: *const c_int = @ptrCast(@alignCast(a.?));
    const ib: *const c_int = @ptrCast(@alignCast(b.?));
    if (ia.* < ib.*) return -1;
    if (ia.* > ib.*) return 1;
    return 0;
}

test "callback wrapper for qsort" {
    var numbers = [_]c_int{ 5, 2, 8, 1, 9, 3 };
    Comparator.qsort(c_int, &numbers, compareInts);

    try testing.expectEqual(@as(c_int, 1), numbers[0]);
    try testing.expectEqual(@as(c_int, 2), numbers[1]);
    try testing.expectEqual(@as(c_int, 3), numbers[2]);
    try testing.expectEqual(@as(c_int, 5), numbers[3]);
    try testing.expectEqual(@as(c_int, 8), numbers[4]);
    try testing.expectEqual(@as(c_int, 9), numbers[5]);
}
// ANCHOR_END: callback_wrapper

// ANCHOR: const_wrapper
// Wrapper that enforces const correctness
pub const ConstString = struct {
    pub fn find(haystack: []const u8, needle: []const u8) ?usize {
        if (haystack.len == 0 or needle.len == 0) return null;

        const result = c.strstr(haystack.ptr, needle.ptr);
        if (result == null) return null;

        const ptr_val: usize = @intFromPtr(result);
        const base_val: usize = @intFromPtr(haystack.ptr);
        return ptr_val - base_val;
    }

    pub fn findChar(str: []const u8, ch: u8) ?usize {
        const result = c.strchr(str.ptr, ch);
        if (result == null) return null;

        const ptr_val: usize = @intFromPtr(result);
        const base_val: usize = @intFromPtr(str.ptr);
        return ptr_val - base_val;
    }
};

test "const-correct string wrapper" {
    const text = "Hello, World!";

    const pos1 = ConstString.find(text, "World");
    try testing.expectEqual(@as(?usize, 7), pos1);

    const pos2 = ConstString.find(text, "Zig");
    try testing.expectEqual(@as(?usize, null), pos2);

    const pos3 = ConstString.findChar(text, 'W');
    try testing.expectEqual(@as(?usize, 7), pos3);
}
// ANCHOR_END: const_wrapper
