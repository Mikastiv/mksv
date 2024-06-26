const std = @import("std");

const assert = std.debug.assert;

const Child = std.meta.Child;

// Math library for Vulkan

// Right handed

// Column major

pub const Vec2i = @Vector(2, i32);
pub const Vec3i = @Vector(3, i32);
pub const Vec4i = @Vector(4, i32);
pub const Vec2 = @Vector(2, f32);
pub const Vec3 = @Vector(3, f32);
pub const Vec4 = @Vector(4, f32);
pub const Mat2i = [2]Vec2i;
pub const Mat3i = [3]Vec3i;
pub const Mat4i = [4]Vec4i;
pub const Mat2 = [2]Vec2;
pub const Mat3 = [3]Vec3;
pub const Mat4 = [4]Vec4;

const mask = struct {
    const movelh = Vec4i{ 0, 1, -1, -2 };
    const movehl = Vec4i{ -3, -4, 2, 3 };

    const movelh_1 = Vec4i{ 0, 1, 0, 1 };
    const movehl_1 = Vec4i{ 2, 3, 2, 3 };
};

pub const Plane = struct {
    data: Vec4, // nx, ny, nx, d

    pub fn init(p: Vec3, n: Vec3) Plane {
        const x = vec.normalize(n);
        const d = vec.dot(-x, p);
        return .{ .data = .{ x[0], x[1], x[2], d } };
    }

    pub fn pointDistance(self: Plane, point: Vec3) f32 {
        checkNormalized(self.normal());
        return vec.dot(self.data, vec.vec4(point));
    }

    pub fn normal(self: Plane) Vec3 {
        return vec.swizzle3(self.data, .x, .y, .z);
    }
};

pub const Frustum = struct {
    const check_sides: void = if (Frustum.side_count != 6) @compileError("invalid side count") else {};

    pub const Side = enum(u8) { near = 0, far, left, right, top, bottom };
    const side_count = @typeInfo(Side).Enum.fields.len;

    planes: [side_count]Plane,

    pub fn init(fov: f32, aspect: f32, near: f32, far: f32, pos: Vec3, forward: Vec3) Frustum {
        assert(fov > 0);
        checkNormalized(forward);

        const right = vec.normalize(vec.cross(forward, .{ 0, 1, 0 }));
        const up = vec.normalize(vec.cross(right, forward));

        const half_v_side = far * @tan(fov / 2);
        const half_h_side = half_v_side * aspect;
        const forward_far = vec.mul(forward, far);

        var planes: [side_count]Plane = undefined;
        for (std.enums.values(Side)) |side| {
            planes[@intFromEnum(side)] = switch (side) {
                .near => Plane.init(pos + vec.mul(forward, near), forward),
                .far => Plane.init(pos + forward_far, -forward),
                .left => Plane.init(pos, vec.cross(up, forward_far + vec.mul(right, half_h_side))),
                .right => Plane.init(pos, vec.cross(forward_far - vec.mul(right, half_h_side), up)),
                .top => Plane.init(pos, vec.cross(right, forward_far - vec.mul(up, half_v_side))),
                .bottom => Plane.init(pos, vec.cross(forward_far + vec.mul(up, half_v_side), right)),
            };
        }

        return .{ .planes = planes };
    }

    pub fn isPointInside(self: *const @This(), point: Vec3) bool {
        for (&self.planes) |plane| {
            if (plane.pointDistance(point) < 0) return false;
        }
        return true;
    }
};

pub const vec = struct {
    fn checkType(comptime T: type) void {
        const info = @typeInfo(T);
        if (info != .Vector)
            @compileError("invalid type: " ++ @typeName(T));

        const child = @typeInfo(info.Vector.child);
        if (child != .Float and child != .Int)
            @compileError("invalid vector type: " ++ @typeName(info.Vector.child));
    }

    fn veclen(comptime T: type) comptime_int {
        checkType(T);
        return @typeInfo(T).Vector.len;
    }

    pub inline fn zero(comptime T: type) T {
        checkType(T);
        return @splat(0);
    }

    pub fn mul(a: anytype, b: Child(@TypeOf(a))) @TypeOf(a) {
        checkType(@TypeOf(a));
        return a * @as(@TypeOf(a), @splat(b));
    }

    pub fn div(a: anytype, b: Child(@TypeOf(a))) @TypeOf(a) {
        checkType(@TypeOf(a));
        return a / @as(@TypeOf(a), @splat(b));
    }

    pub fn dot(a: anytype, b: @TypeOf(a)) Child(@TypeOf(a)) {
        checkType(@TypeOf(a));
        return @reduce(.Add, a * b);
    }

    pub fn length2(v: anytype) Child(@TypeOf(v)) {
        checkType(@TypeOf(v));
        return dot(v, v);
    }

    pub fn magnitude2(v: anytype) Child(@TypeOf(v)) {
        return length2(v);
    }

    pub fn length(v: anytype) Child(@TypeOf(v)) {
        return @sqrt(length2(v));
    }

    pub fn magnitude(v: anytype) Child(@TypeOf(v)) {
        return length(v);
    }

    pub fn normalize(v: anytype) @TypeOf(v) {
        checkType(@TypeOf(v));
        const len = length(v);
        return div(v, len);
    }

    pub fn cross(a: anytype, b: anytype) @TypeOf(a, b) {
        const T = @TypeOf(a, b);
        checkType(T);
        if (veclen(T) != 3) @compileError("cross product is only defined for 3-element vectors");

        const C = Child(T);

        const x: T = a;
        const y: T = b;

        // https://geometrian.com/programming/tutorials/cross-product/index.php
        const tmp0 = @shuffle(C, x, undefined, Vec3i{ 1, 2, 0 });
        const tmp1 = @shuffle(C, y, undefined, Vec3i{ 2, 0, 1 });

        const tmp2 = tmp0 * y;
        const tmp3 = tmp0 * tmp1;

        const tmp4 = @shuffle(C, tmp2, undefined, Vec3i{ 1, 2, 0 });

        return tmp3 - tmp4;
    }

    pub fn distance2(a: anytype, b: anytype) Child(@TypeOf(a, b)) {
        const T = @TypeOf(a, b);
        checkType(T);

        const x: T = a;
        const y: T = b;

        return length2(y - x);
    }

    pub fn distance(a: anytype, b: anytype) Child(@TypeOf(a, b)) {
        return @sqrt(distance2(a, b));
    }

    pub fn eql(a: anytype, b: anytype) bool {
        const T = @TypeOf(a, b);
        checkType(T);

        const x: T = a;
        const y: T = b;

        return @reduce(.And, x == y);
    }

    pub const Component = enum(usize) { x = 0, y = 1, z = 2, w = 3 };

    pub fn swizzle2(
        v: anytype,
        comptime c0: Component,
        comptime c1: Component,
    ) @Vector(2, Child(@TypeOf(v))) {
        checkType(@TypeOf(v));
        const m = Vec2i{ @intFromEnum(c0), @intFromEnum(c1) };
        return @shuffle(Child(@TypeOf(v)), v, undefined, m);
    }

    pub fn swizzle3(
        v: anytype,
        comptime c0: Component,
        comptime c1: Component,
        comptime c2: Component,
    ) @Vector(3, Child(@TypeOf(v))) {
        checkType(@TypeOf(v));
        const m = Vec3i{ @intFromEnum(c0), @intFromEnum(c1), @intFromEnum(c2) };
        return @shuffle(Child(@TypeOf(v)), v, undefined, m);
    }

    pub fn swizzle4(
        v: anytype,
        comptime c0: Component,
        comptime c1: Component,
        comptime c2: Component,
        comptime c3: Component,
    ) @Vector(4, Child(@TypeOf(v))) {
        checkType(@TypeOf(v));
        const m = Vec4i{ @intFromEnum(c0), @intFromEnum(c1), @intFromEnum(c2), @intFromEnum(c3) };
        return @shuffle(Child(@TypeOf(v)), v, undefined, m);
    }

    pub fn vec2(v: anytype) @Vector(2, Child(@TypeOf(v))) {
        const len = veclen(@TypeOf(v));
        return switch (len) {
            3, 4 => .{ v[0], v[1] },
            else => unsupportedType(@TypeOf(v)),
        };
    }

    pub fn vec3(v: anytype) @Vector(3, Child(@TypeOf(v))) {
        const len = veclen(@TypeOf(v));
        return switch (len) {
            2 => .{ v[0], v[1], 0 },
            4 => .{ v[0], v[1], v[2] },
            else => unsupportedType(@TypeOf(v)),
        };
    }

    pub fn vec4(v: anytype) @Vector(4, Child(@TypeOf(v))) {
        const len = veclen(@TypeOf(v));
        return switch (len) {
            2 => .{ v[0], v[1], 0, 1 },
            3 => .{ v[0], v[1], v[2], 1 },
            else => unsupportedType(@TypeOf(v)),
        };
    }

    pub fn vec4Dir(v: anytype) @Vector(4, Child(@TypeOf(v))) {
        const len = veclen(@TypeOf(v));
        return switch (len) {
            2 => .{ v[0], v[1], 0, 0 },
            3 => .{ v[0], v[1], v[2], 0 },
            else => unsupportedType(@TypeOf(v)),
        };
    }

    /// Lossy cast
    pub fn cast(comptime T: type, v: anytype) @Vector(veclen(@TypeOf(v)), T) {
        checkType(@TypeOf(v));
        const info = @typeInfo(T);
        if (info != .Float and info != .Int) @compileError("invalid vector type: " ++ @typeName(T));

        const len = veclen(@TypeOf(v));
        var out: [len]T = undefined;
        inline for (0..len) |i| {
            out[i] = std.math.lossyCast(T, v[i]);
        }
        return out;
    }
};

