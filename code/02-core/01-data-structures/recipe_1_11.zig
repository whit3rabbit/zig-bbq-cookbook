// Recipe 1.11: Naming Slices and Indices
// Target Zig Version: 0.15.2
//
// Demonstrates using named constants and descriptive patterns for slice operations.
// Run: zig test code/02-core/01-data-structures/recipe_1_11.zig

const std = @import("std");
const testing = std.testing;

// ==============================================================================
// Basic Named Indices
// ==============================================================================

// ANCHOR: named_indices
test "named indices for clarity" {
    const data = [_]i32{ 100, 200, 300, 400, 500 };

    // Clear semantic meaning
    const INDEX_QUANTITY = 0;
    const INDEX_PRICE = 2;
    const INDEX_DISCOUNT = 4;

    try testing.expectEqual(@as(i32, 100), data[INDEX_QUANTITY]);
    try testing.expectEqual(@as(i32, 300), data[INDEX_PRICE]);
    try testing.expectEqual(@as(i32, 500), data[INDEX_DISCOUNT]);
}
// ANCHOR_END: named_indices

test "named ranges for fixed-width record" {
    const record = "John Doe    Software Engineer       2024-01-15";

    const NAME_START = 0;
    const NAME_END = 12;
    const TITLE_START = 12;
    const TITLE_END = 36;
    const DATE_START = 36;

    const name = std.mem.trim(u8, record[NAME_START..NAME_END], " ");
    const title = std.mem.trim(u8, record[TITLE_START..TITLE_END], " ");
    const date = record[DATE_START..];

    try testing.expectEqualStrings("John Doe", name);
    try testing.expectEqualStrings("Software Engineer", title);
    try testing.expectEqualStrings("2024-01-15", date);
}

// ==============================================================================
// Struct-Based Field Descriptors
// ==============================================================================

// ANCHOR: field_range
const FieldRange = struct {
    start: usize,
    end: usize,

    pub fn slice(self: FieldRange, data: []const u8) []const u8 {
        return data[self.start..self.end];
    }

    pub fn sliceTrimmed(self: FieldRange, data: []const u8) []const u8 {
        return std.mem.trim(u8, data[self.start..self.end], " ");
    }
};

const PersonFields = struct {
    const name = FieldRange{ .start = 0, .end = 20 };
    const address = FieldRange{ .start = 20, .end = 50 };
    const phone = FieldRange{ .start = 50, .end = 62 };
// ANCHOR_END: field_range
};

test "struct-based field descriptors" {
    const record = "Alice Johnson       123 Main Street               555-1234    ";
    //              |<------ 20 ------>|<---------- 30 ---------->|<---- 12 --->|

    const name = PersonFields.name.sliceTrimmed(record);
    const address = PersonFields.address.sliceTrimmed(record);
    const phone = PersonFields.phone.sliceTrimmed(record);

    try testing.expectEqualStrings("Alice Johnson", name);
    try testing.expectEqualStrings("123 Main Street", address);
    try testing.expectEqualStrings("555-1234", phone);
}

test "reusable field range for multiple records" {
    const records = [_][]const u8{
        "Bob Smith           456 Oak Avenue                555-5678    ",
        "Carol White         789 Pine Road                 555-9012    ",
    };

    for (records, 0..) |record, i| {
        const name = PersonFields.name.sliceTrimmed(record);
        const phone = PersonFields.phone.sliceTrimmed(record);

        switch (i) {
            0 => {
                try testing.expectEqualStrings("Bob Smith", name);
                try testing.expectEqualStrings("555-5678", phone);
            },
            1 => {
                try testing.expectEqualStrings("Carol White", name);
                try testing.expectEqualStrings("555-9012", phone);
            },
            else => unreachable,
        }
    }
}

// ==============================================================================
// Named Array Positions with Semantic Meaning
// ==============================================================================

const RGB = struct {
    const RED = 0;
    const GREEN = 1;
    const BLUE = 2;
};

fn adjustBrightness(color: *[3]u8, factor: f32) void {
    color[RGB.RED] = @intFromFloat(@as(f32, @floatFromInt(color[RGB.RED])) * factor);
    color[RGB.GREEN] = @intFromFloat(@as(f32, @floatFromInt(color[RGB.GREEN])) * factor);
    color[RGB.BLUE] = @intFromFloat(@as(f32, @floatFromInt(color[RGB.BLUE])) * factor);
}

