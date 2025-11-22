## Problem

You need to establish secure TLS/SSL connections for HTTPS requests or secure network communication. You need to configure TLS versions, cipher suites, certificate validation, and handle the TLS handshake process. Security requirements dictate using modern TLS versions (1.2+) and strong cipher suites while properly validating server certificates.

## Solution

Build TLS connection management using enum types for versions and cipher suites, structures for certificates and configuration, and a state machine for the handshake process. While Zig's standard library TLS support is evolving, this recipe demonstrates the fundamental patterns for TLS configuration and connection management.

### TLS Version Management

```zig
{{#include ../../../code/04-specialized/11-network-web/recipe_11_8.zig:tls_version}}
```

**Version Recommendations:**
- **TLS 1.3**: Latest, fastest, most secure (recommended)
- **TLS 1.2**: Widely supported, secure, minimum acceptable
- **TLS 1.1**: Deprecated, not recommended
- **TLS 1.0**: Deprecated, insecure, avoid

### Cipher Suite Configuration

```zig
{{#include ../../../code/04-specialized/11-network-web/recipe_11_8.zig:cipher_suite}}
```

**Cipher Suite Selection:**
- TLS 1.3 uses AEAD ciphers (GCM, ChaCha20-Poly1305)
- Prefer forward secrecy (ECDHE key exchange)
- Avoid weak ciphers (RC4, DES, MD5, SHA1)

### Certificate Management

```zig
var cert = try Certificate.init(
    testing.allocator,
    "CN=example.com",
    "CN=Example CA",
);
defer cert.deinit();

// Set certificate fingerprint
try cert.setFingerprint("AA:BB:CC:DD:EE:FF");

// Check validity
if (cert.isValid()) {
    // Certificate is within validity period
}

// Check expiration
if (cert.isExpired()) {
    // Certificate has expired
}

// Days until expiry
const days = cert.daysUntilExpiry();
if (days < 30) {
    // Certificate expires soon
}
```

The `Certificate` struct stores:
- **Subject**: Entity the certificate identifies (e.g., "CN=example.com")
- **Issuer**: Certificate Authority that signed it
- **Not Before**: Start of validity period (Unix timestamp)
- **Not After**: End of validity period
- **Fingerprint**: Certificate hash for verification

### TLS Configuration

```zig
var config = TlsConfig.init(testing.allocator);
defer config.deinit();

// Set version range
config.min_version = .tls_1_2; // Minimum secure version
config.max_version = .tls_1_3; // Latest version

// Add allowed cipher suites (in preference order)
try config.addCipher(.tls_aes_256_gcm_sha384);
try config.addCipher(.tls_aes_128_gcm_sha256);
try config.addCipher(.tls_chacha20_poly1305_sha256);

// Configure certificate verification
config.verify_certificates = true;
config.verify_hostname = true;

// Add trusted root certificates
var root_ca = try Certificate.init(
    allocator,
    "CN=Root CA",
    "CN=Root CA",
);
try config.addTrustedCertificate(root_ca);
```

**Configuration Options:**
- **min_version/max_version**: Acceptable TLS version range
- **allowed_ciphers**: Cipher suites in preference order
- **verify_certificates**: Validate server certificate chain
- **verify_hostname**: Ensure certificate matches hostname
- **trusted_certificates**: Root CAs to trust

### Secure vs Insecure Configuration

```zig
// Secure configuration (recommended)
var config = TlsConfig.init(allocator);
config.min_version = .tls_1_2;
config.verify_certificates = true;
config.verify_hostname = true;

if (config.isSecure()) {
    // Configuration meets security standards
}

// Insecure configuration (development only)
config.setInsecure(); // Disables all verification
```

**Never use insecure configuration in production!** It defeats the purpose of TLS and makes connections vulnerable to man-in-the-middle attacks.

### TLS Handshake Process

```zig
var conn = TlsConnection.init(testing.allocator, &config);
defer conn.deinit();

// Perform TLS handshake
while (!conn.isEstablished()) {
    try conn.handshake();
}

// Connection is now secure
if (conn.negotiated_version) |version| {
    // TLS version was negotiated
}

if (conn.negotiated_cipher) |cipher| {
    // Cipher suite was selected
}
```

