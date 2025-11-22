const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_opaque
// Define an opaque handle type for C
pub const Database = opaque {};

// Internal implementation (not visible to C)
const DatabaseImpl = struct {
    name: []const u8,
    connection_count: usize,
    allocator: std.mem.Allocator,
};

export fn database_create(name: [*:0]const u8) ?*Database {
    const allocator = std.heap.c_allocator;

    // Convert C string to Zig slice
    const name_len = std.mem.len(name);
    const name_copy = allocator.dupe(u8, name[0..name_len]) catch return null;

    const impl = allocator.create(DatabaseImpl) catch {
        allocator.free(name_copy);
        return null;
    };

    impl.* = DatabaseImpl{
        .name = name_copy,
        .connection_count = 0,
        .allocator = allocator,
    };

    return @ptrCast(impl);
}

export fn database_connect(db: ?*Database) bool {
    const impl: *DatabaseImpl = @ptrCast(@alignCast(db orelse return false));
    impl.connection_count += 1;
    return true;
}

export fn database_get_connections(db: ?*const Database) usize {
    const impl: *const DatabaseImpl = @ptrCast(@alignCast(db orelse return 0));
    return impl.connection_count;
}

export fn database_destroy(db: ?*Database) void {
    if (db) |handle| {
        const impl: *DatabaseImpl = @ptrCast(@alignCast(handle));
        impl.allocator.free(impl.name);
        impl.allocator.destroy(impl);
    }
}

test "basic opaque handle" {
    const db = database_create("test_db");
    try testing.expect(db != null);

    try testing.expect(database_connect(db));
    try testing.expect(database_connect(db));
    try testing.expectEqual(@as(usize, 2), database_get_connections(db));

    database_destroy(db);
}
// ANCHOR_END: basic_opaque

// ANCHOR: opaque_with_state
// More complex opaque type with multiple operations
pub const FileHandle = opaque {};

const FileHandleImpl = struct {
    path: []const u8,
    is_open: bool,
    read_count: usize,
    write_count: usize,
    allocator: std.mem.Allocator,
};

export fn file_open(path: [*:0]const u8) ?*FileHandle {
    const allocator = std.heap.c_allocator;
    const path_len = std.mem.len(path);
    const path_copy = allocator.dupe(u8, path[0..path_len]) catch return null;

    const impl = allocator.create(FileHandleImpl) catch {
        allocator.free(path_copy);
        return null;
    };

    impl.* = FileHandleImpl{
        .path = path_copy,
        .is_open = true,
        .read_count = 0,
        .write_count = 0,
        .allocator = allocator,
    };

    return @ptrCast(impl);
}

export fn file_read(handle: ?*FileHandle) bool {
    const impl: *FileHandleImpl = @ptrCast(@alignCast(handle orelse return false));
    if (!impl.is_open) return false;
    impl.read_count += 1;
    return true;
}

export fn file_write(handle: ?*FileHandle) bool {
    const impl: *FileHandleImpl = @ptrCast(@alignCast(handle orelse return false));
    if (!impl.is_open) return false;
    impl.write_count += 1;
    return true;
}

export fn file_get_stats(handle: ?*const FileHandle, reads: *usize, writes: *usize) bool {
    const impl: *const FileHandleImpl = @ptrCast(@alignCast(handle orelse return false));
    reads.* = impl.read_count;
    writes.* = impl.write_count;
    return true;
}

export fn file_close(handle: ?*FileHandle) void {
    if (handle) |h| {
        const impl: *FileHandleImpl = @ptrCast(@alignCast(h));
        impl.is_open = false;
        impl.allocator.free(impl.path);
        impl.allocator.destroy(impl);
    }
}

test "opaque file handle with state" {
    const handle = file_open("test.txt");
    try testing.expect(handle != null);

    try testing.expect(file_read(handle));
    try testing.expect(file_read(handle));
    try testing.expect(file_write(handle));

    var reads: usize = 0;
    var writes: usize = 0;
    try testing.expect(file_get_stats(handle, &reads, &writes));
    try testing.expectEqual(@as(usize, 2), reads);
    try testing.expectEqual(@as(usize, 1), writes);

    file_close(handle);
}
// ANCHOR_END: opaque_with_state

// ANCHOR: opaque_iterator
// Iterator pattern using opaque types
pub const Iterator = opaque {};