test "named array positions for RGB" {
    var color = [_]u8{ 100, 150, 200 };

    try testing.expectEqual(@as(u8, 100), color[RGB.RED]);
    try testing.expectEqual(@as(u8, 150), color[RGB.GREEN]);
    try testing.expectEqual(@as(u8, 200), color[RGB.BLUE]);

    adjustBrightness(&color, 1.2);

    try testing.expectEqual(@as(u8, 120), color[RGB.RED]);
    try testing.expectEqual(@as(u8, 180), color[RGB.GREEN]);
    try testing.expectEqual(@as(u8, 240), color[RGB.BLUE]);
}

// ==============================================================================
// Comptime Field Descriptors
// ==============================================================================

fn Field(comptime start: usize, comptime end: usize) type {
    return struct {
        pub inline fn get(data: []const u8) []const u8 {
            return data[start..end];
        }

        pub inline fn getTrimmed(data: []const u8) []const u8 {
            return std.mem.trim(u8, data[start..end], " ");
        }

        pub const range = .{ start, end };
        pub const length = end - start;
    };
}

const Record = struct {
    pub const Name = Field(0, 20);
    pub const Email = Field(20, 50);
    pub const Age = Field(50, 53);
};

test "comptime field descriptors" {
    const data = "John Smith          john@example.com              35 ";

    const name = Record.Name.getTrimmed(data);
    const email = Record.Email.getTrimmed(data);
    const age_str = Record.Age.getTrimmed(data);

    try testing.expectEqualStrings("John Smith", name);
    try testing.expectEqualStrings("john@example.com", email);
    try testing.expectEqualStrings("35", age_str);

    // Verify comptime-known lengths
    comptime {
        try testing.expectEqual(20, Record.Name.length);
        try testing.expectEqual(30, Record.Email.length);
        try testing.expectEqual(3, Record.Age.length);
    }
}

// ==============================================================================
// Binary Protocol Fields
// ==============================================================================

// ANCHOR: packet_header
const PacketHeader = struct {
    const VERSION_BYTE = 0;
    const TYPE_BYTE = 1;
    const LENGTH_START = 2;
    const LENGTH_END = 4;
    const CHECKSUM_START = 4;
    const CHECKSUM_END = 8;
    const PAYLOAD_START = 8;

    pub fn version(packet: []const u8) u8 {
        return packet[VERSION_BYTE];
    }

    pub fn packetType(packet: []const u8) u8 {
        return packet[TYPE_BYTE];
    }

    pub fn length(packet: []const u8) u16 {
        return std.mem.readInt(u16, packet[LENGTH_START..LENGTH_END][0..2], .big);
    }

    pub fn checksum(packet: []const u8) u32 {
        return std.mem.readInt(u32, packet[CHECKSUM_START..CHECKSUM_END][0..4], .big);
    }

    pub fn payload(packet: []const u8) []const u8 {
        return packet[PAYLOAD_START..];
    }
};
// ANCHOR_END: packet_header

test "binary protocol field access" {
    const allocator = testing.allocator;

    // Build a test packet
    var packet = try allocator.alloc(u8, 20);
    defer allocator.free(packet);

    packet[PacketHeader.VERSION_BYTE] = 1;
    packet[PacketHeader.TYPE_BYTE] = 42;
    std.mem.writeInt(u16, packet[PacketHeader.LENGTH_START..PacketHeader.LENGTH_END][0..2], 12, .big);
    std.mem.writeInt(u32, packet[PacketHeader.CHECKSUM_START..PacketHeader.CHECKSUM_END][0..4], 0xDEADBEEF, .big);
    @memcpy(packet[PacketHeader.PAYLOAD_START..], "Hello World!");

    try testing.expectEqual(@as(u8, 1), PacketHeader.version(packet));
    try testing.expectEqual(@as(u8, 42), PacketHeader.packetType(packet));
    try testing.expectEqual(@as(u16, 12), PacketHeader.length(packet));
    try testing.expectEqual(@as(u32, 0xDEADBEEF), PacketHeader.checksum(packet));
    try testing.expectEqualStrings("Hello World!", PacketHeader.payload(packet));
}

// ==============================================================================
// Matrix/Grid Access
// ==============================================================================

const Grid = struct {
    data: []i32,
    width: usize,
    height: usize,

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Grid {
        return Grid{
            .data = try allocator.alloc(i32, width * height),
            .width = width,
            .height = height,
        };
    }

    pub fn deinit(self: *Grid, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }

    pub fn index(self: Grid, row_idx: usize, col: usize) usize {
        return row_idx * self.width + col;
    }

    pub fn get(self: Grid, row_idx: usize, col: usize) i32 {
        return self.data[self.index(row_idx, col)];
    }

    pub fn set(self: *Grid, row_idx: usize, col: usize, value: i32) void {
        self.data[self.index(row_idx, col)] = value;
    }

    pub fn row(self: Grid, row_num: usize) []i32 {
        const start = row_num * self.width;
        return self.data[start..][0..self.width];
    }
};

