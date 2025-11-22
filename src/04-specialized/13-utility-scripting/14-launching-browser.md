# Recipe 13.14: Launching a Web Browser

## Problem

You need to open a URL in the user's default web browser from your Zig application.

## Solution

Use platform-specific commands to launch the browser:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_14.zig:open_url}}
```

## Discussion

Opening URLs in a browser is common for documentation, authentication flows, and user-facing links. Each platform has a different mechanism for launching the default browser.

### Platform Commands

**macOS:** `open <url>`
**Linux:** `xdg-open <url>`
**Windows:** `cmd /c start <url>`

The solution detects the platform at compile time and uses the appropriate command.

### Browser Launcher

Create a more structured launcher:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_14.zig:browser_launcher}}
```

This provides better error handling and platform detection.

### Specific Browser

Launch a specific browser instead of the default:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_14.zig:specific_browser}}
```

Specific browsers require different commands per platform.

### URL Building

Build URLs with query parameters:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_14.zig:url_builder}}
```

URL builders make it easy to construct complex URLs programmatically.

### URL Validation

Validate and sanitize URLs before opening:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_14.zig:url_validator}}
```

Validation prevents opening malicious or malformed URLs.

### Browser Options

Launch browsers with specific options:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_14.zig:browser_options}}
```

Options control how the browser opens (new window, incognito, etc.).

### Safe Launcher

Create a security-aware launcher:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_14.zig:safe_launcher}}
```

Safe launchers restrict which URLs can be opened.

### Opening Local HTML Files

Open local HTML files in the browser:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_14.zig:html_file_opener}}
```

This converts file paths to `file://` URLs for browser consumption.

## Best Practices

1. **Validate URLs** - Always check URLs before opening
2. **Handle errors gracefully** - Browser may not be available
3. **Don't block** - Spawn browser asynchronously
4. **Sanitize input** - Escape special characters
5. **Provide fallback** - Show URL if browser fails
6. **Log attempts** - Track when URLs are opened
7. **Respect user choice** - Let users disable auto-opening

### Common Patterns

**Documentation links:**
```zig
pub fn openDocs(allocator: std.mem.Allocator) !void {
    const url = "https://ziglang.org/documentation/master/";
    try openURL(allocator, url);
}
```

**OAuth authentication:**
```zig
pub fn startOAuthFlow(allocator: std.mem.Allocator, auth_url: []const u8) !void {
    std.log.info("Opening browser for authentication...", .{});
    std.log.info("URL: {s}", .{auth_url});

    openURL(allocator, auth_url) catch |err| {
        std.log.err("Failed to open browser: {}", .{err});
        std.log.info("Please manually open: {s}", .{auth_url});
        return err;
    };

    std.log.info("Complete authentication in your browser", .{});
}
```

**Search engine query:**
```zig
pub fn searchWeb(allocator: std.mem.Allocator, query: []const u8) !void {
    var builder = URLBuilder.init(allocator, "https://www.google.com/search");
    defer builder.deinit();

    try builder.addParam("q", query);

    const url = try builder.build();
    defer allocator.free(url);

    try openURL(allocator, url);
}
```

**Report generation:**
```zig
pub fn viewReport(allocator: std.mem.Allocator, report_path: []const u8) !void {
    // Generate HTML report
    try generateHTMLReport(report_path);

    // Open in browser
    try openHTMLFile(allocator, report_path);

    std.log.info("Report opened in browser: {s}", .{report_path});
}
```

### Error Handling

**Graceful degradation:**
```zig
fn openURLWithFallback(allocator: std.mem.Allocator, url: []const u8) !void {
    const launcher = BrowserLauncher.init(allocator);

    if (!launcher.isSupported()) {
        std.log.warn("Browser launching not supported on this platform", .{});
        std.log.info("Please manually open: {s}", .{url});
        return error.UnsupportedPlatform;
    }

    launcher.open(url) catch |err| {
        std.log.err("Failed to launch browser: {}", .{err});
        std.log.info("Please manually open: {s}", .{url});
        return err;
    };
}
```

**User confirmation:**
```zig
fn openURLWithConfirmation(allocator: std.mem.Allocator, url: []const u8) !void {
    std.debug.print("Open URL in browser? {s}\n", .{url});
    std.debug.print("Press Enter to continue, Ctrl+C to cancel...\n", .{});

    const stdin = std.io.getStdIn().reader();
    var buf: [1]u8 = undefined;
    _ = try stdin.read(&buf);

    try openURL(allocator, url);
}
```

### Security Considerations

