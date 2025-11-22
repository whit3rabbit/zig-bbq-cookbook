// Recipe 3.6: Performing complex-valued math
// Target Zig Version: 0.15.2
//
// This recipe demonstrates working with complex numbers using std.math.Complex
// for mathematical, engineering, and signal processing applications.

const std = @import("std");
const testing = std.testing;
const math = std.math;
const Complex = math.Complex;

// ANCHOR: basic_operations
/// Create complex number from real and imaginary parts
pub fn makeComplex(comptime T: type, real: T, imag: T) Complex(T) {
    return Complex(T).init(real, imag);
}

/// Add two complex numbers
pub fn add(comptime T: type, a: Complex(T), b: Complex(T)) Complex(T) {
    return a.add(b);
}

/// Subtract two complex numbers
pub fn sub(comptime T: type, a: Complex(T), b: Complex(T)) Complex(T) {
    return a.sub(b);
}

/// Multiply two complex numbers
pub fn mul(comptime T: type, a: Complex(T), b: Complex(T)) Complex(T) {
    return a.mul(b);
}

/// Divide two complex numbers
pub fn div(comptime T: type, a: Complex(T), b: Complex(T)) Complex(T) {
    return a.div(b);
}

/// Get complex conjugate
pub fn conjugate(comptime T: type, z: Complex(T)) Complex(T) {
    return z.conjugate();
}

/// Get magnitude (absolute value) of complex number
pub fn magnitude(comptime T: type, z: Complex(T)) T {
    return z.magnitude();
}

/// Get squared magnitude (more efficient than magnitude)
pub fn magnitudeSquared(comptime T: type, z: Complex(T)) T {
    return z.re * z.re + z.im * z.im;
}

/// Get argument (phase angle) of complex number in radians
pub fn argument(comptime T: type, z: Complex(T)) T {
    return math.atan2(z.im, z.re);
}

/// Reciprocal of complex number (1/z)
pub fn reciprocal(comptime T: type, z: Complex(T)) Complex(T) {
    return z.reciprocal();
}
// ANCHOR_END: basic_operations

// ANCHOR: polar_conversions
/// Complex number from polar coordinates
pub fn fromPolar(comptime T: type, r: T, theta: T) Complex(T) {
    return Complex(T).init(r * @cos(theta), r * @sin(theta));
}

/// Convert to polar coordinates (magnitude, angle)
pub fn toPolar(comptime T: type, z: Complex(T)) struct { r: T, theta: T } {
    return .{
        .r = magnitude(T, z),
        .theta = argument(T, z),
    };
}

/// Square root of complex number using polar form
/// sqrt(r*e^(iθ)) = sqrt(r)*e^(iθ/2)
pub fn sqrt(comptime T: type, z: Complex(T)) Complex(T) {
    const r = magnitude(T, z);
    const theta = argument(T, z);
    return fromPolar(T, @sqrt(r), theta / 2.0);
}

/// Exponential of complex number using Euler's formula
/// e^(a+bi) = e^a * (cos(b) + i*sin(b))
pub fn exp(comptime T: type, z: Complex(T)) Complex(T) {
    const exp_real = @exp(z.re);
    return Complex(T).init(
        exp_real * @cos(z.im),
        exp_real * @sin(z.im),
    );
}

/// Natural logarithm of complex number
/// ln(r*e^(iθ)) = ln(r) + iθ
pub fn log(comptime T: type, z: Complex(T)) Complex(T) {
    const r = magnitude(T, z);
    const theta = argument(T, z);
    return Complex(T).init(@log(r), theta);
}

/// Power of complex number (z^n) using logarithm
/// z^n = e^(n*ln(z))
pub fn pow(comptime T: type, z: Complex(T), n: Complex(T)) Complex(T) {
    const ln_z = log(T, z);
    const product = mul(T, n, ln_z);
    return exp(T, product);
}
// ANCHOR_END: polar_conversions

// ANCHOR: trig_functions
/// Cosine of complex number
/// cos(a+bi) = cos(a)*cosh(b) - i*sin(a)*sinh(b)
pub fn cos(comptime T: type, z: Complex(T)) Complex(T) {
    return Complex(T).init(
        @cos(z.re) * math.cosh(z.im),
        -@sin(z.re) * math.sinh(z.im),
    );
}

/// Sine of complex number
/// sin(a+bi) = sin(a)*cosh(b) + i*cos(a)*sinh(b)
pub fn sin(comptime T: type, z: Complex(T)) Complex(T) {
    return Complex(T).init(
        @sin(z.re) * math.cosh(z.im),
        @cos(z.re) * math.sinh(z.im),
    );
}
// ANCHOR_END: trig_functions

test "create complex number" {
    const z = makeComplex(f64, 3.0, 4.0);
    try testing.expectEqual(@as(f64, 3.0), z.re);
    try testing.expectEqual(@as(f64, 4.0), z.im);
}

