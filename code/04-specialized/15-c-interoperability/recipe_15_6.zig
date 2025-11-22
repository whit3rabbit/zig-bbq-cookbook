const std = @import("std");
const testing = std.testing;

const c = @cImport({
    @cInclude("string.h");
    @cInclude("stdlib.h");
});

// ANCHOR: sentinel_pointer
// Using sentinel-terminated pointers for C strings
export fn get_string_length(str: [*:0]const u8) usize {
    return c.strlen(str);
}

test "sentinel-terminated pointers" {
    const text = "Hello, World!";
    const len = get_string_length(text.ptr);
    try testing.expectEqual(@as(usize, 13), len);
}
// ANCHOR_END: sentinel_pointer

// ANCHOR: zig_to_c_string
// Convert Zig string to C string
export fn process_zig_string(str: [*:0]const u8) c_int {
    var len: c_int = 0;
    while (str[@as(usize, @intCast(len))] != 0) {
        len += 1;
    }
    return len;
}

test "passing Zig strings to C" {
    const message = "Zig string";
    const result = process_zig_string(message.ptr);
    try testing.expectEqual(@as(c_int, 10), result);
}
// ANCHOR_END: zig_to_c_string

// ANCHOR: allocate_c_string
// Allocate NULL-terminated string for C
pub fn createCString(allocator: std.mem.Allocator, str: []const u8) ![*:0]u8 {
    const result = try allocator.allocSentinel(u8, str.len, 0);
    @memcpy(result, str);
    return result;
}

pub fn freeCString(allocator: std.mem.Allocator, str: [*:0]u8) void {
    const len = c.strlen(str);
    const slice = str[0 .. len + 1];
    allocator.free(slice);
}

test "allocating C strings" {
    const allocator = testing.allocator;
    const c_str = try createCString(allocator, "test string");
    defer freeCString(allocator, c_str);

    const len = c.strlen(c_str);
    try testing.expectEqual(@as(usize, 11), len);
}
// ANCHOR_END: allocate_c_string

// ANCHOR: string_conversion
// Convert between Zig and C strings
pub const StringConv = struct {
    pub fn fromC(str: [*:0]const u8) []const u8 {
        const len = c.strlen(str);
        return str[0..len];
    }

    pub fn toC(allocator: std.mem.Allocator, str: []const u8) ![*:0]u8 {
        return try allocator.dupeZ(u8, str);
    }

    pub fn freeC(allocator: std.mem.Allocator, str: [*:0]u8) void {
        const len = c.strlen(str);
        allocator.free(str[0 .. len + 1]);
    }
};

test "string conversion utilities" {
    const allocator = testing.allocator;

    // Zig to C
    const zig_str = "Hello from Zig";
    const c_str = try StringConv.toC(allocator, zig_str);
    defer StringConv.freeC(allocator, c_str);

    // C to Zig
    const back_to_zig = StringConv.fromC(c_str);
    try testing.expect(std.mem.eql(u8, back_to_zig, zig_str));
}
// ANCHOR_END: string_conversion

// ANCHOR: string_array
// Working with arrays of C strings
export fn count_strings(strings: [*]const [*:0]const u8, count: usize) usize {
    var total_length: usize = 0;
    for (0..count) |i| {
        total_length += c.strlen(strings[i]);
    }
    return total_length;
}

test "array of C strings" {
    const str1 = "hello";
    const str2 = "world";
    const str3 = "test";

    const strings = [_][*:0]const u8{ str1.ptr, str2.ptr, str3.ptr };
    const total = count_strings(&strings, 3);
    try testing.expectEqual(@as(usize, 14), total);
}
// ANCHOR_END: string_array

// ANCHOR: string_concatenation
// Concatenate C strings
pub fn concatenateCStrings(allocator: std.mem.Allocator, s1: [*:0]const u8, s2: [*:0]const u8) ![*:0]u8 {
    const len1 = c.strlen(s1);
    const len2 = c.strlen(s2);
    const result = try allocator.allocSentinel(u8, len1 + len2, 0);

    @memcpy(result[0..len1], s1[0..len1]);
    @memcpy(result[len1 .. len1 + len2], s2[0..len2]);

    return result;
}