**URL validation:**
```zig
fn openSafeURL(allocator: std.mem.Allocator, url: []const u8) !void {
    // Only allow HTTPS
    if (!std.mem.startsWith(u8, url, "https://")) {
        return error.InsecureProtocol;
    }

    // Validate domain
    const allowed_domains = [_][]const u8{
        "example.com",
        "docs.example.com",
        "api.example.com",
    };

    var domain_ok = false;
    for (allowed_domains) |domain| {
        if (std.mem.indexOf(u8, url, domain) != null) {
            domain_ok = true;
            break;
        }
    }

    if (!domain_ok) {
        return error.UntrustedDomain;
    }

    try openURL(allocator, url);
}
```

**Prevent command injection:**
```zig
// BAD - vulnerable to injection
fn unsafeOpen(allocator: std.mem.Allocator, url: []const u8) !void {
    const cmd = try std.fmt.allocPrint(allocator, "open {s}", .{url});
    defer allocator.free(cmd);
    // NEVER do this - shell injection vulnerability
}

// GOOD - use argv array
fn safeOpen(allocator: std.mem.Allocator, url: []const u8) !void {
    var process = std.process.Child.init(&[_][]const u8{ "open", url }, allocator);
    try process.spawn();
    _ = try process.wait();
}
```

**Content Security Policy:**
```zig
pub const URLPolicy = struct {
    allow_http: bool = false,
    allow_file: bool = false,
    allowed_schemes: []const []const u8,
    blocked_domains: []const []const u8,

    pub fn check(self: *const URLPolicy, url: []const u8) !void {
        // Check scheme
        var scheme_ok = false;
        for (self.allowed_schemes) |scheme| {
            if (std.mem.startsWith(u8, url, scheme)) {
                scheme_ok = true;
                break;
            }
        }
        if (!scheme_ok) {
            return error.SchemeNotAllowed;
        }

        // Check blocked domains
        for (self.blocked_domains) |domain| {
            if (std.mem.indexOf(u8, url, domain) != null) {
                return error.DomainBlocked;
            }
        }
    }
};
```

### Advanced Usage

**Multiple URLs:**
```zig
pub fn openMultipleURLs(allocator: std.mem.Allocator, urls: []const []const u8) !void {
    const launcher = BrowserLauncher.init(allocator);

    for (urls, 0..) |url, i| {
        std.log.info("Opening URL {d}/{d}: {s}", .{ i + 1, urls.len, url });

        launcher.open(url) catch |err| {
            std.log.err("Failed to open {s}: {}", .{ url, err });
            continue;
        };

        // Small delay between openings
        if (i < urls.len - 1) {
            std.Thread.sleep(500 * std.time.ns_per_ms);
        }
    }
}
```

**Browser detection:**
```zig
pub fn detectInstalledBrowsers(allocator: std.mem.Allocator) ![]SpecificBrowser {
    var browsers = std.ArrayList(SpecificBrowser){};
    errdefer browsers.deinit(allocator);

    const candidates = [_]SpecificBrowser{ .chrome, .firefox, .safari, .edge };

    for (candidates) |browser| {
        if (try isBrowserInstalled(allocator, browser)) {
            try browsers.append(allocator, browser);
        }
    }

    return try browsers.toOwnedSlice(allocator);
}

fn isBrowserInstalled(allocator: std.mem.Allocator, browser: SpecificBrowser) !bool {
    const command = switch (builtin.os.tag) {
        .macos => &[_][]const u8{ "which", try browser.getMacOSBinary() },
        .linux => &[_][]const u8{ "which", try browser.getLinuxBinary() },
        .windows => &[_][]const u8{ "where", try browser.getWindowsBinary() },
        else => return false,
    };

    var process = std.process.Child.init(command, allocator);
    process.stdout_behavior = .Ignore;
    process.stderr_behavior = .Ignore;

    try process.spawn();
    const result = try process.wait();

    return result.Exited == 0;
}
```

**Custom browser profiles:**
```zig
pub fn openWithProfile(
    allocator: std.mem.Allocator,
    url: []const u8,
    profile: []const u8,
) !void {
    const command = switch (builtin.os.tag) {
        .macos => try std.fmt.allocPrint(
            allocator,
            "open -a 'Google Chrome' --args --profile-directory='{s}' {s}",
            .{ profile, url },
        ),
        .linux => try std.fmt.allocPrint(
            allocator,
            "google-chrome --profile-directory='{s}' {s}",
            .{ profile, url },
        ),
        .windows => try std.fmt.allocPrint(
            allocator,
            "chrome --profile-directory=\"{s}\" {s}",
            .{ profile, url },
        ),
        else => return error.UnsupportedPlatform,
    };
    defer allocator.free(command);

    var process = std.process.Child.init(&[_][]const u8{command}, allocator);
    try process.spawn();
    _ = try process.wait();
}
```

### Testing