pub const mat = struct {
    fn checkType(comptime T: type) void {
        const info = @typeInfo(T);
        if (info != .Array)
            @compileError("invalid type: " ++ @typeName(T));

        const child = @typeInfo(info.Array.child);
        if (child != .Vector)
            @compileError("invalid matrix child type: " ++ @typeName(info.Array.child));

        const underlying_type = @typeInfo(child.Vector.child);
        if (underlying_type != .Float and underlying_type != .Int)
            @compileError("invalid underlying matrix type: " ++ @typeName(child.Vector.child));
    }

    fn matsize(comptime T: type) comptime_int {
        checkType(T);

        const info = @typeInfo(T);

        const w = vec.veclen(Child(T));
        const h = info.Array.len;
        if (w != h) @compileError("non square matrix are not supported");

        return w;
    }

    pub fn mat2(m: anytype) [2]@Vector(2, Child(Child(@TypeOf(m)))) {
        const T = @TypeOf(m);
        const size = matsize(T);
        return switch (size) {
            3, 4 => .{
                vec.vec2(m[0]),
                vec.vec2(m[1]),
            },
            else => unsupportedType(T),
        };
    }

    pub fn mat3(m: anytype) [3]@Vector(3, Child(Child(@TypeOf(m)))) {
        const T = @TypeOf(m);
        const size = matsize(T);
        return switch (size) {
            2 => .{
                vec.vec3(m[0]),
                vec.vec3(m[1]),
                .{ 0, 0, 0 },
            },
            4 => .{
                vec.vec3(m[0]),
                vec.vec3(m[1]),
                vec.vec3(m[2]),
            },
            else => unsupportedType(T),
        };
    }

    pub fn mat4(m: anytype) [4]@Vector(4, Child(Child(@TypeOf(m)))) {
        const T = @TypeOf(m);
        const size = matsize(T);
        return switch (size) {
            2 => .{
                vec.vec4(m[0]),
                vec.vec4(m[1]),
                .{ 0, 0, 0, 0 },
                .{ 0, 0, 0, 0 },
            },
            3 => .{
                vec.vec4(m[0]),
                vec.vec4(m[1]),
                vec.vec4(m[2]),
                .{ 0, 0, 0, 0 },
            },
            else => unsupportedType(T),
        };
    }

    pub fn zero(comptime T: type) T {
        checkType(T);
        return std.mem.zeroes(T);
    }

    pub fn identity(comptime T: type) T {
        const size = matsize(T);

        var out = std.mem.zeroes(T);
        inline for (0..size) |i| {
            out[i][i] = 1;
        }

        return out;
    }

    pub fn add(a: anytype, b: anytype) @TypeOf(a, b) {
        const T = @TypeOf(a, b);
        const size = matsize(T);

        const x: T = a;
        const y: T = b;

        var out: T = undefined;
        inline for (0..size) |i| {
            out[i] = x[i] + y[i];
        }

        return out;
    }

    pub fn sub(a: anytype, b: anytype) @TypeOf(a, b) {
        const T = @TypeOf(a, b);
        const size = matsize(T);

        const x: T = a;
        const y: T = b;

        var out: T = undefined;
        inline for (0..size) |i| {
            out[i] = x[i] - y[i];
        }

        return out;
    }

    pub fn mulScalar(a: anytype, b: Child(Child(@TypeOf(a)))) @TypeOf(a) {
        const T = @TypeOf(a);
        const size = matsize(T);

        var out: T = undefined;
        inline for (0..size) |i| {
            out[i] = vec.mul(a[i], b);
        }

        return out;
    }

    pub fn divScalar(a: anytype, b: Child(Child(@TypeOf(a)))) @TypeOf(a) {
        const T = @TypeOf(a);
        const size = matsize(T);

        var out: T = undefined;
        inline for (0..size) |i| {
            out[i] = vec.div(a[i], b);
        }

        return out;
    }

    fn Matrix(comptime Vec: type) type {
        const vec_len = vec.veclen(Vec);
        return [vec_len]@Vector(vec_len, Child(Vec));
    }

    pub fn mulVec(m: anytype, v: Child(@TypeOf(m))) @TypeOf(v) {
        const size = matsize(@TypeOf(m));

        const T = Child(@TypeOf(v));
        const Vec = @TypeOf(v);

        switch (size) {
            2 => {
                const v0 = @shuffle(T, v, undefined, Vec4i{ 0, 0, 1, 1 });
                const m0 = @shuffle(T, m[0], m[1], mask.movelh);

                const a0 = m0 * v0;

                const f0 = @shuffle(T, a0, undefined, Vec4i{ 2, 3, 2, 3 });
                const g0 = a0 + f0;

                return .{ g0[0], g0[1] };
            },
            3 => {
                const v0 = @shuffle(T, v, undefined, Vec3i{ 0, 0, 0 });
                const v1 = @shuffle(T, v, undefined, Vec3i{ 1, 1, 1 });
                const v2 = @shuffle(T, v, undefined, Vec3i{ 2, 2, 2 });

                if (@typeInfo(T) == .Int) {
                    const m0 = m[0] * v0;
                    const m1 = m[1] * v1;
                    const m2 = m[2] * v2;

                    const a0 = m0 + m1;

                    return a0 + m2;
                }

                // .Float
                const m0 = m[0] * v0;
                const m1 = @mulAdd(Vec, m[1], v1, m0);
                const m2 = @mulAdd(Vec, m[2], v2, m1);

                return m2;
            },
            4 => {
                const v0 = @shuffle(T, v, undefined, Vec4i{ 0, 0, 0, 0 });
                const v1 = @shuffle(T, v, undefined, Vec4i{ 1, 1, 1, 1 });
                const v2 = @shuffle(T, v, undefined, Vec4i{ 2, 2, 2, 2 });
                const v3 = @shuffle(T, v, undefined, Vec4i{ 3, 3, 3, 3 });

                if (@typeInfo(T) == .Int) {
                    const m0 = m[0] * v0;
                    const m1 = m[1] * v1;
                    const m2 = m[2] * v2;
                    const m3 = m[3] * v3;

                    const a0 = m0 + m1;
                    const a1 = m2 + m3;

                    return a0 + a1;
                }

                // .Float
                const m0 = m[0] * v0;
                const m1 = @mulAdd(Vec, m[1], v1, m0);
                const m2 = @mulAdd(Vec, m[2], v2, m1);
                const m3 = @mulAdd(Vec, m[3], v3, m2);

                return m3;
            },
            else => @compileError("vector and matrix dimensions not supported"),
        }
    }

    pub fn mul(a: anytype, b: anytype) @TypeOf(a, b) {
        const T = @TypeOf(a, b);
        const size = matsize(T);

        const x: T = a;
        const y: T = b;

        var out: T = undefined;
        inline for (0..size) |i| {
            out[i] = mulVec(x, y[i]);
        }

        return out;
    }

    pub fn transpose(m: anytype) @TypeOf(m) {
        const T = @TypeOf(m);
        const size = matsize(T);

        const C = Child(Child(T));
        switch (size) {
            2 => {
                const m0 = @shuffle(C, m[0], m[1], Vec2i{ 0, -1 });
                const m1 = @shuffle(C, m[0], m[1], Vec2i{ 1, -2 });

                return .{ m0, m1 };
            },
            3 => {
                const t0 = @shuffle(C, m[0], m[1], Vec4i{ 0, 1, -1, -2 });
                const t2 = @shuffle(C, m[0], m[1], Vec4i{ 2, 2, -3, -3 });
                const t1 = @shuffle(C, m[2], undefined, Vec4i{ 0, 1, -1, -2 });
                const t3 = @shuffle(C, m[2], undefined, Vec4i{ 2, 2, -3, -3 });

                const m0 = @shuffle(C, t0, t1, Vec3i{ 0, 2, -1 });
                const m1 = @shuffle(C, t0, t1, Vec3i{ 1, 3, -2 });
                const m2 = @shuffle(C, t2, t3, Vec3i{ 0, 2, -1 });

                return .{ m0, m1, m2 };
            },
            4 => {
                const t0 = @shuffle(C, m[0], m[1], Vec4i{ 0, 1, -1, -2 });
                const t2 = @shuffle(C, m[0], m[1], Vec4i{ 2, 3, -3, -4 });
                const t1 = @shuffle(C, m[2], m[3], Vec4i{ 0, 1, -1, -2 });
                const t3 = @shuffle(C, m[2], m[3], Vec4i{ 2, 3, -3, -4 });

                const m0 = @shuffle(C, t0, t1, Vec4i{ 0, 2, -1, -3 });
                const m1 = @shuffle(C, t0, t1, Vec4i{ 1, 3, -2, -4 });
                const m2 = @shuffle(C, t2, t3, Vec4i{ 0, 2, -1, -3 });
                const m3 = @shuffle(C, t2, t3, Vec4i{ 1, 3, -2, -4 });

                return .{ m0, m1, m2, m3 };
            },
            else => @compileError("vector and matrix dimensions not supported"),
        }
    }

    pub fn scaling(s: Vec3) Mat4 {
        var out = zero(Mat4);
        out[0][0] = s[0];
        out[1][1] = s[1];
        out[2][2] = s[2];
        out[3][3] = 1;
        return out;
    }

    pub fn scalingUniform(s: f32) Mat4 {
        return scaling(.{ s, s, s });
    }

    pub fn scale(m: Mat4, s: Vec3) Mat4 {
        var out: Mat4 = undefined;
        out[0] = vec.mul(m[0], s[0]);
        out[1] = vec.mul(m[1], s[1]);
        out[2] = vec.mul(m[2], s[2]);
        out[3] = m[3];
        return out;
    }

    pub fn scaleScalar(m: Mat4, s: f32) Mat4 {
        return mat.scale(m, .{ s, s, s });
    }

    pub fn translation(t: Vec3) Mat4 {
        var out = identity(Mat4);
        out[3] = vec.vec4(t);
        return out;
    }

    pub fn translate(m: Mat4, t: Vec3) Mat4 {
        var out = m;
        const a = vec.mul(m[0], t[0]);
        const b = vec.mul(m[1], t[1]);
        const c = vec.mul(m[2], t[2]);
        out[3] = (a + b) + (c + m[3]);
        return out;
    }

    pub fn rotation(angle: f32, axis: Vec3) Mat4 {
        const s = @sin(angle);
        const c = @cos(angle);
        const a = vec.normalize(axis);
        const t = vec.mul(a, 1 - c);

        var out = zero(Mat4);
        out[0][0] = c + t[0] * a[0];
        out[0][1] = t[0] * a[1] + s * a[2];
        out[0][2] = t[0] * a[2] - s * a[1];
        out[1][0] = t[1] * a[0] - s * a[2];
        out[1][1] = c + t[1] * a[1];
        out[1][2] = t[1] * a[2] + s * a[0];
        out[2][0] = t[2] * a[0] + s * a[1];
        out[2][1] = t[2] * a[1] - s * a[0];
        out[2][2] = c + t[2] * a[2];
        out[3][3] = 1;
        return out;
    }

    pub fn rotate(m: Mat4, angle: f32, axis: Vec3) Mat4 {
        const rot = rotation(angle, axis);

        var out: Mat4 = undefined;

        const a = vec.mul(m[0], rot[0][0]);
        const b = vec.mul(m[1], rot[0][1]);
        const c = vec.mul(m[2], rot[0][2]);
        out[0] = a + b + c;

        const d = vec.mul(m[0], rot[1][0]);
        const e = vec.mul(m[1], rot[1][1]);
        const f = vec.mul(m[2], rot[1][2]);
        out[1] = d + e + f;

        const g = vec.mul(m[0], rot[2][0]);
        const h = vec.mul(m[1], rot[2][1]);
        const i = vec.mul(m[2], rot[2][2]);
        out[2] = g + h + i;

        out[3] = m[3];

        return out;
    }

    pub fn determinant(m: anytype) Child(Child(@TypeOf(m))) {
        const T = @TypeOf(m);
        const size = matsize(T);

        const C = Child(Child(T));

        switch (size) {
            2 => {
                return (m[0][0] * m[1][1]) - (m[1][0] * m[0][1]);
            },
            3 => {
                const a = m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]);
                const b = m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]);
                const c = m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
                return a - b + c;
            },
            4 => {
                // https://gitlab.com/libeigen/eigen/-/blob/master/Eigen/src/LU/arch/InverseSize4.h
                const a = @shuffle(C, m[0], m[1], mask.movelh);
                const b = @shuffle(C, m[1], m[0], mask.movehl);
                const c = @shuffle(C, m[2], m[3], mask.movelh);
                const d = @shuffle(C, m[3], m[2], mask.movehl);

                const mask0 = Vec4i{ 3, 3, 0, 0 };
                const mask1 = Vec4i{ 1, 1, 2, 2 };
                const mask2 = Vec4i{ 2, 3, 0, 1 };
                const mask3 = Vec4i{ 3, 3, 1, 1 };

                var ab = @shuffle(C, a, undefined, mask0) * b;
                ab -= @shuffle(C, a, undefined, mask1) * @shuffle(C, b, undefined, mask2);

                var dc = @shuffle(C, d, undefined, mask0) * c;
                dc -= @shuffle(C, d, undefined, mask1) * @shuffle(C, c, undefined, mask2);

                var det_a = @shuffle(C, a, undefined, mask3) * a;
                det_a -= @shuffle(C, det_a, undefined, mask.movehl_1);

                var det_b = @shuffle(C, b, undefined, mask3) * b;
                det_b -= @shuffle(C, det_b, undefined, mask.movehl_1);

                var det_c = @shuffle(C, c, undefined, mask3) * c;
                det_c -= @shuffle(C, det_c, undefined, mask.movehl_1);

                var det_d = @shuffle(C, d, undefined, mask3) * d;
                det_d -= @shuffle(C, det_d, undefined, mask.movehl_1);

                var x = @shuffle(C, dc, undefined, Vec4i{ 0, 2, 1, 3 }) * ab;
                x += @shuffle(C, x, undefined, mask.movehl_1);
                x += @shuffle(C, x, undefined, Vec4i{ 1, 0, 0, 0 });

                const d1 = det_a * det_d;
                const d2 = det_b * det_c;

                const det = (d1 + d2) - x;

                return det[0];
            },
            else => unsupportedType(@TypeOf(m)),
        }
    }

    pub fn inverse(m: anytype) @TypeOf(m) {
        const T = @TypeOf(m);
        const size = matsize(T);

        const Vec = Child(T);
        const C = Child(Vec);

        switch (size) {
            2 => {
                const rd = 1 / determinant(m);

                const m0 = @shuffle(C, m[0], m[1], Vec4i{ -2, 1, -1, 0 });
                const m1 = @Vector(4, C){ rd, -rd, -rd, rd };

                const a0 = m0 * m1;

                const f0 = @shuffle(C, a0, undefined, Vec2i{ 0, 1 });
                const f1 = @shuffle(C, a0, undefined, Vec2i{ 2, 3 });

                return .{ f0, f1 };
            },
            3 => {
                // https://www.onlinemathstutor.org/post/3x3_inverses
                const a = vec.cross(m[1], m[2]);
                const b = vec.cross(m[2], m[0]);
                const c = vec.cross(m[0], m[1]);

                var inv: Matrix(Vec) = .{ a, b, c };
                inv = mat.transpose(inv);

                const det = vec.dot(m[0], a);
                const rq = 1 / det;

                return mulScalar(inv, rq);
            },
            4 => {
                // https://gitlab.com/libeigen/eigen/-/blob/master/Eigen/src/LU/arch/InverseSize4.h
                const a = @shuffle(C, m[0], m[1], mask.movelh);
                const b = @shuffle(C, m[1], m[0], mask.movehl);
                const c = @shuffle(C, m[2], m[3], mask.movelh);
                const d = @shuffle(C, m[3], m[2], mask.movehl);

                const mask0 = Vec4i{ 3, 3, 0, 0 };
                const mask1 = Vec4i{ 1, 1, 2, 2 };
                const mask2 = Vec4i{ 2, 3, 0, 1 };
                const mask3 = Vec4i{ 3, 3, 1, 1 };

                var ab = @shuffle(C, a, undefined, mask0) * b;
                ab -= @shuffle(C, a, undefined, mask1) * @shuffle(C, b, undefined, mask2);

                var dc = @shuffle(C, d, undefined, mask0) * c;
                dc -= @shuffle(C, d, undefined, mask1) * @shuffle(C, c, undefined, mask2);

                var det_a = @shuffle(C, a, undefined, mask3) * a;
                det_a -= @shuffle(C, det_a, undefined, mask.movehl_1);

                var det_b = @shuffle(C, b, undefined, mask3) * b;
                det_b -= @shuffle(C, det_b, undefined, mask.movehl_1);

                var det_c = @shuffle(C, c, undefined, mask3) * c;
                det_c -= @shuffle(C, det_c, undefined, mask.movehl_1);

                var det_d = @shuffle(C, d, undefined, mask3) * d;
                det_d -= @shuffle(C, det_d, undefined, mask.movehl_1);

                var x = @shuffle(C, dc, undefined, Vec4i{ 0, 2, 1, 3 }) * ab;
                x += @shuffle(C, x, undefined, mask.movehl_1);
                x += @shuffle(C, x, undefined, Vec4i{ 1, 0, 0, 0 });

                const d1 = det_a * det_d;
                const d2 = det_b * det_c;

                const t = (d1 + d2) - x;
                const det = @shuffle(C, t, undefined, Vec4i{ 0, 0, 0, 0 });
                var rd = @as(Vec, @splat(1)) / det;

                var id = @shuffle(C, c, undefined, Vec4i{ 0, 0, 2, 2 }) * @shuffle(C, ab, undefined, mask.movelh_1);
                id += @shuffle(C, c, undefined, Vec4i{ 1, 1, 3, 3 }) * @shuffle(C, ab, undefined, mask.movehl_1);
                id = (d * @shuffle(C, det_a, undefined, Vec4i{ 0, 0, 0, 0 })) - id;

                var ia = @shuffle(C, b, undefined, Vec4i{ 0, 0, 2, 2 }) * @shuffle(C, dc, undefined, mask.movelh_1);
                ia += @shuffle(C, b, undefined, Vec4i{ 1, 1, 3, 3 }) * @shuffle(C, dc, undefined, mask.movehl_1);
                ia = (a * @shuffle(C, det_d, undefined, Vec4i{ 0, 0, 0, 0 })) - ia;

                var ib = d * @shuffle(C, ab, undefined, Vec4i{ 3, 0, 3, 0 });
                ib -= @shuffle(C, d, undefined, Vec4i{ 1, 0, 3, 2 }) * @shuffle(C, ab, undefined, Vec4i{ 2, 1, 2, 1 });
                ib = (c * @shuffle(C, det_b, undefined, Vec4i{ 0, 0, 0, 0 })) - ib;

                var ic = a * @shuffle(C, dc, undefined, Vec4i{ 3, 0, 3, 0 });
                ic -= @shuffle(C, a, undefined, Vec4i{ 1, 0, 3, 2 }) * @shuffle(C, dc, undefined, Vec4i{ 2, 1, 2, 1 });
                ic = (b * @shuffle(C, det_c, undefined, Vec4i{ 0, 0, 0, 0 })) - ic;

                const sign = Vec{ 1, -1, -1, 1 };
                rd *= sign;

                ia *= rd;
                ib *= rd;
                ic *= rd;
                id *= rd;

                const m0 = @shuffle(C, ia, ib, Vec4i{ 3, 1, -4, -2 });
                const m1 = @shuffle(C, ia, ib, Vec4i{ 2, 0, -3, -1 });
                const m2 = @shuffle(C, ic, id, Vec4i{ 3, 1, -4, -2 });
                const m3 = @shuffle(C, ic, id, Vec4i{ 2, 0, -3, -1 });

                return .{ m0, m1, m2, m3 };
            },
            else => unsupportedType(T),
        }
    }

    pub fn orthographic(left: f32, right: f32, top: f32, bottom: f32, near: f32, far: f32) Mat4 {
        var out = zero(Mat4);
        out[0][0] = 2 / (right - left);
        out[1][1] = 2 / (bottom - top);
        out[2][2] = 1 / (far - near);
        out[3][0] = -(right + left) / (right - left);
        out[3][1] = -(bottom + top) / (bottom - top);
        out[3][2] = -near / (far - near);
        return out;
    }

    pub fn perspective(fovy: f32, aspect: f32, near: f32, far: f32) Mat4 {
        std.debug.assert(near > 0 and far > 0);

        const g = 1.0 / @tan(fovy / 2.0);
        const k = far / (far - near);

        var out = zero(Mat4);
        out[0][0] = g / aspect;
        out[1][1] = -g;
        out[2][2] = -k;
        out[2][3] = -1;
        out[3][2] = -near * k;
        return out;
    }

    pub fn lookAtDir(eye: Vec3, dir: Vec3, up: Vec3) Mat4 {
        std.debug.assert(vec.length2(dir) != 0);

        const w = vec.normalize(dir);
        const u = vec.normalize(vec.cross(w, up));
        const v = vec.cross(u, w);

        const dot_u = vec.dot(u, eye);
        const dot_v = vec.dot(v, eye);
        const dot_w = vec.dot(w, eye);

        return .{
            .{ u[0], v[0], -w[0], 0 },
            .{ u[1], v[1], -w[1], 0 },
            .{ u[2], v[2], -w[2], 0 },
            .{ -dot_u, -dot_v, dot_w, 1 },
        };
    }

    pub fn lookAt(eye: Vec3, target: Vec3, up: Vec3) Mat4 {
        return lookAtDir(eye, vec.sub(target, eye), up);
    }

    pub fn debugPrint(m: anytype) void {
        const size = matsize(@TypeOf(m));
        for (0..size) |i| {
            std.log.err("{any}", .{m[i]});
        }
    }
};

