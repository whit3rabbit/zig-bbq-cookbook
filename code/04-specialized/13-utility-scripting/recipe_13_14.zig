const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");

// Windows API declarations for secure URL opening
// SECURITY: We use ShellExecuteW instead of cmd.exe to avoid command injection
const windows = if (builtin.os.tag == .windows) struct {
    const WINAPI = std.os.windows.WINAPI;
    const HWND = std.os.windows.HWND;
    const HINSTANCE = std.os.windows.HINSTANCE;
    const LPWSTR = [*:0]const u16;

    // ShellExecuteW from shell32.dll
    // See: https://learn.microsoft.com/en-us/windows/win32/api/shellapi/nf-shellapi-shellexecutew
    extern "shell32" fn ShellExecuteW(
        hwnd: ?HWND,
        lpOperation: ?LPWSTR,
        lpFile: LPWSTR,
        lpParameters: ?LPWSTR,
        lpDirectory: ?LPWSTR,
        nShowCmd: i32,
    ) callconv(WINAPI) ?HINSTANCE;

    const SW_SHOWNORMAL = 1;

    // Convert UTF-8 to UTF-16 for Windows API
    fn toWideString(allocator: std.mem.Allocator, str: []const u8) ![:0]u16 {
        const len = try std.unicode.utf8ToUtf16LeStringLiteral(allocator, str);
        return len;
    }
} else struct {};

// ANCHOR: open_url
/// Open URL in default browser
/// SECURITY: This function validates URLs and uses platform-specific secure methods
/// to prevent command injection attacks. On Windows, it uses ShellExecuteW API
/// instead of cmd.exe to avoid shell metacharacter injection vulnerabilities.
pub fn openURL(allocator: std.mem.Allocator, url: []const u8) !void {
    // SECURITY: Validate URL for shell metacharacters BEFORE opening
    // This prevents injection attacks like: "https://example.com&calc.exe"
    if (!URLValidator.isSafeForShell(url)) {
        return error.UnsafeURL;
    }

    if (builtin.os.tag == .windows) {
        // SECURITY: Use ShellExecuteW API to avoid cmd.exe and command injection
        // This is much safer than using "cmd /c start <url>" which would be
        // vulnerable to shell metacharacters like &, |, >, <, ;, etc.
        const wide_url = try windows.toWideString(allocator, url);
        defer allocator.free(wide_url);

        const open_verb = try windows.toWideString(allocator, "open");
        defer allocator.free(open_verb);

        const result = windows.ShellExecuteW(
            null, // hwnd (no parent window)
            open_verb.ptr, // operation: "open"
            wide_url.ptr, // file/URL to open
            null, // parameters
            null, // directory
            windows.SW_SHOWNORMAL, // show command
        );

        // ShellExecuteW returns a value > 32 on success
        if (@intFromPtr(result) <= 32) {
            return error.ShellExecuteFailed;
        }
    } else if (builtin.os.tag == .macos or builtin.os.tag == .linux) {
        // SECURITY: While macOS/Linux commands are safer than Windows cmd.exe,
        // we still validate the URL above to prevent potential issues
        const command = switch (builtin.os.tag) {
            .macos => &[_][]const u8{ "open", url },
            .linux => &[_][]const u8{ "xdg-open", url },
            else => unreachable,
        };

        var process = std.process.Child.init(command, allocator);
        process.stdin_behavior = .Ignore;
        process.stdout_behavior = .Ignore;
        process.stderr_behavior = .Ignore;

        try process.spawn();
        _ = try process.wait();
    } else {
        return error.UnsupportedPlatform;
    }
}

test "open url validates safe URLs" {
    // Test that safe URLs are accepted
    const safe_url = "https://example.com";
    try testing.expect(URLValidator.isSafeForShell(safe_url));
}

test "open url rejects unsafe URLs with shell metacharacters" {
    // SECURITY TEST: URLs with shell metacharacters should be rejected
    const unsafe_urls = [_][]const u8{
        "https://example.com&calc.exe", // & for command chaining
        "https://example.com|whoami", // | for piping
        "https://example.com;rm -rf /", // ; for command separation
        "https://example.com>file.txt", // > for redirection
        "https://example.com<input.txt", // < for input redirection
        "https://example.com$(whoami)", // $() for command substitution
        "https://example.com`whoami`", // backticks for command substitution
    };

    for (unsafe_urls) |url| {
        try testing.expect(!URLValidator.isSafeForShell(url));
    }
}
// ANCHOR_END: open_url

