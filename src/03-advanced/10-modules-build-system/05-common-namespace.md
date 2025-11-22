## Problem

You have multiple independent feature modules (auth, billing, analytics) organized in separate directories. You want users to access all features through a common namespace (`features.auth`, `features.billing`, `features.analytics`) instead of importing each directory separately. You need a clean organizational structure that makes adding new features straightforward.

## Solution

Create a namespace aggregator module that imports all feature directories and re-exports them under a common namespace. Each feature lives in its own directory with its own submodules. The aggregator provides a single import point and consistent access pattern.

### Module Structure

Organize features in separate directories:

```
recipe_10_5/
├── features.zig (namespace aggregator)
├── auth/
│   ├── auth.zig
│   └── auth/login.zig
├── billing/
│   ├── billing.zig
│   └── billing/invoice.zig
└── analytics/
    ├── analytics.zig
    └── analytics/tracking.zig
```

### Import the Namespace

Users import only the namespace aggregator:

```zig
{{#include ../../../code/03-advanced/10-modules-build-system/recipe_10_5.zig:namespace_imports}}
```

All features are accessible through this single import.

### Using Features Through the Namespace

Access all features through the common namespace:

```zig
test "accessing features through namespace" {
    // All features are accessible through the common namespace
    const auth_result = features.auth.authenticate("alice", "password123");
    try testing.expect(auth_result);

    const invoice = features.billing.Invoice{
        .id = 1,
        .customer = "ACME Corp",
        .amount = 1000.50,
    };
    try testing.expectEqual(@as(u32, 1), invoice.id);

    const event = features.analytics.Event{
        .name = "page_view",
        .user_id = 42,
        .timestamp = 1234567890,
    };
    features.analytics.track(event);
}
```

Clear organization: `features.{feature}.{function}`.

## Discussion

### Creating the Namespace Aggregator

The `features.zig` file imports and re-exports all feature modules:

```zig
// Features namespace aggregator
const std = @import("std");

// Import each feature directory's main module
pub const auth = @import("auth/auth.zig");
pub const billing = @import("billing/billing.zig");
pub const analytics = @import("analytics/analytics.zig");
```

This creates the namespace structure:
- `features.auth` (authentication feature)
- `features.billing` (billing feature)
- `features.analytics` (analytics feature)

### Auth Feature

The auth feature demonstrates a stateful module:

```zig
// Authentication feature module
const std = @import("std");
const login = @import("auth/login.zig");

pub const User = struct {
    id: u32,
    username: []const u8,
};

// Simple in-memory auth state (for demonstration)
// WARNING: Global state is NOT thread-safe and for demonstration only.
// Production code should use explicit context structs passed to functions.
var current_user: ?User = null;
var logged_in: bool = false;

pub fn authenticate(username: []const u8, password: []const u8) bool {
    // Use login module for authentication logic
    const result = login.verifyCredentials(username, password);

    if (result) {
        current_user = User{
            .id = 1,
            .username = username,
        };
        logged_in = true;
    }

    return result;
}

pub fn logout() void {
    current_user = null;
    logged_in = false;
}

pub fn isLoggedIn() bool {
    return logged_in;
}

pub fn getCurrentUser() User {
    return current_user orelse User{ .id = 0, .username = "guest" };
}
```

The auth feature maintains state and provides authentication services.

Test the auth feature:

```zig
test "auth feature" {
    // Authentication through namespace
    try testing.expect(features.auth.authenticate("alice", "password123"));
    try testing.expect(!features.auth.authenticate("alice", "wrong"));

    const user = features.auth.getCurrentUser();
    try testing.expectEqualStrings("alice", user.username);

    features.auth.logout();
    try testing.expect(!features.auth.isLoggedIn());
}
```

### Billing Feature

The billing feature demonstrates a stateless module:

```zig
// Billing feature module
const std = @import("std");
const invoice_mod = @import("billing/invoice.zig");

pub const Invoice = struct {
    id: u32,
    customer: []const u8,
    amount: f64,
};

pub fn calculateTotal(invoice: *const Invoice, tax_rate: f64) f64 {
    return invoice_mod.applyTax(invoice.amount, tax_rate);
}
```

Billing works on data structures without maintaining state.

Test the billing feature:

```zig
test "billing feature" {
    // Billing operations through namespace
    const invoice = features.billing.Invoice{
        .id = 123,
        .customer = "Test Customer",
        .amount = 500.00,
    };

    try testing.expectEqual(@as(u32, 123), invoice.id);
    try testing.expectEqualStrings("Test Customer", invoice.customer);
    try testing.expectApproxEqAbs(@as(f64, 500.00), invoice.amount, 0.01);

    const total = features.billing.calculateTotal(&invoice, 0.1);
    try testing.expectApproxEqAbs(@as(f64, 550.00), total, 0.01);
}
```