fn unsupportedType(comptime T: type) void {
    @compileError("unsupported type: " ++ @typeName(T));
}

fn checkNormalized(v: anytype) void {
    const len = vec.length(v);
    assert(std.math.approxEqRel(f32, len, 1, float_tolerance));
}

pub const Sphere = struct {
    data: Vec4, // x, y, z, radius

    pub fn init(c: Vec3, r: f32) Sphere {
        return .{ .data = .{ c[0], c[1], c[2], r } };
    }

    pub fn contains(self: Sphere, point: Vec3) bool {
        return vec.distance(self.center(), point) <= self.radius() + float_tolerance;
    }

    pub fn center(self: Sphere) Vec3 {
        return vec.swizzle3(self.data, .x, .y, .z);
    }

    pub fn radius(self: Sphere) f32 {
        return self.data[3];
    }

    pub fn circumsphere(a: Vec3, b: Vec3, c: Vec3, d: Vec3) Sphere {
        const a2 = vec.length2(a);
        const b2 = vec.length2(b);
        const c2 = vec.length2(c);
        const d2 = vec.length2(d);

        const det_inv = 1.0 / mat.determinant(Mat4{
            .{ a[0], a[1], a[2], 1 },
            .{ b[0], b[1], b[2], 1 },
            .{ c[0], c[1], c[2], 1 },
            .{ d[0], d[1], d[2], 1 },
        });

        const x = mat.determinant(Mat4{
            .{ a2, a[1], a[2], 1 },
            .{ b2, b[1], b[2], 1 },
            .{ c2, c[1], c[2], 1 },
            .{ d2, d[1], d[2], 1 },
        });
        const y = mat.determinant(Mat4{
            .{ a[0], a2, a[2], 1 },
            .{ b[0], b2, b[2], 1 },
            .{ c[0], c2, c[2], 1 },
            .{ d[0], d2, d[2], 1 },
        });
        const z = mat.determinant(Mat4{
            .{ a[0], a[1], a2, 1 },
            .{ b[0], b[1], b2, 1 },
            .{ c[0], c[1], c2, 1 },
            .{ d[0], d[1], d2, 1 },
        });

        const cen = vec.mul(Vec3{ x, y, z }, det_inv * 0.5);

        return init(cen, vec.distance(cen, a));
    }

    pub fn circumsphereTriangle(a: Vec3, b: Vec3, c: Vec3) Sphere {
        const ca = c - a;
        const ba = b - a;
        const crs = vec.cross(ba, ca);

        const t0 = vec.mul(vec.cross(crs, ba), vec.length2(ca));
        const t1 = vec.mul(vec.cross(ca, crs), vec.length2(ba));
        const x = t0 + t1;

        const rvec = vec.div(x, 2.0 * vec.length2(crs));

        return init(a + rvec, vec.length(rvec));
    }

    pub fn fromDiameter(a: Vec3, b: Vec3) Sphere {
        const cen = vec.mul(a + b, 0.5);
        return init(cen, vec.distance(cen, a));
    }
};

