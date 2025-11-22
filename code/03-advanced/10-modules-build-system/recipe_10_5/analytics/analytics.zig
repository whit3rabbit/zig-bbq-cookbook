// Analytics feature module
const std = @import("std");
const tracking = @import("analytics/tracking.zig");

// ANCHOR: analytics_types
pub const Event = struct {
    name: []const u8,
    user_id: u32,
    timestamp: u64,
};
// ANCHOR_END: analytics_types

// ANCHOR: analytics_state
// Simple in-memory event storage (for demonstration)
// WARNING: Global state is NOT thread-safe and for demonstration only.
// Production code should use explicit context structs passed to functions.
//
// Production alternative pattern:
//   const AnalyticsContext = struct {
//       event_count: usize = 0,
//       mutex: std.Thread.Mutex = .{},
//       pub fn track(self: *AnalyticsContext, event: Event) void { ... }
//   };
// Then pass *AnalyticsContext to functions instead of using global state.
var event_count: usize = 0;
// ANCHOR_END: analytics_state

// ANCHOR: track
pub fn track(event: Event) void {
    tracking.recordEvent(event);
    event_count += 1;
}
// ANCHOR_END: track

// ANCHOR: get_event_count
pub fn getEventCount() usize {
    return event_count;
}
// ANCHOR_END: get_event_count

// ANCHOR: reset
pub fn reset() void {
    event_count = 0;
}
// ANCHOR_END: reset
