## Problem

You need to maintain state across HTTP requests in a web application. HTTP is stateless, so you need cookies to track client identity and server-side sessions to store user data. You need to handle cookie attributes (secure, httpOnly, sameSite), parse Cookie headers, generate Set-Cookie headers, and manage session lifecycle with proper cleanup.

## Solution

Build cookie and session management using Zig's standard library. The solution includes a Cookie structure with all standard attributes, a cookie parser for incoming requests, SessionData for storing key-value pairs, and a SessionStore for managing session lifecycle.

### Creating and Setting Cookies

```zig
{{#include ../../../code/04-specialized/11-network-web/recipe_11_7.zig:test_cookie_creation}}
```

### Cookie Attributes

The `Cookie` struct supports all standard HTTP cookie attributes:

```zig
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
    // ...
};
```

**Attribute Usage:**
- **Domain**: Which domain the cookie applies to
- **Path**: Which URL paths receive the cookie
- **Expires**: When the cookie expires (absolute time)
- **Max-Age**: How long until cookie expires (seconds from now)
- **HttpOnly**: Prevents JavaScript access (XSS protection)
- **Secure**: Only sent over HTTPS
- **SameSite**: CSRF protection (strict, lax, or none)

### SameSite Attribute

The `SameSite` enum provides CSRF protection:

```zig
pub const SameSite = enum {
    none,   // Send cookie with all requests (requires Secure)
    lax,    // Send on top-level navigation (default)
    strict, // Only send to same site
};

// Create cookie with strict same-site policy
var cookie = try Cookie.init(allocator, "auth", "token");
cookie.same_site = .strict;
cookie.secure = true; // Required for .none
```

**When to Use:**
- `strict`: Maximum protection for sensitive cookies
- `lax`: Good balance (allows GET from external sites)
- `none`: Cross-site requests needed (requires HTTPS)

### Parsing Cookie Headers

Parse the `Cookie` header from incoming requests:

```zig
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

// Access parsed cookies
const session = cookies.get("session"); // "abc123"
const user_id = cookies.get("user_id"); // "456"
const theme = cookies.get("theme"); // "dark"
```

The parser returns a `StringHashMap` with owned copies of cookie names and values.

### Session Management

Create and manage server-side sessions:

```zig
var store = SessionStore.init(testing.allocator);
defer store.deinit();

// Create new session with secure random ID
const session_id = try store.create();

// Store session data
if (store.get(session_id)) |session| {
    try session.data.set("user", "alice");
    try session.data.set("role", "admin");
    try session.data.set("login_time", "2024-01-15");
}

// Retrieve session data
if (store.get(session_id)) |session| {
    const user = session.data.get("user"); // "alice"
    const role = session.data.get("role"); // "admin"
}
```

### Session Data Operations

The `SessionData` struct stores key-value pairs:

```zig
var session_data = SessionData.init(testing.allocator);
defer session_data.deinit();

// Set values
try session_data.set("username", "alice");
try session_data.set("cart_items", "3");

// Get values
const username = session_data.get("username");
if (username) |name| {
    // Use name
}

// Update values
try session_data.set("cart_items", "4");

// Remove values
session_data.remove("cart_items");
```

### Session Lifecycle

Sessions track creation time and last access:

```zig
var session = try Session.init(testing.allocator, "session_id");
defer session.deinit();

// Session automatically records creation time
const created = session.created_at;

// Update last accessed time
session.touch();

// Check if expired (1 hour timeout)
if (session.isExpired(3600)) {
    // Session has expired
}
```

### Session Store Operations

The `SessionStore` manages multiple sessions:

```zig
var store = SessionStore.init(testing.allocator);
defer store.deinit();

// Configure timeout (default 1 hour)
store.default_timeout = 7200; // 2 hours

// Create session
const session_id = try store.create();

// Get session (returns null if not found or expired)
if (store.get(session_id)) |session| {
    // Session exists and is valid
    // Automatically updates last_accessed
}

// Destroy session
store.destroy(session_id);

// Cleanup expired sessions
try store.cleanup();
```

