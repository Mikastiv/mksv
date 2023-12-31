#pragma once

#include "vec.hpp"

namespace mksv {
template <typename T>
struct Mat2 {
    Vec2<T> e[2] = {};

    constexpr Mat2() {
    }

    constexpr Mat2(const T v)
        : e{ Vec2<T>(v, 0), Vec2<T>(0, v) } {
    }

    constexpr Mat2(const T x1, const T y1, const T x2, const T y2)
        : e{ Vec2<T>(x1, y1), Vec2<T>(x2, y2) } {
    }

    constexpr Mat2(const Vec2<T>& x, const Vec2<T>& y)
        : e{ x, y } {
    }

    Vec2<T>&
    operator[](const u64 idx) {
        assert(idx < 2);
        return e[idx];
    }

    const Vec2<T>&
    operator[](const u64 idx) const {
        assert(idx < 2);
        return e[idx];
    }

    T*
    ptr() const {
        return (T*)&e[0].e[0];
    }
};

template <typename T>
struct Mat3 {
    Vec3<T> e[3] = {};

    constexpr Mat3() {
    }

    constexpr Mat3(const T v)
        : e{ Vec3<T>(v, 0, 0), Vec3<T>(0, v, 0), Vec3<T>(0, 0, v) } {
    }

    constexpr Mat3(
        const T x1,
        const T y1,
        const T z1,
        const T x2,
        const T y2,
        const T z2,
        const T x3,
        const T y3,
        const T z3
    )
        : e{ Vec3<T>(x1, y1, z1), Vec3<T>(x2, y2, z2), Vec3<T>(x3, y3, z3) } {
    }

    constexpr Mat3(const Vec3<T>& x, const Vec3<T>& y, const Vec3<T>& z)
        : e{ x, y, z } {
    }

    Vec3<T>&
    operator[](const u64 idx) {
        assert(idx < 3);
        return e[idx];
    }

    const Vec3<T>&
    operator[](const u64 idx) const {
        assert(idx < 3);
        return e[idx];
    }

    T*
    ptr() const {
        return (T*)&e[0].e[0];
    }
};

template <typename T>
struct Mat4 {
    Vec4<T> e[4] = {};

    constexpr Mat4() {
    }

    constexpr Mat4(const T v)
        : e{ Vec4<T>(v, 0, 0, 0), Vec4<T>(0, v, 0, 0), Vec4<T>(0, 0, v, 0), Vec4<T>(0, 0, 0, v) } {
    }

    constexpr Mat4(
        const T x1,
        const T y1,
        const T z1,
        const T w1,
        const T x2,
        const T y2,
        const T z2,
        const T w2,
        const T x3,
        const T y3,
        const T z3,
        const T w3,
        const T x4,
        const T y4,
        const T z4,
        const T w4
    )
        : e{ Vec4<T>(x1, y1, z1, w1),
             Vec4<T>(x2, y2, z2, w2),
             Vec4<T>(x3, y3, z3, w3),
             Vec4<T>(x4, y4, z4, w4) } {
    }

    constexpr Mat4(const Vec4<T>& x, const Vec4<T>& y, const Vec4<T>& z, const Vec4<T>& w)
        : e{ x, y, z, w } {
    }

    constexpr Mat4(const Mat3<T>& other)
        : e{
              Vec4<T>{ other.e[0], (T)0 },
              Vec4<T>{ other.e[1], (T)0 },
              Vec4<T>{ other.e[2], (T)0 },
              Vec4<T>{ (T)0, (T)0, (T)0, (T)1 }
    } {
    }

    constexpr
    operator Mat3<T>() const {
        return {
            e[0],
            e[1],
            e[2],
        };
    }

    Vec4<T>&
    operator[](const u64 idx) {
        assert(idx < 4);
        return e[idx];
    }

    const Vec4<T>&
    operator[](const u64 idx) const {
        assert(idx < 4);
        return e[idx];
    }