fn smallestEnclosingSphereImpl(points: []const Vec3, end: usize, pin1: ?Vec3, pin2: ?Vec3, pin3: ?Vec3) Sphere {
    var sphere: Sphere = undefined;

    var current: usize = 0;
    if (pin1 != null and pin2 != null and pin3 != null) {
        sphere = Sphere.circumsphereTriangle(pin1.?, pin2.?, pin3.?);
    } else if (pin1 != null and pin2 != null) {
        sphere = Sphere.fromDiameter(pin1.?, pin2.?);
    } else if (pin1 != null) {
        sphere = Sphere.fromDiameter(points[current], pin1.?);
        current += 1;
    } else {
        sphere = Sphere.fromDiameter(points[current], points[current + 1]);
        current += 2;
    }

    while (current < end) {
        if (!sphere.contains(points[current])) {
            if (pin1 != null and pin2 != null and pin3 != null) {
                sphere = Sphere.circumsphere(pin1.?, pin2.?, pin3.?, points[current]);
            } else if (pin1 != null and pin2 != null) {
                sphere = smallestEnclosingSphereImpl(points, current, pin1, pin2, points[current]);
            } else if (pin1 != null) {
                sphere = smallestEnclosingSphereImpl(points, current, pin1, points[current], null);
            } else {
                sphere = smallestEnclosingSphereImpl(points, current, points[current], null, null);
            }
        }
        current += 1;
    }

    return sphere;
}