### Complete Cookie and Session Flow

Here's a typical web application flow:

```zig
// On login: Create session and set cookie
var store = SessionStore.init(allocator);
defer store.deinit();

// Create new session
const session_id = try store.create();

// Store user data
if (store.get(session_id)) |session| {
    try session.data.set("user_id", "123");
    try session.data.set("username", "alice");
}

// Create session cookie
var cookie = try Cookie.init(allocator, "session_id", session_id);
defer cookie.deinit();

try cookie.setPath("/");
cookie.http_only = true;
cookie.secure = true;
cookie.same_site = .strict;
cookie.max_age = 7200; // 2 hours

const set_cookie = try cookie.toSetCookieHeader();
defer allocator.free(set_cookie);
// Send: "Set-Cookie: session_id=...; Path=/; Max-Age=7200; HttpOnly; Secure; SameSite=Strict"

// On subsequent requests: Parse cookie and retrieve session
var parser = CookieParser.init(allocator);
var cookies = try parser.parse(request_cookie_header);
defer {
    var it = cookies.iterator();
    while (it.next()) |entry| {
        allocator.free(entry.key_ptr.*);
        allocator.free(entry.value_ptr.*);
    }
    cookies.deinit();
}

if (cookies.get("session_id")) |sid| {
    if (store.get(sid)) |session| {
        // Session valid - user is authenticated
        const user_id = session.data.get("user_id");
    }
}

// On logout: Destroy session and clear cookie
store.destroy(session_id);

var logout_cookie = try Cookie.init(allocator, "session_id", "");
defer logout_cookie.deinit();
logout_cookie.max_age = 0; // Expire immediately
```

## Discussion

### Cookie Security Attributes

**HttpOnly Flag:**
Prevents JavaScript access to cookies, protecting against XSS attacks:

```zig
cookie.http_only = true;
```

Without HttpOnly, malicious scripts can steal session cookies:
```javascript
// If HttpOnly is false, attacker can steal cookies
document.cookie // Returns all cookies
```

With HttpOnly set, `document.cookie` won't include the protected cookie.

**Secure Flag:**
Ensures cookies are only sent over HTTPS:

```zig
cookie.secure = true;
```

Without Secure, cookies can be intercepted on unsecured connections. Always use Secure for sensitive cookies in production.

**SameSite Protection:**
Prevents CSRF attacks by controlling when cookies are sent:

```zig
cookie.same_site = .strict; // Best protection
cookie.same_site = .lax;    // Good balance
cookie.same_site = .none;   // Requires Secure=true
```

- **Strict**: Cookie never sent on cross-site requests
- **Lax**: Cookie sent on top-level GET navigation
- **None**: Cookie sent on all requests (requires Secure)

### Session ID Generation

The implementation uses cryptographically secure random IDs:

```zig
pub fn create(self: *SessionStore) ![]const u8 {
    // Generate cryptographically secure session ID
    var random_bytes: [16]u8 = undefined;
    std.crypto.random.bytes(&random_bytes);

    // Encode as hex string (32 chars)
    var id_buf: [32]u8 = undefined;
    const id = std.fmt.bytesToHex(random_bytes, .lower);
    @memcpy(&id_buf, &id);

    const owned_id = try self.allocator.dupe(u8, &id_buf);
    // ...
}
```

This generates a 128-bit random ID (32 hex characters), making session hijacking computationally infeasible. Never use predictable values like timestamps or sequential counters.

### Memory Management

All cookie and session structures use explicit allocator passing:

```zig
pub const Cookie = struct {
    name: []const u8,
    value: []const u8,
    // ... optional attributes
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Cookie) void {
        self.allocator.free(self.name);
        self.allocator.free(self.value);
        if (self.domain) |domain| self.allocator.free(domain);
        if (self.path) |path| self.allocator.free(path);
    }
};
```