The handshake progresses through states:
1. **client_hello**: Client sends supported versions/ciphers
2. **server_hello**: Server selects version/cipher
3. **certificate_exchange**: Server sends certificate
4. **key_exchange**: Keys are exchanged
5. **finished**: Handshake complete
6. **established**: Secure connection ready

### TLS Handshake State Machine

```zig
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
};

// Check connection state
if (conn.state.isComplete()) {
    // Ready to send/receive encrypted data
}

if (conn.state.isFailed()) {
    // Handshake failed
}
```

### Version and Cipher Negotiation

```zig
var config = TlsConfig.init(allocator);
defer config.deinit();

// Client supports TLS 1.2 and 1.3
config.min_version = .tls_1_2;
config.max_version = .tls_1_3;

// Client preference order
try config.addCipher(.tls_aes_256_gcm_sha384); // First choice
try config.addCipher(.tls_aes_128_gcm_sha256); // Second choice

var conn = TlsConnection.init(allocator, &config);
defer conn.deinit();

// Handshake negotiates
try conn.handshake(); // client_hello
try conn.handshake(); // server_hello

// Check negotiated parameters
const version = conn.negotiated_version.?; // TLS 1.3 if server supports it
const cipher = conn.negotiated_cipher.?; // Server selects from client's list
```

The negotiation process:
1. Client sends supported versions and ciphers
2. Server chooses highest common version
3. Server selects cipher from client's list
4. Both sides use negotiated parameters

### Certificate Verification

```zig
var config = TlsConfig.init(allocator);
defer config.deinit();

// Add trusted root CA
var root_ca = try Certificate.init(
    allocator,
    "CN=Root CA",
    "CN=Root CA",
);
try config.addTrustedCertificate(root_ca);

var conn = TlsConnection.init(allocator, &config);
defer conn.deinit();

// Complete handshake (receives server certificate)
while (!conn.isEstablished()) {
    try conn.handshake();
}

// Verify the server certificate
try conn.verifyCertificate();
```

Certificate verification checks:
- Certificate is within validity period
- Certificate is signed by trusted CA
- Certificate matches hostname (if verify_hostname enabled)
- Certificate chain is complete and valid

### Handling Certificate Expiration

```zig
// During verification
try conn.verifyCertificate(); // Returns error.CertificateExpired

// Proactive monitoring
if (conn.server_certificate) |cert| {
    if (cert.isExpired()) {
        return error.CertificateExpired;
    }

    const days_left = cert.daysUntilExpiry();
    if (days_left < 30) {
        std.log.warn("Certificate expires in {} days", .{days_left});
    }
}
```

## Discussion

### TLS Protocol Versions

**TLS 1.3** (2018):
- Faster handshake (fewer round trips)
- Only AEAD ciphers (better security)
- Perfect forward secrecy required
- Removed weak/legacy features
- Encrypted handshake messages

**TLS 1.2** (2008):
- Widely supported
- Secure with proper cipher selection
- Allows non-AEAD ciphers (backwards compatibility)
- Slower handshake than 1.3

**TLS 1.0/1.1** (1999/2006):
- **Deprecated** - do not use
- Vulnerable to attacks (BEAST, POODLE)
- Disabled by major browsers

### Cipher Suite Components

A cipher suite specifies:

1. **Key Exchange**: How session keys are negotiated
   - ECDHE: Elliptic Curve Diffie-Hellman Ephemeral (forward secrecy)
   - RSA: Legacy, no forward secrecy

2. **Authentication**: How server is authenticated
   - RSA: RSA signature
   - ECDSA: Elliptic Curve signature

3. **Encryption**: Bulk data encryption
   - AES128/256: Advanced Encryption Standard
   - ChaCha20: Modern stream cipher

4. **MAC/AEAD**: Message authentication
   - GCM: Galois/Counter Mode (AEAD)
   - Poly1305: AEAD for ChaCha20
   - SHA256/384: Hash for MAC