// ANCHOR: browser_launcher
/// Browser launcher with platform detection
/// SECURITY: Uses secure platform-specific methods to prevent command injection
pub const BrowserLauncher = struct {
    allocator: std.mem.Allocator,
    platform: Platform,

    pub const Platform = enum {
        macos,
        linux,
        windows,
        unsupported,

        pub fn detect() Platform {
            return switch (builtin.os.tag) {
                .macos => .macos,
                .linux => .linux,
                .windows => .windows,
                else => .unsupported,
            };
        }
    };

    pub fn init(allocator: std.mem.Allocator) BrowserLauncher {
        return .{
            .allocator = allocator,
            .platform = Platform.detect(),
        };
    }

    /// Open URL in browser
    /// SECURITY: Validates URLs and uses secure platform-specific methods
    pub fn open(self: *const BrowserLauncher, url: []const u8) !void {
        // SECURITY: Validate URL for shell metacharacters
        if (!URLValidator.isSafeForShell(url)) {
            return error.UnsafeURL;
        }

        switch (self.platform) {
            .windows => {
                if (builtin.os.tag == .windows) {
                    // SECURITY: Use ShellExecuteW API to avoid cmd.exe
                    const wide_url = try windows.toWideString(self.allocator, url);
                    defer self.allocator.free(wide_url);

                    const open_verb = try windows.toWideString(self.allocator, "open");
                    defer self.allocator.free(open_verb);

                    const result = windows.ShellExecuteW(
                        null,
                        open_verb.ptr,
                        wide_url.ptr,
                        null,
                        null,
                        windows.SW_SHOWNORMAL,
                    );

                    if (@intFromPtr(result) <= 32) {
                        return error.ShellExecuteFailed;
                    }
                } else {
                    unreachable; // platform detection ensures this doesn't happen
                }
            },
            .macos, .linux => {
                const command = switch (self.platform) {
                    .macos => &[_][]const u8{ "open", url },
                    .linux => &[_][]const u8{ "xdg-open", url },
                    else => unreachable,
                };

                var process = std.process.Child.init(command, self.allocator);
                process.stdin_behavior = .Ignore;
                process.stdout_behavior = .Ignore;
                process.stderr_behavior = .Ignore;

                try process.spawn();
                _ = try process.wait();
            },
            .unsupported => return error.UnsupportedPlatform,
        }
    }

    pub fn isSupported(self: *const BrowserLauncher) bool {
        return self.platform != .unsupported;
    }
};

test "browser launcher platform detection" {
    const launcher = BrowserLauncher.init(testing.allocator);

    try testing.expect(launcher.isSupported());
    try testing.expect(launcher.platform != .unsupported);
}
// ANCHOR_END: browser_launcher

// ANCHOR: specific_browser
/// Launch specific browser
/// SECURITY: Validates URLs before launching to prevent command injection
pub const SpecificBrowser = enum {
    chrome,
    firefox,
    safari,
    edge,

    /// Open URL in specific browser
    /// SECURITY: Validates URL and uses direct process execution (not shell)
    pub fn open(self: SpecificBrowser, allocator: std.mem.Allocator, url: []const u8) !void {
        // SECURITY: Validate URL before opening
        if (!URLValidator.isSafeForShell(url)) {
            return error.UnsafeURL;
        }

        switch (builtin.os.tag) {
            .macos => try self.openMacOS(allocator, url),
            .linux => try self.openLinux(allocator, url),
            .windows => try self.openWindows(allocator, url),
            else => return error.UnsupportedPlatform,
        }
    }

    fn openMacOS(self: SpecificBrowser, allocator: std.mem.Allocator, url: []const u8) !void {
        const app = switch (self) {
            .chrome => "Google Chrome",
            .firefox => "Firefox",
            .safari => "Safari",
            .edge => "Microsoft Edge",
        };

        // SECURITY: Use array of arguments instead of string concatenation
        // This prevents shell interpretation of special characters
        const args = [_][]const u8{ "open", "-a", app, url };

        var process = std.process.Child.init(&args, allocator);
        process.stdin_behavior = .Ignore;
        process.stdout_behavior = .Ignore;
        process.stderr_behavior = .Ignore;

        try process.spawn();
        _ = try process.wait();
    }

    fn openLinux(self: SpecificBrowser, allocator: std.mem.Allocator, url: []const u8) !void {
        const binary = switch (self) {
            .chrome => "google-chrome",
            .firefox => "firefox",
            .safari => return error.SafariNotAvailableOnLinux,
            .edge => "microsoft-edge",
        };

        // SECURITY: Use array of arguments instead of string concatenation
        const args = [_][]const u8{ binary, url };

        var process = std.process.Child.init(&args, allocator);
        process.stdin_behavior = .Ignore;
        process.stdout_behavior = .Ignore;
        process.stderr_behavior = .Ignore;

        try process.spawn();
        _ = try process.wait();
    }

    fn openWindows(self: SpecificBrowser, allocator: std.mem.Allocator, url: []const u8) !void {
        const binary = switch (self) {
            .chrome => "chrome.exe",
            .firefox => "firefox.exe",
            .safari => return error.SafariNotAvailableOnWindows,
            .edge => "msedge.exe",
        };

        // SECURITY: Use array of arguments instead of string concatenation
        const args = [_][]const u8{ binary, url };

        var process = std.process.Child.init(&args, allocator);
        process.stdin_behavior = .Ignore;
        process.stdout_behavior = .Ignore;
        process.stderr_behavior = .Ignore;

        try process.spawn();
        _ = try process.wait();
    }
};