const IteratorImpl = struct {
    data: []const c_int,
    current: usize,
    allocator: std.mem.Allocator,
};

export fn iterator_create(data: [*]const c_int, len: usize) ?*Iterator {
    const allocator = std.heap.c_allocator;
    const data_copy = allocator.dupe(c_int, data[0..len]) catch return null;

    const impl = allocator.create(IteratorImpl) catch {
        allocator.free(data_copy);
        return null;
    };

    impl.* = IteratorImpl{
        .data = data_copy,
        .current = 0,
        .allocator = allocator,
    };

    return @ptrCast(impl);
}

export fn iterator_has_next(iter: ?*const Iterator) bool {
    const impl: *const IteratorImpl = @ptrCast(@alignCast(iter orelse return false));
    return impl.current < impl.data.len;
}

export fn iterator_next(iter: ?*Iterator, out_value: *c_int) bool {
    const impl: *IteratorImpl = @ptrCast(@alignCast(iter orelse return false));
    if (impl.current >= impl.data.len) return false;

    out_value.* = impl.data[impl.current];
    impl.current += 1;
    return true;
}

export fn iterator_reset(iter: ?*Iterator) void {
    if (iter) |it| {
        const impl: *IteratorImpl = @ptrCast(@alignCast(it));
        impl.current = 0;
    }
}

export fn iterator_destroy(iter: ?*Iterator) void {
    if (iter) |it| {
        const impl: *IteratorImpl = @ptrCast(@alignCast(it));
        impl.allocator.free(impl.data);
        impl.allocator.destroy(impl);
    }
}

test "opaque iterator pattern" {
    const data = [_]c_int{ 10, 20, 30, 40 };
    const iter = iterator_create(&data, data.len);
    try testing.expect(iter != null);

    var value: c_int = 0;
    var count: usize = 0;

    while (iterator_has_next(iter)) {
        try testing.expect(iterator_next(iter, &value));
        count += 1;
    }
    try testing.expectEqual(@as(usize, 4), count);

    // Reset and iterate again
    iterator_reset(iter);
    try testing.expect(iterator_next(iter, &value));
    try testing.expectEqual(@as(c_int, 10), value);

    iterator_destroy(iter);
}
// ANCHOR_END: opaque_iterator

// ANCHOR: opaque_collection
// Collection type with opaque internals
pub const Stack = opaque {};

const StackImpl = struct {
    items: std.ArrayList(c_int),
    max_size: usize,
    allocator: std.mem.Allocator,
};

export fn stack_create(max_size: usize) ?*Stack {
    const allocator = std.heap.c_allocator;
    const impl = allocator.create(StackImpl) catch return null;

    impl.* = StackImpl{
        .items = .{},
        .max_size = max_size,
        .allocator = allocator,
    };

    return @ptrCast(impl);
}

export fn stack_push(stack: ?*Stack, value: c_int) bool {
    const impl: *StackImpl = @ptrCast(@alignCast(stack orelse return false));
    if (impl.items.items.len >= impl.max_size) return false;

    impl.items.append(impl.allocator, value) catch return false;
    return true;
}

export fn stack_pop(stack: ?*Stack, out_value: *c_int) bool {
    const impl: *StackImpl = @ptrCast(@alignCast(stack orelse return false));
    if (impl.items.items.len == 0) return false;

    out_value.* = impl.items.pop() orelse return false;
    return true;
}

export fn stack_peek(stack: ?*const Stack, out_value: *c_int) bool {
    const impl: *const StackImpl = @ptrCast(@alignCast(stack orelse return false));
    if (impl.items.items.len == 0) return false;

    out_value.* = impl.items.items[impl.items.items.len - 1];
    return true;
}

export fn stack_size(stack: ?*const Stack) usize {
    const impl: *const StackImpl = @ptrCast(@alignCast(stack orelse return 0));
    return impl.items.items.len;
}

export fn stack_is_empty(stack: ?*const Stack) bool {
    const impl: *const StackImpl = @ptrCast(@alignCast(stack orelse return true));
    return impl.items.items.len == 0;
}

export fn stack_clear(stack: ?*Stack) void {
    if (stack) |s| {
        const impl: *StackImpl = @ptrCast(@alignCast(s));
        impl.items.clearRetainingCapacity();
    }
}

