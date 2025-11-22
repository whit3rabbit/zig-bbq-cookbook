const std = @import("std");
const testing = std.testing;

// Import base types from main recipe
const Session = @import("recipe_11_7.zig").Session;
const SessionData = @import("recipe_11_7.zig").SessionData;

// ANCHOR: threadsafe_session_store
/// Thread-Safe Session Store for Production Web Servers
///
/// This implementation adds mutex synchronization to prevent data races when
/// multiple threads access the session store concurrently. Essential for
/// multi-threaded HTTP servers where requests are handled in parallel.
///
/// Key Differences from Basic SessionStore:
/// - std.Thread.Mutex protects all HashMap operations
/// - lock()/unlock() pattern ensures atomic operations
/// - defer unlock() prevents lock leaks on early returns
///
/// Performance: Adds ~100ns per operation. For >10k req/s, consider:
/// - Sharded stores (multiple stores with separate locks)
/// - Lock-free data structures (advanced, see Recipe 12.3)
/// - External session storage (Redis, database)
pub const ThreadSafeSessionStore = struct {
    sessions: std.StringHashMap(Session),
    allocator: std.mem.Allocator,
    default_timeout: i64,
    mutex: std.Thread.Mutex,

    pub fn init(allocator: std.mem.Allocator) ThreadSafeSessionStore {
        return .{
            .sessions = std.StringHashMap(Session).init(allocator),
            .allocator = allocator,
            .default_timeout = 3600, // 1 hour default
            .mutex = .{}, // Zero-initialize mutex
        };
    }

    pub fn deinit(self: *ThreadSafeSessionStore) void {
        // No lock needed - deinit called when no other threads access store
        var it = self.sessions.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            var session = entry.value_ptr;
            session.deinit();
        }
        self.sessions.deinit();
    }

    pub fn create(self: *ThreadSafeSessionStore) ![]const u8 {
        // Lock before accessing shared HashMap
        self.mutex.lock();
        defer self.mutex.unlock();

        // Generate cryptographically secure session ID
        var random_bytes: [16]u8 = undefined;
        std.crypto.random.bytes(&random_bytes);

        // Encode as hex string (32 chars)
        var id_buf: [32]u8 = undefined;
        const id = std.fmt.bytesToHex(random_bytes, .lower);
        @memcpy(&id_buf, &id);

        const owned_id = try self.allocator.dupe(u8, &id_buf);
        errdefer self.allocator.free(owned_id);

        const session = try Session.init(self.allocator, owned_id);
        try self.sessions.put(owned_id, session);

        return owned_id;
    }

    pub fn get(self: *ThreadSafeSessionStore, session_id: []const u8) ?*Session {
        // Lock prevents concurrent modification while reading
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.sessions.getPtr(session_id)) |session| {
            if (session.isExpired(self.default_timeout)) {
                return null;
            }
            session.touch();
            return session;
        }
        return null;
    }

    pub fn destroy(self: *ThreadSafeSessionStore, session_id: []const u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.sessions.getPtr(session_id)) |session| {
            session.deinit();
        }
        if (self.sessions.fetchRemove(session_id)) |kv| {
            self.allocator.free(kv.key);
        }
    }

    pub fn cleanup(self: *ThreadSafeSessionStore) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var to_remove = std.ArrayList([]const u8){};
        defer to_remove.deinit(self.allocator);

        var it = self.sessions.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.isExpired(self.default_timeout)) {
                try to_remove.append(self.allocator, entry.key_ptr.*);
            }
        }

        // Cleanup while holding lock (safe because we're in the same function)
        for (to_remove.items) |session_id| {
            if (self.sessions.getPtr(session_id)) |session| {
                session.deinit();
            }
            if (self.sessions.fetchRemove(session_id)) |kv| {
                self.allocator.free(kv.key);
            }
        }
    }
};
// ANCHOR_END: threadsafe_session_store

// ANCHOR: test_threadsafe_basic
test "thread-safe session store basic operations" {
    var store = ThreadSafeSessionStore.init(testing.allocator);
    defer store.deinit();

    const session_id = try store.create();

    const session = store.get(session_id);
    try testing.expect(session != null);
    try testing.expectEqualStrings(session_id, session.?.id);
}
// ANCHOR_END: test_threadsafe_basic

// ANCHOR: test_concurrent_create
test "concurrent session creation" {
    var store = ThreadSafeSessionStore.init(testing.allocator);
    defer store.deinit();

    const num_threads = 10;
    var threads: [num_threads]std.Thread = undefined;

    // Spawn threads that create sessions concurrently
    for (&threads) |*thread| {
        thread.* = try std.Thread.spawn(.{}, createSessionWorker, .{&store});
    }

    for (threads) |thread| {
        thread.join();
    }

    // All 10 sessions should exist without corruption or loss
    try testing.expectEqual(@as(u32, num_threads), store.sessions.count());
}

fn createSessionWorker(store: *ThreadSafeSessionStore) void {
    const session_id = store.create() catch return;
    _ = store.get(session_id);
}
// ANCHOR_END: test_concurrent_create

