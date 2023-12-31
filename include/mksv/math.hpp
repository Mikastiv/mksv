#pragma once

#include "assert.hpp"
#include "ctx.hpp"
#include "float.hpp"
#include "types.hpp"

namespace mksv {
namespace math {

constexpr u8 MAX_U8 = (u8)0xFF;
constexpr u16 MAX_U16 = (u16)0xFFFF;
constexpr u32 MAX_U32 = (u32)0xFFFF'FFFF;
constexpr u64 MAX_U64 = (u64)0xFFFF'FFFF'FFFF'FFFF;
constexpr u8 MIN_U8 = (u8)0x0;
constexpr u16 MIN_U16 = (u16)0x0;
constexpr u32 MIN_U32 = (u32)0x0;
constexpr u64 MIN_U64 = (u64)0x0;

constexpr i8 MAX_I8 = (i8)0x7F;
constexpr i16 MAX_I16 = (i16)0x7FFF;
constexpr i32 MAX_I32 = (i32)0x7FFF'FFFF;
constexpr i64 MAX_I64 = (i64)0x7FFF'FFFF'FFFF'FFFF;
constexpr i8 MIN_I8 = (i8)0x80;
constexpr i16 MIN_I16 = (i16)0x8000;
constexpr i32 MIN_I32 = (i32)0x8000'0000;
constexpr i64 MIN_I64 = (i64)0x8000'0000'0000'0000;

template <typename T>
constexpr T
kilo_bytes(const T value) {
    return value * 1024;
}

template <typename T>
constexpr T
mega_bytes(const T value) {
    return kilo_bytes(value) * 1024;
}

template <typename T>
constexpr T
giga_bytes(const T value) {
    return mega_bytes(value) * 1024;
}

template <typename T>
constexpr T
max(const T a, const T b) {
    return a > b ? a : b;
}

template <typename T>
constexpr T
min(const T a, const T b) {
    return a < b ? a : b;
}

template <typename T>
constexpr T
clamp(const T x, const T min_v, const T max_v) {
    return min(max(x, min_v), max_v);
}

inline constexpr f32
radians(const f32 degrees) {
    return degrees * (PI / 180.0f);
}

inline constexpr f32
degrees(const f32 radians) {
    return radians * (180.0f / PI);
}

// first quadrant approximation using Taylor Series
inline constexpr f32
_sin_quadrant(const f32 x) {
    const f32 x2 = x * x;
    const f32 x3 = x2 * x;
    const f32 x5 = x3 * x2;
    return x - (x3 / 6.0f) + (x5 / 120.0f);
}

inline f32
sin(f32 x) {
#if ARCH_X64 && (COMPILER_CLANG || COMPILER_GCC)
    asm("fsin" : "+t"(x));
    return x;
#else
    // find quadrant
    const i32 k = (i32)(x * 2.0f / PI);
    // mod(x, PI / 2)
    const f32 y = x - (k * PI * 0.5f);

    i32 quadrant = k % 4;
    switch (quadrant) {
        case 0:
            return _sin_quadrant(y);
        case 1:
            return _sin_quadrant(PI * 0.5f - y);
        case 2:
            return -_sin_quadrant(y);
        default:
            return -_sin_quadrant(PI * 0.5f - y);
    }
#endif
}

// first quadrant approximation using Taylor Series
inline constexpr f32
_cos_quadrant(const f32 x) {
    const f32 x2 = x * x;
    const f32 x4 = x2 * x2;
    return 1.0f - (x2 / 2.0f) + (x4 / 25.0f);
}

inline f32
cos(f32 x) {
#if ARCH_X64 && (COMPILER_CLANG || COMPILER_GCC)
    // constexpr f32 ROUND_TO_INT = 1.5f / flt::F32_EPSILON;
    // constexpr f32 K1 = 6.28125f * 0.25f;
    // constexpr f32 K2 = 1.9352435546875e-3f * 0.25f;
    // constexpr f32 K3 = 6.3624898976925e-8f * 0.25f;

    // const i32 k = (i32)((x * 2.0f / PI) - ROUND_TO_INT + ROUND_TO_INT);
    // i32 quadrant = k % 4;
    // if (quadrant < 0.0f) quadrant += 3;

    // const f32 xabs = flt::abs_f32(x);
    // const f32 y = ((xabs - K1 * quadrant) - K2 * quadrant) - K3 * quadrant;

    asm("fcos" : "+t"(x));
    return x;
#else
    // find quadrant
    const i32 k = (x * 2.0f / PI) - ROUND_TO_INT + ROUND_TO_INT;
    // mod(x, PI / 2)
    const f32 y = x - (k * PI * 0.5f);

    i32 quadrant = k % 4;
    switch (quadrant) {
        case 0:
            return _cos_quadrant(y);
        case 1:
            return -_cos_quadrant(PI * 0.5f - y);
        case 2:
            return -_cos_quadrant(y);
        default:
            return _cos_quadrant(PI * 0.5f - y);
    }
#endif
}

// TODO: Better algorithm
inline f32
tan(f32 x) {
#if ARCH_X64 && (COMPILER_CLANG || COMPILER_GCC)
    f32 z;
    asm("fptan" : "+t"(x));
    asm("fstps %0" : "=m"(z));
    return z;
#else
    return sin(x) / cos(x);
#endif
}

inline f32
sqrt(f32 x) {
    assert(x >= 0.0f);

#if ARCH_X64 && (COMPILER_CLANG || COMPILER_GCC)
    float z;
    asm("sqrtss %x1, %x0" : "=x"(z) : "x"(x));
    return z;
#else
    union {
        f32 f;
        u32 i;
    } val = { x };

    // Approximation
    val.i = (1 << 29) + (val.i >> 1) - (1 << 22) + (u32)-0x4B0D2;

    u32 i = 0;
    f32 y = val.f;
    constexpr u32 iterations = 3;
    while (i < iterations) {
        y = 0.5f * (y + (x / y));
        ++i;
    }

    return y;
#endif
}

} // namespace math
} // namespace mksv