**Example breakdown:**
- `TLS_AES_256_GCM_SHA384`: TLS 1.3, AES-256, GCM mode, SHA-384
- `ECDHE_RSA_AES128_GCM_SHA256`: ECDHE key exchange, RSA auth, AES-128 GCM, SHA-256

### Certificate Validation Process

In production TLS implementations, certificate validation involves:

1. **Chain Validation**:
   - Server sends certificate chain
   - Each certificate signed by next in chain
   - Chain ends at trusted root CA

2. **Validity Period**:
   - Check current time >= not_before
   - Check current time <= not_after

3. **Hostname Verification**:
   - Certificate subject matches hostname
   - Check Subject Alternative Names (SAN)
   - Wildcard matching (*.example.com)

4. **Revocation Checking**:
   - Check Certificate Revocation List (CRL)
   - Online Certificate Status Protocol (OCSP)

This recipe demonstrates basic validation. Production code needs full chain verification.

### Memory Management in Certificates

The `Certificate.init` uses proper error handling:

```zig
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
```

The `errdefer` statements ensure:
- If issuer allocation fails, subject is freed
- If fingerprint allocation fails, both subject and issuer are freed
- No memory leaks on partial initialization

### Safe Fingerprint Updates

The `setFingerprint` method allocates new memory before freeing old:

```zig
pub fn setFingerprint(self: *Certificate, fingerprint: []const u8) !void {
    const new_fingerprint = try self.allocator.dupe(u8, fingerprint);

    if (self.fingerprint.len > 0) {
        self.allocator.free(self.fingerprint);
    }
    self.fingerprint = new_fingerprint;
}
```

This prevents double-free if allocation fails:
1. Try to allocate new fingerprint
2. If successful, free old fingerprint
3. Store new fingerprint

If allocation fails, the old fingerprint remains valid.

### TLS Configuration Best Practices

**For Production:**
```zig
var config = TlsConfig.init(allocator);
defer config.deinit();

// Modern TLS only
config.min_version = .tls_1_2;
config.max_version = .tls_1_3;

// Strong ciphers only (TLS 1.3 preferred)
try config.addCipher(.tls_aes_256_gcm_sha384);
try config.addCipher(.tls_aes_128_gcm_sha256);
try config.addCipher(.tls_chacha20_poly1305_sha256);
try config.addCipher(.ecdhe_rsa_aes256_gcm_sha384); // TLS 1.2 fallback

// Strict validation
config.verify_certificates = true;
config.verify_hostname = true;

// Load system root CAs or specific trusted CAs
try loadSystemRootCAs(&config);
```

**For Development/Testing:**
```zig
var config = TlsConfig.init(allocator);
defer config.deinit();

// Less strict for self-signed certs
config.setInsecure(); // DO NOT USE IN PRODUCTION

// Or selective disabling
config.verify_hostname = false; // Allow localhost
config.verify_certificates = true; // Still check expiration
```

### Handshake State Progression

The TLS handshake is a multi-step negotiation:

```zig
pub fn handshake(self: *TlsConnection) !void {
    switch (self.state) {
        .client_hello => {
            // Send ClientHello with supported versions/ciphers
            self.state = .server_hello;
            self.negotiated_version = self.config.max_version;
        },
        .server_hello => {
            // Receive ServerHello with selected version/cipher
            self.state = .certificate_exchange;
            if (self.config.allowed_ciphers.items.len > 0) {
                self.negotiated_cipher = self.config.allowed_ciphers.items[0];
            }
        },
        .certificate_exchange => {
            // Receive and store server certificate
            self.state = .key_exchange;
            if (self.config.verify_certificates) {
                const cert = try Certificate.init(...);
                self.server_certificate = cert;
            }
        },
        .key_exchange => {
            // Exchange keys for symmetric encryption
            self.state = .finished;
        },
        .finished => {
            // Verify handshake integrity
            self.state = .established;
        },
        .established => {
            // Connection ready
        },
        .failed => {
            return error.HandshakeFailed;
        },
    }
}
```

Each state represents a phase in establishing trust and encryption.

### Error Handling

TLS operations can fail for many reasons:

```zig
const TlsError = error{
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

// Handle specific errors
conn.verifyCertificate() catch |err| switch (err) {
    error.CertificateExpired => {
        std.log.err("Server certificate expired", .{});
        return err;
    },
    error.UntrustedCertificate => {
        std.log.err("Server certificate not trusted", .{});
        return err;
    },
    else => return err,
};
```

### Certificate Lifecycle

Certificates have limited validity periods:

```zig
var cert = try Certificate.init(allocator, "CN=example.com", "CN=CA");
defer cert.deinit();

// Typically valid for 1 year (set in init)
try testing.expect(cert.isValid());

// Check how long until renewal needed
const days = cert.daysUntilExpiry();
if (days < 30) {
    std.log.warn("Certificate renewal needed", .{});
}

// Simulate expiration
cert.not_after = std.time.timestamp() - 1;
try testing.expect(cert.isExpired());
```

**Certificate Renewal Best Practices:**
- Renew 30-60 days before expiration
- Use automated renewal (Let's Encrypt, cert-manager)
- Monitor expiration dates
- Test renewal process regularly

### Integration with std.http.Client

In production, TLS configuration integrates with HTTP clients:

```zig
// Conceptual integration (API may vary)
var tls_config = TlsConfig.init(allocator);
defer tls_config.deinit();

tls_config.min_version = .tls_1_2;
try tls_config.addCipher(.tls_aes_128_gcm_sha256);

var client = std.http.Client{
    .allocator = allocator,
    .tls_config = &tls_config, // Pass TLS configuration
};
defer client.deinit();

// HTTPS requests use TLS configuration
var request = try client.open(.GET, uri, .{});
defer request.deinit();
```

### Security Considerations

**Certificate Pinning:**
For high-security applications, pin specific certificates or public keys:

```zig
const expected_fingerprint = "AA:BB:CC:DD:EE:FF:...";

if (conn.server_certificate) |cert| {
    if (!std.mem.eql(u8, cert.fingerprint, expected_fingerprint)) {
        return error.CertificatePinningFailed;
    }
}
```

**Forward Secrecy:**
Always use ECDHE key exchange for forward secrecy:

```zig
// Good - Forward secrecy
.ecdhe_rsa_aes128_gcm_sha256

// Bad - No forward secrecy
.rsa_aes128_gcm_sha256
```

Forward secrecy ensures past communications can't be decrypted even if the server's private key is compromised.

**Perfect Forward Secrecy (TLS 1.3):**
TLS 1.3 requires forward secrecy for all cipher suites.

### Limitations of This Implementation

This recipe demonstrates TLS concepts but lacks:

**Missing Production Features:**
- Actual network I/O
- Real certificate chain validation
- OCSP/CRL revocation checking
- Hostname verification implementation
- Certificate pinning
- Session resumption
- ALPN (Application-Layer Protocol Negotiation)
- SNI (Server Name Indication)

**For Production:**
- Use Zig's `std.crypto.tls` when stable
- Use established TLS libraries (BoringSSL, OpenSSL via C binding)
- Implement full certificate chain validation
- Support certificate revocation checking
- Add proper hostname verification
- Implement session caching/resumption

### Best Practices Summary

**Configuration:**
- Use TLS 1.2 minimum, prefer 1.3
- Select strong cipher suites (AEAD only)
- Enable certificate and hostname verification
- Load proper trusted root CAs

**Certificates:**
- Monitor expiration dates
- Automate renewal
- Use proper error handling
- Validate certificate chains

**Error Handling:**
- Never ignore TLS errors
- Log security-relevant events
- Fail securely (deny by default)
- Provide clear error messages

**Development:**
- Use secure defaults
- Test with real certificates
- Never use `setInsecure()` in production
- Implement proper logging

## See Also

- Recipe 11.1: Making HTTP requests - Use TLS for HTTPS
- Recipe 11.6: Working with REST APIs - Secure API communication
- Recipe 11.7: Handling cookies and sessions - Secure flag requires HTTPS
- Recipe 13.5: Cryptographic operations - Certificate generation and validation

Full compilable example: `code/04-specialized/11-network-web/recipe_11_8.zig`