test "grid with named position access" {
    const allocator = testing.allocator;

    var grid = try Grid.init(allocator, 3, 3);
    defer grid.deinit(allocator);

    // Initialize with values
    var val: i32 = 1;
    var r: usize = 0;
    while (r < 3) : (r += 1) {
        var c: usize = 0;
        while (c < 3) : (c += 1) {
            grid.set(r, c, val);
            val += 1;
        }
    }

    // Named access is much clearer than raw indexing
    const ROW_TOP = 0;
    const ROW_MIDDLE = 1;
    const ROW_BOTTOM = 2;
    const COL_LEFT = 0;
    const COL_CENTER = 1;
    const COL_RIGHT = 2;

    try testing.expectEqual(@as(i32, 1), grid.get(ROW_TOP, COL_LEFT));
    try testing.expectEqual(@as(i32, 5), grid.get(ROW_MIDDLE, COL_CENTER));
    try testing.expectEqual(@as(i32, 9), grid.get(ROW_BOTTOM, COL_RIGHT));

    // Test row extraction
    const middle_row = grid.row(ROW_MIDDLE);
    try testing.expectEqual(@as(i32, 4), middle_row[0]);
    try testing.expectEqual(@as(i32, 5), middle_row[1]);
    try testing.expectEqual(@as(i32, 6), middle_row[2]);
}

// ==============================================================================
// Fixed-Width Record Parser
// ==============================================================================

const RecordParser = struct {
    const RecordField = struct {
        name: []const u8,
        start: usize,
        length: usize,

        pub fn extract(self: RecordField, record: []const u8) []const u8 {
            return std.mem.trim(u8, record[self.start..][0..self.length], " ");
        }
    };

    fields: []const RecordField,

    pub fn parse(self: RecordParser, record: []const u8, allocator: std.mem.Allocator) !std.StringHashMap([]const u8) {
        var result = std.StringHashMap([]const u8).init(allocator);
        errdefer result.deinit();

        for (self.fields) |field| {
            const value = field.extract(record);
            try result.put(field.name, value);
        }

        return result;
    }
};

test "fixed-width record parser" {
    const allocator = testing.allocator;

    const employee_fields = [_]RecordParser.RecordField{
        .{ .name = "id", .start = 0, .length = 6 },
        .{ .name = "name", .start = 6, .length = 30 },
        .{ .name = "department", .start = 36, .length = 20 },
        .{ .name = "salary", .start = 56, .length = 10 },
    };

    const parser = RecordParser{ .fields = &employee_fields };
    const record = "E12345Alice Johnson                 Engineering         75000     ";
    //              |<-6->|<---------- 30 ---------->|<------ 20 ----->|<-- 10 ->|

    var parsed = try parser.parse(record, allocator);
    defer parsed.deinit();

    try testing.expectEqualStrings("E12345", parsed.get("id").?);
    try testing.expectEqualStrings("Alice Johnson", parsed.get("name").?);
    try testing.expectEqualStrings("Engineering", parsed.get("department").?);
    try testing.expectEqualStrings("75000", parsed.get("salary").?);
}

// ==============================================================================
// Enum-Based Indexing
// ==============================================================================

const Stat = enum(usize) {
    health = 0,
    mana = 1,
    stamina = 2,
    strength = 3,

    pub fn get(self: Stat, stats: []const i32) i32 {
        return stats[@intFromEnum(self)];
    }

    pub fn set(self: Stat, stats: []i32, value: i32) void {
        stats[@intFromEnum(self)] = value;
    }

    pub fn modify(self: Stat, stats: []i32, delta: i32) void {
        stats[@intFromEnum(self)] += delta;
    }
};

test "enum-based array indexing" {
    var stats = [_]i32{ 100, 50, 75, 20 };

    // Much clearer than stats[0], stats[1], etc.
    try testing.expectEqual(@as(i32, 100), Stat.health.get(&stats));
    try testing.expectEqual(@as(i32, 50), Stat.mana.get(&stats));
    try testing.expectEqual(@as(i32, 75), Stat.stamina.get(&stats));
    try testing.expectEqual(@as(i32, 20), Stat.strength.get(&stats));

    // Modify stats
    Stat.health.modify(&stats, -10);
    Stat.mana.modify(&stats, 15);

    try testing.expectEqual(@as(i32, 90), Stat.health.get(&stats));
    try testing.expectEqual(@as(i32, 65), Stat.mana.get(&stats));
}

// ==============================================================================
// HTTP Request Parsing with Re-slicing
// ==============================================================================

