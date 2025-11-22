## Problem

You need to implement OAuth2 authentication in your application, handling authorization code flow, client credentials, token refresh, and PKCE for enhanced security.

## Solution

Zig's cryptographic libraries and string handling make it well-suited for implementing OAuth2 flows. This recipe demonstrates the authorization code flow with PKCE, token management, and multiple grant types.

### Grant Types

OAuth2 defines several grant types for different use cases:

```zig
{{#include ../../../code/04-specialized/11-network-web/recipe_11_12.zig:oauth_grant_type}}
```

### OAuth2 Token

Tokens carry access credentials and metadata:

```zig
pub const OAuth2Token = struct {
    access_token: []const u8,
    token_type: []const u8,
    expires_in: ?i64,
    refresh_token: ?[]const u8,
    scope: ?[]const u8,
    issued_at: i64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, access_token: []const u8, token_type: []const u8) !OAuth2Token {
        const owned_access_token = try allocator.dupe(u8, access_token);
        errdefer allocator.free(owned_access_token);

        const owned_token_type = try allocator.dupe(u8, token_type);
        errdefer allocator.free(owned_token_type);

        return .{
            .access_token = owned_access_token,
            .token_type = owned_token_type,
            .expires_in = null,
            .refresh_token = null,
            .scope = null,
            .issued_at = std.time.timestamp(),
            .allocator = allocator,
        };
    }

    pub fn isExpired(self: *const OAuth2Token) bool {
        if (self.expires_in) |expires| {
            const now = std.time.timestamp();
            const elapsed = now - self.issued_at;
            return elapsed >= expires;
        }
        return false;
    }

    pub fn getAuthorizationHeader(self: *const OAuth2Token) ![]const u8 {
        var buffer = std.ArrayList(u8){};
        defer buffer.deinit(self.allocator);

        try buffer.appendSlice(self.allocator, self.token_type);
        try buffer.appendSlice(self.allocator, " ");
        try buffer.appendSlice(self.allocator, self.access_token);

        return buffer.toOwnedSlice(self.allocator);
    }
};
```

### OAuth2 Configuration

Configuration stores client credentials and endpoint URLs:

```zig
pub const OAuth2Config = struct {
    client_id: []const u8,
    client_secret: ?[]const u8,
    authorization_endpoint: []const u8,
    token_endpoint: []const u8,
    redirect_uri: ?[]const u8,
    scope: ?[]const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *OAuth2Config) void {
        self.allocator.free(self.client_id);
        self.allocator.free(self.authorization_endpoint);
        self.allocator.free(self.token_endpoint);

        if (self.client_secret) |cs| {
            // Zero sensitive data before freeing
            @memset(@constCast(cs), 0);
            self.allocator.free(cs);
        }

        // Free other optional fields...
    }

    pub fn setClientSecret(self: *OAuth2Config, client_secret: []const u8) !void {
        if (self.client_secret) |old_cs| {
            // Zero sensitive data before freeing
            @memset(@constCast(old_cs), 0);
            self.allocator.free(old_cs);
        }
        self.client_secret = try self.allocator.dupe(u8, client_secret);
    }
};
```

### PKCE (Proof Key for Code Exchange)

PKCE enhances security for authorization code flow by preventing code interception attacks:

```zig
pub const PKCE = struct {
    code_verifier: []const u8,
    code_challenge: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !PKCE {
        // Generate 128-character code verifier (64 random bytes, hex-encoded)
        // RFC 7636 requires 43-128 characters
        var verifier_buf: [64]u8 = undefined;
        std.crypto.random.bytes(&verifier_buf);

        var encoded_buf: [128]u8 = undefined;
        const verifier = std.fmt.bytesToHex(verifier_buf, .lower);
        @memcpy(encoded_buf[0..verifier.len], &verifier);

        const owned_verifier = try allocator.dupe(u8, encoded_buf[0..verifier.len]);
        errdefer allocator.free(owned_verifier);

        // Generate code challenge (SHA256 hash of verifier, base64url encoded per RFC 7636)
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(owned_verifier, &hash, .{});

        // Base64url encode the hash (no padding) per RFC 7636
        const encoder = std.base64.url_safe_no_pad.Encoder;
        var challenge_buf: [64]u8 = undefined;
        const challenge = encoder.encode(&challenge_buf, &hash);
        const owned_challenge = try allocator.dupe(u8, challenge);

        return .{
            .code_verifier = owned_verifier,
            .code_challenge = owned_challenge,
            .allocator = allocator,
        };
    }
};
```

