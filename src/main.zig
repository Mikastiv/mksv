const std = @import("std");
const mksv = @import("mksv");
const math = mksv.math;

pub fn main() !u8 {
    const f = math.Frustum.init(std.math.degreesToRadians(80), 16.0 / 9.0, 0.1, 10000, .{ 0, 0, 0 }, .{ 0, 0, 1 });

    var args = try std.process.argsWithAllocator(std.heap.page_allocator);
    if (args.next()) |_| {
        if (f.isPointInside(.{ 0, 0, 38 })) {
            return 1;
        }
        return 2;
    }

    return 0;
}
