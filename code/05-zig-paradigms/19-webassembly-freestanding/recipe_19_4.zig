const std = @import("std");
const testing = std.testing;

// Custom panic handler
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = msg;
    _ = error_return_trace;
    _ = ret_addr;
    while (true) {}
}

// ANCHOR: string_buffer
// Static buffer for returning strings to JavaScript
var string_buffer: [1024]u8 = undefined;
var string_buffer_len: usize = 0;
// ANCHOR_END: string_buffer

// ANCHOR: string_exports
// Export functions to access string buffer
export fn getStringPtr() [*]const u8 {
    return &string_buffer;
}

export fn getStringLen() usize {
    return string_buffer_len;
}
// ANCHOR_END: string_exports

// ANCHOR: process_string
// Process a string passed from JavaScript
export fn processString(ptr: [*]const u8, len: usize) usize {
    const input = ptr[0..len];

    var count: usize = 0;
    for (input) |char| {
        if (char >= 'a' and char <= 'z') {
            count += 1;
        }
    }

    return count;
}
// ANCHOR_END: process_string

// ANCHOR: uppercase_string
// Convert string to uppercase and store in buffer
export fn uppercaseString(ptr: [*]const u8, len: usize) void {
    const input = ptr[0..len];

    // Ensure it fits in our buffer
    const copy_len = @min(input.len, string_buffer.len);

    for (0..copy_len) |i| {
        if (input[i] >= 'a' and input[i] <= 'z') {
            string_buffer[i] = input[i] - 32; // Convert to uppercase
        } else {
            string_buffer[i] = input[i];
        }
    }

    string_buffer_len = copy_len;
}
// ANCHOR_END: uppercase_string

// ANCHOR: reverse_string
// Reverse a string in the buffer
export fn reverseString(ptr: [*]const u8, len: usize) void {
    const input = ptr[0..len];
    const copy_len = @min(input.len, string_buffer.len);

    var i: usize = 0;
    while (i < copy_len) : (i += 1) {
        string_buffer[i] = input[copy_len - 1 - i];
    }

    string_buffer_len = copy_len;
}
// ANCHOR_END: reverse_string

// ANCHOR: concatenate_strings
// Concatenate two strings
export fn concatenateStrings(ptr1: [*]const u8, len1: usize, ptr2: [*]const u8, len2: usize) void {
    const str1 = ptr1[0..len1];
    const str2 = ptr2[0..len2];

    const total_len = @min(len1 + len2, string_buffer.len);
    const len1_clamped = @min(len1, string_buffer.len);
    const len2_clamped = @min(total_len - len1_clamped, len2);

    // Copy first string
    for (0..len1_clamped) |i| {
        string_buffer[i] = str1[i];
    }

    // Copy second string
    for (0..len2_clamped) |i| {
        string_buffer[len1_clamped + i] = str2[i];
    }

    string_buffer_len = len1_clamped + len2_clamped;
}
// ANCHOR_END: concatenate_strings

// ANCHOR: parse_number
// Parse number from string
export fn parseNumber(ptr: [*]const u8, len: usize) i32 {
    const input = ptr[0..len];

    var result: i32 = 0;
    var is_negative = false;
    var start_index: usize = 0;

    // Check for negative sign
    if (input.len > 0 and input[0] == '-') {
        is_negative = true;
        start_index = 1;
    }

    for (start_index..input.len) |i| {
        const char = input[i];
        if (char >= '0' and char <= '9') {
            result = result * 10 + @as(i32, char - '0');
        }
    }

    return if (is_negative) -result else result;
}
// ANCHOR_END: parse_number

// ANCHOR: format_number
// Format number as string
export fn formatNumber(num: i32) void {
    if (num == 0) {
        string_buffer[0] = '0';
        string_buffer_len = 1;
        return;
    }

    var n = num;
    var is_negative = false;

    if (n < 0) {
        is_negative = true;
        n = -n;
    }

    var temp_buffer: [32]u8 = undefined;
    var temp_len: usize = 0;

    // Convert digits in reverse
    while (n > 0) : (n = @divTrunc(n, 10)) {
        const digit: u8 = @intCast(@rem(n, 10));
        temp_buffer[temp_len] = '0' + digit;
        temp_len += 1;
    }

    // Add negative sign if needed
    if (is_negative) {
        temp_buffer[temp_len] = '-';
        temp_len += 1;
    }

    // Reverse into string_buffer
    for (0..temp_len) |i| {
        string_buffer[i] = temp_buffer[temp_len - 1 - i];
    }

    string_buffer_len = temp_len;
}
// ANCHOR_END: format_number

