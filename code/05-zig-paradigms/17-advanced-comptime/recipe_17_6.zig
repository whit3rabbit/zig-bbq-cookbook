// Recipe 17.6: Build-Time Resource Embedding
// This recipe demonstrates how to embed files, generate lookup tables, and
// compile assets into your binary using @embedFile and comptime processing.

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_embed
/// Embed a text file directly into the binary
const embedded_message = @embedFile("assets/message.txt");

test "basic file embedding" {
    try testing.expect(embedded_message.len > 0);
    try testing.expect(std.mem.indexOf(u8, embedded_message, "Hello") != null);
}
// ANCHOR_END: basic_embed

// ANCHOR: parse_at_comptime
/// Parse embedded configuration at compile time
const embedded_config = @embedFile("assets/config.txt");

fn parseConfig(comptime content: []const u8) type {
    @setEvalBranchQuota(10000);

    var line_count: usize = 0;
    var pos: usize = 0;

    // Count lines
    while (pos < content.len) : (pos += 1) {
        if (content[pos] == '\n') {
            line_count += 1;
        }
    }

    // Parse key-value pairs
    var fields: [line_count]std.builtin.Type.StructField = undefined;
    var field_idx: usize = 0;
    var line_start: usize = 0;

    pos = 0;
    while (pos < content.len) : (pos += 1) {
        if (content[pos] == '\n' or pos == content.len - 1) {
            const line_end = if (content[pos] == '\n') pos else pos + 1;
            const line = content[line_start..line_end];

            // Find '=' separator
            for (line, 0..) |char, i| {
                if (char == '=') {
                    const key = line[0..i];

                    // Create field with null-terminated name
                    const key_z = key ++ "";
                    fields[field_idx] = .{
                        .name = key_z[0..key.len :0],
                        .type = []const u8,
                        .default_value_ptr = null,
                        .is_comptime = false,
                        .alignment = @alignOf([]const u8),
                    };
                    field_idx += 1;
                    break;
                }
            }

            line_start = pos + 1;
        }
    }

    return @Type(.{
        .@"struct" = .{
            .layout = .auto,
            .fields = fields[0..field_idx],
            .decls = &[_]std.builtin.Type.Declaration{},
            .is_tuple = false,
        },
    });
}

test "parse config at compile time" {
    const ConfigType = parseConfig(embedded_config);

    // Verify the type has the expected fields
    const type_info = @typeInfo(ConfigType);
    try testing.expect(type_info == .@"struct");
    try testing.expect(type_info.@"struct".fields.len == 3);
}
// ANCHOR_END: parse_at_comptime

// ANCHOR: lookup_table
/// Generate a lookup table from embedded data
fn generateLookupTable(comptime data: []const u8) [256]u8 {
    var table: [256]u8 = undefined;

    // Simple transformation: rotate each byte value
    for (0..256) |i| {
        table[i] = @as(u8, @intCast((i + data.len) % 256));
    }

    return table;
}

const lookup = generateLookupTable(embedded_message);

test "generated lookup table" {
    try testing.expect(lookup.len == 256);

    // Verify it's a valid lookup table
    for (lookup) |value| {
        try testing.expect(value < 256);
    }
}
// ANCHOR_END: lookup_table

// ANCHOR: hash_at_comptime
/// Compute hash of embedded file at compile time
fn simpleHash(comptime data: []const u8) u64 {
    var hash: u64 = 0;
    for (data) |byte| {
        hash = hash *% 31 +% byte;
    }
    return hash;
}

const file_hash = simpleHash(embedded_message);

test "compile-time hash" {
    // Hash is computed once at compile time
    try testing.expect(file_hash != 0);

    // Verify it matches runtime calculation
    const runtime_hash = simpleHash(embedded_message);
    try testing.expectEqual(file_hash, runtime_hash);
}
// ANCHOR_END: hash_at_comptime

// ANCHOR: resource_map
/// Create a resource map at compile time
const ResourceEntry = struct {
    name: []const u8,
    content: []const u8,
    size: usize,
};

fn createResourceMap(comptime resources: []const ResourceEntry) type {
    return struct {
        pub fn get(name: []const u8) ?[]const u8 {
            inline for (resources) |resource| {
                if (std.mem.eql(u8, resource.name, name)) {
                    return resource.content;
                }
            }
            return null;
        }

        pub fn getSize(name: []const u8) ?usize {
            inline for (resources) |resource| {
                if (std.mem.eql(u8, resource.name, name)) {
                    return resource.size;
                }
            }
            return null;
        }

        pub fn list() []const []const u8 {
            comptime {
                var names: [resources.len][]const u8 = undefined;
                for (resources, 0..) |resource, i| {
                    names[i] = resource.name;
                }
                const final_names = names;
                return &final_names;
            }
        }
    };
}

