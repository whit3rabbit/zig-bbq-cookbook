// Recipe 18.6: Tracking and Debugging Memory Usage
// This recipe demonstrates tools and techniques for tracking memory allocations,
// detecting leaks, profiling usage, and debugging memory-related issues.

const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

// ANCHOR: testing_allocator
// Using testing allocator for leak detection
test "testing allocator detects leaks" {
    // testing.allocator automatically detects leaks
    const slice = try testing.allocator.alloc(u8, 100);
    defer testing.allocator.free(slice); // Comment this to see leak detection

    slice[0] = 42;
    try testing.expectEqual(@as(u8, 42), slice[0]);

    // If defer is commented out, test fails with leak detection
}
// ANCHOR_END: testing_allocator

// ANCHOR: logging_allocator
// Logging allocator wrapper
const LoggingAllocator = struct {
    parent: Allocator,
    alloc_count: *usize,
    free_count: *usize,
    bytes_allocated: *usize,

    pub fn init(parent: Allocator, alloc_count: *usize, free_count: *usize, bytes_allocated: *usize) LoggingAllocator {
        return .{
            .parent = parent,
            .alloc_count = alloc_count,
            .free_count = free_count,
            .bytes_allocated = bytes_allocated,
        };
    }

    pub fn allocator(self: *LoggingAllocator) Allocator {
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
        const self: *LoggingAllocator = @ptrCast(@alignCast(ctx));
        const result = self.parent.rawAlloc(len, ptr_align, ret_addr);

        if (result) |ptr| {
            self.alloc_count.* += 1;
            self.bytes_allocated.* += len;
            std.debug.print("ALLOC: {d} bytes at {*}\n", .{ len, ptr });
            return ptr;
        }
        return null;
    }

    fn resize(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *LoggingAllocator = @ptrCast(@alignCast(ctx));
        return self.parent.rawResize(buf, buf_align, new_len, ret_addr);
    }

    fn remap(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *LoggingAllocator = @ptrCast(@alignCast(ctx));
        return self.parent.rawRemap(buf, buf_align, new_len, ret_addr);
    }

    fn free(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, ret_addr: usize) void {
        const self: *LoggingAllocator = @ptrCast(@alignCast(ctx));
        self.free_count.* += 1;
        std.debug.print("FREE: {d} bytes at {*}\n", .{ buf.len, buf.ptr });
        self.parent.rawFree(buf, buf_align, ret_addr);
    }
};

test "logging allocator" {
    var alloc_count: usize = 0;
    var free_count: usize = 0;
    var bytes_allocated: usize = 0;

    var logging = LoggingAllocator.init(
        testing.allocator,
        &alloc_count,
        &free_count,
        &bytes_allocated,
    );
    const allocator = logging.allocator();

    const slice1 = try allocator.alloc(u32, 10);
    defer allocator.free(slice1);

    const slice2 = try allocator.alloc(u64, 5);
    defer allocator.free(slice2);

    try testing.expectEqual(@as(usize, 2), alloc_count);
    try testing.expect(bytes_allocated > 0);
}
// ANCHOR_END: logging_allocator

// ANCHOR: tracking_allocator
// Allocation tracking allocator
const AllocationInfo = struct {
    size: usize,
    address: usize,
    return_address: usize,
};

const TrackingAllocator = struct {
    parent: Allocator,
    allocations: std.ArrayList(AllocationInfo),
    total_allocated: usize,
    peak_allocated: usize,

    pub fn init(parent: Allocator) TrackingAllocator {
        return .{
            .parent = parent,
            .allocations = .{},
            .total_allocated = 0,
            .peak_allocated = 0,
        };
    }

    pub fn deinit(self: *TrackingAllocator) void {
        self.allocations.deinit(self.parent);
    }

    pub fn allocator(self: *TrackingAllocator) Allocator {
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
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        const result = self.parent.rawAlloc(len, ptr_align, ret_addr) orelse return null;

        self.allocations.append(self.parent, .{
            .size = len,
            .address = @intFromPtr(result),
            .return_address = ret_addr,
        }) catch {};

        self.total_allocated += len;
        if (self.total_allocated > self.peak_allocated) {
            self.peak_allocated = self.total_allocated;
        }

        return result;
    }

    fn resize(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        return self.parent.rawResize(buf, buf_align, new_len, ret_addr);
    }

    fn remap(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        return self.parent.rawRemap(buf, buf_align, new_len, ret_addr);
    }

    fn free(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, ret_addr: usize) void {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        const addr = @intFromPtr(buf.ptr);

        // Remove from tracking
        var i: usize = 0;
        while (i < self.allocations.items.len) {
            if (self.allocations.items[i].address == addr) {
                self.total_allocated -= self.allocations.items[i].size;
                _ = self.allocations.swapRemove(i);
                break;
            }
            i += 1;
        }

        self.parent.rawFree(buf, buf_align, ret_addr);
    }

    pub fn reportLeaks(self: *TrackingAllocator) void {
        if (self.allocations.items.len > 0) {
            std.debug.print("\n=== MEMORY LEAKS DETECTED ===\n", .{});
            for (self.allocations.items) |info| {
                std.debug.print("Leak: {d} bytes at 0x{x} (from 0x{x})\n", .{
                    info.size,
                    info.address,
                    info.return_address,
                });
            }
        }
    }
};