const HttpRequest = struct {
    raw: []const u8,

    pub fn method(self: HttpRequest) ?[]const u8 {
        const space_pos = std.mem.indexOfScalar(u8, self.raw, ' ') orelse return null;
        return self.raw[0..space_pos];
    }

    pub fn path(self: HttpRequest) ?[]const u8 {
        const first_space = std.mem.indexOfScalar(u8, self.raw, ' ') orelse return null;
        const remaining = self.raw[first_space + 1 ..];
        const second_space = std.mem.indexOfScalar(u8, remaining, ' ') orelse return null;
        return remaining[0..second_space];
    }

    pub fn version(self: HttpRequest) ?[]const u8 {
        const first_space = std.mem.indexOfScalar(u8, self.raw, ' ') orelse return null;
        const remaining = self.raw[first_space + 1 ..];
        const second_space = std.mem.indexOfScalar(u8, remaining, ' ') orelse return null;
        const after_path = remaining[second_space + 1 ..];
        const newline = std.mem.indexOfScalar(u8, after_path, '\n') orelse return null;
        return std.mem.trim(u8, after_path[0..newline], "\r");
    }
};

test "HTTP request parsing with named re-slicing" {
    const request_line = "GET /api/users HTTP/1.1\n";
    const req = HttpRequest{ .raw = request_line };

    const method_str = req.method().?;
    const path_str = req.path().?;
    const version_str = req.version().?;

    try testing.expectEqualStrings("GET", method_str);
    try testing.expectEqualStrings("/api/users", path_str);
    try testing.expectEqualStrings("HTTP/1.1", version_str);
}

test "HTTP request with POST method" {
    const request_line = "POST /submit HTTP/1.0\r\n";
    const req = HttpRequest{ .raw = request_line };

    try testing.expectEqualStrings("POST", req.method().?);
    try testing.expectEqualStrings("/submit", req.path().?);
    try testing.expectEqualStrings("HTTP/1.0", req.version().?);
}

// ==============================================================================
// Common Named Patterns
// ==============================================================================

const CSV = struct {
    const NAME = 0;
    const AGE = 1;
    const EMAIL = 2;
    const PHONE = 3;
};

const Time = struct {
    const HOUR = 0;
    const MINUTE = 1;
    const SECOND = 2;
};

const Color = struct {
    const R = 0;
    const G = 1;
    const B = 2;
    const A = 3;
};

test "common CSV column pattern" {
    const row = [_][]const u8{ "Alice", "30", "alice@example.com", "555-1234" };

    try testing.expectEqualStrings("Alice", row[CSV.NAME]);
    try testing.expectEqualStrings("30", row[CSV.AGE]);
    try testing.expectEqualStrings("alice@example.com", row[CSV.EMAIL]);
    try testing.expectEqualStrings("555-1234", row[CSV.PHONE]);
}

test "time component array" {
    const time = [_]u8{ 14, 30, 45 };

    try testing.expectEqual(@as(u8, 14), time[Time.HOUR]);
    try testing.expectEqual(@as(u8, 30), time[Time.MINUTE]);
    try testing.expectEqual(@as(u8, 45), time[Time.SECOND]);
}

test "RGBA color components" {
    const color = [_]u8{ 255, 128, 64, 200 };

    try testing.expectEqual(@as(u8, 255), color[Color.R]);
    try testing.expectEqual(@as(u8, 128), color[Color.G]);
    try testing.expectEqual(@as(u8, 64), color[Color.B]);
    try testing.expectEqual(@as(u8, 200), color[Color.A]);
}

// ==============================================================================
// Edge Cases and Safety
// ==============================================================================

test "empty slice handling" {
    const data: []const u8 = &[_]u8{};
    const req = HttpRequest{ .raw = data };

    try testing.expect(req.method() == null);
    try testing.expect(req.path() == null);
    try testing.expect(req.version() == null);
}

test "named indices don't exceed bounds" {
    const data = [_]i32{ 1, 2, 3 };

    const VALID_INDEX = 2;
    const value = data[VALID_INDEX];

    try testing.expectEqual(@as(i32, 3), value);
}

test "field range extraction with exact boundaries" {
    const range = FieldRange{ .start = 0, .end = 5 };
    const data = "Hello World";

    const extracted = range.slice(data);
    try testing.expectEqualStrings("Hello", extracted);
}

test "comptime field length validation" {
    comptime {
        const TestRecord = struct {
            pub const Field1 = Field(0, 10);
            pub const Field2 = Field(10, 25);
        };

        // Verify no overlap
        try testing.expect(TestRecord.Field1.range[1] == TestRecord.Field2.range[0]);
    }
}
