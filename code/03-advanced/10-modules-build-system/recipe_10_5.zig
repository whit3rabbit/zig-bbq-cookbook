// Recipe 10.5: Making Separate Directories of Code Import Under a Common Namespace
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to organize separate feature directories
// under a common namespace using a namespace aggregator module.
//
// Package structure:
// recipe_10_5.zig (root test file)
// └── recipe_10_5/
//     ├── features.zig (namespace aggregator)
//     ├── auth/ (authentication feature)
//     │   ├── auth.zig
//     │   └── auth/login.zig
//     ├── billing/ (billing feature)
//     │   ├── billing.zig
//     │   └── billing/invoice.zig
//     └── analytics/ (analytics feature)
//         ├── analytics.zig
//         └── analytics/tracking.zig

const std = @import("std");
const testing = std.testing;

// ANCHOR: import_namespace
// Import the namespace aggregator
const features = @import("recipe_10_5/features.zig");
// ANCHOR_END: import_namespace

// ANCHOR: accessing_features
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
// ANCHOR_END: accessing_features

// ANCHOR: auth_feature
test "auth feature" {
    // Authentication through namespace
    try testing.expect(features.auth.authenticate("alice", "password123"));
    try testing.expect(!features.auth.authenticate("alice", "wrong"));

    const user = features.auth.getCurrentUser();
    try testing.expectEqualStrings("alice", user.username);

    features.auth.logout();
    try testing.expect(!features.auth.isLoggedIn());
}
// ANCHOR_END: auth_feature

// ANCHOR: billing_feature
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
// ANCHOR_END: billing_feature

// ANCHOR: analytics_feature
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
// ANCHOR_END: analytics_feature

// ANCHOR: cross_feature_usage
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
// ANCHOR_END: cross_feature_usage

// ANCHOR: namespace_benefits
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
// ANCHOR_END: namespace_benefits

// ANCHOR: feature_modules
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
// ANCHOR_END: feature_modules

// ANCHOR: namespace_organization
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
// ANCHOR_END: namespace_organization

// ANCHOR: adding_features
test "adding new features is easy" {
    // To add a new feature:
    // 1. Create a new directory: features/newfeature/
    // 2. Create newfeature.zig with public API
    // 3. Add to features.zig: pub const newfeature = @import("newfeature/newfeature.zig");
    // 4. Use it: features.newfeature.doSomething()

    // The namespace pattern makes feature addition straightforward
    try testing.expect(true);
}
// ANCHOR_END: adding_features

// ANCHOR: feature_isolation
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
// ANCHOR_END: feature_isolation

// Comprehensive test
test "comprehensive namespace usage" {
    // Authenticate
    try testing.expect(features.auth.authenticate("alice", "secret"));
    const user = features.auth.getCurrentUser();
    try testing.expectEqual(@as(u32, 1), user.id);

    // Create invoice
    const invoice = features.billing.Invoice{
        .id = 100,
        .customer = user.username,
        .amount = 250.00,
    };
    const total = features.billing.calculateTotal(&invoice, 0.15);
    try testing.expectApproxEqAbs(@as(f64, 287.50), total, 0.01);

    // Track events
    features.analytics.reset();
    features.analytics.track(.{
        .name = "login",
        .user_id = user.id,
        .timestamp = 1000,
    });
    features.analytics.track(.{
        .name = "invoice_created",
        .user_id = user.id,
        .timestamp = 1001,
    });

    try testing.expectEqual(@as(usize, 2), features.analytics.getEventCount());

    // Logout
    features.auth.logout();
    try testing.expect(!features.auth.isLoggedIn());
}