test "tracking allocator" {
    var tracker = TrackingAllocator.init(testing.allocator);
    defer tracker.deinit();

    const allocator = tracker.allocator();

    const slice1 = try allocator.alloc(u8, 100);
    try testing.expectEqual(@as(usize, 100), tracker.total_allocated);

    const slice2 = try allocator.alloc(u32, 50);
    try testing.expect(tracker.total_allocated > 100);
    try testing.expect(tracker.peak_allocated >= tracker.total_allocated);

    allocator.free(slice1);
    allocator.free(slice2);

    try testing.expectEqual(@as(usize, 0), tracker.total_allocated);
    try testing.expectEqual(@as(usize, 0), tracker.allocations.items.len);
}
// ANCHOR_END: tracking_allocator

// ANCHOR: validating_allocator
// Validating allocator with bounds checking
const ValidatingAllocator = struct {
    const CANARY: u32 = 0xDEADBEEF;

    parent: Allocator,

    pub fn init(parent: Allocator) ValidatingAllocator {
        return .{ .parent = parent };
    }

    pub fn allocator(self: *ValidatingAllocator) Allocator {
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
        const self: *ValidatingAllocator = @ptrCast(@alignCast(ctx));

        // Allocate extra space for canaries
        const total_len = len + @sizeOf(u32) * 2;
        const raw = self.parent.rawAlloc(total_len, ptr_align, ret_addr) orelse return null;

        // Write front canary
        const front_canary: *u32 = @ptrCast(@alignCast(raw));
        front_canary.* = CANARY;

        // Write back canary
        const back_canary: *u32 = @ptrCast(@alignCast(raw + @sizeOf(u32) + len));
        back_canary.* = CANARY;

        return raw + @sizeOf(u32);
    }

    fn resize(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        _ = ctx;
        _ = buf;
        _ = buf_align;
        _ = new_len;
        _ = ret_addr;
        return false; // Don't support resize for simplicity
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
        const self: *ValidatingAllocator = @ptrCast(@alignCast(ctx));

        const raw = buf.ptr - @sizeOf(u32);

        // Check front canary
        const front_canary: *u32 = @ptrCast(@alignCast(raw));
        if (front_canary.* != CANARY) {
            std.debug.panic("CORRUPTION: Front canary overwritten!\n", .{});
        }

        // Check back canary
        const back_canary: *u32 = @ptrCast(@alignCast(raw + @sizeOf(u32) + buf.len));
        if (back_canary.* != CANARY) {
            std.debug.panic("CORRUPTION: Back canary overwritten!\n", .{});
        }

        const total_len = buf.len + @sizeOf(u32) * 2;
        self.parent.rawFree(raw[0..total_len], buf_align, ret_addr);
    }
};

test "validating allocator" {
    var validating = ValidatingAllocator.init(testing.allocator);
    const allocator = validating.allocator();

    const slice = try allocator.alloc(u8, 100);
    defer allocator.free(slice);

    // Normal use - canaries should remain intact
    @memset(slice, 42);
    try testing.expectEqual(@as(u8, 42), slice[0]);
}
// ANCHOR_END: validating_allocator

// ANCHOR: memory_profiler
// Simple memory profiler
const MemoryProfiler = struct {
    allocations_by_size: std.AutoHashMap(usize, usize),
    parent: Allocator,

    pub fn init(parent: Allocator) !MemoryProfiler {
        return .{
            .allocations_by_size = std.AutoHashMap(usize, usize).init(parent),
            .parent = parent,
        };
    }

    pub fn deinit(self: *MemoryProfiler) void {
        self.allocations_by_size.deinit();
    }

    pub fn allocator(self: *MemoryProfiler) Allocator {
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
        const self: *MemoryProfiler = @ptrCast(@alignCast(ctx));
        const result = self.parent.rawAlloc(len, ptr_align, ret_addr) orelse return null;

        const entry = self.allocations_by_size.getOrPut(len) catch return result;
        if (!entry.found_existing) {
            entry.value_ptr.* = 0;
        }
        entry.value_ptr.* += 1;

        return result;
    }

    fn resize(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
        const self: *MemoryProfiler = @ptrCast(@alignCast(ctx));
        return self.parent.rawResize(buf, buf_align, new_len, ret_addr);
    }

    fn remap(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
        const self: *MemoryProfiler = @ptrCast(@alignCast(ctx));
        return self.parent.rawRemap(buf, buf_align, new_len, ret_addr);
    }

    fn free(ctx: *anyopaque, buf: []u8, buf_align: std.mem.Alignment, ret_addr: usize) void {
        const self: *MemoryProfiler = @ptrCast(@alignCast(ctx));
        self.parent.rawFree(buf, buf_align, ret_addr);
    }

    pub fn report(self: *MemoryProfiler) void {
        std.debug.print("\n=== MEMORY PROFILE ===\n", .{});
        var iter = self.allocations_by_size.iterator();
        while (iter.next()) |entry| {
            std.debug.print("Size {d:>6} bytes: {d:>4} allocations\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
    }
};

test "memory profiler" {
    var profiler = try MemoryProfiler.init(testing.allocator);
    defer profiler.deinit();

    const allocator = profiler.allocator();

    const s1 = try allocator.alloc(u8, 100);
    defer allocator.free(s1);

    const s2 = try allocator.alloc(u8, 100);
    defer allocator.free(s2);

    const s3 = try allocator.alloc(u8, 200);
    defer allocator.free(s3);

    try testing.expectEqual(@as(usize, 2), profiler.allocations_by_size.count());
}
// ANCHOR_END: memory_profiler
