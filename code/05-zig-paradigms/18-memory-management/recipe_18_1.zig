// Recipe 18.1: Custom Allocator Implementation
// This recipe demonstrates how to build custom allocators for specific use cases,
// understand the Allocator interface, and implement different allocation strategies.

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

// ANCHOR: basic_allocator
/// Simple bump allocator that allocates from a fixed buffer
const BumpAllocator = struct {
    buffer: []u8,
    offset: usize,

    pub fn init(buffer: []u8) BumpAllocator {
        return .{
            .buffer = buffer,
            .offset = 0,
        };
    }

    pub fn allocator(self: *BumpAllocator) Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, ptr_align: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        _ = ret_addr;
        const self: *BumpAllocator = @ptrCast(@alignCast(ctx));

        const align_offset = std.mem.alignForward(usize, self.offset, ptr_align.toByteUnits());
        const new_offset = align_offset + len;

        if (new_offset > self.buffer.len) {
            return null;
        }

        const result = self.buffer[align_offset..new_offset];
        self.offset = new_offset;

        return result.ptr;
    }

    fn resize(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        _ = ctx;
        _ = buf_align;
        _ = ret_addr;
        return new_len <= buf.len;
    }

    fn remap(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        _ = ctx;
        _ = buf;
        _ = buf_align;
        _ = new_len;
        _ = ret_addr;
        return null;
    }

    fn free(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, ret_addr: usize) void {
        _ = ctx;
        _ = buf;
        _ = buf_align;
        _ = ret_addr;
    }

    pub fn reset(self: *BumpAllocator) void {
        self.offset = 0;
    }
};

test "bump allocator" {
    var buffer: [1024]u8 = undefined;
    var bump = BumpAllocator.init(&buffer);
    const allocator = bump.allocator();

    const slice1 = try allocator.alloc(u8, 100);
    try testing.expectEqual(100, slice1.len);

    const slice2 = try allocator.alloc(u32, 10);
    try testing.expectEqual(10, slice2.len);

    bump.reset();
    const slice3 = try allocator.alloc(u8, 50);
    try testing.expectEqual(50, slice3.len);
}
// ANCHOR_END: basic_allocator

// ANCHOR: counting_allocator
/// Allocator wrapper that counts allocations and bytes
const CountingAllocator = struct {
    parent: Allocator,
    alloc_count: usize,
    free_count: usize,
    bytes_allocated: usize,

    pub fn init(parent: Allocator) CountingAllocator {
        return .{
            .parent = parent,
            .alloc_count = 0,
            .free_count = 0,
            .bytes_allocated = 0,
        };
    }

    pub fn allocator(self: *CountingAllocator) Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, ptr_align: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        const result = self.parent.rawAlloc(len, ptr_align, ret_addr);
        if (result) |ptr| {
            self.alloc_count += 1;
            self.bytes_allocated += len;
            return ptr;
        }
        return null;
    }

    fn resize(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        return self.parent.rawResize(buf, buf_align, new_len, ret_addr);
    }

    fn remap(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        return self.parent.rawRemap(buf, buf_align, new_len, ret_addr);
    }

    fn free(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, ret_addr: usize) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(ctx));
        self.free_count += 1;
        self.parent.rawFree(buf, buf_align, ret_addr);
    }
};

test "counting allocator" {
    var counting = CountingAllocator.init(testing.allocator);
    const allocator = counting.allocator();

    const slice = try allocator.alloc(u8, 100);
    defer allocator.free(slice);

    try testing.expectEqual(@as(usize, 1), counting.alloc_count);
    try testing.expectEqual(@as(usize, 100), counting.bytes_allocated);
}
// ANCHOR_END: counting_allocator

// ANCHOR: fail_allocator
/// Allocator that fails after N allocations (for testing)
const FailAllocator = struct {
    parent: Allocator,
    fail_after: usize,
    alloc_count: usize,

    pub fn init(parent: Allocator, fail_after: usize) FailAllocator {
        return .{
            .parent = parent,
            .fail_after = fail_after,
            .alloc_count = 0,
        };
    }

    pub fn allocator(self: *FailAllocator) Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = remap,
                .free = free,
            },
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, ptr_align: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        const self: *FailAllocator = @ptrCast(@alignCast(ctx));
        if (self.alloc_count >= self.fail_after) {
            return null;
        }
        self.alloc_count += 1;
        return self.parent.rawAlloc(len, ptr_align, ret_addr);
    }

    fn resize(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *FailAllocator = @ptrCast(@alignCast(ctx));
        return self.parent.rawResize(buf, buf_align, new_len, ret_addr);
    }

    fn remap(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *FailAllocator = @ptrCast(@alignCast(ctx));
        return self.parent.rawRemap(buf, buf_align, new_len, ret_addr);
    }

    fn free(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, ret_addr: usize) void {
        const self: *FailAllocator = @ptrCast(@alignCast(ctx));
        self.parent.rawFree(buf, buf_align, ret_addr);
    }
};

test "fail allocator" {
    var fail_alloc = FailAllocator.init(testing.allocator, 2);
    const allocator = fail_alloc.allocator();

    const slice1 = try allocator.alloc(u8, 10);
    defer allocator.free(slice1);

    const slice2 = try allocator.alloc(u8, 20);
    defer allocator.free(slice2);

    try testing.expectError(error.OutOfMemory, allocator.alloc(u8, 30));
}
// ANCHOR_END: fail_allocator
