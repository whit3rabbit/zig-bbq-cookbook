const std = @import("std");
const testing = std.testing;

// ANCHOR: progress_callback
pub const ProgressCallback = *const fn (bytes_transferred: usize, total_bytes: ?usize) void;

pub fn defaultProgressCallback(bytes_transferred: usize, total_bytes: ?usize) void {
    if (total_bytes) |total| {
        const percent = (@as(f64, @floatFromInt(bytes_transferred)) / @as(f64, @floatFromInt(total))) * 100.0;
        std.debug.print("Progress: {d:.1}% ({d}/{d} bytes)\n", .{ percent, bytes_transferred, total });
    } else {
        std.debug.print("Progress: {d} bytes\n", .{bytes_transferred});
    }
}
// ANCHOR_END: progress_callback

// ANCHOR: download_options
pub const DownloadOptions = struct {
    chunk_size: usize = 8192,
    resume_from: ?usize = null,
    progress_callback: ?ProgressCallback = null,
    max_retries: u32 = 3,
};
// ANCHOR_END: download_options

// ANCHOR: downloader
pub const Downloader = struct {
    allocator: std.mem.Allocator,
    options: DownloadOptions,

    pub fn init(allocator: std.mem.Allocator, options: DownloadOptions) Downloader {
        return .{
            .allocator = allocator,
            .options = options,
        };
    }

    pub fn downloadToMemory(self: *Downloader, url: []const u8) ![]const u8 {
        _ = url;
        // Simulate download - in real implementation, use std.http.Client
        var buffer = std.ArrayList(u8){};
        defer buffer.deinit(self.allocator);

        const test_data = "File contents from server";
        try buffer.appendSlice(self.allocator, test_data);

        // Simulate progress
        if (self.options.progress_callback) |callback| {
            callback(test_data.len, test_data.len);
        }

        return buffer.toOwnedSlice(self.allocator);
    }

    pub fn downloadToFile(self: *Downloader, url: []const u8, file_path: []const u8) !void {
        _ = url;
        const file = try std.fs.cwd().createFile(file_path, .{});
        defer file.close();

        const test_data = "Downloaded file content";
        try file.writeAll(test_data);

        if (self.options.progress_callback) |callback| {
            callback(test_data.len, test_data.len);
        }
    }

    pub fn downloadChunked(self: *Downloader, url: []const u8) ![]const u8 {
        _ = url;
        var buffer = std.ArrayList(u8){};
        defer buffer.deinit(self.allocator);

        // Simulate chunked download
        const chunks = [_][]const u8{ "chunk1", "chunk2", "chunk3" };
        var total_size: usize = 0;
        for (chunks) |chunk| {
            total_size += chunk.len;
        }

        var transferred: usize = 0;
        for (chunks) |chunk| {
            try buffer.appendSlice(self.allocator, chunk);
            transferred += chunk.len;

            if (self.options.progress_callback) |callback| {
                callback(transferred, total_size);
            }
        }

        return buffer.toOwnedSlice(self.allocator);
    }
};
// ANCHOR_END: downloader

// ANCHOR: upload_options
pub const UploadOptions = struct {
    content_type: ?[]const u8 = null,
    chunk_size: usize = 8192,
    progress_callback: ?ProgressCallback = null,
};
// ANCHOR_END: upload_options

