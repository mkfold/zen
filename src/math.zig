//! TODO: comprehensive tests
//!       simd support (in progress)
//!       - better matmul implementation (whenever it's actually needed)
//!       - look at generated asm for further optimization

const std = @import("std");
const Vector = std.meta.Vector;
const math = std.math;
const sin = math.sin;
const cos = math.cos;
const tan = math.tan;
const sqrt = math.sqrt;
const abs = math.absFloat;

pub const real = f32;

const matmul_block_size: usize = sqrt(65536 / @sizeOf(real));
pub const rads_per_degree: real = math.pi / 180.0;
pub const degrees_per_rad: real = 180.0 / math.pi;
const Index = u5;

pub fn to_radians(degrees: real) real {
    return degrees * rads_per_degree;
}

pub fn to_degrees(radians: real) real {
    return radians * degrees_per_rad;
}

// "officially-supported" types
// this was designed for 3D graphics, after all ;)
pub const Vec2 = Vec(real, 2);
pub const Vec3 = Vec(real, 3);
pub const Vec4 = Vec(real, 4);

pub const Mat2 = Mat(real, 2, 2);
pub const Mat3 = Mat(real, 3, 3);
pub const Mat4 = Mat(real, 4, 4);

// vector types

pub fn Vec(comptime T: type, comptime N: Index) type {
    return struct {
        pub const Self = @This();

        pub const dtype = T;
        pub const dim = N;

        const VT = Vector(N, T);

        data: [N]T,

        pub fn add(l: Self, r: Self) Self {
            const lv: VT = l.data;
            const rv: VT = r.data;
            return Self{ .data = lv + rv };
        }

        pub fn add_(self: *Self, other: Self) void {
            self.* = self.add(other);
        }

        pub fn adds(self: Self, value: T) Self {
            const lv: VT = self.data;
            return Self{ .data = lv + @splat(N, value) };
        }

        pub fn adds_(self: *Self, value: T) void {
            self.* = self.adds(value);
        }

        pub fn sub(l: Self, r: Self) Self {
            const lv: VT = l.data;
            const rv: VT = r.data;
            return Self{ .data = lv - rv };
        }

        pub fn sub_(self: *Self, other: Self) void {
            self.* = self.sub(other);
        }

        pub fn subs(self: Self, value: T) Self {
            const lv: VT = self.data;
            return Self{ .data = lv - @splat(N, value) };
        }

        pub fn subs_(self: *Self, value: T) void {
            self.* = self.subs(value);
        }

        pub fn mul(l: Self, r: Self) Self {
            const lv: VT = l.data;
            const rv: VT = r.data;
            return Self{ .data = lv * rv };
        }

        pub fn mul_(self: *Self, other: Self) void {
            self.* = self.mul(other);
        }

        pub fn muls(self: Self, value: T) Self {
            const lv: VT = self.data;
            return Self{ .data = lv * @splat(N, value) };
        }

        pub fn muls_(self: *Self, value: T) void {
            self.* = self.muls(value);
        }

        pub fn div(l: Self, r: Self) Self {
            const lv: VT = l.data;
            const rv: VT = r.data;
            return Self{ .data = lv / rv };
        }

        pub fn div_(self: *Self, other: Self) void {
            self.* = self.div(other);
        }

        pub fn divs(self: Self, value: T) Self {
            const lv: VT = self.data;
            return Self{ .data = lv / @splat(N, value) };
        }

        pub fn divs_(self: *Self, value: T) void {
            self.* = self.divs(value);
        }

        pub fn sum(self: *Self) T {
            const data: VT = self.data;
            return @reduce(.Add, data);
        }

        pub fn product(self: *Self) T {
            const data: VT = self.data;
            return @reduce(.Mul, data);
        }

        pub fn dot(self: Self, other: Self) T {
            return self.mul(other).sum();
        }

        pub fn magnitude(self: Self) real {
            return sqrt(self.dot(self));
        }

        inline fn _norm_impl(self: Self) Vector(N, T) {
            const data: VT = self.data;
            const m = self.magnitude();
            const dor = if (m != 0.0) @splat(N, m) else @splat(N, @as(T, 1));
            return data / dor;
        }

        pub fn normalize(self: Self) Self {
            return Self{ .data = _norm_impl(self) };
        }

        pub fn normalize_(self: *Self) void {
            self.data = self._norm_impl();
        }

        pub fn expand(self: Self, value: T) Vec(T, N + 1) {
            var b: [N + 1]T = undefined;
            for (self.data) |v, i| b[i] = v;
            b[N] = value;

            return Vec(T, N + 1){ .data = b };
        }

        pub fn fill(k: T) Self {
            return Self{ .data = @splat(N, k) };
        }

        pub fn zero() Self {
            return Self.fill(@as(T, 0));
        }

        pub fn one() Self {
            return Self.fill(@as(T, 1));
        }

        pub fn format(
            value: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options; // TODO: use precision, width, alignment

            try std.fmt.format(writer, "Vec({},{})[ ", .{ T, N });
            var i: Index = 0;
            while (i < Self.dim - 1) : (i += 1) {
                if (i == 3 and Self.dim > 6) {
                    i = Self.dim - 3;
                    try std.fmt.format(writer, " ... ", .{});
                    continue;
                }
                try std.fmt.format(writer, "{:.3}, ", .{value.data[i]});
            }
            try std.fmt.format(writer, "{:.3} ]", .{value.data[i]});
        }
    };
}

