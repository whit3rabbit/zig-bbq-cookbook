// Features namespace aggregator
// This module provides a common namespace for all features

const std = @import("std");

// ANCHOR: namespace_aggregator
// Import each feature directory's main module
pub const auth = @import("auth/auth.zig");
pub const billing = @import("billing/billing.zig");
pub const analytics = @import("analytics/analytics.zig");
// ANCHOR_END: namespace_aggregator

// ANCHOR: namespace_structure
// The namespace structure looks like:
// features
// ├── auth (authentication feature)
// ├── billing (billing feature)
// └── analytics (analytics feature)
//
// Usage:
// features.auth.authenticate(...)
// features.billing.createInvoice(...)
// features.analytics.track(...)
// ANCHOR_END: namespace_structure