### Analytics Feature

The analytics feature demonstrates event tracking:

```zig
// Analytics feature module
const std = @import("std");
const tracking = @import("analytics/tracking.zig");

pub const Event = struct {
    name: []const u8,
    user_id: u32,
    timestamp: u64,
};

// Simple in-memory event storage (for demonstration)
// WARNING: Global state is NOT thread-safe and for demonstration only.
// Production code should use explicit context structs passed to functions.
var event_count: usize = 0;

pub fn track(event: Event) void {
    tracking.recordEvent(event);
    event_count += 1;
}

pub fn getEventCount() usize {
    return event_count;
}

pub fn reset() void {
    event_count = 0;
}
```

Analytics tracks events and maintains counts.

Test the analytics feature:

```zig
test "analytics feature" {
    // Reset analytics state for clean test
    features.analytics.reset();

    // Analytics through namespace
    const event1 = features.analytics.Event{
        .name = "button_click",
        .user_id = 1,
        .timestamp = 1000,
    };

    const event2 = features.analytics.Event{
        .name = "page_view",
        .user_id = 2,
        .timestamp = 2000,
    };

    features.analytics.track(event1);
    features.analytics.track(event2);

    const count = features.analytics.getEventCount();
    try testing.expectEqual(@as(usize, 2), count);

    features.analytics.reset();
    try testing.expectEqual(@as(usize, 0), features.analytics.getEventCount());
}
```

### Cross-Feature Usage

Features work together through the namespace:

```zig
test "using multiple features together" {
    // Reset state for clean test
    features.analytics.reset();
    features.auth.logout();

    // Features can work together through the common namespace

    // Authenticate user
    const logged_in = features.auth.authenticate("bob", "secret123");
    try testing.expect(logged_in);

    // Track login event
    const login_event = features.analytics.Event{
        .name = "user_login",
        .user_id = 1,
        .timestamp = 1234567890,
    };
    features.analytics.track(login_event);

    // Create invoice for logged-in user
    const user = features.auth.getCurrentUser();
    const invoice = features.billing.Invoice{
        .id = 1,
        .customer = user.username,
        .amount = 99.99,
    };

    try testing.expectEqualStrings("bob", invoice.customer);

    // Track billing event
    const billing_event = features.analytics.Event{
        .name = "invoice_created",
        .user_id = user.id,
        .timestamp = 1234567891,
    };
    features.analytics.track(billing_event);

    try testing.expectEqual(@as(usize, 2), features.analytics.getEventCount());
}
```

Features coordinate through the shared namespace without direct imports.

### Namespace Benefits

The namespace pattern provides clear advantages:

```zig
test "namespace benefits" {
    // Benefit 1: All features under one import
    // Benefit 2: Clear feature separation
    // Benefit 3: Easy to add new features
    // Benefit 4: Features can be developed independently

    // Single import gives access to all features
    try testing.expect(features.auth.authenticate("test", "password"));
    _ = features.billing.Invoice{ .id = 1, .customer = "Test", .amount = 100 };
    _ = features.analytics.Event{ .name = "test", .user_id = 1, .timestamp = 0 };
}
```

One import provides access to the entire feature set.

### Feature Independence

Each feature is independent and testable:

```zig
test "feature modules are independent" {
    // Each feature can be tested independently

    // Auth feature
    try testing.expect(features.auth.authenticate("user1", "password1"));

    // Billing feature (doesn't depend on auth being called)
    const inv = features.billing.Invoice{
        .id = 1,
        .customer = "Customer",
        .amount = 100,
    };
    try testing.expectEqual(@as(u32, 1), inv.id);

    // Analytics feature (doesn't depend on others)
    features.analytics.reset();
    try testing.expectEqual(@as(usize, 0), features.analytics.getEventCount());
}
```

Features don't require each other to function.

### Namespace Organization

Clear organizational structure:

```zig
test "namespace organization" {
    // Clear organization: features.{feature}.{function}

    // Auth namespace
    _ = features.auth.authenticate("user", "pass");
    _ = features.auth.logout();
    _ = features.auth.isLoggedIn();

    // Billing namespace
    const invoice = features.billing.Invoice{
        .id = 1,
        .customer = "Test",
        .amount = 50,
    };
    _ = features.billing.calculateTotal(&invoice, 0.1);

    // Analytics namespace
    const event = features.analytics.Event{
        .name = "test",
        .user_id = 1,
        .timestamp = 0,
    };
    features.analytics.track(event);
    _ = features.analytics.getEventCount();

    try testing.expect(true);
}
```