// ANCHOR: multipart_form
pub const MultipartForm = struct {
    boundary: []const u8,
    fields: std.StringHashMap([]const u8),
    files: std.ArrayList(FileField),
    allocator: std.mem.Allocator,

    pub const FileField = struct {
        name: []const u8,
        filename: []const u8,
        content_type: []const u8,
        data: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator) !MultipartForm {
        // Generate cryptographically secure boundary
        // Using random bytes prevents boundary collision attacks where
        // malicious file content contains the boundary string
        var random_bytes: [16]u8 = undefined;
        std.crypto.random.bytes(&random_bytes);

        var boundary_buf: [50]u8 = undefined;
        const hex = std.fmt.bytesToHex(random_bytes, .lower);
        const boundary = try std.fmt.bufPrint(&boundary_buf, "----Boundary{s}", .{hex});

        const owned_boundary = try allocator.dupe(u8, boundary);
        errdefer allocator.free(owned_boundary);

        return .{
            .boundary = owned_boundary,
            .fields = std.StringHashMap([]const u8).init(allocator),
            .files = std.ArrayList(FileField){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *MultipartForm) void {
        self.allocator.free(self.boundary);

        var it = self.fields.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.fields.deinit();

        for (self.files.items) |file| {
            self.allocator.free(file.name);
            self.allocator.free(file.filename);
            self.allocator.free(file.content_type);
            self.allocator.free(file.data);
        }
        self.files.deinit(self.allocator);
    }

    pub fn addField(self: *MultipartForm, name: []const u8, value: []const u8) !void {
        // HashMap Memory Leak Prevention
        //
        // Using getOrPut() instead of put() prevents memory leaks when the same
        // form field is added multiple times (e.g., updating a field value).
        //
        // This is critical for user-facing forms where duplicate field names
        // could occur due to user error or programmatic mistakes.
        //
        // See recipe_11_4.zig HttpResponse.setHeader for reference implementation.

        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);

        const gop = try self.fields.getOrPut(name);
        if (gop.found_existing) {
            // Duplicate field: free old value, reuse existing key
            self.allocator.free(gop.value_ptr.*);
            gop.value_ptr.* = owned_value;
        } else {
            // New field: allocate key and store both
            const owned_name = try self.allocator.dupe(u8, name);
            gop.key_ptr.* = owned_name;
            gop.value_ptr.* = owned_value;
        }
    }

    pub fn addFile(self: *MultipartForm, name: []const u8, filename: []const u8, content_type: []const u8, data: []const u8) !void {
        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);

        const owned_filename = try self.allocator.dupe(u8, filename);
        errdefer self.allocator.free(owned_filename);

        const owned_content_type = try self.allocator.dupe(u8, content_type);
        errdefer self.allocator.free(owned_content_type);

        const owned_data = try self.allocator.dupe(u8, data);
        errdefer self.allocator.free(owned_data);

        const file = FileField{
            .name = owned_name,
            .filename = owned_filename,
            .content_type = owned_content_type,
            .data = owned_data,
        };

        try self.files.append(self.allocator, file);
    }

    pub fn build(self: *const MultipartForm) ![]const u8 {
        var buffer = std.ArrayList(u8){};
        defer buffer.deinit(self.allocator);

        // Add text fields
        var it = self.fields.iterator();
        while (it.next()) |entry| {
            try buffer.appendSlice(self.allocator, "--");
            try buffer.appendSlice(self.allocator, self.boundary);
            try buffer.appendSlice(self.allocator, "\r\n");
            try buffer.appendSlice(self.allocator, "Content-Disposition: form-data; name=\"");
            try buffer.appendSlice(self.allocator, entry.key_ptr.*);
            try buffer.appendSlice(self.allocator, "\"\r\n\r\n");
            try buffer.appendSlice(self.allocator, entry.value_ptr.*);
            try buffer.appendSlice(self.allocator, "\r\n");
        }

        // Add file fields
        for (self.files.items) |file| {
            try buffer.appendSlice(self.allocator, "--");
            try buffer.appendSlice(self.allocator, self.boundary);
            try buffer.appendSlice(self.allocator, "\r\n");
            try buffer.appendSlice(self.allocator, "Content-Disposition: form-data; name=\"");
            try buffer.appendSlice(self.allocator, file.name);
            try buffer.appendSlice(self.allocator, "\"; filename=\"");
            try buffer.appendSlice(self.allocator, file.filename);
            try buffer.appendSlice(self.allocator, "\"\r\n");
            try buffer.appendSlice(self.allocator, "Content-Type: ");
            try buffer.appendSlice(self.allocator, file.content_type);
            try buffer.appendSlice(self.allocator, "\r\n\r\n");
            try buffer.appendSlice(self.allocator, file.data);
            try buffer.appendSlice(self.allocator, "\r\n");
        }

        // Final boundary
        try buffer.appendSlice(self.allocator, "--");
        try buffer.appendSlice(self.allocator, self.boundary);
        try buffer.appendSlice(self.allocator, "--\r\n");

        return buffer.toOwnedSlice(self.allocator);
    }

    pub fn getContentType(self: *const MultipartForm) ![]const u8 {
        var buffer = std.ArrayList(u8){};
        defer buffer.deinit(self.allocator);

        try buffer.appendSlice(self.allocator, "multipart/form-data; boundary=");
        try buffer.appendSlice(self.allocator, self.boundary);

        return buffer.toOwnedSlice(self.allocator);
    }
};
// ANCHOR_END: multipart_form

