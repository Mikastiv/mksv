const std = @import("std");
const mksv = @import("mksv");
const math = mksv.math;

pub fn main() !void {
    const a = math.Mat4i{
        .{ 1, 2, 3, 4 },
        .{ 5, 6, 7, 8 },
        .{ 9, 10, 11, 12 },
        .{ 13, 14, 15, 16 },
    };
    const out = math.mat.transpose(a);
    math.mat.debugPrint(out);
}