pub fn smallestEnclosingSphere(points: []const Vec3) Sphere {
    std.debug.assert(points.len > 1);
    return smallestEnclosingSphereImpl(points, points.len, null, null, null);
}

pub fn average(comptime T: type, values: []const T) T {
    var sum: T = 0;
    for (values) |value| {
        sum += value;
    }
    return sum / values.len;
}

pub fn scale(comptime T: type, value: T, factor: f32) T {
    if (@typeInfo(T) != .Int) @compileError("only accepts integer");

    const value_float: f32 = @floatFromInt(value);
    const scaled = value_float * factor;
    return @intFromFloat(scaled);
}

const testing = std.testing;
const float_tolerance = 0.0001;

test "vec.zero" {
    const x = vec.zero(Vec4);
    const y = Vec4{ 0, 0, 0, 0 };
    try testing.expectEqual(x, y);
}

test "vec.neg" {
    const v = Vec4i{ 8, 2, 1, 4 };

    try testing.expect(vec.eql(-v, .{ -8, -2, -1, -4 }));
}

test "vec.mul" {
    const x = Vec4{ 1, 8, 2, 0 };
    const y = vec.mul(x, 4);

    try testing.expect(vec.eql(y, .{ 4, 32, 8, 0 }));
}

test "vec.dot" {
    const x = Vec3{ 3, 9, 1 };
    const y = Vec3{ 8, 7, 2 };

    const d = vec.dot(x, y);

    try testing.expectApproxEqRel(89, d, float_tolerance);
}

