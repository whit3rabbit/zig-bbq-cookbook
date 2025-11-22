const std = @import("std");
const testing = std.testing;

// ANCHOR: cookie
pub const Cookie = struct {
    name: []const u8,
    value: []const u8,
    domain: ?[]const u8,
    path: ?[]const u8,
    expires: ?i64, // Unix timestamp
    max_age: ?i64, // Seconds
    http_only: bool,
    secure: bool,
    same_site: SameSite,
    allocator: std.mem.Allocator,

    pub const SameSite = enum {
        none,
        lax,
        strict,

        pub fn toString(self: SameSite) []const u8 {
            return switch (self) {
                .none => "None",
                .lax => "Lax",
                .strict => "Strict",
            };
        }
    };

    pub fn init(allocator: std.mem.Allocator, name: []const u8, value: []const u8) !Cookie {
        return .{
            .name = try allocator.dupe(u8, name),
            .value = try allocator.dupe(u8, value),
            .domain = null,
            .path = null,
            .expires = null,
            .max_age = null,
            .http_only = false,
            .secure = false,
            .same_site = .lax,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Cookie) void {
        self.allocator.free(self.name);
        self.allocator.free(self.value);
        if (self.domain) |domain| self.allocator.free(domain);
        if (self.path) |path| self.allocator.free(path);
    }

    pub fn setDomain(self: *Cookie, domain: []const u8) !void {
        if (self.domain) |old_domain| {
            self.allocator.free(old_domain);
        }
        self.domain = try self.allocator.dupe(u8, domain);
    }

    pub fn setPath(self: *Cookie, path: []const u8) !void {
        if (self.path) |old_path| {
            self.allocator.free(old_path);
        }
        self.path = try self.allocator.dupe(u8, path);
    }

    pub fn toSetCookieHeader(self: *const Cookie) ![]const u8 {
        var buffer = std.ArrayList(u8){};
        defer buffer.deinit(self.allocator);

        // Name=Value
        try buffer.appendSlice(self.allocator, self.name);
        try buffer.append(self.allocator, '=');
        try buffer.appendSlice(self.allocator, self.value);

        // Domain
        if (self.domain) |domain| {
            try buffer.appendSlice(self.allocator, "; Domain=");
            try buffer.appendSlice(self.allocator, domain);
        }

        // Path
        if (self.path) |path| {
            try buffer.appendSlice(self.allocator, "; Path=");
            try buffer.appendSlice(self.allocator, path);
        }

        // Expires
        if (self.expires) |expires| {
            try buffer.appendSlice(self.allocator, "; Expires=");
            var time_buf: [32]u8 = undefined;
            const time_str = try std.fmt.bufPrint(&time_buf, "{d}", .{expires});
            try buffer.appendSlice(self.allocator, time_str);
        }

        // Max-Age
        if (self.max_age) |max_age| {
            try buffer.appendSlice(self.allocator, "; Max-Age=");
            var age_buf: [32]u8 = undefined;
            const age_str = try std.fmt.bufPrint(&age_buf, "{d}", .{max_age});
            try buffer.appendSlice(self.allocator, age_str);
        }

        // HttpOnly
        if (self.http_only) {
            try buffer.appendSlice(self.allocator, "; HttpOnly");
        }

        // Secure
        if (self.secure) {
            try buffer.appendSlice(self.allocator, "; Secure");
        }

        // SameSite
        if (self.same_site != .lax) {
            try buffer.appendSlice(self.allocator, "; SameSite=");
            try buffer.appendSlice(self.allocator, self.same_site.toString());
        }

        return buffer.toOwnedSlice(self.allocator);
    }
};
// ANCHOR_END: cookie

// ANCHOR: cookie_parser
pub const CookieParser = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) CookieParser {
        return .{ .allocator = allocator };
    }

    pub fn parse(self: *CookieParser, cookie_header: []const u8) !std.StringHashMap([]const u8) {
        var cookies = std.StringHashMap([]const u8).init(self.allocator);
        errdefer {
            var it = cookies.iterator();
            while (it.next()) |entry| {
                self.allocator.free(entry.key_ptr.*);
                self.allocator.free(entry.value_ptr.*);
            }
            cookies.deinit();
        }

        var pairs = std.mem.splitSequence(u8, cookie_header, "; ");
        while (pairs.next()) |pair| {
            const trimmed = std.mem.trim(u8, pair, " \t");
            if (trimmed.len == 0) continue;

            const eq_pos = std.mem.indexOf(u8, trimmed, "=") orelse continue;
            const name = std.mem.trim(u8, trimmed[0..eq_pos], " \t");
            const value = std.mem.trim(u8, trimmed[eq_pos + 1 ..], " \t");

            const owned_value = try self.allocator.dupe(u8, value);
            errdefer self.allocator.free(owned_value);

            const result = try cookies.getOrPut(name);
            if (result.found_existing) {
                self.allocator.free(result.value_ptr.*); // Free old value
                result.value_ptr.* = owned_value; // Use new value
            } else {
                const owned_name = try self.allocator.dupe(u8, name);
                errdefer self.allocator.free(owned_name);
                result.key_ptr.* = owned_name;
                result.value_ptr.* = owned_value;
            }
        }

        return cookies;
    }
};
// ANCHOR_END: cookie_parser

