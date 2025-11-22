const std = @import("std");
const testing = std.testing;

// ANCHOR: tls_version
pub const TlsVersion = enum(u16) {
    tls_1_0 = 0x0301,
    tls_1_1 = 0x0302,
    tls_1_2 = 0x0303,
    tls_1_3 = 0x0304,

    pub fn toString(self: TlsVersion) []const u8 {
        return switch (self) {
            .tls_1_0 => "TLS 1.0",
            .tls_1_1 => "TLS 1.1",
            .tls_1_2 => "TLS 1.2",
            .tls_1_3 => "TLS 1.3",
        };
    }

    pub fn isSecure(self: TlsVersion) bool {
        // TLS 1.2 and 1.3 are considered secure
        return @intFromEnum(self) >= @intFromEnum(TlsVersion.tls_1_2);
    }
};
// ANCHOR_END: tls_version

// ANCHOR: cipher_suite
pub const CipherSuite = enum(u16) {
    // TLS 1.3 cipher suites (recommended)
    tls_aes_128_gcm_sha256 = 0x1301,
    tls_aes_256_gcm_sha384 = 0x1302,
    tls_chacha20_poly1305_sha256 = 0x1303,

    // TLS 1.2 cipher suites
    ecdhe_rsa_aes128_gcm_sha256 = 0xC02F,
    ecdhe_rsa_aes256_gcm_sha384 = 0xC030,

    pub fn toString(self: CipherSuite) []const u8 {
        return switch (self) {
            .tls_aes_128_gcm_sha256 => "TLS_AES_128_GCM_SHA256",
            .tls_aes_256_gcm_sha384 => "TLS_AES_256_GCM_SHA384",
            .tls_chacha20_poly1305_sha256 => "TLS_CHACHA20_POLY1305_SHA256",
            .ecdhe_rsa_aes128_gcm_sha256 => "ECDHE-RSA-AES128-GCM-SHA256",
            .ecdhe_rsa_aes256_gcm_sha384 => "ECDHE-RSA-AES256-GCM-SHA384",
        };
    }

    pub fn isRecommended(self: CipherSuite) bool {
        // TLS 1.3 cipher suites are recommended
        return @intFromEnum(self) >= 0x1301 and @intFromEnum(self) <= 0x1303;
    }
};
// ANCHOR_END: cipher_suite

// ANCHOR: certificate
pub const Certificate = struct {
    subject: []const u8,
    issuer: []const u8,
    not_before: i64, // Unix timestamp
    not_after: i64, // Unix timestamp
    fingerprint: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, subject: []const u8, issuer: []const u8) !Certificate {
        const subject_copy = try allocator.dupe(u8, subject);
        errdefer allocator.free(subject_copy);

        const issuer_copy = try allocator.dupe(u8, issuer);
        errdefer allocator.free(issuer_copy);

        const fingerprint_copy = try allocator.dupe(u8, "");

        return .{
            .subject = subject_copy,
            .issuer = issuer_copy,
            .not_before = std.time.timestamp(),
            .not_after = std.time.timestamp() + 31536000, // 1 year
            .fingerprint = fingerprint_copy,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Certificate) void {
        self.allocator.free(self.subject);
        self.allocator.free(self.issuer);
        self.allocator.free(self.fingerprint);
    }

    pub fn setFingerprint(self: *Certificate, fingerprint: []const u8) !void {
        const new_fingerprint = try self.allocator.dupe(u8, fingerprint);

        if (self.fingerprint.len > 0) {
            self.allocator.free(self.fingerprint);
        }
        self.fingerprint = new_fingerprint;
    }

    pub fn isValid(self: *const Certificate) bool {
        const now = std.time.timestamp();
        return now >= self.not_before and now <= self.not_after;
    }

    pub fn isExpired(self: *const Certificate) bool {
        return std.time.timestamp() > self.not_after;
    }

    pub fn daysUntilExpiry(self: *const Certificate) i64 {
        const now = std.time.timestamp();
        const seconds_remaining = self.not_after - now;
        return @divFloor(seconds_remaining, 86400); // Convert to days
    }
};
// ANCHOR_END: certificate