The `deinit` method ensures:
- All string fields are freed
- Optional fields are checked before freeing
- No memory leaks on proper cleanup

### Cookie Parser Memory Safety

The parser uses `getOrPut` to handle duplicate cookie names without leaking memory:

```zig
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
```

If the same cookie appears multiple times (`session=abc; session=xyz`), the parser:
1. Allocates the new value
2. Checks if the key already exists
3. If exists: frees the old value and updates with new value
4. If new: allocates the key and stores both

This prevents memory leaks from duplicate keys.

### Session Expiration

Sessions track last access time and support expiration:

```zig
pub fn isExpired(self: *const Session, timeout_seconds: i64) bool {
    const now = std.time.timestamp();
    return (now - self.last_accessed) >= timeout_seconds;
}
```

The `>=` operator ensures:
- Timeout of 0 expires immediately
- Timeout of 3600 expires after 1 hour of inactivity

When getting a session, it automatically updates last access:

```zig
pub fn get(self: *SessionStore, session_id: []const u8) ?*Session {
    if (self.sessions.getPtr(session_id)) |session| {
        if (session.isExpired(self.default_timeout)) {
            return null;
        }
        session.touch(); // Update last_accessed
        return session;
    }
    return null;
}
```

### Session Cleanup

Periodically remove expired sessions to prevent memory bloat:

```zig
var store = SessionStore.init(allocator);
defer store.deinit();

// Periodically call cleanup (e.g., every hour)
try store.cleanup();
```

The cleanup method:
1. Iterates through all sessions
2. Identifies expired sessions
3. Destroys them and frees memory

In production, run cleanup on a background timer or request count threshold.

### Cookie Path and Domain

Control where cookies are sent:

```zig
// Cookie sent to all paths under /api
try cookie.setPath("/api");

// Cookie sent to example.com and all subdomains
try cookie.setDomain("example.com");
```

**Path specificity:**
- `Path=/` - All paths
- `Path=/api` - Only /api and subdirectories
- `Path=/admin` - Only /admin and subdirectories

**Domain specificity:**
- No domain set - Current host only
- `Domain=example.com` - example.com and subdomains
- Cannot set domain to different top-level domain

### Session Store Destruction

Properly clean up sessions and their data:

```zig
pub fn deinit(self: *SessionStore) void {
    var it = self.sessions.iterator();
    while (it.next()) |entry| {
        self.allocator.free(entry.key_ptr.*);
        var session = entry.value_ptr;
        session.deinit(); // Cleanup session data
    }
    self.sessions.deinit();
}
```

Each session's `deinit` recursively frees all session data:

```zig
pub fn deinit(self: *Session) void {
    self.allocator.free(self.id);
    self.data.deinit(); // Frees all key-value pairs
}
```

### Set-Cookie Header Generation

The `toSetCookieHeader` method builds proper HTTP headers:

```zig
// Basic cookie
cookie = Cookie.init(allocator, "theme", "dark");
// Result: "theme=dark"

// Cookie with attributes
cookie.http_only = true;
cookie.secure = true;
cookie.max_age = 86400; // 1 day
// Result: "theme=dark; Max-Age=86400; HttpOnly; Secure"

// Cookie with domain and path
try cookie.setDomain("example.com");
try cookie.setPath("/");
// Result: "theme=dark; Domain=example.com; Path=/; Max-Age=86400; HttpOnly; Secure"
```

The order of attributes doesn't matter - browsers parse all of them.

### Security Considerations

**Production Recommendations:**

1. **Always use Secure and HttpOnly for session cookies:**
   ```zig
   cookie.secure = true;
   cookie.http_only = true;
   ```

2. **Use SameSite=Strict for sensitive cookies:**
   ```zig
   cookie.same_site = .strict;
   ```

3. **Set reasonable expiration times:**
   ```zig
   cookie.max_age = 3600; // 1 hour for sensitive sessions
   cookie.max_age = 2592000; // 30 days for "remember me"
   ```

