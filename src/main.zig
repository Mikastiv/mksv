const std = @import("std");
const mksv = @import("mksv");
const math = mksv.math;

fn less(a: *const u32, b: *const u32) std.math.Order {
    return std.math.order(a.*, b.*);
}

const FiberData = struct {
    text: [*:0]const u8,
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    _ = allocator; // autofix

    const Tree = mksv.rb.Tree(u32, less);
    var t = Tree{};

    var nodes = [_]Tree.Node{
        .{ .value = 12 },
        .{ .value = 1 },
        .{ .value = 14 },
        .{ .value = 19 },
        .{ .value = 20 },
        .{ .value = 22 },
        .{ .value = 32 },
        .{ .value = 0 },
    };

    _ = t.insert(&nodes[0]);
    _ = t.insert(&nodes[1]);
    _ = t.insert(&nodes[2]);
    _ = t.insert(&nodes[3]);
    _ = t.insert(&nodes[4]);
    _ = t.insert(&nodes[5]);
    _ = t.insert(&nodes[6]);

    try t.debugPrint(true);

    _ = t.removeKey(&12);

    try t.debugPrint(true);

    _ = t.removeKey(&13);
    _ = t.removeKey(&14);

    try t.debugPrint(true);
}