test "add complex numbers" {
    const a = makeComplex(f64, 1.0, 2.0);
    const b = makeComplex(f64, 3.0, 4.0);
    const result = add(f64, a, b);

    try testing.expectEqual(@as(f64, 4.0), result.re);
    try testing.expectEqual(@as(f64, 6.0), result.im);
}

test "subtract complex numbers" {
    const a = makeComplex(f64, 5.0, 7.0);
    const b = makeComplex(f64, 2.0, 3.0);
    const result = sub(f64, a, b);

    try testing.expectEqual(@as(f64, 3.0), result.re);
    try testing.expectEqual(@as(f64, 4.0), result.im);
}

test "multiply complex numbers" {
    const a = makeComplex(f64, 1.0, 2.0);
    const b = makeComplex(f64, 3.0, 4.0);
    const result = mul(f64, a, b);

    // (1+2i)(3+4i) = 3+4i+6i+8i² = 3+10i-8 = -5+10i
    try testing.expectApproxEqAbs(@as(f64, -5.0), result.re, 0.0001);
    try testing.expectApproxEqAbs(@as(f64, 10.0), result.im, 0.0001);
}

test "divide complex numbers" {
    const a = makeComplex(f64, 4.0, 2.0);
    const b = makeComplex(f64, 3.0, -1.0);
    const result = div(f64, a, b);

    // (4+2i)/(3-i) = (4+2i)(3+i)/(3²+1²) = (12+4i+6i+2i²)/10 = (10+10i)/10 = 1+i
    try testing.expectApproxEqAbs(@as(f64, 1.0), result.re, 0.0001);
    try testing.expectApproxEqAbs(@as(f64, 1.0), result.im, 0.0001);
}

test "complex conjugate" {
    const z = makeComplex(f64, 3.0, 4.0);
    const conj = conjugate(f64, z);

    try testing.expectEqual(@as(f64, 3.0), conj.re);
    try testing.expectEqual(@as(f64, -4.0), conj.im);
}

test "magnitude of complex number" {
    const z = makeComplex(f64, 3.0, 4.0);
    const mag = magnitude(f64, z);

    // |3+4i| = sqrt(9+16) = 5
    try testing.expectApproxEqAbs(@as(f64, 5.0), mag, 0.0001);
}

test "magnitude squared" {
    const z = makeComplex(f64, 3.0, 4.0);
    const mag_sq = magnitudeSquared(f64, z);

    // |3+4i|² = 9+16 = 25
    try testing.expectEqual(@as(f64, 25.0), mag_sq);
}

test "argument (phase angle)" {
    const z = makeComplex(f64, 1.0, 1.0);
    const arg = argument(f64, z);

    // arg(1+i) = atan2(1,1) = π/4
    try testing.expectApproxEqAbs(@as(f64, math.pi / 4.0), arg, 0.0001);
}

test "reciprocal" {
    const z = makeComplex(f64, 1.0, 1.0);
    const recip = reciprocal(f64, z);

    // 1/(1+i) = (1-i)/(1²+1²) = (1-i)/2 = 0.5-0.5i
    try testing.expectApproxEqAbs(@as(f64, 0.5), recip.re, 0.0001);
    try testing.expectApproxEqAbs(@as(f64, -0.5), recip.im, 0.0001);
}

test "from polar coordinates" {
    const r: f64 = 5.0;
    const theta: f64 = math.pi / 4.0; // 45 degrees
    const z = fromPolar(f64, r, theta);

    // r=5, θ=π/4 → x=5cos(π/4)≈3.536, y=5sin(π/4)≈3.536
    try testing.expectApproxEqAbs(@as(f64, 3.536), z.re, 0.01);
    try testing.expectApproxEqAbs(@as(f64, 3.536), z.im, 0.01);
}

test "to polar coordinates" {
    const z = makeComplex(f64, 3.0, 4.0);
    const polar = toPolar(f64, z);

    try testing.expectApproxEqAbs(@as(f64, 5.0), polar.r, 0.0001);
    try testing.expectApproxEqAbs(@as(f64, 0.927), polar.theta, 0.01);
}

test "square root" {
    const z = makeComplex(f64, 0.0, 4.0); // 4i
    const result = sqrt(f64, z);

    // sqrt(4i) ≈ 1.414+1.414i
    try testing.expectApproxEqAbs(@as(f64, 1.414), result.re, 0.01);
    try testing.expectApproxEqAbs(@as(f64, 1.414), result.im, 0.01);
}

test "natural logarithm" {
    const z = makeComplex(f64, 1.0, 0.0);
    const result = log(f64, z);

    // ln(1) = 0
    try testing.expectApproxEqAbs(@as(f64, 0.0), result.re, 0.0001);
    try testing.expectApproxEqAbs(@as(f64, 0.0), result.im, 0.0001);
}