// ANCHOR: session_data
pub const SessionData = struct {
    data: std.StringHashMap([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) SessionData {
        return .{
            .data = std.StringHashMap([]const u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SessionData) void {
        var it = self.data.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.data.deinit();
    }

    pub fn set(self: *SessionData, key: []const u8, value: []const u8) !void {
        const owned_value = try self.allocator.dupe(u8, value);
        errdefer self.allocator.free(owned_value);

        const result = try self.data.getOrPut(key);
        if (result.found_existing) {
            self.allocator.free(result.value_ptr.*);
            result.value_ptr.* = owned_value;
        } else {
            const owned_key = try self.allocator.dupe(u8, key);
            errdefer self.allocator.free(owned_key);
            result.key_ptr.* = owned_key;
            result.value_ptr.* = owned_value;
        }
    }

    pub fn get(self: *const SessionData, key: []const u8) ?[]const u8 {
        return self.data.get(key);
    }

    pub fn remove(self: *SessionData, key: []const u8) void {
        if (self.data.fetchRemove(key)) |kv| {
            self.allocator.free(kv.key);
            self.allocator.free(kv.value);
        }
    }
};
// ANCHOR_END: session_data

// ANCHOR: session
pub const Session = struct {
    id: []const u8,
    data: SessionData,
    created_at: i64,
    last_accessed: i64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, id: []const u8) !Session {
        const now = std.time.timestamp();
        return .{
            .id = try allocator.dupe(u8, id),
            .data = SessionData.init(allocator),
            .created_at = now,
            .last_accessed = now,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Session) void {
        self.allocator.free(self.id);
        self.data.deinit();
    }

    pub fn touch(self: *Session) void {
        self.last_accessed = std.time.timestamp();
    }

    pub fn isExpired(self: *const Session, timeout_seconds: i64) bool {
        const now = std.time.timestamp();
        return (now - self.last_accessed) >= timeout_seconds;
    }
};
// ANCHOR_END: session

// ANCHOR: session_store
pub const SessionStore = struct {
    sessions: std.StringHashMap(Session),
    allocator: std.mem.Allocator,
    default_timeout: i64,

    pub fn init(allocator: std.mem.Allocator) SessionStore {
        return .{
            .sessions = std.StringHashMap(Session).init(allocator),
            .allocator = allocator,
            .default_timeout = 3600, // 1 hour default
        };
    }

    pub fn deinit(self: *SessionStore) void {
        var it = self.sessions.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            var session = entry.value_ptr;
            session.deinit();
        }
        self.sessions.deinit();
    }

    pub fn create(self: *SessionStore) ![]const u8 {
        // Generate cryptographically secure session ID
        var random_bytes: [16]u8 = undefined;
        std.crypto.random.bytes(&random_bytes);

        // Encode as hex string (32 chars)
        var id_buf: [32]u8 = undefined;
        const id = std.fmt.bytesToHex(random_bytes, .lower);
        @memcpy(&id_buf, &id);

        const owned_id = try self.allocator.dupe(u8, &id_buf);
        errdefer self.allocator.free(owned_id);

        const session = try Session.init(self.allocator, owned_id);
        try self.sessions.put(owned_id, session);

        return owned_id;
    }

    pub fn get(self: *SessionStore, session_id: []const u8) ?*Session {
        if (self.sessions.getPtr(session_id)) |session| {
            if (session.isExpired(self.default_timeout)) {
                return null;
            }
            session.touch();
            return session;
        }
        return null;
    }

    pub fn destroy(self: *SessionStore, session_id: []const u8) void {
        if (self.sessions.getPtr(session_id)) |session| {
            session.deinit();
        }
        if (self.sessions.fetchRemove(session_id)) |kv| {
            self.allocator.free(kv.key);
        }
    }

    pub fn cleanup(self: *SessionStore) !void {
        var to_remove = std.ArrayList([]const u8){};
        defer to_remove.deinit(self.allocator);

        var it = self.sessions.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.isExpired(self.default_timeout)) {
                try to_remove.append(self.allocator, entry.key_ptr.*);
            }
        }

        for (to_remove.items) |session_id| {
            self.destroy(session_id);
        }
    }
};
// ANCHOR_END: session_store

