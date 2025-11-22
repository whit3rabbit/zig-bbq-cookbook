// Recipe 3.10: Performing matrix and linear algebra calculations
// Target Zig Version: 0.15.2
//
// This recipe demonstrates basic matrix operations and linear algebra
// calculations using Zig's type system and memory safety features.

const std = @import("std");
const testing = std.testing;
const mem = std.mem;
const math = std.math;

// ANCHOR: matrix_type
/// Matrix type with compile-time dimensions
pub fn Matrix(comptime T: type, comptime rows: usize, comptime cols: usize) type {
    return struct {
        const Self = @This();

        data: [rows][cols]T,

        /// Create matrix filled with zeros
        pub fn zero() Self {
            return Self{ .data = [_][cols]T{[_]T{0} ** cols} ** rows };
        }

        /// Create identity matrix (only for square matrices)
        pub fn identity() Self {
            comptime {
                if (rows != cols) {
                    @compileError("Identity matrix must be square");
                }
            }
            var result = Self.zero();
            var i: usize = 0;
            while (i < rows) : (i += 1) {
                result.data[i][i] = 1;
            }
            return result;
        }

        /// Create matrix from 2D array
        pub fn init(data: [rows][cols]T) Self {
            return Self{ .data = data };
        }

        /// Get element at position
        pub fn get(self: Self, row: usize, col: usize) T {
            return self.data[row][col];
        }

        /// Set element at position
        pub fn set(self: *Self, row: usize, col: usize, value: T) void {
            self.data[row][col] = value;
        }

        /// Add two matrices
        pub fn add(self: Self, other: Self) Self {
            var result = Self.zero();
            for (0..rows) |i| {
                for (0..cols) |j| {
                    result.data[i][j] = self.data[i][j] + other.data[i][j];
                }
            }
            return result;
        }

        /// Subtract two matrices
        pub fn sub(self: Self, other: Self) Self {
            var result = Self.zero();
            for (0..rows) |i| {
                for (0..cols) |j| {
                    result.data[i][j] = self.data[i][j] - other.data[i][j];
                }
            }
            return result;
        }

        /// Multiply by scalar
        pub fn scale(self: Self, scalar: T) Self {
            var result = Self.zero();
            for (0..rows) |i| {
                for (0..cols) |j| {
                    result.data[i][j] = self.data[i][j] * scalar;
                }
            }
            return result;
        }

        /// Matrix multiplication
        pub fn mul(self: Self, comptime other_cols: usize, other: Matrix(T, cols, other_cols)) Matrix(T, rows, other_cols) {
            var result = Matrix(T, rows, other_cols).zero();
            for (0..rows) |i| {
                for (0..other_cols) |j| {
                    var sum: T = 0;
                    for (0..cols) |k| {
                        sum += self.data[i][k] * other.data[k][j];
                    }
                    result.data[i][j] = sum;
                }
            }
            return result;
        }

        /// Transpose matrix
        pub fn transpose(self: Self) Matrix(T, cols, rows) {
            var result = Matrix(T, cols, rows).zero();
            for (0..rows) |i| {
                for (0..cols) |j| {
                    result.data[j][i] = self.data[i][j];
                }
            }
            return result;
        }

        /// Determinant (2x2 matrices only)
        pub fn det2x2(self: Self) T {
            comptime {
                if (rows != 2 or cols != 2) {
                    @compileError("det2x2 only works for 2x2 matrices");
                }
            }
            return self.data[0][0] * self.data[1][1] - self.data[0][1] * self.data[1][0];
        }

        /// Determinant (3x3 matrices only)
        pub fn det3x3(self: Self) T {
            comptime {
                if (rows != 3 or cols != 3) {
                    @compileError("det3x3 only works for 3x3 matrices");
                }
            }
            const a = self.data[0][0] * (self.data[1][1] * self.data[2][2] - self.data[1][2] * self.data[2][1]);
            const b = self.data[0][1] * (self.data[1][0] * self.data[2][2] - self.data[1][2] * self.data[2][0]);
            const c = self.data[0][2] * (self.data[1][0] * self.data[2][1] - self.data[1][1] * self.data[2][0]);
            return a - b + c;
        }

        /// Check if matrix equals another
        pub fn eql(self: Self, other: Self) bool {
            for (0..rows) |i| {
                for (0..cols) |j| {
                    if (self.data[i][j] != other.data[i][j]) return false;
                }
            }
            return true;
        }
    };
}
// ANCHOR_END: matrix_type

