const std = @import("std");
const mksv = @import("mksv");
const math = mksv.math;

fn less(a: *const u32, b: *const u32) std.math.Order {
    return std.math.order(a.*, b.*);
}

pub fn main() !void {
    const T = mksv.rb.Tree(u32, less);
    var tree = T{};

    var nodes: [10]T.Node = .{
        .{ .value = 32 },
        .{ .value = 64 },
        .{ .value = 0 },
        .{ .value = 1 },
        .{ .value = 8 },
        .{ .value = 26 },
        .{ .value = 42 },
        .{ .value = 2 },
        .{ .value = 3 },
        .{ .value = 4 },
    };

    _ = tree.insert(&nodes[0]);
    _ = tree.insert(&nodes[1]);
    _ = tree.insert(&nodes[2]);
    _ = tree.insert(&nodes[4]);
    _ = tree.insert(&nodes[3]);
    _ = tree.insert(&nodes[5]);
    _ = tree.insert(&nodes[7]);
    _ = tree.insert(&nodes[6]);
    _ = tree.insert(&nodes[8]);
    _ = tree.insert(&nodes[9]);

    try tree.debugPrint();
}