pub fn cross(lhs: Vec3, rhs: Vec3) Vec3 {
    return Vec3{ .data = _cross_impl(lhs.data, rhs.data) };
}

pub fn cross_(lhs: *Vec3, rhs: Vec3) void {
    lhs.* = _cross_impl(lhs.data, rhs.data);
}

inline fn _cross_impl(v1: Vector(3, real), v2: Vector(3, real)) Vector(3, real) {
    const yzx = [_]i32{ 1, 2, 0 };
    const zxy = [_]i32{ 2, 0, 1 };
    const lhs = @shuffle(real, v1, undefined, yzx) * @shuffle(real, v2, undefined, zxy);
    const rhs = @shuffle(real, v1, undefined, zxy) * @shuffle(real, v2, undefined, yzx);
    return lhs - rhs;
}

// matrix types

pub fn Mat(comptime T: type, comptime N: Index, comptime M: Index) type {
    return struct {
        pub const Self = @This();

        pub const dtype = T;
        pub const nrows = N;
        pub const ncols = M;

        const Row = Vec(T, M);
        const Column = Vec(T, N);

        const MT = Vector(N * M, T);

        data: [N * M]T,

        pub fn add(self: Self, other: Self) Self {
            const lv: MT = self.data;
            const rv: MT = other.data;
            return Self{ .data = lv + rv };
        }

        pub fn add_(self: *Self, other: Self) void {
            self.data = self.add(other);
        }

        pub fn adds(self: Self, value: T) Self {
            const lv: MT = self.data;
            return Self{ .data = lv + @splat(N * M, value) };
        }

        pub fn adds_(self: *Self, value: T) void {
            self.* = self.adds(value);
        }

        pub fn sub(self: Self, other: Self) Self {
            const lv: MT = self.data;
            const rv: MT = other.data;
            return Self{ .data = lv - rv };
        }

        pub fn sub_(self: *Self, other: Self) void {
            self.data = self.sub(other);
        }

        pub fn subs(self: Self, value: T) Self {
            const lv: MT = self.data;
            return Self{ .data = lv - @splat(N * M, value) };
        }

        pub fn subs_(self: *Self, value: T) void {
            self.* = self.subs(value);
        }

        pub fn mul(self: Self, other: Self) Self {
            const lv: MT = self.data;
            const rv: MT = other.data;
            return Self{ .data = lv * rv };
        }

        pub fn mul_(self: *Self, other: Self) void {
            self.data = self.mul(other);
        }

        pub fn muls(self: Self, value: T) Self {
            const lv: MT = self.data;
            return Self{ .data = lv * @splat(N * M, value) };
        }

        pub fn muls_(self: *Self, value: T) void {
            self.* = self.muls(value);
        }

        pub fn div(self: Self, other: Self) Self {
            const lv: MT = self.data;
            const rv: MT = other.data;
            return Self{ .data = lv / rv };
        }

        pub fn div_(self: *Self, other: Self) void {
            self.data = self.div(other);
        }

        pub fn divs(self: Self, value: T) Self {
            const lv: MT = self.data;
            return Self{ .data = lv / @splat(N * M, value) };
        }

        pub fn divs_(self: *Self, value: T) void {
            self.* = self.muls(value);
        }

        pub fn row(self: Self, n: Index) Vec(T, M) {
            const r = self.data[n * M .. (n + 1) * M];
            return Vec(T, M){ .data = r[0..M].* };
        }

        pub fn col(self: Self, m: Index) Vec(T, N) {
            var r: [N]T = undefined;
            var i: usize = 0;
            while (i < N) : (i += 1) {
                r[i] = self.data[i * M + m];
            }
            return Vec(T, N){ .data = r };
        }

        pub fn rows(self: Self) [N]Vec(T, M) {
            var _rs: [N]Vec(T, M) = undefined;
            var i: Index = 0;
            while (i < N) : (i += 1) _rs[i] = self.row(i);
            return _rs;
        }

        pub fn cols(self: Self) [M]Vec(T, N) {
            var _cs: [M]Vec(T, N) = undefined;
            var i: Index = 0;
            while (i < M) : (i += 1) _cs[i] = self.col(i);
            return _cs;
        }

        /// TODO: this is probably really slow and likely generates a lot of code
        inline fn _matmul_impl(m1: Mat(T, N, M), m2: Mat(T, M, N)) Mat(T, N, N) {
            var c: Mat(T, N, N) = undefined;

            var m1_rows = m1.rows();
            var m2_cols = m2.cols();

            var i: Index = 0;
            while (i < N * N) : (i += 1) c.data[i] = m1_rows[i / M].dot(m2_cols[@mod(i, M)]);
            return c;
        }

        pub fn matmul(self: Self, other: Self) Self {
            return _matmul_impl(self, other);
        }

        pub fn matmul_(self: *Self, other: Self) void {
            self = _matmul_impl(self, other);
        }

        pub fn vecmul(self: Self, vec: Vec(T, M)) Vec(T, M) {
            var v = Vec(T, M).zero();
            var m1_rows = self.rows();
            for (m1_rows) |r, i| v.data[i] = r.dot(vec);
            return v;
        }

        pub fn get(self: Self, r: Index, c: Index) T {
            return self.data[(N * r) + c];
        }

        pub fn set(self: Self, val: T, r: Index, c: Index) Self {
            var m: Self = self;
            m.set_(val, r, c);
            return m;
        }

        pub fn set_(self: *Self, val: T, r: Index, c: Index) void {
            const offs = (M * r) + c;
            self.data[offs] = val;
        }

        pub fn eye() Self {
            return Self{ .data = comptime blk: {
                var data: [N * M]T = [_]T{@as(T, 0)} ** (N * M);
                var i: usize = 0;
                inline while (i < @minimum(N, M)) : (i += 1) data[(M * i) + i] = @as(T, 1);
                break :blk data;
            } };
        }

        pub fn fill(k: T) Self {
            return Self{ .data = @splat(N * M, k) };
        }

        pub fn fill_(self: *Self, k: T) void {
            self.data = @splat(N * M, k);
        }

        pub fn zero() Self {
            return Self.fill(@as(T, 0));
        }

        pub fn one() Self {
            return Self.fill(@as(T, 1));
        }

        pub fn empty() Self {
            return Self{ .data = undefined };
        }

        pub fn format(
            value: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options; // TODO: use precision, width, alignment

            try std.fmt.format(writer, "Mat({},{},{}) [ ", .{ T, N, M });
            comptime var i: Index = 0;
            inline while (i < Self.nrows) : (i += 1) {
                try std.fmt.format(writer, "[ ", .{});
                if (i == 3 and Self.nrows > 6) {
                    i = Self.nrows - 3;
                    try std.fmt.format(writer, " ... ] ", .{});
                    continue;
                }
                const r = value.row(i);
                comptime var j: Index = 0;
                inline while (j < Self.ncols - 1) : (j += 1) {
                    if (j == 3 and Self.ncols > 6) {
                        j = Self.ncols - 3;
                        try std.fmt.format(writer, " ... ", .{});
                        continue;
                    }
                    try std.fmt.format(writer, "{:.3}, ", .{r.data[j]});
                }
                const ch: u8 = if (i == Self.nrows - 1) '\x00' else ',';
                try std.fmt.format(writer, "{:.3} ]{c} ", .{ r.data[j], ch });
            }
            try std.fmt.format(writer, "]", .{});
        }
    };
}

