// Recipe 8.4: Saving Memory When Creating Many Instances
// Target Zig Version: 0.15.2

const std = @import("std");

// ANCHOR: basic_packed
// Basic packed struct
const CompactFlags = packed struct {
    is_active: bool,
    is_visible: bool,
    is_enabled: bool,
    priority: u5,
};
// ANCHOR_END: basic_packed

test "packed struct size" {
    try std.testing.expectEqual(@as(usize, 1), @sizeOf(CompactFlags));

    const flags = CompactFlags{
        .is_active = true,
        .is_visible = false,
        .is_enabled = true,
        .priority = 10,
    };

    try std.testing.expect(flags.is_active);
    try std.testing.expect(!flags.is_visible);
    try std.testing.expectEqual(@as(u5, 10), flags.priority);
}

// ANCHOR: size_comparison
// Normal vs packed comparison
const NormalFlags = struct {
    is_active: bool,
    is_visible: bool,
    is_enabled: bool,
    count: u8,
};

const PackedFlags = packed struct {
    is_active: bool,
    is_visible: bool,
    is_enabled: bool,
    count: u5,
};

test "normal vs packed" {
    const normal_size = @sizeOf(NormalFlags);
    try std.testing.expect(normal_size >= 4);

    const packed_size = @sizeOf(PackedFlags);
    try std.testing.expectEqual(@as(usize, 1), packed_size);
}
// ANCHOR_END: size_comparison

// Color packing
const RGBColor = packed struct {
    red: u8,
    green: u8,
    blue: u8,
};

const CompactColor = packed struct {
    red: u5,
    green: u6,
    blue: u5,
};

test "color packing" {
    // RGBColor may be padded for alignment
    try std.testing.expect(@sizeOf(RGBColor) >= 3);

    // CompactColor saves space vs full u8 fields
    try std.testing.expect(@sizeOf(CompactColor) <= @sizeOf(RGBColor));

    const color = CompactColor{
        .red = 31,
        .green = 63,
        .blue = 31,
    };

    try std.testing.expectEqual(@as(u5, 31), color.red);
    try std.testing.expectEqual(@as(u6, 63), color.green);
}

// Network packet header
const PacketHeader = packed struct {
    version: u4,
    packet_type: u4,
    flags: u8,
    length: u16,
};

test "packet header" {
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(PacketHeader));

    const header = PacketHeader{
        .version = 1,
        .packet_type = 5,
        .flags = 0x80,
        .length = 1024,
    };

    const bytes: *const [4]u8 = @ptrCast(&header);
    _ = bytes;
}

// Game entity
const Entity = packed struct {
    can_move: bool,
    can_jump: bool,
    can_fly: bool,
    can_swim: bool,
    is_hostile: bool,
    is_invulnerable: bool,
    can_attack: bool,
    _padding1: bool,
    is_visible: bool,
    casts_shadow: bool,
    receives_shadow: bool,
    _padding2: u5,
    health_percent: u8,
};

test "game entity" {
    // Packed struct may be padded for alignment
    try std.testing.expect(@sizeOf(Entity) <= 8);

    var entity = Entity{
        .can_move = true,
        .can_jump = true,
        .can_fly = false,
        .can_swim = false,
        .is_hostile = true,
        .is_invulnerable = false,
        .can_attack = true,
        ._padding1 = false,
        .is_visible = true,
        .casts_shadow = true,
        .receives_shadow = true,
        ._padding2 = 0,
        .health_percent = 100,
    };

    try std.testing.expect(entity.can_move);
    try std.testing.expectEqual(@as(u8, 100), entity.health_percent);

    entity.health_percent = 50;
    try std.testing.expectEqual(@as(u8, 50), entity.health_percent);
}

// File header
const FileHeader = packed struct {
    magic: u32,
    version_major: u8,
    version_minor: u8,
    flags: u16,
    entry_count: u32,
    reserved: u64,
};

test "file header" {
    // FileHeader contains u64, so may be aligned to 8 bytes
    try std.testing.expect(@sizeOf(FileHeader) >= 16);

    const header = FileHeader{
        .magic = 0x12345678,
        .version_major = 1,
        .version_minor = 0,
        .flags = 0,
        .entry_count = 42,
        .reserved = 0,
    };

    try std.testing.expectEqual(@as(u32, 0x12345678), header.magic);
}