### OAuth2 Client

The client manages the OAuth2 flow:

```zig
pub const OAuth2Client = struct {
    config: OAuth2Config,
    allocator: std.mem.Allocator,

    pub fn buildAuthorizationUrl(
        self: *const OAuth2Client,
        state: ?[]const u8,
        pkce: ?*const PKCE,
    ) ![]const u8 {
        var buffer = std.ArrayList(u8){};
        defer buffer.deinit(self.allocator);

        try buffer.appendSlice(self.allocator, self.config.authorization_endpoint);
        try buffer.appendSlice(self.allocator, "?response_type=code");
        try buffer.appendSlice(self.allocator, "&client_id=");
        try buffer.appendSlice(self.allocator, self.config.client_id);

        if (self.config.redirect_uri) |ru| {
            try buffer.appendSlice(self.allocator, "&redirect_uri=");
            try self.appendUrlEncoded(&buffer, ru);
        }

        if (self.config.scope) |scope| {
            try buffer.appendSlice(self.allocator, "&scope=");
            try self.appendUrlEncoded(&buffer, scope);
        }

        if (state) |s| {
            try buffer.appendSlice(self.allocator, "&state=");
            try self.appendUrlEncoded(&buffer, s);
        }

        if (pkce) |p| {
            try buffer.appendSlice(self.allocator, "&code_challenge=");
            try buffer.appendSlice(self.allocator, p.code_challenge);
            try buffer.appendSlice(self.allocator, "&code_challenge_method=S256");
        }

        return buffer.toOwnedSlice(self.allocator);
    }

    fn appendUrlEncoded(
        self: *const OAuth2Client,
        buffer: *std.ArrayList(u8),
        str: []const u8,
    ) !void {
        for (str) |c| {
            switch (c) {
                'A'...'Z', 'a'...'z', '0'...'9', '-', '_', '.', '~' => {
                    try buffer.append(self.allocator, c);
                },
                ' ' => {
                    try buffer.append(self.allocator, '+');
                },
                else => {
                    try buffer.appendSlice(self.allocator, "%");
                    var hex_buf: [2]u8 = undefined;
                    _ = try std.fmt.bufPrint(&hex_buf, "{X:0>2}", .{c});
                    try buffer.appendSlice(self.allocator, &hex_buf);
                },
            }
        }
    }
};
```

## Discussion

This recipe implements OAuth2 authentication following the OAuth 2.0 specification (RFC 6749) and PKCE extension (RFC 7636).

### OAuth2 Flow Overview

**Authorization Code Flow (Most Common):**
1. Redirect user to authorization URL with state and PKCE challenge
2. User authenticates and grants permission
3. Provider redirects back with authorization code
4. Exchange code for access token (include PKCE verifier)
5. Use access token for API requests
6. Refresh token when expired

**Example:**
```zig
var config = try OAuth2Config.init(
    allocator,
    "my_client_id",
    "https://oauth.provider.com/authorize",
    "https://oauth.provider.com/token",
);
defer config.deinit();

try config.setRedirectUri("https://myapp.com/callback");
try config.setScope("read write");

var pkce = try PKCE.init(allocator);
defer pkce.deinit();

var client = OAuth2Client.init(allocator, config);

// Step 1: Build authorization URL
const auth_url = try client.buildAuthorizationUrl("random_state_123", &pkce);
defer allocator.free(auth_url);

// Redirect user to auth_url...

// Step 2: After callback, exchange code for token
var token = try client.exchangeAuthorizationCode("received_code", &pkce);
defer token.deinit();

// Step 3: Use token for API requests
const auth_header = try token.getAuthorizationHeader();
defer allocator.free(auth_header);
// Authorization: Bearer access_token_12345
```

### PKCE Security

PKCE (RFC 7636) protects against authorization code interception:

**How it works:**
1. **Code Verifier**: Random 43-128 character string
2. **Code Challenge**: SHA256 hash of verifier, base64url encoded
3. **Initial Request**: Send code challenge to authorization endpoint
4. **Token Exchange**: Send code verifier with authorization code
5. **Server Verification**: Server hashes verifier and compares to challenge

**Why base64url?:**
RFC 7636 mandates base64url encoding (not hex) for the code challenge:
```zig
// Correct (per RFC 7636):
const encoder = std.base64.url_safe_no_pad.Encoder;
const challenge = encoder.encode(&challenge_buf, &hash);

// Incorrect (would be rejected by OAuth2 providers):
const challenge = std.fmt.bytesToHex(hash, .lower);
```