test "vec.length" {
    const v = Vec3{ 3, 4, 5 };

    try testing.expectApproxEqRel(50, vec.length2(v), float_tolerance);
    try testing.expectApproxEqRel(7.0710, vec.length(v), float_tolerance);
}

test "vec.normalize" {
    const v = Vec2{ 3, 4 };
    const n = vec.normalize(v);

    try testing.expectApproxEqRel(0.6, n[0], float_tolerance);
    try testing.expectApproxEqRel(0.8, n[1], float_tolerance);
}

test "vec.cross" {
    const a = Vec3i{ 3, 9, 2 };
    const b = Vec3i{ 1, 8, 6 };
    const c = vec.cross(a, b);

    try testing.expectEqual(38, c[0]);
    try testing.expectEqual(-16, c[1]);
    try testing.expectEqual(15, c[2]);
}

test "vec.distance" {
    const v0 = Vec3{ 8, 2, 1 };
    const v1 = Vec3{ 2, 9, 6 };

    try testing.expectApproxEqRel(110, vec.distance2(v0, v1), float_tolerance);
    try testing.expectApproxEqRel(10.4880, vec.distance(v0, v1), float_tolerance);
}

test "vec.eql" {
    const v0 = Vec3{ 8, 2, 1 };
    const v1 = Vec3{ 2, 9, 6 };
    const v2 = Vec3{ 2, 9, 6 };

    try testing.expect(!vec.eql(v0, v1));
    try testing.expect(vec.eql(v2, v1));

    const v0i = Vec3{ 8, 2, 1 };
    const v1i = Vec3{ 2, 9, 6 };
    const v2i = Vec3{ 2, 9, 6 };

    try testing.expect(!vec.eql(v0i, v1i));
    try testing.expect(vec.eql(v2i, v1i));
}

test "vec.swizzle" {
    const v = Vec4i{ 82, 12, 97, 26 };

    try testing.expect(vec.eql(vec.swizzle2(v, .x, .x), .{ 82, 82 }));
    try testing.expect(vec.eql(vec.swizzle2(v, .x, .w), .{ 82, 26 }));

    try testing.expect(vec.eql(vec.swizzle3(v, .z, .z, .z), .{ 97, 97, 97 }));
    try testing.expect(vec.eql(vec.swizzle3(v, .z, .y, .y), .{ 97, 12, 12 }));
    try testing.expect(vec.eql(vec.swizzle3(v, .x, .y, .z), .{ 82, 12, 97 }));

    try testing.expect(vec.eql(vec.swizzle4(v, .w, .w, .w, .w), .{ 26, 26, 26, 26 }));
    try testing.expect(vec.eql(vec.swizzle4(v, .x, .y, .z, .w), .{ 82, 12, 97, 26 }));
    try testing.expect(vec.eql(vec.swizzle4(v, .y, .y, .x, .z), .{ 12, 12, 82, 97 }));
    try testing.expect(vec.eql(vec.swizzle4(v, .z, .x, .x, .y), .{ 97, 82, 82, 12 }));
}

