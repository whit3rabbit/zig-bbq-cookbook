const std = @import("std");
const testing = std.testing;
const Thread = std.Thread;

// ANCHOR: wait_group
const WaitGroup = Thread.WaitGroup;

fn worker(wg: *WaitGroup, id: usize) void {
    defer wg.finish();

    std.debug.print("Worker {} starting\n", .{id});
    Thread.sleep(10 * std.time.ns_per_ms);
    std.debug.print("Worker {} done\n", .{id});
}

test "wait group basic usage" {
    var wg: WaitGroup = .{};

    wg.start();
    wg.start();
    wg.start();

    const t1 = try Thread.spawn(.{}, worker, .{ &wg, 1 });
    const t2 = try Thread.spawn(.{}, worker, .{ &wg, 2 });
    const t3 = try Thread.spawn(.{}, worker, .{ &wg, 3 });

    wg.wait(); // Wait for all to finish

    t1.join();
    t2.join();
    t3.join();
}
// ANCHOR_END: wait_group

// ANCHOR: parallel_tasks
fn parallelTask(wg: *WaitGroup, id: usize, result: []i32) void {
    defer wg.finish();

    var sum: i32 = 0;
    var i: i32 = 0;
    while (i < 100) : (i += 1) {
        sum += i;
    }

    result[id] = sum;
}

test "wait for parallel tasks" {
    var wg: WaitGroup = .{};
    var results: [5]i32 = undefined;

    var threads: [5]Thread = undefined;
    for (&threads, 0..) |*thread, i| {
        wg.start();
        thread.* = try Thread.spawn(.{}, parallelTask, .{ &wg, i, &results });
    }

    wg.wait();

    for (threads) |thread| {
        thread.join();
    }

    // Sum of 0..99 = 4950
    for (results) |result| {
        try testing.expectEqual(@as(i32, 4950), result);
    }
}
// ANCHOR_END: parallel_tasks

// ANCHOR: dynamic_spawning
fn dynamicWorker(wg: *WaitGroup, counter: *std.atomic.Value(i32)) void {
    defer wg.finish();

    _ = counter.fetchAdd(@as(i32, 1), .monotonic);
    Thread.sleep(5 * std.time.ns_per_ms);
}

test "dynamic task spawning" {
    var wg: WaitGroup = .{};
    var counter = std.atomic.Value(i32).init(0);

    var threads: [10]Thread = undefined;

    // Dynamically spawn tasks
    for (&threads) |*thread| {
        wg.start();
        thread.* = try Thread.spawn(.{}, dynamicWorker, .{ &wg, &counter });
    }

    wg.wait(); // Wait for all

    for (threads) |thread| {
        thread.join();
    }

    try testing.expectEqual(@as(i32, 10), counter.load(.monotonic));
}
// ANCHOR_END: dynamic_spawning

// ANCHOR: nested_wait_groups
fn outerWorker(wg: *WaitGroup, id: usize) void {
    defer wg.finish();

    var inner_wg: WaitGroup = .{};

    // Spawn sub-tasks
    var threads: [3]Thread = undefined;
    for (&threads, 0..) |*thread, i| {
        inner_wg.start();
        thread.* = Thread.spawn(.{}, innerWorker, .{ &inner_wg, id * 10 + i }) catch unreachable;
    }

    inner_wg.wait();

    for (threads) |thread| {
        thread.join();
    }
}

fn innerWorker(wg: *WaitGroup, id: usize) void {
    defer wg.finish();
    std.debug.print("Inner worker {}\n", .{id});
    Thread.sleep(5 * std.time.ns_per_ms);
}

test "nested wait groups" {
    var wg: WaitGroup = .{};

    var threads: [2]Thread = undefined;
    for (&threads, 0..) |*thread, i| {
        wg.start();
        thread.* = try Thread.spawn(.{}, outerWorker, .{ &wg, i });
    }

    wg.wait();

    for (threads) |thread| {
        thread.join();
    }
}
// ANCHOR_END: nested_wait_groups