**Mock browser launching:**
```zig
const TestBrowserLauncher = struct {
    last_url: ?[]const u8 = null,
    should_fail: bool = false,

    fn open(self: *TestBrowserLauncher, url: []const u8) !void {
        if (self.should_fail) return error.BrowserLaunchFailed;
        self.last_url = url;
    }

    fn reset(self: *TestBrowserLauncher) void {
        self.last_url = null;
        self.should_fail = false;
    }
};

test "application opens docs" {
    var mock = TestBrowserLauncher{};

    // Simulate opening docs
    try mock.open("https://docs.example.com");

    try testing.expectEqualStrings("https://docs.example.com", mock.last_url.?);
}
```

**Integration test:**
```zig
test "url builder and launcher integration" {
    var builder = URLBuilder.init(testing.allocator, "https://example.com/search");
    defer builder.deinit();

    try builder.addParam("q", "zig+programming");
    try builder.addParam("sort", "relevance");

    const url = try builder.build();
    defer testing.allocator.free(url);

    // Validate constructed URL
    try testing.expect(URLValidator.isValid(url));
    try testing.expect(std.mem.indexOf(u8, url, "q=zig+programming") != null);

    // Would launch browser in real scenario:
    // try openURL(testing.allocator, url);
}
```

### Platform-Specific Notes

**macOS:**
- `open` command supports `-a` flag for specific apps
- Can use `-g` to open in background
- Supports `-n` for new instance

**Linux:**
- `xdg-open` respects desktop environment settings
- Fallback to `sensible-browser` if `xdg-open` unavailable
- May need `xdg-utils` package installed

**Windows:**
- `start` requires `cmd /c` prefix
- Use double quotes for URLs with spaces
- May trigger Windows Defender SmartScreen

### Complete Example

Full application with browser launching:

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const launcher = BrowserLauncher.init(allocator);

    if (!launcher.isSupported()) {
        std.debug.print("Browser launching not supported\n", .{});
        return;
    }

    // Build search URL
    var builder = URLBuilder.init(allocator, "https://ziglang.org/documentation/master/");
    defer builder.deinit();

    try builder.addParam("search", "ArrayList");

    const url = try builder.build();
    defer allocator.free(url);

    // Validate
    if (!URLValidator.isValid(url)) {
        std.debug.print("Invalid URL: {s}\n", .{url});
        return error.InvalidURL;
    }

    // Launch
    std.debug.print("Opening documentation...\n", .{});
    std.debug.print("URL: {s}\n", .{url});

    launcher.open(url) catch |err| {
        std.debug.print("Failed to open browser: {}\n", .{err});
        std.debug.print("Please manually open: {s}\n", .{url});
        return err;
    };

    std.debug.print("Documentation opened in browser\n", .{});
}
```

### Troubleshooting

**Browser not found:**
```zig
fn findBrowser(allocator: std.mem.Allocator) ![]const u8 {
    const browsers = switch (builtin.os.tag) {
        .linux => &[_][]const u8{ "xdg-open", "sensible-browser", "firefox", "chrome" },
        .macos => &[_][]const u8{ "open" },
        .windows => &[_][]const u8{ "start" },
        else => return error.UnsupportedPlatform,
    };

    for (browsers) |browser| {
        if (try commandExists(allocator, browser)) {
            return try allocator.dupe(u8, browser);
        }
    }

    return error.NoBrowserFound;
}

fn commandExists(allocator: std.mem.Allocator, command: []const u8) !bool {
    var process = std.process.Child.init(
        &[_][]const u8{ "which", command },
        allocator,
    );
    process.stdout_behavior = .Ignore;
    process.stderr_behavior = .Ignore;

    try process.spawn();
    const result = try process.wait();

    return result.Exited == 0;
}
```

**Timeout handling:**
```zig
fn openURLWithTimeout(allocator: std.mem.Allocator, url: []const u8, timeout_ms: u64) !void {
    var process = std.process.Child.init(
        &[_][]const u8{ "open", url },
        allocator,
    );

    try process.spawn();

    const start = std.time.milliTimestamp();
    while (std.time.milliTimestamp() - start < timeout_ms) {
        if (try process.tryWait()) |status| {
            if (status.Exited != 0) {
                return error.BrowserLaunchFailed;
            }
            return;
        }
        std.Thread.sleep(100 * std.time.ns_per_ms);
    }

    // Timeout - kill process
    try process.kill();
    return error.Timeout;
}
```

## See Also

- Recipe 13.5: Executing an external command and getting its output
- Recipe 13.15: Parsing command-line options
- Recipe 11.1: Making HTTP requests

Full compilable example: `code/04-specialized/13-utility-scripting/recipe_13_14.zig`