pub fn rotate2d(theta: real) Mat2 {
    const c: real = cos(theta * rads_per_degree);
    const s: real = sin(theta * rads_per_degree);
    return Mat2{ .data = [4]real{ c, s, -s, c } };
}

pub fn rotate3d_aa(theta: real, axis: Vec3) Mat4 {
    const v = axis.normalize();
    const c: real = cos(theta * rads_per_degree);
    const s: real = sin(theta * rads_per_degree);

    return Mat4{
        .data = [16]real{
            c + v.x * v.x * (1 - c),        -v.z * s + v.x * v.y * (1 - c), v.y * s + v.x * v.z * (1 - c),  0,
            v.z * s + v.y * v.x * (1 - c),  c + v.y * v.y * (1 - c),        -v.x * s + v.y * v.z * (1 - c), 0,
            -v.y * s + v.z * v.x * (1 - c), v.x * s + v.z * v.y * (1 - c),  c + v.z * v.z * (1 - c),        0,
            0,                              0,                              0,                              1,
        },
    };
}

pub fn rotate3d_euler(xt: real, yt: real, zt: real) Mat4 {
    const cx = cos(xt);
    const sx = sin(xt);
    const cy = cos(yt);
    const sy = sin(yt);
    const cz = cos(zt);
    const sz = sin(zt);

    return Mat4{
        .data = [16]real{
            cy * cz,                 -cy * sz,                sy,       0,
            sx * sy * cz + cx * sz,  -sx * sy * sz + cx * cz, -sx * cy, 0,
            -cx * sy * cz + sx * sz, cx * sy * sz + sx * cz,  cx * cy,  0,
            0,                       0,                       0,        1,
        },
    };
}