test "vec.cast" {
    const a = Vec4{ 8, 2, -4, 1 };
    const b = vec.cast(i32, a);
    const c = vec.cast(u32, b);

    try testing.expect(vec.eql(b, .{ 8, 2, -4, 1 }));
    try testing.expect(vec.eql(c, .{ 8, 2, 0, 1 }));

    const x = Vec3i{ 8, 6, -5 };
    const y = vec.cast(f32, x);
    const z = vec.cast(i16, y);

    try testing.expect(vec.eql(y, .{ 8, 6, -5 }));
    try testing.expect(vec.eql(z, .{ 8, 6, -5 }));
}

test "plane.pointDistance" {
    const p = Plane.init(.{ 6, 7, 2 }, .{ 8, 3, 1 });
    const n = p.normal();
    const dist = p.pointDistance(.{ 10, 9, 4 });

    try testing.expectApproxEqRel(4.65, dist, float_tolerance);
    try testing.expect(vec.eql(n, vec.normalize(Vec3{ 8, 3, 1 })));
}

test "frustum.isPointInside" {
    const forward = Vec3{ 0, 0, 1 };
    const frustum = Frustum.init(std.math.degreesToRadians(80), 16.0 / 9.0, 1, 100, .{ 0, 0, 0 }, forward);

    try testing.expect(frustum.isPointInside(.{ 0, 0, 50 }));
    try testing.expect(frustum.isPointInside(.{ 0, 41.95, 50 }));
    try testing.expect(!frustum.isPointInside(.{ 0, 42, 50 }));
    try testing.expect(frustum.isPointInside(.{ 74.58, 41.95, 50 }));
    try testing.expect(frustum.isPointInside(.{ -74.58, 41.95, 50 }));
    try testing.expect(!frustum.isPointInside(.{ 74.59, 41.95, 50 }));
    try testing.expect(frustum.isPointInside(.{ 0, 0, 100 }));
    try testing.expect(!frustum.isPointInside(.{ 0, 0, 100.5 }));
    try testing.expect(!frustum.isPointInside(.{ 0, 0, -100 }));
    try testing.expect(!frustum.isPointInside(.{ 0, 0, 0.5 }));
}

test "mat.add" {
    const a = Mat4{
        .{ 1, 9, 3, 9 },
        .{ 9, 2, 1, 5 },
        .{ 4, 3, 9, 0 },
        .{ 4, 5, 6, 7 },
    };
    const b = Mat4{
        .{ 9, 3, 1, 2 },
        .{ 1, 1, 4, 5 },
        .{ 9, 8, 7, 3 },
        .{ 2, 1, 5, 0 },
    };
    const c = mat.add(a, b);

    try testing.expectEqual(a[0] + b[0], c[0]);
    try testing.expectEqual(a[1] + b[1], c[1]);
    try testing.expectEqual(a[2] + b[2], c[2]);
    try testing.expectEqual(a[3] + b[3], c[3]);
}

test "mat.mulVec" {
    const a = Mat4i{
        .{ 9, 3, 1, 9 },
        .{ 5, 4, 7, 6 },
        .{ 1, 2, 0, 8 },
        .{ 3, 1, 9, 2 },
    };
    const b = Vec4i{ 3, 8, 5, 1 };
    const c = mat.mulVec(a, b);

    try testing.expectEqual(Vec4i{ 75, 52, 68, 117 }, c);

    const x = Mat3{
        .{ 3, 4, 8 },
        .{ 9, 1, 5 },
        .{ 8, 2, 8 },
    };
    const y = Vec3{ 7, 9, 1 };
    const z = mat.mulVec(x, y);

    try testing.expectEqual(Vec3{ 110, 39, 109 }, z);

    const t = Mat2i{
        .{ 3, 4 },
        .{ 9, 1 },
    };
    const u = Vec2i{ 7, 9 };
    const v = mat.mulVec(t, u);

    try testing.expectEqual(Vec2i{ 102, 37 }, v);
}

test "mat.mul" {
    const a = Mat4i{
        .{ 3, 4, 8, 8 },
        .{ 9, 1, 5, 2 },
        .{ 8, 2, 8, 4 },
        .{ 9, 6, 5, 2 },
    };
    const b = Mat4i{
        .{ 7, 9, 1, 3 },
        .{ 8, 6, 2, 5 },
        .{ 3, 9, 1, 3 },
        .{ 0, 4, 2, 1 },
    };
    const c = mat.mul(a, b);

    try testing.expectEqual(
        Mat4i{
            .{ 137, 57, 124, 84 },
            .{ 139, 72, 135, 94 },
            .{ 125, 41, 92, 52 },
            .{ 61, 14, 41, 18 },
        },
        c,
    );

    const x = Mat3i{
        .{ 3, 4, 8 },
        .{ 9, 1, 5 },
        .{ 8, 2, 8 },
    };
    const y = Mat3i{
        .{ 7, 9, 1 },
        .{ 8, 6, 2 },
        .{ 3, 9, 1 },
    };
    const z = mat.mul(x, y);

    try testing.expectEqual(
        Mat3i{
            .{ 110, 39, 109 },
            .{ 94, 42, 110 },
            .{ 98, 23, 77 },
        },
        z,
    );

    const t = Mat2i{
        .{ 3, 4 },
        .{ 9, 1 },
    };
    const u = Mat2i{
        .{ 7, 9 },
        .{ 8, 6 },
    };
    const v = mat.mul(t, u);

    try testing.expectEqual(
        Mat2i{
            .{ 102, 37 },
            .{ 78, 38 },
        },
        v,
    );
}