test "specific browser enum values" {
    // Test that all browsers are defined
    const chrome: SpecificBrowser = .chrome;
    const firefox: SpecificBrowser = .firefox;
    const safari: SpecificBrowser = .safari;
    const edge: SpecificBrowser = .edge;

    try testing.expect(chrome != firefox);
    try testing.expect(safari != edge);
}

test "specific browser url validation" {
    // SECURITY TEST: Verify that unsafe URLs are rejected
    const unsafe_url = "https://example.com&calc.exe";

    const result = SpecificBrowser.chrome.open(testing.allocator, unsafe_url);
    try testing.expectError(error.UnsafeURL, result);
}
// ANCHOR_END: specific_browser

// ANCHOR: url_builder
/// Build URLs with parameters
/// MEMORY: URLBuilder owns all strings passed to it and must free them in deinit()
pub const URLBuilder = struct {
    base: []const u8,
    params: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, base: []const u8) !URLBuilder {
        // MEMORY: Duplicate base string to ensure URLBuilder owns it
        const owned_base = try allocator.dupe(u8, base);
        return .{
            .base = owned_base,
            .params = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *URLBuilder) void {
        // MEMORY: Free the owned base string
        self.allocator.free(self.base);

        // MEMORY: Free all owned keys and values from the HashMap
        var iter = self.params.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.params.deinit();
    }

    pub fn addParam(self: *URLBuilder, key: []const u8, value: []const u8) !void {
        // MEMORY: Duplicate both key and value to ensure URLBuilder owns them
        // This prevents Use-After-Free if caller passes temporary buffers
        const owned_key = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned_key);

        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);

        try self.params.put(owned_key, owned_value);
    }

    pub fn build(self: *const URLBuilder) ![]const u8 {
        var result = std.ArrayList(u8){};
        errdefer result.deinit(self.allocator);

        try result.appendSlice(self.allocator, self.base);

        var first = true;
        var iter = self.params.iterator();
        while (iter.next()) |entry| {
            if (first) {
                try result.append(self.allocator, '?');
                first = false;
            } else {
                try result.append(self.allocator, '&');
            }

            try result.appendSlice(self.allocator, entry.key_ptr.*);
            try result.append(self.allocator, '=');
            try result.appendSlice(self.allocator, entry.value_ptr.*);
        }

        return try result.toOwnedSlice(self.allocator);
    }
};

test "url builder basic usage" {
    var builder = try URLBuilder.init(testing.allocator, "https://example.com/search");
    defer builder.deinit();

    try builder.addParam("q", "zig+lang");
    try builder.addParam("type", "code");

    const url = try builder.build();
    defer testing.allocator.free(url);

    try testing.expect(std.mem.startsWith(u8, url, "https://example.com/search?"));
    try testing.expect(std.mem.indexOf(u8, url, "q=zig+lang") != null);
    try testing.expect(std.mem.indexOf(u8, url, "type=code") != null);
}