pub fn perspective(fov: real, aspect: real, near: real, far: real) Mat4 {
    const tfov2 = tan(fov / 2.0);
    const fmn = far - near;
    return Mat4{
        .data = [16]real{
            1.0 / (aspect * tfov2), 0,           0,                   0,
            0,                      1.0 / tfov2, 0,                   0,
            0,                      0,           -(far + near) / fmn, -(2.0 * far * near) / fmn,
            0,                      0,           -1,                  0,
        },
    };
}

pub fn orthographic(top: real, bottom: real, left: real, right: real, near: real, far: real) Mat4 {
    return Mat4{
        .data = [16]real{
            2.0 / (right - left), 0,                    0,                   -((right + left) / (right - left)),
            0,                    2.0 / (top - bottom), 0,                   -((top + bottom) / (top - bottom)),
            0,                    0,                    -2.0 / (far - near), -((far + near) / (far - near)),
            0,                    0,                    0,                   1,
        },
    };
}

pub fn lookat(pos: Vec3, dir: Vec3, up: Vec3) Mat4 {
    const f = pos.sub(dir).normalize();
    const s = cross(f, up).normalize();
    const u = cross(s, f);

    var data: [16]real = undefined;
    data[0..3].* = s.data;
    data[3] = -Vec3.dot(s, pos);
    data[4..7].* = u.data;
    data[7] = -Vec3.dot(u, pos);
    data[8..11].* = f.muls(-1).data;
    data[11] = Vec3.dot(f, pos);
    data[12..15].* = [1]real{0} ** 3;
    data[15] = 1;

    return Mat4{ .data = data };
}

pub fn fpslook(pos: Vec3, theta: Vec3) Mat4 {
    var look = rotate3d_euler(theta.data[0], theta.data[1], theta.data[2]);
    look.data[12] = -pos.data[0];
    look.data[13] = -pos.data[1];
    look.data[14] = -pos.data[2];
    look.data[15] = 1.0;
    return look;
}

fn matmul_prof(comptime M: type, trials: i64) void {
    var t = @intToFloat(f64, std.time.nanoTimestamp());
    var m1 = M.eye();
    var m2 = M.fill(2);
    var m3 = M.empty();
    var i: i64 = 0;
    while (i < trials) : (i += 1) m3 = m1.matmul(m2);
    std.debug.print(
        "matmul took {}ms per call, {*}\n",
        .{ ((@intToFloat(f64, std.time.nanoTimestamp()) - t) / @intToFloat(f64, trials)) / 1000.0, &m3.data },
    );
}

