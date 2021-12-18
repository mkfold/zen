const math = @import("std").math;

const sin = math.sin;
const cos = math.cos;
const tan = math.tan;
const sqrt = math.sqrt;
const abs = math.absFloat;

//! TODO: comprehensive tests
//!       simd support

pub const real = f32;

const rads_per_degree: comptime real = math.pi / 180.;
const degrees_per_rad: comptime real = 180. / math.pi;

//! vector types

pub const Vec2 = struct {
    x: real,
    y: real,

    pub fn add(l: Vec2, r: Vec2) Vec2 {
        return Vec2{ .x = l.x + r.x, .y = l.y + r.y };
    }

    pub fn sub(l: Vec2, r: Vec2) Vec2 {
        return Vec2{ .x = l.x - r.x, .y = l.y - r.y };
    }

    pub fn mul(l: Vec2, r: Vec2) Vec2 {
        return Vec2{ .x = l.x * r.x, .y = l.y * r.y };
    }

    pub fn div(l: Vec2, r: Vec2) Vec2 {
        return Vec2{ .x = l.x / r.x, .y = l.y / r.y };
    }

    pub fn dot(l: Vec2, r: Vec2) real {
        return (l.x * r.x) + (l.y * r.y);
    }

    pub fn zero() comptime Vec2 {
        return Vec2{ .x = 0, .y = 0 };
    }

    pub fn one() comptime Vec2 {
        return Vec2{ .x = 1, .y = 1 };
    }
};

pub const Vec3 = struct {
    x: real,
    y: real,
    z: real,

    pub fn add(l: Vec3, r: Vec3) Vec3 {
        return Vec3{ .x = l.x + r.x, .y = l.y + r.y, .z = l.z + r.z };
    }

    pub fn sub(l: Vec3, r: Vec3) Vec3 {
        return Vec3{ .x = l.x - r.x, .y = l.y - r.y, .z = l.z - r.z };
    }

    pub fn mul(l: Vec3, r: Vec3) Vec3 {
        return Vec3{ .x = l.x * r.x, .y = l.y * r.y, .z = l.z * r.z };
    }

    pub fn div(l: Vec3, r: Vec3) Vec3 {
        return Vec3{ .x = l.x / r.x, .y = l.y / r.y, .z = l.z / r.z };
    }

    pub fn magnitude(v: Vec3) real {
        return sqrt(dot(v, v));
    }

    pub fn normalize(v: Vec3) Vec3 {
        const m = magnitude(v);
        return Vec3{ .x = v.x / m, .y = v.y / m, .z = v.z / m };
    }

    pub fn dot(l: Vec3, r: Vec3) real {
        return (l.x * r.x) + (l.y * r.y) + (l.z * r.z);
    }

    pub fn cross(l: Vec3, r: Vec3) Vec3 {
        return Vec3{
            .x = l.y * r.z - l.z * r.y,
            .y = l.z * r.x - l.x * r.z,
            .z = l.x * r.y - l.y * r.x,
        };
    }

    pub fn zero() comptime Vec3 {
        return Vec3{ .x = 0, .y = 0, .z = 0 };
    }

    pub fn one() comptime Vec3 {
        return Vec3{ .x = 1, .y = 1, .z = 1 };
    }
};

pub const Vec4 = struct {
    x: real,
    y: real,
    z: real,
    w: real,

    pub fn add(l: Vec4, r: Vec4) Vec4 {
        return Vec4{ .x = l.x + r.x, .y = l.y + r.y, .z = l.z + r.z, .w = l.w + r.w };
    }

    pub fn sub(l: Vec4, r: Vec4) Vec4 {
        return Vec4{ .x = l.x - r.x, .y = l.y - r.y, .z = l.z - r.z, .w = l.w - r.w };
    }

    pub fn mul(l: Vec4, r: Vec4) Vec4 {
        return Vec4{ .x = l.x * r.x, .y = l.y * r.y, .z = l.z * r.z, .w = l.w * r.w };
    }

    pub fn div(l: Vec4, r: Vec4) Vec4 {
        return Vec4{ .x = l.x / r.x, .y = l.y / r.y, .z = l.z / r.z, .w = l.w / r.w };
    }

    pub fn dot(l: Vec4, r: Vec4) real {
        return (l.x * r.x) + (l.y * r.y) + (l.z * r.z) + (l.w * r.w);
    }

    pub fn magnitude(v: Vec4) real {
        return sqrt(dot(v, v));
    }

    pub fn normalize(v: Vec4) Vec4 {
        const m = magnitude(v);
        return Vec4{ .x = v.x / m, .y = v.y / m, .z = v.z / m, .w = v.w / m };
    }

    pub fn zero() comptime Vec4 {
        return Vec4{ .x = 0, .y = 0, .z = 0, .w = 0 };
    }

    pub fn one() comptime Vec4 {
        return Vec4{ .x = 1, .y = 1, .z = 1, .w = 1 };
    }
};