test "url builder with temporary buffers" {
    // MEMORY TEST: Verify URLBuilder handles temporary buffers safely
    // This test ensures URLBuilder duplicates strings to prevent Use-After-Free
    var builder = try URLBuilder.init(testing.allocator, "https://api.example.com");
    defer builder.deinit();

    // Simulate temporary stack buffers that go out of scope
    {
        var key_buffer: [50]u8 = undefined;
        const temp_key = try std.fmt.bufPrint(&key_buffer, "user_id", .{});

        var value_buffer: [50]u8 = undefined;
        const temp_value = try std.fmt.bufPrint(&value_buffer, "{d}", .{12345});

        // URLBuilder should duplicate these strings, not just store pointers
        try builder.addParam(temp_key, temp_value);
        // Buffers go out of scope here, but URLBuilder owns copies
    }

    // If URLBuilder didn't dupe strings, this would be Use-After-Free
    const url = try builder.build();
    defer testing.allocator.free(url);

    try testing.expect(std.mem.indexOf(u8, url, "user_id=12345") != null);
}

test "url builder memory safety" {
    // MEMORY TEST: Ensure testing allocator catches any leaks
    var builder = try URLBuilder.init(testing.allocator, "https://example.com");
    defer builder.deinit();

    try builder.addParam("key1", "value1");
    try builder.addParam("key2", "value2");
    try builder.addParam("key3", "value3");

    const url = try builder.build();
    defer testing.allocator.free(url);

    // If deinit() doesn't free all duplicated strings, testing allocator will fail
    try testing.expect(url.len > 0);
}
// ANCHOR_END: url_builder

// ANCHOR: url_validator
/// Validate URLs before opening
/// SECURITY: Provides validation to prevent command injection and other attacks
pub const URLValidator = struct {
    pub fn isValid(url: []const u8) bool {
        if (url.len == 0) return false;

        // Check for protocol
        if (!std.mem.startsWith(u8, url, "http://") and
            !std.mem.startsWith(u8, url, "https://") and
            !std.mem.startsWith(u8, url, "file://"))
        {
            return false;
        }

        // Basic sanity checks
        if (std.mem.indexOf(u8, url, " ") != null) return false;

        return true;
    }

    /// Check if URL is safe for shell execution
    /// SECURITY: This is CRITICAL for preventing command injection attacks.
    /// Shell metacharacters can allow arbitrary command execution, especially
    /// on Windows where cmd.exe is often used. This function blocks URLs
    /// containing dangerous characters that could be used to inject commands.
    ///
    /// Examples of attacks prevented:
    /// - "https://example.com&calc.exe" - Chain commands with &
    /// - "https://example.com|whoami" - Pipe output to another command
    /// - "https://example.com;rm -rf /" - Execute multiple commands
    /// - "https://example.com>file.txt" - Redirect output to overwrite files
    /// - "https://example.com$(whoami)" - Command substitution
    /// - "https://example.com`whoami`" - Command substitution (backticks)
    pub fn isSafeForShell(url: []const u8) bool {
        if (!isValid(url)) return false;

        // SECURITY: Check for shell metacharacters that could enable command injection
        // These characters have special meaning in shells and can be used to:
        // - Chain commands: & && | || ;
        // - Redirect I/O: < > >> 2>
        // - Execute commands: $ ` ( ) { }
        // - Escape sequences: \ ^ (Windows)
        // - Quotes that could break out: " '
        const dangerous_chars = "&|;<>$`(){}\\^\"'";

        for (url) |char| {
            for (dangerous_chars) |dangerous| {
                if (char == dangerous) {
                    return false;
                }
            }
        }

        // Additional check for command substitution patterns
        if (std.mem.indexOf(u8, url, "$(") != null) return false;
        if (std.mem.indexOf(u8, url, "${") != null) return false;

        return true;
    }

    pub fn sanitize(allocator: std.mem.Allocator, url: []const u8) ![]const u8 {
        // Add https:// if no protocol specified
        if (!std.mem.startsWith(u8, url, "http://") and
            !std.mem.startsWith(u8, url, "https://") and
            !std.mem.startsWith(u8, url, "file://"))
        {
            return try std.fmt.allocPrint(allocator, "https://{s}", .{url});
        }

        return try allocator.dupe(u8, url);
    }

    pub fn escapeSpaces(allocator: std.mem.Allocator, url: []const u8) ![]const u8 {
        if (std.mem.indexOf(u8, url, " ") == null) {
            return try allocator.dupe(u8, url);
        }

        var result = std.ArrayList(u8){};
        errdefer result.deinit(allocator);

        for (url) |c| {
            if (c == ' ') {
                try result.appendSlice(allocator, "%20");
            } else {
                try result.append(allocator, c);
            }
        }

        return try result.toOwnedSlice(allocator);
    }
};

