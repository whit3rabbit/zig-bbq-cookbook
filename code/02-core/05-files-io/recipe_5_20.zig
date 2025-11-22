// Recipe 5.20: Using Directory Handles for Testable File Operations
// Target Zig Version: 0.15.2
//
// This recipe demonstrates Zig's directory-handle-based filesystem API,
// showing how to write testable file operations using Dir handles instead
// of absolute paths, and when to use openFileAbsolute.

const std = @import("std");
const testing = std.testing;

// ANCHOR: dir_vs_absolute
/// BAD: Function takes absolute path, hard to test
pub fn saveDataBad(path: []const u8, data: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    try file.writeAll(data);
}

/// GOOD: Function takes directory handle and relative path
pub fn saveDataGood(dir: std.fs.Dir, filename: []const u8, data: []const u8) !void {
    const file = try dir.createFile(filename, .{});
    defer file.close();
    try file.writeAll(data);
}

/// When to use openFileAbsolute: user-provided absolute paths
pub fn loadConfig(absolute_path: []const u8) ![]u8 {
    // Assert path is absolute for safety
    std.debug.assert(std.fs.path.isAbsolute(absolute_path));

    const file = try std.fs.openFileAbsolute(absolute_path, .{});
    defer file.close();

    const allocator = std.heap.page_allocator; // For example
    return try file.readToEndAlloc(allocator, 1024 * 1024);
}
// ANCHOR_END: dir_vs_absolute

// ANCHOR: testable_pattern
/// Processor that works with any directory
pub const FileProcessor = struct {
    directory: std.fs.Dir,

    pub fn init(dir: std.fs.Dir) FileProcessor {
        return .{ .directory = dir };
    }

    /// Process a file in the configured directory
    pub fn processFile(self: *FileProcessor, filename: []const u8) !usize {
        const file = try self.directory.openFile(filename, .{});
        defer file.close();

        const stat = try file.stat();
        return stat.size;
    }

    /// Save processed results
    pub fn saveResults(self: *FileProcessor, filename: []const u8, data: []const u8) !void {
        const file = try self.directory.createFile(filename, .{});
        defer file.close();
        try file.writeAll(data);
    }
};

/// Data manager with directory injection
pub const DataManager = struct {
    data_dir: std.fs.Dir,

    pub fn init(data_dir: std.fs.Dir) DataManager {
        return .{ .data_dir = data_dir };
    }

    pub fn saveItem(self: *DataManager, id: u32, content: []const u8) !void {
        var buf: [64]u8 = undefined;
        const filename = try std.fmt.bufPrint(&buf, "item_{}.dat", .{id});

        const file = try self.data_dir.createFile(filename, .{});
        defer file.close();
        try file.writeAll(content);
    }

    pub fn loadItem(self: *DataManager, allocator: std.mem.Allocator, id: u32) ![]u8 {
        var buf: [64]u8 = undefined;
        const filename = try std.fmt.bufPrint(&buf, "item_{}.dat", .{id});

        const file = try self.data_dir.openFile(filename, .{});
        defer file.close();

        return try file.readToEndAlloc(allocator, 1024 * 1024);
    }

    pub fn itemExists(self: *DataManager, id: u32) bool {
        var buf: [64]u8 = undefined;
        const filename = std.fmt.bufPrint(&buf, "item_{}.dat", .{id}) catch return false;

        self.data_dir.access(filename, .{}) catch return false;
        return true;
    }
};
// ANCHOR_END: testable_pattern

// ANCHOR: directory_scoping
/// Work with a subdirectory safely
pub fn processSubdirectory(parent: std.fs.Dir, subdir_name: []const u8) !void {
    // Open subdirectory - operations are scoped to this directory
    var subdir = try parent.openDir(subdir_name, .{});
    defer subdir.close();

    // All operations relative to subdir
    const file = try subdir.createFile("output.txt", .{});
    defer file.close();
    try file.writeAll("Data in subdirectory");
}

/// Create nested directory structure
pub fn createNestedDirs(base: std.fs.Dir) !void {
    // makePath creates all parent directories
    try base.makePath("data/cache/temp");

    // Now we can open the nested directory
    var temp_dir = try base.openDir("data/cache/temp", .{});
    defer temp_dir.close();

    const file = try temp_dir.createFile("cached.dat", .{});
    defer file.close();
    try file.writeAll("Cached data");
}
// ANCHOR_END: directory_scoping

// ANCHOR: cross_platform_paths
/// Handle paths correctly across platforms
pub fn crossPlatformOpen(dir: std.fs.Dir, components: []const []const u8, allocator: std.mem.Allocator) !std.fs.File {
    // Use std.fs.path.join for cross-platform path handling
    const path = try std.fs.path.join(allocator, components);
    defer allocator.free(path);

    // Forward slashes work on all platforms with Dir API
    return try dir.openFile(path, .{});
}

/// DON'T: Mix absolute paths with Dir API
pub fn badCrossPlatformOpen(dir: std.fs.Dir) !std.fs.File {
    // This might fail on Windows or with different mount points
    return try dir.openFile("/tmp/file.txt", .{});
}

/// DO: Use directory handles with relative paths
pub fn goodCrossPlatformOpen(dir: std.fs.Dir) !std.fs.File {
    // Relative paths work consistently
    return try dir.openFile("file.txt", .{});
}
// ANCHOR_END: cross_platform_paths

// Tests

test "dir vs absolute path comparison" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    // Good pattern: testable with tmp.dir
    try saveDataGood(tmp.dir, "test.txt", "Hello, Zig!");

    const content = try tmp.dir.readFileAlloc(testing.allocator, "test.txt", 1024);
    defer testing.allocator.free(content);

    try testing.expectEqualStrings("Hello, Zig!", content);
}