//! matrix types

// zig fmt: off

/// 2x2 matrix
pub const Mat2x2 = struct {
    mat: [2][2]real,

    pub fn add(l: Mat2x2, r: Mat2x2) Mat2x2 {
        return Mat2x2{
            .mat = [2][2]real{
                [2]real{ l.mat[0][0] + r.mat[0][0], l.mat[0][1] + r.mat[0][1], },
                [2]real{ l.mat[1][0] + r.mat[1][0], l.mat[1][1] + r.mat[1][1], },
            },
        };
    }

    pub fn sub(l: Mat2x2, r: Mat2x2) Mat2x2 {
        return Mat2x2{
            .mat = [2][2]real{
                [2]real{ l.mat[0][0] - r.mat[0][0], l.mat[0][1] - r.mat[0][1], },
                [2]real{ l.mat[1][0] - r.mat[1][0], l.mat[1][1] - r.mat[1][1], },
            },
        };
    }

    pub fn mul_pointwise(l: Mat2x2, r: Mat2x2) Mat2x2 {
        return Mat2x2{
            .mat = [2][2]real{
                [2]real{ l.mat[0][0] * r.mat[0][0], l.mat[0][1] * r.mat[0][1], },
                [2]real{ l.mat[1][0] * r.mat[1][0], l.mat[1][1] * r.mat[1][1], },
            },
        };
    }

    pub fn div(l: Mat2x2, r: Mat2x2) Mat2x2 {
        return Mat2x2{
            .mat = [2][2]real{
                [2]real{ l.mat[0][0] / r.mat[0][0], l.mat[0][1] / r.mat[0][1], },
                [2]real{ l.mat[1][0] / r.mat[1][0], l.mat[1][1] / r.mat[1][1], },
            },
        };
    }

    pub fn mul(l: Mat2x2, r: Mat2x2) Mat2x2 {
        return Mat2x2{
            .mat = [2][2]real{
                [2]real{
                    l.mat[0][0] * r.mat[0][0] + l.mat[0][1] * r.mat[1][0],
                    l.mat[0][0] * r.mat[0][1] + l.mat[0][1] * r.mat[1][1],
                },
                [2]real{
                    l.mat[1][0] * r.mat[0][0] + l.mat[1][1] * r.mat[1][0],
                    l.mat[1][0] * r.mat[0][1] + l.mat[1][1] * r.mat[1][1],
                },
            },
        };
    }

    pub fn zero() Mat2x2 {
        return Mat2x2{
            .mat = [2][2]real{
                [2]real{ 0, 0 },
                [2]real{ 0, 0 },
            },
        };
    }

    pub fn ident() Mat2x2 {
        return Mat2x2{
            .mat = [2][2]real{
                [2]real{ 1, 0 },
                [2]real{ 0, 1 },
            },
        };
    }

    pub fn rotate(theta: real) Mat2x2 {
        const c: real = cos(theta * rads_per_degree);
        const s: real = sin(theta * rads_per_degree);
        return Mat2x2{
            .mat = [2][2]real{
                [2]real{ c, s },
                [2]real{ -s, c },
            },
        };
    }
};

