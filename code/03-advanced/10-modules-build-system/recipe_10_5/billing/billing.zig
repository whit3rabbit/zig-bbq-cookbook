// Billing feature module
const std = @import("std");
const invoice_mod = @import("billing/invoice.zig");

// ANCHOR: billing_types
pub const Invoice = struct {
    id: u32,
    customer: []const u8,
    amount: f64,
};
// ANCHOR_END: billing_types

// ANCHOR: calculate_total
pub fn calculateTotal(invoice: *const Invoice, tax_rate: f64) f64 {
    return invoice_mod.applyTax(invoice.amount, tax_rate);
}
// ANCHOR_END: calculate_total