test "mat.transpose" {
    const a = Mat4i{
        .{ 1, 2, 3, 4 },
        .{ 5, 6, 7, 8 },
        .{ 9, 10, 11, 12 },
        .{ 13, 14, 15, 16 },
    };
    const b = mat.transpose(a);

    try testing.expectEqual(
        Mat4i{
            .{ 1, 5, 9, 13 },
            .{ 2, 6, 10, 14 },
            .{ 3, 7, 11, 15 },
            .{ 4, 8, 12, 16 },
        },
        b,
    );

    const x = Mat3i{
        .{ 1, 2, 3 },
        .{ 4, 5, 6 },
        .{ 7, 8, 9 },
    };
    const y = mat.transpose(x);

    try testing.expectEqual(
        Mat3i{
            .{ 1, 4, 7 },
            .{ 2, 5, 8 },
            .{ 3, 6, 9 },
        },
        y,
    );

    const u = Mat2i{
        .{ 1, 2 },
        .{ 3, 4 },
    };
    const v = mat.transpose(u);

    try testing.expectEqual(
        Mat2i{
            .{ 1, 3 },
            .{ 2, 4 },
        },
        v,
    );
}

test "mat.translate" {
    var m = mat.identity(Mat4);
    m = mat.translate(m, .{ 1, 2, 3 });

    const pos = Vec4{ 0, 0, 0, 1 };
    const out = mat.mulVec(m, pos);

    try testing.expectEqual(.{ 1, 2, 3, 1 }, out);

    const t = mat.translation(.{ 1, 2, 3 });
    const p = mat.mulVec(t, Vec4{ 4, 6, 8, 1 });
    try testing.expectEqual(.{ 5, 8, 11, 1 }, p);
}

test "mat.rotate" {
    const pos = Vec4{ 1, 1, 1, 1 };

    var m = mat.identity(Mat4);
    m = mat.rotate(m, std.math.degreesToRadians(180), .{ 1, 0, 0 });

    try testing.expectApproxEqRel(1, mat.mulVec(m, pos)[0], float_tolerance);
    try testing.expectApproxEqRel(-1, mat.mulVec(m, pos)[1], float_tolerance);
    try testing.expectApproxEqRel(-1, mat.mulVec(m, pos)[2], float_tolerance);
    try testing.expectApproxEqRel(1, mat.mulVec(m, pos)[3], float_tolerance);

    m = mat.identity(Mat4);
    m = mat.rotate(m, std.math.degreesToRadians(180), .{ 0, 1, 0 });

    try testing.expectApproxEqRel(-1, mat.mulVec(m, pos)[0], float_tolerance);
    try testing.expectApproxEqRel(1, mat.mulVec(m, pos)[1], float_tolerance);
    try testing.expectApproxEqRel(-1, mat.mulVec(m, pos)[2], float_tolerance);
    try testing.expectApproxEqRel(1, mat.mulVec(m, pos)[3], float_tolerance);

    m = mat.identity(Mat4);
    m = mat.rotate(m, std.math.degreesToRadians(180), .{ 0, 0, 1 });

    try testing.expectApproxEqRel(-1, mat.mulVec(m, pos)[0], float_tolerance);
    try testing.expectApproxEqRel(-1, mat.mulVec(m, pos)[1], float_tolerance);
    try testing.expectApproxEqRel(1, mat.mulVec(m, pos)[2], float_tolerance);
    try testing.expectApproxEqRel(1, mat.mulVec(m, pos)[3], float_tolerance);
}

test "mat.scale" {
    const pos = Vec4{ 1, 1, 1, 1 };

    var m = mat.identity(Mat4);
    m = mat.scale(m, .{ 2, 3, 4 });

    try testing.expectEqual(.{ 2, 3, 4, 1 }, mat.mulVec(m, pos));
}

test "mat.determinant" {
    const a = Mat4{
        .{ 2, 1, 9, 3 },
        .{ 8, 9, 2, 1 },
        .{ 6, 4, 2, 9 },
        .{ 7, 0, 1, 3 },
    };

    try testing.expectApproxEqRel(3961, mat.determinant(a), float_tolerance);

    const b = Mat2{
        .{ 4, 6 },
        .{ 3, 8 },
    };

    try testing.expectApproxEqRel(14, mat.determinant(b), float_tolerance);

    const c = Mat3{
        .{ 6, 1, 1 },
        .{ 4, -2, 5 },
        .{ 2, 8, 7 },
    };

    try testing.expectApproxEqRel(-306, mat.determinant(c), float_tolerance);
}

test "mat.inverse" {
    const a = Mat2{
        .{ 4, 6 },
        .{ 3, 8 },
    };

    const b = mat.inverse(a);

    try testing.expectApproxEqRel(1.0 / 14.0 * 8, b[0][0], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 14.0 * -6, b[0][1], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 14.0 * -3, b[1][0], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 14.0 * 4, b[1][1], float_tolerance);

    const x = Mat3{
        .{ 6, 1, 1 },
        .{ 4, -2, 5 },
        .{ 2, 8, 7 },
    };

    const y = mat.inverse(x);

    try testing.expectApproxEqRel(1.0 / 306.0 * 54, y[0][0], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 306.0 * -1, y[0][1], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 306.0 * -7, y[0][2], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 306.0 * 18, y[1][0], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 306.0 * -40, y[1][1], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 306.0 * 26, y[1][2], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 306.0 * -36, y[2][0], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 306.0 * 46, y[2][1], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 306.0 * 16, y[2][2], float_tolerance);

    const u = Mat4{
        .{ 2, 1, 9, 3 },
        .{ 8, 9, 2, 1 },
        .{ 6, 4, 2, 9 },
        .{ 7, 0, 1, 3 },
    };

    const v = mat.inverse(u);

    try testing.expectApproxEqRel(1.0 / 3961.0 * -47, v[0][0], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 3961.0 * 99, v[0][1], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 3961.0 * -211, v[0][2], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 3961.0 * 647, v[0][3], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 3961.0 * -58, v[1][0], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 3961.0 * 375, v[1][1], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 3961.0 * 161, v[1][2], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 3961.0 * -550, v[1][3], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 3961.0 * 473, v[2][0], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 3961.0 * 15, v[2][1], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 3961.0 * -152, v[2][2], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 3961.0 * -22, v[2][3], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 3961.0 * -48, v[3][0], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 3961.0 * -236, v[3][1], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 3961.0 * 543, v[3][2], float_tolerance);
    try testing.expectApproxEqRel(1.0 / 3961.0 * -182, v[3][3], float_tolerance);
}

test "sphere.contains" {
    const s = smallestEnclosingSphere(&.{
        .{ 2.0, 1.0, 0.0 },
        .{ 2.0, -1.0, 0.0 },
        .{ 0.0, -1.0, 0.0 },
        .{ 0.0, 1.0, 0.0 },
    });

    try testing.expect(s.contains(.{ 2.0, 1.0, 0.0 }));
    try testing.expect(s.contains(.{ 2.0, 0.0, 1.0 }));
    try testing.expect(!s.contains(.{ 2.41, 1.0, 0.0 }));
    try testing.expect(s.contains(.{ 2.41, 0.0, 0.0 }));
    try testing.expect(!s.contains(.{ 2.42, 0.0, 0.0 }));
}
