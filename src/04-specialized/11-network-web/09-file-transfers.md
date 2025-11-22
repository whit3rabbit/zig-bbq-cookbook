## Problem

You need to transfer files over HTTP with proper progress tracking, support for chunked transfers, and multipart form uploads.

## Solution

Zig provides file I/O capabilities through `std.fs` and can be combined with HTTP networking to implement file transfers. This recipe demonstrates download management, multipart form uploads, and progress tracking:

```zig
{{#include ../../../code/04-specialized/11-network-web/recipe_11_9.zig:progress_callback}}
```

### Downloading Files

The `Downloader` supports multiple download strategies with optional progress tracking:

```zig
pub const DownloadOptions = struct {
    chunk_size: usize = 8192,
    resume_from: ?usize = null,
    progress_callback: ?ProgressCallback = null,
    max_retries: u32 = 3,
};

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
        var buffer = std.ArrayList(u8){};
        defer buffer.deinit(self.allocator);

        const test_data = "File contents from server";
        try buffer.appendSlice(self.allocator, test_data);

        if (self.options.progress_callback) |callback| {
            callback(test_data.len, test_data.len);
        }

        return buffer.toOwnedSlice(self.allocator);
    }

    pub fn downloadChunked(self: *Downloader, url: []const u8) ![]const u8 {
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
```

### Multipart Form Uploads

The `MultipartForm` struct handles both text fields and file uploads using the `multipart/form-data` encoding:

```zig
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
        var boundary_buf: [32]u8 = undefined;
        const timestamp = std.time.timestamp();
        const boundary = try std.fmt.bufPrint(&boundary_buf, "----Boundary{d}", .{timestamp});

        const owned_boundary = try allocator.dupe(u8, boundary);
        errdefer allocator.free(owned_boundary);

        return .{
            .boundary = owned_boundary,
            .fields = std.StringHashMap([]const u8).init(allocator),
            .files = std.ArrayList(FileField){},
            .allocator = allocator,
        };
    }

    pub fn addField(self: *MultipartForm, name: []const u8, value: []const u8) !void {
        const owned_name = try self.allocator.dupe(u8, name);
        errdefer self.allocator.free(owned_name);
        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);
        try self.fields.put(owned_name, owned_value);
    }

    pub fn addFile(self: *MultipartForm, name: []const u8, filename: []const u8,
                   content_type: []const u8, data: []const u8) !void {
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
};
```

### Uploading Files

The `Uploader` provides convenient methods for file and data uploads:

```zig
pub const UploadOptions = struct {
    content_type: ?[]const u8 = null,
    chunk_size: usize = 8192,
    progress_callback: ?ProgressCallback = null,
};

pub const Uploader = struct {
    allocator: std.mem.Allocator,
    options: UploadOptions,

    pub fn uploadFile(self: *Uploader, url: []const u8, file_path: []const u8) !void {
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
};
```

### Resumable Downloads

The `ResumeInfo` struct enables resuming interrupted downloads:

```zig
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

    pub fn load(allocator: std.mem.Allocator, resume_file: []const u8,
                url: []const u8, file_path: []const u8) !ResumeInfo {
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
```

## Discussion

This recipe demonstrates comprehensive file transfer capabilities in Zig. Key concepts include:

### Progress Tracking

The `ProgressCallback` type allows monitoring transfer progress. Callbacks receive:
- `bytes_transferred`: Current progress
- `total_bytes`: Optional total size (may be unknown for streaming)

Progress tracking is optional and can be enabled per-transfer by setting the callback in options.

### Download Strategies

Three download approaches are supported:

1. **Memory Download**: Entire file loaded into memory (`downloadToMemory`)
2. **Direct to File**: Streaming download to disk (`downloadToFile`)
3. **Chunked Transfer**: Download in chunks with progress updates (`downloadChunked`)

Choose based on file size and memory constraints. Large files should use chunked or direct-to-file downloads.

### Multipart Form Encoding

The multipart/form-data encoding (RFC 2388) allows uploading files with metadata:

- **Boundary**: Unique separator between form parts
- **Text Fields**: Regular form fields with name/value pairs
- **File Fields**: Files with name, filename, content-type, and data

The `build()` method generates the properly formatted multipart body with boundary markers, content-disposition headers, and data sections.

### Memory Safety

Critical memory safety patterns used throughout:

**Error Cleanup with errdefer**:
```zig
pub fn addField(self: *MultipartForm, name: []const u8, value: []const u8) !void {
    const owned_name = try self.allocator.dupe(u8, name);
    errdefer self.allocator.free(owned_name);
    const owned_value = try self.allocator.dupe(u8, value);
    errdefer self.allocator.free(owned_value);  // Prevents leak if put() fails
    try self.fields.put(owned_name, owned_value);
}
```

**Chained Error Cleanup**:
```zig
pub fn addFile(...) !void {
    const owned_name = try self.allocator.dupe(u8, name);
    errdefer self.allocator.free(owned_name);

    const owned_filename = try self.allocator.dupe(u8, filename);
    errdefer self.allocator.free(owned_filename);

    const owned_content_type = try self.allocator.dupe(u8, content_type);
    errdefer self.allocator.free(owned_content_type);

    const owned_data = try self.allocator.dupe(u8, data);
    errdefer self.allocator.free(owned_data);

    // All allocations protected - if append fails, all are freed
    try self.files.append(self.allocator, file);
}
```

This pattern ensures that if any allocation fails, all previous allocations are properly cleaned up.

### Resumable Downloads