test "url validator" {
    try testing.expect(URLValidator.isValid("https://example.com"));
    try testing.expect(URLValidator.isValid("http://example.com"));
    try testing.expect(URLValidator.isValid("file:///path/to/file.html"));

    try testing.expect(!URLValidator.isValid("not a url"));
    try testing.expect(!URLValidator.isValid(""));
    try testing.expect(!URLValidator.isValid("https://example.com with spaces"));
}

test "url validator shell safety" {
    // SECURITY TEST: Test that isSafeForShell properly detects injection attempts

    // Safe URLs should pass
    try testing.expect(URLValidator.isSafeForShell("https://example.com"));
    try testing.expect(URLValidator.isSafeForShell("https://example.com/path"));
    try testing.expect(URLValidator.isSafeForShell("https://example.com/path?query=value"));
    try testing.expect(URLValidator.isSafeForShell("https://example.com:8080/path"));

    // URLs with shell metacharacters should fail
    try testing.expect(!URLValidator.isSafeForShell("https://example.com&calc.exe"));
    try testing.expect(!URLValidator.isSafeForShell("https://example.com|whoami"));
    try testing.expect(!URLValidator.isSafeForShell("https://example.com;ls"));
    try testing.expect(!URLValidator.isSafeForShell("https://example.com>file.txt"));
    try testing.expect(!URLValidator.isSafeForShell("https://example.com<input.txt"));
    try testing.expect(!URLValidator.isSafeForShell("https://example.com$(whoami)"));
    try testing.expect(!URLValidator.isSafeForShell("https://example.com`whoami`"));
    try testing.expect(!URLValidator.isSafeForShell("https://example.com${USER}"));
    try testing.expect(!URLValidator.isSafeForShell("https://example.com(test)"));
    try testing.expect(!URLValidator.isSafeForShell("https://example.com\\test"));
    try testing.expect(!URLValidator.isSafeForShell("https://example.com^test"));
    try testing.expect(!URLValidator.isSafeForShell("https://example.com\"test\""));
    try testing.expect(!URLValidator.isSafeForShell("https://example.com'test'"));
}

test "url sanitize" {
    const sanitized = try URLValidator.sanitize(testing.allocator, "example.com");
    defer testing.allocator.free(sanitized);

    try testing.expectEqualStrings("https://example.com", sanitized);
}

test "url escape spaces" {
    const escaped = try URLValidator.escapeSpaces(testing.allocator, "https://example.com/hello world");
    defer testing.allocator.free(escaped);

    try testing.expectEqualStrings("https://example.com/hello%20world", escaped);
}
// ANCHOR_END: url_validator

// ANCHOR: browser_options
/// Browser launch options
pub const BrowserOptions = struct {
    new_window: bool = false,
    new_tab: bool = false,
    incognito: bool = false,
    fullscreen: bool = false,

    pub fn toArgs(self: BrowserOptions, allocator: std.mem.Allocator, browser: SpecificBrowser) ![]const []const u8 {
        var args = std.ArrayList([]const u8){};
        errdefer {
            for (args.items) |arg| {
                allocator.free(arg);
            }
            args.deinit(allocator);
        }

        if (self.new_window) {
            const arg = switch (browser) {
                .chrome, .edge => try allocator.dupe(u8, "--new-window"),
                .firefox => try allocator.dupe(u8, "-new-window"),
                .safari => try allocator.dupe(u8, "-n"),
            };
            try args.append(allocator, arg);
        }

        if (self.incognito) {
            const arg = switch (browser) {
                .chrome => try allocator.dupe(u8, "--incognito"),
                .firefox => try allocator.dupe(u8, "-private"),
                .edge => try allocator.dupe(u8, "-inprivate"),
                .safari => return error.SafariNoIncognitoFlag,
            };
            try args.append(allocator, arg);
        }

        if (self.fullscreen) {
            const arg = switch (browser) {
                .chrome, .edge => try allocator.dupe(u8, "--start-fullscreen"),
                .firefox => try allocator.dupe(u8, "-fullscreen"),
                .safari => return error.SafariNoFullscreenFlag,
            };
            try args.append(allocator, arg);
        }

        return try args.toOwnedSlice(allocator);
    }

    pub fn freeArgs(allocator: std.mem.Allocator, args: []const []const u8) void {
        for (args) |arg| {
            allocator.free(arg);
        }
        allocator.free(args);
    }
};

