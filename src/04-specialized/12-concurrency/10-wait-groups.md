## Problem

You're spawning multiple threads and need to wait for all of them to complete. Manually tracking threads is error-prone.

## Solution

Use `std.Thread.WaitGroup` to track and wait for parallel tasks.

```zig
{{#include ../../../code/04-specialized/12-concurrency/recipe_12_10.zig:wait_group}}
```

## Discussion

WaitGroups provide a clean pattern for parallel task completion. Call `start()` before spawning, `finish()` when done (via `defer`), and `wait()` to block until all complete.

### Parallel Tasks

```zig
var wg: WaitGroup = .{};
var results: [5]i32 = undefined;

for (0..5) |i| {
    wg.start();
    _ = try Thread.spawn(.{}, parallelTask, .{ &wg, i, &results });
}

wg.wait(); // All tasks complete
```

### Dynamic Spawning

```zig
var wg: WaitGroup = .{};

for (work_items) |item| {
    wg.start();
    _ = try Thread.spawn(.{}, processItem, .{ &wg, item });
}

wg.wait();
```

### Nested WaitGroups

```zig
fn outerWorker(wg: *WaitGroup) void {
    defer wg.finish();

    var inner_wg: WaitGroup = .{};
    // Spawn sub-tasks...
    inner_wg.wait();
}
```

## See Also

- Recipe 12.1: Basic threading and thread management
- Recipe 12.6: Condition variables and signaling

Full compilable example: `code/04-specialized/12-concurrency/recipe_12_10.zig`