4. **Regenerate session ID on privilege escalation:**
   ```zig
   // On login, create new session
   const new_session_id = try store.create();
   store.destroy(old_session_id);
   ```

5. **Validate session data:**
   ```zig
   if (store.get(session_id)) |session| {
       const user_id = session.data.get("user_id") orelse return error.InvalidSession;
       // Verify user_id is valid
   }
   ```

6. **Implement CSRF tokens for state-changing requests:**
   ```zig
   // Generate CSRF token per session
   if (store.get(session_id)) |session| {
       var token_bytes: [16]u8 = undefined;
       std.crypto.random.bytes(&token_bytes);
       const token = std.fmt.bytesToHex(token_bytes, .lower);
       try session.data.set("csrf_token", &token);
   }
   ```

### Limitations of This Implementation

This recipe provides educational patterns but lacks some production features:

**Missing Features:**
- Cookie value URL encoding (special characters in values)
- Expires attribute HTTP date formatting (currently uses timestamp)
- Cookie signing/encryption
- Session persistence (stored in memory only)
- Distributed session storage (Redis, database)
- Session size limits
- Rate limiting for session creation

**Security Improvements Needed:**
```zig
// TODO: Add cookie value encoding
pub fn encodeValue(allocator: std.mem.Allocator, value: []const u8) ![]const u8 {
    // URL encode special characters
    // Escape semicolons, commas, spaces
}

// TODO: Validate cookie names
pub fn validateName(name: []const u8) !void {
    if (name.len == 0) return error.EmptyCookieName;
    if (std.mem.indexOfAny(u8, name, ";=, \t\r\n") != null) {
        return error.InvalidCookieName;
    }
}

// TODO: Add persistent session storage
pub const PersistentSessionStore = struct {
    backend: SessionBackend, // Redis, PostgreSQL, etc.
    // ...
};
```

For production use:
- Add cookie value encoding/decoding
- Implement session persistence
- Add session size limits (prevent DoS)
- Sign cookies to prevent tampering
- Encrypt sensitive cookie values
- Implement sliding expiration (extend on activity)
- Add session revocation mechanism
- Log security events (failed lookups, expirations)

### Advanced: Thread-Safe Session Store

**Critical Production Requirement:** The basic `SessionStore` implementation above is **NOT thread-safe**. In multi-threaded web servers where requests are handled concurrently, multiple threads accessing the same `SessionStore` will cause data races, memory corruption, and crashes.

#### Why This Matters

Consider this scenario with 3 concurrent HTTP requests:

```zig
// Thread 1: Reading session
const session = store.get(session_id);

// Thread 2: Simultaneously creating session (RACE CONDITION!)
const new_id = store.create();

// Thread 3: Simultaneously cleaning up (MEMORY CORRUPTION!)
store.cleanup();
```

All three threads access `store.sessions` (a `StringHashMap`) concurrently. HashMaps in Zig are **NOT thread-safe**. Concurrent access will:
- Corrupt the internal hash table structure
- Cause use-after-free bugs when one thread deletes while another reads
- Trigger assertion failures in debug builds
- Produce undefined behavior in release builds

#### Solution: Add Mutex Synchronization

For production multi-threaded servers, protect the `SessionStore` with `std.Thread.Mutex`:

```zig
{{#include ../../../code/04-specialized/11-network-web/recipe_11_7_threadsafe.zig:threadsafe_session_store}}
```

#### Key Changes for Thread Safety

1. **Add mutex field:**
   ```zig
   mutex: std.Thread.Mutex,
   ```

2. **Lock before ALL HashMap operations:**
   ```zig
   pub fn create(self: *ThreadSafeSessionStore) ![]const u8 {
       self.mutex.lock();
       defer self.mutex.unlock();
       // ... HashMap operations are now atomic
   }
   ```

3. **Use `defer` for automatic unlock:**
   - Ensures unlock even on error returns
   - Prevents deadlocks from forgotten unlocks
   - Idiomatic Zig cleanup pattern

