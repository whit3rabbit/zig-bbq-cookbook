const std = @import("std");
const testing = std.testing;

// Custom panic handler
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = msg;
    _ = error_return_trace;
    _ = ret_addr;
    while (true) {}
}

// ANCHOR: bump_allocator
// Simple bump allocator - fast but can't free individual allocations
const BumpAllocator = struct {
    buffer: []u8,
    offset: usize,

    pub fn init(buffer: []u8) BumpAllocator {
        return .{
            .buffer = buffer,
            .offset = 0,
        };
    }

    pub fn allocator(self: *BumpAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
                .remap = remap,
            },
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, ptr_align: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
        _ = ret_addr;
        const self: *BumpAllocator = @ptrCast(@alignCast(ctx));

        const align_offset = std.mem.alignForward(usize, self.offset, ptr_align.toByteUnits());
        const new_offset = align_offset + len;

        if (new_offset > self.buffer.len) {
            return null; // Out of memory
        }

        const result = self.buffer[align_offset..new_offset];
        self.offset = new_offset;

        return result.ptr;
    }

    fn resize(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        _ = ctx;
        _ = buf;
        _ = buf_align;
        _ = new_len;
        _ = ret_addr;
        return false; // Cannot resize
    }

    fn free(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, ret_addr: usize) void {
        _ = ctx;
        _ = buf;
        _ = buf_align;
        _ = ret_addr;
        // Bump allocator doesn't free individual allocations
    }

    fn remap(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        _ = ctx;
        _ = buf;
        _ = buf_align;
        _ = new_len;
        _ = ret_addr;
        return null; // Cannot remap
    }

    pub fn reset(self: *BumpAllocator) void {
        self.offset = 0;
    }
};
// ANCHOR_END: bump_allocator

// ANCHOR: global_allocator
// Global allocator instance for WASM
var global_heap: [64 * 1024]u8 = undefined; // 64KB
var global_allocator = BumpAllocator.init(&global_heap);
// ANCHOR_END: global_allocator

// ANCHOR: using_allocator
// Example: Create dynamic array
export fn createArray(size: usize) ?[*]i32 {
    const allocator = global_allocator.allocator();
    const array = allocator.alloc(i32, size) catch return null;

    // Initialize array
    for (array, 0..) |*item, i| {
        item.* = @intCast(i);
    }

    return array.ptr;
}

export fn resetAllocator() void {
    global_allocator.reset();
}
// ANCHOR_END: using_allocator

// ANCHOR: arena_allocator
// Arena allocator - groups allocations for bulk freeing
const ArenaWrapper = struct {
    var backing_buffer: [32 * 1024]u8 = undefined;
    var fixed_allocator = std.heap.FixedBufferAllocator.init(&backing_buffer);
    var arena = std.heap.ArenaAllocator.init(fixed_allocator.allocator());

    pub fn get() std.mem.Allocator {
        return arena.allocator();
    }

    pub fn reset() void {
        _ = arena.reset(.free_all);
    }
};
// ANCHOR_END: arena_allocator

// ANCHOR: using_arena
// Example: Process with arena
export fn processData(count: usize) i32 {
    const allocator = ArenaWrapper.get();

    // Allocate temporary data
    const buffer = allocator.alloc(i32, count) catch return -1;

    var sum: i32 = 0;
    for (0..count) |i| {
        buffer[i] = @as(i32, @intCast(i)) * 2;
        sum += buffer[i];
    }

    // No need to free - arena will handle it
    return sum;
}

export fn resetArena() void {
    ArenaWrapper.reset();
}
// ANCHOR_END: using_arena

// ANCHOR: fixed_buffer_allocator
// Direct use of FixedBufferAllocator
export fn useFixedBuffer() i32 {
    var buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    // Allocate and use memory
    const array = allocator.alloc(i32, 10) catch return -1;
    defer allocator.free(array);

    var sum: i32 = 0;
    for (array, 0..) |*item, i| {
        item.* = @intCast(i);
        sum += item.*;
    }

    return sum; // 0+1+2+...+9 = 45
}
// ANCHOR_END: fixed_buffer_allocator