// ANCHOR: word_count
// Count words in a string
export fn wordCount(ptr: [*]const u8, len: usize) usize {
    const input = ptr[0..len];
    var count: usize = 0;
    var in_word = false;

    for (input) |char| {
        const is_space = (char == ' ' or char == '\t' or char == '\n' or char == '\r');

        if (!is_space and !in_word) {
            count += 1;
            in_word = true;
        } else if (is_space) {
            in_word = false;
        }
    }

    return count;
}
// ANCHOR_END: word_count

// ANCHOR: allocate_bytes
// Allocate bytes and return pointer (simplified - uses static buffer)
export fn allocateBytes(size: usize) [*]u8 {
    const static = struct {
        var heap: [4096]u8 = undefined;
        var offset: usize = 0;
    };

    if (static.offset + size > static.heap.len) {
        // Out of space - reset (not production-ready!)
        static.offset = 0;
    }

    const ptr: [*]u8 = @ptrCast(&static.heap[static.offset]);
    static.offset += size;

    return ptr;
}
// ANCHOR_END: allocate_bytes

// Tests

// ANCHOR: test_process_string
test "process string" {
    const str = "Hello World!";
    const count = processString(str.ptr, str.len);
    try testing.expectEqual(@as(usize, 8), count); // 8 lowercase letters
}
// ANCHOR_END: test_process_string

// ANCHOR: test_uppercase
test "uppercase string" {
    const str = "hello";
    uppercaseString(str.ptr, str.len);

    const result = string_buffer[0..string_buffer_len];
    try testing.expectEqualStrings("HELLO", result);
}
// ANCHOR_END: test_uppercase

// ANCHOR: test_reverse
test "reverse string" {
    const str = "hello";
    reverseString(str.ptr, str.len);

    const result = string_buffer[0..string_buffer_len];
    try testing.expectEqualStrings("olleh", result);
}
// ANCHOR_END: test_reverse

// ANCHOR: test_concatenate
test "concatenate strings" {
    const str1 = "Hello, ";
    const str2 = "World!";
    concatenateStrings(str1.ptr, str1.len, str2.ptr, str2.len);

    const result = string_buffer[0..string_buffer_len];
    try testing.expectEqualStrings("Hello, World!", result);
}
// ANCHOR_END: test_concatenate

// ANCHOR: test_parse_number
test "parse number" {
    const str1 = "123";
    try testing.expectEqual(@as(i32, 123), parseNumber(str1.ptr, str1.len));

    const str2 = "-456";
    try testing.expectEqual(@as(i32, -456), parseNumber(str2.ptr, str2.len));

    const str3 = "0";
    try testing.expectEqual(@as(i32, 0), parseNumber(str3.ptr, str3.len));
}
// ANCHOR_END: test_parse_number

// ANCHOR: test_format_number
test "format number" {
    formatNumber(123);
    try testing.expectEqualStrings("123", string_buffer[0..string_buffer_len]);

    formatNumber(-456);
    try testing.expectEqualStrings("-456", string_buffer[0..string_buffer_len]);

    formatNumber(0);
    try testing.expectEqualStrings("0", string_buffer[0..string_buffer_len]);
}
// ANCHOR_END: test_format_number

// ANCHOR: test_word_count
test "word count" {
    const str1 = "Hello World";
    try testing.expectEqual(@as(usize, 2), wordCount(str1.ptr, str1.len));

    const str2 = "  Multiple   spaces  ";
    try testing.expectEqual(@as(usize, 2), wordCount(str2.ptr, str2.len));

    const str3 = "";
    try testing.expectEqual(@as(usize, 0), wordCount(str3.ptr, str3.len));
}
// ANCHOR_END: test_word_count
