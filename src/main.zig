const std = @import("std");
const mksv = @import("mksv");
const math = mksv.math;

fn less(a: *const u32, b: *const u32) std.math.Order {
    return std.math.order(a.*, b.*);
}

pub fn main() !void {
    const T = mksv.rb.Tree(u32, less);
    var tree = T{};

    var rng = std.Random.DefaultPrng.init(0);
    const rand = rng.random();

    var nodes = [10]T.Node{
        .{ .value = rand.int(u32) % 64 },
        .{ .value = rand.int(u32) % 64 },
        .{ .value = rand.int(u32) % 64 },
        .{ .value = rand.int(u32) % 64 },
        .{ .value = rand.int(u32) % 64 },
        .{ .value = rand.int(u32) % 64 },
        .{ .value = rand.int(u32) % 64 },
        .{ .value = rand.int(u32) % 64 },
        .{ .value = rand.int(u32) % 64 },
        .{ .value = rand.int(u32) % 64 },
    };

    _ = tree.insert(&nodes[0]);
    _ = tree.insert(&nodes[1]);
    _ = tree.insert(&nodes[2]);
    _ = tree.insert(&nodes[3]);
    _ = tree.insert(&nodes[4]);
    _ = tree.insert(&nodes[5]);
    _ = tree.insert(&nodes[6]);
    _ = tree.insert(&nodes[7]);
    _ = tree.insert(&nodes[8]);

    try tree.debugPrint(true);

    nodes[9].value = nodes[4].value;
    try tree.replace(&nodes[4], &nodes[9]);

    try tree.debugPrint(true);
}