**Security benefit:**
Even if an attacker intercepts the authorization code, they cannot exchange it for a token without the original code verifier.

### RFC 7636 Compliance

This implementation fully complies with RFC 7636 (PKCE for OAuth 2.0) to ensure interoperability with OAuth2 providers and maximum security.

**Code Verifier Requirements (Section 4.1):**
- **Length:** 43-128 characters (we generate 128)
- **Character Set:** Unreserved characters `[A-Z]/[a-z]/[0-9]/"-"/"."/"_"/"~"`
- **Entropy:** Minimum 256 bits recommended (we provide 512 bits)

Our implementation uses `std.crypto.random.bytes()` for cryptographically secure randomness, then hex-encodes the result. Hex encoding produces only `[a-f][0-9]` characters, which are valid unreserved characters and satisfy RFC 7636 requirements.

**S256 Challenge Method (Section 4.2):**
```
code_challenge = BASE64URL(SHA256(ASCII(code_verifier)))
```

The S256 method is recommended over the "plain" method because:
- SHA256 is a one-way function (challenge cannot be reversed to get verifier)
- Protects against eavesdropping on the authorization request
- Ensures only the client with the original verifier can complete the flow

**Base64url Encoding (Section 4.2):**

RFC 7636 mandates base64url encoding, which differs from standard base64:
- **URL-safe alphabet:** Uses `-` and `_` instead of `+` and `/`
- **No padding:** Omits trailing `=` characters
- **Why it matters:** Can be safely included in URL query parameters without additional escaping

Our implementation uses `std.base64.url_safe_no_pad.Encoder`, which correctly implements RFC 4648 Section 5 (base64url) as required by RFC 7636.

**S256 Parameter (Section 4.3):**

The `code_challenge_method=S256` parameter in the authorization URL tells the server:
1. How the challenge was computed (SHA256 + base64url)
2. How to verify the verifier during token exchange
3. That we're using the recommended method (not "plain")

When the authorization code is exchanged for tokens, the server computes `BASE64URL(SHA256(code_verifier))` and compares it to the stored `code_challenge`. Only exact matches are accepted.

### URL Encoding

Proper URL encoding prevents injection attacks:

```zig
fn appendUrlEncoded(self: *const OAuth2Client, buffer: *std.ArrayList(u8), str: []const u8) !void {
    for (str) |c| {
        switch (c) {
            'A'...'Z', 'a'...'z', '0'...'9', '-', '_', '.', '~' => {
                try buffer.append(self.allocator, c);
            },
            ' ' => {
                try buffer.append(self.allocator, '+');
            },
            else => {
                try buffer.appendSlice(self.allocator, "%");
                var hex_buf: [2]u8 = undefined;
                _ = try std.fmt.bufPrint(&hex_buf, "{X:0>2}", .{c});
                try buffer.appendSlice(self.allocator, &hex_buf);
            },
        }
    }
}
```

**Critical for state parameter:**
The `state` parameter must be URL-encoded to prevent CSRF bypass:
```zig
// Secure - prevents injection:
try self.appendUrlEncoded(&buffer, state);

// Insecure - vulnerable to injection:
try buffer.appendSlice(self.allocator, state);  // DON'T DO THIS
```

### Sensitive Data Handling

Client secrets and tokens are zeroed before freeing:

```zig
if (self.client_secret) |cs| {
    // Zero sensitive data before freeing
    @memset(@constCast(cs), 0);
    self.allocator.free(cs);
}
```

**Why this matters:**
- Prevents secrets from remaining in memory
- Reduces risk from memory dumps
- Protects against swap file disclosure
- Mitigates use-after-free exploits

**When to zero:**
- Client secrets (always)
- Access tokens (consider, especially for sensitive APIs)
- Refresh tokens (consider, especially for long-lived tokens)
- Authorization codes (less critical, short-lived)

### Token Expiration

Tokens track their expiration and can be validated:

```zig
pub fn isExpired(self: *const OAuth2Token) bool {
    if (self.expires_in) |expires| {
        const now = std.time.timestamp();
        const elapsed = now - self.issued_at;
        return elapsed >= expires;
    }
    return false;
}
```

**Best practice:** Check expiration before each API request and refresh proactively when the token is about to expire (e.g., within 5 minutes of expiration).

