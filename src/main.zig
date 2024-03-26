const std = @import("std");
const mksv = @import("mksv");
const math = mksv.math;

pub fn main() !void {
    const a = math.Mat4{
        .{ 3, 4, 8, 8 },
        .{ 9, 1, 5, 2 },
        .{ 8, 2, 8, 4 },
        .{ 9, 6, 5, 2 },
    };
    const b = math.Mat4{
        .{ 7, 9, 1, 3 },
        .{ 8, 6, 2, 5 },
        .{ 3, 9, 1, 3 },
        .{ 0, 4, 2, 1 },
    };
    // const vec = math.Vec4{ 0, 1, 1, 1 };
    const out = math.mat.mul(a, b);

    math.mat.debugPrint(a);
    std.log.debug("", .{});
    math.mat.debugPrint(b);
    std.log.debug("", .{});
    math.mat.debugPrint(out);
}