// ANCHOR: uploader
pub const Uploader = struct {
    allocator: std.mem.Allocator,
    options: UploadOptions,

    pub fn init(allocator: std.mem.Allocator, options: UploadOptions) Uploader {
        return .{
            .allocator = allocator,
            .options = options,
        };
    }

    pub fn uploadFile(self: *Uploader, url: []const u8, file_path: []const u8) !void {
        _ = url;
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        const stat = try file.stat();
        const file_size = stat.size;

        // Simulate chunked upload
        var uploaded: usize = 0;
        while (uploaded < file_size) {
            const chunk_size = @min(self.options.chunk_size, file_size - uploaded);
            uploaded += chunk_size;

            if (self.options.progress_callback) |callback| {
                callback(uploaded, file_size);
            }
        }
    }

    pub fn uploadData(self: *Uploader, url: []const u8, data: []const u8) !void {
        _ = url;
        if (self.options.progress_callback) |callback| {
            callback(data.len, data.len);
        }
    }
};
// ANCHOR_END: uploader

// ANCHOR: resume_info
pub const ResumeInfo = struct {
    url: []const u8,
    file_path: []const u8,
    bytes_downloaded: usize,
    total_bytes: ?usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, url: []const u8, file_path: []const u8) !ResumeInfo {
        const owned_url = try allocator.dupe(u8, url);
        errdefer allocator.free(owned_url);

        const owned_file_path = try allocator.dupe(u8, file_path);

        return .{
            .url = owned_url,
            .file_path = owned_file_path,
            .bytes_downloaded = 0,
            .total_bytes = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ResumeInfo) void {
        self.allocator.free(self.url);
        self.allocator.free(self.file_path);
    }

    pub fn save(self: *const ResumeInfo, resume_file: []const u8) !void {
        const file = try std.fs.cwd().createFile(resume_file, .{});
        defer file.close();

        var buffer = std.ArrayList(u8){};
        defer buffer.deinit(self.allocator);

        try buffer.writer(self.allocator).print("{d}\n", .{self.bytes_downloaded});
        if (self.total_bytes) |total| {
            try buffer.writer(self.allocator).print("{d}\n", .{total});
        }

        try file.writeAll(buffer.items);
    }

    pub fn load(allocator: std.mem.Allocator, resume_file: []const u8, url: []const u8, file_path: []const u8) !ResumeInfo {
        const file = try std.fs.cwd().openFile(resume_file, .{});
        defer file.close();

        var info = try ResumeInfo.init(allocator, url, file_path);
        errdefer info.deinit();

        var buf: [1024]u8 = undefined;
        const bytes_read = try file.readAll(&buf);
        const content = buf[0..bytes_read];

        var lines = std.mem.splitScalar(u8, content, '\n');
        if (lines.next()) |line| {
            info.bytes_downloaded = try std.fmt.parseInt(usize, std.mem.trim(u8, line, " \r\n"), 10);
        }

        return info;
    }
};
// ANCHOR_END: resume_info

