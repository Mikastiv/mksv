const std = @import("std");
const mksv = @import("mksv");
const math = mksv.math;

pub fn main() !void {
    var args = try std.process.argsWithAllocator(std.heap.page_allocator);
    var i: i32 = 0;
    while (args.next()) |_| : (i += 1) {}
    const a = math.Mat2i{
        .{ 3, i },
        .{ 9, 1 },
    };
    const b = math.Mat2i{
        .{ 7, 9 },
        .{ i, 6 },
    };
    const out = math.mat.mul(a, b);
    math.mat.debugPrint(out);
}
