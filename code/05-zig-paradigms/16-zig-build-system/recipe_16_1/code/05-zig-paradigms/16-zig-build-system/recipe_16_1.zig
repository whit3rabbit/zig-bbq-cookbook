const std = @import("std");
const testing = std.testing;

// ANCHOR: build_concepts
pub const BuildMode = enum {
    Debug,
    ReleaseSafe,
    ReleaseFast,
    ReleaseSmall,
};

test "build modes exist" {
    const mode: BuildMode = .Debug;
    try testing.expect(mode == .Debug);
}
// ANCHOR_END: build_concepts