Consistent access pattern across all features.

### Adding New Features

The pattern makes extension straightforward:

```zig
test "adding new features is easy" {
    // To add a new feature:
    // 1. Create a new directory: features/newfeature/
    // 2. Create newfeature.zig with public API
    // 3. Add to features.zig: pub const newfeature = @import("newfeature/newfeature.zig");
    // 4. Use it: features.newfeature.doSomething()

    // The namespace pattern makes feature addition straightforward
    try testing.expect(true);
}
```

Adding features requires minimal changes to existing code.

### Feature Isolation

Each feature maintains its own state:

```zig
test "features are isolated" {
    // Each feature directory is self-contained

    // Auth state is isolated
    try testing.expect(features.auth.authenticate("user", "password"));

    // Analytics state is isolated
    const count_before = features.analytics.getEventCount();
    features.analytics.track(.{
        .name = "test",
        .user_id = 1,
        .timestamp = 0,
    });
    try testing.expectEqual(count_before + 1, features.analytics.getEventCount());

    // Billing has no state (just functions on data)
    const inv = features.billing.Invoice{
        .id = 1,
        .customer = "Test",
        .amount = 100,
    };
    _ = features.billing.calculateTotal(&inv, 0.1);
}
```

Features don't interfere with each other.

### Feature Directory Structure

Each feature is self-contained:

```
auth/
├── auth.zig (public API)
└── auth/
    └── login.zig (implementation details)

billing/
├── billing.zig (public API)
└── billing/
    └── invoice.zig (implementation details)

analytics/
├── analytics.zig (public API)
└── analytics/
    └── tracking.zig (implementation details)
```

Public API in the top-level file, implementation in subdirectories.

### Login Verification

The login module provides credential verification:

```zig
// Login verification logic
pub fn verifyCredentials(username: []const u8, password: []const u8) bool {
    // WARNING: This is UNSAFE demonstration code only!
    // NEVER use in production. Always:
    // - Hash passwords with bcrypt/argon2
    // - Validate against secure database
    // - Implement rate limiting
    // - Use constant-time comparison

    if (username.len == 0 or password.len < 6) {
        return false;
    }

    // Accept any username with password length >= 6 (demonstration only!)
    return true;
}
```

This demonstrates the pattern, not secure authentication.

### Invoice Calculations

The invoice module handles tax calculations:

```zig
// Invoice calculation logic
pub fn applyTax(amount: f64, tax_rate: f64) f64 {
    return amount * (1.0 + tax_rate);
}
```

Simple calculation isolated in its own module.

### Event Tracking

The tracking module records events:

```zig
// Event tracking logic
pub fn recordEvent(event: anytype) void {
    // In production, this would send events to an analytics service
    // For demonstration, we just acknowledge the event
    _ = event;
}
```

Placeholder for external service integration.

### Benefits of Namespace Organization

**Single Import Point:**
- Users import one module
- Access all features through namespace
- Consistent API surface

**Clear Organization:**
- Features grouped logically
- Easy to find functionality
- Self-documenting structure

**Independent Development:**
- Features don't share code
- Can be developed separately
- No cross-dependencies

**Easy Extension:**
- Add new features without changing existing code
- Just add to aggregator
- No breaking changes

### When to Use Namespace Aggregation

Use namespace aggregation when:

**Multiple Features:** You have distinct features to organize
**Clear Boundaries:** Features have well-defined responsibilities
**Independent Development:** Different teams work on different features
**Plugin Architecture:** You want to add features dynamically

Don't use namespace aggregation when:

**Single Feature:** Only one feature exists
**Tight Coupling:** Features depend heavily on each other
**Simple API:** A flat module structure is clearer
**Performance Critical:** Extra indirection matters

### Best Practices

**Keep Aggregator Thin:**
```zig
// Good: Just re-exports
pub const auth = @import("auth/auth.zig");
pub const billing = @import("billing/billing.zig");

// Bad: Logic in aggregator
pub fn crossFeatureOperation() void {
    // Don't put logic here
}
```

**Feature Independence:**
```zig
// Good: Features don't import each other
// auth/auth.zig doesn't import billing or analytics

// Bad: Cross-feature imports
// auth/auth.zig imports billing/billing.zig
```

**Consistent Naming:**
```
features/auth/auth.zig
features/billing/billing.zig
features/analytics/analytics.zig
```

**Public API at Top Level:**
```zig
// feature/feature.zig - Public API
pub const Type = ...;
pub fn publicFunction() void { ... }

// feature/feature/internal.zig - Implementation details
fn internalFunction() void { ... }
```