### Grant Type Comparison

**Authorization Code (with PKCE):**
- **Use for:** Web apps, mobile apps, desktop apps
- **Security:** High (with PKCE)
- **User interaction:** Required
- **Refresh tokens:** Yes

**Client Credentials:**
- **Use for:** Service-to-service authentication
- **Security:** Medium (requires secret storage)
- **User interaction:** None
- **Refresh tokens:** No (get new token instead)

**Refresh Token:**
- **Use for:** Obtaining new access token without user interaction
- **Security:** High (long-lived, must be protected)
- **User interaction:** None
- **Refresh tokens:** Returns new refresh token

**Password (Deprecated):**
- **Use for:** Legacy systems only
- **Security:** Low (exposes user credentials)
- **User interaction:** Required
- **Refresh tokens:** Yes
- **Note:** RFC 6749 discourages use; prefer authorization code

### Real Implementation

This recipe simulates token exchange. A production implementation would:

**Make HTTP POST request:**
```zig
pub fn exchangeAuthorizationCode(
    self: *const OAuth2Client,
    code: []const u8,
    pkce: ?*const PKCE,
) !OAuth2Token {
    var client = std.http.Client{ .allocator = self.allocator };
    defer client.deinit();

    // Build request body
    var body = std.ArrayList(u8){};
    defer body.deinit(self.allocator);

    try body.appendSlice(self.allocator, "grant_type=authorization_code");
    try body.appendSlice(self.allocator, "&code=");
    try body.appendSlice(self.allocator, code);
    try body.appendSlice(self.allocator, "&client_id=");
    try body.appendSlice(self.allocator, self.config.client_id);

    if (self.config.redirect_uri) |uri| {
        try body.appendSlice(self.allocator, "&redirect_uri=");
        try self.appendUrlEncoded(&body, uri);
    }

    if (pkce) |p| {
        try body.appendSlice(self.allocator, "&code_verifier=");
        try body.appendSlice(self.allocator, p.code_verifier);
    }

    // Make POST request to token endpoint
    var req = try client.request(.POST, try std.Uri.parse(self.config.token_endpoint), .{
        .extra_headers = &.{
            .{ .name = "Content-Type", .value = "application/x-www-form-urlencoded" },
        },
    });
    defer req.deinit();

    req.transfer_encoding = .{ .content_length = body.items.len };
    try req.send();
    try req.writeAll(body.items);
    try req.finish();

    // Parse JSON response into OAuth2Token
    // ...
}
```

**Parse JSON response:**
```zig
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600,
  "refresh_token": "tGzv3JOkF0XG5Qx2TlKWIA",
  "scope": "read write"
}
```

Use `std.json.parseFromSlice()` to parse into a token struct.

### Security Best Practices

**1. Always use PKCE for public clients:**
```zig
var pkce = try PKCE.init(allocator);
defer pkce.deinit();

const url = try client.buildAuthorizationUrl(state, &pkce);
```

**2. Generate cryptographically random state:**
```zig
var state_buf: [32]u8 = undefined;
std.crypto.random.bytes(&state_buf);
const state = std.fmt.bytesToHex(state_buf, .lower);
```

**3. Validate state on callback:**
```zig
if (!std.mem.eql(u8, received_state, expected_state)) {
    return error.InvalidState;  // CSRF attack detected
}
```

**4. Use HTTPS for all OAuth2 endpoints:**
Never use HTTP for OAuth2 - credentials would be exposed in transit.

**5. Store refresh tokens securely:**
- Encrypt at rest
- Use platform-specific secure storage (Keychain, Credential Manager)
- Never log or transmit over insecure channels

**6. Validate redirect URI:**
Ensure the redirect URI matches exactly (OAuth2 providers enforce this).

### Error Handling

OAuth2 errors are returned in the response:

```json
{
  "error": "invalid_request",
  "error_description": "Missing required parameter: code",
  "error_uri": "https://docs.provider.com/oauth/errors#invalid_request"
}
```

Common errors:
- `invalid_request`: Malformed request
- `unauthorized_client`: Client not authorized
- `access_denied`: User denied authorization
- `invalid_grant`: Invalid or expired authorization code
- `invalid_client`: Invalid client credentials

## See Also

- Recipe 11.1: Making HTTP requests
- Recipe 11.7: Handling cookies and sessions
- Recipe 11.8: SSL/TLS connections

Full compilable example: `code/04-specialized/11-network-web/recipe_11_12.zig`