// ANCHOR: test_download_to_memory
test "download to memory" {
    var downloader = Downloader.init(testing.allocator, .{});

    const data = try downloader.downloadToMemory("http://example.com/file.txt");
    defer testing.allocator.free(data);

    try testing.expect(data.len > 0);
    try testing.expectEqualStrings("File contents from server", data);
}
// ANCHOR_END: test_download_to_memory

// ANCHOR: test_download_to_file
test "download to file" {
    var downloader = Downloader.init(testing.allocator, .{});

    const test_file = "test_download.txt";
    defer std.fs.cwd().deleteFile(test_file) catch {};

    try downloader.downloadToFile("http://example.com/file.txt", test_file);

    const file = try std.fs.cwd().openFile(test_file, .{});
    defer file.close();

    var buf: [1024]u8 = undefined;
    const bytes_read = try file.readAll(&buf);
    try testing.expectEqualStrings("Downloaded file content", buf[0..bytes_read]);
}
// ANCHOR_END: test_download_to_file

// ANCHOR: test_chunked_download
test "chunked download" {
    var downloader = Downloader.init(testing.allocator, .{});

    const data = try downloader.downloadChunked("http://example.com/large-file.dat");
    defer testing.allocator.free(data);

    try testing.expectEqualStrings("chunk1chunk2chunk3", data);
}
// ANCHOR_END: test_chunked_download

// ANCHOR: test_download_with_progress
test "download with progress callback" {
    const TestProgress = struct {
        var last_bytes: usize = 0;
        var last_total: ?usize = null;

        fn callback(bytes: usize, total: ?usize) void {
            last_bytes = bytes;
            last_total = total;
        }
    };

    var downloader = Downloader.init(testing.allocator, .{
        .progress_callback = TestProgress.callback,
    });

    const data = try downloader.downloadToMemory("http://example.com/file.txt");
    defer testing.allocator.free(data);

    try testing.expect(TestProgress.last_bytes > 0);
    try testing.expect(TestProgress.last_total != null);
}
// ANCHOR_END: test_download_with_progress

// ANCHOR: test_multipart_form_creation
test "create multipart form" {
    var form = try MultipartForm.init(testing.allocator);
    defer form.deinit();

    try testing.expect(form.boundary.len > 0);
    try testing.expect(std.mem.startsWith(u8, form.boundary, "----Boundary"));
}
// ANCHOR_END: test_multipart_form_creation

// ANCHOR: test_multipart_add_field
test "add field to multipart form" {
    var form = try MultipartForm.init(testing.allocator);
    defer form.deinit();

    try form.addField("username", "alice");
    try form.addField("email", "alice@example.com");

    try testing.expectEqual(@as(u32, 2), form.fields.count());

    const username = form.fields.get("username");
    try testing.expect(username != null);
    try testing.expectEqualStrings("alice", username.?);
}
// ANCHOR_END: test_multipart_add_field

test "add duplicate field to multipart form - no memory leak" {
    var form = try MultipartForm.init(testing.allocator);
    defer form.deinit();

    // Add same field multiple times - last value should win
    try form.addField("username", "alice");
    try form.addField("username", "bob");
    try form.addField("email", "old@example.com");
    try form.addField("email", "new@example.com");

    // Should only have 2 fields, not 4
    try testing.expectEqual(@as(u32, 2), form.fields.count());

    // Last values should win
    const username = form.fields.get("username");
    try testing.expect(username != null);
    try testing.expectEqualStrings("bob", username.?);

    const email = form.fields.get("email");
    try testing.expect(email != null);
    try testing.expectEqualStrings("new@example.com", email.?);
}

// ANCHOR: test_multipart_add_file
test "add file to multipart form" {
    var form = try MultipartForm.init(testing.allocator);
    defer form.deinit();

    try form.addFile("avatar", "photo.jpg", "image/jpeg", "fake image data");

    try testing.expectEqual(@as(usize, 1), form.files.items.len);

    const file = form.files.items[0];
    try testing.expectEqualStrings("avatar", file.name);
    try testing.expectEqualStrings("photo.jpg", file.filename);
    try testing.expectEqualStrings("image/jpeg", file.content_type);
}
// ANCHOR_END: test_multipart_add_file