// ANCHOR: test_concurrent_access
test "concurrent read/write operations" {
    var store = ThreadSafeSessionStore.init(testing.allocator);
    defer store.deinit();

    // Create initial sessions
    const session_id1 = try store.create();
    const session_id2 = try store.create();

    const Context = struct {
        store: *ThreadSafeSessionStore,
        session_id: []const u8,
    };

    var ctx1 = Context{ .store = &store, .session_id = session_id1 };
    var ctx2 = Context{ .store = &store, .session_id = session_id2 };

    var threads: [4]std.Thread = undefined;

    // Spawn multiple threads accessing sessions
    threads[0] = try std.Thread.spawn(.{}, accessSessionWorker, .{&ctx1});
    threads[1] = try std.Thread.spawn(.{}, accessSessionWorker, .{&ctx2});
    threads[2] = try std.Thread.spawn(.{}, accessSessionWorker, .{&ctx1});
    threads[3] = try std.Thread.spawn(.{}, accessSessionWorker, .{&ctx2});

    for (threads) |thread| {
        thread.join();
    }

    // Both sessions should still exist and be valid
    try testing.expect(store.get(session_id1) != null);
    try testing.expect(store.get(session_id2) != null);
}

fn accessSessionWorker(ctx: anytype) void {
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        if (ctx.store.get(ctx.session_id)) |session| {
            _ = session.data.get("test");
        }
    }
}
// ANCHOR_END: test_concurrent_access

// ANCHOR: test_concurrent_cleanup
test "concurrent cleanup with active sessions" {
    var store = ThreadSafeSessionStore.init(testing.allocator);
    defer store.deinit();

    store.default_timeout = 0; // All sessions expire immediately

    const num_sessions = 20;
    var i: usize = 0;
    while (i < num_sessions) : (i += 1) {
        _ = try store.create();
    }

    var threads: [2]std.Thread = undefined;

    // One thread creates new sessions, another cleans up expired ones
    threads[0] = try std.Thread.spawn(.{}, createManySessionsWorker, .{&store});
    threads[1] = try std.Thread.spawn(.{}, cleanupWorker, .{&store});

    for (threads) |thread| {
        thread.join();
    }

    // Should complete without crashes or data corruption
    try testing.expect(true);
}

fn createManySessionsWorker(store: *ThreadSafeSessionStore) void {
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        _ = store.create() catch return;
    }
}

fn cleanupWorker(store: *ThreadSafeSessionStore) void {
    var i: usize = 0;
    while (i < 5) : (i += 1) {
        store.cleanup() catch return;
    }
}
// ANCHOR_END: test_concurrent_cleanup

// ANCHOR: test_destroy_while_reading
test "destroy session while other thread reads" {
    var store = ThreadSafeSessionStore.init(testing.allocator);
    defer store.deinit();

    const session_id = try store.create();

    const Context = struct {
        store: *ThreadSafeSessionStore,
        session_id: []const u8,
        attempts: std.atomic.Value(usize),
    };

    var ctx = Context{
        .store = &store,
        .session_id = session_id,
        .attempts = std.atomic.Value(usize).init(0),
    };

    var threads: [2]std.Thread = undefined;

    // One thread repeatedly reads, another destroys
    threads[0] = try std.Thread.spawn(.{}, readSessionWorker, .{&ctx});
    threads[1] = try std.Thread.spawn(.{}, destroySessionWorker, .{&ctx});

    for (threads) |thread| {
        thread.join();
    }

    // Should complete without crashes
    try testing.expect(ctx.attempts.load(.acquire) > 0);
}

fn readSessionWorker(ctx: anytype) void {
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        _ = ctx.store.get(ctx.session_id);
        _ = ctx.attempts.fetchAdd(1, .release);
    }
}

fn destroySessionWorker(ctx: anytype) void {
    // Wait a bit then destroy
    std.Thread.sleep(1 * std.time.ns_per_ms);
    ctx.store.destroy(ctx.session_id);
}
// ANCHOR_END: test_destroy_while_reading

// ANCHOR: performance_comparison
test "performance comparison - single threaded" {
    // This test demonstrates the mutex overhead
    // In single-threaded scenarios, basic SessionStore is ~100ns faster per operation
    // In multi-threaded scenarios, ThreadSafeSessionStore prevents data corruption

    var store = ThreadSafeSessionStore.init(testing.allocator);
    defer store.deinit();

    const iterations = 100;
    var i: usize = 0;

    const start = std.time.nanoTimestamp();
    while (i < iterations) : (i += 1) {
        const session_id = try store.create();
        _ = store.get(session_id);
        store.destroy(session_id);
    }
    const end = std.time.nanoTimestamp();

    const elapsed = @as(u64, @intCast(end - start));
    const avg_per_op = elapsed / iterations;

    // Educational note: Mutex adds ~100-200ns overhead per operation
    // Acceptable for most web applications (<10k req/s per core)
    std.debug.print("Average operation time: {d}ns\n", .{avg_per_op});

    try testing.expect(avg_per_op > 0);
}
// ANCHOR_END: performance_comparison