4. **Lock in every method that touches `sessions`:**
   - `create()` - Writes to HashMap
   - `get()` - Reads from HashMap (and modifies Session)
   - `destroy()` - Removes from HashMap
   - `cleanup()` - Iterates and modifies HashMap

#### When You Need Thread Safety

Use `ThreadSafeSessionStore` when:
- Building multi-threaded HTTP servers
- Using thread pools for request handling
- Running background cleanup threads
- Processing >1 concurrent request

Use basic `SessionStore` only for:
- Single-threaded educational examples
- Testing and prototyping
- Single-request-at-a-time architectures

#### Performance Considerations

**Mutex Overhead:**
- Each lock/unlock adds approximately 100-200 nanoseconds
- For typical web apps (<10k requests/second per core), this is negligible
- The safety benefits far outweigh the minimal performance cost

**High-Performance Alternatives:**

For extremely high-traffic servers (>10k req/s), consider:

1. **Sharded Session Stores** (multiple stores with separate locks):
   ```zig
   pub const ShardedSessionStore = struct {
       shards: [16]ThreadSafeSessionStore,

       fn getShard(self: *ShardedSessionStore, session_id: []const u8) *ThreadSafeSessionStore {
           const hash = std.hash.Wyhash.hash(0, session_id);
           return &self.shards[hash % self.shards.len];
       }
   };
   ```

2. **Lock-free data structures** (advanced, see Recipe 12.3: Atomic operations)

3. **External session storage** (Redis, PostgreSQL with connection pooling)

#### Testing Thread Safety

The thread-safe implementation includes comprehensive concurrency tests:

```zig
{{#include ../../../code/04-specialized/11-network-web/recipe_11_7_threadsafe.zig:test_concurrent_create}}
```

Run these tests to verify:
- No data races under concurrent load
- All operations complete without corruption
- No memory leaks from race conditions

#### Deadlock Prevention

The implementation avoids deadlocks by:
1. **Never holding multiple locks** - Only one mutex in the entire structure
2. **Using `defer unlock()`** - Ensures unlock on all code paths
3. **No nested locking** - Functions don't call other locking functions while holding lock

**Important:** If you extend this with multiple locks, always acquire locks in consistent order to prevent deadlocks.

### Best Practices

**Cookie Best Practices:**
- Use shortest viable expiration time
- Set specific Path instead of root (/) when possible
- Always set Secure flag in production
- Use HttpOnly unless JavaScript needs access
- Use SameSite=Strict for authentication cookies

**Session Best Practices:**
- Generate cryptographically random session IDs
- Regenerate session ID on login
- Implement absolute timeout (max session lifetime)
- Implement idle timeout (inactivity expiration)
- Clear sessions on logout
- Run periodic cleanup to free memory
- Store minimal data in sessions
- Never store sensitive data unencrypted

**Error Handling:**
```zig
// Validate session before use
if (store.get(session_id)) |session| {
    // Check user is still authorized
    const user_id = session.data.get("user_id") orelse {
        store.destroy(session_id);
        return error.InvalidSession;
    };

    // Verify user exists and is active
    const user = try database.getUser(user_id);
    if (!user.is_active) {
        store.destroy(session_id);
        return error.UserDeactivated;
    }
} else {
    // Session not found or expired
    return error.Unauthenticated;
}
```

## See Also

- Recipe 11.4: Building a simple HTTP server - Integrate cookies and sessions
- Recipe 11.6: Working with REST APIs - Use cookies for API authentication
- Recipe 11.12: OAuth2 authentication - Alternative to session-based auth
- Recipe 12.1: Basic threading and thread management - Understanding concurrent request handling
- Recipe 12.2: Mutexes and basic locking - Deep dive into thread synchronization
- Recipe 12.3: Atomic operations - Lock-free alternatives for high performance
- Recipe 13.5: Cryptographic operations - Secure random number generation

Full compilable example: `code/04-specialized/11-network-web/recipe_11_7.zig`
