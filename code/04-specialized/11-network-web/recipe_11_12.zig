const std = @import("std");
const testing = std.testing;

// ANCHOR: oauth_grant_type
pub const GrantType = enum {
    authorization_code,
    client_credentials,
    refresh_token,
    password,

    pub fn toString(self: GrantType) []const u8 {
        return switch (self) {
            .authorization_code => "authorization_code",
            .client_credentials => "client_credentials",
            .refresh_token => "refresh_token",
            .password => "password",
        };
    }
};
// ANCHOR_END: oauth_grant_type

// ANCHOR: oauth_token
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

    pub fn deinit(self: *OAuth2Token) void {
        self.allocator.free(self.access_token);
        self.allocator.free(self.token_type);

        if (self.refresh_token) |rt| {
            self.allocator.free(rt);
        }

        if (self.scope) |s| {
            self.allocator.free(s);
        }
    }

    pub fn setRefreshToken(self: *OAuth2Token, refresh_token: []const u8) !void {
        if (self.refresh_token) |old_rt| {
            self.allocator.free(old_rt);
        }
        self.refresh_token = try self.allocator.dupe(u8, refresh_token);
    }

    pub fn setScope(self: *OAuth2Token, scope: []const u8) !void {
        if (self.scope) |old_scope| {
            self.allocator.free(old_scope);
        }
        self.scope = try self.allocator.dupe(u8, scope);
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
// ANCHOR_END: oauth_token

// ANCHOR: oauth_config
pub const OAuth2Config = struct {
    client_id: []const u8,
    client_secret: ?[]const u8,
    authorization_endpoint: []const u8,
    token_endpoint: []const u8,
    redirect_uri: ?[]const u8,
    scope: ?[]const u8,
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        client_id: []const u8,
        authorization_endpoint: []const u8,
        token_endpoint: []const u8,
    ) !OAuth2Config {
        const owned_client_id = try allocator.dupe(u8, client_id);
        errdefer allocator.free(owned_client_id);

        const owned_auth_endpoint = try allocator.dupe(u8, authorization_endpoint);
        errdefer allocator.free(owned_auth_endpoint);

        const owned_token_endpoint = try allocator.dupe(u8, token_endpoint);
        errdefer allocator.free(owned_token_endpoint);

        return .{
            .client_id = owned_client_id,
            .client_secret = null,
            .authorization_endpoint = owned_auth_endpoint,
            .token_endpoint = owned_token_endpoint,
            .redirect_uri = null,
            .scope = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *OAuth2Config) void {
        self.allocator.free(self.client_id);
        self.allocator.free(self.authorization_endpoint);
        self.allocator.free(self.token_endpoint);

        if (self.client_secret) |cs| {
            // Zero sensitive data before freeing
            @memset(@constCast(cs), 0);
            self.allocator.free(cs);
        }

        if (self.redirect_uri) |ru| {
            self.allocator.free(ru);
        }

        if (self.scope) |s| {
            self.allocator.free(s);
        }
    }

    pub fn setClientSecret(self: *OAuth2Config, client_secret: []const u8) !void {
        if (self.client_secret) |old_cs| {
            // Zero sensitive data before freeing
            @memset(@constCast(old_cs), 0);
            self.allocator.free(old_cs);
        }
        self.client_secret = try self.allocator.dupe(u8, client_secret);
    }

    pub fn setRedirectUri(self: *OAuth2Config, redirect_uri: []const u8) !void {
        if (self.redirect_uri) |old_ru| {
            self.allocator.free(old_ru);
        }
        self.redirect_uri = try self.allocator.dupe(u8, redirect_uri);
    }

    pub fn setScope(self: *OAuth2Config, scope: []const u8) !void {
        if (self.scope) |old_scope| {
            self.allocator.free(old_scope);
        }
        self.scope = try self.allocator.dupe(u8, scope);
    }
};
// ANCHOR_END: oauth_config

// ANCHOR: pkce
// PKCE (Proof Key for Code Exchange) implements RFC 7636 to prevent authorization code
// interception attacks in OAuth 2.0 flows. This is critical for public clients (like mobile
// apps and SPAs) that cannot securely store client secrets.
//
// RFC 7636 Compliance:
// - code_verifier: Cryptographically random string (43-128 characters)
// - code_challenge: Transformed version of verifier sent to authorization server
// - S256 method: Uses SHA256 hash + base64url encoding (recommended over "plain" method)
//
// Security Flow:
// 1. Client generates random code_verifier and derives code_challenge
// 2. Client sends code_challenge to authorization endpoint
// 3. Authorization server stores code_challenge
// 4. Client sends code_verifier to token endpoint
// 5. Server verifies: code_challenge == BASE64URL(SHA256(code_verifier))
//
// This prevents attackers who intercept the authorization code from exchanging it for tokens,
// since they don't have the original code_verifier.
pub const PKCE = struct {
    code_verifier: []const u8,
    code_challenge: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !PKCE {
        // Generate cryptographically random code_verifier per RFC 7636 Section 4.1
        //
        // RFC 7636 Requirements:
        // - Length: 43-128 characters (we generate 128 characters)
        // - Character set: Unreserved characters [A-Z]/[a-z]/[0-9]/"-"/"."/"_"/"~"
        // - Entropy: Minimum 256 bits recommended (we use 512 bits = 64 random bytes)
        //
        // Implementation:
        // - std.crypto.random provides cryptographically secure random bytes
        // - Hex encoding (lowercase) produces characters [a-f][0-9], which are valid
        //   unreserved characters per RFC 3986 and satisfy RFC 7636 requirements
        // - 64 random bytes -> 128 hex characters = 512 bits of entropy (exceeds minimum)
        var verifier_buf: [64]u8 = undefined;
        std.crypto.random.bytes(&verifier_buf);

        var encoded_buf: [128]u8 = undefined;
        const verifier = std.fmt.bytesToHex(verifier_buf, .lower);
        @memcpy(encoded_buf[0..verifier.len], &verifier);

        const owned_verifier = try allocator.dupe(u8, encoded_buf[0..verifier.len]);
        errdefer allocator.free(owned_verifier);

        // Generate code_challenge using S256 method per RFC 7636 Section 4.2
        //
        // RFC 7636 S256 Method:
        // - Formula: code_challenge = BASE64URL(SHA256(ASCII(code_verifier)))
        // - S256 is the RECOMMENDED method (more secure than "plain" method)
        // - The "plain" method sends code_verifier directly, vulnerable to interception
        //
        // Security: SHA256 is a one-way function, so code_challenge cannot be reversed
        // to obtain code_verifier. Only the client with the original verifier can prove
        // possession during the token exchange.
        var hash: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(owned_verifier, &hash, .{});

        // Apply BASE64URL encoding per RFC 7636 Section 4.2
        //
        // RFC 7636 Base64url Requirements:
        // - MUST use URL-safe alphabet: [A-Z]/[a-z]/[0-9]/-/_ (no +/)
        // - MUST NOT include padding ('=' characters)
        // - Standard base64 uses +/ which require URL encoding, causing issues
        //
        // Implementation Compliance:
        // - std.base64.url_safe_no_pad.Encoder uses the correct URL-safe alphabet
        // - Replaces + with - and / with _ (per RFC 4648 Section 5)
        // - no_pad ensures no trailing '=' characters are added
        // - This encoding can be safely included in URL query parameters without
        //   additional escaping, which is critical for OAuth authorization URLs
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

    pub fn deinit(self: *PKCE) void {
        self.allocator.free(self.code_verifier);
        self.allocator.free(self.code_challenge);
    }
};
// ANCHOR_END: pkce

// ANCHOR: oauth_client
pub const OAuth2Client = struct {
    config: OAuth2Config,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: OAuth2Config) OAuth2Client {
        return .{
            .config = config,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *OAuth2Client) void {
        self.config.deinit();
    }

    pub fn buildAuthorizationUrl(self: *const OAuth2Client, state: ?[]const u8, pkce: ?*const PKCE) ![]const u8 {
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
            // S256 indicates SHA256 transform method per RFC 7636 Section 4.3
            // This tells the authorization server how to verify the challenge:
            // it must compute BASE64URL(SHA256(code_verifier)) and compare with code_challenge
            try buffer.appendSlice(self.allocator, "&code_challenge_method=S256");
        }

        return buffer.toOwnedSlice(self.allocator);
    }

    pub fn exchangeAuthorizationCode(
        self: *const OAuth2Client,
        code: []const u8,
        pkce: ?*const PKCE,
    ) !OAuth2Token {
        _ = code;
        _ = pkce;
        // Simulate token exchange
        var token = try OAuth2Token.init(self.allocator, "access_token_12345", "Bearer");
        token.expires_in = 3600;
        try token.setRefreshToken("refresh_token_67890");
        return token;
    }

    pub fn refreshToken(self: *const OAuth2Client, refresh_token: []const u8) !OAuth2Token {
        _ = refresh_token;
        // Simulate token refresh
        var token = try OAuth2Token.init(self.allocator, "new_access_token_99999", "Bearer");
        token.expires_in = 3600;
        return token;
    }

    pub fn getClientCredentialsToken(self: *const OAuth2Client) !OAuth2Token {
        // Simulate client credentials flow
        var token = try OAuth2Token.init(self.allocator, "client_cred_token_11111", "Bearer");
        token.expires_in = 7200;
        return token;
    }

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
};
// ANCHOR_END: oauth_client

// ANCHOR: test_grant_type
test "grant type to string" {
    try testing.expectEqualStrings("authorization_code", GrantType.authorization_code.toString());
    try testing.expectEqualStrings("client_credentials", GrantType.client_credentials.toString());
    try testing.expectEqualStrings("refresh_token", GrantType.refresh_token.toString());
    try testing.expectEqualStrings("password", GrantType.password.toString());
}
// ANCHOR_END: test_grant_type

// ANCHOR: test_token_basic
test "create OAuth2 token" {
    var token = try OAuth2Token.init(testing.allocator, "test_access_token", "Bearer");
    defer token.deinit();

    try testing.expectEqualStrings("test_access_token", token.access_token);
    try testing.expectEqualStrings("Bearer", token.token_type);
    try testing.expect(token.expires_in == null);
    try testing.expect(token.refresh_token == null);
}
// ANCHOR_END: test_token_basic

// ANCHOR: test_token_refresh_token
test "token with refresh token" {
    var token = try OAuth2Token.init(testing.allocator, "access", "Bearer");
    defer token.deinit();

    try token.setRefreshToken("refresh_12345");

    try testing.expect(token.refresh_token != null);
    try testing.expectEqualStrings("refresh_12345", token.refresh_token.?);
}
// ANCHOR_END: test_token_refresh_token

// ANCHOR: test_token_scope
test "token with scope" {
    var token = try OAuth2Token.init(testing.allocator, "access", "Bearer");
    defer token.deinit();

    try token.setScope("read write");

    try testing.expect(token.scope != null);
    try testing.expectEqualStrings("read write", token.scope.?);
}
// ANCHOR_END: test_token_scope

// ANCHOR: test_token_expiration
test "token expiration check" {
    var token = try OAuth2Token.init(testing.allocator, "access", "Bearer");
    defer token.deinit();

    token.expires_in = 3600; // 1 hour

    try testing.expect(!token.isExpired());

    // Simulate expired token
    token.issued_at -= 3601;
    try testing.expect(token.isExpired());
}
// ANCHOR_END: test_token_expiration

// ANCHOR: test_token_authorization_header
test "get authorization header" {
    var token = try OAuth2Token.init(testing.allocator, "test_token_123", "Bearer");
    defer token.deinit();

    const header = try token.getAuthorizationHeader();
    defer testing.allocator.free(header);

    try testing.expectEqualStrings("Bearer test_token_123", header);
}
// ANCHOR_END: test_token_authorization_header

// ANCHOR: test_oauth_config
test "create OAuth2 config" {
    var config = try OAuth2Config.init(
        testing.allocator,
        "client_id_123",
        "https://auth.example.com/authorize",
        "https://auth.example.com/token",
    );
    defer config.deinit();

    try testing.expectEqualStrings("client_id_123", config.client_id);
    try testing.expectEqualStrings("https://auth.example.com/authorize", config.authorization_endpoint);
    try testing.expectEqualStrings("https://auth.example.com/token", config.token_endpoint);
}
// ANCHOR_END: test_oauth_config

// ANCHOR: test_oauth_config_with_secret
test "config with client secret" {
    var config = try OAuth2Config.init(
        testing.allocator,
        "client_id_123",
        "https://auth.example.com/authorize",
        "https://auth.example.com/token",
    );
    defer config.deinit();

    try config.setClientSecret("secret_abc");

    try testing.expect(config.client_secret != null);
    try testing.expectEqualStrings("secret_abc", config.client_secret.?);
}
// ANCHOR_END: test_oauth_config_with_secret

// ANCHOR: test_oauth_config_redirect
test "config with redirect URI" {
    var config = try OAuth2Config.init(
        testing.allocator,
        "client_id_123",
        "https://auth.example.com/authorize",
        "https://auth.example.com/token",
    );
    defer config.deinit();

    try config.setRedirectUri("https://myapp.com/callback");

    try testing.expect(config.redirect_uri != null);
    try testing.expectEqualStrings("https://myapp.com/callback", config.redirect_uri.?);
}
// ANCHOR_END: test_oauth_config_redirect

// ANCHOR: test_pkce
test "generate PKCE challenge" {
    var pkce = try PKCE.init(testing.allocator);
    defer pkce.deinit();

    try testing.expect(pkce.code_verifier.len > 0);
    try testing.expect(pkce.code_challenge.len > 0);
    try testing.expect(pkce.code_verifier.len >= 43);
}
// ANCHOR_END: test_pkce

// ANCHOR: test_build_auth_url_basic
test "build authorization URL basic" {
    var config = try OAuth2Config.init(
        testing.allocator,
        "my_client_id",
        "https://oauth.example.com/authorize",
        "https://oauth.example.com/token",
    );
    defer config.deinit();

    var client = OAuth2Client.init(testing.allocator, config);

    const url = try client.buildAuthorizationUrl(null, null);
    defer testing.allocator.free(url);

    try testing.expect(std.mem.indexOf(u8, url, "response_type=code") != null);
    try testing.expect(std.mem.indexOf(u8, url, "client_id=my_client_id") != null);
}
// ANCHOR_END: test_build_auth_url_basic

// ANCHOR: test_build_auth_url_with_state
test "build authorization URL with state" {
    var config = try OAuth2Config.init(
        testing.allocator,
        "my_client_id",
        "https://oauth.example.com/authorize",
        "https://oauth.example.com/token",
    );
    defer config.deinit();

    var client = OAuth2Client.init(testing.allocator, config);

    const url = try client.buildAuthorizationUrl("state_xyz", null);
    defer testing.allocator.free(url);

    try testing.expect(std.mem.indexOf(u8, url, "state=state_xyz") != null);
}
// ANCHOR_END: test_build_auth_url_with_state

// ANCHOR: test_build_auth_url_with_pkce
test "build authorization URL with PKCE" {
    var config = try OAuth2Config.init(
        testing.allocator,
        "my_client_id",
        "https://oauth.example.com/authorize",
        "https://oauth.example.com/token",
    );
    defer config.deinit();

    var pkce = try PKCE.init(testing.allocator);
    defer pkce.deinit();

    var client = OAuth2Client.init(testing.allocator, config);

    const url = try client.buildAuthorizationUrl(null, &pkce);
    defer testing.allocator.free(url);

    try testing.expect(std.mem.indexOf(u8, url, "code_challenge=") != null);
    try testing.expect(std.mem.indexOf(u8, url, "code_challenge_method=S256") != null);
}
// ANCHOR_END: test_build_auth_url_with_pkce

// ANCHOR: test_exchange_code
test "exchange authorization code for token" {
    var config = try OAuth2Config.init(
        testing.allocator,
        "my_client_id",
        "https://oauth.example.com/authorize",
        "https://oauth.example.com/token",
    );
    defer config.deinit();

    var client = OAuth2Client.init(testing.allocator, config);

    var token = try client.exchangeAuthorizationCode("auth_code_123", null);
    defer token.deinit();

    try testing.expect(token.access_token.len > 0);
    try testing.expect(token.expires_in != null);
    try testing.expect(token.refresh_token != null);
}
// ANCHOR_END: test_exchange_code

// ANCHOR: test_refresh_token
test "refresh access token" {
    var config = try OAuth2Config.init(
        testing.allocator,
        "my_client_id",
        "https://oauth.example.com/authorize",
        "https://oauth.example.com/token",
    );
    defer config.deinit();

    var client = OAuth2Client.init(testing.allocator, config);

    var token = try client.refreshToken("old_refresh_token");
    defer token.deinit();

    try testing.expect(token.access_token.len > 0);
    try testing.expectEqualStrings("Bearer", token.token_type);
}
// ANCHOR_END: test_refresh_token

// ANCHOR: test_client_credentials
test "get client credentials token" {
    var config = try OAuth2Config.init(
        testing.allocator,
        "my_client_id",
        "https://oauth.example.com/authorize",
        "https://oauth.example.com/token",
    );
    defer config.deinit();

    try config.setClientSecret("my_secret");

    var client = OAuth2Client.init(testing.allocator, config);

    var token = try client.getClientCredentialsToken();
    defer token.deinit();

    try testing.expect(token.access_token.len > 0);
    try testing.expectEqual(@as(?i64, 7200), token.expires_in);
}
// ANCHOR_END: test_client_credentials

// ANCHOR: test_url_encoding
test "URL encode special characters" {
    var config = try OAuth2Config.init(
        testing.allocator,
        "my_client_id",
        "https://oauth.example.com/authorize",
        "https://oauth.example.com/token",
    );
    defer config.deinit();

    try config.setScope("read write profile");
    try config.setRedirectUri("https://app.com/callback?foo=bar");

    var client = OAuth2Client.init(testing.allocator, config);

    const url = try client.buildAuthorizationUrl(null, null);
    defer testing.allocator.free(url);

    try testing.expect(std.mem.indexOf(u8, url, "scope=read+write+profile") != null);
    try testing.expect(std.mem.indexOf(u8, url, "%3F") != null); // encoded ?
}
// ANCHOR_END: test_url_encoding

// ANCHOR: secure_password_verify
/// Securely verify password hash using constant-time comparison
///
/// When implementing OAuth2 password grant flow or any authentication system,
/// password hashes MUST be compared using timing-safe functions to prevent
/// timing attacks that could leak information about the stored credentials.
///
/// WRONG: std.mem.eql(u8, password_hash, stored_hash)
/// - Timing varies based on where mismatch occurs
/// - Attacker can measure response time to guess password character-by-character
///
/// CORRECT: std.crypto.timing_safe.eql()
/// - Constant-time comparison regardless of input values
/// - Prevents side-channel timing attacks
///
/// Implementation Note:
/// - std.crypto.timing_safe.eql works with compile-time-known fixed-size arrays
/// - For variable-length slices (like dynamic password hashes), manual constant-time
///   comparison is needed as shown below
/// - The XOR pattern ensures timing is independent of where values differ
pub fn verifyPasswordHash(
    password_hash: []const u8,
    stored_hash: []const u8,
) bool {
    // Early return on length mismatch is safe - length is not secret
    if (password_hash.len != stored_hash.len) {
        return false;
    }

    // Manual constant-time comparison for variable-length slices
    // Alternative: If hash length is fixed at compile time, use:
    //   std.crypto.timing_safe.eql([hash_len]u8, password_hash[0..hash_len].*, stored_hash[0..hash_len].*)
    //
    // This manual approach works for any slice length
    var result: u8 = 0;
    for (password_hash, stored_hash) |a, b| {
        result |= a ^ b;
    }

    // Return true only if all bytes matched (result == 0)
    // Using constant-time comparison for the final result
    return result == 0;
}
// ANCHOR_END: secure_password_verify

// ANCHOR: test_timing_safe_password
test "timing-safe password hash verification" {
    // Simulated bcrypt/argon2 password hashes (in real use, these would be actual hashes)
    const hash1 = "bcrypt$2b$12$abcdefghijklmnopqrstuvwxyz1234567890ABCDEFGH";
    const hash2 = "bcrypt$2b$12$abcdefghijklmnopqrstuvwxyz1234567890ABCDEFGH";
    const hash3 = "bcrypt$2b$12$WRONGHASH_zyxwvutsrqponmlkjihgfedcba9876543210";

    // Same hashes should match
    try testing.expect(verifyPasswordHash(hash1, hash2));

    // Different hashes should not match
    try testing.expect(!verifyPasswordHash(hash1, hash3));

    // Different lengths should not match
    const short_hash = "bcrypt$2b$12$short";
    try testing.expect(!verifyPasswordHash(hash1, short_hash));
}
// ANCHOR_END: test_timing_safe_password

// ANCHOR: test_timing_safe_tokens
test "timing-safe token comparison" {
    // OAuth2 tokens should also be compared using timing-safe functions
    // to prevent token guessing attacks through timing analysis
    const token1 = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.payload.signature";
    const token2 = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.payload.signature";
    const token3 = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.payload.WRONGSIG";

    try testing.expect(verifyPasswordHash(token1, token2));
    try testing.expect(!verifyPasswordHash(token1, token3));
}
// ANCHOR_END: test_timing_safe_tokens