test "file processor with dir injection" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    // Create test file
    {
        const file = try tmp.dir.createFile("input.txt", .{});
        defer file.close();
        try file.writeAll("Test data");
    }

    // Create processor with test directory
    var processor = FileProcessor.init(tmp.dir);

    // Process file
    const size = try processor.processFile("input.txt");
    try testing.expectEqual(@as(usize, 9), size);

    // Save results
    try processor.saveResults("output.txt", "Processed");

    // Verify
    const result = try tmp.dir.readFileAlloc(testing.allocator, "output.txt", 1024);
    defer testing.allocator.free(result);
    try testing.expectEqualStrings("Processed", result);
}

test "data manager with directory injection" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    var manager = DataManager.init(tmp.dir);

    // Save items
    try manager.saveItem(1, "First item");
    try manager.saveItem(2, "Second item");

    // Check existence
    try testing.expect(manager.itemExists(1));
    try testing.expect(manager.itemExists(2));
    try testing.expect(!manager.itemExists(3));

    // Load items
    const item1 = try manager.loadItem(testing.allocator, 1);
    defer testing.allocator.free(item1);
    try testing.expectEqualStrings("First item", item1);

    const item2 = try manager.loadItem(testing.allocator, 2);
    defer testing.allocator.free(item2);
    try testing.expectEqualStrings("Second item", item2);
}

test "subdirectory scoping" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    // Create subdirectory
    try tmp.dir.makeDir("subdir");

    // Process subdirectory
    try processSubdirectory(tmp.dir, "subdir");

    // Verify file exists in subdirectory
    var subdir = try tmp.dir.openDir("subdir", .{});
    defer subdir.close();

    const content = try subdir.readFileAlloc(testing.allocator, "output.txt", 1024);
    defer testing.allocator.free(content);

    try testing.expectEqualStrings("Data in subdirectory", content);
}

test "nested directory creation" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    try createNestedDirs(tmp.dir);

    // Verify nested structure exists
    var data_dir = try tmp.dir.openDir("data", .{});
    defer data_dir.close();

    var cache_dir = try data_dir.openDir("cache", .{});
    defer cache_dir.close();

    var temp_dir = try cache_dir.openDir("temp", .{});
    defer temp_dir.close();

    // Verify file exists
    const file = try temp_dir.openFile("cached.dat", .{});
    defer file.close();

    var buf: [20]u8 = undefined;
    const n = try file.read(&buf);
    try testing.expectEqualStrings("Cached data", buf[0..n]);
}

test "cross-platform path joining" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    // Create nested structure
    try tmp.dir.makePath("data/items");

    // Create file in nested directory
    {
        var nested_dir = try tmp.dir.openDir("data/items", .{});
        defer nested_dir.close();

        const file = try nested_dir.createFile("file.txt", .{});
        defer file.close();
        try file.writeAll("nested");
    }

    // Open using path components
    const components = [_][]const u8{ "data", "items", "file.txt" };
    const file = try crossPlatformOpen(tmp.dir, &components, testing.allocator);
    defer file.close();

    var buf: [10]u8 = undefined;
    const n = try file.read(&buf);
    try testing.expectEqualStrings("nested", buf[0..n]);
}

test "production vs test directory pattern" {
    // In production code
    {
        // Would use cwd() or specific directory
        const prod_dir = std.fs.cwd();
        const manager = DataManager.init(prod_dir);
        _ = manager;
    }

    // In test code
    {
        var tmp = testing.tmpDir(.{});
        defer tmp.cleanup();

        // Same code, different directory!
        var manager = DataManager.init(tmp.dir);
        try manager.saveItem(1, "test");
        try testing.expect(manager.itemExists(1));
    }
}

test "openFileAbsolute works with absolute paths" {
    const test_path = "/tmp/test_absolute.txt";
    defer std.fs.cwd().deleteFile(test_path) catch {};

    // Create test file using cwd
    {
        const file = try std.fs.cwd().createFile(test_path, .{});
        defer file.close();
        try file.writeAll("absolute path test");
    }

    // openFileAbsolute works with absolute path
    const file = try std.fs.openFileAbsolute(test_path, .{});
    defer file.close();

    var buf: [30]u8 = undefined;
    const n = try file.read(&buf);
    try testing.expectEqualStrings("absolute path test", buf[0..n]);
}

test "directory iteration with Dir handle" {
    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    // Create several files
    {
        const f1 = try tmp.dir.createFile("file1.txt", .{});
        defer f1.close();
        const f2 = try tmp.dir.createFile("file2.txt", .{});
        defer f2.close();
        const f3 = try tmp.dir.createFile("file3.txt", .{});
        defer f3.close();
    }

    // Iterate using Dir handle
    var count: usize = 0;
    var iter = tmp.dir.iterate();
    while (try iter.next()) |entry| {
        try testing.expect(entry.kind == .file);
        count += 1;
    }

    try testing.expectEqual(@as(usize, 3), count);
}

test "benefit: parallel testing with different directories" {
    // Each test gets its own tmp directory
    var tmp1 = testing.tmpDir(.{});
    defer tmp1.cleanup();

    var tmp2 = testing.tmpDir(.{});
    defer tmp2.cleanup();

    // Tests can run in parallel without conflicts
    var manager1 = DataManager.init(tmp1.dir);
    var manager2 = DataManager.init(tmp2.dir);

    try manager1.saveItem(1, "test1");
    try manager2.saveItem(1, "test2");

    const item1 = try manager1.loadItem(testing.allocator, 1);
    defer testing.allocator.free(item1);

    const item2 = try manager2.loadItem(testing.allocator, 1);
    defer testing.allocator.free(item2);

    // Different data, no collision
    try testing.expectEqualStrings("test1", item1);
    try testing.expectEqualStrings("test2", item2);
}