export fn stack_destroy(stack: ?*Stack) void {
    if (stack) |s| {
        const impl: *StackImpl = @ptrCast(@alignCast(s));
        impl.items.deinit(impl.allocator);
        impl.allocator.destroy(impl);
    }
}

test "opaque stack collection" {
    const stack = stack_create(5);
    try testing.expect(stack != null);
    try testing.expect(stack_is_empty(stack));

    try testing.expect(stack_push(stack, 10));
    try testing.expect(stack_push(stack, 20));
    try testing.expect(stack_push(stack, 30));
    try testing.expectEqual(@as(usize, 3), stack_size(stack));

    var value: c_int = 0;
    try testing.expect(stack_peek(stack, &value));
    try testing.expectEqual(@as(c_int, 30), value);
    try testing.expectEqual(@as(usize, 3), stack_size(stack));

    try testing.expect(stack_pop(stack, &value));
    try testing.expectEqual(@as(c_int, 30), value);
    try testing.expectEqual(@as(usize, 2), stack_size(stack));

    stack_clear(stack);
    try testing.expect(stack_is_empty(stack));

    stack_destroy(stack);
}
// ANCHOR_END: opaque_collection

// ANCHOR: opaque_resource_manager
// Resource manager with opaque handle
pub const ResourcePool = opaque {};

const Resource = struct {
    id: usize,
    in_use: bool,
};

const ResourcePoolImpl = struct {
    resources: std.ArrayList(Resource),
    next_id: usize,
    allocator: std.mem.Allocator,
};

export fn resource_pool_create(initial_capacity: usize) ?*ResourcePool {
    const allocator = std.heap.c_allocator;
    const impl = allocator.create(ResourcePoolImpl) catch return null;

    impl.* = ResourcePoolImpl{
        .resources = .{},
        .next_id = 0,
        .allocator = allocator,
    };

    // Pre-allocate resources
    for (0..initial_capacity) |_| {
        const resource = Resource{ .id = impl.next_id, .in_use = false };
        impl.next_id += 1;
        impl.resources.append(allocator, resource) catch {
            impl.resources.deinit(allocator);
            allocator.destroy(impl);
            return null;
        };
    }

    return @ptrCast(impl);
}

export fn resource_pool_acquire(pool: ?*ResourcePool) isize {
    const impl: *ResourcePoolImpl = @ptrCast(@alignCast(pool orelse return -1));

    for (impl.resources.items) |*resource| {
        if (!resource.in_use) {
            resource.in_use = true;
            return @intCast(resource.id);
        }
    }

    return -1; // No available resources
}

export fn resource_pool_release(pool: ?*ResourcePool, resource_id: usize) bool {
    const impl: *ResourcePoolImpl = @ptrCast(@alignCast(pool orelse return false));

    for (impl.resources.items) |*resource| {
        if (resource.id == resource_id and resource.in_use) {
            resource.in_use = false;
            return true;
        }
    }

    return false;
}

export fn resource_pool_available_count(pool: ?*const ResourcePool) usize {
    const impl: *const ResourcePoolImpl = @ptrCast(@alignCast(pool orelse return 0));
    var count: usize = 0;

    for (impl.resources.items) |resource| {
        if (!resource.in_use) count += 1;
    }

    return count;
}

export fn resource_pool_destroy(pool: ?*ResourcePool) void {
    if (pool) |p| {
        const impl: *ResourcePoolImpl = @ptrCast(@alignCast(p));
        impl.resources.deinit(impl.allocator);
        impl.allocator.destroy(impl);
    }
}

test "opaque resource pool" {
    const pool = resource_pool_create(3);
    try testing.expect(pool != null);
    try testing.expectEqual(@as(usize, 3), resource_pool_available_count(pool));

    const r1 = resource_pool_acquire(pool);
    const r2 = resource_pool_acquire(pool);
    try testing.expect(r1 >= 0);
    try testing.expect(r2 >= 0);
    try testing.expectEqual(@as(usize, 1), resource_pool_available_count(pool));

    try testing.expect(resource_pool_release(pool, @intCast(r1)));
    try testing.expectEqual(@as(usize, 2), resource_pool_available_count(pool));

    resource_pool_destroy(pool);
}
// ANCHOR_END: opaque_resource_manager