/// 3x3 matrix
pub const Mat3x3 = struct {
    mat: [3][3]real,

    pub fn add(l: Mat3x3, r: Mat3x3) Mat3x3 {
        return Mat3x3{
            .mat = [3][3]real{
                [3]real{ l.mat[0][0] + r.mat[0][0], l.mat[0][1] + r.mat[0][1], l.mat[0][2] + r.mat[0][2], },
                [3]real{ l.mat[1][0] + r.mat[1][0], l.mat[1][1] + r.mat[1][1], l.mat[1][2] + r.mat[1][2], },
                [3]real{ l.mat[2][0] + r.mat[2][0], l.mat[2][1] + r.mat[2][1], l.mat[2][2] + r.mat[2][2], },
            },
        };
    }

    pub fn sub(l: Mat3x3, r: Mat3x3) Mat3x3 {
        return Mat3x3{
            .mat = [3][3]real{
                [3]real{ l.mat[0][0] - r.mat[0][0], l.mat[0][1] - r.mat[0][1], l.mat[0][2] - r.mat[0][2], },
                [3]real{ l.mat[1][0] - r.mat[1][0], l.mat[1][1] - r.mat[1][1], l.mat[1][2] - r.mat[1][2], },
                [3]real{ l.mat[2][0] - r.mat[2][0], l.mat[2][1] - r.mat[2][1], l.mat[2][2] - r.mat[2][2], },
            },
        };
    }

    pub fn mul_pointwise(l: Mat3x3, r: Mat3x3) Mat3x3 {
        return Mat3x3{
            .mat = [3][3]real{
                [3]real{ l.mat[0][0] * r.mat[0][0], l.mat[0][1] * r.mat[0][1], l.mat[0][2] * r.mat[0][2], },
                [3]real{ l.mat[1][0] * r.mat[1][0], l.mat[1][1] * r.mat[1][1], l.mat[1][2] * r.mat[1][2], },
                [3]real{ l.mat[2][0] * r.mat[2][0], l.mat[2][1] * r.mat[2][1], l.mat[2][2] * r.mat[2][2], },
            },
        };
    }

    pub fn div(l: Mat3x3, r: Mat3x3) Mat3x3 {
        return Mat3x3{
            .mat = [3][3]real{
                [3]real{ l.mat[0][0] / r.mat[0][0], l.mat[0][1] / r.mat[0][1], l.mat[0][2] / r.mat[0][2], },
                [3]real{ l.mat[1][0] / r.mat[1][0], l.mat[1][1] / r.mat[1][1], l.mat[1][2] / r.mat[1][2], },
                [3]real{ l.mat[2][0] / r.mat[2][0], l.mat[2][1] / r.mat[2][1], l.mat[2][2] / r.mat[2][2], },
            },
        };
    }

    pub fn matmul(l: Mat3x3, r: Mat3x3) Mat3x3 {
        return Mat3x3{
            .mat = [3][3]real{
                [3]real{
                    l.mat[0][0] * r.mat[0][0] + l.mat[0][1] * r.mat[1][0] + l.mat[0][2] * r.mat[2][0],
                    l.mat[0][0] * r.mat[0][1] + l.mat[0][1] * r.mat[1][1] + l.mat[0][2] * r.mat[2][1],
                    l.mat[0][0] * r.mat[0][2] + l.mat[0][1] * r.mat[1][2] + l.mat[0][2] * r.mat[2][2],
                },
                [3]real{
                    l.mat[1][0] * r.mat[0][0] + l.mat[1][1] * r.mat[1][0] + l.mat[1][2] * r.mat[2][0],
                    l.mat[1][0] * r.mat[0][1] + l.mat[1][1] * r.mat[1][1] + l.mat[1][2] * r.mat[2][1],
                    l.mat[1][0] * r.mat[0][2] + l.mat[1][1] * r.mat[1][2] + l.mat[1][2] * r.mat[2][2],
                },
                [3]real{
                    l.mat[2][0] * r.mat[0][0] + l.mat[2][1] * r.mat[1][0] + l.mat[2][2] * r.mat[2][0],
                    l.mat[2][0] * r.mat[0][1] + l.mat[2][1] * r.mat[1][1] + l.mat[2][2] * r.mat[2][1],
                    l.mat[2][0] * r.mat[0][2] + l.mat[2][1] * r.mat[1][2] + l.mat[2][2] * r.mat[2][2],
                },
            },
        };
    }

    pub fn zero() Mat3x3 {
        return Mat3x3{
            .mat = [3][3]real{
                [3]real{ 0, 0, 0 },
                [3]real{ 0, 0, 0 },
                [3]real{ 0, 0, 0 },
            },
        };
    }

    pub fn ident() Mat3x3 {
        return Mat3x3{
            .mat = [3][3]real{
                [3]real{ 1, 0, 0 },
                [3]real{ 0, 1, 0 },
                [3]real{ 0, 0, 1 },
            },
        };
    }
};