// ANCHOR: test_cookie_creation
test "create basic cookie" {
    var cookie = try Cookie.init(testing.allocator, "user_id", "12345");
    defer cookie.deinit();

    try testing.expectEqualStrings("user_id", cookie.name);
    try testing.expectEqualStrings("12345", cookie.value);
    try testing.expectEqual(false, cookie.http_only);
    try testing.expectEqual(false, cookie.secure);
    try testing.expectEqual(Cookie.SameSite.lax, cookie.same_site);
}
// ANCHOR_END: test_cookie_creation

// ANCHOR: test_cookie_attributes
test "cookie with attributes" {
    var cookie = try Cookie.init(testing.allocator, "session", "abc123");
    defer cookie.deinit();

    try cookie.setDomain("example.com");
    try cookie.setPath("/");
    cookie.http_only = true;
    cookie.secure = true;
    cookie.same_site = .strict;
    cookie.max_age = 3600;

    try testing.expectEqualStrings("example.com", cookie.domain.?);
    try testing.expectEqualStrings("/", cookie.path.?);
    try testing.expect(cookie.http_only);
    try testing.expect(cookie.secure);
    try testing.expectEqual(@as(?i64, 3600), cookie.max_age);
}
// ANCHOR_END: test_cookie_attributes

// ANCHOR: test_set_cookie_header
test "generate Set-Cookie header" {
    var cookie = try Cookie.init(testing.allocator, "session", "abc123");
    defer cookie.deinit();

    try cookie.setPath("/");
    cookie.http_only = true;
    cookie.secure = true;

    const header = try cookie.toSetCookieHeader();
    defer testing.allocator.free(header);

    try testing.expect(std.mem.startsWith(u8, header, "session=abc123"));
    try testing.expect(std.mem.indexOf(u8, header, "Path=/") != null);
    try testing.expect(std.mem.indexOf(u8, header, "HttpOnly") != null);
    try testing.expect(std.mem.indexOf(u8, header, "Secure") != null);
}
// ANCHOR_END: test_set_cookie_header

// ANCHOR: test_samesite_attribute
test "cookie SameSite attribute" {
    var cookie = try Cookie.init(testing.allocator, "test", "value");
    defer cookie.deinit();

    cookie.same_site = .strict;
    const header1 = try cookie.toSetCookieHeader();
    defer testing.allocator.free(header1);
    try testing.expect(std.mem.indexOf(u8, header1, "SameSite=Strict") != null);

    cookie.same_site = .none;
    const header2 = try cookie.toSetCookieHeader();
    defer testing.allocator.free(header2);
    try testing.expect(std.mem.indexOf(u8, header2, "SameSite=None") != null);
}
// ANCHOR_END: test_samesite_attribute

// ANCHOR: test_cookie_parsing
test "parse Cookie header" {
    var parser = CookieParser.init(testing.allocator);

    const cookie_header = "session=abc123; user_id=456; theme=dark";
    var cookies = try parser.parse(cookie_header);
    defer {
        var it = cookies.iterator();
        while (it.next()) |entry| {
            testing.allocator.free(entry.key_ptr.*);
            testing.allocator.free(entry.value_ptr.*);
        }
        cookies.deinit();
    }

    try testing.expectEqual(@as(u32, 3), cookies.count());

    const session = cookies.get("session");
    try testing.expect(session != null);
    try testing.expectEqualStrings("abc123", session.?);

    const user_id = cookies.get("user_id");
    try testing.expect(user_id != null);
    try testing.expectEqualStrings("456", user_id.?);

    const theme = cookies.get("theme");
    try testing.expect(theme != null);
    try testing.expectEqualStrings("dark", theme.?);
}
// ANCHOR_END: test_cookie_parsing