const Resources = createResourceMap(&[_]ResourceEntry{
    .{
        .name = "message",
        .content = @embedFile("assets/message.txt"),
        .size = @embedFile("assets/message.txt").len,
    },
    .{
        .name = "config",
        .content = @embedFile("assets/config.txt"),
        .size = @embedFile("assets/config.txt").len,
    },
});

test "resource map" {
    const message = Resources.get("message");
    try testing.expect(message != null);
    try testing.expect(message.?.len > 0);

    const config = Resources.get("config");
    try testing.expect(config != null);

    const missing = Resources.get("nonexistent");
    try testing.expectEqual(@as(?[]const u8, null), missing);

    const size = Resources.getSize("message");
    try testing.expect(size != null);
    try testing.expectEqual(message.?.len, size.?);
}
// ANCHOR_END: resource_map

// ANCHOR: version_info
/// Embed version information at compile time
const version_info = struct {
    const major = 1;
    const minor = 0;
    const patch = 0;
    const git_hash = "abc123"; // Would come from build system

    pub fn string() []const u8 {
        return comptime std.fmt.comptimePrint(
            "{d}.{d}.{d}-{s}",
            .{ major, minor, patch, git_hash },
        );
    }

    pub fn full() []const u8 {
        return comptime std.fmt.comptimePrint(
            "Version {d}.{d}.{d} (commit {s})",
            .{ major, minor, patch, git_hash },
        );
    }
};

test "version embedding" {
    const ver = version_info.string();
    try testing.expectEqualStrings("1.0.0-abc123", ver);

    const full = version_info.full();
    try testing.expect(std.mem.indexOf(u8, full, "Version") != null);
}
// ANCHOR_END: version_info

// ANCHOR: string_interner
/// String interner for embedded strings
fn StringInterner(comptime strings: []const []const u8) type {
    return struct {
        pub fn getId(str: []const u8) ?usize {
            inline for (strings, 0..) |s, i| {
                if (std.mem.eql(u8, s, str)) {
                    return i;
                }
            }
            return null;
        }

        pub fn getString(id: usize) ?[]const u8 {
            if (id >= strings.len) return null;
            return strings[id];
        }

        pub fn count() usize {
            return strings.len;
        }
    };
}

const Strings = StringInterner(&[_][]const u8{
    "error",
    "warning",
    "info",
    "debug",
});

test "string interner" {
    const error_id = Strings.getId("error");
    try testing.expectEqual(@as(?usize, 0), error_id);

    const info_id = Strings.getId("info");
    try testing.expectEqual(@as(?usize, 2), info_id);

    const str = Strings.getString(1);
    try testing.expectEqualStrings("warning", str.?);

    try testing.expectEqual(@as(usize, 4), Strings.count());
}
// ANCHOR_END: string_interner

// ANCHOR: asset_compression
/// Simple run-length encoding at compile time
fn compressRLE(comptime data: []const u8) []const u8 {
    @setEvalBranchQuota(100000);

    var result: []const u8 = "";
    var i: usize = 0;

    while (i < data.len) {
        const byte = data[i];
        var count: usize = 1;

        // Count consecutive identical bytes
        while (i + count < data.len and data[i + count] == byte and count < 255) {
            count += 1;
        }

        // Append count and byte
        const count_byte = [_]u8{@as(u8, @intCast(count))};
        const value_byte = [_]u8{byte};
        result = result ++ &count_byte ++ &value_byte;

        i += count;
    }

    return result;
}

test "compile-time compression" {
    const original = "aaabbbccc";
    const compressed = comptime compressRLE(original);

    // RLE format: count, byte, count, byte, ...
    try testing.expect(compressed.len < original.len or compressed.len == original.len * 2);

    // First run: 3x 'a'
    try testing.expectEqual(@as(u8, 3), compressed[0]);
    try testing.expectEqual(@as(u8, 'a'), compressed[1]);
}
// ANCHOR_END: asset_compression

// ANCHOR: build_metadata
/// Embed build-time metadata
const build_info = struct {
    const timestamp = "2025-01-20T12:00:00Z"; // Would come from build system
    const compiler = "zig 0.15.2";
    const target = "x86_64-linux";

    pub fn summary() []const u8 {
        return comptime std.fmt.comptimePrint(
            "Built: {s} | Compiler: {s} | Target: {s}",
            .{ timestamp, compiler, target },
        );
    }
};

test "build metadata" {
    const info = build_info.summary();
    try testing.expect(std.mem.indexOf(u8, info, "Built:") != null);
    try testing.expect(std.mem.indexOf(u8, info, "Compiler:") != null);
    try testing.expect(std.mem.indexOf(u8, info, "Target:") != null);
}
// ANCHOR_END: build_metadata