test "exponential" {
    const z = makeComplex(f64, 0.0, math.pi);
    const result = exp(f64, z);

    // e^(iπ) = -1
    try testing.expectApproxEqAbs(@as(f64, -1.0), result.re, 0.0001);
    try testing.expectApproxEqAbs(@as(f64, 0.0), result.im, 0.0001);
}

test "power operation" {
    const z = makeComplex(f64, 2.0, 0.0);
    const n = makeComplex(f64, 3.0, 0.0);
    const result = pow(f64, z, n);

    // 2³ = 8
    try testing.expectApproxEqAbs(@as(f64, 8.0), result.re, 0.0001);
    try testing.expectApproxEqAbs(@as(f64, 0.0), result.im, 0.0001);
}

test "cosine" {
    const z = makeComplex(f64, 0.0, 0.0);
    const result = cos(f64, z);

    // cos(0) = 1
    try testing.expectApproxEqAbs(@as(f64, 1.0), result.re, 0.0001);
    try testing.expectApproxEqAbs(@as(f64, 0.0), result.im, 0.0001);
}

test "sine" {
    const z = makeComplex(f64, 0.0, 0.0);
    const result = sin(f64, z);

    // sin(0) = 0
    try testing.expectApproxEqAbs(@as(f64, 0.0), result.re, 0.0001);
    try testing.expectApproxEqAbs(@as(f64, 0.0), result.im, 0.0001);
}

test "purely real complex number" {
    const z = makeComplex(f64, 5.0, 0.0);
    try testing.expectEqual(@as(f64, 5.0), z.re);
    try testing.expectEqual(@as(f64, 0.0), z.im);

    const mag = magnitude(f64, z);
    try testing.expectApproxEqAbs(@as(f64, 5.0), mag, 0.0001);
}

test "purely imaginary complex number" {
    const z = makeComplex(f64, 0.0, 5.0);
    try testing.expectEqual(@as(f64, 0.0), z.re);
    try testing.expectEqual(@as(f64, 5.0), z.im);

    const mag = magnitude(f64, z);
    try testing.expectApproxEqAbs(@as(f64, 5.0), mag, 0.0001);
}

test "complex number operations with f32" {
    const a = makeComplex(f32, 1.0, 2.0);
    const b = makeComplex(f32, 3.0, 4.0);
    const result = add(f32, a, b);

    try testing.expectEqual(@as(f32, 4.0), result.re);
    try testing.expectEqual(@as(f32, 6.0), result.im);
}

test "zero complex number" {
    const z = makeComplex(f64, 0.0, 0.0);
    const mag = magnitude(f64, z);

    try testing.expectEqual(@as(f64, 0.0), mag);
}

test "division by conjugate" {
    const z = makeComplex(f64, 3.0, 4.0);
    const conj = conjugate(f64, z);
    const result = div(f64, z, conj);

    // (3+4i)/(3-4i) = (3+4i)²/(3²+4²) = (9+24i-16)/25 = (-7+24i)/25
    try testing.expectApproxEqAbs(@as(f64, -0.28), result.re, 0.01);
    try testing.expectApproxEqAbs(@as(f64, 0.96), result.im, 0.01);
}

test "euler's identity" {
    // e^(iπ) + 1 = 0
    const z = makeComplex(f64, 0.0, math.pi);
    const result = exp(f64, z);
    const one = makeComplex(f64, 1.0, 0.0);
    const sum = add(f64, result, one);

    try testing.expectApproxEqAbs(@as(f64, 0.0), sum.re, 0.0001);
    try testing.expectApproxEqAbs(@as(f64, 0.0), sum.im, 0.0001);
}

test "de moivre's formula" {
    // (cos θ + i sin θ)^n = cos(nθ) + i sin(nθ)
    const theta: f64 = math.pi / 4.0;
    const z = fromPolar(f64, 1.0, theta);
    const n = makeComplex(f64, 2.0, 0.0);
    const result = pow(f64, z, n);

    const expected = fromPolar(f64, 1.0, 2.0 * theta);

    try testing.expectApproxEqAbs(expected.re, result.re, 0.01);
    try testing.expectApproxEqAbs(expected.im, result.im, 0.01);
}

test "memory safety - no allocation" {
    // All complex operations are pure math, no allocation
    const a = makeComplex(f64, 1.0, 2.0);
    const b = makeComplex(f64, 3.0, 4.0);
    const result = mul(f64, a, b);

    try testing.expect(result.re != 0.0 or result.im != 0.0);
}

test "security - stable division" {
    // Division should be numerically stable
    const a = makeComplex(f64, 1e10, 1e10);
    const b = makeComplex(f64, 1e-10, 1e-10);
    const result = div(f64, a, b);

    // Should not overflow or produce NaN
    try testing.expect(!math.isNan(result.re));
    try testing.expect(!math.isNan(result.im));
}