The `ResumeInfo` struct enables resuming interrupted downloads by:
1. Tracking download progress (bytes downloaded, total bytes)
2. Persisting state to a resume file
3. Loading state when resuming

This is useful for large files over unreliable connections. In a real implementation, you would:
- Use HTTP Range requests (`Range: bytes=12345-`)
- Verify file integrity with checksums
- Handle server resume support detection

### Real Implementation Considerations

This recipe uses simulated transfers for testing. A production implementation would:

**Use std.http.Client**:
```zig
var client = std.http.Client{ .allocator = allocator };
defer client.deinit();

var req = try client.request(.GET, uri, headers, .{});
defer req.deinit();
```

**Handle HTTP headers**:
- `Content-Length` for total size
- `Content-Range` for resume support
- `Content-Type` for file type detection

**Error handling and retries**:
- Network timeouts
- Connection failures
- Partial writes
- Disk space errors

**Security considerations**:
- Validate file paths (prevent directory traversal)
- Limit file sizes
- Sanitize filenames
- Verify content types
- Use HTTPS for sensitive transfers

### Zig 0.15.2 ArrayList API

This code uses the unmanaged ArrayList pattern in Zig 0.15.2:

```zig
var buffer = std.ArrayList(u8){};
defer buffer.deinit(allocator);

try buffer.appendSlice(allocator, data);
return buffer.toOwnedSlice(allocator);
```

The allocator is passed to each method rather than stored in the ArrayList.

### Advanced: Secure Boundary Generation

**Security Issue:** The multipart form boundary must be generated securely to prevent boundary collision attacks.

#### Why Boundary Security Matters

Consider this attack scenario:

1. Attacker uploads a malicious file containing: `----Boundary1234567890`
2. If the boundary is predictable (timestamp-based), attacker can guess it
3. File content matches the boundary, breaking multipart parsing
4. Server misinterprets file data as form fields
5. Can lead to injection attacks or data corruption

**Example Attack:**
```
// Malicious file content:
----Boundary1234567890
Content-Disposition: form-data; name="admin"

true
----Boundary1234567890--
```

If the boundary is predictable, this content can inject fake form fields.

#### Vulnerable Implementation (DO NOT USE)

```zig
// INSECURE: Timestamp is predictable
const timestamp = std.time.timestamp();
const boundary = try std.fmt.bufPrint(&boundary_buf, "----Boundary{d}", .{timestamp});

// Attacker can:
// 1. Know approximate server time
// 2. Include boundary string in file content
// 3. Break multipart parsing
```

Timestamps are predictable because:
- Server time can be inferred from HTTP Date headers
- Upload happens at known time (attacker controls timing)
- Only ~1 million possible values per day (1 second resolution)
- Easy to brute force all possibilities in file content

#### Secure Implementation (CORRECT)

The updated implementation uses cryptographically random boundaries:

```zig
pub fn init(allocator: std.mem.Allocator) !MultipartForm {
    // Generate cryptographically secure boundary
    var random_bytes: [16]u8 = undefined;
    std.crypto.random.bytes(&random_bytes);

    var boundary_buf: [50]u8 = undefined;
    const hex = std.fmt.bytesToHex(random_bytes, .lower);
    const boundary = try std.fmt.bufPrint(&boundary_buf, "----Boundary{s}", .{hex});
    // Result: "----Boundary4a3f9b2e7d8c1a6f..."
}
```

**Security Benefits:**
1. **128 bits of entropy** - 2^128 possible boundaries (~3.4 × 10^38)
2. **Unpredictable** - Attacker cannot guess boundary value
3. **Unique per upload** - New random boundary for each form
4. **Collision resistant** - Astronomically unlikely to match file content

**Why 16 bytes?**
- 128 bits of randomness exceeds security requirements
- 32 hex characters fit comfortably in boundary
- Same strength as AES-128 encryption
- Industry standard (comparable to UUIDs)

#### Comparison: Timestamp vs Cryptographic Random

| Aspect | Timestamp | Crypto Random |
|--------|-----------|---------------|
| Entropy | ~20 bits | 128 bits |
| Possible values | ~1 million/day | 2^128 |
| Predictable | Yes | No |
| Collision risk | High | Negligible |
| Attack difficulty | Trivial | Impossible |

#### When Boundaries Matter

Secure boundaries are critical when:
- Accepting file uploads from untrusted users
- Processing user-generated content
- Implementing public APIs
- Handling sensitive data

For internal tools with trusted users, timestamp boundaries may be acceptable, but crypto random has negligible overhead and is always safer.

#### Boundary Validation

Production systems should also validate boundaries don't appear in content:

```zig
pub fn validateBoundary(self: *const MultipartForm) !void {
    // Check boundary doesn't appear in any file data
    for (self.files.items) |file| {
        if (std.mem.indexOf(u8, file.data, self.boundary)) |_| {
            return error.BoundaryCollision;
        }
    }
}
```

However, with 128-bit random boundaries, collision probability is:
- 1 in 2^128 for random data
- Effectively impossible in practice
- More likely to win lottery 20 times consecutively

#### Industry Standards

Major platforms use similar approaches:
- **Browsers**: Generate random multipart boundaries (16+ bytes)
- **Python requests**: UUID4-based boundaries (128-bit random)
- **Node.js multer**: Crypto random boundaries
- **PHP**: Unique random identifiers

Our implementation follows these best practices while demonstrating the security rationale for educational purposes.

## See Also

- Recipe 11.1: Making HTTP requests
- Recipe 11.4: Building a simple HTTP server
- Recipe 11.6: Working with REST APIs

Full compilable example: `code/04-specialized/11-network-web/recipe_11_9.zig`