test "concatenating C strings" {
    const allocator = testing.allocator;
    const s1 = "Hello, ";
    const s2 = "World!";

    const result = try concatenateCStrings(allocator, s1.ptr, s2.ptr);
    defer {
        const len = c.strlen(result);
        allocator.free(result[0 .. len + 1]);
    }

    const as_slice = StringConv.fromC(result);
    try testing.expect(std.mem.eql(u8, as_slice, "Hello, World!"));
}
// ANCHOR_END: string_concatenation

// ANCHOR: string_comparison
// String comparison with C functions
export fn compare_strings(s1: [*:0]const u8, s2: [*:0]const u8) c_int {
    return c.strcmp(s1, s2);
}

export fn compare_strings_n(s1: [*:0]const u8, s2: [*:0]const u8, n: usize) c_int {
    return c.strncmp(s1, s2, n);
}

test "string comparison" {
    const s1 = "apple";
    const s2 = "banana";
    const s3 = "apple";

    const cmp1 = compare_strings(s1.ptr, s2.ptr);
    try testing.expect(cmp1 < 0);

    const cmp2 = compare_strings(s1.ptr, s3.ptr);
    try testing.expectEqual(@as(c_int, 0), cmp2);

    const cmp3 = compare_strings_n(s1.ptr, s2.ptr, 1);
    try testing.expect(cmp3 < 0);
}
// ANCHOR_END: string_comparison

// ANCHOR: string_search
// Search operations on C strings
pub const StringSearch = struct {
    pub fn find(haystack: [*:0]const u8, needle: [*:0]const u8) ?[*:0]const u8 {
        const result = c.strstr(haystack, needle);
        return result;
    }

    pub fn findChar(str: [*:0]const u8, ch: c_int) ?[*:0]const u8 {
        const result = c.strchr(str, ch);
        return result;
    }

    pub fn findLastChar(str: [*:0]const u8, ch: c_int) ?[*:0]const u8 {
        const result = c.strrchr(str, ch);
        return result;
    }
};

test "string search operations" {
    const text = "Hello, World! Hello!";

    const found = StringSearch.find(text.ptr, "World");
    try testing.expect(found != null);

    const char_pos = StringSearch.findChar(text.ptr, 'W');
    try testing.expect(char_pos != null);

    const last_h = StringSearch.findLastChar(text.ptr, 'H');
    try testing.expect(last_h != null);
}
// ANCHOR_END: string_search

// ANCHOR: string_manipulation
// String manipulation with C functions
export fn to_uppercase_c(str: [*]u8, len: usize) void {
    for (0..len) |i| {
        if (str[i] >= 'a' and str[i] <= 'z') {
            str[i] -= 32;
        }
    }
}

export fn copy_string(dest: [*]u8, src: [*:0]const u8, max_len: usize) void {
    _ = c.strncpy(dest, src, max_len);
}

test "string manipulation" {
    var buffer: [20]u8 = undefined;

    // Copy string
    const source = "hello";
    copy_string(&buffer, source.ptr, buffer.len);

    // Convert to uppercase
    to_uppercase_c(&buffer, 5);

    try testing.expect(buffer[0] == 'H');
    try testing.expect(buffer[1] == 'E');
    try testing.expect(buffer[2] == 'L');
    try testing.expect(buffer[3] == 'L');
    try testing.expect(buffer[4] == 'O');
}
// ANCHOR_END: string_manipulation

// ANCHOR: format_string
// Format strings for C (similar to sprintf)
pub fn formatCString(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) ![*:0]u8 {
    const result = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(result);
    return try allocator.dupeZ(u8, result);
}

test "formatting C strings" {
    const allocator = testing.allocator;

    const formatted = try formatCString(allocator, "Number: {d}, String: {s}", .{ 42, "test" });
    defer {
        const len = c.strlen(formatted);
        allocator.free(formatted[0 .. len + 1]);
    }

    const as_slice = StringConv.fromC(formatted);
    try testing.expect(std.mem.eql(u8, as_slice, "Number: 42, String: test"));
}
// ANCHOR_END: format_string