// ANCHOR: enum_packing
// Enum-based packing
const Priority = enum(u2) {
    low = 0,
    medium = 1,
    high = 2,
    critical = 3,
};

const Status = enum(u2) {
    idle = 0,
    running = 1,
    paused = 2,
    stopped = 3,
};

const Task = packed struct {
    priority: Priority,
    status: Status,
    is_async: bool,
    is_cancellable: bool,
    progress: u8,
    _padding: u4,
};

test "task packing" {
    // Packed struct may be aligned to word boundary
    try std.testing.expect(@sizeOf(Task) <= 4);

    const task = Task{
        .priority = .high,
        .status = .running,
        .is_async = true,
        .is_cancellable = true,
        .progress = 75,
        ._padding = 0,
    };

    try std.testing.expectEqual(Priority.high, task.priority);
    try std.testing.expectEqual(Status.running, task.status);
}
// ANCHOR_END: enum_packing

// Date/time packing
const CompactDateTime = packed struct {
    year: u12,
    month: u4,
    day: u5,
    hour: u5,
    minute: u6,
    second: u6,
};

test "datetime packing" {
    const dt = CompactDateTime{
        .year = 2024,
        .month = 11,
        .day = 13,
        .hour = 14,
        .minute = 30,
        .second = 45,
    };

    try std.testing.expectEqual(@as(u12, 2024), dt.year);
    try std.testing.expectEqual(@as(u4, 11), dt.month);
    try std.testing.expectEqual(@as(u5, 13), dt.day);
}

// Permissions
const Permissions = packed struct {
    owner_read: bool,
    owner_write: bool,
    owner_execute: bool,
    group_read: bool,
    group_write: bool,
    group_execute: bool,
    others_read: bool,
    others_write: bool,
    others_execute: bool,
    setuid: bool,
    setgid: bool,
    sticky: bool,
    _padding: u4,
};

test "permissions" {
    try std.testing.expectEqual(@as(usize, 2), @sizeOf(Permissions));

    const perms = Permissions{
        .owner_read = true,
        .owner_write = true,
        .owner_execute = true,
        .group_read = true,
        .group_write = false,
        .group_execute = true,
        .others_read = true,
        .others_write = false,
        .others_execute = false,
        .setuid = false,
        .setgid = false,
        .sticky = false,
        ._padding = 0,
    };

    try std.testing.expect(perms.owner_read);
    try std.testing.expect(!perms.group_write);
}

// Field ordering optimization
const UnoptimizedStruct = struct {
    flag1: bool,
    value1: u64,
    flag2: bool,
    value2: u64,
};

const OptimizedStruct = struct {
    value1: u64,
    value2: u64,
    flag1: bool,
    flag2: bool,
};

test "field ordering" {
    const unopt_size = @sizeOf(UnoptimizedStruct);
    const opt_size = @sizeOf(OptimizedStruct);

    try std.testing.expect(opt_size <= unopt_size);
}

// Array comparison
test "array memory comparison" {
    const NormalItem = struct {
        active: bool,
        id: u16,
        flags: u8,
    };

    const PackedItem = packed struct {
        active: bool,
        id: u16,
        flags: u8,
    };

    const count = 10000;

    const normal_total = @sizeOf(NormalItem) * count;
    const packed_total = @sizeOf(PackedItem) * count;

    try std.testing.expect(packed_total <= normal_total);
}

// Comprehensive test
test "comprehensive packing" {
    const flags = CompactFlags{
        .is_active = true,
        .is_visible = true,
        .is_enabled = false,
        .priority = 15,
    };

    const color = CompactColor{
        .red = 20,
        .green = 40,
        .blue = 25,
    };

    const task = Task{
        .priority = .medium,
        .status = .running,
        .is_async = false,
        .is_cancellable = true,
        .progress = 50,
        ._padding = 0,
    };

    try std.testing.expect(flags.is_active);
    try std.testing.expectEqual(@as(u5, 20), color.red);
    try std.testing.expectEqual(Priority.medium, task.priority);
}