    T*
    ptr() const {
        return (T*)&e[0].e[0];
    }
};

using Mat2f = Mat2<f32>;
using Mat3f = Mat3<f32>;
using Mat4f = Mat4<f32>;

template <typename T>
constexpr Mat2<T>
operator+(const Mat2<T>& a, const Mat2<T>& b) {
    return {
        a[0] + b[0],
        a[1] + b[1],
    };
}

template <typename T>
constexpr Mat3<T>
operator+(const Mat3<T>& a, const Mat3<T>& b) {
    return {
        a[0] + b[0],
        a[1] + b[1],
        a[2] + b[2],
    };
}

template <typename T>
constexpr Mat4<T>
operator+(const Mat4<T>& a, const Mat4<T>& b) {
    return {
        a[0] + b[0],
        a[1] + b[1],
        a[2] + b[2],
        a[3] + b[3],
    };
}

template <typename T>
constexpr Mat2<T>
operator-(const Mat2<T>& a, const Mat2<T>& b) {
    return {
        a[0] - b[0],
        a[1] - b[1],
    };
}

template <typename T>
constexpr Mat3<T>
operator-(const Mat3<T>& a, const Mat3<T>& b) {
    return {
        a[0] - b[0],
        a[1] - b[1],
        a[2] - b[2],
    };
}

template <typename T>
constexpr Mat4<T>
operator-(const Mat4<T>& a, const Mat4<T>& b) {
    return {
        a[0] - b[0],
        a[1] - b[1],
        a[2] - b[2],
        a[3] - b[3],
    };
}

template <typename T>
constexpr Mat2<T>
operator*(const Mat2<T>& a, const T b) {
    return {
        a[0] * b,
        a[1] * b,
    };
}

template <typename T>
constexpr Mat3<T>
operator*(const Mat3<T>& a, const T b) {
    return {
        a[0] * b,
        a[1] * b,
        a[2] * b,
    };
}

template <typename T>
constexpr Mat4<T>
operator*(const Mat4<T>& a, const T b) {
    return {
        a[0] * b,
        a[1] * b,
        a[2] * b,
        a[4] * b,
    };
}

template <typename T>
constexpr Mat2<T>
operator*(const Mat2<T>& a, const Mat2<T>& b) {
    return {
        (a[0][0] * b[0][0]) + (a[0][1] * b[1][0]),
        (a[0][0] * b[0][1]) + (a[0][1] * b[1][1]),
        (a[1][0] * b[0][0]) + (a[1][1] * b[1][0]),
        (a[1][0] * b[0][1]) + (a[1][1] * b[1][1]),
    };
}

template <typename T>
constexpr Mat3<T>
operator*(const Mat3<T>& a, const Mat3<T>& b) {
    const T a00 = a[0][0];
    const T a01 = a[0][1];
    const T a02 = a[0][2];
    const T a10 = a[1][0];
    const T a11 = a[1][1];
    const T a12 = a[1][2];
    const T a20 = a[2][0];
    const T a21 = a[2][1];
    const T a22 = a[2][2];

    const T b00 = b[0][0];
    const T b01 = b[0][1];
    const T b02 = b[0][2];
    const T b10 = b[1][0];
    const T b11 = b[1][1];
    const T b12 = b[1][2];
    const T b20 = b[2][0];
    const T b21 = b[2][1];
    const T b22 = b[2][2];

    Mat3<T> out;
    out[0][0] = (a00 * b00) + (a10 * b01) + (a20 * b02);
    out[0][1] = (a01 * b00) + (a11 * b01) + (a21 * b02);
    out[0][2] = (a02 * b00) + (a12 * b01) + (a22 * b02);
    out[1][0] = (a00 * b10) + (a10 * b11) + (a20 * b12);
    out[1][1] = (a01 * b10) + (a11 * b11) + (a21 * b12);
    out[1][2] = (a02 * b10) + (a12 * b11) + (a22 * b12);
    out[2][0] = (a00 * b20) + (a10 * b21) + (a20 * b22);
    out[2][1] = (a01 * b20) + (a11 * b21) + (a21 * b22);
    out[2][2] = (a02 * b20) + (a12 * b21) + (a22 * b22);
    return out;
}

template <typename T>
constexpr Mat4<T>
operator*(const Mat4<T>& a, const Mat4<T>& b) {
    const Vec4<T> a0 = a[0];
    const Vec4<T> a1 = a[1];
    const Vec4<T> a2 = a[2];
    const Vec4<T> a3 = a[3];

    const Vec4<T> b0 = b[0];
    const Vec4<T> b1 = b[1];
    const Vec4<T> b2 = b[2];
    const Vec4<T> b3 = b[3];

    Mat4<T> out;
    out[0] = a0 * b0[0] + a1 * b0[1] + a2 * b0[2] + a3 * b0[3];
    out[1] = a0 * b1[0] + a1 * b1[1] + a2 * b1[2] + a3 * b1[3];
    out[2] = a0 * b2[0] + a1 * b2[1] + a2 * b2[2] + a3 * b2[3];
    out[3] = a0 * b3[0] + a1 * b3[1] + a2 * b3[2] + a3 * b3[3];
    return out;
}

template <typename T>
constexpr Vec2<T>
operator*(const Mat2<T>& a, const Vec2<T> b) {
    return {
        (a[0][0] * b.x) + (a[1][0] * b.y),
        (a[0][1] * b.x) + (a[1][1] * b.y),
    };
}

template <typename T>
constexpr Vec3<T>
operator*(const Mat3<T>& a, const Vec3<T> b) {
    return {
        (a[0][0] * b.x) + (a[1][0] * b.y) + (a[2][0] * b.z),
        (a[0][1] * b.x) + (a[1][1] * b.y) + (a[2][1] * b.z),
        (a[0][2] * b.x) + (a[1][2] * b.y) + (a[2][2] * b.z),
    };
}

template <typename T>
constexpr Vec4<T>
operator*(const Mat4<T>& a, const Vec4<T> b) {
    return {
        (a[0][0] * b.x) + (a[1][0] * b.y) + (a[2][0] * b.z) + (a[3][0] * b.w),
        (a[0][1] * b.x) + (a[1][1] * b.y) + (a[2][1] * b.z) + (a[3][1] * b.w),
        (a[0][2] * b.x) + (a[1][2] * b.y) + (a[2][2] * b.z) + (a[3][2] * b.w),
        (a[0][3] * b.x) + (a[1][3] * b.y) + (a[2][3] * b.z) + (a[3][3] * b.w),
    };
}

namespace math {

template <typename T>
constexpr Mat4<T>
scale(const Mat4<T>& m, const Vec3<T> s) {
    Mat4f out;
    out[0] = m[0] * s[0];
    out[1] = m[1] * s[1];
    out[2] = m[2] * s[2];
    out[3] = m[3];
    return out;
}

template <typename T>
constexpr Mat4<T>
scale(const Mat4<T>& m, const T s) {
    return scale(m, Vec3<T>(s, s, s));
}

template <typename T>
constexpr Mat4<T>
translate(const Mat4<T>& m, const Vec3<T> t) {
    Mat4f out = m;
    out[3] = m[0] * t[0] + m[1] * t[1] + m[2] * t[2] + m[3];
    return out;
}

template <typename T>
constexpr Mat4<T>
rotate(const Mat4<T>& m, const T angle, Vec3<T> axis) {
    const T c = cos(angle);
    const T s = sin(angle);
    axis = axis.unit();
    Vec3f t = { axis * ((T)1 - c) };

    Mat4f r;
    r[0][0] = c + t[0] * axis[0];
    r[0][1] = t[0] * axis[1] + s * axis[2];
    r[0][2] = t[0] * axis[2] - s * axis[1];
    r[1][0] = t[1] * axis[0] - s * axis[2];
    r[1][1] = c + t[1] * axis[1];
    r[1][2] = t[1] * axis[2] + s * axis[0];
    r[2][0] = t[2] * axis[0] + s * axis[1];
    r[2][1] = t[2] * axis[1] - s * axis[0];
    r[2][2] = c + t[2] * axis[2];

    Mat4f out;
    out[0] = m[0] * r[0][0] + m[1] * r[0][1] + m[2] * r[0][2];
    out[1] = m[0] * r[1][0] + m[1] * r[1][1] + m[2] * r[1][2];
    out[2] = m[0] * r[2][0] + m[1] * r[2][1] + m[2] * r[2][2];
    out[3] = m[3];
    return out;
}

template <typename T>
constexpr Mat4<T>
orthographic(const T l, const T r, const T b, const T t, const T n, const T f) {
    Mat4<T> out = { (T)1 };
    out[0][0] = (T)2 / (r - l);
    out[1][1] = (T)2 / (t - b);
    out[2][2] = (T)-2 / (f - n);
    out[3][0] = -(r + l) / (r - l);
    out[3][1] = -(t + b) / (t - b);
    out[3][2] = -(f + n) / (f - n);
    return out;
}

template <typename T>
constexpr Mat4<T>
perspective(const T fovy, const T aspect, const T n, const T f) {
    T const tan_half_fov = tan(fovy / (T)2);

    Mat4<T> out = { (T)0 };
    out[0][0] = (T)1 / (aspect * tan_half_fov);
    out[1][1] = (T)1 / (tan_half_fov);
    out[2][2] = -(f + n) / (f - n);
    out[2][3] = (T)-1;
    out[3][2] = -((T)2 * f * n) / (f - n);
    return out;
}

template <typename T>
constexpr Mat4<T>
look_at(const Vec3<T>& eye, const Vec3<T>& target, const Vec3<T>& up) {
    const Vec3<T> zaxis = normalize(target - eye);
    const Vec3<T> xaxis = normalize(cross(up, zaxis));
    const Vec3<T> yaxis = cross(zaxis, xaxis);

    Mat4<T> translation = { (T)1 };
    translation[3][0] = -eye.x;
    translation[3][1] = -eye.y;
    translation[3][2] = -eye.z;

    Mat4<T> rotation = { (T)1 };
    rotation[0][0] = -xaxis.x;
    rotation[1][0] = -xaxis.y;
    rotation[2][0] = -xaxis.z;
    rotation[0][1] = yaxis.x;
    rotation[1][1] = yaxis.y;
    rotation[2][1] = yaxis.z;
    rotation[0][2] = -zaxis.x; 
    rotation[1][2] = -zaxis.y;
    rotation[2][2] = -zaxis.z;

    return rotation * translation;

    // const Vec3<T> zaxis = normalize(target - eye);
    // const Vec3<T> xaxis = normalize(cross(zaxis, up));
    // const Vec3<T> yaxis = cross(xaxis, zaxis);

    // Mat4<T> out = { (T)1 };
    // out[0][0] = xaxis.x;
    // out[1][0] = xaxis.y;
    // out[2][0] = xaxis.z;
    // out[0][1] = yaxis.x;
    // out[1][1] = yaxis.y;
    // out[2][1] = yaxis.z;
    // out[0][2] = -zaxis.x;
    // out[1][2] = -zaxis.y;
    // out[2][2] = -zaxis.z;
    // out[3][0] = -dot(xaxis, eye);
    // out[3][1] = -dot(yaxis, eye);
    // out[3][2] = dot(zaxis, eye);
    // return out;
}

} // namespace math

} // namespace mksv