// ANCHOR: test_empty_cookie_header
test "parse empty cookie header" {
    var parser = CookieParser.init(testing.allocator);

    var cookies = try parser.parse("");
    defer cookies.deinit();

    try testing.expectEqual(@as(u32, 0), cookies.count());
}
// ANCHOR_END: test_empty_cookie_header

// ANCHOR: test_session_data
test "session data storage" {
    var session_data = SessionData.init(testing.allocator);
    defer session_data.deinit();

    try session_data.set("username", "alice");
    try session_data.set("role", "admin");

    const username = session_data.get("username");
    try testing.expect(username != null);
    try testing.expectEqualStrings("alice", username.?);

    const role = session_data.get("role");
    try testing.expect(role != null);
    try testing.expectEqualStrings("admin", role.?);
}
// ANCHOR_END: test_session_data

// ANCHOR: test_session_data_update
test "update session data" {
    var session_data = SessionData.init(testing.allocator);
    defer session_data.deinit();

    try session_data.set("counter", "1");
    try session_data.set("counter", "2");

    const counter = session_data.get("counter");
    try testing.expect(counter != null);
    try testing.expectEqualStrings("2", counter.?);
}
// ANCHOR_END: test_session_data_update

// ANCHOR: test_session_data_remove
test "remove session data" {
    var session_data = SessionData.init(testing.allocator);
    defer session_data.deinit();

    try session_data.set("temp", "value");
    try testing.expect(session_data.get("temp") != null);

    session_data.remove("temp");
    try testing.expect(session_data.get("temp") == null);
}
// ANCHOR_END: test_session_data_remove

// ANCHOR: test_session_creation
test "create session" {
    var session = try Session.init(testing.allocator, "session_123");
    defer session.deinit();

    try testing.expectEqualStrings("session_123", session.id);
    try testing.expect(session.created_at > 0);
    try testing.expect(session.last_accessed > 0);
}
// ANCHOR_END: test_session_creation

// ANCHOR: test_session_touch
test "session touch updates last accessed" {
    var session = try Session.init(testing.allocator, "session_123");
    defer session.deinit();

    const initial_time = session.last_accessed;
    session.touch();

    try testing.expect(session.last_accessed >= initial_time);
}
// ANCHOR_END: test_session_touch

// ANCHOR: test_session_expiry
test "session expiry check" {
    var session = try Session.init(testing.allocator, "session_123");
    defer session.deinit();

    // Not expired with 1 hour timeout
    try testing.expect(!session.isExpired(3600));

    // Expired with 0 second timeout
    try testing.expect(session.isExpired(0));
}
// ANCHOR_END: test_session_expiry

// ANCHOR: test_session_store
test "session store operations" {
    var store = SessionStore.init(testing.allocator);
    defer store.deinit();

    const session_id = try store.create();

    const session = store.get(session_id);
    try testing.expect(session != null);
    try testing.expectEqualStrings(session_id, session.?.id);
}
// ANCHOR_END: test_session_store

// ANCHOR: test_session_store_data
test "store and retrieve session data" {
    var store = SessionStore.init(testing.allocator);
    defer store.deinit();

    const session_id = try store.create();

    if (store.get(session_id)) |session| {
        try session.data.set("user", "alice");
    }

    if (store.get(session_id)) |session| {
        const user = session.data.get("user");
        try testing.expect(user != null);
        try testing.expectEqualStrings("alice", user.?);
    }
}
// ANCHOR_END: test_session_store_data

// ANCHOR: test_session_destroy
test "destroy session" {
    var store = SessionStore.init(testing.allocator);
    defer store.deinit();

    const session_id = try store.create();
    try testing.expect(store.get(session_id) != null);

    store.destroy(session_id);
    try testing.expect(store.get(session_id) == null);
}
// ANCHOR_END: test_session_destroy

// ANCHOR: test_session_cleanup
test "cleanup expired sessions" {
    var store = SessionStore.init(testing.allocator);
    defer store.deinit();

    store.default_timeout = 0; // All sessions expire immediately

    const session_id1 = try store.create();
    const session_id2 = try store.create();

    try store.cleanup();

    try testing.expect(store.get(session_id1) == null);
    try testing.expect(store.get(session_id2) == null);
}
// ANCHOR_END: test_session_cleanup