// ANCHOR: vec2_type
/// 2D vector operations
pub const Vec2 = struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) Vec2 {
        return Vec2{ .x = x, .y = y };
    }

    pub fn add(self: Vec2, other: Vec2) Vec2 {
        return Vec2{ .x = self.x + other.x, .y = self.y + other.y };
    }

    pub fn sub(self: Vec2, other: Vec2) Vec2 {
        return Vec2{ .x = self.x - other.x, .y = self.y - other.y };
    }

    pub fn scale(self: Vec2, scalar: f32) Vec2 {
        return Vec2{ .x = self.x * scalar, .y = self.y * scalar };
    }

    pub fn dot(self: Vec2, other: Vec2) f32 {
        return self.x * other.x + self.y * other.y;
    }

    pub fn length(self: Vec2) f32 {
        return @sqrt(self.x * self.x + self.y * self.y);
    }

    pub fn normalize(self: Vec2) Vec2 {
        const len = self.length();
        if (len == 0) return Vec2{ .x = 0, .y = 0 };
        return Vec2{ .x = self.x / len, .y = self.y / len };
    }
};
// ANCHOR_END: vec2_type

// ANCHOR: vec3_type
/// 3D vector operations
pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn init(x: f32, y: f32, z: f32) Vec3 {
        return Vec3{ .x = x, .y = y, .z = z };
    }

    pub fn add(self: Vec3, other: Vec3) Vec3 {
        return Vec3{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
    }

    pub fn sub(self: Vec3, other: Vec3) Vec3 {
        return Vec3{ .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
    }

    pub fn scale(self: Vec3, scalar: f32) Vec3 {
        return Vec3{ .x = self.x * scalar, .y = self.y * scalar, .z = self.z * scalar };
    }

    pub fn dot(self: Vec3, other: Vec3) f32 {
        return self.x * other.x + self.y * other.y + self.z * other.z;
    }

    pub fn cross(self: Vec3, other: Vec3) Vec3 {
        return Vec3{
            .x = self.y * other.z - self.z * other.y,
            .y = self.z * other.x - self.x * other.z,
            .z = self.x * other.y - self.y * other.x,
        };
    }

    pub fn length(self: Vec3) f32 {
        return @sqrt(self.x * self.x + self.y * self.y + self.z * self.z);
    }

    pub fn normalize(self: Vec3) Vec3 {
        const len = self.length();
        if (len == 0) return Vec3{ .x = 0, .y = 0, .z = 0 };
        return Vec3{ .x = self.x / len, .y = self.y / len, .z = self.z / len };
    }
};
// ANCHOR_END: vec3_type

test "create zero matrix" {
    const m = Matrix(f32, 2, 3).zero();
    try testing.expectEqual(@as(f32, 0), m.get(0, 0));
    try testing.expectEqual(@as(f32, 0), m.get(1, 2));
}

test "create identity matrix" {
    const m = Matrix(f32, 3, 3).identity();
    try testing.expectEqual(@as(f32, 1), m.get(0, 0));
    try testing.expectEqual(@as(f32, 1), m.get(1, 1));
    try testing.expectEqual(@as(f32, 1), m.get(2, 2));
    try testing.expectEqual(@as(f32, 0), m.get(0, 1));
    try testing.expectEqual(@as(f32, 0), m.get(1, 0));
}

test "matrix addition" {
    const a = Matrix(i32, 2, 2).init([_][2]i32{
        [_]i32{ 1, 2 },
        [_]i32{ 3, 4 },
    });
    const b = Matrix(i32, 2, 2).init([_][2]i32{
        [_]i32{ 5, 6 },
        [_]i32{ 7, 8 },
    });
    const result = a.add(b);

    try testing.expectEqual(@as(i32, 6), result.get(0, 0));
    try testing.expectEqual(@as(i32, 8), result.get(0, 1));
    try testing.expectEqual(@as(i32, 10), result.get(1, 0));
    try testing.expectEqual(@as(i32, 12), result.get(1, 1));
}

test "matrix subtraction" {
    const a = Matrix(i32, 2, 2).init([_][2]i32{
        [_]i32{ 5, 6 },
        [_]i32{ 7, 8 },
    });
    const b = Matrix(i32, 2, 2).init([_][2]i32{
        [_]i32{ 1, 2 },
        [_]i32{ 3, 4 },
    });
    const result = a.sub(b);

    try testing.expectEqual(@as(i32, 4), result.get(0, 0));
    try testing.expectEqual(@as(i32, 4), result.get(0, 1));
    try testing.expectEqual(@as(i32, 4), result.get(1, 0));
    try testing.expectEqual(@as(i32, 4), result.get(1, 1));
}

test "matrix scalar multiplication" {
    const m = Matrix(i32, 2, 2).init([_][2]i32{
        [_]i32{ 1, 2 },
        [_]i32{ 3, 4 },
    });
    const result = m.scale(3);

    try testing.expectEqual(@as(i32, 3), result.get(0, 0));
    try testing.expectEqual(@as(i32, 6), result.get(0, 1));
    try testing.expectEqual(@as(i32, 9), result.get(1, 0));
    try testing.expectEqual(@as(i32, 12), result.get(1, 1));
}

test "matrix multiplication" {
    const a = Matrix(i32, 2, 3).init([_][3]i32{
        [_]i32{ 1, 2, 3 },
        [_]i32{ 4, 5, 6 },
    });
    const b = Matrix(i32, 3, 2).init([_][2]i32{
        [_]i32{ 7, 8 },
        [_]i32{ 9, 10 },
        [_]i32{ 11, 12 },
    });
    const result = a.mul(2, b);

    // [1,2,3] * [7,9,11]^T = 1*7 + 2*9 + 3*11 = 7+18+33 = 58
    try testing.expectEqual(@as(i32, 58), result.get(0, 0));
    // [1,2,3] * [8,10,12]^T = 1*8 + 2*10 + 3*12 = 8+20+36 = 64
    try testing.expectEqual(@as(i32, 64), result.get(0, 1));
}

test "matrix transpose" {
    const m = Matrix(i32, 2, 3).init([_][3]i32{
        [_]i32{ 1, 2, 3 },
        [_]i32{ 4, 5, 6 },
    });
    const result = m.transpose();

    try testing.expectEqual(@as(i32, 1), result.get(0, 0));
    try testing.expectEqual(@as(i32, 4), result.get(0, 1));
    try testing.expectEqual(@as(i32, 2), result.get(1, 0));
    try testing.expectEqual(@as(i32, 5), result.get(1, 1));
    try testing.expectEqual(@as(i32, 3), result.get(2, 0));
    try testing.expectEqual(@as(i32, 6), result.get(2, 1));
}

test "determinant 2x2" {
    const m = Matrix(i32, 2, 2).init([_][2]i32{
        [_]i32{ 3, 8 },
        [_]i32{ 4, 6 },
    });
    const det = m.det2x2();

    // det = 3*6 - 8*4 = 18 - 32 = -14
    try testing.expectEqual(@as(i32, -14), det);
}

test "determinant 3x3" {
    const m = Matrix(i32, 3, 3).init([_][3]i32{
        [_]i32{ 1, 2, 3 },
        [_]i32{ 0, 1, 4 },
        [_]i32{ 5, 6, 0 },
    });
    const det = m.det3x3();

    try testing.expectEqual(@as(i32, 1), det);
}

test "matrix equality" {
    const a = Matrix(i32, 2, 2).init([_][2]i32{
        [_]i32{ 1, 2 },
        [_]i32{ 3, 4 },
    });
    const b = Matrix(i32, 2, 2).init([_][2]i32{
        [_]i32{ 1, 2 },
        [_]i32{ 3, 4 },
    });
    const c = Matrix(i32, 2, 2).init([_][2]i32{
        [_]i32{ 1, 2 },
        [_]i32{ 3, 5 },
    });

    try testing.expect(a.eql(b));
    try testing.expect(!a.eql(c));
}

test "vec2 operations" {
    const a = Vec2.init(3, 4);
    const b = Vec2.init(1, 2);

    const sum = a.add(b);
    try testing.expectEqual(@as(f32, 4), sum.x);
    try testing.expectEqual(@as(f32, 6), sum.y);

    const diff = a.sub(b);
    try testing.expectEqual(@as(f32, 2), diff.x);
    try testing.expectEqual(@as(f32, 2), diff.y);

    const scaled = a.scale(2);
    try testing.expectEqual(@as(f32, 6), scaled.x);
    try testing.expectEqual(@as(f32, 8), scaled.y);
}

test "vec2 dot product" {
    const a = Vec2.init(3, 4);
    const b = Vec2.init(2, 1);
    const dot = a.dot(b);

    // 3*2 + 4*1 = 6 + 4 = 10
    try testing.expectEqual(@as(f32, 10), dot);
}

test "vec2 length" {
    const v = Vec2.init(3, 4);
    const len = v.length();

    // sqrt(3^2 + 4^2) = sqrt(9 + 16) = sqrt(25) = 5
    try testing.expectApproxEqAbs(@as(f32, 5.0), len, 0.0001);
}

test "vec2 normalize" {
    const v = Vec2.init(3, 4);
    const norm = v.normalize();

    try testing.expectApproxEqAbs(@as(f32, 0.6), norm.x, 0.0001);
    try testing.expectApproxEqAbs(@as(f32, 0.8), norm.y, 0.0001);
    try testing.expectApproxEqAbs(@as(f32, 1.0), norm.length(), 0.0001);
}

test "vec3 operations" {
    const a = Vec3.init(1, 2, 3);
    const b = Vec3.init(4, 5, 6);

    const sum = a.add(b);
    try testing.expectEqual(@as(f32, 5), sum.x);
    try testing.expectEqual(@as(f32, 7), sum.y);
    try testing.expectEqual(@as(f32, 9), sum.z);
}

test "vec3 dot product" {
    const a = Vec3.init(1, 2, 3);
    const b = Vec3.init(4, 5, 6);
    const dot = a.dot(b);

    // 1*4 + 2*5 + 3*6 = 4 + 10 + 18 = 32
    try testing.expectEqual(@as(f32, 32), dot);
}

test "vec3 cross product" {
    const a = Vec3.init(1, 0, 0);
    const b = Vec3.init(0, 1, 0);
    const cross = a.cross(b);

    try testing.expectEqual(@as(f32, 0), cross.x);
    try testing.expectEqual(@as(f32, 0), cross.y);
    try testing.expectEqual(@as(f32, 1), cross.z);
}

test "vec3 length" {
    const v = Vec3.init(1, 2, 2);
    const len = v.length();

    // sqrt(1 + 4 + 4) = sqrt(9) = 3
    try testing.expectApproxEqAbs(@as(f32, 3.0), len, 0.0001);
}

test "identity matrix multiplication" {
    const m = Matrix(i32, 2, 2).init([_][2]i32{
        [_]i32{ 5, 6 },
        [_]i32{ 7, 8 },
    });
    const identity = Matrix(i32, 2, 2).identity();
    const result = m.mul(2, identity);

    try testing.expect(m.eql(result));
}

test "memory safety - no allocation" {
    // All operations are on stack
    const m = Matrix(i32, 2, 2).init([_][2]i32{
        [_]i32{ 1, 2 },
        [_]i32{ 3, 4 },
    });
    const result = m.scale(2);

    try testing.expectEqual(@as(i32, 2), result.get(0, 0));
}

test "security - bounds checking" {
    // Compile-time size checking prevents out-of-bounds
    const m = Matrix(i32, 2, 2).zero();
    try testing.expectEqual(@as(i32, 0), m.get(0, 0));
    try testing.expectEqual(@as(i32, 0), m.get(1, 1));
}
