const std = @import("std");

// ANCHOR: decompress_gzip
/// Read and decompress a gzip file
pub fn readGzipFile(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var reader_buffer: [8192]u8 = undefined;
    var decompress_buffer: [std.compress.flate.max_window_len]u8 = undefined;

    var file_reader = file.reader(&reader_buffer);
    var decompressor = std.compress.flate.Decompress.init(
        &file_reader.interface,
        .gzip,
        &decompress_buffer
    );

    // Read in chunks until EOF
    var result: std.ArrayList(u8) = .{};
    errdefer result.deinit(allocator);

    var chunk_buffer: [4096]u8 = undefined;
    while (true) {
        const n = decompressor.reader.readSliceShort(&chunk_buffer) catch |err| switch (err) {
            error.ReadFailed => break,
            else => return err,
        };
        if (n == 0) break;
        try result.appendSlice(allocator, chunk_buffer[0..n]);
    }

    return result.toOwnedSlice(allocator);
}

/// Read and decompress a zlib file
pub fn readZlibFile(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var reader_buffer: [8192]u8 = undefined;
    var decompress_buffer: [std.compress.flate.max_window_len]u8 = undefined;

    var file_reader = file.reader(&reader_buffer);
    var decompressor = std.compress.flate.Decompress.init(
        &file_reader.interface,
        .zlib,
        &decompress_buffer
    );

    // Read in chunks until EOF
    var result: std.ArrayList(u8) = .{};
    errdefer result.deinit(allocator);

    var chunk_buffer: [4096]u8 = undefined;
    while (true) {
        const n = decompressor.reader.readSliceShort(&chunk_buffer) catch |err| switch (err) {
            error.ReadFailed => break,
            else => return err,
        };
        if (n == 0) break;
        try result.appendSlice(allocator, chunk_buffer[0..n]);
    }

    return result.toOwnedSlice(allocator);
}
// ANCHOR_END: decompress_gzip

// ANCHOR: stream_decompress
/// Stream decompress a gzip file to another file
pub fn streamDecompressFile(src_path: []const u8, dst_path: []const u8) !void {
    const src = try std.fs.cwd().openFile(src_path, .{});
    defer src.close();

    const dst = try std.fs.cwd().createFile(dst_path, .{});
    defer dst.close();

    var reader_buffer: [8192]u8 = undefined;
    var decompress_buffer: [std.compress.flate.max_window_len]u8 = undefined;

    var src_reader = src.reader(&reader_buffer);
    var decompressor = std.compress.flate.Decompress.init(
        &src_reader.interface,
        .gzip,
        &decompress_buffer
    );

    // Stream in chunks
    var chunk_buffer: [4096]u8 = undefined;
    while (true) {
        const n = decompressor.reader.readSliceShort(&chunk_buffer) catch |err| switch (err) {
            error.ReadFailed => break,
            else => return err,
        };
        if (n == 0) break;
        try dst.writeAll(chunk_buffer[0..n]);
    }
}
// ANCHOR_END: stream_decompress

// ANCHOR: error_handling
/// Safe decompression with error handling
pub fn safeDecompress(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    return readGzipFile(path, allocator) catch |err| switch (err) {
        error.BadGzipHeader => {
            std.debug.print("Invalid gzip file format\n", .{});
            return error.InvalidFormat;
        },
        error.WrongGzipChecksum => {
            std.debug.print("Corrupted gzip file (checksum mismatch)\n", .{});
            return error.CorruptedData;
        },
        error.EndOfStream => {
            std.debug.print("Truncated gzip file\n", .{});
            return error.TruncatedFile;
        },
        else => return err,
    };
}
// ANCHOR_END: error_handling

// Helper to create gzipped test files using system gzip
fn createGzipFile(path: []const u8, content: []const u8, allocator: std.mem.Allocator) !void {
    // Write uncompressed file
    const temp_path = try std.fmt.allocPrint(allocator, "{s}.tmp", .{path});
    defer allocator.free(temp_path);

    {
        const file = try std.fs.cwd().createFile(temp_path, .{});
        defer file.close();
        try file.writeAll(content);
    }

    // Compress with system gzip
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "gzip", "-c", temp_path },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    // Write compressed output
    {
        const file = try std.fs.cwd().createFile(path, .{});
        defer file.close();
        try file.writeAll(result.stdout);
    }

    // Cleanup temp file
    std.fs.cwd().deleteFile(temp_path) catch {};
}

// Tests

test "read gzip file" {
    const allocator = std.testing.allocator;
    const test_path = "/tmp/test_read.gz";
    const test_content = "Hello, Gzip World!";

    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create gzipped file
    try createGzipFile(test_path, test_content, allocator);

    // Read and decompress
    const data = try readGzipFile(test_path, allocator);
    defer allocator.free(data);

    try std.testing.expectEqualStrings(test_content, data);
}

