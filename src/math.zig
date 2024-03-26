const std = @import("std");

const assert = std.debug.assert;
const testing = std.testing;
const float_tolerance = 0.0001;

const Child = std.meta.Child;

// Math library for Vulkan

// Right handed

// Row major

pub const Vec2i = @Vector(2, i32);
pub const Vec3i = @Vector(3, i32);
pub const Vec4i = @Vector(4, i32);
pub const Vec2 = @Vector(2, f32);
pub const Vec3 = @Vector(3, f32);
pub const Vec4 = @Vector(4, f32);
pub const Mat2 = [2]Vec2;
pub const Mat3 = [3]Vec3;
pub const Mat4 = [4]Vec4;

pub const Plane = struct {
    data: Vec4,

    pub fn init(p: Vec3, n: Vec3) Plane {
        const x = vec.normalize(n);
        const d = vec.dot(-x, p);
        return .{ .data = .{ x[0], x[1], x[2], d } };
    }

    pub fn pointDistance(self: Plane, point: Vec3) f32 {
        checkNormalized(self.normal());
        return vec.dot(self.data, .{ point[0], point[1], point[2], 1 });
    }

    pub fn normal(self: Plane) Vec3 {
        return .{ self.data[0], self.data[1], self.data[2] };
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

    pub fn cross(a: anytype, b: @TypeOf(a)) @TypeOf(a, b) {
        checkType(@TypeOf(a));
        if (veclen(@TypeOf(a)) != 3) @compileError("cross product is only defined for 3-element vectors");

        const T = Child(@TypeOf(a));

        // https://geometrian.com/programming/tutorials/cross-product/index.php
        const tmp0 = @shuffle(T, a, undefined, Vec3i{ 1, 2, 0 });
        const tmp1 = @shuffle(T, b, undefined, Vec3i{ 2, 0, 1 });

        const tmp2 = tmp0 * b;
        const tmp3 = tmp0 * tmp1;

        const tmp4 = @shuffle(T, tmp2, undefined, Vec3i{ 1, 2, 0 });

        return tmp3 - tmp4;
    }

    pub fn distance2(a: anytype, b: @TypeOf(a)) Child(@TypeOf(a)) {
        checkType(@TypeOf(a));
        return length2(b - a);
    }

    pub fn distance(a: anytype, b: @TypeOf(a)) Child(@TypeOf(a)) {
        checkType(@TypeOf(a));
        return @sqrt(length2(b - a));
    }

    pub fn eql(a: anytype, b: @TypeOf(a)) bool {
        checkType(@TypeOf(a));
        return @reduce(.And, a == b);
    }

    pub const Component = enum(usize) { x = 0, y = 1, z = 2, w = 3 };

    pub fn swizzle2(
        v: anytype,
        comptime c0: Component,
        comptime c1: Component,
    ) @Vector(2, Child(@TypeOf(v))) {
        checkType(@TypeOf(v));
        const mask = Vec2i{ @intFromEnum(c0), @intFromEnum(c1) };
        return @shuffle(Child(@TypeOf(v)), v, undefined, mask);
    }

    pub fn swizzle3(
        v: anytype,
        comptime c0: Component,
        comptime c1: Component,
        comptime c2: Component,
    ) @Vector(3, Child(@TypeOf(v))) {
        checkType(@TypeOf(v));
        const mask = Vec3i{ @intFromEnum(c0), @intFromEnum(c1), @intFromEnum(c2) };
        return @shuffle(Child(@TypeOf(v)), v, undefined, mask);
    }

    pub fn swizzle4(
        v: anytype,
        comptime c0: Component,
        comptime c1: Component,
        comptime c2: Component,
        comptime c3: Component,
    ) @Vector(4, Child(@TypeOf(v))) {
        checkType(@TypeOf(v));
        const mask = Vec4i{ @intFromEnum(c0), @intFromEnum(c1), @intFromEnum(c2), @intFromEnum(c3) };
        return @shuffle(Child(@TypeOf(v)), v, undefined, mask);
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

        return switch (T) {
            Mat2, Mat3, Mat4 => w,
            else => unsupportedType(T),
        };
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

    pub fn add(a: anytype, b: @TypeOf(a)) @TypeOf(a, b) {
        const T = @TypeOf(a);
        const size = matsize(T);

        var out: T = undefined;
        inline for (0..size) |i| {
            out[i] = a[i] + b[i];
        }

        return out;
    }

    pub fn sub(a: anytype, b: @TypeOf(a)) @TypeOf(a, b) {
        const T = @TypeOf(a);
        const size = matsize(T);

        var out: T = undefined;
        inline for (0..size) |i| {
            out[i] = a[i] - b[i];
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

    pub fn mulVec(v: Vec4, m: Mat4) Vec4 {
        const v0 = @shuffle(f32, v, undefined, Vec4i{ 0, 0, 0, 0 });
        const v1 = @shuffle(f32, v, undefined, Vec4i{ 1, 1, 1, 1 });
        const v2 = @shuffle(f32, v, undefined, Vec4i{ 2, 2, 2, 2 });
        const v3 = @shuffle(f32, v, undefined, Vec4i{ 3, 3, 3, 3 });

        const m0 = v0 * m[0];
        const m1 = v1 * m[1];
        const m2 = v2 * m[2];
        const m3 = v3 * m[3];

        const a0 = m0 + m1;
        const a1 = m2 + m3;
        const a2 = a0 + a1;

        return a2;
    }

    pub fn mul(a: Mat4, b: Mat4) Mat4 {
        var out: Mat4 = undefined;
        inline for (0..4) |i| {
            out[i] = mulVec(a[i], b);
        }

        return out;
    }

    pub inline fn scaling(s: Vec3) Mat4 {
        var out = zero(Mat4);
        out[0][0] = s[0];
        out[1][1] = s[1];
        out[2][2] = s[2];
        out[3][3] = 1;
        return out;
    }

    pub inline fn scalingUniform(s: f32) Mat4 {
        return scaling(.{ s, s, s });
    }

    pub fn debugPrint(m: anytype) void {
        const size = matsize(@TypeOf(m));
        for (0..size) |i| {
            std.log.debug("{any}", .{m[i]});
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
    const a = mat.identity(Mat4);
    const b = mat.identity(Mat4);
    const c = mat.add(a, b);

    try testing.expectEqual(2, c[1][1]);
}

test "mat.mul" {
    const a = Mat4{
        .{ 3, 4, 8, 8 },
        .{ 9, 1, 5, 2 },
        .{ 8, 2, 8, 4 },
        .{ 9, 6, 5, 2 },
    };
    const b = Mat4{
        .{ 7, 9, 1, 3 },
        .{ 8, 6, 2, 5 },
        .{ 3, 9, 1, 3 },
        .{ 0, 4, 2, 1 },
    };
    const out = mat.mul(a, b);

    try testing.expectEqual(
        Mat4{
            .{ 77, 155, 35, 61 },
            .{ 86, 140, 20, 49 },
            .{ 96, 172, 28, 62 },
            .{ 126, 170, 30, 74 },
        },
        out,
    );
}