### Global State Considerations

The example uses global state for simplicity, but has important limitations:

**Demonstration Pattern:**
```zig
// WARNING: Global state is NOT thread-safe and for demonstration only.
// Production code should use explicit context structs passed to functions.
var current_user: ?User = null;
```

**Production Pattern:**
```zig
// Better: Explicit context struct
pub const AuthContext = struct {
    current_user: ?User,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) AuthContext {
        return .{ .current_user = null, .allocator = allocator };
    }

    pub fn authenticate(self: *AuthContext, username: []const u8, password: []const u8) !void {
        // Thread-safe, explicit state management
    }
};
```

For production code, use context structs instead of global state.

### Testing Strategy

Test features independently:

```zig
// Test each feature in isolation
test "auth works alone" {
    try testing.expect(features.auth.authenticate("user", "password"));
}

test "billing works alone" {
    const inv = features.billing.Invoice{ ... };
    _ = features.billing.calculateTotal(&inv, 0.1);
}

test "analytics works alone" {
    features.analytics.reset();
    features.analytics.track(...);
}
```

Then test integration:

```zig
// Test features working together
test "features integrate" {
    features.auth.authenticate(...);
    const user = features.auth.getCurrentUser();
    const invoice = features.billing.Invoice{ .customer = user.username, ... };
    features.analytics.track(...);
}
```

### Refactoring to Namespace Pattern

Start with separate imports:

```zig
// Before: Multiple imports
const auth = @import("auth.zig");
const billing = @import("billing.zig");
const analytics = @import("analytics.zig");
```

Refactor to namespace:

```zig
// After: Single namespace import
const features = @import("features.zig");

// Access through namespace
features.auth.authenticate(...);
features.billing.calculateTotal(...);
features.analytics.track(...);
```

Create the aggregator:

```zig
// features.zig
pub const auth = @import("auth/auth.zig");
pub const billing = @import("billing/billing.zig");
pub const analytics = @import("analytics/analytics.zig");
```

### Common Patterns

**Simple Aggregator:**
```zig
pub const feature1 = @import("feature1/feature1.zig");
pub const feature2 = @import("feature2/feature2.zig");
```

**Selective Export:**
```zig
const internal = @import("internal/internal.zig");
pub const PublicAPI = internal.PublicType;
// Don't export internal.PrivateType
```

**Nested Namespaces:**
```zig
pub const core = struct {
    pub const auth = @import("core/auth.zig");
    pub const config = @import("core/config.zig");
};

pub const plugins = struct {
    pub const billing = @import("plugins/billing.zig");
    pub const analytics = @import("plugins/analytics.zig");
};
```

### Directory Naming Conventions

Use consistent naming:

```
features/
├── auth/ (feature name)
│   └── auth.zig (feature name + .zig)
├── billing/
│   └── billing.zig
└── analytics/
    └── analytics.zig
```

This makes the structure predictable and easy to navigate.

### Documentation Strategy

Document at the namespace level:

```zig
//! Features namespace
//!
//! This module provides access to all application features:
//! - auth: User authentication and authorization
//! - billing: Invoice generation and payment processing
//! - analytics: Event tracking and analytics

pub const auth = @import("auth/auth.zig");
pub const billing = @import("billing/billing.zig");
pub const analytics = @import("analytics/analytics.zig");
```

Document each feature:

```zig
//! Authentication feature
//!
//! Provides user authentication, session management, and access control.
//!
//! WARNING: This implementation uses global state for demonstration.
//! Production code should use explicit context structs.

pub const User = struct { ... };
```

### Performance Considerations

The namespace pattern has minimal overhead:

- **Compile time:** No impact - imports are resolved at compile time
- **Runtime:** Zero overhead - just namespace organization
- **Code size:** No increase - no additional indirection

The pattern is purely organizational with no performance cost.

### Migration Path

Migrate incrementally:

**Step 1:** Create aggregator
```zig
// features.zig
pub const auth = @import("auth.zig");
```

**Step 2:** Update imports
```zig
// Old: const auth = @import("auth.zig");
// New: const features = @import("features.zig");
```

**Step 3:** Move features to directories
```
auth.zig → auth/auth.zig
```

**Step 4:** Update aggregator paths
```zig
pub const auth = @import("auth/auth.zig");
```

Each step is independent and testable.

## See Also

- Recipe 10.1: Making a hierarchical package of modules
- Recipe 10.3: Importing package submodules using relative names
- Recipe 10.4: Splitting a module into multiple files

Full compilable example: `code/03-advanced/10-modules-build-system/recipe_10_5.zig`