test "browser options to args" {
    const options = BrowserOptions{
        .new_window = true,
        .incognito = true,
    };

    const args = try options.toArgs(testing.allocator, .chrome);
    defer BrowserOptions.freeArgs(testing.allocator, args);

    try testing.expectEqual(2, args.len);
    try testing.expectEqualStrings("--new-window", args[0]);
    try testing.expectEqualStrings("--incognito", args[1]);
}
// ANCHOR_END: browser_options

// ANCHOR: safe_launcher
/// Safe browser launcher with validation
/// SECURITY: Provides additional layers of validation beyond shell safety checks
/// - Restricts file:// URLs to prevent local file access
/// - Enforces domain allowlisting to prevent phishing/malicious redirects
/// - Combines all validation checks before launching
pub const SafeBrowserLauncher = struct {
    launcher: BrowserLauncher,
    allow_file_urls: bool,
    allowed_domains: ?[]const []const u8,

    pub fn init(allocator: std.mem.Allocator, allow_file_urls: bool, allowed_domains: ?[]const []const u8) SafeBrowserLauncher {
        return .{
            .launcher = BrowserLauncher.init(allocator),
            .allow_file_urls = allow_file_urls,
            .allowed_domains = allowed_domains,
        };
    }

    /// Open URL with strict validation
    /// SECURITY: Multiple layers of validation prevent various attack vectors
    pub fn open(self: *const SafeBrowserLauncher, url: []const u8) !void {
        // SECURITY: Basic URL structure validation
        if (!URLValidator.isValid(url)) {
            return error.InvalidURL;
        }

        // SECURITY: Prevent local file access unless explicitly allowed
        // This protects against URLs like file:///etc/passwd or file://C:/Windows/System32/
        if (std.mem.startsWith(u8, url, "file://") and !self.allow_file_urls) {
            return error.FileURLsNotAllowed;
        }

        // SECURITY: Domain allowlisting prevents phishing and malicious redirects
        // Only URLs containing allowed domains will be opened
        if (self.allowed_domains) |domains| {
            var allowed = false;
            for (domains) |domain| {
                if (std.mem.indexOf(u8, url, domain) != null) {
                    allowed = true;
                    break;
                }
            }
            if (!allowed) {
                return error.DomainNotAllowed;
            }
        }

        // SECURITY: launcher.open() performs additional shell safety checks
        // and uses platform-specific secure APIs (ShellExecuteW on Windows)
        try self.launcher.open(url);
    }
};

test "safe browser launcher validation" {
    const allowed_domains = [_][]const u8{ "example.com", "trusted.org" };
    const safe_launcher = SafeBrowserLauncher.init(
        testing.allocator,
        false,
        &allowed_domains,
    );

    // Should reject file URLs
    const result1 = safe_launcher.open("file:///etc/passwd");
    try testing.expectError(error.FileURLsNotAllowed, result1);

    // Should reject non-allowed domains
    const result2 = safe_launcher.open("https://malicious.com");
    try testing.expectError(error.DomainNotAllowed, result2);

    // Should reject invalid URLs
    const result3 = safe_launcher.open("not a url");
    try testing.expectError(error.InvalidURL, result3);
}
// ANCHOR_END: safe_launcher

// ANCHOR: html_file_opener
/// Open local HTML file in browser
/// SECURITY: Uses secure launcher with validation for file:// URLs
pub fn openHTMLFile(allocator: std.mem.Allocator, file_path: []const u8) !void {
    // Convert to absolute path (validates file exists)
    const abs_path = try std.fs.cwd().realpathAlloc(allocator, file_path);
    defer allocator.free(abs_path);

    // Create file:// URL
    const url = try std.fmt.allocPrint(allocator, "file://{s}", .{abs_path});
    defer allocator.free(url);

    // SECURITY: Uses BrowserLauncher which validates URLs and uses secure APIs
    const launcher = BrowserLauncher.init(allocator);
    try launcher.open(url);
}

test "html file opener path construction" {
    const file_path = "test.html";

    const abs_path = try std.fs.cwd().realpathAlloc(testing.allocator, ".");
    defer testing.allocator.free(abs_path);

    const url = try std.fmt.allocPrint(testing.allocator, "file://{s}/{s}", .{ abs_path, file_path });
    defer testing.allocator.free(url);

    try testing.expect(std.mem.startsWith(u8, url, "file://"));
    try testing.expect(std.mem.endsWith(u8, url, "test.html"));
}
// ANCHOR_END: html_file_opener