/// 4x4 matrix
pub const Mat4x4 = struct {
    mat: [4][4]real,

    pub fn add(l: Mat4x4, r: Mat4x4) Mat4x4 {
        return Mat4x4{
            .mat = [4][4]real{
                [4]real{ l.mat[0][0] + r.mat[0][0], l.mat[0][1] + r.mat[0][1], l.mat[0][2] + r.mat[0][2], l.mat[0][3] + r.mat[0][3], },
                [4]real{ l.mat[1][0] + r.mat[1][0], l.mat[1][1] + r.mat[1][1], l.mat[1][2] + r.mat[1][2], l.mat[1][3] + r.mat[1][3], },
                [4]real{ l.mat[2][0] + r.mat[2][0], l.mat[2][1] + r.mat[2][1], l.mat[2][2] + r.mat[2][2], l.mat[2][3] + r.mat[2][3], },
                [4]real{ l.mat[3][0] + r.mat[3][0], l.mat[3][1] + r.mat[3][1], l.mat[3][2] + r.mat[3][2], l.mat[3][3] + r.mat[3][3], },
            },
        };
    }

    pub fn sub(l: Mat4x4, r: Mat4x4) Mat4x4 {
        return Mat4x4{
            .mat = [4][4]real{
                [4]real{ l.mat[0][0] - r.mat[0][0], l.mat[0][1] - r.mat[0][1], l.mat[0][2] - r.mat[0][2], l.mat[0][3] - r.mat[0][3], },
                [4]real{ l.mat[1][0] - r.mat[1][0], l.mat[1][1] - r.mat[1][1], l.mat[1][2] - r.mat[1][2], l.mat[1][3] - r.mat[1][3], },
                [4]real{ l.mat[2][0] - r.mat[2][0], l.mat[2][1] - r.mat[2][1], l.mat[2][2] - r.mat[2][2], l.mat[2][3] - r.mat[2][3], },
                [4]real{ l.mat[3][0] - r.mat[3][0], l.mat[3][1] - r.mat[3][1], l.mat[3][2] - r.mat[3][2], l.mat[3][3] - r.mat[3][3], },
            },
        };
    }

    pub fn mul_pointwise(l: Mat4x4, r: Mat4x4) Mat4x4 {
        return Mat4x4{
            .mat = [4][4]real{
                [4]real{ l.mat[0][0] * r.mat[0][0], l.mat[0][1] * r.mat[0][1], l.mat[0][2] * r.mat[0][2], l.mat[0][3] * r.mat[0][3], },
                [4]real{ l.mat[1][0] * r.mat[1][0], l.mat[1][1] * r.mat[1][1], l.mat[1][2] * r.mat[1][2], l.mat[1][3] * r.mat[1][3], },
                [4]real{ l.mat[2][0] * r.mat[2][0], l.mat[2][1] * r.mat[2][1], l.mat[2][2] * r.mat[2][2], l.mat[2][3] * r.mat[2][3], },
                [4]real{ l.mat[3][0] * r.mat[3][0], l.mat[3][1] * r.mat[3][1], l.mat[3][2] * r.mat[3][2], l.mat[3][3] * r.mat[3][3], },
            },
        };
    }

    pub fn div(l: Mat4x4, r: Mat4x4) Mat4x4 {
        return Mat4x4{
            .mat = [4][4]real{
                [4]real{ l.mat[0][0] / r.mat[0][0], l.mat[0][1] + r.mat[0][1], l.mat[0][2] + r.mat[0][2], l.mat[0][3] + r.mat[0][3], },
                [4]real{ l.mat[1][0] / r.mat[1][0], l.mat[1][1] + r.mat[1][1], l.mat[1][2] + r.mat[1][2], l.mat[1][3] + r.mat[1][3], },
                [4]real{ l.mat[2][0] / r.mat[2][0], l.mat[2][1] + r.mat[2][1], l.mat[2][2] + r.mat[2][2], l.mat[2][3] + r.mat[2][3], },
                [4]real{ l.mat[3][0] / r.mat[3][0], l.mat[3][1] + r.mat[3][1], l.mat[3][2] + r.mat[3][2], l.mat[3][3] + r.mat[3][3], },
            },
        };
    }

    pub fn mul(l: Mat4x4, r: Mat4x4) Mat4x4 {
        return Mat4x4{
            .mat = [4][4]real{
                [4]real{
                    l.mat[0][0] * r.mat[0][0] + l.mat[0][1] * r.mat[1][0] + l.mat[0][2] * r.mat[2][0] + l.mat[0][3] * r.mat[3][0],
                    l.mat[0][0] * r.mat[0][1] + l.mat[0][1] * r.mat[1][1] + l.mat[0][2] * r.mat[2][1] + l.mat[0][3] * r.mat[3][1],
                    l.mat[0][0] * r.mat[0][2] + l.mat[0][1] * r.mat[1][2] + l.mat[0][2] * r.mat[2][2] + l.mat[0][3] * r.mat[3][2],
                    l.mat[0][0] * r.mat[0][3] + l.mat[0][1] * r.mat[1][3] + l.mat[0][2] * r.mat[2][3] + l.mat[0][3] * r.mat[3][3],
                },
                [4]real{
                    l.mat[1][0] * r.mat[0][0] + l.mat[1][1] * r.mat[1][0] + l.mat[1][2] * r.mat[2][0] + l.mat[1][3] * r.mat[3][0],
                    l.mat[1][0] * r.mat[0][1] + l.mat[1][1] * r.mat[1][1] + l.mat[1][2] * r.mat[2][1] + l.mat[1][3] * r.mat[3][1],
                    l.mat[1][0] * r.mat[0][2] + l.mat[1][1] * r.mat[1][2] + l.mat[1][2] * r.mat[2][2] + l.mat[1][3] * r.mat[3][2],
                    l.mat[1][0] * r.mat[0][3] + l.mat[1][1] * r.mat[1][3] + l.mat[1][2] * r.mat[2][3] + l.mat[1][3] * r.mat[3][3],
                },
                [4]real{
                    l.mat[2][0] * r.mat[0][0] + l.mat[2][1] * r.mat[1][0] + l.mat[2][2] * r.mat[2][0] + l.mat[2][3] * r.mat[3][0],
                    l.mat[2][0] * r.mat[0][1] + l.mat[2][1] * r.mat[1][1] + l.mat[2][2] * r.mat[2][1] + l.mat[2][3] * r.mat[3][1],
                    l.mat[2][0] * r.mat[0][2] + l.mat[2][1] * r.mat[1][2] + l.mat[2][2] * r.mat[2][2] + l.mat[2][3] * r.mat[3][2],
                    l.mat[2][0] * r.mat[0][3] + l.mat[2][1] * r.mat[1][3] + l.mat[2][2] * r.mat[2][3] + l.mat[2][3] * r.mat[3][3],
                },
                [4]real{
                    l.mat[3][0] * r.mat[0][0] + l.mat[3][1] * r.mat[1][0] + l.mat[3][2] * r.mat[2][0] + l.mat[3][3] * r.mat[3][0],
                    l.mat[3][0] * r.mat[0][1] + l.mat[3][1] * r.mat[1][1] + l.mat[3][2] * r.mat[2][1] + l.mat[3][3] * r.mat[3][1],
                    l.mat[3][0] * r.mat[0][2] + l.mat[3][1] * r.mat[1][2] + l.mat[3][2] * r.mat[2][2] + l.mat[3][3] * r.mat[3][2],
                    l.mat[3][0] * r.mat[0][3] + l.mat[3][1] * r.mat[1][3] + l.mat[3][2] * r.mat[2][3] + l.mat[3][3] * r.mat[3][3],
                },
            },
        };
    }

    pub fn zero() Mat4x4 {
        return Mat4x4{
            .mat = [4][4]real{
                [4]real{ 0, 0, 0, 0 },
                [4]real{ 0, 0, 0, 0 },
                [4]real{ 0, 0, 0, 0 },
                [4]real{ 0, 0, 0, 0 },
            },
        };
    }

    pub fn ident() Mat4x4 {
        return Mat4x4{
            .mat = [4][4]real{
                [4]real{ 1, 0, 0, 0 },
                [4]real{ 0, 1, 0, 0 },
                [4]real{ 0, 0, 1, 0 },
                [4]real{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn rotate_aa(theta: real, axis: Vec3) Mat4x4 {
        const v = Vec3.normalize(axis);
        const c: real = cos(theta * rads_per_degree);
        const s: real = sin(theta * rads_per_degree);

        return Mat4x4{
            .mat = [4][4]real{
                [4]real{ c + v.x * v.x * (1 - c), -v.z * s + v.x * v.y * (1 - c), v.y * s + v.x * v.z * (1 - c), 0 },
                [4]real{ v.z * s + v.y * v.x * (1 - c), c + v.y * v.y * (1 - c), -v.x * s + v.y * v.z * (1 - c), 0 },
                [4]real{ -v.y * s + v.z * v.x * (1 - c), v.x * s + v.z * v.y * (1 - c), c + v.z * v.z * (1 - c), 0 },
                [4]real{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn rotate_euler(xt: real, yt: real, zt: real) Mat4x4 {
        const cx: real = cos(xt);
        const sx: real = sin(xt);
        const cy: real = cos(yt);
        const sy: real = sin(yt);
        const cz: real = cos(zt);
        const sz: real = sin(zt);

        return Mat4x4{
            .mat = [4][4]real{
                [4]real{ cy * cz, -cy * sz, sy, 0 },
                [4]real{ sx * sy * cz + cx * sz, -sx * sy * sz + cx * cz, -sx * cy, 0 },
                [4]real{ -cx * sy * cz + sx * sz, cx * sy * sz + sx * cz, cx * cy, 0 },
                [4]real{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn perspective(fov: real, aspect_ratio: real, near: real, far: real) Mat4x4 {
        return Mat4x4{
            .mat = [4][4]real{
                [4]real{ 1.0 / (aspect_ratio * tan(fov / 2.0)), 0, 0, 0 },
                [4]real{ 0, 1.0 / tan(fov / 2.0), 0, 0 },
                [4]real{ 0, 0, -(far + near) / (far - near), -(2.0 * far * near) / (far - near) },
                [4]real{ 0, 0, -1, 0 },
            },
        };
    }

    pub fn orthographic(top: real, bottom: real, left: real, right: real, near: real, far: real) Mat4x4 {
        return Mat4x4{
            .mat = [4][4]real{
                [4]real{ 2.0 / (right - left), 0, 0, -((right + left) / (right - left)) },
                [4]real{ 0, 2.0 / (top - bottom), 0, -((top + bottom) / (top - bottom)) },
                [4]real{ 0, 0, -2.0 / (far - near), -((far + near) / (far - near)) },
                [4]real{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn lookat(pos: Vec3, dir: Vec3, up: Vec3) Mat4x4 {
        const f = Vec3.normalize(Vec3.sub(pos, dir)); // front
        const s = Vec3.normalize(Vec3.cross(f, up)); // side
        const u = Vec3.cross(s, f); // up

        return Mat4x4{
            .mat = [4][4]real{
                [4]real{ s.x, s.y, s.z, -Vec3.dot(s, pos) },
                [4]real{ u.x, u.y, u.z, -Vec3.dot(u, pos) },
                [4]real{ -f.x, -f.y, -f.z, Vec3.dot(f, pos) },
                [4]real{ 0, 0, 0, 1 },
            },
        };
    }

    pub fn fpslook(pos: Vec3, theta: Vec3) Mat4x4 {
        var look = rotate_euler(theta.x, theta.y, theta.z);
        look.mat[3] = [4]real{ -pos.x, -pos.y, -pos.z, 1.0 };
        return look;
    }
};

pub const Mat2 = Mat2x2;
pub const Mat3 = Mat3x3;
pub const Mat4 = Mat4x4;

/// axis-aligned bounding boxes
const AABB = struct {
    pos: Vec3, // position of center of box
    dim: Vec3, // distance of each axis-aligned pair of faces from center

    /// AABB intersection test
    /// based on https://www.gamasutra.com/view/feature/131790/simple_intersection_tests_for_games.php?page=3
    pub fn intersect(a: AABB, b: AABB) bool {
        return (abs(b.pos.x - a.pos.x) <= (a.dim.x + b.dim.x)
            and abs(b.pos.y - a.pos.y) <= (a.dim.y + b.dim.y)
            and abs(b.pos.z - a.pos.z) <= (a.dim.z + b.dim.z));
    }
};

// zig fmt: on

//! tests

test "lookat" {
    const debug = @import("std").debug;
    const la = Mat4.lookat(Vec3.zero(), Vec3.one(), Vec3{ .x = 0, .y = 1, .z = 0 });
    const fpl = Mat4.fpslook(Vec3.zero(), Vec3.one());

    debug.warn("{}\n", .{la.mat});
    debug.warn("{}\n", .{fpl.mat});
}
