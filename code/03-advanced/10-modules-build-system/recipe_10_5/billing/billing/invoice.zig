// Invoice calculation logic
const std = @import("std");

// ANCHOR: apply_tax
pub fn applyTax(amount: f64, tax_rate: f64) f64 {
    return amount * (1.0 + tax_rate);
}
// ANCHOR_END: apply_tax