// ANCHOR: pool_allocator
// Pool allocator for fixed-size allocations
const PoolAllocator = struct {
    const POOL_SIZE = 100;
    const ITEM_SIZE = 64;

    pool: [POOL_SIZE][ITEM_SIZE]u8,
    free_list: [POOL_SIZE]bool,
    initialized: bool,

    pub fn init() PoolAllocator {
        return .{
            .pool = undefined,
            .free_list = [_]bool{true} ** POOL_SIZE,
            .initialized = true,
        };
    }

    pub fn allocate(self: *PoolAllocator) ?[*]u8 {
        for (&self.free_list, 0..) |*is_free, i| {
            if (is_free.*) {
                is_free.* = false;
                return &self.pool[i];
            }
        }
        return null; // Pool exhausted
    }

    pub fn deallocate(self: *PoolAllocator, ptr: [*]u8) void {
        const base = @intFromPtr(&self.pool[0]);
        const addr = @intFromPtr(ptr);
        const offset = addr - base;
        const index = offset / ITEM_SIZE;

        if (index < POOL_SIZE) {
            self.free_list[index] = true;
        }
    }
};

var global_pool = PoolAllocator.init();
// ANCHOR_END: pool_allocator

// ANCHOR: using_pool
// Example: Use pool allocator
export fn allocateFromPool() ?[*]u8 {
    return global_pool.allocate();
}

export fn freeToPool(ptr: [*]u8) void {
    global_pool.deallocate(ptr);
}
// ANCHOR_END: using_pool

// Tests

// ANCHOR: test_bump_allocator
test "bump allocator" {
    var buffer: [1024]u8 = undefined;
    var bump = BumpAllocator.init(&buffer);
    const allocator = bump.allocator();

    const slice1 = try allocator.alloc(u8, 100);
    try testing.expectEqual(@as(usize, 100), slice1.len);

    const slice2 = try allocator.alloc(u8, 200);
    try testing.expectEqual(@as(usize, 200), slice2.len);

    // Reset and reuse
    bump.reset();
    const slice3 = try allocator.alloc(u8, 50);
    try testing.expectEqual(@as(usize, 50), slice3.len);
}
// ANCHOR_END: test_bump_allocator

// ANCHOR: test_arena
test "arena allocator" {
    var backing: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&backing);
    var arena = std.heap.ArenaAllocator.init(fba.allocator());
    defer arena.deinit();

    const allocator = arena.allocator();

    // Multiple allocations
    const slice1 = try allocator.alloc(i32, 10);
    const slice2 = try allocator.alloc(i32, 20);

    try testing.expectEqual(@as(usize, 10), slice1.len);
    try testing.expectEqual(@as(usize, 20), slice2.len);

    // All freed together
}
// ANCHOR_END: test_arena

// ANCHOR: test_fixed_buffer
test "fixed buffer allocator" {
    var buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    const array = try allocator.alloc(i32, 10);
    defer allocator.free(array);

    var sum: i32 = 0;
    for (array, 0..) |*item, i| {
        item.* = @intCast(i);
        sum += item.*;
    }

    try testing.expectEqual(@as(i32, 45), sum);
}
// ANCHOR_END: test_fixed_buffer

// ANCHOR: test_pool
test "pool allocator" {
    var pool = PoolAllocator.init();

    const ptr1 = pool.allocate().?;
    const ptr2 = pool.allocate().?;

    try testing.expect(ptr1 != ptr2);

    pool.deallocate(ptr1);

    const ptr3 = pool.allocate().?;
    try testing.expectEqual(ptr1, ptr3); // Reused slot
}
// ANCHOR_END: test_pool

// ANCHOR: test_out_of_memory
test "out of memory handling" {
    var buffer: [100]u8 = undefined;
    var bump = BumpAllocator.init(&buffer);
    const allocator = bump.allocator();

    _ = try allocator.alloc(u8, 50);

    // This should fail
    const result = allocator.alloc(u8, 100);
    try testing.expectError(error.OutOfMemory, result);
}
// ANCHOR_END: test_out_of_memory