// ANCHOR: test_multipart_build
test "build multipart form body" {
    var form = try MultipartForm.init(testing.allocator);
    defer form.deinit();

    try form.addField("name", "John");
    try form.addFile("document", "test.txt", "text/plain", "file contents");

    const body = try form.build();
    defer testing.allocator.free(body);

    try testing.expect(std.mem.indexOf(u8, body, "name=\"name\"") != null);
    try testing.expect(std.mem.indexOf(u8, body, "John") != null);
    try testing.expect(std.mem.indexOf(u8, body, "filename=\"test.txt\"") != null);
    try testing.expect(std.mem.indexOf(u8, body, "file contents") != null);
}
// ANCHOR_END: test_multipart_build

// ANCHOR: test_multipart_content_type
test "get multipart content type" {
    var form = try MultipartForm.init(testing.allocator);
    defer form.deinit();

    const content_type = try form.getContentType();
    defer testing.allocator.free(content_type);

    try testing.expect(std.mem.startsWith(u8, content_type, "multipart/form-data; boundary="));
}
// ANCHOR_END: test_multipart_content_type

// ANCHOR: test_upload_file
test "upload file" {
    // Create test file
    const test_file = "test_upload.txt";
    {
        const file = try std.fs.cwd().createFile(test_file, .{});
        defer file.close();
        try file.writeAll("Test upload content");
    }
    defer std.fs.cwd().deleteFile(test_file) catch {};

    var uploader = Uploader.init(testing.allocator, .{});
    try uploader.uploadFile("http://example.com/upload", test_file);
}
// ANCHOR_END: test_upload_file

// ANCHOR: test_upload_data
test "upload data" {
    var uploader = Uploader.init(testing.allocator, .{});

    const data = "Some data to upload";
    try uploader.uploadData("http://example.com/api/data", data);
}
// ANCHOR_END: test_upload_data

// ANCHOR: test_upload_with_progress
test "upload with progress callback" {
    const TestProgress = struct {
        var called: bool = false;

        fn callback(bytes: usize, total: ?usize) void {
            _ = bytes;
            _ = total;
            called = true;
        }
    };

    var uploader = Uploader.init(testing.allocator, .{
        .progress_callback = TestProgress.callback,
    });

    const data = "Upload data";
    try uploader.uploadData("http://example.com/upload", data);

    try testing.expect(TestProgress.called);
}
// ANCHOR_END: test_upload_with_progress

// ANCHOR: test_resume_info_creation
test "create resume info" {
    var info = try ResumeInfo.init(
        testing.allocator,
        "http://example.com/file.zip",
        "/tmp/file.zip",
    );
    defer info.deinit();

    try testing.expectEqualStrings("http://example.com/file.zip", info.url);
    try testing.expectEqualStrings("/tmp/file.zip", info.file_path);
    try testing.expectEqual(@as(usize, 0), info.bytes_downloaded);
}
// ANCHOR_END: test_resume_info_creation

// ANCHOR: test_resume_info_save_load
test "save and load resume info" {
    const resume_file = "test_resume.txt";
    defer std.fs.cwd().deleteFile(resume_file) catch {};

    // Create and save
    {
        var info = try ResumeInfo.init(
            testing.allocator,
            "http://example.com/file.zip",
            "/tmp/file.zip",
        );
        defer info.deinit();

        info.bytes_downloaded = 12345;
        info.total_bytes = 67890;

        try info.save(resume_file);
    }

    // Load and verify
    {
        var info = try ResumeInfo.load(
            testing.allocator,
            resume_file,
            "http://example.com/file.zip",
            "/tmp/file.zip",
        );
        defer info.deinit();

        try testing.expectEqual(@as(usize, 12345), info.bytes_downloaded);
    }
}
// ANCHOR_END: test_resume_info_save_load