test "matmul profiling" {
    const trials: i64 = 1024;

    std.debug.print("\nprofiling matrix multiplies...\n", .{});
    matmul_prof(Mat2, trials);
    matmul_prof(Mat3, trials);
    matmul_prof(Mat4, trials);
}

test "Mat3" {
    var m1 = Mat3.eye();
    var m2 = Mat3.fill(2);

    var m3 = m1.add(m2);
    m1.set_(10, 2, 2);

    const row: Vec3 = m3.row(1);
    const col: Vec3 = m3.col(2);

    var m4 = m1.matmul(m3);

    std.debug.print("{} {} {} {} {} {}\n", .{ m1, m2, m3, row, col, m1.get(2, 2) });
    std.debug.print("{}\n", .{m4});
    std.debug.print("{}\n", .{matmul_block_size});
}

pub const Quat = struct {
    data: [4]real,
    const VT = Vector(4, real);

    pub fn from_vec4(v: Vec4) Quat {
        return Quat{ .data = v.data };
    }

    pub fn mul(self: Quat, other: Quat) Quat {
        const lv: VT = self.data;
        const rv: VT = other.data;
        _ = lv;
        _ = rv;
        return self;
    }

    pub fn mul_(self: *Quat, other: Quat) void {
        self.* = self.mul(other);
    }

    pub fn to_mat3(q: Quat) Mat3 {
        // [ 1 - (2yy + 2zz)  2xy - 2zw        2xz + 2yw       ]
        // [ 2xy + 2zw        1 - (2xx + 2zz)  2yz - 2xw       ]
        // [ 2xz - 2yw        2yz + 2xw        1 - (2xx + 2yy) ]
        const dx = 2 * q.x;
        const dy = 2 * q.y;
        const dz = 2 * q.z;
        const dxy = dx * q.y;
        const dxz = dx * q.z;
        const dyz = dy * q.z;
        const dxw = dx * q.w;
        const dyw = dy * q.w;
        const dzw = dz * q.w;
        const dxx = dx * q.x;
        const dyy = dy * q.y;
        const dzz = dz * q.z;

        return Mat3{ .data = [9]real{
            1 - (dyy + dzz), dxy - dzw,       dxz + dyw,
            dxy + dzw,       1 - (dxx + dzz), dyz - dxw,
            dxz - dyw,       dyz + dxw,       1 - (dxx + dyy),
        } };
    }
};

/// axis-aligned bounding boxes
/// TODO: change to min/max rep
pub const AABB = struct {
    pos: Vec3, // position of center of box
    dim: Vec3, // distance of each axis-aligned pair of faces from center

    /// AABB intersection test
    /// based on https://www.gamasutra.com/view/feature/131790/simple_intersection_tests_for_games.php?page=3
    pub fn intersect(a: AABB, b: AABB) bool {
        return (abs(b.pos.x - a.pos.x) <= (a.dim.x + b.dim.x) and abs(b.pos.y - a.pos.y) <= (a.dim.y + b.dim.y) and abs(b.pos.z - a.pos.z) <= (a.dim.z + b.dim.z));
    }
};

pub const Plane = struct {
    norm: Vec3 = Vec3.zero(),
    dist: f32 = 1.0,

    pub fn intersect(a: Plane, b: Plane, c: Plane) ?Vec3 {
        var p = cross(b.norm, c.norm);
        const d = a.norm.dot(p);
        if (d == 0.0) return null; // parallel, no intersection

        p = p.muls(-a.dist);
        p = p.sub(cross(c.norm, a.norm).muls(b.dist));
        p = p.sub(cross(a.norm, b.norm).muls(c.dist));
        return p.divs(d);
    }
};

pub inline fn vec2(x: real, y: real) Vec2 {
    return Vec2{ .data = [2]real{ x, y } };
}

pub inline fn vec3(x: real, y: real, z: real) Vec3 {
    return Vec3{ .data = [3]real{ x, y, z } };
}

pub inline fn vec4(x: real, y: real, z: real, w: real) Vec4 {
    return Vec4{ .data = [4]real{ x, y, z, w } };
}