// ANCHOR: tls_config
pub const TlsConfig = struct {
    min_version: TlsVersion,
    max_version: TlsVersion,
    allowed_ciphers: std.ArrayList(CipherSuite),
    verify_certificates: bool,
    verify_hostname: bool,
    trusted_certificates: std.ArrayList(Certificate),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) TlsConfig {
        return .{
            .min_version = .tls_1_2, // Minimum secure version
            .max_version = .tls_1_3,
            .allowed_ciphers = std.ArrayList(CipherSuite){},
            .verify_certificates = true,
            .verify_hostname = true,
            .trusted_certificates = std.ArrayList(Certificate){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TlsConfig) void {
        self.allowed_ciphers.deinit(self.allocator);
        for (self.trusted_certificates.items) |*cert| {
            cert.deinit();
        }
        self.trusted_certificates.deinit(self.allocator);
    }

    pub fn addCipher(self: *TlsConfig, cipher: CipherSuite) !void {
        try self.allowed_ciphers.append(self.allocator, cipher);
    }

    pub fn addTrustedCertificate(self: *TlsConfig, cert: Certificate) !void {
        try self.trusted_certificates.append(self.allocator, cert);
    }

    pub fn setInsecure(self: *TlsConfig) void {
        self.verify_certificates = false;
        self.verify_hostname = false;
    }

    pub fn isSecure(self: *const TlsConfig) bool {
        return self.min_version.isSecure() and
            self.verify_certificates and
            self.verify_hostname;
    }
};
// ANCHOR_END: tls_config

// ANCHOR: tls_handshake_state
pub const TlsHandshakeState = enum {
    client_hello,
    server_hello,
    certificate_exchange,
    key_exchange,
    finished,
    established,
    failed,

    pub fn isComplete(self: TlsHandshakeState) bool {
        return self == .established;
    }

    pub fn isFailed(self: TlsHandshakeState) bool {
        return self == .failed;
    }
};
// ANCHOR_END: tls_handshake_state

// ANCHOR: tls_connection
pub const TlsConnection = struct {
    config: *const TlsConfig,
    state: TlsHandshakeState,
    negotiated_version: ?TlsVersion,
    negotiated_cipher: ?CipherSuite,
    server_certificate: ?Certificate,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: *const TlsConfig) TlsConnection {
        return .{
            .config = config,
            .state = .client_hello,
            .negotiated_version = null,
            .negotiated_cipher = null,
            .server_certificate = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *TlsConnection) void {
        if (self.server_certificate) |*cert| {
            cert.deinit();
        }
    }

    pub fn handshake(self: *TlsConnection) !void {
        // Simulate TLS handshake steps
        switch (self.state) {
            .client_hello => {
                self.state = .server_hello;
                self.negotiated_version = self.config.max_version;
            },
            .server_hello => {
                self.state = .certificate_exchange;
                if (self.config.allowed_ciphers.items.len > 0) {
                    self.negotiated_cipher = self.config.allowed_ciphers.items[0];
                }
            },
            .certificate_exchange => {
                self.state = .key_exchange;
                // Simulate receiving server certificate
                if (self.config.verify_certificates) {
                    const cert = try Certificate.init(
                        self.allocator,
                        "CN=example.com",
                        "CN=Example CA",
                    );
                    self.server_certificate = cert;
                }
            },
            .key_exchange => {
                self.state = .finished;
            },
            .finished => {
                self.state = .established;
            },
            .established => {
                // Already established
            },
            .failed => {
                return error.HandshakeFailed;
            },
        }
    }

    pub fn isEstablished(self: *const TlsConnection) bool {
        return self.state.isComplete();
    }

    pub fn verifyCertificate(self: *const TlsConnection) !void {
        const cert = self.server_certificate orelse return error.NoCertificate;

        // Check validity period
        if (!cert.isValid()) {
            return error.CertificateExpired;
        }

        // In a real implementation, verify certificate chain
        // against trusted certificates
        if (self.config.verify_certificates) {
            if (self.config.trusted_certificates.items.len == 0) {
                return error.NoTrustedCertificates;
            }
        }
    }
};
// ANCHOR_END: tls_connection

// ANCHOR: tls_error
pub const TlsError = error{
    HandshakeFailed,
    CertificateExpired,
    CertificateInvalid,
    UntrustedCertificate,
    HostnameMismatch,
    NoCertificate,
    NoTrustedCertificates,
    UnsupportedVersion,
    UnsupportedCipher,
};
// ANCHOR_END: tls_error

// ANCHOR: test_tls_version
test "TLS version enum" {
    try testing.expectEqual(@as(u16, 0x0303), @intFromEnum(TlsVersion.tls_1_2));
    try testing.expectEqual(@as(u16, 0x0304), @intFromEnum(TlsVersion.tls_1_3));

    try testing.expectEqualStrings("TLS 1.2", TlsVersion.tls_1_2.toString());
    try testing.expectEqualStrings("TLS 1.3", TlsVersion.tls_1_3.toString());
}
// ANCHOR_END: test_tls_version

// ANCHOR: test_tls_version_security
test "TLS version security check" {
    try testing.expect(!TlsVersion.tls_1_0.isSecure());
    try testing.expect(!TlsVersion.tls_1_1.isSecure());
    try testing.expect(TlsVersion.tls_1_2.isSecure());
    try testing.expect(TlsVersion.tls_1_3.isSecure());
}
// ANCHOR_END: test_tls_version_security

// ANCHOR: test_cipher_suite
test "cipher suite enum" {
    try testing.expectEqualStrings(
        "TLS_AES_128_GCM_SHA256",
        CipherSuite.tls_aes_128_gcm_sha256.toString(),
    );

    try testing.expect(CipherSuite.tls_aes_128_gcm_sha256.isRecommended());
    try testing.expect(!CipherSuite.ecdhe_rsa_aes128_gcm_sha256.isRecommended());
}
// ANCHOR_END: test_cipher_suite

// ANCHOR: test_certificate_creation
test "create certificate" {
    var cert = try Certificate.init(
        testing.allocator,
        "CN=example.com",
        "CN=Example CA",
    );
    defer cert.deinit();

    try testing.expectEqualStrings("CN=example.com", cert.subject);
    try testing.expectEqualStrings("CN=Example CA", cert.issuer);
    try testing.expect(cert.not_before > 0);
    try testing.expect(cert.not_after > cert.not_before);
}
// ANCHOR_END: test_certificate_creation

// ANCHOR: test_certificate_validity
test "certificate validity check" {
    var cert = try Certificate.init(
        testing.allocator,
        "CN=example.com",
        "CN=Example CA",
    );
    defer cert.deinit();

    // Should be valid (just created)
    try testing.expect(cert.isValid());
    try testing.expect(!cert.isExpired());

    // Set to expired
    cert.not_after = std.time.timestamp() - 1;
    try testing.expect(!cert.isValid());
    try testing.expect(cert.isExpired());
}
// ANCHOR_END: test_certificate_validity

// ANCHOR: test_certificate_expiry_days
test "certificate days until expiry" {
    var cert = try Certificate.init(
        testing.allocator,
        "CN=example.com",
        "CN=Example CA",
    );
    defer cert.deinit();

    const days = cert.daysUntilExpiry();
    // Should be approximately 365 days (1 year)
    try testing.expect(days > 360);
    try testing.expect(days < 370);
}
// ANCHOR_END: test_certificate_expiry_days

// ANCHOR: test_certificate_fingerprint
test "set certificate fingerprint" {
    var cert = try Certificate.init(
        testing.allocator,
        "CN=example.com",
        "CN=Example CA",
    );
    defer cert.deinit();

    try cert.setFingerprint("AA:BB:CC:DD");
    try testing.expectEqualStrings("AA:BB:CC:DD", cert.fingerprint);

    // Update fingerprint
    try cert.setFingerprint("11:22:33:44");
    try testing.expectEqualStrings("11:22:33:44", cert.fingerprint);
}
// ANCHOR_END: test_certificate_fingerprint

// ANCHOR: test_tls_config_creation
test "create TLS config" {
    var config = TlsConfig.init(testing.allocator);
    defer config.deinit();

    try testing.expectEqual(TlsVersion.tls_1_2, config.min_version);
    try testing.expectEqual(TlsVersion.tls_1_3, config.max_version);
    try testing.expect(config.verify_certificates);
    try testing.expect(config.verify_hostname);
}
// ANCHOR_END: test_tls_config_creation

// ANCHOR: test_tls_config_ciphers
test "add cipher suites to config" {
    var config = TlsConfig.init(testing.allocator);
    defer config.deinit();

    try config.addCipher(.tls_aes_128_gcm_sha256);
    try config.addCipher(.tls_aes_256_gcm_sha384);

    try testing.expectEqual(@as(usize, 2), config.allowed_ciphers.items.len);
    try testing.expectEqual(
        CipherSuite.tls_aes_128_gcm_sha256,
        config.allowed_ciphers.items[0],
    );
}
// ANCHOR_END: test_tls_config_ciphers

// ANCHOR: test_tls_config_certificates
test "add trusted certificates to config" {
    var config = TlsConfig.init(testing.allocator);
    defer config.deinit();

    const cert = try Certificate.init(
        testing.allocator,
        "CN=Root CA",
        "CN=Root CA",
    );

    try config.addTrustedCertificate(cert);
    try testing.expectEqual(@as(usize, 1), config.trusted_certificates.items.len);
}
// ANCHOR_END: test_tls_config_certificates

// ANCHOR: test_tls_config_insecure
test "set insecure TLS config" {
    var config = TlsConfig.init(testing.allocator);
    defer config.deinit();

    try testing.expect(config.isSecure());

    config.setInsecure();
    try testing.expect(!config.verify_certificates);
    try testing.expect(!config.verify_hostname);
    try testing.expect(!config.isSecure());
}
// ANCHOR_END: test_tls_config_insecure

// ANCHOR: test_tls_connection_creation
test "create TLS connection" {
    var config = TlsConfig.init(testing.allocator);
    defer config.deinit();

    var conn = TlsConnection.init(testing.allocator, &config);
    defer conn.deinit();

    try testing.expectEqual(TlsHandshakeState.client_hello, conn.state);
    try testing.expect(!conn.isEstablished());
}
// ANCHOR_END: test_tls_connection_creation

// ANCHOR: test_tls_handshake
test "TLS handshake process" {
    var config = TlsConfig.init(testing.allocator);
    defer config.deinit();

    try config.addCipher(.tls_aes_128_gcm_sha256);

    var conn = TlsConnection.init(testing.allocator, &config);
    defer conn.deinit();

    // Perform handshake steps
    try testing.expect(!conn.isEstablished());

    try conn.handshake(); // client_hello -> server_hello
    try testing.expectEqual(TlsHandshakeState.server_hello, conn.state);

    try conn.handshake(); // server_hello -> certificate_exchange
    try testing.expectEqual(TlsHandshakeState.certificate_exchange, conn.state);

    try conn.handshake(); // certificate_exchange -> key_exchange
    try testing.expectEqual(TlsHandshakeState.key_exchange, conn.state);

    try conn.handshake(); // key_exchange -> finished
    try testing.expectEqual(TlsHandshakeState.finished, conn.state);

    try conn.handshake(); // finished -> established
    try testing.expect(conn.isEstablished());
}
// ANCHOR_END: test_tls_handshake

// ANCHOR: test_tls_version_negotiation
test "TLS version negotiation" {
    var config = TlsConfig.init(testing.allocator);
    defer config.deinit();

    config.max_version = .tls_1_3;

    var conn = TlsConnection.init(testing.allocator, &config);
    defer conn.deinit();

    try conn.handshake();

    try testing.expect(conn.negotiated_version != null);
    try testing.expectEqual(TlsVersion.tls_1_3, conn.negotiated_version.?);
}
// ANCHOR_END: test_tls_version_negotiation

// ANCHOR: test_tls_cipher_negotiation
test "TLS cipher suite negotiation" {
    var config = TlsConfig.init(testing.allocator);
    defer config.deinit();

    try config.addCipher(.tls_aes_256_gcm_sha384);

    var conn = TlsConnection.init(testing.allocator, &config);
    defer conn.deinit();

    try conn.handshake(); // client_hello -> server_hello
    try conn.handshake(); // server_hello -> certificate_exchange

    try testing.expect(conn.negotiated_cipher != null);
    try testing.expectEqual(
        CipherSuite.tls_aes_256_gcm_sha384,
        conn.negotiated_cipher.?,
    );
}
// ANCHOR_END: test_tls_cipher_negotiation

// ANCHOR: test_certificate_verification
test "certificate verification" {
    var config = TlsConfig.init(testing.allocator);
    defer config.deinit();

    const trusted_cert = try Certificate.init(
        testing.allocator,
        "CN=Root CA",
        "CN=Root CA",
    );
    try config.addTrustedCertificate(trusted_cert);

    var conn = TlsConnection.init(testing.allocator, &config);
    defer conn.deinit();

    // Complete handshake
    try conn.handshake(); // client_hello
    try conn.handshake(); // server_hello
    try conn.handshake(); // certificate_exchange

    // Verify certificate
    try conn.verifyCertificate();
}
// ANCHOR_END: test_certificate_verification

// ANCHOR: test_expired_certificate
test "expired certificate detection" {
    var config = TlsConfig.init(testing.allocator);
    defer config.deinit();

    var conn = TlsConnection.init(testing.allocator, &config);
    defer conn.deinit();

    // Complete handshake to get certificate
    try conn.handshake();
    try conn.handshake();
    try conn.handshake();

    // Expire the certificate
    if (conn.server_certificate) |*cert| {
        cert.not_after = std.time.timestamp() - 1;
    }

    // Verification should fail
    try testing.expectError(error.CertificateExpired, conn.verifyCertificate());
}
// ANCHOR_END: test_expired_certificate