test "read zlib file" {
    const allocator = std.testing.allocator;
    const test_path = "/tmp/test_zlib.zz";
    const test_content = "Zlib test data";

    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create temp file
    const temp_path = "/tmp/test_zlib_temp.txt";
    {
        const file = try std.fs.cwd().createFile(temp_path, .{});
        defer file.close();
        try file.writeAll(test_content);
    }
    defer std.fs.cwd().deleteFile(temp_path) catch {};

    // Compress with zlib (using python for zlib compression)
    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "python3", "-c", "import zlib, sys; sys.stdout.buffer.write(zlib.compress(open(sys.argv[1], 'rb').read()))", temp_path },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    // Write compressed output
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll(result.stdout);
    }

    // Read and decompress
    const data = try readZlibFile(test_path, allocator);
    defer allocator.free(data);

    try std.testing.expectEqualStrings(test_content, data);
}

test "stream decompress file" {
    const allocator = std.testing.allocator;
    const src_path = "/tmp/test_stream_src.gz";
    const dst_path = "/tmp/test_stream_dst.txt";
    const test_content = "Stream decompression test\n" ** 100;

    defer std.fs.cwd().deleteFile(src_path) catch {};
    defer std.fs.cwd().deleteFile(dst_path) catch {};

    // Create gzipped file
    try createGzipFile(src_path, test_content, allocator);

    // Stream decompress
    try streamDecompressFile(src_path, dst_path);

    // Verify
    const result = try std.fs.cwd().readFileAlloc(allocator, dst_path, 10 * 1024 * 1024);
    defer allocator.free(result);

    try std.testing.expectEqualStrings(test_content, result);
}

test "read empty gzip file" {
    const allocator = std.testing.allocator;
    const test_path = "/tmp/test_empty.gz";

    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create empty gzipped file
    try createGzipFile(test_path, "", allocator);

    // Read
    const data = try readGzipFile(test_path, allocator);
    defer allocator.free(data);

    try std.testing.expectEqual(@as(usize, 0), data.len);
}

test "read large gzip file" {
    const allocator = std.testing.allocator;
    const test_path = "/tmp/test_large.gz";

    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create large content
    var large_content: std.ArrayList(u8) = .{};
    defer large_content.deinit(allocator);

    var i: usize = 0;
    while (i < 10000) : (i += 1) {
        try large_content.writer(allocator).print("Line {d}\n", .{i});
    }

    // Create gzipped file
    try createGzipFile(test_path, large_content.items, allocator);

    // Read and decompress
    const data = try readGzipFile(test_path, allocator);
    defer allocator.free(data);

    try std.testing.expectEqualStrings(large_content.items, data);
}

test "read binary gzip data" {
    const allocator = std.testing.allocator;
    const test_path = "/tmp/test_binary.gz";

    // Create binary test data
    var binary_data: [256]u8 = undefined;
    for (&binary_data, 0..) |*byte, i| {
        byte.* = @intCast(i);
    }

    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create gzipped file
    try createGzipFile(test_path, &binary_data, allocator);

    // Read and decompress
    const data = try readGzipFile(test_path, allocator);
    defer allocator.free(data);

    try std.testing.expectEqualSlices(u8, &binary_data, data);
}

test "multiple reads from same file" {
    const allocator = std.testing.allocator;
    const test_path = "/tmp/test_multiple.gz";
    const test_content = "Multiple reads test";

    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create gzipped file
    try createGzipFile(test_path, test_content, allocator);

    // Read multiple times
    var i: usize = 0;
    while (i < 3) : (i += 1) {
        const data = try readGzipFile(test_path, allocator);
        defer allocator.free(data);
        try std.testing.expectEqualStrings(test_content, data);
    }
}

test "decompress unicode content" {
    const allocator = std.testing.allocator;
    const test_path = "/tmp/test_unicode.gz";
    const test_content = "Hello, 世界! Привет мир! 🚀";

    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create gzipped file
    try createGzipFile(test_path, test_content, allocator);

    // Read and decompress
    const data = try readGzipFile(test_path, allocator);
    defer allocator.free(data);

    try std.testing.expectEqualStrings(test_content, data);
}

test "stream chunks correctly" {
    const allocator = std.testing.allocator;
    const src_path = "/tmp/test_chunks.gz";
    const dst_path = "/tmp/test_chunks_out.txt";

    // Create content larger than chunk size
    const test_content = "x" ** 10000;

    defer std.fs.cwd().deleteFile(src_path) catch {};
    defer std.fs.cwd().deleteFile(dst_path) catch {};

    // Create gzipped file
    try createGzipFile(src_path, test_content, allocator);

    // Stream decompress
    try streamDecompressFile(src_path, dst_path);

    // Verify
    const result = try std.fs.cwd().readFileAlloc(allocator, dst_path, 10 * 1024 * 1024);
    defer allocator.free(result);

    try std.testing.expectEqualStrings(test_content, result);
}

test "gzip file with multiple lines" {
    const allocator = std.testing.allocator;
    const test_path = "/tmp/test_lines.gz";
    const test_content = "line 1\nline 2\nline 3\n";

    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create gzipped file
    try createGzipFile(test_path, test_content, allocator);

    // Read
    const data = try readGzipFile(test_path, allocator);
    defer allocator.free(data);

    // Count lines
    var lines = std.mem.splitScalar(u8, data, '\n');
    var count: usize = 0;
    while (lines.next()) |line| {
        if (line.len > 0) count += 1;
    }

    try std.testing.expectEqual(@as(usize, 3), count);
}
